extends "res://tests/cargo_scanner_application.gd"
## Earned purchase, aimed projectile contacts, nonlethal disable and saved fitting.

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_EMP_PRIMARY_RESUMED")=="1"
	var item:=17;var price:=0;var proceeds:=0
	if not resumed:
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		var offers: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==item and row.stock>0)
		var spare: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==0 and row.owned>0)
		if offers.size()!=1 or spare.size()!=1:check(false,"The earned shop lacks the EMP gun or owned spare");return
		price=int(offers[0].unit_price);proceeds=int(spare[0].unit_price)
		if not app.equipment_action("sell",0) or not app.equipment_action("buy",item):check(false,app.session.error);return
		for slot in quote.loadout.slots:
			if slot!=null and slot.category==0:
				if not app.equipment_action("unmount",slot.item_id):check(false,app.session.error);return
		if not app.equipment_action("mount",item):check(false,app.session.error);return
		for change in [[91,81],[86,55]]:
			if not app.equipment_action("unmount",change[0]) or not app.equipment_action("mount",change[1]):check(false,app.session.error);return
		var mounted: Dictionary=app.session.station_owner().snapshot()
		check(mounted.contracts.credits==quote.contracts.credits+proceeds-price and mounted.cargo.entries.has({"item_id":2,"quantity":1}),"The EMP purchase lost the spare sale price or retained primary")
		await capture_free_application("emp-primary-purchased-fitted")
		if not app.equipment_action("close"):check(false,app.session.error);return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(item) and fitted.loadout.equipment_ids.has(81) and fitted.loadout.equipment_ids.has(55),"The actual EMP fitting lost its scanner or armor")
	check(fitted.contracts.completed_side_missions==original.contracts.completed_side_missions and fitted.mission==original.mission,"Fitting an EMP gun advanced a mission")
	if failures or not retain_recovery_save("fitted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var flight: Dictionary=app.session.snapshot()
	check(flight.encounter.primaries.guns.size()==1 and flight.encounter.primaries.guns[0].projectiles.weapon.item_id==item,"Departure fired a different or extra primary")
	var candidates: Array=flight.encounter.combat.actors.filter(func(actor):return actor.active and actor.population_group=="freighter" and actor.systems.integrity>0)
	candidates.sort_custom(func(a,b):return a.position.distance_squared_to(flight.player_pose.origin)<b.position.distance_squared_to(flight.player_pose.origin))
	if candidates.is_empty():check(false,"The generated flight has no living freighter to disable");return
	if not await disable_with_primary(candidates[0]):return
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.cargo==fitted.cargo and landed.contracts.credits==fitted.contracts.credits,"EMP fire changed owned cargo, fitting or credits")
	check(landed.contracts.completed_side_missions==original.contracts.completed_side_missions and landed.mission==original.mission,"Disabling a ship completed a job or changed the story")
	if not retain_recovery_save("returned"):return
	await capture_free_application("emp-primary-saved-station")
	print("EMP primary saved: ",{"item":item,"price":price,"sale":proceeds,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor})

func disable_with_primary(initial: Dictionary) -> bool:
	var id:=int(initial.actor_id);var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var captured:=false;var fired:=false;var hit:=false
	while now_us-started<240000000:
		var state: Dictionary=app.session.snapshot();var actor: Dictionary=state.encounter.combat.actors[id]
		if app.session.flight_owner().death_active():check(false,"The EMP pilot died before disabling the target");return false
		if actor.systems.integrity<initial.systems.integrity:hit=true
		check(actor.vitals.hull==initial.vitals.hull and actor.vitals.armor==initial.vitals.armor,"EMP projectiles damaged the target's hull or armor")
		if failures:return false
		if actor.systems.disabled:
			check(fired and hit and actor.systems_disabled,"Aimed EMP fire did not disable the target's movement")
			var sound:=int(definitions.weapon_parameters.audio.player_event_ids[17])
			check(app.session.flight_audio.snapshot().history.any(func(event):return event.get("source_id")==sound and event.get("item_id")==17),"The purchased EMP gun omitted its original firing sound")
			await capture_free_application("emp-primary-disabled-target")
			print("EMP target disabled: ",{"actor":id,"hull":actor.vitals.hull,"integrity":actor.systems.integrity,"elapsed":(now_us-started)/1000000.0})
			return failures==0
		var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
		pilot.firing_range=float(weapon.speed_units_per_millisecond)*float(weapon.lifetime_ms)*0.9
		var input: Dictionary=pilot.controls_at_time(state,float(state.world_elapsed_ms),[id])
		input.throttle=1.0 if input.distance>14000.0 else 0.0;input.strafe=0.0
		if input.fire:fired=true
		if not pirate_step(input):return false
		if not captured and state.encounter.primaries.guns[0].projectiles.slots.any(func(slot):return slot!=null):
			await capture_free_application("emp-primary-live-projectiles");captured=true
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("EMP pilot: ",{"elapsed":(now_us-started)/1000000.0,"target":id,"distance":input.distance,"systems":actor.systems.integrity,"hull":actor.vitals.hull})
			next_log=now_us+10000000
	check(false,"Input-only EMP fire did not disable the generated target");return false
