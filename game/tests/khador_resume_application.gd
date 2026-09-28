extends "res://tests/khador_application.gd"
## Fresh Resume of a real paid trip, with keyboard/menu or station-map entry.
func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.loadout.equipment_ids.has(85) and energy(original.cargo)>=2,"Fresh Resume lost the fitted drive or its paid fuel")
	if failures:return
	var destination:=19 if original.loadout.station_id==30 else 30
	if OS.get_environment("GOF2_KHADOR_STATION")=="1":
		if not app.open_map(now_us):check(false,app.status.text);return
		check(app.map_panel.snapshot().drive_mode,"Station map ignored the fitted drive")
		if not await choose_map_destination(destination,true) or not await release_application_flight():return
		check(app.session.snapshot().khador.phase=="charging" and energy(app.session.snapshot().cargo)==energy(original.cargo)-2,"Station-selected drive course did not charge on departure")
		if not await complete_drive(destination):return
	else:
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
		var retained: Dictionary=app.session.snapshot()
		if not await open_drive_selector():return
		drive_key(KEY_ESCAPE)
		check(not app.map_panel.visible and app.session.snapshot().cargo==retained.cargo and app.session.snapshot().khador==retained.khador,"Cancelling the drive map spent fuel or began charging")
		if not await jump_drive(destination):return
	if not await dock_application() or not retain_recovery_save("returned"):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(energy(landed.cargo)==energy(original.cargo)-2 and landed.loadout.equipment_ids==original.loadout.equipment_ids,"Resume lost fuel or fitted equipment across the actual trip")
	check(landed.contracts.credits==original.contracts.credits and landed.campaign_cursor==original.campaign_cursor and landed.contracts.travel_statistics==original.contracts.travel_statistics,"Drive Resume changed wallet, campaign or physical gate statistics")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty(),"Drive arrival did not write its station autosave")
	await capture_free_application("khador-fresh-resume-saved")
