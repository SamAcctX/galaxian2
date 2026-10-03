extends "res://tests/post_probe_application.gd"
## Public-map arrival from the immutable earned202 Ga'kkrr save. Selection,
## cancellation, confirmation, travel and the complete session use their native
## owners. This check does not replay the contest or claim another earned38 save.
const BakkaArrival=preload("res://src/content/bakka_contest_definitions.gd")
const SOURCE_SHA="8ca722bb5ce6ce1fd9898ec1baef845f3c9fa594c7ba7dfc04861acb6c1d8ebb"

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var original: Dictionary=app.session.station_owner().snapshot()
	check(FileAccess.get_sha256(saved)==SOURCE_SHA and original.campaign_cursor==36 and original.loadout.station_id==29 and BakkaArrival.available(definitions),"Use the actual earned202 Ga'kkrr36 source without relabelling")
	check(original.contracts.credits==22100 and original.contracts.passengers==3 and original.cargo.used==0,"The saved arrival lost its actual wallet, passengers or cleared hold")
	var clock:=OS.get_environment("GOF2_ALIOTH_WORLD_BASE")
	check(clock=="1789100373","Use the recorded Ga'kkrr departure clock")
	if failures:return
	_world_clock_base=clock.to_int()
	chapter_directory=arrival_save_directory()
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use runner-isolated arrival output")
	if failures:return
	app.enable_saves(chapter_directory)
	app.show();app.present_session();await process_frame;resume_application_focus()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var session=app.session
	var departing: RefCounted=session.flight_owner()
	var before: Dictionary=departing.snapshot()
	check(PostProbeNavigation.destination_supported(definitions,36,original.mission,27) and departing._local_travel.supports_destination(27),"Complete B'akka support did not reach the native destination list")
	if failures:return
	if not app.open_map(now_us):check(false,app.status.text);return
	if app.map_panel.snapshot().route_mode=="galaxy":app.map_panel.show_system(int(app.session.snapshot().location.system_id))
	var held: Dictionary=session.snapshot()
	check(app.map_panel.is_visible_in_tree() and app.map_panel.snapshot().rows.any(func(row):return row.station_id==27 and row.supported),"The visible local map cannot select B'akka")
	app.map_panel.select_station(27);app.map_panel.request_confirmation()
	check(app.map_panel.snapshot().confirmation_visible and session.snapshot()==held,"Map selection traveled before confirmation")
	app.map_panel.back()
	check(not app.map_panel.snapshot().confirmation_visible and session.snapshot()==held,"Cancelling the B'akka course changed the earned flight")
	await capture_free_application("saved202-bakka-map-selection")
	app.map_panel.request_confirmation()
	check(app.map_panel.snapshot().confirmation_visible and session.snapshot()==held,"Reopening confirmation changed the retained flight")
	await capture_free_application("saved202-bakka-map-confirmation")
	if failures or not app.confirm_map_planet(27,now_us):check(false,app.status.text);return
	check(not session.map_active() and not app.map_panel.visible and departing.snapshot()==before,"Confirmed map travel retained its modal or changed the departure owner")
	for tick in 2000:
		if session.status=="local_arrival_transition_required":break
		if not application_step():return
		if session.flight_owner().death_active():check(false,"The map arrival pilot died during native travel");return
		if tick%100==0:await process_frame
	check(session.status=="local_arrival_transition_required","Native planet guidance did not complete its acquisition and launch")
	if failures:return
	var completed: RefCounted=session.flight_owner()
	var completed_state: Dictionary=completed.snapshot()
	var packet: Dictionary=completed.prepare_local_arrival()
	check(packet.get("station_id")==27 and packet.get("from_station_id")==29 and packet.get("campaign_cursor")==36,"The real transit did not retain its source, target and campaign")
	check(completed_state.world_elapsed_ms>before.world_elapsed_ms and completed_state.player_pose!=before.player_pose and completed_state.player.vitals.hull>0,"Map admission skipped native motion or surviving-player validation")
	var save_hash:=FileAccess.get_sha256(app.station_save_path())
	if failures or not app.enter_local_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var arrival: Dictionary=app.session.snapshot()
	check(arrival.campaign_cursor==36 and arrival.location.station_id==27 and arrival.location.system_id==5 and arrival.actors.size()==8,"Complete arrival did not select the original B'akka cast and destination")
	check(arrival.cargo==completed_state.cargo and arrival.mission==original.mission and arrival.progress==completed_state.progress,"Arrival changed live cargo, progress or the pending story")
	for key in ["credits","passengers","mission","accepted_contact","blueprints","void_source","completed_side_missions","delivery_statistics"]:
		check(arrival.contracts[key]==completed_state.contracts[key],"Arrival changed the independent career: "+key)
	check(completed.snapshot()==completed_state and departing.snapshot()==before,"Arrival mutated a retained departure owner")
	check(not app.session.can_control() and app.session.flight_owner().prepare_station().is_empty(),"Arrival skipped its entry or completed an unplayed contest")
	await capture_free_application("saved202-bakka-incoming")
	if failures:return
	await verify_arrival_briefing()
	check(FileAccess.get_sha256(saved)==SOURCE_SHA and FileAccess.get_sha256(app.station_save_path())==save_hash,"Arrival or briefing overwrote the earned station checkpoint")
	check(PostProbeNavigation.destination_supported(definitions,36,original.mission,27),"Arrival changed the complete source-bound route capability")
	if not failures:print("Saved202 public map: selection/cancel/confirm -> native Ga'kkrr acquisition/launch -> complete B'akka incoming -> original briefing; no battle replay or new earned save claimed")

func arrival_save_directory() -> String:
	return OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")

func verify_arrival_briefing() -> void:
	for tick in 200:
		if app.session.snapshot().dialogue.visible:break
		if not application_step():return
	var state: Dictionary=app.session.snapshot()
	check(state.phase=="briefing" and state.dialogue.visible and state.dialogue.count==2,"The complete B'akka arrival omitted its original two-line briefing")
	if failures:return
	var events: Array=definitions.mido_travel.bakka_contest.mission.briefing_events
	var panel=app.session.scene.dialogue
	check(panel.is_visible_in_tree() and not app.session.can_control() and state.dialogue.text_id==int(events[0].text_id),"The original first briefing line did not own the visible controls")
	await capture_free_application("saved202-bakka-briefing-first")
	if not app.session.navigate("next"):check(false,app.session.error);return
	state=app.session.snapshot()
	check(state.dialogue.index==1 and state.dialogue.text_id==int(events[1].text_id) and state.campaign_cursor==36,"Briefing Next changed its original text or advanced the campaign")
	check(app.session.briefing_audio.snapshot().history.map(func(event):return event.source_id)==[182,183],"The arrival briefing omitted its original voices")
	await capture_free_application("saved202-bakka-briefing-last")
	if not app.session.navigate("next"):check(false,app.session.error);return
	check(app.session.can_control() and not app.session.snapshot().dialogue.visible and app.session.snapshot().campaign_cursor==36 and app.session.flight_owner().prepare_station().is_empty(),"Final briefing acknowledgement completed the contest or failed to release flight")
