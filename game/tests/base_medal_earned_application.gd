extends "res://tests/lounge_diplomat_journey.gd"
## Earn one real cumulative medal tier from the immutable end-game career.
## No counters or medal levels are injected: combat, travel, docking and the
## station autosave are the only producers promoted by this test.
const MedalLedger=preload("res://src/simulation/base_medal_progress.gd")

func resumed_contract_valid(state: Dictionary) -> bool:
	if OS.get_environment("GOF2_MEDAL_EARNED_STAGE")=="resume":
		return state.campaign_cursor==45 and state.contracts.progress.player_kills==50 and state.contracts.base_medals.levels[4]==3
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
	else:
		check(false,"Select an explicit earned-medal stage");return
	check(FileAccess.get_sha256(input_path)==input_hash,"The immutable earned input was modified")
	print("Earned medal threshold result: ",{"stage":stage,"kills":app.session.station_owner().snapshot().contracts.progress.player_kills,"killer":app.session.station_owner().snapshot().contracts.base_medals.levels[4],"input_sha256":input_hash})
