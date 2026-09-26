extends RefCounted
## Late ordinary camera construction, after scenery/cast/equipment allocation.
## A fixed entry eye is transformed from the retained player root. This owner
## never seeds the world stream, constructs a player, or authorizes a journey.
const Rig=preload("res://src/simulation/camera_rig.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Pose=preload("res://src/simulation/npc_flight.gd")
const Definitions=preload("res://src/content/first_flight_definitions.gd")
const ARRIVAL_AXIS_BOUND=500
const ARRIVAL_Z=7000
var error:=""
var _state:={}
var _camera: RefCounted

func configure(bindings: RefCounted,pose: Transform3D,random_state: Dictionary,special_placement: bool=false) -> bool:
	error=""
	if not _state.is_empty() or bindings==null or not Pose.rigid_pose(pose):return reject("Camera construction requires a fresh owner and retained proper player pose")
	var random:=Random.new()
	if not random.restore(random_state):return reject(random.error)
	var bound: int=ARRIVAL_AXIS_BOUND if special_placement else int(Definitions.VALUES.camera_axis_bound)
	var offset:=Vector3.ZERO
	for axis in 2:offset[axis]=int(Definitions.VALUES.camera_axis_base)+random.next_int(bound)
	offset.z=ARRIVAL_Z if special_placement else int(Definitions.VALUES.camera_z)
	for axis in 2:
		if random.next_int(2)==0:offset[axis]=-offset[axis]
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	var scene:=identity.duplicate();scene.player_pose=pose
	var shot:=identity.duplicate();shot.merge({"target":"player","mode":"follow"})
	var fixed:=shot.duplicate();fixed.merge({"mode":"fixed_eye","eye":pose*offset,"inherit_target_up":true},true)
	var camera:=Rig.new()
	if not camera.configure(bindings) or not camera.update(0,shot,scene,fixed):return reject(camera.error)
	_state=identity.duplicate()
	_state.merge({"player_pose":pose,"special_placement":special_placement,"offset":offset,
		"input_random_state":random_state.duplicate(true),"random_state":random.snapshot(),
		"entry_release_ms":int(Definitions.VALUES.entry_release_ms),"shot":shot,"fixed_shot":fixed})
	_camera=camera
	return true

func snapshot() -> Dictionary:return _state.duplicate(true)
func camera_owner() -> RefCounted:return null if _camera==null else _camera.fork_for_frame()
func reject(message: String) -> bool:error=message;return false
