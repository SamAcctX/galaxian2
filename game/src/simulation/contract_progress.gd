extends RefCounted
## Generated terms stay immutable while an earned continuation changes the
## active destination. Saves validate this derivation at their entry boundary.
const Recipe=preload("res://src/content/mission_recipe.gd")

static func mission_for(quote: Dictionary,phase: Variant="",catalogues: RefCounted=null) -> Dictionary:
	var original: Dictionary=quote.get("mission",{})
	if phase=="":return original.duplicate(true)
	var continuation:=Recipe.contract_continuation(original)
	if continuation.is_empty() or phase!=continuation.kind or catalogues==null:return {}
	var mission:=original.duplicate(true)
	mission.kind=int(continuation.mission_kind)
	mission.title_text_id=int(original.title_text_id)-int(original.kind)+int(mission.kind)
	mission.station_id=int(quote.context.station_id)
	mission.system_id=int(catalogues.tables.stations[mission.station_id].system_id)
	mission.source_parameter=int(continuation.source_parameter)
	mission.briefing_text_id=int(continuation.briefing_text_id)
	return mission

static func matches(state: Dictionary,quote: Dictionary,catalogues: RefCounted=null) -> bool:
	var expected:=mission_for(quote,state.get("contract_phase",""),catalogues)
	if state.has("station_outcome"):
		if not Recipe.defers_station_result(expected) or not state.station_outcome is int or state.station_outcome not in [1,2]:return false
	return not expected.is_empty() and state.get("mission")==expected

static func occupied_passengers(state: Dictionary) -> int:
	if state.get("contract_phase","")!="":return 0
	var mission: Dictionary=state.get("mission",{})
	return int(mission.get("quantity",0)) if mission.get("kind")==11 else 0

static func continue_delivery(state: Dictionary,continuation: Dictionary,catalogues: RefCounted) -> bool:
	if not state.get("contract_phase","").is_empty() or continuation.is_empty():return false
	var quote: Dictionary=state.get("accepted_contact",{}).get("offer",{})
	if not matches(state,quote,catalogues) or Recipe.contract_continuation(quote.mission)!=continuation:return false
	var mission:=mission_for(quote,continuation.kind,catalogues)
	if mission.is_empty():return false
	state.mission=mission;state.contract_phase=continuation.kind
	return true
