extends "res://tests/khador_application.gd"
## The constructed drive enters a real Void world, then returns directly to the
## remembered planet without replacing the career's random wormhole source.
var _void_deltas:={}

func verify_free_application() -> void:
	var initial: Dictionary=app.session.station_owner().snapshot()
	check(initial.loadout.equipment_ids.has(85) and energy(initial.cargo)>=2,"Void pilot requires the earned fitted drive and paid return fuel")
	if failures:return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	var before: Dictionary=app.session.snapshot()
	drive_key(KEY_K)
	check(app.map_panel.visible and app.map_panel.snapshot().get("void_prompt",false) and app.map_panel.snapshot().confirmation_text==source.strings[411],"Drive omitted the original Void question")
	await capture_free_application("khador-void-question")
	drive_key(KEY_ENTER)
	check(not app.map_panel.visible and energy(app.session.snapshot().cargo)==energy(before.cargo)-1,"Void entry did not consume exactly one cell")
	if failures or not await complete_drive(-1):return
	var visit: Dictionary=app.session.snapshot()
	check(visit.campaign_cursor==initial.campaign_cursor and visit.location.station_id==-1 and visit.location.system_id==-1,"Void entry replaced the earned campaign or selected an ordinary station")
	check(visit.void_environment.return_station_id==initial.loadout.station_id and visit.void_environment.return_system_id==initial.loadout.system_id,"Void entry lost the actual departure planet")
	var retained: Dictionary=app.session.flight_owner().contract_owner().snapshot()
	check(retained.void_source==initial.contracts.void_source and retained.credits==initial.contracts.credits,"Void entry overwrote the random wormhole source or spent credits")
	check(not visit.scenery.objects.is_empty() and visit.scenery.objects.all(func(row):return row.item_id==164),"Void entry did not construct its crystal field")
	await capture_free_application("khador-void-flight")
	var portal_return:=OS.get_environment("GOF2_KHADOR_PORTAL")=="1"
	if portal_return:
		if not await fly_return_portal():return
		var contacting: Dictionary=app.session.snapshot()
		await capture_free_application("khador-void-portal-contact")
		if not app.enter_portal_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		check(app.session.snapshot().location.station_id==initial.loadout.station_id and app.session.snapshot().cargo==contacting.cargo,"Physical Void exit changed the remembered planet or spent drive fuel")
		if not await release_application_flight():return
	else:
		drive_key(KEY_K)
		check(not app.map_panel.visible and app.session.snapshot().khador.phase=="charging" and energy(app.session.snapshot().cargo)==energy(visit.cargo)-1,"Void drive return opened a map or lost its single-cell cost")
		if failures or not await complete_drive(int(initial.loadout.station_id)):return
	if not await dock_application():return
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.inventory.cargo==app.session.station_owner().snapshot().cargo,"Void return did not automatically save its retained fuel")
	if not retain_recovery_save("returned"):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(energy(landed.cargo)==energy(initial.cargo)-(1 if portal_return else 2) and landed.loadout==initial.loadout,"Void round trip lost fitted equipment, hull or paid fuel")
	check(landed.contracts.credits==initial.contracts.credits and landed.campaign_cursor==initial.campaign_cursor and landed.contracts.travel_statistics==initial.contracts.travel_statistics,"Void travel changed credits, campaign or gate count")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty(),"Void return did not write the station save")
	await capture_free_application("khador-void-return-saved")
	var timing:=OS.get_environment("GOF2_PIRATE_TIMING")
	if timing=="144hz":check(_void_deltas.has(6944) and _void_deltas.has(6945) and _void_deltas.size()==2,"Void flight did not use the actual144Hz input clock")
	elif timing=="variable":check(_void_deltas.size()==6,"Void flight did not use variable frame durations")
	print("Void visit input durations: ",_void_deltas.keys())

func application_step() -> bool:return step_void_pilot(Vector2.ZERO)

func step_void_pilot(command: Vector2) -> bool:
	resume_application_focus()
	var delta:=pirate_delta_us();now_us+=delta
	if app.session.snapshot().get("location",{}).get("station_id",0)<0:_void_deltas[delta]=true
	if not app.session.step(now_us,command):check(false,app.session.error);return false
	app.present_session()
	if app._transition_failed:check(false,app.status.text);return false
	return true

func fly_return_portal() -> bool:
	var began:=now_us;var tick:=0
	while now_us-began<400000000:
		if app.session.status=="void_return_transition_required":return true
		var state: Dictionary=app.session.snapshot()
		var offset: Vector3=state.player_pose.basis.inverse()*(state.void_portal.position-state.player_pose.origin)
		var angles:=Vector2(-atan2(offset.y,sqrt(offset.x*offset.x+offset.z*offset.z)),atan2(offset.x,offset.z))
		var command:=Vector2(signf(angles.x)*sqrt(minf(absf(angles.x)*2,1)),signf(angles.y)*sqrt(minf(absf(angles.y)*2,1)))
		if not step_void_pilot(command):return false
		tick+=1
		if tick%20==0:await process_frame
	check(false,"The earned Khador visitor did not reach the physical Void exit")
	return false
