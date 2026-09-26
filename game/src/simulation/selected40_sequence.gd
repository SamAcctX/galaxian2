extends RefCounted
## A native encounter sequence over the retained thirteen-actor world. Radio
## runs first; commands are committed by the shared combat controller. No save,
## reward, destination or campaign successor can be produced by this owner.
const Rules=preload("res://src/content/selected40_population_definitions.gd")
const Radio=preload("res://src/simulation/radio_sequence.gd")
const Resources=preload("res://src/presentation/opening_radio_resources.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
enum Stage { WAITING, FREIGHTER_VIEW, ESCORT, REINFORCEMENTS, PORTAL_ESCAPE, ESCAPED }
var error:=""
var _world: RefCounted
var _radio: RefCounted
var _state:={}
var _max_ms:=0

func configure(bindings: RefCounted,library: RefCounted,world: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or not is_instance_of(world,load("res://src/simulation/opening_world_initialization.gd")):return reject("Selected40 sequence needs a fresh native world owner")
	var packet: Dictionary=world.snapshot()
	if not Rules.context_valid(bindings,packet.get("selected40_context",{})) or world.npc_construction_owner()==null:return reject("Selected40 sequence lacks its generated source context")
	var resources:=Resources.new();var radio:=Radio.new()
	if not resources.prepare(library,bindings,null,40) or not radio.configure(bindings,library,resources.line_counts,40):return reject(resources.error+radio.error)
	_world=world;_radio=radio;_max_ms=Frames.simulation_limit(bindings)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":40,"phase":Stage.WAITING,"elapsed_ms":0,"revision":0,"input_blocked":false,"hud_visible":true,"failure_observed":false,"frame":{},"radio_events":[]}
	return true

func prepare_application_entry(release_ms: int) -> bool:
	if _state.is_empty() or _state.revision!=0 or _state.has("entry_released") or release_ms!=7001:return reject("Prepare the native entry controller once before flight time")
	_state.entry_released=false;_state.entry_elapsed_ms=0;_state.entry_release_ms=release_ms
	_state.input_blocked=true;_state.hud_visible=false
	return true

func advance(milliseconds: Variant,combat: RefCounted,random_state: Dictionary,destruction: RefCounted=null) -> bool:
	error=""
	if _state.is_empty() or not Rules.Numbers.integer(milliseconds,0,_max_ms) or not combat is Combat:return reject("Invalid selected40 sequence frame")
	var world: RefCounted=combat.selected40_world_owner()
	if world==null or world.npc_construction_owner()!=_world.npc_construction_owner() or world.snapshot()!=_world.snapshot():return reject("Selected40 sequence changed its actual constructor generation")
	if destruction!=null:
		if not is_instance_of(destruction,load("res://src/simulation/player_destruction.gd")) or destruction.selected40_construction_owner()!=_world.npc_construction_owner() or destruction.snapshot().get("phase")=="ready":return reject("Selected40 death gating requires its actual started player destruction owner")
	elif _state.get("player_destroyed",false):return reject("Selected40 choreography cannot resurrect a destroyed player")
	var actors: Array=combat.actor_snapshots()
	if actors.size()!=int(Rules.VALUES.actor_count):return reject("Selected40 sequence lost an original actor")
	for id in actors.size():
		if actors[id].get("actor_id")!=id or not Flight.rigid_pose(actors[id].get("body_pose")):return reject("Selected40 sequence actor pose is unavailable")
	var random:=Random.new()
	if not random.restore(random_state):return reject(random.error)
	var radio: RefCounted=_radio.fork_for_frame();var next:=_state.duplicate(true)
	next.elapsed_ms+=int(milliseconds);next.revision+=1
	var events: Array=radio.step_selected40(next.elapsed_ms,combat)
	if not radio.error.is_empty():return reject(radio.error)
	var frame:={"actor_commands":{},"camera_operations":[],"cancel_actions":false,"reset_follow":false,"refresh_geometry_detail":false,"input_random_state":random_state.duplicate(true)}
	if destruction!=null:
		# The late death poll gates mission choreography and follow-camera work,
		# not the independent radio/world clock or the later NPC pass.
		next.input_blocked=true;next.hud_visible=false;next.player_destroyed=true
		frame.random_state=random.snapshot();next.frame=frame;next.radio_events=events
		_state=next;_radio=radio
		return true
	var freight: Dictionary=actors[0];var pose: Transform3D=freight.body_pose
	if next.has("entry_released") and not next.entry_released:
		next.entry_elapsed_ms+=int(milliseconds)
		frame.refresh_geometry_detail=true
		if next.entry_elapsed_ms>=next.entry_release_ms:
			next.entry_elapsed_ms=0;next.entry_released=true
			next.input_blocked=false;next.hud_visible=true
			frame.entry_released=true
			frame.camera_operations.append({"kind":"follow_player"})
	var tuning: Dictionary=Rules.SEQUENCE
	match int(_state.phase):
		Stage.WAITING:
			if radio.event_state(int(tuning.reveal_started_event)).get("condition_satisfied")==true:
				var position:=vector(Rules.VALUES.patrol_points[0])
				frame.actor_commands[0]={"action":"reveal","position":position}
				frame.camera_operations=[{"kind":"freighter_view","actor_id":0,"position":position+vector(tuning.camera_offset)}]
				frame.cancel_actions=true;frame.reset_follow=true;frame.refresh_geometry_detail=true
				next.input_blocked=true;next.hud_visible=false;next.phase=Stage.FREIGHTER_VIEW
		Stage.FREIGHTER_VIEW:
			frame.camera_operations=[{"kind":"translate","offset":Vector3(0,0,int(milliseconds)*int(tuning.camera_z_per_ms))}]
			if radio.event_state(int(tuning.restore_finished_event)).get("playback_finished")==true:
				frame.camera_operations.append({"kind":"follow_player"})
				next.input_blocked=false;next.hud_visible=true;next.phase=Stage.ESCORT
		Stage.ESCORT:
			if pose.origin.z>=float(tuning.reserve_at_z):
				for id in range(int(Rules.VALUES.reserve_first),actors.size()):
					var position:=vector(Rules.ENTRY_VALUES.portal_position)
					for axis in 3:position[axis]=Vitals.single(Vitals.single(position[axis]+float(tuning.reserve_jitter_offset))+float(random.next_int(int(tuning.reserve_jitter_bound))))
					frame.actor_commands[id]={"action":"reserve","position":position}
				next.phase=Stage.REINFORCEMENTS
		Stage.REINFORCEMENTS:
			if pose.origin.z>=float(Rules.ENTRY_VALUES.portal_position[2]):next.phase=Stage.PORTAL_ESCAPE
		Stage.PORTAL_ESCAPE:
			# This source helper adds an integer forward displacement; it does
			# not set world Z or consume another ordinary cruise tick.
			var extra:=int(Vitals.single(Vitals.single(pose.origin.z-float(tuning.escape_origin_z))-float(milliseconds)))
			var moved:=Vectors.added(pose.origin,Vectors.scaled(Vectors.normalized(pose.basis.z),float(extra)))
			var retired:=moved.z>float(tuning.retire_above_z)
			frame.actor_commands[0]={"action":"escape","forward_units":extra,"retire":retired,"retired_position":vector(tuning.retired_position)}
			if retired:next.phase=Stage.ESCAPED
	# Source failure is completed breakup mode4, not the first lethal contact.
	# The enclosing result/modal owner must consume this before awarding anything.
	next.failure_observed=int(freight.actor_mode)==int(Rules.VALUES.destroyed_mode)
	frame.random_state=random.snapshot();next.frame=frame;next.radio_events=events
	_state=next;_radio=radio
	return true

func world_owner() -> RefCounted:return _world
func radio_owner() -> RefCounted:return null if _radio==null else _radio.fork_for_frame()
func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var value:=_state.duplicate(true);value.radio=_radio.snapshot()
	return value

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._world=_world;copy._radio=null if _radio==null else _radio.fork_for_frame();copy._state=_state.duplicate(true);copy._max_ms=_max_ms
	return copy

static func vector(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
func reject(message: String) -> bool:error=message;return false
