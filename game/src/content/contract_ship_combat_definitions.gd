extends RefCounted
## Original ship setup for accepted early contracts.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const Encounters=preload("res://src/content/contract_encounter_definitions.gd")
const ControlRules=preload("res://src/content/combat_training_control_definitions.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Transit=preload("res://src/content/convoy_transit_definitions.gd")
const VALUES = {"scope":"mido_contract_ship_combat","campaign_cursor":13,"mission_kinds":[4,12],"weapons":{"rank_offset":-2,"rank_multiplier":0.8999999761581421,"rank_level_min":0,"rank_level_max":20,"scaled_level_max":22,"zero_level_damage":3,"damage_offset":2,"game_difficulty_offset":-0.5,"category":0,"capacity":4,"lifetime_ms":3000,"interval_base_ms":600,"interval_cursor_multiplier":-2,"speed":16.0,"rival_speed":28.0,"rival_adds_rank_to_damage":true,"factions":[{"actor_kind":0,"item_id":0,"kind":0,"catalogue_kind":0,"model_resource_id":6754},{"actor_kind":1,"item_id":3,"kind":0,"catalogue_kind":0,"model_resource_id":6760},{"actor_kind":2,"item_id":7,"kind":0,"catalogue_kind":0,"model_resource_id":6764},{"actor_kind":3,"item_id":25,"kind":0,"catalogue_kind":2,"model_resource_id":6802},{"actor_kind":8,"item_id":19,"kind":1,"catalogue_kind":1,"model_resource_id":6795}]},"player_target_id":-1,"initial_target_index":0,"challenge_player_last_for_odd_actor_ids":true,"rival":{"initial_mode":0,"initial_active":true,"initial_targeting_blocked":false,"boost_enabled":false,"motion_speed":2.0,"initial_hostile":false,"updated_hostile":false,"friendly":true},"pirate":{"initial_hostile":false,"updated_hostile":true,"friendly":false,"boost_enabled":true}}
const SPANS = {"ship_combat_weapon_level":[54868,245],"ship_combat_damage":[55500,423],"ship_combat_weapon_factions":[55923,217],"ship_combat_special_guards":[56140,1125],"ship_combat_weapon_constructor":[57315,197],"ship_combat_weapon_table":[58994,44],"ship_combat_targets":[59632,1421],"ship_combat_boost_gate":[621413,474],"ship_combat_hostility":[610958,487],"ship_combat_speed_initialization":[606944,55],"ship_combat_motion_speed":[627033,118],"ship_combat_level_constants":[1575346,12]}

const MAC_SPANS = {"ship_combat_weapon_level":[54868,245],"ship_combat_damage":[55500,423],"ship_combat_weapon_factions":[55923,217],"ship_combat_special_guards":[56140,1125],"ship_combat_weapon_constructor":[57315,197],"ship_combat_weapon_table":[58994,44],"ship_combat_targets":[59632,1421],"ship_combat_boost_gate":[621961,474],"ship_combat_hostility":[611506,487],"ship_combat_speed_initialization":[607492,55],"ship_combat_motion_speed":[627581,118],"ship_combat_level_constants":[1550410,12]}

static func parameters(data: Variant) -> bool:
	return Equal.equal_value(data,VALUES)

# Native setup helpers.
static func population(bindings: RefCounted,packet: Dictionary,capability: RefCounted=null) -> Dictionary:
	if bindings==null or not parameters(bindings.early_contracts.get("ship_combat")) or not Encounters.parameters(bindings.early_contracts.get("encounter_construction")) or not ControlRules.parameters(bindings.combat_training_control):return {}
	var source: Variant=packet.get("contract_encounter")
	var actors: Variant=packet.get("actors")
	if not source is Dictionary or not source.get("context") is Dictionary or not actors is Array:return {}
	var context: Dictionary=source.context
	var rules: Dictionary=bindings.early_contracts.ship_combat
	for key in ["base_content_id","binding_id"]:
		if packet.get(key)!=bindings.get(key) or context.get(key)!=bindings.get(key):return {}
	if not is_instance_of(capability,load("res://src/simulation/mission_context.gd")) or not capability.matches_contract_population(bindings,packet):return {}
	var mission: Dictionary=source.mission
	var cast: Dictionary=capability.recipe().cast
	# Only a recipe that declares no ships (an incoming call) flies an empty cast.
	if actors.is_empty() and int(cast.actor_count)!=0:return {}
	var debris: Dictionary={}
	if int(cast.debris_count)>0:
		debris=load("res://src/content/contract_junk_definitions.gd").population(bindings,packet,capability)
		if debris.is_empty():return {}
	var data:=rules.duplicate(true)
	data.ordinary_standing=bindings.mido_travel.free_lifecycle.standing.duplicate(true) if cast.ship_state.get("ordinary_hostility",false) else {}
	data.campaign_cursor=context.campaign_cursor
	# Construction already validates the equipped ship's system against these
	# declarations; the retained contract context identifies its station directly.
	data.merge({"station_id":context.station_id,"system_id":int(capability.recipe().system_id),"rank":context.rank,"difficulty":context.difficulty,
		"mission_kind":mission.kind,"actor_count":actors.size(),"debris_count":int(cast.debris_count),"player_ship_id":capability.ship_id(),
		"actor_kinds":[],"hull_catalogue_ids":[],"target_memberships":[],"player_weapon_targets":[],"npc_weapons":[],"actor_policies":[]})
	for key in ["rank_base","rank_multiplier","cursor_multiplier","difficulty_offset","percentage_scale","engagement_half_extent","proximity_half_extent","target_activation_half_extent","initial_model_draw_enabled","initial_node_draw_requested","initial_engine_draw_enabled","npc_statistics_targeting_blocked","random_selection_chance","random_selection_attempts","nonplayer_selection_checks_range","completed_route_retains_position_once"]:
		data[key]=bindings.combat_training_control[key]
	var hulls: Dictionary=bindings.early_contracts.encounter_construction.hulls
	for id in actors.size():
		var actor: Variant=actors[id]
		if id<int(cast.debris_count):
			data.actor_kinds.append(-1);data.hull_catalogue_ids.append(-1);data.player_weapon_targets.append(id)
			data.npc_weapons.append({"actor_id":id,"actor_kind":-1,"hull_catalogue_id":-1,"unarmed":true})
			data.actor_policies.append({})
			continue
		var options: Dictionary=load("res://src/content/mission_recipe.gd").contract_ship_options(cast,id,int(source.unused_enemy_faction),int(context.client_faction))
		var rival: bool=options.rival
		if not actor is Dictionary or actor.get("actor_id")!=id or actor.get("subtype")!=options.subtype or actor.get("population_group")!=options.population_group:return {}
		var faction: Variant=actor.get("actor_kind")
		if not faction is int or faction!=options.faction:return {}
		var hull: Variant=actor.get("hull_catalogue_id")
		var freighter: bool=options.subtype==1
		if freighter:
			var population=load("res://src/content/free_population_definitions.gd")
			if hull!=population.freighter_hull(bindings,faction) or not population.freighter_assembly_matches(bindings,faction,actor.get("assembly")) or not actor.get("world_flag",false):return {}
		elif not hull is int or hull<0 or hull>=hulls.factions.size() or int(hulls.factions[hull])!=faction or (faction!=1 and hull<=int(hulls.mask_limit) and (int(hulls.excluded_mask)>>hull)&1):return {}
		if rival and (actor.get("friendly")!=true or actor.get("name","").is_empty() or actor.name!=context.get("contact_name") or actor.get("current_hull_override")!=9999999):return {}
		if not rival:
			for key in options.ship_state:
				if actor.get(key)!=options.ship_state[key]:return {}
		var policy: Dictionary=(rules.rival if rival else rules.pirate).duplicate(true)
		policy.merge(options.policy,true)
		if not data.ordinary_standing.is_empty():
			var standing: Dictionary=load("res://src/content/free_lifecycle_definitions.gd").standing(data.ordinary_standing,faction,context.reputation,false)
			if standing.is_empty():return {}
			policy.initial_hostile=standing.hostile;policy.updated_hostile=standing.hostile;policy.friendly=standing.friendly
		data.actor_policies.append(policy)
		data.actor_kinds.append(faction);data.hull_catalogue_ids.append(hull);data.player_weapon_targets.append(id)
		var weapon:={"unarmed":true,"actor_kind":faction} if freighter else shared_weapon(rules.weapons,context.campaign_cursor,context.rank,float(context.difficulty),faction,bool(options.ship_state.get("enhanced_weapon",rival)))
		if weapon.is_empty():return {}
		weapon.actor_id=id;weapon.hull_catalogue_id=hull;data.npc_weapons.append(weapon)
	data.target_memberships=target_memberships(data.actor_kinds,cast.player_last_ids)
	data.companion_player_last_ids=cast.player_last_ids.duplicate()
	data.companion_player_only_ids=cast.player_only_ids.duplicate()
	for id in cast.player_only_ids:data.target_memberships[id]=[int(data.player_target_id)]
	for id in int(cast.debris_count):data.target_memberships[id]=[]
	return data

## Shared unattached-actor membership, before live target selection. The
## caller resolves the original mission's player-last exceptions explicitly.
static func target_memberships(kinds: Array,player_last_ids: Array=[]) -> Array:
	var result:=[]
	for id in kinds.size():
		var targets:=[]
		for other in kinds.size():
			if other!=id and kinds[id]!=kinds[other]:targets.append(other)
		if id in player_last_ids:targets.append(-1)
		else:targets.push_front(-1)
		result.append(targets)
	return result

static func weapon_for(data: Dictionary,rank: int,difficulty: float,faction: int,rival: bool) -> Dictionary:
	if not parameters(data) or rank<0 or rank>20 or difficulty not in [0.5,1.0] or (rival and faction not in [0,1,2,3]) or (not rival and faction!=8):return {}
	return shared_weapon(data.weapons,int(data.campaign_cursor),rank,difficulty,faction,rival)

static func shared_weapon(rules: Dictionary,cursor: int,rank: int,difficulty: float,faction: int,enhanced:=false) -> Dictionary:
	if not Equal.equal_value(rules,VALUES.weapons) or cursor<0 or cursor>2147483647 or rank<0 or rank>20 or difficulty not in [0.5,1.0] or faction not in [0,1,2,3,8]:return {}
	for source in rules.factions:
		if int(source.actor_kind)!=faction:continue
		var row:=scaled_parameters(rules,cursor,rank,difficulty,enhanced)
		for key in ["actor_kind","item_id","kind","catalogue_kind","model_resource_id"]:row[key]=int(source[key])
		return row
	return {}

static func scaled_parameters(rules: Dictionary,cursor: int,rank: int,difficulty: float,enhanced:=false) -> Dictionary:
	# Shared factory arithmetic only. The encounter still supplies a verified
	# faction, ship and any authored damage override before creating a gun.
	# A cursor scales the authored firing interval; it does not grant flight.
	if not Equal.equal_value(rules,VALUES.weapons) or cursor<0 or cursor>2147483647 or rank<0 or rank>20 or difficulty not in [0.5,1.0]:return {}
	var level:=int(clampf(Vitals.single(float(rank+int(rules.rank_offset))*float(rules.rank_multiplier)),float(rules.rank_level_min),float(rules.rank_level_max)))
	level=mini(int(rules.scaled_level_max),int(Vitals.single(float(level)+Vitals.single(float(level)*Vitals.single(difficulty+float(rules.game_difficulty_offset))))))
	var damage:=int(rules.zero_level_damage) if level==0 else level+int(rules.damage_offset)
	if enhanced:damage+=rank
	return {"category":int(rules.category),"damage":damage,"projectile_capacity":int(rules.capacity),"lifetime_ms":int(rules.lifetime_ms),
		"interval_ms":int(rules.interval_base_ms)+cursor*int(rules.interval_cursor_multiplier),
		"speed_units_per_millisecond":float(rules.rival_speed if enhanced else rules.speed),"nonplayer_source":true}
