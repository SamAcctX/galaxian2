extends "res://tests/ordinary_world_geometry.gd"
## Original Eanya gate, planets, stations and Mido hangars; detached rendering.
func geometry_specs() -> Array:
	var result:=[]
	for station in [20,21,22,23,24]:
		result.append({"station_id":station,"system_id":4,"planet_count":5,"hangar_row":3,"gate":station==20})
	return result
func geometry_cursor() -> int:return 38
func geometry_name(station: int) -> String:return "eanya-%d"%station
func geometry_available(bindings: RefCounted) -> bool:return load("res://src/content/ordinary_world_definitions.gd").Thynome.coherent(bindings.mido_travel)
