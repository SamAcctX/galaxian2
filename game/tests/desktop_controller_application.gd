extends "res://tests/first_flight_session.gd"
## Earned first-station save: menu, confirmation, stick, mining and fresh Resume.
const Frontend=preload("res://src/presentation/player_frontend.gd")
const Preferences=preload("res://src/content/player_preferences.gd")
var _frontend: Control
var _profile:=""

class PreparedFrontend extends "res://src/presentation/player_frontend.gd":
	# This career already has its imported packs. Reuse them for Resume without
	# running an unrelated background extraction check.
	func _refresh_import() -> void:pass

func verify(args: PackedStringArray) -> void:
	_profile=OS.get_environment("GOF2_MENU_TEST_DIRECTORY")
	var source_save:=OS.get_environment("GOF2_SOURCE_SAVE")
	if _profile.is_empty() or source_save.is_empty():check(false,"Supply an earned opening save and private profile");return
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1920,1080)
	_frontend=PreparedFrontend.new();root.add_child(_frontend);_frontend.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frontend.boot(PackedStringArray(),_profile)
	var selection:=Preferences.defaults();selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2]
	selection.import_record=OS.get_environment("GOF2_MENU_IMPORT_RECEIPT")
	if selection.import_record.is_empty():check(false,"Supply the matching existing import receipt for fresh Resume");return
	if not _frontend.select_content(selection):check(false,_frontend.error);return
	lib=_frontend.library;bindings=_frontend.bindings;visuals=_frontend.visuals
	await send_pad(JOY_BUTTON_A)
	_frontend.menu._buttons.options.grab_focus();await send_pad(JOY_BUTTON_A)
	check(_frontend.phase=="options","Controller did not open Options from the menu")
	await send_pad(JOY_BUTTON_B);check(_frontend.phase=="menu","Controller did not return from Options")
	var path:=SaveFile.path_for(_profile.path_join("saves"),bindings)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(DirAccess.copy_absolute(source_save,path)==OK,"Could not stage the earned first-station save")
	_frontend.menu.present(false,true);_frontend.menu._buttons.load.grab_focus();await send_pad(JOY_BUTTON_A)
	check(_frontend.phase=="game" and _frontend.has_session(),"Controller did not load the saved career")
	if failures:return
	host=_frontend.game;host.set_process(false);await restore_test_focus();host.session.rebase_time(0)
	for line in 32:
		if not host.session.snapshot().dialogue.visible:break
		await send_pad(JOY_BUTTON_A)
	var before: Dictionary=host.session.snapshot()
	check(before.campaign_cursor==2,"Use the earned save before the first Var Hastra mining trip")
	await send_key(KEY_ENTER)
	check(host._launch_dialog.visible and host._launch_dialog._yes.has_focus(),"Departure question did not own keyboard focus")
	if args.size()==4:await capture(args[3],"controller-departure-question")
	await send_key(KEY_LEFT);await send_key(KEY_ENTER)
	check(not host._launch_dialog.visible and host.session is Station,"Keyboard No launched the ship")
	await send_pad(JOY_BUTTON_A);await send_pad(JOY_BUTTON_B)
	check(not host._launch_dialog.visible and host.session is Station,"Controller B failed to cancel departure")
	await send_pad(JOY_BUTTON_A);await send_key(KEY_ESCAPE)
	check(_frontend.phase=="game" and not host._launch_dialog.visible,"Departure Escape opened the menu instead of cancelling")
	var cancelled: Dictionary=host.session.snapshot()
	for field in ["campaign_cursor","cargo","loadout","mission","reward_credits"]:
		check(cancelled.get(field)==before.get(field),"Cancelled departure changed "+field)
	await send_pad(JOY_BUTTON_A);await send_pad(JOY_BUTTON_A)
	check(host.session is Trip,"Controller A failed to confirm departure")
	if failures:return
	host.session.rebase_time(0);now_us=0
	for tick in 160:
		if host.session.snapshot().phase=="flight" and host.session.can_control():break
		if host.session.snapshot().dialogue.visible:await send_pad(JOY_BUTTON_A)
		if not step():return
	check(host.session.can_control(),"Departure and Gunant briefing never released flight")
	for cadence in [[16667],[6944,6945],[4000,17000,31000,9000]]:
		for tick in 8:
			for sample in 16:
				var event:=InputEventJoypadMotion.new();event.device=5;event.axis=JOY_AXIS_LEFT_X
				event.axis_value=0.5 if tick<4 else (0.04 if sample%2 else -0.03)
				root.push_input(event,true)
			var input: Dictionary=host._controls.snapshot();now_us+=int(cadence[tick%cadence.size()])
			check(not input.mouse_response,"A captured pointer selected mouse response for the stick")
			if tick>=4:check(input.command==Vector2.ZERO,"Stick noise moved the neutral aim")
			if not host.session.step(now_us,input.command,false,input.mouse_response):check(false,host.session.error);return
			host.present_session()
			check(not host.session.snapshot().fast_forward.camera_response.relative_capture,"The flight camera used mouse response for stick steering")
	if args.size()==4:await capture(args[3],"controller-mining-flight")
	host.clear_input()
	if not await mine_trip(args):return
	check(host.enter_station(now_us,42),host.status.text)
	if failures:return
	host.session.rebase_time(now_us)
	for tick in 10:if not step():return
	for line in 8:
		if host.session.snapshot().phase in host.STATION_DEPARTURE_PHASES:break
		await send_pad(JOY_BUTTON_A)
	var earned: Dictionary=host.session.snapshot()
	check(earned.campaign_cursor==4 and earned.cargo.used==0,"Mining return did not hand in cargo and advance the career")
	check(earned.reward_credits==0 and earned.player_cache.values.hull>0,"Mining return retained a reward popup or dead ship")
	var cat:=Catalogues.new();check(cat.open(lib),cat.error)
	var saved: Dictionary=SaveFile.new().load_document(host.station_save_path(),bindings,cat,lib)
	check(not saved.is_empty() and saved.station.campaign_cursor==4,"The mining return did not autosave its next cursor")
	if args.size()==4:await capture(args[3],"controller-returned-station")
	# The companion Resume test starts a fresh process with this same profile.
	_frontend.free();host=null

func send_pad(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.device=5;event.button_index=code;event.pressed=pressed
		root.push_input(event,true);await process_frame
	if is_instance_valid(host):host.session.rebase_time(now_us)

func send_key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		root.push_input(event,true);await process_frame
	if is_instance_valid(host):host.session.rebase_time(now_us)
