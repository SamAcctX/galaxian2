extends "res://tests/beam_primary_application.gd"
## Resume an earned fitted career and observe the shared field in real flight.

func verify_free_application() -> void:
	var station: Dictionary=app.session.station_owner().snapshot()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var dust: Node=app.session.scene.sky.foreground_particles
	if dust==null:check(false,"Earned departure omitted its nearby particle field");return
	var initial: Dictionary=dust.snapshot()
	var cpu_us:=0
	for index in 60:
		var begin:=Time.get_ticks_usec()
		if not pirate_step({"commands":Vector2.ZERO,"throttle":1.0,"fire":false,"strafe":0.0}):return
		cpu_us+=Time.get_ticks_usec()-begin
		if index%10==0:await process_frame
	var flying: Dictionary=dust.snapshot()
	check(flying.elapsed_ms>initial.elapsed_ms and flying.camera.distance_to(initial.camera)>1000,"Cruise did not advance the nearby field with its camera")
	check(Array(flying.weights).any(func(value):return value>0.1),"Moving through the field left every nearby particle faded out")
	await capture_free_application("cruising-dust")
	var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=true
	resume_application_focus();app._unhandled_input(key)
	for index in 10:
		if not pirate_step({"commands":Vector2.ZERO,"throttle":1.0,"fire":false,"strafe":0.0}):return
	check(app.session.booster_state().active,"The earned fitted booster did not activate during field observation")
	await capture_free_application("boosted-dust")
	var live: Dictionary=dust.snapshot()
	check(app.session.set_pause("user",true,now_us),app.session.error)
	now_us+=1000000
	check(app.session.step(now_us) and dust.snapshot()==live,"Pause moved the foreground field")
	check(app.session.present_current() and dust.snapshot()==live,"Repeated flight presentation moved nearby particles")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	check(app.session.snapshot().campaign_cursor==station.campaign_cursor,"Foreground rendering changed campaign progress")
	print("Earned flight dust: ",{"clock_ms":live.elapsed_ms,"camera_travel":live.camera.distance_to(initial.camera),"particles":live.positions.size(),"mean_whole_flight_step_us":cpu_us/60.0,"cursor":station.campaign_cursor})
