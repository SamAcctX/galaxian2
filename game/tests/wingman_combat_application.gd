extends "res://tests/wingman_route_application.gd"
## One earned combat/loss/docking checkpoint followed by a fresh-process Resume.
## This pilot only steers, fires and acknowledges normal game UI.
var combat_metrics:={"enemy_aim_frames":0,"enemy_shots":0,"incoming_contacts":0,"crew_shots":0,"lost":[],"results":[],"death_phases":[]}

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var original: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==original.contracts.wingmen and document.career.mission==original.contracts.mission and document.career.credits==original.contracts.credits,"Combat Resume changed the earned crew, job or wallet")
	if OS.get_environment("GOF2_COMBAT_STAGE")=="resume":
		var expected: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_COMBAT_RECEIPT")))
		check(expected is Dictionary and not expected.get("lost",[]).is_empty(),"Fresh Resume lost its preceding earned casualty evidence")
		if failures:return
		check(original.contracts.wingmen==expected.wingmen and original.contracts.credits==expected.credits and original.campaign_cursor==expected.cursor,"Fresh Resume changed surviving pilots, lifetime, wallet or campaign")
		check(original.contracts.wingmen.active.get("names",[]).all(func(name):return name not in expected.lost),"A genuinely destroyed pilot returned after fresh Resume")
		await capture_free_application("wingman-combat-fresh-resume")
		check(FileAccess.get_sha256(input_path)==input_hash,"Fresh Resume modified the earned combat checkpoint")
		print("Fresh earned combat Resume: ",{"wingmen":original.contracts.wingmen,"credits":original.contracts.credits,"failures":failures})
		return
	check(original.contracts.wingmen.active.get("names",[]).size()==3 and original.contracts.mission.get("kind")==2,"Combined combat requires the retained paid Protection career")
	if failures or not await depart_for_lifetime():return
	var parent: RefCounted=app.session.flight_owner()
	var before: Dictionary=parent.snapshot()
	check(parent.command_wingmen(3,true)==null and parent.snapshot()==before,"A paused attack order changed the earned flight")
	if failures:return
	combat_metrics.paused_order_refused=true
	var pilot:=PiratePilot.new()
	var started:=now_us;var next_yield:=now_us;var next_log:=now_us;var loss_at:=-1
	var minimum_hull: Array=before.wingman_actors.actors.map(func(actor):return int(actor.vitals.hull))
	var captured_fight:=false
	while now_us-started<220000000:
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():
			await capture_free_application("wingman-combat-player-loss")
			check(false,"The earned player died before banking the companion combat result");return
		if not state.contracts.pending_result.is_empty():
			combat_metrics.results.append(state.contracts.pending_result.duplicate(true))
			await capture_free_application("wingman-combat-job-result")
			await acknowledge_recovery_result();app.session.rebase_time(now_us)
			if failures:return
			continue
		for event in state.encounter.actor_events:
			if event.get("decision",{}).get("target_kind")=="wingman":combat_metrics.enemy_aim_frames+=1
			for shot in event.get("firing",{}).get("actors",[]):
				if shot.get("outcome",{}).get("fired",false):combat_metrics.enemy_shots+=1
		for event in state.encounter.weapon_events:combat_metrics.incoming_contacts+=event.get("wingman_contacts",[]).size()
		for shot in state.wingman_actors.primary_firing.actors:
			if shot.get("outcome",{}).get("fired",false):combat_metrics.crew_shots+=1
		for index in state.wingman_actors.actors.size():
			var actor: Dictionary=state.wingman_actors.actors[index]
			minimum_hull[index]=mini(minimum_hull[index],int(actor.vitals.hull))
			if actor.vitals.hull==0:
				if actor.name not in combat_metrics.lost:combat_metrics.lost.append(actor.name)
				var phase: String=state.wingman_actors.destruction[index].phase
				if phase not in combat_metrics.death_phases:combat_metrics.death_phases.append(phase)
		if not combat_metrics.lost.is_empty():
			if loss_at<0:
				loss_at=now_us
				await capture_free_application("wingman-combat-earned-loss")
			if now_us-loss_at>=12000000:break
		var hostiles: Array=state.encounter.combat.actors.filter(func(actor):return actor.active and actor.vitals.hull>0 and actor.hostile).map(func(actor):return int(actor.actor_id))
		var input: Dictionary
		if not hostiles.is_empty():
			input=pilot.controls_at_time(state,float(state.world_elapsed_ms),hostiles,false)
			input.throttle=1.0 if input.distance>18000.0 else 0.0
			input.fire=input.fire and now_us-started<15000000
			input.strafe=1.0 if input.distance<40000.0 else 0.0
		else:
			input={"commands":PiratePilot.Steering.steering_toward(state.player_pose,state.player_pose.origin+state.player_pose.basis.z*10000.0),"throttle":0.0,"fire":false,"strafe":0.0}
		if not pirate_step(input):return
		if now_us>=next_log:
			print("Earned crew combat: ",{"elapsed_ms":int((now_us-started)/1000),"minimum_hull":minimum_hull,"lost":combat_metrics.lost,"incoming":combat_metrics.incoming_contacts,"enemy_aim":combat_metrics.enemy_aim_frames,"crew_shots":combat_metrics.crew_shots,"player":state.player.vitals})
			next_log=now_us+20000000
		if now_us>=next_yield:
			await process_frame;next_yield=now_us+1000000
			if not captured_fight and now_us-started>=15000000:
				await capture_free_application("wingman-combat-live-fight");captured_fight=true
	combat_metrics.minimum_hull=minimum_hull;combat_metrics.elapsed_ms=int((now_us-started)/1000)
	print("Earned combat observation: ",combat_metrics)
	check(not combat_metrics.lost.is_empty() and combat_metrics.enemy_aim_frames>0 and combat_metrics.incoming_contacts>0 and combat_metrics.crew_shots>0,"The bounded earned fight did not produce a reciprocal companion combat loss")
	if failures:return
	var before_dock: Dictionary=app.session.snapshot()
	check(before_dock.contracts.wingmen.active.get("names",[]).all(func(name):return name not in combat_metrics.lost),"The live casualty remained in the paid career")
	if failures or not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	check(returned.contracts.wingmen.active.get("names",[])==before_dock.contracts.wingmen.active.get("names",[]) and returned.contracts.wingmen.hired_total==original.contracts.wingmen.hired_total,"Docking resurrected, rehired or expired the observed combat roster")
	check(returned.contracts.credits==before_dock.contracts.credits and returned.cargo==original.cargo and returned.loadout.equipment_ids==original.loadout.equipment_ids and returned.campaign_cursor==original.campaign_cursor,"Banking the combat loss changed unrelated earned property")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen and automatic.career.mission==returned.contracts.mission and automatic.career.credits==returned.contracts.credits,"The immediate docking autosave lost combat survivors or the native job outcome")
	if failures or not retain_recovery_save("returned"):return
	combat_metrics.wingmen=returned.contracts.wingmen;combat_metrics.credits=returned.contracts.credits;combat_metrics.cursor=returned.campaign_cursor
	var receipt:=FileAccess.open(OS.get_environment("GOF2_COMBAT_RECEIPT"),FileAccess.WRITE)
	check(receipt!=null,"The combat observation could not be retained")
	if receipt!=null:receipt.store_string(JSON.stringify(combat_metrics,"  "));receipt.close()
	await capture_free_application("wingman-combat-docked")
	check(parent.snapshot()==before and FileAccess.get_sha256(input_path)==input_hash,"The earned combat run altered its retained parent or input save")
	print("Earned combat banked: ",combat_metrics)
