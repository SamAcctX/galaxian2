extends "res://tests/void_ambush_application.gd"
## Enter the authored world from the earned station and exercise its touch UI.
## This is an input regression, not a second claim of mission completion.
func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.campaign_cursor==40 and original.loadout.station_id==30,"Touch mission path requires the earned Néhma departure")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	_world_clock_base=1789105600;app.enable_saves(chapter_directory);app.set_player_mode(true)
	if failures or not await depart_onward() or not await enter_mission40_gate():return
	for tick in 75:
		if app.session.can_control():break
		now_us+=100000;app._selected40_tick(now_us)
	check(app.session.can_control() and not app.touch_overlay.visible,"Authored desktop flight lost controls or exposed touch surfaces")
	if failures:return
	root.size=Vector2i(844,390);app.set_mobile_layout(true);app.set_touch_controls(true)
	await touch(Vector2(1,1),true,7);await touch(Vector2(1,1),false,7)
	check(app.touch_overlay.visible and app.touch_overlay.active and app._flight_actions.visible,"Authored mission still hides admitted touch controls")
	if failures:return
	var stick: Vector2=app.touch_overlay.get_global_transform_with_canvas()*app.touch_overlay.stick_center()
	var fire: Vector2=app.touch_overlay.get_global_transform_with_canvas()*app.touch_overlay.fire_center()
	await touch(stick+Vector2(24,0),true,1);await touch(fire,true,2)
	check(app._controls.snapshot().command.length()>0 and app._controls.snapshot().held.fire,"Mission touch cannot simultaneously steer and fire")
	app.session.rebase_time(now_us);now_us+=100000;app._selected40_tick(now_us)
	check(not app._transition_failed and app.session.snapshot().player.vitals.hull>0,"Mission touch frame was refused")
	await touch(stick,false,1);await touch(fire,false,2)
	await tap(app._actions_button)
	check(app.flight_menu.visible and app.session.is_paused(),"Mission touch Actions is unreachable")
	if failures:return
	await capture_free_application("touch-mission-actions")
	await tap(app.flight_menu._cancel)
	check(not app.session.is_paused() and app.touch_overlay.active,"Mission Cancel did not release touch input")
	await tap(app.session.scene.secondary_panel._select)
	check(app.session.scene.secondary_panel.selection_snapshot().open,"Mission touch secondary menu is unreachable")
	if failures:return
	await capture_free_application("touch-mission-secondary")
	await tap(app.session.scene.secondary_panel._menu_cancel)
	check(not app.session.is_paused() and app.touch_overlay.active,"Mission secondary Cancel left flight paused")
	await tap(app._pause_button)
	check(app.session.is_paused() and not app.touch_overlay.active,"Mission touch Pause retained active controls")
	await tap(app._pause_button)
	check(not app.session.is_paused() and app.touch_overlay.active,"Mission touch Resume failed")
	await capture_free_application("touch-mission-flight")

func touch(point: Vector2,down: bool,index:=0) -> void:
	resume_application_focus()
	var event:=InputEventScreenTouch.new();event.device=0;event.index=index;event.position=root.get_final_transform()*point;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events();await process_frame;app.refresh_render_mode()

func tap(control: Control) -> void:
	await process_frame
	var point:=control.get_global_rect().get_center()
	if control.get_viewport()==app.viewport:
		var view: Control=app.viewport.get_parent()
		point=view.get_global_transform_with_canvas()*(point*view.size/Vector2(app.viewport.size))
	await touch(point,true);await touch(point,false);app.session.rebase_time(now_us)
