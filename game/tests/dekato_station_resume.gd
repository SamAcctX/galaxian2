extends "res://tests/dekato_arrival_application.gd"
## A separate application consumes the genuinely docked checkpoint. No flight
## replay or direct generation of a completed campaign state is involved.
const StationGuards=preload("res://tests/fixtures/dekato_station_checks.gd")
const StationFile=preload("res://src/simulation/station_save_file.gd")
const PilotSave=preload("res://tests/dekato_station_save.gd")
const Frontend=preload("res://src/presentation/player_frontend.gd")

func run_free_checkpoint() -> void:
	var args:=OS.get_cmdline_user_args()
	if not open_application_content(args):quit(1);return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var path:=OS.get_environment("GOF2_SOURCE_SAVE");var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	var device:=OS.get_environment("GOF2_DEKATO_RESUME_INPUT")
	if device.is_empty():device="keyboard"
	check(device in ["keyboard","mouse"],"Choose keyboard or mouse for the fresh menu Resume")
	check(expected.length()==64 and FileAccess.get_sha256(path)==expected,"Resume only the exact newly retained docking checkpoint")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/player.json") and not FileAccess.file_exists(chapter_directory+"/player.json"),"Use fresh private frontend output for a new-process Resume")
	if failures:quit(1);return
	var frontend:=Frontend.new();root.add_child(frontend);frontend.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frontend.boot(PackedStringArray(),chapter_directory)
	var selection:=Frontend.Preferences.defaults();selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2]
	if not frontend.select_content(selection):check(false,frontend.error)
	else:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
		if not frontend.bindings.attach_dekato_source(str(supplement[1]),frontend.library.manifest):check(false,frontend.bindings.error)
		else:
			definitions=frontend.bindings;source=frontend.library;visual=frontend.visuals
			var destination:=StationFile.path_for(frontend._save_directory,definitions)
			check(not FileAccess.file_exists(destination),"Fresh Resume output already contains a save")
			if not failures:
				DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
				check(DirAccess.copy_absolute(path,destination)==OK,"Could not copy the immutable produced checkpoint into the isolated frontend")
			if not failures:
				frontend.show_menu()
				check(not frontend.has_session() and frontend.has_save(),"Resume began with a preconstructed live station")
				resume_key(KEY_ENTER);await process_frame
				var rows: Array=frontend.menu.snapshot().actions
				var index:=rows.map(func(row):return row.action).find("resume")
				check(not frontend.menu.snapshot().title_active and index>=0,"The real menu omitted Resume for the produced save")
				if not failures:
					if device=="keyboard":resume_key(KEY_1+index)
					else:
						var point: Vector2=root.get_final_transform()*frontend.menu._buttons.resume.get_global_rect().get_center()
						var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
						Input.parse_input_event(motion);Input.flush_buffered_events()
						for pressed in [true,false]:
							var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=point;click.global_position=point;click.pressed=pressed
							Input.parse_input_event(click);Input.flush_buffered_events()
					check(frontend.phase=="game" and frontend.has_session(),device+" Resume did not restore the station through the actual frontend: "+frontend.error)
					if not failures:
						app=frontend.game;app.set_process(false);app._focused=true;app.session.rebase_time(now_us)
						await verify_free_application()
	frontend.free();await process_frame
	print("Dekato fresh-process menu Resume: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func resume_key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()

func verify_free_application() -> void:
	var path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	check(expected.length()==64 and FileAccess.get_sha256(path)==expected,"Resume only the exact genuine docking checkpoint")
	if failures:return
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.campaign_cursor==39 and original.loadout.station_id==22 and original.arrival_player.campaign_cursor==38 and original.mission.station_id==30,"The new application changed the pending story or actual world boundary")
	check(original.contracts.credits==19370 and original.contracts.passengers==3 and original.cargo.entries.is_empty() and original.player_cache.values.hull>0,"Fresh application restoration lost the earned wallet, passengers, empty cargo or surviving player")
	var file:=StationFile.new();var document:=file.read_document(path)
	var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	var guards:=StationGuards.new()
	guards.verify(definitions,catalogue,source,document,OS.get_cmdline_user_args()[1],str(supplement[1]))
	guards.check(guards.completed,"Fresh application archive guards did not finish")
	var restored_archive:=StationGuards.Archive.new()
	guards.check(restored_archive.capture(app.session.station_owner(),definitions)==document,"Menu Resume changed the complete earned archive")
	PilotSave.verify_pilot_observation(OS.get_environment("GOF2_DEKATO_EXPECTED_STATE"),path,original,guards)
	checks+=guards.checks;failures+=guards.failures
	if failures:return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated application restore output")
	if failures:return
	app.show();app.present_session();await process_frame;resume_application_focus()
	await capture_free_application("dekato39-fresh-application")
	if not app.save_station() or not app.load_station(now_us):check(false,app._save_notice.text);return
	check(app.session.station_owner().snapshot()==original,"Fresh-process Save/Load changed the full retained station/career")
	var valid_sha:=FileAccess.get_sha256(app.station_save_path())
	var legacy:=OS.get_environment("GOF2_LEGACY_SOURCE_SAVE")
	check(FileAccess.get_sha256(legacy)==SOURCE_SHA and DirAccess.copy_absolute(legacy,app.station_save_path()+".bak")==OK,"Use the unchanged earlier checkpoint only as an isolated fallback test")
	var plain:=Bindings.new()
	if not plain.open(OS.get_cmdline_user_args()[1],source.manifest):check(false,plain.error);return
	check(file.load_document(app.station_save_path(),plain,catalogue,source).is_empty() and not file.recovered_backup,"Missing explicit source silently rolled39 back to the older20 backup")
	var archive:=StationGuards.Archive.new()
	var predecessor: RefCounted=archive.restore(plain,catalogue,source,file.read_document(legacy))
	check(predecessor!=null and not file.save(app.station_save_path(),predecessor,plain,catalogue,source),"The original8 predecessor replaced a supplemental9 checkpoint")
	check(FileAccess.get_sha256(app.station_save_path())==valid_sha and FileAccess.get_sha256(path)==expected and FileAccess.get_sha256(legacy)==SOURCE_SHA,"A rejected source change modified a retained checkpoint")
	now_us+=100000
	if not app.session.step(now_us):check(false,app.session.error);return
	app.present_session()
	var onward: bool=load("res://src/content/free_campaign_definitions.gd").onward_available(definitions)
	check(app.session.station_owner().snapshot()==original and app.request_departure()==onward,"Station polling or departure ignored the retained source capability")
	if onward:app.cancel_departure()
	await capture_free_application("dekato39-fresh-save-load")
	if not failures:print("Fresh menu Resume restored original202 v9 station39 and its complete observed pilot state; corruption and legacy rollback rejected; onward departure available=",onward)
