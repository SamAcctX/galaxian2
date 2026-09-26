extends RefCounted
## Native camera/aim consumer, attached to the same selected source generation.
## It consumes current player and pre-NPC poses; it never moves a player, invents
## a result or cancels equipment actions. The geometry manager consumes the
## retained immediate-refresh reference separately from ordinary camera motion.
## Auxiliary-camera cancellation is consumed here before a cinematic setter.
const Rules=preload("res://src/content/selected40_population_definitions.gd")
const Sequence=preload("res://src/simulation/selected40_sequence.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Rig=preload("res://src/simulation/camera_rig.gd")
const Aim=preload("res://src/simulation/opening_aim.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const ORBIT_SCALE=-0.005
const ORBIT_INITIAL_UNITS=Vector2(25,-50)
const ORBIT_DAMPING=0.9
var error:=""
var _world: RefCounted
var _camera: RefCounted
var _aim: RefCounted
var _state:={}
var _shot:={}
var _max_ms:=0

func configure(bindings: RefCounted,world: RefCounted,camera: RefCounted,aim: RefCounted,player: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or not is_instance_of(world,load("res://src/simulation/opening_world_initialization.gd")) or not camera is Rig or not aim is Aim or not player is Player:return reject("Selected40 view requires fresh native owners")
	if not Rules.context_valid(bindings,world.snapshot().get("selected40_context",{})) or world.npc_construction_owner()==null or player.selected40_construction_owner()!=world.npc_construction_owner():return reject("Selected40 view changed its retained player or source generation")
	var view: Dictionary=camera.snapshot();var reticle: Dictionary=aim.snapshot()
	for key in ["base_content_id","binding_id"]:
		if view.get(key)!=bindings.get(key) or reticle.get(key)!=bindings.get(key):return reject("Selected40 view lost its preceding camera/aim identity")
	if not Flight.rigid_pose(view.get("pose")):return reject("Selected40 view requires an established renderer camera")
	_world=world;_camera=camera.fork_for_frame();_aim=aim.fork_for_frame();_max_ms=Frames.simulation_limit(bindings)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"scope":"selected40_camera_aim_component","revision":0,"elapsed_ms":0,"input_blocked":false,"hud_visible":true,
		"camera_mode":0,"orbit_input":{"units":ORBIT_INITIAL_UNITS,"pointer":Vector2i.ZERO,"last_delta":Vector2i.ZERO,"velocity":Vector2.ZERO,"damping":Vector2.ZERO,"dragging":false},
		"player_render_suppressed":camera.auxiliary_snapshot().transition_pending,"detail_refresh_reference":null}
	_shot={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"follow","target":"player","actor_id":-1,"inherit_target_up":true,"eye":view.eye}
	return true

## Normal selection retains input and radius. The separate source player
## event's -98/35/3800 preset is NOT an ordinary view-control default. Mac
## requests for mode2 normalize to3; no auxiliary/device action is admitted.
func prepare_application_entry() -> bool:
	if _state.is_empty() or _state.revision!=0 or _shot.mode!="follow":return reject("Prepare the fixed entry camera before its first native frame")
	_shot.mode="fixed_eye";_state.input_blocked=true;_state.hud_visible=false
	return true

## The application changes capture policy independently of orbit. Reuse the
## shared source response coefficients without replacing the preceding pose.
func refresh_player_response(relative_capture: bool,handling: float) -> bool:
	error=""
	if _state.is_empty():return reject("Configure selected40 view before refreshing player response")
	var camera: RefCounted=_camera.fork_for_frame()
	var before: Dictionary=camera.response_snapshot()
	if before.relative_capture!=relative_capture or before.player_handling!=Rig.single(handling):camera.mark_response_dirty()
	if not camera.refresh_player_response(relative_capture,handling):return reject(camera.error)
	_camera=camera
	return true

func select_camera(mode: Variant) -> bool:
	error=""
	if _state.is_empty() or not mode is int or mode not in [0,2,3] or _state.input_blocked or _shot.mode!="follow":return reject("Camera selection requires released native follow/orbit flight")
	if mode==2:mode=3
	var camera: RefCounted=_camera.fork_for_frame();var next:=_state.duplicate(true)
	if not camera.set_auxiliary_enabled(false) or not camera.set_orbit_enabled(mode==3):return reject(camera.error)
	next.camera_mode=mode;next.player_render_suppressed=camera.auxiliary_snapshot().transition_pending
	_state=next;_camera=camera
	return true

## Single-pointer source input, independent of flight steering. Release uses
## the last integer delta once more, even below the inertia threshold. The
## original multi-pointer zoom/device paths are not admitted by this API.
func orbit_pointer(kind: String,position: Variant=Vector2i.ZERO) -> bool:
	error=""
	if _state.is_empty() or _state.camera_mode!=3 or _state.input_blocked or not position is Vector2i or kind not in ["press","move","release"]:return reject("Orbit pointer requires released mode3 and native integer coordinates")
	var input: Dictionary=_state.orbit_input.duplicate(true)
	if (kind=="press")==bool(input.dragging):return reject("Orbit pointer event does not match its retained drag")
	match kind:
		"press":input.pointer=position;input.last_delta=Vector2i.ZERO;input.dragging=true
		"move":
			var dx: int=int(position.x)-int(input.pointer.x);var dy: int=int(position.y)-int(input.pointer.y)
			if dx< -2147483648 or dx>2147483647 or dy< -2147483648 or dy>2147483647:return reject("Orbit pointer displacement exceeds its source integer range")
			input.last_delta=Vector2i(dx,dy);input.pointer=position;input.damping=Vector2.ONE
			input.units+=Vector2(input.last_delta)
		"release":
			input.velocity=Vector2(input.last_delta.x if absi(input.last_delta.x)>=4 else 0,input.last_delta.y if absi(input.last_delta.y)>=4 else 0)
			input.units+=Vector2(input.last_delta);input.damping=Vector2.ONE*Rig.single(ORBIT_DAMPING);input.dragging=false
	if not input.units.is_finite():return reject("Orbit pointer accumulation overflowed")
	_state.orbit_input=input
	return true

static func _orbit_angles(units: Vector2) -> Vector3:
	return Vector3(units.y*Rig.single(ORBIT_SCALE),units.x*Rig.single(ORBIT_SCALE),0)

func advance(sequence: RefCounted,combat: RefCounted,player: RefCounted,pose: Transform3D,milliseconds: Variant,viewport: Vector2i,npc_contact: bool,look_jitter:=Vector3.ZERO,destruction: RefCounted=null,player_updated:=true,aim_pose: Variant=null) -> bool:
	error=""
	if _state.is_empty() or not sequence is Sequence or not combat is Combat or not player is Player or not Flight.rigid_pose(pose) or not Rules.Numbers.integer(milliseconds,0,_max_ms):return reject("Invalid selected40 camera/aim frame")
	if aim_pose!=null and not Flight.rigid_pose(aim_pose):return reject("Selected40 aim requires its pre-contact native pose")
	for world in [sequence.world_owner(),combat.selected40_world_owner()]:
		if world==null or world.npc_construction_owner()!=_world.npc_construction_owner() or world.snapshot()!=_world.snapshot():return reject("Selected40 view cannot consume an independently regenerated cast")
	if player.selected40_construction_owner()!=_world.npc_construction_owner():return reject("Selected40 view requires its retained native player")
	var cue: Dictionary=sequence.snapshot()
	if cue.revision!=_state.revision+1 or cue.elapsed_ms!=_state.elapsed_ms+int(milliseconds):return reject("Selected40 view must consume each native sequence revision exactly once")
	if destruction!=null:
		if not is_instance_of(destruction,load("res://src/simulation/player_destruction.gd")) or destruction.selected40_construction_owner()!=_world.npc_construction_owner() or destruction.snapshot().get("phase")=="ready" or not cue.get("player_destroyed",false) or player.snapshot().vitals.hull!=0 or look_jitter!=Vector3.ZERO:return reject("Selected40 death camera requires its actual destruction and disabled follow pass")
	elif not player_updated or cue.get("player_destroyed",false):return reject("Only native player destruction can suspend this view")
	var actors:=[]
	for actor in combat.actor_snapshots():
		if not Flight.rigid_pose(actor.get("body_pose")):return reject("Selected40 view lost a physical actor pose")
		actors.append({"actor_id":actor.actor_id,"pose":actor.body_pose})
	var scene:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"player_pose":pose,"actors":actors}
	var camera: RefCounted=_camera.fork_for_frame();var aim: RefCounted=_aim.fork_for_frame();var shot:=_shot.duplicate(true)
	var next:=_state.duplicate(true)
	# The player pass projects aim against the PRECEDING renderer view. The
	# current camera and late input consume the sequence only afterward.
	if player_updated and not aim.advance(pose if aim_pose==null else aim_pose,_camera.snapshot().pose,viewport):return reject(aim.error)
	if destruction!=null:
		if not aim.sample_feedback(npc_contact,milliseconds,false):return reject(aim.error)
		next.detail_refresh_reference=null;next.orbit_input.dragging=false
		for key in ["revision","elapsed_ms","input_blocked","hud_visible"]:next[key]=cue[key]
		_state=next;_aim=aim
		return true
	if cue.frame.reset_follow and not camera.set_auxiliary_enabled(false):return reject(camera.error)
	if cue.frame.cancel_actions:next.orbit_input.dragging=false
	for operation in cue.frame.camera_operations:
		match operation.kind:
			"freighter_view":
				shot.mode="fixed_eye";shot.eye=operation.position
				# Source eye translation immediately refreshes the old target;
				# setting the new target itself does not update the view matrix.
				if not camera.update(0,shot,scene,shot):return reject(camera.error)
				shot.target="actor";shot.actor_id=0
			"translate":
				shot.eye=Vectors.added(shot.eye,operation.offset)
				if not camera.update(0,shot,scene,shot):return reject(camera.error)
			"follow_player":
				shot.mode="follow";shot.target="player";shot.actor_id=-1
			_:
				return reject("Unknown selected40 camera operation")
	# The cinematic call is the existing geometry-detail manager, not a star
	# emitter. It samples the immediately translated renderer eye before the
	# late ordinary camera update and consumes no simulation time or RNG.
	next.detail_refresh_reference=camera.snapshot().eye if cue.frame.refresh_geometry_detail else null
	if next.camera_mode==3:
		var input: Dictionary=next.orbit_input
		if not input.dragging:
			input.velocity*=input.damping
			for axis in 2:
				if absf(input.velocity[axis])>1.0:input.units[axis]=Rig.single(input.units[axis]+input.velocity[axis])
			input.units.y=clampf(input.units.y,-200,200)
		if not camera.set_orbit_parameters(_orbit_angles(input.units),camera.orbit_snapshot().distance):return reject(camera.error)
	if not camera.update(milliseconds,shot,scene,{},null,look_jitter):return reject(camera.error)
	if not aim.sample_feedback(npc_contact,milliseconds,cue.hud_visible):return reject(aim.error)
	# Source normal0/mode3 clear the explicit hide flag. The camera's live
	# transition latch is still sampled AFTER each update, never once at entry.
	# The retained living player has both original base draw flags enabled.
	next.player_render_suppressed=camera.auxiliary_snapshot().transition_pending
	for key in ["revision","elapsed_ms","input_blocked","hud_visible"]:next[key]=cue[key]
	_state=next;_camera=camera;_aim=aim;_shot=shot
	return true

func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate(true)
	result.camera=_camera.snapshot();result.player_aim=_aim.snapshot();result.shot=_shot.duplicate(true)
	result.camera_response=_camera.response_snapshot()
	result.auxiliary_camera=_camera.auxiliary_snapshot()
	result.orbit_camera=_camera.orbit_snapshot()
	return result

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._world=_world;copy._max_ms=_max_ms;copy._state=_state.duplicate(true);copy._shot=_shot.duplicate(true)
	copy._camera=null if _camera==null else _camera.fork_for_frame();copy._aim=null if _aim==null else _aim.fork_for_frame()
	return copy

func reject(message: String) -> bool:error=message;return false
