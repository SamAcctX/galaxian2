extends RefCounted
## The first native cinematic transaction only. Later event5 stages remain
## closed until their full freighter/effect/player consumers are composed.
const ATTACK_OFFSETS=[[-40000,500,-30000],[-41000,-200,-31000],[-42000,100,-32000]]
const ATTACK_CAMERA_OFFSET=[-38000,0,-30200]
## Source41 has its own eight-actor construction. In particular the new
## freighter uses the Vossk factory, not the retained Terran assembly of40.
## These declarations grant neither a saved cursor nor application admission.
const Previous=preload("res://src/content/selected40_population_definitions.gd")
const Vossk=preload("res://src/content/vossk_traffic_definitions.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const VALUES = {"campaign_cursor":41,"mission_kind":4,"station_id":-1,"system_id":-1,"actor_count":8,"freighter_actor_id":0,"freighter_actor_kind":1,"freighter_subtype":1,"freighter_hull_catalogue_id":13,"freighter_hull_base":1800,"freighter_hull_per_rank":5,"missing_hull_factor":0.7,"freighter_cruise_enabled":true,"fighter_actor_kind":9,"fighter_subtype":0,"fighter_hull_catalogue_id":8,"positions":[[0,0,-300000],[0,0,-260000],[-10000,10000,-240000],[13000,2000,-220000],[-72000,-4000,-210000],[60000,-40000,-190000],[-18000,30000,-160000],[17000,40000,-140000]],"player_position":[3000,2000,-320000],"player_rotation":[0,0,0],"completion_condition":{"kind":25,"parameter":0},"failure_condition":{"kind":7,"parameter":1}}
const NAME_IDS=[1593,1585]
## Both supplied Mac editions use the same eight voice events. The source
## radio observes the player's FIRST NPC target (the retained freighter),
## independently of scanner selection, lifetime kills and mission results.
const RADIO_TEXT_IDS=[[2041,2042,2043,2044,2045,2046,2052,2053],[2027,2028,2029,2030,2031,2032,2038,2039]]
const RADIO_SPEAKERS=[0,7,0,7,7,7,0,0]
const RADIO_KINDS=[5,6,6,6,26,6,1,6]
const RADIO_VALUES=[80000,0,1,2,-100000,4,0,6]
const RADIO_POSITION_TOLERANCE=5000.0

static func radio_events(edition: int) -> Array:
	if edition not in [0,1]:return []
	var events:=[]
	for index in 8:events.append({"speaker_id":RADIO_SPEAKERS[index],"text_id":RADIO_TEXT_IDS[edition][index],"voice_event_id":531+index,"condition":RADIO_KINDS[index],"values":[RADIO_VALUES[index]]})
	return events

static func radio(bindings: RefCounted) -> Array:
	if not available(bindings):return []
	return radio_events(0 if Previous.Equal.equal_value(Previous.Nehma.declarations(bindings),Previous.Nehma.VALUES) else 1)

## The ordinary player-first target builder also applies to story41. Neither
## the earlier Void player-last exceptions nor story16's damage doubling apply.
static func weapon_profile(bindings: RefCounted,packet: Dictionary) -> Dictionary:
	var data:=player_profile(bindings,packet)
	if data.is_empty() or not load("res://src/content/free_lifecycle_definitions.gd").available(bindings) or not load("res://src/content/contract_ship_lifecycle_definitions.gd").available(bindings):return {}
	data.actor_count=packet.actors.size();data.player_ship_id=packet.player_ship_id
	data.actor_kinds=packet.actors.map(func(row):return row.actor_kind)
	data.hull_catalogue_ids=packet.actors.map(func(row):return row.hull_catalogue_id)
	data.target_memberships=Previous.Weapons.target_memberships(data.actor_kinds)
	data.free_traffic=bindings.mido_travel.free_traffic
	data.selection_skipped_modes=bindings.early_contracts.ship_lifecycle.selection_skipped_modes.map(func(mode):return int(mode))
	return data

## This consumes the completed native41 generation, never an arbitrary Void
## dictionary or a new factory. Physical location is -1; faction lookup retains
## the actual normal-space source carried by the typed portal entry.
static func consequence_profile(bindings: RefCounted,catalogues: RefCounted,world: RefCounted) -> Dictionary:
	if not is_instance_of(world,load("res://src/simulation/selected41_world_initialization.gd")) or world.snapshot().is_empty():return {}
	if not is_instance_of(catalogues,load("res://src/content/catalogues.gd")) or bindings==null or catalogues.content_id!=bindings.base_content_id:return {}
	var builder: RefCounted=world.construction_owner();var scenery: RefCounted=world.scenery_owner()
	var construction: RefCounted=builder.npc_construction_owner()
	if scenery.world_initialization_owner().npc_construction_owner()!=construction:return {}
	var packet: Dictionary=construction.snapshot();var data:=weapon_profile(bindings,packet)
	var entry: RefCounted=world.entry_owner();var retained: Dictionary=entry.snapshot()
	var equipment: RefCounted=entry.equipment_owner();var owned: Dictionary=equipment.snapshot()
	if data.is_empty() or not equipment.cargo_cache_valid() or packet.selected41_context!=retained.context:return {}
	if owned.loadout.station_id!=-1 or owned.loadout.system_id!=-1 or owned.loadout.ship_id!=packet.player_ship_id or owned.loadout.equipment_ids!=packet.player_equipment_ids:return {}
	if load("res://src/simulation/equipment_slots.gd").checked_slots(bindings,catalogues,owned.loadout).is_empty():return {}
	var system: Variant=retained.get("return_system_id")
	if not Numbers.integer(system,0,catalogues.tables.systems.size()-1) or retained.source_before.get("source_system_id")!=system:return {}
	if not load("res://src/content/alioth_lifecycle_definitions.gd").available(bindings):return {}
	data.merge({"authored_story":true,"context_key":"selected41_context","context":retained.context.duplicate(true),"selected41_context":retained.context.duplicate(true),
		"source_system_id":system,"actor_rows":packet.actors.duplicate(true),"standing":bindings.mido_travel.free_lifecycle.standing,
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
	data.freighter_death=load("res://src/content/freighter_destruction_definitions.gd").for_faction(bindings,1)
	if data.freighter_death.is_empty():return {}
	data.freighter_death.merge({"campaign_cursor":41,"station_id":-1,"system_id":-1,"hull_catalogue_id":13},true)
	return data

static func available(bindings: RefCounted) -> bool:
	return Previous.available(bindings) and Vossk.parameters(bindings.mido_travel.get("vossk_traffic"))

static func mission(bindings: RefCounted) -> Dictionary:
	if not available(bindings):return {}
	return {"campaign_cursor":41,"kind":4,"station_id":-1,"reward":0,"bonus":0,"source_parameter":0,"story":true}

## The original setter restores current hull and only raises capacity when
## needed. Its missing-carry fallback is binary32 multiplication then truncate.
static func freighter_hull(retained: Variant,rank: Variant) -> int:
	if not Numbers.integer(retained,-2147483648,2147483647) or not Numbers.integer(rank,0,20):return -1
	if retained>0:return retained
	return int(Vitals.single(Vitals.single(float(VALUES.freighter_hull_base+VALUES.freighter_hull_per_rank*rank))*Vitals.single(VALUES.missing_hull_factor)))

static func context_valid(bindings: RefCounted,context: Dictionary) -> bool:
	if not available(bindings):return false
	for key in ["base_content_id","binding_id"]:
		if context.get(key)!=bindings.get(key):return false
	return context.get("campaign_cursor")==41 and context.get("station_id")==-1 and context.get("system_id")==-1 and context.get("mission_kind")==4 and context.get("mission_story")==true and context.get("mission_completed")==false and context.get("mission_failed")==false and Numbers.integer(context.get("rank"),0,20) and context.get("difficulty") in [0.5,1.0] and Numbers.integer(context.get("retained_freighter_hull"),-2147483648,2147483647)

static func construction_recipe(bindings: RefCounted,context: Dictionary) -> Dictionary:
	if not context_valid(bindings,context):return {}
	var result:=VALUES.duplicate(true)
	result.context=context.duplicate(true)
	result.freighter_assembly=Previous.Population.freighter_assembly(bindings,1).duplicate(true)
	result.freighter_cargo=bindings.ambient_population.freighter.duplicate(true)
	result.name_text_id=NAME_IDS[0 if Previous.Equal.equal_value(Previous.Nehma.declarations(bindings),Previous.Nehma.VALUES) else 1]
	result.retained_hull=freighter_hull(context.retained_freighter_hull,context.rank)
	return result

static func body_profile(bindings: RefCounted,packet: Dictionary) -> Dictionary:
	var context: Variant=packet.get("selected41_context")
	if not context is Dictionary or not context_valid(bindings,context):return {}
	if not load("res://src/content/alioth_population_definitions.gd").available(bindings) or not load("res://src/content/npc_systems_definitions.gd").available(bindings):return {}
	for key in ["base_content_id","binding_id","campaign_cursor","station_id","system_id"]:
		if packet.get(key)!=context.get(key):return {}
	var actors: Variant=packet.get("actors")
	if not actors is Array or actors.size()!=int(VALUES.actor_count):return {}
	for id in actors.size():
		var row: Variant=actors[id]
		if not row is Dictionary or row.get("actor_id")!=id or row.get("actor_kind")!=(1 if id==0 else 9) or row.get("subtype")!=(1 if id==0 else 0) or row.get("hull_catalogue_id")!=(13 if id==0 else 8):return {}
		if id==0 and (not Previous.Equal.equal_value(row.get("assembly"),bindings.mido_travel.vossk_traffic.assembly) or row.get("retained_current_hull")!=freighter_hull(context.retained_freighter_hull,context.rank)):return {}
	var data: Dictionary=bindings.combat_training_control.duplicate(true)
	data.merge(context,true)
	for key in ["initial_actor_mode","initial_active","initial_hostile","friendly","initial_actor_targeting_blocked","initial_statistics_targeting_blocked"]:
		data[key]=bindings.mido_travel.traffic_control[key]
	data.freighter=bindings.mido_travel.alioth_attack.population.freighter_combat.duplicate(true)
	data.freighter.boxes=bindings.mido_travel.vossk_traffic.boxes.duplicate(true)
	return data

static func player_profile(bindings: RefCounted,packet: Dictionary) -> Dictionary:
	var data:=body_profile(bindings,packet)
	if data.is_empty() or not Previous.Weapons.parameters(bindings.early_contracts.get("ship_combat")):return {}
	if not load("res://src/content/sahi_encounter_definitions.gd").coherent(bindings.mido_travel):return {}
	data.npc_weapons=[]
	for actor in packet.actors:
		var weapon:={"unarmed":true}
		if actor.population_group=="fighter":
			weapon=Previous.Weapons.scaled_parameters(bindings.early_contracts.ship_combat.weapons,41,int(data.rank),float(data.difficulty))
			if weapon.is_empty():return {}
			var source: Dictionary=bindings.mido_travel.sahi_encounter.weapons["void"]
			for key in ["item_id","kind","catalogue_kind","model_resource_id"]:weapon[key]=int(source[key])
			weapon.damage=int(Vitals.single(Vitals.single(float(weapon.damage))*float(source.damage_multiplier)))
		for key in ["actor_id","actor_kind","hull_catalogue_id"]:weapon[key]=actor[key]
		data.npc_weapons.append(weapon)
	return data
