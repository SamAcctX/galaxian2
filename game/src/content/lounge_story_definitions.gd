extends RefCounted
## Source station handoff after the additional-contract requirement.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const VALUES = {"scope":"mido_contract_story_handoff","campaign_cursor":13,"story_kind":150,"station_scope":"current_station","acknowledgement_required":true,"events":[{"speaker_id":3,"text_id":1792,"voice_event_id":222},{"speaker_id":0,"text_id":1793,"voice_event_id":223}],"next_cursor":14,"next_kind":4,"next_station_id":79,"reward":0,"bonus":0,"source_parameter":0}
const SPANS = {"contract_story_dialogue":[1547114,16],"contract_story_voices":[1560626,16],"contract_story_dialogue_count":[1555310,4],"contract_story_station_poll":[446081,58],"contract_story_station_result":[447318,69],"contract_story_acknowledged_story":[428880,54],"contract_story_advance_story":[429803,32],"contract_story_advance_cursor":[859851,9],"contract_story_next_mission":[861385,38],"contract_story_result_mode":[-693553,73],"contract_story_dialogue_constructor":[-694652,84],"contract_story_flight_defer_dialogue":[386979,88],"contract_story_flight_early_story":[388111,24]}

const MAC_SPANS = {"contract_story_dialogue":[1522098,16],"contract_story_voices":[1535690,16],"contract_story_dialogue_count":[1530294,4],"contract_story_station_poll":[446607,58],"contract_story_station_result":[447844,69],"contract_story_acknowledged_story":[429308,54],"contract_story_advance_story":[430231,32],"contract_story_advance_cursor":[860483,9],"contract_story_next_mission":[862017,38],"contract_story_result_mode":[-699449,73],"contract_story_dialogue_constructor":[-700548,84],"contract_story_flight_defer_dialogue":[387495,88],"contract_story_flight_early_story":[388627,24]}
const MAC_VALUES = {"scope":"mido_contract_story_handoff","campaign_cursor":13,"story_kind":150,"station_scope":"current_station","acknowledgement_required":true,"events":[{"speaker_id":3,"text_id":1806,"voice_event_id":222},{"speaker_id":0,"text_id":1807,"voice_event_id":223}],"next_cursor":14,"next_kind":4,"next_station_id":79,"reward":0,"bonus":0,"source_parameter":0}

# Android: spans inside named functions (Layouts.anchored, checked by mido_travel_definitions.gd).
const ANDROID_SPANS = {"contract_story_station_poll":[0,4016],"contract_story_gate":[0,1508],"contract_story_dialogue_constructor":[0,86],"contract_story_result_mode":[0,120],"contract_story_acknowledged_story":[0,6536],"contract_story_flight_defer_dialogue":[0,1764],"contract_story_dispatch":[58,10],"contract_story_case":[94,2],"contract_story_advance_cursor":[392,8],"contract_story_next_mission":[7416,30],"contract_story_dialogue_count":[52,4],"contract_story_dialogue":[752,16],"contract_story_voices":[472,16]}

static func parameters(data: Variant) -> bool:
	return Equal.equal_value(data,VALUES) or Equal.equal_value(data,MAC_VALUES)

static func available(bindings: RefCounted) -> bool:
	return bindings!=null and parameters(bindings.mido_travel.get("contract_completion"))
