extends "res://tests/player_import_update.gd"
const Flight=preload("res://src/presentation/first_flight_session.gd")
## Resume an earned station, depart, then compare detached flight branches.
## Only the final branch is rendered; the player's save is never written.
func run() -> void:
	var args:=OS.get_cmdline_user_args();var directory:=OS.get_environment("GOF2_MENU_TEST_DIRECTORY")
	if args.size()!=3 or not Guard.private_path(directory.path_join("player.json")):
		check(false,"Expected two imports, an earned save and isolated profile");finish();return
	root.size=Vector2i(1280,720)
	var earlier:=Frontend.DmgImport.read_receipt(args[0])
	var copy:=directory.path_join("saves").path_join(earlier.base_content_id).path_join(earlier.binding_id).path_join("station.gof2save")
	DirAccess.make_dir_recursive_absolute(copy.get_base_dir());check(DirAccess.copy_absolute(args[2],copy)==OK,"Could not copy the earned station")
	var app:=Frontend.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.remove_absolute(directory.path_join("player.json"))
	app.boot(PackedStringArray(),directory)
	check(app.open_import(args[0]),app.error);app.request_action("resume")
	if not app.has_session():check(false,app.error);app.free();finish();return
	var host=app.game;host.set_process(false);host._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(host.request_departure(),host.status.text);host.choose_departure(1)
	if not host.session is Flight:
		check(false,host.status.text);app.free();finish();return
	var flight=host.session;var now:=1000000;flight.rebase_time(now)
	for i in 300:
		if flight.can_control():break
		now+=100000;check(flight.step(now),flight.error)
		if flight.snapshot().dialogue.visible:check(flight.navigate("next"),flight.error)
	check(flight.can_control(),"Tutorial flight did not release control")
	host.present_session();host._sync_mouse_capture()
	check(host._mouse_captured,"Desktop flight did not capture mouse steering")
	var base: RefCounted=flight._world;var results:=[]
	for steps in [[17],[7],[100],[5,35,11,49]]:
		host.clear_input();host._controls.mouse_sensitivity=1.0
		var physical:=Vector2(2560,1440) if steps==[7] else Vector2(1280,720)
		var event:=InputEventMouseMotion.new();event.screen_relative=Vector2(224,0)*(physical/Vector2(1280,720));host._input(event)
		var frame: RefCounted=base.fork_for_frame();var elapsed:=0;var index:=0
		while elapsed<2000:
			var dt:=mini(int(steps[index%steps.size()]),2000-elapsed);index+=1;elapsed+=dt
			host._controls.advance_mouse(float(dt)/1000.0,physical)
			var input: Dictionary=host._controls.snapshot()
			var next: RefCounted=frame.evaluate(dt,input.command,0.0,false,Vector2i(1280,720),Vector2.ZERO,false,false,input.mouse_capture)
			if next==null:check(false,frame.error);break
			frame=next
			if index==1:
				check(frame._camera.response_snapshot().relative_capture,"Captured flight retained the keyboard camera policy")
				var point: Vector3=frame._aim.snapshot().point
				check(Vector2(point.x,point.y).is_equal_approx(Vector2(864,360)),"Steering cursor waited for the camera or ship to turn")
			if steps==[17]:check(flight._commit(frame,true),flight.error)
		var angle:=acos(clampf(base.snapshot().player_pose.basis.z.dot(frame.snapshot().player_pose.basis.z),-1,1))
		check(angle>0.1,"Mouse barely turned the ship in two seconds: "+str(angle))
		results.append(angle);print("Mouse flight steps ",steps," turn degrees ",rad_to_deg(angle))
	check(results.max()-results.min()<0.08,"Rendering rate materially changed the mouse turn")
	host.present_session();await capture("mouse-turn")
	host.set_user_paused(true);check(host._controls.snapshot().command==Vector2.ZERO,"Pausing retained a displaced steering cursor")
	host.set_user_paused(false);host.clear_input();check(host._controls.snapshot().command==Vector2.ZERO,"Resuming restored stale steering")
	app.free();await process_frame
	print("Mouse flight: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
