extends RefCounted
## Independently designed ordinary-location light state. RGB is imported; the
## setup factors and float precision follow both verified source renderers.
## Sky 15 (Ginoya) is lit brighter while its star burns (cursor < 158).
## Assumption: callers without a cursor get the burning star. The no-system
## background has its own palette selection, not a fabricated station seed.
const Colors = preload("res://src/content/environment_color_definitions.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")
const Placement = preload("res://src/simulation/sun_placement.gd")
const Fog = preload("res://src/simulation/distance_fog.gd")
var error := ""

func for_station(colors: Dictionary, station_id: Variant, planet_type: Variant, sky_index: Variant, cursor:=-1) -> Dictionary:
	error=""
	if not Colors.parameters(colors): return reject("Environment color tables are unavailable")
	if not Numbers.integer(sky_index,0,18):
		return reject("This sky requires unsupported environment lighting conditions")
	if not Numbers.integer(planet_type,0,26): return reject("Station planet type has no environment color row")
	var placement := Placement.new()
	var sun := placement.for_station(station_id,int(planet_type))
	if sun.is_empty(): return reject(placement.error)
	var source_sun := rgb(colors.sun_rgb[int(sky_index)])
	var source_planet := rgb(colors.planet_rgb[int(planet_type)])
	var burning: bool=sky_index==15 and cursor<158
	var result:=_compose(source_sun,source_planet,rgb(colors.rim_rgb[int(sky_index)]),sun.direction_to_sun,sun,30.0 if burning else 15.0,0.7 if burning else 0.15)
	result.fog=Fog.for_sky(int(sky_index))
	return result

func for_void(colors: Dictionary) -> Dictionary:
	error=""
	if not Colors.parameters(colors):return reject("Environment color tables are unavailable")
	# The fallback fill spans adjacent entries in the imported palette.
	var fill:=Vector3(colors.planet_rgb[7][2],colors.planet_rgb[8][0],colors.planet_rgb[8][1])
	return _compose(rgb(colors.sun_rgb[10]),fill,rgb(colors.rim_rgb[10]),Vector3(0,0,-1))

func _compose(source_sun: Vector3,source_planet: Vector3,rim: Vector3,direction: Vector3,sun: Dictionary={},diffuse_scale:=15.0,ambient_scale:=0.15) -> Dictionary:
	var diffuse := source_sun*diffuse_scale
	for axis in 3: diffuse[axis]=clampf(diffuse[axis],0.0,2.0)
	return {"sun":sun,"fog":{},"global_ambient":source_sun*PackedFloat32Array([ambient_scale])[0],
		"rim_color":rim*3.0,
		"lights":[{"direction_to_light":direction,"ambient":Vector3.ZERO,
			"diffuse":diffuse,"specular":Vector3.ONE*2.0},
			{"direction_to_light":Vector3(0,0,-1),"ambient":Vector3.ZERO,"diffuse":source_planet*1.5,"specular":source_planet*1.5}]}

func rgb(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func reject(message: String) -> Dictionary:
	error=message
	return {}
