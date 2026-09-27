extends "res://tests/wanted_unlocked.gd"
## Detached component fixtures vary cast roles and scenery anchors. The
## application pilot separately earns and flies an actual generated offer.

func verify_contract_boundaries(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted) -> void:
	var original: Dictionary=station.snapshot()
	var anchors:=[]
	for index in 16:anchors.append(Vector3(index*6000,1000,index*-4000))
	var last_contract: RefCounted
	var enemy_kinds:={}
	for faction in 4:
		for quantity in range(2,6):
			var contracts: RefCounted=station.contract_owner().fork()
			contracts._state.mission.kind=2;contracts._state.mission.quantity=quantity
			contracts._state.mission.difficulty=[1,3,5,8][quantity-2]
			contracts._state.accepted_contact.offer.mission=contracts._state.mission.duplicate(true)
			last_contract=contracts
			var context: Dictionary=contracts.flight_context(int(original.loadout.station_id),bindings)
			for seed in 4:
				var admission=load("res://src/simulation/mission_context.gd").new()
				if not admission.admit_contract(bindings,cat,contracts,station.equipment_owner()):check(false,admission.error);return
				admission._recipe=load("res://src/content/mission_recipe.gd").from_contract(bindings,context,original.loadout,faction)
				var construction=load("res://src/simulation/opening_npc_construction.gd").new()
				if not construction.configure_contract(bindings,cat,station.equipment_owner(),contracts,Vector3.ZERO,Vector3.ZERO,admission):check(false,construction.error);return
				var random=load("res://src/simulation/seeded_random.gd").new();random.seed_from(seed)
				var packet: Dictionary=construction.generate(random.snapshot(),anchors)
				if packet.is_empty():check(false,construction.error);return
				var count:=int(admission.recipe().result.success.end_actor)
				check(packet.actors.size()==count+quantity,"Protection lost a ship from the accepted offer")
				var path: Array=packet.contract_encounter.path
				check(path.size()==2 and path[1]==Vector3.ZERO and path[0].y==0 and path[0].x>=-39999 and path[0].x<=-20000 and path[0].z>=-39999 and path[0].z<=-20000,"The attackers lost their incoming approach")
				var rules: Dictionary=load("res://src/content/contract_ship_combat_definitions.gd").population(bindings,packet,admission)
				if rules.is_empty():check(false,"Protection cast did not bind shared combat");return
				var bodies:=[]
				for id in packet.actors.size():
					var actor=load("res://src/simulation/opening_combat_actor.gd").new()
					if not actor.configure_contract(bindings,cat,construction,id):check(false,actor.error);return
					var body: Dictionary=actor.snapshot();bodies.append(body)
					var hostile: bool=id<count
					check(body.active and body.actor_mode==0 and body.hostile==hostile and body.friendly!=hostile,"Protection changed initial activation or permanent allegiance")
					if hostile:
						enemy_kinds[body.actor_kind]=true
						check(body.position==path[0]+Vector3(2000,2000,2000)*id,"An attacker lost its approach spacing")
						var route: Dictionary=construction.route(id).snapshot()
						check(route.waypoints==path and route.index==1 and not route.loop,"An attacker wandered instead of approaching the encounter")
						check(rules.target_memberships[id].back()==-1 and rules.target_memberships[id].slice(0,-1)==range(count,packet.actors.size()),"The attacker did not prioritize the protected ships")
					else:
						check(body.actor_kind==faction and body.position==anchors[8+id-count]+Vector3(0,2000,0),"A protected ship lost its local faction or asteroid-relative position")
						check(body.max_hull==bodies[0].max_hull*3 and body.vitals.hull==body.max_hull and packet.actors[id].cargo.is_empty(),"A protected ship lost reinforced hull or acquired salvage cargo")
						check(rules.target_memberships[id]==[-1],"The stationary miner became a defending patrol")
						var guidance=load("res://src/simulation/opening_npc_guidance.gd").new()
						if not guidance.configure_contract(bindings,cat,construction,id):check(false,guidance.error);return
						check(guidance.snapshot().speed==0.0 and not guidance._boost_enabled,"A miner can leave its asteroid")
				var runner=load("res://src/simulation/mission_runner.gd").new()
				if not runner.configure(admission):check(false,runner.error);return
				for id in range(count,bodies.size()-1):bodies[id].actor_mode=4;bodies[id].vitals.hull=0
				check(not runner.observe(bodies).failed,"Losing only some protected ships failed the job")
				bodies.back().vitals.hull=0;bodies.back().actor_mode=3
				check(not runner.observe(bodies).failed,"A protected ship's unfinished explosion failed the job")
				bodies.back().actor_mode=4
				check(runner.sample_clock(5001,5001) and runner.poll(bodies,true,true).mode==2,"Losing all protected ships did not fail during radio")
	check(enemy_kinds.size()==5,"The fixtures missed one of the opposing attacker factions")
	if failures==0:verify_protection_results(bindings,cat,library,station,last_contract)
	check(station.snapshot()==original,"Protection fixtures changed the earned station")

func verify_protection_results(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted,contracts: RefCounted) -> void:
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var construction:=Construction.new()
	if not construction._prepare_free_owned(bindings,cat,station.equipment_owner(),contracts,station.snapshot().mission,{},4096,1789101200,false,bodies,effects):check(false,construction.error);return
	var frame=load("res://src/simulation/first_flight_frame.gd").new()
	if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
	var original: Dictionary=frame.snapshot()
	var split:=int(frame.mission_context_owner().recipe().result.success.end_actor)
	for won in [true,false]:
		var branch: RefCounted=frame.fork_for_frame()
		var combat: RefCounted=branch._encounter._combat.fork_for_frame();branch._encounter._combat=combat
		if not combat.begin_contact_pass(original.random_state,true):check(false,combat.error);return
		var selected: Array=range(split) if won else range(split,original.encounter.combat.actors.size())
		for id in selected:
			if combat.normal_hit(id,original.encounter.combat.actors[id].vitals.hull,false).is_empty():check(false,combat.error);return
		for tick in 160:
			var next: RefCounted=branch.evaluate(100)
			if next==null:check(false,branch.error);return
			branch=next
			if branch.contract_result_pending():break
		var pending: Dictionary=branch.snapshot()
		check(branch.contract_result_pending() and pending.contracts.pending_result.get("completed")==won,"Protection's retired cast did not produce its expected result")
		if failures:return
		if won:
			for id in range(split,original.encounter.combat.actors.size()):check(pending.encounter.combat.actors[id].position==original.encounter.combat.actors[id].position,"A living miner moved from its asteroid during battle")
		var serial:=int(pending.contracts.pending_result.serial)
		var paid: RefCounted=branch.acknowledge_contract_result(serial)
		if paid==null:check(false,branch.error);return
		var job: Dictionary=original.contracts.mission
		check(paid.snapshot().contracts.credits==original.contracts.credits+(int(job.reward)+int(job.bonus) if won else 0) and paid.snapshot().campaign_cursor==original.campaign_cursor,"Protection settlement changed the campaign or reward")
		check(paid.acknowledge_contract_result(serial)==null,"Protection paid twice")
	check(frame.snapshot()==original,"Protection outcome fixtures corrupted their parent frame")
