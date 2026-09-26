extends RefCounted
## Native prepared-flight application regression, NOT an earned departure.
## Near-portal entry uses an explicit component pose, not an earned journey.
## Damage and portal-phase branches are explicitly detached regressions,
## never earned campaign completions or changes to the protected arrival save.
const Builder=preload("res://src/simulation/selected40_flight_construction.gd")
const Initial=preload("res://src/simulation/flight_camera_initialization.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Host=preload("res://src/presentation/opening_preview.gd")
const VIEWPORT=Vector2i(1440,900)

static func run(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted,pose: Transform3D,career: RefCounted=null) -> Dictionary:
	var check: Callable=host.check
	var before_player: Dictionary=player.snapshot();var before_field: Dictionary=scenery.snapshot();var before_gear: Dictionary=equipment.snapshot()
	for incoming in [false,true]:
		var camera:=Initial.new();var random:=Random.new()
		check.call(random.restore(scenery.random_state()),random.error)
		var offset:=Vector3(0,0,7000 if incoming else 9000)
		for axis in 2:offset[axis]=500+random.next_int(500 if incoming else 2000)
		for axis in 2:
			if random.next_int(2)==0:offset[axis]=-offset[axis]
		if not camera.configure(bindings,pose,scenery.random_state(),incoming):check.call(false,camera.error);return {}
		var sample: Dictionary=camera.snapshot()
		check.call(sample.offset==offset and sample.random_state==random.snapshot() and camera.camera_owner().snapshot().eye.is_equal_approx(pose*offset),"Native camera changed late draw order, arrival/default bounds or player-space transform")
		check.call(not camera.configure(bindings,pose,scenery.random_state(),incoming) and camera.snapshot()==sample,"Repeated camera constructor changed its retained initialization")
		var detached: Dictionary=camera.snapshot();detached.offset=Vector3.ZERO
		check.call(camera.snapshot()==sample,"Camera initialization observation aliases its owner")
	var bad:=Initial.new()
	check.call(not bad.configure(bindings,Transform3D(Basis.IDENTITY,Vector3.INF),scenery.random_state()) and bad.snapshot().is_empty(),"Invalid entry camera retained a partial view")
	check.call(not bad.configure(bindings,pose,{"state":-1}) and bad.snapshot().is_empty(),"Invalid late camera stream was silently reseeded")
	var builder:=Builder.new()
	if not builder.prepare(bindings,cat,library,player,scenery,equipment,reputation,pose,0.5,VIEWPORT,career):check.call(false,builder.error);return {}
	var world: RefCounted=builder.world_owner();var first: Dictionary=world.frame_context();var init: Dictionary=builder.snapshot()
	var entry_contact: Dictionary=await check_entry_contact(host,library,bindings,cat,scenery,equipment,reputation,player,world,career)
	check.call(entry_contact.get("complete")==true,"Near-portal application entry did not complete its gated-contact regression")
	if host.failures:return {}
	await check_campaign_failure(host,library,bindings,visuals_for(host,library),builder,career)
	if host.failures:return {}
	if career!=null:
		check_career_retained(check,world,career.snapshot(),"prepared application")
		check_career_binding(check,world,bindings,career)
	check.call(init.special_placement and init.offset.z==7000 and init.input_random_state==scenery.random_state() and first.random_state==init.random_state,"Application consumed portal-initial draws or default departure camera instead of its late arrival stream")
	check.call(first.encounter.sequence.input_blocked and not first.encounter.sequence.hud_visible and first.encounter.view.shot.mode=="fixed_eye" and not first.player.active and not first.player.damage_allowed,"Application skipped the source fixed-eye entry gate")
	check.call(world.camera_input(3)==null and world.select_secondary(42)==null,"Entry gate admitted early view/secondary input")
	check.call(not builder.prepare(bindings,cat,library,player,scenery,equipment,reputation,pose) and builder.world_owner().snapshot()==world.snapshot(),"Repeated application construction replaced the accepted native lifetime")
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):check.call(false,visuals.error);return {}
	var app:=Host.new();host.root.add_child(app);app.set_process(false);app.size=Vector2(1440,960)
	app.library=library;app.bindings=bindings;app.visuals=visuals
	await host.process_frame
	app.viewport.size=VIEWPORT;app.viewport.size_2d_override=VIEWPORT
	var now:=1000000
	if not app.enter_selected40_prepared(builder,now):check.call(false,app.status.text);app.free();return {}
	var session: Node3D=app.session
	var ids: Array=session.scene.encounter.actors.map(func(row):return row.hull.get_instance_id())
	var prepared: Dictionary=session.snapshot()
	check.call(not app.enter_selected40_prepared(RefCounted.new(),now) and app.session==session and session.snapshot()==prepared and app.viewport.get_camera_3d()==session.camera,"Rejected application replacement lost the prior flight or active camera")
	await capture(host,app,"entry")
	app._selected40_input(key(KEY_SPACE,true));app._selected40_input(key(KEY_R,true))
	check.call(not session._secondary_pending and not app._controls.snapshot().held.fire,"Controls accepted fire held before entry release")
	for tick in 70:
		now+=100000;app._selected40_tick(now)
		if app._transition_failed:check.call(false,app.status.text);app.free();return {}
		var state: Dictionary=session.flight_owner().frame_context()
		check.call(state.elapsed_ms==(tick+1)*100 and not session.can_control() and state.encounter.view.camera.eye==first.encounter.view.camera.eye and not state.input.enabled,"Source entry released or moved its fixed eye at/before7000ms")
		if tick==0:
			check.call(session.camera.global_transform.is_equal_approx(state.encounter.view.camera.pose) and not session.camera.is_position_behind(state.player_pose.origin),"Application entry renderer lost its native fixed view or player target")
			await capture(host,app,"entry-first-frame")
	now+=1000;app._selected40_tick(now)
	if app._transition_failed:check.call(false,app.status.text);app.free();return {}
	var released: Dictionary=session.flight_owner().frame_context()
	check.call(released.elapsed_ms==7001 and released.encounter.sequence.entry_released and released.encounter.sequence.entry_elapsed_ms==0 and released.encounter.view.shot.mode=="follow" and session.can_control() and released.player.damage_allowed,"Actual application did not release its native follow/input/damage gate at7001ms")
	check.call(not released.input.primary_held and not released.input.secondary_requested,"Previously blocked held fire leaked across the entry boundary")
	check.call(session.scene.secondary_panel.snapshot().hint.contains("G / D-pad right: Weapons menu"),"Shown secondary-menu key does not open the real application selector")
	await capture(host,app,"released")
	var captured: Dictionary=await check_captured_controls(host,app,bindings,cat,equipment,now)
	check.call(captured.get("complete")==true,"Captured application regression did not reach its completion sentinel")
	now=captured.get("now",now)
	if host.failures:app.free();return {}
	# Independent pause reasons and a rebased monotonic clock: no catch-up and
	# no delayed paid projectile when an action was queued immediately before it.
	check.call(session.action("missiles"),session.error)
	var paused: Dictionary=session.flight_owner().snapshot()
	check.call(session.set_pause("focus",true,now) and session.set_pause("hidden",true,now),session.error)
	now+=9000000;check.call(session.step(now,Vector2.ONE,true),session.error)
	check.call(session.flight_owner().snapshot()==paused and not session._secondary_pending,"Paused session advanced native clocks/random/ammo or kept a queued paid action")
	check.call(session.set_pause("focus",false,now) and session.is_paused(),"Releasing one pause reason unblocked another")
	check.call(session.set_pause("hidden",false,now) and not session.is_paused(),session.error)
	now+=100000;app._selected40_tick(now)
	check.call(session.flight_owner().frame_context().elapsed_ms==paused.elapsed_ms+100 and not session.flight_owner().frame_context().input.secondary_requested,"Resume caught up paused time or fired its discarded action")
	app._selected40_input(key(KEY_T,true));app._selected40_input(key(KEY_T,false))
	check.call(session.flight_owner().frame_context().encounter.view.camera_mode==3,"Application view key failed to enter the native Mac orbit mode")
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=Vector2(400,350);press.pressed=true
	var move:=InputEventMouseMotion.new();move.position=Vector2(427,338)
	var release: InputEventMouseButton=press.duplicate();release.position=move.position;release.pressed=false
	for event in [press,move,release]:app._selected40_input(event)
	check.call(not session.flight_owner().frame_context().encounter.view.orbit_input.dragging and session.flight_owner().frame_context().encounter.view.orbit_input.units!=Vector2(25,-50),"Application orbit lost ordered native pointer input")
	app._selected40_input(key(KEY_T,true));app._selected40_input(key(KEY_T,false))
	app._selected40_input(key(KEY_UP,true));app._selected40_input(key(KEY_SPACE,true))
	now+=100000;app._selected40_tick(now)
	if app._transition_failed:check.call(false,app.status.text);app.free();return {}
	var controlled: Dictionary=session.flight_owner().frame_context()
	check.call(controlled.input.primary_held and controlled.input.commands!=Vector2.ZERO,"Shared application controls did not reach real flight/primary input")
	for code in [KEY_SPACE,KEY_UP]:app._selected40_input(key(code,false))
	app._selected40_input(key(KEY_G,true));app._selected40_input(key(KEY_G,false))
	check.call(session.is_paused() and session.scene.secondary_panel.selection_snapshot().open,"Application failed to open the actual secondary menu")
	var menu_parent: Dictionary=session.flight_owner().snapshot()
	check.call(not session.confirm_secondary(43) and session.flight_owner().snapshot()==menu_parent and session.is_paused(),"Invalid unpaid menu choice changed the world or dismissed selection")
	check.call(session.set_pause("focus",true,now),session.error)
	check.call(not session.confirm_secondary(42) and session.scene.secondary_panel.selection_snapshot().active==false,"Focus loss left modal paid selection active")
	check.call(session.set_pause("focus",false,now),session.error)
	app._selected40_input(key(KEY_DOWN,true));app._selected40_input(key(KEY_DOWN,false))
	app._selected40_input(key(KEY_ENTER,true));app._selected40_input(key(KEY_ENTER,false))
	check.call(not session.is_paused() and session.flight_owner().secondary_feedback().selected_item_id==42,"Actual menu keyboard confirmation failed to choose the owned EMP")
	check.call(session.rebase_time(now),session.error)
	# The active pad can disappear after its edge has left Controls. Disconnect
	# must discard that pending launch, without treating it as a release/fire.
	var pad:=InputEventJoypadButton.new();pad.device=19;pad.button_index=JOY_BUTTON_B;pad.pressed=true
	app._selected40_input(pad)
	check.call(session._secondary_pending and app._controls.device==19,"Controller did not queue the owned EMP edge")
	app._controller_connection(20,false)
	check.call(session._secondary_pending,"Disconnecting an unrelated controller erased the active pad request")
	app._controller_connection(19,false)
	check.call(not session._secondary_pending,"Disconnected active controller retained a paid launch")
	now+=100000;app._selected40_tick(now)
	check.call(not app._transition_failed and session.flight_owner().secondary_feedback().weapons[0].quantity==3 and not session.flight_owner().frame_context().input.secondary_requested,"Disconnected controller spent an EMP round")
	app._selected40_input(key(KEY_R,true));app._selected40_input(key(KEY_R,false))
	now+=100000;app._selected40_tick(now)
	check.call(not app._transition_failed,app.status.text)
	check.call(session.flight_owner().frame_context().input.secondary_requested,"Application lost the discrete secondary edge")
	check.call(session.flight_owner().secondary_feedback().weapons[0].quantity==2 and session.flight_owner().secondary_feedback().weapons[0].live,"Application input did not launch one real paid EMP")
	load("res://tests/fixtures/selected40_flight_checks.gd").check_secondary_retention(host,session.flight_owner(),2)
	now+=100000;app._selected40_tick(now)
	check.call(session.flight_owner().secondary_feedback().weapons[0].quantity==2 and session.flight_owner().secondary_feedback().weapons[0].live,"A held secondary button repeated or automatically detonated its paid projectile")
	app._selected40_input(key(KEY_R,true));app._selected40_input(key(KEY_R,false))
	now+=100000;app._selected40_tick(now)
	var detonation_events: Array=session.flight_owner().encounter_owner().snapshot().secondary_events
	check.call(detonation_events.any(func(event):return event.action=="detonated"),"Second application edge failed to detonate the retained EMP")
	check.call(session.scene.encounter.actors.map(func(row):return row.hull.get_instance_id())==ids,"Application rebuilt its retained cast during input/pause/view changes")
	await capture(host,app,"controls")
	# Explicit component damage, only after source entry release. The application
	# then runs all destruction/fade ticks and must consume the native exit once.
	var lethal: RefCounted=session.flight_owner()
	check.call(not lethal._player.normal_hit(100000).is_empty(),lethal._player.error)
	session._world=lethal
	var continued:=key(KEY_ENTER,true)
	app._selected40_input(continued)
	for tick in 200:
		now+=100000;app._selected40_tick(now)
		if app._transition_failed:check.call(false,app.status.text);app.free();return {}
		if session.flight_owner().destruction_owner().snapshot().phase=="game_over":break
	check.call(session.flight_owner().destruction_owner().snapshot().phase=="game_over" and session.prepare_game_over().is_empty(),"Native game-over did not finish its fade or accepted a held Continue")
	await capture(host,app,"game-over")
	app._selected40_input(continued)
	check.call(app.session==session and session.prepare_game_over().is_empty(),"Repeated held Continue exited without release")
	app._selected40_input(key(KEY_ENTER,false));app._selected40_input(key(KEY_ENTER,true))
	check.call(session.status=="game_over_transition_required",session.error)
	var before_exit: Dictionary=session.snapshot()
	if career!=null:check_career_retained(check,session.flight_owner(),career.snapshot(),"native game-over exit")
	now+=100000;app._selected40_tick(now)
	var result: Dictionary=app.game_over_result()
	check.call(app.session==null and result.get("transition",{}).get("source_state")==1 and result.get("flight",{}).get("campaign_cursor")==40,"Application failed to consume native game-over into source menu state1")
	check.call(not app.enter_game_over() and app.game_over_result()==result,"Application replayed an already consumed game-over exit")
	check.call(player.snapshot()==before_player and scenery.snapshot()==before_field and equipment.snapshot()==before_gear,"Application/camera/death acceptance changed supplied canonical owners")
	app.free()
	print("Selected40 application: native camera,7001ms entry,shared controls,pause,orbit,secondary and source1 exit checked; no earned departure/results")
	return {"application_only":true,"entry":init,"exit":result.get("transition",{}),"frames":before_exit.revision}

## Predict the ordinary entry drift with the installed native pilot, then place
## this detached fixture so that the first released contact is near the portal.
## No teleport, altered speed, equipment grant or save mutation advances it.
static func check_entry_contact(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted,template: RefCounted,career: RefCounted) -> Dictionary:
	var check: Callable=host.check
	var original: Dictionary=template.snapshot()
	var drift:=Transform3D.IDENTITY;var pilot: RefCounted=template.pilot_owner()
	for tick in 70:drift=pilot.advance_prepared(drift,1.0,0.1)
	drift=pilot.advance_prepared(drift,1.0,0.001)
	check.call(pilot.error.is_empty(),pilot.error)
	var near_pose:=Transform3D(Basis.IDENTITY,template.portal_owner().portal_snapshot().position+Vector3(900,0,0)-drift.origin)
	var builder:=Builder.new()
	if not builder.prepare(bindings,cat,library,player,scenery,equipment,reputation,near_pose,0.5,VIEWPORT,career):check.call(false,builder.error);return {}
	var entry: RefCounted=builder.world_owner();var start: Dictionary=entry.frame_context()
	var exposed: RefCounted=entry.portal_owner()
	check.call(exposed.observe_contact({"player_pose":near_pose,"environment_contact_enabled":true,"mining_active":false}) and not exposed.snapshot().contact.is_empty(),"Near-portal fixture does not exercise the live pull volume")
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):check.call(false,visuals.error);return {}
	var app:=Host.new();host.root.add_child(app);app.set_process(false);app.size=Vector2(1440,960)
	app.library=library;app.bindings=bindings;app.visuals=visuals
	await host.process_frame
	app.viewport.size=VIEWPORT;app.viewport.size_2d_override=VIEWPORT
	var now:=2000000
	if not app.enter_selected40_prepared(builder,now):check.call(false,app.status.text);app.free();return {}
	var session: Node3D=app.session
	# Even a zero-duration display/input sample must not pull during entry.
	app._selected40_tick(now)
	var state: Dictionary=session.flight_owner().frame_context()
	check.call(not app._transition_failed and state.portal_contact.contact.is_empty() and not state.portal_contact.portal_entered and state.player_pose==near_pose,"Arrival sampled portal pull/entry while its contact permission was disabled")
	if host.failures:app.free();return {}
	for tick in 71:
		var duration:=100 if tick<70 else 1
		var before: RefCounted=session.flight_owner();var previous: Dictionary=before.frame_context()
		var expected: Transform3D=before.pilot_owner().advance_prepared(previous.player_pose,previous.throttle,float(duration)/1000.0)
		now+=duration*1000;app._selected40_tick(now)
		if app._transition_failed:check.call(false,app.status.text);app.free();return {}
		state=session.flight_owner().frame_context()
		check.call(state.player_pose.is_equal_approx(expected) and state.portal_contact.contact.is_empty() and not state.portal_contact.portal_entered,"Fixed-eye entry applied hidden portal pull or latched a transition before its released contact pass")
		check.call(state.elapsed_ms==mini((tick+1)*100,7001) and state.portal.animation_elapsed_ms==state.elapsed_ms and state.boundary.is_empty(),"Near-portal entry stopped its native clocks or exited early")
		if tick<70:check.call(not session.can_control() and state.encounter.view.camera.eye==start.encounter.view.camera.eye,"Near-portal contact released input/camera before7001ms")
		if tick==69:await capture(host,app,"portal-entry-7000")
	check.call(state.elapsed_ms==7001 and state.encounter.sequence.entry_released and session.can_control() and state.player.damage_allowed,"Live portal prevented native entry release at7001ms")
	check.call(state.player_pose.origin.distance_to(state.portal.position)<999,"Native approach did not reach the intended post-entry contact volume")
	await capture(host,app,"portal-entry-released")
	var released: RefCounted=session.flight_owner();var released_before: Dictionary=released.snapshot()
	if not check_solid_contacts(host,released):app.free();return {}
	var paused: RefCounted=released.evaluate(1,Vector2.ZERO,1.0,false,true)
	check.call(paused!=null and paused.snapshot()==released_before,"Paused near-portal frame latched a contact or advanced the source entry")
	# Eligibility is shared with physical contacts, NOT the damage permission.
	for active in [false,true]:
		var probe: RefCounted=released.fork_for_frame()
		check.call(probe._player.set_permissions(active,false),probe._player.error)
		var observed: RefCounted=probe.evaluate(0)
		check.call(observed!=null and observed.frame_context().portal_contact.portal_entered==active and (observed.player_owner().snapshot().vitals.hull==0)==active,"Portal eligibility ignored native activity, or early-entry rejection incorrectly required damage permission")
	var broken: RefCounted=released.fork_for_frame();broken._portal._max_ms=0
	var broken_before: Dictionary=broken.snapshot()
	check.call(broken.evaluate(1)==null and broken.snapshot()==broken_before and released.snapshot()==released_before,"Late environment failure leaked a latched portal contact, player motion or career state")
	check_portal_phases(check,released,bindings,cat)
	# A normal first post-release player pass now owns the real contact.
	now+=1000;app._selected40_tick(now)
	if app._transition_failed:check.call(false,app.status.text);app.free();return {}
	var entered: RefCounted=session.flight_owner();state=entered.frame_context()
	check.call(not entered.portal_transition_required() and state.portal_contact.contact.entry_contact and state.elapsed_ms==7002 and state.boundary.is_empty() and state.player.vitals.hull==0 and state.portal_outcome.kind=="early_entry","First post-release early portal failed to apply its source-owned zero-hull consequence")
	check.call(state.player.vitals.armor==released_before.player.vitals.armor and state.player.vitals.shield==released_before.player.vitals.shield and entered.prepare_portal_transition().is_empty(),"Early portal consumed armor/shield or prepared an unearned mission41")
	check.call(session.camera.global_transform.is_equal_approx(state.encounter.view.camera.pose),"Near-portal source camera did not reach the actual application view")
	await capture(host,app,"portal-entry-contact")
	if career!=null:check_career_retained(check,entered,career.snapshot(),"entry portal contact")
	var settled: Dictionary=entered.snapshot()
	now+=100000;app._selected40_tick(now)
	state=session.flight_owner().frame_context()
	check.call(app.session==session and session.status=="running" and state.elapsed_ms==7102 and not session.can_control() and app.game_over_result().is_empty() and session.flight_owner().destruction_owner().snapshot().phase!="ready","Early portal failed to enter the actual native destruction path")
	check.call(state.player.vitals.hull==0 and session.flight_owner().equipment_owner().snapshot()==equipment.snapshot() and template.snapshot()==original,"Early portal resurrected its player, spent inventory or mutated its supplied parent")
	await capture(host,app,"portal-early-destruction")
	app.free()
	print("Selected40 portal:7000/7001 gate,next-pass7002 early entry clears hull only,native destruction; detached phase3 rejection/4-5 onward preparation; no earned journey/result")
	return {"complete":true,"released_ms":7001,"contact_ms":7002}

## Isolate the source tail's threshold with a native physical contact. Only
## this detached controller phase is changed; no scenario, career or save is
## claimed to have earned that phase or entered the successor world.
static func check_portal_phases(check: Callable,parent: RefCounted,bindings: RefCounted,cat: RefCounted) -> void:
	var original: Dictionary=parent.snapshot()
	for phase in [0,1,2,3,4,5]:
		for failed in [false,true]:
			var branch: RefCounted=parent.fork_for_frame()
			branch._encounter._selected40_sequence=branch._encounter._selected40_sequence.fork_for_frame()
			branch._encounter._selected40_sequence._state.phase=phase
			if failed:branch._state.campaign_phase="failure_instructions"
			check.call(branch._portal.observe_contact({"player_pose":branch.frame_context().player_pose,"environment_contact_enabled":true,"mining_active":false}),branch._portal.error)
			var pools: Dictionary=branch.player_owner().snapshot().vitals
			check.call(branch.portal_transition_required() and branch._resolve_portal_tail(),branch.error)
			var packet: Dictionary=branch.prepare_portal_transition()
			if phase<4:
				check.call(packet.is_empty() and branch.player_owner().snapshot().vitals==pools.merged({"hull":0},true) and branch.campaign_dialogue_visible()==failed,"Early source phase changed protected pools or its existing failure modal")
				check.call(branch.prepare_successor41_entry(bindings)==null,"Early or dead native portal admitted successor41")
			else:
				check.call(packet.source_state==2 and packet.next_cursor==41 and packet.mission.kind==4 and packet.mission.station_id==-1 and packet.system_id==-1 and packet.station_id==-1 and not packet.career_committed,"Allowed source phase fabricated a station target or committed a career")
				check.call(packet.freighter_hull==branch.encounter_owner().combat_snapshot().actors[0].vitals.hull and packet.player==branch.player_owner().snapshot() and packet.loadout==branch.player_owner().loadout() and branch.player_owner().snapshot().vitals==pools and not branch.campaign_dialogue_visible(),"Portal tail lost the actual surviving freighter/player or failed to arbitrate after the result poll")
				var before: Dictionary=branch.snapshot();var boundary: RefCounted=branch.evaluate(100)
				check.call(boundary!=null and boundary.frame_context().boundary=="selected40_portal_transition_required" and boundary.frame_context().elapsed_ms==before.elapsed_ms and branch.snapshot()==before,"Prepared onward request advanced a world without a native navigation commit")
				check.call(not branch.successor41_ready(bindings) and branch.prepare_successor41_entry(bindings)==null,"Preview-only selected40 component bypassed actual navigation to create41")
			if parent.career_owner()!=null:check.call(branch.career_owner().snapshot()==parent.career_owner().snapshot(),"Detached portal arbitration moved or paid the retained passenger career")
	check.call(parent.snapshot()==original,"Detached phase probes changed the living parent")

static func visuals_for(host: SceneTree,library: RefCounted) -> RefCounted:
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):host.check(false,visuals.error);return null
	return visuals

## Let the real script reveal its original freighter. Only then apply an
## explicit detached lethal contact; the ordinary destruction clock, mode4
## poll, original modal, input edge, and menu transition remain native.
static func check_campaign_failure(host: SceneTree,library: RefCounted,bindings: RefCounted,visuals: RefCounted,builder: RefCounted,career: RefCounted) -> void:
	var check: Callable=host.check
	if visuals==null:return
	var app:=Host.new();host.root.add_child(app);app.set_process(false);app.size=Vector2(1440,960)
	app.library=library;app.bindings=bindings;app.visuals=visuals
	await host.process_frame
	app.viewport.size=VIEWPORT;app.viewport.size_2d_override=VIEWPORT
	var now:=3000000
	if not app.enter_selected40_prepared(builder,now):check.call(false,app.status.text);app.free();return
	var session: Node3D=app.session
	for tick in 430:
		now+=100000;app._selected40_tick(now)
		if app._transition_failed:check.call(false,app.status.text);app.free();return
		if session.flight_owner().encounter_owner().combat_snapshot().actors[0].actor_kind==1:break
	var revealed: RefCounted=session.flight_owner();var preserved: Dictionary=revealed.snapshot()
	check.call(revealed.encounter_owner().combat_snapshot().actors[0].actor_kind==1 and revealed.player_owner().snapshot().vitals.hull>0,"Failure regression did not reach the native living freighter reveal")
	if host.failures:app.free();return
	app._selected40_input(key(KEY_ENTER,true))
	var lethal: RefCounted=revealed.fork_for_frame();var combat: RefCounted=lethal.encounter_owner().combat_owner()
	if not combat.begin_contact_pass(lethal.frame_context().random_state,true) or combat.normal_hit(0,1000000,false).is_empty():check.call(false,combat.error);app.free();return
	lethal._encounter._combat=combat;lethal._random=combat.contact_random_state()
	session._world=lethal
	var observed_mode4:=false;var opened:=false
	for tick in 250:
		var before: RefCounted=session.flight_owner();var mode: int=before.encounter_owner().combat_snapshot().actors[0].actor_mode
		observed_mode4=observed_mode4 or mode==4
		now+=100000;app._selected40_tick(now)
		if app._transition_failed:check.call(false,app.status.text);app.free();return
		var current: RefCounted=session.flight_owner()
		check.call(not current.campaign_dialogue_visible() or mode==4,"Failure opened on lethal contact or unfinished breakup instead of native mode4")
		if current.campaign_dialogue_visible():opened=true;break
	check.call(opened and observed_mode4 and session.flight_owner().player_owner().snapshot().vitals.hull>0,"Completed native freighter breakup did not open the living-player failure conversation")
	if host.failures:app.free();return
	var failed: RefCounted=session.flight_owner();var frozen: Dictionary=failed.snapshot()
	var result: Dictionary=failed.campaign_result();var expected: Array=load("res://src/content/kappa_outcome_definitions.gd").failure_lines(bindings,library)
	check.call(result.dialogue.text==expected[0].text and result.dialogue.speaker_id==16 and result.dialogue.count==1 and not result.dialogue.previous_available,"Failure lost the shared original localized line, portrait or acknowledgement count")
	check.call(session.scene.feedback.dialogue.visible and not session.can_control() and not session.flight_hud_visible() and not session.scene.secondary_panel.visible,"Visible failure left flight/HUD or weapon input active")
	check.call(failed.camera_input(3)==null and failed.select_secondary(42)==null and failed.request_game_over_exit()==null,"Failure modal admitted camera, weapon or unearned death acknowledgement")
	check.call(failed.request_campaign_failure_exit(true)==null and failed.snapshot()==frozen,"Paused native failure acknowledgement mutated the live frame")
	if career!=null:check_career_retained(check,failed,career.snapshot(),"freighter failure modal")
	await capture(host,app,"campaign-failure")
	now+=9000000;app._selected40_tick(now)
	check.call(session.flight_owner().snapshot()==frozen and revealed.snapshot()==preserved,"Waiting for failure acknowledgement advanced time, actors, RNG, career or the living parent")
	app._selected40_input(key(KEY_ENTER,true))
	check.call(session.prepare_game_over().is_empty(),"A pre-held Enter acknowledged the new failure modal")
	check.call(session.set_pause("user",true,now),session.error)
	app._selected40_input(key(KEY_ENTER,false));app._selected40_input(key(KEY_ENTER,true))
	check.call(session.prepare_game_over().is_empty() and session.scene.feedback.dialogue._next.disabled,"Paused failure input acknowledged or enabled its original Next button")
	check.call(session.set_pause("user",false,now),session.error)
	app._selected40_input(key(KEY_ENTER,true))
	check.call(session.prepare_game_over().is_empty(),"Resuming a held acknowledgement dismissed the failure")
	app._selected40_input(key(KEY_ENTER,false));app._selected40_input(key(KEY_ENTER,true))
	check.call(session.status=="game_over_transition_required" and session.prepare_game_over().get("campaign_failure",{}).get("outcome")=="failed","Fresh original failure acknowledgement did not request the source menu")
	var accepted: RefCounted=session.flight_owner()
	check.call(accepted.campaign_result().phase=="failure_acknowledged" and accepted.request_campaign_failure_exit()==null and accepted.player_owner().snapshot()==failed.player_owner().snapshot() and accepted.equipment_owner().snapshot()==failed.equipment_owner().snapshot(),"Failure acknowledgement repeated, healed the player or changed paid inventory")
	check.call(not session.scene.feedback.present(failed,failed.frame_context().elapsed_ms),"Failure feedback replayed its unacknowledged parent")
	if career!=null:check_career_retained(check,accepted,career.snapshot(),"acknowledged freighter failure")
	now+=1000;app._selected40_tick(now)
	var menu: Dictionary=app.game_over_result()
	check.call(not app._transition_failed and app.session==null and menu.get("transition",{}).get("source_state")==1 and menu.get("transition",{}).get("campaign_failure",{}).get("reward_credits")==0,"Failure did not reach the application menu without a reward or fabricated retry")
	await capture(host,app,"campaign-failure-menu")
	app.free()
	print("Selected40 campaign failure: real reveal,detached lethal contact,native breakup mode4,original silent one-line modal,held/pause guards,source-state1 menu; no campaign success or side-job settlement")

## Detached contact poses use the existing authored station/asteroid volumes.
## These probes neither dock nor relocate the canonical retained career.
static func check_solid_contacts(host: SceneTree,origin: RefCounted) -> bool:
	var check: Callable=host.check;var original: Dictionary=origin.snapshot()
	var station: RefCounted=origin.station_owner();var exterior: Dictionary=station.snapshot()
	var shapes: Array=exterior.collision.get("shapes",exterior.collision.get("boxes",[]))
	var point:=Vector3.INF
	for shape in shapes:
		var candidate: Vector3=exterior.pose.origin+shape.center
		if shape.get("kind",1)==0:candidate.x+=float(shape.radius)*0.25
		if station.point_volume(candidate)>=0:point=candidate;break
	check.call(point.is_finite(),"Station regression could not find an authored interior point")
	if not point.is_finite():return false
	var bodies: Dictionary=origin.scenery_owner().read_snapshot().bodies
	var rock: Dictionary={}
	for body in bodies.objects:
		if body.active and body.collision_enabled and body.vitals.hull>0 and body.half_extent>1:
			rock=body;break
	check.call(not rock.is_empty(),"Contact regression lost its actual live native asteroid")
	if rock.is_empty():return false
	for kind in ["station","asteroid"]:
		var position: Vector3=point if kind=="station" else rock.position+Vector3(1,0,0)
		for flags in [[false,true],[true,false],[true,true]]:
			var probe: RefCounted=origin.fork_for_frame()
			probe._pose=Transform3D(Basis.IDENTITY,position);probe._statistics_pose=probe._pose
			check.call(probe._player.set_permissions(flags[0],flags[1]),probe._player.error)
			var before: Dictionary=probe.snapshot()
			var plan: Dictionary=probe._physical.plan(probe._player.collision_context(probe._pose),bodies,true)
			check.call(not plan.is_empty(),probe._physical.error)
			if plan.is_empty():return false
			check.call(plan.operations.any(func(operation):return operation.kind==kind)==flags[0],"Authored contact probe missed its intended native volume or activity gate: "+kind)
			var expected: RefCounted=probe.player_owner()
			for operation in plan.operations:
				if operation.kind=="asteroid":check.call(not expected.normal_hit(operation.player_damage).is_empty(),expected.error)
			var observed: RefCounted=probe.evaluate(0,Vector2.ZERO,0)
			check.call(observed!=null,"Native "+kind+" contact interrupted the selected frame: "+probe.error)
			if observed==null:return false
			var state: Dictionary=observed.frame_context()
			check.call(state.physical_contacts==plan.operations and state.player_pose.origin==plan.center_after,"Selected frame changed the shared contact projection or operation order: "+kind)
			check.call(state.player.vitals==expected.snapshot().vitals,"Station projection invented damage or asteroid contact lost native player damage")
			check.call(state.boundary.is_empty() and not observed.portal_transition_required(),"Solid scenery fabricated station arrival, portal contact or mission completion")
			if kind=="asteroid" and flags[0]:check.call(observed.scenery_owner().read_snapshot().bodies.objects[int(rock.index)].vitals.hull<=0,"Native asteroid contact lost its source body damage")
			check.call(probe.snapshot()==before and origin.snapshot()==original,"Solid-contact probe mutated its retained player, field or career")
	print("Selected40 solid contact: actual station projection without damage-field error; native asteroid/player damage, activity and invulnerability remain separate")
	return true

static func check_captured_controls(host: SceneTree,app: Control,bindings: RefCounted,cat: RefCounted,equipment: RefCounted,now: int) -> Dictionary:
	var check: Callable=host.check;var session: Node3D=app.session
	var parent: RefCounted=session.flight_owner();var original: Dictionary=parent.snapshot()
	var vehicle: RefCounted=load("res://src/simulation/vehicle_response.gd").new()
	if not vehicle.configure(bindings,cat,bindings.base_content_id):check.call(false,vehicle.error);return {}
	var loadout: Dictionary=equipment.snapshot().loadout
	var resolved: Dictionary=vehicle.resolve(loadout.ship_id,[],loadout.equipment_ids)
	if resolved.is_empty():check.call(false,vehicle.error);return {}
	var handling: float=resolved.response_factor
	check.call(is_equal_approx(parent.pilot_owner().response_factor(),handling),"Camera handling did not come from the actual installed vehicle")
	var rules: Dictionary=bindings.fast_forward.camera
	var rig=load("res://src/simulation/camera_rig.gd")
	var normal_look: float=rig.single(float(rules.fixed_normal_look_rate));var normal_eye: float=rig.single(float(rules.fixed_normal_eye_rate))
	var response: Dictionary=parent.frame_context().encounter.view.camera_response
	check.call(not response.dirty and not response.relative_capture and response.look_rate==normal_look and response.eye_rate==normal_eye,"Normal entry did not refresh source fixed response rates: "+str(response))
	var held: RefCounted=parent.evaluate(100,Vector2.ZERO,1.0,false,true,VIEWPORT,0.0,false,-1,true)
	check.call(held!=null and held.snapshot()==original,"Paused capture-mode change altered camera history or native state")
	check.call(parent.evaluate(100,Vector2.INF,1.0,false,false,VIEWPORT,0.0,false,-1,true)==null and parent.snapshot()==original,"Rejected captured frame partially committed camera rates")
	app.set_player_mode(true)
	app._selected40_input(key(KEY_M,true));app._selected40_input(key(KEY_M,false))
	check.call(app._mouse_captured,"Actual M action did not capture the player mouse")
	var move:=InputEventMouseMotion.new();move.screen_relative=Vector2(24,-12)
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	app._input(move);app._input(press);app._controls.advance_mouse(0.1)
	now+=100000;app._selected40_tick(now)
	if app._transition_failed:check.call(false,app.status.text);return {}
	var state: Dictionary=session.flight_owner().frame_context();response=state.encounter.view.camera_response
	check.call(state.input.commands.is_equal_approx(Vector2(-0.2,-0.4)) and state.input.primary_held,"Captured relative motion/left-click did not reach the native application frame")
	var factor: float=rig.single(handling);var scaled: float=rig.single(factor*float(rules.handling_scale))
	var look: float=rig.single(rig.single(rig.single(float(rules.look_complement)-scaled)*float(rules.look_scale))+float(rules.look_add))
	var eye: float=rig.single(rig.single(scaled*float(rules.eye_scale))+float(rules.eye_add))
	check.call(response.relative_capture and not response.dirty and response.cached_handling==factor and response.player_handling==factor and response.look_rate==look and response.eye_rate==eye,"Captured camera ignored installed handling or source single-precision response")
	check.call(parent.snapshot()==original,"Captured response mutated its retained parent")
	check.call(session.camera.global_transform.is_equal_approx(state.encounter.view.camera.pose),"Captured response failed to reach the actual camera")
	await capture(host,app,"captured-mouse")
	# Turning capture off must release the held mouse button and restore normal
	# rates, retaining the source handling cache rather than resetting the view.
	app._selected40_input(key(KEY_M,true));app._selected40_input(key(KEY_M,false))
	app._controls.advance_mouse(0.1);now+=100000;app._selected40_tick(now)
	if app._transition_failed:check.call(false,app.status.text);return {}
	state=session.flight_owner().frame_context();response=state.encounter.view.camera_response
	check.call(not app._mouse_captured and not state.input.primary_held and state.input.commands==Vector2.ZERO,"Capture release left mouse steering/fire held")
	check.call(not response.relative_capture and response.cached_handling==factor and response.look_rate==normal_look and response.eye_rate==normal_eye,"Keyboard return discarded handling history or retained captured rates: "+str(response))
	app.set_player_mode(false)
	print("Selected40 captured application: installed handling=%s; source look=%s eye=%s; real M/motion/click and release"%[handling,look,eye])
	return {"now":now,"complete":true}

## Reuse the native career ledger; these are malformed detached inputs, not
## altered saves or fabricated successful passenger/campaign transitions.
static func check_career_binding(check: Callable,frame: RefCounted,bindings: RefCounted,career: RefCounted) -> void:
	var original: Dictionary=career.snapshot();var before: Dictionary=frame.snapshot()
	var encounter: RefCounted=frame.encounter_owner();var field: RefCounted=frame.scenery_owner()
	for field_name in ["campaign_cursor","station_id","passengers","active_offer_id","accepted_contact","mission"]:
		var invalid: RefCounted=career.fork()
		match field_name:
			"campaign_cursor":invalid._state.campaign_cursor=39
			"station_id":invalid._state.station_id=field.read_snapshot().station_id
			"passengers":invalid._state.passengers=0
			"active_offer_id":invalid._state.active_offer_id=-1
			"accepted_contact":invalid._state.accepted_contact.offer.mission.quantity+=1
			"mission":invalid._state.mission.story=true
		var rejected: Dictionary=invalid.snapshot()
		check.call(not invalid.bind_selected40_world(bindings,encounter._control,field) and invalid.snapshot()==rejected,"Selected40 accepted or partially committed malformed independent career: "+field_name)
	for foreign in [null,RefCounted.new(),load("res://src/simulation/opening_scenery.gd").new()]:
		var invalid: RefCounted=career.fork()
		check.call(not invalid.bind_selected40_world(bindings,encounter._control,foreign) and invalid.snapshot()==original,"Selected40 career accepted an unrelated scenery owner")
	var detached: RefCounted=frame.career_owner()
	var bound: Dictionary=detached.snapshot()
	check.call(not detached.bind_selected40_world(bindings,encounter._control,field) and detached.snapshot()==bound,"Repeated career binding reset its native accounting")
	check.call(not detached.poll_station(frame.equipment_owner(),bindings) and detached.snapshot()==bound,"Story flight opened the independent passenger station result")
	check.call(detached.acknowledge_flight_result(encounter._control,1).is_empty() and detached.snapshot()==bound,"Story flight paid or retired an unearned side-job result")
	check.call(encounter.finish_contract_session(detached)==null and detached.snapshot()==bound,"Accounting-only selected40 component released an unearned arrival/result")
	var observed: Dictionary=encounter.evaluate_contract_session(detached,false,true,true)
	check.call(not observed.is_empty() and not observed.get("opened",true),"Ordinary result polling selected the retained passenger job in story40")
	if not observed.is_empty():
		var repeated: Dictionary=encounter.evaluate_contract_session(observed.session,false,true,true)
		check.call(not repeated.is_empty() and repeated.session.snapshot()==observed.session.snapshot(),"Repeated selected40 career polling paid or advanced twice")
	check.call(career.snapshot()==original and frame.snapshot()==before,"Career arbitration mutated supplied station/world owners")

static func check_career_retained(check: Callable,frame: RefCounted,original: Dictionary,label: String) -> void:
	var state: Dictionary=frame.frame_context();var retained: Dictionary=state.get("career",{})
	check.call(not retained.is_empty(),label+": native selected40 career is missing")
	if retained.is_empty():return
	for key in ["station_id","campaign_cursor","credits","passengers","mission","active_offer_id","accepted_contact","pending_result","result_serial","completed_side_missions","delivery_statistics","last_result","void_source"]:
		check.call(retained.get(key)==original.get(key),label+": story selection settled or replaced independent side-job state: "+key)
	check.call(retained.flight.ordinary_context.mission.is_empty() and retained.flight.story_mission.kind==161 and retained.flight.story_mission.station_id==-1 and retained.mission.kind==11 and not retained.mission.story,label+": active campaign and retained passenger mission were conflated")
	check.call(retained.flight.elapsed_ms==state.elapsed_ms and retained.flight.selected40_entry.station_id==frame.environment_state().entry.station_id,label+": retained ledger lost the actual selected world/clock")
	print("Selected40 career %s: story161 target-1; separate %d passengers to station%d, credits%d, result serial%d unchanged"%[label,retained.passengers,retained.mission.station_id,retained.credits,retained.result_serial])

static func key(code: int,pressed: bool) -> InputEventKey:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
	return event

static func capture(host: SceneTree,app: Control,label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
	var image: Image=app.viewport.get_texture().get_image()
	host.check(image!=null and not image.is_empty(),"Actual selected application viewport produced no image")
	if image!=null and not host.captures.is_empty():host.check(image.save_png(host.captures.path_join("selected40-application-"+label+".png"))==OK,"Application capture failed")
