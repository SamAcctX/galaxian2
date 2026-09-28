extends "res://tests/khador_application.gd"
## Keep one genuinely purchased cell, attempt Void entry and retain it on disk.
func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	if not app.equipment_action("open"):check(false,app.session.error);return
	for unit in energy(original.cargo)-1:
		if not app.equipment_action("sell",122):check(false,app.session.error);return
	if not app.equipment_action("close"):check(false,app.session.error);return
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(energy(paid.cargo)==1 and paid.loadout.equipment_ids.has(85),"The actual sale did not retain one paid cell and the drive")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	var before: Dictionary=app.session.snapshot()
	drive_key(KEY_K)
	check(app.map_panel.snapshot().get("void_prompt",false),"One-cell Void attempt omitted the destination question")
	await activate_ship_control(app.map_panel._yes,true)
	check(app.map_panel.snapshot().get("drive_message")=="fuel" and app.map_panel.snapshot().confirmation_text==source.strings[569],"Void entry with only one cell omitted the original return-fuel warning")
	check(app.session.snapshot().cargo==before.cargo and app.session.snapshot().khador==before.khador,"Refused Void entry consumed its reserved cell or began charging")
	await capture_free_application("khador-void-return-fuel-refusal")
	drive_key(KEY_ENTER)
	check(app.map_panel.visible and not app.map_panel.snapshot().get("void_prompt",false),"Acknowledging fuel warning lost ordinary galaxy selection")
	drive_key(KEY_ESCAPE)
	if failures or not await dock_application() or not retain_recovery_save("returned"):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.cargo==paid.cargo and landed.loadout==paid.loadout and landed.contracts.credits==paid.contracts.credits and landed.campaign_cursor==paid.campaign_cursor,"Refused Void entry or docking altered the paid inventory or career")
	await capture_free_application("khador-void-refusal-saved")
