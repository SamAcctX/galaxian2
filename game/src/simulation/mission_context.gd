extends RefCounted
## The entry boundary admits the world and equipment once. Flight subsystems
## consume this immutable capability instead of maintaining campaign ID lists.
const Slots=preload("res://src/simulation/equipment_slots.gd")
const Recipe=preload("res://src/content/mission_recipe.gd")
var error:=""
var _recipe:={}
var _identity:={}
var _loadout:={}
var _normal_return: RefCounted
var _normal_progress:={}
var _contract_context:={}
var _legacy_flight:={}
var _live_cursors: Array=[]

## Base-game player hulls come from the ordinary stock factory, including its
## fixed station offers and dedicated faction selection. NPC-only prototypes
## and expansion-only offers are not admitted by a catalogue index alone.
static func base_player_hull(bindings: RefCounted,ship_id: Variant) -> bool:
	if bindings==null or not preload("res://src/content/opening_definitions.gd").integer(ship_id,0,2147483647):return false
	if not preload("res://src/content/base_station_stock_definitions.gd").available(bindings):
		return ship_id==bindings.opening_loadout.get("ship_id",-1) or ship_id==bindings.station_entry.get("ship_id",-1)
	var ships: Dictionary=bindings.early_contracts.base_station_stock.ships
	if not preload("res://src/content/opening_definitions.gd").integer(ship_id,0,int(ships.selection_draw_bound)-1):return false
	if int(ship_id)==int(ships.vossk_ship_id) or ships.fixed_first_ships.values().any(func(id):return int(id)==int(ship_id)):return true
	return not ships.selection_excluded_ids.any(func(id):return int(id)==int(ship_id))

## Older mission owners still select their authored entry and run their own
## objectives. Admit that selected flight here without creating a runner recipe.
func admit_legacy(bindings: RefCounted,catalogues: RefCounted,flight: Dictionary,loadout: Dictionary) -> bool:
	error=""
	if not _identity.is_empty():return reject("A flight context is admitted only once")
	if bindings==null or flight.is_empty():return reject("Flight entry requires its selected world declarations")
	var source_cursor: Variant=flight.get("campaign_cursor")
	if not (source_cursor is int or source_cursor is float) or not is_finite(source_cursor) or source_cursor<0 or source_cursor>2147483647 or source_cursor!=int(source_cursor):return reject("Flight entry requires its selected campaign cursor")
	for key in ["station_id","system_id"]:
		if loadout.get(key)!=flight.get(key):return reject("Flight entry and equipped location disagree")
	if loadout.has("campaign_cursor") and loadout.campaign_cursor!=flight.campaign_cursor:return reject("Flight entry changed its player cursor")
	if not _accept_equipment(bindings,catalogues,loadout):return false
	var ordinary=load("res://src/content/ordinary_flight_definitions.gd")
	var cursor:=int(source_cursor)
	var cursors: Array=[cursor]
	var objective: Dictionary=ordinary.objective(bindings,cursor)
	if int(objective.get("cursor_after_acknowledgement",cursor))>cursor:cursors.append(int(objective.cursor_after_acknowledgement))
	var campaign=load("res://src/content/free_campaign_definitions.gd")
	if campaign.visit_at(bindings.mido_travel,cursor,int(loadout.station_id)):
		var visit: Dictionary=campaign.dialogue_rules(bindings,cursor,campaign.mission(bindings,cursor))
		if visit.has("next_cursor"):cursors.append(int(visit.next_cursor))
	_legacy_flight=flight.duplicate(true);_live_cursors=cursors
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":cursor}
	_loadout=loadout.duplicate(true)
	return true

func _accept_equipment(bindings: RefCounted,catalogues: RefCounted,loadout: Dictionary) -> bool:
	if not base_player_hull(bindings,loadout.get("ship_id")):return reject("This hull has no supported player flight")
	if loadout.has("ship_instance") and not load("res://src/simulation/ship_instance.gd").valid(loadout.ship_instance):return reject("Flight entry lost its retained hull properties")
	var slots:=Slots.checked_slots(bindings,catalogues,loadout)
	if slots.is_empty():return reject("Flight entry requires valid installed equipment")
	for id in slots.equipment_ids:
		if int(catalogues.tables.items[id].arrays[2][5])==27:return reject("Escape-device flight is not supported yet")
	return true

func live_cursors() -> Array:
	return _live_cursors.duplicate() if not _legacy_flight.is_empty() else ([_recipe.cursor,_recipe.next_cursor] if not _recipe.is_empty() else [])

func matches_location(bindings: RefCounted,location: Dictionary) -> bool:
	return bindings!=null and not _identity.is_empty() and _identity.base_content_id==bindings.base_content_id and _identity.binding_id==bindings.binding_id and location.get("station_id")==_loadout.station_id and location.get("system_id")==_loadout.system_id

static func supports_contract(bindings: RefCounted,mission: Variant,cursor: int) -> bool:
	if bindings==null or not mission is Dictionary or mission.get("story")!=false:return false
	if mission.get("kind")==6 and (not mission.get("target_name") is String or mission.target_name.is_empty()):return false
	var rules: Dictionary=bindings.early_contracts.get("encounter_construction",{})
	if rules.is_empty():return false
	var world=load("res://src/content/contract_world_definitions.gd")
	if world.supports(bindings,cursor):
		return rules.kinds.any(func(value):return int(value)==mission.get("kind")) and rules.mission_difficulties.any(func(value):return int(value)==mission.get("difficulty")) and not world.flight(bindings,int(mission.get("station_id",-1)),cursor).is_empty()
	var ordinary=load("res://src/content/free_flight_definitions.gd")
	# Keeping a side slot through a story world does not select that job's cast.
	# Actual entry also requires the location/flight admitted below.
	if mission.get("kind")==2 and not preload("res://src/content/opening_definitions.gd").integer(mission.get("quantity"),2,5):return false
	if Recipe.defers_station_result(mission) and not load("res://src/content/free_lifecycle_definitions.gd").available(bindings):return false
	if mission.get("kind") in [9,10]:
		var population=load("res://src/content/free_population_definitions.gd")
		if not [0,1,2,3].all(func(faction):return population.freighter_hull(bindings,faction)>=0 and not population.freighter_assembly(bindings,faction).is_empty()):return false
	if mission.get("kind") in [3,5] and (not preload("res://src/content/tractor_recovery_definitions.gd").available(bindings) or not preload("res://src/content/opening_definitions.gd").integer(mission.get("quantity"),2,9)):return false
	return ordinary.available(bindings) and cursor>=int(bindings.mido_travel.free_flight.campaign_cursor) and mission.get("kind") in [1,2,3,4,5,6,7,9,10,12,13] and preload("res://src/content/opening_definitions.gd").integer(mission.get("difficulty"),1,9) and not ordinary.Worlds.location(bindings.mido_travel,mission.get("station_id")).is_empty()

## A retained career and inventory authorize a generated side job once. Other
## owners receive this capability with the cast, never a caller-authored recipe.
func admit_contract(bindings: RefCounted,catalogues: RefCounted,contracts: RefCounted,equipment: RefCounted) -> bool:
	error=""
	if not _identity.is_empty():return reject("A mission context is admitted only once")
	if not is_instance_of(contracts,load("res://src/simulation/contract_session.gd")) or not is_instance_of(equipment,load("res://src/simulation/station_equipment.gd")):return reject("Contract entry requires its retained career and inventory")
	if bindings==null or catalogues==null or catalogues.content_id!=bindings.base_content_id or not load("res://src/content/early_contract_definitions.gd").encounter_parameters(bindings.early_contracts):return reject("Contract entry requires matching original declarations")
	var owned: Dictionary=equipment.snapshot()
	if not owned.get("training_inventory_released",false) or not owned.get("prototype_drill_replaced",false) or not equipment.cargo_cache_valid():return reject("Contract entry requires released, usable inventory")
	var loadout: Dictionary=owned.loadout
	var context: Dictionary=contracts.flight_context(int(loadout.station_id),bindings)
	if context.is_empty():return reject(contracts.error)
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key) or loadout.get(key)!=bindings.get(key):return reject("Contract entry belongs to another content source")
	var rules: Dictionary=bindings.early_contracts.encounter_construction
	var flight: Dictionary=load("res://src/content/contract_world_definitions.gd").flight(bindings,context.station_id,context.campaign_cursor)
	if flight.is_empty():flight=load("res://src/content/free_flight_definitions.gd").flight(bindings,context.station_id,context.campaign_cursor)
	if flight.is_empty() or loadout.system_id!=int(flight.system_id):return reject("This contract location has no complete flight recipe")
	if not context.get("rank") is int or context.rank<0 or context.rank>=bindings.opening_handoff.rank_thresholds.size() or not rules.supported_game_difficulties.has(context.difficulty):return reject("Unsupported contract career or difficulty")
	var mission: Dictionary=context.mission
	if not supports_contract(bindings,mission,int(context.campaign_cursor)):return reject("This active contract has no complete cast recipe")
	if int(mission.kind)==12 and (context.client_faction not in [0,1,2,3] or context.contact_name.is_empty()):return reject("The contest lost its generated rival")
	if not _accept_equipment(bindings,catalogues,loadout):return false
	var local_faction:=int(catalogues.tables.systems[int(loadout.system_id)].fields[int(bindings.early_contracts.generation.system_faction_field)])
	if local_faction not in [0,1,2,3]:return reject("Contract ships require a supported local faction")
	_recipe=Recipe.from_contract(bindings,context,loadout,local_faction)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":context.campaign_cursor}
	_loadout=loadout.duplicate(true);_contract_context=context.duplicate(true)
	return true

func contract_context() -> Dictionary:return _contract_context.duplicate(true)
func has_contract_actors() -> bool:return not _contract_context.is_empty() and int(_recipe.cast.actor_count)>0

## Construction resolves a variable cast once before exposing any actors. The
## admitted parent remains unchanged; result and actor owners share this copy.
func resolve_contract_count(count: int) -> RefCounted:
	if _contract_context.is_empty():reject("Only admitted contracts can resolve a cast");return null
	var draw: Dictionary=_recipe.cast.get("count_draw",{})
	if draw.is_empty() or count<int(draw.minimum) or count>=int(draw.minimum)+int(draw.bound):reject("The generated population exceeds its admitted cast");return null
	var copy: RefCounted=get_script().new()
	copy._identity=_identity;copy._loadout=_loadout;copy._contract_context=_contract_context
	copy._recipe=_recipe.duplicate(true)
	copy._recipe.cast.actor_count=count;copy._recipe.cast.count_draw={};copy._recipe.result.actor_count=count
	if draw.has("group"):
		var selected:=int(draw.group);var groups: Array=copy._recipe.cast.ship_groups
		var boundary:=int(groups[selected].end_actor);var change:=count-int(_recipe.cast.actor_count)
		for index in range(selected,groups.size()):
			groups[index].end_actor+=change
			if index>selected:groups[index].first_actor+=change
		for name in ["success","failure","periodic_failure"]:
			var condition: Dictionary=copy._recipe.result[name]
			for field in ["first_actor","end_actor"]:
				if condition.get(field,-1)>=boundary:condition[field]+=change
		for name in ["player_last_ids","player_only_ids"]:
			var adjusted:=[]
			for id in copy._recipe.cast[name]:
				if id<boundary+change:adjusted.append(id)
				elif id>=boundary:adjusted.append(id+change)
			copy._recipe.cast[name]=adjusted
	return copy
func advances_campaign() -> bool:return not _recipe.is_empty() and _recipe.get("track","campaign")=="campaign"

func matches_contract_population(bindings: RefCounted,packet: Dictionary) -> bool:
	if _contract_context.is_empty() or bindings==null:return false
	for key in ["base_content_id","binding_id"]:
		if _identity[key]!=bindings.get(key) or packet.get(key)!=_identity[key]:return false
	var source: Dictionary=packet.get("contract_encounter",{})
	if not _recipe.cast.ship_groups.is_empty() and source.get("unused_enemy_faction") not in [8,int([1,0,3,2][int(_recipe.cast.local_faction)])]:return false
	return packet.get("campaign_cursor")==_recipe.cursor and packet.get("station_id")==_recipe.station_id and source.get("context")==_contract_context and source.get("mission")==_recipe.mission and source.get("kind")==_recipe.mission.kind and source.get("actor_count")==_recipe.cast.actor_count and packet.get("actors") is Array and packet.actors.size()==_recipe.cast.actor_count

static func contract_combat_matches(bindings: RefCounted,combat: Dictionary) -> bool:
	if not load("res://src/content/contract_world_definitions.gd").available(bindings):return false
	var source: Dictionary=combat.get("contract_encounter",{})
	var context: Dictionary=source.get("context",{})
	var actors: Variant=combat.get("actors")
	if not actors is Array or source.get("actor_count")!=actors.size() or source.get("mission",{})!=context.get("mission"):return false
	for key in ["base_content_id","binding_id"]:
		if combat.get(key)!=bindings.get(key) or context.get(key)!=bindings.get(key):return false
	if context.get("campaign_cursor")!=combat.get("campaign_cursor"):return false
	var kind: Variant=source.get("kind")
	if kind!=context.mission.get("kind"):return false
	# Cast admission owns location and population size; presentation observes it.
	var hulls: Dictionary=bindings.early_contracts.encounter_construction.hulls
	for id in actors.size():
		var actor: Variant=actors[id]
		if not actor is Dictionary or actor.get("actor_id")!=id:return false
		if actor.get("population_group")=="debris":
			if actor.get("actor_kind")!=-1 or actor.get("hull_catalogue_id")!=-1:return false
		else:
			var hull: Variant=actor.get("hull_catalogue_id")
			var faction: Variant=actor.get("actor_kind")
			if not actor.get("contract_ship",false):return false
			if actor.get("subtype")==1:
				if actor.get("population_group")!="freighter" or hull!=load("res://src/content/free_population_definitions.gd").freighter_hull(bindings,int(faction)):return false
				continue
			if actor.get("subtype")!=0:return false
			if not hull is int or hull<0 or hull>=hulls.factions.size() or int(hulls.factions[hull])!=faction:return false
	return true


## Normal space is admitted by a completed living escape, not by a cursor or
## a caller-supplied location. The generic mission/free-flight entries stay shut.
func admit_normal_return(bindings: RefCounted,catalogues: RefCounted,transfer: RefCounted) -> bool:
	error=""
	if not _identity.is_empty():return reject("A mission context is admitted only once")
	if not is_instance_of(transfer,load("res://src/simulation/mission_portal_return.gd")) or transfer.snapshot().is_empty():return reject("Normal space requires its completed native mission return")
	var retained: Dictionary=transfer.snapshot()
	var recipe:=Recipe.select_flight(bindings,retained.campaign_cursor)
	if recipe.is_empty() or recipe.get("world_return",{})!={"kind":"normal_space","location":"retained_entry"}:return reject("This mission has no retained normal-space continuation")
	if catalogues==null or catalogues.content_id!=bindings.base_content_id:return reject("Normal return catalogues belong to another content source")
	for key in ["base_content_id","binding_id"]:
		if retained.get(key)!=bindings.get(key):return reject("Normal return belongs to another content source")
	var equipment: RefCounted=transfer.equipment_owner();var career: Dictionary=transfer.career_owner().snapshot()
	var loadout: Dictionary=equipment.snapshot().loadout
	if Slots.checked_slots(bindings,catalogues,loadout).is_empty() or not equipment.cargo_cache_valid():return reject("Normal return lost its installed equipment")
	if loadout.station_id!=retained.return_station_id or loadout.system_id!=retained.return_system_id or career.station_id!=loadout.station_id or career.campaign_cursor!=recipe.cursor or retained.mission!=recipe.mission:return reject("Normal return lost its retained location or active mission")
	# The ordinary unfinished story uses the existing empty-story factory. It
	# does not revive the Void cast or turn the independent passenger job into it.
	recipe.station_id=loadout.station_id;recipe.system_id=loadout.system_id
	recipe.entry="normal_space_return"
	recipe.world={"station":true,"portal":true,"asteroid_field":true,"normal_space":true}
	recipe.cast={"kind":"ordinary_empty"};recipe.sequences=[];recipe.radio=[]
	recipe.result.actor_count=0
	recipe.entry_release_ms=int(bindings.mido_travel.free_flight.launch_clear_after_ms)+1
	_recipe=recipe;_loadout=loadout.duplicate(true)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":recipe.cursor}
	# Do not keep the old Void frame/resources alive in the new world capability.
	_normal_return=RefCounted.new()
	_normal_progress={"rank":career.progress.rank,"difficulty":career.difficulty}
	return true

func normal_location(bindings: RefCounted,station_id: int,cursor: int) -> bool:
	return _normal_return!=null and has_feature("normal_space") and _identity.base_content_id==bindings.base_content_id and _identity.binding_id==bindings.binding_id and cursor==_recipe.cursor and station_id==_recipe.station_id

func ordinary_location(bindings: RefCounted,station_id: int,cursor: int) -> bool:
	return has_feature("station") and not has_feature("void_environment") and _identity.base_content_id==bindings.base_content_id and _identity.binding_id==bindings.binding_id and cursor==_recipe.cursor and station_id==_recipe.station_id

func world_observation(elapsed_ms: int) -> Dictionary:
	if _recipe.is_empty() or elapsed_ms<0:return {}
	return {"features":_recipe.world.duplicate(true),"station_id":_recipe.station_id,"elapsed_ms":elapsed_ms}

static func normal_combat_matches(bindings: RefCounted,combat: Dictionary,capability: RefCounted) -> bool:
	if not normal_population_matches(bindings,combat.get("free_context"),capability):return false
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if combat.get(key)!=capability.identity()[key]:return false
	return combat.get("actors") is Array and combat.actors.is_empty() and combat.get("provocation",{}).get("station_id")==capability.recipe().station_id

func normal_population_context(position: Vector3) -> Dictionary:
	if _normal_return==null or not position.is_finite():return {}
	var context:=_identity.duplicate()
	context.merge({"station_id":_recipe.station_id,"system_id":_recipe.system_id,"rank":_normal_progress.rank,"difficulty":_normal_progress.difficulty,
		"mission_kind":_recipe.mission.kind,"mission_completed":false,"mission_story":true,"companions_empty":true,
		"side_missions_empty":true,"station_response":false,"special_arrival":true,"void_encounter":false,"player_position":position})
	return context

static func normal_population_matches(bindings: RefCounted,context: Variant,capability: RefCounted) -> bool:
	if not is_instance_of(capability,load("res://src/simulation/mission_context.gd")) or not context is Dictionary or not context.get("player_position") is Vector3:return false
	return capability.normal_location(bindings,int(context.get("station_id",-1)),int(context.get("campaign_cursor",-1))) and context==capability.normal_population_context(context.player_position)

func admit(bindings: RefCounted,catalogues: RefCounted,context: Dictionary,loadout: Dictionary) -> bool:
	error=""
	if not _identity.is_empty():return reject("A mission context is admitted only once")
	var recipe:=Recipe.select_flight(bindings,context.get("campaign_cursor"))
	if recipe.is_empty():return reject("No complete recipe supports this mission")
	if recipe.entry=="retained_world":return reject("This mission must continue its acknowledged living world")
	if catalogues==null or catalogues.content_id!=bindings.base_content_id:return reject("Mission catalogues belong to another content source")
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key) or loadout.get(key)!=bindings.get(key):return reject("Mission entry belongs to another content source")
	for key in ["station_id","system_id"]:
		if context.get(key)!=recipe[key] or loadout.get(key)!=recipe[key]:return reject("Mission entry and equipped location disagree")
	if context.get("mission_kind")!=recipe.mission.kind or context.get("mission_story")!=true:return reject("The authored mission is not selected")
	if context.get("mission_completed")!=false or context.get("mission_failed",false)!=false:return reject("A completed mission cannot be entered again")
	if not _accept_equipment(bindings,catalogues,loadout):return false
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
	var source:=Recipe.select_flight(bindings,_recipe.cursor)
	var recipe:=Recipe.select_flight(bindings,_recipe.next_cursor)
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
func has_feature(name: String) -> bool:
	if not _legacy_flight.is_empty():
		if name=="station":return int(_legacy_flight.station_id)>=0
		if name=="void_environment":return int(_legacy_flight.station_id)<0
	return not _recipe.is_empty() and _recipe.world.get(name,false)
func ship_id() -> int:return int(_loadout.get("ship_id",-1))
func matches_factory(player_ship_id: int,equipment_ids: Array) -> bool:
	return not _recipe.is_empty() and player_ship_id==ship_id() and equipment_ids==_loadout.get("equipment_ids",[])
func matches_loadout(loadout: Dictionary) -> bool:
	if _identity.is_empty():return false
	for key in ["base_content_id","binding_id","station_id","system_id","ship_id","equipment_ids","slots"]:
		if loadout.get(key)!=_loadout.get(key):return false
	return not loadout.has("campaign_cursor") or loadout.campaign_cursor==_identity.campaign_cursor

func matches_source(bindings: RefCounted,departure: Dictionary) -> bool:
	if _recipe.is_empty():return false
	var current:=Recipe.select_flight(bindings,_recipe.cursor)
	return not current.is_empty() and current.source_receipt==_recipe.source_receipt and departure.get(_recipe.receipt_key,{})==_recipe.source_receipt

func accepts_result(cursor: int,mission: Dictionary,station_id: int) -> bool:
	return not _recipe.is_empty() and cursor==_recipe.next_cursor and mission==_recipe.next_mission and station_id==_recipe.station_id

func flight_rules(bindings: RefCounted) -> Dictionary:
	if _recipe.is_empty():return {}
	var result: Dictionary=bindings.first_flight.duplicate(true)
	result.campaign_cursor=_recipe.cursor;result.station_id=_recipe.station_id;result.system_id=_recipe.system_id
	result.mission_kind=_recipe.mission.kind;result.scope="mission_flight";result.erase("actor_count")
	return result

func ordinary_docking_rules() -> Dictionary:
	if _recipe.get("track")!="side_job" or not has_feature("station"):return {}
	return load("res://src/content/free_flight_definitions.gd")._docking_values(int(_recipe.station_id),int(_recipe.system_id),int(_recipe.cursor))

func reject(message: String) -> bool:error=message;return false
