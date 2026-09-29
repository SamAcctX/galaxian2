extends "res://tests/lounge_diplomat_journey.gd"
## Earn one real cumulative medal tier from the immutable end-game career.
## No counters or medal levels are injected: combat, travel, docking and the
## station autosave are the only producers promoted by this test.
const MedalLedger=preload("res://src/simulation/base_medal_progress.gd")

func resumed_contract_valid(state: Dictionary) -> bool:
	var stage:=OS.get_environment("GOF2_MEDAL_EARNED_STAGE")
	if stage=="resume":
		return state.campaign_cursor==45 and state.contracts.progress.player_kills==50 and state.contracts.base_medals.levels[4]==3
	if stage=="naysayer_resume":
		return state.campaign_cursor==45 and state.contracts.get("rejected_jobs",0)==51 and state.contracts.base_medals.levels[32]==1
	if stage=="renegade_earn":
		return state.campaign_cursor==45 and state.contracts.reputation.axes==[-71,3] and state.contracts.base_medals.levels[28] in [MedalLedger.UNKNOWN,1]
	if stage=="renegade_resume":
		return state.campaign_cursor==45 and state.contracts.reputation.axes==[-71,3] and state.contracts.base_medals.levels[28]==1
	if stage=="visits_earn":
		return state.campaign_cursor==45 and state.contracts.base_medals.levels[28]==1
	if stage=="visits_resume":
		return state.campaign_cursor==45 and state.contracts.travel_statistics.get("visited_station_ids",[])==[8] and state.contracts.travel_statistics.get("visited_system_ids",[])==[1]
	return state.campaign_cursor==45 and state.loadout.station_id==99 and state.contracts.progress.player_kills==43

func seek_smaller_patrol() -> bool:
	# The immutable end-game career resumes in the Néhma system, whose observed
	# native route contains either no patrol or four ships. Accept that real
	# population here rather than importing the earlier diplomat pilot's <=2
	# survivability restriction; actors, vitals and random state stay untouched.
	for journey in 5:
		var state: Dictionary=app.session.snapshot()
		var patrols: Array=state.encounter.combat.actors.filter(func(actor):return actor.active and actor.actor_kind==0 and actor.population_group=="patrol" and actor.vitals.hull>0)
		print("Observed medal patrol: ",{"station":state.location.station_id,"count":patrols.size(),"journey":journey})
		if not patrols.is_empty() and patrols.size()<=4:return true
		var stations:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==state.location.system_id:stations.append(id)
		if stations.size()<2:check(false,"This system has no native alternate medal route");return false
		var next: int=stations[(stations.find(state.location.station_id)+1)%stations.size()]
		if not await travel_application(next):return false
	check(false,"The bounded native medal route found no patrol");return false

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var original: Dictionary=app.session.station_owner().snapshot()
	check(MedalLedger.valid_retained(original.contracts.base_medals,original.contracts,original.contracts.get("blueprints",{})),"The threshold input lost its retained medal ledger")
	var stage:=OS.get_environment("GOF2_MEDAL_EARNED_STAGE")
	if stage=="earn":
		check(original.contracts.progress.player_kills==43,"Use the immutable 43-kill earned career for the threshold proof")
		check(original.contracts.base_medals.levels[4]==0,"Killer bronze was already earned before real combat")
		if failures:return
		for sortie in 7:
			var before: Dictionary=app.session.station_owner().snapshot()
			if not await earn_hostility():return
			var flight: Dictionary=app.session.snapshot()
			check(flight.progress.player_kills==before.contracts.progress.player_kills+1,"A medal sortie did not earn exactly one real player kill")
			if failures:return
			if not await withdraw_and_dock():return
			var docked: Dictionary=app.session.station_owner().snapshot()
			check(docked.contracts.progress.player_kills==flight.progress.player_kills,"Physical docking lost the earned kill")
			var expected:=3 if docked.contracts.progress.player_kills>=50 else 0
			check(docked.contracts.base_medals.levels[4]==expected,"Station docking did not bank the native Killer tier")
			var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
			check(not automatic.is_empty() and automatic.career.progress.player_kills==docked.contracts.progress.player_kills and automatic.career.base_medals.levels[4]==expected,"The physical-dock autosave lost the earned Killer tier")
			print("Earned Killer sortie: ",{"sortie":sortie+1,"kills":docked.contracts.progress.player_kills,"tier":docked.contracts.base_medals.levels[4],"station":docked.loadout.station_id})
			if failures:return
		var earned: Dictionary=app.session.station_owner().snapshot()
		check(earned.contracts.progress.player_kills==50 and earned.contracts.base_medals.levels[4]==3,"Seven real kills did not cross Killer bronze exactly")
		if failures:return
		await capture_free_application("medal-killer-bronze-docked")
		var destination:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("killer-bronze.gof2save")
		check(DirAccess.copy_absolute(app.station_save_path(),destination)==OK,"Could not retain the physical-dock autosave")
		var retained: Dictionary=app._save_file.load_document(destination,definitions,catalogue,source)
		check(not retained.is_empty() and retained.career.progress.player_kills==50 and retained.career.base_medals.levels[4]==3,"Retained autosave lost Killer bronze")
	elif stage=="resume":
		check(original.contracts.progress.player_kills==50 and original.contracts.base_medals.levels[4]==3,"Fresh Resume did not open the earned Killer checkpoint")
		if failures:return
		var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(saved.career.progress.player_kills==50 and original.contracts.progress.player_kills==50,"Fresh Resume changed the earned kill count")
		check(saved.career.base_medals.levels[4]==3 and original.contracts.base_medals.levels[4]==3,"Fresh Resume lost Killer bronze")
		check(MedalLedger.valid_retained(original.contracts.base_medals,original.contracts,original.contracts.get("blueprints",{})),"Fresh Resume restored an invalid medal ledger")
		if failures:return
		await capture_free_application("medal-killer-bronze-resumed")
	elif stage=="naysayer_earn":
		await earn_naysayer(original)
	elif stage=="naysayer_resume":
		check(original.contracts.get("rejected_jobs",0)==51 and original.contracts.base_medals.levels[32]==1,"Fresh Resume did not open the earned Naysayer checkpoint")
		if failures:return
		var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(not saved.is_empty() and saved.career.get("rejected_jobs",0)==51,"Fresh Resume changed the explicit refusal count")
		check(not saved.is_empty() and saved.career.base_medals.levels[32]==1,"Fresh Resume lost Naysayer gold")
		check(MedalLedger.valid_retained(original.contracts.base_medals,original.contracts,original.contracts.get("blueprints",{})),"Fresh Resume restored an invalid Naysayer ledger")
		if failures:return
		await capture_free_application("medal-naysayer-gold-resumed")
	elif stage=="renegade_earn":
		var source_document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(not source_document.is_empty() and source_document.career.reputation.axes==[-71,3],"The immutable Renegade source is not the genuine hostile diplomat checkpoint")
		var source_medals: Dictionary=source_document.career.get("base_medals",{})
		check(source_medals.is_empty() or source_medals.get("levels",[]).size()==MedalLedger.BASE_COUNT and source_medals.levels[28]==MedalLedger.UNKNOWN,"The immutable hostile source already contained Renegade gold")
		check(original.contracts.reputation.axes==[-71,3],"Use the genuine hostile diplomat checkpoint for Renegade")
		check(original.contracts.base_medals.levels[28] in [MedalLedger.UNKNOWN,1],"Station preparation produced an invalid Renegade tier")
		if failures:return
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight() or not await dock_application():return
		var docked: Dictionary=app.session.station_owner().snapshot()
		check(docked.contracts.reputation.axes==[-71,3],"Physical Renegade docking changed the earned hostile standing")
		check(docked.contracts.base_medals.levels[28]==1,"Physical docking did not bank Renegade gold")
		var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
		check(not automatic.is_empty() and automatic.career.reputation.axes==[-71,3] and automatic.career.base_medals.levels[28]==1,"The physical-dock autosave lost Renegade gold")
		if failures:return
		await capture_free_application("medal-renegade-gold-docked")
		var destination:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("renegade-gold.gof2save")
		check(DirAccess.copy_absolute(app.station_save_path(),destination)==OK,"Could not retain the physical Renegade autosave")
		var retained: Dictionary=app._save_file.load_document(destination,definitions,catalogue,source)
		check(not retained.is_empty() and retained.career.reputation.axes==[-71,3] and retained.career.base_medals.levels[28]==1,"Retained Renegade autosave lost the earned award")
	elif stage=="renegade_resume":
		check(original.contracts.reputation.axes==[-71,3] and original.contracts.base_medals.levels[28]==1,"Fresh Resume did not open the earned Renegade checkpoint")
		if failures:return
		var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(not saved.is_empty() and saved.career.reputation.axes==[-71,3] and saved.career.base_medals.levels[28]==1,"Fresh Resume lost Renegade gold")
		check(MedalLedger.valid_retained(original.contracts.base_medals,original.contracts,original.contracts.get("blueprints",{})),"Fresh Resume restored invalid Renegade medal evidence")
		if failures:return
		await capture_free_application("medal-renegade-gold-resumed")
	elif stage=="visits_earn":
		check(original.loadout.station_id==7 and original.loadout.system_id==1,"Use the retained Binon Renegade checkpoint for the visit producer proof")
		check(not original.contracts.travel_statistics.has("visited_station_ids") and not original.contracts.travel_statistics.has("visited_system_ids"),"The legacy visit producer input already contains native visit history")
		if failures:return
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight() or not await travel_application(8):return
		var arrived: Dictionary=app.session.snapshot()
		check(arrived.location.station_id==8 and arrived.location.system_id==1,"The visit producer did not physically arrive at the selected planet")
		check(arrived.contracts.travel_statistics.visited_station_ids==[8] and arrived.contracts.travel_statistics.visited_system_ids==[1],"The real local arrival did not record exactly its new station and system")
		check(arrived.contracts.base_medals.levels[11]==0 and arrived.contracts.base_medals.levels[12]==0,"A single real visit crossed a medal threshold")
		if failures or not await dock_application():return
		var docked: Dictionary=app.session.station_owner().snapshot()
		check(docked.loadout.station_id==8 and docked.loadout.system_id==1,"Physical docking lost the visit destination")
		check(docked.contracts.travel_statistics.visited_station_ids==[8] and docked.contracts.travel_statistics.visited_system_ids==[1],"Docking duplicated or lost the source-equivalent visit history")
		check(docked.contracts.base_medals.levels[11]==0 and docked.contracts.base_medals.levels[12]==0,"Docking invented a Space Tourist or Explorer tier")
		var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
		check(not automatic.is_empty() and automatic.career.travel_statistics.visited_station_ids==[8] and automatic.career.travel_statistics.visited_system_ids==[1],"The physical-dock autosave lost visit history")
		if failures:return
		await capture_free_application("medal-visit-history-docked")
		var destination:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("visit-history.gof2save")
		check(DirAccess.copy_absolute(app.station_save_path(),destination)==OK,"Could not retain the physical visit-history autosave")
		var retained: Dictionary=app._save_file.load_document(destination,definitions,catalogue,source)
		check(not retained.is_empty() and retained.career.travel_statistics.visited_station_ids==[8] and retained.career.travel_statistics.visited_system_ids==[1],"Retained autosave lost its earned visit history")
	elif stage=="visits_resume":
		check(original.loadout.station_id==8 and original.loadout.system_id==1,"Fresh Resume did not open the physical visit destination")
		check(original.contracts.travel_statistics.visited_station_ids==[8] and original.contracts.travel_statistics.visited_system_ids==[1],"Fresh Resume lost the native visit sets")
		check(original.contracts.base_medals.levels[11]==0 and original.contracts.base_medals.levels[12]==0,"Fresh Resume invented a visit medal tier")
		check(MedalLedger.valid_retained(original.contracts.base_medals,original.contracts,original.contracts.get("blueprints",{})),"Fresh Resume restored invalid visit-medal evidence")
		if failures:return
		var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(not saved.is_empty() and saved.career.travel_statistics.visited_station_ids==[8] and saved.career.travel_statistics.visited_system_ids==[1],"Fresh Resume changed the physical visit-history save")
		if failures:return
		await capture_free_application("medal-visit-history-resumed")
	else:
		check(false,"Select an explicit earned-medal stage");return
	check(FileAccess.get_sha256(input_path)==input_hash,"The immutable earned input was modified")
	var final: Dictionary=app.session.station_owner().snapshot()
	print("Earned medal threshold result: ",{"stage":stage,"kills":final.contracts.progress.player_kills,"killer":final.contracts.base_medals.levels[4],"rejected_jobs":final.contracts.get("rejected_jobs",0),"naysayer":final.contracts.base_medals.levels[32],"renegade":final.contracts.base_medals.levels[28],"visited_stations":final.contracts.travel_statistics.get("visited_station_ids",[]),"visited_systems":final.contracts.travel_statistics.get("visited_system_ids",[]),"input_sha256":input_hash})

func earn_naysayer(original: Dictionary) -> void:
	var initial_refusals:=int(original.contracts.get("rejected_jobs",0))
	check(initial_refusals<=50,"The immutable earned career already crossed Naysayer")
	check(original.contracts.base_medals.levels[32]!=1,"The immutable earned career already contains Naysayer gold")
	if failures:return
	var selected:=await open_refusible_job()
	if selected<0:check(false,"The earned lounge has no refusible generated job");return
	app.lounge_panel.select_contact(selected)
	check(app.lounge_panel.snapshot().selected==selected and app.lounge_panel.snapshot().accept_visible,"The earned generated job is not selectable")
	check(app.lounge_panel.label_text(848)=="No thanks.","The earned refusal does not expose the original No thanks. action")
	if failures:return
	var count:=initial_refusals
	var crossed_from_50:=false
	while count<51:
		app.lounge_panel.confirm()
		check(app.lounge_panel.snapshot().confirming,"The earned job did not enter explicit confirmation")
		if count==50:await capture_free_application("medal-naysayer-before-refusal")
		var before: Dictionary=app.session.station_owner().snapshot()
		app.lounge_panel.decline()
		var after: Dictionary=app.session.station_owner().snapshot()
		check(not app.lounge_panel.snapshot().confirming,"No thanks. left the job confirmation open")
		check(int(after.contracts.get("rejected_jobs",0))==count+1,"No thanks. did not advance the explicit refusal history exactly once")
		check(not after.contracts.offers[selected].consumed and after.contracts.mission==before.contracts.mission,"No thanks. consumed or accepted the generated job")
		if count==50:
			check(int(before.contracts.get("rejected_jobs",0))==50 and after.contracts.base_medals.levels[32]==1,"The explicit 50-to-51 refusal did not earn Naysayer gold")
			crossed_from_50=true
		count=int(after.contracts.get("rejected_jobs",0))
		if failures:return
	check(crossed_from_50 and count==51,"The earned refusal path did not cross Naysayer exactly at 50-to-51")
	await capture_free_application("medal-naysayer-gold-lounge")
	if not app.contract_action("close",-1):check(false,app.session.error);return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await dock_application():return
	var docked: Dictionary=app.session.station_owner().snapshot()
	check(docked.contracts.get("rejected_jobs",0)==51 and docked.contracts.base_medals.levels[32]==1,"Physical docking lost Naysayer refusal history or gold")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.get("rejected_jobs",0)==51 and automatic.career.base_medals.levels[32]==1,"The physical-dock autosave lost Naysayer history or gold")
	if failures:return
	await capture_free_application("medal-naysayer-gold-docked")
	var destination:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("naysayer-gold.gof2save")
	check(DirAccess.copy_absolute(app.station_save_path(),destination)==OK,"Could not retain the physical Naysayer autosave")
	var retained: Dictionary=app._save_file.load_document(destination,definitions,catalogue,source)
	check(not retained.is_empty() and retained.career.get("rejected_jobs",0)==51 and retained.career.base_medals.levels[32]==1,"Retained Naysayer autosave lost its earned refusal history")

func open_refusible_job() -> int:
	var entry: Dictionary=app.session.station_owner().snapshot()
	var stations: Array=[int(entry.loadout.station_id)]
	for station_id in catalogue.tables.stations.size():
		if catalogue.tables.stations[station_id].system_id==entry.loadout.system_id and station_id!=entry.loadout.station_id:stations.append(station_id)
	for station_id in stations:
		if int(app.session.station_owner().snapshot().loadout.station_id)!=station_id:
			if not await visit_delivery_station(station_id):return -1
		if not app.contract_action("open",-1):check(false,app.session.error);return -1
		for step in 30:
			if not application_step():return -1
		for contact in app.session.station_owner().snapshot().contracts.population.contacts:
			if contact.get("offer",{}).is_empty():continue
			var preview: Dictionary=app.session.station_owner().contract_preview(int(contact.contact_id),definitions)
			if preview.get("can_accept",false):
				print("Naysayer earned offer: ",{"station":station_id,"contact":contact.contact_id,"role":contact.role,"kind":contact.offer.mission.kind})
				return int(contact.contact_id)
		if not app.contract_action("close",-1):check(false,app.session.error);return -1
	return -1
