extends RefCounted
## Preparing a station conversation never authorizes its journey or successor.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Previous=preload("res://src/content/dekato_convoy_definitions.gd")
const Visit=preload("res://src/content/post_probe_visit_definitions.gd")
const VALUES = {"scope":"nehma_station_return39","mission":{"campaign_cursor":39,"kind":11,"station_id":30,"story":true,"reward":0,"bonus":0,"source_parameter":0,"system_id":2,"briefing_events":[],"result_events":[{"speaker_id":1,"text_id":2021,"voice_event_id":401},{"speaker_id":0,"text_id":2022,"voice_event_id":402},{"speaker_id":1,"text_id":2023,"voice_event_id":403},{"speaker_id":0,"text_id":2024,"voice_event_id":404},{"speaker_id":1,"text_id":2025,"voice_event_id":405},{"speaker_id":0,"text_id":2026,"voice_event_id":406},{"speaker_id":1,"text_id":2027,"voice_event_id":407},{"speaker_id":1,"text_id":2028,"voice_event_id":408},{"speaker_id":1,"text_id":2029,"voice_event_id":409},{"speaker_id":0,"text_id":2030,"voice_event_id":410}],"completion":{"requires_landed_target":true,"advance_on_final_next_to_cursor":40,"reward_credits":0}},"next_mission":{"campaign_cursor":40,"kind":161,"station_id":-1,"story":true,"reward":0,"bonus":0,"source_parameter":0}}
const MAC_VALUES = {"scope":"nehma_station_return39","mission":{"campaign_cursor":39,"kind":11,"station_id":30,"story":true,"reward":0,"bonus":0,"source_parameter":0,"system_id":2,"briefing_events":[],"result_events":[{"speaker_id":1,"text_id":2007,"voice_event_id":401},{"speaker_id":0,"text_id":2008,"voice_event_id":402},{"speaker_id":1,"text_id":2009,"voice_event_id":403},{"speaker_id":0,"text_id":2010,"voice_event_id":404},{"speaker_id":1,"text_id":2011,"voice_event_id":405},{"speaker_id":0,"text_id":2012,"voice_event_id":406},{"speaker_id":1,"text_id":2013,"voice_event_id":407},{"speaker_id":1,"text_id":2014,"voice_event_id":408},{"speaker_id":1,"text_id":2015,"voice_event_id":409},{"speaker_id":0,"text_id":2016,"voice_event_id":410}],"completion":{"requires_landed_target":true,"advance_on_final_next_to_cursor":40,"reward_credits":0}},"next_mission":{"campaign_cursor":40,"kind":161,"station_id":-1,"story":true,"reward":0,"bonus":0,"source_parameter":0}}
const SPANS = {"nehma39_factory39_entry":[872190,4],"nehma39_factory39":[863497,38],"nehma39_factory40_entry":[872194,4],"nehma39_factory40":[863540,38],"nehma39_brief39_count":[1529742,4],"nehma39_brief40_count":[1529746,4],"nehma39_result39_count":[1530398,4],"nehma39_result40_count":[1530402,4],"nehma39_result39_pairs":[1523386,80],"nehma39_voice401":[1537122,8],"nehma39_voice402":[1537130,8],"nehma39_voice403":[1537138,8],"nehma39_voice404":[1537146,8],"nehma39_voice405":[1537154,8],"nehma39_voice406":[1537162,8],"nehma39_voice407":[1537170,8],"nehma39_voice408":[1537178,8],"nehma39_voice409":[1537186,8],"nehma39_voice410":[1537194,8],"nehma39_radio39_entry":[104642,4],"nehma39_final_next_dispatch":[430231,992],"nehma39_final_next_retire":[431930,209]}
const MAC_SPANS = {"nehma39_factory39_entry":[871558,4],"nehma39_factory39":[862865,38],"nehma39_factory40_entry":[871562,4],"nehma39_factory40":[862908,38],"nehma39_brief39_count":[1554758,4],"nehma39_brief40_count":[1554762,4],"nehma39_result39_count":[1555414,4],"nehma39_result40_count":[1555418,4],"nehma39_result39_pairs":[1548402,80],"nehma39_voice401":[1562058,8],"nehma39_voice402":[1562066,8],"nehma39_voice403":[1562074,8],"nehma39_voice404":[1562082,8],"nehma39_voice405":[1562090,8],"nehma39_voice406":[1562098,8],"nehma39_voice407":[1562106,8],"nehma39_voice408":[1562114,8],"nehma39_voice409":[1562122,8],"nehma39_voice410":[1562130,8],"nehma39_radio39_entry":[104642,4],"nehma39_final_next_dispatch":[429803,992],"nehma39_final_next_retire":[431502,209]}

static func parameters(data: Variant) -> bool:
	return Equal.equal_value(data,VALUES) or Equal.equal_value(data,MAC_VALUES)

static func declarations(bindings: RefCounted) -> Dictionary:
	if bindings==null:return {}
	var data: Dictionary=bindings.mido_travel.get("nehma_return",bindings.nehma_source_declarations())
	return data if parameters(data) else {}

static func available(bindings: RefCounted) -> bool:
	var data:=declarations(bindings)
	if data.is_empty() or not Previous.available(bindings):return false
	return Equal.equal_value(Previous.declarations(bindings),Previous.VALUES if Equal.equal_value(data,VALUES) else Previous.MAC_VALUES)

static func conversation(bindings: RefCounted,cursor: Variant,mission: Variant) -> Dictionary:
	if not available(bindings):return {}
	var data:=declarations(bindings)
	return Visit.station_rules(data.mission,data.next_mission,cursor,mission)

static func source_available(bindings: RefCounted) -> bool:
	return available(bindings) and Previous.source_arrival_available(bindings) and not bindings.nehma_source_receipt().is_empty()

static func source_receipt_matches(bindings: RefCounted,value: Variant) -> bool:
	if not source_available(bindings) or not value is Dictionary:return false
	var receipt: Dictionary=bindings.nehma_source_receipt()
	if value.size()!=receipt.size():return false
	for key in receipt:
		if not value.get(key) is String or value[key]!=receipt[key]:return false
	return true

## A station continuation is not permission to construct the special next flight.
static func station_supported(bindings: RefCounted,cursor: Variant,station_id: Variant) -> bool:
	if not source_available(bindings) or not cursor is int or not station_id is int:return false
	var data:=declarations(bindings)
	if cursor==int(data.next_mission.campaign_cursor):return station_id==int(data.mission.station_id)
	return cursor==int(data.mission.campaign_cursor) and not load("res://src/content/ordinary_world_definitions.gd").location(bindings.mido_travel,station_id).is_empty()

static func station_mission(bindings: RefCounted,cursor: Variant,station_id: Variant,mission: Variant) -> bool:
	if not station_supported(bindings,cursor,station_id) or not mission is Dictionary or mission.size()!=5:return false
	var data:=declarations(bindings)
	var expected: Dictionary=data.mission if cursor==int(data.mission.campaign_cursor) else data.next_mission
	for key in ["kind","station_id","reward","bonus","source_parameter"]:
		if not mission.get(key) is int or mission[key]!=int(expected[key]):return false
	return true
