extends "res://tests/dekato_arrival_application.gd"
## A separate application consumes the genuinely docked checkpoint. No flight
## replay or direct generation of a completed campaign state is involved.
const StationGuards=preload("res://tests/fixtures/dekato_station_checks.gd")
const StationFile=preload("res://src/simulation/station_save_file.gd")

func verify_free_application() -> void:
	var path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	check(expected.length()==64 and FileAccess.get_sha256(path)==expected,"Resume only the exact genuine docking checkpoint")
	if failures:return
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.campaign_cursor==39 and original.loadout.station_id==22 and original.arrival_player.campaign_cursor==38 and original.mission.station_id==30,"The new application changed the pending story or actual world boundary")
	check(original.contracts.credits==19370 and original.contracts.passengers==3 and original.cargo.entries.is_empty() and original.player_cache.values.hull==95 and original.player_cache.values.armor==20,"Fresh application restoration lost actual postbattle resources")
	check(original.loadout.slots.any(func(row):return row is Dictionary and row.item_id==42 and row.quantity==6),"Fresh application restoration replenished the spent EMP ammunition")
	var file:=StationFile.new();var document:=file.read_document(path)
	var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	var guards:=StationGuards.new()
	guards.verify(definitions,catalogue,source,document,OS.get_cmdline_user_args()[1],str(supplement[1]))
	guards.check(guards.completed,"Fresh application archive guards did not finish")
	checks+=guards.checks;failures+=guards.failures
	if failures:return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated application restore output")
	if failures:return
	app.enable_saves(chapter_directory)
	app.show();app.present_session();await process_frame;resume_application_focus()
	await capture_free_application("dekato39-fresh-application")
	if not app.save_station() or not app.load_station():check(false,app._save_notice.text);return
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
	if not failures:print("Fresh application restored actual original202 v9 station39; exact source receipt, native owners and world38 pools preserved; corruption, legacy rollback and onward departure rejected")
