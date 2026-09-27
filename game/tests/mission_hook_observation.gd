extends "res://tests/mission_pilot_input.gd"
## Paired full-event-read and event-only Hosts over the same detached entry.
## Every root sample, native snapshot and actual scene frame is retained.
const Cadence=preload("res://tests/fixtures/mission_host_cadence.gd")
const SAMPLES=64

class CountedHook extends "res://src/simulation/selected41_npc_combat.gd":
	static var full_reads:=0
	var legacy_events:=false
	func snapshot() -> Dictionary:
		full_reads+=1
		return super.snapshot()
	func event_observation() -> Dictionary:
		return snapshot().get("events",{}) if legacy_events else super.event_observation()
	func fork_for_frame() -> RefCounted:
		var next: RefCounted=super.fork_for_frame()
		next.legacy_events=legacy_events
		return next

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()!=3:check(false,"Supply explicit content, bindings and visuals")
	else:await verify(args)
	print("Mission hook observation checks: ",checks,"; failures: ",failures)
	quit(1 if failures else 0)

func verify_events(hook: RefCounted,label: String) -> void:
	var before: Dictionary=hook.snapshot()
	CountedHook.full_reads=0
	var events: Dictionary=hook.event_observation()
	check(CountedHook.full_reads==0,"Event observation rebuilt a complete hook at "+label)
	check(events==before.get("events",{}),"Event observation differs from the native snapshot at "+label)
	events.clear()
	check(hook.snapshot()==before,"Returned event observation mutated its native owner at "+label)

func verify_boundaries(hook: RefCounted,pose: Transform3D) -> void:
	var original: Dictionary=hook.snapshot()
	verify_events(hook,"entry")
	var contacts: RefCounted=hook.evaluate_contacts(7,pose)
	if contacts==null:check(false,hook.error);return
	verify_events(contacts,"contacts")
	var sequence: RefCounted=contacts.evaluate_sequence()
	if sequence==null:check(false,contacts.error);return
	verify_events(sequence,"sequence")
	var motion: RefCounted=sequence.evaluate_motion()
	if motion==null:check(false,sequence.error);return
	verify_events(motion,"motion")
	check(hook.snapshot()==original,"Event boundary checks changed their incoming native hook")
	# Synthetic nested payloads test detachment and same-time replacement only;
	# they never enter simulation, the scene, the live Host or an earned save.
	var probe: RefCounted=hook.fork_for_frame()
	for index in 4:
		probe._events={"contacts":[{"nested":{"value":index}}],"radio":[{"nested":{"value":index+1}}],
			"actors":[{"nested":{"value":index+2}}],"sequence":{"nested":{"value":index+3}}}
		var expected: Dictionary=probe.snapshot()
		var exposed: Dictionary=probe.event_observation()
		exposed.contacts[0].nested.value=-1;exposed.radio[0].nested.value=-1
		exposed.actors[0].nested.clear();exposed.sequence.nested.clear()
		check(probe.snapshot()==expected and probe.event_observation()==expected.events,
			"Nested events leaked or same-time replacement reused an earlier observation")
	check(hook.snapshot()==original,"Detached payload checks mutated the real source")

func verify_component(world: RefCounted) -> void:
	var incoming: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var hook:=CountedHook.new()
	if not hook.prepare(bindings,catalogues,library,world):check(false,hook.error);return
	check(hook.snapshot()==frame._encounter._hook.snapshot(),"Counted hook did not preserve the real initial native state")
	verify_boundaries(hook,incoming.player_pose)
	if failures:return
	frame._encounter._hook=hook
	var retained: Dictionary=frame.snapshot()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var reference:=[];var reference_scenes:=[];var metrics:=[]
	for legacy in [true,false]:
		now_us=1000000
		var trial: RefCounted=frame.fork_for_frame()
		trial._encounter._hook=hook.fork_for_frame();trial._encounter._hook.legacy_events=legacy
		var app: Control=await make_host(trial)
		if app==null:return
		app._mouse_steering=true;app.present_session()
		for page in 4:await key(KEY_ENTER)
		check(app.session.can_control() and app._mouse_captured,"Paired Host did not enter ordinary mouse flight")
		if failures:app.free();return
		app.session.rebase_time(now_us)
		var host_us:=0;var input_us:=0;var snapshot_us:=0;var focus_us:=0;var full_reads:=0
		for index in SAMPLES:
			if index==SAMPLES/2:
				app.set_user_paused(true);app.present_session()
				check(not app.session.can_control() and not app._mouse_captured,"Pause retained root flight input")
				if not legacy:await capture(app,"mission-hook-observation-paused")
				app.set_user_paused(false);app.session.rebase_time(now_us);app.present_session()
			CountedHook.full_reads=0
			var started:=Time.get_ticks_usec();var before: Dictionary=app.session.snapshot()
			snapshot_us+=Time.get_ticks_usec()-started
			# Exercise the real earned harness's focus path, including its existing
			# false focus hold and renderer refresh. Do not optimize it away here.
			started=Time.get_ticks_usec();app._focused=true
			if app.session._pauses.has("focus"):
				app.session.set_pause("focus",false,now_us);app.session.rebase_time(now_us)
			app.refresh_render_mode();focus_us+=Time.get_ticks_usec()-started
			var input:={"commands":Vector2(.2,-.4) if index%2==0 else Vector2(-.1,.3),
				"throttle":[0.0,0.3,1.0,0.8][(index/8)%4],"fire":index%3==0,"strafe":float((index%3)-1)}
			var delta_us: int=Cadence.rate_delta_us(index,144)
			started=Time.get_ticks_usec();var delivered:=DesktopPilot.apply(app,root,input,delta_us)
			input_us+=Time.get_ticks_usec()-started
			check(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,"Root input sample changed")
			check(app.session.snapshot()==before,"Pending root input changed the accepted native frame")
			now_us+=delta_us;started=Time.get_ticks_usec();app._selected40_tick(now_us)
			host_us+=Time.get_ticks_usec()-started
			check(not app._transition_failed,app.status.text)
			if failures:app.free();return
			started=Time.get_ticks_usec();var after: Dictionary=app.session.snapshot()
			snapshot_us+=Time.get_ticks_usec()-started
			full_reads+=CountedHook.full_reads
			check(after.elapsed_ms-before.elapsed_ms==Cadence.native_delta_ms(now_us-delta_us,delta_us),"Hook observation changed native clock endpoints")
			check(after.input.commands.is_equal_approx(input.commands) and after.input.primary_held==input.fire
				and not after.input.secondary_requested and is_equal_approx(after.throttle,input.throttle),"Hook observation changed consumed flight input")
			check(app.session.scene._revision==after.revision and app.session.scene._elapsed_ms==after.elapsed_ms,"Hook observation omitted actual scene presentation")
			var presented: Dictionary=app.session.scene.snapshot()
			if legacy:reference.append(after);reference_scenes.append(presented)
			else:
				check(after==reference[index],"Full native flight differs from full-event-read reference at sample "+str(index))
				check(presented==reference_scenes[index],"Actual scene differs from full-event-read reference at sample "+str(index))
			if failures:app.free();return
		metrics.append({"legacy":legacy,"frames":SAMPLES,"hook_snapshots":full_reads,
			"mean_host_us":float(host_us)/SAMPLES,"mean_input_us":float(input_us)/SAMPLES,
			"mean_two_snapshot_us":float(snapshot_us)/SAMPLES,"mean_focus_us":float(focus_us)/SAMPLES})
		if not legacy:await capture(app,"mission-hook-observation-flight")
		app.free();await process_frame
	check(metrics[0].hook_snapshots>0 and metrics[1].hook_snapshots==0,"Event consumers still reconstruct complete hooks")
	check(frame.snapshot()==retained and world.snapshot()==incoming,"Paired observations mutated the source frame/world")
	print("Paired event observation: ",metrics,"; equal full native/scene snapshots at every sample; detached, not earned/FPS/full-budget acceptance")
