extends SceneTree
## Verified additive source updates retain an earned career's original identity.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Importer=preload("res://src/content/dmg_import.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Worlds=preload("res://src/content/ordinary_world_definitions.gd")
const Jobs=preload("res://src/content/ordinary_contracts_definitions.gd")
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected original import, newer import and earned save");finish();return
	var original:=Importer.read_receipt(args[0]);var update:=Importer.read_receipt(args[1])
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	check(library.open(args[0].get_base_dir().path_join(original.content)),library.error)
	check(bindings.open(args[0].get_base_dir().path_join(original.bindings),library.manifest,library),bindings.error)
	check(cat.open(library) and library.select_language("gb"),cat.error+library.error)
	if failures:finish();return
	var file:=SaveFile.new();var archive:=Archive.new()
	var saved:=FileAccess.get_file_as_bytes(args[2]);var document:=file.read_document(args[2])
	var station:=archive.restore(bindings,cat,library,document)
	check(station!=null,archive.error)
	if failures:finish();return
	var before: Dictionary=station.snapshot()
	check(bindings.attach_import_update(args[1].get_base_dir().path_join(update.bindings),library.manifest,library),bindings.error)
	check(bindings.binding_id==original.binding_id and bindings.import_update_receipt().get("source_binding_id")==update.binding_id,"Update relabeled the original content or lost the supplemental source")
	station=archive.restore(bindings,cat,library,document)
	check(station!=null and station.snapshot()==before,"Updated source changed the earned station, inventory or career")
	if failures:finish();return
	var rules: Dictionary=bindings.early_contracts.base_station_stock
	for id in range(int(rules.last_station_id)+1):
		check(not Worlds.catalogue_location(bindings,cat,id).is_empty(),"Base-game station excluded from shared world support: "+str(id))
		for kind in range(int(bindings.early_contracts.ordinary_generation.offers.kind_count)):
			var mission:={"kind":kind,"story":false,"difficulty":2,"station_id":id,"quantity":3,"source_parameter":97,"target_name":"Test target"}
			check(Jobs.retained_mission(bindings,mission,18),"Implemented job excluded at destination %d, kind %d"%[id,kind])
	var target:="user://import-update/station.gof2save"
	check(file.save(target,station,bindings,cat,library,archive.restored_locations),file.error)
	var updated:=file.read_document(target)
	check(updated.get("binding_id")==document.binding_id and updated.get("import_update")==bindings.import_update_receipt(),"Save did not retain its original identity and exact extension receipt")
	check(archive.restore(bindings,cat,library,updated)!=null,archive.error)
	var earlier:=Bindings.new();check(earlier.open(args[0].get_base_dir().path_join(original.bindings),library.manifest,library),earlier.error)
	check(archive.restore(earlier,cat,library,updated)==null,"An updated career silently loaded without its required additional source")
	check(FileAccess.get_file_as_bytes(args[2])==saved,"Updating a copied career changed the player's original save")
	var proof=preload("res://src/content/import_update.gd")
	var changed: Dictionary=bindings._update_body.duplicate(true);changed.pilot_response.target_gain+=1
	check(not proof.compatible(bindings._update_header,bindings._update_body,bindings._update_header,changed),"An update changed an existing flight rule")
	var foreign:=bindings._update_header.duplicate(true);foreign.source_executable_sha256="f".repeat(64)
	check(not proof.compatible(bindings._update_header,bindings._update_body,foreign,bindings._update_body),"An update crossed original executable identities")
	finish()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func finish():print("Import compatibility: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
