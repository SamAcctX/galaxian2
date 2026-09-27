extends "res://tests/mission_pilot_input.gd"
## Explicit observation sharing in the pilot harness; no native frame cache.
## Paired real Hosts retain every root sample, native assertion and scene frame.
const Observation=preload("res://tests/fixtures/mission_pilot_observation.gd")
const Cadence=preload("res://tests/fixtures/mission_host_cadence.gd")
const SAMPLES=32

class CountedFrame extends "res://src/simulation/mission_flight_frame.gd":
	static var full_reads:=0
	func snapshot() -> Dictionary:
		full_reads+=1
		return super.snapshot()

class ObservationOwner extends RefCounted:
	var throttle: float
	func _init(value: float) -> void:throttle=value

class ObservationSession extends Node3D:
	var _world: RefCounted
	var _active:=true
	var status:="running"
	var paused:=false
	func is_paused() -> bool:return paused
	func snapshot() -> Dictionary:
		return {"revision":0,"elapsed_ms":0,"throttle":_world.throttle,"status":status,"paused":paused}

func run() -> void:
	await verify_lifetime()
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()!=3:check(false,"Supply explicit content, bindings and visuals")
	elif not failures:await verify(args)
	print("Mission pilot observation checks: ",checks,"; failures: ",failures)
	quit(1 if failures else 0)

func verify_lifetime() -> void:
	var session:=ObservationSession.new();session._world=ObservationOwner.new(0.3)
	var receipt:=Observation.new(session);var before: Dictionary=receipt.read(session)
	check(receipt.matches(session) and before==session.snapshot(),"New receipt differs from accepted state")
	session._world=ObservationOwner.new(0.8)
	check(session.snapshot().revision==before.revision and session.snapshot().elapsed_ms==before.elapsed_ms,
		"Same-time replacement stimulus changed revision/time")
	check(not receipt.matches(session) and receipt.read(session).is_empty(),"Equal revision/time hid a different native owner")
	var other:=ObservationSession.new();other._world=session._world
	receipt=Observation.new(session)
	check(not receipt.matches(other),"A replacement session reused a receipt for the same world")
	for gate in ["paused","status","_active"]:
		receipt=Observation.new(session);var original: Variant=session.get(gate)
		session.set(gate,"prepared" if gate=="status" else not bool(original))
		check(not receipt.matches(session),"Dynamic session gate retained a stale receipt: "+gate)
		session.set(gate,original)
	receipt=Observation.new(session);receipt.invalidate()
	check(not receipt.matches(session) and receipt.read(session).is_empty(),"Explicit await/navigation invalidation was ignored")
	receipt=Observation.new(session)
	await process_frame;await process_frame
	check(not receipt.matches(session) and receipt.read(session).is_empty(),"A yielded iteration reused an old receipt without native motion")
	receipt=Observation.new(session);session._world=null
	check(not receipt.matches(session),"Clearing the native owner retained its observation")
	session.free();other.free()

func restore_focus(app: Control) -> void:
	app._focused=true
	if app.session._pauses.has("focus"):
		app.session.set_pause("focus",false,now_us);app.session.rebase_time(now_us)
	app.refresh_render_mode()

func reject_stale(app: Control,receipt: RefCounted,label: String) -> void:
	var before: Dictionary=app.session.snapshot();var held: Dictionary=app._controls.snapshot()
	var input:={"commands":Vector2(.3,-.4),"throttle":0.0,"fire":true,"strafe":-1.0}
	var delivered: Dictionary=DesktopPilot.apply(app,root,input,6944,receipt)
	check(delivered.has("error"),"Stale receipt delivered input at "+label)
	check(app.session.snapshot()==before and app._controls.snapshot()==held,"Rejected receipt changed native/pending input at "+label)

func verify_component(world: RefCounted) -> void:
	var incoming: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=CountedFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var retained: Dictionary=frame.snapshot()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var reference:=[];var reference_scenes:=[];var metrics:=[]
	# Order-balanced short trajectories. These are operation counts and local
	# timings, not an earned journey, render FPS or full-run budget acceptance.
	for trial in 4:
		var shared: bool=trial in [1,2]
		now_us=1000000
		var app: Control=await make_host(frame)
		if app==null:return
		app._mouse_steering=true;app.present_session()
		var navigation:=Observation.new(app.session)
		DesktopPilot.press(root,KEY_ENTER)
		check(not navigation.matches(app.session),"Arrival navigation retained the old accepted owner")
		reject_stale(app,navigation,"arrival navigation")
		await process_frame
		# Briefing navigation accepts a real replacement owner without motion.
		# This mission deliberately has no alternate player camera view.
		for page in 3:
			var page_receipt:=Observation.new(app.session);var before_page: Dictionary=page_receipt.read(app.session)
			DesktopPilot.press(root,KEY_ENTER)
			check(not page_receipt.matches(app.session) and app.session.snapshot().elapsed_ms==before_page.elapsed_ms,
				"Zero-time briefing navigation reused an accepted observation")
			reject_stale(app,page_receipt,"briefing navigation")
			await process_frame
		check(app.session.can_control() and app._mouse_captured,"Paired pilot did not enter ordinary mouse flight")
		if failures:app.free();return
		app.session.rebase_time(now_us);restore_focus(app)
		var pilot_reads:=0;var after_reads:=0;var pilot_us:=0;var host_us:=0;var after_us:=0
		for index in SAMPLES:
			if index==SAMPLES/2:
				var pause_receipt:=Observation.new(app.session)
				app.set_user_paused(true);app.present_session()
				check(not app.session.can_control() and not app._mouse_captured,"Pause retained flight input")
				reject_stale(app,pause_receipt,"pause")
				var capture_receipt:=Observation.new(app.session);capture_receipt.invalidate()
				if trial==2:await capture(app,"mission-pilot-observation-paused")
				check(not capture_receipt.matches(app.session),"Capture reused an expired observation")
				var resume_receipt:=Observation.new(app.session)
				app.set_user_paused(false);app.session.rebase_time(now_us);app.present_session()
				reject_stale(app,resume_receipt,"resume")
				if failures:app.free();return
			restore_focus(app)
			CountedFrame.full_reads=0
			var started:=Time.get_ticks_usec()
			var receipt: RefCounted=Observation.new(app.session) if shared else null
			var outer: Dictionary=receipt.read(app.session) if shared else app.session.snapshot()
			var before: Dictionary=receipt.read(app.session) if shared else app.session.snapshot()
			var input:={"commands":Vector2(.2,-.4) if index%2==0 else Vector2(-.1,.3),
				"throttle":[0.0,0.3,1.0,0.8][(index/4)%4],"fire":index%3==0,"strafe":float((index%3)-1)}
			var delta_us: int=Cadence.rate_delta_us(index,144)
			var delivered:=DesktopPilot.apply(app,root,input,delta_us,receipt)
			pilot_us+=Time.get_ticks_usec()-started
			var reads: int=CountedFrame.full_reads;pilot_reads+=reads
			check(reads==(1 if shared else 3),"Pilot scope did not share exactly one native observation: "+str(reads))
			check(not delivered.has("error"),str(delivered.get("error","")))
			if failures:app.free();return
			check(before==outer,"Outer pilot and step assertions observed different native frames")
			check(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,"Shared observation changed root input")
			check(app.session.snapshot()==before,"Pending root input mutated the accepted native frame")
			if shared:
				check(not receipt.matches(app.session),"Delivered receipt remained reusable for pending throttle edges")
				if index==0:reject_stale(app,receipt,"duplicate root sample")
			now_us+=delta_us;started=Time.get_ticks_usec();app._selected40_tick(now_us)
			host_us+=Time.get_ticks_usec()-started
			check(not app._transition_failed,app.status.text)
			if failures:app.free();return
			CountedFrame.full_reads=0;started=Time.get_ticks_usec()
			var after: Dictionary=app.session.snapshot()
			after_us+=Time.get_ticks_usec()-started;after_reads+=CountedFrame.full_reads
			check(CountedFrame.full_reads==1,"Post-step assertion omitted or duplicated its native snapshot")
			check(after.elapsed_ms-before.elapsed_ms==Cadence.native_delta_ms(now_us-delta_us,delta_us),"Shared observation changed native clock endpoints")
			check(after.input.commands.is_equal_approx(input.commands) and after.input.primary_held==input.fire
				and not after.input.secondary_requested and is_equal_approx(after.throttle,input.throttle),"Shared observation changed consumed flight input")
			check(app.session.scene._revision==after.revision and app.session.scene._elapsed_ms==after.elapsed_ms,"Shared observation omitted actual scene presentation")
			var presented: Dictionary=app.session.scene.snapshot()
			if trial==0:reference.append(after);reference_scenes.append(presented)
			else:
				check(after==reference[index],"Full native flight changed at paired sample "+str(index))
				check(presented==reference_scenes[index],"Actual scene changed at paired sample "+str(index))
			if failures:app.free();return
		metrics.append({"shared":shared,"frames":SAMPLES,"pilot_snapshots":pilot_reads,"after_snapshots":after_reads,
			"mean_pilot_us":float(pilot_us)/SAMPLES,"mean_host_us":float(host_us)/SAMPLES,"mean_after_us":float(after_us)/SAMPLES})
		if trial==2:await capture(app,"mission-pilot-observation-flight")
		app.free();await process_frame
	check(frame.snapshot()==retained and world.snapshot()==incoming,"Pilot observations mutated their retained source frame/world")
	print("Paired pilot observations: ",metrics,"; every native/scene frame equal; four-to-two harness snapshots, extra native assertions retained; detached, not earned/FPS/full-budget acceptance")
