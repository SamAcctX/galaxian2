extends "res://tests/player_frontend.gd"
## Fresh process, same imported installation and the earned controller autosave.
class PreparedFrontend extends "res://src/presentation/player_frontend.gd":
	func _refresh_import() -> void:pass

func run() -> void:
	args=OS.get_cmdline_user_args();directory=OS.get_environment("GOF2_MENU_TEST_DIRECTORY")
	captures=OS.get_environment("GOF2_CAPTURE_DIR")
	if args.size()!=3 or directory.is_empty():check(false,"Supply imported packs and the career profile");quit(1);return
	app=PreparedFrontend.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not app.boot(PackedStringArray(),directory):check(false,app.error);quit(1);return
	check(app.bindings.binding_id==args[1].get_file() and app.bindings.base_content_id==args[0].get_file(),"Fresh entry selected a different content identity")
	var catalogue:=Catalogue.new();check(catalogue.open(app.library),catalogue.error)
	var path:=SaveFile.path_for(directory.path_join("saves"),app.bindings)
	var bytes:=FileAccess.get_file_as_bytes(path)
	var saved: Dictionary=SaveFile.new().load_document(path,app.bindings,catalogue,app.library)
	check(not saved.is_empty() and saved.station.campaign_cursor==4,"Resume requires the earned mining autosave")
	if failures:app.free();quit(1);return
	await pad()
	check(not app.menu.snapshot().title_active,"Controller did not dismiss the startup title")
	app.menu._buttons.resume.grab_focus();await pad()
	check(app.phase=="game" and app.has_session(),"Fresh controller Resume failed: "+app.error)
	if app.has_session():
		app.game.set_process(false);app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		var current: Dictionary=Archive.new().capture(app.game.session.station_owner(),app.bindings,app.game.session.location_owner())
		check(current==saved,"Fresh Resume changed the earned cursor, cargo, rewards or career")
		check(FileAccess.get_file_as_bytes(path)==bytes,"Resume rewrote the earned station autosave")
		await capture("controller-fresh-resume")
	app.free();await process_frame
	print("Fresh controller Resume: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func pad() -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.device=5;event.button_index=JOY_BUTTON_A;event.pressed=pressed
		root.push_input(event,true);await process_frame
