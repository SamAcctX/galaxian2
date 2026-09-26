extends "res://tests/mission_arrival_input.gd"
## Actual root input across a mission modal, followed by short high-rate and
## variable-rate flight. The inherited source entry is detached, not earned.

func verify_component(world: RefCounted) -> void:
	var original: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner()
	var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var before: Dictionary=frame.snapshot()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	for rhythm in ["144hz","variable"]:
		await verify_modal_return(frame,rhythm)
		if failures:return
	check(frame.snapshot()==before and world.snapshot()==original,"Modal input mutated its retained source frame/world")

func axis(which: JoyAxis,value: float,device_id:=29) -> void:
	var event:=InputEventJoypadMotion.new();event.axis=which;event.axis_value=value;event.device=device_id
	root.push_input(event,true)

func triggers(value: float) -> void:
	axis(JOY_AXIS_TRIGGER_RIGHT,value);axis(JOY_AXIS_TRIGGER_LEFT,value)

func motion(distance: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.screen_relative=distance;event.relative=distance
	root.push_input(event,true)

func mouse_button(down: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	root.push_input(event,true)

func tick(app: Control,delta_us: int) -> bool:
	app._controls.advance_mouse(float(delta_us)/1000000.0)
	now_us+=delta_us;app._selected40_tick(now_us)
	check(not app._transition_failed,"Mission input frame rejected: "+app.status.text)
	return not app._transition_failed

func pointer_next(app: Control) -> void:
	var button: Control=app.session.scene.feedback.dialogue._next
	var view: Control=app.viewport.get_parent()
	await click_at(view.get_global_transform_with_canvas()*button.get_global_rect().get_center())
	app.present_session()

func verify_modal_return(frame: RefCounted,rhythm: String) -> void:
	var app: Control=await make_host(frame)
	if app==null:return
	# Select the ordinary desktop mouse-steering preference before entry release.
	app._mouse_steering=true;app.present_session()
	await key(KEY_ENTER)
	await pointer_next(app)
	var session: Node3D=app.session;var scene: Node3D=session.scene;var camera: Camera3D=session.camera
	var audio: Node3D=scene.feedback.audio;var lights: Node3D=scene.environment.lights
	check(session.snapshot().dialogue.get("text_id")==2039 and not app._mouse_captured,"Pointer did not reach the second uncaptured briefing page")
	if failures:app.free();return
	var modal: Dictionary=session.snapshot()
	var ammunition: int=session.flight_owner().secondary_feedback().weapons[0].quantity
	# A primary trigger may acknowledge one briefing page. Its hold must not
	# leak into flight after the separate pointer Next; left trigger is no ack.
	triggers(0.8);motion(Vector2(200,-100))
	var acknowledged: Dictionary=session.snapshot()
	check(acknowledged.dialogue.get("text_id")==2040 and acknowledged.elapsed_ms==modal.elapsed_ms and acknowledged.player_pose==modal.player_pose and not session._secondary_pending and not app._controls.snapshot().held.fire,"Trigger acknowledgement did not keep the final briefing page separate from flight")
	if failures:app.free();return
	await pointer_next(app)
	check(session.can_control() and app._mouse_captured and not session.snapshot().dialogue.visible,"Mouse Next did not release the retained mission into captured flight")
	check(not app._controls.snapshot().held.fire,"Final dialogue click became a held primary trigger")
	session.rebase_time(now_us)
	triggers(0.9)
	if not tick(app,6944):app.free();return
	var returned: Dictionary=session.snapshot()
	check(not returned.input.primary_held,"A trigger first pressed during briefing fired on return without release")
	check(not returned.input.secondary_requested,"A trigger first pressed during briefing queued an EMP on return without release")
	check(session.flight_owner().secondary_feedback().weapons[0].quantity==ammunition,"A held modal trigger spent paid EMP ammunition")
	await capture(app,"modal-return-"+rhythm)
	print("Modal return ",rhythm,": primary=",returned.input.primary_held," secondary=",returned.input.secondary_requested," EMP=",session.flight_owner().secondary_feedback().weapons[0].quantity)
	if failures:app.free();return
	# Returning to neutral while another modal owns input must unblock the pad;
	# a subsequent blocked press must quarantine it again until a real release.
	await key(KEY_G)
	check(session.is_paused() and scene.secondary_panel.selection_snapshot().open,"Actual G did not open the mission weapon selector")
	var menu: Dictionary=session.snapshot()
	triggers(0.0);triggers(0.75);motion(Vector2(300,150));mouse_button(true);mouse_button(false)
	check(session.snapshot()==menu and not session._secondary_pending,"Weapon selector advanced the mission or accepted a flight action")
	await key(KEY_DOWN);await key(KEY_ENTER)
	check(not session.is_paused() and session.can_control() and app._mouse_captured and session.flight_owner().secondary_feedback().selected_item_id==42,"Weapon selector did not select the owned EMP and restore captured flight")
	session.rebase_time(now_us);triggers(0.9)
	if not tick(app,9000):app.free();return
	check(not session.snapshot().input.primary_held and not session.snapshot().input.secondary_requested and session.flight_owner().secondary_feedback().weapons[0].quantity==ammunition,"Weapon selector leaked held triggers into live weapons")
	if failures:app.free();return
	triggers(0.0)
	var before_flight: RefCounted=session.flight_owner();var before_state: Dictionary=before_flight.snapshot()
	var start_us:=now_us;var elapsed_us:=0;var index:=0
	while elapsed_us<500000:
		var delta_us: int=int((index+1)*1000000/144)-int(index*1000000/144) if rhythm=="144hz" else int([4000,17000,31000,9000,67000][index%5])
		delta_us=mini(delta_us,500000-elapsed_us)
		motion(Vector2(120,-60)*float(delta_us)/1000000.0)
		if not tick(app,delta_us):app.free();return
		var state: Dictionary=session.snapshot()
		check(state.input.commands.is_equal_approx(Vector2(-0.1,-0.2)) and not state.input.primary_held and not state.input.secondary_requested,"Root mouse motion changed with frame cadence or revived a modal shot: "+rhythm)
		elapsed_us+=delta_us;index+=1
	var flown: Dictionary=session.snapshot()
	check(flown.elapsed_ms-before_state.elapsed_ms==int(now_us/1000)-int(start_us/1000),"Host lost or accumulated time during short "+rhythm+" flight")
	var flight_camera: RefCounted=session.flight_owner()._camera
	check(not flown.player_pose.is_equal_approx(before_state.player_pose) and flight_camera.response_snapshot().relative_capture,"Captured mouse did not move the real ship and update its camera mode")
	check(camera.global_transform.is_equal_approx(flight_camera.snapshot().pose),"The rendered camera did not consume the accepted mouse flight")
	check(before_flight.snapshot()==before_state,"Mouse flight mutated a retained parent frame")
	check(app.session==session and session.scene==scene and session.camera==camera and scene.feedback.audio==audio and scene.environment.lights==lights and flown.encounter.combat.actors.size()==8,"Modal return rebuilt the retained mission scene or cast")
	await capture(app,"modal-mouse-flight-"+rhythm)
	# Fresh physical presses remain usable after the quarantine's neutral edge.
	triggers(0.9)
	if not tick(app,7000):app.free();return
	var fresh: Dictionary=session.snapshot()
	check(fresh.input.primary_held and fresh.input.secondary_requested,"Fresh neutral-to-pressed triggers failed to reach live weapons")
	check(session.flight_owner().secondary_feedback().weapons[0].quantity==ammunition-1,"A fresh EMP press did not spend exactly one owned round")
	if not tick(app,7000):app.free();return
	check(session.snapshot().input.primary_held and not session.snapshot().input.secondary_requested and session.flight_owner().secondary_feedback().weapons[0].quantity==ammunition-1,"Holding a fresh trigger duplicated the discrete EMP request")
	triggers(0.0);mouse_button(true)
	if not tick(app,7000):app.free();return
	check(session.snapshot().input.primary_held,"Fresh captured left-click could not fire after pointer dialogue")
	mouse_button(false);await key(KEY_M)
	if not tick(app,7000):app.free();return
	check(not app._mouse_captured and not session.snapshot().input.primary_held and session.snapshot().input.commands==Vector2.ZERO,"Mouse release/toggle left residual fire or steering")
	print("Modal controls ",rhythm,": ",index," real Host frames / 500ms, pointer briefing, weapon selector, neutral guard and fresh weapons; EMP ",ammunition," -> ",session.flight_owner().secondary_feedback().weapons[0].quantity)
	app.free();await process_frame
