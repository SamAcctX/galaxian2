extends RefCounted
const Frames=preload("res://src/simulation/frame_clock.gd")
var _max_ms:=0
## First-departure asteroid acquisition. Selection grants no cargo, movement or
## mission progress. The flight supplies committed poses and its retained aim.
const Definitions=preload("res://src/content/mining_targeting_definitions.gd")
const RecoveryDefinitions=preload("res://src/content/tractor_recovery_definitions.gd")
const OrdinaryFlight=preload("res://src/content/ordinary_flight_definitions.gd")
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const TargetProjection=preload("res://src/presentation/target_projection.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Selected40=preload("res://src/content/selected40_population_definitions.gd")
const Equipment=preload("res://src/simulation/station_equipment.gd")
const Readonly=preload("res://src/simulation/readonly_state.gd")
var error:=""
var _rules:={}
var _perspective:={}
var _identity:={}
var _field_identity: RefCounted
var _radii:=Vector2.ZERO
var _frames:=0
var _duration:=0
var _scanner_id:=-1
var _drill_id:=-1
var _tractor_id:=-1
var _tractor_mode:=-1
var _selected:=-1
var _candidate:=-1
var _elapsed:=0
var _sample:={}
var _selected40_world: RefCounted
## The scan behind the last sample. No presentation draws a marker per body, so
## a frame only decides the candidates; snapshot() describes every body from here.
var _scan_field:={}
var _scan_camera:=Transform3D.IDENTITY
var _scan_low:=Vector2i.ZERO
var _scan_high:=Vector2i.ZERO
var _scan_selected:=-1
## The read-only body lists that passed validation, and their positions for the
## coarse window test. Frames share the lists until a body changes.
var _checked_bodies:=[]
var _checked_objects:=[]
var _positions:=PackedVector3Array()
var _extent:=0.0
# Coarse rejection: the slack is four times the largest binary32 rounding
# difference between the engine's transform and sample() (2^-21 of the summed
# coordinates), and coordinates beyond the limit take the exact test.
const COARSE_SLACK:=0.000002
const COARSE_LIMIT:=1.0e15

func configure(bindings: RefCounted, catalogues: RefCounted, construction: RefCounted, frame_radii: Vector2, animation_frames: int) -> bool:
	error=""
	if bindings==null or catalogues==null or construction==null or construction.get_script()!=Construction or not Definitions.parameters(bindings.mining_targeting):return reject("Asteroid selection requires a supported mining departure")
	var entry: Dictionary=construction.snapshot()
	if entry.is_empty() or entry.get("base_content_id")!=bindings.base_content_id or entry.get("binding_id")!=bindings.binding_id or catalogues.content_id!=bindings.base_content_id or OrdinaryFlight.for_departure(bindings,entry).is_empty():return reject("Asteroid selection belongs to another departure")
	return _configure_devices(bindings,catalogues,entry.departure.loadout,construction.scenery_owner(),frame_radii,animation_frames)

## Native scenery acquisition is independent of the ship scanner. The source
## permits the default asteroid timer without that device; a missing drill or
## tractor produces its real notice instead of equipment, cargo or progress.
func configure_selected40(bindings: RefCounted,catalogues: RefCounted,equipment: RefCounted,scenery: RefCounted,frame_radii: Vector2,animation_frames: int) -> bool:
	error=""
	if not _rules.is_empty() or not scenery is Scenery or not equipment is Equipment or bindings==null or catalogues==null:return reject("Selected40 asteroid acquisition requires fresh native scenery and equipment")
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null or world.npc_construction_owner()==null or not Selected40.context_valid(bindings,world.snapshot().get("selected40_context",{})):return reject("Selected40 asteroid acquisition lacks its native source generation")
	var loadout: Dictionary=equipment.snapshot().loadout
	if Selected40.retained_player_context(bindings,world.npc_construction_owner().snapshot(),loadout).is_empty() or not equipment.cargo_cache_valid():return reject("Selected40 asteroid acquisition changed its retained origin loadout")
	if not _configure_devices(bindings,catalogues,loadout,scenery,frame_radii,animation_frames):return false
	_selected40_world=world
	return true

func configure_mission(bindings: RefCounted,catalogues: RefCounted,equipment: RefCounted,scenery: RefCounted,frame_radii: Vector2,animation_frames: int,context: RefCounted) -> bool:
	error=""
	if not _rules.is_empty() or not scenery is Scenery or not equipment is Equipment or bindings==null or catalogues==null or not is_instance_of(context,load("res://src/simulation/mission_context.gd")):return reject("Mission asteroid acquisition requires fresh admitted scenery and equipment")
	var loadout: Dictionary=equipment.snapshot().loadout
	if not context.matches_loadout(loadout) or not equipment.cargo_cache_valid():return reject("Mission asteroid acquisition lost its admitted loadout")
	return _configure_devices(bindings,catalogues,loadout,scenery,frame_radii,animation_frames)

func _configure_devices(bindings: RefCounted,catalogues: RefCounted,loadout: Dictionary,scenery: RefCounted,frame_radii: Vector2,animation_frames: int) -> bool:
	if not Definitions.parameters(bindings.mining_targeting) or catalogues.content_id!=bindings.base_content_id:return reject("Asteroid acquisition requires its source declarations and catalogue")
	var projection:=TargetProjection.new()
	if not projection.configure(bindings.flight_projection,Vector2i.ONE,frame_radii):return reject(projection.error)
	if animation_frames<1 or animation_frames>1024:return reject("Invalid source acquisition filmstrip")
	var rules: Dictionary=bindings.mining_targeting
	var scanner:=-1;var drill:=-1;var tractor:=-1;var tractor_mode:=-1
	var items: Array=catalogues.tables.get("items",[])
	for id in loadout.equipment_ids:
		if not Numbers.integer(id,0,items.size()-1):return reject("Asteroid selection equipment is unavailable")
		var properties: Dictionary=items[id].properties
		# Installed primaries share the loadout but do not supply the equipment
		# subtypes used by the scanner and drill getters.
		if properties.get(int(rules.item_kind_property))!=int(rules.equipment_kind):continue
		var category: Variant=properties.get(int(rules.category_property))
		if tractor<0 and category==int(rules.unsupported_device_category):
			if not RecoveryDefinitions.available(bindings):return reject("Scenery cargo requires verified tractor declarations")
			var device: Dictionary=bindings.mido_travel.tractor_recovery.equipment
			var mode: Variant=properties.get(int(device.mode_property))
			if not Numbers.integer(mode,0,2147483647) or not device.modes.any(func(value):return int(value)==int(mode)):return reject("Unsupported scenery tractor acquisition mode")
			tractor=id;tractor_mode=int(mode)
		if scanner<0 and category==int(rules.scanner_category):scanner=id
		if drill<0 and category==int(rules.drill_category):drill=id
	var duration:=int(rules.default_duration_ms)
	if scanner>=0:
		var value: Variant=items[scanner].properties.get(int(rules.duration_property))
		if not Numbers.integer(value,int(rules.animation_delay_ms)+1,2147483647):return reject("Unsupported asteroid acquisition duration")
		duration=int(value)
	_rules=rules.duplicate(true);_perspective=bindings.flight_projection.duplicate(true)
	_max_ms=Frames.simulation_limit(bindings,int(_rules.max_frame_ms))
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_field_identity=scenery.presentation_identity();_selected40_world=null
	_radii=frame_radii;_frames=animation_frames;_duration=duration;_scanner_id=scanner;_drill_id=drill;_tractor_id=tractor;_tractor_mode=tractor_mode
	_selected=-1;_candidate=-1;_elapsed=0;_sample={};_scan_field={}
	return true

func advance(scenery: RefCounted, player: Transform3D, camera: Transform3D, aim: Dictionary, delta_ms: Variant, enabled: bool, approaching:=false, selection_blocked:=false, acquisition_suspended:=false, recovery_pending:=false) -> bool:
	error=""
	if _rules.is_empty() or scenery==null or scenery.get_script()!=Scenery or scenery.presentation_identity()!=_field_identity or not Numbers.integer(delta_ms,0,_max_ms):return reject("Invalid asteroid selection field or frame")
	if _selected40_world!=null:
		var world: RefCounted=scenery.world_initialization_owner()
		if world==null or world.npc_construction_owner()!=_selected40_world.npc_construction_owner() or world.snapshot()!=_selected40_world.snapshot():return reject("Selected40 asteroid acquisition changed its actual constructor generation")
	for key in _identity:
		if aim.get(key)!=_identity[key]:return reject("Asteroid selection aim belongs to another identity")
	var point: Variant=aim.get("point");var viewport: Variant=aim.get("viewport_size")
	if not point is Vector3 or not point.is_finite() or not TargetProjection.safe_pixel(point.x) or not TargetProjection.safe_pixel(point.y) or not viewport is Vector2i or not player.is_finite() or not camera.is_finite() or not camera.basis.is_equal_approx(camera.basis.orthonormalized()) or camera.basis.determinant()<=0:return reject("Invalid asteroid selection aim or pose")
	var projection:=TargetProjection.new()
	if not projection.configure(_perspective,viewport,_radii):return reject(projection.error)
	var radius:=int(viewport.x)/int(_rules.window_divisor)
	var lower:=Vector2(TargetProjection.single(point.x-float(radius)),TargetProjection.single(point.y-float(radius)))
	for value in [lower.x,lower.y,lower.x+radius*2,lower.y+radius*2]:
		if not TargetProjection.safe_pixel(value):return reject("Asteroid selection window exceeds source pixel coordinates")
	var low:=Vector2i(int(lower.x),int(lower.y));var high:=low+Vector2i(radius*2,radius*2)
	var field: Dictionary=scenery.read_snapshot()
	for key in _identity:
		if field.get(key)!=_identity[key] or field.get("bodies",{}).get(key)!=_identity[key]:return reject("Asteroid bodies belong to another content identity")
	var bodies: Variant=field.get("bodies",{}).get("objects")
	var lifecycles: Array=field.get("destruction",[])
	if not bodies is Array or bodies.size()!=field.objects.size() or (not lifecycles.is_empty() and lifecycles.size()!=bodies.size()):return reject("Asteroid selection requires complete live bodies")
	var objects: Array=field.objects
	if not _check_rows(bodies,objects):return false
	var candidates:=[];var kinds:={};var automatic_recovery:=-1
	var scanning: bool=enabled and not approaching
	var normal_selection: bool=not selection_blocked and not acquisition_suspended
	var limit:=int(_rules.candidate_limit)
	# One engine call places every body in camera space, a few binary32 roundings
	# away from sample(): enough to rule a body out of the scan window, never to
	# place it. Bodies it cannot rule out are projected exactly.
	var rough:=_positions*camera if scanning else PackedVector3Array()
	var slack:=COARSE_SLACK*(_extent+absf(camera.origin.x)+absf(camera.origin.y)+absf(camera.origin.z))
	if not slack<COARSE_SLACK*COARSE_LIMIT:slack=INF
	var window:=projection.window(low,high);var near:=projection.near()
	var slack_x:=slack*(1.0+absf(window[0])+window[1]);var slack_y:=slack*(1.0+absf(window[2])+window[3])
	for index in bodies.size():
		var debris:=false
		if not lifecycles.is_empty():
			var lifecycle: Dictionary=lifecycles[index].lifecycle
			var state:=int(lifecycle.actor_state)
			if state!=0:
				if state!=3 and state!=4:return reject("Unsupported asteroid selection lifecycle")
				# Scenery's cargo flag is independent of retired collision statistics.
				# Its position getter follows the physical model, not those statistics.
				if not lifecycle.drop_allowed:continue
				debris=true
		if not scanning:continue
		# Automatic recovery keeps the ordered cargo request separate from the
		# mining clock. All-direction devices bypass ordinary selection gates,
		# but neither mode can replace an existing pickup or a prior cargo row.
		var recovers: bool=debris and automatic_recovery<0 and not recovery_pending
		if recovers and _tractor_mode==2:automatic_recovery=index;continue
		var recovers_in_view: bool=recovers and _tractor_mode==1 and normal_selection
		var selects: bool=normal_selection and not recovery_pending and automatic_recovery<0 and candidates.size()<limit
		if not recovers_in_view:
			if not selects:continue
			var local:=rough[index]
			if local.z-slack>near or absf(local.x-window[0]*local.z)>window[1]*absf(local.z)+slack_x or absf(local.y-window[2]*local.z)>window[3]*absf(local.z)+slack_y:continue
		if not projection.sample(camera,objects[index].position):return reject(projection.error)
		if recovers_in_view and projection.in_view:automatic_recovery=index
		if selects and automatic_recovery<0 and _in_window(projection,low,high) and not bodies[index].get("mined",false):
			candidates.append(index);kinds[index]="debris" if debris else "asteroid"
	var selected:=_selected;var candidate:=_candidate;var elapsed:=_elapsed
	var nearest:=-1;var nearest_distance:=int(_rules.candidate_distance_limit)
	var events:=[];var animation:=-1;var recovery:=automatic_recovery
	# Mining owns its selected body while approaching. An earlier NPC candidate
	# or ordinary autopilot also skips this clock/selection pass. A retained
	# request, planet or mission route instead prevents a new candidate; ordinary
	# aim-loss cleanup then resets the scenery clock without touching that owner.
	if enabled and not approaching and not acquisition_suspended:
		for index in candidates:
			var offset:=Vectors.added(field.objects[index].position,-player.origin)
			var length:=TargetProjection.single(sqrt(Vectors.dot(offset,offset)))
			if not is_finite(length) or length>2147483647.0:return reject("Asteroid target distance exceeds source range")
			var distance:=int(length)
			if distance<nearest_distance:nearest=index;nearest_distance=distance
		selected=-1
		if nearest<0:
			candidate=-1;elapsed=0
		else:
			if candidate!=nearest:elapsed=0
			candidate=nearest
			if elapsed>2147483647-int(delta_ms):return reject("Asteroid acquisition time exceeds source range")
			elapsed+=int(delta_ms)
			if elapsed>_duration-int(_rules.acquisition_lead_ms):
				if kinds[candidate]=="debris":
					if _tractor_id>=0:
						if recovery<0:recovery=candidate
					else:events.append({"kind":"notification","source_id":int(_rules.missing_tractor_notification),"object_index":candidate})
				elif _drill_id<0:events.append({"kind":"notification","source_id":int(_rules.missing_drill_notification),"object_index":candidate})
				else:
					selected=candidate
					if _selected!=selected:events.append({"kind":"sound","source_id":int(_rules.acquisition_sound_id),"unless_source_id_playing":0,"object_index":selected})
			if elapsed>int(_rules.animation_delay_ms):
				if selected==candidate or recovery==candidate:animation=_frames-1
				else:
					var progress:=TargetProjection.single(TargetProjection.single(float(elapsed-int(_rules.animation_delay_ms)))/TargetProjection.single(float(_duration-int(_rules.animation_delay_ms))))
					var frame:=int(TargetProjection.single(float(_frames-1)*progress))
					if frame<_frames-1:animation=frame
	_scan_field=field if scanning else {};_scan_camera=camera;_scan_low=low;_scan_high=high;_scan_selected=_selected
	_selected=selected;_candidate=candidate;_elapsed=elapsed
	# The sample is replaced whole by the next advance: read-only, it is shared
	# with forks and with the per-frame presentation observation.
	_sample=Readonly.freeze({"visible":enabled,"candidate_indices":candidates,"nearest_index":nearest,
		"events":events,"animation_frame":animation,"recovery_object_index":recovery,"aim_pixels":Vector2i(int(point.x),int(point.y)),"viewport_size":viewport})
	return true

## Body rows are read-only and stay the same lists between frames until a body
## changes, so each pair of lists is checked once instead of once per frame.
func _check_rows(bodies: Array,objects: Array) -> bool:
	if is_same(bodies,_checked_bodies) and is_same(objects,_checked_objects):return true
	var positions:=PackedVector3Array();var extent:=0.0
	for index in bodies.size():
		var body: Variant=bodies[index];var object: Variant=objects[index]
		if not body is Dictionary or body.get("index")!=index or not body.get("active") is bool or not body.get("position") is Vector3 or not body.position.is_finite() or not Numbers.integer(body.get("source_size_value"),4,7) or not object.position is Vector3 or not object.position.is_finite() or body.model_id!=object.model_id:return reject("Invalid asteroid body sample")
		positions.append(object.position);extent=maxf(extent,absf(object.position.x)+absf(object.position.y)+absf(object.position.z))
	var shared: bool=bodies.is_read_only() and objects.is_read_only()
	_checked_bodies=bodies if shared else [];_checked_objects=objects if shared else []
	_positions=positions;_extent=extent
	return true

static func _in_window(projection: RefCounted,low: Vector2i,high: Vector2i) -> bool:
	var pixel: Vector2i=projection.pixels
	return projection.in_view and pixel.x>low.x and pixel.x<high.x and pixel.y>low.y and pixel.y<high.y

## One marker per body the last scan considered, each projected exactly.
func _markers() -> Array:
	var markers:=[]
	if _scan_field.is_empty():return markers
	var projection:=TargetProjection.new()
	if not projection.configure(_perspective,_sample.viewport_size,_radii):return markers
	var bodies: Array=_scan_field.bodies.objects;var lifecycles: Array=_scan_field.get("destruction",[])
	for index in bodies.size():
		var debris:=false
		if not lifecycles.is_empty() and int(lifecycles[index].lifecycle.actor_state)!=0:
			if not lifecycles[index].lifecycle.drop_allowed:continue
			debris=true
		if not projection.sample(_scan_camera,_scan_field.objects[index].position):return []
		markers.append({"object_index":index,"pixels":projection.pixels,"in_view":projection.in_view,"in_scan_window":_in_window(projection,_scan_low,_scan_high),"selected":index==_scan_selected,"kind":"debris" if debris else "asteroid","item_id":bodies[index].item_id})
	return markers

func snapshot() -> Dictionary:
	if _sample.is_empty():return _observation({})
	var sample:={"visible":_sample.visible,"markers":_markers()}
	sample.merge(_sample.duplicate(true))
	return _observation(sample)

## The same observation without its markers for per-frame presentation reads;
## its sample is shared.
func read_snapshot() -> Dictionary:return _observation(_sample)

func _observation(sample: Dictionary) -> Dictionary:
	if _rules.is_empty():return {}
	var state:=_identity.duplicate()
	state.merge({"selected_object_index":_selected,"candidate_object_index":_candidate,"elapsed_ms":_elapsed,
		"scanner_id":_scanner_id,"drill_id":_drill_id,"tractor_id":_tractor_id,"tractor_mode":_tractor_mode,"duration_ms":_duration,"animation_frames":_frames})
	state.merge(sample)
	return state

func clear_selection() -> void:_selected=-1
func selected_object_index() -> int:return _selected
func selection_events() -> Array:return _sample.get("events",[]).duplicate(true)
func recovery_object_index() -> int:return int(_sample.get("recovery_object_index",-1))
func field_identity() -> RefCounted:return _field_identity
func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._rules=_rules;copy._perspective=_perspective;copy._identity=_identity;copy._field_identity=_field_identity
	copy._radii=_radii;copy._frames=_frames;copy._duration=_duration;copy._scanner_id=_scanner_id;copy._drill_id=_drill_id;copy._tractor_id=_tractor_id;copy._tractor_mode=_tractor_mode
	# Each advance replaces the complete sample; public observations stay detached.
	copy._selected=_selected;copy._candidate=_candidate;copy._elapsed=_elapsed;copy._sample=_sample
	copy._scan_field=_scan_field;copy._scan_camera=_scan_camera;copy._scan_low=_scan_low;copy._scan_high=_scan_high;copy._scan_selected=_scan_selected
	copy._checked_bodies=_checked_bodies;copy._checked_objects=_checked_objects;copy._positions=_positions;copy._extent=_extent
	copy._selected40_world=_selected40_world
	copy._max_ms=_max_ms;return copy
func clear() -> void:
	_max_ms=0
	error="";_rules={};_perspective={};_identity={};_field_identity=null;_sample={}
	_scan_field={};_scan_camera=Transform3D.IDENTITY;_scan_low=Vector2i.ZERO;_scan_high=Vector2i.ZERO;_scan_selected=-1
	_checked_bodies=[];_checked_objects=[];_positions=PackedVector3Array();_extent=0.0
	_selected40_world=null
	_radii=Vector2.ZERO;_frames=0;_duration=0;_scanner_id=-1;_drill_id=-1;_tractor_id=-1;_tractor_mode=-1;_selected=-1;_candidate=-1;_elapsed=0
func reject(message: String) -> bool:error=message;return false
