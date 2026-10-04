extends "res://tests/wingman_route_application.gd"
## New reciprocal targeting coverage; detached diagnostics never enter a save.

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.contracts.wingmen.active.get("names",[]).size()==3 and original.contracts.mission.get("kind")==2,"Reciprocal coverage requires the unchanged paid Protection career")
	if failures or not await depart_for_lifetime():return
	var parent: RefCounted=app.session.flight_owner()
	var before: Dictionary=parent.snapshot()
	var control_only:=OS.get_environment("GOF2_RECIPROCAL_STAGE")=="control"
	if control_only:verify_reciprocal_control(parent)
	else:verify_reciprocal_components(parent)
	check(parent.snapshot()==before and app.session.flight_owner().snapshot()==before,"Reciprocal components changed the live flight")
	if failures:return
	if not control_only:await capture_free_application("wingman-reciprocal-live")
	check(FileAccess.get_sha256(input_path)==input_hash,"Reciprocal coverage modified its earned input")
	print("Reciprocal component result: ",{"failures":failures,"input_sha256":input_hash,"earned_casualties":0})

func verify_reciprocal_components(parent: RefCounted) -> void:
	var before: Dictionary=parent.snapshot()
	var encounter: RefCounted=parent.encounter_owner()
	var retained: Dictionary=encounter.snapshot()
	var crew: RefCounted=parent.wingman_owner()
	var cast: Dictionary=crew.snapshot()
	var player: Dictionary=encounter.target(parent._player,before.player_pose)
	var actors: Array=encounter.combat_snapshot().actors
	var shooter:=-1;var peer:=-1;var excluded:=-1
	for id in actors.size():
		var guidance: RefCounted=encounter._control._guidance[id]
		if guidance==null:continue
		var targets: Array=guidance.training_targets(player,actors,crew)
		check(not targets.is_empty(),guidance.error)
		var actual: Array=targets.map(func(row):return {"group":"wingman","index":row.wingman_index} if row.target_kind=="wingman" else row.actor_id)
		check(actual==encounter._weapons.companion_target_order(id,crew),"Aim and projectile memberships disagree about paid slots or Protection order")
		check(actual.filter(func(row):return row is int)==guidance._training.target_memberships[id],"Adding aim targets changed the configured mission population order")
		var paid: Array=targets.filter(func(row):return row.target_kind=="wingman")
		if paid.is_empty():excluded=id
		if shooter<0 and actors[id].hostile and not paid.is_empty():shooter=id;peer=int(paid[0].wingman_index)
	check(shooter>=0 and peer>=0,"The earned encounter has no hostile eligible to aim at a paid pilot")
	if failures:return
	var guidance: RefCounted=encounter._control._guidance[shooter].fork_for_frame()
	var initial_guidance: Dictionary=guidance.snapshot()
	var native_target: Dictionary=crew.body_owner(peer).snapshot()
	# Isolate aim with detached input observations. No actor owner or live pose
	# is replaced; all clocks advance through the normal component update.
	var observer: Dictionary=actors[shooter].duplicate(true)
	observer.actor_mode=1
	observer.pose=Transform3D(native_target.pose.basis,native_target.pose.origin-native_target.pose.basis.z*10000.0)
	var quiet: Array=actors.duplicate(true)
	for row in quiet:row.active=false;row.vitals.hull=0
	var absent_player: Dictionary=player.duplicate(true);absent_player.active=false;absent_player.hull=0
	var random: Dictionary=parent._random.duplicate(true)
	var decision:={};var aimed:=false
	for tick in 80:
		decision=guidance.update(100,observer,observer.pose,absent_player,random,quiet,crew)
		if decision.is_empty():check(false,guidance.error);return
		random=decision.random_state
		if decision.fire_requested and decision.target_kind=="wingman":aimed=true;break
	check(aimed and decision.get("target_wingman_index")==peer and decision.target_actor_id==-1,"Native guidance did not distinguish its paid target from a mission actor or player")
	if aimed:check(decision.direction.dot((native_target.pose.origin-observer.pose.origin).normalized())>0.999,"Reciprocal guidance did not point at the selected paid pilot")
	var invalid: RefCounted=encounter._control._guidance[shooter].fork_for_frame()
	check(invalid.update(100,observer,observer.pose,absent_player,random,quiet,RefCounted.new()).is_empty() and invalid.snapshot()==initial_guidance,"An untyped companion input mutated guidance")
	var wrong: Dictionary=guidance._identity.duplicate();wrong.binding_id="different-content"
	check(not crew.matches_target_context(wrong) and crew.snapshot()==cast,"Foreign content was admitted as paid target statistics")
	if failures:return
	var weapons: RefCounted=encounter._weapons.fork_for_frame()
	var request:={"actor_id":shooter,"target_actor_id":-1,"wingman_index":peer,"pose":observer.pose}
	var emitted:=false
	for tick in 20:
		var fired: Dictionary=weapons.fire_combat_training(encounter.combat_owner(),[request],crew)
		if fired.is_empty():check(false,weapons.error);return
		if fired.actors.any(func(row):return row.actor_id==shooter and row.outcome.fired):emitted=true;break
		var gun: RefCounted=weapons._guns[shooter].fork_state()
		if gun.advance(100).is_empty():check(false,gun.error);return
		weapons._guns[shooter]=gun
	check(emitted,"Reciprocal fire intent never emitted a native enemy projectile")
	var gun_before: Dictionary=weapons.snapshot()
	var alias: Dictionary=request.duplicate();alias.target_actor_id=0
	check(weapons.fire_combat_training(encounter.combat_owner(),[alias],crew).is_empty() and weapons.snapshot()==gun_before,"A paid slot was accepted as mission actor zero")
	var unavailable: Dictionary=request.duplicate();unavailable.wingman_index=99
	check(weapons.fire_combat_training(encounter.combat_owner(),[unavailable],crew).is_empty() and weapons.snapshot()==gun_before,"An unavailable paid slot emitted a round")
	check(weapons.fire_combat_training(encounter.combat_owner(),[request]).is_empty() and weapons.snapshot()==gun_before,"A companion request fired without its cast owner")
	if excluded>=0:
		var forbidden: Dictionary=request.duplicate();forbidden.actor_id=excluded
		check(weapons.fire_combat_training(encounter.combat_owner(),[forbidden],crew).is_empty() and weapons.snapshot()==gun_before,"A player-only or same-faction shooter acquired a paid pilot")
	var dead: RefCounted=crew.fork_for_frame()
	check(dead.bind_incoming_weapons(encounter._weapons),dead.error)
	var declaration: Dictionary=encounter._weapons._guns[shooter].snapshot().weapon
	for tick in 2000:
		if dead.body_owner(peer).snapshot().vitals.hull==0:break
		if dead.weapon_hit(peer,declaration).is_empty():check(false,dead.error);return
	check(dead.body_owner(peer).snapshot().vitals.hull==0,"The detached target was not depleted for death-selection coverage")
	var dead_targets: Array=guidance.training_targets(absent_player,quiet,dead)
	var live_targets: Array=guidance.training_targets(absent_player,quiet,crew)
	check(dead_targets.size()==live_targets.size() and dead_targets.map(func(row):return row.get("wingman_index",-1))==live_targets.map(func(row):return row.get("wingman_index",-1)),"Losing a pilot shifted retained target identities")
	check(weapons.fire_combat_training(encounter.combat_owner(),[request],dead).is_empty() and weapons.snapshot()==gun_before,"A depleted paid pilot admitted a new firing request")
	var after_loss: Dictionary=guidance.update(100,observer,observer.pose,absent_player,random,quiet,dead)
	check(not after_loss.is_empty() and not (after_loss.fire_requested and after_loss.get("target_wingman_index")==peer),"Guidance continued firing at a depleted paid pilot")
	var integrated: Dictionary=encounter.evaluate_world(parent._player,before.player_pose,100,parent._random,crew)
	check(not integrated.is_empty(),encounter.error)
	if not integrated.is_empty():check(integrated.encounter.combat_snapshot().actors.size()==actors.size(),"Reciprocal control changed mission population counts")
	check(encounter.snapshot()==retained and crew.snapshot()==cast and parent.snapshot()==before,"Reciprocal selection or firing leaked into a parent or sibling")
	print("Reciprocal targeting diagnostics: ",{"shooter":shooter,"paid_slot":peer,"aimed":aimed,"emitted":emitted,"mission_actors":actors.size(),"paid_pilots":cast.actors.size(),"actor_kinds":actors.map(func(row):return row.actor_kind)})

func verify_reciprocal_control(parent: RefCounted) -> void:
	var before: Dictionary=parent.snapshot()
	var encounter: RefCounted=parent.encounter_owner()
	var crew: RefCounted=parent.wingman_owner()
	var combat: RefCounted=encounter.combat_owner()
	var actors: Array=combat.snapshot().actors
	var hostile_ids: Array=actors.filter(func(actor):return actor.hostile).map(func(actor):return actor.actor_id)
	check(not hostile_ids.is_empty(),"The controller component has no native opposing ship")
	if failures:return
	var declaration: Dictionary=encounter._weapons._guns[hostile_ids[0]].snapshot().weapon
	# Isolate the controller boundary after earlier protected targets are gone.
	# Only canonical damage is applied, to a detached native combat owner. This
	# is explicitly NOT an earned death, mission outcome or saved career.
	var removed:=[]
	for actor in actors:
		if actor.actor_kind!=crew.snapshot().actors[0].actor_kind:continue
		for round_index in 20000:
			if combat.actor_snapshot(actor.actor_id).vitals.hull==0:break
			if combat.weapon_hit(actor.actor_id,declaration).is_empty():check(false,combat.error);return
		check(combat.actor_snapshot(actor.actor_id).vitals.hull==0,"The detached controller fixture retained an earlier protected target")
		removed.append(actor.actor_id)
	encounter._combat=combat
	if failures:return
	if report_parent_change(parent,before,"canonical component damage"):check(false,"Component preparation changed the parent");return
	var random: Dictionary=parent._random.duplicate(true)
	var aimed:=false;var fired:=false;var frame_count:=0;var target_indices:=[]
	for frame_index in 1200:
		var following: Dictionary=crew.advance_targeting(100,before.player_pose,parent._player.snapshot(),encounter.combat_snapshot().actors,random)
		if following.is_empty():check(false,crew.error);return
		if frame_index==0 and report_parent_change(parent,before,"paid following"):check(false,"Detached following changed the parent");return
		var aged: RefCounted=encounter._weapons.fork_for_frame()
		if aged.advance(100).is_empty():check(false,aged.error);return
		encounter._weapons=aged
		if frame_index==0 and report_parent_change(parent,before,"weapon aging"):check(false,"Detached weapon aging changed the parent");return
		var operation: Dictionary=encounter.evaluate_world(parent._player,before.player_pose,100,following.random_state,crew)
		if operation.is_empty():check(false,encounter.error);return
		encounter=operation.encounter;random=operation.random_state;frame_count+=1
		if frame_index==0 and report_parent_change(parent,before,"native controller"):check(false,"Detached actor control changed the parent");return
		for event in encounter.actor_events():
			if event.get("decision",{}).get("target_kind")!="wingman":continue
			aimed=true
			check(event.decision.target_actor_id==-1 and event.decision.target_wingman_index in range(3),"Enclosing control aliased a paid pilot to a mission actor")
			if event.decision.target_wingman_index not in target_indices:target_indices.append(event.decision.target_wingman_index)
			for shot in event.firing.get("actors",[]):
				if shot.outcome.fired:fired=true
		if fired:break
	check(aimed and fired,"The native controller never forwarded a paid target into its ordinary weapon pool")
	check(encounter.combat_snapshot().actors.size()==actors.size() and crew.snapshot().actors.size()==3,"Integrated companion control changed population counts")
	report_parent_change(parent,before,"completed native controller")
	check(parent.snapshot()==before and app.session.flight_owner().snapshot()==before,"A controller diagnostic escaped into the live career")
	print("Separate native controller result: ",{"frames":frame_count,"earlier_targets_removed_in_component":removed,"paid_target_indices":target_indices,"aimed":aimed,"emitted":fired,"earned_casualties":0,"failures":failures})

func report_parent_change(parent: RefCounted,before: Dictionary,stage: String) -> bool:
	var current: Dictionary=parent.snapshot()
	if current==before:return false
	var paths:=[]
	append_changed_paths(before,current,"flight",paths)
	print("Parent changed at ",stage,": ",paths)
	return true

func append_changed_paths(before: Variant,after: Variant,path: String,paths: Array) -> void:
	if paths.size()>=12 or before==after:return
	if before is Dictionary and after is Dictionary:
		for key in before:
			if not after.has(key):paths.append(path+"."+str(key))
			else:append_changed_paths(before[key],after[key],path+"."+str(key),paths)
		for key in after:
			if not before.has(key):paths.append(path+"."+str(key))
	elif before is Array and after is Array and before.size()==after.size():
		for index in before.size():append_changed_paths(before[index],after[index],path+"["+str(index)+"]",paths)
	else:paths.append(path)
