extends "res://tests/ordinary_world_geometry.gd"
## Representative newly admitted base worlds, including source asset variants.
func geometry_specs() -> Array:
	return [
		{"station_id":0,"system_id":0,"planet_count":5,"hangar_row":2,"gate":true},
		{"station_id":60,"system_id":12,"planet_count":2,"hangar_row":1,"gate":true},
		{"station_id":80,"system_id":16,"planet_count":5,"hangar_row":0,"gate":true}]
func geometry_name(station: int) -> String:return "base-%d"%station
