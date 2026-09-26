extends RefCounted
## Exercise a genuinely produced9 record; never create an earned checkpoint.
const Archive=preload("res://src/simulation/station_archive.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Dekato=preload("res://src/content/dekato_convoy_definitions.gd")
var checks:=0
var failures:=0
var completed:=false

func verify(bindings: RefCounted,cat: RefCounted,library: RefCounted,document: Dictionary,base_directory: String,source_directory: String) -> void:
	completed=false
	var archive:=Archive.new()
	check(not preload("res://src/simulation/station_save_file.gd")._supplement_matches(bindings,"malformed-station"),"A malformed station field bypassed the file-level receipt guard")
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot();var untouched:=document.duplicate(true)
	check(document.version==9 and document.binding_id==bindings.binding_id and original.campaign_cursor==39 and original.loadout.station_id==22 and original.arrival_player.campaign_cursor==38,"The actual checkpoint lost its explicit version, location or world/career distinction")
	check(archive.capture(station,bindings)==document,"The v9 checkpoint changed during native recapture")
	check(station.prepare_departure(bindings,cat).is_empty()==not load("res://src/content/free_campaign_definitions.gd").onward_available(bindings),"Restoration ignored the explicit onward source boundary")
	var plain:=Bindings.new();var supplemental:=Bindings.new()
	if not plain.open(base_directory,library.manifest) or not supplemental.open(source_directory,library.manifest):check(false,plain.error+supplemental.error);return
	check(archive.restore(plain,cat,library,document)==null and archive.restored_locations==null,"Unextended202 silently attached supplemental save provenance")
	check(archive.restore(supplemental,cat,library,document)==null,"The supplementary203 identity replaced the original202 save")
	var mutations: Array=[
		[["version"],8],[["version"],9.0],[["version"],10],
		[["station","campaign_cursor"],38],[["station","campaign_cursor"],39.0],
		[["station","mission","station_id"],22],[["station","mission","kind"],11.0],
		[["station","player_cache","values","hull"],0],
		[["station","arrival_player","campaign_cursor"],39],
		[["station","docking","station_id"],20],[["station","docking","position"],"not-a-position"],
		[["station","acknowledged"],false],[["station","reward_credits"],1],
		[["career","campaign_cursor"],38],[["career","credits"],-1],
		[["career","passengers"],0],[["career","pending_result"],{"serial":1}],
		[["career","progress","rank"],99],[["career","completed_side_missions"],3],
		[["locations","current_station_id"],20],
		[["inventory","prototype_drill_replaced"],false],[["inventory","loadout","station_id"],20]]
	for key in document.station.dekato_source_receipt:
		mutations.append([["station","dekato_source_receipt",key],"foreign-source"])
	for mutation in mutations:
		var invalid:=document.duplicate(true);var parent: Dictionary=invalid
		for index in mutation[0].size()-1:parent=parent[mutation[0][index]]
		parent[mutation[0].back()]=mutation[1]
		check(archive.restore(bindings,cat,library,invalid)==null and not archive.error.is_empty() and archive.restored_locations==null,"The checkpoint accepted corrupted or mistyped data: "+str(mutation[0]))
	for path in [["station","dekato_source_receipt"],["career","void_source"],["career","blueprints"],["station","docking"]]:
		var invalid:=document.duplicate(true);invalid[path[0]].erase(path[1])
		check(archive.restore(bindings,cat,library,invalid)==null,"The checkpoint accepted missing provenance/owner: "+str(path))
	var invalid:=document.duplicate(true);invalid.station.dekato_source_receipt.extra="unknown"
	check(archive.restore(bindings,cat,library,invalid)==null,"The checkpoint accepted additional source fields")
	invalid=document.duplicate(true);invalid.station.docking.pre_motion_contact=false;invalid.station.docking.post_motion_volume_index=-1
	check(archive.restore(bindings,cat,library,invalid)==null,"The checkpoint omitted actual accepted contact")
	invalid=document.duplicate(true);invalid.version=8;invalid.station.erase("dekato_source_receipt")
	check(archive.restore(bindings,cat,library,invalid)==null,"A stripped receipt downgraded a39 checkpoint into legacy8")
	var detached: RefCounted=station.fork();detached._state.dekato_source_receipt.source_binding_id="foreign"
	check(archive.capture(detached,bindings).is_empty(),"Capture silently replaced the retained supplemental source")
	check(station.snapshot()==original and document==untouched,"Rejected detached restoration mutated its retained native owners")
	check(archive.restore(bindings,cat,library,document)!=null and archive.capture(station,bindings)==document,"A failed load poisoned the viable checkpoint")
	completed=true

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
