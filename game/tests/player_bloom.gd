extends "res://tests/campaign_ending_application.gd"
## Live player preference, scene replacement and an earned ending with glare.
const Frontend=preload("res://src/presentation/player_frontend.gd")
const Preferences=preload("res://src/content/player_preferences.gd")

func _initialize() -> void:call_deferred("run_bloom")

func run_bloom() -> void:
	await verify_options()
	if failures:done();return
	await run_application()

func key(code: int) -> void:
	# Native GUI actions use the logical key; flight also consumes physical keys.
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()
	await process_frame

func verify_options() -> void:
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	var settings_path:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("options")
	if not PrivatePath.private_path(settings_path.path_join("player.json")):
		check(false,"Bloom options need private preferences");return
	var frontend:=Frontend.new();root.add_child(frontend);frontend.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frontend.boot(PackedStringArray(),settings_path)
	var args:=OS.get_cmdline_user_args();var selection:=Preferences.defaults()
	selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2]
	if not frontend.select_content(selection):check(false,frontend.error);frontend.free();return
	frontend.menu._background.set_process(false)
	frontend.menu._dismiss_title();frontend.show_options()
	var menu_view: Control=frontend.menu._background_rect
	check(menu_view._bloom!=null,"The default player preference did not reach the menu world")
	var toggle: CheckButton=frontend._settings_controls.bloom
	toggle.grab_focus();frontend._body.get_parent().ensure_control_visible(toggle)
	await process_frame;await process_frame
	await key(KEY_SPACE)
	check(not frontend.preferences.values.bloom and menu_view._bloom==null,"Keyboard Bloom off did not remove the menu effect")
	await click(toggle.get_global_rect().get_center())
	check(frontend.preferences.values.bloom and menu_view._bloom!=null,"Mouse Bloom on did not restore the menu effect")
	check(frontend.change_preference("bloom",false),frontend.error)
	var saved:=Preferences.new()
	check(saved.read_file(settings_path.path_join("player.json")) and not saved.values.bloom,"Restart would forget Bloom off")
	frontend.show_menu()
	if not frontend._enter_game("new_game"):check(false,frontend.error);frontend.free();return
	frontend.game.set_process(false)
	var flight: Control=frontend.game.viewport.get_parent()
	check(flight._bloom==null,"A new flight ignored the saved off preference")
	check(frontend.change_preference("bloom",true),frontend.error)
	check(flight._bloom!=null and menu_view._bloom!=null,"Changing Bloom did not reach existing flight and menu views")
	check(menu_view._bloom._targets.all(func(target):return target.render_target_update_mode==SubViewport.UPDATE_DISABLED),"Hidden menu filters kept rendering")
	var source: SubViewport=flight.viewport
	frontend.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frame;await RenderingServer.frame_post_draw
	check(flight.texture.get_image().get_size()==source.size,"Bloom replaced the flight's source image")
	frontend.show_menu()
	check(flight._bloom._targets.all(func(target):return target.render_target_update_mode==SubViewport.UPDATE_DISABLED),"Paused hidden flight filters kept rendering")
	check(frontend.change_preference("bloom",false) and flight._bloom==null and flight.viewport==source,"Disabling Bloom replaced flight or kept targets alive")
	frontend.free();await process_frame
	# A fresh presentation host restores the independently saved preference.
	frontend=Frontend.new();root.add_child(frontend)
	frontend.boot(PackedStringArray(),settings_path)
	check(not frontend.preferences.values.bloom,"Fresh frontend forgot Bloom off")
	frontend.free();await process_frame

func capture(name: String) -> void:
	if name=="ending-invitation-keith":app.apply_preferences(Preferences.defaults())
	if name=="ending-brent":await compare_ending()
	await super.capture(name)

func compare_ending() -> void:
	var panel: Control=app.session._presentation_view
	var view: Control=panel._image
	check(view._bloom!=null and view.viewport==panel.background,"New ending view did not inherit Bloom over its own exterior")
	check(not app.viewport.get_parent().visible and app.viewport.get_parent()._bloom._targets.all(func(target):return target.render_target_update_mode==SubViewport.UPDATE_DISABLED),"Covered hangar kept rendering its Bloom graph")
	var before: Dictionary=app.session.snapshot()
	await process_frame;await RenderingServer.frame_post_draw
	var mode: int=panel.background.render_target_update_mode
	panel.background.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var source: Image=panel.background.get_texture().get_image()
	var settings:=Preferences.defaults();settings.bloom=false;app.apply_preferences(settings)
	await process_frame;await RenderingServer.frame_post_draw
	var off: Image=root.get_texture().get_image()
	check(off.save_png(captures.path_join("ending-bloom-off.png"))==OK,"Could not capture Bloom off")
	settings.bloom=true;app.apply_preferences(settings)
	await process_frame;await RenderingServer.frame_post_draw
	var on: Image=root.get_texture().get_image()
	check(on.save_png(captures.path_join("ending-bloom-on.png"))==OK,"Could not capture Bloom on")
	check(source.get_data()==panel.background.get_texture().get_image().get_data() and before==app.session.snapshot(),"Bloom changed the held source picture or career")
	var brightened:=0;var darkened:=0
	for y in range(128,720,3):
		for x in range(0,1280,3):
			var delta:=on.get_pixel(x,y)-off.get_pixel(x,y)
			if maxf(delta.r,maxf(delta.g,delta.b))>3.0/255.0:brightened+=1
			if minf(delta.r,minf(delta.g,delta.b))< -2.0/255.0:darkened+=1
	check(brightened>100 and darkened==0,"Ending glare is missing or darkens the world: %d brighter, %d darker"%[brightened,darkened])
	# The actual radio remains a sharp sibling drawn after the world image.
	check(panel.radio.get_parent()==panel and panel.radio.get_index()>view.get_index() and panel.radio.material==null,"Bloom moved radio into the filtered world")
	settings.bloom=false;app.apply_preferences(settings)
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().get_data()==off.get_data(),"Bloom off did not restore the held image exactly")
	settings.bloom=true;app.apply_preferences(settings)
	panel.background.render_target_update_mode=mode
	print("Ending Bloom comparison: %d sampled world pixels brightened; %d darkened"%[brightened,darkened])
