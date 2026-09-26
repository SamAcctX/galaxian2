extends "res://tests/mission_normal_return.gd"
## Native station integration built on the documented ambush component. Its
## detached initial stimuli are NOT a full earned campaign playthrough.
const StationTransfer=preload("res://src/simulation/mission_station_return.gd")
const StationContext=preload("res://src/simulation/mission_station_context.gd")

func verify_normal_result(app: Control) -> void:
	await super.verify_normal_result(app)
	if failures:return
	var old_session: Node3D=app.session
	var source: RefCounted=old_session.flight_owner()
	var before: Dictionary=source.snapshot();var source_career: Dictionary=source.contract_owner().snapshot()
	app.enable_saves(capture_path.path_join("station-autosave"))
	var slot: String=app.station_save_path()
	check(DirAccess.make_dir_recursive_absolute(slot.get_base_dir())==OK,"Could not prepare the isolated test save slot")
	var original_bytes:=FileAccess.get_file_as_bytes(OS.get_environment("GOF2_SOURCE_SAVE"))
	var seeded:=FileAccess.open(slot,FileAccess.WRITE)
	if seeded==null:check(false,"Could not seed the isolated slot with the untouched earned input");return
	seeded.store_buffer(original_bytes);seeded.close()
	var unissued:=StationTransfer.new()
	check(not unissued.prepare(bindings,catalogues,library,null,Host.BASE_STOCK_SETTINGS,200),"An observation admitted a live station transfer")
	check(not app.enter_station(-1,0,200) and app.session==old_session and old_session.flight_owner().snapshot()==before and app.viewport.get_camera_3d()==old_session.camera,"Rejected station construction replaced the pending world or camera")
	check(FileAccess.get_file_as_bytes(slot)==original_bytes,"Rejected station construction overwrote the earned input")
	var blocked_path:=capture_path.path_join("station-write-blocker")
	var blocker:=FileAccess.open(blocked_path,FileAccess.WRITE)
	if blocker==null:check(false,"Could not prepare the isolated write-failure fixture");return
	blocker.store_string("not a directory");blocker.close()
	app.enable_saves(blocked_path)
	check(not app.enter_station(70000000,0,200) and app.session==old_session and old_session.flight_owner().snapshot()==before and app.viewport.get_camera_3d()==old_session.camera,"Failed autosave discarded the pending world or camera")
	check(app.status.text.contains("Cannot create the save directory"),"The write-failure fixture did not reach the actual save-directory boundary: "+app.status.text)
	check(FileAccess.get_file_as_bytes(slot)==original_bytes,"Failed autosave changed the previous earned input")
	app.enable_saves(capture_path.path_join("station-autosave"))
	if not app.retry_transition():check(false,app.status.text);return
	check(app.session is Host.StationSession and app.session!=old_session and not app._transition_failed,"Station retry failed to commit the real hangar session")
	var arrived: Dictionary=app.session.snapshot()
	check(arrived.campaign_cursor==43 and arrived.loadout.station_id==10 and arrived.mission=={"kind":11,"station_id":10,"reward":0,"bonus":0,"source_parameter":0},"Station continuation changed its original next mission")
	check(arrived.reward_credits==0 and arrived.contracts.credits==source_career.credits,"Station continuation paid a premature story reward")
	check(FileAccess.get_file_as_bytes(slot+".bak")==original_bytes,"Station autosave failed to retain the earned input backup")
	for key in ["mission","accepted_contact","passengers","result_serial","completed_side_missions","pending_result","last_result","blueprints","progress","travel_statistics","delivery_statistics"]:
		check(arrived.contracts.get(key)==source_career.get(key),"Station continuation changed retained career: "+key)
	var equipment: Dictionary=before.equipment.duplicate(true)
	equipment.loadout.station_id=arrived.loadout.station_id;equipment.loadout.system_id=arrived.loadout.system_id
	check(arrived.equipment==equipment,"Station entry changed paid equipment, ammunition, prices or cargo")
	var cached: Dictionary=StationTransfer.Cache._capture_arrival(bindings.mido_travel,before.equipment.loadout,arrived.loadout,before.player)
	cached.campaign_cursor=43
	check(arrived.player_cache==cached,"Station entry repaired the surviving ship or lost its cache")
	check(arrived.station_response_flags==source.station_response_flags(),"Station entry lost the native station responses")
	check(source.snapshot()==before,"Station entry mutated its copy-on-write flight parent")
	check(app.viewport.get_camera_3d()==app.session.camera,"Station scene committed the wrong camera")
	check(FreeEntry.player_entry(bindings,10,arrived.loadout.ship_id,43).is_empty(),"Station-only entry opened generic campaign flight")
	check(not StationContext.permits(bindings,43,10,StationContext.new()),"Empty station context granted admission")
	app.session.rebase_time(70000000)
	check(app.session.step(70100000),app.session.error)
	check(app.session.snapshot().campaign_cursor==43,"Entering the station acknowledged the next mission")
	await verify_station_save(app,arrived)
	if DisplayServer.get_name()!="headless":
		app.present_session()
		await capture_normal_scene(app,"mission-station-arrival")
	print("Native station continuation committed Thynome10 at cursor43; retained career, equipment and pools")

func verify_station_save(app: Control,arrived: Dictionary) -> void:
	var path: String=app.station_save_path()
	check(FileAccess.file_exists(path),"The committed station did not autosave")
	var save:=Host.StationSaveFile.new();var archive:=Host.StationArchive.new()
	var document: Dictionary=save.load_document(path,bindings,catalogues,library)
	if document.is_empty():check(false,save.error);return
	check(document.version==11 and document.station.campaign_cursor==43,"Autosave lost its sourced continuation version")
	var restored: RefCounted=archive.restore(bindings,catalogues,library,document)
	if restored==null:check(false,archive.error);return
	var recovered: Dictionary=restored.snapshot()
	for key in ["mission","player_cache","contracts","equipment","progress","station_response_flags"]:
		check(recovered.get(key)==arrived.get(key),"Save roundtrip changed the retained station: "+key)
	for key in ["station_id","campaign_cursor","source_cursor","system_id"]:
		var invalid: Dictionary=document.duplicate(true)
		invalid.station.mission_station_return[key]+=1
		check(archive.restore(bindings,catalogues,library,invalid)==null,"Save accepted altered continuation: "+key)
	var invalid: Dictionary=document.duplicate(true);invalid.station.reward_credits=40000
	check(archive.restore(bindings,catalogues,library,invalid)==null,"Save accepted mission45's reward before its station")
	invalid=document.duplicate(true);invalid.station.arrival_player.ship_id+=1
	check(archive.restore(bindings,catalogues,library,invalid)==null,"Save accepted another ship as the arriving player")
	invalid=document.duplicate(true);invalid.station.arrival_player.vitals.armor+=1
	check(archive.restore(bindings,catalogues,library,invalid)==null,"Save accepted repaired arrival pools without the matching retained cache")
	invalid=document.duplicate(true);invalid.station.flight_elapsed_ms=0
	check(archive.restore(bindings,catalogues,library,invalid)==null,"Save accepted station arrival before the normal-space result")
	check(app.load_station(72000000),"Real application station load failed")
	check(app.session.snapshot().contracts==arrived.contracts and app.session.snapshot().player_cache==arrived.player_cache,"Application load changed the paid career or surviving pools")
	print("Component autosave (not earned journey): "+path)
