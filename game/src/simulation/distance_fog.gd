extends RefCounted
## Location fog is independent of lighting and is absent in clear space.
const SPACE := {11:[0xdb6923,50000.0],12:[0x163e7c,50000.0],
	16:[0x47665e,150000.0],17:[0x738d95,150000.0],18:[0xaba075,150000.0]}

static func for_sky(sky_index: int) -> Dictionary:
	if not SPACE.has(sky_index):return {}
	return _state(SPACE[sky_index][0],SPACE[sky_index][1])

static func for_interior(location: Dictionary, faction: int, room: String) -> Dictionary:
	if faction==1 and room in ["hangar","lounge"]:
		return _state(0x011e0c,30000.0 if room=="hangar" else 5000.0)
	return location.duplicate(true)

static func _state(rgb: int, distance: float) -> Dictionary:
	return {"color":Vector3((rgb>>16)&255,(rgb>>8)&255,rgb&255)/255.0,"end":distance}

static func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	var color: Variant=value.get("color");var distance: Variant=value.get("end")
	return value.size()==2 and color is Vector3 and color.is_finite() and color.clamp(Vector3.ZERO,Vector3.ONE)==color and (distance is float or distance is int) and is_finite(float(distance)) and distance>0
