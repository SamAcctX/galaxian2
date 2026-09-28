extends RefCounted
## Shared selected-story and ordinary Void portal. Flight owns transitions.
const Definitions=preload("res://src/content/void_portal_definitions.gd")
const Access=preload("res://src/content/void_access_definitions.gd")
const Portal=preload("res://src/simulation/alioth_portal.gd")
const Contact=preload("res://src/simulation/portal_contact.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Library=preload("res://src/content/library.gd")
const AEM=preload("res://src/content/aem.gd")
const Effects=preload("res://src/content/scenery_effect_resources.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Source=preload("res://src/simulation/ordinary_void_source.gd")
const Selected40=preload("res://src/content/selected40_population_definitions.gd")
const Context=preload("res://src/simulation/mission_context.gd")
var error:=""
var _rules:={}
var _probe:={}
var _state:={}
var _contact:={}
var _frame:={}
var _entered:=false
var _max_ms:=0
var _selected40_generation: RefCounted
var _context: RefCounted
var _hold_open: Variant=null
var _explicit_opening:=false
var _identity: RefCounted

## Entry has already been admitted by the capability owner. Consume the
## initialized world's original environment slot, without selecting a story.
func configure_admitted_world(bindings: RefCounted,context: RefCounted,world: Dictionary,library: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or bindings==null or not context is Context or not context.has_feature("portal"):
		return reject("Portal requires a fresh admitted world")
	if not Definitions.coherent(bindings.mido_travel):return reject("Shared portal declarations are unavailable")
	var identity: Dictionary=context.identity();var recipe: Dictionary=context.recipe()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if world.get(key)!=identity.get(key):return reject("Portal belongs to another admitted world")
	for key in ["station_id","system_id"]:
		if world.get(key)!=recipe.get(key):return reject("Portal location differs from its admitted world")
	var entry:=world.duplicate(true);entry.mission_kind=recipe.mission.kind
	if not _configure_accepted(bindings,entry,library,{}):return false
	_context=context
	return true

## Retain the animation and model. A newly opened contact volume starts a new
## entry latch; the flight still owns contact sampling, pull and world changes.
func open_at(position: Vector3,hold_open:=true) -> bool:
	error=""
	if _state.is_empty() or not position.is_finite():return reject("Open a configured portal at a finite position")
	_state=_state.duplicate(true)
	_state.position=position;_state.pose.origin=position;_state.visible=true
	_state.elapsed_ms=-int(_rules.portal.open_duration_ms);_state.extent=0;_state.scale=0.0
	_hold_open=hold_open;_explicit_opening=true;_entered=false;_contact={};_frame={}
	return true

func set_hold_open(enabled: bool) -> bool:
	error=""
	if _state.is_empty():return reject("Hold a configured portal")
	_hold_open=enabled
	return true

func begin_closing(age_ms:=59000) -> bool:
	error=""
	if _state.is_empty() or age_ms<0 or age_ms>int(_rules.portal.close_start_ms):return reject("Portal closing requires a full-size lifetime age")
	_state=_state.duplicate(true)
	_state.elapsed_ms=age_ms;_state.extent=int(_rules.portal.extent_scale);_state.scale=1.0;_state.visible=true
	_hold_open=false;_explicit_opening=false
	return true

func mission_context_owner() -> RefCounted:return _context
func retained_identity() -> RefCounted:return _identity

func set_visible(enabled: bool) -> bool:
	error=""
	if _state.is_empty():return reject("Visibility requires a configured portal")
	_state=_state.duplicate(true);_state.visible=enabled
	if not enabled:_entered=false;_contact={};_frame={}
	return true

func configure(bindings: RefCounted,entry: Dictionary,library: RefCounted) -> bool:
	error=""
	if bindings==null or not Definitions.selected(bindings.mido_travel,entry):return reject("The portal requires its selected source world")
	return _configure_accepted(bindings,entry,library,{})

## The ordinary source flight and its retained Void return select the sentinel
## mission. The caller owns the actual world and commits any transition once.
func configure_ordinary(bindings: RefCounted,entry: Dictionary,source_owner: RefCounted,library: RefCounted) -> bool:
	error=""
	if bindings==null or not bindings.mido_travel is Dictionary or not Definitions.coherent(bindings.mido_travel) or not Access.parameters(bindings.mido_travel.get("void_access")):
		return reject("Ordinary Void portal declarations are unavailable")
	if load("res://src/simulation/mission_context.gd").ordinary_void_route(bindings,source_owner).is_empty():return reject("Ordinary Void portal requires its retained native source")
	var source: Dictionary=load("res://src/simulation/mission_context.gd").ordinary_void_route(bindings,source_owner)
	if source.get("base_content_id")!=bindings.base_content_id or source.get("binding_id")!=bindings.binding_id or not source.get("source_system_id") is int or not source.get("source_station_id") is int or source.source_system_id<0 or source.source_station_id<0:
		return reject("Ordinary Void portal source belongs to another content or location")
	var ordinary: Dictionary=bindings.mido_travel.void_access.ordinary_portal
	if not entry.get("campaign_cursor") is int or entry.campaign_cursor!=source.campaign_cursor or not entry.get("mission_kind") is int or entry.mission_kind!=int(ordinary.selected_mission_kind_at_source_flight):
		return reject("Ordinary Void portal requires its admitted sentinel selection")
	if entry.get("mission_story")!=false or not entry.get("mission_story") is bool:
		return reject("Ordinary Void portal requires a nonstory sentinel selection")
	for key in ["system_id","station_id","current_station_id","void_station_id"]:
		if not entry.get(key) is int:return reject("Ordinary Void portal requires its selected and retained locations")
	if entry.void_station_id!=int(ordinary.retained_void_station_id):return reject("Ordinary Void portal lost its retained Void station")
	var in_source: bool=entry.system_id==source.source_system_id and entry.station_id==source.source_station_id and entry.current_station_id==source.source_station_id
	var in_void: bool=entry.system_id==int(ordinary.selected_void_system_id) and entry.station_id==int(ordinary.selected_void_station_id) and entry.current_station_id==int(ordinary.selected_void_station_id)
	if not in_source and not in_void:return reject("Ordinary Void portal is outside the retained source and Void")
	if in_void and (not entry.get("return_station_id") is int or entry.return_station_id!=source.source_station_id):
		return reject("Ordinary Void return lacks the actual retained source station")
	if in_source and entry.has("return_station_id") and (not entry.return_station_id is int or entry.return_station_id!=source.source_station_id):
		return reject("Ordinary Void entry changed its source station")
	if entry.has("return_system_id") and (not entry.return_system_id is int or entry.return_system_id!=source.source_system_id):
		return reject("Ordinary Void portal changed its source system")
	var route:={"ordinary_mode":"void_return" if in_void else "source_entry",
		"source_system_id":source.source_system_id,"source_station_id":source.source_station_id,
		"return_system_id":source.source_system_id,"return_station_id":source.source_station_id}
	return _configure_accepted(bindings,entry,library,route)

## Source40 is a selected story in normal space, NOT cursor33's sentinel.
## Its actual native field carries the source-before-reroll entry and the
## selected actor generation; a caller-supplied relocated cache is not enough.
func configure_selected40(bindings: RefCounted,scenery: RefCounted,library: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or bindings==null or not is_instance_of(scenery,load("res://src/simulation/opening_scenery.gd")) or not Definitions.coherent(bindings.mido_travel):
		return reject("Selected40 portal requires a fresh native source-world owner")
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null or not Selected40.context_valid(bindings,world.snapshot().get("selected40_context",{})) or world.npc_construction_owner()==null:
		return reject("Selected40 portal lost its source-selected constructor generation")
	var entry: Dictionary=scenery.snapshot().get("departure_population",{}).get("selected40_entry",{})
	if entry.get("campaign_cursor")!=40 or entry.get("mission_kind")!=161 or entry.get("mission_story")!=true or entry.get("selected40")!=true or entry.get("world_type")!=3:
		return reject("Selected40 portal requires its selected normal-space mission")
	var retained: Variant=entry.get("source_before")
	if not retained is Dictionary or retained!=entry.get("source_after") or not entry.get("station_id") is int or not entry.get("system_id") is int or entry.station_id<0 or entry.system_id<0 or entry.station_id!=retained.get("source_station_id") or entry.system_id!=retained.get("source_system_id"):
		return reject("Selected40 portal must retain the actual old source before reroll")
	for key in ["base_content_id","binding_id"]:
		if entry.get(key)!=bindings.get(key) or retained.get(key)!=bindings.get(key):return reject("Selected40 portal changed source identity")
	var position: Array=Selected40.ENTRY_VALUES.portal_position
	var context:=entry.duplicate(true)
	context.environment_object={"resource_id":int(bindings.mido_travel.void_portal.portal.model_id),"position":Vector3(position[0],position[1],position[2])}
	if not _configure_accepted(bindings,context,library,{"scope":"selected40_source_portal_component","source_system_id":entry.system_id,"source_station_id":entry.station_id}):return false
	_selected40_generation=world.npc_construction_owner()
	return true

func _configure_accepted(bindings: RefCounted,entry: Dictionary,library: RefCounted,route: Dictionary) -> bool:
	for key in ["base_content_id","binding_id"]:
		if not Library.valid_hash(bindings.get(key)) or entry.get(key)!=bindings.get(key):return reject("Void portal belongs to another content identity")
	if not Frames.valid_parameters(bindings.frame_clock):return reject("Void portal requires the native frame clock")
	var rules: Dictionary=bindings.mido_travel.void_portal
	var environment: Variant=entry.get("environment_object")
	if not environment is Dictionary or environment.get("resource_id")!=int(rules.portal.model_id) or not environment.get("position") is Vector3 or not environment.position.is_finite():return reject("Void portal lacks its original environment slot")
	if library==null or library.manifest.get("content_id")!=bindings.base_content_id:return reject("Void portal requires its original animation resource")
	var path: String=bindings.resolve(int(rules.portal.model_id),"mesh")
	if path.is_empty():return reject(bindings.error)
	var reader:=AEM.new();var model: Dictionary=reader.decode(library.read_resource(path,AEM.MAX_BYTES))
	var timing:=Effects.playback_range(model.get("surfaces",[]))
	if timing.is_empty():return reject("Unsupported original Void portal animation")
	timing.time_ms=timing.start_ms;timing.playing=true
	var state:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"campaign_cursor":int(entry.campaign_cursor),"system_id":int(entry.system_id),"station_id":int(entry.station_id),
		"mission_kind":int(entry.mission_kind),"slot":int(rules.portal.environment_slot),"model_id":int(rules.portal.model_id),
		"position":environment.position,"pose":Transform3D(Basis.IDENTITY,environment.position),"animation":timing,
		"elapsed_ms":int(rules.portal.initial_elapsed_ms),"animation_elapsed_ms":0,
		"extent":int(rules.portal.initial_extent),"visible":true,"scale":1.0}
	state.merge(route)
	_rules=rules.duplicate(true);_probe=bindings.mido_travel.void_probe.duplicate(true) if entry.campaign_cursor==29 else {}
	_state=state;_contact={};_frame={};_entered=false
	_selected40_generation=null
	_context=null;_hold_open=null;_explicit_opening=false
	_identity=RefCounted.new()
	_max_ms=Frames.simulation_limit(bindings,150)
	return true

func advance(milliseconds: Variant,camera: Transform3D,random: RefCounted) -> bool:
	error=""
	if _state.is_empty() or not milliseconds is int or milliseconds<0 or milliseconds>_max_ms or not Flight.rigid_pose(camera):return reject("Void portal requires its accepted world frame")
	if not random is Random or random.snapshot().is_empty():return reject("Void portal requires the retained world random stream")
	if _state.animation_elapsed_ms>2147483647-milliseconds:return reject("Void portal animation exceeds its source time range")
	var relocation:={};var next_random: RefCounted=null
	# The already source-checked shared update explicitly clamps cursor40 in
	# normal space at close_start_ms while its constructor flag remains set.
	# Animation and facing still advance. This path never draws relocation RNG.
	var held_open: bool=_selected40_generation!=null if _hold_open==null else _hold_open
	if not held_open and _state.visible and _state.elapsed_ms+milliseconds>=int(_rules.portal.hide_at_ms):
		next_random=random.fork()
		var policy: Dictionary=_rules.portal.relocation
		var magnitude: int=int(policy.x_magnitude_offset)+next_random.next_int(int(policy.random_bounds[0]))
		var x: int=magnitude if next_random.next_int(int(policy.random_bounds[1]))==int(policy.x_positive_sign_draw) else -magnitude
		var y: int=int(policy.y_offset)+next_random.next_int(int(policy.random_bounds[2]))
		var z: int=int(policy.z_offset)+int(policy.z_draw_multiplier)*next_random.next_int(int(policy.random_bounds[3]))
		relocation={"position":Vector3(x,y,z),"elapsed_ms":int(policy.opening_elapsed_ms)}
	var next:=Portal.evaluate_clock(_state,_rules.portal,milliseconds,camera,relocation,held_open)
	if next.has("error"):return reject(next.error)
	# Explicit opening controls reach full extent at the opening boundary.
	# Legacy lifecycle callers retain their historical boundary-frame extent.
	if _explicit_opening and next.elapsed_ms>=0 and next.elapsed_ms<=int(_rules.portal.close_start_ms):
		next.extent=int(_rules.portal.extent_scale);next.scale=1.0
	if next_random!=null and not random.restore(next_random.snapshot()):return reject(random.error)
	_state=next
	if _explicit_opening and next.elapsed_ms>=0:_explicit_opening=false
	_frame={} if relocation.is_empty() else {"relocated":true,"cancel_autopilot":bool(_rules.portal.relocation.cancel_player_autopilot_on_relocation)}
	return true

func observe_contact(observation: Dictionary) -> bool:
	error=""
	if _state.is_empty() or not Flight.rigid_pose(observation.get("player_pose")):return reject("Void portal contact requires the player's physical pose")
	for key in ["environment_contact_enabled","mining_active"]:
		if not observation.get(key) is bool:return reject("Void portal contact lacks environment/mining admission")
	var admission:=1
	if _state.campaign_cursor==29:
		admission=Definitions.contact_admission(_probe,_state,observation.get("story_selection"))
		if admission<0:return reject("Void29 contact requires its retained story selection")
	var offset:=Vectors.added(observation.player_pose.origin,-_state.position)
	if not offset.is_finite():return reject("Void portal contact exceeds source coordinates")
	var contact:=Contact.evaluate(_rules.contact,int(_rules.portal.close_start_ms),{
		"environment_contact_enabled":observation.environment_contact_enabled,"mining_active":observation.mining_active,
		"portal_visible":_state.visible,"portal_elapsed_ms":int(_state.elapsed_ms),"player_offset":offset})
	if not contact.is_empty():
		contact.portal_position=_state.position;contact.player_offset=offset
		if contact.entry_contact and admission==0:contact.entry_contact=false
		elif contact.entry_contact:_entered=true
	_contact=contact
	return true

func transition_ready(current_hull: Variant) -> bool:return _entered and current_hull is int and current_hull>0
func selected40_construction_owner() -> RefCounted:return _selected40_generation
func portal_snapshot() -> Dictionary:return _state.duplicate(true)
func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"campaign_cursor":_state.campaign_cursor,
		"portal_entered":_entered,"frame":_frame.duplicate(true),"contact":_contact.duplicate(true)}
	for key in ["scope","ordinary_mode","source_system_id","source_station_id","return_system_id","return_station_id"]:
		if _state.has(key):result[key]=_state[key]
	return result
func clear_frame_cues() -> void:_frame={};_contact={}
func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._rules=_rules;copy._probe=_probe;copy._state=_state.duplicate(true);copy._frame=_frame.duplicate(true)
	copy._contact=_contact.duplicate(true);copy._entered=_entered;copy._max_ms=_max_ms
	copy._selected40_generation=_selected40_generation
	copy._context=_context;copy._hold_open=_hold_open;copy._explicit_opening=_explicit_opening
	copy._identity=_identity
	return copy
func reject(message: String) -> bool:error=message;return false
