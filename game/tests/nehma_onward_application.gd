extends "res://tests/dekato_arrival_application.gd"
## Each route checkpoint is earned through the existing application controls.
## Failed later stages resume a retained native checkpoint, never a relocation.
const Onward=preload("res://src/content/nehma_return_definitions.gd")
const OnwardFile=preload("res://src/simulation/station_save_file.gd")

func open_application_content(args: PackedStringArray) -> bool:
	if not super.open_application_content(args):return false
	var addon: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_NEHMA_SOURCE_ARGS")))
	if not addon is Array or addon.size()!=3:check(false,"Supply the explicit onward source");return false
	if not definitions.attach_nehma_source(str(addon[1]),source.manifest):check(false,definitions.error);return false
	return true

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_sha:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	var original: Dictionary=app.session.station_owner().snapshot()
	check(input_sha.length()==64 and FileAccess.get_sha256(input_path)==input_sha and definitions.binding_id==SOURCE_BINDING,"Use the exact retained original202 checkpoint")
	check(not definitions.mido_travel.has("dekato_convoy") and not definitions.mido_travel.has("nehma_return") and Onward.source_available(definitions),"Onward travel rewrote raw202 or omitted explicit sources")
	check(Onward.station_mission(definitions,original.campaign_cursor,original.loadout.station_id,original.mission) and original.loadout.station_id in [22,20,85,30],"Resume an actual station on the onward route")
	check(original.contracts.credits==19370 and original.contracts.passengers==3 and original.cargo.entries.is_empty(),"The onward route lost its actual wallet, passenger job or empty hold")
	if failures:return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated onward checkpoint output")
	if failures:return
	_world_clock_base=1789105200
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.enable_saves(chapter_directory)
	app.show();app.present_session();await process_frame;resume_application_focus()
	await capture_free_application("nehma-onward-retained-source")
	var station_id: int=original.loadout.station_id
	if station_id==22:
		if not await depart_onward() or not await travel_application(20) or not await dock_with_paid_emp(2147483647):return
		if not retain_chapter_save("nehma39-eanya20"):return
		await capture_free_application("nehma39-earned-eanya20")
		station_id=20
	if station_id==20:
		if not await depart_onward() or not await expedition_gate(17,85) or not await dock_with_paid_emp(2147483647):return
		if not retain_chapter_save("nehma39-nesla85"):return
		await capture_free_application("nehma39-earned-nesla85")
		station_id=85
	if station_id==85:
		if not await depart_onward() or not await expedition_gate(2,30):return
		var incoming: Dictionary=app.session.snapshot()
		check(incoming.campaign_cursor==39 and incoming.location.station_id==30 and incoming.encounter.combat.actors.is_empty() and not incoming.dialogue.visible,"The original selected39 visit gained a flight cast or premature station dialogue")
		if failures:return
		await capture_free_application("nehma39-actual-flight-arrival")
		if not await dock_application():return
		station_id=30
	if app.session.station_owner().snapshot().campaign_cursor==39:
		var arrived: Dictionary=app.session.station_owner().snapshot()
		check(arrived.loadout.station_id==30 and arrived.arrival_player.campaign_cursor==39 and not app.save_station(),"An unacknowledged visit produced a station checkpoint")
		if failures or not await acknowledge_station_chapter(39):return
		var after: Dictionary=app.session.station_owner().snapshot()
		check(after.campaign_cursor==40 and after.loadout==arrived.loadout and after.cargo==arrived.cargo and after.arrival_player==arrived.arrival_player and after.player_cache.values==arrived.player_cache.values,"Final Next changed the actual ship, cargo or world39 instead of only the career")
		check(after.contracts.mission==arrived.contracts.mission and after.contracts.accepted_contact==arrived.contracts.accepted_contact and after.contracts.travel_statistics==arrived.contracts.travel_statistics and after.contracts.credits==arrived.contracts.credits,"Final Next changed the independently earned career")
		if failures:return
	if not retain_chapter_save("nehma40-acknowledged"):return
	var completed: Dictionary=app.session.station_owner().snapshot()
	var file:=OnwardFile.new();var document:=file.read_document(app.station_save_path())
	check(document.version==10 and completed.campaign_cursor==40 and completed.arrival_player.campaign_cursor==39 and completed.player_cache.campaign_cursor==40,"The durable onward station lost its version or world/career separation")
	check(not app.request_departure() and app.session.station_owner().snapshot()==completed,"The station-only special successor opened an incomplete flight")
	check(FileAccess.get_sha256(input_path)==input_sha,"Onward travel modified its retained input checkpoint")
	await capture_free_application("nehma40-actual-saved-station")
	if not failures:print("Actual original202 onward journey, source-selected39 arrival, ten native station lines and transactional40/v10 save-load passed")

func depart_onward() -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	return await release_application_flight()
