extends RefCounted
## Shared source-coordinate binary32 vector operations. Positive Z is forward.
const Vitals = preload("res://src/simulation/combat_vitals.gd")

static func local_xyz(angles: Vector3) -> Basis:
	return Basis(Vector3.RIGHT,angles.x)*Basis(Vector3.UP,angles.y)*Basis(Vector3.BACK,angles.z)

# Engine vectors store single-precision components. Constructing one from double
# arithmetic performs the same binary32 rounding as Vitals.single() on each
# component, without a script call per operation. Values read back from a vector
# are therefore already binary32.
static func _static_init() -> void:
	if Vector3(0.1,0.0,0.0).x==0.1:push_error("Source vector math requires a single-precision engine build")

static func scaled(value: Vector3, factor: float) -> Vector3:
	return Vector3(value.x*factor,value.y*factor,value.z*factor)

static func normalized(value: Vector3) -> Vector3:
	var total := dot(value,value)
	if not is_finite(total): return Vector3(INF,INF,INF)
	var length := Vitals.single(sqrt(total))
	if length==0: return Vector3.UP
	return Vector3(value.x/length,value.y/length,value.z/length)

static func squares(value: Vector3) -> Vector3:
	return Vector3(value.x*value.x,value.y*value.y,value.z*value.z)

static func added(left: Vector3, right: Vector3) -> Vector3:
	return Vector3(left.x+right.x,left.y+right.y,left.z+right.z)

static func dot(left: Vector3, right: Vector3) -> float:
	var products := Vector3(left.x*right.x,left.y*right.y,left.z*right.z)
	return Vector2(Vector2(products.x+products.y,0.0).x+products.z,0.0).x

static func cross(left: Vector3, right: Vector3) -> Vector3:
	var first := Vector3(left.y*right.z,left.z*right.x,left.x*right.y)
	var second := Vector3(left.z*right.y,left.x*right.z,left.y*right.x)
	return Vector3(first.x-second.x,first.y-second.y,first.z-second.z)
