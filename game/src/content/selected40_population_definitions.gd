extends RefCounted
## Consequence preparation consumes an actual field/world owner. It does not
## turn a retained station inventory into an inventory at the selected source.
## Native construction rules for the separately selected kind161 cast.
## This capability neither constructs its special world nor admits departure.
const Difficulty=preload("res://src/content/difficulty_definitions.gd")
const Nehma=preload("res://src/content/nehma_return_definitions.gd")
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Population=preload("res://src/content/free_population_definitions.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Weapons=preload("res://src/content/contract_ship_combat_definitions.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const VALUES = {"actor_count":13,"freighter_actor_id":0,"freighter_actor_kind":0,"freighter_subtype":1,"freighter_hull_catalogue_id":13,"freighter_hull_base":1800,"freighter_hull_per_rank":5,"freighter_position":[-9999999,-9999999,-9999999],"escort_first":1,"escort_end":5,"escort_actor_kind":0,"named_escort_id":2,"attack_first":5,"reserve_first":9,"void_actor_kind":9,"void_hull_catalogue_id":8,"reserve_position":[-500000,-500000,-500000],"patrol_points":[[-20000,-3000,35000],[-20000,-3000,200000]],"attack_origin":[-20000,-3000,200000],"route_loop":false,"route_initial_index":0,"parked_mode":5,"failure_condition_kind":7,"failure_prefix_count":1,"destroyed_mode":4}
const NAME_IDS=[[1593,1594],[1585,1586]]
const REVEALED_KIND=1
const ACTIVATION_MODE=1

## The script reclassifies the same Terran freighter, not its hull/resources.
## Consumers with constructor-keyed resources retain that original kind.
static func constructed_kind_matches(actor: Dictionary,kind: int) -> bool:
	return actor.get("actor_kind")==kind or (kind==0 and actor.get("selected40_component")==true and actor.get("selected40_revealed")==true and actor.get("actor_id")==0 and actor.get("actor_kind")==REVEALED_KIND and actor.get("hull_catalogue_id")==13)
## Separate source latches: radio3 starting reveals the freighter; radio4
## finishing restores flight. Reserves consume XYZ draws in actor9..12 order.
const SEQUENCE={"reveal_started_event":3,"restore_finished_event":4,"camera_offset":[-7000,500,17000],"camera_z_per_ms":-2,"reserve_at_z":90000,"reserve_jitter_bound":20000,"reserve_jitter_offset":-10000,"escape_origin_z":200000,"retire_above_z":500000,"retired_position":[0,0,-200000],"escaped_radio_minimum_ms":60000}

static func radio_events(edition: int) -> Array:
	if edition not in [0,1]:return []
	var events:=[]
	var speakers:=[0,8,0,7,0,7,0];var kinds:=[5,6,6,5,6,12,24];var values:=[10000,0,1,40000,3,0,0]
	for index in 7:events.append({"speaker_id":speakers[index],"text_id":(2031 if edition==0 else 2017)+index,"voice_event_id":524+index,"condition":kinds[index],"values":[values[index]]})
	return events

static func radio(bindings: RefCounted) -> Array:
	if not available(bindings):return []
	return radio_events(0 if Equal.equal_value(Nehma.declarations(bindings),Nehma.VALUES) else 1)
## Special mission selection is independent of its -1 pending target. The
## enclosing normal-space world keeps the chosen real location and type 3.
const ENTRY_VALUES = {"world_type":3,"last_source_selection_cursor":44,"pending_target_station_id":-1,"portal_slot":3,"portal_position":[-20000,-3000,200000],"arrival_player_position":[-105000,0,80000],"arrival_player_yaw":1.5707963705062866}

static func available(bindings: RefCounted) -> bool:
	return Nehma.source_available(bindings) and Population.available(bindings) and load("res://src/content/early_contract_definitions.gd").encounter_parameters(bindings.early_contracts)

## The station is an origin, not the special encounter's destination. In
## particular no station_id=-1 record is manufactured from this context.
static func context_valid(bindings: RefCounted,context: Dictionary) -> bool:
	if not available(bindings):return false
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key):return false
	for key in ["campaign_cursor","mission_kind"]:
		if not context.get(key) is int or context[key]!={"campaign_cursor":40,"mission_kind":161}[key]:return false
	# The retained equipment follows real native travel; Néhma30/2 is the
	# immutable input checkpoint, not the only possible runtime location.
	if not context.get("origin_station_id") is int or not context.get("origin_system_id") is int:return false
	var origin: Dictionary=load("res://src/content/ordinary_world_definitions.gd").location(bindings,context.origin_station_id)
	if origin.is_empty() or origin.system_id!=context.origin_system_id:return false
	return context.get("mission_story")==true and context.get("mission_completed")==false and context.get("mission_failed")==false and Numbers.integer(context.get("rank"),0,20) and Difficulty.valid(context.get("difficulty"))

static func construction_recipe(bindings: RefCounted,context: Dictionary) -> Dictionary:
	if not context_valid(bindings,context):return {}
	var result: Dictionary=VALUES.duplicate(true)
	result.freighter_assembly=Population.freighter_assembly(bindings,int(result.freighter_actor_kind)).duplicate(true)
	# This story passes hull13 to the same Terran assembly factory that
	# ordinary traffic calls with hull15. Do not replace the authored hull.
	if result.freighter_assembly.is_empty():return {}
	var edition:=0 if Equal.equal_value(Nehma.declarations(bindings),Nehma.VALUES) else 1
	result.name_text_ids=NAME_IDS[edition].duplicate()
	result.hulls=bindings.early_contracts.encounter_construction.hulls.duplicate(true)
	result.freighter_cargo=bindings.ambient_population.freighter.duplicate(true)
	result.context=context.duplicate(true)
	return result

## Statistics use the shared fighter/Terran freighter factory. This profile
## deliberately has no selected world location or mission-result authority.
static func body_profile(bindings: RefCounted,packet: Dictionary) -> Dictionary:
	var context: Variant=packet.get("selected40_context")
	if not context is Dictionary or not context_valid(bindings,context):return {}
	if not load("res://src/content/alioth_population_definitions.gd").available(bindings) or not load("res://src/content/npc_systems_definitions.gd").available(bindings):return {}
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if packet.get(key)!=context[key]:return {}
	var actors: Variant=packet.get("actors")
	if not actors is Array or actors.size()!=int(VALUES.actor_count):return {}
	var data: Dictionary=bindings.combat_training_control.duplicate(true)
	data.merge(context,true)
	for key in ["initial_actor_mode","initial_active","initial_hostile","friendly","initial_actor_targeting_blocked","initial_statistics_targeting_blocked"]:
		data[key]=bindings.mido_travel.traffic_control[key]
	data.freighter=bindings.mido_travel.alioth_attack.population.freighter_combat
	# The training declaration carries its own station. That is not this
	# component's location: keep only the separately validated earned origin.
	data.erase("station_id")
	data.erase("system_id")
	return data

## Retained equipment is still at the earned origin. A prospective source-world
## selection must not relabel this loadout or fabricate a target-world cache.
static func retained_player_context(bindings: RefCounted,packet: Dictionary,loadout: Dictionary) -> Dictionary:
	var context: Variant=packet.get("selected40_context")
	if not context is Dictionary or not context_valid(bindings,context):return {}
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if packet.get(key)!=context[key]:return {}
	for key in ["base_content_id","binding_id"]:
		if loadout.get(key)!=context[key]:return {}
	if not packet.get("actors") is Array or packet.actors.size()!=int(VALUES.actor_count):return {}
	for key in ["station_id","system_id"]:
		if not loadout.get(key) is int or loadout[key]!=context["origin_"+key]:return {}
	if not loadout.get("ship_id") is int or loadout.ship_id!=packet.get("player_ship_id"):return {}
	if not loadout.get("equipment_ids") is Array or loadout.equipment_ids!=packet.get("player_equipment_ids"):return {}
	return context.duplicate(true)

## Compose shared reactions and destruction for the actual selected source,
## without changing the physical origin of retained equipment or player cache.
static func matches_world(scenery: RefCounted,world: RefCounted) -> bool:
	if not is_instance_of(scenery,load("res://src/simulation/opening_scenery.gd")) or not is_instance_of(world,load("res://src/simulation/opening_world_initialization.gd")):return false
	var actual: RefCounted=scenery.world_initialization_owner()
	if actual==null or actual.npc_construction_owner()==null:return false
	# Scenery deliberately returns an isolated world wrapper. Its completed
	# constructor retains generation identity across wrappers; equal dictionaries
	# alone must never admit an independently regenerated cast.
	return is_same(actual.npc_construction_owner(),world.npc_construction_owner()) and actual.snapshot()==world.snapshot()

static func consequence_profile(bindings: RefCounted,catalogues: RefCounted,scenery: RefCounted,equipment: RefCounted) -> Dictionary:
	if not is_instance_of(bindings,load("res://src/content/resource_bindings.gd")) or not is_instance_of(catalogues,load("res://src/content/catalogues.gd")) or catalogues.content_id!=bindings.base_content_id:return {}
	if not is_instance_of(scenery,load("res://src/simulation/opening_scenery.gd")) or not is_instance_of(equipment,load("res://src/simulation/station_equipment.gd")):return {}
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null or world.npc_construction_owner()==null:return {}
	var field: Dictionary=scenery.read_snapshot();var packet: Dictionary=world.npc_construction_owner().snapshot()
	var data:=weapon_profile(bindings,packet)
	var owned: Dictionary=equipment.snapshot();var context:=retained_player_context(bindings,packet,owned.get("loadout",{}))
	if data.is_empty() or context.is_empty() or not equipment.cargo_cache_valid():return {}
	if load("res://src/simulation/equipment_slots.gd").checked_slots(bindings,catalogues,owned.loadout).is_empty():return {}
	var entry: Dictionary=field.get("departure_population",{}).get("selected40_entry",{})
	if entry.get("selected40")!=true or entry.get("mission_kind")!=161 or entry.get("world_type")!=3:return {}
	# The shared scenery field has no campaign cursor. Its selected entry and
	# native construction carry that identity; do not invent one on the field.
	if entry.get("campaign_cursor")!=context.campaign_cursor:return {}
	for key in ["base_content_id","binding_id"]:
		if field.get(key)!=context.get(key) or entry.get(key)!=context.get(key):return {}
	var station: Variant=entry.get("station_id");var system: Variant=entry.get("system_id")
	if not Numbers.integer(station,0,catalogues.tables.stations.size()-1) or not Numbers.integer(system,0,catalogues.tables.systems.size()-1):return {}
	if catalogues.tables.stations[station].system_id!=system or field.get("station_id")!=station or field.get("system_id")!=system:return {}
	if entry.get("source_before",{}).get("source_station_id")!=station or entry.source_before.get("source_system_id")!=system:return {}
	if not load("res://src/content/contract_ship_lifecycle_definitions.gd").available(bindings) or not load("res://src/content/alioth_lifecycle_definitions.gd").available(bindings):return {}
	data.merge({"authored_story":true,"context_key":"selected40_context","context":context,"selected40_context":context,
		"selected40_entry":entry.duplicate(true),"station_id":station,"system_id":system,"equipment_station_id":int(context.origin_station_id),
		"actor_rows":packet.actors.duplicate(true),"standing":bindings.mido_travel.free_lifecycle.standing,
		"cargo":bindings.combat_training_destruction.cargo,"nonhostile_remaining_delta":int(bindings.combat_training_destruction.nonhostile_remaining_delta)},true)
	data.lifecycle=bindings.early_contracts.ship_lifecycle.duplicate(true)
	var population: Dictionary=bindings.mido_travel.free_population
	var faction:=int(catalogues.tables.systems[system].fields[int(population.faction_field)])
	if faction<0 or faction>=population.enemy_factions.size():return {}
	data.lifecycle.reactions.primary_faction=faction
	data.lifecycle.reactions.eligible_factions=[faction,int(population.enemy_factions[faction])]
	data.actors=[]
	var models: Array=data.lifecycle.cargo_models.duplicate();models.append(bindings.mido_travel.alioth_lifecycle.void_cargo)
	for actor in packet.actors:
		var row:={}
		for key in ["actor_id","actor_kind","hull_catalogue_id","subtype","population_group"]:row[key]=actor[key]
		for model in models:
			if int(model.actor_kind)==actor.actor_kind:
				row.cargo_model_id=int(model.cargo_model_id);row.cargo_model_resource=model.cargo_model_resource
		if not row.has("cargo_model_id"):return {}
		data.actors.append(row)
	data.freighter_death=load("res://src/content/freighter_destruction_definitions.gd").for_faction(bindings,int(packet.actors[0].actor_kind))
	if data.freighter_death.is_empty():return {}
	data.freighter_death.merge({"campaign_cursor":40,"station_id":station,"system_id":system,"hull_catalogue_id":int(packet.actors[0].hull_catalogue_id)},true)
	return data

## Shared fighter targeting and gun construction, not collision consequences or
## mission admission. Kind161/story40 takes the ordinary player-FIRST branch;
## the earlier story16/24/28 Void player-last exceptions do not apply here.
static func weapon_profile(bindings: RefCounted,packet: Dictionary) -> Dictionary:
	var data:=body_profile(bindings,packet)
	if data.is_empty() or not Weapons.parameters(bindings.early_contracts.get("ship_combat")):return {}
	if not load("res://src/content/free_lifecycle_definitions.gd").available(bindings):return {}
	if not load("res://src/content/sahi_encounter_definitions.gd").coherent(bindings.mido_travel):return {}
	data.actor_count=packet.actors.size();data.player_ship_id=packet.player_ship_id
	data.actor_kinds=packet.actors.map(func(row):return row.actor_kind)
	data.hull_catalogue_ids=packet.actors.map(func(row):return row.hull_catalogue_id)
	data.target_memberships=Weapons.target_memberships(data.actor_kinds)
	data.free_traffic=bindings.mido_travel.free_traffic
	data.selection_skipped_modes=bindings.early_contracts.ship_lifecycle.selection_skipped_modes.map(func(mode):return int(mode))
	data.npc_weapons=[]
	var rules: Dictionary=bindings.early_contracts.ship_combat.weapons
	for actor in packet.actors:
		var weapon:={"unarmed":true}
		if actor.population_group=="fighter":
			weapon=Weapons.scaled_parameters(rules,40,int(data.rank),float(data.difficulty))
			if weapon.is_empty():return {}
			# Only story16 doubles Void damage. Story40 takes the shared 0.8x
			# branch, with single-precision multiplication before truncation.
			var source: Dictionary=bindings.mido_travel.sahi_encounter.weapons["void"] if actor.actor_kind==9 else rules.factions[0]
			for key in ["item_id","kind","catalogue_kind","model_resource_id"]:weapon[key]=int(source[key])
			if actor.actor_kind==9:weapon.damage=int(Vitals.single(Vitals.single(float(weapon.damage))*float(source.damage_multiplier)))
		for key in ["actor_id","actor_kind","hull_catalogue_id"]:weapon[key]=actor[key]
		data.npc_weapons.append(weapon)
	return data
