extends "res://tests/ship_purchase_application.gd"
## Real saved career, station map departure, selected-planet gate arrival,
## local travel to the return gate, docking and autosave. No location edits.
func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor==45 and state.contracts.mission.is_empty()

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	if is_instance_valid(app.session._blueprint_pickup) and app.session._blueprint_pickup.visible:await activate_ship_control(app.session._blueprint_pickup.get_ok_button())
	if not app.open_map(now_us):check(false,app.status.text);return
	check(app.map_panel.snapshot().route_mode=="galaxy","Station map did not open the galaxy overview")
	await capture_free_application("galaxy-station-overview")
	if OS.get_environment("GOF2_GALAXY_LOCAL_GATE")=="1":
		if not await choose_map_destination(10,false) or not await release_application_flight() or not await follow_selected_course(10,int(original.loadout.station_id)):return
		if not await release_application_flight():return
		check(app.session.snapshot().navigation_destination_id==-1 and not app.session.snapshot().station_autopilot.active,"Gate map kept the replaced remote course after arrival")
		await capture_free_application("galaxy-same-system-gate-arrival")
		if not await dock_application():return
		var landed: Dictionary=app.session.station_owner().snapshot()
		check(landed.loadout.station_id==original.loadout.station_id and landed.cargo==original.cargo and landed.contracts.credits==original.contracts.credits and landed.campaign_cursor==original.campaign_cursor,"Same-system gate lost the earned career")
		check(landed.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+1,"Same-system gate did not count exactly one physical jump")
		retain_recovery_save("returned");return
	if OS.get_environment("GOF2_GALAXY_RESUMED")=="1":
		check(app.map_panel.snapshot().system_id==original.loadout.system_id,"Fresh Resume opened another galaxy location")
		if not app.close_map(now_us):check(false,app.session.error);return
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
		if not app.open_map(now_us):check(false,app.status.text);return
		await capture_free_application("galaxy-resumed-flight")
		if not app.close_map(now_us) or not await dock_application():return
		var landed: Dictionary=app.session.station_owner().snapshot()
		check(landed.cargo==original.cargo and landed.contracts.credits==original.contracts.credits and landed.contracts.travel_statistics==original.contracts.travel_statistics,"Resume or browsing altered the earned travel result")
		retain_recovery_save("returned");return
	var before: Dictionary=app.session.station_owner().snapshot()
	var rows: Array=app.map_panel._galaxy.snapshot().rows
	var far: Dictionary=rows.filter(func(row):return not row.connected and row.supported)[0]
	await galaxy_click(int(far.system_id))
	map_key(KEY_ENTER)
	check(app.map_panel.snapshot().get("diagnostic")==source.strings[409] and app.session.station_owner().snapshot()==before,"Distant target refusal failed: "+str(app.map_panel.snapshot().get("diagnostic")))
	await capture_free_application("galaxy-distant-target-refused")
	if not await choose_map_destination(36,true):return
	check(app.session is FlightSession,"Confirming a station course did not enter flight")
	if not await release_application_flight():return
	if OS.get_environment("GOF2_GALAXY_PRESENTATION")=="1":
		check(app.session.snapshot().navigation_destination_id==36 and app.session.snapshot().station_autopilot.target_kind=="gate","Revised overview lost the confirmed departure course")
		await capture_free_application("galaxy-station-course-flight")
		if not choose_free_keyboard_flight_action(KEY_Q,"cancel_autopilot"):check(false,"Autopilot menu did not cancel the selected course");return
		if not await dock_application():return
		check(app.session.station_owner().snapshot().contracts.travel_statistics==original.contracts.travel_statistics,"Cancelling the flight course counted a gate jump")
		retain_recovery_save("returned");return
	if not await follow_selected_course(36):return
	check(app.session.snapshot().contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+1,"First selected gate jump did not count exactly once")
	if not await release_application_flight():return
	await capture_free_application("galaxy-selected-planet-arrival")
	if not await dock_application() or not retain_recovery_save("outbound"):return
	if not app.open_map(now_us) or not await choose_map_destination(int(original.loadout.station_id),false):return
	if not await release_application_flight() or not await follow_selected_course(int(original.loadout.station_id)):return
	if not await release_application_flight() or not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	check(returned.loadout.station_id==original.loadout.station_id and returned.cargo==original.cargo and returned.contracts.credits==original.contracts.credits,"Galaxy round trip changed location, cargo or wallet")
	check(returned.campaign_cursor==original.campaign_cursor and returned.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+2,"Return gate lost campaign cursor or counted local travel as another gate")
	if not retain_recovery_save("returned"):return
	await capture_free_application("galaxy-round-trip-saved")

func choose_map_destination(station_id: int,cancel_once: bool) -> bool:
	var system_id:=int(catalogue.tables.stations[station_id].system_id)
	await galaxy_click(system_id)
	if app.map_panel.snapshot().route_mode=="galaxy":map_key(KEY_ENTER)
	check(app.map_panel.snapshot().system_id==system_id and app.map_panel.snapshot().route_mode!="galaxy","Galaxy selection did not open the original local planet map")
	if failures:return false
	# Use the same canvas click and keyboard confirmation as the player.
	await process_frame
	var point:=Vector2.ZERO
	for row in app.map_panel._local._canvas.rows:
		if row.station_id==station_id:point=row.pixels
	await map_pointer(app.map_panel._local._canvas.get_global_transform()*point)
	if not app.map_panel.snapshot().confirmation_visible:map_key(KEY_ENTER)
	check(app.map_panel.snapshot().confirmation_visible,"Planet selection skipped its original confirmation")
	if cancel_once:
		map_key(KEY_ESCAPE)
		check(not app.map_panel.snapshot().confirmation_visible and app.map_panel.visible,"Cancel closed navigation or retained confirmation")
		map_key(KEY_ENTER)
	await capture_free_application("galaxy-course-confirmation")
	var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A;event.pressed=true;app._unhandled_input(event)
	await process_frame;resume_application_focus()
	return failures==0 and not app.map_panel.visible

func galaxy_click(id: int) -> void:
	# Let the map viewport adopt the station/flight layout before projecting.
	await process_frame;await process_frame
	for frame in 180:
		if not app.map_panel._galaxy._centering:break
		await process_frame
	var point:=Vector2.ZERO
	for zoom_step in 14:
		for row in app.map_panel._galaxy._canvas.rows:
			if row.system_id==id:point=row.pixels
		if Rect2(Vector2(70,70),app.map_panel._galaxy.size-Vector2(140,150)).has_point(point):break
		var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
		app.map_panel._galaxy._gui_input(wheel)
	await map_pointer(app.map_panel._galaxy._canvas.get_global_transform()*point)

func map_pointer(point: Vector2) -> void:
	await process_frame;resume_application_focus()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
	await process_frame;resume_application_focus()

func map_key(code: int) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;app._unhandled_input(event)

func follow_selected_course(destination: int,gate_destination: int=-1) -> bool:
	var local_legs:=0;var gate_seen:=false
	for leg in 3:
		app.session.rebase_time(now_us)
		var started:=now_us;var next_yield:=now_us+1000000
		while app.session.status=="running" and now_us-started<300000000:
			if not application_step():return false
			if app.session.flight_owner().death_active():check(false,"Galaxy navigation pilot died");return false
			if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if app.session.status=="local_arrival_transition_required":
			local_legs+=1
			if not app.enter_local_arrival(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return false
			check(app.session.snapshot().navigation_destination_id==destination,"Local gate approach forgot the selected remote planet")
			continue
		check(app.session.status=="gate_confirmation_required","Selected course did not reach its physical gate: "+app.session.status)
		if failures:return false
		gate_seen=true
		await capture_free_application("galaxy-gate-confirmation")
		if not app.choose_gate_confirmation(1,now_us):check(false,app.session.error);return false
		check(app.map_panel.snapshot().route_mode=="galaxy","In-flight gate opened a plain system button row")
		var chosen:=destination if gate_destination<0 else gate_destination
		if not await choose_map_destination(chosen,false):return false
		app.session.rebase_time(now_us);started=now_us
		while app.session.status=="running" and now_us-started<10000000:
			if not application_step():return false
		check(app.session.status=="gate_arrival_transition_required","Gate animation failed to finish")
		check(app.session.gate_jump_plays==1,"The gate jump played its sound %d times (clip %s)"%[app.session.gate_jump_plays,str(app.session._gate_jump_clip.keys())])
		if failures or not app.enter_gate_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
		check(app.session.snapshot().location.station_id==chosen,"Gate arrived at a different planet from the confirmed destination")
		break
	check(gate_seen,"Selected course never entered a gate")
	if destination==10:check(local_legs==1,"Departure away from a gate skipped its local approach")
	return failures==0
