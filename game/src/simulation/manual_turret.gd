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
	if row.get("collector",false):_state.collector=true
	if row.get("auto",false):_state.merge({"auto":true,"auto_clock":Definitions.AUTO_RETARGET_MS,"target_id":-1})
	return true

## A plasma collector: turret view and aim only, never a shot.
func collector() -> bool:return not _state.is_empty() and _state.get("collector",false)
func automatic() -> bool:return not _state.is_empty() and _state.get("auto",false) and _state.get("auto_enabled",true)
func has_auto() -> bool:return not _state.is_empty() and _state.get("auto",false)
## The player can switch automatic fire off and on again; it starts on.
func set_auto_enabled(value: bool) -> void:
	if has_auto():_state.auto_enabled=value;_state.target_id=-1

## Turn toward the chosen hostile; true when the barrel is on target.
func advance_auto(ship: Transform3D,actors: Array,milliseconds: int) -> bool:
	if not automatic() or active():return false
	var mount: Vector3=ship*(_state.mount+Vector3(0,_state.declaration.height,0))
	_state.auto_clock+=milliseconds
	var target: Dictionary={}
	for actor in actors:
		if actor.get("actor_id")==_state.target_id:target=actor
	if _state.auto_clock>Definitions.AUTO_RETARGET_MS or not _auto_candidate(target,mount):
		_state.auto_clock=0;_state.target_id=-1;target={}
		var nearest:=Definitions.AUTO_RANGE
		for actor in actors:
			if not _auto_candidate(actor,mount):continue
			var distance: float=Vector3(actor.position).distance_to(mount)
			if distance<nearest:nearest=distance;target=actor;_state.target_id=int(actor.actor_id)
	if target.is_empty():return false
	var aim: Vector3=target.position
	var body: Variant=target.get("body_pose")
	if body is Transform3D:aim+=body.basis.z.normalized()*Definitions.AUTO_LEAD
	var local: Vector3=(barrel_pose(ship).affine_inverse()*aim).normalized()
	var seconds:=float(milliseconds)/1000.0
	var yaw_error:=atan2(local.x,local.z);var pitch_error:=atan2(-local.y,Vector2(local.x,local.z).length())
	_state.yaw=wrapf(_state.yaw+clampf(yaw_error,-_state.yaw_speed*seconds,_state.yaw_speed*seconds),-PI,PI)
	_state.pitch=clampf(_state.pitch+clampf(pitch_error,-Definitions.PITCH_SPEED*seconds,Definitions.PITCH_SPEED*seconds),-300.0*TAU/4096.0,70.0*TAU/4096.0)
	return absf(local.x)<=Definitions.AUTO_TOLERANCE and absf(local.y)<=Definitions.AUTO_TOLERANCE

static func _auto_candidate(actor: Dictionary,mount: Vector3) -> bool:
	if actor.is_empty() or actor.get("scenery",false) or actor.get("hostile")!=true or actor.get("active")!=true or int(actor.get("vitals",{}).get("hull",0))<=0:return false
	return actor.get("position") is Vector3 and Vector3(actor.position).distance_to(mount)<Definitions.AUTO_RANGE

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
