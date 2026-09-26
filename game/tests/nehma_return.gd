extends SceneTree
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const Guards=preload("res://tests/fixtures/nehma_return_checks.gd")

func _initialize() -> void:
	var guards:=Guards.new()
	verify(OS.get_cmdline_user_args(),guards)
	print("Néhma39 retained-source and dialogue components: %d checks; %d failures"%[guards.checks,guards.failures])
	quit(1 if guards.failures else 0)

func verify(args: PackedStringArray,guards: RefCounted) -> void:
	if args.size()!=3:guards.check(false,"Supply original202 arguments");return
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	var parent: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_DEKATO_SOURCE_ARGS")))
	var addon: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_NEHMA_SOURCE_ARGS")))
	if not parent is Array or parent.size()!=3 or not addon is Array or addon.size()!=3:guards.check(false,"Supply explicit203 and204 source arguments");return
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library) or not bindings.attach_dekato_source(str(parent[1]),library.manifest):guards.check(false,library.error+bindings.error+cat.error);return
	var path:=OS.get_environment("GOF2_SOURCE_SAVE");var sha:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	guards.check(sha=="0b7043d77501317f6d04c9f59c1a929c81a99d99e33b853b8b35cab7197643d4" and FileAccess.get_sha256(path)==sha,"Use the exact earned station39 save")
	if guards.failures:return
	var file:=SaveFile.new();var document:=file.load_document(path,bindings,cat,library)
	if document.is_empty():guards.check(false,file.error);return
	guards.verify(bindings,library,cat,document,args[1],str(addon[1]))
	guards.check(guards.completed,"The new source/conversation suite did not finish")
	guards.check(FileAccess.get_sha256(path)==sha,"Tests changed the actual earned save")
