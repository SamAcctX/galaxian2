extends "res://tests/mission_presentation.gd"
## Source-art rendering component; the earned station journey is a separate test.
const Credits=preload("res://src/presentation/mission_credits_panel.gd")
const PrivatePath=preload("res://tests/fixtures/free_play_station_scenario.gd")
var panel: Control
var requests:=0
var captures:=""

func _initialize() -> void:call_deferred("run")

func run() -> void:
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args()
	captures=args[3] if args.size()==4 else OS.get_environment("GOF2_CAPTURE_DIR")
	if args.size()==4:args.resize(3)
	if captures.is_empty() or not PrivatePath.private_path(captures.path_join("credits.png")):
		check(false,"Credits verification requires private captures");finish();return
	DirAccess.make_dir_recursive_absolute(captures)
	if not prepare_content(args):finish();return
	var visuals=load("res://src/content/visual_library.gd").new()
	if not visuals.open(args[2],library.manifest):check(false,visuals.error);finish();return
	var sequence:=prepared()
	panel=Credits.new();root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.skip_requested.connect(func():requests+=1)
	if not panel.configure(library,bindings,visuals,sequence,Epilogue.presentation(),10,42) or not panel.activate():
		check(false,panel.error);finish();return
	await process_frame
	check(panel.background.planets!=null and panel.background.selection.station_id==10,"Credits did not prepare the current station and its original planets")
	var shaded:=0;var emissive:=0
	for branch in [panel.background.station,panel.background.scenery]:
		for child in branch.find_children("*","",true,false):
			if child.get_script()!=preload("res://src/presentation/imported_model.gd"):continue
			for material in child.materials:
				check(material.shader!=preload("res://src/presentation/imported_material.gdshader"),"The ending retained a generic PBR exterior")
				if material.shader==preload("res://src/presentation/surface_response.gdshader"):
					shaded+=1
					check(material.get_shader_parameter("reflection_texture")==panel.background.reflection.texture,"The ending uses another location's reflection")
				else:emissive+=1
	check(shaded>0 and emissive>0,"Exterior shading removed the independent station light layers")
	var key:=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
	check(requests==0,"Early keyboard input bypassed the radio gate")
	var paused: Dictionary=sequence.snapshot()
	panel.set_paused(true)
	check(panel.music.stream_paused and panel.speech.snapshot().paused and sequence.snapshot()==paused,"Pausing the view advanced the presentation or left sound running")
	panel.set_paused(false)
	var captured:={};var sampled:=0;var next_yield:=1000
	while sequence.snapshot().elapsed_ms<148000:
		if not sequence.advance(100) or not panel.present(sequence):check(false,sequence.error+panel.error);break
		var state: Dictionary=sequence.snapshot()
		var moment:=""
		if state.elapsed_ms==12000:moment="ending-exterior"
		elif state.radio.visible and not captured.has("ending-radio"):moment="ending-radio"
		elif state.credits_visible and panel._logo.position.y<=300 and panel._logo.position.y>270 and not captured.has("ending-logo"):moment="ending-logo"
		elif state.elapsed_ms==110000:moment="ending-credits"
		if not moment.is_empty():await capture(moment);captured[moment]=true
		if state.can_skip and sampled==0:
			sampled=1
			Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
			check(requests==1,"The allowed keyboard skip was not delivered")
			var point:=Vector2(640,600)
			for down in [true,false]:
				var mouse:=InputEventMouseButton.new();mouse.position=point;mouse.global_position=point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=down
				Input.parse_input_event(mouse);Input.flush_buffered_events()
			await process_frame
			check(requests==2,"The allowed mouse skip was not delivered")
		if state.elapsed_ms>=next_yield:await process_frame;next_yield=state.elapsed_ms+1000
	check(captured.size()==4,"Credits verification missed a key visual moment")
	var history: Array=panel.speech.snapshot().history
	check(history.map(func(row):return row.source_id)==[539,540,541,542],"Credits speech was missing, reordered or replayed by repeated presentation")
	check(not sequence.snapshot().complete and sequence.advance(1) and sequence.snapshot().completion=="watched","The complete rendered ending did not reach its continuation boundary")
	panel.free();finish()

func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(captures.path_join(name+".png"))==OK,"Could not capture "+name)
