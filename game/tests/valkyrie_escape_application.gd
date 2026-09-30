extends "res://tests/valkyrie_start_application.gd"
## Valkyrie opening chain from the earned call: Kanado talk, the Vossk loan
## ship to B'akrram and the K'Suukk handover, then the escape flights.

func verify_free_application() -> void:
	var staged:=OS.get_environment("GOF2_VALKYRIE_STAGE")
	if staged.is_empty():
		await super.verify_free_application()
		if failures:return
		if not await story_route(74) or not await take_station_talk(47,48):return
		var loaned: Dictionary=app.session.station_owner().snapshot()
		check(loaned.loadout.ship_id==9 and app.session.station_owner().equipment_owner().snapshot().has("stored_ship"),"The Kanado talk did not lend the Vossk ship")
		print("VALKYRIE loan ship=",loaned.loadout.ship_id," items=",loaned.loadout.equipment_ids)
		await capture_free_application("valkyrie-loan-ship")
		if failures or not await story_route(58) or not await take_station_talk(48,49):return
		var prototype: Dictionary=app.session.station_owner().snapshot()
		print("VALKYRIE prototype ship=",prototype.loadout.ship_id," items=",prototype.loadout.equipment_ids)
		check(prototype.loadout.ship_id==41 and prototype.loadout.equipment_ids.count(177)==3,"B'akrram did not hand over the K'Suukk with three scatterguns")
		check(app.save_station(false),"Saving the escape start failed: "+app._save_notice.text)
		if failures:return
		var checkpoint:=OS.get_environment("GOF2_CAPTURE_DIR").path_join("valkyrie-49.gof2save")
		check(DirAccess.copy_absolute(app.station_save_path(),checkpoint)==OK,"The escape checkpoint could not be kept")
		check(app.load_station(),"Fresh Resume at B'akrram failed: "+app._save_notice.text)
		if failures:return
		check(app.session.station_owner().snapshot().loadout==prototype.loadout,"Fresh Resume lost the K'Suukk")
		await capture_free_application("valkyrie-prototype-resumed")

## Fly the earned route to a station, docking at each gate like a player.
func story_route(destination: int) -> bool:
	var original: Dictionary=app.session.station_owner().snapshot()
	var navigation:=Navigation.new()
	if not navigation.configure(definitions,catalogue,original.contracts.lounges.system_availability):check(false,navigation.error);return false
	var system_id:=int(catalogue.tables.stations[destination].system_id)
	var route: Array=navigation.route(original.loadout.system_id,system_id)
	print("VALKYRIE route to ",destination,": ",route)
	if route.is_empty():check(false,"The career has no route to station "+str(destination));return false
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	var gate_field:=int(definitions.mido_travel.free_navigation.gate_station_field)
	if route.size()>1:
		var first_gate:=int(catalogue.tables.systems[route[0]].fields[gate_field])
		if original.loadout.station_id!=first_gate and not await travel_application(first_gate):return false
		for next_system in route.slice(1):
			var gate:=int(catalogue.tables.systems[next_system].fields[gate_field])
			if not await follow_gate_course(next_system,gate) or not await release_application_flight():return false
			if next_system==system_id and gate==destination:return await dock_application()
			if next_system!=route[-1]:
				if not await dock_application():return false
				if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
				if not await release_application_flight():return false
	if app.session.snapshot().location.station_id!=destination and not await travel_application(destination):return false
	return await dock_application()
