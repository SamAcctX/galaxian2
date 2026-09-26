extends SceneTree
## Synthetic observations exercise reusable radio rules, not a campaign result.
const Condition = preload("res://src/simulation/radio_condition.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	verify_hulls_and_positions()
	verify_activity_and_progress()
	verify_boundaries()
	print("Radio conditions: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)

func matches(kind: int, values: Array, observation: Dictionary = {}, clock: int = 0, started: Array = [], history: Dictionary = {}, event_index: int = -1) -> bool:
	var row := {"condition": kind, "values": values}
	check(Condition.valid_row(row, started.size()), "Malformed condition fixture")
	check(Condition.observation_error(observation, clock).is_empty(), "Malformed observation fixture")
	return Condition.evaluate(row, clock, observation, started, history, event_index)

func verify_hulls_and_positions() -> void:
	check(not matches(1, [2, 3], {"hulls": {0: 0, 2: 1}}), "Missing or unrelated actors counted as dead")
	for hull in [0, -1, -2147483648]:
		check(matches(1, [2, 3], {"hulls": {2: 100, 3: hull}}), "Any nonpositive referenced hull must suffice")
	check(not matches(9, [2, 3], {"hulls": {2: 0}}), "All-hull predicate accepted a missing actor")
	check(not matches(9, [2, 3], {"hulls": {2: 0, 3: 1}}), "All-hull predicate ignored a survivor")
	check(matches(9, [2, 3], {"hulls": {2: 0, 3: -1}}), "All-hull predicate rejected nonpositive hulls")
	for sample in [[200, 100, false], [200, 99, true], [1825, 912, false], [1825, 911, true]]:
		check(matches(12, [3], {"hulls": {3: sample[1]}, "maximum_hulls": {3: sample[0]}}) == sample[2], "Half-hull lost strict integer division")
	check(not matches(12, [3], {"hulls": {3: 0}}), "Missing maximum hull satisfied damage radio")
	check(not matches(12, [3], {"maximum_hulls": {3: 200}}), "Missing current hull satisfied damage radio")
	for center in [-100000, 42000]:
		for offset in [-5001.0, -5000.0, -4999.9921875, 0.0, 4999.9921875, 5000.0, 5001.0]:
			var observation := {"hulls": {0: 1}, "activity": {0: true}, "positions_z": {0: float(center) + offset}}
			check(matches(26, [center], observation) == (absf(offset) < 5000.0), "Proximity lost supplied center or strict boundary")
	for changed in [{"hulls": {0: 0}}, {"hulls": {0: -1}}, {"activity": {0: false}}, {"positions_z": {}}, {"hulls": {1: 1}, "activity": {1: true}, "positions_z": {1: 42000.0}}]:
		var observation := {"hulls": {0: 1}, "activity": {0: true}, "positions_z": {0: 42000.0}}
		observation.merge(changed, true)
		check(not matches(26, [42000], observation), "Proximity accepted an absent, dead or inactive first target")
	var frozen := {"hulls": {0: 1}, "activity": {0: true}, "positions_z": {0: 42000.0}}
	for field in frozen.values(): field.make_read_only()
	frozen.make_read_only()
	check(matches(26, [42000], frozen) and frozen.hulls[0] == 1, "Predicate edited a frozen observation")

func verify_activity_and_progress() -> void:
	check(not matches(5, [10], {}, 9) and matches(5, [10], {}, 10), "Elapsed condition lost inclusive supplied clock")
	check(matches(6, [1], {}, 0, [false, true, false]), "Dependency did not observe the referenced started latch")
	check(not matches(6, [1], {}, 0, [true, false, true]), "Dependency inferred previous/last event instead of the referenced latch")
	check(matches(16, [0], {"hostile_active": true, "hulls": {0: 0}}), "Hostile activity acquired a hull gate")
	check(not matches(16, [0], {"hostile_active": false}), "Inactive hostility triggered radio")
	var target := {"active": false, "scenery": true, "systems_disabled": true}
	check(matches(21, [0], {"targets": [target]}), "Disabled systems acquired an activity/scenery gate")
	check(not matches(21, [1], {"targets": [target]}), "Missing indexed target satisfied disabled systems")
	target.active = true
	check(not matches(8, [0], {"targets": [target]}), "Scenery counted as an active radio target")
	target.scenery = false
	check(matches(8, [0], {"targets": [target]}), "Indexed activity gained an allegiance gate")
	check(not matches(22, [3], {}) and not matches(22, [3], {"collected_cargo_quantity": 2}), "Missing/insufficient recovery satisfied quantity")
	check(matches(22, [3], {"collected_cargo_quantity": 3}), "Accepted quantity missed inclusive threshold")
	check(not matches(20, [2], {"defeated_targets": 1}) and matches(20, [2], {"defeated_targets": 2}), "Defeated-target threshold changed")
	check(matches(23, [0], {"mother_ship_locked": true}) and not matches(23, [0]), "Target-lock observation changed")
	check(matches(27, [12], {"phase": 12}) and not matches(27, [12], {"phase": 13}), "Phase equality became a range")
	var escaped := {"activity": {3: false}, "hulls": {3: 1}}
	check(not matches(24, [3], escaped, 59999) and matches(24, [3], escaped, 60000), "Inactive living target lost the minute boundary")
	escaped.hulls[3] = 0
	check(not matches(24, [3], escaped, 60000), "Dead target counted as escaped")
	var history := {}
	check(not matches(25, [2], {"route_index": -1, "survivors": 2}, 0, [], history, 4) and history.is_empty(), "Missing route consumed a waypoint")
	check(not matches(25, [2], {"route_index": 0, "survivors": 2}, 0, [], history, 4), "Initial waypoint counted as progress")
	check(not matches(25, [2], {"route_index": 1, "survivors": 1}, 0, [], history, 4) and history[4] == 1, "Insufficient survivors failed to consume progress")
	check(not matches(25, [2], {"route_index": 1, "survivors": 2}, 0, [], history, 4), "Survivor increase replayed a consumed waypoint")
	check(not matches(25, [2], {"route_index": 2, "survivors": 2}, 0, [], history, 4), "Second waypoint replayed the first transition")
	check(matches(25, [2], {"route_index": 1, "survivors": 2}, 0, [], {}, 4), "Living survivors failed the first route transition")

func verify_boundaries() -> void:
	for invalid in [null, true, "1", -1, 2147483648, 1.0, 0.5, NAN, INF]:
		check(not Condition.observation_error({}, invalid).is_empty(), "Invalid condition clock accepted: " + str(invalid))
	for observation in [{"hulls": {0: NAN}}, {"hulls": {0: 0.5}}, {"hulls": {0: true}}, {"hulls": {0: -2147483649}}, {"hulls": {"0": 1}}, {"maximum_hulls": {0: 0}}, {"activity": {0: 1}}, {"positions_z": {0: INF}}, {"positions_z": {0: NAN}}, {"positions_z": {0: 1e100}}, {"positions_z": {0: "0"}}, {"phase": NAN}, {"survivors": -1}, {"route_index": 0.5}, {"defeated_targets": INF}, {"collected_cargo_quantity": -1}, {"hostile_active": 1}, {"targets": [{"active": false, "scenery": false, "systems_disabled": true, "current_hull": NAN}]}]:
		check(not Condition.observation_error(observation, 0).is_empty(), "Invalid numeric/activity observation accepted: " + str(observation))
	for row in [{}, {"condition": 1, "values": []}, {"condition": 6, "values": [-1]}, {"condition": 6, "values": [2]}, {"condition": 5, "values": [NAN]}, {"condition": 12, "values": [0.5]}, {"condition": 26, "values": [INF]}, {"condition": 31, "values": [0]}]:
		check(not Condition.valid_row(row, 2), "Invalid condition row accepted")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
