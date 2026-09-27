extends RefCounted
## Station-only admission from an acknowledged mission continuation. Restoring
## its receipt retains history; the shared flight owner admits any later launch.
const Recipe=preload("res://src/content/mission_recipe.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
var error:=""
var _record:={}
var _recipe:={}

func admit(bindings: RefCounted,cat: RefCounted,flight: RefCounted) -> bool:
	if not _record.is_empty():return reject("A station context is immutable after admission")
	if not is_instance_of(flight,load("res://src/simulation/first_flight_frame.gd")) or flight.mission_station_return_identity()==null:return reject("Station continuation requires its acknowledged living flight")
	var state: Dictionary=flight.snapshot();var pending: Dictionary=state.get("mission_station_return",{})
	var context: RefCounted=flight.mission_context_owner()
	if state.get("boundary")!="mission_station_return_required" or context==null or not context.has_feature("normal_space"):return reject("The normal-world result has not requested station entry")
	var expected:=_source_record(bindings,cat,pending.get("source_cursor"))
	if expected.is_empty() or pending!={"source_cursor":expected.source_cursor,"campaign_cursor":expected.campaign_cursor,"station_id":expected.station_id}:return reject("Station continuation differs from its source recipe")
	if state.campaign_cursor!=expected.campaign_cursor or context.recipe().cursor!=expected.source_cursor:return reject("Station continuation changed its acknowledged campaign")
	_record=expected;_recipe=Recipe.select(bindings,int(expected.campaign_cursor))
	return true

func restore(bindings: RefCounted,cat: RefCounted,record: Variant) -> bool:
	if not _record.is_empty():return reject("A station context is immutable after restoration")
	if not record is Dictionary:return reject("The station checkpoint lost its source receipt")
	var expected:=_source_record(bindings,cat,record.get("source_cursor"))
	if expected.is_empty():return reject("The station checkpoint lost its original flight continuation")
	var history: Variant=record.get("station_history",[])
	if not history is Array or history.size()>64:return reject("Invalid station continuation history")
	for cursor in history:
		if not cursor is int or cursor!=expected.campaign_cursor:return reject("Station continuation skipped an acknowledgement")
		var step:=Recipe.select(bindings,cursor)
		if not _station_recipe_matches(expected,step):return reject("Station continuation lost an authored acknowledgement")
		expected=_after_recipe(expected,step)
	if expected.is_empty() or record!=expected:return reject("The station checkpoint differs from its sourced continuation")
	for key in expected:
		if typeof(record[key])!=typeof(expected[key]):return reject("Station continuation metadata changed its native types")
	_record=expected;_recipe=Recipe.select(bindings,int(expected.campaign_cursor))
	return true

static func _source_record(bindings: RefCounted,cat: RefCounted,cursor: Variant) -> Dictionary:
	if bindings==null or cat==null or cat.content_id!=bindings.base_content_id:return {}
	var recipe:=Recipe.select(bindings,cursor)
	if recipe.get("entry")=="station" or recipe.get("continuation",{}).get("kind")!="station":return {}
	var station: Variant=recipe.continuation.get("station_id")
	if not Numbers.integer(station,0,cat.tables.stations.size()-1) or recipe.next_mission.station_id!=station or recipe.next_mission.reward!=0:return {}
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"source_cursor":recipe.cursor,"campaign_cursor":recipe.next_cursor,"station_id":station,
		"system_id":int(cat.tables.stations[station].system_id),"mission":recipe.next_mission.duplicate(true),
		"source_receipt":recipe.source_receipt.duplicate(true)}

static func _station_recipe_matches(record: Dictionary,step: Dictionary) -> bool:
	return not step.is_empty() and step.get("entry")=="station" and step.cursor==record.campaign_cursor and step.station_id==record.station_id and step.mission==record.mission and step.continuation.get("kind")=="station" and step.continuation.station_id==record.station_id

static func _after_recipe(record: Dictionary,step: Dictionary) -> Dictionary:
	var result:=record.duplicate(true)
	if not result.has("station_history"):result.station_history=[]
	result.station_history.append(int(step.cursor))
	result.campaign_cursor=int(step.next_cursor);result.mission=step.next_mission.duplicate(true)
	result.reward_credits=int(step.career.reward_credits)
	return result

func successor(bindings: RefCounted,receipt: Dictionary) -> RefCounted:
	if not _station_recipe_matches(_record,_recipe):reject("No admitted station recipe awaits continuation");return null
	var expected:={"base_content_id":_record.base_content_id,"binding_id":_record.binding_id,
		"from_cursor":_recipe.cursor,"campaign_cursor":_recipe.next_cursor,"previous_mission":_recipe.mission,
		"mission":_recipe.next_mission,"station_id":_record.station_id,"reward_credits":_recipe.career.reward_credits}
	if receipt!=expected:reject("The station acknowledgement changed its authored continuation");return null
	var next: RefCounted=get_script().new()
	next._record=_after_recipe(_record,_recipe);next._recipe=Recipe.select(bindings,int(next._record.campaign_cursor))
	return next

func recipe() -> Dictionary:return _recipe.duplicate(true)

func completed_career(bindings: RefCounted) -> bool:
	if _record.is_empty() or bindings==null or _record.base_content_id!=bindings.base_content_id or _record.binding_id!=bindings.binding_id:return false
	var completed:=Recipe.completed_career(bindings,_record.campaign_cursor)
	return not completed.is_empty() and completed==_record.mission

## Cached contacts retain the station chapter that originally generated them.
## Reconstruct only an acknowledged prefix; never use it as the current entry.
func historical(bindings: RefCounted,cursor: Variant) -> RefCounted:
	if _record.is_empty() or not cursor is int:return null
	if cursor==_record.campaign_cursor:return self
	var source:=Recipe.select(bindings,int(_record.source_cursor))
	var record:=_record.duplicate(true)
	record.erase("station_history");record.erase("reward_credits")
	record.campaign_cursor=source.next_cursor;record.mission=source.next_mission.duplicate(true)
	for acknowledged in _record.get("station_history",[]):
		if record.campaign_cursor==cursor:
			var result: RefCounted=get_script().new();result._record=record;result._recipe=Recipe.select(bindings,cursor)
			return result
		if acknowledged!=record.campaign_cursor:return null
		record=_after_recipe(record,Recipe.select(bindings,int(acknowledged)))
	return null

static func permits(bindings: RefCounted,cursor: Variant,station: Variant,context: RefCounted) -> bool:
	if not is_instance_of(context,load("res://src/simulation/mission_station_context.gd")) or bindings==null:return false
	var record: Dictionary=context._record
	if record.is_empty() or not cursor is int or not station is int or record.base_content_id!=bindings.base_content_id or record.binding_id!=bindings.binding_id or record.campaign_cursor!=cursor:return false
	if record.station_id==station:return true
	return context.completed_career(bindings) and not load("res://src/content/ordinary_world_definitions.gd").location(bindings.mido_travel,station).is_empty()

func snapshot() -> Dictionary:return _record.duplicate(true)
func reject(message: String) -> bool:error=message;return false
