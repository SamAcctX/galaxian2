extends "res://tests/void_ambush_application.gd"
## Short actual-input route to locate history changes before the long ambush.
## Uses the full earned driver's departure and gate input, not a detached world.
func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	check(FileAccess.get_sha256(input_path)==OS.get_environment("GOF2_SOURCE_SAVE_SHA256"),"Navigation history requires the canonical earned station")
	if failures:return
	_world_clock_base=1789105600
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	if not await depart_onward():return
	print("Station history before departure: ",original.station_response_flags)
	print("Ordinary departure history: ",app.session.flight_owner().station_response_flags())
	check(app.session.flight_owner().station_response_flags()==original.station_response_flags,"Departure changed existing response history")
	if not await enter_mission40_gate():return
	var after: Dictionary=app.session.flight_owner().station_response_flags()
	print("Selected world history after actual gate: ",after)
	if not retain_navigation_history(original.station_response_flags):return
	check(void_route_history==after,"The full driver did not retain its validated navigation history")
	var destination: int=app.session.flight_owner().player_owner().loadout().station_id
	var initial: bool=definitions.mido_travel.traffic_combat.station_flag_initial
	var old_station: int=original.station_response_flags.keys()[0]
	var missing: Dictionary=after.duplicate(true);missing.erase(old_station)
	check(not navigation_history_matches(original.station_response_flags,missing,destination,initial),"History check accepted a dropped old station")
	var changed: Dictionary=after.duplicate(true);changed[old_station]=not changed[old_station]
	check(not navigation_history_matches(original.station_response_flags,changed,destination,initial),"History check accepted a changed old response")
	changed=after.duplicate(true);changed[destination]=not initial
	check(not navigation_history_matches(original.station_response_flags,changed,destination,initial),"History check accepted an incorrect arrival response")
	changed=after.duplicate(true);changed[10000]=false
	check(not navigation_history_matches(original.station_response_flags,changed,destination,initial),"History check accepted an unrelated added station")
	after.clear()
	check(not void_route_history.is_empty() and app.session.flight_owner().station_response_flags()==void_route_history,"Inspected history mutated the retained route or live world")
	await capture_free_application("mission-history-selected-arrival")
	check(FileAccess.get_sha256(input_path)==OS.get_environment("GOF2_SOURCE_SAVE_SHA256"),"Navigation changed the earned source")
