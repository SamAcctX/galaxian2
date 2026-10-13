extends RefCounted
const Layouts=preload("res://src/content/declaration_layouts.gd")
## Departure preparation after the first mining delivery. World construction,
## pirate activation and the next conversations have separate owners.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Fonts=preload("res://src/content/font_definitions.gd")
const Departure=preload("res://src/content/station_departure_definitions.gd")
const StationReturn=preload("res://src/content/station_return_definitions.gd")
const VALUES := {"scope":"full_hold_station_departure","campaign_cursor":4,"station_id":78,"system_id":15,"ship_id":0,"source_state":2,"world_type":3,"confirmation_text_id":386,"confirmation_required":true,"cache_reset":-1,"initial_cargo_used":0,"audio_selector":1,"previous_cursor":3,"mission_kind":154,"mission_parameter":25,"requires_acknowledged_delivery":true,"requires_empty_cargo":true}
const SPANS := {"launch_gates":[437002,744],"accepted_departure":[431746,259],"mission_dispatch":[871418,4],"mission_factory":[860566,82],"station_keeps_ship":[414806,548],"negative_pool_restore":[335297,128],"ordinary_pool_refresh":[335425,207],"cargo_clear":[730926,112],"gamma_environment":[878638,300]}

const MAC_ALTERNATE := {"launch_gates":[437438,820],"accepted_departure":[432174,259],"mission_dispatch":[872050,4],"mission_factory":[861198,82],"station_keeps_ship":[415224,550],"negative_pool_restore":[334997,128],"ordinary_pool_refresh":[335125,207],"cargo_clear":[731558,112],"gamma_environment":[879270,300]}

# Android: the VALUES; spans inside named functions (Layouts.anchored).
const ANDROID_SPANS := {"launch_gates":[0,684],"accept":[1808,20],"destination":[1982,60],"cache_reset_and_state":[2532,84],"mission_selection":[0,1072],"mission_dispatch":[74,2],"mission_factory":[6556,52],"mission_parameter":[8228,14],"cargo_clear":[0,92],"cargo_used":[0,4],"station_keeps_ship":[0,136],"world_entry":[618,40],"negative_pool_restore":[670,112],"ordinary_pool_refresh":[782,126],"gamma_environment":[0,80],"audio_selector_consumer":[2072,48]}

static func parameters(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=VALUES.size()+1 or not data.get("provenance") is Dictionary:return false
	for key in VALUES:
		if not Equal.equal_value(data.get(key),VALUES[key]):return false
	return true

static func validate(data: Variant, source_bytes: int, arch: String, arrival: Dictionary, departure: Dictionary, station_return: Dictionary) -> String:
	if not data is Dictionary:return "Missing second mining departure declarations"
	if data.is_empty():return ""
	if not (arch=="x86_64" or arch=="android-armv7") or not parameters(data):return "Unsupported second mining departure declarations"
	if not Departure.parameters(departure) or not StationReturn.parameters(station_return):return "Second mining departure requires its first departure and acknowledged station return"
	if arch=="android-armv7":return "" if Layouts.anchored(data.provenance,source_bytes,ANDROID_SPANS) else "Invalid second mining departure extents"
	var origin: Variant=arrival.get("provenance",{}).get("actor")
	if not Fonts.extent(origin,"offset","bytes",[315],source_bytes):return "Second mining departure lacks its source anchor"
	return "" if Layouts.matches(data.provenance,int(origin.offset),source_bytes,[SPANS,MAC_ALTERNATE]) else "Invalid second mining departure extents"
