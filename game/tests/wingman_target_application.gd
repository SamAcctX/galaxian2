extends "res://tests/wingman_follow_application.gd"
## Actual earned departure, target pursuit, docking and independent Resume.
## Synthetic opponents below are confined to detached component candidates.

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and not entry.contracts.wingmen.active.is_empty() and document.career.wingmen==entry.contracts.wingmen,"Resume changed the genuinely paid crew")
	check(document.career.credits==entry.contracts.credits,"Resume changed the earned wallet")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var initial: Dictionary=app.session.flight_owner().snapshot()
	var crew: RefCounted=app.session.flight_owner().wingman_owner()
	check(crew!=null and crew.snapshot().targeting_connected and not crew.snapshot().weapons_connected,"Targeting is absent or falsely claims weapons")
	if failures:return
	check(crew.snapshot().targeting.selections[0].target_actor_id==-1,"Departure retained a target from the previous world")
	var resumed:=OS.get_environment("GOF2_WINGMEN_TARGET_STAGE")=="resume"
	if not resumed:
		verify_target_components(crew,initial.player_pose,initial.player)
		check(app.session.flight_owner().snapshot()==initial,"Detached targeting checks changed the actual flight")
	if failures or not await release_application_flight():return
	var scene:=find_flight_scene(app)
	check(scene!=null and scene.wingmen!=null,"The live pilot has no original ship geometry")
	if failures:return
	if resumed:
		for tick in 40:
			if not pirate_step({"commands":Vector2(.3,0),"throttle":0.0,"fire":false,"strafe":0.0}):return
		var fresh: Dictionary=app.session.snapshot()
		var id: int=fresh.wingman_actors.targeting.selections[0].target_actor_id
		check(id<0 or fresh.encounter.combat.actors.any(func(row):return row.actor_id==id and row.hostile),"Fresh targeting names a missing or peaceful actor")
		check(fresh.wingman_actors.actors[0].name==entry.contracts.wingmen.active.names[0],"Fresh targeting replaced the saved pilot")
		await capture_free_application("wingman-target-resumed-flight")
	else:
		if not await acquire_live_target(scene):return
		var paused: Dictionary=app.session.flight_owner().snapshot().wingman_actors
		check(app.session.set_pause("user",true,now_us),app.session.error)
		for tick in 8:
			if not application_step():return
		check(app.session.flight_owner().snapshot().wingman_actors==paused,"Pause advanced the pilot's target history or pursuit")
		check(app.session.set_pause("user",false,now_us),app.session.error)
	if failures:return
	# Leave any provoked patrol through ordinary travel, not a forced docking.
	var airborne: Dictionary=app.session.snapshot()
	if airborne.encounter.combat.actors.any(func(row):return row.active and row.hostile and row.vitals.hull>0):
		var stations:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==airborne.location.system_id:stations.append(id)
		check(stations.size()>1,"No ordinary withdrawal destination exists")
		if failures or not await travel_application(stations[(stations.find(airborne.location.station_id)+1)%stations.size()]):return
	if not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	for key in ["credits","mission","passengers","blueprints"]:
		check(returned.contracts[key]==entry.contracts[key],"Pursuit changed unrelated career field "+key)
	check(returned.cargo==entry.cargo and returned.loadout.equipment_ids==entry.loadout.equipment_ids and returned.campaign_cursor==entry.campaign_cursor,"Pursuit changed cargo, fitting or campaign")
	check(returned.contracts.wingmen.active.names==entry.contracts.wingmen.active.names and returned.contracts.wingmen.hired_total==entry.contracts.wingmen.hired_total,"Pursuit or docking replaced the paid roster")
	check(returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"Pursuit failed to bank the consumed hire time")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen,"Docking autosave lost the pursuing pilot")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"Target acceptance modified its earned input")
	await capture_free_application("wingman-target-returned")
	print("Earned wingman targeting: ",{"input_sha256":input_hash,"resumed":resumed,"name":returned.contracts.wingmen.active.names[0],"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"credits":returned.contracts.credits,"timing":_pilot_deltas,"weapons_accepted":false})

func verify_target_components(crew: RefCounted,pose: Transform3D,player: Dictionary) -> void:
	var before: Dictionary=crew.snapshot()
	var random:=CrewActors.Random.new()
	check(random.seed_from(17),random.error)
	var hostile: Dictionary=before.actors[0].duplicate(true)
	hostile.actor_id=0;hostile.hostile=true;hostile.pose.origin=pose.origin+Vector3(0,0,30000)
	var peaceful: Dictionary=hostile.duplicate(true)
	peaceful.actor_id=1;peaceful.actor_kind=8;peaceful.hostile=false;peaceful.pose.origin=pose.origin+Vector3(0,0,1000)
	var candidate: RefCounted=crew.fork_for_frame();var sibling: RefCounted=crew.fork_for_frame()
	check(not candidate.advance_targeting(100,pose,player,[hostile,peaceful],random.snapshot()).is_empty(),candidate.error)
	var pursued: Dictionary=candidate.snapshot()
	check(pursued.targeting.selections[0].target_actor_id==0 and pursued.following.targets[0]==hostile.pose.origin,"The hired pilot preferred a peaceful faction rival to the player's actual enemy")
	check(pursued.actors[0].pose!=before.actors[0].pose,"Target selection did not move the native pilot")
	check(crew.snapshot()==before and sibling.snapshot()==before,"Target pursuit mutated a retained parent or sibling")
	var exported: Dictionary=candidate.snapshot();exported.targeting.selections[0].target_actor_id=99
	check(candidate.snapshot()==pursued,"Target observations expose writable retained state")
	var nearer: Dictionary=peaceful.duplicate(true);nearer.hostile=true
	check(not candidate.advance_targeting(100,pose,player,[hostile,nearer],random.snapshot()).is_empty(),candidate.error)
	check(candidate.snapshot().targeting.selections[0].target_actor_id==0,"Targeting replaced retained membership order with nearest distance")
	var dead: Dictionary=hostile.duplicate(true);dead.vitals.hull=0;dead.active=false
	check(not candidate.advance_targeting(100,pose,player,[dead,nearer],random.snapshot()).is_empty(),candidate.error)
	check(candidate.snapshot().targeting.selections[0].target_actor_id==1,"A dead opponent prevented selection of the remaining enemy")
	var no_enemy: RefCounted=crew.fork_for_frame()
	var calm: Dictionary=hostile.duplicate(true);calm.hostile=false
	check(not no_enemy.advance_targeting(100,pose,player,[calm,peaceful],random.snapshot()).is_empty(),no_enemy.error)
	check(no_enemy.snapshot().targeting.selections[0].target_actor_id==-1 and no_enemy.snapshot().following.targets[0]==CrewActors.follow_position(pose,0),"A peaceful encounter displaced the follow formation")
	var ordinary: Dictionary=before.actors[0].duplicate(true);ordinary.wingman=false
	var rows:=[{"actor_kind":0,"active":true,"hull":100,"pose":pose},{"actor_kind":0,"active":true,"hull":100,"pose":hostile.pose},{"actor_kind":8,"active":true,"hull":100,"pose":peaceful.pose}]
	var selected:=CrewActors.Targeting.select({"target_index":-1,"fire_desired":false,"target_selected":false,"straight":false,"selection_elapsed_ms":100},ordinary,rows,random,definitions.opening_actors.npc_initialization.guidance,definitions.combat_training_control)
	check(selected.target_index==2,"The wingman branch changed ordinary faction-opposition targeting")
	var stable: Dictionary=candidate.snapshot()
	for invalid in [-1,1.5,null,"100",2147483647]:
		check(candidate.advance_targeting(invalid,pose,player,[hostile],random.snapshot()).is_empty() and candidate.snapshot()==stable,"Invalid target duration partially changed the crew")
	var foreign: Dictionary=peaceful.duplicate(true);foreign.binding_id="foreign"
	check(candidate.advance_targeting(100,pose,player,[hostile,foreign],random.snapshot()).is_empty() and candidate.snapshot()==stable,"Invalid later membership partially changed the pilot")
	for cadence in [[100],[7,7,6],[7,17,42,8,100,11]]:
		var trial: RefCounted=crew.fork_for_frame();var elapsed:=0;var tick:=0;var rng: Dictionary=random.snapshot()
		while elapsed<600:
			var delta:=mini(int(cadence[tick%cadence.size()]),600-elapsed)
			var result: Dictionary=trial.advance_targeting(delta,pose,player,[hostile,peaceful],rng)
			if result.is_empty():check(false,trial.error);return
			rng=result.random_state;elapsed+=delta;tick+=1
		check(trial.snapshot().targeting.selections[0].target_actor_id==0,"Accepted cadence changed the acquired enemy")
	check(crew.snapshot()==before,"Detached target checks contaminated the live crew")

func acquire_live_target(scene: Node3D) -> bool:
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var acquired_at:=-1;var initial_pilot: Transform3D=app.session.snapshot().wingman_actors.actors[0].pose
	print("Live target candidates: ",app.session.snapshot().encounter.combat.actors.map(func(row):return {"id":row.actor_id,"kind":row.actor_kind,"hostile":row.hostile,"active":row.active,"group":row.get("population_group","")}))
	while now_us-started<150000000:
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The real pilot died before pursuit acceptance");return false
		var chosen: int=state.wingman_actors.targeting.selections[0].target_actor_id
		var targets: Array=state.encounter.combat.actors.filter(func(row):return row.active and row.vitals.hull>0 and not row.get("contract_debris",false)).map(func(row):return row.actor_id)
		if targets.is_empty():check(false,"No real opponent is available for pursuit acceptance");return false
		var input: Dictionary
		if chosen<0:
			var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
			var reach:=float(weapon.speed_units_per_millisecond)*float(weapon.lifetime_ms)
			pilot.firing_range=reach*.9
			input=pilot.controls_at_time(state,float(state.world_elapsed_ms),targets,false)
			input.throttle=1.0 if input.distance>minf(18000.0,reach*.6) else 0.0
		else:
			if acquired_at<0:
				check(state.encounter.combat.actors[chosen].hostile,"The live pilot selected a peaceful ship")
				acquired_at=now_us
			input={"commands":PiratePilot.Steering.steering_toward(state.player_pose,state.wingman_actors.actors[0].pose.origin),"throttle":0.0,"fire":false,"strafe":0.0}
		if not pirate_step(input):return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+500000
		var next: Dictionary=app.session.snapshot()
		var selection: int=next.wingman_actors.targeting.selections[0].target_actor_id
		if selection>=0 and selection<state.encounter.combat.actors.size():
			check(next.wingman_actors.following.targets[0].distance_to(state.encounter.combat.actors[selection].pose.origin)<.5,"Pursuit did not sample the retained pre-NPC-pass target pose")
			if failures:return false
		if acquired_at>=0 and now_us-acquired_at>=2000000:
			var position: Vector3=next.wingman_actors.actors[0].pose.origin
			if not scene.camera.is_position_behind(position):
				var area: Rect2=scene.camera.get_viewport().get_visible_rect().grow(-100)
				if area.has_point(scene.camera.unproject_position(position)) and position.distance_to(next.player_pose.origin)<15000:
					check(position.distance_to(initial_pilot.origin)>1000,"Acquisition left the native pilot stationary")
					check(scene.wingmen.actors[0].ship.transform==next.wingman_actors.actors[0].pose,"Rendering ignored the pursuing body")
					check(scene.wingmen.actors[0].ship.is_visible_in_tree(),"The pursuing pilot is hidden")
					await capture_free_application("wingman-target-pursuit")
					print("Actual wingman pursuit: ",{"target":selection,"seconds":(now_us-started)/1000000.0,"pilot":position,"targeting":next.wingman_actors.targeting})
					return failures==0
		if now_us>=next_log:
			print("Wingman target pilot: ",{"seconds":(now_us-started)/1000000.0,"selected":selection,"hull":next.player.vitals.hull,"input":input})
			next_log=now_us+30000000
	check(false,"Bounded real piloting did not produce a visible pursuing wingman")
	return false
