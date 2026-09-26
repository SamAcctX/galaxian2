extends RefCounted
## Native cinematic hook over an already initialized generation. The parent
## result poll precedes this hook; radio follows contacts, then choreography,
## ordinary NPC motion and the late camera. Completion never grants a result.
const World=preload("res://src/simulation/selected41_world_initialization.gd")
const Radio=preload("res://src/simulation/radio_sequence.gd")
const Rules=preload("res://src/content/selected41_population_definitions.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
var error:=""
var _world: RefCounted
var _state:={}
var _camera: RefCounted
var _shot:={}
var _max_ms:=0

func configure(bindings: RefCounted,world: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or not world is World or world.snapshot().is_empty():return reject("Source41 sequence requires one initialized native world")
	var view: RefCounted=world.camera_owner()
	if view==null or not Flight.rigid_pose(view.snapshot().get("pose")):return reject("Source41 sequence lost its retained arrival camera")
	for key in ["base_content_id","binding_id"]:
		if view.snapshot().get(key)!=bindings.get(key):return reject("Source41 camera identity changed")
	_world=world;_camera=view;_max_ms=Frames.simulation_limit(bindings)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":41,
		"phase":0,"revision":0,"view_revision":0,"frame_milliseconds":0,"elapsed_ms":0,"input_blocked":false,"hud_visible":true,
		"phase_elapsed_ms":0,"sequence_complete":false,"player_damage_allowed":true,"effects_enabled":[],
		"frame":empty_frame(),"complete_cinematic_supported":true}
	_shot={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye",
		"target":"actor","actor_id":0,"inherit_target_up":true,"eye":view.snapshot().eye}
	return true

func advance(milliseconds: Variant,radio: RefCounted,combat: RefCounted,player_pose: Transform3D) -> bool:
	error=""
	if _state.is_empty() or not Rules.Numbers.integer(milliseconds,0,_max_ms) or not Flight.rigid_pose(player_pose) or not radio is Radio:return reject("Invalid source41 choreography frame")
	if not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")) or combat.selected41_world_owner()!=_world:return reject("Source41 choreography cannot replace its initialized bodies")
	var speech: Dictionary=radio.snapshot()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if speech.get(key)!=_state[key]:return reject("Source41 choreography received unrelated radio")
	if _state.elapsed_ms>2147483647-milliseconds:return reject("Source41 sequence clock overflow")
	if _state.view_revision!=_state.revision:return reject("Source41 preceding frame has no completed late camera")
	var next:=_state.duplicate(true);var shot:=_shot.duplicate(true)
	next.revision+=1;next.elapsed_ms+=milliseconds;next.frame_milliseconds=milliseconds
	next.frame=empty_frame()
	var actors: Array=combat.actor_snapshots()
	if actors.size()!=8:return reject("Source41 sequence requires all eight original bodies")
	for id in actors.size():
		if actors[id].get("actor_id")!=id or not Flight.rigid_pose(actors[id].get("body_pose")):return reject("Source41 choreography lost an actor pose")
	var scene:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"player_pose":player_pose,
		"actors":actors.map(func(row):return {"actor_id":row.actor_id,"pose":row.body_pose})}
	var camera: RefCounted=_camera.fork_for_frame()
	if next.phase==0 and radio.event_state(4).condition_satisfied:
		var origin: Vector3=actors[0].body_pose.origin
		for id in range(1,4):
			var values: Array=Rules.ATTACK_OFFSETS[id-1];var offset:=Vector3(values[0],values[1],values[2])
			# Absolute placement copies the PREVIOUS root orientation to stats.
			# Relative movement and the following aim setter affect the root.
			var statistics: Transform3D=actors[id].body_pose;statistics.origin=origin
			var forward:=Vectors.normalized(-offset)
			var right:=Vectors.normalized(Vectors.cross(Vector3.UP,forward))
			var up:=Vectors.normalized(Vectors.cross(forward,right))
			var physical:=Transform3D(Basis(right,up,forward),Vectors.added(origin,offset))
			next.frame.reset_fighters.append({"actor_id":id,"statistics_pose":statistics,"body_pose":physical,"target_actor_id":0})
		var delta: Array=Rules.ATTACK_CAMERA_OFFSET
		shot.eye=Vectors.added(origin,Vector3(delta[0],delta[1],delta[2]))
		# Unlike selected40, source41 assigns the freighter target BEFORE
		# its absolute-eye and relative-eye setters refresh the renderer.
		if not camera.set_auxiliary_enabled(false) or not camera.set_orbit_enabled(false) or not camera.update(0,shot,scene,shot):return reject(camera.error)
		next.phase=1;next.input_blocked=true;next.hud_visible=false;next.frame.cancel_actions=true
		next.player_damage_allowed=false
		next.frame.input_actions=[{"action":"cancel_player_actions"},{"action":"set_player_control","enabled":false}]
	elif _state.phase==1 and radio.event_state(5).condition_satisfied:
		next.phase=2;next.phase_elapsed_ms=0
		next.effects_enabled=[40,41]
		for effect in next.effects_enabled:next.frame.effects.append({"action":"set_enabled","actor_id":0,"effect_type":effect,"enabled":true})
		next.frame.actor_actions=[{"action":"set_hull","actor_id":0,"hull":9999999},
			{"action":"set_freighter_motion","actor_id":0,"cruise_enabled":false}]
		next.frame.audio=[{"action":"play","sound_id":155},{"action":"stop_actor_engine","actor_id":0}]
		shot.eye=actors[0].body_pose.origin+Vector3(-3000,-2000,12000)
		if not camera.set_orbit_enabled(false) or not camera.update(0,shot,scene,shot):return reject(camera.error)
	elif _state.phase==2:
		next.phase_elapsed_ms+=milliseconds
		var pose: Transform3D=actors[0].body_pose
		pose.origin+=Vector3(0,-milliseconds,2*milliseconds)
		pose.basis=(pose.basis*Vectors.local_xyz(Vector3(0,0,0.00003*milliseconds))).orthonormalized()
		next.frame.actor_actions=[{"action":"set_freighter_motion","actor_id":0,"pose":pose}]
		if next.phase_elapsed_ms>15000:next.phase=3
	elif _state.phase==3:
		var pose:=Transform3D(Vectors.local_xyz(Vector3(-0.4,0,1.8)),Vector3(2006,-31500,-86720))
		next.frame.actor_actions=[{"action":"set_freighter_motion","actor_id":0,"pose":pose},
			{"action":"set_engine_draw","actor_id":0,"enabled":false}]
		for id in range(1,actors.size()):
			if actors[id].actor_kind==9:next.frame.actor_actions.append({"action":"retarget_player","actor_id":id})
		shot.eye=pose.origin+Vector3(3000,1000,2000);shot.inherit_target_up=false
		scene.actors[0].pose=pose
		if not camera.update(0,shot,scene,shot):return reject(camera.error)
		next.phase=4;next.phase_elapsed_ms=0
	elif _state.phase==4:
		next.phase_elapsed_ms+=milliseconds
		shot.eye+=Vector3(milliseconds,milliseconds,-2*milliseconds)
		if not camera.update(0,shot,scene,shot):return reject(camera.error)
		if next.phase_elapsed_ms>15000:
			next.frame.actor_actions=[{"action":"set_hull","actor_id":0,"hull":100},
				{"action":"set_freighter_motion","actor_id":0,"speed":0.0}]
			next.frame.audio=[{"action":"stop","sound_id":156}]
			next.frame.input_actions=[{"action":"set_player_control","enabled":true}]
			next.frame.restore_control=true;next.frame.refresh_geometry_detail=true
			next.phase=5;next.sequence_complete=true;next.input_blocked=false;next.hud_visible=true;next.player_damage_allowed=true
			shot={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"mode":"follow","target":"player"}
	if next.phase!=_state.phase:
		next.frame.camera_actions=[{"action":"select_shot","shot":shot.duplicate(true)}]
		next.frame.phase_changed={"from":_state.phase,"to":next.phase}
	_state=next;_camera=camera;_shot=shot
	return true

static func empty_frame() -> Dictionary:
	return {"reset_fighters":[],"actor_actions":[],"effects":[],"audio":[],"input_actions":[],"camera_actions":[],
		"cancel_actions":false,"restore_control":false,"refresh_geometry_detail":false}

## Cinematic eye setters refresh immediately before NPCs. The ordinary camera
## update then follows their CURRENT physical target, not last frame's pose.
func finish_camera(milliseconds: Variant,combat: RefCounted,player_pose: Transform3D) -> bool:
	error=""
	if _state.is_empty() or _state.view_revision+1!=_state.revision or milliseconds!=_state.frame_milliseconds or not Flight.rigid_pose(player_pose):return reject("Source41 camera must finish its staged frame exactly once")
	if not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")) or combat.selected41_world_owner()!=_world:return reject("Source41 late camera lost its native generation")
	var actors: Array=combat.actor_snapshots()
	var scene:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"player_pose":player_pose,
		"actors":actors.map(func(row):return {"actor_id":row.actor_id,"pose":row.body_pose})}
	var camera: RefCounted=_camera.fork_for_frame()
	if _state.phase>0 and not camera.update(milliseconds,_shot,scene):return reject(camera.error)
	_camera=camera;_state.view_revision=_state.revision
	return true

func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate(true);result.camera=_camera.snapshot();result.shot=_shot.duplicate(true)
	return result
func world_owner() -> RefCounted:return _world
func result_flags() -> Dictionary:return {"sequence_complete":not _state.is_empty() and _state.sequence_complete}
func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._world=_world;copy._state=_state.duplicate(true);copy._shot=_shot.duplicate(true);copy._max_ms=_max_ms
	copy._camera=null if _camera==null else _camera.fork_for_frame()
	return copy
func reject(message: String) -> bool:error=message;return false
