extends "res://tests/freelance_unlocked.gd"
## Deliberate contact fixtures cover mixed-role accounting and result precedence;
## the separate application pilot earns clearance without moving or damaging actors.

func requested_contract_kind() -> int:return 7

func verify_contract_frame(_bindings: RefCounted,frame: RefCounted,accepted: Dictionary) -> void:
	var world: Dictionary=frame.snapshot()
	var debris: Array=world.encounter.combat.actors.filter(func(actor):return actor.population_group=="debris").map(func(actor):return actor.actor_id)
	var pirates: Array=world.encounter.combat.actors.filter(func(actor):return actor.population_group=="pirate").map(func(actor):return actor.actor_id)
	check(not debris.is_empty() and pirates.size()==1,"The mixed Junk fixture requires one pirate and a debris field")
	check(pirates.all(func(id):return world.encounter.combat.actors[id].active and world.encounter.combat.actors[id].actor_mode==0),"The Junk pirate borrowed deferred Pirate-job activation")
	if failures:return
	var cleared: RefCounted=frame.fork_for_frame()
	cleared._encounter._combat=cleared._encounter._combat.fork_for_frame()
	var combat: RefCounted=cleared._encounter._combat
	if not combat.begin_contact_pass(world.random_state,true):check(false,combat.error);return
	for id in debris:
		if combat.normal_hit(id,1,id%2==0).is_empty():check(false,combat.error);return
	check(combat.current_reputation()==world.contracts.reputation,"Debris hits changed faction standing")
	for tick in 160:
		var next: RefCounted=cleared.evaluate(100)
		if next==null:check(false,cleared.error);return
		cleared=next
		if cleared.contract_result_pending():break
	var pending: Dictionary=cleared.snapshot()
	check(cleared.contract_result_pending() and pending.contracts.pending_result.completed,"Debris clearance waited for the live pirate")
	check(pending.encounter.combat.actors[pirates[0]].vitals.hull>0,"The clearance fixture killed its pirate")
	check(pending.progress.debris_destroyed==world.progress.debris_destroyed+debris.size() and pending.progress.player_kills==world.progress.player_kills and pending.progress.pirate_kills==world.progress.pirate_kills,"Debris was counted as ship kills")
	check(frame.snapshot()==world,"Clearing debris corrupted the parent frame")
	if failures:return
	var paid: RefCounted=cleared.acknowledge_contract_result(pending.contracts.pending_result.serial)
	if paid==null:check(false,cleared.error);return
	check(paid.snapshot().contracts.credits==world.contracts.credits+accepted.contracts.mission.reward+accepted.contracts.mission.bonus and paid.snapshot().campaign_cursor==world.campaign_cursor,"Junk payment lost money or advanced the story")
	check(paid.acknowledge_contract_result(pending.contracts.pending_result.serial)==null,"Repeated Junk acknowledgement paid twice")
	# Kill the remaining ship after settlement. Reputation must start from the
	# settled bonus, while debris statistics and the result stay unchanged.
	var paid_world: Dictionary=paid.snapshot()
	var after: RefCounted=paid.fork_for_frame()
	after._encounter._combat=after._encounter._combat.fork_for_frame()
	combat=after._encounter._combat
	if not combat.begin_contact_pass(paid_world.random_state,true):check(false,combat.error);return
	var pirate: Dictionary=combat.actor_snapshot(pirates[0])
	if combat.normal_hit(pirates[0],pirate.vitals.hull).is_empty():check(false,combat.error);return
	for tick in 120:
		var next: RefCounted=after.evaluate(100)
		if next==null:check(false,after.error);return
		after=next
		if after.snapshot().encounter.combat.actors[pirates[0]].actor_mode==4:break
	var retired: Dictionary=after.snapshot()
	check(retired.progress.player_kills==paid_world.progress.player_kills+1 and retired.progress.pirate_kills==paid_world.progress.pirate_kills+1 and retired.progress.debris_destroyed==paid_world.progress.debris_destroyed,"The pirate inherited debris accounting")
	check(retired.contracts.credits==paid_world.contracts.credits and retired.contracts.pending_result.is_empty() and retired.contracts.mission.is_empty(),"Killing the remaining pirate repeated the settled job")
	check(retired.contracts.reputation!=paid_world.contracts.reputation,"The pirate lost its ordinary lethal-hit reputation")
	check(paid.snapshot()==paid_world and frame.snapshot()==world,"The mixed ship death mutated a parent frame")
