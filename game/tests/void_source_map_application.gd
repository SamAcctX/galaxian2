extends "res://tests/post_probe_application.gd"
## Observe the map from the real paid cargo-fit station, then fly its next gate.
## Alternative map views are detached read-only fixtures, never earned or saved.
const SourceMap=preload("res://src/simulation/local_map.gd")
const SourceMapPanel=preload("res://src/presentation/local_map_panel.gd")
const SourceCampaign=preload("res://src/content/free_campaign_definitions.gd")
const SourceNavigation=preload("res://src/content/free_navigation_definitions.gd")

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	check(not saved.is_empty(),"Resume the genuine fitted mission32 station archive")
	if failures:return
	var input_hash:=FileAccess.get_sha256(saved)
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.campaign_cursor==32 and original.loadout.station_id==95 and original.cargo.capacity==50 and original.cargo.used==0,"The source-map check lost its actual earned cargo-fit station")
	check(original.contracts.passengers==3 and original.contracts.void_source.source_station_id==91 and original.contracts.void_source.eligible_selection_count==1,"The source-map check lost the retained passengers or actual Void source")
	if failures:return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if chapter_directory.is_empty() or not FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"):check(false,"Set a private source-map save directory");return
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var flying: Dictionary=app.session.snapshot()
	if not app.open_map(now_us):check(false,app.status.text);return
	var map: Dictionary=app.map_panel.snapshot()
	check(map.has("void_warning") and not map.get("void_warning",{}).is_empty(),"The earned mission32 map omits its retained Void source warning")
	if failures:return
	check(map.void_warning.system_id==18 and map.void_warning.station_id==-1 and map.void_warning.station_name.is_empty(),"Mission32 hid the warned system or revealed the station hint early")
	check(map.void_warning.system_name==catalogue.tables.systems[18].name and app.map_panel._galaxy._warning!=null,"The earned source warning lost its catalogue name or original galaxy model")
	check(app.session.snapshot().contracts==flying.contracts,"Opening the map rerolled or advanced the retained career")
	await capture_free_application("earned-void-source-map")
	if not app.switch_map_system(14):check(false,app.status.text);return
	check(app.map_panel.snapshot().void_warning==map.void_warning and app.map_panel.snapshot().rows.all(func(row):return not row.void_source),"A neighboring system view moved the source or revealed a station hint")
	if not app.switch_map_system(19):check(false,app.status.text);return
	app.map_panel.select_station(98);app.map_panel.request_confirmation()
	check(app.map_panel.snapshot().confirmation_visible,"The ordinary Alioth course lost its confirmation")
	app.map_panel.back()
	check(not app.map_panel.snapshot().confirmation_visible,"Cancelling a map choice retained the pending course")
	verify_source_observations(flying)
	if failures:return
	await verify_source_layouts(flying)
	if failures or not app.close_map(now_us):check(false,app.status.text);return
	var observed: Dictionary=app.session.snapshot()
	for key in ["contracts","cargo","equipment","progress","mission","player","player_pose"]:
		check(observed[key]==flying[key],"Map inspection, cancellation or layout changed the actual "+key)
	check(SourceNavigation.destination_supported(definitions,32,original.mission,10),"Source-map inspection lost the supported Thynome32 course")
	if failures:return
	# Use ordinary application input, paid EMP and real gate/docking ownership.
	if not await expedition_gate(14,70) or not await dock_with_paid_emp(2147483647):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.campaign_cursor==32 and landed.loadout.station_id==70 and landed.mission==original.mission,"The actual return gate changed the pending Thynome visit")
	check(landed.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+1,"The source-map route did not earn exactly one gate")
	var retained: Dictionary=original.contracts.void_source.duplicate(true);retained.eligible_selection_count+=1
	check(landed.contracts.void_source==retained,"Map inspection added eligible source selections to the actual route")
	check(landed.contracts.credits==route_credits and landed.contracts.mission==retained_job and landed.contracts.passengers==3 and landed.contracts.blueprints==original.contracts.blueprints,"The map route changed the paid career or blueprint materials")
	check(landed.cargo==original.cargo and landed.loadout.equipment_ids==original.loadout.equipment_ids and landed.player_cache.values.hull>0,"The real gate lost the empty50t mining fit or living pilot")
	if failures or not retain_chapter_save("thynome32-route-70"):return
	check(FileAccess.get_sha256(saved)==input_hash,"The map route changed its immutable earned input")
	print("Earned cargo-fit95 -> source map -> actual Dis70 gate, docking and station save/load; source ",landed.contracts.void_source)

func map_fixture(flying: Dictionary,cursor: int,station_id:=90) -> Dictionary:
	# This is only a map interface, not a proposed career or flight owner.
	return {"base_content_id":definitions.base_content_id,"binding_id":definitions.binding_id,
		"campaign_cursor":cursor,"location":{"station_id":station_id,"system_id":int(catalogue.tables.stations[station_id].system_id)},
		"mission":SourceCampaign.mission(definitions.mido_travel,cursor),"local_travel":{"phase":"flight"},
		"contracts":{"mission":retained_job.duplicate(true),"void_source":flying.contracts.void_source.duplicate(true),
			"lounges":{"system_availability":flying.contracts.lounges.system_availability.duplicate()}}}

func verify_source_observations(flying: Dictionary) -> void:
	var navigation:=SourceMap.new()
	for cursor in [31,32,33]:
		var fixture:=map_fixture(flying,cursor);var before:=fixture.duplicate(true)
		if not navigation.configure(source,definitions,catalogue,fixture):check(false,navigation.error);return
		var map: Dictionary=navigation.snapshot()
		check(fixture==before,"A detached map view changed its input")
		check(map.void_warning.is_empty()==(cursor<32),"The system warning crossed its imported cursor32 gate")
		check(map.rows.filter(func(row):return row.void_source).map(func(row):return row.station_id)==([91] if cursor==33 else []),"The local station hint crossed its cursor33 or system/station match gate")
		if cursor>=32:check(map.void_warning.station_id==(91 if cursor==33 else -1),"The station hint ignored its source gate")
	var changed:=map_fixture(flying,33,95)
	changed.contracts.void_source.source_system_id=19;changed.contracts.void_source.source_station_id=98
	if not navigation.configure(source,definitions,catalogue,changed):check(false,navigation.error);return
	var refreshed: Dictionary=navigation.snapshot()
	check(refreshed.void_warning.system_id==19 and refreshed.void_warning.station_id==98 and refreshed.void_warning.station_name==catalogue.tables.stations[98].name,"The map hardcoded the initial Dima source instead of the supplied retained source")
	check(refreshed.rows.filter(func(row):return row.void_source).map(func(row):return row.station_id)==[98],"The source row did not follow the retained system/station pair")
	check(refreshed.rows.filter(func(row):return row.mission_target).map(func(row):return row.station_id)==[99],"A Void marker replaced the accepted passenger destination")
	for patch in [{"binding_id":"foreign"},{"base_content_id":"foreign"},{"source_system_id":18},{"source_station_id":999},{"eligible_selection_count":11},{"source_station_id":98.0}]:
		var invalid:=changed.duplicate(true);invalid.contracts.void_source.merge(patch,true)
		check(not navigation.configure(source,definitions,catalogue,invalid) and navigation.snapshot()==refreshed,"Invalid retained source replaced the accepted map: "+str(patch))
	var disconnected:=changed.duplicate(true);disconnected.contracts.lounges.system_availability=[]
	check(not navigation.configure(source,definitions,catalogue,disconnected) and navigation.snapshot()==refreshed,"A source without retained system access replaced the map")
	for disabled in [false,true]:
		var absent:=changed.duplicate(true)
		if disabled:
			absent.contracts.void_source.source_system_id=-10;absent.contracts.void_source.source_station_id=-10
		else:absent.contracts.erase("void_source")
		check(navigation.configure(source,definitions,catalogue,absent) and navigation.snapshot().void_warning.is_empty() and navigation.snapshot().rows.all(func(row):return not row.void_source),"Missing or disabled source invented a warning")
	var coincident:=changed.duplicate(true);coincident.contracts.void_source.source_station_id=99
	if not navigation.configure(source,definitions,catalogue,coincident):check(false,navigation.error);return
	var target: Array=navigation.snapshot().rows.filter(func(row):return row.station_id==99)
	check(target.size()==1 and target[0].void_source and target[0].mission_target and target[0].supported,"A source hint replaced the accepted passenger destination or blocked ordinary travel")
	check(SourceNavigation.destination_supported(definitions,33,coincident.mission,10) and not SourceCampaign.ordinary_story_at(definitions.mido_travel,33,10),"The crystal hand-in lost ordinary navigation or incorrectly selected a story cast")

func verify_source_layouts(flying: Dictionary) -> void:
	if DisplayServer.get_name()=="headless":return
	var original_size: Vector2i=root.size
	var panel:=SourceMapPanel.new();root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fixture:=map_fixture(flying,33)
	if not panel.configure(source,definitions,app.visuals,catalogue,fixture):check(false,panel.error);panel.free();return
	panel.set_active(true)
	var before:=panel.snapshot()
	for mobile in [false,true]:
		root.size=Vector2i(800,450) if mobile else Vector2i(1280,720);panel.set_mobile_layout(mobile)
		for _tick in 5:await process_frame
		check(panel._void_warning.visible and panel._void_warning.text.ends_with(" / Dima"),"The selected cursor33 readout omitted the retained station")
		check(Rect2(Vector2.ZERO,panel.size).encloses(panel._void_warning.get_rect()),"Source text exceeds its landscape map")
		var labels: Array=panel._canvas.label_rectangles()
		for index in labels.size():
			check(not labels[index].intersects(panel._void_warning.get_rect()) and labels[index].end.y<=panel._footer.position.y,"Source text or footer overlaps a planet label")
			for other in index:check(not labels[index].intersects(labels[other]),"The Void station tag overlaps another planet name")
		check(panel.snapshot()==before,"Changing source-map layout changed its selection or source")
		var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
		if not directory.is_empty():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(directory.path_join("selected-void-source-map-"+("phone" if mobile else "desktop")+".png"))==OK,"Could not capture the source map")
	var accepted:=panel.snapshot();var caption: String=panel._void_warning.text
	var invalid:=fixture.duplicate(true);invalid.contracts.void_source.binding_id="foreign"
	check(not panel.configure(source,definitions,app.visuals,catalogue,invalid) and panel.snapshot()==accepted and panel._void_warning.text==caption,"Rejected map staging lost the visible source warning")
	var earlier:=map_fixture(flying,31)
	check(panel.configure(source,definitions,app.visuals,catalogue,earlier) and not panel._void_warning.visible and panel._void_warning.text.is_empty(),"Reconfiguring an earlier map left a stale warning")
	panel.clear();check(not panel._void_warning.visible and panel._void_warning.text.is_empty(),"Closing the map retained its source readout")
	panel.free();root.size=original_size
