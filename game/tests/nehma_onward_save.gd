extends SceneTree
## Positive records come only from the real onward application producer.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const PrivateOutput=preload("res://tests/fixtures/convoy_station_scenario.gd")
const SaveCompare=preload("res://tests/fixtures/save_compare.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	verify()
	print("Onward station saves: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Supply original202 content arguments");return
	var extra: Array=[]
	for name in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(name)))
		if not value is Array or value.size()!=3:check(false,"Supply both explicit supplemental sources");return
		extra.append(str(value[1]))
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library) or not bindings.attach_dekato_source(extra[0],library.manifest) or not bindings.attach_nehma_source(extra[1],library.manifest):check(false,library.error+bindings.error+cat.error);return
	var path:=OS.get_environment("GOF2_SOURCE_SAVE");var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	check(expected.length()==64 and FileAccess.get_sha256(path)==expected,"Use an exact retained actual onward checkpoint")
	if failures:return
	var file:=Save.new();var document:=file.load_document(path,bindings,cat,library)
	if document.is_empty():check(false,file.error);return
	var archive:=Archive.new();var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot();var untouched:=document.duplicate(true)
	check(document.version==10 and document.binding_id==bindings.binding_id and original.campaign_cursor in [39,40] and original.arrival_player.campaign_cursor==39,"The actual onward save lost its version or surviving world")
	check(Archive.Nehma.station_mission(bindings,original.campaign_cursor,original.loadout.station_id,original.mission) and SaveCompare.matches_older(archive.capture(station,bindings),document),"Native recapture changed the actual sourced station")
	check(original.contracts.credits==19370 and original.contracts.passengers==3 and original.cargo.entries.is_empty(),"Onward persistence changed the independent wallet or passenger job")
	check(not station.prepare_departure(bindings,cat).is_empty(),"The earned station cannot prepare its supported next departure")
	if original.campaign_cursor==40:
		var fitting: RefCounted=load("res://tests/fixtures/mission_paid_loadout.gd").new()
		var refitted: RefCounted=fitting.prepare(bindings,cat,library,station,check)
		if refitted==null:check(false,fitting.error);return
		var fitted: Dictionary=refitted.snapshot()
		var after: Dictionary=archive.capture(refitted,bindings)
		check(not after.is_empty(),"A paid Néhma refit cannot be saved: "+archive.error)
		if failures:return
		var resumed: RefCounted=archive.restore(bindings,cat,library,after)
		check(resumed!=null,"The paid refit cannot Resume: "+archive.error)
		if failures:return
		check(archive.capture(resumed,bindings)==after and resumed.snapshot().loadout==fitted.loadout,"Resume lost the purchased primary or its paid station record")
		check(fitted.arrival_player==original.arrival_player and fitted.player_cache==original.player_cache,"A station purchase rewrote arrival pools or equipment history")
		check(not resumed.prepare_departure(bindings,cat).is_empty(),"The saved refit cannot prepare its next departure")
	var plain:=Bindings.new();var previous:=Bindings.new();var selected:=Bindings.new()
	if not plain.open(args[1],library.manifest) or not previous.open(args[1],library.manifest) or not previous.attach_dekato_source(extra[0],library.manifest) or not selected.open(extra[1],library.manifest):check(false,plain.error+previous.error+selected.error);return
	for candidate in [plain,previous,selected]:
		check(archive.restore(candidate,cat,library,document)==null and archive.restored_locations==null,"A missing or rebased supplemental identity restored v10")
	check(not Save._supplement_matches(previous,document.station,10) and not Save._supplement_matches(bindings,"not-a-station",10),"File provenance accepted a missing source or malformed station")
	var mutations: Array=[
		[["version"],8],[["version"],9],[["version"],10.0],
		[["station","campaign_cursor"],float(original.campaign_cursor)],
		[["station","mission","kind"],float(original.mission.kind)],
		[["station","mission","station_id"],99],[["station","mission","reward"],1],
		[["station","arrival_player","campaign_cursor"],38],[["station","arrival_player","campaign_cursor"],40],
		[["station","player_cache","values","hull"],0],
		[["station","docking","station_id"],99],[["station","docking","position"],"not-a-pose"],
		[["station","acknowledged"],false],[["station","reward_credits"],1],
		[["career","campaign_cursor"],38],[["career","credits"],-1],[["career","passengers"],0],
		[["career","pending_result"],{"serial":1}],[["career","progress","rank"],99],
		[["locations","current_station_id"],99],[["inventory","loadout","station_id"],99]]
	if original.campaign_cursor==40:mutations.append([["station","campaign_conversation"],true])
	for receipt in ["dekato_source_receipt","nehma_source_receipt"]:
		for key in document.station[receipt]:
			mutations.append([["station",receipt,key],"foreign-source"])
			mutations.append([["station",receipt,key],0])
	for mutation in mutations:
		var invalid:=document.duplicate(true);var parent: Dictionary=invalid
		for index in mutation[0].size()-1:parent=parent[mutation[0][index]]
		parent[mutation[0].back()]=mutation[1]
		check(archive.restore(bindings,cat,library,invalid)==null and not archive.error.is_empty() and archive.restored_locations==null,"The onward archive accepted altered/mistyped "+str(mutation[0]))
	for missing in [["station","dekato_source_receipt"],["station","nehma_source_receipt"],["station","docking"],["career","void_source"],["career","blueprints"]]:
		var invalid:=document.duplicate(true);invalid[missing[0]].erase(missing[1])
		check(archive.restore(bindings,cat,library,invalid)==null,"The onward archive accepted missing "+str(missing))
	for receipt in ["dekato_source_receipt","nehma_source_receipt"]:
		var invalid:=document.duplicate(true);invalid.station[receipt].extra="unknown"
		check(archive.restore(bindings,cat,library,invalid)==null,"The onward archive accepted extra provenance")
	check(document==untouched and station.snapshot()==original,"Rejected archives mutated the actual retained owners")
	if failures:return
	verify_file_boundary(file,station,bindings,previous,cat,library,document)
	check(FileAccess.get_sha256(path)==expected and bindings.binding_id==document.binding_id and not bindings.mido_travel.has("nehma_return"),"Save validation changed the actual checkpoint or raw202 identity")
	print("Actual onward checkpoint: ",JSON.stringify({"sha256":expected,"version":document.version,"cursor":original.campaign_cursor,"station":original.loadout.station_id,"world_cursor":original.arrival_player.campaign_cursor,"vitals":original.player_cache.values,"equipment":original.loadout.slots,"credits":original.contracts.credits,"passengers":original.contracts.passengers,"gate_statistics":original.contracts.travel_statistics}))

func verify_file_boundary(file: RefCounted,station: RefCounted,bindings: RefCounted,previous: RefCounted,cat: RefCounted,library: RefCounted,document: Dictionary) -> void:
	var root_path:=OS.get_environment("GOF2_ONWARD_GUARD_DIRECTORY")
	var directory:=root_path.path_join("run-%d-%d"%[int(Time.get_unix_time_from_system()),Time.get_ticks_usec()])
	var main:=directory.path_join("station.gof2save")
	if root_path.is_empty() or not PrivateOutput.private_path(main) or FileAccess.file_exists(main) or DirAccess.make_dir_recursive_absolute(directory)!=OK:check(false,"Use a new private save-guard directory");return
	var legacy_path:=OS.get_environment("GOF2_LEGACY_SOURCE_SAVE")
	var legacy_sha:=FileAccess.get_sha256(legacy_path)
	var legacy: Dictionary=file.read_document(legacy_path)
	check(legacy_sha=="0b7043d77501317f6d04c9f59c1a929c81a99d99e33b853b8b35cab7197643d4" and legacy.get("version")==9,"Use the original retained v9 rollback guard")
	if failures:return
	if DirAccess.copy_absolute(legacy_path,main)!=OK:check(false,"Could not stage an isolated v9 checkpoint");return
	check(file.save(main,station,bindings,cat,library),file.error)
	if failures:return
	var main_sha:=FileAccess.get_sha256(main);var backup_sha:=FileAccess.get_sha256(main+".bak")
	check(SaveCompare.matches_older(file.read_document(main),document) and backup_sha==legacy_sha,"The atomic9→10 upgrade changed its backup or earned record")
	check(file.load_document(main,previous,cat,library).is_empty() and not file.recovered_backup and not file.error.is_empty(),"A missing204 source silently rolled an intact v10 back to v9")
	var archive:=Archive.new();var old_station: RefCounted=archive.restore(bindings,cat,library,legacy)
	check(old_station!=null and not file.save(main,old_station,bindings,cat,library),"A v9 save silently overwrote an onward v10 checkpoint")
	check(FileAccess.get_sha256(main)==main_sha and FileAccess.get_sha256(main+".bak")==backup_sha and FileAccess.get_sha256(legacy_path)==legacy_sha,"A rejected downgrade changed checkpoint bytes")
	check(SaveCompare.matches_older(file.load_document(main,bindings,cat,library),document) and not file.recovered_backup,"Explicit source restoration changed the actual v10 record")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
