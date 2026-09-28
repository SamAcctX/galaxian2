extends RefCounted
## Transient manual aim. Equipment ownership remains in the ship's loadout.
const Definitions=preload("res://src/content/manual_turret_definitions.gd")
var error:=""
var _state:={}

func configure(item: Dictionary,mount: Dictionary) -> bool:
	_state={};error=""
	var row:=Definitions.declaration(int(item.get("id",-1)))
	var handling: Variant=item.get("properties",{}).get(17)
	if row.is_empty() or mount.get("category")!=2 or not mount.get("position") is Vector3 or not mount.position.is_finite() or not handling is int or handling<=0:
		error="Manual turret requires its original mount and handling";return false
	_state={"ready":true,"active":false,"item_id":int(item.id),"mount":mount.position,"yaw":0.0,"pitch":0.0,"camera_pitch":0.0,
		"yaw_speed":deg_to_rad(float(handling)*0.6591796875),"declaration":row}
	return true

func snapshot() -> Dictionary:return _state.duplicate(true)
func active() -> bool:return not _state.is_empty() and _state.active
func set_active(value: bool) -> void:if not _state.is_empty():_state.active=value
func fork() -> RefCounted:
	var next: RefCounted=get_script().new();next._state=_state.duplicate(true);return next

func advance(command: Vector2,milliseconds: int,inverted:=false) -> void:
	if not active():return
	var seconds:=float(milliseconds)/1000.0
	_state.yaw=wrapf(_state.yaw+command.y*_state.yaw_speed*seconds,-PI,PI)
	_state.pitch=clampf(_state.pitch+command.x*Definitions.PITCH_SPEED*seconds,(-500.0 if inverted else -300.0)*TAU/4096.0,70.0*TAU/4096.0)
	_state.camera_pitch=clampf(_state.camera_pitch+command.x*Definitions.PITCH_SPEED*seconds*0.5,(-250.0 if inverted else -200.0)*TAU/4096.0,70.0*TAU/4096.0)

func barrel_pose(ship: Transform3D) -> Transform3D:
	return ship*Transform3D(Basis(Vector3.UP,PI+_state.yaw)*Basis(Vector3.RIGHT,_state.pitch),_state.mount+Vector3(0,_state.declaration.height,0))

func camera_pose(ship: Transform3D) -> Transform3D:
	var yaw:=Basis(Vector3.UP,_state.yaw)
	return ship*Transform3D(yaw*Basis(Vector3.RIGHT,-_state.camera_pitch),_state.mount+yaw*Definitions.CAMERA_OFFSET)

func aim_pose(ship: Transform3D) -> Transform3D:
	return barrel_pose(ship)
