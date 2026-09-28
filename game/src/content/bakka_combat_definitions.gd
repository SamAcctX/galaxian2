extends RefCounted
## Native combat parameters for the authored B'akka contest. This reuses the
## ordinary ship factories without reclassifying the story flight as a contract.
const Bakka=preload("res://src/content/bakka_contest_definitions.gd")
const Shared=preload("res://src/content/contract_ship_combat_definitions.gd")
const ContractLife=preload("res://src/content/contract_ship_lifecycle_definitions.gd")
const TrainingDeath=preload("res://src/content/combat_training_destruction_definitions.gd")
const ControlRules=preload("res://src/content/combat_training_control_definitions.gd")

static func population(bindings: RefCounted,packet: Dictionary) -> Dictionary:
	if bindings==null or not Bakka.available(bindings) or not Shared.parameters(bindings.early_contracts.get("ship_combat")) or not ContractLife.parameters(bindings.early_contracts.get("ship_lifecycle")) or not TrainingDeath.parameters(bindings.combat_training_destruction) or not ControlRules.parameters(bindings.combat_training_control):return {}
	var encounter: Variant=packet.get("bakka_encounter")
	var actors: Variant=packet.get("actors")
	if not encounter is Dictionary or not actors is Array or actors.size()!=8:return {}
	var context: Variant=encounter.get("context")
	if not context is Dictionary or not Bakka.context_valid(bindings,context):return {}
	for key in ["base_content_id","binding_id"]:
		if packet.get(key)!=bindings.get(key) or context.get(key)!=bindings.get(key):return {}
	if packet.get("campaign_cursor")!=36 or packet.get("station_id")!=27 or packet.get("system_id")!=5:return {}
	if encounter.get("kind")!=12 or not encounter.get("mission") is Dictionary or encounter.mission.get("kind")!=12 or encounter.mission.get("story")!=true:return {}
	if encounter.get("actor_count")!=8:return {}
	var rules: Dictionary=bindings.early_contracts.ship_combat
	var data:=rules.duplicate(true)
	data.bakka=true
	data.campaign_cursor=36;data.station_id=27;data.system_id=5
	data.rank=int(context.rank);data.difficulty=float(context.difficulty);data.mission_kind=12;data.actor_count=8
	# The authored contest still uses ordinary ship hit/faction routines. Their
	# primary faction comes from this world, not the shared Mido contract defaults.
	var world: Dictionary=load("res://src/content/ordinary_world_definitions.gd").location(bindings,int(data.station_id))
	if not load("res://src/content/free_lifecycle_definitions.gd").available(bindings) or world.get("system_id")!=data.system_id:return {}
	data.lifecycle=bindings.early_contracts.ship_lifecycle.duplicate(true)
	data.lifecycle.reactions=bindings.mido_travel.free_lifecycle.reactions.duplicate(true)
	data.lifecycle.reactions.primary_faction=int(world.faction)
	data.lifecycle.reactions.eligible_factions=[int(world.faction),int(bindings.mido_travel.free_population.enemy_factions[int(world.faction)])]
	data.player_ship_id=int(bindings.combat_training_weapons.player_entry.ship_id)
	data.cargo=bindings.combat_training_destruction.cargo.duplicate(true)
	data.nonhostile_remaining_delta=int(bindings.combat_training_destruction.nonhostile_remaining_delta)
	data.actor_kinds=[];data.hull_catalogue_ids=[];data.target_memberships=[];data.player_weapon_targets=[];data.npc_weapons=[];data.actors=[]
	for key in ["rank_base","rank_multiplier","cursor_multiplier","difficulty_offset","percentage_scale","engagement_half_extent","proximity_half_extent","target_activation_half_extent","initial_model_draw_enabled","initial_node_draw_requested","initial_engine_draw_enabled","npc_statistics_targeting_blocked","random_selection_chance","random_selection_attempts","nonplayer_selection_checks_range","completed_route_retains_position_once"]:
		data[key]=bindings.combat_training_control[key]
	for id in actors.size():
		var actor: Variant=actors[id]
		var rival: bool=id==0
		if not actor is Dictionary or actor.get("actor_id")!=id or actor.get("subtype")!=0:return {}
		if rival:
			if actor.get("population_group")!="rival" or actor.get("actor_kind")!=1 or actor.get("hull_catalogue_id")!=9 or actor.get("friendly")!=true or actor.get("current_hull_override")!=9999999:return {}
			if actor.get("name_text_id")!=int(bindings.mido_travel.bakka_contest.population.rival_name_text_id):return {}
			data.rival=data.rival.duplicate(true)
			data.rival.initial_mode=int(actor.get("mode",0));data.rival.initial_active=bool(actor.get("active",true));data.rival.initial_targeting_blocked=bool(actor.get("targeting_blocked",false))
			data.rival.motion_speed=float(actor.get("speed",3.0))
		else:
			if actor.get("population_group")!="pirate" or actor.get("actor_kind")!=8 or actor.get("mode")!=5 or actor.get("active")!=false or actor.get("targeting_blocked")!=true:return {}
		var faction:=int(actor.actor_kind);var hull:=int(actor.hull_catalogue_id)
		data.actor_kinds.append(faction);data.hull_catalogue_ids.append(hull);data.player_weapon_targets.append(id)
		var row:={"actor_id":id,"actor_kind":faction,"hull_catalogue_id":hull,"subtype":int(actor.subtype),"population_group":String(actor.population_group),"hostile":not rival}
		for model in bindings.early_contracts.ship_lifecycle.cargo_models:
			if int(model.actor_kind)==faction:row.cargo_model_id=int(model.cargo_model_id);row.cargo_model_resource=model.cargo_model_resource
		if not row.has("cargo_model_id"):return {}
		data.actors.append(row)
		var weapon:=Shared.shared_weapon(rules.weapons,36,data.rank,data.difficulty,faction,rival)
		if weapon.is_empty():return {}
		weapon.actor_id=id;weapon.hull_catalogue_id=hull;data.npc_weapons.append(weapon)
	for id in actors.size():
		if id==0:
			var targets:=[-1]
			for other in range(1,actors.size()):targets.append(other)
			data.target_memberships.append(targets)
		else:data.target_memberships.append([0,-1] if id%2==1 else [-1,0])
	return data

static func combat_population(bindings: RefCounted,combat: Dictionary) -> bool:
	if bindings==null or combat.get("campaign_cursor")!=36:return false
	var encounter: Variant=combat.get("bakka_encounter");var actors: Variant=combat.get("actors")
	if not encounter is Dictionary or not actors is Array or actors.size()!=8 or encounter.get("kind")!=12 or encounter.get("actor_count")!=8:return false
	var context: Variant=encounter.get("context")
	if not context is Dictionary or not Bakka.context_valid(bindings,context):return false
	for key in ["base_content_id","binding_id"]:
		if combat.get(key)!=bindings.get(key):return false
	for id in actors.size():
		var actor: Variant=actors[id]
		if not actor is Dictionary or actor.get("actor_id")!=id:return false
		if id==0:
			if actor.get("population_group")!="rival" or actor.get("actor_kind")!=1 or actor.get("hull_catalogue_id")!=9:return false
		elif actor.get("population_group")!="pirate" or actor.get("actor_kind")!=8:return false
	return true

static func npc_hit(data: Dictionary,weapon: Dictionary) -> bool:
	if not data.get("bakka",false) or data.get("campaign_cursor")!=36 or not data.get("npc_weapons") is Array:return false
	for row in data.npc_weapons:
		var matches:=true
		for key in ["item_id","category","kind","damage","nonplayer_source"]:
			if weapon.get(key)!=row.get(key):matches=false;break
		if matches:return true
	return false
