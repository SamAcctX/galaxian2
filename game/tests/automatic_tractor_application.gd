extends "res://tests/beam_primary_application.gd"
## Earned supplier travel, paid fitting and input-only automatic debris recovery.
const Navigation=preload("res://src/simulation/system_navigation.gd")

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_AUTOMATIC_TRACTOR_RESUMED")=="1"
	var item:=70;var price:=0
	if not resumed:
		if original.loadout.station_id!=16 and not await visit_tractor_supplier(16):return
		if not retain_recovery_save("supplier"):return
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		var offers: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==item and row.stock>0)
		if offers.size()!=1:check(false,"The actual supplier shop has no automatic tractor");return
		price=int(offers[0].unit_price)
		var proceeds:=0
		if quote.contracts.credits<price:
			var spares: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==64 and row.owned>0 and not row.mission)
			if spares.size()!=1:check(false,"The earned wallet cannot afford the tractor or sell its spare");return
			proceeds=int(spares[0].unit_price)
			if not app.equipment_action("sell",64):check(false,app.session.error);return
		if not app.equipment_action("buy",item) or not app.equipment_action("unmount",57) or not app.equipment_action("mount",item):check(false,app.session.error);return
		var bought: Dictionary=app.session.station_owner().snapshot()
		check(bought.contracts.credits==quote.contracts.credits+proceeds-price and bought.cargo.entries.has({"item_id":57,"quantity":1}),"The automatic tractor purchase lost its real quote, sale or removed armor")
		app.equipment_panel.select_tab("ship")
		await capture_free_application("automatic-tractor-fitted")
		if not app.equipment_action("close"):check(false,app.session.error);return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(item) and fitted.contracts.passengers==3 and fitted.contracts.mission==original.contracts.mission,"Automatic fitting lost its device or retained passengers")
	check(fitted.loadout.equipment_ids.all(func(id):return catalogue.tables.items[id].properties.get(2)!=17),"The scenery route unexpectedly fitted a ship scanner")
	if failures or not retain_recovery_save("fitted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	if not await recover_automatic_scenery():return
	var collected: Dictionary=app.session.snapshot()
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.cargo==collected.cargo and landed.contracts.credits==fitted.contracts.credits,"Docking lost automatic recovery's fitting, cargo or wallet")
	var recovered:=int(collected.encounter.combat.recovery.accepted_quantity)
	check(landed.contracts.progress.get("cargo_recovered",0)==int(fitted.contracts.progress.get("cargo_recovered",0))+recovered,"Docking failed to credit the actual recovered quantity exactly once")
	check(landed.contracts.passengers==3 and landed.contracts.mission==original.contracts.mission and landed.campaign_cursor==45,"Automatic recovery changed the passenger job or completed story")
	if not retain_recovery_save("returned"):return
	await capture_free_application("automatic-tractor-saved-station")
	print("Automatic tractor saved: ",{"item":item,"price":price,"credits":landed.contracts.credits,"cargo":landed.cargo.entries,"cursor":landed.campaign_cursor,"passengers":landed.contracts.passengers})

func visit_tractor_supplier(destination: int) -> bool:
	var original: Dictionary=app.session.station_owner().snapshot()
	var navigation:=Navigation.new()
	if not navigation.configure(definitions,catalogue,original.contracts.lounges.system_availability):check(false,navigation.error);return false
	var system_id:=int(catalogue.tables.stations[destination].system_id)
	var route: Array=navigation.route(original.loadout.system_id,system_id)
	if route.is_empty():check(false,"The earned career has no available route to the supplier");return false
	print("Automatic tractor supplier route: ",route)
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	var gate_field:=int(definitions.mido_travel.free_navigation.gate_station_field)
	if route.size()>1:
		var first_gate:=int(catalogue.tables.systems[route[0]].fields[gate_field])
		if original.loadout.station_id!=first_gate and not await travel_application(first_gate):return false
		for next_system in route.slice(1):
			var gate:=int(catalogue.tables.systems[next_system].fields[gate_field])
			if not await follow_gate_course(next_system,gate) or not await release_application_flight():return false
			if not await dock_application() or not retain_recovery_save("route-"+str(gate)):return false
			if next_system==system_id and gate==destination:return true
			if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
			if not await release_application_flight():return false
	if app.session.snapshot().location.station_id!=destination and not await travel_application(destination):return false
	return await dock_application()

func follow_gate_course(system_id: int,station_id: int) -> bool:
	if not app.open_map() or not app.switch_map_system(system_id):check(false,app.status.text);return false
	app.map_panel.select_station(station_id);app.map_panel.request_confirmation()
	if not app.confirm_map_planet(station_id,now_us):check(false,app.map_panel.error);return false
	var started:=now_us;var next_yield:=now_us;var coasting:=false
	while app.session.status=="running" and now_us-started<240000000:
		if not application_step():return false
		coasting=coasting or app.session.snapshot().gate_transit.coasting
		if app.session.flight_owner().death_active():check(false,"The supplier pilot died on its gate approach");return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	check(app.session.status=="gate_confirmation_required" and coasting,"The supplier gate course never reached its physical confirmation")
	if failures or not app.choose_gate_confirmation(0,now_us):check(false,app.session.error);return false
	app.session.rebase_time(now_us)
	started=now_us
	while app.session.status=="running" and now_us-started<10000000:
		if not application_step():return false
	check(app.session.status=="gate_arrival_transition_required","The confirmed supplier gate did not finish its animation")
	if failures or not app.enter_gate_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	check(app.session.snapshot().location.system_id==system_id and app.session.snapshot().location.station_id==station_id,"The supplier gate arrived at a different destination")
	return failures==0

func recover_automatic_scenery(automatic:=true) -> bool:
	var target:=-1;var visited:=[];var request_seen:=false;var beam_seen:=false;var sound_seen:=false
	var initial: Dictionary=app.session.snapshot()
	var accepted_before:=int(initial.encounter.combat.get("recovery",{}).get("accepted_quantity",0))
	var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	while now_us-started<360000000:
		var state: Dictionary=app.session.snapshot();var field: Dictionary=state.scenery
		if int(state.encounter.combat.get("recovery",{}).get("accepted_quantity",0))>accepted_before:
			check(request_seen and beam_seen and sound_seen and state.cargo.used>initial.cargo.used,"Automatic recovery skipped its request, original beam/audio or cargo transfer")
			check(state.mining_targeting.scanner_id==-1 and state.tractor.equipment_id==(70 if automatic else 68),"Scenery pickup required a ship scanner or substituted equipment")
			await capture_free_application("automatic-tractor-pickup")
			return failures==0
		if app.session.flight_owner().death_active():check(false,"The automatic recovery pilot died before collecting cargo");return false
		if target>=0 and not field.bodies.objects[target].active and not field.destruction[target].lifecycle.drop_allowed:target=-1
		if target<0:
			var candidates: Array=field.objects.filter(func(row):return row.source_size_value!=7 and not visited.has(row.index) and field.bodies.objects[row.index].active)
			candidates.sort_custom(func(a,b):return a.position.distance_squared_to(state.player_pose.origin)<b.position.distance_squared_to(state.player_pose.origin))
			if candidates.is_empty():break
			target=int(candidates[0].index);visited.append(target)
		var life: Dictionary=field.destruction[target].lifecycle
		var dropping: bool=life.actor_state in [3,4]
		if dropping and not life.drop_allowed:target=-1;continue
		var position: Vector3=field.objects[target].position
		var offset: Vector3=position-state.player_pose.origin
		var local: Vector3=state.player_pose.basis.inverse()*offset
		var angles:=Vector2(-atan2(local.y,sqrt(local.x*local.x+local.z*local.z)),atan2(local.x,local.z))
		var pulling: bool=state.tractor.active
		var input:={"commands":PiratePilot.Steering.steering_toward(state.player_pose,position),"throttle":1.0 if not pulling and offset.length()>(2500.0 if dropping else 8000.0) else 0.0,"fire":not dropping and offset.length()<22000 and angles.length()<.1,"strafe":0.0}
		if pulling:input.commands=Vector2.ZERO
		if not pirate_step(input):return false
		var after: Dictionary=app.session.snapshot()
		if not request_seen and after.tractor.request_actor_id>=0:
			check(after.tractor.request_group=="scenery" and (not automatic or after.mining_targeting.elapsed_ms<1000),"Debris recovery queued another population or delayed automatic targeting")
			request_seen=true
		for event in after.tractor_frame.get("events",[]):
			if event.get("kind")=="sound" and event.get("source_id")==0:sound_seen=true
		if not beam_seen and after.tractor_frame.get("phase")=="pulling":
			check(after.tractor.beam.model_id==(14234 if automatic else 14232) and app.session.flight_audio!=null,"Scenery recovery lost its original model or flight audio")
			await capture_free_application("automatic-tractor-beam");beam_seen=true
		if now_us>=next_log:
			print("Automatic recovery pilot: ",{"seconds":(now_us-started)/1000000.0,"target":target,"distance":offset.length(),"lifecycle":life.actor_state,"hull":after.player.vitals.hull,"request":after.tractor.request_actor_id,"phase":after.tractor_frame.get("phase","")})
			next_log=now_us+10000000
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	await capture_free_application("automatic-tractor-stopped")
	check(false,"The ordinary scenery did not yield an automatic cargo pickup");return false
