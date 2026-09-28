extends "res://tests/bakka_arrival_application.gd"
## Native frontend loads the unchanged earned save. Deliberately undefended
## flight takes actual enemy fire; no positioned projectile, damage, death or
## campaign flag is supplied. The real loss/menu/Resume path must retain36.
const RetryFrontend=preload("res://src/presentation/player_frontend.gd")
const RetryPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
# Surviving pirate groups can be over 160000 source units apart. Keep their
# real travel and attacks, using the same bounded allowance as the live contest.
const MAX_UNDEFENDED_FRAMES:=12000
var frontend: Control

func run_free_checkpoint() -> void:
	var args:=OS.get_cmdline_user_args()
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(args.size() in [3,4] and not directory.is_empty() and FreePlayCheckpoint.private_path(directory+"/profile/player.json"),"Use explicit prepared content and an isolated retry profile")
	if failures:quit(1);return
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	if args.size()==4:_free_capture_dir=args[3]
	frontend=RetryFrontend.new();root.add_child(frontend);frontend.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await prepare_and_retry(args,directory.path_join("profile"))
	frontend.free();await process_frame
	print("Bakka earned loss/menu/retry: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func prepare_and_retry(args: PackedStringArray,directory: String) -> void:
	check(not FileAccess.file_exists(directory.path_join("player.json")),"Never overwrite a retained retry profile")
	if failures:return
	check(not frontend.boot(PackedStringArray(),directory),"The isolated profile invented a remembered installation")
	var selection:=RetryFrontend.Preferences.defaults()
	selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2];selection.language="gb"
	if not frontend.select_content(selection):check(false,frontend.error);return
	source=frontend.library;definitions=frontend.bindings;visual=frontend.visuals
	catalogue=Catalogues.new()
	if not catalogue.open(source):check(false,catalogue.error);return
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	check(FileAccess.get_sha256(saved)==SOURCE_SHA,"Retry must use the unchanged earned202 Ga'kkrr save")
	var path:=NativeSave.path_for(frontend._save_directory,definitions)
	check(not path.is_empty() and not FileAccess.file_exists(path),"Use a fresh native save destination for retry")
	if failures:return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if DirAccess.copy_absolute(saved,path)!=OK:check(false,"Cannot stage the unchanged earned save for the native menu");return
	var file:=NativeSave.new()
	var original: Dictionary=file.load_document(path,definitions,catalogue,source)
	check(original.get("version")==8 and original.station.campaign_cursor==36,"The native menu source is not the actual v8/cursor36 checkpoint")
	frontend.show_menu()
	var event:=InputEventKey.new();event.physical_keycode=KEY_ENTER;event.pressed=true
	frontend.menu._unhandled_input(event)
	check(frontend.menu._buttons.resume.is_visible_in_tree() and not frontend.menu._buttons.resume.disabled,"Title dismissal omitted the saved Resume control")
	if failures:return
	frontend.menu._buttons.resume.pressed.emit()
	if not frontend.has_session():check(false,frontend.error);return
	app=frontend.game;app.set_process(false);resume_application_focus()
	var original_station: Dictionary=app.session.station_owner().snapshot()
	check(frontend.phase=="game" and original_station.campaign_cursor==36 and original_station.loadout.station_id==29,"Resume did not enter the earned Ga'kkrr station")
	if failures:return
	await super.verify_free_application()
	if failures:return
	check(app.station_save_path()==path,"Staged arrival detached the native frontend checkpoint path")
	var checkpoint_hash:=FileAccess.get_sha256(path)
	var initial: Dictionary=app.session.snapshot()
	var pilot:=RetryPilot.new()
	var loss:=""
	var exposed:=false
	var exposure_target:=-1
	var loss_tick:=-1
	for tick in MAX_UNDEFENDED_FRAMES:
		var state: Dictionary=app.session.snapshot()
		if state.phase=="failure_instructions":loss="contest defeat";loss_tick=tick;break
		if app.session.flight_owner().death_active():loss="player destruction";loss_tick=tick;break
		var input:=pilot.controls(state,tick)
		# Retarget after a real pirate death, and reacquire a distant flyby.
		# Otherwise the one-shot exposure flag can park outside every survivor.
		if exposed and (input.target!=exposure_target or input.distance>35000.0):exposed=false
		if not exposed and input.target>=0 and input.distance<6000.0:
			exposed=true;exposure_target=input.target
			print("Saved202 stopped defending at real contact range ",int(input.distance)," after ",tick," input frames")
		# Pursuing a circling pirate can evade its fire indefinitely. Stop with
		# ordinary throttle after a close approach; allow its native flyby to
		# 35000 before following again. No repositioned ships or supplied hits.
		var approach: bool=input.target>=0 and not exposed
		if not undefended_step(input.commands if approach else Vector2.ZERO,1.0 if approach else 0.0):return
		if tick%200==0:print("Saved202 undefended flight ",tick," target ",input.target," distance ",int(input.distance)," exposed ",exposed," player ",state.player.vitals)
		if tick%20==0:await process_frame
	check(not loss.is_empty(),"Normal undefended flight did not reach a genuine loss within %d input frames"%MAX_UNDEFENDED_FRAMES)
	if failures:return
	var lost: Dictionary=app.session.snapshot()
	check(lost.campaign_cursor==36 and lost.progress.player_kills==initial.progress.player_kills and lost.contracts.credits==initial.contracts.credits,"The no-fire loss awarded kills, credits or campaign progress")
	check(lost.equipment==initial.equipment and lost.cargo==initial.cargo,"Undefended flight changed the saved inventory")
	print("Saved202 real loss: ",loss," at ",loss_tick," input frames; player ",lost.player.vitals)
	if loss=="player destruction":
		check(lost.player.vitals.hull<=0 and initial.player.vitals.hull>0,"Native destruction lacks actual depletion of the saved ship")
		for tick in 600:
			if app.session.snapshot().player_destruction.phase=="game_over":break
			if not undefended_step():return
			if tick%20==0:await process_frame
		check(app.session.snapshot().player_destruction.phase=="game_over","The real destruction did not complete its original fade")
	else:
		check(lost.dialogue.visible and lost.dialogue.voice_event_id==-1,"Actual contest defeat lost its silent failure instruction")
	if failures:return
	await capture_free_application("saved202-bakka-genuine-loss")
	resume_application_focus()
	event=InputEventKey.new();event.physical_keycode=KEY_ENTER;event.pressed=true
	app._unhandled_input(event)
	check(app.session.status=="game_over_transition_required","Actual loss confirmation did not request the native menu transition")
	if failures or not app.enter_game_over():check(false,app.status.text);return
	check(frontend.phase=="menu" and not frontend.has_session() and frontend.menu._buttons.resume.is_visible_in_tree() and not frontend.menu._buttons.resume.disabled,"Genuine loss failed to return to a usable native Resume menu")
	check(FileAccess.get_sha256(path)==checkpoint_hash and file.load_document(path,definitions,catalogue,source)==original,"Loss overwrote the viable earned checkpoint")
	await capture_free_application("saved202-bakka-loss-menu")
	if failures:return
	frontend.menu._buttons.resume.pressed.emit()
	if not frontend.has_session():check(false,frontend.error);return
	app=frontend.game;app.set_process(false);resume_application_focus()
	var restored: Dictionary=app.session.station_owner().snapshot()
	check(frontend.phase=="game" and restored==original_station and not frontend.music.player.playing,"Menu Resume changed the exact earned career or kept menu music running")
	check(FileAccess.get_sha256(saved)==SOURCE_SHA and FileAccess.get_sha256(path)==checkpoint_hash,"Retry rewrote a source or checkpoint")
	await capture_free_application("saved202-bakka-retry-station")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var departing: Dictionary=app.session.snapshot()
	check(departing.campaign_cursor==36 and departing.location.station_id==29 and departing.player.vitals.hull>0 and departing.contracts.credits==22100 and departing.contracts.passengers==3,"Saved retry did not restore viable ordinary flight")
	await capture_free_application("saved202-bakka-retry-departure")
	if not failures:print("Saved202 genuine ",loss," -> native loss confirmation/menu -> unchanged Ga'kkrr36 Resume -> living departure; no controlled contacts or earned38 claim")

func arrival_save_directory() -> String:
	return frontend._save_directory

func undefended_step(commands:=Vector2.ZERO,throttle:=0.0) -> bool:
	resume_application_focus()
	if app.session.can_control():
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-throttle)<.01:break
			if not app.session.action("throttle_up" if current<throttle else "throttle_down"):check(false,app.session.error);return false
	now_us+=100000
	if not app.session.step(now_us,commands,false,false,0.0):check(false,app.session.error);return false
	app.present_session()
	return true

func capture_free_application(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	if _free_capture_dir.is_empty():_free_capture_dir=OS.get_environment("GOF2_CAPTURE_DIR")
	check(not _free_capture_dir.is_empty() and FreePlayCheckpoint.private_path(_free_capture_dir+"/image.png"),"Keep retry captures in the runner's private output")
	if failures:return
	DirAccess.make_dir_recursive_absolute(_free_capture_dir)
	root.grab_focus()
	for attempt in 20:
		if root.has_focus():break
		await create_timer(.05).timeout
	frontend.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	if frontend.has_session():app.present_session()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(_free_capture_dir.path_join(label+".png"))==OK,"Cannot capture "+label)
	frontend.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
