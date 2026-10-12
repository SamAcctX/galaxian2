extends RefCounted
const Fonts = preload("res://src/content/font_definitions.gd")
const VALUES = {"equipment_property":19,"period_ms":100,"capacity_divisor":100.0,
	"initial_elapsed_ms":0,"discard_excess_time":true,"pulses_per_update":1,
	"requires_living_hull":true,"before_world_weapons":true}
const SIZES = {
	"x86_64":{"pulse":69,"recharge":94,"assignment":26,"getter":9,"hull_getter":12,"adder":38,"clock_zero":11,"blocked_zero":4,"equipment_zero":8,"application_order":131,"world_pass":40,"divisor":4},
	"armv7":{"pulse":62,"recharge":110,"assignment":14,"getter":4,"hull_getter":4,"adder":42,"clock_zero":8,"blocked_zero":4,"equipment_zero":12,"zero_vector":6,"zero_integer":2,"divisor_load":4,"application_order":120,"world_pass":30,"divisor":4},
	"android-armv7":{"application_order":98,"recharge":80,"pulse":54,"entry":28,"clock_zero":8,"blocked_zero":4,"divisor_load":4,"divisor":4,"assignment":14,"equipment_zero":4,"getter":4,"hull_getter":4,"adder":42}}
# Player equipment anchors: [shield assignment size, reset size, assignment delta, reset delta].
const ANCHORS = {"x86_64":[26,8,26,-8],"armv7":[14,12,14,0],"android-armv7":[30,44,14,40]}

static func parameters(data: Dictionary) -> bool:
	if data.size()!=VALUES.size()+1 or not data.get("provenance") is Dictionary: return false
	for key in VALUES:
		var value: Variant=data.get(key)
		if VALUES[key] is bool:
			if not value is bool or value!=VALUES[key]: return false
		elif not (value is int or value is float) or value!=VALUES[key]: return false
	return true

static func validate(data: Variant, executable_bytes: int, architecture: String, player: Dictionary) -> String:
	if not data is Dictionary: return "Missing player recharge declaration"
	if data.is_empty(): return ""
	if not parameters(data): return "Invalid player recharge parameters"
	var sizes: Dictionary=SIZES.get(architecture,{})
	if sizes.is_empty() or data.provenance.size()!=sizes.size(): return "Invalid recharge provenance"
	var spans := []
	for key in sizes:
		var row: Variant=data.provenance.get(key)
		if not Fonts.extent(row,"offset","bytes",[sizes[key]],executable_bytes): return "Invalid recharge source extent"
		var span := Vector2i(int(row.offset),int(row.offset)+int(row.bytes))
		for previous in spans:
			if span.x<previous.y and span.y>previous.x: return "Overlapping recharge source extents"
		spans.append(span)
	var parent: Variant=player.get("provenance")
	if not parent is Dictionary: return "Recharge requires player equipment anchors"
	var assignment: Variant=parent.get("shield_assignment")
	var reset: Variant=parent.get("reset")
	var anchor: Array=ANCHORS[architecture]
	if not Fonts.extent(assignment,"offset","bytes",[anchor[0]],executable_bytes) or not Fonts.extent(reset,"offset","bytes",[anchor[1]],executable_bytes): return "Invalid recharge equipment anchors"
	if int(data.provenance.assignment.offset)!=int(assignment.offset)+anchor[2]: return "Recharge belongs to another equipment assignment"
	if int(data.provenance.equipment_zero.offset)!=int(reset.offset)+anchor[3]: return "Recharge equipment reset is disconnected"
	return ""
