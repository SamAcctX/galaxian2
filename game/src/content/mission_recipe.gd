extends RefCounted
## Adapt imported authored data into recipes. No resolved actors or live state
## are stored here; the existing native factory still constructs each cast.
const Convoy=preload("res://src/content/dekato_convoy_definitions.gd")
const Story=preload("res://src/content/full_hold_story_definitions.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Ambush=preload("res://src/content/selected41_population_definitions.gd")

## The entry owner has already admitted the retained side job. Cast counts and
## result conditions share this recipe; downstream owners do not infer them.
static func from_contract(bindings: RefCounted,context: Dictionary,loadout: Dictionary) -> Dictionary:
	var rules: Dictionary=bindings.early_contracts.encounter_construction
	var mission: Dictionary=context.mission
	var scaled:=Vitals.single(float(mission.difficulty)/float(rules.difficulty_divisor))
	var count:=0
	match int(mission.kind):
		4:
			var base:=int(Vitals.single(scaled*float(rules.pirate.count_multiplier)))+int(rules.pirate.count_offset)
			count=int(Vitals.single(base+Vitals.single(base*Vitals.single(float(context.difficulty)+float(rules.pirate.game_difficulty_offset)))))
		7:count=int(Vitals.single(scaled*float(rules.junk.debris_count_multiplier)))+int(rules.junk.debris_count_offset)
		12:
			var base:=int(Vitals.single(scaled*float(rules.challenge.count_multiplier)))
			count=base+(int(rules.challenge.count_odd_offset) if (base+int(rules.challenge.count_odd_offset))%2 else int(rules.challenge.count_even_offset))+1
	var success:={"kind":18,"first_actor":0,"end_actor":count}
	var failure:={"kind":"never"}
	var periodic:={"kind":"never"}
	match int(mission.kind):
		0:success={"kind":"never"}
		7:
			success={"kind":7,"end_actor":count}
			periodic={"kind":"elapsed","after_ms":int(bindings.early_contracts.junk_lifecycle.deadline_milliseconds)}
		12:
			var objectives: Dictionary=bindings.early_contracts.ship_lifecycle.objectives.duplicate(true)
			success={"kind":int(objectives.challenge_success_kind),"rules":objectives}
			failure={"kind":int(objectives.challenge_failure_kind),"rules":objectives}
	return {"track":"side_job","cursor":context.campaign_cursor,"station_id":context.station_id,"system_id":loadout.system_id,
		"mission":mission.duplicate(true),"entry":"ordinary_flight","world":{"station":true,"portal":true,"asteroid_field":true},
		"cast":{"kind":"contract","actor_count":count,"operations":rules.duplicate(true)},"briefing":[],"radio":[],"sequences":[],
		"result":{"success":success,"failure":failure,"periodic_failure":periodic,"actor_count":count,
			"retire_failure":true,"freeze_clock_on_result":true,"reset_while_blocked":false,"policy":bindings.early_contracts.flight_results.duplicate(true)}}

static func select(bindings: RefCounted,cursor: Variant) -> Dictionary:
	if bindings==null or not cursor is int:return {}
	var source: Dictionary=Convoy.declarations(bindings)
	if Convoy.available(bindings) and int(source.mission.campaign_cursor)==cursor:
		return from_convoy(bindings,source)
	if Ambush.available(bindings) and int(Ambush.VALUES.campaign_cursor)==cursor:
		return from_ambush(bindings)
	if Ambush.available(bindings) and int(Ambush.VALUES.campaign_cursor)+1==cursor:
		return from_ambush_escape(bindings)
	return {}

static func from_ambush(bindings: RefCounted) -> Dictionary:
	var source:=Ambush.mission(bindings)
	if source.is_empty():return {}
	var particles:=ambush_particles(bindings)
	if particles.size()!=2:return {}
	var appstore: bool=Ambush.Previous.Equal.equal_value(Ambush.Previous.Nehma.declarations(bindings),Ambush.Previous.Nehma.VALUES)
	var first_text:=2038 if appstore else 2024
	var briefing_events:=[];var result_events:=[]
	var briefing_speakers:=[0,7,0];var result_speakers:=[0,7,0,7,0]
	for index in briefing_speakers.size():briefing_events.append({"speaker_id":briefing_speakers[index],"text_id":first_text+index,"voice_event_id":185+index})
	for index in result_speakers.size():result_events.append({"speaker_id":result_speakers[index],"text_id":first_text+9+index,"voice_event_id":416+index})
	return {"cursor":int(source.campaign_cursor),"station_id":int(source.station_id),"system_id":int(Ambush.VALUES.system_id),
		"mission":mission_values(source),"next_cursor":int(source.campaign_cursor)+1,
		"next_mission":{"kind":160,"station_id":-1,"reward":0,"bonus":0,"source_parameter":0},
		"entry":"retained_portal_transition","world":{"station":false,"portal":true,"asteroid_field":true,"void_environment":true},
		"cast":{"kind":"initialized_cast","operations":Ambush.VALUES.duplicate(true)},
		"briefing":briefing_events,"radio":Ambush.radio(bindings),
		"result":{"success":{"kind":25,"sequence_flag":"sequence_complete"},"failure":{"kind":7,"end_actor":1},
			"actor_count":int(Ambush.VALUES.actor_count),"lines":result_events,"policy":bindings.early_contracts.flight_results.duplicate(true)},
		"sequences":["freighter_ambush"],"entry_release_ms":7001,"docking":{},
		"continuation":{"kind":"retained_world"},
		"portal_policy":{"initially_visible":false,"unauthorized_exit":"destroy_player"},
		"sequence_models":[{"model_id":14285,"face_forward":false,"forward_offset":0},
			{"model_id":14286,"face_forward":true,"forward_offset":10000},{"model_id":14287,"face_forward":true,"forward_offset":0}],
		"escape_sounds":[153,154],
		"sequence_sounds":[155,156],
		"actor_engines":[{"actor_id":0,"sound_id":47}],
		"sequence_particles":particles,
		"receipt_key":"nehma_source_receipt","source_receipt":bindings.nehma_source_receipt().duplicate(true)}

## Both authored variants use the general manager's imported explosion art.
## Register once on the physical actor root; the native hook owns enablement.
static func ambush_particles(bindings: RefCounted) -> Array:
	var smoke:={};var fire:={}
	for row in bindings.damage_particles.get("presets",[]):
		if int(row.preset_id)==15:smoke=row.duplicate(true)
	for row in bindings.full_hold_particles.get("presets",[]):
		if int(row.preset_id)==9:fire=row.duplicate(true)
	if smoke.is_empty() or fire.is_empty():return []
	smoke.merge({"preset_id":40,"material_id":fire.material_id,"size":1800.0,"size_jitter":300,"local_offset_z":500.0},true)
	fire.merge({"preset_id":41,"capacity":1000,"lifetime_ms":1000,"emission_per_second":9.0,
		"size":4000.0,"size_jitter":2000,"scatter_xz":1000,"scatter_y":800,
		"local_offset_z":-4000.0,"local_offset_z_jitter":8000.0},true)
	return [{"actor_id":0,"kind":"fire","preset":smoke,"initial_emitting":false,"fade_in_rgb":true},
		{"actor_id":0,"kind":"fire","preset":fire,"initial_emitting":false,"fade_in_rgb":true}]

## The ambush result changes the objective, not the world. Its retained radio
## and freighter remain authoritative until the escape and normal-space return.
static func from_ambush_escape(bindings: RefCounted) -> Dictionary:
	var previous:=from_ambush(bindings)
	if previous.is_empty():return {}
	var recipe:=previous.duplicate(true)
	recipe.cursor=previous.next_cursor;recipe.mission=previous.next_mission.duplicate(true)
	recipe.next_cursor=recipe.cursor+1
	recipe.next_mission={"kind":11,"station_id":10,"reward":0,"bonus":0,"source_parameter":0}
	recipe.entry="retained_world";recipe.retained_world_cursor=previous.cursor
	recipe.briefing=[];recipe.entry_release_ms=0;recipe.sequences=["freighter_escape"]
	recipe.continuation={"kind":"station","station_id":10}
	recipe.world_return={"kind":"normal_space","location":"retained_entry"}
	recipe.result.success={"kind":"world_elapsed","feature":"normal_space","after_ms":10000,"different_station":-1}
	recipe.result.failure={"kind":"never"}
	recipe.result.lines=[]
	var speakers:=[0,0,6,0]
	for index in speakers.size():
		recipe.result.lines.append({"speaker_id":speakers[index],"text_id":int(previous.briefing[0].text_id)+16+index,"voice_event_id":421+index})
	return recipe

static func from_convoy(bindings: RefCounted,source: Dictionary) -> Dictionary:
	if not Convoy.parameters(source):return {}
	var mission: Dictionary=source.mission
	var continuation: Dictionary=source.next_mission
	return {"cursor":int(mission.campaign_cursor),"station_id":int(mission.station_id),
		"system_id":int(mission.system_id),"mission":mission_values(mission),
		"next_cursor":int(continuation.campaign_cursor),"next_mission":mission_values(continuation),
		"entry":"ordinary_arrival","world":{"station":true,"portal":true,"asteroid_field":true},
		"cast":{"kind":"convoy","operations":source.population.duplicate(true)},
		"briefing":mission.briefing_events.duplicate(true),"radio":source.radio_events.duplicate(true),
		"result":{"success":source.objectives.success.duplicate(true),"failure":source.objectives.failure.duplicate(true),
			"actor_count":int(source.objectives.actor_count),"lines":mission.result_events.duplicate(true),
			"policy":bindings.early_contracts.flight_results.duplicate(true)},
		"entry_release_ms":int(bindings.mido_travel.free_flight.launch_clear_after_ms)+1,
		"docking":Convoy.docking(bindings),"receipt_key":"dekato_source_receipt",
		"source_receipt":bindings.dekato_source_receipt().duplicate(true)}

static func mission_values(value: Dictionary) -> Dictionary:
	var result:={}
	for key in ["kind","station_id","reward","bonus","source_parameter"]:result[key]=int(value[key])
	return result

static func briefing(bindings: RefCounted,recipe: Dictionary) -> Dictionary:
	var result:=Story.briefing(bindings,2)
	if result.is_empty() or recipe.is_empty():return {}
	result.campaign_cursor=recipe.cursor;result.mission_kind=recipe.mission.kind
	result.events=recipe.briefing.duplicate(true);result.entry_release_ms=recipe.entry_release_ms
	return result

static func objective(bindings: RefCounted,recipe: Dictionary) -> Dictionary:
	var result:=Story.objective(bindings,2)
	if result.is_empty() or recipe.is_empty():return {}
	result.campaign_cursor=recipe.cursor;result.mission_kind=recipe.mission.kind;result.station_id=recipe.station_id
	result.required_cargo=0;result.events=recipe.result.lines.duplicate(true);result.runner_controlled=true
	result.cursor_after_acknowledgement=recipe.next_cursor;result.next_kind=recipe.next_mission.kind
	result.next_mission=recipe.next_mission.duplicate(true);result.mission=recipe.mission.duplicate(true)
	result.result_modes=recipe.result.policy.duplicate(true)
	result.campaign_failure=bindings.mido_travel.kappa_outcome.failure.duplicate(true)
	return result
