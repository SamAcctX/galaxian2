extends SceneTree
const Preferences=preload("res://src/content/player_preferences.gd")
const DisplaySettings=preload("res://src/presentation/display_settings.gd")
const Frontend=preload("res://src/presentation/player_frontend.gd")
const PathGuard=preload("res://tests/fixtures/free_play_station_scenario.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var directory:=OS.get_environment("GOF2_DISPLAY_TEST_DIRECTORY")
	if directory.is_empty() and not OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").is_empty():directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("display")
	if directory.is_empty() or not PathGuard.private_path(directory+"/player.json"):
		check(false,"Supply a private display test directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	var path:=directory.path_join("player.json")
	check(not FileAccess.file_exists(path),"Use a fresh display test directory")
	var original:=Preferences.defaults();original.schema=1
	for key in Preferences.DISPLAY_KEYS+["mouse_steering","mouse_sensitivity","bloom","upscaler","render_scale","graphics_quality"]:original.erase(key)
	original.content="/example/content";original.import_record="/example/installation.json";original.music=0.4;original.invert_pitch=true
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(original));file.close()
	var prefs:=Preferences.new();check(prefs.read_file(path),prefs.error)
	for key in original:
		if key!="schema":check(prefs.values[key]==original[key],"Preferences upgrade lost "+key)
	check(prefs.values.schema==6 and prefs.values.mouse_steering and prefs.values.ui_scale==0 and prefs.values.bloom,"Preferences upgrade omitted desktop controls, automatic UI scale or Bloom")
	var version2:=prefs.values.duplicate(true);version2.schema=2;version2.erase("ui_scale")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(version2));file.close()
	check(prefs.read_file(path) and prefs.values.schema==6 and prefs.values.content==original.content and prefs.values.music==original.music,"Version 2 upgrade lost the existing installation/preferences")
	var version3:=prefs.values.duplicate(true);version3.schema=3;version3.erase("bloom");version3.ui_scale=150
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(version3));file.close()
	check(prefs.read_file(path) and prefs.values.bloom and prefs.values.ui_scale==150 and prefs.values.content==original.content,"Version 3 upgrade lost settings or omitted Bloom")
	var version4:=prefs.values.duplicate(true);version4.schema=4;version4.erase("upscaler");version4.erase("render_scale")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(version4));file.close()
	check(prefs.read_file(path) and prefs.values.upscaler=="off" and prefs.values.render_scale==0.77 and prefs.values.ui_scale==150,"Version 4 upgrade lost settings or omitted upscaling")
	var version5:=prefs.values.duplicate(true);version5.schema=5;version5.erase("graphics_quality")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(version5));file.close()
	check(prefs.read_file(path) and prefs.values.graphics_quality==1.0 and prefs.values.upscaler=="off","Version 5 upgrade lost settings or did not default to High quality")
	# Graphics quality: Low/Medium turn off camera dust and fog and lower the
	# level-of-detail input; High keeps both.
	var Quality:=preload("res://src/presentation/graphics_quality.gd")
	var effects:=quality_effects()
	for level in [0.0,0.5]:
		effects.apply({"graphics_quality":level});check(not Quality.effects_enabled(),"Quality %s kept dust and fog"%level)
	effects.apply({"graphics_quality":1.0});check(Quality.effects_enabled(),"High quality hid dust and fog")
	var selector:=preload("res://src/presentation/geometry_detail.gd").new()
	check(selector.configure([1000,2000,3000],3,0,[0.3,0.6],[0.25,0.5,1.0]),selector.error)
	var levels:=[]
	for level in [0.0,0.5,1.0]:
		Quality.level=level;levels.append(selector.select(1500.0*1500.0,1.0).get("level"))
	Quality.level=1.0
	check(levels[0]!=levels[2],"Graphics quality did not change the level of detail: %s"%str(levels))
	# Upscaling reaches the 3D viewport only in a mode the renderer supports.
	var Effects:=preload("res://src/presentation/scene_effect_settings.gd")
	check(Effects.supported_upscalers().has("off"),"Native rendering is not offered")
	var probe:=SubViewport.new();root.add_child(probe)
	Effects.configure_viewport(probe,"fsr1",0.67)
	check(probe.scaling_3d_mode==Viewport.SCALING_3D_MODE_FSR and is_equal_approx(probe.scaling_3d_scale,0.67),"FSR 1.0 did not reach the 3D viewport")
	Effects.configure_viewport(probe,"off",0.5)
	check(probe.scaling_3d_mode==Viewport.SCALING_3D_MODE_BILINEAR and probe.scaling_3d_scale==1.0,"Native rendering kept a reduced scale")
	probe.free()
	prefs.values.ui_scale=0
	for pair in [["resolution","0x0"],["aspect_ratio","portrait"],["frame_rate",true],["frame_rate",61],["mouse_sensitivity",NAN],["mouse_sensitivity",0],["window_mode","invalid"],["ui_scale",true],["ui_scale",101],["ui_scale",NAN],["ui_scale",400],["upscaler","dlss"],["render_scale",0.3]]:
		var invalid:=prefs.values.duplicate();invalid[pair[0]]=pair[1]
		check(not Preferences.valid(invalid),"Invalid display/input preference accepted: "+pair[0])
	var settings:=DisplaySettings.new()
	var invalid_bloom:=prefs.values.duplicate();invalid_bloom.bloom=1
	check(not Preferences.valid(invalid_bloom),"Non-boolean Bloom preference accepted")
	root.unfocusable=true
	settings.apply(root,prefs.values)
	for rate in Preferences.FRAME_RATES:
		prefs.values.frame_rate=rate;settings.apply(root,prefs.values)
		check(Engine.max_fps==maxi(0,rate),"Frame cap was not applied")
		if DisplayServer.get_name()!="headless":check(DisplayServer.window_get_vsync_mode()==(DisplayServer.VSYNC_ENABLED if rate==-1 else DisplayServer.VSYNC_DISABLED),"Frame choice did not update V-Sync")
	prefs.values.frame_rate=0;prefs.values.resolution="native";prefs.values.aspect_ratio="native";prefs.values.mouse_sensitivity=1.7;prefs.values.bloom=false
	check(prefs.save_file(path,prefs.values),prefs.error)
	var restarted:=Preferences.new();check(restarted.read_file(path) and restarted.values==prefs.values,"Restart lost display or mouse settings")
	for native in [Vector2i(1920,1080),Vector2i(3024,1964),Vector2i(3440,1440),Vector2i(8000,5120)]:
		check(DisplaySettings.resolution_size("native",native)==native,"Native resolution was reduced to a preset")
		check(DisplaySettings.aspect_size(native,"native",native)==native,"Native aspect ratio added bars")
	check(DisplaySettings.aspect_size(Vector2i(1600,900),"16:10",Vector2i(1920,1080))==Vector2i(1440,900),"Fixed aspect ratio distorted geometry")
	check(DisplaySettings.fit_size(Vector2i(3840,2160),Vector2i(1600,900))==Vector2i(1600,900),"Oversized window escaped the screen")
	check(DisplaySettings.ui_factor(Vector2i(5120,2880),0)==2.75,"5K automatic UI scale remained tiny")
	check(DisplaySettings.ui_factor(Vector2i(5120,2880),200)==2.0,"Explicit UI percentage was ignored")
	check(DisplaySettings.ui_factor(Vector2i(960,540),300)==1.0,"Large UI choice made a small window unusable")
	root.size_changed.disconnect(settings.refresh_aspect)
	var args:=OS.get_cmdline_user_args()
	if args.size()>=3:await check_options(args,directory)
	Engine.max_fps=0
	print("Display/settings: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func check_options(args: PackedStringArray,directory: String) -> void:
	var app:=Frontend.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.boot(PackedStringArray(),directory.path_join("ui"))
	var selection:=Preferences.defaults();selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2]
	if not app.select_content(selection):check(false,app.error);app.free();return
	app.show_options()
	app._settings_controls.frame_rate.select(Preferences.FRAME_RATES.find(0))
	app._settings_controls.frame_rate.item_selected.emit(Preferences.FRAME_RATES.find(0))
	check(app.preferences.values.frame_rate==0 and Engine.max_fps==0,"Unlimited option did not reach the renderer")
	for size in [Vector2i(1280,800),Vector2i(1440,600)]:
		root.size=size
		app.change_preference("aspect_ratio","auto")
		await process_frame;await process_frame;await process_frame
		check(root.content_scale_size==Vector2i.ZERO and Vector2i(app.size)==root.size,"Automatic aspect did not fill the window at native pixels")
		check(app.get_global_rect().encloses(app._details.get_global_rect()),"Options escaped the resized window")
		if args.size()>3 and DisplayServer.get_name()!="headless":
			DirAccess.make_dir_recursive_absolute(args[3]);RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(args[3].path_join("options-%dx%d.png"%[size.x,size.y]))==OK,"Could not capture options")
	app.change_preference("aspect_ratio","16:10");await process_frame;await process_frame
	check(absf(app.size.x/app.size.y-1.6)<0.002,"Fixed aspect ratio stretched the UI")
	if DisplayServer.get_name()!="headless":
		app.change_preference("aspect_ratio","auto")
		app.change_preference("window_mode","fullscreen")
		await wait_for_window(Window.MODE_FULLSCREEN)
		check(root.mode==Window.MODE_FULLSCREEN and root.size==DisplaySettings.native_size(root),"Fullscreen did not use native display resolution: mode=%d size=%s native=%s"%[root.mode,root.size,DisplaySettings.native_size(root)])
		check((app.size*root.content_scale_factor-Vector2(root.size)).length()<4 and app._settings_controls.resolution.disabled,"Fullscreen did not fill the native aspect or explain window-only resolutions")
		app.change_preference("window_mode","windowed")
		await wait_for_window(Window.MODE_WINDOWED)
		check(root.mode==Window.MODE_WINDOWED and not app._settings_controls.resolution.disabled,"Could not return from fullscreen")
	root.size=Vector2i(5120,2880)
	app.change_preference("aspect_ratio","auto")
	app.show_options()
	app._settings_controls.ui_scale.select(Preferences.UI_SCALES.find(200))
	app._settings_controls.ui_scale.item_selected.emit(Preferences.UI_SCALES.find(200))
	await process_frame;await process_frame;await process_frame
	check(app.preferences.values.ui_scale==200 and root.content_scale_factor==2.0,"UI scaling option did not apply live")
	check(app.get_global_rect().encloses(app._details.get_global_rect()),"Scaled options escaped the logical viewport")
	var restored:=Preferences.new()
	check(restored.read_file(directory.path_join("ui/player.json")) and restored.values.ui_scale==200,"UI percentage was not saved")
	var view:=preload("res://src/presentation/native_scene_view.gd").new();app.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame;await process_frame
	check(view.viewport.size==root.size,"UI scaling reduced the 3D render resolution: "+str(view.viewport.size))
	check(view.viewport.get_visible_rect().size.is_equal_approx(app.size),"3D projection no longer matches logical HUD coordinates")
	view.free()
	if args.size()>3 and DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(args[3].path_join("options-5k-200.png"))==OK,"Could not capture 5K options")
	app.change_preference("ui_scale",0);await process_frame;await process_frame
	check(is_equal_approx(root.content_scale_factor,DisplaySettings.ui_factor(root.size,0)),"Automatic scaling did not return after a manual choice")
	app.free();await process_frame

func wait_for_window(mode: int) -> void:
	# The OS window manager applies modes asynchronously, beyond a few uncapped frames.
	var deadline:=Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if root.mode==mode and (mode!=Window.MODE_FULLSCREEN or root.size==DisplaySettings.native_size(root)):return

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func quality_effects() -> RefCounted:return preload("res://src/presentation/scene_effect_settings.gd").new()
