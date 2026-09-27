extends RefCounted
## One synchronous pilot iteration's borrowed, read-only accepted observation.
## This is a harness receipt, not a native cache. Invalidate before any await or
## navigation; the desktop adapter consumes it before a second input delivery.
## Owner identity matters even when revision and elapsed time are unchanged.
var _session: Node3D
var _owner: RefCounted
var _state: Dictionary
var _active: bool
var _process_frame: int
var _physics_frame: int
var _valid:=true

func _init(session: Node3D) -> void:
	_session=session;_owner=session._world;_active=session._active
	_process_frame=Engine.get_process_frames();_physics_frame=Engine.get_physics_frames()
	_state=session.snapshot()

func matches(session: Node3D) -> bool:
	return _valid and is_instance_valid(session) and session==_session and _owner!=null \
		and session._world==_owner and session._active==_active \
		and session.status==_state.status and session.is_paused()==_state.paused \
		and Engine.get_process_frames()==_process_frame and Engine.get_physics_frames()==_physics_frame

func read(session: Node3D) -> Dictionary:
	return _state if matches(session) else {}

func invalidate() -> void:
	_valid=false;_session=null;_owner=null
