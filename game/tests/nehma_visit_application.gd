extends "res://tests/post_probe_application.gd"
## Earn landed visits through the same gate/local travel, docking, dialogue and
## archive path. Subclasses supply only their source-bound route and cursor.
const NEHMA_ROUTE=[[6,10],[7,35],[11,55],[9,45],[2,30]]

func visit_spec(_original: Dictionary) -> Dictionary:
	return {"cursor":34,"name":"nehma","route":NEHMA_ROUTE}

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(saved)
	var original: Dictionary=app.session.station_owner().snapshot()
	if OS.get_environment("GOF2_VISIT_DEPARTURE_ONLY")=="1":
		await verify_saved_visit_departure(original,saved,input_hash)
		return
	var spec:=visit_spec(original)
	if failures or spec.is_empty():return
	var cursor: int=spec.cursor
	var label: String=spec.name
	var route: Array=spec.route
	var index:=-1
	for position in route.size():
		if route[position][1]==original.loadout.station_id:index=position;break
	check(not input_hash.is_empty() and original.campaign_cursor==cursor and index>=0 and index<route.size()-1,"Resume a genuine pending station visit on its route")
	var rules: Dictionary=PostProbeCampaign.dialogue_rules(definitions,cursor,original.mission,true)
	check(not rules.is_empty() and original.mission==PostProbeCampaign.mission(definitions.mido_travel,cursor),"The station visit lost its complete source declarations")
	check(original.cargo.used==0 and original.contracts.passengers==3 and original.contracts.mission.station_id==99,"The route lost the delivered crystals or retained passenger job")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Set a private station-visit save directory")
	var clock:=OS.get_environment("GOF2_ALIOTH_WORLD_BASE")
	if not clock.is_empty():
		check(clock.is_valid_int() and clock.to_int()>=0 and clock.to_int()<2147480000,"Use a valid recorded route clock")
		_world_clock_base=clock.to_int()
	if failures:return
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	var jumps:=0
	while index<route.size()-1:
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight():return
		var previous_system: int=route[index][0]
		index+=1
		var destination: Array=route[index]
		if index==route.size()-1 and not await verify_station_visit_map(int(destination[0]),int(destination[1]),label+str(cursor)):return
		if int(destination[0])==previous_system:
			if not await travel_application(int(destination[1])):return
		else:
			if not await expedition_gate(int(destination[0]),int(destination[1])):return
			jumps+=1
		var arrival: Dictionary=app.session.snapshot()
		check(arrival.campaign_cursor==cursor and arrival.location.station_id==destination[1] and arrival.location.system_id==destination[0] and arrival.mission==original.mission,"Travel changed the pending station objective")
		check(arrival.cargo==original.cargo and arrival.contracts.blueprints==original.contracts.blueprints,"Travel changed the cleared hold or blueprint credit")
		check(arrival.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+jumps,"The station route lost its actual gate count")
		if failures:return
		if index<route.size()-1:
			if not await dock_with_paid_emp(2147483647) or not retain_chapter_save(label+str(cursor)+"-route-"+str(destination[1])):return
		else:
			check(arrival.encounter.combat.actors.is_empty() and not arrival.dialogue.visible and not arrival.has("void_probe") and not arrival.has("void_portal"),"The landed visit selected an authored combat, flight briefing or portal")
			if failures or not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.campaign_cursor==cursor and landed.loadout.station_id==original.mission.station_id,"The earned route did not dock at its source target")
	check(not app.save_station(),"An unacknowledged station result was saved")
	if failures or not await acknowledge_station_chapter(cursor):return
	var acknowledged: Dictionary=app.session.station_owner().snapshot()
	var next_cursor:=cursor+1
	check(acknowledged.campaign_cursor==next_cursor and acknowledged.mission==PostProbeCampaign.mission(definitions.mido_travel,next_cursor),"Final Next lost the declared next objective")
	for field in ["loadout","cargo","player_cache"]:
		if field=="player_cache":check(acknowledged[field].values==landed[field].values,"The station result changed the retained flight pools")
		else:check(acknowledged[field]==landed[field],"Final Next changed "+field)
	for field in ["credits","passengers","mission","accepted_contact","blueprints","void_source","travel_statistics"]:
		check(acknowledged.contracts[field]==landed.contracts[field],"Final Next changed retained "+field)
	check(acknowledged.reward_credits==0 and not acknowledged.has("next_course") and acknowledged.contracts.lounges.system_availability==landed.contracts.lounges.system_availability,"The landed visit granted payment, a course or system access")
	var station: RefCounted=app.session.station_owner()
	check(not station.acknowledge() and not station.begin_campaign_conversation(definitions,catalogue,source) and station.snapshot()==acknowledged,"The acknowledged visit repeated")
	if failures or not retain_chapter_save(label+str(next_cursor)+"-acknowledged"):return
	await capture_free_application("earned-"+label+str(next_cursor)+"-station")
	await verify_visit_departure(acknowledged,label)
	check(FileAccess.get_sha256(saved)==input_hash,"The station acceptance changed its immutable earned input")
	if not failures:print("Earned %s%d route/dock -> %d original result lines ->%d, zero payment or inventory mutation, save/reload and ordinary departure"%[label,cursor,rules.events.size(),next_cursor])

## Recover only the uncompleted departure after a retained acknowledged save.
## The producer's travel/dialogue report stays separate and is never rewritten.
func verify_saved_visit_departure(original: Dictionary,saved: String,input_hash: String) -> void:
	var cursor: int=original.campaign_cursor
	var previous: Dictionary=PostProbeCampaign.mission(definitions.mido_travel,cursor-1)
	var rules: Dictionary=PostProbeCampaign.dialogue_rules(definitions,cursor-1,previous,true)
	check(cursor in [35,36] and not rules.is_empty() and original.loadout.station_id==previous.get("station_id") and original.mission==PostProbeCampaign.mission(definitions.mido_travel,cursor) and not input_hash.is_empty(),"Use the actual acknowledged Néhma or Ga'kkrr save for departure-only verification")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Set a private departure-only output directory")
	var clock:=OS.get_environment("GOF2_ALIOTH_WORLD_BASE")
	check(clock.is_valid_int() and clock.to_int()>=0 and clock.to_int()<2147480000,"Departure-only verification requires its recorded encounter clock")
	if failures:return
	_world_clock_base=clock.to_int()
	app.enable_saves(chapter_directory)
	app.show();app.present_session();await process_frame;resume_application_focus()
	await verify_visit_departure(original,"acknowledged")
	check(FileAccess.get_sha256(saved)==input_hash,"Departure-only verification rewrote its earned source")
	if not failures:print("Acknowledged station departure only: cursor%d station%d; no route, dialogue or new earned save replayed"%[cursor,original.loadout.station_id])

func verify_visit_departure(acknowledged: Dictionary,label: String) -> void:
	var next_cursor: int=acknowledged.campaign_cursor
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var departed: Dictionary=app.session.snapshot()
	check(departed.campaign_cursor==next_cursor and departed.location.station_id==acknowledged.loadout.station_id and departed.mission==acknowledged.mission and app.session.can_control(),"The acknowledged visit cannot depart into ordinary flight")
	check(departed.cargo==acknowledged.cargo and departed.contracts.credits==acknowledged.contracts.credits and departed.contracts.blueprints==acknowledged.contracts.blueprints and departed.contracts.passengers==3,"Ordinary departure changed the earned continuation")
	if failures or not await verify_next_station_target(departed):return
	await capture_free_application("earned-"+label+str(next_cursor)+"-departure")

func verify_station_visit_map(system_id: int,station_id: int,label: String) -> bool:
	if not app.open_map(now_us):check(false,app.status.text);return false
	if app.map_panel.snapshot().system_id!=system_id and not app.switch_map_system(system_id):check(false,app.status.text);return false
	var held: Dictionary=app.session.snapshot()
	var mapped: Dictionary=app.map_panel.snapshot()
	check(mapped.rows.any(func(row):return row.station_id==station_id and row.supported),"The map cannot select the source station visit")
	app.map_panel.select_station(station_id);app.map_panel.request_confirmation()
	check(app.map_panel.snapshot().confirmation_visible and app.session.snapshot()==held,"Selecting the station traveled before confirmation")
	app.map_panel.back()
	check(not app.map_panel.snapshot().confirmation_visible and app.session.snapshot()==held,"Cancelling the station changed the earned flight")
	await capture_free_application("earned-"+label+"-admission")
	if not app.close_map(now_us):check(false,app.status.text);return false
	return failures==0

func verify_next_station_target(departed: Dictionary) -> bool:
	var target: int=departed.mission.station_id
	var supported: bool=PostProbeCampaign.ordinary_story_at(definitions.mido_travel,departed.campaign_cursor,target) or (departed.campaign_cursor==36 and target==27 and PostProbeCampaign.BakkaReturn.available(definitions))
	check(PostProbeNavigation.destination_supported(definitions,departed.campaign_cursor,departed.mission,target)==supported,"The next destination disagrees with its implemented source world")
	if supported or catalogue.tables.stations[target].system_id!=departed.location.system_id:return failures==0
	if not app.open_map(now_us):check(false,app.status.text);return false
	var mapped: Dictionary=app.map_panel.snapshot()
	var held: Dictionary=app.session.snapshot()
	check(mapped.rows.any(func(row):return row.station_id==target and not row.supported),"The local map exposed an unimplemented next mission")
	check(not app.session.confirm_map_planet(target,now_us) and app.session.snapshot()==held,"An unimplemented next mission changed the retained flight")
	await capture_free_application("earned-"+str(departed.campaign_cursor)+"-closed-story-target")
	if not app.close_map(now_us):check(false,app.status.text);return false
	return failures==0
