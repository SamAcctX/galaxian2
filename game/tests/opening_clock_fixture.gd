extends RefCounted
const Definitions = preload("res://src/content/opening_clock_definitions.gd")

static func definition(mac: bool = true, android := false) -> Dictionary:
	var data := {"initial_elapsed_ms": 12, "advance_before_controller": true, "time_unit": "milliseconds", "provenance": {}}
	var offset := 256
	var architecture := "android-armv7" if android else ("x86_64" if mac else "armv7")
	for key in Definitions.sizes(architecture):
		var size: int = Definitions.sizes(architecture)[key]
		data.provenance[key] = {"offset": offset,"bytes": size}
		offset += size+16
	return data
