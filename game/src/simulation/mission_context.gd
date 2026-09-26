extends RefCounted
## The entry boundary admits the world and equipment once. Flight subsystems
## consume this immutable capability instead of maintaining campaign ID lists.
const Slots=preload("res://src/simulation/equipment_slots.gd")
const Recipe=preload("res://src/content/mission_recipe.gd")
var error:=""
var _recipe:={}
var _identity:={}
var _loadout:={}

func admit(bindings: RefCounted,catalogues: RefCounted,context: Dictionary,loadout: Dictionary) -> bool:
	error=""
	if not _recipe.is_empty():return reject("A mission context is admitted only once")
	var recipe:=Recipe.select(bindings,context.get("campaign_cursor"))
	if recipe.is_empty():return reject("No complete recipe supports this mission")
	if recipe.entry=="retained_world":return reject("This mission must continue its acknowledged living world")
	if catalogues==null or catalogues.content_id!=bindings.base_content_id:return reject("Mission catalogues belong to another content source")
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key) or loadout.get(key)!=bindings.get(key):return reject("Mission entry belongs to another content source")
	for key in ["station_id","system_id"]:
		if context.get(key)!=recipe[key] or loadout.get(key)!=recipe[key]:return reject("Mission entry and equipped location disagree")
	if context.get("mission_kind")!=recipe.mission.kind or context.get("mission_story")!=true:return reject("The authored mission is not selected")
	if context.get("mission_completed")!=false or context.get("mission_failed",false)!=false:return reject("A completed mission cannot be entered again")
	var slots:=Slots.checked_slots(bindings,catalogues,loadout)
	if slots.is_empty():return reject("Mission entry requires valid installed equipment")
	for id in slots.equipment_ids:
		if int(catalogues.tables.items[id].arrays[2][5])==27:return reject("Escape-device flight is not supported yet")
	_recipe=recipe
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":recipe.cursor}
	_loadout=loadout.duplicate(true)
	return true

## Keep the original capability on the living world. A successor capability is
## for the active objective only; it neither reconstructs nor re-identifies any
## already admitted player, actor, radio, camera or presentation owner.
func retained_successor(bindings: RefCounted,loadout: Dictionary) -> RefCounted:
	error=""
	if _recipe.is_empty() or _recipe.get("continuation",{}).get("kind")!="retained_world" or not matches_loadout(loadout):
		reject("No retained-world continuation accepts this equipment");return null
	var source:=Recipe.select(bindings,_recipe.cursor)
	var recipe:=Recipe.select(bindings,_recipe.next_cursor)
	if source!=_recipe or recipe.is_empty() or recipe.get("entry")!="retained_world" or recipe.get("retained_world_cursor")!=_recipe.cursor or recipe.mission!=_recipe.next_mission:
		reject("The retained successor differs from its admitted recipe");return null
	if recipe.world!=_recipe.world or recipe.station_id!=_recipe.station_id or recipe.system_id!=_recipe.system_id:
		reject("A retained continuation cannot replace its world or location");return null
	var next: RefCounted=get_script().new()
	next._recipe=recipe;next._identity=_identity.duplicate();next._identity.campaign_cursor=recipe.cursor
	next._loadout=_loadout.duplicate(true)
	if next._loadout.has("campaign_cursor"):next._loadout.campaign_cursor=recipe.cursor
	return next

func recipe() -> Dictionary:return _recipe.duplicate(true)
func identity() -> Dictionary:return _identity.duplicate()
static func from_owner(owner: RefCounted) -> RefCounted:
	if owner==null or not owner.has_method("mission_context_owner"):return null
	var context: RefCounted=owner.mission_context_owner()
	return context if context!=null and context.get_script()==load("res://src/simulation/mission_context.gd") and not context._recipe.is_empty() else null
func radio_observation(condition_clock: int,facts: Dictionary={}) -> Dictionary:
	var observation:=facts.duplicate(true)
	observation.merge(_identity,true);observation.condition_clock=condition_clock
	return observation
func has_feature(name: String) -> bool:return not _recipe.is_empty() and _recipe.world.get(name,false)
func ship_id() -> int:return int(_loadout.get("ship_id",-1))
func matches_loadout(loadout: Dictionary) -> bool:
	if _recipe.is_empty():return false
	for key in ["base_content_id","binding_id","station_id","system_id","ship_id","equipment_ids","slots"]:
		if loadout.get(key)!=_loadout.get(key):return false
	return not loadout.has("campaign_cursor") or loadout.campaign_cursor==_recipe.cursor

func matches_source(bindings: RefCounted,departure: Dictionary) -> bool:
	if _recipe.is_empty():return false
	var current:=Recipe.select(bindings,_recipe.cursor)
	return not current.is_empty() and current.source_receipt==_recipe.source_receipt and departure.get(_recipe.receipt_key,{})==_recipe.source_receipt

func accepts_result(cursor: int,mission: Dictionary,station_id: int) -> bool:
	return not _recipe.is_empty() and cursor==_recipe.next_cursor and mission==_recipe.next_mission and station_id==_recipe.station_id

func flight_rules(bindings: RefCounted) -> Dictionary:
	if _recipe.is_empty():return {}
	var result: Dictionary=bindings.first_flight.duplicate(true)
	result.campaign_cursor=_recipe.cursor;result.station_id=_recipe.station_id;result.system_id=_recipe.system_id
	result.mission_kind=_recipe.mission.kind;result.scope="mission_flight";result.erase("actor_count")
	return result

func reject(message: String) -> bool:error=message;return false
