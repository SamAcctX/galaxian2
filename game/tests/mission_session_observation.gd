extends "res://tests/mission_pilot_input.gd"
## Small observations must remain equivalent to their immutable native owner.
## This covers real Host input/presentation, not an earned battle or render FPS.
const Session=preload("res://src/presentation/mission_session.gd")
const Cadence=preload("res://tests/fixtures/mission_host_cadence.gd")

class CountedFrame extends "res://src/simulation/mission_flight_frame.gd":
	static var context_reads:=0
	static var full_forks:=0
	func frame_context() -> Dictionary:
		context_reads+=1
		return super.frame_context()
	func fork_for_frame() -> RefCounted:
		full_forks+=1
		return super.fork_for_frame()

class ObservationWorld extends RefCounted:
	var flags:=0
	var reads:=0
	func _init(value: int) -> void:flags=value
	func frame_context() -> Dictionary:
		reads+=1
		return {"revision":0,"elapsed_ms":0,"player":{"active":bool(flags&4),"vitals":{"hull":1 if flags&8 else 0}},
			"encounter":{"sequence":{"input_blocked":bool(flags&1),"hud_visible":bool(flags&2),"entry_released":bool(flags&2)},
			"view":{"camera_mode":3 if flags&64 else 0,"orbit_input":{"dragging":bool(flags&64)}}}}
	func campaign_dialogue_visible() -> bool:return bool(flags&32)
	func prepare_portal_transition() -> Dictionary:return {"pending":true} if flags&16 else {}
	func destruction_owner() -> RefCounted:return self
	func snapshot() -> Dictionary:return {"phase":"ready" if flags%3==0 else "destroyed","game_over_visible":flags%3==2}

func run() -> void:
	verify_observation_lifetime()
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()!=3:check(false,"Supply explicit content, bindings and visuals")
	elif not failures:await verify(args)
	print("Mission session observation checks: ",checks,"; failures: ",failures)
	quit(1 if failures else 0)

func verify_observation_lifetime() -> void:
	var session:=Session.new()
	for flags in 128:
		# Every owner has the same clock/revision: identity, not either scalar,
		# must invalidate observations across zero-time navigation boundaries.
		var owner:=ObservationWorld.new(flags);session._world=owner
		var expected: Dictionary=session.flight_observation()
		check(expected.camera_mode==(3 if flags&64 else 0) and expected.input_blocked==bool(flags&1)
			and expected.destruction_phase==owner.snapshot().phase and expected.game_over_visible==owner.snapshot().game_over_visible,
			"A same-time owner replacement retained the previous presentation flags")
		var exposed: Dictionary=session.flight_observation()
		exposed.input_blocked=not exposed.input_blocked;exposed.orbit_input.dragging=not exposed.orbit_input.dragging
		check(session.flight_observation()==expected,"Returned observations exposed mutable cached state")
		for session_status in ["prepared","running","normal_space_return_required"]:
			for active in [false,true]:
				for paused in [false,true]:
					session.status=session_status;session._active=active;session._pauses={"user":paused}
					var control: bool=active and session_status=="running" and not paused and not bool(flags&1) and bool(flags&4) and bool(flags&8) and not bool(flags&16) and not bool(flags&32)
					var hud: bool=active and bool(flags&2) and not bool(flags&32)
					check(session.can_control()==control,"Control observation cached a dynamic session gate or lost a native gate")
					check(session.flight_hud_visible()==hud,"HUD observation changed the existing pause/status semantics")
		check(owner.reads==1,"Repeated reads rebuilt an immutable owner's complete context")
	session._world=null
	check(session.flight_observation().is_empty() and not session.can_control() and not session.flight_hud_visible(),"A cleared session reused the last flight")
	session.free()

func check_observation(app: Control,label: String) -> void:
	var session: Node3D=app.session;var owner: RefCounted=session._world
	var before: Dictionary=owner.snapshot();var sequence: Dictionary=before.encounter.sequence
	var expected:={"dialogue_visible":owner.campaign_dialogue_visible(),"portal_pending":not owner.prepare_portal_transition().is_empty(),
		"input_blocked":sequence.input_blocked,"hud_visible":sequence.hud_visible,"player_active":before.player.active,"player_alive":before.player.vitals.hull>0,
		"entry_released":sequence.get("entry_released",false),"camera_mode":before.encounter.view.camera_mode,
		"orbit_input":before.encounter.view.orbit_input,"destruction_phase":before.player_destruction.phase,"game_over_visible":before.player_destruction.game_over_visible}
	check(session.flight_observation()==expected,"Small observation differs from the full native owner at "+label)
	var control: bool=session._active and session.status=="running" and not session.is_paused() and not expected.dialogue_visible and not expected.portal_pending and not expected.input_blocked and expected.player_active and expected.player_alive
	var hud: bool=session._active and not expected.dialogue_visible and expected.hud_visible
	CountedFrame.context_reads=0;CountedFrame.full_forks=0
	for repeat in 16:
		check(session.can_control()==control and session.flight_hud_visible()==hud and session.flight_observation()==expected,
			"Repeated observation changed input/HUD state at "+label)
	check(CountedFrame.context_reads==0 and CountedFrame.full_forks==0,"Repeated small observations rebuilt a context or cloned a flight")
	var exposed: Dictionary=session.flight_observation();exposed.orbit_input.clear();exposed.input_blocked=not expected.input_blocked
	check(session.flight_observation()==expected and owner.snapshot()==before,"Observation mutation escaped into the accepted native frame")
	var text: String
	if session.is_paused():text="Paused · Esc / controller Start resumes"
	elif session.status!="running":text="This flight has reached an unimplemented travel or result boundary. No progress has been awarded."
	elif expected.destruction_phase!="ready":text="Game over" if expected.game_over_visible else "Your ship was destroyed"
	elif not expected.entry_released:text="Entering the selected encounter"
	else:text="Steer: Mouse / arrows / stick · Fire: Space / trigger · Select secondary: G · EMP: R / left trigger · View: T"
	check(app.status.text==text,"Host status changed its native interpretation at "+label)
	check(session.scene._revision==before.revision and session.scene._elapsed_ms==before.elapsed_ms,"Host skipped actual scene presentation at "+label)

func verify_component(world: RefCounted) -> void:
	var incoming: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=CountedFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var retained: Dictionary=frame.snapshot()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var app: Control=await make_host(frame)
	if app==null:return
	app._mouse_steering=true;app.present_session();check_observation(app,"arrival")
	check(not app.session.can_control() and not app.session.flight_hud_visible(),"Arrival admitted input/HUD before release")
	for page in 4:
		await key(KEY_ENTER);check_observation(app,"briefing-"+str(page))
	check(app.session.can_control() and app._mouse_captured and app.session.flight_hud_visible(),"Briefing did not restore mouse input and HUD")
	if failures:app.free();return
	app.session.rebase_time(now_us)
	var host_us:=0;var input_us:=0
	for index in 32:
		if index==16:
			app.set_user_paused(true);app.present_session();check_observation(app,"paused")
			check(not app.session.can_control() and not app._mouse_captured,"Pause left flight input captured")
			await capture(app,"mission-session-observation-paused")
			app.set_user_paused(false);app.session.rebase_time(now_us);app.present_session();check_observation(app,"resumed")
		var before: Dictionary=app.session.snapshot()
		var input:={"commands":Vector2(.2,-.4) if index%2==0 else Vector2(-.1,.3),"throttle":[0.0,0.3,1.0,0.8][(index/8)%4],"fire":index%3==0,"strafe":float((index%3)-1)}
		var delta_us: int=Cadence.rate_delta_us(index,144)
		var started:=Time.get_ticks_usec();var delivered:=DesktopPilot.apply(app,root,input,delta_us);input_us+=Time.get_ticks_usec()-started
		check(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,"Root input delivery changed")
		check(app.session.snapshot()==before,"Pending input mutated the accepted native frame")
		now_us+=delta_us;started=Time.get_ticks_usec();app._selected40_tick(now_us);host_us+=Time.get_ticks_usec()-started
		check(not app._transition_failed,app.status.text)
		if failures:app.free();return
		var after: Dictionary=app.session.snapshot()
		check(after.elapsed_ms-before.elapsed_ms==Cadence.native_delta_ms(now_us-delta_us,delta_us),"Observation reuse changed native clock endpoints")
		check(after.input.commands.is_equal_approx(input.commands) and after.input.primary_held==input.fire and not after.input.secondary_requested and is_equal_approx(after.throttle,input.throttle),"Observation reuse changed consumed flight controls")
		check_observation(app,"flight-"+str(index))
		if failures:app.free();return
	check(frame.snapshot()==retained and world.snapshot()==incoming,"Session observations mutated a retained incoming frame/world")
	await capture(app,"mission-session-observation-flight")
	print("Observation sample:32 actual144Hz Host frames; mean Host us ",float(host_us)/32,"; input us ",float(input_us)/32,"; repeated small reads:0 full contexts/0 flight forks; not earned/FPS/budget acceptance")
	app.free();await process_frame
