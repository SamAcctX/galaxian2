extends SceneTree
## Browsing starts from an earned career. Route/refusal branches use detached
## observations and must leave the restored station and its availability intact.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Galaxy=preload("res://src/simulation/galaxy_map.gd")
const GalaxyPanel=preload("res://src/presentation/galaxy_map_panel.gd")
var checks:=0
var failures:=0
var opened:=[]
var closed:=0

func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<3:check(false,"Expected content, bindings and visuals");finish();return
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not lib.select_language("gb") or not cat.open(lib) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+visuals.error);finish();return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		if OS.get_environment(key).is_empty():continue
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array:check(false,"Missing retained campaign source");finish();return
		var accepted: bool=bindings.attach_dekato_source(supplement[1],lib.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(supplement[1],lib.manifest)
		if not accepted:check(false,bindings.error);finish();return
	var save:=Save.new();var archive:=Archive.new()
	var document:=save.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,lib)
	if document.is_empty():check(false,save.error);finish();return
	var station: RefCounted=archive.restore(bindings,cat,lib,document)
	if station==null:check(false,archive.error);finish();return
	var before: Dictionary=station.snapshot();var observed:=before.duplicate(true)
	observed.location={"station_id":int(before.loadout.station_id),"system_id":int(before.loadout.system_id)};observed.station_map=true
	var galaxy:=Galaxy.new()
	if not galaxy.configure(lib,bindings,cat,observed):check(false,galaxy.error);finish();return
	var state:=galaxy.snapshot();var available: Array=before.contracts.lounges.system_availability
	check(state.rows.size()==available.count(true),"Galaxy omitted a known system or exposed locked content")
	check(state.rows.all(func(row):return available[row.system_id]),"Unavailable system became selectable")
	var adjacent:=-1;var distant:=-1
	for row in state.rows:
		if row.connected and not row.current and row.supported:adjacent=row.system_id
		if not row.connected and row.supported:distant=row.system_id
	check(adjacent>=0 and distant>=0,"Earned career has no adjacent/distant selection cases")
	check(galaxy.select_system(distant) and galaxy.open_selected()==-1 and galaxy.snapshot().diagnostic==lib.strings[409],"Distant ordinary target bypassed the original gate refusal")
	check(galaxy.select_system(adjacent) and galaxy.open_selected()==adjacent,"Adjacent system cannot open its planet view")
	var retained:=galaxy.snapshot()
	check(not galaxy.select_system(-1) and galaxy.snapshot()==retained,"Unknown system changed selection")
	observed.contracts.lounges.system_availability.fill(false)
	check(galaxy.snapshot()==retained and station.snapshot()==before,"Map borrowed mutable career availability")
	observed=before.duplicate(true);observed.location={"station_id":95,"system_id":19};observed.station_map=true
	observed.mission={"kind":156,"station_id":56,"reward":0,"bonus":0,"source_parameter":0}
	observed.contracts.mission={};observed.contracts.accepted_contact={}
	observed.campaign_cursor=18
	var route_map:=Galaxy.new()
	check(route_map.configure(lib,bindings,cat,observed),route_map.error)
	check(route_map.snapshot().mission_route.size()>2 and route_map.snapshot().mission_route.front()==19 and route_map.snapshot().mission_route.back()==11,"Galaxy omitted multi-hop mission guidance")
	observed=before.duplicate(true);observed.location={"station_id":int(before.loadout.station_id),"system_id":int(before.loadout.system_id)};observed.station_map=true
	var panel:=GalaxyPanel.new();root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.configure(lib,bindings,visuals,cat,observed):check(false,panel.error);panel.free();finish();return
	panel.system_requested.connect(func(id):opened.append(id));panel.close_requested.connect(func():closed+=1)
	panel.set_active(true)
	root.size=Vector2i(1280,720)
	await process_frame;await process_frame
	await capture("galaxy-current-system.png")
	if not state.void_warning.is_empty():
		check(panel._warning!=null and state.rows.filter(func(row):return row.void_source).size()==1,"Earned Void warning has no visible source model")
		var warning_before: Dictionary=before.contracts.void_source.duplicate(true)
		panel._navigation.select_system(int(state.void_warning.system_id));panel._center_selected();panel._present()
		for frame in 30:panel._process(0.1);await process_frame
		await capture("galaxy-void-warning.png")
		check(panel._warning.error.is_empty() and station.snapshot().contracts.void_source==warning_before,"Displaying the animated Void source changed its saved selection")
	panel._navigation.select_system(distant);panel._present();panel.open_selected()
	check(opened.is_empty() and panel.snapshot().diagnostic==lib.strings[409],"Presented distant refusal emitted travel")
	await capture("galaxy-distant-refusal.png")
	panel._navigation.select_system(adjacent);panel._present()
	var enter:=InputEventKey.new();enter.physical_keycode=KEY_ENTER;enter.pressed=true;panel.handle_event(enter)
	check(opened==[adjacent],"Keyboard did not enter the selected adjacent system")
	var gamepad:=InputEventJoypadButton.new();gamepad.button_index=JOY_BUTTON_B;gamepad.pressed=true;panel.handle_event(gamepad)
	check(closed==1,"Controller could not close galaxy navigation")
	panel.set_active(false);panel.handle_event(enter);check(opened.size()==1,"Paused map accepted a course")
	panel.set_active(true);panel.set_mobile_layout(true);root.size=Vector2i(960,540)
	await process_frame;await process_frame
	var point:=Vector2.ZERO
	for row in panel._canvas.rows:
		if row.system_id==adjacent:point=row.pixels
	var press:=InputEventScreenTouch.new();press.pressed=true;press.position=point;panel._gui_input(press)
	press=InputEventScreenTouch.new();press.pressed=false;press.position=point;panel._gui_input(press)
	check(opened.size()==2 and opened.back()==adjacent,"Touch did not enter the selected system")
	await capture("galaxy-touch.png")
	check(station.snapshot()==before,"Presentation changed the earned station")
	panel.clear();panel.free();finish()

func capture(name: String) -> void:
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty():return
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(name))==OK,"Galaxy capture failed")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func finish() -> void:print("Galaxy map: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
