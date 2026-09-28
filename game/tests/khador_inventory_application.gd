extends "res://tests/khador_application.gd"
## Fitted inventory is shared by world construction, actions and docking save.
func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	if not await open_drive_selector():return
	drive_key(KEY_ESCAPE)
	check(not app.map_panel.visible and app.session.snapshot().cargo==original.cargo,"Cancelling the flight action spent retained fuel")
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.inventory.cargo==landed.cargo and automatic.inventory.loadout==landed.loadout and automatic.career.credits==landed.contracts.credits,"Docking autosave lost the fitted drive, fuel or wallet")
	check(landed.cargo==original.cargo and landed.loadout==original.loadout,"World construction changed the retained player inventory")
	await capture_free_application("khador-menu-cancel-autosaved")
