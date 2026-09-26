extends "res://tests/nehma_onward_application.gd"
## A fresh process restores the actual completed visit; it never replays travel.
const OnwardArchive=preload("res://src/simulation/station_archive.gd")

func verify_free_application() -> void:
	var path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	check(expected.length()==64 and FileAccess.get_sha256(path)==expected,"Resume only the exact earned onward checkpoint")
	if failures:return
	var original: Dictionary=app.session.station_owner().snapshot()
	var file:=OnwardFile.new();var archive:=OnwardArchive.new()
	var document: Dictionary=file.read_document(path)
	check(document.version==10 and document.binding_id==SOURCE_BINDING and definitions.binding_id==SOURCE_BINDING,"Fresh Resume changed the native save version or original202 identity")
	check(original.campaign_cursor==40 and original.loadout.station_id==30 and original.loadout.system_id==2 and original.arrival_player.campaign_cursor==39 and original.player_cache.campaign_cursor==40,"Fresh Resume changed the actual station or world39/career40 separation")
	check(Onward.station_mission(definitions,40,30,original.mission) and not original.campaign_conversation,"Fresh Resume recreated an acknowledged visit or changed the special successor")
	check(original.contracts.credits==19370 and original.contracts.passengers==3 and original.cargo.entries.is_empty(),"Fresh Resume changed the wallet, carried passengers or hold")
	check(archive.capture(app.session.station_owner(),definitions)==document,"Fresh Resume changed a retained native owner")
	check(not definitions.mido_travel.has("dekato_convoy") and not definitions.mido_travel.has("nehma_return"),"Supplemental declarations rewrote raw202 data")
	if failures:return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated fresh-process save output")
	if failures:return
	app.enable_saves(chapter_directory)
	app.show();app.present_session();await process_frame;resume_application_focus()
	check(not app.session.snapshot().dialogue.visible,"The acknowledged station reopened its conversation")
	await capture_free_application("nehma40-fresh-application")
	if not app.save_station() or not app.load_station():check(false,app._save_notice.text);return
	check(file.read_document(app.station_save_path())==document and app.session.station_owner().snapshot()==original,"Fresh application Save/Load changed its full station, equipment or career")
	var saved_sha:=FileAccess.get_sha256(app.station_save_path())
	for tick in 3:
		now_us+=100000
		if not app.session.step(now_us):check(false,app.session.error);return
		app.present_session()
	check(app.session.station_owner().snapshot()==original and not app.session.snapshot().dialogue.visible,"Polling duplicated the visit reward or changed the retained passenger job")
	check(not app.request_departure() and app.session.station_owner().snapshot()==original,"Fresh Resume opened the incomplete special flight or changed station state")
	check(FileAccess.get_sha256(app.station_save_path())==saved_sha and FileAccess.get_sha256(path)==expected,"Resume, polling or rejected departure changed checkpoint bytes")
	await capture_free_application("nehma40-fresh-save-load")
	if not failures:print("Fresh application restored actual original202 v10 Néhma40, retained world39 and all native owners; special departure remains closed")
