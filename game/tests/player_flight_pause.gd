extends "res://tests/player_station_departure.gd"
## The pause window through the real frontend in a live flight: Escape opens it,
## Options returns to it, the Back to Main Menu question steps back, P resumes,
## and OK ends the flight at the main menu with the station save kept.

func verify_departure(app: Control) -> void:
	var host: Control=app.game
	host.set_process(false)
	host._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	host.present_session();await process_frame;await process_frame
	for line in 40:
		if not host.station_panel.visible:break
		click(host.station_panel._next);await process_frame
	click(host.station_shell._actions.depart);await process_frame;await process_frame
	check(host._launch_dialog.visible,"Depart did not ask: "+host.status.text)
	if failures:return
	click(host._launch_dialog._yes);await process_frame
	check(host.session is Flight,"Yes did not depart: "+host.status.text)
	if failures:return
	host.session.rebase_time(0)
	for tick in 80:
		host.session.set_pause("focus",false,tick*100000)
		check(host.session.step((tick+1)*100000),host.session.error)
		if failures:return
		host.present_session()
		if host.session.can_control():break
	check(host.session.can_control(),"Departure did not release flight controls")
	if failures:return
	_press(KEY_ESCAPE);await process_frame
	check(app.phase=="pause" and app._flight_pause.view=="menu" and host.session.is_paused(),"Escape did not pause the flight in the pause window")
	if failures:return
	await capture("flight-pause-window")
	var pause: Control=app._flight_pause
	check(pause.press(pause.text("options")) and app.phase=="options","Pause Options did not open the options")
	_press(KEY_ESCAPE);await process_frame
	check(app.phase=="pause" and pause.view=="menu","Leaving Options lost the pause window")
	check(pause.press(pause.text("main_menu")) and pause.view=="confirm" and pause.button_texts().has(pause.text("ok")),"Back to Main Menu asked no question")
	await capture("flight-pause-main-menu-question")
	_press(KEY_ESCAPE);await process_frame
	check(pause.view=="menu" and app.has_session(),"Escape on the question left the flight")
	_press(KEY_P);await process_frame
	check(app.phase=="game" and not host.session.is_paused(),"P did not resume the flight")
	if failures:return
	_press(KEY_ESCAPE);await process_frame
	check(pause.press(pause.text("main_menu")) and pause.press(pause.text("ok")),"Pause could not confirm Back to Main Menu")
	await process_frame
	check(app.phase=="menu" and not app.has_session() and app.has_save(),"Back to Main Menu did not end the flight at the main menu with the save kept")
	await capture("flight-pause-main-menu")

func _press(key: Key) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()
