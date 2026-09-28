extends "res://tests/post_probe_application.gd"
## One actual original202 hop from the retained Genoh85 checkpoint. No prefix replay.
const AccessNavigation=preload("res://src/simulation/system_navigation.gd")
const SOURCE_SHA="a4a88b9f7b170c7d770ceeea2dd1a6c23684c91609ea243c524747543c3d64ab"
const SOURCE_BINDING="3c3d6c0153e6b2444ab0f3edeefcfa99b33385a1e3b2aa59668c28331c302639"

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var original: Dictionary=app.session.station_owner().snapshot()
	check(FileAccess.get_sha256(saved)==SOURCE_SHA and definitions.binding_id==SOURCE_BINDING,"Use the retained original202 Genoh checkpoint without rebinding")
	check(original.campaign_cursor==38 and original.loadout.station_id==85 and original.loadout.system_id==17 and original.mission=={"kind":4,"station_id":22,"reward":0,"bonus":0,"source_parameter":0},"Resume the actual pending Dekato assignment at Genoh85")
	check(original.contracts.credits==19370 and original.contracts.passengers==3 and original.cargo.entries.is_empty(),"The Genoh predecessor lost its actual wallet, passengers or hold")
	var navigation:=AccessNavigation.new()
	if not navigation.configure(definitions,catalogue,original.contracts.lounges.system_availability):check(false,navigation.error);return
	var course: Dictionary=navigation.course(85,22)
	check(course.get("system_path")==[17,4] and course.get("jump_count")==1,"The retained original Eanya course changed")
	check(not PostProbeNavigation.destination_supported(definitions,38,original.mission,22),"Ordinary access admitted the unfinished selected-identity convoy")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated new output for the actual one-hop journey")
	if failures:return
	_world_clock_base=1789104672
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	# Continue with the actual thirteen retained rounds; do not purchase or
	# manufacture a new loadout merely to enter the neighboring ordinary world.
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await expedition_gate(4,20):return
	var arrival: Dictionary=app.session.snapshot()
	check(arrival.campaign_cursor==38 and arrival.location.station_id==20 and arrival.location.system_id==4 and arrival.mission==original.mission,"The actual gate did not reach Eanya with the pending career")
	check(arrival.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+1,"The final hop omitted or invented a gate transit")
	for field in ["mission","passengers","accepted_contact","blueprints"]:check(arrival.contracts[field]==original.contracts[field],"The actual gate changed retained "+field)
	check(arrival.contracts.lounges.system_availability==original.contracts.lounges.system_availability and not arrival.has("dekato_context") and not arrival.dialogue.visible,"Ordinary Eanya granted access or launched an unplayed story")
	await capture_free_application("earned202-eanya38-gate20-incoming")
	if failures or not await dock_with_paid_emp(2147483647):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout.station_id==20 and landed.loadout.system_id==4 and landed.campaign_cursor==38 and landed.binding_id==SOURCE_BINDING and landed.mission==original.mission,"Actual Eanya docking changed the source identity or mission")
	check(landed.contracts.credits==original.contracts.credits and landed.cargo==original.cargo and landed.contracts.passengers==3,"The final hop granted credits or changed cargo/passengers")
	if failures or not retain_chapter_save("eanya38-gate20"):return
	await capture_free_application("earned202-eanya38-station20")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not app.open_map(now_us):check(false,app.status.text);return
	if app.map_panel.snapshot().route_mode=="galaxy":app.map_panel.show_system(int(app.session.snapshot().location.system_id))
	var held: Dictionary=app.session.snapshot();var rows: Array=app.map_panel.snapshot().rows
	check(rows.map(func(row):return row.station_id)==[20,21,22,23,24],"Eanya map lost its original member planets")
	check(rows.any(func(row):return row.station_id==21 and row.supported) and rows.any(func(row):return row.station_id==22 and not row.supported),"Ordinary member admission and pending-story rejection diverged")
	check(not app.session.confirm_map_planet(22,now_us) and app.session.snapshot()==held,"Selecting unfinished Dekato changed the actual Eanya world")
	await capture_free_application("earned202-eanya38-pending22-map")
	if not app.close_map(now_us):check(false,app.status.text);return
	check(FileAccess.get_sha256(saved)==SOURCE_SHA,"The final hop overwrote the retained Genoh predecessor")
	if not failures:print("Earned actual202 Genoh85 -> Eanya20 gate, docking, station save/load and controlled departure; mission38 pending22 retained; credits ",landed.contracts.credits," vitals ",landed.player_cache.values)
