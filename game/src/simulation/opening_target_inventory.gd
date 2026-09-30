extends RefCounted
## Complete ordinary target membership for verified opening and training worlds.
## Unknown equipment groups and changed source populations remain unsupported.
const Opening = preload("res://src/content/opening_sky_definitions.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")
const Vehicle = preload("res://src/content/vehicle_definitions.gd")
const Loadout = preload("res://src/simulation/opening_loadout.gd")
const Actors = preload("res://src/simulation/opening_actor_state.gd")
const Population = preload("res://src/simulation/scenery_population.gd")
const Ores = preload("res://src/simulation/scenery_ores.gd")
const Field = preload("res://src/simulation/scenery_field.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Training=preload("res://src/content/combat_training_weapon_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Ambient=preload("res://src/content/ambient_population_definitions.gd")
const ContractWorld=preload("res://src/content/contract_world_definitions.gd")
const VoidCrystals=preload("res://src/content/void_crystal_definitions.gd")
const REQUIRED_EQUIPMENT_TYPE := 33
var error := ""
var _state := {}
var _actors := []
var _scenery := []
var _selected40_construction: RefCounted
var _selected40_context:={}

func configure_mission(bindings: RefCounted,catalogues: RefCounted,context: RefCounted,player: RefCounted,scenery: RefCounted,combat: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or not is_instance_of(context,load("res://src/simulation/mission_context.gd")) or not player is Player or not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")):return reject("Mission targets require the admitted player, field and cast")
	var source: Dictionary=player.loadout()
	if not context.matches_loadout(source):return reject("Mission targets lost their admitted loadout")
	var generation: RefCounted=scenery.world_initialization_owner()
	if generation==null:return reject("Mission targets require their completed native generation")
	var constructor: RefCounted=generation.npc_construction_owner()
	var field: Dictionary=scenery.snapshot();var generated: Dictionary=generation.snapshot()
	if not _configure_source(bindings,catalogues,source,constructor.snapshot().actors,field,field.departure_population,{},generated.entry_conditions.location_match):return false
	return validate_owners(combat.snapshot(),field.bodies)

## Target location belongs to the actual generated source field. The player's
## canonical equipment remains at its retained origin; no cache is relocated.
func configure_selected40(bindings: RefCounted,catalogues: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,combat: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or not player is Player or not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")):return reject("Selected40 targets require fresh inventory and native player/combat owners")
	var rules=load("res://src/content/selected40_population_definitions.gd")
	var data: Dictionary=rules.consequence_profile(bindings,catalogues,scenery,equipment)
	if data.is_empty() or not combat.has_local_reactions() or not rules.matches_world(scenery,combat.selected40_world_owner()):return reject("Selected40 targets require the complete same-generation consequence owners")
	var construction: RefCounted=combat.selected40_world_owner().npc_construction_owner()
	var source: Dictionary=player.loadout();var expected: Dictionary=equipment.snapshot().loadout.duplicate(true)
	expected.campaign_cursor=40
	if player.selected40_construction_owner()!=construction or player.snapshot().get("selected40_context")!=data.context or source!=expected:return reject("Selected40 targets differ from their native retained origin player")
	var field: Dictionary=scenery.snapshot();var count: Dictionary=field.departure_population
	if not _configure_source(bindings,catalogues,source,construction.snapshot().actors,field,count,data):return false
	_selected40_construction=construction;_selected40_context=data.context.duplicate(true)
	_state.selected40_context=_selected40_context.duplicate(true)
	_state.target_station_id=int(data.station_id);_state.target_system_id=int(data.system_id)
	return true

func matches_selected40(combat: RefCounted,construction: RefCounted,context: Dictionary) -> bool:
	if _selected40_construction==null or construction!=_selected40_construction or context!=_selected40_context:return false
	if not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")) or not combat.has_local_reactions():return false
	var world: RefCounted=combat.selected40_world_owner()
	return world!=null and world.npc_construction_owner()==_selected40_construction

func configure(bindings: RefCounted, catalogues: RefCounted, opening_field: Dictionary) -> bool:
	clear()
	if bindings==null or catalogues==null or not Opening.parameters(bindings.opening_sky):
		return reject("Target inventory requires the verified fresh opening context")
	if not Vehicle.valid_parameters(bindings.vehicle_response):
		return reject("Target inventory requires the source installed equipment type schema")
	var loadout := Loadout.new()
	if not loadout.configure(bindings,catalogues,bindings.base_content_id):return reject(loadout.error)
	var source := loadout.snapshot()
	var actors := Actors.new()
	if not actors.configure(bindings,catalogues,bindings.base_content_id):return reject(actors.error)
	var population := Population.new()
	if not population.configure(bindings):return reject(population.error)
	var count: Dictionary = population.for_station(source.station_id)
	if count.is_empty():return reject(population.error)
	count.center=Vector3.ZERO
	return _configure_source(bindings,catalogues,source,actors.snapshot().actors,opening_field,count)

func configure_combat_training(bindings: RefCounted, catalogues: RefCounted, player: RefCounted, scenery: RefCounted) -> bool:
	return _configure_equipped(bindings,catalogues,player,scenery,7)

func configure_local_travel(bindings: RefCounted, catalogues: RefCounted, player: RefCounted, scenery: RefCounted, cursor: int=10) -> bool:
	if bindings==null or not Travel.parameters(bindings.mido_travel):clear();return reject("Local targets require their source declarations")
	if not (load("res://src/content/free_campaign_definitions.gd").supported(bindings,cursor) and load("res://src/content/free_flight_definitions.gd").available(bindings)) and not (cursor==16 and load("res://src/content/alioth_flight_definitions.gd").available(bindings)) and not (cursor==14 and not load("res://src/content/convoy_world_definitions.gd").flight(bindings,79).is_empty()) and not (ContractWorld.supports(bindings,cursor)) and (cursor not in [10,11,12] or Travel.journey(bindings.mido_travel,cursor).is_empty()):clear();return reject("Unsupported local target context")
	return _configure_equipped(bindings,catalogues,player,scenery,cursor)

func configure_kappa_rescue(bindings: RefCounted,catalogues: RefCounted,player: RefCounted,scenery: RefCounted) -> bool:
	clear()
	if not player is Player or scenery==null or scenery.get_script()==null or scenery.get_script().resource_path!="res://src/simulation/opening_scenery.gd":return reject("Kappa targets require native player and scenery owners")
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null:return reject("Kappa targets require completed world construction")
	var packet: Dictionary=world.snapshot().get("npc_construction",{})
	var data: Dictionary=load("res://src/content/kappa_population_definitions.gd").lifecycle(bindings,packet)
	if data.is_empty() or player.snapshot().get("kappa_context")!=packet.kappa_context:return reject("Kappa targets differ from the player's generated encounter")
	return _configure_equipped(bindings,catalogues,player,scenery,int(data.campaign_cursor))

func _configure_story(bindings: RefCounted,catalogues: RefCounted,player: RefCounted,scenery: RefCounted,data: Dictionary) -> bool:
	return _configure_equipped(bindings,catalogues,player,scenery,int(data.campaign_cursor),data)

func configure_ordinary_void(bindings: RefCounted,catalogues: RefCounted,player: RefCounted,scenery: RefCounted,data: Dictionary) -> bool:
	clear()
	if bindings==null or not data.get("ordinary_void",false) or not player is Player or scenery==null or scenery.get_script()==null or scenery.get_script().resource_path!="res://src/simulation/opening_scenery.gd":return reject("Void targets require the generated fighter, player and crystal field")
	var world: RefCounted=scenery.world_initialization_owner()
	var initial: Dictionary={} if world==null else world.snapshot()
	var source: Dictionary=player.loadout();var field: Dictionary=scenery.snapshot()
	if initial.get("campaign_cursor")!=data.campaign_cursor or not initial.get("void_context") is Dictionary or source.get("campaign_cursor")!=data.campaign_cursor or source.get("station_id")!=-1 or source.get("system_id")!=-1:return reject("Void target player differs from the selected location")
	for key in initial.void_context:
		if data.context.get(key)!=initial.void_context[key]:return reject("Void target selection changed after fighter construction")
	if source.get("base_content_id")!=bindings.base_content_id or source.get("binding_id")!=bindings.binding_id or initial.get("base_content_id")!=bindings.base_content_id or initial.get("binding_id")!=bindings.binding_id:return reject("Void target content identity changed")
	var context: Dictionary=initial.void_context.duplicate(true);context.merge(initial.entry_conditions,true)
	if not VoidCrystals.selected_void(bindings.mido_travel,context):return reject("Void target lost its nonstory selection")
	var population:=Population.new()
	if not population.configure(bindings):return reject(population.error)
	var count: Dictionary=population.for_void_crystals(context)
	if count.is_empty():return reject(population.error)
	return _configure_source(bindings,catalogues,source,initial.npc_construction.actors,field,count,data,true,true)

func _configure_equipped(bindings: RefCounted, catalogues: RefCounted, player: RefCounted, scenery: RefCounted, cursor: int, story: Dictionary={}) -> bool:
	clear()
	# Scenery also owns primary contact staging; avoid a preload cycle through
	# its primary owner while still requiring the native scenery implementation.
	if bindings==null or not player is Player or scenery==null or scenery.get_script()==null or scenery.get_script().resource_path!="res://src/simulation/opening_scenery.gd" or not Training.parameters(bindings.combat_training_weapons):return reject("Training targets require the native equipped player and scenery")
	var source: Dictionary=player.loadout();var field: Dictionary=scenery.snapshot()
	if source.get("campaign_cursor")!=cursor or source.get("binding_id")!=bindings.binding_id or source.get("base_content_id")!=bindings.base_content_id:return reject("Equipped target entry has a different identity")
	var world: RefCounted=scenery.world_initialization_owner()
	var initial: Dictionary={} if world==null else world.snapshot()
	if initial.get("campaign_cursor")!=cursor:return reject("Equipped targets require completed world construction")
	var population:=Population.new()
	if not population.configure(bindings):return reject(population.error)
	var count:=population.for_dekato(bindings,story.context,initial.entry_conditions) if story.get("context_key")=="dekato_context" else population.for_departure(source.station_id,initial.entry_conditions,cursor)
	if count.is_empty():return reject(population.error)
	return _configure_source(bindings,catalogues,source,initial.npc_construction.actors,field,count,story,initial.entry_conditions.location_match)

func _configure_source(bindings: RefCounted, catalogues: RefCounted, source: Dictionary, actor_rows: Array, opening_field: Dictionary, count: Dictionary, story: Dictionary={},location_match:=false,ordinary_void:=false) -> bool:
	if catalogues==null or catalogues.content_id!=bindings.base_content_id or not Vehicle.valid_parameters(bindings.vehicle_response):return reject("Target inventory requires matching equipment type declarations")
	var location: Dictionary=story.selected40_entry if story.get("context_key")=="selected40_context" else source
	var type_index := int(bindings.vehicle_response.item_type_value_index)
	for id in source.equipment_ids:
		var values: Variant = catalogues.tables.items[id].arrays[2]
		if values.size()<=type_index or not Numbers.integer(values[type_index],0,65535):
			return reject("Opening equipment has no supported source type")
		if int(values[type_index])==REQUIRED_EQUIPMENT_TYPE:
			return reject("Opening equipment requires an unsupported additional target group")
	for key in ["base_content_id","binding_id"]:
		if not exact_value(opening_field.get(key),source[key]):return reject("Opening target field has a different identity or location")
	if ordinary_void:
		if opening_field.get("station_id")!=-1 or opening_field.get("system_id")!=-1 or source.get("station_id")!=-1 or source.get("system_id")!=-1:return reject("Void target field or equipped selected location changed")
	else:
		for key in ["station_id","system_id"]:
			if not exact_value(opening_field.get(key),location[key]):return reject("Opening target field has a different identity or location")
	if not opening_field.get("center") is Vector3 or opening_field.center!=count.center:
		return reject("Ordinary targets require the source scenery center")
	var rows: Variant = opening_field.get("objects")
	if not rows is Array or rows.size()!=count.count:
		return reject("Opening target scenery count differs from its source population")
	var large_count: Variant = opening_field.get("large_count")
	if not large_count is int or large_count<Field.LARGE_COUNT_BASE or large_count>=Field.LARGE_COUNT_BASE+Field.LARGE_COUNT_BOUND:
		return reject("Opening target scenery has an invalid size-class boundary")
	var ores := Ores.new()
	if not ores.configure(bindings,catalogues,-1 if ordinary_void else location.station_id,location_match,false,int(source.get("campaign_cursor",0))):return reject(ores.error)
	var possible_ores := {}
	if location_match:possible_ores[int(bindings.scenery_resources.fallback_item_id)]=true
	var ore_rows: Array = ores.snapshot().rows
	for index in int(bindings.scenery_resources.sample_rows):
		var ore: Dictionary = ore_rows[index]
		if ore.weight>0 and ores.accepted_id(ore.item_id):possible_ores[ore.item_id]=true
	var variant := 1 if location_match else (2 if location.system_id==22 else 0)
	var model_id := int(bindings.scenery_resources.model_ids[variant])
	var scenery := []
	var indices := []
	for index in rows.size():
		var row: Variant = rows[index]
		if not row is Dictionary or not row.get("index") is int or row.index!=index:
			return reject("Opening scenery targets must retain source array order")
		if not row.get("model_variant") is int or row.model_variant!=variant or not row.get("model_id") is int or row.model_id!=model_id:
			return reject("Opening scenery target model differs from its fresh source variant")
		if not row.get("item_id") is int or not possible_ores.has(row.item_id) or (ordinary_void and row.item_id!=int(bindings.mido_travel.void_crystals.field.ore_item_id)):
			return reject("Opening scenery target ore is outside its source population")
		if not row.get("large") is bool or row.large!=(index<large_count):
			return reject("Opening scenery target size classes are out of order")
		if not row.get("position") is Vector3 or not row.position.is_finite():
			return reject("Opening scenery target position is unavailable")
		var half_width := float(Field.LARGE_WIDTH if row.large else Field.SMALL_WIDTH)*0.5
		for axis in 3:
			if row.position[axis]<count.center[axis]-half_width or row.position[axis]>=count.center[axis]+half_width:
				return reject("Opening scenery target lies outside its source field")
		var minimum_scale := Field.f32(float(120 if row.large else 30)*Field.f32(0.01))
		var maximum_scale := Field.f32(float(219 if row.large else 99)*Field.f32(0.01))
		if not row.get("scale") is float or not is_finite(row.scale) or row.scale!=Field.f32(row.scale) or row.scale<minimum_scale or row.scale>maximum_scale:
			return reject("Opening scenery target scale is outside its source size class")
		scenery.append({"index":index,"model_id":model_id,"item_id":row.item_id,
			"scale":row.scale,"large":row.large,"position":row.position})
		indices.append(index)
	var npc_ids := []
	var cast:=[]
	for actor in actor_rows:
		# The native world already validated its cast and assemblies. Target
		# resources follow those semantic records, not the campaign cursor.
		var assembled: bool=actor.get("population_group") in ["freighter","capital"]
		var debris: bool=actor.get("population_group") in ["debris","static"]
		var root_id:=-1
		if assembled:
			var assembly: Variant=actor.get("assembly")
			if not assembly is Dictionary:return reject("Constructed target lost its body assembly")
			if assembly.has("root_model_id"):root_id=int(assembly.root_model_id)
			elif assembly.get("body_resource_ids") is Array and not assembly.body_resource_ids.is_empty():root_id=int(assembly.body_resource_ids[0])
			if root_id<0:return reject("Constructed target lost its body resource")
		var model: String=bindings.resolve(root_id,"mesh") if assembled else bindings.resolve(int(actor.resource_id),"mesh") if debris else bindings.resolve_ship_model(int(actor.hull_catalogue_id))
		if model.is_empty():return reject(bindings.error)
		npc_ids.append(actor.actor_id)
		cast.append({"actor_id":actor.actor_id,"actor_kind":actor.actor_kind,
			"hull_catalogue_id":-1 if debris else actor.hull_catalogue_id,"hull_resource":model})
	var canonical := {}
	for key in ["base_content_id","binding_id","ship_id","slots","equipment_ids"]:canonical[key]=source[key]
	if source.has("campaign_cursor"):canonical.campaign_cursor=source.campaign_cursor
	_state={"base_content_id":source.base_content_id,"binding_id":source.binding_id,
		"station_id":source.station_id,"system_id":source.system_id,"ship_id":source.ship_id,
		"equipment_ids":source.equipment_ids.duplicate(),"npc_ids":npc_ids,"scenery_indices":indices,
		"third_group_absence":"missing_equipment_type","required_equipment_type":REQUIRED_EQUIPMENT_TYPE,
		"loadout":canonical.duplicate(true)}
	_actors=cast;_scenery=scenery
	return true

## Ammunition removal cannot add targets or reconstruct their source ordering.
## Call this on a fork before committing the corresponding weapon frame.
func retain_secondary_ammunition(owner: RefCounted) -> bool:
	error=""
	if _state.is_empty() or not is_instance_of(owner,load("res://src/simulation/secondary_weapons.gd")):return reject("Target inventory requires the actual secondary launch history")
	if _state.get("equipment_ids")!=_state.loadout.get("equipment_ids"):return reject("Target inventory lost its retained equipment order")
	var next: Dictionary=owner.reconcile_weapon_loadout(_state.loadout)
	if next.is_empty():return reject(owner.error)
	_state.loadout=next;_state.equipment_ids=next.equipment_ids.duplicate()
	return true

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate(true)
	# Construction membership and geometry are immutable after configuration.
	copy._actors=_actors;copy._scenery=_scenery
	copy._selected40_construction=_selected40_construction;copy._selected40_context=_selected40_context
	return copy

func validate_loadout(loadout: Dictionary) -> bool:
	error=""
	if _state.is_empty():return reject("Configure fresh opening targets before validating equipment")
	for key in _state.loadout:
		if not exact_value(loadout.get(key),_state.loadout[key]):
			return reject("Current equipment differs from the verified fresh opening loadout")
	return true

func validate_owners(combat: Dictionary, bodies: Dictionary) -> bool:
	error=""
	if _state.is_empty():return reject("Configure fresh opening targets before validating owners")
	for owner in [combat,bodies]:
		for key in ["base_content_id","binding_id"]:
			if owner.get(key)!=_state[key]:return reject("Target owner belongs to another content identity")
	var actors: Variant = combat.get("actors")
	var scenery: Variant = bodies.get("objects")
	if not actors is Array or actors.size()!=_actors.size() or not scenery is Array or scenery.size()!=_scenery.size():
		return reject("Target owner omits or adds source targets")
	for index in actors.size():
		var actor: Variant = actors[index]
		if not actor is Dictionary:return reject("Invalid target actor record")
		for key in ["actor_id","hull_catalogue_id","hull_resource","actor_kind"]:
			if key=="actor_kind" and _selected40_construction!=null and load("res://src/content/selected40_population_definitions.gd").constructed_kind_matches(actor,int(_actors[index][key])):continue
			if not exact_value(actor.get(key),_actors[index][key]):return reject("Target actor identity or source order changed")
		for key in ["base_content_id","binding_id"]:
			if actor.get(key)!=_state[key]:return reject("Target actor belongs to another content identity")
	for index in scenery.size():
		var row: Variant = scenery[index]
		if not row is Dictionary:return reject("Invalid scenery target record")
		for key in _scenery[index]:
			if not exact_value(row.get(key),_scenery[index][key]):return reject("Scenery target identity, order or placement changed")
	return true

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func npc_ids() -> Array:
	return _state.get("npc_ids",[]).duplicate()

func clear() -> void:
	error="";_state={};_actors=[];_scenery=[];_selected40_construction=null;_selected40_context={}

static func exact_value(left: Variant, right: Variant) -> bool:
	if typeof(left)!=typeof(right):return false
	if left is Array:
		if left.size()!=right.size():return false
		for index in left.size():
			if not exact_value(left[index],right[index]):return false
		return true
	if left is Dictionary:
		if left.size()!=right.size():return false
		for key in left:
			if not right.has(key) or not exact_value(left[key],right[key]):return false
		return true
	return left==right

func reject(message: String) -> bool:
	error=message;return false
