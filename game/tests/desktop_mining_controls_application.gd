extends "res://tests/station_equipment.gd"
## One tutorial career: desktop skip, unarmed mouse/trackpad steering, mining,
## hangar Escape, equipment, autosave, fresh Resume and armed departure.
const Frontend=preload("res://src/presentation/player_frontend.gd")
var _armed_continuation:=false

func verify_departure_input() -> void:
	root.content_scale_size=Vector2i.ZERO
	host.set_player_mode(true);host._mouse_steering=true;host.present_session()
	host.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"))
	DirAccess.make_dir_recursive_absolute(OS.get_environment("GOF2_CAPTURE_DIR"))
	for tick in 30:
		if host.session.can_skip_cinematic():break
		if not step():return
	check(host.session.can_skip_cinematic() and not host._mouse_captured,"Departure did not offer an uncaptured desktop skip")
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT
	click.position=Vector2(640,360);click.global_position=click.position;click.pressed=true
	root.push_input(click,true)
	click=click.duplicate();click.pressed=false;root.push_input(click,true)
	check(not host.session.can_skip_cinematic() and host.session.snapshot().entry_released,"A desktop scene click did not skip departure")

func acknowledge_briefing() -> void:
	for page in 5:
		var button: Control=host.session.scene.dialogue._next
		var view: Control=host.viewport.get_parent()
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT
		click.position=view.get_global_transform_with_canvas()*button.get_global_rect().get_center();click.global_position=click.position;click.pressed=true
		root.push_input(click,true);await process_frame
		click=click.duplicate();click.pressed=false;root.push_input(click,true);await process_frame

func verify_released_input() -> void:
	host._mouse_steering=true;host.present_session()
	check(host._mouse_captured and host._controls.snapshot().mouse_capture,"Briefing release waited for a fire click to capture steering")
	var retained: RefCounted=host.session.flight_owner()
	for cadence in ([[16667]] if _armed_continuation else [[16667],[6944,6945],[4000,17000,31000,9000]]):
		for small_moves in [false,true]:
			for page in 8:
				if not host.session.snapshot().dialogue.visible:break
				key(KEY_ENTER)
			host.present_session()
			check(host.session.can_control() and host._mouse_captured,"Acknowledging a later briefing did not restore mouse steering")
			host.clear_input();host.session.rebase_time(now_us)
			var start: Transform3D=host.session.snapshot().player_pose
			var elapsed:=0;var ticks:=0
			var duration:=100000 if _armed_continuation else 400000
			while elapsed<duration:
				var span: int=mini(cadence[ticks%cadence.size()],duration-elapsed)
				if (small_moves and ticks<28) or (not small_moves and ticks==0):
					var motion:=InputEventMouseMotion.new();motion.screen_relative=Vector2(4 if small_moves else 112,0)
					motion.relative=motion.screen_relative;root.push_input(motion,true)
				host._controls.advance_mouse(float(span)/1000000.0)
				var input: Dictionary=host._controls.snapshot()
				now_us+=span;elapsed+=span;ticks+=1
				check(input.command.y<0,"Mouse/trackpad motion was lost before a click")
				if failures:return
				if not host.session.step(now_us,input.command,false,host._mouse_captured):check(false,host.session.error);return
				host.present_session()
				if ticks==1 and not small_moves:check(start.basis.z.distance_to(host.session.snapshot().player_pose.basis.z)>0.00001,"Mouse steering waited for another simulation frame")
			var state: Dictionary=host.session.snapshot()
			check(start.basis.z.distance_to(state.player_pose.basis.z)>0.005,"Mouse/trackpad flight remained unresponsive")
			check(state.fast_forward.camera_response.relative_capture,"Mouse flight kept the stick camera response")
			if cadence==[16667] and not small_moves and not OS.get_environment("GOF2_CAPTURE_DIR").is_empty():await capture(OS.get_environment("GOF2_CAPTURE_DIR"),"desktop-mining-mouse-"+str(state.campaign_cursor))
			host.clear_input()
			for settling in (0 if _armed_continuation else 20):
				now_us+=100000
				if not host.session.step(now_us,Vector2.ZERO,false,true,0.0,true):check(false,host.session.error);return
	# A camera must follow the same mouse turn when Fast Forward is unavailable.
	var without_fast: RefCounted=retained.fork_for_frame();without_fast._fast_forward=null
	var normal: RefCounted=retained.evaluate(100,Vector2(0,-0.5),0.0,false,Vector2i(1280,720),Vector2.ZERO,false,false,true)
	var plain: RefCounted=without_fast.evaluate(100,Vector2(0,-0.5),0.0,false,Vector2i(1280,720),Vector2.ZERO,false,false,true)
	check(normal!=null and plain!=null,"Mouse response failed without Fast Forward")
	if normal!=null and plain!=null:check(normal.snapshot().camera_view.pose.is_equal_approx(plain.snapshot().camera_view.pose),"Camera response depended on Fast Forward availability")
	host.clear_input();host._mouse_steering=false;host.set_player_mode(false);host.present_session();host.session.rebase_time(now_us)

func verify_hangar_input() -> void:
	var before: Dictionary=host.session.snapshot()
	var frontend:=Frontend.new();root.add_child(frontend)
	frontend.game=host;frontend.phase="game";frontend.menu.hide();frontend._details.hide();host.reparent(frontend)
	var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	root.push_input(escape,true)
	escape=escape.duplicate();escape.pressed=false;root.push_input(escape,true)
	check(frontend.phase=="game" and not host.equipment_panel.visible and not host.session.snapshot().hangar_open,"Escape opened the menu instead of closing the hangar")
	var after: Dictionary=host.session.snapshot()
	check(after.campaign_cursor==before.campaign_cursor and after.loadout==before.loadout and after.cargo==before.cargo,"Hangar Escape changed the career or inventory")
	check(host.equipment_action("open"),host.session.error)
	host.reparent(root);frontend.game=null;frontend.free()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func after_second_return(args: PackedStringArray) -> void:
	await super.after_second_return(args)
	if failures:return
	var saved: Dictionary=host.session.snapshot()
	check(host.save_station(),host._save_notice.text)
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	host.free();host=Host.new();root.add_child(host);host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.set_context(lib,bindings,visuals);host.set_process(false);host.enable_saves(directory);host.set_player_mode(true)
	await restore_test_focus()
	check(host.load_station(),host._save_notice.text)
	if failures:return
	var restored: Dictionary=host.session.snapshot()
	check(restored.campaign_cursor==saved.campaign_cursor and restored.loadout==saved.loadout and restored.cargo==saved.cargo,"Fresh Resume changed the mined/equipped career")
	check(host.request_departure() and host.enter_first_flight(now_us,4096,1789100000),host.status.text)
	if failures:return
	host.session.rebase_time(now_us)
	await verify_departure_input()
	for tick in 200:
		if host.session.can_control():break
		if host.session.snapshot().dialogue.visible:key(KEY_ENTER)
		elif not step():return
	check(host.session.can_control(),"Armed departure did not release control")
	_armed_continuation=true
	if not failures:await verify_released_input()
