extends RefCounted
## Compose an authored population once at encounter entry. The flight's existing
## combat, motion, hit and cargo owners consume this accepted construction.
const Sahi=preload("res://src/content/sahi_encounter_definitions.gd")
const Dima=preload("res://src/content/dima_encounter_definitions.gd")
const Post=preload("res://src/content/post_sahi_definitions.gd")
const BaseFlight=preload("res://src/content/first_flight_definitions.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const ControlRules=preload("res://src/content/combat_training_control_definitions.gd")
const Life=preload("res://src/content/contract_ship_lifecycle_definitions.gd")
const FreeLife=preload("res://src/content/free_lifecycle_definitions.gd")
const AliothLife=preload("res://src/content/alioth_lifecycle_definitions.gd")
const Weapons=preload("res://src/content/contract_ship_combat_definitions.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const FreighterDeath=preload("res://src/content/freighter_destruction_definitions.gd")
const World=preload("res://src/simulation/opening_world_initialization.gd")
const Equipment=preload("res://src/simulation/station_equipment.gd")
const VoidSource=preload("res://src/simulation/ordinary_void_source.gd")
const VoidCrystals=preload("res://src/content/void_crystal_definitions.gd")
const TrafficPopulation=preload("res://src/simulation/traffic_population.gd")

## Source story dispatch shares the verified ordinary placement, wormhole and
## camera constructor but does not make Sahi an ordinary FreeFlight destination.
static func entry_conditions(cursor: int) -> Dictionary:
	if cursor not in [24,25,26,28,29]:return {}
	return {"companions_empty":true,"location_match":cursor in [25,29],"special_placement":false}

static func flight(bindings: RefCounted,context: Dictionary) -> Dictionary:
	if bindings==null or not BaseFlight.parameters(bindings.first_flight) or not selected(bindings,context):return {}
	var result: Dictionary=bindings.first_flight.duplicate(true)
	result.scope="sahi_story_flight"
	for key in ["campaign_cursor","system_id","station_id","mission_kind"]:result[key]=int(context[key])
	result.erase("actor_count")
	return result

## The selected ordinary Void has no authored story cast or briefing. Its
## pending crystal mission remains in the career, separate from this sentinel.
static func ordinary_void_flight(bindings: RefCounted,context: Dictionary) -> Dictionary:
	if bindings==null or not BaseFlight.parameters(bindings.first_flight) or not VoidCrystals.selected_void(bindings.mido_travel,context):return {}
	var result: Dictionary=bindings.first_flight.duplicate(true)
	result.merge({"scope":"ordinary_void_flight","campaign_cursor":33,"system_id":-1,"station_id":-1,"mission_kind":-1},true)
	result.erase("actor_count")
	return result

static func prepared_ordinary_void(bindings: RefCounted,entry: Dictionary) -> bool:
	var context: Dictionary=entry.get("void_context",{})
	if ordinary_void_flight(bindings,context).is_empty():return false
	for key in ["base_content_id","binding_id"]:
		if entry.get(key)!=bindings.get(key):return false
	return entry.get("campaign_cursor")==33 and entry.get("location",{}).get("station_id") == -1 and entry.location.get("system_id") == -1 and entry.get("departure",{}).get("void_context")==context and entry.get("scenery",{}).get("world_initialization",{}).get("void_context")==context

static func prepared_entry(bindings: RefCounted,entry: Dictionary) -> bool:
	var context: Dictionary=entry.get("sahi_context",{})
	if not selected(bindings,context):return false
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if entry.get(key)!=context.get(key):return false
	return entry.get("location",{}).get("station_id")==context.station_id and entry.get("scenery",{}).get("world_initialization",{}).get("npc_construction",{}).get("sahi_context") == context

static func combat_population(bindings: RefCounted,combat: Dictionary) -> bool:
	if bindings==null or not Sahi.coherent(bindings.mido_travel):return false
	var cursor: Variant=combat.get("campaign_cursor")
	var dima: bool=cursor==28 and Dima.Thynome.coherent(bindings.mido_travel)
	var ordinary_void: bool=cursor is int and cursor==33 and VoidCrystals.parameters(bindings.mido_travel.get("void_crystals"))
	if cursor!=24 and not dima and not ordinary_void and (cursor not in [25,26,29] or not Post.portal_available(bindings.mido_travel,cursor)):return false
	var actors: Variant=combat.get("actors")
	var cast: Array=bindings.mido_travel.sahi_encounter.population.actors
	if dima:
		cast=[]
		for group in bindings.mido_travel.thynome_expedition.world28.cast.groups:
			for _index in int(group.count):cast.append({"actor_kind":int(group.actor_kind),"subtype":int(group.subtype),"hull_catalogue_id":int(group.hull_catalogue_id)})
	if cursor in [25,26,29]:
		var rule: Dictionary=bindings.mido_travel.post_sahi["void"].population if cursor in [25,29] else bindings.mido_travel.post_sahi.pursuers
		cast=[]
		for id in int(rule.count):cast.append({"actor_kind":int(rule.actor_kind),"subtype":int(rule.subtype),"hull_catalogue_id":int(rule.hull_catalogue_id)})
	if ordinary_void:
		# This cast comes from the ordinary factory, not either earlier story
		# visit's fixed two fighters. The generated rank owns its count bound.
		if not actors is Array or actors.is_empty() or not actors[0] is Dictionary:return false
		var rank: Variant=actors[0].get("rank")
		if not rank is int or not Numbers.integer(rank,0,bindings.opening_handoff.rank_thresholds.size()-1) or actors.size()>TrafficPopulation.maximum_void_actor_count_for_rank(bindings,rank):return false
		var rules: Dictionary=bindings.mido_travel.void_crystals.void_population
		cast=[]
		for actor in actors:
			if not actor is Dictionary or not actor.get("rank") is int or actor.rank!=rank or actor.get("campaign_cursor")!=33 or actor.get("station_id")!=-1 or actor.get("population_group")!="fighter":return false
			cast.append({"actor_kind":int(rules.actor_kind),"subtype":int(rules.actor_subtype),"hull_catalogue_id":int(rules.hull_id)})
	if not actors is Array or actors.size()!=cast.size():return false
	for id in actors.size():
		var actor: Variant=actors[id];var row: Dictionary=cast[id]
		if not actor is Dictionary or not actor.get("authored_story",false) or actor.get("actor_id")!=id:return false
		for key in ["actor_kind","subtype","hull_catalogue_id"]:
			if actor.get(key)!=int(row[key]):return false
		for key in ["base_content_id","binding_id"]:
			if actor.get(key)!=bindings.get(key):return false
	return true

static func compose(bindings: RefCounted,catalogues: RefCounted,packet: Dictionary) -> Dictionary:
	if bindings==null or catalogues==null or catalogues.content_id!=bindings.base_content_id:return {}
	if not Life.available(bindings) or not FreeLife.available(bindings) or not AliothLife.available(bindings) or not ControlRules.parameters(bindings.combat_training_control):return {}
	var context: Variant=packet.get("sahi_context")
	if not context is Dictionary or not selected(bindings,context):return {}
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key) or packet.get(key)!=bindings.get(key):return {}
	for key in ["campaign_cursor","station_id"]:
		if packet.get(key)!=context.get(key):return {}
	if not Numbers.integer(context.get("rank"),0,20) or context.get("difficulty") not in [0.5,1.0]:return {}
	var dima: bool=Dima.selected(bindings.mido_travel,context)
	var source: Dictionary=bindings.mido_travel.sahi_encounter.duplicate()
	if dima:source.population=Dima.population(bindings.mido_travel,context)
	elif context.campaign_cursor in [25,26,29]:source.population=Post.population(bindings.mido_travel,context)
	if source.population.is_empty():return {}
	var actors: Variant=packet.get("actors")
	if not actors is Array or actors.size()!=int(source.population.actor_count):return {}
	for id in actors.size():
		var row: Variant=actors[id];var expected: Dictionary=source.population.actors[id]
		if not row is Dictionary:return {}
		for key in ["actor_id","actor_kind","subtype","hull_catalogue_id"]:
			if not row.get(key) is int or row[key]!=int(expected[key]):return {}
		if not Flight.rigid_pose(row.get("body_pose")) or row.get("statistics_pose")!=row.body_pose:return {}
		if row.get("population_group")!=("freighter" if row.subtype==1 else "fighter"):return {}
		if row.subtype==1:
			if row.get("assembly")!=source.population.freighter_assembly or row.get("cargo")!=[] or row.get("hull_divisors")!=[int(source.population.freighter_hull_divisor)] or row.get("cruise_enabled")!=false:return {}
	var faction_system:=18 if context.campaign_cursor==29 else int(bindings.mido_travel.post_sahi["void"].return_system_id) if context.system_id==-1 else int(context.system_id)
	return _compose_population(bindings,catalogues,packet,context,source,actors,dima,faction_system,-1,false)

## Cursor33's population is generated by the ordinary factory; the retained
## source owner supplies the real system and station used by faction reactions.
## The selected flight remains Void(-1,-1), kind-1, nonstory.
static func compose_void(bindings: RefCounted,catalogues: RefCounted,generated_world: RefCounted,equipment: RefCounted,ordinary_void_source: RefCounted,difficulty: Variant) -> Dictionary:
	if bindings==null or catalogues==null or catalogues.content_id!=bindings.base_content_id or not generated_world is World or not equipment is Equipment or not ordinary_void_source is VoidSource:return {}
	if not Life.available(bindings) or not FreeLife.available(bindings) or not AliothLife.available(bindings) or not ControlRules.parameters(bindings.combat_training_control) or not Sahi.coherent(bindings.mido_travel):return {}
	if difficulty not in [0.5,1.0]:return {}
	var world: Dictionary=generated_world.snapshot()
	var packet: Variant=world.get("npc_construction")
	if not packet is Dictionary or world.get("campaign_cursor")!=33 or world.get("station_id")!=-1 or world.get("system_id")!=-1:return {}
	if world.get("entry_conditions")!={"companions_empty":true,"location_match":true,"special_placement":false}:return {}
	var context: Variant=world.get("void_context")
	if not context is Dictionary or not VoidCrystals.selected_void(bindings.mido_travel,context) or packet.get("void_context")!=context:return {}
	for key in ["base_content_id","binding_id"]:
		if world.get(key)!=bindings.get(key) or packet.get(key)!=bindings.get(key):return {}
	if not Numbers.integer(context.get("rank"),0,bindings.opening_handoff.rank_thresholds.size()-1):return {}
	var source: Dictionary=ordinary_void_source.snapshot()
	var source_system: Variant=source.get("source_system_id")
	var source_station: Variant=source.get("source_station_id")
	if source.get("base_content_id")!=bindings.base_content_id or source.get("binding_id")!=bindings.binding_id or not Numbers.integer(source_system,0,catalogues.tables.systems.size()-1) or not Numbers.integer(source_station,0,catalogues.tables.stations.size()-1):return {}
	if catalogues.tables.stations[source_station].system_id!=source_system:return {}
	var owned: Dictionary=equipment.snapshot();var loadout: Variant=owned.get("loadout")
	if not loadout is Dictionary or not equipment.cargo_cache_valid() or loadout.get("base_content_id")!=bindings.base_content_id or loadout.get("binding_id")!=bindings.binding_id:return {}
	var selected_loadout: bool=loadout.get("station_id")==-1 and loadout.get("system_id")==-1
	var station_loadout: bool=Numbers.integer(loadout.get("station_id"),0,catalogues.tables.stations.size()-1) and Numbers.integer(loadout.get("system_id"),0,catalogues.tables.systems.size()-1)
	if station_loadout:station_loadout=catalogues.tables.stations[loadout.station_id].system_id==loadout.system_id
	if (not selected_loadout and not station_loadout) or loadout.get("ship_id")!=packet.get("player_ship_id"):return {}
	var installed: Variant=loadout.get("equipment_ids")
	if not installed is Array or installed!=packet.get("player_equipment_ids"):return {}
	var actors: Variant=packet.get("actors")
	var count: Variant=packet.get("population",{}).get("actor_count")
	var maximum: int=TrafficPopulation.maximum_void_actor_count_for_rank(bindings,context.rank)
	if not actors is Array or not Numbers.integer(count,1,maximum) or actors.size()!=count or packet.population.get("mission_kind")!=-1 or packet.population.get("groups",{}).get("void")!=count:return {}
	var rules: Dictionary=bindings.mido_travel.void_crystals.void_population
	for id in actors.size():
		var row: Variant=actors[id]
		if not row is Dictionary or row.get("actor_id")!=id or row.get("actor_kind")!=int(rules.actor_kind) or row.get("subtype")!=int(rules.actor_subtype) or row.get("hull_catalogue_id")!=int(rules.hull_id) or row.get("population_group")!="fighter":return {}
		if not Flight.rigid_pose(row.get("body_pose")) or row.get("statistics_pose")!=row.body_pose or row.get("activation_setter_argument")!=int(rules.shared_activation_setter_argument) or row.get("activation_fields")!={"f8":1,"b60":1,"b61":0,"ec":1}:return {}
	var selected: Dictionary=context.duplicate(true)
	selected.merge({"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":33,"station_id":-1,"system_id":-1,"mission_kind":-1,"mission_story":false,"mission_completed":true,"difficulty":difficulty},true)
	var weapon_source: Dictionary=bindings.mido_travel.sahi_encounter.duplicate(true)
	var composed: Dictionary=_compose_population(bindings,catalogues,packet,selected,weapon_source,actors,false,int(source_system),int(source_station),true)
	if not composed.is_empty():composed.equipment_station_id=int(loadout.station_id)
	return composed

static func _compose_population(bindings: RefCounted,catalogues: RefCounted,packet: Dictionary,context: Dictionary,source: Dictionary,actors: Array,dima: bool,faction_system: int,source_station_id: int,ordinary_void: bool) -> Dictionary:
	var data: Dictionary=bindings.combat_training_control.duplicate(true)
	data.merge(context,true)
	data.authored_story=true;data.context_key="void_context" if ordinary_void else "sahi_context"
	data.actor_count=actors.size();data.actor_kinds=actors.map(func(row):return row.actor_kind)
	data.hull_catalogue_ids=actors.map(func(row):return row.hull_catalogue_id)
	data.actor_rows=actors.duplicate(true);data.context=context.duplicate(true)
	if not Numbers.integer(packet.get("player_ship_id"),0,catalogues.tables.ships.size()-1):return {}
	data.player_ship_id=packet.player_ship_id
	for key in ["initial_actor_mode","initial_active","initial_hostile","friendly","initial_actor_targeting_blocked","initial_statistics_targeting_blocked"]:
		data[key]=bindings.mido_travel.traffic_control[key]
	data.freighter=source.population.freighter_combat
	data.free_traffic=bindings.mido_travel.free_traffic
	data.standing=bindings.mido_travel.free_lifecycle.standing
	data.lifecycle=bindings.early_contracts.ship_lifecycle.duplicate(true)
	var population: Dictionary=bindings.mido_travel.free_population
	var faction:=int(catalogues.tables.systems[faction_system].fields[int(population.faction_field)])
	if faction<0 or faction>=population.enemy_factions.size():return {}
	data.lifecycle.reactions.primary_faction=faction
	data.lifecycle.reactions.eligible_factions=[faction,int(population.enemy_factions[faction])]
	data.cargo=bindings.combat_training_destruction.cargo
	data.nonhostile_remaining_delta=int(bindings.combat_training_destruction.nonhostile_remaining_delta)
	data.selection_skipped_modes=data.lifecycle.selection_skipped_modes
	data.actors=[];data.npc_weapons=[]
	data.player_weapon_targets=source.weapons.player_weapon_targets.map(func(id):return int(id))
	data.target_memberships=source.weapons.npc_target_memberships.map(func(ids):return ids.map(func(id):return int(id)))
	if dima:
		data.player_weapon_targets=range(actors.size())
		data.target_memberships=source.population.dima.target_memberships.map(func(ids):return ids.map(func(id):return int(id)))
	elif ordinary_void or context.campaign_cursor in [25,26,29]:
		data.player_weapon_targets=range(actors.size())
		data.target_memberships=actors.map(func(_actor):return [-1])
	var models: Array=data.lifecycle.cargo_models.duplicate()
	models.append(bindings.mido_travel.alioth_lifecycle.void_cargo)
	for actor in actors:
		var row: Dictionary={}
		for key in ["actor_id","actor_kind","hull_catalogue_id","subtype","population_group"]:row[key]=actor[key]
		for model in models:
			if int(model.actor_kind)==actor.actor_kind:
				row.cargo_model_id=int(model.cargo_model_id);row.cargo_model_resource=model.cargo_model_resource
		if not row.has("cargo_model_id"):return {}
		data.actors.append(row)
		var weapon:={"unarmed":true}
		if actor.population_group=="fighter":
			if actor.actor_kind==9:
				weapon=Weapons.scaled_parameters(bindings.early_contracts.ship_combat.weapons,int(context.campaign_cursor),int(context.rank),float(context.difficulty))
				if weapon.is_empty():return {}
				var original: Dictionary=source.weapons["void"]
				for key in ["item_id","kind","catalogue_kind","model_resource_id"]:weapon[key]=int(original[key])
				weapon.damage=int(Vitals.single(Vitals.single(float(weapon.damage))*float(original.damage_multiplier)))
			else:
				weapon=Weapons.shared_weapon(bindings.early_contracts.ship_combat.weapons,int(context.campaign_cursor),int(context.rank),float(context.difficulty),int(actor.actor_kind))
				if weapon.is_empty():return {}
		for key in ["actor_id","actor_kind","hull_catalogue_id"]:weapon[key]=actor[key]
		data.npc_weapons.append(weapon)
	var freight: Dictionary=FreighterDeath.for_alioth(bindings) if dima else bindings.freighter_destruction.duplicate(true)
	if freight.is_empty():return {}
	if not dima:freight.merge(bindings.mido_travel.free_lifecycle.nivelian_death,true)
	for key in ["campaign_cursor","station_id","system_id"]:freight[key]=int(context[key])
	freight.actor_kind=0 if dima else 2
	for model in models:
		if int(model.actor_kind)==freight.actor_kind:
			freight.cargo_model_id=int(model.cargo_model_id);freight.cargo_model_resource=model.cargo_model_resource
	data.freighter_death=freight
	if ordinary_void:
		# Internal shared-controller marker only: this is an ordinary nonstory
		# sentinel, with no authored cast or mission reward.
		data.ordinary_void=true
		data.source_system_id=faction_system
		data.source_station_id=source_station_id
	return data

## Detached/live combat composition only. This does not admit a departure,
## arrival, mission result or career transition to the unfinished chapter.
static func compose_dekato(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> Dictionary:
	var rules: Script=load("res://src/content/dekato_convoy_definitions.gd")
	if not is_instance_of(construction,load("res://src/simulation/opening_npc_construction.gd")):return {}
	if bindings==null or catalogues==null or catalogues.content_id!=bindings.base_content_id:return {}
	var packet: Dictionary=construction.snapshot()
	var context: Variant=packet.get("dekato_context")
	if not context is Dictionary or not rules.context_valid(bindings,context) or not ControlRules.parameters(bindings.combat_training_control) or not Life.available(bindings) or not FreeLife.available(bindings):return {}
	if not Sahi.coherent(bindings.mido_travel) or not Weapons.parameters(bindings.early_contracts.get("ship_combat")):return {}
	for key in ["base_content_id","binding_id","campaign_cursor","station_id","system_id"]:
		if packet.get(key)!=context[key]:return {}
	var actors: Variant=packet.get("actors")
	var source: Dictionary=rules.declarations(bindings).population
	if not actors is Array or actors.size()!=int(source.actor_count):return {}
	for id in actors.size():
		var row: Variant=actors[id]
		var freight: bool=id<int(source.freighter_count)
		if not row is Dictionary or row.get("actor_id")!=id or row.get("actor_kind")!=int(source.freighter_actor_kind if freight else source.escort_actor_kind):return {}
		if row.get("population_group")!=("freighter" if freight else "fighter") or row.get("subtype")!=(1 if freight else 0):return {}
		if freight and (row.get("friendly")!=true or row.get("cruise_enabled")!=false or row.get("hull_catalogue_id")!=int(source.freighter_hull_catalogue_id)):return {}
		if not freight and (row.get("script_hostile")!=true or construction.route(id)==null):return {}
	var kinds: Array=actors.map(func(row):return row.actor_kind)
	# Same Nivelian factory and combat boxes as Sahi, without Sahi's hull/cargo
	# overrides or its Void-specific target/weapon branch.
	var profile:={"population":{"freighter_combat":bindings.mido_travel.sahi_encounter.population.freighter_combat},
		"weapons":{"player_weapon_targets":range(actors.size()),"npc_target_memberships":Weapons.target_memberships(kinds)}}
	var data:=_compose_population(bindings,catalogues,packet,context,profile,actors,false,int(context.system_id),-1,false)
	if not data.is_empty():
		data.context_key="dekato_context"
		data.mission_recipe=load("res://src/content/mission_recipe.gd").select(bindings,context.campaign_cursor)
	return data

## Reuse the ordinary ship factory and lifecycle under the admitted return.
## The independent passenger job remains a separate retained career owner.
static func compose_normal_return(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,mission_context: RefCounted) -> Dictionary:
	if not is_instance_of(construction,load("res://src/simulation/opening_npc_construction.gd")) or catalogues==null or catalogues.content_id!=bindings.base_content_id:return {}
	var packet: Dictionary=construction.snapshot()
	var population:=FreeLife.population(bindings,packet,mission_context)
	if population.is_empty():return {}
	var data: Dictionary=bindings.combat_training_control.duplicate(true)
	data.merge(population,true)
	data.authored_story=true;data.actor_rows=packet.actors.duplicate(true)
	data.actor_kinds=packet.actors.map(func(row):return row.actor_kind)
	data.hull_catalogue_ids=packet.actors.map(func(row):return row.hull_catalogue_id)
	data.standing=bindings.mido_travel.free_lifecycle.standing.duplicate(true)
	data.nonhostile_remaining_delta=int(bindings.combat_training_destruction.nonhostile_remaining_delta)
	data.selection_skipped_modes=data.lifecycle.selection_skipped_modes
	data.context_key="free_context";data.context=packet.free_context.duplicate(true)
	data.player_ship_id=packet.player_ship_id
	data.player_weapon_targets=[];data.target_memberships=[]
	data.mission_context=mission_context;data.mission_recipe=mission_context.recipe()
	return data

static func selected(bindings: RefCounted,context: Dictionary) -> bool:
	return bindings!=null and (Sahi.selected(bindings.mido_travel,context) or Post.selected(bindings.mido_travel,context) or Dima.selected(bindings.mido_travel,context))

static func npc_hit(data: Dictionary,weapon: Dictionary) -> bool:
	for row in data.npc_weapons:
		if row.get("unarmed",false):continue
		var matches:=true
		for key in ["item_id","category","kind","damage","nonplayer_source"]:
			if weapon.get(key)!=row.get(key):matches=false;break
		if matches:return true
	return false
