extends RefCounted
const Layouts=preload("res://src/content/declaration_layouts.gd")
## Source-present starter offers and installed-equipment tutorial predicate.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Fonts=preload("res://src/content/font_definitions.gd")
const Return=preload("res://src/content/full_hold_return_definitions.gd")
const VALUES := {"scope":"var_hastra_equipment_tutorial","station_id":78,"system_id":15,"campaign_cursor":6,"mission_kind":158,"stock_maximum_cursor":6,"stock":[{"item_id":0,"quantity":1,"unit_price":0},{"item_id":22,"quantity":1,"unit_price":0},{"item_id":55,"quantity":1,"unit_price":0}],"protected_item_ids":[90,81],"item_category_value_index":3,"item_subtype_value_index":5,"item_text_offset":1255,"multiple_subtype_mask":6137572235519,"weapon_category":0,"armor_subtype":10,"refresh_cargo_on_transaction":true,"reward_credits":0,"bonus_credits":0,"cursor_after_acknowledgement":7,"next_mission_kind":4,"next_mission_parameter":0,"next_text_id":179,"final_text_id":180,"events":[{"speaker_id":2,"text_id":1725,"voice_event_id":438}],"mount_audio_id":98,"unmount_audio_id":96}
const SPANS := {"tutorial_stock":[-244274,214],"stock_clone":[-81912,30],"zero_price_preserved":[877999,16],"stock_install":[857285,73],"item_fields":[-84866,152],"category":[-84670,20],"subtype":[-84650,10],"protected":[-81574,10],"multiple_subtypes":[-84704,26],"item_transfer":[-84322,104],"quantity_commit":[-166554,146],"mount":[-137582,780],"unmount":[-138150,568],"first_free_slot":[731910,100],"cargo_refresh":[730926,112],"protected_action":[-135013,64],"equipment_check":[874532,119],"equipment_result":[874886,38],"station_check":[446081,78],"completion_dialogue":[447318,69],"mode1_counts":[1555258,28],"mode1_event":[1546642,8],"voice_table":[1560154,12032],"cursor7_dispatch":[871430,4],"cursor7_factory":[860756,38],"factory_install":[860545,16],"station_acknowledgement":[429803,1908],"item_text":[-134704,34]}

const MAC_ALTERNATE := {"tutorial_stock":[-245762,214],"stock_clone":[-81912,30],"zero_price_preserved":[878631,16],"stock_install":[857917,73],"item_fields":[-84866,152],"category":[-84670,20],"subtype":[-84650,10],"protected":[-81574,10],"multiple_subtypes":[-84704,26],"item_transfer":[-84322,104],"quantity_commit":[-167046,146],"mount":[-138042,784],"unmount":[-138614,572],"first_free_slot":[732542,100],"cargo_refresh":[731558,112],"protected_action":[-135469,64],"equipment_check":[875164,119],"equipment_result":[875518,38],"station_check":[446607,78],"completion_dialogue":[447844,69],"mode1_counts":[1530242,28],"mode1_event":[1521626,8],"voice_table":[1535218,12032],"cursor7_dispatch":[872062,4],"cursor7_factory":[861388,38],"factory_install":[861177,16],"station_acknowledgement":[430231,1908],"item_text":[-135082,34]}
const MAC_VALUES := {"scope":"var_hastra_equipment_tutorial","station_id":78,"system_id":15,"campaign_cursor":6,"mission_kind":158,"stock_maximum_cursor":6,"stock":[{"item_id":0,"quantity":1,"unit_price":0},{"item_id":22,"quantity":1,"unit_price":0},{"item_id":55,"quantity":1,"unit_price":0}],"protected_item_ids":[90,81],"item_category_value_index":3,"item_subtype_value_index":5,"item_text_offset":1263,"multiple_subtype_mask":6137572235519,"weapon_category":0,"armor_subtype":10,"refresh_cargo_on_transaction":true,"reward_credits":0,"bonus_credits":0,"cursor_after_acknowledgement":7,"next_mission_kind":4,"next_mission_parameter":0,"next_text_id":179,"final_text_id":180,"events":[{"speaker_id":2,"text_id":1736,"voice_event_id":438}],"mount_audio_id":98,"unmount_audio_id":96}
# Android: the MAC_VALUES; spans inside named functions and tables (Layouts.anchored).
const ANDROID_SPANS := {"tutorial_gate":[16,28],"tutorial_items":[44,102],"stock_clone":[0,18],"item_fields":[0,78],"category":[0,4],"subtype":[0,4],"protected":[0,6],"protected_action":[190,28],"protected_message":[394,20],"multiple_subtypes":[0,16],"multiple_subtype_table":[0,43],"item_text":[0,40],"item_transfer":[0,88],"first_free_slot":[0,78],"cargo_refresh":[0,92],"mount":[0,358],"mount_sound":[358,2],"mount_tail":[360,28],"unmount":[0,396],"unmount_sound":[396,2],"unmount_tail":[398,34],"equipment_dispatch":[190,98],"equipment_check":[766,96],"station_check":[2044,38],"completion_dialogue":[2684,36],"acknowledgement":[0,6536],"story_increment":[392,4],"story_dispatch":[58,24],"equipment_mission":[7206,24],"equipment_mission_arguments":[7230,10],"next_mission":[7506,16],"next_mission_arguments":[7522,14],"campaign_mission_tail":[426,14],"mission_factory":[0,288],"next_label":[32,2],"final_label":[2342,2],"mode1_counts":[0,28],"mode1_event":[280,8],"voice":[2200,8]}


static func parameters(data: Variant) -> bool:
	return _parameters(data,VALUES) or _parameters(data,MAC_VALUES)

static func _parameters(data: Variant,expected: Dictionary) -> bool:
	if not data is Dictionary or data.size()!=expected.size()+1 or not data.get("provenance") is Dictionary:return false
	for key in expected:
		if not Equal.equal_value(data.get(key),expected[key]):return false
	return true

static func validate(data: Variant, source_bytes: int, arch: String, arrival: Dictionary, station_return: Dictionary) -> String:
	if not data is Dictionary:return "Missing station equipment declarations"
	if data.is_empty():return ""
	if arch=="android-armv7":
		if not _parameters(data,MAC_VALUES):return "Unsupported station equipment declarations"
		if not Return.parameters(station_return):return "Station equipment lacks its mining delivery"
		return "" if Layouts.anchored(data.provenance,source_bytes,ANDROID_SPANS) else "Invalid station equipment extents"
	if arch!="x86_64" or not parameters(data):return "Unsupported station equipment declarations"
	if not Return.parameters(station_return):return "Station equipment lacks its mining delivery"
	var origin: Variant=arrival.get("provenance",{}).get("actor")
	if not Fonts.extent(origin,"offset","bytes",[315],source_bytes):return "Station equipment lacks its source anchor"
	var layouts: Array=[]
	if _parameters(data,VALUES):layouts.append(SPANS)
	if _parameters(data,MAC_VALUES):layouts.append(MAC_ALTERNATE)
	return "" if Layouts.matches(data.provenance,int(origin.offset),source_bytes,layouts) else "Invalid station equipment extents"
