extends "res://tests/bakka_arrival_application.gd"
## Actual earned202 ship through the staged native arrival, input-only contest,
## full physical return and station38 archive. Only route27 admission is staged;
## never substitute the shielded component inventory or controlled contacts.
const ContestPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")

func verify_free_application() -> void:
	await super.verify_free_application()
	if failures:return
	var initial: Dictionary=app.session.snapshot()
	retained_job=initial.contracts.mission.duplicate(true)
	var checkpoint_hash:=FileAccess.get_sha256(app.station_save_path())
	if not await win_saved_contest(initial):return
	check(FileAccess.get_sha256(app.station_save_path())==checkpoint_hash,"Combat overwrote the viable Ga'kkrr checkpoint")
	if failures:return
	var events: Array=definitions.mido_travel.bakka_contest.result_events
	if not await acknowledge_story_lines(events):return
	var acknowledged: Dictionary=app.session.snapshot()
	check(acknowledged.campaign_cursor==37 and acknowledged.station_return_supported and acknowledged.contracts.credits==initial.contracts.credits,"Victory acknowledgement lost the original unpaid return37")
	await capture_free_application("saved202-bakka-victory-acknowledged")
	if failures or not await return_saved_contest():return
	if not await acknowledge_station_chapter(37):return
	var completed: Dictionary=app.session.station_owner().snapshot()
	check(completed.campaign_cursor==38 and completed.loadout.station_id==27 and completed.acknowledged,"The real return did not acknowledge the original station38 checkpoint")
	for key in ["credits","passengers","mission","accepted_contact","blueprints","void_source","completed_side_missions","delivery_statistics","travel_statistics"]:
		check(completed.contracts[key]==initial.contracts[key],"Earned contest changed independent career: "+key)
	check(completed.progress.player_kills>=initial.progress.player_kills+4 and completed.cargo==initial.cargo,"The archived return lost its real kills or cargo")
	check(not PostProbeNavigation.destination_supported(definitions,38,completed.mission,22),"Acceptance opened the unsupported next route")
	if failures or not retain_chapter_save("bakka38-acknowledged"):return
	var file:=NativeSave.new()
	var record: Dictionary=file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(record.get("version")==8 and record.station.campaign_cursor==38,"The actual saved contest did not create a version8 archive38")
	check(FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==SOURCE_SHA,"The contest changed its immutable earned36 source")
	await capture_free_application("saved202-bakka38-station")
	if not failures:print("Earned202 B'akka: input-only strict-majority victory, full physical return37, eight original station lines, acknowledged38 save/reload; public route admission remains staged")

func contest_step(input: Dictionary) -> bool:
	resume_application_focus()
	for adjustment in 10:
		var current: float=app.session.snapshot().input_throttle
		if absf(current-float(input.throttle))<.01:break
		if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
	now_us+=100000
	if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
	app.present_session()
	return true

func win_saved_contest(initial: Dictionary) -> bool:
	var pilot:=ContestPilot.new()
	var firing_frames:=0
	if not select_paid_emp():return false
	print("Saved202 contest initial: ",initial.player.vitals," equipment ",initial.equipment," primary ",initial.encounter.primaries.guns[0].projectiles.weapon)
	for tick in 12000:
		var state: Dictionary=app.session.snapshot()
		var defeated: int=state.encounter.combat.actors.filter(func(actor):return actor.actor_id>0 and actor.vitals.hull<=0).size()
		var kills: int=int(state.progress.player_kills)-int(initial.progress.player_kills)
		if state.dialogue.visible:
			check(state.phase=="return_instructions" and state.combat_objective_satisfied and defeated==7 and kills>=4 and firing_frames>0 and state.player.vitals.hull>0,"The actual saved ship did not earn a strict-majority contest victory")
			check(state.campaign_cursor==36 and state.contracts.credits==initial.contracts.credits,"The live contest advanced or paid before final acknowledgement")
			await capture_free_application("saved202-bakka-contest-result")
			print("Saved202 contest result: ",tick," frames; ",firing_frames," firing frames; ",kills," player kills; ",defeated," defeated pirates; player ",state.player.vitals)
			return failures==0
		if app.session.flight_owner().death_active():
			await capture_free_application("saved202-bakka-contest-death")
			check(false,"The actual saved ship died at input frame "+str(tick)+" after "+str(kills)+" player kills; "+str(state.player.vitals));return false
		var input:=pilot.controls(state,tick)
		if not try_paid_emp(state,15000,0.0,"B'akka pirates",true):return false
		if tick%200==0:print("Saved202 contest pilot ",tick," target ",input.target," distance ",int(input.distance)," player ",state.player.vitals," defeated ",defeated," player kills ",kills)
		if not contest_step(input):return false
		if input.fire:firing_frames+=1
		if tick%20==0:await process_frame
	check(false,"The saved-career contest exhausted its normal-input allowance")
	return false

func return_saved_contest() -> bool:
	var initial: RefCounted=app.session.flight_owner()
	var before: Dictionary=initial.snapshot()
	var position: Vector3=initial._station.snapshot().pose.origin
	check(initial.prepare_station().is_empty() and initial._station.point_volume(before.player_pose.origin)<0,"Return must start at the actual battle position, not a supplied contact pose")
	if failures or not app.session.action("station_autopilot"):check(false,app.session.error);return false
	var previous: Vector3=before.player_pose.origin
	var travelled:=0.0
	for tick in 6000:
		if not application_step():return false
		var frame: RefCounted=app.session.flight_owner()
		var state: Dictionary=frame.snapshot()
		travelled+=previous.distance_to(state.player_pose.origin);previous=state.player_pose.origin
		var packet: Dictionary=frame.prepare_station()
		if not packet.is_empty():
			check(packet.campaign_cursor==37 and packet.source_state==5 and packet.docking.station_id==27 and (packet.docking.pre_motion_contact or packet.docking.post_motion_volume_index>=0),"Saved-career return bypassed native station contact")
			check(state.world_elapsed_ms>before.world_elapsed_ms and state.player.vitals.hull>0 and travelled>0,"The full return skipped native motion or survival")
			check(packet.cargo==before.cargo and packet.equipment==before.equipment and packet.progress==state.progress,"The full return lost live cargo, equipment or combat progress")
			check(packet.player_cache.values.hull==state.player.vitals.hull and packet.player_cache.values.armor==state.player.vitals.armor and packet.player_cache.values.shield==int(state.player.vitals.shield),"Station contact replaced surviving ship pools")
			check(initial.snapshot()==before,"The return mutated its retained victory frame")
			await capture_free_application("saved202-bakka-return-contact")
			print("Saved202 full return: ",tick+1," frames; initial distance ",int(before.player_pose.origin.distance_to(position)),"; travelled ",int(travelled),"; player ",state.player.vitals)
			if failures or not app.enter_station(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
			return true
		if tick%200==0:print("Saved202 return ",tick," distance ",int(previous.distance_to(position)))
		if tick%20==0:await process_frame
	check(false,"The saved-career pilot did not reach station27 from its actual battle position")
	return false
