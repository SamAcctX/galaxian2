extends "res://tests/ordinary_world_geometry.gd"
## Full original Nesla gate/local scenery and hangars, without earning travel.
func geometry_specs() -> Array:
	var result:=[]
	for station in [85,86,87,88,89]:
		result.append({"station_id":station,"system_id":17,"planet_count":5,"hangar_row":2,"gate":station==85})
	return result
func geometry_name(station: int) -> String:return "nesla-%d"%station
func geometry_available(bindings: RefCounted) -> bool:return load("res://src/content/ordinary_world_definitions.gd").Thynome.coherent(bindings.mido_travel)
