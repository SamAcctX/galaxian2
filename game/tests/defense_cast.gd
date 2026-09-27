extends "res://tests/wanted_unlocked.gd"
## Explicit component casts fork a genuinely accepted bounty. The application
## test separately earns and flies a generated Defense offer; these fixtures
## vary factions and construction RNG without rewriting any saved career.

func verify_contract_boundaries(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted) -> void:
	var original: Dictionary=station.snapshot()
	var contracts: RefCounted=station.contract_owner().fork()
	contracts._state.mission.kind=1
	contracts._state.accepted_contact.offer.mission=contracts._state.mission.duplicate(true)
	var equipment: RefCounted=station.equipment_owner()
	var context: Dictionary=contracts.flight_context(int(original.loadout.station_id),bindings)
	var seen_counts:={};var seen_enemies:={}
	for faction in 4:
		for seed in 12:
			var admission=load("res://src/simulation/mission_context.gd").new()
			if not admission.admit_contract(bindings,cat,contracts,equipment):check(false,admission.error);return
			# The fixture substitutes the faction in a fresh recipe, not a world
			# location or save. Real entry resolves it from the station catalogue.
			admission._recipe=load("res://src/content/mission_recipe.gd").from_contract(bindings,context,original.loadout,faction)
			var before: Dictionary=admission.recipe()
			var construction=load("res://src/simulation/opening_npc_construction.gd").new()
			if not construction.configure_contract(bindings,cat,equipment,contracts,Vector3.ZERO,Vector3.ZERO,admission):check(false,construction.error);return
			var random=load("res://src/simulation/seeded_random.gd").new();random.seed_from(seed)
			var population: Dictionary=construction.generate(random.snapshot())
			if population.is_empty():check(false,construction.error);return
			var resolved: RefCounted=construction.mission_context_owner()
			var actors: Array=population.actors
			var attackers:=int(resolved.recipe().result.success.end_actor)
			var defenders:=actors.size()-attackers
			seen_counts[defenders]=true;seen_enemies[int(population.contract_encounter.unused_enemy_faction)]=true
			check(defenders>=3 and defenders<=7 and resolved.recipe().result.actor_count==actors.size() and admission.recipe()==before,"Variable cast size escaped its recipe or changed the admitted parent")
			var route: Array=population.contract_encounter.path
			check(route.size()==3 and route[0].z==50000 and route[1].z==75000 and route[2].z==100000 and route.all(func(point):return point.y==0 and point.x>=-50000 and point.x<50000),"Defenders lost their spaced launch points")
			var bodies:=[]
			for id in actors.size():
				var actor=load("res://src/simulation/opening_combat_actor.gd").new()
				if not actor.configure_contract(bindings,cat,construction,id):check(false,actor.error);return
				var state: Dictionary=actor.snapshot();bodies.append(state)
				var hostile: bool=id<attackers
				check(state.active and state.actor_mode==0 and state.hostile==hostile and state.friendly!=hostile and state.vitals.hull==state.max_hull,"Defense ships lost ordinary activation, hull or allegiance")
				check(state.actor_kind==(int(population.contract_encounter.unused_enemy_faction) if hostile else faction),"A ship used the client's faction instead of its cast role")
				var centers: Array=[Vector3.ZERO] if hostile else route
				check(centers.any(func(point):return inside_scatter(actors[id].factory_position,point)),"A defense ship escaped its ordinary spawn scatter")
				if not actor.enable_contract_combat(bindings) or not actor.refresh_contract_hostility(true):check(false,actor.error);return
				check(actor.snapshot().hostile==hostile,"Provocation overturned permanent defense allegiance")
			var runner=load("res://src/simulation/mission_runner.gd").new()
			if not runner.configure(resolved):check(false,runner.error);return
			for id in range(attackers,bodies.size()):bodies[id].actor_mode=4;bodies[id].vitals.hull=0
			check(not runner.observe(bodies).satisfied and not runner.observe(bodies).failed,"Defender losses ended the attacker's objective")
			for id in attackers:bodies[id].actor_mode=3;bodies[id].vitals.hull=0
			check(not runner.observe(bodies).satisfied,"Unfinished attacker explosions completed defense")
			for id in attackers:bodies[id].actor_mode=4
			check(runner.sample_clock(5001,5001) and runner.poll(bodies,true,true).mode==0,"Defense success interrupted radio")
			check(runner.sample_clock(10002,5001) and runner.poll(bodies,false,true).mode==1,"Retired attackers did not complete defense")
	check(seen_counts.size()==5 and seen_enemies.size()==5,"The fixture did not exercise every patrol size and all attacker factions")
	if failures==0:verify_defense_result(bindings,cat,library,station,contracts)
	check(station.snapshot()==original,"Defense fixture changed the earned station")

static func inside_scatter(position: Vector3,center: Vector3) -> bool:
	var distance: Vector3=(position-center).abs()
	return distance.x<=20000 and distance.y<=20000 and distance.z<=20000

func verify_defense_result(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted,contracts: RefCounted) -> void:
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var construction:=Construction.new()
	if not construction._prepare_free_owned(bindings,cat,station.equipment_owner(),contracts,station.snapshot().mission,{},4096,1789100020,false,bodies,effects):check(false,construction.error);return
	var frame=load("res://src/simulation/first_flight_frame.gd").new()
	if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
	var original: Dictionary=frame.snapshot()
	var count:=int(frame.mission_context_owner().recipe().result.success.end_actor)
	check(original.encounter.combat.actors.size()>count and count>0,"Defense flight lost its friendly and hostile cast")
	var branch: RefCounted=frame.fork_for_frame()
	# Direct fixture damage must detach the combat owner just as the normal
	# input/contact transaction does before applying any hits.
	var combat: RefCounted=branch._encounter._combat.fork_for_frame()
	branch._encounter._combat=combat
	if not combat.begin_contact_pass(original.random_state,true):check(false,combat.error);return
	for id in count:
		var hit: Dictionary=combat.normal_hit(id,original.encounter.combat.actors[id].vitals.hull,false)
		if hit.is_empty() or not hit.destroyed_now:check(false,combat.error);return
	for tick in 160:
		var next: RefCounted=branch.evaluate(100)
		if next==null:check(false,branch.error);return
		branch=next
		if branch.contract_result_pending():break
	var pending: Dictionary=branch.snapshot()
	check(branch.contract_result_pending() and pending.encounter.combat.actors.slice(count).all(func(actor):return actor.vitals.hull>0),"Surviving defenders prevented payment or were destroyed by their own result")
	check(frame.snapshot()==original,"Defense retirement changed its parent")
	check(pending.contracts.credits==original.contracts.credits,"Defense paid before acknowledgement")
	if failures:return
	var serial:=int(pending.contracts.pending_result.serial)
	var paid: RefCounted=branch.acknowledge_contract_result(serial)
	if paid==null:check(false,branch.error);return
	var job: Dictionary=original.contracts.mission
	check(paid.snapshot().contracts.credits==original.contracts.credits+job.reward+job.bonus and paid.snapshot().campaign_cursor==original.campaign_cursor,"Defense payment changed its terms or campaign")
	check(paid.acknowledge_contract_result(serial)==null,"Defense payment was duplicated")
