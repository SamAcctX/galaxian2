extends RefCounted
## Shared display units for NPC, station and waypoint distances.
const TargetProjection=preload("res://src/presentation/target_projection.gd")

static func meters(point: Vector3,eye: Vector3,rules: Dictionary) -> int:
	if rules.is_empty() or not point.is_finite() or not eye.is_finite():return -1
	var squared: int=0
	for axis in 3:
		var delta:=TargetProjection.single(TargetProjection.single(point[axis]*rules.distance_coordinate_scale)-TargetProjection.single(eye[axis]*rules.distance_coordinate_scale))
		if not is_finite(delta) or absf(delta)>1000000000:return -1
		var component:=int(delta);squared+=component*component
	var root:=TargetProjection.single(sqrt(TargetProjection.single(TargetProjection.single(float(squared))*rules.distance_squared_scale)))
	var result:=int(root)*int(rules.distance_result_scale)
	return result if result<2147483648 else -1

static func label(value: int,rules: Dictionary) -> String:
	if value<int(rules.kilometer_threshold):return "%dm"%value
	@warning_ignore("integer_division")
	return "%d.%dkm"%[value/1000,(value%1000)/100]
