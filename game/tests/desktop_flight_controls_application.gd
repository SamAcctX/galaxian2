extends "res://tests/beam_primary_application.gd"
## One saved career: current mouse input, straight A/D flight, pause, docking
## and fresh Resume. Native desktop events run on the check's private display.
const DesktopInput=preload("res://tests/fixtures/mission_pilot_input.gd")

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	# The earned beam career also owns its retained travelling gun. Fit that
	# owned gun so the strafe capture contains visible forward-flying shots.
	if not original.loadout.equipment_ids.has(2):
		check(original.cargo.entries.any(func(row):return row.item_id==2 and row.quantity>0),"Earned career lacks its retained primary gun")
		if failures or not app.equipment_action("open"):return
		for slot in original.loadout.slots:
			if slot!=null and slot.category==0 and not app.equipment_action("unmount",slot.item_id):check(false,app.session.error);return
		if not app.equipment_action("mount",2) or not app.equipment_action("close"):check(false,app.session.error);return
		original=app.session.station_owner().snapshot()
	app.set_player_mode(true);app._mouse_steering=true;app.show();app.present_session()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	app.present_session();check(app._mouse_captured,"Flight did not capture desktop mouse")
	for adjustment in 10:DesktopInput.press(root,KEY_SLASH)
	var before: Transform3D=app.session.snapshot().player_pose
	if not desktop_frame(Vector2(.1,-.3),0.0,false,16667):return
	var turned: Transform3D=app.session.snapshot().player_pose
	check(before.basis.z.distance_to(turned.basis.z)>0.00001,"Mouse movement waited for the following frame")
	for tick in 120:
		if not desktop_frame(Vector2.ZERO,0.0,false,16667):return
	await capture_free_application("desktop-mouse-response")
	for cadence in [[16667],[6944,6945],[4000,17000,31000,9000,67000]]:
		for direction in [-1.0,1.0]:
			var initial: Dictionary=app.session.snapshot()
			var pose: Transform3D=initial.player_pose
			var model: Basis=initial.player_model_basis
			var elapsed:=0;var frame:=0;var emitted:=false
			while elapsed<400000:
				var step:=mini(int(cadence[frame%cadence.size()]),400000-elapsed)
				var parent: RefCounted=app.session.flight_owner()
				var prior_ms: int=app.session.snapshot().world_elapsed_ms
				if not desktop_frame(Vector2.ZERO,direction,true,step):return
				elapsed+=step;frame+=1
				var state: Dictionary=app.session.snapshot()
				check(state.player_pose.basis.is_equal_approx(pose.basis),"A/D rotated the physical ship")
				check(state.player_model_basis.is_equal_approx(model),"A/D banked or tilted the visible ship")
				# Compare with the same frame without A/D, so existing mouse
				# camera settling is not mistaken for a strafe-induced turn.
				var neutral: RefCounted=parent.evaluate(state.world_elapsed_ms-prior_ms,Vector2.ZERO,0.0,false,Vector2i(1280,720),Vector2.ZERO,true,false,true)
				if neutral==null:check(false,parent.error);return
				var view: Transform3D=neutral._camera.snapshot().pose
				check(app.session.camera.global_basis.z.dot(view.basis.z)>0.99999,"A/D swung the camera and angled the ship on screen")
				var movement: Vector3=state.player_pose.origin-pose.origin
				check(movement.dot(pose.basis.x)*direction<0 and absf(movement.dot(pose.basis.z))<0.1 and absf(movement.dot(pose.basis.y))<0.1,"A/D added forward or vertical movement")
				var aim: Dictionary=state.player_aim
				var gun_point: Vector3=state.player_pose.origin+state.player_pose.basis.z*22000.0
				var on_screen: Vector2=app.session.camera.unproject_position(gun_point)
				check(on_screen.distance_to(Vector2(aim.point.x,aim.point.y))<1.0,"Crosshair missed the gun line in the displayed camera")
				for weapon in state.encounter.get("primary_fire",{}).get("weapons",[]):
					if weapon.result.get("fired",false):emitted=true
			check(emitted,"Holding fire during A/D did not emit a primary")
			if cadence==[16667]:await capture_free_application("desktop-strafe-left" if direction<0 else "desktop-strafe-right")
			var stopped: Transform3D=app.session.snapshot().player_pose
			if not desktop_frame(Vector2.ZERO,0.0,false,16667):return
			check(app.session.snapshot().player_pose.is_equal_approx(stopped),"Releasing A/D continued moving or rotated the ship")
			if failures:return
	app.set_user_paused(true)
	var paused: Dictionary=app.session.snapshot()
	var move:=InputEventMouseMotion.new();move.screen_relative=Vector2(224,0);root.push_input(move,true)
	DesktopInput.key(root,KEY_D,true);DesktopInput.key(root,KEY_SPACE,true)
	check(app.session.snapshot()==paused and app._controls.snapshot().command==Vector2.ZERO and app._controls.snapshot().strafe==0,"Pause retained mouse/strafe/fire input")
	DesktopInput.key(root,KEY_D,false);DesktopInput.key(root,KEY_SPACE,false)
	app.set_user_paused(false);app.clear_input()
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.campaign_cursor==original.campaign_cursor and landed.loadout==original.loadout and landed.contracts.credits==original.contracts.credits and landed.contracts.mission==original.contracts.mission,"Controls flight changed the saved career")
	check(FileAccess.file_exists(app.station_save_path()),"Docking did not write its autosave")
	await capture_free_application("desktop-controls-docked")
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.campaign_cursor==landed.campaign_cursor and saved.career.credits==landed.contracts.credits,"Docking autosave lost career progress or credits")
	app.free();await process_frame
	app=Host.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(source,definitions,visual);app.set_process(false);app.enable_saves(directory);app.set_player_mode(true)
	app.show();app.present_session();await process_frame;resume_application_focus()
	var resume:=InputEventKey.new();resume.physical_keycode=KEY_F9;resume.pressed=true;app._unhandled_input(resume)
	check(app.session!=null,"Fresh Resume failed: "+app._save_notice.text)
	if app.session!=null:
		var restored: Dictionary=app.session.station_owner().snapshot()
		check(restored.campaign_cursor==landed.campaign_cursor and restored.loadout==landed.loadout and restored.contracts.credits==landed.contracts.credits and restored.contracts.mission==landed.contracts.mission,"Fresh Resume changed the completed controls flight")
		await capture_free_application("desktop-controls-fresh-resume")

func desktop_frame(command: Vector2,strafe: float,fire: bool,delta_us: int) -> bool:
	resume_application_focus()
	app._controls.advance_mouse(0.0)
	var held: Dictionary=app._controls.snapshot()
	if held.held.fire!=fire:DesktopInput.key(root,KEY_SPACE,fire)
	if (held.strafe<0)!=(strafe<0):DesktopInput.key(root,KEY_A,strafe<0)
	if (held.strafe>0)!=(strafe>0):DesktopInput.key(root,KEY_D,strafe>0)
	var change:=Vector2(held.command.y-command.y,command.x-held.command.x)
	var mouse:=InputEventMouseMotion.new()
	mouse.screen_relative=change*app._controls.MOUSE_REFERENCE_SIZE*0.35/app._controls.mouse_sensitivity
	mouse.relative=mouse.screen_relative;root.push_input(mouse,true)
	app._controls.advance_mouse(float(delta_us)/1000000.0)
	var input: Dictionary=app._controls.snapshot()
	app.handle_action_events(app._controls.take_events())
	now_us+=delta_us
	if not app.session.step(now_us,input.command,input.held.fire,app._mouse_captured,input.strafe):check(false,app.session.error);return false
	app.present_session()
	if app._transition_failed:check(false,app.status.text);return false
	return failures==0
