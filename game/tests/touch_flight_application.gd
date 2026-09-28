extends "res://tests/khador_application.gd"
## Real saved equipment, short landscape touch input and on-disk retention.
func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor>=18

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	app.set_player_mode(true);app.set_mobile_layout(false);app.set_touch_controls(false)
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	check(not app.touch_overlay.visible and not app._flight_actions.visible,"Desktop exposed touch surfaces")
	await capture_free_application("touch-hidden-desktop")
	root.size=Vector2i(844,390);app.set_mobile_layout(true);app.set_touch_controls(true)
	await process_frame;resume_application_focus();app.present_session()
	check(not app.touch_actions_enabled(),"Layout/preference fabricated a touch device")
	await finger(7,Vector2(1,1),true);await finger(7,Vector2(1,1),false)
	check(app.touch_actions_enabled() and app.touch_overlay.active and app._flight_actions.visible,"Device touch did not enable flight controls")
	if failures:return
	var stick: Vector2=app.touch_overlay.get_global_transform_with_canvas()*app.touch_overlay.stick_center()
	await finger(1,stick+Vector2(24,0),true)
	var primary: Vector2=app.touch_overlay.get_global_transform_with_canvas()*app.touch_overlay.fire_center()
	await finger(2,primary,true)
	check(app._controls.snapshot().command.length()>0 and app._controls.snapshot().held.fire,"Two fingers did not independently steer and fire")
	if not touch_step():return
	await finger(2,primary,false)
	check(not app._controls.snapshot().held.fire and app._controls.snapshot().command.length()>0,"Releasing fire also released steering")
	await finger(1,stick,false)
	check(app._controls.snapshot().command.is_zero_approx(),"Releasing steering left a held command")
	await tap(app._actions_button)
	check(app.flight_menu.visible and app.session.is_paused() and not app.touch_overlay.active,"Touch Actions did not exclusively own input")
	if failures:return
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(app.flight_menu._cancel.get_global_rect()),"Touch Cancel is outside short landscape")
	await capture_free_application("touch-actions-short")
	await tap(app.flight_menu._cancel)
	check(not app.flight_menu.visible and app.session.can_control(),"Touch Cancel left flight paused")
	if not await touch_action("map"):return
	check(app.map_panel.visible and not app.touch_overlay.active,"Touch menu Map did not own flight")
	if failures:return
	await capture_free_application("touch-galaxy")
	await tap(app.map_panel._back)
	check(not app.map_panel.visible and app.session.can_control(),"Touch map Back did not resume flight")
	if failures:return
	await tap(app._station_button)
	check(app.flight_menu.visible,"Touch autopilot did not show its destinations")
	await tap(app.flight_menu._cancel)
	if app.session.snapshot().get("booster",{}).get("ready",false):
		await tap(app._boost_button)
		if not touch_step():return
		check(app.session.snapshot().booster.activation==1,"Touch boost did not activate the fitted device")
		await capture_free_application("touch-booster-active")
	if original.loadout.equipment_ids.has(85):
		if not await touch_action("khador"):return
		check(app.map_panel.snapshot().get("void_prompt",false),"Touch omitted the drive's original question")
		await tap(app.map_panel._no)
		await tap(app.map_panel._back)
		check(app.session.snapshot().cargo==original.cargo,"Touch cancellation spent drive fuel")
	if app.session.turret_state().get("ready",false):
		if not await touch_action("turret"):return
		check(app.session.turret_state().active,"Touch failed to enter mounted turret")
		await finger(1,stick+Vector2(24,0),true);await finger(2,primary,true)
		var turret: Dictionary=app.session.turret_state()
		if not touch_step():return
		check(app.session.turret_state().yaw!=turret.yaw,"Touch steering did not aim the mounted turret")
		await capture_free_application("touch-turret-firing")
		await finger(2,primary,false);await finger(1,stick,false)
		if not await touch_action("turret"):return
		check(not app.session.turret_state().active,"Touch failed to leave mounted turret")
	if app.session.cloak_state().get("ready",false):
		if not await touch_action("cloak") or not touch_step():return
		check(app.session.cloak_state().phase=="charging" and energy(app.session.snapshot().cargo)==energy(original.cargo)-int(app.session.cloak_state().energy_cost),"Touch cloak did not spend its real fuel")
		for tick in 15:
			if not touch_step():return
		await capture_free_application("touch-cloak-charging")
	if app.session.secondary_available():
		var feedback: Dictionary=app.session.secondary_feedback()
		await tap(app.secondary_panel._select)
		check(app.secondary_panel.selection_snapshot().open,"Touch secondary selection did not open")
		if failures:return
		var choices: Array=app.secondary_panel.selection_snapshot().choices
		var target: int=feedback.weapons[0].item_id
		for index in choices.size():
			if choices[index].item_id==target:await tap(app.secondary_panel._menu_rows.get_child(index));break
		await tap(app.secondary_panel._menu_confirm)
		var count: int=app.session.secondary_feedback().weapons[0].quantity
		await tap(app.secondary_panel._fire)
		if not touch_step():return
		check(app.session.secondary_feedback().weapons[0].quantity==count-1,"Touch secondary did not fire exactly one owned round")
		await capture_free_application("touch-secondary-fired")
	await tap(app._pause_button)
	check(app.session.is_paused() and not app.touch_overlay.active and not app._controls.snapshot().held.fire,"Touch pause left flight input held")
	await tap(app._pause_button)
	check(not app.session.is_paused(),"Touch pause could not resume")
	await capture_free_application("touch-flight-short")
	app.session.rebase_time(now_us)
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.inventory.cargo==landed.cargo and saved.inventory.loadout==landed.loadout,"Touch flight did not autosave retained equipment/cargo")
	check(landed.campaign_cursor==original.campaign_cursor and landed.contracts.credits==original.contracts.credits,"Touch flight changed the story or wallet")
	if not retain_recovery_save("returned"):return
	await capture_free_application("touch-docked-autosaved")

func finger(id: int,point: Vector2,down: bool) -> void:
	resume_application_focus()
	var event:=InputEventScreenTouch.new();event.device=0;event.index=id;event.position=root.get_final_transform()*point;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame;app.present_session()

func tap(control: Control) -> void:
	await process_frame;resume_application_focus()
	var point:=control.get_global_rect().get_center()
	await finger(0,point,true);await finger(0,point,false)
	app.session.rebase_time(now_us)

func touch_action(action: String) -> bool:
	await tap(app._actions_button)
	if not app.flight_menu.visible:check(false,"Touch Actions did not open for "+action);return false
	var rows: Array=app.flight_menu.snapshot().rows
	for index in rows.size():
		if rows[index].action==action:
			app.flight_menu._scroll.ensure_control_visible(app.flight_menu._buttons[index]);await process_frame
			await tap(app.flight_menu._buttons[index]);return true
	check(false,"Equipped touch action unavailable: "+action);return false

func touch_step() -> bool:
	app.handle_action_events(app._controls.take_events())
	app.session.rebase_time(now_us);now_us+=100000
	var input: Dictionary=app._controls.snapshot()
	if not app.session.step(now_us,input.command,input.held.fire):check(false,app.session.error);return false
	app.present_session();return true
