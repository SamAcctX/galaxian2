extends "res://tests/post_probe_application.gd"
## Actual original-identity saved-career travel to the last supported Eanya
## neighbor. Shared input, purchases, motion, docking and persistence only.
const AccessNavigation=preload("res://src/simulation/system_navigation.gd")
const AccessGate=preload("res://src/content/gate_arrival_definitions.gd")
const SOURCE_SHA="d48230d070bd6c99b997487bfc2785beb1726f14cb5bfd11443205fdc0ec74ec"
const SOURCE_BINDING="3c3d6c0153e6b2444ab0f3edeefcfa99b33385a1e3b2aa59668c28331c302639"

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var original: Dictionary=app.session.station_owner().snapshot()
	check(FileAccess.get_sha256(saved)==SOURCE_SHA and definitions.binding_id==SOURCE_BINDING,"Use the unchanged actual B'akka202 checkpoint with its original identity")
	check(original.campaign_cursor==38 and original.loadout.station_id==27 and original.mission=={"kind":4,"station_id":22,"reward":0,"bonus":0,"source_parameter":0},"Nesla access requires the actual pending Dekato assignment")
	check(original.contracts.credits==22100 and original.contracts.passengers==3 and original.cargo.entries.is_empty(),"The route lost its retained wallet, passengers or cleared hold")
	var navigation:=AccessNavigation.new()
	if not navigation.configure(definitions,catalogue,original.contracts.lounges.system_availability):check(false,navigation.error);return
	var course: Dictionary=navigation.course(27,22)
	check(course.get("system_path")==[5,3,8,2,17,4] and course.get("jump_count")==5 and course.get("guidance",{}).get("station_id")==25,"The original available-system Eanya course changed")
	check(not original.contracts.lounges.system_availability[27],"Nesla access silently unlocked the expansion alternative")
	check(not PostProbeNavigation.destination_supported(definitions,38,original.mission,22),"A supported neighbor opened the unimplemented original-identity convoy continuation")
	var path: Array=navigation.route(5,17)
	check(path==[5,3,8,2,17],"Nesla must use the original available-system prefix")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated new earned-checkpoint output")
	var clock:=OS.get_environment("GOF2_ALIOTH_WORLD_BASE")
	check(clock=="1789104000","Use the recorded deterministic access-pilot clock")
	if failures:return
	_world_clock_base=clock.to_int()
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	# The original route's first instruction is local travel to S'inokk25.
	# The neighbor-system picker is only available at the current gate station.
	if not await depart_saved_route("nesla38"):return
	if not await travel_application(25) or not await dock_with_paid_emp(2147483647):return
	check(app.session.station_owner().snapshot().campaign_cursor==38 and app.session.station_owner().snapshot().loadout.station_id==25,"The native gate approach did not retain the pending career at S'inokk")
	if failures or not retain_chapter_save("nesla38-route-25"):return
	var jumps:=0
	for index in range(1,path.size()):
		if not await depart_saved_route("nesla38"):return
		var system_id: int=path[index]
		var station_id: int=catalogue.tables.systems[system_id].fields[int(definitions.mido_travel.free_navigation.gate_station_field)]
		if not await expedition_gate(system_id,station_id):return
		jumps+=1
		var arrival: Dictionary=app.session.snapshot()
		check(arrival.campaign_cursor==38 and arrival.location.station_id==station_id and arrival.location.system_id==system_id and arrival.mission==original.mission,"Gate travel replaced the pending convoy with a completed or unrelated story")
		check(arrival.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+jumps,"The actual access route lost or invented a gate transit")
		check(arrival.contracts.passengers==3 and arrival.contracts.mission==original.contracts.mission and arrival.contracts.accepted_contact==original.contracts.accepted_contact,"Gate travel changed the independent accepted passenger job")
		check(arrival.contracts.blueprints==original.contracts.blueprints and arrival.contracts.lounges.system_availability==original.contracts.lounges.system_availability,"Travel granted blueprint credit or system access")
		check(not arrival.has("dekato_context") and not arrival.dialogue.visible,"A neighboring ordinary world launched the unplayed convoy")
		if failures:return
		if system_id==17:await capture_free_application("earned202-nesla38-genoh-incoming")
		if not await dock_with_paid_emp(2147483647):return
		var landed: Dictionary=app.session.station_owner().snapshot()
		check(landed.campaign_cursor==38 and landed.loadout.station_id==station_id and landed.binding_id==SOURCE_BINDING and landed.mission==original.mission,"Docking changed the retained mission or source identity")
		if failures or not retain_chapter_save("nesla38-route-"+str(station_id)):return
		print("Earned original202 access prefix ",path.slice(0,index+1)," station ",station_id," credits ",landed.contracts.credits," vitals ",landed.player_cache.values)
	var final: Dictionary=app.session.station_owner().snapshot()
	check(final.loadout.station_id==85 and final.loadout.system_id==17 and final.campaign_cursor==38 and final.binding_id==original.binding_id,"The genuine source-identity journey did not reach Genoh")
	await capture_free_application("earned202-nesla38-genoh-station")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var resumed: Dictionary=app.session.snapshot()
	check(resumed.location.station_id==85 and resumed.mission==original.mission and resumed.campaign_cursor==38 and app.session.can_control(),"Saved Genoh cannot resume ordinary controlled flight")
	var request:={"base_content_id":definitions.base_content_id,"binding_id":definitions.binding_id,"from_station_id":85,"destination_station_id":20}
	var eanya_ready: bool=not load("res://src/content/ordinary_world_definitions.gd").catalogue_location(definitions,catalogue,20).is_empty()
	check(AccessGate.packet(definitions,catalogue,request,38).is_empty()!=eanya_ready,"Eanya gate permission disagrees with its complete ordinary-world dependencies")
	if not app.open_map(now_us):check(false,app.status.text);return
	if app.map_panel.snapshot().route_mode=="galaxy":app.map_panel.show_system(int(app.session.snapshot().location.system_id))
	var held: Dictionary=app.session.snapshot()
	check(app.map_panel.snapshot().rows.map(func(row):return row.station_id)==[85,86,87,88,89],"Nesla map omitted original member stations")
	check(app.map_panel.snapshot().rows.any(func(row):return row.station_id==88 and row.supported),"The original Aoéh contact world is not reachable")
	check(not app.session.confirm_map_planet(20,now_us) and app.session.snapshot()==held,"A closed Eanya request changed the retained Genoh world")
	await capture_free_application("earned202-nesla38-map-boundary")
	if not app.close_map(now_us):check(false,app.status.text);return
	check(FileAccess.get_sha256(saved)==SOURCE_SHA,"The access journey overwrote its canonical source checkpoint")
	if not failures:print("Earned actual202 B'akka27 -> four original gate transits -> Genoh85 save/load/departure; mission38 pending22 and original identity retained; Eanya last leg not played by this producer")
