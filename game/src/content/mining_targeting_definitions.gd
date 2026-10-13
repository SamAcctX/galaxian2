extends RefCounted
const Layouts=preload("res://src/content/declaration_layouts.gd")
## Source first-flight asteroid acquisition; approach and missions are separate.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Fonts=preload("res://src/content/font_definitions.gd")
const Flight=preload("res://src/content/first_flight_definitions.gd")
const VALUES := {"scope":"first_mining_asteroid_selection","campaign_cursor":2,"max_frame_ms":150,"item_kind_property":1,"equipment_kind":3,"category_property":2,"scanner_category":17,"drill_category":19,"unsupported_device_category":13,"duration_property":29,"default_duration_ms":8000,"window_divisor":18,"candidate_slots":5,"candidate_limit":4,"candidate_distance_limit":999999,"mineable_size_min":4,"acquisition_lead_ms":200,"animation_delay_ms":500,"acquisition_sound_id":26,"missing_drill_notification":20,"missing_tractor_notification":9,"animation_image_id":1110,"animation_texture_id":10062,"animation_region":10,"selection_requires_continued_aim":true,"selection_before_approach":true}
const SPANS := {"initial_state":[657262,382],"equipment_and_duration":[660721,213],"candidate_storage_and_window":[661052,116],"animation_source":[660507,127],"mineable_size":[546230,13],"mineable_accessor":[547174,14],"retired_accessor":[-77838,16],"destruction_accessor":[-77822,16],"array_reset":[674353,31],"body_eligibility":[674642,124],"candidate_window":[674766,268],"nearest_candidate":[675449,316],"selected_cleanup":[675785,88],"candidate_kind":[675873,48],"acquisition":[675921,307],"animation":[676228,319],"no_candidate":[676547,78],"selection_clear":[681540,24]}

const MAC_ALTERNATE := {"initial_state":[657810,382],"equipment_and_duration":[661269,213],"candidate_storage_and_window":[661600,116],"animation_source":[661055,127],"mineable_size":[546766,13],"mineable_accessor":[547710,14],"retired_accessor":[-77838,16],"destruction_accessor":[-77822,16],"array_reset":[674901,31],"body_eligibility":[675190,124],"candidate_window":[675314,268],"nearest_candidate":[675997,316],"selected_cleanup":[676333,88],"candidate_kind":[676421,48],"acquisition":[676469,307],"animation":[676776,319],"no_candidate":[677095,78],"selection_clear":[682088,24]}

# Android: VALUES with the Globals::w / 16 window; spans inside named functions (Layouts.anchored).
const ANDROID_VALUES := {"scope":"first_mining_asteroid_selection","campaign_cursor":2,"max_frame_ms":150,"item_kind_property":1,"equipment_kind":3,"category_property":2,"scanner_category":17,"drill_category":19,"unsupported_device_category":13,"duration_property":29,"default_duration_ms":8000,"window_divisor":16,"candidate_slots":5,"candidate_limit":4,"candidate_distance_limit":999999,"mineable_size_min":4,"acquisition_lead_ms":200,"animation_delay_ms":500,"acquisition_sound_id":26,"missing_drill_notification":20,"missing_tractor_notification":9,"animation_image_id":1110,"animation_texture_id":10062,"animation_region":10,"selection_requires_continued_aim":true,"selection_before_approach":true}
const ANDROID_SPANS := {"animation_source":[2186,84],"equipment_and_duration":[2324,148],"candidate_storage":[2550,34],"window":[2584,48],"mineable_size":[256,12],"mineable_accessor":[0,6],"retired_accessor":[0,14],"destruction_accessor":[0,14],"array_reset":[8120,12],"body_eligibility":[8480,106],"candidate_window":[8586,344],"nearest_candidate":[9132,164],"acquisition":[9296,296],"missing_devices":[9848,32],"animation":[9880,216],"selection_getter":[0,4],"selection_clear":[0,6]}

static func parameters(data: Variant) -> bool:
	return _parameters(data,VALUES) or _parameters(data,ANDROID_VALUES)

static func _parameters(data: Variant, expected: Dictionary) -> bool:
	if not data is Dictionary or data.size()!=expected.size()+1 or not data.get("provenance") is Dictionary:return false
	for key in expected:
		if not data.has(key) or not Equal.equal_value(data.get(key),expected[key]):return false
	return true

static func validate(data: Variant, source_bytes: int, arch: String, arrival: Dictionary, flight: Dictionary) -> String:
	if not data is Dictionary:return "Missing mining targeting declarations"
	if data.is_empty():return ""
	if arch=="android-armv7":
		if not _parameters(data,ANDROID_VALUES) or not Flight.parameters(flight):return "Unsupported mining targeting declarations"
		return "" if Layouts.anchored(data.provenance,source_bytes,ANDROID_SPANS) else "Invalid mining targeting extents"
	if arch!="x86_64" or not _parameters(data,VALUES) or not Flight.parameters(flight):return "Unsupported mining targeting declarations"
	var origin: Variant=arrival.get("provenance",{}).get("actor")
	if not Fonts.extent(origin,"offset","bytes",[315],source_bytes):return "Mining targeting lacks its source anchor"
	if data.provenance.size()!=SPANS.size():return "Invalid mining targeting provenance"
	return "" if Layouts.matches(data.provenance,int(origin.offset),source_bytes,[SPANS,MAC_ALTERNATE]) else "Invalid mining targeting extent"
