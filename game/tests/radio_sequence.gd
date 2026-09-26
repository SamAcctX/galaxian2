extends SceneTree
const Radio = preload("res://src/simulation/radio_sequence.gd")
const Bindings = preload("res://src/content/resource_bindings.gd")
const Library = preload("res://src/content/library.gd")
var failures := 0

func _initialize() -> void:
	var binding := Bindings.new()
	binding.base_content_id = "a".repeat(64)
	binding.binding_id = "b".repeat(64)
	binding.opening_dialogue = fixture()
	var library := Library.new()
	library.manifest = {"content_id": binding.base_content_id}
	library.active_language = "gb"
	for i in 23: library.strings.append("Synthetic line %d" % i)
	var counts := []
	counts.resize(23)
	counts.fill(1)
	var radio := Radio.new()
	check(radio.configure(binding, library, counts), radio.error)
	check(radio.step(49, {}, 0).is_empty(), "Elapsed trigger fired early")
	check(radio.step(50, {}, 0) == [{"kind": "started", "event": 0}], "Elapsed trigger boundary")
	check(radio.snapshot().started[0] and not radio.snapshot().finished[0], "Started conflated with finished")
	check(radio.step(2050, {}, 0).is_empty(), "Radio display delay must be strict")
	check(radio.step(2051, {}, 0).size() == 1 and radio.snapshot().visible, "Radio failed to become visible")
	check(radio.step(5550, {}, 0).is_empty(), "Radio finished at inclusive boundary")
	check(radio.step(5551, {}, 0) == [{"kind": "finished", "event": 0}], "Radio completion boundary")
	check(radio.snapshot().active_event == -1, "Next event started within completion frame")
	check(radio.step(5551, {}, 0) == [{"kind": "started", "event": 1}], "Dependent event missing")
	var snap := radio.snapshot()
	snap.finished[0] = false
	check(radio.snapshot().finished[0], "Mutable radio snapshot")
	check(radio.step(5550, {}, 0).is_empty() and not radio.error.is_empty() and radio.snapshot().active_event == 1, "Backward time changed state")
	# One large advance completes only the active line. It never earns a mission.
	var changes := radio.step(50000, {}, 0)
	check(changes.size() == 2 and changes[0].kind == "display" and changes[1].kind == "finished", "Long frame lost display/completion")
	check(radio.step(50000, {}, 0).is_empty(), "Missing actors treated as destroyed")
	check(radio.step(50000, {0: 0, 1: 0, 2: 1}, 0).is_empty(), "Live actor ignored")
	check(radio.step(50000, {0: 0, 1: 0, 2: -1}, 0) == [{"kind": "started", "event": 2}], "Hull gate not satisfied")
	radio.step(55501, {}, 0)
	check(radio.step(55501, {}, 11).is_empty(), "Phase equality used as greater-than")
	check(radio.step(55501, {}, 12) == [{"kind": "started", "event": 3}], "Phase gate not satisfied")
	# The reader accepts edition text IDs; runtime binds to the selected language.
	for bad in ["identity", "language", "text", "line_count", "self_dependency"]:
		binding.opening_dialogue = fixture()
		binding.base_content_id = library.manifest.content_id
		library.active_language = "gb"
		counts[0] = 1
		match bad:
			"identity": binding.base_content_id = "c".repeat(64)
			"language": library.active_language = ""
			"text": binding.opening_dialogue.events[0].text_id = 23
			"line_count": counts[0] = 0
			"self_dependency": binding.opening_dialogue.events[1].values = [1]
		check(not radio.configure(binding, library, counts) and radio.snapshot().is_empty(), "Invalid configuration retained radio: " + bad)
	verify_runner_conditions()
	verify_observation_boundaries()
	verify_waypoint_forks()
	verify_stage_clock()
	var args := OS.get_cmdline_user_args()
	# The standard App Store check supplies content, bindings and visuals. This
	# scheduling test only needs the first two; older explicit pairs still work.
	if args.size() == 3: args.resize(2)
	check(args.size() % 2 == 0, "Pass content/binding pairs")
	for i in range(0, args.size() - 1, 2):
		check(library.open(args[i]) and library.select_language("gb"), library.error)
		check(binding.open(args[i + 1], library.manifest), binding.error)
		counts.fill(1) # Isolated scheduling fixture. Bitmap-derived counts are checked by source_text_layout.
		check(radio.configure(binding, library, counts), radio.error)
		var rows: Array = binding.opening_dialogue.get("events", [])
		check(rows.size() == 23, "Source opening event count")
		if rows.size() != 23: continue
		# Both supplied Mac layouts use the same profile name but have different
		# source text tables. The guarded declaration offset identifies the one
		# imported with this binding; the voice table independently names its row.
		var first_text_id:=1668 if library.manifest.profile.edition=="ios-hd" else -1
		if first_text_id<0:
			match int(binding.opening_dialogue.get("provenance",{}).get("declaration",{}).get("offset",-1)):
				839618:first_text_id=1649
				845802:first_text_id=1657
		check(first_text_id>=0 and rows[0].text_id==first_text_id,"Imported opening text differs from its guarded source layout")
		var voice: Dictionary=binding.opening_dialogue.get("voice",{})
		if not voice.is_empty():check(voice.get("text_ids",[]).size()==rows.size() and int(voice.text_ids[0])==first_text_id,"Opening voice table names another source text row")
		check(rows[9].values.map(func(value): return int(value)) == [0, 1, 2] and rows[16].values.map(func(value): return int(value)) == [12], "Source combat/phase gates changed")
		check(radio.step(1500, {}, 0) == [{"kind": "started", "event": 0}], "Real declarations did not activate")
		check(radio.snapshot().text == library.strings[int(rows[0].text_id)], "Localized radio binding failed")
		var time := 1500
		for event in 9:
			if event > 0:
				check(radio.step(time, {}, 0) == [{"kind": "started", "event": event}], "Real pre-combat dialogue order changed")
			time += 5501
			radio.step(time, {}, 0)
			check(radio.snapshot().finished[event], "Real radio line did not finish")
		check(radio.step(time, {}, 0).is_empty(), "Missing combat was treated as won")
		check(radio.step(time, {0: 0, 1: 0, 2: 0}, 0) == [{"kind": "started", "event": 9}], "Real combat radio gate failed")
		verify_imported_probe(binding, library)
		print(library.manifest.profile.edition, ": 23 radio events bound to selected language")
	print("Radio checks: %d failures" % failures)
	quit(1 if failures else 0)

func fixture() -> Dictionary:
	var rows := []
	for i in 23:
		rows.append({"text_id": i, "speaker_id": i, "condition": 5, "values": [100000]})
	rows[0].values = [50]
	rows[1].condition = 6
	rows[1].values = [0]
	rows[2].condition = 9
	rows[2].values = [0, 1, 2]
	rows[3].condition = 27
	rows[3].values = [12]
	return {"campaign_cursor": 0, "events": rows, "timing": {"display_delay_ms": 2000, "base_duration_ms": 1500, "per_line_ms": 2000}}

## Synthetic records enter the scheduler directly so the same radio condition
## can be exercised under different identities without inventing mission data.
func synthetic_radio(rows: Array, cursor: int = 0) -> RefCounted:
	var binding := Bindings.new()
	binding.base_content_id = "a".repeat(64)
	binding.binding_id = "b".repeat(64)
	var library := Library.new()
	library.manifest = {"content_id": binding.base_content_id}
	library.active_language = "gb"
	var events := rows.duplicate(true)
	var counts := []
	for i in events.size():
		events[i].text_id = i
		events[i].speaker_id = 0
		library.strings.append("Synthetic radio line %d" % i)
		counts.append(1)
	var radio := Radio.new()
	check(radio._configure_records(binding, library, {"events": events, "timing": fixture().timing}, counts, cursor), radio.error)
	return radio

func observation_for(radio: RefCounted, clock: Variant, facts: Dictionary = {}) -> Dictionary:
	var result: Dictionary = radio._identity.duplicate()
	result.campaign_cursor = result.get("campaign_cursor", 0)
	result.condition_clock = clock
	result.merge(facts, true)
	return result

func verify_runner_conditions() -> void:
	for cursor in [0, 7, 29, 38, 40, 41, 99]:
		for sample in [
			[1, [2, 3], {"hulls": {2: 1, 3: -1}}],
			[5, [60000], {}],
			[12, [3], {"hulls": {3: 49}, "maximum_hulls": {3: 100}}],
			[16, [0], {"hostile_active": true}],
			[21, [0], {"targets": [{"scenery": true, "active": false, "systems_disabled": true}]}],
			[22, [3], {"collected_cargo_quantity": 3}],
			[24, [2], {"activity": {2: false}, "hulls": {2: 1}}],
			[25, [2], {"route_index": 1, "survivors": 2}],
			[26, [42000], {"hulls": {0: 1}, "activity": {0: true}, "positions_z": {0: 42000.0}}]
		]:
			var radio := synthetic_radio([{"condition": sample[0], "values": sample[1]}], cursor)
			check(radio.bind_context(observation_for(radio, 60000, sample[2])), radio.error)
			check(radio.step_context(0) == [{"kind": "started", "event": 0}], "Radio condition %d still depends on cursor %d" % [sample[0], cursor])
	# A reference may point forward in the list and it observes START, even
	# while that event's text is not visible or finished.
	var radio := synthetic_radio([{"condition": 6, "values": [2]}, {"condition": 5, "values": [1000]}, {"condition": 5, "values": [0]}])
	check(radio.bind_context(observation_for(radio, 0)), radio.error)
	check(radio.step_context(0) == [{"kind": "started", "event": 2}], "Referenced later row did not start")
	check(radio.eligible({"condition": 6, "values": [2]}, 0, {}, 0) and not radio.event_state(2).playback_finished, "Dependency waited for finish or used previous row")
	check(radio.step_context(5501).back() == {"kind": "finished", "event": 2} and not radio.event_state(0).condition_satisfied, "Dependent row overlapped completion frame")
	check(radio.step_context(5501) == [{"kind": "started", "event": 0}], "Referenced started event did not unlock the earlier row")

func verify_observation_boundaries() -> void:
	var radio := synthetic_radio([{"condition": 1, "values": [0]}])
	var observation := observation_for(radio, 0, {"hulls": {0: 1}})
	check(radio.bind_context(observation), radio.error)
	observation.hulls[0] = 0
	check(radio.step_context(0).is_empty(), "Caller edit changed a bound observation")
	var parent: Dictionary = radio.snapshot()
	var child: RefCounted = radio.fork_for_frame()
	check(child.step_context(0).is_empty() and child.error.is_empty(), "Fork lost its bound observations")
	observation.hulls.make_read_only()
	observation.make_read_only()
	check(child.bind_context(observation) and child.step_context(1) == [{"kind": "started", "event": 0}], "Frozen observation could not be bound on a fork")
	check(radio.snapshot() == parent and radio.step_context(1).is_empty(), "Forked observation or started latch changed its parent")
	var bound: Dictionary = radio._observation.duplicate(true)
	for invalid in [null, true, "1", -1, 2147483648, 1.0, 0.5, NAN, INF]:
		var wrong := observation_for(radio, invalid)
		check(not radio.bind_context(wrong) and not radio.error.is_empty() and radio._observation == bound, "Rejected condition clock replaced bound observations")
		check(radio.step_context(invalid).is_empty() and not radio.error.is_empty() and radio._last_time == 1 and radio.snapshot() == parent, "Rejected display clock changed playback")
	for changed in [{"base_content_id": "foreign"}, {"binding_id": "foreign"}, {"campaign_cursor": 1}, {"campaign_cursor": 0.0}, {"hulls": {0: NAN}}, {"hulls": {0: 0.5}}, {"maximum_hulls": {0: 0}}, {"positions_z": {0: INF}}, {"collected_cargo_quantity": -1}]:
		check(not radio.bind_context(observation_for(radio, 0, changed)) and radio._observation == bound and radio.snapshot() == parent, "Invalid observation partly committed")
	var missing := observation_for(radio, 0)
	missing.erase("condition_clock")
	check(not radio.bind_context(missing), "Runner silently substituted a clock")
	check(radio.step(500, {0: NAN}, 0).is_empty() and not radio.error.is_empty() and radio._last_time == 1, "Legacy hull input accepted non-finite data")
	check(radio.step(500.5, {0: 0}, 0).is_empty() and not radio.error.is_empty() and radio._last_time == 1, "Legacy display clock was silently truncated")
	check(not radio.eligible({"condition": 20, "values": [0]}, 0, {}, 0, false, 0.5), "Legacy predicate silently truncated a fractional count")
	check(not radio.eligible({"condition": 26, "values": [0]}, 0, {0: 1}, 0, false, 0, {"activity": 1, "freighter_active": true, "freighter_z": 0.0}), "Malformed legacy actor data reached the evaluator")
	check(radio.step(2, {0: 0}, 0) == [{"kind": "started", "event": 0}], "Rejected future frame consumed display time")

func verify_waypoint_forks() -> void:
	var radio := synthetic_radio([{"condition": 5, "values": [0]}, {"condition": 25, "values": [2]}])
	check(radio.bind_context(observation_for(radio, 0, {"route_index": 1, "survivors": 2})), radio.error)
	check(radio.step_context(0) == [{"kind": "started", "event": 0}] and radio._waypoint_indices.is_empty(), "Earlier eligible row consumed the waypoint")
	radio.step_context(5501)
	check(radio._waypoint_indices.is_empty(), "Active playback observed the deferred waypoint")
	var child: RefCounted = radio.fork_for_frame()
	check(child.step_context(5501) == [{"kind": "started", "event": 1}] and radio._waypoint_indices.is_empty(), "Waypoint observation leaked through a fork")
	check(radio.bind_context(observation_for(radio, 0, {"route_index": 1, "survivors": 1})), radio.error)
	check(radio.step_context(5501).is_empty() and radio._waypoint_indices[1] == 1, "Failed survivor gate did not consume its observed route transition")
	check(radio.bind_context(observation_for(radio, 0, {"route_index": 1, "survivors": 2})), radio.error)
	check(radio.step_context(5502).is_empty(), "Increasing survivors replayed consumed progress")
	var snapshot: Dictionary = child.snapshot()
	snapshot.waypoint_observations[1] = 0
	check(child.snapshot().waypoint_observations[1] == 1, "Mutable waypoint snapshot changed radio history")

func verify_stage_clock() -> void:
	var radio := synthetic_radio([{"condition": 5, "values": [120000]}], 29)
	var observation := observation_for(radio, 999999, {"stage_elapsed_ms": 119999, "mother_ship_locked": false})
	check(radio.step_probe(200000, observation).is_empty() and radio._observation.condition_clock == 119999, "Probe adapter substituted world time for the stage clock")
	observation.stage_elapsed_ms = 0
	check(radio.step_probe(200001, observation).is_empty() and radio._observation.condition_clock == 0, "Stage reset was ignored or required monotonic condition time")
	for invalid in [null, 1.0, -1, NAN, INF]:
		observation.stage_elapsed_ms = invalid
		check(radio.step_probe(200002, observation).is_empty() and not radio.error.is_empty() and radio._last_time == 200001 and radio._observation.condition_clock == 0, "Bad stage clock silently fell back to world time")
	observation.stage_elapsed_ms = 120000
	check(radio.step_probe(200002, observation) == [{"kind": "started", "event": 0}], "Probe lost inclusive stage-clock boundary")
	observation.stage_elapsed_ms = 0
	check(radio.step_probe(202002, observation).is_empty(), "Stage reset altered strict display delay")
	check(radio.step_probe(202003, observation).front().kind == "display", "Stage reset blocked monotonic display time")
	check(radio.step_probe(205502, observation).is_empty() and radio.step_probe(205503, observation) == [{"kind": "finished", "event": 0}], "Stage reset changed playback completion")
	check(radio.step_probe(205502, observation).is_empty() and not radio.error.is_empty(), "Stage reset permitted backward display time")
	# The legacy recovery owner still supplies the elapsed clock; the probe
	# mapping is confined to its compatibility adapter, never a predicate gate.
	var recovery := synthetic_radio([{"condition": 5, "values": [12000]}], 24)
	var recovered := observation_for(recovery, 0, {"recovery": {"accepted_quantity": 0}})
	check(recovery.step_sahi(11999, recovered).is_empty() and recovery.step_sahi(12000, recovered) == [{"kind": "started", "event": 0}], "Sahi recovery lost its elapsed clock")

func verify_imported_probe(binding: RefCounted, library: RefCounted) -> void:
	var declarations: Dictionary = Radio.Definitions.select(binding, 29)
	if declarations.is_empty(): return
	var counts := []
	counts.resize(declarations.events.size())
	counts.fill(1)
	var radio := Radio.new()
	check(radio.configure(binding, library, counts, 29), radio.error)
	var observation := observation_for(radio, 0, {"stage_elapsed_ms": 0, "mother_ship_locked": true})
	var time := 0
	for event in 4:
		check(radio.step_probe(time, observation) == [{"kind": "started", "event": event}], "Imported probe radio changed its initial order")
		time += 5501
		check(radio.step_probe(time, observation).back() == {"kind": "finished", "event": event}, "Imported probe line failed to finish")
	check(radio.step_probe(200000, observation).is_empty(), "Imported probe used display time after the stage reset")
	observation.stage_elapsed_ms = 119999
	check(radio.step_probe(200001, observation).is_empty(), "Imported probe warning fired before 120 seconds of stage time")
	observation.stage_elapsed_ms = 120000
	check(radio.step_probe(200002, observation) == [{"kind": "started", "event": 4}], "Imported probe missed the stage-clock threshold")
	print("Imported probe: resettable stage clock verified")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
