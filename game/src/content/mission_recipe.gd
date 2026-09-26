extends RefCounted
## Adapt imported authored data into recipes. No resolved actors or live state
## are stored here; the existing native factory still constructs each cast.
const Convoy=preload("res://src/content/dekato_convoy_definitions.gd")
const Story=preload("res://src/content/full_hold_story_definitions.gd")
const Ambush=preload("res://src/content/selected41_population_definitions.gd")

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
		"receipt_key":"nehma_source_receipt","source_receipt":bindings.nehma_source_receipt().duplicate(true)}

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
