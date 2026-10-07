extends RefCounted
const Frames=preload("res://src/simulation/frame_clock.gd")
var _max_ms:=0
## Mac starter destruction component. The flight owner supplies its physical
## motion before each player pass, then applies the returned camera, activity,
## particle and audio events in source order. No cargo or save is owned here.
const Definitions=preload("res://src/content/player_destruction_definitions.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Resources=preload("res://src/content/npc_destruction_resources.gd")
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Explosion=preload("res://src/simulation/type_zero_explosion.gd")
const Readonly=preload("res://src/simulation/readonly_state.gd")
var error:=""
var _rules:={}
var _state:={}
var _presentation_identity: RefCounted
# Immutable departure template shared by frame forks. The launcher remains
# the authority for any later removal of an exhausted ammunition stack.
var _departure_loadout: Dictionary={}
var _selected40_construction: RefCounted

func configure_mission(bindings: RefCounted,resources: RefCounted,catalogues: RefCounted,context: RefCounted,player: RefCounted,pose: Transform3D,camera_pose: Transform3D) -> bool:
	error=""
	if not _state.is_empty() or not bindings is Bindings or not resources is Resources or not player is Player or not is_instance_of(context,load("res://src/simulation/mission_context.gd")):return reject("Mission destruction requires fresh admitted native owners")
	if catalogues.content_id!=bindings.base_content_id or not context.matches_loadout(player.loadout()) or not Flight.rigid_pose(pose) or not Flight.rigid_pose(camera_pose):return reject("Mission destruction lost its admitted player or camera")
	var effect: Dictionary=resources.snapshot()
	for key in ["base_content_id","binding_id"]:
		if effect.get(key)!=bindings.get(key):return reject("Mission destruction resources belong to another source")
	var clock:=Explosion.create(effect,[],14292)
	if clock.is_empty():return reject("Mission destruction lacks its original explosion clocks")
	var rules: Dictionary=bindings.player_destruction.duplicate(true)
	rules.ship_id=context.ship_id();rules.departure_cursor=context.identity().campaign_cursor;rules.story_cursors=context.live_cursors()
	_commit_configuration(bindings,rules,clock,player.snapshot(),player.loadout(),pose,camera_pose)
	return true

## Explicit selected-source component, not a fabricated ordinary departure.
## Keep the actual origin inventory and the native constructor generation.
func configure_selected40(bindings: RefCounted,resources: RefCounted,catalogues: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,pose: Transform3D,camera_pose: Transform3D) -> bool:
	error=""
	if not _state.is_empty() or not bindings is Bindings or not resources is Resources or not player is Player or not Definitions.parameters(bindings.player_destruction):return reject("Selected40 destruction requires fresh verified native owners")
	var profile: Dictionary=load("res://src/content/selected40_population_definitions.gd").consequence_profile(bindings,catalogues,scenery,equipment)
	if profile.is_empty() or not Flight.rigid_pose(pose) or not Flight.rigid_pose(camera_pose):return reject("Selected40 destruction lost its native field, origin equipment or poses")
	var world: RefCounted=scenery.world_initialization_owner()
	var constructor: RefCounted=world.npc_construction_owner()
	var initial: Dictionary=player.snapshot();var loadout: Dictionary=equipment.snapshot().loadout.duplicate(true)
	loadout.campaign_cursor=40
	if player.selected40_construction_owner()!=constructor or initial.get("selected40_context")!=profile.context or player.loadout()!=loadout or initial.ship_id!=loadout.ship_id or initial.vitals.hull<=0:return reject("Selected40 destruction requires the living retained player from this exact constructor")
	for id in initial.equipment_ids:
		if not Numbers.integer(id,0,catalogues.tables.items.size()-1) or catalogues.tables.items[id].arrays[2][5]==27:return reject("Escape-device destruction is not yet supported")
	var effect: Dictionary=resources.snapshot()
	for key in ["base_content_id","binding_id"]:
		if effect.get(key)!=bindings.get(key):return reject("Selected40 destruction effects belong to another source")
	var clock:=Explosion.create(effect,[],14292)
	if clock.is_empty():return reject("Selected40 destruction lacks its original explosion clocks")
	var rules: Dictionary=bindings.player_destruction.duplicate(true)
	for index in 2:
		if clock.models[index].get("model_id")!=int(rules.model_ids[index]) or clock.models[index].get("resource")!=Resources.PATHS[index]:return reject("Selected40 destruction changed its original explosion models")
	rules.departure_cursor=40;rules.story_cursors=[40];rules.ship_id=int(loadout.ship_id)
	_commit_configuration(bindings,rules,clock,initial,loadout,pose,camera_pose)
	_selected40_construction=constructor
	return true

func selected40_construction_owner() -> RefCounted:return _selected40_construction

func configure(bindings: RefCounted, resources: RefCounted, construction: RefCounted,_catalogues: RefCounted=null) -> bool:
	error=""
	if not bindings is Bindings or not resources is Resources or not construction is Construction or not Definitions.parameters(bindings.player_destruction):return reject("Player destruction requires its verified Mac departure and effect resources")
	var rules: Dictionary=bindings.player_destruction.duplicate(true)
	var entry: Dictionary=construction.snapshot();var effect: Dictionary=resources.snapshot()
	for key in ["base_content_id","binding_id"]:
		if entry.get(key)!=bindings.get(key) or effect.get(key)!=bindings.get(key):return reject("Player destruction belongs to another content identity")
	var context: RefCounted=construction.flight_context_owner()
	if context==null or not context.matches_loadout(entry.departure.loadout) or not context.matches_location(bindings,entry.location):return reject("Player destruction lost its admitted flight")
	rules.ship_id=context.ship_id();rules.departure_cursor=context.identity().campaign_cursor;rules.story_cursors=context.live_cursors()
	var clock:=Explosion.create(effect,[],14292)
	if clock.is_empty():return reject("Player destruction lacks its authored explosion clocks")
	for index in 2:
		if clock.models[index].get("model_id")!=int(rules.model_ids[index]) or clock.models[index].get("resource")!=Resources.PATHS[index]:return reject("Player destruction changed its explosion model bindings")
	var initial: Dictionary=entry.get("player",{})
	if initial.get("campaign_cursor")!=int(rules.departure_cursor) or initial.get("ship_id")!=context.ship_id() or initial.get("equipment_ids")!=entry.departure.loadout.equipment_ids:return reject("Player destruction requires its admitted player")
	_commit_configuration(bindings,rules,clock,initial,entry.departure.loadout,entry.player_pose,entry.camera_view.pose)
	return true

func _commit_configuration(bindings: RefCounted,rules: Dictionary,clock: Dictionary,initial: Dictionary,loadout: Dictionary,pose: Transform3D,camera_pose: Transform3D) -> void:
	_rules=rules.duplicate(true)
	# Imported JSON numbers become floats; native story observations use ints.
	_rules.story_cursors=_rules.story_cursors.map(func(value):return int(value))
	_max_ms=Frames.simulation_limit(bindings,150)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"actor_id":"player",
		"departure_cursor":int(rules.departure_cursor),"campaign_cursor":int(rules.departure_cursor),
		"phase":"ready","elapsed_ms":0,"player_updates":0,"failure_elapsed_ms":0,"fade_elapsed_ms":0,
		"failed":false,"exit_requested":false,"fragments":[],"effect":clock,
		"physical_pose":pose,"statistics_pose":pose,"model_rotation":Vector3.ZERO,"rendered_model_basis":Basis.IDENTITY,
		"camera_pose":camera_pose,"camera_follow_enabled":true,"particle_emitting":false,"particle_drawing":true,
		"equipment_ids":initial.equipment_ids.duplicate(),"events":{}}
	_departure_loadout=loadout.duplicate(true)
	_presentation_identity=RefCounted.new()
	_selected40_construction=null

func start(player: RefCounted, physical_pose: Variant, model_rotation: Variant, camera_pose: Variant, campaign_cursor: Variant, rendered_model_basis: Variant=null, statistics_pose: Variant=null, secondaries: RefCounted=null) -> bool:
	error=""
	if _state.is_empty() or _state.phase!="ready" or not player is Player:return reject("Start player destruction once, after accepted lethal contact")
	if _selected40_construction!=null and player.selected40_construction_owner()!=_selected40_construction:return reject("Selected40 destruction rejected another native player generation")
	var current: Dictionary=player.snapshot()
	for key in ["base_content_id","binding_id"]:
		if current.get(key)!=_state[key]:return reject("Lethal player belongs to another departure")
	if current.get("campaign_cursor")!=_state.departure_cursor or current.get("ship_id")!=int(_rules.ship_id) or not _accepts_equipment(current.get("equipment_ids"),secondaries):return reject("Lethal player changed its supported loadout")
	if not Numbers.integer(current.get("vitals",{}).get("hull"),0,0):return reject("Player destruction requires exhausted hull")
	if not Flight.rigid_pose(physical_pose) or not Flight.rigid_pose(camera_pose) or not model_rotation is Vector3 or not model_rotation.is_finite():return reject("Player destruction requires finite source poses and Euler angles")
	if not campaign_cursor is int or not campaign_cursor in _rules.story_cursors:return reject("Unsupported player destruction story cursor")
	if (rendered_model_basis==null)!=(statistics_pose==null):return reject("Supply the retained visual basis and statistics pose together")
	if rendered_model_basis!=null:
		if not rendered_model_basis is Basis or not Flight.rigid_pose(Transform3D(rendered_model_basis,Vector3.ZERO)) or not Flight.rigid_pose(statistics_pose):return reject("Player destruction requires rigid retained visual and statistics poses")
	else:
		rendered_model_basis=Vectors.local_xyz(model_rotation)
		statistics_pose=physical_pose*Transform3D(rendered_model_basis,Vector3.ZERO)
	var next:=_state.duplicate(true)
	next.phase="tumble";next.physical_pose=physical_pose;next.model_rotation=model_rotation
	# Banking writes a matrix without updating the child's stored Euler angles.
	# Statistics may have sampled an earlier bank, or retained a mining pose.
	next.rendered_model_basis=rendered_model_basis;next.statistics_pose=statistics_pose
	next.camera_pose=camera_pose;next.campaign_cursor=campaign_cursor;next.particle_emitting=true
	next.camera_follow_enabled=false
	var stop_ids: Array[int]=[]
	for identifier in _rules.stop_sound_ids:stop_ids.append(int(identifier))
	next.events={"started":true,"breakup":false,"failed":false,"expired":false,
		"disable_camera_follow":true,"disable_statistics":true,"disable_engine_effects":true,
		"stop_current_engine_sound":true,"stop_current_music":true,"stop_sound_ids":stop_ids,
		"sound_events":[],"audio_events":[],"particle_events":[{"emitting":true}]}
	_state=next
	return true

func _accepts_equipment(equipment_ids: Variant,secondaries: RefCounted=null) -> bool:
	if equipment_ids==_state.equipment_ids:return true
	if not is_instance_of(secondaries,load("res://src/simulation/secondary_weapons.gd")):return false
	var retained: Dictionary=secondaries.reconcile_loadout(_departure_loadout)
	return not retained.is_empty() and equipment_ids==retained.equipment_ids

func player_updates_enabled() -> bool:
	return not _state.is_empty() and _state.phase!="ready" and not _state.exit_requested and _state.fade_elapsed_ms<int(_rules.fade_ms)

func advance(milliseconds: Variant, physical_pose: Variant, random_state: Variant, paused:=false, statistics_pose: Variant=null, player_tail:=true) -> Dictionary:
	error=""
	if _state.is_empty() or _state.phase=="ready" or not Numbers.integer(milliseconds,0,_max_ms) or not Flight.rigid_pose(physical_pose):return fail("Player destruction requires a started scene, finite physical pose and bounded frame")
	if statistics_pose!=null and not Flight.rigid_pose(statistics_pose):return fail("Player destruction requires a rigid statistics sample from flight")
	var random:=Random.new()
	if not random.restore(random_state):return fail(random.error)
	if paused or _state.exit_requested:return {"state":snapshot(),"random_state":random.snapshot(),"events":{}}
	var next:=_state.duplicate(true)
	var events:={"started":false,"breakup":false,"failed":false,"expired":false,"sound_events":[],"audio_events":[],"particle_events":[]}
	var was_failed: bool=next.failed
	if was_failed:
		if next.failure_elapsed_ms>2147483647-milliseconds or next.fade_elapsed_ms>2147483647-milliseconds:return fail("Player destruction clock exceeds supported range")
		next.failure_elapsed_ms+=milliseconds
	if player_updates_enabled() and player_tail:
		# Manual motion samples the preceding visual matrix. Guided motion may
		# overwrite that sample; mining may retain it. The flight owner supplies
		# those modes' statistics before this tail rebuilds the visual matrix.
		next.physical_pose=physical_pose
		next.statistics_pose=statistics_pose if statistics_pose!=null else physical_pose*Transform3D(next.rendered_model_basis,Vector3.ZERO)
		next.model_rotation=Vectors.added(next.model_rotation,Vector3.ONE*float(_rules.spin_per_update))
		next.rendered_model_basis=Vectors.local_xyz(next.model_rotation)
		next.player_updates+=1
		var old_ms: int=next.elapsed_ms
		if old_ms<int(_rules.breakup_ms) and old_ms+milliseconds>=int(_rules.breakup_ms):
			Explosion.trigger(next.effect,physical_pose.origin)
			events.breakup=true
			var sound:=int(_rules.breakup_sound_base)+random.next_int(int(_rules.breakup_sound_bound))
			events.sound_events.append(sound);events.audio_events.append({"source_id":sound,"position":physical_pose.origin})
			next.particle_emitting=false;next.particle_drawing=false
			events.particle_events.append({"emitting":false,"drawing":false,"impact_requested":true})
		elif old_ms>int(_rules.effect_update_after_ms):
			events.expired=Explosion.advance(next.effect,milliseconds)
		next.elapsed_ms+=milliseconds
	elif physical_pose!=next.physical_pose or (statistics_pose!=null and statistics_pose!=next.statistics_pose):
		return fail("A skipped player tail must retain physical and statistics poses")
	# The later mission poll repeats the emitter-enable call until failure is
	# set. On the breakup frame this follows the earlier disable/draw operations.
	if not was_failed:
		next.particle_emitting=true;events.particle_events.append({"emitting":true})
		if next.elapsed_ms>int(_rules.failure_after_ms):
			next.failed=true;next.failure_elapsed_ms=0;next.fade_elapsed_ms=0;events.failed=true
			events.sound_events.append(int(_rules.failure_sound))
			events.audio_events.append({"source_id":int(_rules.failure_sound),"position":null})
	elif next.failure_elapsed_ms>int(_rules.failure_delay_ms):
		next.fade_elapsed_ms+=milliseconds
	if not next.model_rotation.is_finite() or not Flight.rigid_pose(next.statistics_pose) or not Flight.rigid_pose(Transform3D(next.rendered_model_basis,Vector3.ZERO)):return fail("Player destruction exceeded source coordinate precision")
	next.phase="explosion" if next.elapsed_ms>=int(_rules.breakup_ms) else "tumble"
	if next.failed:
		next.phase="game_over_delay" if next.failure_elapsed_ms<=int(_rules.failure_delay_ms) else "game_over_fade"
		if next.fade_elapsed_ms>=int(_rules.fade_ms):next.phase="game_over"
	next.events=events
	_state=next
	return {"state":snapshot(),"random_state":random.snapshot(),"events":events.duplicate(true)}

func request_exit() -> Dictionary:
	error=""
	if _state.get("phase")!="game_over" or _state.exit_requested:return fail("Game-over exit requires a new acknowledgement after the fade")
	_state.exit_requested=true
	return {"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,
		"source_state":int(_rules.continue_source_state),"campaign_cursor":_state.campaign_cursor}

func sample_camera(pose: Variant, follow_enabled: Variant) -> bool:
	error=""
	if _state.is_empty() or _state.phase=="ready" or _state.exit_requested or not Flight.rigid_pose(pose) or not follow_enabled is bool:return reject("Death camera sampling requires its active flight's proper view")
	# Death disables follow once. A later mining release can re-enable it;
	# camera updates occur after the player tail and continue after fade end.
	_state.camera_pose=pose;_state.camera_follow_enabled=follow_enabled
	return true

func phase() -> String:return "" if _state.is_empty() else String(_state.phase)

func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate(true)
	result.body_visible=result.phase=="ready" or result.elapsed_ms<int(_rules.breakup_ms)
	result.body_pose=result.physical_pose*Transform3D(result.rendered_model_basis,Vector3.ZERO)
	result.hud_visible=result.phase=="ready"
	result.statistics_active=result.phase=="ready"
	result.player_updates_enabled=player_updates_enabled()
	result.game_over_visible=result.failed and result.failure_elapsed_ms>int(_rules.failure_delay_ms)
	result.continue_enabled=result.phase=="game_over" and not result.exit_requested
	result.game_over_alpha_byte=mini(255,int(Vitals.single(Vitals.single(float(result.fade_elapsed_ms)/float(_rules.fade_ms))*255.0)))
	return result

## A story flight's death owner also covers the cursor its silent advance reaches.
func covers_cursor(cursor: int) -> bool:return not _state.is_empty() and (cursor==int(_state.departure_cursor) or cursor in _rules.get("story_cursors",[]))

func presentation_identity() -> RefCounted:return _presentation_identity

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	# Rules are immutable after configuration: freeze once, then share them.
	copy._rules=Readonly.freeze(_rules);copy._state=_state.duplicate(true);copy._presentation_identity=_presentation_identity
	copy._departure_loadout=_departure_loadout
	copy._selected40_construction=_selected40_construction
	copy._max_ms=_max_ms;return copy

func clear() -> void:_max_ms=0;error="";_rules={};_state={};_presentation_identity=null;_departure_loadout={};_selected40_construction=null
func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
