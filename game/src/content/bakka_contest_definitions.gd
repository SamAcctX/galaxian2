extends RefCounted
## Partial contest content, not authorization to enter or complete the mission.
## Construction is available separately from flight and career progression.
const Numbers=preload("res://src/content/opening_definitions.gd")
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const VALUES = {"scope":"bakka_pirate_contest36","mission":{"campaign_cursor":36,"kind":12,"station_id":27,"system_id":5,"story":true,"reward":0,"bonus":0,"briefing_events":[{"speaker_id":7,"text_id":2005,"voice_event_id":182},{"speaker_id":0,"text_id":2006,"voice_event_id":183}]},"encounter_kind":12,"objectives":{"pirate_kind":18,"challenge_success_kind":20,"challenge_failure_kind":21,"challenge_first_actor":1,"challenge_actor_kind":8,"destroyed_mode":4,"challenge_requires_player_majority":true},"result_events":[{"speaker_id":7,"text_id":2007,"voice_event_id":389},{"speaker_id":0,"text_id":2008,"voice_event_id":390}],"authored_radio_events":[],"population":{"actor_count":8,"subtype":0,"pirate_actor_kind":8,"rival_actor_id":0,"rival_actor_kind":1,"rival_hull_catalogue_id":9,"rival_name_text_id":1593,"rival_position_bound":1400,"rival_position_offset":-700,"rival_position_z_offset":1000.0,"rival_base_speed":3.0,"rival_speed":3.0,"rival_current_hull_override":9999999,"rival_friendly":true,"rival_retains_cargo":false,"rival_retains_generated_route":false,"pirate_mode":5,"pirate_active":false,"pirate_targeting_blocked":true,"pirates_retain_cargo_and_routes":true,"route_initial_index":0,"route_loop":false,"waypoints":[[110000,-10000,-80000],[70000,0,-100000],[-100000,10000,-80000],[-130000,-50000,-150000]],"condition_first_actor":1,"condition_end_actor":8}}
const MAC_VALUES = {"scope":"bakka_pirate_contest36","mission":{"campaign_cursor":36,"kind":12,"station_id":27,"system_id":5,"story":true,"reward":0,"bonus":0,"briefing_events":[{"speaker_id":7,"text_id":1991,"voice_event_id":182},{"speaker_id":0,"text_id":1992,"voice_event_id":183}]},"encounter_kind":12,"objectives":{"pirate_kind":18,"challenge_success_kind":20,"challenge_failure_kind":21,"challenge_first_actor":1,"challenge_actor_kind":8,"destroyed_mode":4,"challenge_requires_player_majority":true},"result_events":[{"speaker_id":7,"text_id":1993,"voice_event_id":389},{"speaker_id":0,"text_id":1994,"voice_event_id":390}],"authored_radio_events":[],"population":{"actor_count":8,"subtype":0,"pirate_actor_kind":8,"rival_actor_id":0,"rival_actor_kind":1,"rival_hull_catalogue_id":9,"rival_name_text_id":1585,"rival_position_bound":1400,"rival_position_offset":-700,"rival_position_z_offset":1000.0,"rival_base_speed":3.0,"rival_speed":3.0,"rival_current_hull_override":9999999,"rival_friendly":true,"rival_retains_cargo":false,"rival_retains_generated_route":false,"pirate_mode":5,"pirate_active":false,"pirate_targeting_blocked":true,"pirates_retain_cargo_and_routes":true,"route_initial_index":0,"route_loop":false,"waypoints":[[110000,-10000,-80000],[70000,0,-100000],[-100000,10000,-80000],[-130000,-50000,-150000]],"condition_first_actor":1,"condition_end_actor":8}}
const SPANS = {"bakka_population36_dispatch":[1233,64],"bakka_population_gate":[-42341,312],"bakka_defeat_conditions":[481528,1170],"bakka_result36_count":[1530386,4],"bakka_result36_pairs":[1523290,16],"bakka_result36_voices":[1537026,16],"bakka_radio36_entry":[104630,4],"bakka_population36_entry":[51738,4],"bakka_population36_case":[8434,998],"bakka_population36_path":[1554626,48],"bakka_population36_speed":[1531910,4],"bakka_population36_z":[1531930,4]}
const MAC_SPANS = {"bakka_population36_dispatch":[1233,64],"bakka_population_gate":[-42341,312],"bakka_defeat_conditions":[481000,1170],"bakka_population36_entry":[51738,4],"bakka_population36_case":[8434,998],"bakka_population36_path":[1579562,48],"bakka_population36_speed":[1556910,4],"bakka_population36_z":[1556930,4],"bakka_result36_count":[1555402,4],"bakka_result36_pairs":[1548306,16],"bakka_result36_voices":[1561962,16],"bakka_radio36_entry":[104630,4]}

static func parameters(data: Variant) -> bool:
	return Equal.equal_value(data,VALUES) or Equal.equal_value(data,MAC_VALUES)

static func available(bindings: RefCounted) -> bool:
	return bindings!=null and parameters(bindings.mido_travel.get("bakka_contest"))

## Select the native constructor, without granting the navigation capability.
static func selected(bindings: RefCounted,cursor: Variant,mission: Dictionary,station_id: Variant) -> bool:
	if not available(bindings) or not cursor is int or not station_id is int:return false
	var source: Dictionary=bindings.mido_travel.bakka_contest.mission
	return cursor==int(source.campaign_cursor) and station_id==int(source.station_id) and mission=={"kind":int(source.kind),"station_id":int(source.station_id),"reward":int(source.reward),"bonus":int(source.bonus),"source_parameter":0}

static func context_valid(bindings: RefCounted,context: Dictionary) -> bool:
	if not available(bindings):return false
	var mission: Dictionary=bindings.mido_travel.bakka_contest.mission
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key):return false
	for key in ["campaign_cursor","station_id","system_id"]:
		if not context.get(key) is int or context[key]!=int(mission[key]):return false
	return context.get("mission_kind") is int and context.get("mission_kind")==int(mission.kind) and context.get("mission_story")==true and context.get("mission_completed")==false and Numbers.integer(context.get("rank"),0,20) and context.get("difficulty") in [0.5,1.0]

static func construction_recipe(bindings: RefCounted,context: Dictionary,player_position: Vector3) -> Dictionary:
	# Internal factory data, not an accepted lounge contract. The entry owns
	# validation of the context and shared construction dependencies.
	var source: Dictionary=bindings.mido_travel.bakka_contest.population
	var recipe: Dictionary=bindings.early_contracts.encounter_construction.duplicate(true)
	recipe.bakka=true
	recipe.actor_count=int(source.actor_count)
	recipe.campaign_cursor=context.campaign_cursor
	recipe.context=context.duplicate(true)
	recipe.context.mission={"kind":context.mission_kind,"story":true}
	recipe.player_position=player_position
	recipe.authored_path=source.waypoints.map(func(point):return Vector3(point[0],point[1],point[2]))
	recipe.rival_faction=int(source.rival_actor_kind)
	recipe.rival_hull=int(source.rival_hull_catalogue_id)
	recipe.rival_name_text_id=int(source.rival_name_text_id)
	recipe.pirate_actor_kind=int(source.pirate_actor_kind)
	for key in ["mode","active","targeting_blocked"]:recipe.pirate[key]=source["pirate_"+key]
	for key in ["position_bound","position_offset","position_z_offset","base_speed","speed","current_hull_override","friendly"]:
		recipe.challenge[key]=source["rival_"+key]
	return recipe
