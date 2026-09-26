extends SceneTree
## Separate-process Resume proof. No prior flight, source helper, live world or
## mission constructor is involved; the input is the saved station document.
const Host=preload("res://src/presentation/opening_preview.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()!=3:check(false,"Supply content, bindings and visuals")
	else:await verify(args)
	print("Fresh mission station Resume: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
func verify(args: Array) -> void:
	var library: RefCounted=load("res://src/content/library.gd").new()
	var bindings: RefCounted=load("res://src/content/resource_bindings.gd").new()
	var catalogues:=Host.Catalogues.new()
	if not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not catalogues.open(library):check(false,library.error+bindings.error+catalogues.error);return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array or supplement.size()!=3:check(false,"Missing explicit "+key);return
		var accepted: bool=bindings.attach_dekato_source(supplement[1],library.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(supplement[1],library.manifest)
		if not accepted:check(false,bindings.error);return
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(args[2],library.manifest):check(false,visuals.error);return
	var path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var save:=Host.StationSaveFile.new()
	var document: Dictionary=save.load_document(path,bindings,catalogues,library)
	if document.is_empty():check(false,save.error);return
	check(document.version==11,"Resume did not receive the new native station checkpoint")
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i.ZERO
	var app:=Host.new();root.add_child(app);app.set_process(false)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.library=library;app.bindings=bindings;app.visuals=visuals;app.enable_saves(path.get_base_dir().get_base_dir().get_base_dir())
	check(app.session==null and app.station_save_path()==path,"Fresh Resume unexpectedly inherited an active session")
	if not app.load_station(1000000):check(false,"Fresh application Resume: "+app._save_notice.text);app.free();return
	var recovered: Dictionary=app.session.snapshot()
	check(app.session is Host.StationSession and recovered.campaign_cursor==43 and recovered.loadout.station_id==10,"Fresh Resume lost the Thynome station boundary")
	for key in ["mission","player_cache","progress","mission_station_return","station_response_flags"]:
		check(recovered.get(key)==document.station.get(key),"Fresh Resume changed station state: "+key)
	check(not recovered.station_response_flags.is_empty(),"Fresh Resume received a checkpoint without its earned station-response history")
	var career: Dictionary=recovered.contracts.duplicate(true);career.erase("lounges")
	check(career==document.career,"Fresh Resume changed passenger terms, wallet, progression or source history")
	check(app.session.station_owner().equipment_owner().snapshot().loadout==document.inventory.loadout,"Fresh Resume changed the paid ship")
	check(app.session.location_owner().snapshot()==document.locations,"Fresh Resume regenerated station cache or offers")
	app.present_session()
	if DisplayServer.get_name()!="headless":
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image: Image=root.get_texture().get_image()
		check(image.save_png(OS.get_environment("GOF2_CAPTURE_DIR").path_join("mission-station-fresh-resume.png"))==OK,"Could not capture fresh Resume")
	app.free()
