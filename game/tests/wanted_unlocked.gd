extends "res://tests/freelance_unlocked.gd"
## Component branches from the genuinely accepted bounty; combat damage and
## relocation here are explicit fixtures, separate from the application pilot.

func requested_contract_kind() -> int:return 6

func verify_contract_frame(bindings: RefCounted,frame: RefCounted,accepted: Dictionary) -> void:
	var original: Dictionary=frame.snapshot()
	var actors: Array=original.encounter.combat.actors
	check(actors.size()==1 and actors[0].actor_kind==8,"The bounty did not construct one pirate")
	if failures:return
	var target: Dictionary=actors[0]
	check(target.actor_mode==5 and not target.active and target.vitals.hull==target.max_hull,"The distant bounty activated early or started damaged")
	var path: Array=original.encounter.combat.contract_encounter.path
	check(path.size()==1 and path[0].y==0 and absf(path[0].x)>=60000 and absf(path[0].x)<140000 and absf(path[0].z)>=60000 and absf(path[0].z)<140000,"The bounty did not start around its distant single point")
	if failures:return
	var scatter: Vector3=(target.pose.origin-path[0]).abs()
	check(scatter.x<=20000 and scatter.y<=20000 and scatter.z<=20000,"The bounty escaped its ordinary spawn scatter")
	var guidance: RefCounted=frame._encounter._control._guidance[0].fork_for_frame()
	var body: Dictionary=target.duplicate(true)
	body.active=true;body.actor_mode=0;body.targeting_blocked=false
	body.vitals.hull=int(body.vitals.hull/2)
	var player:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"pose":Transform3D(Basis.IDENTITY,body.pose.origin+Vector3(0,0,20000)),
		"ship_id":0,"active":true,"hull":95,"special_flight":false,"targeting_blocked":false,"alternate_position":null}
	var random: Dictionary=original.random_state.duplicate(true)
	for tick in 105:
		var decision: Dictionary=guidance.update(100,body,body.pose,player,random,[body])
		if decision.is_empty():check(false,guidance.error);return
		random=decision.random_state
	var motion: Dictionary=guidance.snapshot()
	check(motion.speed==3.0 and not motion.boost_active and not motion.damage_boost and motion.boost_elapsed_ms>10000,"The damaged bounty changed speed or enabled its disabled boost")
	var runner: RefCounted=frame._encounter._control._mission_runner.fork()
	var observed: Array=actors.duplicate(true)
	observed[0].vitals.hull=0
	for mode in [0,1,3]:
		observed[0].actor_mode=mode
		check(not runner.observe(observed).satisfied,"Zero hull or an unfinished explosion completed the bounty")
	observed[0].actor_mode=4
	check(runner.sample_clock(5001,5001),runner.error)
	check(runner.poll(observed,true,true).mode==0,"Bounty success interrupted radio")
	check(runner.sample_clock(10002,5001),runner.error)
	check(runner.poll(observed,false,true).mode==1,"A retired target did not release bounty success")
	check(runner.acknowledge() and not runner.acknowledge(),"Bounty retirement acknowledged twice")
	check(frame.snapshot()==original,"The bounty component branches corrupted their parent")
	if failures==0:super.verify_contract_frame(bindings,frame,accepted)

func verify_contract_boundaries(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted) -> void:
	var original: Dictionary=station.snapshot()
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	for difficulty in [0.5,1.0]:
		var hulls:=[];var shots:=[]
		for kind in [4,6]:
			var contracts: RefCounted=station.contract_owner().fork()
			contracts._state.mission.kind=kind;contracts._state.difficulty=difficulty
			contracts._state.accepted_contact.offer.mission=contracts._state.mission.duplicate(true)
			var construction:=Construction.new()
			if not construction._prepare_free_owned(bindings,cat,station.equipment_owner(),contracts,original.mission,{},4096,1789100020,false,bodies,effects):check(false,construction.error);return
			var frame=load("res://src/simulation/first_flight_frame.gd").new()
			if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
			var actor: Dictionary=frame.snapshot().encounter.combat.actors[0]
			hulls.append([actor.max_hull,actor.vitals.hull])
			var before: Dictionary=frame.snapshot()
			var gun: RefCounted=frame._encounter._weapons._guns[0].fork_state()
			if gun.advance(1).is_empty() or not gun.fire(Vector3.ZERO,Vector3.BACK,true).fired or gun.advance(100).is_empty():check(false,gun.error);return
			var fired: Dictionary=gun.snapshot()
			var projectile: Dictionary=fired.slots.filter(func(slot):return slot!=null)[0]
			shots.append({"position":projectile.position,"damage":fired.weapon.damage})
			check(frame.snapshot()==before,"The projectile probe changed its retained flight")
		check(hulls[1][0]==3*hulls[0][0] and hulls[1][1]==3*hulls[0][1],"The bounty did not triple both current and maximum ordinary hull")
		check(shots[1].position.z>shots[0].position.z and shots[1].damage==shots[0].damage+int(original.contracts.rank),"The bounty lost its faster projectile and rank-added weapon damage")
	check(station.snapshot()==original,"Hull boundary fixtures changed the earned station")
