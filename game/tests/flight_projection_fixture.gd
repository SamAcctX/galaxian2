extends RefCounted
const Definitions = preload("res://src/content/flight_projection_definitions.gd")

static func definition(mac: bool = true, android := false) -> Dictionary:
	var data := {"vertical_fov_radians": PI / 2.0, "near": 4.0, "far": 1000.0,
		"matching_location_early_far": 2000.0, "early_cursor_limit": 7,
		"fov_axis": "vertical", "provenance": {}}
	var offset := 256
	var architecture := "android-armv7" if android else ("x86_64" if mac else "armv7")
	for key in Definitions.sizes(architecture):
		var size: int = Definitions.sizes(architecture)[key]
		data.provenance[key] = {"offset": offset, "bytes": size}
		offset += size + 16
	return data
