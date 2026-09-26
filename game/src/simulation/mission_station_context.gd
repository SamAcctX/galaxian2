extends RefCounted
## Station-only admission from an acknowledged mission continuation. Restoring
## its receipt admits a station, never a flight or a live-world transition.
const Recipe=preload("res://src/content/mission_recipe.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
var error:=""
var _record:={}

func admit(bindings: RefCounted,cat: RefCounted,flight: RefCounted) -> bool:
	if not _record.is_empty():return reject("A station context is immutable after admission")
	if not is_instance_of(flight,load("res://src/simulation/first_flight_frame.gd")) or flight.mission_station_return_identity()==null:return reject("Station continuation requires its acknowledged living flight")
	var state: Dictionary=flight.snapshot();var pending: Dictionary=state.get("mission_station_return",{})
	var context: RefCounted=flight.mission_context_owner()
	if state.get("boundary")!="mission_station_return_required" or context==null or not context.has_feature("normal_space"):return reject("The normal-world result has not requested station entry")
	var expected:=_source_record(bindings,cat,pending.get("source_cursor"))
	if expected.is_empty() or pending!={"source_cursor":expected.source_cursor,"campaign_cursor":expected.campaign_cursor,"station_id":expected.station_id}:return reject("Station continuation differs from its source recipe")
	if state.campaign_cursor!=expected.campaign_cursor or context.recipe().cursor!=expected.source_cursor:return reject("Station continuation changed its acknowledged campaign")
	_record=expected
	return true

func restore(bindings: RefCounted,cat: RefCounted,record: Variant) -> bool:
	if not _record.is_empty():return reject("A station context is immutable after restoration")
	if not record is Dictionary:return reject("The station checkpoint lost its source receipt")
	var expected:=_source_record(bindings,cat,record.get("source_cursor"))
	if expected.is_empty() or record!=expected:return reject("The station checkpoint differs from its sourced continuation")
	for key in expected:
		if typeof(record[key])!=typeof(expected[key]):return reject("Station continuation metadata changed its native types")
	_record=expected
	return true

static func _source_record(bindings: RefCounted,cat: RefCounted,cursor: Variant) -> Dictionary:
	if bindings==null or cat==null or cat.content_id!=bindings.base_content_id:return {}
	var recipe:=Recipe.select(bindings,cursor)
	if recipe.get("continuation",{}).get("kind")!="station":return {}
	var station: Variant=recipe.continuation.get("station_id")
	if not Numbers.integer(station,0,cat.tables.stations.size()-1) or recipe.next_mission.station_id!=station or recipe.next_mission.reward!=0:return {}
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"source_cursor":recipe.cursor,"campaign_cursor":recipe.next_cursor,"station_id":station,
		"system_id":int(cat.tables.stations[station].system_id),"mission":recipe.next_mission.duplicate(true),
		"source_receipt":recipe.source_receipt.duplicate(true)}

static func permits(bindings: RefCounted,cursor: Variant,station: Variant,context: RefCounted) -> bool:
	if not is_instance_of(context,load("res://src/simulation/mission_station_context.gd")) or bindings==null:return false
	var record: Dictionary=context._record
	return not record.is_empty() and cursor is int and station is int and record.base_content_id==bindings.base_content_id and record.binding_id==bindings.binding_id and record.campaign_cursor==cursor and record.station_id==station

func snapshot() -> Dictionary:return _record.duplicate(true)
func reject(message: String) -> bool:error=message;return false
