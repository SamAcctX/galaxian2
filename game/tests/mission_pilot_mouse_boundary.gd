extends "res://tests/mission_pilot_observation.gd"
## Pending desktop motion must not contaminate a scripted pilot sample.
## Real root events, native steps and complete scene states remain checked.
const BOUNDARY_FRAMES=12

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()!=3:check(false,"Supply explicit content, bindings and visuals")
	else:await verify(args)
	print("Pilot mouse boundary: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)

func motion(delta: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.relative=delta;event.screen_relative=delta
	root.push_input(event,true)

func verify_accumulation(app: Control) -> void:
	var before: Dictionary=app.session.snapshot()
	app._controls.advance_mouse(0)
	motion(Vector2(.25,-.5));motion(Vector2(.75,.25))
	check(app._controls._mouse_delta.is_equal_approx(Vector2(1,-.25)),"Real root mouse events did not accumulate")
	app._controls.advance_mouse(.01)
	check(app._controls.snapshot().command.is_equal_approx(Vector2(-.25,-1)/6.0),"Production mouse accumulation changed")
	check(app.session.snapshot()==before,"Mouse-only probe advanced the accepted native frame")
	app._controls.advance_mouse(0)

func verify_component(world: RefCounted) -> void:
	var original: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var retained: Dictionary=frame.snapshot();var reference:={};var scenes:={}
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	for trial in 4:
		var noisy: bool=trial%2==1;var shared: bool=trial<2
		var kind: String="144hz" if shared else "variable"
		var label: String=kind+("-pending" if noisy else "-clean")
		if not noisy:reference[kind]=[];scenes[kind]=[]
		now_us=1000123
		var app: Control=await make_host(frame)
		if app==null:return
		app._mouse_steering=true;app.present_session()
		for page in 4:
			restore_focus(app);DesktopPilot.press(root,KEY_ENTER);await process_frame
		restore_focus(app);app.session.rebase_time(now_us)
		check(app.session.can_control() and app._mouse_captured,"Boundary probe did not enter real mouse flight")
		if failures:app.free();return
		var parent: RefCounted=app.session.flight_owner();var initial: Dictionary=parent.snapshot()
		verify_accumulation(app)
		var expired:=Observation.new(app.session)
		await process_frame;restore_focus(app)
		app._controls.advance_mouse(0);motion(Vector2(2,-3))
		var pending: Vector2=app._controls._mouse_delta
		reject_stale(app,expired,"yielded mouse boundary")
		check(app._controls._mouse_delta==pending,"Rejected observation discarded pending mouse motion")
		app._controls.advance_mouse(0)
		if failures:app.free();return
		var native_kinds:={};var interval_kinds:={};var yielded:=0
		for index in BOUNDARY_FRAMES:
			# Reproduce an event delivered while a report/capture yielded, before
			# the next freshly observed synchronous pilot sample. No native time
			# is advanced by the yield or either root motion injection.
			await process_frame;restore_focus(app);yielded+=1
			app._controls.advance_mouse(0)
			if noisy:motion(Vector2(80,-80))
			check(app._controls._mouse_delta.is_equal_approx(Vector2(80,-80) if noisy else Vector2.ZERO),"Pending root-motion stimulus was not delivered")
			var receipt: RefCounted=Observation.new(app.session) if shared else null
			var before: Dictionary=receipt.read(app.session) if shared else app.session.snapshot()
			var input:={"commands":Vector2(.076232,-.369797) if index%2==0 else Vector2(-.31,.22),
				"throttle":[1.0,0.0,.3][index%3],"fire":index%3==1,"strafe":float(1-index%3)}
			var delta_us: int=Cadence.rate_delta_us(index,144) if shared else [4000,17000,31000,9000,67000][index%5]
			var delivered:=DesktopPilot.apply(app,root,input,delta_us,receipt)
			check(not delivered.has("error"),str(delivered.get("error","")))
			check(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,
				"Pending mouse changed root pilot sample "+label+"/"+str(index)+": requested "+str(input)+" delivered "+str(delivered))
			check(app.session.snapshot()==before,"Pending root delivery changed its accepted native frame")
			if shared:
				check(not receipt.matches(app.session),"Mouse boundary reused a consumed observation")
				reject_stale(app,receipt,"duplicate mouse sample")
			if failures:app.free();return
			now_us+=delta_us;app._selected40_tick(now_us)
			check(not app._transition_failed,app.status.text)
			if failures:app.free();return
			var after: Dictionary=app.session.snapshot()
			var native_delta: int=int(after.elapsed_ms)-int(before.elapsed_ms)
			check(native_delta==Cadence.native_delta_ms(now_us-delta_us,delta_us),"Mouse boundary changed absolute native endpoints")
			check(int(after.elapsed_ms)-int(initial.elapsed_ms)==Cadence.native_delta_ms(1000123,now_us-1000123),"Mouse boundary lost cumulative native time")
			check(after.input.commands.is_equal_approx(input.commands) and after.input.primary_held==input.fire
				and not after.input.secondary_requested and is_equal_approx(after.throttle,input.throttle),"Mouse boundary changed consumed controls or throttle")
			check(app.session.scene._revision==after.revision and app.session.scene._elapsed_ms==after.elapsed_ms,"Mouse boundary skipped scene presentation")
			var presented: Dictionary=app.session.scene.snapshot()
			if noisy:
				check(after==reference[kind][index],"Pending motion changed the complete native frame: "+label+"/"+str(index))
				check(presented==scenes[kind][index],"Pending motion changed the complete presented scene: "+label+"/"+str(index))
			else:reference[kind].append(after);scenes[kind].append(presented)
			native_kinds[native_delta]=true;interval_kinds[delta_us]=true
			if failures:app.free();return
		check(yielded==BOUNDARY_FRAMES,"Boundary probe omitted a yielded sample")
		if shared:check(native_kinds.has(6) and native_kinds.has(7) and interval_kinds.has(6944) and interval_kinds.has(6945),"Boundary probe omitted fractional144Hz endpoints")
		else:check(interval_kinds.size()==5,"Boundary probe omitted a variable interval")
		check(parent.snapshot()==initial and app.session.flight_owner().initialized_world_owner()==frame.initialized_world_owner(),"Mouse boundary changed retained native/world ownership")
		if trial in [0,1]:await capture(app,"mission-mouse-boundary-"+label)
		print("Mouse boundary ",label,": ",BOUNDARY_FRAMES," actual Host frames; native ",native_kinds.keys(),"; full native/scene comparison, no earned battle claim")
		app.free();await process_frame
		if failures:return
	check(frame.snapshot()==retained and world.snapshot()==original,"Mouse boundary mutated the retained source world/frame")
