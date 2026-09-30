extends RefCounted
## Radio predicates only. Mission-result condition numbers use another namespace.
## Call observation_error/valid_row at the input boundary before evaluate.
## Observations and started latches are read-only; waypoint history is scheduler
## state, updated only when its row is actually visited in an idle radio tick.
const Numbers = preload("res://src/content/opening_definitions.gd")
const Vitals = preload("res://src/simulation/combat_vitals.gd")
const MAX_INTEGER := 2147483647
const Z_TOLERANCE := 5000.0

static func valid_clock(value: Variant) -> bool:
	return value is int and value >= 0 and value <= MAX_INTEGER

static func valid_row(row: Dictionary, event_count: int) -> bool:
	if not Numbers.integer(row.get("condition"), 0, 31) or not row.get("values") is Array: return false
	var kind := int(row.condition)
	if kind not in [1, 5, 6, 8, 9, 12, 16, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]: return false
	if row.values.is_empty() or row.values.size() > 256 or (kind not in [1, 9, 29, 30] and row.values.size() != 1) or (kind == 29 and row.values.size() != 2) or (kind == 30 and row.values.size() != 3): return false
	for value in row.values:
		if not Numbers.integer(value, -2147483648 if kind == 26 else 0, MAX_INTEGER): return false
	return kind != 6 or int(row.values[0]) < event_count

static func observation_error(observation: Dictionary, condition_clock: Variant) -> String:
	if not valid_clock(condition_clock): return "Radio requires an explicit integer condition clock"
	for key in ["hulls", "maximum_hulls", "activity", "positions_z", "player_distances"]:
		if not observation.has(key): continue
		var values: Variant = observation[key]
		if not values is Dictionary: return "Invalid radio actor observations: " + key
		for actor in values:
			if not actor is int or actor < 0 or actor > MAX_INTEGER: return "Invalid radio actor index"
			var value: Variant = values[actor]
			match key:
				"hulls":
					if not Numbers.integer(value, -2147483648, MAX_INTEGER): return "Invalid radio hull"
				"maximum_hulls":
					if not Numbers.integer(value, 1, MAX_INTEGER): return "Invalid radio maximum hull"
				"activity":
					if not value is bool: return "Invalid radio actor activity"
				"player_distances":
					if not (value is int or value is float) or not is_finite(value) or value < 0: return "Invalid radio player distance"
				"positions_z":
					if not (value is int or value is float) or not is_finite(value) or not is_finite(Vitals.single(float(value))): return "Invalid radio statistics Z position"
	for key in ["phase", "defeated_targets", "collected_cargo_quantity", "survivors", "route_index"]:
		if observation.has(key) and not Numbers.integer(observation[key], -1 if key in ["phase", "route_index"] else 0, MAX_INTEGER): return "Invalid radio quantity: " + key
	for key in ["hostile_active", "mother_ship_locked", "player_armor_depleted"]:
		if observation.has(key) and not observation[key] is bool: return "Invalid radio activity: " + key
	if observation.has("targets"):
		var targets: Variant = observation.targets
		if not targets is Array or targets.size() > 4096: return "Invalid radio target list"
		for target in targets:
			if not target is Dictionary: return "Invalid radio target"
			for key in ["scenery", "active", "systems_disabled"]:
				if not target.get(key) is bool: return "Invalid radio target flag: " + key
			if target.has("friendly") and not target.friendly is bool: return "Invalid radio target allegiance"
			if target.has("current_hull") and not Numbers.integer(target.current_hull, -2147483648, MAX_INTEGER): return "Invalid radio target hull"
	return ""

static func evaluate(row: Dictionary, condition_clock: int, observations: Dictionary, started: Array, waypoint_indices: Dictionary, event_index: int = -1) -> bool:
	var value := int(row.values[0])
	var hulls: Dictionary = observations.get("hulls", {})
	match int(row.condition):
		1:
			for actor in row.values:
				if hulls.has(int(actor)) and hulls[int(actor)] <= 0: return true
			return false
		5: return condition_clock >= value
		6: return value < started.size() and started[value] == true
		8:
			var targets: Array = observations.get("targets", [])
			return value < targets.size() and not targets[value].scenery and targets[value].active
		9:
			for actor in row.values:
				if not hulls.has(int(actor)) or hulls[int(actor)] > 0: return false
			return true
		12:
			var maximum: Variant = observations.get("maximum_hulls", {}).get(value)
			return maximum != null and hulls.has(value) and int(hulls[value]) < int(int(maximum) / 2)
		16: return observations.get("hostile_active", false)
		20: return int(observations.get("defeated_targets", 0)) >= value
		21:
			var targets: Array = observations.get("targets", [])
			return value < targets.size() and targets[value].systems_disabled
		22:
			return observations.has("collected_cargo_quantity") and int(observations.collected_cargo_quantity) >= value
		23: return observations.get("mother_ship_locked", false)
		24:
			return observations.get("activity", {}).get(value) == false and hulls.get(value, 0) > 0 and condition_clock >= 60000
		25:
			var current := int(observations.get("route_index", -1))
			if current < 0 or event_index < 0: return false
			var previous := int(waypoint_indices.get(event_index, 0))
			waypoint_indices[event_index] = current
			return current > previous and previous == 0 and int(observations.get("survivors", 0)) >= value
		26:
			if observations.get("activity", {}).get(0) != true or hulls.get(0, 0) <= 0: return false
			var position: Variant = observations.get("positions_z", {}).get(0)
			return position != null and absf(Vitals.single(float(position) - float(value))) < Z_TOLERANCE
		27: return int(observations.get("phase", 0)) == value
		28: return observations.get("player_armor_depleted", false)
		# Remake story condition: the player is within values[1] of ship values[0].
		29:
			var distance: Variant = observations.get("player_distances", {}).get(value)
			return distance != null and hulls.get(value, 0) > 0 and float(distance) <= float(row.values[1])
		# Remake story condition: at least values[0] of ships values[1]..values[2]-1 destroyed.
		30:
			var destroyed := 0
			for actor in range(int(row.values[1]), int(row.values[2])):
				if hulls.has(actor) and hulls[actor] <= 0: destroyed += 1
			return destroyed >= value
	return false
