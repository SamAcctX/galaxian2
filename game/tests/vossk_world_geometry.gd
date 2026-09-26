extends "res://tests/ordinary_world_geometry.gd"
## Real Vossk gate/local environments and hangars, without granting travel.
func geometry_specs() -> Array:
	var result:=[]
	for station in [15,25,29]:
		result.append({"station_id":station,"system_id":3 if station==15 else 5,"planet_count":5,"hangar_row":1,"gate":station in [15,25]})
	return result

func geometry_name(station: int) -> String:return "vossk-%d"%station
func geometry_available(bindings: RefCounted) -> bool:return load("res://src/content/ordinary_world_definitions.gd").vossk_available(bindings.mido_travel)
