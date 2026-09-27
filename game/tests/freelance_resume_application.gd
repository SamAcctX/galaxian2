extends "res://tests/freelance_unlocked_application.gd"
## A fresh application opens the native checkpoint through its Resume input.

func _initialize() -> void:call_deferred("run_resumed_job")

func run_resumed_job() -> void:
	if not open_application_content(OS.get_cmdline_user_args()):quit(1);return
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	if directory.is_empty() or saved.is_empty():check(false,"Resume requires an earned source file and an isolated destination");quit(1);return
	app=Host.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(source,definitions,visual);app.set_process(false);app.enable_saves(directory)
	DirAccess.make_dir_recursive_absolute(app.station_save_path().get_base_dir())
	if DirAccess.copy_absolute(saved,app.station_save_path())!=OK:check(false,"Could not retain the source checkpoint for Resume");app.free();quit(1);return
	app.show();app.present_session();await process_frame;resume_application_focus()
	check(app.session==null and app._load_button.visible,"A fresh application omitted Resume")
	var key:=InputEventKey.new();key.physical_keycode=KEY_F9;key.pressed=true;app._unhandled_input(key)
	if app.session==null:check(false,app._save_notice.text);app.free();quit(1);return
	var restored: Dictionary=app.session.station_owner().snapshot()
	check(not app.session.snapshot().dialogue.visible and not app.session.snapshot().lounge_open,"Resume replayed a modal conversation")
	await capture_free_application("freelance-resumed-station")
	if OS.get_environment("GOF2_PIRATE_RESUME_PAID")=="1":
		var document: Dictionary=app._save_file.load_document(saved,definitions,catalogue,source)
		if document.is_empty():check(false,app._save_file.error);app.free();quit(1);return
		check(restored.campaign_cursor==document.career.campaign_cursor and restored.contracts.credits==document.career.credits and restored.contracts.completed_side_missions==document.career.completed_side_missions and restored.contracts.mission.is_empty(),"Fresh Resume lost or repeated the saved Pirate payment")
		if app.request_departure() and app.enter_first_flight(now_us,4096,flight_world_seconds()) and await release_application_flight():
			var flight: Dictionary=app.session.snapshot()
			check(flight.contracts.credits==restored.contracts.credits and flight.contracts.completed_side_missions==restored.contracts.completed_side_missions and flight.mission==restored.mission,"Departure after Resume repeated the payment or advanced the campaign")
			check(flight.player.equipment_ids==restored.loadout.equipment_ids,"Departure after Resume lost the saved fitted equipment")
			check(flight.encounter.combat.get("contract_encounter",{}).is_empty() and flight.encounter.combat.free_context.mission_kind==-1,"The paid job respawned its mission pirates")
			await capture_free_application("freelance-paid-resumed-flight")
		else:check(false,app.status.text)
	else:
		check(restored.contracts.mission.get("kind")==4,"Fresh Resume discarded the accepted Pirate job")
		if failures==0:await verify_free_application()
	app.free();print("Freelance Resume: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
