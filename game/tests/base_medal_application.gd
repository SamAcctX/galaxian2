extends "res://tests/recovery_resume_application.gd"
## Read an immutable earned career, bank only its actual cumulative evidence,
## and save it for a second, fresh application. No counter/award injection.
const MedalLedger=preload("res://src/simulation/base_medal_progress.gd")
const MedalArchive=preload("res://src/simulation/station_archive.gd")

func open_application_content(args: PackedStringArray) -> bool:
	if not super.open_application_content(args):return false
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array or supplement.size()!=3:check(false,"Missing the career's explicit source declarations");return false
		var accepted: bool=definitions.attach_dekato_source(supplement[1],source.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else definitions.attach_nehma_source(supplement[1],source.manifest)
		if not accepted:check(false,definitions.error);return false
	return true

func resumed_contract_valid(state: Dictionary) -> bool:
	return state.campaign_cursor==45 and state.loadout.station_id==99

func verify_free_application() -> void:
	var input:=OS.get_environment("GOF2_SOURCE_SAVE")
	var original_hash:=FileAccess.get_sha256(input)
	var source_document: Dictionary=app._save_file.read_document(input)
	var fresh:=OS.get_environment("GOF2_MEDAL_STAGE")=="resume"
	check(not source_document.is_empty() and source_document.career.has("base_medals")==fresh,"The selected stage did not use its expected earned legacy/ledger file")
	var station: RefCounted=app.session.station_owner()
	var initial: Dictionary=station.snapshot()
	check(initial.contracts.has("base_medals") and MedalLedger.valid_retained(initial.contracts.base_medals,initial.contracts,initial.contracts.get("blueprints",{})),"Resume lost its native-backed medal ledger")
	for field in source_document.career:
		check(initial.contracts.get(field)==source_document.career[field],"Medal migration changed earned career field: "+field)
	check(initial.contracts.base_medals.levels[0]==1 and initial.contracts.base_medals.levels[30]==1,"The earned veteran/completed campaign medals were lost")
	check(initial.contracts.base_medals.levels[1]==MedalLedger.UNKNOWN and initial.contracts.base_medals.levels[27]==MedalLedger.UNKNOWN,"Migration invented hull or lifetime hiring history")
	if failures:return
	var retained_owner: RefCounted=station.contract_owner()
	var retained: Dictionary=retained_owner.snapshot()
	for iteration in 3:
		if not station.poll_contract_result(definitions):check(false,station.error);return
	var banked: Dictionary=station.snapshot()
	check(retained_owner.snapshot()==retained,"Station polling changed a retained parent career")
	check(banked.contracts.base_medals==initial.contracts.base_medals,"Repeated station polling upgraded the same evidence twice")
	if not app.save_station(false):check(false,app._save_file.error);return
	var document: Dictionary=app._save_file.read_document(app.station_save_path())
	check(document.career.base_medals==banked.contracts.base_medals,"The native file omitted banked medals")
	var file_hash:=FileAccess.get_sha256(app.station_save_path())
	# Negative restore probes are detached in-memory records, never game state
	# or replacement save files. Both failures must leave the viable file alone.
	var rejected: Dictionary=document.duplicate(true)
	rejected.career.base_medals.levels[1]=1
	var archive:=MedalArchive.new()
	check(archive.restore(definitions,catalogue,source,rejected)==null,"An unsupported gold medal entered a loaded career")
	check(app.session.station_owner().snapshot()==banked and FileAccess.get_sha256(app.station_save_path())==file_hash,"Rejected medal data changed the game or its viable save")
	var destination:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("retained.gof2save")
	check(DirAccess.copy_absolute(app.station_save_path(),destination)==OK,"Could not retain the checked native output")
	app.present_session();await process_frame;resume_application_focus()
	await capture_free_application("medals-fresh-resume" if fresh else "medals-earned-station")
	check(FileAccess.get_sha256(input)==original_hash,"The earned source file was changed")
	var evidence:={"stage":"resume" if fresh else "save","source_sha256":original_hash,"output_sha256":FileAccess.get_sha256(destination),
		"cursor":banked.campaign_cursor,"station":banked.loadout.station_id,"credits":banked.contracts.credits,
		"base_medals":banked.contracts.base_medals,"progress":banked.contracts.progress,
		"delivery_statistics":banked.contracts.delivery_statistics,"travel_statistics":banked.contracts.travel_statistics,
		"blueprint_counts":MedalLedger.blueprint_counts(banked.contracts.get("blueprints",{})),
		"checks":checks,"failures":failures,"earned_reward_purchase":false}
	var report:=FileAccess.open(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("medals-evidence.json"),FileAccess.WRITE)
	if report==null:check(false,"Could not record medal evidence")
	else:report.store_string(JSON.stringify(evidence,"\t"));report.close()
	print("Earned medal ledger: ",evidence)
