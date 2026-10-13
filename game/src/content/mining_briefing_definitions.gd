extends RefCounted
const Layouts=preload("res://src/content/declaration_layouts.gd")
## First mining briefing and entry clocks, separate from mission completion.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Fonts=preload("res://src/content/font_definitions.gd")
const Flight=preload("res://src/content/first_flight_definitions.gd")
const Desktop=preload("res://src/content/desktop_text_definitions.gd")
const Presentation=preload("res://src/content/station_presentation_definitions.gd")
const VALUES := {"scope":"first_mining_briefing","campaign_cursor":2,"mission_kind":154,"mode":0,"entry_release_ms":7001,"briefing_minimum_ms":5001,"max_frame_ms":150,"briefing_before_controller_update":true,"modal_stops_simulation":true,"final_acknowledgement_clears_pending":true,"final_acknowledgement_completes_mission":false,"next_text_id":179,"final_text_id":180,"key_token":"#KEY_DOCK","events":[{"speaker_id":0,"text_id":1699,"voice_event_id":177},{"speaker_id":2,"text_id":1700,"voice_event_id":178},{"speaker_id":0,"text_id":1701,"voice_event_id":179},{"speaker_id":2,"text_id":1702,"voice_event_id":180},{"speaker_id":16,"text_id":1703,"voice_event_id":-1}]}
const SPANS := {"count_prefix":[1554602,12],"events":[1555922,40],"voice_events":[1560266,32],"index_table":[-694459,60],"dialogue_mode":[-693624,144],"speaker_selection":[-692286,155],"text_selection":[-692078,65],"line_count":[-686407,60],"next_line":[-686457,41],"previous_line":[-685046,45],"acknowledgement":[-685001,56],"hud_initial":[338262,51],"hud_modal_clock_gate":[364625,11],"hud_clock":[365124,19],"hud_modal_dispatch":[368096,39],"briefing_start":[385208,516],"controller_order":[377622,24],"modal_update_dispatch":[376727,41],"modal_update":[377346,51],"final_acknowledgement":[351489,102],"unfinished_mission":[352080,40],"post_briefing":[356073,40],"clear_pending":[233366,18]}

const MAC_ALTERNATE := {"count_prefix":[1529586,12],"events":[1530914,40],"voice_events":[1535330,32],"index_table":[-700355,60],"dialogue_mode":[-699520,144],"speaker_selection":[-698182,155],"text_selection":[-697974,65],"line_count":[-692295,60],"next_line":[-692345,41],"previous_line":[-690934,45],"acknowledgement":[-690889,56],"hud_initial":[337962,51],"hud_modal_clock_gate":[364348,11],"hud_clock":[364847,19],"hud_modal_dispatch":[367826,39],"briefing_start":[385724,516],"controller_order":[378134,24],"modal_update_dispatch":[377239,41],"modal_update":[377858,51],"final_acknowledgement":[351203,102],"unfinished_mission":[351794,40],"post_briefing":[355787,40],"clear_pending":[233378,18]}
const MAC_VALUES := {"scope":"first_mining_briefing","campaign_cursor":2,"mission_kind":154,"mode":0,"entry_release_ms":7001,"briefing_minimum_ms":5001,"max_frame_ms":150,"briefing_before_controller_update":true,"modal_stops_simulation":true,"final_acknowledgement_clears_pending":true,"final_acknowledgement_completes_mission":false,"next_text_id":179,"final_text_id":180,"key_token":"#KEY_DOCK","events":[{"speaker_id":0,"text_id":1710,"voice_event_id":177},{"speaker_id":2,"text_id":1711,"voice_event_id":178},{"speaker_id":0,"text_id":1712,"voice_event_id":179},{"speaker_id":2,"text_id":1713,"voice_event_id":180},{"speaker_id":16,"text_id":1714,"voice_event_id":-1}]}

# Android: the MAC_VALUES without the desktop key token (no desktop text); spans inside named functions and tables.
const ANDROID_VALUES := {"scope":"first_mining_briefing","campaign_cursor":2,"mission_kind":154,"mode":0,"entry_release_ms":7001,"briefing_minimum_ms":5001,"max_frame_ms":150,"briefing_before_controller_update":true,"modal_stops_simulation":true,"final_acknowledgement_clears_pending":true,"final_acknowledgement_completes_mission":false,"next_text_id":179,"final_text_id":180,"key_token":null,"events":[{"speaker_id":0,"text_id":1710,"voice_event_id":177},{"speaker_id":2,"text_id":1711,"voice_event_id":178},{"speaker_id":0,"text_id":1712,"voice_event_id":179},{"speaker_id":2,"text_id":1713,"voice_event_id":180},{"speaker_id":16,"text_id":1714,"voice_event_id":-1}]}
const ANDROID_SPANS := {"count_prefix":[0,12],"events":[16,40],"voice_events":[112,32],"briefing_check":[0,32],"index_table":[20,70],"dialogue_mode":[112,120],"text_selection":[288,72],"line_count":[0,104],"next_line":[0,38],"previous_line":[0,26],"last_line":[0,22],"acknowledgement":[0,308],"briefing_start":[0,392],"briefing_time_gate":[10072,68],"controller_order":[10658,20],"modal_update":[4740,52],"final_acknowledgement":[972,76],"unfinished_mission":[3178,28],"post_briefing":[3740,12],"clear_pending":[0,10],"pending_getter":[0,6]}

static func parameters(data: Variant) -> bool:
	return _parameters(data,VALUES) or _parameters(data,MAC_VALUES) or _parameters(data,ANDROID_VALUES)

static func _parameters(data: Variant,expected: Dictionary) -> bool:
	if not data is Dictionary or data.size()!=expected.size()+1 or not data.get("provenance") is Dictionary:return false
	for key in expected:
		if not data.has(key) or not Equal.equal_value(data.get(key),expected[key]):return false
	return true

static func validate(data: Variant, source_bytes: int, arch: String, arrival: Dictionary, flight: Dictionary, presentation: Dictionary, desktop: Dictionary) -> String:
	if not data is Dictionary:return "Missing mining briefing declarations"
	if data.is_empty():return ""
	if arch=="android-armv7":
		# Android shows the touch wording: no desktop pairs are required.
		if not _parameters(data,ANDROID_VALUES) or not Flight.parameters(flight) or not Presentation.parameters(presentation):return "Unsupported mining briefing"
		return "" if Layouts.anchored(data.provenance,source_bytes,ANDROID_SPANS) else "Invalid mining briefing extent"
	if arch!="x86_64" or not _parameters(data,VALUES) and not _parameters(data,MAC_VALUES) or not Flight.parameters(flight) or not Presentation.parameters(presentation) or not Desktop.parameters(desktop):return "Unsupported mining briefing"
	var origin: Variant=arrival.get("provenance",{}).get("actor")
	if not Fonts.extent(origin,"offset","bytes",[315],source_bytes):return "Mining briefing lacks its source anchor"
	if data.provenance.size()!=SPANS.size():return "Invalid mining briefing provenance"
	var layouts: Array=[]
	if _parameters(data,VALUES):layouts.append(SPANS)
	if _parameters(data,MAC_VALUES):layouts.append(MAC_ALTERNATE)
	var instruction: int=int(data.events[-1].text_id)
	if Desktop.select_id(desktop,instruction)!=instruction+1:return "Mining briefing desktop alias belongs to another source"
	return "" if Layouts.matches(data.provenance,int(origin.offset),source_bytes,layouts) else "Invalid mining briefing extent"
