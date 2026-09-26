extends SceneTree
## Fresh-process validation of the genuine station39 producer, not a fixture.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const Guards=preload("res://tests/fixtures/dekato_station_checks.gd")
const PrivatePath=preload("res://tests/fixtures/free_play_station_scenario.gd")

func _initialize() -> void:
	var guards:=Guards.new();var args:=OS.get_cmdline_user_args()
	if args.size()!=3:guards.check(false,"Supply original202 content and source arguments")
	else:verify(args,guards)
	print("Dekato station saves: %d checks; %d failures"%[guards.checks,guards.failures])
	quit(1 if guards.failures else 0)

func verify(args: PackedStringArray,guards: RefCounted) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	if not supplement is Array or supplement.size()!=3:guards.check(false,"Supply the independently validated supplement");return
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library) or not bindings.attach_dekato_source(str(supplement[1]),library.manifest):guards.check(false,library.error+bindings.error+cat.error);return
	var path:=OS.get_environment("GOF2_SOURCE_SAVE");var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	guards.check(expected.length()==64 and FileAccess.get_sha256(path)==expected,"Use the exact retained genuine39 checkpoint")
	if guards.failures:return
	var file:=SaveFile.new();var document:=file.load_document(path,bindings,cat,library)
	if document.is_empty():guards.check(false,file.error);return
	guards.verify(bindings,cat,library,document,args[1],str(supplement[1]))
	guards.check(guards.completed,"The archive guard suite did not finish")
	var archive:=Guards.Archive.new();var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:guards.check(false,archive.error);return
	verify_pilot_observation(OS.get_environment("GOF2_DEKATO_EXPECTED_STATE"),path,station.snapshot(),guards)
	guards.check(FileAccess.get_sha256(path)==expected,"Archive validation changed its immutable earned39 source")

## Optional historical guard runs remain possible, but only a producer's live
## observation earns a fresh pilot Resume claim. Never supply expected vitals
## or ammunition from an older battle: compare the complete native snapshot.
static func verify_pilot_observation(path: String,saved: String,station: Dictionary,guards: RefCounted) -> void:
	if path.is_empty():
		print("Historical checkpoint guard only; no new pilot observation supplied")
		return
	guards.check(PrivatePath.private_path(path) and FileAccess.file_exists(path),"Supply the newly produced pilot observation from private output")
	if guards.failures:return
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:guards.check(false,"Could not read the retained live pilot observation");return
	var observed: Variant=file.get_var(false);file.close()
	guards.check(observed is Dictionary,"Malformed pilot observation")
	if guards.failures:return
	guards.check(observed.get("format")==1 and observed.get("source_sha")=="b86c1dac98a7e68ce768bca8ee33e4500bb2cf5d81985d8bd4caff6e295c7c70" and observed.get("output_sha")==FileAccess.get_sha256(saved),"The observation belongs to another source or another produced save")
	guards.check(observed.get("station")==station,"Fresh restoration changed the producer's live pools, ammunition, equipment, progress, stock or independent career")
	guards.check(observed.get("losses") in [0,1] and observed.get("timing") in ["100ms","144hz","variable"] and observed.get("dialogue_inputs",[]).has("mouse") and observed.get("dialogue_inputs",[]).has("keyboard"),"The pilot record lacks its requested successful player path")
