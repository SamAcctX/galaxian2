extends "res://tests/junk_resume_application.gd"
## Resume an earned contract and inspect its live, passive HUD clock.

func verify_free_application() -> void:
	var saved: Dictionary=app.session.station_owner().snapshot()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	if int(saved.loadout.station_id)!=int(saved.contracts.mission.station_id) and not await travel_application(int(saved.contracts.mission.station_id)):return
	var arrival: Dictionary=app.session.snapshot()
	check(arrival.mission_readout.kind=="countdown" and arrival.mission_readout.remaining_ms==121000-arrival.world_elapsed_ms,"The flight readout lost its world deadline")
	check(app.flight_vitals.visible and app.flight_vitals._cargo_text.text==app.flight_vitals._mission_text(arrival.mission_readout),"The accepted flight clock did not reach the visible HUD")
	check(app.flight_vitals._cargo_frame.texture.get_meta("source_image_id")==1221,"The countdown used another source panel")
	root.size=Vector2i(1280,720);app.set_mobile_layout(false);app.set_touch_controls(false)
	await capture_free_application("countdown-desktop")
	if not app.open_map(now_us):check(false,app.status.text);return
	now_us+=5000000
	if not app.session.step(now_us):check(false,app.session.error);return
	app.present_session()
	check(app.session.snapshot().mission_readout==arrival.mission_readout and not app.flight_vitals.visible,"The map advanced or exposed the paused flight readout")
	await capture_free_application("countdown-paused-map")
	if not app.close_map(now_us):check(false,app.status.text);return
	check(app.flight_vitals.visible and app.session.snapshot().mission_readout==arrival.mission_readout,"Closing the map consumed paused time")
	var before: Dictionary=app.session.snapshot()
	check(not app.session.step(now_us+100000,Vector2(2,0)) and app.session.snapshot()==before,"A rejected input advanced the countdown")
	if not application_step():return
	check(app.session.snapshot().mission_readout.remaining_ms==arrival.mission_readout.remaining_ms-100,"The resumed countdown failed to advance by the accepted step")
	root.size=Vector2i(960,540);app.set_mobile_layout(true);app.set_touch_controls(true)
	await capture_free_application("countdown-mobile-landscape")
	check(app.flight_vitals._cargo_frame.get_global_rect().end.x<=app.size.x and app.flight_vitals._cargo_text.get_minimum_size().x<=app.flight_vitals._cargo_text.size.x,"The landscape countdown clipped its text or panel")
	print("Freelance live readout: ",{"remaining_ms":app.session.snapshot().mission_readout.remaining_ms,"text":app.flight_vitals._cargo_text.text})
