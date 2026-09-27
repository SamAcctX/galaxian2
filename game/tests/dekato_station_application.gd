extends "res://tests/dekato_battle_application.gd"
## Use the already proven input pilot only to reach the new docking boundary.
const StationGuards=preload("res://tests/fixtures/dekato_station_checks.gd")
const StationFile=preload("res://src/simulation/station_save_file.gd")

func verify_free_application() -> void:
	await super.verify_free_application()
	if failures or pilot_losses==2:return
	var flying: Dictionary=app.session.snapshot()
	check(flying.station_return_supported and app.session.flight_owner()._return_rules==DekatoArrival.docking(definitions),"Acknowledgement omitted source-defined physical docking")
	if failures or not await dock_application():return
	var station: RefCounted=app.session.station_owner();var docked: Dictionary=station.snapshot()
	check(docked.campaign_cursor==39 and docked.loadout.station_id==22 and docked.loadout.system_id==4 and docked.mission==flying.mission and not docked.dialogue.visible,"Physical docking advanced the pending station30 visit or selected another station")
	check(docked.arrival_player.campaign_cursor==38 and docked.player_cache.campaign_cursor==39 and docked.player_cache.values.hull==docked.arrival_player.vitals.hull,"Docking relabelled the living world or repaired the retained hull")
	check(docked.dekato_source_receipt==definitions.dekato_source_receipt() and docked.binding_id==SOURCE_BINDING,"Docking changed the original202 or attached-source identity")
	for key in ["credits","passengers","mission","accepted_contact","blueprints","void_source","completed_side_missions","delivery_statistics","travel_statistics"]:
		check(docked.contracts[key]==flying.contracts[key],"Docking changed independent career: "+key)
	check(docked.loadout==flying.equipment.loadout and docked.cargo==flying.cargo and docked.contracts.credits==route_credits,"Docking lost actual spent ammunition, cargo or paid wallet")
	now_us+=100000
	if not app.session.step(now_us):check(false,app.session.error);return
	app.present_session()
	check(app.session.station_owner().snapshot()==docked,"Station result polling changed the pending independent passenger job")
	await capture_free_application("earned202-dekato39-station")
	# Read before any explicit Save can conceal a missing docking autosave.
	var file:=StationFile.new();var archive:=StationGuards.Archive.new()
	var automatic:=file.load_document(app.station_save_path(),definitions,catalogue,source)
	var restored: RefCounted=archive.restore(definitions,catalogue,source,automatic)
	check(not automatic.is_empty() and restored!=null and restored.snapshot()==docked,"Physical docking did not autosave the full newly earned station/career")
	if failures or not retain_chapter_save("dekato39-docked"):return
	var document:=file.read_document(app.station_save_path())
	if document.is_empty():check(false,file.error);return
	var args: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	var guards:=StationGuards.new()
	guards.verify(definitions,catalogue,source,document,str(OS.get_cmdline_user_args()[1]),str(args[1]))
	guards.check(guards.completed,"The post-docking archive guard suite did not finish")
	checks+=guards.checks;failures+=guards.failures
	var plain:=Bindings.new()
	if not plain.open(str(OS.get_cmdline_user_args()[1]),source.manifest):check(false,plain.error);return
	var saved_hash:=FileAccess.get_sha256(app.station_save_path())
	check(file.load_document(app.station_save_path(),plain,catalogue,source).is_empty() and not file.recovered_backup,"Missing supplemental source silently rolled39 back to its older20 backup")
	var legacy:=StationGuards.Archive.new()
	var predecessor: RefCounted=legacy.restore(plain,catalogue,source,file.read_document(OS.get_environment("GOF2_SOURCE_SAVE")))
	check(predecessor!=null,"The unchanged v8 predecessor no longer restores without a supplement")
	if predecessor!=null:check(not file.save(app.station_save_path(),predecessor,plain,catalogue,source),"An unextended v8 save overwrote the supplemental v9 checkpoint")
	check(FileAccess.get_sha256(app.station_save_path())==saved_hash,"A rejected source change modified the viable saved career")
	check(FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==SOURCE_SHA,"The postbattle checkpoint overwrote its earned Eanya predecessor")
	var onward:=PostProbeCampaign.onward_available(definitions)
	check(app.request_departure()==onward and app.session.station_owner().snapshot()==docked,"The saved Néhma continuation ignored its explicit source capability")
	if onward:
		check(not app._launch_packet.is_empty(),"The supported onward departure omitted its confirmation")
		app.cancel_departure()
	check(app.session.station_owner().snapshot()==docked,"Departure confirmation changed the saved station before launch")
	await capture_free_application("earned202-dekato39-restored")
	if not failures:
		var observed_path:=chapter_directory.path_join("dekato39-docked.observed")
		check(not FileAccess.file_exists(observed_path),"Use fresh output for pilot observations")
		if failures:return
		var observation:=FileAccess.open(observed_path,FileAccess.WRITE)
		if observation==null:check(false,"Could not retain the live pilot observation");return
		observation.store_var({"format":1,"source_sha":SOURCE_SHA,"output_sha":FileAccess.get_sha256(chapter_directory.path_join("dekato39-docked.gof2save")),"station":docked,"timing":pilot_timing,"losses":pilot_losses,"entry":pilot_entry,"dialogue_inputs":pilot_dialogue_inputs,"host_deltas_us":pilot_deltas})
		check(observation.get_error()==OK,"Could not write the live pilot observation")
		observation.close()
	if not failures:print("Actual original202 Eanya20 -> Dekato input victory -> physical station22 docking -> v9 explicit-source save/load; native39 career and original38 world pools retained")
