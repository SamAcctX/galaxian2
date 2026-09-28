extends "res://tests/beam_primary_application.gd"
## Earned thermal fitting, acquired-target fire and real docking/save continuity.

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_THERMAL_RESUMED")=="1"
	var price:=0
	if not resumed:
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		var scanners: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==81 and row.stock>0)
		if scanners.size()!=1:check(false,"The earned starting shop lacks its scanner");return
		price=int(scanners[0].unit_price)
		if not app.equipment_action("buy",81) or not app.equipment_action("unmount",57) or not app.equipment_action("mount",81):check(false,app.session.error);return
		check(app.session.station_owner().snapshot().contracts.credits==quote.contracts.credits-price,"Scanner purchase lost the quoted price")
		if not app.equipment_action("close") or not await visit_delivery_station(37):return
		if not app.equipment_action("open"):check(false,app.session.error);return
		quote=app.session.station_owner().snapshot()
		var offers: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==28 and row.stock>0 and row.unit_price<=quote.contracts.credits)
		if offers.size()!=1:check(false,"The earned destination has no affordable thermal gun");return
		var gun_price:=int(offers[0].unit_price);price+=gun_price
		if not app.equipment_action("buy",28) or not app.equipment_action("unmount",2) or not app.equipment_action("mount",28):check(false,app.session.error);return
		var bought: Dictionary=app.session.station_owner().snapshot()
		check(bought.contracts.credits==quote.contracts.credits-gun_price and bought.cargo.entries.has({"item_id":2,"quantity":1}),"Thermal purchase lost the actual price or retained gun")
		app.equipment_panel.select_tab("ship")
		await capture_free_application("thermal-purchased-fitted")
		if not app.equipment_action("close"):check(false,app.session.error);return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(28) and fitted.loadout.equipment_ids.has(81) and fitted.contracts.passengers==3 and fitted.contracts.mission==original.contracts.mission,"Thermal fitting lost its scanner or passenger job")
	if failures or not retain_recovery_save("fitted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await fire_thermal_input():return
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.cargo==fitted.cargo and landed.contracts.credits==fitted.contracts.credits,"Thermal flight changed fitting, cargo or credits")
	check(landed.contracts.passengers==3 and landed.contracts.mission==original.contracts.mission and landed.campaign_cursor==45,"Thermal flight changed the retained campaign/job state")
	if not retain_recovery_save("returned"):return
	await capture_free_application("thermal-saved-station")
	print("Thermal saved: ",{"price":price,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor,"passengers":landed.contracts.passengers})

func fire_thermal_input() -> bool:
	var initial: Dictionary=app.session.snapshot()
	var candidates: Array=initial.encounter.combat.actors.filter(func(actor):return actor.active and actor.population_group=="freighter" and actor.vitals.hull>0)
	candidates.sort_custom(func(a,b):return a.pose.origin.distance_squared_to(initial.player_pose.origin)<b.pose.origin.distance_squared_to(initial.player_pose.origin))
	if candidates.is_empty():check(false,"The generated flight has no living target");return false
	var id:=int(candidates[0].actor_id);var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var captured:=false;var guided:=false;var hit:=false;var first_shot_us:=-1
	while now_us-started<240000000:
		var state: Dictionary=app.session.snapshot();var actor: Dictionary=state.encounter.combat.actors[id]
		if app.session.flight_owner().death_active():check(false,"The thermal pilot died before the hit");return false
		var distance: float=actor.pose.origin.distance_to(state.player_pose.origin)
		var acquired: bool=state.npc_scanner.selected_actor_id==id
		var input:={"commands":PiratePilot.Steering.steering_toward(state.player_pose,actor.pose.origin),"throttle":1.0 if distance>8000.0 else 0.0,"fire":acquired and distance<14000.0 and not hit,"strafe":0.0}
		var markers: Array=state.npc_scanner.markers.filter(func(marker):return marker.actor_id==id and marker.in_view)
		if not markers.is_empty():
			var offset:=Vector2(markers[0].pixels-state.npc_scanner.aim_pixels)
			input.commands=Vector2(clampf(offset.y/300.0,-1.0,1.0),clampf(-offset.x/300.0,-1.0,1.0))
		if not pirate_step(input):return false
		var after: Dictionary=app.session.snapshot();var shots: Dictionary=after.encounter.primaries.guns[0].projectiles
		var previous: Dictionary=state.encounter.primaries.guns[0].projectiles
		for index in shots.slots.size():
			var shot: Variant=shots.slots[index];var old: Variant=previous.slots[index]
			if shot==null:continue
			if first_shot_us<0:first_shot_us=now_us
			if old!=null and shot.id==old.id and not shot.velocity.is_equal_approx(old.velocity) and acquired:guided=true
		for gun in after.encounter.get("primary_contacts",[]):
			if gun.contacts.any(func(contact):return contact.target.group=="npc" and contact.target.index==id):hit=true
		if not captured and first_shot_us>=0 and now_us-first_shot_us>=500000:
			check(shots.trails.any(func(trail):return not trail.is_empty() and trail.sections.size()>1),"Thermal flight did not retain moving ribbon sections")
			await capture_free_application("thermal-guided-trails")
			var paused: Dictionary=shots.duplicate(true)
			check(app.session.set_pause("user",true,now_us),app.session.error)
			now_us+=1000000
			check(app.session.step(now_us) and app.session.snapshot().encounter.primaries.guns[0].projectiles==paused,"Pause moved or aged thermal shots/trails")
			check(app.session.set_pause("user",false,now_us),app.session.error)
			captured=true
		if hit and guided and captured:
			var damaged: Dictionary=after.encounter.combat.actors[id]
			check(damaged.vitals!=candidates[0].vitals and damaged.systems==candidates[0].systems,"Thermal hit did not use normal damage")
			var sound:=int(definitions.weapon_parameters.audio.player_event_ids[28])
			check(app.session.flight_audio.snapshot().history.any(func(event):return event.get("source_id")==sound and event.get("item_id")==28),"Thermal fire omitted the original weapon sound")
			await capture_free_application("thermal-target-hit")
			print("Thermal hit: ",{"target":id,"before":candidates[0].vitals,"after":damaged.vitals,"elapsed":(now_us-started)/1000000.0})
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("Thermal pilot: ",{"elapsed":(now_us-started)/1000000.0,"target":id,"distance":distance,"acquired":acquired,"guided":guided,"hit":hit})
			next_log=now_us+10000000
	check(false,"Input thermal fire failed to acquire, guide and hit the generated target");return false
