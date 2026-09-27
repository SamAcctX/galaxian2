extends RefCounted
## Authored station continuations and their presentation data. The shared
## runner, conversation and career owners apply these at separate boundaries.
const Ambush=preload("res://src/content/selected41_population_definitions.gd")

static func available(bindings: RefCounted) -> bool:
	return bindings!=null and Ambush.available(bindings) and Ambush.Previous.Equal.equal_value(Ambush.Previous.Nehma.declarations(bindings),Ambush.Previous.Nehma.VALUES)

static func recipe(bindings: RefCounted,cursor: Variant) -> Dictionary:
	if not available(bindings) or not cursor is int or cursor not in [43,44]:return {}
	var result:=[]
	if cursor==43:
		result=[{"speaker_id":0,"text_id":2058,"voice_event_id":425},{"speaker_id":6,"text_id":2059,"voice_event_id":426}]
	else:
		for index in 4:result.append({"speaker_id":0,"text_id":2064+index,"voice_event_id":427+index})
	var mission:={"kind":11,"station_id":10,"reward":0,"bonus":0,"source_parameter":0}
	var next_mission:=mission.duplicate()
	if cursor==44:next_mission={"kind":-1,"station_id":0,"reward":0,"bonus":0,"source_parameter":0}
	var policy: Dictionary=bindings.early_contracts.flight_results.duplicate(true)
	policy.success_poll_milliseconds=1001
	return {"cursor":cursor,"station_id":10,"mission":mission,"next_cursor":cursor+1,
		"next_mission":next_mission,"entry":"station","briefing":[],"radio":[],"sequences":[],
		"result":{"success":{"kind":"station","station_id":10,"after_ms":1000},"failure":{"kind":"never"},
			"actor_count":0,"lines":result,"policy":policy},
		"career":{"reward_credits":40000 if cursor==44 else 0},
		"presentation":presentation() if cursor==43 else {},
		"continuation":{"kind":"station","station_id":10},
		"source_receipt":bindings.nehma_source_receipt().duplicate(true)}

static func presentation() -> Dictionary:
	var radio:=[]
	for index in 4:
		radio.append({"speaker_id":1,"text_id":2060+index,"voice_event_id":539+index,
			"condition":5 if index==0 else 6,"values":[4000 if index==0 else index-1]})
	return {"kind":"credits","background":"station_exterior","music_event_id":144,
		"fade_out_ms":6000,"fade_in_ms":6000,"radio_delay_ms":12000,
		"final_fade_at_ms":142000,"complete_after_ms":148000,
		"camera_yaw_rate":0.00003,"radio":radio,"logo_image_id":7002,"credits_text_id":46,
		"scroll_pixels_per_second":30.0,"logo_pause_ms":4000,"logo_gap_pixels":10.0}
