extends "res://tests/dekato_arrival_application.gd"
## Genuine source202 career and local arrival, followed only by flight inputs.
const ConvoyPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")

func verify_free_application() -> void:
	await super.verify_free_application()
	if failures:return
	var initial: Dictionary=app.session.snapshot()
	var retained_hash:=FileAccess.get_sha256(app.station_save_path())
	if not await win_earned_convoy(initial):return
	var events: Array=DekatoArrival.declarations(definitions).mission.result_events
	check(events.size()==2,"The source victory must have its original two result pages")
	if failures:return
	for index in events.size():
		var pending: Dictionary=app.session.snapshot()
		check(pending.campaign_cursor==38 and pending.contracts.campaign_cursor==38 and pending.dialogue.text_id==int(events[index].text_id) and pending.dialogue.voice_event_id==int(events[index].voice_event_id),"Victory advanced before the original final acknowledgement")
		if index==events.size()-1:
			var original: RefCounted=app.session.flight_owner()
			var original_before: Dictionary=original.snapshot()
			var rejected: RefCounted=original.fork_for_frame()
			rejected._entry=original._entry.duplicate(true)
			rejected._entry.departure.dekato_source_receipt.source_binding_id="foreign"
			var refused_before: Dictionary=rejected.snapshot()
			check(rejected.navigate("next")==null and rejected.snapshot()==refused_before and original.snapshot()==original_before and app.session.snapshot()==pending,"A changed source receipt partially acknowledged the actual battle")
		await capture_free_application("earned202-dekato-result-"+str(index))
		if failures or not app.session.navigate("next"):check(false,app.session.error);return
	var completed: Dictionary=app.session.snapshot()
	check(completed.dekato_source_receipt==definitions.dekato_source_receipt(),"The earned result lost its original supplemental declaration receipt")
	check(completed.campaign_cursor==39 and completed.contracts.campaign_cursor==39 and completed.progress.campaign_cursor==39 and completed.combat_objective_acknowledged,"The actual victory did not commit cursor39 atomically")
	check(completed.mission=={"kind":11,"station_id":30,"reward":0,"bonus":0,"source_parameter":0} and completed.reward_credits==0,"The original result lost its pending station30 visit or paid an invented reward")
	check(completed.location.station_id==22 and completed.player.campaign_cursor==38 and app.session.flight_owner()._entry.campaign_cursor==38,"Acknowledgement rebuilt or relabelled the living world")
	for key in ["credits","passengers","mission","accepted_contact","blueprints","void_source","completed_side_missions","delivery_statistics","travel_statistics"]:
		check(completed.contracts[key]==initial.contracts[key],"The convoy result changed independent career: "+key)
	check(completed.cargo==initial.cargo and completed.player.vitals.hull>0,"Victory changed carried cargo or ignored player survival")
	check(app.session.flight_owner().prepare_station().is_empty() and not PostProbeNavigation.destination_supported(definitions,39,completed.mission,30),"The flight-only result manufactured unfinished station persistence or onward travel")
	check(not app.session.navigate("next") and app.session.snapshot()==completed,"Duplicate acknowledgement changed the completed career")
	if failures or not battle_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return
	check(app.session.snapshot().contracts.campaign_cursor==39 and app.session.snapshot().world_elapsed_ms>completed.world_elapsed_ms,"The living world stopped retaining its acknowledged career")
	check(FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==SOURCE_SHA and FileAccess.get_sha256(app.station_save_path())==retained_hash,"The flight-only victory overwrote its viable Eanya station checkpoint")
	await capture_free_application("earned202-dekato39-live")
	if not failures:print("Actual original202 earned Eanya20->Dekato22 input-only victory, final38->39 acknowledgement and live career retained; station39 persistence remains a separate boundary")

func battle_step(input: Dictionary) -> bool:
	resume_application_focus()
	if app.session.can_control():
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01:break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
	now_us+=100000
	if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
	app.present_session()
	return true

func win_earned_convoy(initial: Dictionary) -> bool:
	var pilot:=ConvoyPilot.new();var firing_frames:=0
	if not select_paid_emp():return false
	print("Actual202 convoy initial pools ",initial.player.vitals,"; owned equipment ",initial.equipment.loadout.equipment_ids,"; paid EMP ",initial.encounter.secondaries.guns[0].ammunition)
	for tick in 6000:
		var state: Dictionary=app.session.snapshot()
		var escorts: Array=state.encounter.combat.actors.filter(func(actor):return actor.actor_id in range(2,7))
		if state.dialogue.visible:
			check(state.phase=="return_instructions" and state.campaign_cursor==38 and state.combat_objective_satisfied and escorts.all(func(actor):return actor.actor_mode==4),"The actual input pilot did not earn the source five-escort victory")
			check(state.player.vitals.hull>0 and firing_frames>0 and state.progress.player_kills>initial.progress.player_kills,"Victory lacks surviving-player and real weapon-contact evidence")
			await capture_free_application("earned202-dekato-victory")
			print("Actual202 convoy result: frames=",tick," firing=",firing_frames," player kills=",int(state.progress.player_kills)-int(initial.progress.player_kills)," pools=",state.player.vitals," actor hulls=",state.encounter.combat.actors.map(func(actor):return actor.vitals.hull))
			return failures==0
		if app.session.flight_owner().death_active():
			await capture_free_application("earned202-dekato-death")
			check(false,"The actual convoy pilot died at frame "+str(tick)+"; pools "+str(state.player.vitals));return false
		var input: Dictionary=pilot.controls(state,tick,range(2,7),true)
		# A wider orbit avoids exceeding this equipped ship's angular tracking
		# speed when an EMP stops the target. Only ordinary control inputs change.
		input.strafe=1.0
		if input.target>=0:
			input.throttle=1.0 if input.distance>10000.0 else 0.0
		if not try_paid_emp(state,9000,0.0,"Dekato escorts",true):return false
		if tick%200==0:print("Actual202 convoy pilot ",tick," target=",input.target," distance=",int(input.distance)," firing=",firing_frames," aim=",input.commands," pools=",state.player.vitals," actor hulls=",state.encounter.combat.actors.map(func(actor):return actor.vitals.hull))
		if not battle_step(input):return false
		if input.fire:firing_frames+=1
		if tick%20==0:await process_frame
	check(false,"The actual convoy pilot exhausted its normal-input allowance")
	return false
