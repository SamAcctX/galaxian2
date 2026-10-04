extends RefCounted
## Independent single-speaker radio scheduler. Simulation time is supplied by the
## mission owner, which also owns pause policy, actor hulls and cinematic phase.
## Source-layout line counts must be supplied explicitly; desktop UI wrapping
## must not shorten or lengthen source timing. No mission/reward is completed here.
const Definitions = preload("res://src/content/dialogue_definitions.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")
const Library = preload("res://src/content/library.gd")
const Combat = preload("res://src/simulation/opening_combat_group.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const ContractWorld=preload("res://src/content/contract_world_definitions.gd")
const FreeFlight=preload("res://src/content/free_flight_definitions.gd")
const Alioth=preload("res://src/content/alioth_attack_definitions.gd")
const Condition = preload("res://src/simulation/radio_condition.gd")
var error := ""
var _definition := {}
var _lines: Array = []
var _text: Array = []
var _started: Array = []
var _finished: Array = []
var _active := -1
var _visible := false
var _activated_at := 0
var _last_time := -1
var _identity := {}
var _waypoint_indices := {}
var _requires_encounter_context:=false
var _observation := {}

func clear() -> void:
	error = ""
	_definition = {}
	_lines = []
	_text = []
	_started = []
	_finished = []
	_active = -1
	_visible = false
	_activated_at = 0
	_last_time = -1
	_identity = {}
	_waypoint_indices = {}
	_requires_encounter_context=false
	_observation = {}

func configure(bindings: RefCounted, library: RefCounted, source_line_counts: Array, campaign_cursor: int = 0) -> bool:
	clear()
	var content_id: String = library.manifest.get("content_id", "")
	if not Library.valid_hash(content_id) or content_id != bindings.base_content_id or not Library.valid_hash(bindings.binding_id): return fail("Radio belongs to another or unavailable content identity")
	var data: Dictionary = Definitions.select(bindings, campaign_cursor)
	if not Definitions.valid_parameters(data, campaign_cursor) or source_line_counts.size() != data.events.size(): return fail("Scene radio or source text layout is unavailable")
	if not _configure_records(bindings,library,data,source_line_counts,campaign_cursor):return false
	_requires_encounter_context=campaign_cursor in [7,14,16,21,24,29,40,41]
	return true

func _configure_records(bindings: RefCounted, library: RefCounted, data: Dictionary, source_line_counts: Array, campaign_cursor: int) -> bool:
	var content_id: String=library.manifest.get("content_id", "")
	if library.active_language.is_empty(): return fail("Select a verified content language before starting radio")
	for i in data.events.size():
		if not Condition.valid_row(data.events[i], data.events.size()): return fail("Invalid radio condition parameters")
		var text_id := int(data.events[i].text_id)
		if text_id >= library.strings.size() or not library.strings[text_id] is String: return fail("Radio text is outside the selected language")
		if not Numbers.integer(source_line_counts[i], 1, 65535): return fail("Missing verified source line count")
	_definition = data.duplicate(true)
	_lines = source_line_counts.duplicate()
	_text = library.strings.duplicate()
	_started.resize(data.events.size())
	_started.fill(false)
	_finished = _started.duplicate()
	_identity = {"base_content_id": content_id, "binding_id": bindings.binding_id, "language": library.active_language}
	if campaign_cursor != 0: _identity.campaign_cursor = campaign_cursor
	return true

func configure_local_message(bindings: RefCounted, library: RefCounted, layout: RefCounted, text_id: int, cursor: int=10) -> bool:
	clear()
	if bindings==null or library==null or layout==null or (Travel.journey(bindings.mido_travel,cursor).is_empty() and not ContractWorld.supports(bindings,cursor) and not (load("res://src/content/free_campaign_definitions.gd").supported(bindings,cursor) and FreeFlight.available(bindings))) or not Definitions.valid_parameters(bindings.opening_dialogue,0):return fail("Local radio requires its verified dialogue and clock")
	if library.manifest.get("content_id")!=bindings.base_content_id or layout.content_id!=bindings.base_content_id or layout.binding_id!=bindings.binding_id or layout.language!=library.active_language:return fail("Local radio layout belongs to another content or language")
	var rule: Dictionary=bindings.mido_travel.traffic_combat.radio
	if not rule.warning_text_ids.any(func(value):return int(value)==text_id) and not rule.response_text_ids.any(func(value):return int(value)==text_id):return fail("Local radio text is outside the verified faction messages")
	if text_id>=library.strings.size() or not library.strings[text_id] is String:return fail("Local radio text is unavailable")
	var lines: PackedStringArray=layout.wrap(library.strings[text_id])
	if not layout.error.is_empty():return fail(layout.error)
	var row:={"speaker_id":int(rule.speaker_id),"text_id":text_id,"condition":int(rule.condition),"values":[int(rule.value)]}
	return _configure_records(bindings,library,{"events":[row],"timing":bindings.opening_dialogue.timing.duplicate(true)},[lines.size()],cursor)

## A prepared recipe supplies its events; timing and text measurement remain
## shared with flight radio. This entry does not grant a flight capability.
func configure_scripted(bindings: RefCounted,library: RefCounted,layout: RefCounted,cursor: int,events: Array) -> bool:
	clear()
	if bindings==null or library==null or layout==null or cursor<0 or events.is_empty() or events.size()>256:return fail("Scripted radio requires its declared events and text layout")
	if library.manifest.get("content_id")!=bindings.base_content_id or layout.content_id!=bindings.base_content_id or layout.binding_id!=bindings.binding_id or layout.language!=library.active_language:return fail("Scripted radio belongs to another content or language")
	if not Definitions.valid_parameters(bindings.opening_dialogue,0):return fail("Scripted radio lacks its shared display timing")
	var counts:=[]
	for index in events.size():
		var row: Variant=events[index]
		if not row is Dictionary or not Condition.valid_row(row,events.size()) or not Numbers.integer(row.get("speaker_id"),0,65535) or not Numbers.integer(row.get("text_id"),0,library.strings.size()-1) or not Numbers.integer(row.get("voice_event_id"),-1,65535):return fail("Invalid scripted radio event")
		if int(row.condition)==6 and int(row.values[0])==index:return fail("Radio cannot depend on its own start")
		var lines: PackedStringArray=layout.wrap(library.strings[int(row.text_id)])
		if not layout.error.is_empty():return fail(layout.error)
		counts.append(lines.size())
	var data:={"events":events.duplicate(true),"timing":bindings.opening_dialogue.timing.duplicate(true),"scripted":true}
	return _configure_records(bindings,library,data,counts,cursor)

func configure_from_layout(bindings: RefCounted, library: RefCounted, layout: RefCounted, campaign_cursor: int = 0) -> bool:
	clear()
	if layout.content_id != library.manifest.get("content_id", "") or layout.language != library.active_language or (not layout.binding_id.is_empty() and layout.binding_id != bindings.binding_id):
		return fail("Radio layout belongs to another content or language")
	var data: Dictionary = Definitions.select(bindings, campaign_cursor)
	if not Definitions.valid_parameters(data, campaign_cursor): return fail("Scene radio is unavailable")
	var counts := []
	for row in data.events:
		var text_id := int(row.text_id)
		if text_id >= library.strings.size() or not library.strings[text_id] is String: return fail("Radio text is outside the selected language")
		var lines: PackedStringArray = layout.wrap(library.strings[text_id])
		if not layout.error.is_empty(): return fail(layout.error)
		counts.append(lines.size())
	return configure(bindings, library, counts, campaign_cursor)

## The runner supplies the admitted identity plus an explicit condition_clock
## (integer milliseconds, allowed to reset). Optional predicate fields are hulls,
## maximum_hulls, activity, positions_z (actor-index dictionaries), phase,
## hostile_active, defeated_targets, targets, route_index, survivors,
## collected_cargo_quantity and mother_ship_locked. Missing facts cannot satisfy
## actor predicates. Binding copies the observation, including frozen snapshots.
func bind_context(observation: Dictionary) -> bool:
	error = ""
	if _identity.is_empty(): return fail("Configure radio before binding observations")
	for key in ["base_content_id", "binding_id"]:
		if observation.get(key) != _identity[key]: return fail("Radio observation belongs to another content identity")
	if not observation.get("campaign_cursor") is int or observation.campaign_cursor != _identity.get("campaign_cursor", 0): return fail("Radio observation belongs to another encounter")
	var problem := Condition.observation_error(observation, observation.get("condition_clock"))
	if not problem.is_empty(): return fail(problem)
	_observation = observation.duplicate(true)
	return true

## Display time stays monotonic even when the bound condition clock resets.
func step_context(display_elapsed_ms: Variant) -> Array:
	error = ""
	if _observation.is_empty():
		fail("Radio requires a bound observation")
		return []
	return _advance(display_elapsed_ms, _observation)

func step(elapsed_ms: Variant, actor_hulls: Dictionary, cinematic_phase: Variant) -> Array:
	if _requires_encounter_context:
		fail("Encounter radio requires its verified target context")
		return []
	return _step(elapsed_ms,actor_hulls,cinematic_phase,false)

func step_combat_training(elapsed_ms: Variant, combat: RefCounted) -> Array:
	error=""
	if _identity.get("campaign_cursor")!=7 or not combat is Combat:
		fail("Training radio requires its typed actor activity context")
		return []
	var state: Dictionary=combat.snapshot()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if state.get(key)!=_identity[key]:
			fail("Training radio belongs to another encounter")
			return []
	if not state.get("actors") is Array or state.actors.size()!=4:
		fail("Training radio requires the complete source actor list")
		return []
	var hostile_active:=false
	for id in 4:
		var actor: Dictionary=state.actors[id]
		if actor.get("actor_id")!=id or not actor.get("active") is bool or not actor.get("friendly") is bool:
			fail("Training radio lacks source actor activity or allegiance")
			return []
		# Scenery is absent from this typed NPC group. Hull and explosion mode
		# do not participate in source radio condition16.
		hostile_active=hostile_active or (actor.active and not actor.friendly)
	return _step(elapsed_ms,{},0,hostile_active)

## Read the native freighter, not a caller's victory flag. The mission owner
## separately verifies that this group retains its exact constructor generation.
func step_selected40(elapsed_ms: Variant, combat: RefCounted) -> Array:
	error=""
	if _identity.get("campaign_cursor")!=40 or not combat is Combat or combat.selected40_world_owner()==null:
		fail("Selected40 radio requires its native selected-world actor group");return []
	var body: Dictionary=combat.actor_snapshot(0)
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if body.get(key)!=_identity[key]:fail("Selected40 radio belongs to another encounter");return []
	if body.get("actor_id")!=0 or body.get("population_group")!="freighter" or not body.get("active") is bool or not Numbers.integer(body.get("max_hull"),1,2147483647) or not Numbers.integer(body.get("vitals",{}).get("hull"),0,2147483647):
		fail("Selected40 radio lacks its retained freighter vitals and activity");return []
	return _step(elapsed_ms,{0:int(body.vitals.hull)},0,false,0,{"maximum_hulls":{0:int(body.max_hull)},"activity":{0:body.active}})

## Condition26 uses the statistics pose and STRICT absolute Z proximity.
## Condition1 only tests current hull <= 0; the active wreck and completed
## breakup mode belong to different predicates. No caller supplies victory.
func step_selected41(elapsed_ms: Variant, combat: RefCounted) -> Array:
	error=""
	if _identity.get("campaign_cursor")!=41 or not combat is Combat or combat.selected41_world_owner()==null:
		fail("Source41 radio requires its native initialized actor group");return []
	var body: Dictionary=combat.actor_snapshot(0)
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if body.get(key)!=_identity[key]:fail("Source41 radio belongs to another encounter");return []
	if body.get("actor_id")!=0 or body.get("population_group")!="freighter" or not body.get("active") is bool or not Numbers.integer(body.get("vitals",{}).get("hull"),0,2147483647) or not load("res://src/simulation/npc_flight.gd").rigid_pose(body.get("pose")):
		fail("Source41 radio lacks the first retained target's hull, activity or statistics pose");return []
	return _step(elapsed_ms,{0:int(body.vitals.hull)},0,false,0,{"activity":{0:body.active},"positions_z":{0:body.pose.origin.z}})

func step_convoy(elapsed_ms: Variant, targets: Dictionary) -> Array:
	error=""
	if _identity.get("campaign_cursor")!=14:
		fail("Convoy radio requires its original dialogue")
		return []
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if targets.get(key)!=_identity[key]:
			fail("Convoy target list belongs to another encounter")
			return []
	var rows: Variant=targets.get("player_targets")
	if not rows is Array or rows.size()>4096:
		fail("Convoy radio requires the player's current target list")
		return []
	var defeated:=0
	for row in rows:
		if not row is Dictionary or not row.get("scenery") is bool:
			fail("Convoy target has no scenery classification")
			return []
		# Source condition20 skips scenery before reading hull. Activity and
		# hostility do not participate, and this is not the lifetime kill count.
		if row.scenery:continue
		if not Numbers.integer(row.get("current_hull"),-2147483648,2147483647):
			fail("Convoy target has no current hull")
			return []
		if row.current_hull<=0:defeated+=1
	return _step(elapsed_ms,{},0,false,defeated)

func step_alioth_attack(elapsed_ms: Variant, combat: Dictionary) -> Array:
	error=""
	if _identity.get("campaign_cursor")!=16:
		fail("Alioth radio requires its original encounter")
		return []
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if combat.get(key)!=_identity[key]:
			fail("Alioth actors belong to another encounter")
			return []
	var actors: Variant=combat.get("actors")
	var expected: Array=Alioth.VALUES.population.actors
	if not actors is Array or actors.size()!=expected.size():
		fail("Alioth radio requires its complete authored population")
		return []
	var hulls:={}
	for id in actors.size():
		var row: Variant=actors[id]
		if not row is Dictionary:
			fail("Alioth radio lost an authored actor")
			return []
		for key in ["actor_id","actor_kind","hull_catalogue_id"]:
			if row.get(key)!=int(expected[id][key]):
				fail("Alioth radio changed its authored actor membership")
				return []
		if not Numbers.integer(row.get("current_hull"),-2147483648,2147483647):
			fail("Alioth radio requires current actor hulls")
			return []
		hulls[id]=int(row.current_hull)
	# Condition9 observes the three freighter hulls. Visibility, activity,
	# retirement and the player's lifetime kill count are unrelated.
	return _step(elapsed_ms,hulls,0,false)

func step_kappa_rescue(elapsed_ms: Variant, targets: Dictionary) -> Array:
	error=""
	if _identity.get("campaign_cursor")!=21:
		fail("Kappa radio requires its original rescue declarations")
		return []
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if targets.get(key)!=_identity[key]:
			fail("Kappa targets belong to another encounter")
			return []
	var rows: Variant=targets.get("player_targets")
	var route_index: Variant=targets.get("route_index")
	if not rows is Array or rows.is_empty() or rows.size()>4096 or not Numbers.integer(route_index,-1,2):
		fail("Kappa radio requires the player's current targets and two-waypoint route")
		return []
	var hostile_active:=false
	var survivors:=0
	for row in rows:
		if not row is Dictionary:
			fail("Invalid Kappa radio target")
			return []
		for key in ["scenery","active","friendly","systems_disabled"]:
			if not row.get(key) is bool:
				fail("Kappa radio target lacks its current activity, allegiance or systems state")
				return []
		if not Numbers.integer(row.get("current_hull"),-2147483648,2147483647):
			fail("Kappa radio target lacks its current hull")
			return []
		if row.scenery:continue
		hostile_active=hostile_active or (row.active and not row.friendly)
		if row.current_hull>0:survivors+=1
	# The flight supplies the actual target order and projected NPC stun flag.
	# These predicates do not use lifetime kills or scanner selection.
	return _step(elapsed_ms,{},0,hostile_active,0,{"targets":rows,"route_index":int(route_index),"survivors":survivors})

func step_sahi(elapsed_ms: Variant, combat: Dictionary) -> Array:
	if _identity.get("campaign_cursor") != 24:
		fail("Sahi radio requires its original encounter declarations")
		return []
	if not bind_sahi_context(elapsed_ms, combat): return []
	return step_context(elapsed_ms)

## The stage clock can reset after event1 playback while radio display time
## remains monotonic. The flight owner supplies the current target lock and
## already-incremented stage clock; this scheduler owns neither value.
func step_probe(display_elapsed_ms: Variant, observation: Dictionary) -> Array:
	if _identity.get("campaign_cursor") != 29:
		fail("Probe radio requires its original six-row encounter")
		return []
	if not bind_sahi_context(display_elapsed_ms, observation): return []
	return step_context(display_elapsed_ms)

## Compatibility adapter for the existing recovery and subsequent probe owners.
## Their typed admission remains here until they supply runner observations.
## In particular the probe clock is its stage clock, NEVER world/display time.
func bind_sahi_context(display_elapsed_ms: Variant, observation: Dictionary) -> bool:
	error = ""
	if not _valid_display_clock(display_elapsed_ms): return false
	for key in ["base_content_id", "binding_id", "campaign_cursor"]:
		if observation.get(key) != _identity.get(key): return fail("Sahi radio observation belongs to another encounter")
	var context := _identity.duplicate()
	match _identity.get("campaign_cursor"):
		24:
			var recovery: Variant = observation.get("recovery", {})
			if not recovery is Dictionary: return fail("Sahi radio requires the current world recovery counter")
			var collected: Variant = recovery.get("accepted_quantity", 0)
			if not Numbers.integer(collected, 0, 2147483647): return fail("Sahi radio requires the accepted recovery quantity")
			context.condition_clock = display_elapsed_ms
			context.collected_cargo_quantity = int(collected)
		29:
			if not observation.get("campaign_cursor") is int: return fail("Probe radio requires its campaign cursor")
			var stage_elapsed: Variant = observation.get("stage_elapsed_ms")
			if not Condition.valid_clock(stage_elapsed) or not observation.get("mother_ship_locked") is bool: return fail("Probe radio requires its current stage clock and mother-ship lock")
			context.condition_clock = stage_elapsed
			context.mother_ship_locked = observation.mother_ship_locked
		_: return fail("Sahi radio requires its existing recovery or probe context")
	return bind_context(context)

func _valid_display_clock(elapsed_ms: Variant) -> bool:
	if _identity.is_empty() or not Condition.valid_clock(elapsed_ms) or elapsed_ms < _last_time: return fail("Invalid radio context or simulation time")
	return true

func _step(elapsed_ms: Variant, actor_hulls: Dictionary, cinematic_phase: Variant, hostile_active: bool, defeated_targets := 0, observations: Dictionary = {}) -> Array:
	error = ""
	var context := _condition_observation(elapsed_ms, actor_hulls, cinematic_phase, hostile_active, defeated_targets, observations)
	var problem := Condition.observation_error(context, context.condition_clock)
	if not problem.is_empty():
		fail(problem)
		return []
	return _advance(elapsed_ms, context)

func _advance(elapsed_ms: Variant, observation: Dictionary) -> Array:
	if not _valid_display_clock(elapsed_ms): return []
	_last_time = elapsed_ms
	var changes := []
	if _active < 0:
		for i in _started.size():
			if not _started[i] and Condition.evaluate(_definition.events[i], observation.condition_clock, observation, _started, _waypoint_indices, i):
				_active = i
				_started[i] = true
				_activated_at = elapsed_ms
				_visible = false
				changes.append({"kind": "started", "event": i})
				break
		return changes
	var timing: Dictionary = _definition.timing
	var visible_at := _activated_at + int(timing.display_delay_ms)
	if elapsed_ms <= visible_at: return changes
	if not _visible:
		_visible = true
		changes.append({"kind": "display", "event": _active, "text_id": int(_definition.events[_active].text_id)})
	var finish_at := visible_at + int(timing.base_duration_ms) + int(timing.per_line_ms) * int(_lines[_active])
	if elapsed_ms > finish_at:
		_finished[_active] = true
		changes.append({"kind": "finished", "event": _active})
		_active = -1
		_visible = false
	return changes

## Compatibility predicate entry; new owners bind_context and step_context.
## Explicit condition_clock (or the older stage_elapsed_ms) overrides elapsed_ms.
func eligible(row: Dictionary, elapsed_ms: Variant, hulls: Dictionary, phase: Variant, hostile_active: Variant = false, defeated_targets: Variant = 0, observations: Dictionary = {}, event_index: int = -1) -> bool:
	if not Condition.valid_row(row, _started.size()): return false
	var context := _condition_observation(elapsed_ms, hulls, phase, hostile_active, defeated_targets, observations)
	if not Condition.observation_error(context, context.condition_clock).is_empty(): return false
	return Condition.evaluate(row, context.condition_clock, context, _started, _waypoint_indices, event_index)

func _condition_observation(elapsed_ms: Variant, hulls: Dictionary, phase: Variant, hostile_active: Variant, defeated_targets: Variant, observations: Dictionary) -> Dictionary:
	var context := observations.duplicate()
	context.condition_clock = observations.get("condition_clock", observations.get("stage_elapsed_ms", elapsed_ms))
	context.hulls = hulls
	context.phase = phase
	context.hostile_active = hostile_active
	context.defeated_targets = defeated_targets
	# Preserve the old direct predicate call shape without actor-specific names
	# in the shared evaluator. Never edit a caller's nested/frozen dictionaries.
	if observations.has("freighter_active") and observations.get("activity", {}) is Dictionary:
		context.activity = observations.get("activity", {}).duplicate()
		context.activity[0] = observations.freighter_active
	if observations.has("freighter_z") and observations.get("positions_z", {}) is Dictionary:
		context.positions_z = observations.get("positions_z", {}).duplicate()
		context.positions_z[0] = observations.freighter_z
	return context

## Source row+0x30 and row+0x31 are distinct latches. A stage can inspect
## these after each radio tick without inferring playback from visibility.
func event_state(event_index: int) -> Dictionary:
	if _identity.is_empty() or event_index<0 or event_index>=_started.size():return {}
	return {"condition_satisfied":bool(_started[event_index]),"playback_finished":bool(_finished[event_index])}

func snapshot() -> Dictionary:
	if _identity.is_empty(): return {}
	var result := _identity.duplicate(true)
	result.merge({"started": _started.duplicate(), "finished": _finished.duplicate(), "active_event": _active, "visible": _visible})
	if _definition.events.any(func(row): return int(row.condition) == 25): result.waypoint_observations = _waypoint_indices.duplicate()
	# Presentation prepares speakers and line layout from recipe radio events.
	if _definition.get("scripted",false): result.scripted_events = _definition.events.duplicate(true)
	if _active >= 0:
		var row: Dictionary = _definition.events[_active]
		result["text_id"] = int(row.text_id)
		result["speaker_id"] = int(row.speaker_id)
		result["text"] = _text[int(row.text_id)]
	return result

## Skip (pause window): the first `count` lines count as started and finished
## at once; a line still playing among them stops.
func finish_through(count: int) -> void:
	for index in mini(count,_started.size()):
		_started[index]=true;_finished[index]=true
	if _active>=0 and _active<count:_active=-1;_visible=false

func fork_for_frame() -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy._definition = _definition.duplicate(true)
	copy._lines = _lines.duplicate()
	copy._text = _text.duplicate()
	copy._started = _started.duplicate()
	copy._finished = _finished.duplicate()
	copy._active = _active
	copy._visible = _visible
	copy._activated_at = _activated_at
	copy._last_time = _last_time
	copy._identity = _identity.duplicate(true)
	copy._waypoint_indices = _waypoint_indices.duplicate()
	copy._requires_encounter_context=_requires_encounter_context
	copy._observation = _observation.duplicate(true)
	return copy

func fail(message: String) -> bool:
	error = message
	return false
