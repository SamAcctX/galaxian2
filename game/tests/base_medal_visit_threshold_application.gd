extends "res://tests/khador_application.gd"
## Earn Space Tourist and Explorer bronze only through real player travel.
## The source checkpoint is the accepted fitted Khador career from the base-game
## release batch, made before native visit histories existed. Migration starts
## conservatively at the resumed location; this test never writes visit IDs or tiers.
const MedalLedger=preload("res://src/simulation/base_medal_progress.gd")
const OrdinaryWorld=preload("res://src/content/ordinary_world_definitions.gd")
const SystemNavigation=preload("res://src/simulation/system_navigation.gd")
const LoungeContacts=preload("res://src/simulation/lounge_contacts.gd")
const Persistent=preload("res://src/content/persistent_contact_definitions.gd")
var unsupported_persistent_stations:=[]

func resumed_contract_valid(state: Dictionary) -> bool:
	if state.campaign_cursor!=45 or not state.loadout.equipment_ids.has(85):
		print("Visit Resume source mismatch: ",{"cursor":state.campaign_cursor,"equipment":state.loadout.equipment_ids})
		return false
	var stage:=OS.get_environment("GOF2_MEDAL_VISIT_STAGE")
	var travel: Dictionary=state.contracts.get("travel_statistics",{})
	if stage=="resume":
		return travel.get("visited_station_ids",[]).size()>=25 and travel.get("visited_system_ids",[]).filter(func(id):return id<22).size()>=5 and state.contracts.base_medals.levels[11]==3 and state.contracts.base_medals.levels[12]==3
	var levels: Array=state.contracts.get("base_medals",{}).get("levels",[])
	print("Visit Resume migrated source: ",{"cursor":state.campaign_cursor,"equipment":state.loadout.equipment_ids,"travel":travel,"medal11":levels[11] if levels.size()>12 else null,"medal12":levels[12] if levels.size()>12 else null})
	return travel.get("visited_station_ids",[]).size()<=1 and travel.get("visited_system_ids",[]).size()<=1 and levels.size()>12 and levels[11] in [MedalLedger.UNKNOWN,0] and levels[12] in [MedalLedger.UNKNOWN,0]

func verify_free_application() -> void:
	app.set_player_mode(true);app.show();app.present_session();await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var original: Dictionary=app.session.station_owner().snapshot()
	var stage:=OS.get_environment("GOF2_MEDAL_VISIT_STAGE")
	if stage=="resume":
		verify_visit_resume(original);return
	check(original.loadout.equipment_ids.has(85),"Use the accepted fitted Khador checkpoint for the visit route")
	check(not original.contracts.travel_statistics.has("visited_station_ids") and not original.contracts.travel_statistics.has("visited_system_ids"),"Legacy visit migration invented history before a new physical arrival")
	check(original.contracts.base_medals.levels[11]==MedalLedger.UNKNOWN and original.contracts.base_medals.levels[12]==MedalLedger.UNKNOWN,"Legacy visit migration inferred an unearned visit tier")
	unsupported_persistent_stations=unsupported_persistent_station_ids()
	check(failures==0,"Could not resolve the original persistent-contact route exclusions")
	print("Visit threshold start: ",{"station":original.loadout.station_id,"system":original.loadout.system_id,"equipment":original.loadout.equipment_ids,"drive_or_cells":original.cargo.entries.filter(func(row):return row.item_id in [85,122]),"visits":original.contracts.travel_statistics})
	if failures:return
	var safety:=0
	while safety<10:
		safety+=1
		var station_state: Dictionary=app.session.station_owner().snapshot()
		var travel: Dictionary=station_state.contracts.travel_statistics
		var systems_under_22: Array=travel.get("visited_system_ids",[]).filter(func(id):return id<22)
		if travel.get("visited_station_ids",[]).size()>=25 and systems_under_22.size()>=5:break
		# Local planet travel is genuine station evidence and avoids turning
		# system availability into medal evidence. Khador is used only after
		# exhausting the resumed system, and its admitted arrival goes through
		# the same rebase_station transaction as ordinary local arrivals.
		if not await visit_unseen_current_system():return
		station_state=app.session.station_owner().snapshot();travel=station_state.contracts.travel_statistics
		systems_under_22=travel.visited_system_ids.filter(func(id):return id<22)
		if travel.visited_station_ids.size()>=25 and systems_under_22.size()>=5:break
		if not await drive_to_next_original_system():return
	var earned: Dictionary=app.session.station_owner().snapshot()
	var systems: Array=earned.contracts.travel_statistics.visited_system_ids.filter(func(id):return id<22)
	check(earned.contracts.travel_statistics.visited_station_ids.size()>=25,"Physical route did not reach twenty-five unique stations")
	check(systems.size()>=5,"Physical route did not reach five source-counted systems")
	check(earned.contracts.travel_statistics.visited_station_ids.size()<50 and systems.size()<10,"Bounded bronze route unexpectedly crossed a silver threshold")
	check(earned.contracts.base_medals.levels[11]==3 and earned.contracts.base_medals.levels[12]==3,"Physical visit route did not bank Space Tourist and Explorer bronze")
	if failures:return
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.base_medals.levels[11]==3 and automatic.career.base_medals.levels[12]==3,"Final physical-dock autosave lost visit bronze")
	check(not automatic.is_empty() and automatic.career.travel_statistics.visited_station_ids==earned.contracts.travel_statistics.visited_station_ids and automatic.career.travel_statistics.visited_system_ids==earned.contracts.travel_statistics.visited_system_ids,"Final autosave changed earned visit sets")
	if failures:return
	await capture_free_application("medal-visits-bronze-docked")
	var destination:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("visits-bronze.gof2save")
	check(DirAccess.copy_absolute(app.station_save_path(),destination)==OK,"Could not retain the physical visit-bronze autosave")
	var retained: Dictionary=app._save_file.load_document(destination,definitions,catalogue,source)
	check(not retained.is_empty() and retained.career.base_medals.levels[11]==3 and retained.career.base_medals.levels[12]==3,"Retained visit-bronze autosave lost its awards")
	print("Earned visit bronze: ",{"stations":earned.contracts.travel_statistics.visited_station_ids,"systems":earned.contracts.travel_statistics.visited_system_ids,"station_tier":earned.contracts.base_medals.levels[11],"system_tier":earned.contracts.base_medals.levels[12]})

func verify_visit_resume(original: Dictionary) -> void:
	var travel: Dictionary=original.contracts.travel_statistics
	var systems: Array=travel.visited_system_ids.filter(func(id):return id<22)
	check(travel.visited_station_ids.size()>=25 and travel.visited_station_ids.size()<50,"Fresh Resume changed Space Tourist bronze evidence")
	check(systems.size()>=5 and systems.size()<10,"Fresh Resume changed Explorer bronze evidence")
	check(original.contracts.base_medals.levels[11]==3 and original.contracts.base_medals.levels[12]==3,"Fresh Resume lost visit bronze")
	check(MedalLedger.valid_retained(original.contracts.base_medals,original.contracts,original.contracts.get("blueprints",{})),"Fresh Resume restored invalid visit-medal evidence")
	if failures:return
	await capture_free_application("medal-visits-bronze-resumed")
	print("Resumed visit bronze: ",{"stations":travel.visited_station_ids.size(),"systems":systems.size()})

func ordinary_station_ids(system_id: int) -> Array:
	var result:=[]
	for station_id in catalogue.tables.systems[system_id].station_ids:
		if not OrdinaryWorld.location(definitions,int(station_id)).is_empty() and int(station_id) not in unsupported_persistent_stations:result.append(int(station_id))
	result.sort()
	return result

func unsupported_persistent_station_ids() -> Array:
	var rules: Dictionary=definitions.early_contracts.ordinary_generation.persistent
	var raw: PackedByteArray=source.read_resource(rules.resource,1024*1024)
	if raw.is_empty():check(false,source.error);return []
	var records:=LoungeContacts.decode_persistent_contacts(raw,rules)
	if records.is_empty():check(false,"Original persistent-contact table could not be decoded");return []
	var capability: Dictionary=definitions.persistent_contacts
	var fields: Dictionary=capability.fields
	var result:=[]
	for record in records:
		var station_id:=int(record.fields[int(fields.station)])
		var system_id:=int(record.fields[int(fields.system)])
		var contact_id:=int(record.fields[int(fields.id)])
		if contact_id not in Persistent.contact_ids(capability,station_id,system_id) and station_id not in result:result.append(station_id)
	result.sort()
	return result

func visit_unseen_current_system() -> bool:
	var station: Dictionary=app.session.station_owner().snapshot()
	var seen: Array=station.contracts.travel_statistics.get("visited_station_ids",[]).duplicate()
	var current_station:=int(station.loadout.station_id)
	var candidates:=ordinary_station_ids(int(station.loadout.system_id)).filter(func(id):return id!=current_station and id not in seen)
	if candidates.is_empty():return true
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	for destination in candidates:
		var before: Dictionary=app.session.snapshot()
		var before_count: int=before.contracts.travel_statistics.get("visited_station_ids",[]).size()
		if not await travel_application(int(destination)):return false
		var after: Dictionary=app.session.snapshot()
		check(after.contracts.travel_statistics.visited_station_ids.has(destination),"Real local arrival did not retain its station visit")
		check(after.contracts.travel_statistics.visited_station_ids.size()==before_count+1,"Real local arrival did not add exactly one unique station")
		print("Earned station visit: ",{"station":destination,"system":after.location.system_id,"count":after.contracts.travel_statistics.visited_station_ids.size(),"tier":after.contracts.base_medals.levels[11]})
		if failures:return false
		if after.contracts.travel_statistics.visited_station_ids.size()>=25:break
	if not await dock_application():return false
	return failures==0

func drive_to_next_original_system() -> bool:
	var station: Dictionary=app.session.station_owner().snapshot()
	var seen_systems: Array=station.contracts.travel_statistics.get("visited_system_ids",[]).duplicate()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return false
	var owner: RefCounted=app.session.flight_owner()
	var best:={}
	for station_id in owner._navigation_destinations:
		var row: Dictionary=catalogue.tables.stations[int(station_id)]
		var system_id:=int(row.system_id)
		if system_id>=22 or system_id in seen_systems or ordinary_station_ids(system_id).is_empty():continue
		var quote: Dictionary=owner.drive_quote(int(station_id))
		if not quote.get("affordable",false) or quote.get("mode")!="normal":continue
		var score:=ordinary_station_ids(system_id).size()
		if best.is_empty() or score>best.score or score==best.score and int(quote.cost)<int(best.cost):
			best={"station_id":int(station_id),"system_id":system_id,"score":score,"cost":int(quote.cost)}
	if best.is_empty():check(false,"No affordable Khador destination reaches another unvisited original system");return false
	var destination:=int(best.station_id);var before_energy:=energy(app.session.snapshot().cargo)
	if not await jump_drive_visit(destination):return false
	var arrived: Dictionary=app.session.snapshot()
	check(arrived.location.system_id==best.system_id and arrived.location.station_id==destination,"Physical Khador route arrived in another system or station")
	check(arrived.contracts.travel_statistics.visited_system_ids.has(best.system_id),"Physical Khador arrival did not retain its system visit")
	check(energy(arrived.cargo)==before_energy-int(best.cost),"Physical Khador arrival did not retain exactly its quoted fuel debit")
	print("Earned system visit: ",{"system":best.system_id,"station":destination,"cost":best.cost,"systems":arrived.contracts.travel_statistics.visited_system_ids,"stations":arrived.contracts.travel_statistics.visited_station_ids.size(),"tier":arrived.contracts.base_medals.levels[12]})
	if failures or not await dock_application():return false
	return true

func jump_drive_visit(destination: int) -> bool:
	var owner: RefCounted=app.session.flight_owner()
	var initial: Dictionary=app.session.snapshot()
	var quote: Dictionary=owner.drive_quote(destination)
	check(quote.get("affordable",false) and quote.get("mode")=="normal","Earned visit route lost its admitted Khador destination")
	if failures or not await open_drive_selector() or not await choose_map_destination(destination,true):check(false,app.status.text);return false
	var started: Dictionary=app.session.snapshot()
	check(started.khador.phase=="charging" and energy(started.cargo)==energy(initial.cargo)-int(quote.cost),"Visit Khador charge did not debit the quoted cells")
	if failures:return false
	return await complete_drive(destination)
