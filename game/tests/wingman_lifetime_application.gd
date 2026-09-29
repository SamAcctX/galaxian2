extends "res://tests/lounge_wingmen_application.gd"
## The application only receives a byte-copied, genuinely paid career. Detached
## clock/failed-checkpoint components below never enter it or write a save.

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	if directory.is_empty() or input_path.is_empty():check(false,"Wingman lifetime needs isolated earned saves");return
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.wingmen==entry.contracts.wingmen,"Resume changed the actual saved wingman clock")
	for step in 30:
		if not application_step():return
	check(app.session.station_owner().snapshot().contracts.wingmen==entry.contracts.wingmen,"Docked reading consumed the wingman hire")
	var stage:=OS.get_environment("GOF2_WINGMEN_LIFETIME_STAGE")
	if stage.begins_with("resume"):
		check(entry.contracts.wingmen.active.is_empty()==(stage=="resume_expired"),"Fresh Resume changed the crew's expiry state")
		check(not app.session.snapshot().get("wingman_notice",false),"Fresh Resume repeated a committed farewell")
		if not retain_recovery_save("resumed"):return
		await capture_free_application("wingman-"+stage)
	else:
		check(not entry.contracts.wingmen.active.is_empty(),"The paid input has no active crew")
		if failures:return
		verify_lifetime_components(entry)
		if failures or not await depart_for_lifetime():return
		var airborne: Dictionary=app.session.snapshot()
		check(airborne.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"The accepted departure did not consume flight time")
		for step in 20:
			if not application_step():return
		var before_pause: Dictionary=app.session.snapshot().contracts.wingmen
		check(app.session.set_pause("user",true,now_us),app.session.error)
		for step in 30:
			if not application_step():return
		check(app.session.snapshot().contracts.wingmen==before_pause,"Paused flight consumed the crew's hire")
		check(app.session.set_pause("user",false,now_us),app.session.error)
		for step in 20:
			if not application_step():return
		check(app.session.snapshot().contracts.wingmen.active.remaining_ms<before_pause.active.remaining_ms,"The flight clock did not resume")
		await capture_free_application("wingman-clock-flight")
		if not await dock_application():return
		var returned: Dictionary=app.session.station_owner().snapshot()
		check(returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"Docking reset or prematurely ended the paid hire")
		verify_retained_career(entry,returned)
		if failures or not retain_recovery_save("active-returned"):return
		await capture_free_application("wingman-active-returned")
		print("Earned partial wingman lifetime: ",returned.contracts.wingmen)
		if not await depart_for_lifetime():return
		var started:=now_us;var ticks:=0
		while app.session.snapshot().contracts.wingmen.active.remaining_ms>0 and now_us-started<700000000:
			if not application_step():return
			ticks+=1
			if ticks%100==0:
				if app.session.flight_owner().death_active():check(false,"The actual pilot died before the wingman clock expired");return
				await process_frame
			if ticks%1000==0:print("Earned wingman flight remaining: ",app.session.snapshot().contracts.wingmen.active.remaining_ms)
		var exhausted: Dictionary=app.session.snapshot().contracts.wingmen
		check(exhausted.active.remaining_ms==0 and exhausted.active.names==entry.contracts.wingmen.active.names,"The expired timer removed airborne pilots or never reached zero")
		for step in 10:
			if not application_step():return
		check(app.session.snapshot().contracts.wingmen==exhausted,"The exhausted airborne contract underflowed or changed its roster")
		await capture_free_application("wingman-time-exhausted-flight")
		if failures or not await dock_application():return
		# The host publishes the new station before its first presentation tick.
		for step in 20:
			if app.session.snapshot().get("wingman_notice",false):break
			if not application_step():return
		var notice: Dictionary=app.session.snapshot()
		check(notice.get("wingman_notice",false) and notice.dialogue.get("text_id")==302 and notice.dialogue.get("speaker_name")==entry.contracts.wingmen.active.names[0],"Docking did not display the original crew farewell")
		check(notice.contracts.wingmen.active.is_empty() and notice.contracts.wingmen.hired_total==entry.contracts.wingmen.hired_total,"The farewell lost the durable hired count or retained the expired roster")
		check(app.station_panel.visible and app.station_panel._body.text==source.strings[302] and app.station_panel._portrait.texture!=null,"The original farewell text or retained portrait is absent")
		var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
		check(not automatic.is_empty() and automatic.career.wingmen==notice.contracts.wingmen,"The immediate native checkpoint lost the dismissal")
		check(app.session.prepare_departure(definitions,catalogue).is_empty(),"Departure skipped the crew farewell")
		check(not app.session.contract_action("open",-1,app.lounge_panel),"The lounge opened beneath the farewell")
		check(not app.session.navigate("previous",app.station_panel),"The one-line farewell invented a previous conversation")
		await capture_free_application("wingman-station-farewell")
		check(app.session.set_pause("user",true,now_us),app.session.error)
		check(not app.session.navigate("next",app.station_panel),"Paused input acknowledged the farewell")
		check(app.session.set_pause("user",false,now_us),app.session.error)
		press_coordinate_key(KEY_ENTER)
		check(not app.session.snapshot().get("wingman_notice",false),"Keyboard acknowledgement did not close the farewell")
		if failures or not retain_recovery_save("expired-returned"):return
		await capture_free_application("wingman-farewell-acknowledged")
	var final: Dictionary=app.session.station_owner().snapshot()
	verify_retained_career(entry,final)
	check(FileAccess.get_sha256(input_path)==input_hash,"The paid input save was changed")
	print("Earned wingman lifetime result: ",{"stage":stage,"input_sha256":input_hash,"wingmen":final.contracts.wingmen,"credits":final.contracts.credits,"actors_accepted":false})

func depart_for_lifetime() -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	for step in 10:
		if not app.session.action("throttle_down"):check(false,app.session.error);return false
	return true

func verify_retained_career(before: Dictionary,after: Dictionary) -> void:
	for key in ["credits","mission","passengers","blueprints"]:
		check(before.contracts[key]==after.contracts[key],"Wingman lifetime changed unrelated "+key)
	check(before.progress==after.progress and before.cargo==after.cargo and before.loadout.equipment_ids==after.loadout.equipment_ids,"Wingman lifetime changed the campaign, cargo or fitting")

func verify_lifetime_components(entry: Dictionary) -> void:
	var parent: RefCounted=app.session.station_owner().contract_owner()
	var original: Dictionary=parent.snapshot()
	var single: RefCounted=parent.fork()
	check(single.advance_wingmen(1000),single.error)
	var partitioned: RefCounted=parent.fork()
	for delta in [6,7,17,100,150,120,150,150,150,150]:check(partitioned.advance_wingmen(delta),partitioned.error)
	check(single.snapshot().wingmen==partitioned.snapshot().wingmen,"The career clock depends on the frame partition")
	check(parent.snapshot()==original,"A candidate clock mutated the retained parent")
	for invalid in [-1,1.5,"100",null]:
		var before: Dictionary=single.snapshot()
		check(not single.advance_wingmen(invalid) and single.snapshot()==before,"An invalid duration changed the paid clock")
	check(single.advance_wingmen(2147483647) and single.snapshot().wingmen.active.remaining_ms==0,"Wingman time did not saturate safely")
	check(single.snapshot().wingmen.active.names==entry.contracts.wingmen.active.names,"Clock exhaustion removed airborne names")
	var no_hire=load("res://src/simulation/contract_session.gd").new()
	check(no_hire.advance_wingmen(100) and not no_hire.snapshot().has("wingmen"),"A clock update invented a hire in an old career")
	# This detached station component cannot become the application or a save.
	var component=load("res://src/presentation/station_session.gd").new()
	component._world=app.session.station_owner();component._world._contracts=single
	component._active=true;component.status="running";component._dialogue_started=true
	component._library=source;component._bindings=definitions;component._visuals=app.visuals
	var panel=load("res://src/presentation/station_dialogue_panel.gd").new()
	check(panel.configure_empty(source,definitions),panel.error)
	var unpaid: Dictionary=component._world.snapshot()
	check(not component.poll_wingman_farewell(panel,func(_candidate):return false),"A refused checkpoint committed the component farewell")
	check(component._world.snapshot()==unpaid and component._wingman_notice.is_empty() and not panel.visible,"Failed checkpoint lost the expired crew or published its notice")
	component._pauses={"user":true}
	check(component.poll_wingman_farewell(panel) and component._world.snapshot()==unpaid,"Paused station dismissed the expired crew")
	component._pauses={}
	check(component.poll_wingman_farewell(panel,func(_candidate):return true),component.error)
	check(component._world.snapshot().contracts.wingmen.active.is_empty() and not component._wingman_notice.is_empty(),"The valid component farewell did not clear the roster")
	check(component.poll_wingman_farewell(panel,func(_candidate):check(false,"A displayed farewell saved twice");return false),component.error)
	panel.free();component.free()
	check(app.session.station_owner().snapshot()==entry,"A detached lifetime component contaminated the application")
