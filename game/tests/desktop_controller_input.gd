extends "res://tests/player_frontend.gd"
## Normal GUI dispatch plus a noisy controller stream with no flight snapshot.
const Controls=preload("res://src/input/flight_controls.gd")
const Question=preload("res://src/presentation/gate_confirmation_panel.gd")
const Host=preload("res://src/presentation/opening_preview.gd")

class InputProbe extends "res://src/presentation/first_flight_session.gd":
	var snapshot_reads:=0
	func snapshot() -> Dictionary:
		snapshot_reads+=1;return {"dialogue":{"visible":false}}
	func dialogue_visible() -> bool:return false
	func is_paused() -> bool:return false
	func can_control() -> bool:return true
	func can_skip_cinematic() -> bool:return false
	func can_stop_mining() -> bool:return false
	func fast_forward_available() -> bool:return false
	func secondary_menu_open() -> bool:return false
	func map_open() -> bool:return false
	func handle_game_over_event(_event: InputEvent) -> bool:return false

func run() -> void:
	verify_steering()
	await verify_input_stream()
	args=OS.get_cmdline_user_args();directory=OS.get_environment("GOF2_MENU_TEST_DIRECTORY")
	if args.size()!=3 or directory.is_empty():check(false,"Supply content and private profile");quit(1);return
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	app=Frontend.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.boot(PackedStringArray(),directory)
	var selection:=Preferences.defaults();selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2]
	if not app.select_content(selection):check(false,app.error);quit(1);return
	dismiss_title();await process_frame
	for device in [0,5]:
		app.menu._buttons.options.grab_focus();await pad(JOY_BUTTON_A,device)
		check(app.phase=="options","Controller A did not activate the focused menu item")
		await pad(JOY_BUTTON_B,device)
		check(app.phase=="menu","Controller B did not go back from Options")
	var question:=Question.new();root.add_child(question);question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var choices: Array[int]=[];question.choice_requested.connect(func(choice):choices.append(choice);question.clear())
	for method in ["keyboard_no","pad_no","pad_yes","keyboard_yes","back"]:
		check(question.present_question(app.library,app.bindings,app.visuals,app.library.strings[386],386),question.error)
		question.set_active(true);await process_frame
		check(question._yes.has_focus(),"A new question did not focus Yes")
		if method=="keyboard_no":await keypress(KEY_LEFT);await keypress(KEY_ENTER)
		elif method=="pad_no":await pad(JOY_BUTTON_DPAD_LEFT,5);await pad(JOY_BUTTON_A,5)
		elif method=="pad_yes":await pad(JOY_BUTTON_A,5)
		elif method=="keyboard_yes":await keypress(KEY_ENTER)
		else:
			var cancel:=InputEventJoypadButton.new();cancel.button_index=JOY_BUTTON_B;cancel.pressed=true
			question.handle_event(cancel)
		check(not question.visible,"Question input did not complete its selected choice")
	check(choices==[0,0,1,1,0],"Question accepted a different choice from the focused button")
	check(question.present_question(app.library,app.bindings,app.visuals,app.library.strings[386],386),question.error)
	question.set_active(false)
	var blocked:=InputEventJoypadButton.new();blocked.button_index=JOY_BUTTON_A;blocked.pressed=true
	question.handle_event(blocked);check(question.visible and choices.size()==5,"An inactive question accepted input")
	question.free();app.free();await process_frame
	print("Desktop controller input: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify_steering() -> void:
	var controls:=Controls.new();controls.set_mouse_active(true)
	var mouse:=InputEventMouseMotion.new();mouse.screen_relative=Vector2(80,40)
	controls.accept(mouse);controls.advance_mouse(1.0/60.0)
	check(controls.snapshot().mouse_response and controls.snapshot().command!=Vector2.ZERO,"Mouse did not retain its own response")
	var motion:=InputEventJoypadMotion.new();motion.device=5;motion.axis=JOY_AXIS_LEFT_X;motion.axis_value=0.6
	controls.accept(motion)
	check(not controls.snapshot().mouse_response and controls.snapshot().command.x==0 and controls.snapshot().command.y<0,"Stick used mouse response or a retained mouse offset")
	for noise in [0.0,0.03,-0.06,0.12,-0.17,0.0]:
		motion.axis_value=noise;controls.accept(motion)
		check(controls.snapshot().command==Vector2.ZERO and not controls.snapshot().mouse_response,"Neutral stick noise restored an old turn")
	mouse.screen_relative=Vector2(24,0);controls.accept(mouse);controls.advance_mouse(1.0/60.0)
	check(controls.snapshot().mouse_response and controls.snapshot().command.y<0,"Mouse could not take steering back")
	controls.clear();controls.set_mouse_active(false);motion.axis_value=0.6;controls.accept(motion)
	check(controls.snapshot().command.y<0 and not controls.snapshot().mouse_response,"Uncaptured controller steering stopped working")

func verify_input_stream() -> void:
	var host:=Host.new();root.add_child(host);host.set_process(false);host._focused=true
	var probe:=InputProbe.new();probe.status="running";host.viewport.add_child(probe);host.session=probe
	for tick in 128:
		var event:=InputEventJoypadMotion.new();event.device=5;event.axis=JOY_AXIS_LEFT_X;event.axis_value=0.3+float(tick%2)*0.01
		host._unhandled_input(event)
	check(probe.snapshot_reads==0,"Stick events copied the whole flight to test dialogue visibility")
	check(host._controls.snapshot().command.y<0,"The controller stream never reached steering")
	host.free();await process_frame

func pad(button: int,device: int=0) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.device=device;event.button_index=button;event.pressed=pressed
		root.push_input(event,true);await process_frame

func keypress(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
		root.push_input(event,true);await process_frame
