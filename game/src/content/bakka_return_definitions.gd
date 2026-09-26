extends RefCounted
## Source declaration adapter. Docked dialogue does not admit the next encounter.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Station=preload("res://src/content/post_probe_visit_definitions.gd")
const VALUES:={"scope":"post_bakka_return","mission":{"campaign_cursor":37,"kind":160,"station_id":27,"system_id":5,"story":true,"reward":0,"bonus":0,"source_parameter":0,"briefing_events":[],"result_events":[{"speaker_id":1,"text_id":2009,"voice_event_id":391},{"speaker_id":0,"text_id":2010,"voice_event_id":392},{"speaker_id":1,"text_id":2011,"voice_event_id":393},{"speaker_id":0,"text_id":2012,"voice_event_id":394},{"speaker_id":1,"text_id":2013,"voice_event_id":395},{"speaker_id":0,"text_id":2014,"voice_event_id":396},{"speaker_id":1,"text_id":2015,"voice_event_id":397},{"speaker_id":0,"text_id":2016,"voice_event_id":398}],"completion":{"requires_landed_target":false,"result_mode":1,"completed_on_result_open":true,"advance_on_final_next_to_cursor":38,"reward_credits":0}},"flight_completion":{"requires_different_station":true,"elapsed_strictly_greater_ms":10000},"next_mission":{"campaign_cursor":38,"kind":4,"station_id":22,"story":true,"reward":0,"bonus":0,"source_parameter":0}}
const MAC_VALUES:={"scope":"post_bakka_return","mission":{"campaign_cursor":37,"kind":160,"station_id":27,"system_id":5,"story":true,"reward":0,"bonus":0,"source_parameter":0,"briefing_events":[],"result_events":[{"speaker_id":1,"text_id":1995,"voice_event_id":391},{"speaker_id":0,"text_id":1996,"voice_event_id":392},{"speaker_id":1,"text_id":1997,"voice_event_id":393},{"speaker_id":0,"text_id":1998,"voice_event_id":394},{"speaker_id":1,"text_id":1999,"voice_event_id":395},{"speaker_id":0,"text_id":2000,"voice_event_id":396},{"speaker_id":1,"text_id":2001,"voice_event_id":397},{"speaker_id":0,"text_id":2002,"voice_event_id":398}],"completion":{"requires_landed_target":false,"result_mode":1,"completed_on_result_open":true,"advance_on_final_next_to_cursor":38,"reward_credits":0}},"flight_completion":{"requires_different_station":true,"elapsed_strictly_greater_ms":10000},"next_mission":{"campaign_cursor":38,"kind":4,"station_id":22,"story":true,"reward":0,"bonus":0,"source_parameter":0}}
const SPANS:={"bakka_return_factory37":[863379,75],"bakka_return_factory37_entry":[872182,4],"bakka_return_factory38":[863454,38],"bakka_return_factory38_entry":[872186,4],"bakka_return_kind160_entry":[875906,4],"bakka_return_kind160_condition":[874637,46],"bakka_return_away_clock":[875735,18],"bakka_return_brief_count":[1529734,4],"bakka_return_result_count":[1530390,4],"bakka_return_result_pairs":[1523306,64],"bakka_return_result_voices":[1537042,64]}
const MAC_SPANS:={"bakka_return_factory37":[862747,75],"bakka_return_factory37_entry":[871550,4],"bakka_return_factory38":[862822,38],"bakka_return_factory38_entry":[871554,4],"bakka_return_kind160_entry":[875274,4],"bakka_return_kind160_condition":[874005,46],"bakka_return_away_clock":[875103,18],"bakka_return_brief_count":[1554750,4],"bakka_return_result_count":[1555406,4],"bakka_return_result_pairs":[1548322,64],"bakka_return_result_voices":[1561978,64]}

static func parameters(data: Variant) -> bool:
	return data is Dictionary and (Equal.equal_value(data,VALUES) or Equal.equal_value(data,MAC_VALUES))

static func available(bindings: RefCounted) -> bool:
	return bindings!=null and parameters(bindings.mido_travel.get("bakka_return"))

static func conversation(bindings: RefCounted,cursor: Variant,mission: Variant) -> Dictionary:
	if not available(bindings):return {}
	var data: Dictionary=bindings.mido_travel.bakka_return
	return Station.station_rules(data.mission,data.next_mission,cursor,mission)
