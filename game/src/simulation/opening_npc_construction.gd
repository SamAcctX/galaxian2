extends RefCounted
const Difficulty=preload("res://src/content/difficulty_definitions.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
const Transit=preload("res://src/content/convoy_transit_definitions.gd")
const ContractDefinitions=preload("res://src/content/early_contract_definitions.gd")
const Bakka=preload("res://src/content/bakka_contest_definitions.gd")
const Dekato=preload("res://src/content/dekato_convoy_definitions.gd")
const Selected40=preload("res://src/content/selected40_population_definitions.gd")
const Selected41=preload("res://src/content/selected41_population_definitions.gd")
const FreePopulation=preload("res://src/content/free_population_definitions.gd")
const AmbientDefinitions=preload("res://src/content/ambient_population_definitions.gd")
const TrafficPopulation=preload("res://src/simulation/traffic_population.gd")
## Shared supported factory records from the RNG before the first NPC.
## Rescue and Gunant replace generated routes; ordinary pirates keep theirs.
## Live combat and target decisions have separate owners.
const Definitions = preload("res://src/content/npc_construction_definitions.gd")
const ArrivalDefinitions = preload("res://src/content/arrival_actor_construction_definitions.gd")
const FullHold = preload("res://src/content/full_hold_flight_definitions.gd")
const Training = preload("res://src/content/combat_training_definitions.gd")
const Travel = preload("res://src/content/mido_travel_definitions.gd")
const Equipment = preload("res://src/simulation/station_equipment.gd")
const ArrivalStaging = preload("res://src/content/arrival_staging_definitions.gd")
const ArrivalLocation = preload("res://src/simulation/arrival_location.gd")
const Poses = preload("res://src/simulation/opening_staging.gd")
const Route = preload("res://src/simulation/npc_route.gd")
const Random = preload("res://src/simulation/seeded_random.gd")
const Loadout = preload("res://src/simulation/opening_loadout.gd")
const Vitals = preload("res://src/simulation/combat_vitals.gd")
const Convoy = preload("res://src/content/convoy_world_definitions.gd")
const Kappa = preload("res://src/content/kappa_population_definitions.gd")
const Alioth = preload("res://src/content/alioth_attack_definitions.gd")
const Sahi = preload("res://src/content/sahi_encounter_definitions.gd")
const Dima = preload("res://src/content/dima_encounter_definitions.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")
const Vectors = preload("res://src/simulation/source_vectors.gd")
const Statics = preload("res://src/content/static_object_definitions.gd")
var error := ""
var _identity := {}
var _definition := {}
var _items := []
var _khador_fitted:=false
var _player_energy_cells:=0
var _routes := []
var _actors := []
var _random_state := {}
var _arrival := {}
var _full_hold := {}
var _training := {}
var _traffic := {}
var _ambient:={}
var _free:={}
var _population_owner: RefCounted
var _mission_context: RefCounted
var _traffic_sample := {}
var _authored_route: RefCounted
var _convoy:={}
var _alioth:={}
var _kappa:={}
var _sahi:={}
var _dekato:={}
var _selected40:={}
var _selected41:={}

func configure(bindings: RefCounted, catalogues: RefCounted) -> bool:
	clear()
	if bindings==null or catalogues==null: return reject("NPC construction requires content and bindings")
	var loadout := Loadout.new()
	if not loadout.configure(bindings,catalogues,bindings.base_content_id): return reject(loadout.error)
	var seed: Dictionary = loadout.snapshot()
	return _configure(bindings,catalogues,seed,{})

func configure_arrival(bindings: RefCounted, catalogues: RefCounted, cache: Variant) -> bool:
	clear()
	if bindings==null or not ArrivalDefinitions.parameters(bindings.arrival_actor_construction):
		return reject("Rescue actor construction is unavailable; prepare current resource bindings")
	if not ArrivalStaging.parameters(bindings.arrival_staging):return reject("Prepare current resource bindings for corrected rescue visibility")
	var location:=ArrivalLocation.new()
	var context:=location.resolve(bindings,catalogues,cache)
	if context.is_empty():return reject(location.error)
	if bindings.resolve_ship_model(int(bindings.arrival_actor_construction.hull_catalogue_id)).is_empty():return reject(bindings.error)
	return _configure(bindings,catalogues,context,bindings.arrival_actor_construction)

func configure_full_hold(bindings: RefCounted, catalogues: RefCounted, cache: Variant) -> bool:
	clear()
	if bindings==null or not FullHold.parameters(bindings.full_hold_flight):return reject("Second-flight NPC construction is unavailable")
	var location:=ArrivalLocation.new()
	var context:=location.resolve_departure(bindings,catalogues,cache)
	if context.is_empty():return reject(location.error)
	if context.campaign_cursor!=int(bindings.full_hold_flight.campaign_cursor):return reject("Second-flight NPC requires its own departure cache")
	if bindings.resolve_ship_model(int(bindings.full_hold_flight.hull_catalogue_id)).is_empty():return reject(bindings.error)
	return _configure(bindings,catalogues,context,{},bindings.full_hold_flight)

func configure_combat_training(bindings: RefCounted, catalogues: RefCounted, equipment: RefCounted, player_position: Variant) -> bool:
	clear()
	if bindings==null or catalogues==null or not Training.parameters(bindings.combat_training):return reject("Combat-training construction is unavailable")
	if not equipment is Equipment or not equipment.requirements().satisfied:return reject("Combat training requires owned and installed tutorial equipment")
	var seed: Dictionary=equipment.snapshot().loadout
	if seed.base_content_id!=bindings.base_content_id or seed.binding_id!=bindings.binding_id or catalogues.content_id!=bindings.base_content_id:return reject("Combat-training equipment belongs to another content identity")
	if not player_position is Vector3 or not player_position.is_finite():return reject("Combat training requires a finite source player position")
	var position:=Vector3.ZERO
	for axis in 3:position[axis]=Vitals.single(Vitals.single(player_position[axis])+float(bindings.combat_training.companion_position_offset[axis]))
	if not position.is_finite():return reject("Companion placement exceeds source precision")
	for id in [bindings.combat_training.pirate_hull_catalogue_id,bindings.combat_training.companion_hull_catalogue_id]:
		if bindings.resolve_ship_model(int(id)).is_empty():return reject(bindings.error)
	var route:=Route.new()
	if not route.configure_training_authored(bindings):return reject(route.error)
	if not _configure(bindings,catalogues,seed,{},{},bindings.combat_training):return false
	_training.companion_position=position;_authored_route=route
	return true

func configure_local_traffic(bindings: RefCounted, catalogues: RefCounted, equipment: RefCounted, unix_seconds: Variant) -> bool:
	clear()
	if bindings==null or catalogues==null or not Travel.parameters(bindings.mido_travel):return reject("Local traffic construction is unavailable")
	if not equipment is Equipment:return reject("Local traffic requires its retained equipment owner")
	var owned: Dictionary=equipment.snapshot()
	if not owned.get("training_inventory_released",false) or not owned.get("prototype_drill_replaced",false) or not equipment.requirements().satisfied:return reject("Local traffic requires the released training inventory and drill exchange")
	var data: Dictionary=bindings.mido_travel.departure_traffic
	var seed: Dictionary=owned.loadout
	if catalogues.content_id!=bindings.base_content_id or seed.base_content_id!=bindings.base_content_id or seed.binding_id!=bindings.binding_id:return reject("Local traffic belongs to another content identity")
	for key in ["ship_id","station_id","system_id"]:
		if seed[key]!=int(data[key]):return reject("Local traffic requires its Var Hastra departure")
	if not unix_seconds is int or unix_seconds<0 or unix_seconds>2147483647:return reject("Local traffic requires explicit supported Unix seconds")
	if catalogues.tables.systems[int(data.system_id)].fields[2]!=int(data.actor_kind):return reject("Local traffic changed the source system faction")
	for hull in data.hull_candidates:
		if bindings.resolve_ship_model(int(hull)).is_empty():return reject(bindings.error)
	if not _configure(bindings,catalogues,seed,{},{},{},data):return false
	_traffic.unix_seconds=unix_seconds
	return true

func configure_ambient_traffic(bindings: RefCounted,catalogues: RefCounted,equipment: RefCounted,context: Dictionary,unix_seconds: Variant) -> bool:
	clear()
	var population:=TrafficPopulation.new()
	if not population.configure(bindings,context,unix_seconds):return reject(population.error)
	if catalogues==null or not equipment is Equipment:return reject("Ambient construction requires its retained equipment and catalogues")
	var owned: Dictionary=equipment.snapshot()
	if not owned.get("training_inventory_released",false) or not owned.get("prototype_drill_replaced",false) or not equipment.requirements().satisfied:return reject("Ambient construction requires the completed equipment tutorial and exchange")
	var seed: Dictionary=owned.loadout
	if seed.base_content_id!=bindings.base_content_id or seed.binding_id!=bindings.binding_id or catalogues.content_id!=bindings.base_content_id:return reject("Ambient construction belongs to another content identity")
	for key in ["station_id","system_id"]:
		if seed[key]!=context[key]:return reject("Ambient construction does not match the retained player location")
	var ambient: Dictionary=bindings.ambient_population
	if catalogues.tables.systems[int(context.system_id)].fields[2]!=int(ambient.actor_kind):return reject("Ambient construction changed the system faction")
	var data: Dictionary=bindings.mido_travel.departure_traffic.duplicate(true)
	data.station_id=int(context.station_id);data.campaign_cursor=int(context.campaign_cursor)
	data.ambient=true
	for hull in data.hull_candidates:
		if bindings.resolve_ship_model(int(hull)).is_empty():return reject(bindings.error)
	# Freighter 15 uses the separate assembly factory. Its raw hull-table entry
	# is not a registered mesh; rendering must resolve the assembly separately.
	if int(ambient.freighter.hull_catalogue_id)>=catalogues.tables.ships.size():return reject("The freighter catalogue entry is absent")
	for key in ["root_model_id","light_model_id","engine_model_id","container_model_id","container_lod_model_id","lod_model_id"]:
		if bindings.resolve(int(ambient.freighter.assembly[key]),"mesh").is_empty():return reject(bindings.error)
	if not _configure(bindings,catalogues,seed,{},{},{},data):return false
	_traffic.unix_seconds=unix_seconds;_ambient=ambient.duplicate(true);_population_owner=population
	return true

func configure_free_traffic(bindings: RefCounted,catalogues: RefCounted,equipment: RefCounted,context: Dictionary,unix_seconds: Variant,mission_context: RefCounted=null) -> bool:
	clear()
	if bindings==null or not equipment is Equipment:return reject("Ordinary construction requires its retained equipment")
	var owned: Dictionary=equipment.snapshot()
	if not owned.get("training_inventory_released",false) or not owned.get("prototype_drill_replaced",false) or not equipment.cargo_cache_valid():return reject("Ordinary construction requires the retained released inventory")
	if not preload("res://src/content/ordinary_fitting_definitions.gd").available(bindings) and not equipment.requirements().satisfied:return reject("This profile requires the retained tutorial equipment")
	var seed: Dictionary=owned.loadout
	if seed.base_content_id!=bindings.base_content_id or seed.binding_id!=bindings.binding_id:return reject("Ordinary construction belongs to another content identity")
	for key in ["station_id","system_id"]:
		if seed[key]!=context.get(key):return reject("Ordinary construction does not match the retained player location")
	if mission_context!=null and (not is_instance_of(mission_context,load("res://src/simulation/mission_context.gd")) or not mission_context.matches_loadout(seed)):return reject("Ordinary factory equipment differs from its admitted mission")
	if not configure_free_factory(bindings,catalogues,int(seed.ship_id),seed.equipment_ids,context,unix_seconds,mission_context):return false
	return retain_player_cargo(equipment)

func configure_free_factory(bindings: RefCounted,catalogues: RefCounted,player_ship_id: int,equipment_ids: Array,context: Dictionary,unix_seconds: Variant,mission_context: RefCounted=null) -> bool:
	# Detached factory inputs. The session owns permission to depart and the
	# retained player; this method neither creates nor updates gameplay progress.
	clear()
	var population:=TrafficPopulation.new()
	if not population.configure_free(bindings,catalogues,context,unix_seconds,mission_context):return reject(population.error)
	if mission_context!=null and not mission_context.matches_factory(player_ship_id,equipment_ids):return reject("Ordinary factory changed the admitted player ship or equipment")
	if player_ship_id<0 or player_ship_id>=catalogues.tables.ships.size():return reject("Unknown player ship for cargo construction")
	for id in equipment_ids:
		if not id is int or id<0 or id>=catalogues.tables.items.size():return reject("Unknown installed equipment for cargo construction")
	var rules: Dictionary=bindings.mido_travel.free_population
	var hulls: Dictionary=bindings.early_contracts.encounter_construction.hulls
	var local_faction: int=int(catalogues.tables.systems[int(context.system_id)].fields[int(rules.faction_field)])
	for faction in [local_faction,int(rules.pirate_faction),int(rules.enemy_factions[local_faction])]:
		for hull in int(hulls.draw_bound):
			if int(hulls.factions[hull])!=faction or (hull<=int(hulls.mask_limit) and (int(hulls.excluded_mask)&(1<<hull))!=0):continue
			if bindings.resolve_ship_model(hull).is_empty():return reject(bindings.error)
	if bindings.resolve_ship_model(int(hulls.early_vossk_hull)).is_empty():return reject(bindings.error)
	var assemblies: Dictionary=FreePopulation.assemblies(bindings)
	for faction in [local_faction,int(rules.freighter_alternate_factions[local_faction])]:
		var assembly: Dictionary=assemblies.get(str(faction),{})
		if assembly.is_empty():return reject("Unsupported local freighter assembly")
		var resources: Array=[]
		if faction==int(bindings.ambient_population.actor_kind):
			for key in ["root_model_id","light_model_id","engine_model_id","container_model_id","container_lod_model_id","lod_model_id"]:resources.append(assembly[key])
		else:
			resources=assembly.body_resource_ids.duplicate()
			var empty_children: Array=FreePopulation.empty_child_resources(bindings,assembly)
			for children in assembly.child_resource_ids:
				for child in children:
					if child not in empty_children:resources.append(child)
		for resource in resources:
			if bindings.resolve(int(resource),"mesh").is_empty():return reject(bindings.error)
	var data: Dictionary=bindings.mido_travel.departure_traffic.duplicate(true)
	data.merge({"station_id":int(context.station_id),"system_id":int(context.system_id),"campaign_cursor":int(context.campaign_cursor),"actor_kind":local_faction,"ambient":true,"free_context":context.duplicate(true),"free_player_ship_id":player_ship_id},true)
	var seed:={"ship_id":player_ship_id,"equipment_ids":equipment_ids.duplicate(),"station_id":int(context.station_id)}
	_mission_context=mission_context
	if not _configure(bindings,catalogues,seed,{},{},{},data):return false
	_traffic.unix_seconds=unix_seconds;_ambient=bindings.ambient_population.duplicate(true)
	_free=rules.duplicate(true);_free.hulls=hulls.duplicate(true);_population_owner=population
	_free.freighter_assemblies=assemblies
	_free.freighter_hulls={}
	for faction in assemblies:_free.freighter_hulls[faction]=FreePopulation.freighter_hull(bindings,int(faction))
	if not context.side_missions_empty:_free.delivery=bindings.mido_travel.ordinary_contracts.population.duplicate(true)
	if context.special_arrival:_free.arrival=bindings.mido_travel.free_arrival.duplicate(true)
	return true

## Detached ordinary Void actor factory. The caller supplies earned equipment
## and the selected world context; this owner does not advance cursor33.
func configure_void_factory(bindings: RefCounted,catalogues: RefCounted,player_ship_id: int,equipment_ids: Array,context: Dictionary) -> bool:
	clear()
	var population:=TrafficPopulation.new()
	if not population.configure_void(bindings,context):return reject(population.error)
	if catalogues==null or catalogues.content_id!=bindings.base_content_id:return reject("Void construction requires its matching imported catalogue")
	if not Numbers.integer(player_ship_id,0,catalogues.tables.ships.size()-1):return reject("Void construction requires an earned catalogue ship")
	for id in equipment_ids:
		if not Numbers.integer(id,0,catalogues.tables.items.size()-1):return reject("Void construction requires installed catalogue equipment")
	var rules: Dictionary=bindings.mido_travel.void_crystals.void_population
	if bindings.resolve_ship_model(int(rules.hull_id)).is_empty():return reject(bindings.error)
	var traffic:={"campaign_cursor":int(context.campaign_cursor),"station_id":int(context.selected_station_id),
		"system_id":int(context.selected_system_id),"actor_kind":int(rules.actor_kind),"subtype":int(rules.actor_subtype),
		"void_context":context.duplicate(true),"void_rules":rules.duplicate(true),
		"void_maximum_count":population.maximum_void_actor_count(),"void_player_ship_id":player_ship_id,
		"void_equipment_ids":equipment_ids.duplicate()}
	var seed:={"ship_id":player_ship_id,"equipment_ids":equipment_ids.duplicate(),"station_id":-1,"system_id":-1}
	if not _configure(bindings,catalogues,seed,{},{},{},traffic):return false
	_population_owner=population
	_identity.station_id=-1;_identity.system_id=-1
	return true

func configure_contract(bindings: RefCounted,catalogues: RefCounted,equipment: RefCounted,contracts: RefCounted,player_position: Vector3,field_center: Vector3,capability: RefCounted=null) -> bool:
	clear()
	if capability==null:
		capability=load("res://src/simulation/mission_context.gd").new()
		if not capability.admit_contract(bindings,catalogues,contracts,equipment):return reject(capability.error)
	elif not capability.matches_loadout(equipment.snapshot().loadout) or (not capability.void_story() and capability.contract_context()!=contracts.flight_context(int(equipment.snapshot().loadout.station_id),bindings)):return reject("Contract construction differs from its admitted career and equipment")
	if not player_position.is_finite() or not field_center.is_finite():return reject("Contract construction requires finite player and asteroid-field positions")
	var seed: Dictionary=equipment.snapshot().loadout
	var context: Dictionary=capability.contract_context()
	var recipe: Dictionary=capability.recipe()
	var rules: Dictionary=recipe.cast.operations
	var count: int=recipe.cast.actor_count
	var has_rival: bool=recipe.cast.rival_actor_id>=0
	var factions: Array=[int(rules.pirate_actor_kind)]
	if has_rival:factions.append(int(context.client_faction))
	var opposite:=int([1,0,3,2][int(recipe.cast.local_faction)])
	for group in recipe.cast.ship_groups:
		var faction: int=opposite if int(group.faction)==-2 else int(group.faction)
		if faction not in factions:factions.append(faction)
	var possible_hulls:=[]
	if count>int(recipe.cast.debris_count):
		for hull in int(rules.hulls.draw_bound):
			if hull<=int(rules.hulls.mask_limit) and (int(rules.hulls.excluded_mask)&(1<<hull))!=0:continue
			var faction:=int(rules.hulls.factions[hull])
			if faction in factions:possible_hulls.append(hull)
		if int(rules.hulls.early_vossk_faction) in factions:possible_hulls.append(int(rules.hulls.early_vossk_hull))
		for group in recipe.cast.ship_groups:
			if int(group.get("hull_catalogue_id",-1))>=0:possible_hulls.append(int(group.hull_catalogue_id))
	for hull in possible_hulls:
		if bindings.resolve_ship_model(hull).is_empty():return reject(bindings.error)
	for group in recipe.cast.ship_groups:
		var placed: Variant=group.get("static_object",{})
		if not placed is Dictionary or (not placed.is_empty() and not Statics.supported(placed.get("model"))):return reject("The cast places an unsupported static object")
	if int(recipe.cast.debris_count)>0:
		for resource_id in rules.junk.model_ids:
			if bindings.resolve(int(resource_id),"mesh").is_empty():return reject(bindings.error)
	var definition: Dictionary=rules.duplicate(true)
	definition.freighter_hulls={};definition.freighter_assemblies={}
	definition.freighter_cargo={}
	for group in recipe.cast.ship_groups:
		if group.get("subtype",0)!=1:continue
		if not group.get("clear_cargo",false):definition.freighter_cargo=bindings.ambient_population.freighter.duplicate(true)
		var faction:=int(group.faction)
		var assembly:=FreePopulation.freighter_assembly(bindings,faction)
		if assembly.is_empty():return reject("The admitted freighter has no original assembly")
		definition.freighter_hulls[faction]=FreePopulation.freighter_hull(bindings,faction)
		definition.freighter_assemblies[faction]=assembly.duplicate(true)
	definition.merge({"context":context,"actor_count":count,"debris_count":recipe.cast.debris_count,"ship_state":recipe.cast.ship_state,"player_position":player_position,"field_center":field_center})
	definition.placement=recipe.cast.placement;definition.rival_actor_id=recipe.cast.rival_actor_id
	definition.count_draw=recipe.cast.count_draw;definition.ship_groups=recipe.cast.ship_groups
	if not recipe.cast.ship_groups.is_empty():definition.alternate_enemy_faction=opposite
	definition.campaign_cursor=context.campaign_cursor
	_mission_context=capability
	return _configure(bindings,catalogues,seed,{},{},{},{},definition)

func configure_convoy(bindings: RefCounted,catalogues: RefCounted,equipment: RefCounted,context: Dictionary) -> bool:
	clear()
	if not Convoy.context_valid(bindings,context) or catalogues==null or not equipment is Equipment:return reject("Convoy construction requires its active Kernstal story and retained inventory")
	var owned: Dictionary=equipment.snapshot()
	if not owned.get("training_inventory_released",false) or not owned.get("prototype_drill_replaced",false) or not equipment.cargo_cache_valid() or not equipment.requirements().satisfied:return reject("Convoy construction requires the completed equipment tutorial and exchange")
	var seed: Dictionary=owned.loadout
	if seed.base_content_id!=bindings.base_content_id or seed.binding_id!=bindings.binding_id or catalogues.content_id!=bindings.base_content_id:return reject("Convoy construction belongs to another content identity")
	if not load("res://src/simulation/mission_context.gd").base_player_hull(bindings,seed.ship_id) or seed.station_id!=context.station_id or seed.system_id!=context.system_id:return reject("Convoy construction requires the retained ship at Kernstal")
	var data: Dictionary=bindings.mido_travel.convoy_capture.population.duplicate(true)
	for row in data.actors:
		if int(row.subtype)==0 and bindings.resolve_ship_model(int(row.hull_catalogue_id)).is_empty():return reject(bindings.error)
	data.capital=bindings.mido_travel.convoy_ship.duplicate(true);data.context=context.duplicate(true)
	return _configure(bindings,catalogues,seed,{},{},{},{},{},data)

func configure_alioth_attack(bindings: RefCounted,catalogues: RefCounted,seed: Dictionary,context: Dictionary,player_position: Vector3) -> bool:
	clear()
	# A construction seed describes an already selected encounter. The station
	# session remains responsible for earned departure and the retained inventory.
	if not Alioth.available(bindings) or catalogues==null:return reject("Alioth construction requires its original content")
	var source: Dictionary=bindings.mido_travel.alioth_attack
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key) or seed.get(key)!=bindings.get(key):return reject("Alioth construction belongs to another content identity")
	for key in ["campaign_cursor","station_id","system_id","mission_kind"]:
		if not context.get(key) is int or context[key]!=int(source[key]):return reject("Alioth construction requires its selected station attack")
	if context.get("mission_story")!=true or context.get("mission_completed")!=false or not Numbers.integer(context.get("rank"),0,20) or not Difficulty.valid(context.get("difficulty")):return reject("Alioth construction has an unsupported mission context")
	if catalogues.content_id!=bindings.base_content_id or not load("res://src/simulation/mission_context.gd").base_player_hull(bindings,seed.get("ship_id")) or seed.get("station_id")!=context.station_id or seed.get("system_id")!=context.system_id:return reject("Alioth construction requires the retained ship at Alioth")
	var ids: Variant=seed.get("equipment_ids")
	if not ids is Array or ids.any(func(id):return not Numbers.integer(id,0,catalogues.tables.items.size()-1)):return reject("Alioth construction requires installed catalogue equipment")
	if not player_position.is_finite():return reject("Alioth escorts require the current player position")
	var data: Dictionary=source.population.duplicate(true)
	for row in data.actors:
		if int(row.subtype)==0 and bindings.resolve_ship_model(int(row.hull_catalogue_id)).is_empty():return reject(bindings.error)
	for id in data.freighter_assembly.body_resource_ids:
		if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	for children in data.freighter_assembly.child_resource_ids:
		for id in children:
			if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	data.context=context.duplicate(true);data.player_position=player_position
	return _configure(bindings,catalogues,seed,{},{},{},{},{},{},data)

func configure_bakka(bindings: RefCounted,catalogues: RefCounted,seed: Dictionary,context: Dictionary,player_position: Vector3) -> bool:
	clear()
	if not Bakka.context_valid(bindings,context) or catalogues==null:return reject("Bakka construction requires its selected story context")
	if not ContractDefinitions.encounter_parameters(bindings.early_contracts):return reject("Bakka requires the shared small-ship construction declarations")
	for key in ["base_content_id","binding_id","station_id","system_id"]:
		if seed.get(key)!=context[key]:return reject("Bakka equipment belongs to another content identity or location")
	if catalogues.content_id!=bindings.base_content_id or not Numbers.integer(seed.get("ship_id"),0,catalogues.tables.ships.size()-1):return reject("Bakka requires a retained catalogue ship")
	var ids: Variant=seed.get("equipment_ids")
	if not ids is Array or ids.any(func(id):return not Numbers.integer(id,0,catalogues.tables.items.size()-1)):return reject("Bakka requires installed catalogue equipment")
	if not player_position.is_finite():return reject("Bakka requires a finite player position")
	var recipe:=Bakka.construction_recipe(bindings,context,player_position)
	if bindings.resolve_ship_model(int(recipe.rival_hull)).is_empty():return reject(bindings.error)
	for id in recipe.hulls.factions.size():
		if int(recipe.hulls.factions[id])==int(recipe.pirate_actor_kind) and not (id<=int(recipe.hulls.mask_limit) and (int(recipe.hulls.excluded_mask)&(1<<id))!=0) and bindings.resolve_ship_model(id).is_empty():return reject(bindings.error)
	recipe.loadout=seed.duplicate(true)
	return _configure(bindings,catalogues,seed,{},{},{},{},recipe)

func configure_dekato(bindings: RefCounted,catalogues: RefCounted,seed: Dictionary,context: Dictionary) -> bool:
	clear()
	var recipe:=Dekato.construction_recipe(bindings,context)
	if recipe.is_empty() or catalogues==null:return reject("Dekato construction requires its source-selected story and shared factories")
	for key in ["base_content_id","binding_id","station_id","system_id"]:
		if seed.get(key)!=context[key]:return reject("Dekato loadout belongs to another content identity or location")
	if catalogues.content_id!=bindings.base_content_id or not Numbers.integer(seed.get("ship_id"),0,catalogues.tables.ships.size()-1):return reject("Dekato requires a retained catalogue ship")
	var ids: Variant=seed.get("equipment_ids")
	if not ids is Array or ids.any(func(id):return not Numbers.integer(id,0,catalogues.tables.items.size()-1)):return reject("Dekato requires installed catalogue equipment")
	for id in recipe.hulls.factions.size():
		if int(recipe.hulls.factions[id])==int(recipe.escort_actor_kind) and not (id<=int(recipe.hulls.mask_limit) and (int(recipe.hulls.excluded_mask)&(1<<id))!=0) and bindings.resolve_ship_model(id).is_empty():return reject(bindings.error)
	for id in recipe.freighter_assembly.body_resource_ids:
		if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	for children in recipe.freighter_assembly.child_resource_ids:
		for id in children:
			if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	recipe.loadout=seed.duplicate(true)
	return _configure(bindings,catalogues,seed,{},{},{},{},{},{},{},{},{},recipe)

func configure_kappa_rescue(bindings: RefCounted,catalogues: RefCounted,seed: Dictionary,context: Dictionary) -> bool:
	clear()
	if not Kappa.context_valid(bindings,context) or catalogues==null:return reject("Kappa construction requires its original rescue context")
	for key in ["base_content_id","binding_id","station_id","system_id"]:
		if seed.get(key)!=context[key]:return reject("Kappa loadout belongs to another content identity or location")
	if catalogues.content_id!=bindings.base_content_id or not load("res://src/simulation/mission_context.gd").base_player_hull(bindings,seed.get("ship_id")):return reject("Kappa construction requires the admitted player hull")
	var ids: Variant=seed.get("equipment_ids")
	if not ids is Array or ids.any(func(id):return not Numbers.integer(id,0,catalogues.tables.items.size()-1)):return reject("Kappa construction requires installed catalogue equipment")
	var data: Dictionary=bindings.mido_travel.kappa_rescue.population.duplicate(true)
	for row in data.actors:
		if bindings.resolve_ship_model(int(row.hull_catalogue_id)).is_empty():return reject(bindings.error)
	data.context=context.duplicate(true)
	data.permanent_friendly=bool(bindings.mido_travel.kappa_fighters.initial_permanent_friendly)
	data.loadout=seed.duplicate(true)
	return _configure(bindings,catalogues,seed,{},{},{},{},{},{},{},data)

func configure_sahi(bindings: RefCounted,catalogues: RefCounted,seed: Dictionary,context: Dictionary) -> bool:
	clear()
	var post_rules=load("res://src/content/post_sahi_definitions.gd")
	var post: bool=bindings!=null and post_rules.selected(bindings.mido_travel,context)
	var dima: bool=bindings!=null and Dima.selected(bindings.mido_travel,context)
	if bindings==null or catalogues==null or not (post or dima or Sahi.selected(bindings.mido_travel,context)):return reject("Story construction requires its selected source context")
	for key in ["base_content_id","binding_id"]:
		if seed.get(key)!=bindings.get(key) or context.get(key)!=bindings.get(key):return reject("Sahi construction belongs to another content identity")
	for key in ["station_id","system_id"]:
		if seed.get(key)!=context.get(key):return reject("Sahi construction requires retained equipment at the selected world")
	if catalogues.content_id!=bindings.base_content_id or not Numbers.integer(seed.get("ship_id"),0,catalogues.tables.ships.size()-1):return reject("Sahi construction requires a valid retained ship")
	var ids: Variant=seed.get("equipment_ids")
	if not ids is Array or ids.any(func(id):return not Numbers.integer(id,0,catalogues.tables.items.size()-1)):return reject("Sahi construction requires installed catalogue equipment")
	var data: Dictionary=post_rules.population(bindings.mido_travel,context) if post else (Dima.population(bindings.mido_travel,context) if dima else bindings.mido_travel.sahi_encounter.population.duplicate(true))
	if data.is_empty():return reject("Dima construction requires its relocated portal position")
	if post and context.campaign_cursor==26:
		if not load("res://src/simulation/npc_flight.gd").rigid_pose(context.get("player_pose")):return reject("Pursuers require the actual returning player pose")
		data.player_pose=context.player_pose
	var factory: Dictionary=bindings.opening_actors.get("npc_initialization",{}).get("construction",{})
	if data.factory_spawn_offset!=factory.get("spawn_origin") or int(data.factory_spawn_bound)!=int(factory.get("spawn_bound",-1)):return reject("Sahi construction disagrees with the shared source factory")
	for row in data.actors:
		if int(row.subtype)==0 and bindings.resolve_ship_model(int(row.hull_catalogue_id)).is_empty():return reject(bindings.error)
	for id in data.freighter_assembly.body_resource_ids:
		if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	for children in data.freighter_assembly.child_resource_ids:
		for id in children:
			if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	data.context=context.duplicate(true);data.loadout=seed.duplicate(true)
	return _configure(bindings,catalogues,seed,{},{},{},{},{},{},{},{},data)

## Detached cast construction using the retained origin loadout. No player,
## station, campaign cursor or special-world owner is changed here.
func configure_selected40(bindings: RefCounted,catalogues: RefCounted,seed: Dictionary,context: Dictionary) -> bool:
	clear()
	var recipe:=Selected40.construction_recipe(bindings,context)
	if recipe.is_empty() or catalogues==null:return reject("Selected40 construction requires its explicit original source and origin")
	for key in ["base_content_id","binding_id"]:
		if seed.get(key)!=context[key]:return reject("Selected40 loadout belongs to another content identity")
	if seed.get("station_id")!=context.origin_station_id or seed.get("system_id")!=context.origin_system_id:return reject("Selected40 requires the retained origin, not a fabricated special station")
	if catalogues.content_id!=bindings.base_content_id or not Numbers.integer(seed.get("ship_id"),0,catalogues.tables.ships.size()-1):return reject("Selected40 requires a retained catalogue ship")
	var ids: Variant=seed.get("equipment_ids")
	if not ids is Array or ids.any(func(id):return not Numbers.integer(id,0,catalogues.tables.items.size()-1)):return reject("Selected40 requires retained catalogue equipment")
	for id in recipe.hulls.factions.size():
		if int(recipe.hulls.factions[id])==int(recipe.escort_actor_kind) and not (id<=int(recipe.hulls.mask_limit) and (int(recipe.hulls.excluded_mask)&(1<<id))!=0) and bindings.resolve_ship_model(id).is_empty():return reject(bindings.error)
	if bindings.resolve_ship_model(int(recipe.void_hull_catalogue_id)).is_empty():return reject(bindings.error)
	for id in recipe.freighter_assembly.body_resource_ids:
		if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	for children in recipe.freighter_assembly.child_resource_ids:
		for id in children:
			if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	recipe.loadout=seed.duplicate(true)
	return _configure(bindings,catalogues,seed,{},{},{},{},{},{},{},{},{},{},recipe)

func configure_selected41(bindings: RefCounted,catalogues: RefCounted,entry: RefCounted) -> bool:
	clear()
	if not is_instance_of(entry,load("res://src/simulation/selected41_portal_entry.gd")) or entry.snapshot().is_empty():return reject("Source41 construction requires its native late-portal transaction")
	var equipment: RefCounted=entry.equipment_owner()
	var seed: Dictionary=equipment.snapshot().loadout
	var recipe:=Selected41.construction_recipe(bindings,entry.snapshot().context)
	if recipe.is_empty() or catalogues==null or catalogues.content_id!=bindings.base_content_id or not equipment.cargo_cache_valid():return reject("Source41 construction requires matching original content and inventory")
	if seed.get("station_id")!=-1 or seed.get("system_id")!=-1 or not Numbers.integer(seed.get("ship_id"),0,catalogues.tables.ships.size()-1):return reject("Source41 inventory was not relocated by the native portal")
	if load("res://src/simulation/equipment_slots.gd").checked_slots(bindings,catalogues,seed).is_empty():return reject("Source41 requires actual ordered installed equipment")
	if bindings.resolve_ship_model(int(recipe.fighter_hull_catalogue_id)).is_empty():return reject(bindings.error)
	for id in recipe.freighter_assembly.body_resource_ids:
		if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	var empty_children: Array=Selected41.Previous.Population.empty_child_resources(bindings,recipe.freighter_assembly)
	for children in recipe.freighter_assembly.child_resource_ids:
		for id in children:
			if id in empty_children:continue
			if bindings.resolve(int(id),"mesh").is_empty():return reject(bindings.error)
	recipe.loadout=seed.duplicate(true)
	return _configure(bindings,catalogues,seed,{},{},{},{},{},{},{},{},{},{},{},recipe)

func _configure(bindings: RefCounted, catalogues: RefCounted, seed: Dictionary, arrival: Dictionary, full_hold: Dictionary={}, training: Dictionary={}, traffic: Dictionary={}, contract: Dictionary={}, convoy: Dictionary={}, alioth: Dictionary={}, kappa: Dictionary={}, sahi: Dictionary={}, dekato: Dictionary={}, selected40: Dictionary={}, selected41: Dictionary={}) -> bool:
	var data: Variant = bindings.opening_actors.get("npc_initialization",{}).get("construction",{})
	if not Definitions.parameters(data): return reject("NPC construction is unavailable in this pack")
	if bindings.resolve(int(data.fragment_resource),"mesh").is_empty(): return reject(bindings.error)
	var expected_ship:=10 if full_hold.is_empty() else 0
	var expected_equipment: Array=[2,2,36,54,59,82,73] if full_hold.is_empty() else [90,81]
	if selected41.is_empty() and selected40.is_empty() and dekato.is_empty() and sahi.is_empty() and kappa.is_empty() and not traffic.has("free_context") and not traffic.has("void_context") and alioth.is_empty() and convoy.is_empty() and contract.is_empty() and ((training.is_empty() and traffic.is_empty() and (seed.ship_id!=expected_ship or seed.equipment_ids!=expected_equipment)) or ((not training.is_empty() or not traffic.is_empty()) and seed.ship_id!=0) or seed.station_id!=(int(traffic.station_id) if not traffic.is_empty() else 78)):
		return reject("NPC construction requires its supported retained loadout")
	var items: Variant = catalogues.tables.get("items")
	if not items is Array or items.size()!=233: return reject("Unsupported NPC cargo catalogue")
	var staged := []
	for id in items.size():
		if not items[id] is Dictionary or items[id].get("id")!=id: return reject("Invalid NPC cargo catalogue row")
		var arrays: Variant = items[id].get("arrays")
		if not arrays is Array or arrays.size()!=3 or not (arrays[0] is Array or arrays[0] is PackedInt32Array) or not (arrays[2] is Array or arrays[2] is PackedInt32Array):
			return reject("Missing NPC cargo properties")
		var p: Variant = arrays[2]
		if p.size()<=int(data.price_high_index): return reject("Incomplete NPC cargo properties")
		for index in [data.category_index,data.rank_index,data.chance_index,data.price_low_index,data.price_high_index,5]:
			var value: Variant = p[int(index)]
			if not value is int or value<-2147483648 or value>2147483647: return reject("Invalid NPC cargo property")
		var category: int = p[int(data.category_index)]
		if category<0 or category>=data.category_weights.size(): return reject("Unknown NPC cargo category")
		# Widen before subtraction, then reject values outside the recovered signed domain.
		var low: int=p[int(data.price_low_index)];var delta: int=p[int(data.price_high_index)]-low
		if delta<-2147483648 or delta>2147483647: return reject("NPC cargo price range overflows its source field")
		@warning_ignore("integer_division")
		var average: int=low+delta/2
		if average<-2147483648 or average>2147483647: return reject("NPC cargo average price overflows its source field")
		staged.append({"category":category,"restricted":not arrays[0].is_empty(),"rank":p[int(data.rank_index)],"chance":p[int(data.chance_index)],"price":average,"type":p[5]})
	_khador_fitted=seed.equipment_ids.any(func(id):return staged[id].type==int(data.special_equipment_type))
	var routes := []
	var count: int=0 if traffic.has("void_context") else (int(traffic.empty_population_fallback) if not traffic.is_empty() else (int(training.actor_count) if not training.is_empty() else (3 if arrival.is_empty() and full_hold.is_empty() else 1)))
	if not contract.is_empty():count=int(contract.actor_count)
	if not convoy.is_empty():count=int(convoy.actor_count)
	if not alioth.is_empty():count=int(alioth.actor_count)
	if not kappa.is_empty():count=int(kappa.actor_count)
	if not sahi.is_empty():count=int(sahi.actor_count)
	if not dekato.is_empty():count=int(dekato.actor_count)
	if not selected40.is_empty():count=int(selected40.actor_count)
	if not selected41.is_empty():count=int(selected41.actor_count)
	if traffic.has("free_context"):count=FreePopulation.maximum_actor_count(bindings,int(traffic.free_context.rank),float(traffic.free_context.difficulty),traffic.free_context,_mission_context)
	elif traffic.has("void_context"):count=int(traffic.void_maximum_count)
	elif traffic.get("ambient",false):count=AmbientDefinitions.maximum_actor_count(bindings.ambient_population,traffic)
	for id in count:
		if not contract.is_empty() and id<int(contract.get("debris_count",0)):routes.append(null);continue
		if not selected41.is_empty() and id==int(selected41.freighter_actor_id):routes.append(null);continue
		if not selected40.is_empty() and id==int(selected40.freighter_actor_id):routes.append(null);continue
		if not dekato.is_empty() and id<int(dekato.freighter_count):routes.append(null);continue
		if not alioth.is_empty() and int(alioth.actors[id].subtype)!=0:routes.append(null);continue
		if not convoy.is_empty() and int(convoy.actors[id].subtype)!=0:routes.append(null);continue
		var route := Route.new()
		var ready: bool
		if not selected41.is_empty():ready=route.configure_selected41_generated(bindings,id)
		elif not selected40.is_empty():ready=route.configure_selected40_generated(bindings,id)
		elif not dekato.is_empty():ready=route.configure_dekato_generated(bindings,id)
		elif not sahi.is_empty():ready=route.configure_sahi_generated(bindings,id,sahi.context)
		elif not kappa.is_empty():ready=route.configure_kappa_generated(bindings,id)
		elif not alioth.is_empty():ready=route.configure_alioth_generated(bindings,id)
		elif not convoy.is_empty():ready=route.configure_convoy_generated(bindings,id)
		elif contract.get("bakka",false):ready=route.configure_bakka_generated(bindings,id)
		elif not contract.is_empty():ready=route.configure_contract_generated(bindings,id,_mission_context)
		elif traffic.has("free_context"):ready=route.configure_free_generated(bindings,id,traffic.free_context)
		elif traffic.has("void_context"):ready=route.configure_void_generated(bindings,id,traffic.void_context)
		elif traffic.get("ambient",false):ready=route.configure_ambient_generated(bindings,id,int(traffic.campaign_cursor))
		elif not traffic.is_empty():ready=route.configure_local_generated(bindings,id)
		elif not training.is_empty():ready=route.configure_training_generated(bindings,id)
		elif not full_hold.is_empty():ready=route.configure_full_hold_generated(bindings)
		elif not arrival.is_empty():ready=route.configure_arrival_generated(bindings)
		else:ready=route.configure(bindings,id)
		if not ready: return reject(route.error)
		routes.append(route)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	if not selected41.is_empty():
		_identity.campaign_cursor=41;_identity.station_id=-1;_identity.system_id=-1
		_selected41=selected41.duplicate(true)
	if not selected40.is_empty():
		_identity.campaign_cursor=int(selected40.context.campaign_cursor)
		_selected40=selected40.duplicate(true)
	if not dekato.is_empty():
		_identity.campaign_cursor=int(dekato.context.campaign_cursor)
		_identity.station_id=int(dekato.context.station_id)
		_identity.system_id=int(dekato.context.system_id)
		_dekato=dekato.duplicate(true)
	if not kappa.is_empty():
		_identity.campaign_cursor=int(kappa.context.campaign_cursor)
		_identity.station_id=int(kappa.context.station_id)
		_kappa=kappa.duplicate(true)
	if not sahi.is_empty():
		_identity.campaign_cursor=int(sahi.context.campaign_cursor)
		_identity.station_id=int(sahi.context.station_id)
		_sahi=sahi.duplicate(true)
	if not alioth.is_empty():
		_identity.campaign_cursor=int(alioth.context.campaign_cursor)
		_identity.station_id=int(alioth.context.station_id)
		_alioth=alioth.duplicate(true)
	if not convoy.is_empty():
		_identity.campaign_cursor=int(convoy.context.campaign_cursor)
		_identity.station_id=int(convoy.context.station_id)
		_convoy=convoy.duplicate(true)
	if not contract.is_empty():
		_identity.campaign_cursor=int(contract.context.campaign_cursor)
		_identity.station_id=int(contract.context.station_id)
		_contract=contract.duplicate(true)
	if not traffic.is_empty():
		_identity.campaign_cursor=int(traffic.campaign_cursor)
		_traffic=traffic.duplicate(true)
	if not training.is_empty():
		_identity.campaign_cursor=int(training.campaign_cursor)
		_training=training.duplicate(true)
	if not full_hold.is_empty():
		_identity.campaign_cursor=int(full_hold.campaign_cursor)
		_full_hold=full_hold.duplicate(true)
	if not arrival.is_empty():
		_identity.campaign_cursor=int(arrival.campaign_cursor)
		_arrival=arrival.duplicate(true)
		_arrival.position=Poses.vec(bindings.arrival_staging.actor_initial_position)
		_arrival.waypoints=bindings.arrival_staging.actor_route_points.map(func(point):return Poses.vec(point))
		_arrival.model_draw_enabled=bool(bindings.arrival_staging.actor_model_draw_enabled)
		_arrival.engine_draw_enabled=bool(bindings.arrival_staging.actor_engine_draw_enabled)
		_arrival.engine_resource_id=int(bindings.arrival_staging.actor_engine_resource_id)
	_definition=data.duplicate(true)
	# JSON number arrays are floats; Array membership is type-sensitive.
	_definition.excluded_items=data.excluded_items.map(func(value): return int(value))
	_items=staged;_routes=routes
	return true

## Entry copies only the fuel count. Respawns receive the current hold count;
## the factory never owns or edits the player's inventory.
func retain_player_cargo(equipment: RefCounted) -> bool:
	if _identity.is_empty() or _generated or not _actors.is_empty() or not equipment is Equipment or not equipment.cargo_cache_valid():return reject("NPC cargo requires the retained inventory before generation")
	var owned: Dictionary=equipment.snapshot()
	for key in ["base_content_id","binding_id"]:
		if owned.loadout.get(key)!=_identity.get(key):return reject("NPC cargo belongs to another content source")
	_player_energy_cells=_energy_quantity(owned.cargo.entries)
	return true

func generate(random_state: Variant,scenery_positions: Array=[]) -> Dictionary:
	error=""
	if _identity.is_empty() or not _actors.is_empty() or _generated: return fail("Configure fresh NPC construction before generating once")
	var random := Random.new()
	if not random.restore(random_state): return fail(random.error)
	if not _selected41.is_empty():return _generate_selected41(random)
	if not _selected40.is_empty():return _generate_selected40(random)
	if not _dekato.is_empty():return _generate_dekato(random)
	if not _sahi.is_empty():return _generate_sahi(random)
	if _traffic.has("void_context"):return _generate_void(random)
	if not _kappa.is_empty():return _generate_kappa(random)
	if not _alioth.is_empty():return _generate_alioth(random)
	if not _convoy.is_empty():return _generate_convoy(random)
	if not _contract.is_empty():return _generate_contract(random,scenery_positions)
	var actors := [];var routes := []
	var population: Dictionary={} if _traffic.is_empty() else _sample_traffic(random)
	if not _traffic.is_empty() and population.is_empty():return fail("Ambient population failed before actor construction")
	var population_count: int=_routes.size() if population.is_empty() else int(population.actor_count)
	var hostile_hull:=-1
	for id in population_count:
		var position := Vector3.ZERO
		var origin:=Vector3.ZERO
		var hull:=-1
		var role:="patrol"
		var faction:=int(_traffic.get("actor_kind",-1))
		if not _ambient.is_empty():
			if not _free.is_empty() and id>=int(population.groups.patrol)+int(population.groups.travel)+int(population.groups.freighter)+int(population.groups.hostile):role="delivery_pirate"
			elif not _free.is_empty() and id>=int(population.groups.patrol)+int(population.groups.travel)+int(population.groups.freighter):role="hostile"
			elif id>=int(population.groups.patrol)+int(population.groups.travel):role="freighter"
			elif id>=int(population.groups.patrol):role="travel"
		if not population.is_empty():
			origin=population.spawn_center if role=="patrol" else Vector3.ZERO
			if role=="freighter":
				var drawn:=random.next_int(int(_ambient.freighter.faction_draw_bound))
				if not _free.is_empty() and drawn<int(_free.freighter_alternate_threshold):faction=int(_free.freighter_alternate_factions[faction])
				hull=int(_ambient.freighter.hull_catalogue_id) if _free.is_empty() else int(_free.freighter_hulls.get(str(faction),-1))
				if hull<0:return fail("Unsupported ordinary freighter faction")
			elif not _free.is_empty():
				if role=="delivery_pirate":
					# Even a zero-sized selected hostile group chooses its hull and
					# arrival origin before the independent delivery group begins.
					if population.hostile_selected and hostile_hull<0:
						hostile_hull=_select_hull(random,int(population.hostile_faction),_free.hulls)
						_select_free_arrival(population,random)
					faction=int(_free.delivery.actor_kind)
					hull=_select_hull(random,faction,_free.hulls)
				elif role=="hostile":
					faction=int(population.hostile_faction)
					if hostile_hull<0:
						hostile_hull=_select_hull(random,faction,_free.hulls)
						_select_free_arrival(population,random)
					origin=population.unused_route_origin
					hull=hostile_hull
				else:hull=_select_hull(random,faction,_free.hulls)
			# Rejection over the source catalogue, rather than drawing directly
			# from the eligible pool, retains the shared random stream.
			while hull<0:
				var candidate:=random.next_int(int(_traffic.hull_draw_bound))
				if _traffic.hull_candidates.any(func(value):return int(value)==candidate):hull=candidate
		if not _training.is_empty() and id<int(_training.pirate_count):origin=Poses.vec(_training.waypoints[int(_training.pirate_waypoint_index)])
		var sampled:=_sample_actor(id,origin,random,role=="freighter")
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor
		position=actor.factory_position
		var route: RefCounted=sampled.route
		var cargo: Array=actor.discarded_cargo
		if role=="freighter":
			_scale_freighter_cargo(cargo,random,int(_ambient.freighter.cargo_multiplier_offset),int(_ambient.freighter.cargo_multiplier_bound),int(_ambient.freighter.cargo_floor_offset),int(_ambient.freighter.cargo_floor_bound))
		if not _traffic.is_empty():
			var actual_position:=position
			if role=="delivery_pirate":
				for axis in 3:
					actual_position[axis]=Vitals.single(Vitals.single(_traffic.free_context.player_position[axis]+float(_free.delivery.position_offsets[axis]))+float(random.next_int(int(_free.delivery.position_bounds[axis]))))
			elif role=="freighter":
				var freight: Dictionary=_ambient.freighter
				# The original multipart model is generated before the world moves
				# the freighter. Its container count consumes the shared stream.
				if _free.is_empty() or faction==int(_ambient.actor_kind):
					actor.assembly=freight.assembly.duplicate(true)
					actor.assembly.container_count=random.next_int(int(freight.assembly.container_count_bound))
				else:actor.assembly=_free.freighter_assemblies[str(faction)].duplicate(true)
				actual_position.x=int(freight.position_x_offset)+random.next_int(int(freight.position_x_bound))
				actual_position.x*=1 if random.next_int(int(freight.position_sign_bound))==0 else -1
				actual_position.y=int(freight.position_y_offset)+random.next_int(int(freight.position_y_bound))
				actual_position.z=int(freight.position_z_offset)+random.next_int(int(freight.position_z_bound))
				actor.world_flag=bool(freight.world_flag)
				actor.model_assembly_required=true
			elif role=="travel":
				var point:=Vector3.ZERO
				for axis in 3:point[axis]=int(_ambient.travel_ship.route_offsets[axis])+random.next_int(int(_ambient.travel_ship.route_bounds[axis]))
				actor.discarded_route=actor.route
				if not route.replace_with_ambient_destination(point):return fail(route.error)
				actor.route=route.snapshot();actor.flight_mode=int(_ambient.travel_ship.flight_mode);actor.travel_flag=bool(_ambient.travel_ship.travel_flag)
			var body:=Transform3D(Basis.IDENTITY,actual_position)
			if not _ambient.is_empty():actor.population_group=role
			actor.merge({"actor_kind":faction,"hull_catalogue_id":hull,"subtype":int(_ambient.freighter.subtype) if role=="freighter" else int(_traffic.subtype),
				"discarded_cargo":[],"cargo":cargo,"body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY},true)
		elif not _arrival.is_empty():
			var body:=Transform3D(Basis.IDENTITY,_arrival.position)
			var authored_route:=_identity.duplicate()
			authored_route.merge({"actor_id":id,"waypoints":_arrival.waypoints.duplicate(),"index":int(_arrival.authored_route_initial_index),"loop":bool(_arrival.authored_route_loop)})
			actor.merge({"actor_kind":int(_arrival.actor_kind),"hull_catalogue_id":int(_arrival.hull_catalogue_id),"subtype":int(_arrival.subtype),
				"discarded_cargo":[],"cargo":cargo,"discarded_route":actor.route,"route":authored_route,
				"body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY,"model_draw_enabled":_arrival.model_draw_enabled,
				"engine_draw_enabled":_arrival.engine_draw_enabled,"engine_resource_id":_arrival.engine_resource_id},true)
		elif not _full_hold.is_empty():
			var body:=Transform3D(Basis.IDENTITY,Poses.vec(_full_hold.actor_position))
			actor.merge({"actor_kind":int(_full_hold.actor_kind),"hull_catalogue_id":int(_full_hold.hull_catalogue_id),"subtype":int(_full_hold.subtype),
				"discarded_cargo":[],"cargo":cargo,"body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY,
				"mode":int(_full_hold.actor_mode),"active":bool(_full_hold.actor_active),"targeting_blocked":bool(_full_hold.actor_targeting_blocked)},true)
		elif not _training.is_empty():
			var companion: bool=id==int(_training.companion_actor_id)
			var body:=Transform3D(Basis.IDENTITY,_training.companion_position if companion else position)
			actor.merge({"actor_kind":int(_training.companion_actor_kind if companion else _training.pirate_actor_kind),
				"hull_catalogue_id":int(_training.companion_hull_catalogue_id if companion else _training.pirate_hull_catalogue_id),
				"subtype":int(_training.subtype),"discarded_cargo":[],"cargo":cargo,
				"body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY},true)
			if companion:
				actor.discarded_route=actor.route
				route=_authored_route.fork_for_frame();actor.route=route.snapshot()
				actor.friendly=bool(_training.companion_friendly)
				actor.current_hull_override=int(_training.companion_current_hull_override)
				actor.name_text_id=int(_training.companion_name_text_id)
			else:
				actor.mode=int(_training.pirate_mode);actor.active=bool(_training.pirate_active);actor.targeting_blocked=bool(_training.pirate_targeting_blocked)
		actors.append(actor)
		routes.append(route)
	if not _free.is_empty() and population.hostile_selected and hostile_hull<0:
		_select_hull(random,int(population.hostile_faction),_free.hulls)
		_select_free_arrival(population,random)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_traffic_sample=population;_generated=true
	return snapshot()

func _select_free_arrival(population: Dictionary,random: RefCounted) -> void:
	if _free.has("arrival"):load("res://src/content/free_arrival_definitions.gd").select_origin(_free.arrival,_traffic.free_context,population,random)

func _generate_convoy(random: RefCounted) -> Dictionary:
	var actors:=[];var routes:=[]
	var origin:=Poses.vec(_convoy.waypoints[0])
	var capital_index:=0
	for id in int(_convoy.actor_count):
		var source: Dictionary=_convoy.actors[id]
		var capital: bool=int(source.subtype)==int(_convoy.capital.subtype)
		var sampled:=_sample_actor(id,origin,random,capital)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor
		var position: Vector3=actor.factory_position
		if capital:
			for item in actor.discarded_cargo:
				item.quantity*=int(_convoy.capital.cargo.multiplier_offset)+random.next_int(int(_convoy.capital.cargo.multiplier_bound))
			position=origin+Poses.vec(_convoy.freighter_offsets[capital_index]);capital_index+=1
			actor.assembly=_convoy.capital.assembly.duplicate(true);actor.model_assembly_required=true
		for key in ["actor_kind","subtype","hull_catalogue_id"]:actor[key]=int(source[key])
		actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		actor.population_group="capital" if capital else "fighter"
		actor.body_pose=Transform3D(Basis.IDENTITY,position);actor.statistics_pose=actor.body_pose;actor.model_local_pose=Transform3D.IDENTITY
		actors.append(actor);routes.append(sampled.route)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	return snapshot()

func _generate_kappa(random: RefCounted) -> Dictionary:
	var actors:=[];var routes:=[]
	actors.resize(int(_kappa.actor_count));routes.resize(int(_kappa.actor_count))
	# The mission constructs escorts before actor0, then the shared world builds
	# weapons in actor-list order. Generated cargo, patrol and fragments still
	# consume the factory stream before the authored route replaces the patrol.
	for value in _kappa.construction_order:
		var id:=int(value);var source: Dictionary=_kappa.actors[id]
		var waypoint:=Kappa.vec(_kappa.waypoints[int(source.waypoint_index)])
		var sampled:=_sample_actor(id,waypoint,random)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor;var route: RefCounted=sampled.route
		if not route.replace_with_kappa_patrol():return fail(route.error)
		var position: Vector3=actor.factory_position
		if id==int(_kappa.target_actor_id):
			position=Vectors.added(waypoint,Kappa.vec(_kappa.target_position_offset))
			actor.name_text_id=int(_kappa.target_name_text_id)
		for key in ["actor_kind","subtype","hull_catalogue_id"]:actor[key]=int(source[key])
		actor.population_group="fighter";actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		actor.discarded_route=actor.route;actor.route=route.snapshot()
		actor.script_hostile=bool(source.initial_hostile);actor.permanent_friendly=_kappa.permanent_friendly
		actor.mode=int(_kappa.initial_actor_mode);actor.active=bool(_kappa.initial_active)
		actor.body_pose=Transform3D(Basis.from_euler(Vector3(0,float(_kappa.actor_yaw),0),EULER_ORDER_XYZ),position)
		actor.statistics_pose=actor.body_pose;actor.model_local_pose=Transform3D.IDENTITY
		actors[id]=actor;routes[id]=route
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	return snapshot()

func _generate_alioth(random: RefCounted) -> Dictionary:
	var actors:=[];var routes:=[]
	var waypoint:=Poses.vec(_alioth.waypoints[0])
	var escort_center:=Vectors.added(_alioth.player_position,Poses.vec(_alioth.escort_player_offset))
	for id in int(_alioth.actor_count):
		var source: Dictionary=_alioth.actors[id]
		var freighter: bool=int(source.subtype)==1
		# The factory's waypoint argument changes only its spawn center. Small
		# ships still construct their generated patrol before the scripted move.
		var sampled:=_sample_actor(id,waypoint if source.spawn_at_waypoint else Vector3.ZERO,random,freighter)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor
		var position: Vector3
		if freighter:
			var cargo_rules: Dictionary=_alioth.freighter_cargo
			_scale_freighter_cargo(actor.discarded_cargo,random,int(cargo_rules.multiplier_offset),int(cargo_rules.multiplier_bound),int(cargo_rules.floor_offset),int(cargo_rules.floor_bound))
			position=Vectors.added(waypoint,Poses.vec(_alioth.freighter_offsets[id]))
			actor.assembly=_alioth.freighter_assembly.duplicate(true);actor.model_assembly_required=true
			actor.friendly=bool(_alioth.freighter_friendly);actor.cruise_enabled=bool(_alioth.freighter_cruise_enabled)
			actor.hull_divisors=[int(_alioth.freighter_hull_divisor)]
			if id==0:actor.hull_divisors.append(int(_alioth.lead_hull_divisor))
			# The original constructor consumes cargo RNG before the mission
			# explicitly deletes that cargo. Retain only a diagnostic copy here.
			actor.cargo=[]
		elif int(source.actor_kind)==9:
			position=Vectors.added(waypoint,Poses.vec(_alioth.void_position_offsets))
			for axis in 2:position[axis]+=random.next_int(int(_alioth.void_position_bounds[axis]))
			actor.hull_multiplier=int(_alioth.void_hull_multiplier)
			actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		else:
			position=escort_center
			for axis in 3:position[axis]=Vitals.single(position[axis]+float(int(_alioth.escort_position_offsets[axis])+random.next_int(int(_alioth.escort_position_bounds[axis]))))
			actor.friendly=bool(_alioth.escort_friendly);actor.current_hull_override=int(_alioth.escort_current_hull)
			actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		if not position.is_finite():return fail("Alioth actor placement exceeded source precision")
		for key in ["actor_kind","subtype","hull_catalogue_id"]:actor[key]=int(source[key])
		actor.population_group="freighter" if freighter else "fighter"
		actor.body_pose=Transform3D(Basis.IDENTITY,position);actor.statistics_pose=actor.body_pose;actor.model_local_pose=Transform3D.IDENTITY
		actors.append(actor);routes.append(sampled.route)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	return snapshot()

func _generate_dekato(random: RefCounted) -> Dictionary:
	var actors:=[];var routes:=[]
	var waypoint:=Poses.vec(_dekato.path_points[0])
	for id in int(_dekato.actor_count):
		var freighter: bool=id<int(_dekato.freighter_count)
		# The escort hull rejection draw precedes its factory; the freighter
		# has a fixed hull and no patrol or initial-fragment allocation.
		var hull: int=int(_dekato.freighter_hull_catalogue_id) if freighter else _select_hull(random,int(_dekato.escort_hull_picker_faction),_dekato.hulls)
		var sampled:=_sample_actor(id,waypoint,random,freighter)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor
		var position: Vector3=actor.factory_position
		if freighter:
			var cargo: Dictionary=_dekato.freighter_cargo
			_scale_freighter_cargo(actor.discarded_cargo,random,int(cargo.cargo_multiplier_offset),int(cargo.cargo_multiplier_bound),int(cargo.cargo_floor_offset),int(cargo.cargo_floor_bound))
			position=waypoint
			for axis in 3:position[axis]+=int(_dekato.freighter_position_offset)+random.next_int(int(_dekato.freighter_position_bound))
			actor.assembly=_dekato.freighter_assembly.duplicate(true);actor.model_assembly_required=true
			actor.friendly=bool(_dekato.freighter_forced_friendly)
			actor.cruise_enabled=bool(_dekato.freighter_cruise_enabled)
		else:actor.script_hostile=bool(_dekato.escort_forced_hostile)
		# Unlike Alioth/Sahi, this script never clears cargo or rescales hull.
		actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		actor.actor_kind=int(_dekato.freighter_actor_kind if freighter else _dekato.escort_actor_kind)
		actor.subtype=int(_dekato.freighter_subtype if freighter else _dekato.escort_subtype)
		actor.hull_catalogue_id=hull;actor.population_group="freighter" if freighter else "fighter"
		actor.body_pose=Transform3D(Basis.IDENTITY,position);actor.statistics_pose=actor.body_pose;actor.model_local_pose=Transform3D.IDENTITY
		actors.append(actor);routes.append(sampled.route)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	return snapshot()

func _generate_selected40(random: RefCounted) -> Dictionary:
	var actors:=[];var routes:=[]
	for id in int(_selected40.actor_count):
		var freighter: bool=id==int(_selected40.freighter_actor_id)
		var escort: bool=id>=int(_selected40.escort_first) and id<int(_selected40.escort_end)
		var reserve: bool=id>=int(_selected40.reserve_first)
		var hull: int=int(_selected40.freighter_hull_catalogue_id) if freighter else _select_hull(random,int(_selected40.escort_actor_kind),_selected40.hulls) if escort else int(_selected40.void_hull_catalogue_id)
		var origin:=Poses.vec(_selected40.attack_origin) if id>=int(_selected40.attack_first) and not reserve else Vector3.ZERO
		var sampled:=_sample_actor(id,origin,random,freighter)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor;var route: RefCounted=sampled.route
		var position: Vector3=actor.factory_position
		if freighter:
			var cargo: Dictionary=_selected40.freighter_cargo
			_scale_freighter_cargo(actor.discarded_cargo,random,int(cargo.cargo_multiplier_offset),int(cargo.cargo_multiplier_bound),int(cargo.cargo_floor_offset),int(cargo.cargo_floor_bound))
			actor.assembly=_selected40.freighter_assembly.duplicate(true);actor.model_assembly_required=true
			actor.hull_override=int(_selected40.freighter_hull_base)+int(_selected40.freighter_hull_per_rank)*int(_selected40.context.rank)
			actor.name_text_id=int(_selected40.name_text_ids[0]);position=Poses.vec(_selected40.freighter_position)
		elif escort:
			actor.discarded_route=actor.route
			if not route.replace_with_selected40_patrol():return fail(route.error)
			actor.route=route.snapshot()
			if id==int(_selected40.named_escort_id):actor.name_text_id=int(_selected40.name_text_ids[1])
		elif reserve:position=Poses.vec(_selected40.reserve_position)
		actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		actor.actor_kind=int(_selected40.freighter_actor_kind) if freighter else int(_selected40.escort_actor_kind) if escort else int(_selected40.void_actor_kind)
		actor.subtype=1 if freighter else 0;actor.hull_catalogue_id=hull
		actor.population_group="freighter" if freighter else "fighter"
		actor.friendly=freighter or escort;actor.script_hostile=not actor.friendly
		actor.mode=int(_selected40.parked_mode) if freighter or reserve else 0
		actor.active=not (freighter or reserve);actor.targeting_blocked=not actor.active
		actor.model_draw_enabled=not freighter
		actor.body_pose=Transform3D(Basis.IDENTITY,position);actor.statistics_pose=actor.body_pose;actor.model_local_pose=Transform3D.IDENTITY
		actors.append(actor);routes.append(route)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	return snapshot()

func _generate_selected41(random: RefCounted) -> Dictionary:
	var actors:=[];var routes:=[]
	for id in int(_selected41.actor_count):
		var freighter: bool=id==int(_selected41.freighter_actor_id)
		# Source constructs each factory at zero first, preserving its cargo,
		# patrol and debris draws. Script placement is a later fixed override.
		var sampled:=_sample_actor(id,Vector3.ZERO,random,freighter)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor;var route: RefCounted=sampled.route
		if freighter:
			var cargo: Dictionary=_selected41.freighter_cargo
			_scale_freighter_cargo(actor.discarded_cargo,random,int(cargo.cargo_multiplier_offset),int(cargo.cargo_multiplier_bound),int(cargo.cargo_floor_offset),int(cargo.cargo_floor_bound))
			actor.assembly=_selected41.freighter_assembly.duplicate(true);actor.model_assembly_required=true
			# Current hull is restored, not a replacement for factory capacity.
			actor.retained_current_hull=int(_selected41.retained_hull)
			actor.name_text_id=int(_selected41.name_text_id);actor.cruise_enabled=true
		actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		actor.actor_kind=int(_selected41.freighter_actor_kind if freighter else _selected41.fighter_actor_kind)
		actor.subtype=1 if freighter else 0;actor.hull_catalogue_id=int(_selected41.freighter_hull_catalogue_id if freighter else _selected41.fighter_hull_catalogue_id)
		actor.population_group="freighter" if freighter else "fighter"
		actor.friendly=freighter;actor.script_hostile=not freighter
		actor.body_pose=Transform3D(Basis.IDENTITY,Poses.vec(_selected41.positions[id]));actor.statistics_pose=actor.body_pose;actor.model_local_pose=Transform3D.IDENTITY
		actors.append(actor);routes.append(route)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	return snapshot()

func _generate_sahi(random: RefCounted) -> Dictionary:
	var actors:=[];var routes:=[]
	actors.resize(int(_sahi.actor_count));routes.resize(int(_sahi.actor_count))
	var waypoint:=Poses.vec(_sahi.waypoints[0])
	for value in _sahi.construction_order:
		var id:=int(value);var source: Dictionary=_sahi.actors[id]
		var freighter: bool=int(source.subtype)==1
		# The shared factory selects the concrete subtype before construction.
		# Freighters have no patrol or initial debris; Sahi replaces Void routes.
		var sampled:=_sample_actor(id,waypoint,random,freighter)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor;var route: RefCounted=sampled.route
		if freighter:
			var cargo_rules: Dictionary=_sahi.freighter_cargo
			_scale_freighter_cargo(actor.discarded_cargo,random,int(cargo_rules.multiplier_offset),int(cargo_rules.multiplier_bound),int(cargo_rules.floor_offset),int(cargo_rules.floor_bound))
			actor.assembly=_sahi.freighter_assembly.duplicate(true);actor.model_assembly_required=true
			actor.cruise_enabled=bool(_sahi.freighter_cruise_enabled);actor.hull_divisors=[int(_sahi.freighter_hull_divisor)]
			actor.cargo=[]
		else:
			if not _sahi.has("post_sahi") and not _sahi.has("dima"):
				if not route.replace_with_sahi_patrol():return fail(route.error)
				actor.discarded_route=actor.route;actor.route=route.snapshot()
			actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
		if _sahi.has("post_sahi"):
			var rules: Dictionary=_sahi.post_sahi
			var position:=Vector3.ZERO
			var placement_draws:=[]
			if _sahi.context.campaign_cursor in [25,29]:
				for axis in 3:
					var sign_draw: int=random.next_int(int(rules.sign_bound));var magnitude_draw: int=random.next_int(int(rules.magnitude_bound))
					position[axis]=(1 if sign_draw==int(rules.positive_sign_draw) else -1)*(int(rules.magnitude_offset)+magnitude_draw)
					placement_draws.append([sign_draw,magnitude_draw])
			else:
				position=Vectors.added(_sahi.player_pose.origin,Vectors.scaled(Vectors.normalized(_sahi.player_pose.basis.z),float(rules.forward_distance)))
				for axis in 3:
					var draw: int=random.next_int(int(rules.axis_bound));placement_draws.append(draw)
					position[axis]=Vitals.single(position[axis]+int(rules.axis_offset)+draw)
			actor.factory_position_before_relocation=actor.factory_position
			actor.factory_position=position;actor.placement_draws=placement_draws
		for key in ["actor_kind","subtype","hull_catalogue_id"]:actor[key]=int(source[key])
		actor.population_group="freighter" if freighter else "fighter"
		actor.body_pose=Transform3D(Basis.IDENTITY,actor.factory_position);actor.statistics_pose=actor.body_pose;actor.model_local_pose=Transform3D.IDENTITY
		actors[id]=actor;routes[id]=route
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	return snapshot()

func _generate_void(random: RefCounted) -> Dictionary:
	var population: Dictionary=_sample_traffic(random)
	if population.is_empty() or int(population.actor_count)>_routes.size():return fail("Void actor count exceeds its configured routes")
	var rules: Dictionary=_traffic.void_rules
	var actors:=[];var routes:=[]
	for id in int(population.actor_count):
		# The same kind9/subtype0/hull8 factory used by the earlier Void casts
		# consumes its position, route, cargo and fragment draws first.
		var sampled:=_sample_actor(id,Vector3.ZERO,random)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor;var route: RefCounted=sampled.route
		var position:=Vector3.ZERO;var draws:=[]
		for axis in 3:
			var drawn: int=random.next_int(int(rules.position_bounds[axis]))
			draws.append(drawn)
			position[axis]=int(rules.position_offsets[axis])+drawn
		var body:=Transform3D(Basis.IDENTITY,position)
		actor.merge({"actor_kind":int(rules.actor_kind),"hull_catalogue_id":int(rules.hull_id),
			"subtype":int(rules.actor_subtype),"population_group":"fighter","factory_position_before_relocation":actor.factory_position,
			"factory_position":position,"placement_draws":draws,"cargo":actor.discarded_cargo,"discarded_cargo":[],
			"body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY,
			"activation_setter_argument":int(rules.shared_activation_setter_argument),
			# This setter forces persistent hostility. F8 is a statistics flag;
			# neither it nor these raw bytes set the native actor's active mode.
			"activation_fields":{"f8":1,"b60":1,"b61":0,"ec":1}},true)
		actors.append(actor);routes.append(route)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_traffic_sample=population;_generated=true
	return snapshot()

func _sample_actor(id: int,origin: Vector3,random: RefCounted,freighter:=false) -> Dictionary:
	var position:=Vector3.ZERO
	for axis in 3:position[axis]=origin[axis]+int(_definition.spawn_origin[axis])+random.next_int(int(_definition.spawn_bound))
	var route: RefCounted=null
	if not freighter:
		route=_routes[id].fork_for_frame()
		var generated: Dictionary=route.generate(random.snapshot())
		if generated.is_empty():return fail(route.error)
		if not random.restore(generated.random_state):return fail(random.error)
	var cargo:=_sample_cargo(random)
	var actor:={"actor_id":id,"factory_position":position,"discarded_cargo":cargo,"cargo":[],
		"fragments":[] if freighter else _sample_fragments(random),"route":{} if route==null else route.snapshot()}
	return {"actor":actor,"route":route}

func _contract_path(random: RefCounted,count: int) -> Array:
	var rules: Dictionary=_contract.path
	var points:=[];var z:=0
	for id in count:
		var sign_value:=1 if random.next_int(int(rules.sign_bound))==0 else -1
		var x: int=sign_value*(int(rules.coordinate_offsets[0])+random.next_int(int(rules.coordinate_bounds[0])))
		var y: int=int(rules.coordinate_offsets[1])+random.next_int(int(rules.coordinate_bounds[1]))
		z+=int(rules.coordinate_offsets[2])+random.next_int(int(rules.coordinate_bounds[2]))
		points.append(Vector3(x,y,z))
	return points

static func _scale_freighter_cargo(cargo: Array,random: RefCounted,multiplier_offset: int,multiplier_bound: int,floor_offset: int,floor_bound: int) -> void:
	for item in cargo:
		var multiplied: int=int(item.quantity)*(multiplier_offset+random.next_int(multiplier_bound))
		item.quantity=maxi(multiplied,floor_offset+random.next_int(floor_bound))

func _contract_hull(random: RefCounted,faction: int) -> int:
	return _select_hull(random,faction,_contract.hulls)

static func _select_hull(random: RefCounted,faction: int,rules: Dictionary) -> int:
	if faction==int(rules.early_vossk_faction):return int(rules.early_vossk_hull)
	# A faction with no hull in the pool would never be drawn (refuse, don't hang).
	if not range(mini(int(rules.draw_bound),rules.factions.size())).any(func(hull):return int(rules.factions[hull])==faction and (hull>int(rules.mask_limit) or (int(rules.excluded_mask)&(1<<hull))==0)):return -1
	while true:
		var hull: int=random.next_int(int(rules.draw_bound))
		if hull<=int(rules.mask_limit) and (int(rules.excluded_mask)&(1<<hull))!=0:continue
		if int(rules.factions[hull])==faction:return hull
	return -1

func _generate_contract(random: RefCounted,scenery_positions: Array) -> Dictionary:
	var kind:=int(_contract.context.mission.kind)
	var story: bool=_contract.get("bakka",false)
	# Lounge selection consumes a draw even for empty couriers. The authored
	# story population is a separate source branch and must not consume it.
	var enemy_faction: int=-1 if story else ContractDefinitions.draw_enemy_faction(_contract,random,int(_contract.alternate_enemy_faction))
	var path:=[]
	var actors:=[];var routes:=[]
	var center:=Vector3.ZERO
	if story:path=_contract.authored_path.duplicate()
	else:
		var placement: Dictionary=_contract.placement
		match placement.kind:
			"points":path=placement.points.duplicate()
			"random_point","random_points":
				for region in placement.get("regions",[placement]):
					var point:=Vector3.ZERO
					for axis in 3:
						point[axis]=int(region.offsets[axis])
						if int(region.bounds[axis])>0:point[axis]+=random.next_int(int(region.bounds[axis]))
					path.append(point)
			"approach":
				path=[Vector3(int(placement.horizontal_offset)-random.next_int(int(placement.horizontal_bound)),0,int(placement.horizontal_offset)-random.next_int(int(placement.horizontal_bound))),Vector3.ZERO]
			"line":
				for z in placement.z_positions:path.append(Vector3(int(placement.x_offset)+random.next_int(int(placement.x_bound)),0,int(z)))
			"patrol":
				if int(placement.field_choice_bound)>0 and random.next_int(int(placement.field_choice_bound))==0:path=[Vector3(Vector3i(_contract.field_center))]
				else:path=_contract_path(random,int(placement.minimum_points)+random.next_int(int(placement.point_count_bound)))
			"distant_point":
				var point:=Vector3.ZERO
				for axis in [0,2]:
					var magnitude: int=int(placement.horizontal_offset)+random.next_int(int(placement.horizontal_bound))
					point[axis]=magnitude*(-1 if random.next_int(2)==0 else 1)
				path=[point]
			"debris_field":
				for axis in 3:center[axis]=int(_contract.junk.center_offsets[axis])+random.next_int(int(_contract.junk.center_bounds[axis]))
	var count:=int(_contract.actor_count)
	if not _contract.get("count_draw",{}).is_empty():
		count=int(_contract.count_draw.minimum)+random.next_int(int(_contract.count_draw.bound))
		var resolved: RefCounted=_mission_context.resolve_contract_count(count)
		if resolved==null:return fail(_mission_context.error)
		_mission_context=resolved
		_contract.actor_count=count;_contract.count_draw={};_contract.ship_groups=resolved.recipe().cast.ship_groups
	for id in count:
		if id<int(_contract.get("debris_count",0)):
			var rules: Dictionary=_contract.junk
			var position:=center
			for axis in 3:position[axis]+=int(rules.position_offset)+random.next_int(int(rules.position_bound))
			var mesh:=int(rules.model_ids[random.next_int(rules.model_ids.size())])
			var body:=Transform3D(Basis.IDENTITY,position)
			actors.append({"actor_id":id,"actor_kind":int(rules.actor_kind),"type_id":int(rules.type_id),"resource_id":mesh,
				"population_group":"debris","body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY,
				"hull":int(rules.hull),"half_extent":int(rules.half_extent),"mode":int(rules.mode),
				"hostile":bool(rules.hostile),"friendly":bool(rules.friendly),"cargo":[],"fragments":[],"route":{}})
			routes.append(null);continue
		var rival:=id==int(_contract.challenge.rival_actor_id if story else _contract.rival_actor_id)
		var faction:=int(_contract.rival_faction if story else _contract.context.client_faction) if rival else int(_contract.pirate_actor_kind)
		var options: Dictionary={} if story else load("res://src/content/mission_recipe.gd").contract_ship_options(_contract,id,enemy_faction,int(_contract.context.client_faction))
		if not story:faction=int(options.faction)
		if not story and not options.get("static_object",{}).is_empty():
			actors.append(_static_row(id,faction,options,path,random));routes.append(null);continue
		var freighter: bool=options.get("subtype",0)==1
		var fixed_hull: int=int(options.get("hull_catalogue_id",-1))
		var hull: int=fixed_hull if fixed_hull>=0 else int(_contract.freighter_hulls[faction]) if freighter else int(_contract.rival_hull) if story and rival else _contract_hull(random,faction)
		var at_origin: bool=rival or path.is_empty() or options.get("origin")=="zero"
		var origin: Vector3=Vector3.ZERO if at_origin else path[random.next_int(path.size())]
		var sampled:=_sample_actor(id,origin,random,freighter)
		if sampled.is_empty():return {}
		var actor: Dictionary=sampled.actor
		var route: RefCounted=sampled.route
		var position: Vector3=actor.factory_position
		actor.merge({"actor_kind":faction,"hull_catalogue_id":hull,"subtype":int(_contract.subtype),"population_group":"rival" if rival else "pirate"})
		if not story:actor.population_group=options.population_group
		if freighter:
			actor.subtype=1;actor.world_flag=true;actor.model_assembly_required=true
			actor.assembly=_contract.freighter_assemblies[faction].duplicate(true)
			if actor.assembly.has("container_count_bound"):actor.assembly.container_count=random.next_int(int(actor.assembly.container_count_bound))
		if rival:
			var rules: Dictionary=_contract.challenge
			position=_contract.player_position
			for axis in 2:position[axis]=Vitals.single(position[axis]+int(rules.position_offset)+random.next_int(int(rules.position_bound)))
			position.z=Vitals.single(position.z+float(rules.position_z_offset))
			actor.discarded_route=actor.route
			if not route.replace_with_contract_path(path):return fail(route.error)
			actor.route=route.snapshot()
			actor.merge({"friendly":bool(rules.friendly),"current_hull_override":int(rules.current_hull_override),
				"base_speed":float(rules.base_speed),"speed":float(rules.speed)})
			if story:actor.name_text_id=int(_contract.rival_name_text_id)
			else:actor.name=_contract.context.contact_name
		else:
			actor.cargo=actor.discarded_cargo;actor.discarded_cargo=[]
			actor.merge(options.ship_state if not story else {"mode":int(_contract.pirate.mode),"active":bool(_contract.pirate.active),"targeting_blocked":bool(_contract.pirate.targeting_blocked)})
		if not story:
			if freighter and not options.clear_cargo:
				var cargo_rules: Dictionary=_contract.freighter_cargo
				_scale_freighter_cargo(actor.cargo,random,int(cargo_rules.cargo_multiplier_offset),int(cargo_rules.cargo_multiplier_bound),int(cargo_rules.cargo_floor_offset),int(cargo_rules.cargo_floor_bound))
			if options.clear_cargo:actor.cargo=[]
			if not options.cargo_override.is_empty():
				actor.cargo=options.cargo_override.entries.duplicate(true)
				actor.special_cargo=bool(options.cargo_override.special)
			if int(options.name_text_id)>=0:actor.name_text_id=int(options.name_text_id)
			# A named story criminal (W1) shows his own name when targeted.
			if not String(options.get("display_name","")).is_empty():actor.display_name=String(options.display_name)
			match options.position.get("kind",""):
				"positions":position=options.position.points[int(options.group_index)]
				"path_start":position=path[0]+Vector3(options.position.step)*int(options.group_index)
				"path_scatter":
					position=path[int(options.position.index)]
					for axis in 3:position[axis]+=int(options.position.offsets[axis])+random.next_int(int(options.position.bounds[axis]))
				"path_fan":
					# Ship n steps (first+n) times a random base offset away from the
					# point, alternating left/right (a fan of ships either side).
					position=Vector3(options.position.center) if options.position.has("center") else path[int(options.position.index)]
					var side:=1 if (int(options.group_index)+int(options.position.get("flip",0)))%2==0 else -1
					var step:=Vector3.ZERO
					for axis in 3:step[axis]=int(options.position.offsets[axis])+random.next_int(int(options.position.bounds[axis]))
					step.x*=side
					position+=step*(int(options.position.first)+int(options.group_index))
				"player_offset":
					position=_contract.player_position+Vector3(options.position.offset)
					for axis in 3:position[axis]+=random.next_int(int(options.position.bound[axis]))
				"player_side":
					# Beside the player, alternating left and right.
					position=_contract.player_position+Vector3(float(options.position.side)*(1 if int(options.group_index)%2==0 else -1),0,0)
				"player_band":
					# Each axis: a distance in [min,max] on a random side of the player.
					position=_contract.player_position
					for axis in 3:
						var low:=int(Vector3(options.position.min)[axis]);var gap:=int(Vector3(options.position.max)[axis])-low
						var distance: int=low+(random.next_int(gap) if gap>0 else 0)
						position[axis]+=distance if random.next_int(2)==0 else -distance
				"scenery_midpoint":
					var anchor:=int(scenery_positions.size()/2)+int(options.group_index)
					if anchor>=scenery_positions.size() or not scenery_positions[anchor] is Vector3 or not scenery_positions[anchor].is_finite():return fail("The admitted cast requires its world scenery anchors")
					position=scenery_positions[anchor]+Vector3(options.position.offset)
			# route_loop: the ship flies round these path points for ever.
			var loop: Array=options.get("route_loop",[])
			if not loop.is_empty():
				if loop.any(func(index):return not index is int or index<0 or index>=path.size()):return fail("A looping route names a missing path point")
				actor.discarded_route=route.snapshot()
				if not route.replace_with_contract_path(loop.map(func(index):return path[index]),0,true):return fail(route.error)
				actor.route=route.snapshot()
			elif int(options.route_start)>=0:
				actor.discarded_route=route.snapshot()
				if not route.replace_with_contract_path(path,int(options.route_start)):return fail(route.error)
				actor.route=route.snapshot()
		var body:=Transform3D(Basis.IDENTITY,position)
		actor.merge({"body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY})
		actors.append(actor);routes.append(route)
	_actors=actors;_routes=routes;_random_state=random.snapshot();_generated=true
	_contract_layout={"kind":kind,"context":_contract.context.duplicate(true),"mission":_contract.context.mission.duplicate(true),"path":path,
		"debris_center":center,"unused_enemy_faction":enemy_faction,"actor_count":actors.size()}
	return snapshot()

## A cast static object: no ship sampling, route or cargo. It sits at its
## group position (or the origin) plus the optional per-axis jitter.
func _static_row(id: int,faction: int,options: Dictionary,path: Array,random: RefCounted) -> Dictionary:
	var placed: Dictionary=options.static_object
	var model:=int(placed.model)
	var position:=Vector3.ZERO
	if options.position.get("kind","")=="positions":position=Vector3(options.position.points[int(options.group_index)])
	elif options.get("origin")!="zero" and not path.is_empty():position=path[0]
	# An offset from the anchor and a fixed rotation (80: the weak points on the Valkyrie).
	if placed.has("offset"):position+=Vector3(placed.offset)
	var jitter:=int(placed.get("jitter",0))
	if jitter>0:
		for axis in 3:position[axis]=Vitals.single(position[axis]+float(random.next_int(2*jitter)-jitter))
	var context: Dictionary=_contract.context
	var hull:=int(placed.hull_override) if placed.has("hull_override") else Statics.hull(model,int(context.rank),int(context.campaign_cursor),float(context.difficulty))
	var body:=Transform3D(Basis.from_euler(Vector3(placed.get("rotation",Vector3.ZERO))),position)
	var row:={"actor_id":id,"actor_kind":faction,"hull_catalogue_id":-1,"subtype":0,"population_group":"static","static_model":model,"resource_id":Statics.body_mesh(model),
		"hull_override":hull,"name_text_id":int(options.name_text_id),"cargo":[],"fragments":[],"route":{},
		"body_pose":body,"statistics_pose":body,"model_local_pose":Transform3D.IDENTITY}
	row.merge(options.ship_state,true)
	return row

func _sample_traffic(random: RefCounted) -> Dictionary:
	if _population_owner!=null:
		var population: Dictionary=_population_owner.generate(random.snapshot())
		if population.is_empty() or not random.restore(population.before_actors_random_state):return {}
		return population
	return TrafficPopulation.first_departure(_traffic,random)

func _sample_fragments(random: RefCounted) -> Array:
	return sample_fragments(random,_definition)

static func sample_fragments(random: RefCounted,definition: Dictionary) -> Array:
	# Shared authored debris sampling. Callers own when the shared stream is used:
	# small ships at construction, freighters on their first lethal actor pass.
	var fragments:=[]
	var count: int=int(definition.fragment_count_minimum)+random.next_int(int(definition.fragment_count_bound))
	for fragment in count:
		var rotation:=Vector3.ZERO
		for axis in 3:
			rotation[axis]=Vitals.single(Vitals.single(float(random.next_int(int(definition.rotation_bound)))/float(definition.rotation_divisor))*float(definition.rotation_multiplier))
		var scale_value: float=Vitals.single(float(int(definition.scale_minimum)+random.next_int(int(definition.scale_bound)))/float(definition.scale_divisor))
		fragments.append({"rotation_radians":rotation,"scale":scale_value,"resource_id":int(definition.fragment_resource)})
	return fragments

func _sample_cargo(random: RefCounted,energy_cells: int=-1) -> Array:
	var count: int=random.next_int(int(_definition.cargo_count_bound))
	if count==0:
		if random.next_int(int(_definition.cargo_count_bound))==0: return []
		count=1
	var cargo := []
	for slot in count:
		var selected := -1
		for attempt in int(_definition.cargo_attempts):
			var id: int=random.next_int(_items.size())
			var item: Dictionary=_items[id]
			if item.restricted: continue
			if random.next_int(int(_definition.chance_bound))>=int(_definition.category_weights[item.category]): continue
			if random.next_int(int(_definition.chance_bound))>=item.chance: continue
			if item.price<=0 or id in _definition.excluded_items: continue
			if item.category!=int(_definition.commodity_category) and item.rank>int(_definition.maximum_rank): continue
			selected=id
			break
		var quantity_bound: int=int(_definition.quantity_bound)
		if selected<0:
			selected=int(_definition.fallback_item_minimum)+random.next_int(int(_definition.fallback_item_bound))
			quantity_bound=int(_definition.commodity_quantity_bound)
		elif _items[selected].category==int(_definition.commodity_category):
			quantity_bound=int(_definition.commodity_quantity_bound)
		cargo.append({"item_id":selected,"quantity":int(_definition.quantity_minimum)+random.next_int(quantity_bound)})
	var fuel: int=_player_energy_cells if energy_cells<0 else energy_cells
	if _khador_fitted and fuel==0 and random.next_int(int(_definition.chance_bound))<=int(_definition.special_chance_maximum):
		cargo[0].item_id=int(_definition.special_item)
	return cargo

static func _energy_quantity(entries: Array) -> int:
	for row in entries:
		if row.item_id==122:return int(row.quantity)
	return 0

func sample_relaunch_cargo(random_state: Variant,energy_cells: int=-1) -> Dictionary:
	error=""
	if _ambient.is_empty() or _actors.is_empty():return fail("Traffic cargo regeneration requires its retained generated population")
	var random:=Random.new()
	if not random.restore(random_state):return fail(random.error)
	return {"cargo":_sample_cargo(random,energy_cells),"random_state":random.snapshot()}

func route(actor_id: int) -> RefCounted:
	if not _arrival.is_empty():
		reject("The rescue replaces its generated route; use its authored construction record")
		return null
	if _actors.is_empty() or actor_id<0 or actor_id>=_routes.size():
		reject("Generate opening NPC construction before requesting a route")
		return null
	if _routes[actor_id]==null:
		reject("This actor does not use a generated patrol route")
		return null
	return _routes[actor_id].fork_for_frame()

func arrival_motion_construction() -> Dictionary:
	error=""
	if _arrival.is_empty() or _actors.size()!=1:return fail("Generate rescue construction before requesting its motion poses")
	var result:=_identity.duplicate()
	for key in ["actor_id","body_pose","statistics_pose","model_local_pose"]:result[key]=_actors[0][key]
	return result

func mission_context_owner() -> RefCounted:return _mission_context

func snapshot() -> Dictionary:
	if _identity.is_empty(): return {}
	var value := _identity.duplicate()
	value.merge({"actors":_actors.duplicate(true),"random_state":_random_state.duplicate()})
	if not _traffic_sample.is_empty():value.population=_traffic_sample.duplicate(true)
	if not _contract_layout.is_empty():
		if _contract.get("bakka",false):
			value.bakka_encounter=_contract_layout.duplicate(true)
			value.system_id=int(_contract.context.system_id)
			value.player_ship_id=int(_contract.loadout.ship_id)
		else:value.contract_encounter=_contract_layout.duplicate(true)
	if not _convoy.is_empty():value.convoy_context=_convoy.context.duplicate(true)
	if not _alioth.is_empty():value.alioth_context=_alioth.context.duplicate(true)
	if not _kappa.is_empty():
		value.kappa_context=_kappa.context.duplicate(true);value.kappa_loadout=_kappa.loadout.duplicate(true)
	if not _sahi.is_empty():
		value.sahi_context=_sahi.context.duplicate(true);value.player_ship_id=int(_sahi.loadout.ship_id)
	if not _dekato.is_empty():
		value.dekato_context=_dekato.context.duplicate(true);value.player_ship_id=int(_dekato.loadout.ship_id)
		value.player_equipment_ids=_dekato.loadout.equipment_ids.duplicate()
	if not _selected40.is_empty():
		value.selected40_context=_selected40.context.duplicate(true);value.player_ship_id=int(_selected40.loadout.ship_id)
		value.player_equipment_ids=_selected40.loadout.equipment_ids.duplicate()
	if not _selected41.is_empty():
		value.selected41_context=_selected41.context.duplicate(true);value.player_ship_id=int(_selected41.loadout.ship_id)
		value.player_equipment_ids=_selected41.loadout.equipment_ids.duplicate()
	if _traffic.has("free_context"):
		value.free_context=_traffic.free_context.duplicate(true);value.player_ship_id=int(_traffic.free_player_ship_id)
		value.station_id=int(_traffic.station_id)
	if _traffic.has("void_context"):
		value.void_context=_traffic.void_context.duplicate(true);value.player_ship_id=int(_traffic.void_player_ship_id)
		value.player_equipment_ids=_traffic.void_equipment_ids.duplicate()
		value.station_id=-1;value.system_id=-1
	return value

func clear() -> void:
	error="";_identity={};_definition={};_items=[];_khador_fitted=false;_player_energy_cells=0;_routes=[];_actors=[];_random_state={};_arrival={};_full_hold={};_training={};_traffic={};_traffic_sample={};_authored_route=null;_ambient={};_free={};_population_owner=null;_mission_context=null
	_contract={};_contract_layout={};_generated=false;_convoy={};_alioth={};_kappa={};_sahi={};_dekato={};_selected40={};_selected41={}

var _contract:={}
var _contract_layout:={}
var _generated:=false

func reject(message: String) -> bool:
	error=message
	return false

func fail(message: String) -> Dictionary:
	reject(message)
	return {}
