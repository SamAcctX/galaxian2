extends "res://tests/player_frontend.gd"
## Measure the real application using a new opening and an optional earned save.
## Timings are reported, not asserted against hardware-specific thresholds.
var now_us:=0

func run() -> void:
	args=OS.get_cmdline_user_args();directory=OS.get_environment("GOF2_MENU_TEST_DIRECTORY")
	if args.size()<3 or directory.is_empty() or not PathGuard.private_path(directory+"/player.json"):
		check(false,"Supply content and a private benchmark directory");quit(1);return
	app=Frontend.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.boot(PackedStringArray(),directory)
	var selection:=Preferences.defaults();selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2]
	if not app.select_content(selection):check(false,app.error);finish();return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		if OS.get_environment(key).is_empty():continue
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array or supplement.size()!=3:check(false,"Missing "+key);finish();return
		if not (app.bindings.attach_dekato_source(supplement[1],app.library.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else app.bindings.attach_nehma_source(supplement[1],app.library.manifest)):check(false,app.bindings.error);finish();return
	var update:=OS.get_environment("GOF2_IMPORT_UPDATE")
	if not update.is_empty() and app.bindings.import_update_receipt().is_empty() and not app.bindings.attach_import_update(update,app.library.manifest,app.library):check(false,"Import update: "+app.bindings.error);finish();return
	app.change_preference("frame_rate",0);root.size=Vector2i(1920,1080);root.grab_focus()
	var upscaler:=OS.get_environment("GOF2_BENCH_UPSCALER")
	if not upscaler.is_empty():
		check(app.change_preference("upscaler",upscaler) and app.change_preference("render_scale",0.67),"Upscaler %s refused: %s"%[upscaler,app.error])
	if not app._enter_game("new_game"):check(false,app.error);finish();return
	await measure("opening")
	var source_save:=OS.get_environment("GOF2_SOURCE_SAVE")
	if not source_save.is_empty() and not failures:
		app.show_menu()
		var path: String=app.game.station_save_path();DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if DirAccess.copy_absolute(source_save,path)!=OK:check(false,"Could not stage the earned save");finish();return
		if not app._enter_game("load"):check(false,app.error);finish();return
		await measure("station")
		# Step through any arrival conversation the save resumes into.
		for line in 64:
			if app.game.session.snapshot().phase in app.game.STATION_DEPARTURE_PHASES:break
			app.game.station_navigation("next")
		if not app.game.request_departure() or not app.game.enter_first_flight(0,4096,1789100000):
			check(false,app.game.status.text);finish();return
		await measure("flight")
	finish()

func measure(label: String) -> void:
	app.game.set_process(false);app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	app.game.session.rebase_time(0);now_us=0
	print("BENCHMARK_BEGIN ",label," paused=",app.game.session.is_paused())
	var steps: Array=[];var ui: Array=[];var frames: Array=[]
	for tick in (int(OS.get_environment("GOF2_BENCH_TICKS")) if OS.get_environment("GOF2_BENCH_TICKS")!="" else 150):
		# Window-manager focus events use wall time. Rebase the deterministic
		# sample so such an event cannot silently turn subsequent frames into 0ms.
		app.game.session.set_pause("focus",false,now_us)
		app.game.session.rebase_time(now_us)
		var started:=Time.get_ticks_usec();now_us+=16667
		if not app.game.session.step(now_us):check(false,app.game.session.error);return
		var simulated:=Time.get_ticks_usec()
		app.game.present_session()
		if app.game._transition_failed:check(false,app.game.status.text);return
		var presented:=Time.get_ticks_usec()
		await process_frame
		if tick>=30:
			steps.append((simulated-started)/1000.0);ui.append((presented-simulated)/1000.0)
			frames.append((Time.get_ticks_usec()-started)/1000.0)
	print("BENCHMARK ",JSON.stringify({"scene":label,"simulation_ms":stats(steps),"ui_ms":stats(ui),"frame_ms":stats(frames),"driver":RenderingServer.get_current_rendering_driver_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(app.game.viewport.size)}))
	if args.size()>3 and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(args[3]);RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(args[3].path_join(label+".png"))==OK,"Could not capture benchmark")
	check(app.game.session.status=="running","Benchmark crossed an unsupported boundary")

func stats(samples: Array) -> Dictionary:
	samples.sort()
	return {"median":samples[samples.size()/2],"p95":samples[int(samples.size()*0.95)]}

func finish() -> void:
	app.free();await process_frame
	print("Desktop performance: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
