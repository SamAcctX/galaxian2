extends RefCounted
## Native generation from actual40 navigation plus the explicitly detached
## late-portal fixture. Target/muzzle overlap below is a DISCLOSED contact
## stimulus, not an input-earned story41 battle, result or successor save.
const NPC=preload("res://src/simulation/selected41_npc_combat.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const World=preload("res://src/simulation/selected41_world_initialization.gd")

static func run(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,visuals: RefCounted,world: RefCounted,other: RefCounted) -> void:
	var original: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner()
	var career: Dictionary=entry.career_owner().snapshot();var gear: Dictionary=entry.equipment_owner().snapshot()
	for invalid in [null,RefCounted.new(),World.new()]:
		var rejected:=NPC.new()
		host.check(not rejected.prepare(bindings,cat,library,invalid) and rejected.snapshot().is_empty(),"Uninitialized source41 world admitted NPC combat")
	var owner:=NPC.new()
	if not owner.prepare(bindings,cat,library,world):host.check(false,owner.error);return
	var initial: Dictionary=owner.snapshot();var builder: RefCounted=world.construction_owner()
	host.check(initial.combat.actors==original.components.actors and initial.player==original.components.player,"Live41 rebuilt or changed accepted native bodies/player")
	host.check(owner.player_owner().selected41_construction_owner()==builder.npc_construction_owner() and owner.combat_owner().selected41_world_owner()==world,"Live41 lost its native generation identity")
	host.check(initial.random_state==original.random_state and initial.weapons.selected41.weapon_effects==world.scenery_owner().world_initialization_owner().snapshot().weapon_effects,"Live41 redrew initialized weapon effects or reset RNG")
	host.check(initial.weapons.actors[0].projectiles.is_empty() and initial.weapons.target_memberships==[[-1,1,2,3,4,5,6,7],[-1,0],[-1,0],[-1,0],[-1,0],[-1,0],[-1,0],[-1,0]],"Source41 changed its unarmed freighter or player-first target lists")
	host.check(not owner.prepare(bindings,cat,library,world) and owner.snapshot()==initial,"Repeated source41 preparation replaced its retained owners")
	var pose: Transform3D=original.player_pose
	for duration in [-1,0.5,2147483648]:host.check(owner.evaluate(duration,pose)==null and owner.snapshot()==initial,"Invalid source41 duration mutated a retained parent")
	host.check(owner.evaluate(1,Transform3D(Basis.IDENTITY,Vector3(NAN,0,0)))==null and owner.snapshot()==initial,"Nonfinite source41 pose entered the actor pass")
	var weapons: RefCounted=owner.weapons_owner();var combat: RefCounted=owner.combat_owner();var player: RefCounted=owner.player_owner()
	host.check(weapons.fire_combat_training(combat,[]).is_empty() and weapons.evaluate_combat_training_update(player,pose,combat,false,1).is_empty(),"Generic combat path bypassed source41 native ownership")
	var foreign:=NPC.new()
	if not foreign.prepare(bindings,cat,library,other):host.check(false,foreign.error);return
	host.check(weapons.fire_selected41(foreign.combat_owner(),player,[]).is_empty() and weapons.evaluate_selected41_update(foreign.player_owner(),pose,combat,1).is_empty(),"Equal-context foreign generation entered source41 contacts")
	var observation: Dictionary=owner.snapshot();observation.combat.actors[0].vitals.hull=9999
	host.check(owner.snapshot()==initial,"Source41 observations alias the actual combat bodies")
	var active: RefCounted=owner.evaluate(1,pose)
	if active==null:host.check(false,owner.error);return
	var first: Dictionary=active.snapshot()
	host.check(first.combat.actors[0].body_pose.origin==initial.combat.actors[0].body_pose.origin+Vector3(0,0,1),"Vossk cruise did not use its native one-unit-per-ms movement")
	host.check(first.combat.actors[0].friendly and not first.combat.actors[0].hostile and first.combat.actors.slice(1).all(func(row):return row.hostile),"Native41 pass lost freighter friendship or Void hostility")
	var repeated: RefCounted=owner.evaluate(1,pose)
	host.check(repeated!=null and repeated.snapshot()==first and owner.snapshot()==initial,"Source41 frame replay consumed a parent or changed native RNG")
	# A real gun uses its temporary native muzzle pose. Restore that pose before
	# the late movement pass, retaining the existing controller's physical body.
	var target: Dictionary=active.combat_owner().collision_context(0)
	var point: Vector3=target.center+target.boxes[0].offset
	var fired: RefCounted=active.fork_for_frame();var old: Dictionary=fired._combat.actor_snapshot(1)
	var muzzle:=Transform3D(Basis.IDENTITY,point)
	var wrong_request:=[{"actor_id":1,"target_actor_id":0,"pose":muzzle}]
	host.check(fired._weapons.fire_selected41(fired._combat,fired._player,wrong_request).is_empty(),"Source41 accepted a muzzle unrelated to the live native body")
	if not fired._combat.set_pose(1,muzzle,muzzle):host.check(false,fired._combat.error);return
	var shot: Dictionary=fired._weapons.fire_selected41(fired._combat,fired._player,wrong_request)
	if shot.is_empty() or not shot.actors[0].outcome.fired:host.check(false,"Native41 Void gun failed to allocate a real shot: "+fired._weapons.error);return
	if not fired._combat.set_pose(1,old.pose,old.body_pose):host.check(false,fired._combat.error);return
	var before: Dictionary=fired.snapshot()
	# Break the late controller only in a detached regression branch: contact
	# would damage both owners before this rejection, so rollback matters.
	var broken: RefCounted=fired.fork_for_frame();broken._control._rules=broken._control._rules.duplicate(true);broken._control._rules.actor_count=9
	var broken_before: Dictionary=broken.snapshot()
	host.check(broken.evaluate(100,muzzle)==null and broken.snapshot()==broken_before and fired.snapshot()==before,"Late source41 actor rejection leaked staged damage or projectile cleanup")
	var hit: RefCounted=fired.evaluate(100,muzzle)
	if hit==null:host.check(false,fired.error);return
	var hit_state: Dictionary=hit.snapshot();var events: Array=hit_state.events.contacts.filter(func(row):return row.actor_id==1)
	host.check(events.size()==1 and events[0].contacts.size()==1 and events[0].npc_contacts.map(func(row):return row.actor_id)==[0],"Real Void shot did not contact player first then Vossk freighter")
	if events.size()!=1:return
	host.check(events[0].last_contact_actor=={"group":"npc","index":0} and shot.actors[0].outcome.projectile.id in events[0].motion.cleared,"Native41 cleanup happened before the complete target list")
	host.check(hit_state.player.vitals!=before.player.vitals and hit_state.combat.actors[0].vitals.hull==0,"Real source41 contacts did not damage both retained owners")
	host.check(hit_state.combat.actors[0].body_pose.origin==before.combat.actors[0].body_pose.origin+Vector3(0,0,100),"Freighter lethal contact skipped the final native cruise displacement")
	host.check(hit_state.combat.actors[0].actor_mode!=4 and hit_state.controller.accounting.events.size()==1,"Lethal hull was confused with delayed retirement or accounting duplicated")
	host.check(hit_state.radio.started[6] and not hit_state.failure_condition.satisfied,"Source41 radio missed this frame's lethal contact or treated hull-zero as completed mode4")
	var dying: RefCounted=hit;var death_frames:=0
	while dying.combat_owner().actor_snapshot(0).actor_mode!=4 and death_frames<500:
		var next: RefCounted=dying.evaluate(100,pose,false)
		if next==null:host.check(false,dying.error);return
		dying=next;death_frames+=1
	var death: Dictionary=dying.snapshot()
	host.check(death.radio.started[6] and death.failure_condition=={"kind":7,"parameter":1,"satisfied":true,"npc_revision":death.revision},"Source41 hull-zero radio or completed-wreck failure observation was lost")
	# Source mode4 is the completed wreck, not immediate activity cleanup.
	# Its cargo stays active through the strict cleanup-after boundary.
	host.check(death.combat.actors[0].actor_mode==4 and death.combat.actors[0].active and death.controller.destruction[0].phase=="wreck" and death.controller.accounting.events.size()==1,"Native Vossk breakup failed to retain its mode4 wreck once")
	var cleanup_ms:=int(bindings.freighter_destruction.cleanup_after_ms)
	var cleaned: RefCounted=dying
	for _step in cleanup_ms/100:
		var next: RefCounted=cleaned.evaluate(100,pose,false)
		if next==null:host.check(false,cleaned.error);return
		cleaned=next
	host.check(cleaned.combat_owner().actor_snapshot(0).active and cleaned.snapshot().controller.destruction[0].cleanup_elapsed_ms==cleanup_ms,"Freighter cleanup used >= instead of its source strict > boundary")
	var after_cleanup: RefCounted=cleaned.evaluate(1,pose,false)
	if after_cleanup==null:host.check(false,cleaned.error);return
	host.check(not after_cleanup.combat_owner().actor_snapshot(0).active and after_cleanup.snapshot().controller.accounting.events.size()==1,"Freighter did not deactivate once after its complete native cleanup interval")
	host.check(death.controller.defeat_status.is_empty() and not death.controller.has("contract_result") and not death.application_committed,"NPC lifecycle invented a mission result, side-job settlement or Host grant")
	host.check(fired.snapshot()==before and active.snapshot()==first,"Source41 mixed contact or death mutated the live sibling")
	# DISCLOSED player approach pose inside the actual fighter's range. The
	# original entry player is too distant for this stationary component test.
	# No NPC placement or firing request: shared guidance chooses and fires.
	var approach:=Transform3D(Basis.IDENTITY,first.combat.actors[1].pose*Vector3(0,0,1000))
	var natural: RefCounted=active;var automatic_shots:=0;var natural_frames:=0
	while automatic_shots==0 and natural_frames<100:
		var next: RefCounted=natural.evaluate(100,approach,false)
		if next==null:host.check(false,natural.error);return
		for actor in next._events.actors:
			for event in actor.get("firing",{}).get("actors",[]):
				if event.outcome.fired:
					automatic_shots+=1
					host.check(event.outcome.projectile.position==natural.combat_owner().actor_snapshot(event.actor_id).pose.origin,"Source41 automatic gun used its moved rather than pre-motion muzzle")
		natural=next;natural_frames+=1
	host.check(automatic_shots>0 and natural.combat_owner().actor_snapshot(1).body_pose!=first.combat.actors[1].body_pose,"Native41 guidance failed to move and automatically fire")
	if DisplayServer.get_name()!="headless":await load("res://tests/fixtures/selected41_construction_checks.gd").render(host,library,bindings,visuals,builder,world,natural)
	host.check(world.snapshot()==original and entry.career_owner().snapshot()==career and entry.equipment_owner().snapshot()==gear and owner.snapshot()==initial,"Live41 testing altered initialization, independent passengers, wallet or inventory")
	print("Source41 native NPC:8 actors,player-first real mixed shot,Vossk mode4 after%dms then strict cleanup%d+1ms,automatic%dshots/%dms at disclosed player approach; same initialized generation; component only, no Host commit"%[death_frames*100,cleanup_ms,automatic_shots,natural_frames*100])
