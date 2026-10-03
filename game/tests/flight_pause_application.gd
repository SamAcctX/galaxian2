extends "res://tests/beam_primary_application.gd"
## In-flight pause window from an earned career: the window over the frozen
## flight, the career's Missions log and Cargo hold, and Action Freeze (HUD
## hidden, orbit camera around the ship, Back restores the flight camera).
const Pause=preload("res://src/presentation/flight_pause_panel.gd")

func verify_free_application() -> void:
	var docked: Dictionary=app.session.station_owner().snapshot()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var state: Dictionary=app.pause_state()
	check(int(state.campaign_cursor)==int(docked.campaign_cursor) and state.contracts.mission==docked.contracts.mission,"Pause lost the career story or job")
	check(state.cargo.get("entries",[]).size()==docked.cargo.entries.size() and int(state.cargo.capacity)>0,"Pause lost the cargo hold: "+str(state.cargo))
	app.hold_paused(true)
	check(app.session.is_paused() and not app._mouse_captured,"Pause did not freeze the flight and free the mouse")
	check(app.status_panel.configure(source,definitions,visual),app.status_panel.error)
	var pause:=Pause.new();app.add_child(pause);pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	check(pause.configure(source,definitions,visual,app.status_panel,false),pause.error)
	if failures:return
	var strings: Array=source.strings
	pause.present(state);await process_frame
	check(pause.snapshot().buttons==[strings[41],strings[31],strings[128],strings[165],strings[511],strings[58]],"entries "+str(pause.snapshot().buttons))
	await capture_free_application("pause-menu")
	check(pause.press(strings[128]),"Missions")
	await process_frame
	check(not pause.snapshot().missions.job.is_empty() and pause.snapshot().missions.job!=strings[173],"Missions lost the accepted job")
	await capture_free_application("pause-missions")
	pause.back()
	check(pause.press(strings[165]) and pause.cargo_rows().size()==docked.cargo.entries.size(),"Cargo hold rows")
	await capture_free_application("pause-cargo")
	pause.back()
	var camera: Camera3D=app.freeze_camera()
	var flight_camera: Transform3D=camera.global_transform
	pause.action_requested.connect(func(action):if action=="unfreeze":app.set_action_freeze(false))
	app.set_action_freeze(true)
	check(pause.begin_freeze(camera,app.freeze_pivot()),"freeze")
	check(not app.flight_vitals.visible,"Action Freeze kept the HUD")
	pause.orbit(0.9,0.25,1.0)
	await capture_free_application("action-freeze")
	pause.orbit(0.0,0.0,0.4)
	await capture_free_application("action-freeze-near")
	check(pause.back() and pause.view=="menu","Back from Action Freeze")
	check(camera.global_transform.is_equal_approx(flight_camera),"Action Freeze moved the flight camera")
	pause.clear();pause.queue_free()
	app.hold_paused(false)
	check(not app.session.is_paused(),"Resume left the flight paused")
	print("Flight pause application: cursor=",state.campaign_cursor," cargo=",state.cargo.get("used")," / ",state.cargo.get("capacity"))
