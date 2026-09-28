extends "res://tests/khador_application.gd"
## Sell earned fuel through the Hangar, then exercise both empty-fuel choices.
func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	if not app.equipment_action("open"):check(false,app.session.error);return
	for unit in energy(original.cargo):
		if not app.equipment_action("sell",122):check(false,app.session.error);return
	if not app.equipment_action("close"):check(false,app.session.error);return
	var empty: Dictionary=app.session.station_owner().snapshot()
	check(energy(empty.cargo)==0 and empty.loadout.equipment_ids.has(85),"The actual sale did not leave a fitted, empty-fuel ship")
	if not app.open_map(now_us):check(false,app.status.text);return
	await galaxy_click(int(catalogue.tables.stations[30].system_id))
	check(app.map_panel.snapshot().get("selected_system_id")==catalogue.tables.stations[30].system_id,"Mouse did not select the unaffordable distant system")
	if failures:return
	if app.map_panel.snapshot().route_mode=="galaxy":map_key(KEY_ENTER)
	await process_frame
	var point:=Vector2.ZERO
	for row in app.map_panel._local._canvas.rows:
		if row.station_id==30:point=row.pixels
	await map_pointer(app.map_panel._local._canvas.get_global_transform()*point)
	map_key(KEY_ENTER)
	check(not app.map_panel.snapshot().confirmation_visible and app.map_panel.snapshot().diagnostic==source.strings[568],"Unaffordable multi-hop choice did not show the original refusal")
	check(app.session.station_owner().snapshot()==empty,"Refusing a drive jump changed the station, wallet or cargo")
	await capture_free_application("khador-no-fuel-refusal")
	if failures:return
	map_key(KEY_ESCAPE)
	if not await choose_map_destination(70,true) or not await release_application_flight():return
	var flight: Dictionary=app.session.snapshot()
	check(flight.khador.phase=="ready" and energy(flight.cargo)==0 and flight.navigation_destination_id==70 and flight.station_autopilot.target_kind=="planet","Empty-fuel gate alternative began charging or lost ordinary local guidance")
	await capture_free_application("khador-no-fuel-gate-course")
	if not choose_free_keyboard_flight_action(KEY_Q,"cancel_autopilot") or not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.cargo==empty.cargo and landed.contracts.credits==empty.contracts.credits and landed.campaign_cursor==empty.campaign_cursor,"Refused jump or cancelled gate course changed the earned state")
	retain_recovery_save("returned")
