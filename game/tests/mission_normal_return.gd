extends "res://tests/mission_portal_return.gd"
## The setup still uses the documented detached aim/radio component stimuli.
## Only the native completed escape can admit this normal-space construction.
const NormalConstruction=preload("res://src/simulation/first_flight_construction.gd")
const FreeEntry=preload("res://src/content/free_flight_definitions.gd")
const Host=preload("res://src/presentation/opening_preview.gd")
const EarnedApplication=preload("res://tests/void_ambush_application.gd")
var application: Control

class PreparedWorld extends RefCounted:
	var world: RefCounted
	func world_owner() -> RefCounted:return world

func prepare_scene(visuals: RefCounted) -> bool:
	# Create the real application session BEFORE the first native frame. Keep
	# that same session and scene for the inherited ambush/escape component.
	var prepared:=PreparedWorld.new();prepared.world=active
	application=Host.new();root.add_child(application);application.set_process(false);application.size=Vector2(1440,960)
	application.library=library;application.bindings=bindings;application.visuals=visuals
	application.viewport.size=root.size;application.viewport.size_2d_override=root.size
	if not application.enter_mission_prepared(prepared,1000000):check(false,application.status.text);application.free();return false
	scene=application.session.scene
	scene.world_changed.connect(func(candidate):active=candidate)
	return true

func present() -> bool:
	if not super.present():return false
	# The fixture drives native frames explicitly. Publish each accepted scene
	# to the existing session exactly as its acknowledged scene callback does.
	application.session._accepted_world(active)
	return true

func acknowledge() -> bool:
	var retained_session: Node3D=application.session
	var retained_world: RefCounted=active.initialized_world_owner()
	if not await super.acknowledge():return false
	var published: Dictionary=application.session.snapshot()
	check(EarnedApplication.observed_dialogue(application.session)==active.dialogue(),"The earned pilot could not observe the retained mission dialogue")
	check(application.session==retained_session and active.initialized_world_owner()==retained_world,"Dialogue acknowledgement rebuilt the active mission session or Void world")
	check(published.campaign_cursor==active.snapshot().campaign_cursor and published.campaign_cursor==published.career.campaign_cursor,"Application reported the player's entry cursor instead of the acknowledged mission")
	check(published.player==active.player_owner().snapshot(),"Publishing the active mission changed the retained player")
	return failures==0

func verify_retained_flight() -> void:
	await super.verify_retained_flight()
	if failures:return
	var before: Dictionary=active.snapshot();var transfer:=ReturnEntry.new()
	if not transfer.prepare(bindings,catalogues,active):check(false,transfer.error);return
	var normal:=NormalConstruction.new()
	var bodies: RefCounted=load("res://src/content/scenery_body_resources.gd").new()
	var effects: RefCounted=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	check(not normal.prepare_mission_return(bindings,catalogues,ReturnEntry.new(),100,100) and normal.snapshot().is_empty(),"Unprepared return created a normal world")
	if not normal.prepare_mission_return(bindings,catalogues,transfer,100,100,true,bodies,effects):check(false,normal.error);return
	var built: Dictionary=normal.snapshot();var admitted: RefCounted=normal.mission_context_owner()
	var destination: Dictionary=transfer.snapshot();var career: Dictionary=transfer.career_owner().snapshot()
	check(built.campaign_cursor==42 and built.location.station_id==destination.return_station_id and built.location.system_id==destination.return_system_id and built.location.station_id!=10,"Normal construction skipped the retained return location")
	check(admitted.has_feature("normal_space") and not admitted.has_feature("void_environment"),"Normal construction retained the Void world feature")
	check(built.scenery.world_initialization.npc_construction.actors.is_empty(),"Normal unfinished story revived the Void cast")
	check(normal.equipment_owner().snapshot()==transfer.equipment_owner().snapshot() and normal.contract_owner().snapshot()==career,"Normal construction changed earned equipment or the independent career")
	check(normal.player_owner().cache_snapshot()==destination.player_cache,"Normal construction repaired or reset the transferred player cache")
	check(built.input_random_state==destination.random_state,"Normal construction discarded the terminal escape stream")
	check(built.entry_elapsed_ms==0 and not built.entry_released and not built.activated,"Normal construction inherited the previous world clock")
	check(FreeEntry.player_entry(bindings,built.location.station_id,normal.player_owner().loadout().ship_id,42).is_empty(),"Normal capability opened generic player admission")
	var generic:=NormalConstruction.new()
	check(not generic.prepare_portal_return(bindings,catalogues,normal.equipment_owner(),normal.contract_owner(),{},100,100,true,null,null,destination.player_cache),"Normal capability opened the generic portal-return gate")
	var selected: Dictionary=admitted.normal_population_context(Vector3.ZERO)
	check(not Context.new().admit(bindings,catalogues,selected,normal.equipment_owner().snapshot().loadout),"A copied normal context bypassed the native terminal transfer")
	var invalid: Dictionary=selected.duplicate(true);invalid.station_id=10
	check(not Context.normal_population_matches(bindings,invalid,admitted),"Normal population accepted a different station")
	check(not normal.prepare_mission_return(bindings,catalogues,transfer,100,100) and normal.snapshot()==built,"Repeated construction replaced its accepted normal world")
	check(active.snapshot()==before and transfer.matches_departure(active),"Normal candidate construction mutated the old Void world")
	print("Normal return constructed at station ",built.location.station_id,"/system ",built.location.system_id,"; pools ",normal.player_owner().cache_snapshot().values,"; field objects ",built.scenery.get("remaining_count",-1),"; career and paid ammunition preserved")
	await verify_normal_application(normal)

func verify_normal_application(normal: RefCounted) -> void:
	var app:=application
	var visuals: RefCounted=app.visuals
	var old_session: Node3D=app.session
	# Dispatch the existing terminal boundary exactly as a normal session tick.
	old_session._accepted_world(active);old_session.rebase_time(1000000)
	if not old_session.step(1100000):check(false,old_session.error);app.free();return
	var old: Dictionary=old_session.snapshot()
	check(old_session.status=="normal_space_return_required","Host failed to retain the actual escape boundary")
	check(not app.enter_mission_normal_space(1200000,-1,100) and app.session==old_session and old_session.snapshot()==old and app.viewport.get_camera_3d()==old_session.camera,"Rejected normal-space construction changed the old session or camera")
	var staged: Node3D=load("res://src/presentation/first_flight_session.gd").new();app.viewport.add_child(staged)
	if not staged.configure_prepared_arrival(library,bindings,visuals,catalogues,normal,1200000,100):check(false,staged.error);app.free();return
	check(not app._accept_first_flight(staged,1200000,ReturnEntry.new()) and app.session==old_session and old_session.snapshot()==old and app.viewport.get_camera_3d()==old_session.camera,"Final source recheck accepted an unissued return or replaced the old world")
	if not app.enter_mission_normal_space(1300000,100,100):check(false,app.status.text);app.free();return
	check(app.session is Host.FirstFlightSession and app.session!=old_session and not app._transition_failed,"Host did not accept the retry as an ordinary native session")
	check(app.viewport.get_camera_3d()==app.session.camera,"Normal-space camera was not committed with the session")
	check(app.session.flight_owner().station_response_flags()==active.station_response_flags(),"Normal-space application discarded retained station responses")
	if DisplayServer.get_name()!="headless":
		await capture_normal_scene(app,"normal-return-arrival")
	await verify_normal_result(app)
	app.free()

func verify_normal_result(app: Control) -> void:
	var session: Node3D=app.session
	var initial: Dictionary=session.snapshot()
	check(initial.world_elapsed_ms==0 and not initial.dialogue.visible and initial.campaign_cursor==42,"Normal session did not start a fresh world/result clock")
	var now:=2000000
	if not session.rebase_time(now) or not session.set_pause("user",true,now):check(false,session.error);return
	var paused: Dictionary=session.snapshot()
	now+=18000000
	if not session.step(now):check(false,session.error);return
	check(session.snapshot()==paused,"Paused normal space advanced world time or mission completion")
	if not session.set_pause("user",false,now):check(false,session.error);return
	for tick in 100:
		now+=100000
		if not session.step(now,Vector2.ZERO,false,false,0.0,true):check(false,session.error);return
	var at_limit: Dictionary=session.snapshot()
	check(at_limit.world_elapsed_ms==10000 and not at_limit.dialogue.visible and at_limit.campaign_cursor==42,"Normal-space result triggered at or before its strict ten-second boundary")
	for tick in 80:
		if session.snapshot().dialogue.visible:break
		now+=100000
		if not session.step(now,Vector2.ZERO,false,false,0.0,true):check(false,session.error);return
	var result: Dictionary=session.snapshot()
	check(result.dialogue.visible and result.world_elapsed_ms>10000 and result.campaign_cursor==42,"Normal-world clock and shared poll did not produce result42")
	if not result.dialogue.visible:return
	print("Normal result42 became visible at ",result.world_elapsed_ms,"ms with text ",result.dialogue.text_id)
	var speakers:=[0,0,6,0]
	for page in 4:
		var state: Dictionary=session.snapshot()
		check(EarnedApplication.observed_dialogue(session)==state.dialogue,"The earned pilot used a Void-only dialogue accessor after normal return")
		check(state.dialogue.text_id==2054+page and state.dialogue.voice_event_id==421+page and state.dialogue.speaker_id==speakers[page],"Normal result42 changed its source page, speaker or voice")
		if DisplayServer.get_name()!="headless" and page==0:
			app.present_session()
			await capture_normal_scene(app,"normal-return-result-world")
		if page<3 and not session.navigate("next"):check(false,session.error);return
	check(session.snapshot().campaign_cursor==42,"Result inspection advanced the campaign before final Next")
	var previous: RefCounted=session.flight_owner();var previous_state: Dictionary=previous.snapshot()
	if not session.navigate("next"):check(false,session.error);return
	var acknowledged: Dictionary=session.snapshot()
	check(session.status=="mission_station_return_required" and acknowledged.campaign_cursor==43 and acknowledged.mission_station_return=={"source_cursor":42,"campaign_cursor":43,"station_id":10},"Final Next failed to request the recipe's automatic Thynome continuation")
	check(acknowledged.location.station_id==initial.location.station_id and acknowledged.contracts.mission==initial.contracts.mission and acknowledged.contracts.credits==initial.contracts.credits,"Final Next teleported early, changed the passenger job or paid a false reward")
	check(previous.snapshot()==previous_state,"Final Next mutated the previous result frame")
	check(not session.navigate("next") and session.snapshot()==acknowledged,"Repeated final Next advanced the campaign twice")
	now+=100000
	if not session.step(now,Vector2.ONE,true,false,1.0,false):check(false,session.error);return
	check(session.snapshot()==acknowledged,"Pending station continuation advanced the retired normal world")
	print("Result42 acknowledged once; native Thynome station10 continuation pending at cursor43; no station arrival/save claimed")

func capture_normal_scene(app: Control,label: String) -> void:
	# Set the focused landscape viewport after the preview's asynchronous
	# debug-container layout, rather than capturing that container's minimum size.
	await process_frame;await process_frame
	app.viewport.size=Vector2i(1440,900);app.viewport.size_2d_override=Vector2i(1440,900)
	app.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await process_frame;await RenderingServer.frame_post_draw
	var image: Image=app.viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(capture_path)
	check(image.get_size()==Vector2i(1440,900) and image.save_png(capture_path.path_join(label+".png"))==OK,"Normal-space landscape capture failed")

func capture(_label: String) -> void:
	# The new check will capture normal space, not re-export accepted Void shots.
	pass
