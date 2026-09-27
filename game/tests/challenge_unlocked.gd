extends "res://tests/freelance_unlocked.gd"
## Explicit contact fixtures isolate contest attribution and settlement.
## The application pilot separately verifies both outcomes through flight input.

func requested_contract_kind() -> int:return 12

func verify_contract_frame(_bindings: RefCounted,frame: RefCounted,accepted: Dictionary) -> void:
	var original: Dictionary=frame.snapshot()
	var actors: Array=original.encounter.combat.actors
	check(original.mission_readout=={"kind":"contest","player":0,"other":0},"The contest inherited lifetime career scores")
	check(actors.size() in [4,6,8] and actors[0].population_group=="rival" and actors.slice(1).all(func(actor):return actor.population_group=="pirate"),"The Challenge cast lost its rival or pirate range")
	check(actors[0].name==accepted.contracts.accepted_contact.name and actors[0].vitals.hull==9999999,"The rival lost its accepted identity or protection")
	if failures:return
	for player_wins in [true,false]:
		var branch: RefCounted=frame.fork_for_frame()
		for actor in actors.slice(1):
			branch._pose.origin=actor.pose.origin+Vector3(0,0,20000)
			for tick in 2:
				var next: RefCounted=branch.evaluate(0)
				if next==null:check(false,branch.error);return
				branch=next
		branch._encounter._combat=branch._encounter._combat.fork_for_frame()
		var combat: RefCounted=branch._encounter._combat
		if not combat.begin_contact_pass(branch.snapshot().random_state,true):check(false,combat.error);return
		for actor in combat.snapshot().actors.slice(1):
			var hit: Dictionary=combat.normal_hit(actor.actor_id,actor.vitals.hull,not player_wins)
			if hit.is_empty() or not hit.destroyed_now:check(false,combat.error);return
		check(not branch.contract_result_pending(),"Lethal hits settled a contest before destruction")
		for tick in 180:
			var next: RefCounted=branch.evaluate(100)
			if next==null:check(false,branch.error);return
			branch=next
			if branch.contract_result_pending():break
		var pending: Dictionary=branch.snapshot()
		check(pending.mission_readout=={"kind":"contest","player":actors.size()-1 if player_wins else 0,"other":0 if player_wins else actors.size()-1},"The contest readout lost the actual kill attribution")
		check(branch.contract_result_pending() and pending.contracts.pending_result.completed==player_wins,"The contest selected the wrong winner")
		check(pending.encounter.combat.actors.slice(1).all(func(actor):return actor.actor_mode==4) and pending.encounter.combat.actors[0].vitals.hull>0,"The contest included its living rival in the destruction objective")
		check(pending.contracts.credits==original.contracts.credits,"The contest changed money before acknowledgement")
		check(frame.snapshot()==original,"A contest fixture corrupted its parent frame")
		if failures:return
		var paid: RefCounted=branch.acknowledge_contract_result(pending.contracts.pending_result.serial)
		if paid==null:check(false,branch.error);return
		var settled: Dictionary=paid.snapshot()
		var delta: int=accepted.contracts.mission.reward+accepted.contracts.mission.bonus if player_wins else -accepted.contracts.mission.reward
		check(settled.contracts.credits==maxi(0,original.contracts.credits+delta) and settled.contracts.completed_side_missions==original.contracts.completed_side_missions+int(player_wins),"The contest paid the wrong reward, penalty or success count")
		check(settled.campaign_cursor==original.campaign_cursor and settled.mission==original.mission and settled.contracts.mission.is_empty(),"Contest acknowledgement changed the independent campaign or retained the job")
		check(settled.mission_readout.is_empty(),"Settling the contest retained its score instead of cargo")
		check(paid.acknowledge_contract_result(pending.contracts.pending_result.serial)==null and paid.snapshot()==settled,"Repeated contest acknowledgement changed the career")

func verify_contract_boundaries(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted) -> void:
	# Explicit component fixtures cover newly admitted cast sizes and rival
	# factions. They neither edit the earned save nor claim played acceptance.
	var original: Dictionary=station.snapshot()
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	for row in [[3,0,1.0,6],[8,1,0.5,8],[9,2,1.0,8],[7,3,0.5,6]]:
		var contracts: RefCounted=station.contract_owner().fork()
		var equipment: RefCounted=station.equipment_owner().fork()
		contracts._state.mission.difficulty=row[0]
		contracts._state.accepted_contact.offer.mission=contracts._state.mission.duplicate(true)
		contracts._state.accepted_contact.offer.context.client_faction=row[1]
		contracts._state.difficulty=row[2]
		var construction:=Construction.new()
		if not construction._prepare_free_owned(bindings,cat,equipment,contracts,original.mission,{},4096,1789100010,false,bodies,effects):check(false,construction.error);return
		var frame=load("res://src/simulation/first_flight_frame.gd").new()
		if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
		check(frame.snapshot().encounter.combat.actors.size()==row[3],"A newly admitted difficulty selected the wrong contest cast")
		verify_contract_frame(bindings,frame,{"contracts":contracts.snapshot()})
		if failures:return
	check(station.snapshot()==original,"The cast boundary fixtures altered the earned station")
