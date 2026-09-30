extends RefCounted
## Independently designed deterministic scenery orientation. Both supplied editions
## use the same 48-bit generator and three 16-bit angles with float32 rounding.
const Generator = preload("res://src/simulation/seeded_random.gd")
const SOURCE_TAU := 6.2831854820251465
var error := ""

## The highest sky index a system uses (Supernova's Talidor and Wah'norr: 17, 18).
const LAST_SKY_INDEX:=18
const LIGHT_SYSTEM_ID:=27

## A location's sky rotation. Ginoya (27) turns its sky so the sun sits on
## the sky's +Y pole: +Y toward the sun, +Z = world X cross +Y, +X = +Y cross +Z.
## Skies 17 and 18 are unrotated; others use the station's seeded angles.
func for_location(station_id: int, system_id: int, sky_index: int, planet_type: int) -> Dictionary:
	if system_id!=LIGHT_SYSTEM_ID:return for_station(station_id,sky_index in [17,18])
	var sun: Dictionary=load("res://src/simulation/sun_placement.gd").new().for_station(station_id,planet_type)
	if sun.is_empty():error="Ginoya's sky needs its sun direction";return {}
	var up: Vector3=Vector3(sun.direction_to_sun).normalized()
	var back:=Vector3.RIGHT.cross(up).normalized()
	var basis:=Basis(up.cross(back),up,back)
	return {"angles":basis.get_euler(EULER_ORDER_XYZ),"basis":basis}

func for_station(station_id: Variant, suppressed := false) -> Dictionary:
	error=""
	if station_id!=null and (not station_id is int or station_id<-2147483648 or station_id>2147483647):
		error="Scenery requires a signed 32-bit station ID or an explicitly absent station"
		return {}
	var angles := Vector3.ZERO
	if not suppressed:
		var generator := Generator.new()
		# An absent station differs from an actual station record whose ID is -1.
		var seed_value := -1 if station_id==null else ((int(station_id)*2+2147483648)&0xffffffff)-2147483648
		generator.seed_from(seed_value)
		for axis in 3:
			angles[axis]=PackedFloat32Array([float(generator.next_int(65536))/65536.0*SOURCE_TAU])[0]
	return {"angles":angles,"basis":Basis.from_euler(angles,EULER_ORDER_XYZ)}
