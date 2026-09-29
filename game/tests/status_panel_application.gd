extends "res://tests/beam_primary_application.gd"
## Station Status screen from a real earned career: open from the station menu,
## read pilot/ship/statistics, select an earned medal, close, save and reload.

func verify_free_application() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	# A newly reached tier pays its reward and shows one notice at the idle station.
	var wallet: int=app.session.station_owner().snapshot().contracts.credits
	check(app.session._world.record_stats({"max_free_cargo":101}),"Stats could not reach Space Saver bronze")
	app.present_session();await process_frame
	var docked: Dictionary=app.session.station_owner().snapshot()
	check(docked.contracts.credits==wallet+1000 and docked.contracts.base_medals.levels[31]==3,"Space Saver bronze did not pay its original 1000 credits")
	check(app.medal_notice.visible and app.medal_notice.shown()==[31,3],"The new medal notice did not appear")
	await capture("new-medal")
	var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.physical_keycode=KEY_ENTER;enter.pressed=true
	app._unhandled_input(enter);await process_frame
	check(not app.medal_notice.visible and not app.session.station_owner().snapshot().contracts.has("medal_notices"),"Enter did not acknowledge the medal notice")
	check(app.session._world.record_stats({"max_free_cargo":101}) and not app.session.station_owner().snapshot().contracts.has("medal_notices"),"The same tier was announced twice")
	var before: Dictionary=app.session.station_owner().snapshot()
	check(app.station_shell._actions.status.visible,"The station menu has no Status entry")
	app.station_shell._actions.status.pressed.emit()
	await process_frame
	check(app._status_open and app.status_panel.visible and app.session.is_paused(),"Status did not open from the station menu")
	var view: Dictionary=app.status_panel.snapshot()
	print("STATUS ",view)
	check(view.pilot.begins_with("%d$"%int(before.contracts.credits)),"Status shows the wrong wallet")
	check(view.stats_left.split("\n")[1]==str(before.contracts.progress.player_kills),"Status shows the wrong kill count")
	check(view.stats_right.split("\n")[0]==str(before.contracts.travel_statistics.jumpgates_used),"Status shows the wrong jumpgate count")
	check(not view.ship.strip_edges().is_empty(),"Status shows no ship values")
	var levels: Array=app.session.station_owner().snapshot().contracts.base_medals.levels
	app.status_panel.select_medal(1 if levels[1]<=0 else 0)
	if levels[1]<=0:check(app.status_panel.snapshot().selected==-1,"An unearned medal opened its description")
	app.status_panel.select_medal(10)
	check(app.status_panel.snapshot().hint.contains("Garbage Man") and app.status_panel.snapshot().hint.contains("30"),"Earned bronze Garbage Man lacks its original description")
	await capture("status-screen")
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	app._unhandled_input(escape)
	await process_frame
	check(not app._status_open and not app.status_panel.visible and not app.session.is_paused(),"Escape did not close Status")
	var stats: Dictionary=app.session.station_owner().snapshot().contracts.get("stats",{})
	check(stats.get("max_primaries",0)>=1 and stats.get("max_free_cargo",-1)>=0,"Opening Status did not bank the observed career stats")
	check(app.save_station(false),"Saving after Status failed")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.get("stats",{}).get("max_primaries",0)==stats.max_primaries,"The station save lost the career stats")
	await capture("station-after-status")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))
