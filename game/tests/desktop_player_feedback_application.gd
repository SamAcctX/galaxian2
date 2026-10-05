extends "res://tests/desktop_controller_application.gd"
const Style=preload("res://src/presentation/flight_hud_style.gd")
const MiningUI=preload("res://src/presentation/mining_panel.gd")

func configure_feedback_options(args: PackedStringArray) -> void:
	_frontend.show_options()
	for pair in [["flight_hud_scale",4],["flight_hud_filter","nearest"],["antialiasing","msaa4"],["frame_rate",0]]:
		check(_frontend.change_preference(pair[0],pair[1]),_frontend.error)
	check(_frontend.preferences.values.ui_scale==0,"Flight HUD size changed the menu size choice")
	root.size=Vector2i(1920,1080)
	for tick in 4:await process_frame
	if args.size()==4:
		DirAccess.make_dir_recursive_absolute(args[3]);await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(args[3].path_join("feedback-options.png"))==OK,"Could not capture the feedback options")
	_frontend.show_menu()

func verify_reported_feedback(args: PackedStringArray) -> void:
	check(host.viewport.msaa_3d==Viewport.MSAA_4X,"Flight ignored the selected 4x MSAA")
	check(Style.multiplier==4,"Flight lost its separate HUD scale")
	for cadence in [16667,6944,31000]:
		host.clear_input()
		var moved:=Vector2(120,-48)
		var event:=InputEventMouseMotion.new();event.screen_relative=moved;event.relative=moved
		root.push_input(event,true)
		host._controls.advance_mouse(float(cadence)/1000000.0,Vector2(host.viewport.size))
		var input: Dictionary=host._controls.snapshot();now_us+=cadence
		check(input.mouse_response,"Flight lost immediate mouse control")
		check(host.session.step(now_us,input.command,false,input.mouse_response),host.session.error);host.present_session()
		var state: Dictionary=host.session.snapshot();var logical_size: Vector2=host.viewport.get_visible_rect().size
		var point: Vector3=state.player_aim.point
		var expected:=logical_size*0.5+moved*logical_size/Vector2(host.viewport.size)
		check(Vector2(point.x,point.y).distance_to(expected)<1.0,"The live flight applied handling or camera delay to the pointer")
		var sprite: TextureRect=host.session.scene.reticle.sprite
		check((sprite.position+sprite.size*0.5).distance_to(expected)<1.0,"Displayed crosshair lagged behind mouse input")
		check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Flight crosshair did not use crisp filtering")
		if args.size()==4 and cadence==16667:await capture(args[3],"feedback-mouse-flight")
	host.clear_input()
	var mouse:=InputEventMouseMotion.new();mouse.screen_relative=Vector2(host.viewport.size)*2;mouse.relative=mouse.screen_relative
	root.push_input(mouse,true);host._controls.advance_mouse(1.0/60.0,Vector2(host.viewport.size))
	var mouse_command: Vector2=host._controls.snapshot().command
	now_us+=16667;host.session.step(now_us,mouse_command,false,true);host.present_session()
	var mouse_edge: Vector3=host.session.snapshot().player_aim.point
	for pair in [[JOY_AXIS_LEFT_X,1.0],[JOY_AXIS_LEFT_Y,1.0]]:
		var stick:=InputEventJoypadMotion.new();stick.device=5;stick.axis=pair[0];stick.axis_value=pair[1];root.push_input(stick,true)
	now_us+=16667;host.session.step(now_us,host._controls.snapshot().command,false,false);host.present_session()
	check(host.session.snapshot().player_aim.point.x==mouse_edge.x and host.session.snapshot().player_aim.point.y==mouse_edge.y,"The live controller could not reach the mouse edge")
	if args.size()==4:await capture(args[3],"feedback-controller-edge")
	host.clear_input()
	# One pause/resume boundary must discard held steering and retain choices.
	await send_key(KEY_ESCAPE);check(host.session.is_paused(),"Pause did not block flight")
	check(host._controls.snapshot().command==Vector2.ZERO,"Pause retained a held turn")
	await send_key(KEY_ESCAPE);check(not host.session.is_paused(),"Resume did not release flight")

func mine_trip(args: PackedStringArray) -> bool:
	var result: bool=await super.mine_trip(args)
	check(host.viewport.msaa_3d==Viewport.MSAA_4X and Style.multiplier==4,"Mining lost the selected scene/HUD settings")
	return result

func capture(directory: String,name: String) -> void:
	if is_instance_valid(host) and host.session is Trip and not host.session.snapshot().mining_session.drill.is_empty():
		var panel: Control=host.session.scene.mining_panel
		check(panel._spinner.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Mining retained blurry filtering")
		check(panel._spinner.size.x>=panel._spinner.texture.get_width(),"The mining drill stayed at compact desktop size")
		check(panel.get_global_rect().encloses(panel._quantity.get_global_rect()),"Enlarged mining readout escaped the screen")
	await super.capture(directory,name)
