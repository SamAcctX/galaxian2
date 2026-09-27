extends "res://tests/mission_presentation.gd"
## Earned-save application path. All acknowledgements and skipping use native
## input; isolated missing-resource/write blockers exercise transaction retry.
const Host=preload("res://src/presentation/opening_preview.gd")
const PrivatePath=preload("res://tests/fixtures/free_play_station_scenario.gd")
var app: Control
var cat: RefCounted
var now_us:=1000000
var captures:=""
var directory:=""
var slot:=""
var original_bytes:=PackedByteArray()
var original:={}
var frame_number:=0

func _initialize() -> void:call_deferred("run_application")

func run_application() -> void:
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	if not prepare_content(OS.get_cmdline_user_args()):finish();return
	captures=OS.get_environment("GOF2_CAPTURE_DIR");directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if not PrivatePath.private_path(captures.path_join("ending.png")) or not PrivatePath.private_path(directory.path_join("station.gof2save")):
		check(false,"The ending playtest requires isolated captures and saves");finish();return
	DirAccess.make_dir_recursive_absolute(captures)
	var visuals=load("res://src/content/visual_library.gd").new()
	cat=load("res://src/content/catalogues.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest) or not cat.open(library):check(false,visuals.error+cat.error);finish();return
	app=Host.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(library,bindings,visuals);app.set_player_mode(true);app.set_process(false);app.enable_saves(directory)
	slot=app.station_save_path();DirAccess.make_dir_recursive_absolute(slot.get_base_dir())
	var earned:=OS.get_environment("GOF2_ENDING_EARNED_SAVE")
	if DirAccess.copy_absolute(earned,slot)!=OK:check(false,"Could not copy the earned input to the isolated slot");done();return
	original_bytes=FileAccess.get_file_as_bytes(slot)
	app.show();await process_frame;focus();await key(KEY_F9)
	if app.session==null:check(false,app._save_notice.text);done();return
	app.session.rebase_time(now_us);original=app.session.station_owner().snapshot()
	check(original.campaign_cursor==43 and original.contracts.passengers==3,"Resume did not load the earned Thynome checkpoint")
	if not await until_dialogue():done();return
	await capture("ending-invitation-keith")
	await key(KEY_ENTER)
	check(app.session.snapshot().dialogue.voice_event_id==426,"The native Next key did not reach Carla's invitation")
	await capture("ending-invitation-carla")
	var before: Dictionary=app.session.snapshot()
	var actual_visuals: RefCounted=app.session._visuals
	app.session._visuals=load("res://src/content/visual_library.gd").new()
	await key(KEY_ENTER)
	check(not app.session.presentation_active() and app.session.snapshot()==before and FileAccess.get_file_as_bytes(slot)==original_bytes,"Failed credits preparation consumed the invitation or save")
	app.session._visuals=actual_visuals
	await key(KEY_ENTER)
	if not app.session.presentation_active():check(false,app.session.error);done();return
	check(app.session.snapshot().campaign_cursor==43 and FileAccess.get_file_as_bytes(slot)==original_bytes,"Starting the ending advanced the durable checkpoint")
	for early in [KEY_ESCAPE,KEY_F9,KEY_F5]:await key(early)
	check(app.session.presentation_active() and app.session.snapshot().presentation.elapsed_ms==0 and app.session.snapshot().campaign_cursor==43,"An early menu/save/load key escaped the ending")
	var paused: Dictionary=app.session.snapshot().presentation
	app.session.set_pause("focus",true,now_us);now_us+=5000000
	check(app.session.step(now_us) and app.session.snapshot().presentation==paused and app.session._presentation_view.music.stream_paused,"Focus pause advanced the ending or left its music running")
	app.session.set_pause("focus",false,now_us)
	var captured:={};var voices:=[];var blocked:=false;var skipped:=OS.get_environment("GOF2_ENDING_SKIP")=="1"
	var next_yield:=now_us+1000000
	while app.session.presentation_active() and not app._transition_failed:
		if not step():done();return
		var state: Dictionary=app.session.snapshot()
		if not state.has("presentation"):break
		var presentation: Dictionary=state.presentation
		var view: Control=app.session._presentation_view
		voices=view.speech.snapshot().history.map(func(row):return row.source_id)
		var moment:=""
		if presentation.elapsed_ms>=12000 and not captured.has("ending-exterior"):moment="ending-exterior"
		elif presentation.radio.visible and not captured.has("ending-brent"):moment="ending-brent"
		elif presentation.credits_visible and view._logo.position.y<=300 and view._logo.position.y>250 and not captured.has("ending-logo"):moment="ending-logo"
		elif presentation.elapsed_ms>=110000 and not captured.has("ending-credits"):moment="ending-credits"
		if not moment.is_empty():await capture(moment);captured[moment]=true
		if not blocked and (presentation.can_skip if skipped else presentation.elapsed_ms>=147000):
			blocked=true;block_save()
			if skipped:await click(Vector2(640,600))
		if now_us>=next_yield:await process_frame;focus();next_yield=now_us+1000000
	check(blocked and app._transition_failed and app.session.presentation_complete() and app.session.snapshot().campaign_cursor==43,"The completion write blocker did not retain a retryable ending")
	check(voices==[539,540,541,542],"The ending lost or repeated Brent's four original recordings")
	check(FileAccess.get_file_as_bytes(slot)==original_bytes and app.session.snapshot().contracts.credits==original.contracts.credits,"A failed completion save overwrote the earned checkpoint or paid early")
	app.enable_saves(directory);await key(KEY_ENTER)
	check(not app._transition_failed and not app.session.presentation_active() and app.session.snapshot().campaign_cursor==44,"Native retry did not commit the ending continuation")
	check(not app._save_notice.visible,"A successful retry retained the previous save error")
	var note: Dictionary=app._save_file.load_document(slot,bindings,cat,library)
	check(not note.is_empty() and note.station.campaign_cursor==44 and note.career.credits==original.contracts.credits,"The ending did not autosave the unpaid note")
	var note_bytes:=FileAccess.get_file_as_bytes(slot)
	if not await until_dialogue():done();return
	await capture("ending-carla-note")
	var note_voices:=[]
	for index in 4:
		var line: Dictionary=app.session.snapshot().dialogue;note_voices.append(line.voice_event_id)
		if index==3:block_save()
		await click(app.station_panel._next.get_global_rect().get_center())
	check(app.session.snapshot().campaign_cursor==44 and app.session.snapshot().dialogue.visible and app.session.snapshot().contracts.credits==original.contracts.credits and FileAccess.get_file_as_bytes(slot)==note_bytes,"A failed final payment save changed the live or durable career")
	app.enable_saves(directory);await click(app.station_panel._next.get_global_rect().get_center())
	var paid: Dictionary=app.session.snapshot()
	check(note_voices==[427,428,429,430] and paid.campaign_cursor==45 and paid.mission.kind==-1,"Native note navigation lost a line or the final empty mission")
	check(paid.contracts.credits==original.contracts.credits+40000 and paid.contracts.mission==original.contracts.mission and paid.contracts.passengers==3,"Final payment or retained passengers differ from the earned career")
	await key(KEY_ENTER)
	check(app.session.snapshot().contracts.credits==paid.contracts.credits,"Repeated input paid the ending twice")
	var saved: Dictionary=app._save_file.load_document(slot,bindings,cat,library)
	check(not saved.is_empty(),app._save_file.error)
	# The archive omits the runtime lounge snapshot from its career record.
	if not saved.is_empty():
		var expected: Dictionary=app.session.station_owner().contract_owner().snapshot();expected.erase("lounges")
		check(saved.career==expected,"Paid autosave lost the retained full career")
	for index in 10:
		if not step():break
	check(app.session._released_presentation==null,"The original music stop fade retained an audio owner")
	await capture("ending-paid-station")
	var report:=FileAccess.open(captures.path_join("journey.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"source_save":earned,"saved_file":slot,"cursor":paid.campaign_cursor,"credits":paid.contracts.credits,"passengers":paid.contracts.passengers,"skip":skipped,"checks":checks,"failures":failures},"  "));report.close()
	done()

func step() -> bool:
	focus();frame_number+=1
	var cadence:=OS.get_environment("GOF2_ENDING_CADENCE")
	var delta:=100000
	if cadence=="144":delta=int(frame_number*1000000/144)-int((frame_number-1)*1000000/144)
	elif cadence=="variable":delta=int([6944,16667,41667,8333,100000,11111][frame_number%6])
	now_us+=delta
	if not app.session.step(now_us):check(false,app.session.error);return false
	app.present_session();return true

func until_dialogue() -> bool:
	for index in 400:
		if app.session.snapshot().dialogue.visible:return true
		if not step():return false
		if index%20==0:await process_frame
	check(false,"The station result never became visible: "+app.session.error);return false

func focus() -> void:
	app._focused=true
	if app.session!=null:
		app.session.set_pause("focus",false,now_us);app.session.set_pause("hidden",false,now_us)

func key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame

func click(point: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame

func block_save() -> void:
	var blocker:=directory.path_join("not-a-directory")
	var file:=FileAccess.open(blocker,FileAccess.WRITE);file.store_string("isolated save-write blocker");file.close()
	app.enable_saves(blocker)

func capture(name: String) -> void:
	app.present_session();await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(captures.path_join(name+".png"))==OK,"Could not capture "+name)

func done() -> void:
	if app!=null:app.free()
	print("Earned ending application: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
