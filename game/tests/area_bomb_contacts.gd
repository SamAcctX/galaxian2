extends "res://tests/secondary_retention.gd"
## Detached mixed-target transactions. Original bodies and NPC damage owners
## exercise permissions, contact order, retained ammunition and rollback.
const BodyResources=preload("res://src/content/scenery_body_resources.gd")
const SceneryBodies=preload("res://src/simulation/scenery_bodies.gd")
const BurstResources=preload("res://src/content/emp_detonation_resources.gd")

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_area_contacts(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Area bomb contacts: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_area_contacts(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat):check(false,lib.error+bindings.error+cat.error+mounts.error);return
	var built:=construction(bindings,cat,0.5)
	if built==null:return
	for item in [41,44,45,46]:
		var group:=active_group(bindings,cat,built,0)
		var initial:=equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":1}])
		var views:=detached_views(bindings,cat,lib,initial,built.snapshot().random_state)
		views.equipment._items[item]={"category":1,"subtype":6 if item==41 else 7}
		var owner:=Ownership.new();var resources:=BurstResources.new()
		if group==null or views.is_empty() or not owner.configure(bindings,cat,initial,mounts) or not resources.configure(lib,bindings,6 if item==41 else 7) or not owner.configure_detonations(resources):check(false,owner.error+resources.error);return
		var weapon: Dictionary=owner.snapshot().guns[0].bomb.weapon
		for id in 4:
			var position:=Vector3(weapon.radius*0.5,0,0) if id<2 else Vector3(weapon.radius*2.0,id*1000,0)
			check(group.set_pose(id,Transform3D(Basis.IDENTITY,position)),group.error)
		group._writable(1)._state.damage_allowed=false
		var field:=body_fixture(lib,bindings,weapon.radius)
		if field==null:return
		views.targets._actors=group.snapshot().actors.map(func(actor):return {"actor_id":actor.actor_id,"hull_catalogue_id":actor.hull_catalogue_id,"hull_resource":actor.hull_resource,"actor_kind":actor.actor_kind})
		views.targets._scenery=field.snapshot().objects.map(func(body):return {"index":body.index,"position":body.position})
		views.targets._state.scenery_indices=[0,1,2]
		var order: Array=views.targets.snapshot().npc_ids
		var ready:=owner.evaluate_advance(1,group,order,Vector3.ZERO,field,views.targets)
		if ready.is_empty():check(false,owner.error);return
		check(ready.bodies==field,"An idle launcher copied the asteroid field")
		owner=ready.owner
		var pose:=Transform3D(Basis.IDENTITY,-Vector3(weapon.muzzle_offset))
		var before:=view_snapshot(views);var old_field: Dictionary=field.snapshot();var old_group: Dictionary=group.snapshot();var old_owner:=owner.snapshot()
		var fired:=owner.evaluate_player_trigger(pose,item,group,order,views.player,views.equipment,views.primaries,views.targets,true,field)
		if fired.is_empty():check(false,owner.error);return
		check(view_snapshot(views)==before and field.snapshot()==old_field and group.snapshot()==old_group and owner.snapshot()==old_owner,"Preparing an area launch changed its accepted parents")
		check(fired.bodies==field,"A new launch copied scenery before a radius hit")
		check(fired.owner.snapshot().guns[0].ammunition==0 and fired.events[0].audio.source_id==Bombs.Definitions.declaration(item).launch_sound,"Area launch lost its sound or consumed an incorrect round count")
		owner=fired.owner;views=fired
		var slot: int=owner.snapshot().guns[0].slot_index
		var broken:=fork_views(views);broken.equipment._state.prices.installed[slot]={"item_id":item,"unit_price":5}
		check(owner.evaluate_player_trigger(pose,item,group,order,broken.player,broken.equipment,broken.primaries,broken.targets,true,field).is_empty(),"Invalid empty-slot price accepted a radius transaction")
		check(field.snapshot()==old_field and group.snapshot()==old_group and owner.snapshot().guns[0].bomb.shot.phase=="flying","Rejected pulse changed scenery, ships or the last live round")
		var manual:=owner.evaluate_player_trigger(pose,item,group,order,views.player,views.equipment,views.primaries,views.targets,true,field)
		var contact:=owner.evaluate_advance(100,group,order,Vector3.ZERO,field,views.targets)
		if manual.is_empty() or contact.is_empty():check(false,owner.error);return
		check(manual.events.size()==1 and contact.events.size()==1 and manual.events[0].action=="detonated" and contact.events[0].action=="detonated","Manual and physical contact did not each produce one radius pulse")
		check(contact.events[0].blast.position==Vector3.ZERO and contact.owner.snapshot().guns[0].bomb.shot.position==Vector3.ZERO,"Contact pulse moved before hitting the asteroid")
		check(manual.bodies.snapshot()==contact.bodies.snapshot() and manual.combat.snapshot()==contact.combat.snapshot(),"Manual and contact pulses disagree on actual target consequences")
		check(manual.combat.snapshot().actors[1].vitals==old_group.actors[1].vitals and manual.bodies.snapshot().objects[1].vitals==old_field.objects[1].vitals,"A blast bypassed ship or asteroid damage permission")
		check(manual.bodies.snapshot().objects[2]==old_field.objects[2],"An asteroid on the radius boundary took damage or impulse")
		if item==41:
			check(manual.bodies.snapshot()==old_field and manual.combat.snapshot().actors[0].vitals==old_group.actors[0].vitals,"EMP changed asteroid or ship hull pools")
			check(manual.combat.snapshot().actors[0].systems.integrity<old_group.actors[0].systems.integrity,"EMP contact failed to reach nearby ship systems")
		else:
			check(manual.events[0].normal_hits.size()==4 and manual.events[0].systems_hits.is_empty(),"AMR missed a nearby target or used systems damage")
			check(manual.events[0].normal_hits[0].damage==int(weapon.damage/2.0) and manual.combat.snapshot().actors[0].vitals!=old_group.actors[0].vitals,"AMR failed to damage the ship at half radius")
			check(manual.bodies.snapshot().objects[0].vitals.hull<old_field.objects[0].vitals.hull and manual.bodies.snapshot().objects[0].impact_vector==Vector3.UP,"A centered bomb did not apply damage with the shared zero-distance direction")
			check(manual.bodies.snapshot().objects[1].motion_scalar==0.75 and manual.bodies.snapshot().objects[1].impact_vector==Vector3.RIGHT,"Damage permission incorrectly suppressed the independent scenery impulse")
			check(manual.combat.snapshot().actors[0].systems==old_group.actors[0].systems,"AMR disabled ship systems")
			if item==44:verify_cargo_drift(lib,bindings,cat,built,manual.events)
		var observed: Dictionary=manual.owner.evaluate_advance(100,manual.combat,order,Vector3.ZERO,manual.bodies,manual.targets)
		if observed.is_empty():check(false,manual.owner.error);return
		check(observed.events.is_empty() and observed.self_hits.size()==1 and observed.owner.snapshot().detonation_audio.size()==1,"First observed manual burst omitted or repeated its own-ship/sound consequence")
		if item==44:verify_self_damage(views.player,observed.self_hits)
		var again: Dictionary=observed.owner.evaluate_advance(100,observed.combat,order,Vector3.ZERO,observed.bodies,manual.targets)
		check(not again.is_empty() and again.self_hits.is_empty() and again.events.is_empty() and again.owner.snapshot().detonation_audio.is_empty(),"A retained burst repeated its damage or sound")
		check(view_snapshot(manual)==view_snapshot(views) and field.snapshot()==old_field and group.snapshot()==old_group,"Detonation spent another round or mutated an earlier accepted target frame")

func body_fixture(lib: RefCounted,bindings: RefCounted,radius: int) -> RefCounted:
	var resources:=BodyResources.new();var bodies:=SceneryBodies.new()
	if not resources.configure(lib,bindings):check(false,resources.error);return null
	var rows:=[]
	for index in 3:
		rows.append({"index":index,"model_variant":0,"model_id":int(bindings.scenery_resources.model_ids[0]),"item_id":150,"source_size_value":4,"position":Vector3.ZERO if index==0 else Vector3(radius*(0.25 if index==1 else 1.0),0,0),"large":false,"scale":0.8})
	if not bodies.configure(bindings,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"objects":rows},resources) or not bodies.set_permissions(1,true,false):check(false,bodies.error);return null
	return bodies

func verify_cargo_drift(lib: RefCounted,bindings: RefCounted,cat: RefCounted,built: RefCounted,events: Array) -> void:
	var resources:=Resources.new();var control:=ActorControl.new()
	if not resources.configure_kappa_rescue(lib,bindings,built) or not control.configure_kappa_rescue(bindings,cat,built,{"axes":[0,0],"override":-1}) or not control.set_destruction(bindings,resources):check(false,resources.error+control.error);return
	var death: RefCounted=control._destruction[0]
	# Explicit detached cargo exercises movement even if this generated ship
	# carried nothing. It never enters a player inventory or a saved career.
	death._state.cargo.entries=[{"item_id":0,"quantity":1}];death._state.cargo.eligible=true
	if not death.capture(Transform3D.IDENTITY,2.0):check(false,death.error);return
	var random: Dictionary=built.snapshot().random_state
	for unused in 100:
		var frame: Dictionary=death.advance(100,random)
		if frame.is_empty():check(false,death.error);return
		random=frame.random_state
		if frame.state.phase=="explosion":break
	var before: Dictionary=death.snapshot()
	if before.phase!="explosion":check(false,"Cargo fixture did not finish breakup");return
	var next: RefCounted=control.evaluate_blast_motion(events)
	if next==null:check(false,control.error);return
	var retained: Dictionary=next._destruction[0].snapshot()
	check(death.snapshot()==before and retained.drift_speed==0.5 and retained.drift_direction==before.drift_direction,"AMR changed a parent wreck or replaced its existing cargo direction")
	var moved: Dictionary=next._destruction[0].advance(7,random)
	if moved.is_empty():check(false,next._destruction[0].error);return
	check(absf((moved.state.cargo.pose.origin-before.cargo.pose.origin).length()-0.5)<0.001,"AMR cargo drift did not use the new radius fraction once")
	check(moved.state.effect.position==before.effect.position and moved.state.cargo.entries==before.cargo.entries and moved.random_state==random,"A later blast restarted the explosion, regenerated cargo or consumed random draws")

func verify_self_damage(player: RefCounted,hits: Array) -> void:
	var encounter:=preload("res://src/simulation/full_hold_encounter.gd").new()
	var original: Dictionary=player.snapshot()
	for difficulty in [0.5,1.0,1.5]:
		encounter._difficulty=difficulty
		var result: RefCounted=encounter._evaluate_bomb_damage(player,hits)
		if result==null:check(false,encounter.error);return
		if difficulty!=1.5:check(result.snapshot()==original,"A non-hard difficulty received own-bomb damage")
		else:
			check(result.snapshot().vitals=={"hull":27,"armor":0,"shield":0.0},"Hard own-bomb damage bypassed the player's integer shield/armor pools")
			var protected: RefCounted=player.fork_for_frame();protected.set_permissions(true,false)
			check(encounter._evaluate_bomb_damage(protected,hits).snapshot()==protected.snapshot(),"Own-bomb damage bypassed player protection")
		check(player.snapshot()==original,"Own-bomb damage changed its parent player")
