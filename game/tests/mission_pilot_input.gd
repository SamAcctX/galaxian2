extends "res://tests/mission_arrival_input.gd"
## A small actual-Host check of the earned pilot's desktop adapter, including
## pending throttle edges. The inherited world is detached, not an earned run.
const DesktopPilot=preload("res://tests/fixtures/mission_pilot_input.gd")

func verify_component(world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var app: Control=await make_host(frame)
	if app==null:return
	app._mouse_steering=true;app.present_session()
	for page in 4:await key(KEY_ENTER)
	check(app.session.can_control() and app._mouse_captured,"Pilot adapter did not enter ordinary mouse flight")
	if failures:app.free();return
	app.session.rebase_time(now_us)
	var parent: RefCounted=app.session.flight_owner();var initial: Dictionary=parent.snapshot()
	var levels:=[0.3,0.0,0.8,1.0,1.0,0.3,0.3,0.0,1.0,0.0]
	for index in levels.size():
		var input:={"commands":Vector2(.2,-.4) if index%2==0 else Vector2(-.1,.3),"throttle":levels[index],"fire":index%3==0,"strafe":float((index%3)-1)}
		var delta_us: int=[4000,17000,31000,9000,67000][index%5]
		var before: Dictionary=app.session.snapshot()
		var delivered:=DesktopPilot.apply(app,root,input,delta_us)
		check(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,"Desktop pilot root delivery changed: "+str(delivered))
		check(app.session.snapshot().throttle==before.throttle,"Pending key edges mutated the already accepted flight snapshot")
		now_us+=delta_us;app._selected40_tick(now_us)
		check(not app._transition_failed,app.status.text)
		if failures:app.free();return
		var after: Dictionary=app.session.snapshot()
		check(after.elapsed_ms-before.elapsed_ms==delta_us/1000,"Desktop pilot lost the actual Host time")
		check(after.input.commands.is_equal_approx(input.commands) and after.input.primary_held==input.fire and not after.input.secondary_requested,"Desktop pilot's root commands did not reach native flight")
		check(is_equal_approx(float(after.throttle),float(input.throttle)),"Throttle edges missed the native frame: "+str(before.throttle)+" -> requested "+str(input.throttle)+" actual "+str(after.throttle))
		print("Desktop pilot sample ",index,": ",delta_us/1000,"ms throttle ",before.throttle," -> ",after.throttle," fire ",after.input.primary_held," strafe ",delivered.strafe)
		if failures:app.free();return
	check(parent.snapshot()==initial,"Desktop pilot mutated its retained source frame")
	if DisplayServer.get_name()!="headless":
		check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Mouse flight did not capture the cursor")
		app._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		app.refresh_render_mode()
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not app._mouse_captured and app.session.is_paused(),"Unfocused flight retained or recaptured the cursor")
		check(not app._controls.snapshot().held.fire and app._controls.snapshot().command==Vector2.ZERO,"Focus loss retained the pilot's input")
		app._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Focused flight did not restore mouse steering")
		app.set_user_paused(true)
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pause retained the cursor")
		app.set_user_paused(false)
		app.hide()
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Hidden flight retained the cursor")
		app.show()
	await capture(app,"mission-pilot-input")
	app.free();await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Closing flight retained the cursor")
