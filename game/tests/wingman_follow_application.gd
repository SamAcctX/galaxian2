extends "res://tests/wingman_actors_application.gd"
## Follow acceptance starts from a byte-copied paid career. Only ordinary player
## input moves the application; detached motion checks never enter its save.

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.wingmen==entry.contracts.wingmen and not entry.contracts.wingmen.active.is_empty(),"Resume did not retain the genuinely paid crew")
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var initial: Dictionary=app.session.flight_owner().snapshot()
	var crew: RefCounted=app.session.flight_owner().wingman_owner()
	check(crew!=null and crew.snapshot().following_connected and not crew.snapshot().interactions_connected,"Following is absent or falsely claims combat")
	if failures:return
	verify_follow_components(crew,initial.player_pose)
	check(app.session.flight_owner().snapshot()==initial,"Detached follow checks changed the application")
	if failures or not await release_application_flight():return
	var scene:=find_flight_scene(app)
	check(scene!=null and scene.wingmen!=null,"Live following has no original ship geometry")
	if failures:return
	var airborne: Dictionary=app.session.snapshot().wingman_actors
	var started:=now_us
	var next_yield:=now_us+1000000
	while now_us-started<14000000:
		var turning: bool=now_us-started>=7000000
		if not pirate_step({"commands":Vector2(.65,.2) if turning else Vector2.ZERO,"throttle":1.0,"fire":false,"strafe":0.0}):return
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	var flown: Dictionary=app.session.snapshot()
	var cast: Dictionary=flown.wingman_actors
	check(cast.actors[0].pose.origin.distance_to(airborne.actors[0].pose.origin)>1000.0,"Ordinary player input left the hired pilot stationary")
	check(cast.following.targets[0].distance_to(airborne.following.targets[0])>1000.0,"The pilot kept a fixed departure waypoint")
	check(cast.following.targets[0].distance_to(CrewActors.follow_position(flown.player_pose,0))<.5,"Following did not sample the current accepted player frame")
	check(cast.actors[0].pose.basis.z.dot(airborne.actors[0].pose.basis.z)<.999,"The native pilot did not steer")
	check(scene.wingmen.actors[0].ship.transform==cast.actors[0].pose,"Ship rendering ignored the moving native body")
	check(cast.actors[0].name==entry.contracts.wingmen.active.names[0],"Following replaced the earned pilot")
	if failures or not await view_following_pilot(scene):return
	# Other ships' engines: the hired pilot loops the original wingman engine.
	var engines: Dictionary=app.session.engine_audio.snapshot() if app.session.engine_audio!=null else {}
	print("ENGINES ",engines)
	check(engines.get("prepared",[]).size()==3 and engines.playing.keys().any(func(key):return key.begins_with("wingman:") and engines.playing[key].level>0.0),"The wingman has no engine sound")
	var paused: Dictionary=app.session.flight_owner().snapshot().wingman_actors
	check(app.session.set_pause("user",true,now_us),app.session.error)
	for tick in 10:
		if not application_step():return
	check(app.session.flight_owner().snapshot().wingman_actors==paused,"Paused flight advanced the wingman's native motion")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	if failures or not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	verify_retained_career(entry,returned)
	check(returned.contracts.wingmen.active.names==entry.contracts.wingmen.active.names and returned.contracts.wingmen.hired_total==entry.contracts.wingmen.hired_total,"Following/docking changed the paid roster")
	check(returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"Following did not retain consumed active flight time")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen,"Docking autosave lost the moving crew's paid lifetime")
	if failures or not retain_recovery_save("returned"):return
	var output: Dictionary=app._save_file.load_document(directory.path_join("returned.gof2save"),definitions,catalogue,source)
	check(not output.is_empty() and output.career.wingmen==returned.contracts.wingmen,"The follow checkpoint lost the retained hire")
	check(FileAccess.get_sha256(input_path)==input_hash,"Follow acceptance modified its earned input")
	await capture_free_application("wingman-follow-returned")
	print("Earned wingman following: ",{"input_sha256":input_hash,"name":cast.actors[0].name,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"credits":returned.contracts.credits,"timing":_pilot_deltas,"combat_accepted":false})

func verify_follow_components(crew: RefCounted,player: Transform3D) -> void:
	var before: Dictionary=crew.snapshot()
	var candidate: RefCounted=crew.fork_for_frame()
	var sibling: RefCounted=crew.fork_for_frame()
	check(candidate.advance_follow(100,player),candidate.error)
	var moved: Dictionary=candidate.snapshot()
	check(crew.snapshot()==before and sibling.snapshot()==before,"A motion candidate mutated its retained parent or sibling")
	check(absf(moved.actors[0].pose.origin.distance_to(before.actors[0].pose.origin)-200.0)<1.0,"The pilot did not travel at original unboosted cruise speed")
	check(moved.following.motion[0].bank!=0.0,"Formation steering did not enter native banking")
	var exported: Dictionary=candidate.snapshot()
	exported.following.targets[0]=Vector3.ZERO;exported.following.motion[0].history[0]=999.0
	check(candidate.snapshot()==moved,"A public follow observation exposed retained writable state")
	for invalid in [-1,1.5,null,"100",2147483647]:
		check(not candidate.advance_follow(invalid,player) and candidate.snapshot()==moved,"Invalid duration partially moved the crew")
	var bad_pose:=Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO)
	check(not candidate.advance_follow(100,bad_pose) and candidate.snapshot()==moved,"Invalid player frame partially moved the crew")
	check(candidate.advance_follow(0,player) and candidate.snapshot().actors[0].pose.origin==moved.actors[0].pose.origin,"A zero-time world visit moved the pilot")
	var rotated:=Transform3D(Basis(Vector3.UP,.7)*Basis(Vector3.FORWARD,.8),Vector3(11,23,-17))
	var offsets:=[Vector3(-4000,0,-3000),Vector3(4000,0,-3000),Vector3(0,2000,-2000)]
	for index in 3:
		check(CrewActors.follow_position(Transform3D.IDENTITY,index).distance_to(offsets[index])<.01,"A follow slot used its spawn offset")
		check(CrewActors.follow_position(rotated,index).distance_to(rotated*offsets[index])<.01,"A follow slot ignored the player's rotated axes")
	for cadence in [[100],[6,7,7,7,7,7,7,7,7],[7,17,42,8,100,11]]:
		var trial: RefCounted=crew.fork_for_frame()
		var elapsed:=0;var tick:=0;var travelled:=0.0
		while elapsed<3000:
			var delta:=mini(int(cadence[tick%cadence.size()]),3000-elapsed)
			var prior: Vector3=trial.snapshot().actors[0].pose.origin
			if not trial.advance_follow(delta,rotated):check(false,trial.error);return
			travelled+=prior.distance_to(trial.snapshot().actors[0].pose.origin)
			elapsed+=delta;tick+=1
		check(absf(travelled-6000.0)<float(tick)*.5+1.0,"A supported cadence changed the native cruise distance")
		check(CrewActors.Flight.rigid_pose(trial.snapshot().following.motion[0].root_pose),"Cadence changed a rigid native flight frame")
	check(crew.snapshot()==before,"Cadence tests contaminated the retained pilot")

func view_following_pilot(scene: Node3D) -> bool:
	var started:=now_us;var next_yield:=now_us
	while now_us-started<90000000:
		var state: Dictionary=app.session.snapshot()
		var position: Vector3=state.wingman_actors.actors[0].pose.origin
		if not pirate_step({"commands":PiratePilot.Steering.steering_toward(state.player_pose,position),"throttle":0.0,"fire":false,"strafe":0.0}):return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+500000
		position=app.session.snapshot().wingman_actors.actors[0].pose.origin
		if scene.camera.is_position_behind(position):continue
		var screen: Vector2=scene.camera.unproject_position(position)
		var area: Rect2=scene.camera.get_viewport().get_visible_rect().grow(-120)
		if not area.has_point(screen) or position.distance_to(state.player_pose.origin)>10000.0:continue
		check(scene.wingmen.actors[0].ship.is_visible_in_tree(),"The moving pilot is hidden in the live view")
		await capture_free_application("wingman-follow-visible")
		return failures==0
	check(false,"Ordinary steering never brought the following pilot into view")
	return false
