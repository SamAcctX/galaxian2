extends RefCounted
## Source declarations and construction recipes. This does not admit travel.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Previous=preload("res://src/content/bakka_return_definitions.gd")
const VALUES = {"scope":"dekato_convoy38_declarations","mission":{"campaign_cursor":38,"kind":4,"station_id":22,"story":true,"reward":0,"bonus":0,"source_parameter":0,"system_id":4,"briefing_events":[{"speaker_id":0,"text_id":2017,"voice_event_id":184}],"result_events":[{"speaker_id":0,"text_id":2019,"voice_event_id":399},{"speaker_id":1,"text_id":2020,"voice_event_id":400}]},"population":{"actor_count":7,"freighter_count":2,"freighter_actor_kind":2,"freighter_subtype":1,"freighter_hull_catalogue_id":15,"freighter_forced_friendly":true,"freighter_position_bound":20000,"freighter_position_offset":-10000,"escort_actor_kind":3,"escort_subtype":0,"escort_hull_picker_faction":3,"escort_forced_hostile":true,"path_points":[[90000,10000,80000]]},"objectives":{"actor_count":7,"destroyed_mode":4,"success":{"kind":18,"first_actor":2,"end_actor":7,"requires_all":true},"failure":{"kind":7,"first_actor":0,"end_actor":2,"requires_all":true},"filters_actor_kind":false,"requires_player_kill_majority":false},"radio_events":[{"speaker_id":21,"text_id":2018,"voice_event_id":523,"condition_kind":5,"condition_value":15000}],"next_mission":{"campaign_cursor":39,"kind":11,"station_id":30,"story":true,"reward":0,"bonus":0,"source_parameter":0}}
const MAC_VALUES = {"scope":"dekato_convoy38_declarations","mission":{"campaign_cursor":38,"kind":4,"station_id":22,"story":true,"reward":0,"bonus":0,"source_parameter":0,"system_id":4,"briefing_events":[{"speaker_id":0,"text_id":2003,"voice_event_id":184}],"result_events":[{"speaker_id":0,"text_id":2005,"voice_event_id":399},{"speaker_id":1,"text_id":2006,"voice_event_id":400}]},"population":{"actor_count":7,"freighter_count":2,"freighter_actor_kind":2,"freighter_subtype":1,"freighter_hull_catalogue_id":15,"freighter_forced_friendly":true,"freighter_position_bound":20000,"freighter_position_offset":-10000,"escort_actor_kind":3,"escort_subtype":0,"escort_hull_picker_faction":3,"escort_forced_hostile":true,"path_points":[[90000,10000,80000]]},"objectives":{"actor_count":7,"destroyed_mode":4,"success":{"kind":18,"first_actor":2,"end_actor":7,"requires_all":true},"failure":{"kind":7,"first_actor":0,"end_actor":2,"requires_all":true},"filters_actor_kind":false,"requires_player_kill_majority":false},"radio_events":[{"speaker_id":21,"text_id":2004,"voice_event_id":523,"condition_kind":5,"condition_value":15000}],"next_mission":{"campaign_cursor":39,"kind":11,"station_id":30,"story":true,"reward":0,"bonus":0,"source_parameter":0}}
const SPANS = {"dekato_factory38_entry":[872186,4],"dekato_factory38":[863454,38],"dekato_factory39_entry":[872190,4],"dekato_factory39":[863497,38],"dekato_cast38_entry":[51746,4],"dekato_cast38":[9497,754],"dekato_path":[1554674,12],"dekato_condition_dispatch":[481528,60],"dekato_condition7_entry":[482602,4],"dekato_condition18_entry":[482646,4],"dekato_condition7_all_prefix":[481588,58],"dekato_condition18_all_range":[481804,63],"dekato_retired_mode":[-77838,16],"dekato_range_constructor":[481170,42],"dekato_prefix_constructor":[481078,45],"dekato_radio38_entry":[104638,4],"dekato_radio38":[86134,128],"dekato_brief_count":[1529738,4],"dekato_brief_pairs":[1531138,8],"dekato_result_count":[1530394,4],"dekato_result_pairs":[1523370,16],"dekato_voice184":[1535386,8],"dekato_voice399":[1537106,8],"dekato_voice400":[1537114,8],"dekato_voice523":[1538098,8]}
const MAC_SPANS = {"dekato_factory38_entry":[871554,4],"dekato_factory38":[862822,38],"dekato_factory39_entry":[871558,4],"dekato_factory39":[862865,38],"dekato_cast38_entry":[51746,4],"dekato_cast38":[9497,754],"dekato_path":[1579610,12],"dekato_condition_dispatch":[481000,60],"dekato_condition7_entry":[482074,4],"dekato_condition18_entry":[482118,4],"dekato_condition7_all_prefix":[481060,58],"dekato_condition18_all_range":[481276,63],"dekato_retired_mode":[-77838,16],"dekato_range_constructor":[480642,42],"dekato_prefix_constructor":[480550,45],"dekato_radio38_entry":[104638,4],"dekato_radio38":[86134,128],"dekato_brief_count":[1554754,4],"dekato_brief_pairs":[1556138,8],"dekato_result_count":[1555410,4],"dekato_result_pairs":[1548386,16],"dekato_voice184":[1560322,8],"dekato_voice399":[1562042,8],"dekato_voice400":[1562050,8],"dekato_voice523":[1563034,8]}

static func parameters(data: Variant) -> bool:
	return Equal.equal_value(data,VALUES) or Equal.equal_value(data,MAC_VALUES)

## Imported optional data or an explicitly verified same-source supplement.
## This accessor never adds a key to the original imported travel dictionary.
static func declarations(bindings: RefCounted) -> Dictionary:
	if bindings==null:return {}
	var direct: Variant=bindings.mido_travel.get("dekato_convoy")
	if direct is Dictionary:return direct
	return bindings.dekato_source_declarations()

static func available(bindings: RefCounted) -> bool:
	var data:=declarations(bindings)
	if not parameters(data):return false
	var expected: Dictionary=Previous.VALUES if Equal.equal_value(data,VALUES) else Previous.MAC_VALUES
	return Equal.equal_value(bindings.mido_travel.get("bakka_return"),expected)

## The retained original202 career explicitly opts into its same-source delta.
## A declaration-only component pack does not change the selected save or route.
static func source_arrival_available(bindings: RefCounted) -> bool:
	return available(bindings) and not bindings.dekato_source_receipt().is_empty()

## A saved station is not permission to construct a later flight. The original
## kind11 permits returning to Dekato while its distinct station30 visit waits.
static func station_supported(bindings: RefCounted,cursor: Variant,station_id: Variant) -> bool:
	return source_arrival_available(bindings) and cursor is int and cursor==int(declarations(bindings).next_mission.campaign_cursor) and station_id is int and station_id==int(declarations(bindings).mission.station_id)

static func source_receipt_matches(bindings: RefCounted,value: Variant) -> bool:
	if not source_arrival_available(bindings) or not value is Dictionary:return false
	var expected: Dictionary=bindings.dekato_source_receipt()
	if value.size()!=expected.size():return false
	for key in expected:
		if not value.get(key) is String or value[key]!=expected[key]:return false
	return true

static func station_mission(bindings: RefCounted,cursor: Variant,station_id: Variant,mission: Variant) -> bool:
	if not station_supported(bindings,cursor,station_id) or not mission is Dictionary or mission.size()!=5:return false
	var next: Dictionary=declarations(bindings).next_mission
	for key in ["kind","station_id","reward","bonus","source_parameter"]:
		if not mission.get(key) is int or mission[key]!=int(next[key]):return false
	return true

static func docking(bindings: RefCounted) -> Dictionary:
	if not source_arrival_available(bindings) or not load("res://src/content/station_return_definitions.gd").parameters(bindings.station_return):return {}
	return docking_values()

static func docking_values() -> Dictionary:
	var result: Dictionary=load("res://src/content/free_flight_definitions.gd")._docking_values(22,4,39)
	result.dekato_return=true;result.contract_station=false
	return result

## Selection identifies an already retained story; it does not authorize travel.
static func selected(bindings: RefCounted,cursor: Variant,mission: Variant,station_id: Variant) -> bool:
	if not available(bindings) or not cursor is int or not station_id is int:return false
	var source: Dictionary=declarations(bindings).mission
	if cursor!=int(source.campaign_cursor) or station_id!=int(source.station_id):return false
	var expected:={}
	for key in ["kind","station_id","reward","bonus","source_parameter"]:expected[key]=int(source[key])
	return mission==expected

static func context_valid(bindings: RefCounted,context: Dictionary) -> bool:
	if not available(bindings):return false
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key):return false
	var mission: Dictionary=declarations(bindings).mission
	for key in ["campaign_cursor","station_id","system_id"]:
		if not context.get(key) is int or context[key]!=int(mission[key]):return false
	if not context.get("mission_kind") is int or context.mission_kind!=int(mission.kind):return false
	if context.get("mission_story")!=true or context.get("mission_completed")!=false or context.get("mission_failed")!=false:return false
	return load("res://src/content/opening_definitions.gd").integer(context.get("rank"),0,20) and context.get("difficulty") in [0.5,1.0]

static func construction_recipe(bindings: RefCounted,context: Dictionary) -> Dictionary:
	if not context_valid(bindings,context):return {}
	var population=load("res://src/content/free_population_definitions.gd")
	var convoy=load("res://src/content/convoy_ship_definitions.gd")
	if not population.available(bindings) or not convoy.available(bindings) or not load("res://src/content/early_contract_definitions.gd").encounter_parameters(bindings.early_contracts):return {}
	var data: Dictionary=declarations(bindings).population.duplicate(true)
	data.freighter_assembly=population.freighter_assembly(bindings,int(data.freighter_actor_kind)).duplicate(true)
	if data.freighter_assembly.is_empty() or population.freighter_hull(bindings,int(data.freighter_actor_kind))!=int(data.freighter_hull_catalogue_id):return {}
	data.freighter_cargo=bindings.ambient_population.freighter.duplicate(true)
	data.hulls=bindings.early_contracts.encounter_construction.hulls.duplicate(true)
	# The mission calls the same byte+0x18c setter guarded by convoy_ship:
	# App 0x154326 / older Mac 0x1528da, with false, before relocation.
	# Reuse that source-bound cruise policy, not an unrelated world/AI flag.
	data.freighter_cruise_enabled=bindings.mido_travel.convoy_ship.motion.initial_cruise_enabled
	data.context=context.duplicate(true)
	return data

## Presentation and selected-world construction only. Ordinary player entry,
## navigation and station transactions do not acquire this capability.
static func selected_location(bindings: RefCounted,station_id: int,system_id: int) -> bool:
	return available(bindings) and station_id==int(declarations(bindings).mission.station_id) and system_id==int(declarations(bindings).mission.system_id)

## Shared particles and presentation observe the retained native cast; they
## must not confuse an ordinary seven-ship population with this story world.
static func combat_population(bindings: RefCounted,combat: Dictionary) -> bool:
	var context: Variant=combat.get("dekato_context")
	if not context is Dictionary or not context_valid(bindings,context) or combat.get("campaign_cursor")!=context.campaign_cursor:return false
	for key in ["base_content_id","binding_id"]:
		if combat.get(key)!=bindings.get(key):return false
	var actors: Variant=combat.get("actors")
	var source: Dictionary=declarations(bindings).population
	var hulls: Dictionary=bindings.early_contracts.encounter_construction.hulls
	if not actors is Array or actors.size()!=int(source.actor_count):return false
	for id in actors.size():
		var actor: Variant=actors[id];var freight: bool=id<int(source.freighter_count)
		if not actor is Dictionary or actor.get("actor_id")!=id or not actor.get("authored_story",false):return false
		for key in ["base_content_id","binding_id","campaign_cursor","station_id"]:
			if actor.get(key)!=context[key]:return false
		if actor.get("actor_kind")!=int(source.freighter_actor_kind if freight else source.escort_actor_kind) or actor.get("subtype")!=int(source.freighter_subtype if freight else source.escort_subtype):return false
		if actor.get("population_group")!=("freighter" if freight else "fighter"):return false
		var hull: Variant=actor.get("hull_catalogue_id")
		if not hull is int:return false
		if freight:
			if hull!=int(source.freighter_hull_catalogue_id):return false
		else:
			if hull<0 or hull>=int(hulls.draw_bound) or hull>=hulls.factions.size() or int(hulls.factions[hull])!=int(source.escort_hull_picker_faction):return false
			if hull<=int(hulls.mask_limit) and (int(hulls.excluded_mask)&(1<<hull))!=0:return false
	return true

static func flight(bindings: RefCounted,context: Dictionary) -> Dictionary:
	if not context_valid(bindings,context):return {}
	var result: Dictionary=bindings.first_flight.duplicate(true)
	result.scope="dekato_selected_flight"
	for key in ["campaign_cursor","station_id","system_id","mission_kind"]:result[key]=context[key]
	result.erase("actor_count")
	return result
