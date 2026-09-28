extends "res://tests/ship_purchase_application.gd"
## An earned career buys a turret hull and weapon, then fires from the mount.
func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor>=18

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	if original.contracts.passengers>0:
		var destination:=int(original.contracts.mission.station_id)
		if not await visit_tractor_supplier(destination) or not application_step():return
		if not app.session.snapshot().contracts.pending_result.is_empty():await acknowledge_recovery_result()
		if not retain_recovery_save("passengers-delivered"):return
		original=app.session.station_owner().snapshot()
		check(original.contracts.passengers==0 and original.contracts.mission.is_empty(),"The earned passengers did not reach their destination")
	if OS.get_environment("GOF2_TURRET_PREPARE")=="1":
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		print("Turret purchase planning: ",{"station":quote.loadout.station_id,"credits":quote.contracts.credits,"hulls":quote.equipment.market_ships,"owned":quote.equipment.market_rows.filter(func(row):return row.owned>0),"turrets":quote.equipment.market_rows.filter(func(row):return row.item_id in [47,48,49])})
		if not app.equipment_action("close") or not retain_recovery_save("prepared"):return
		await capture_free_application("turret-earned-budget")
		return
	var destination:=OS.get_environment("GOF2_TURRET_SUPPLIER")
	if not destination.is_empty() and int(original.loadout.station_id)!=destination.to_int():
		if not await visit_tractor_supplier(destination.to_int()):return
	if not retain_recovery_save("supplier"):return
	if not app.session.station_owner().snapshot().loadout.equipment_ids.has(47):
		if not await buy_turret():return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	if not retain_recovery_save("fitted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	await capture_free_application("turret-mounted-hull")
	if not await fire_turret():return
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.contracts.credits==fitted.contracts.credits and landed.campaign_cursor==fitted.campaign_cursor,"Turret flight changed the fitting, wallet or campaign")
	if not retain_recovery_save("returned"):return
	await capture_free_application("turret-saved-station")
	print("Turret saved: ",{"ship":landed.loadout.ship_id,"items":landed.loadout.equipment_ids,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor,"cadence":_pilot_deltas})

func buy_turret() -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var quote: Dictionary=app.session.station_owner().snapshot()
	var offers: Array=quote.equipment.market_ships.filter(func(row):return catalogue.tables.ships[row.ship_id].stats.turret_slots>0)
	var turret: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==47 and row.stock>0)
	print("Actual turret market: ",{"station":quote.loadout.station_id,"wallet":quote.contracts.credits,"hulls":quote.equipment.market_ships,"turrets":turret,"owned":quote.equipment.market_rows.filter(func(row):return row.owned>0)})
	if offers.is_empty() or turret.is_empty():check(false,"This actual Hangar has no turret/hull pair");return false
	offers.sort_custom(func(a,b):return a.unit_price<b.unit_price)
	var offer: Dictionary=offers[0]
	var price:=int(offer.unit_price)+int(turret[0].unit_price)-int(quote.loadout.ship_instance.unit_price)
	for id in [64,9,91,57,2]:
		var current: Dictionary=app.session.station_owner().snapshot()
		if current.contracts.credits>=price:break
		if current.loadout.equipment_ids.has(id) and not app.equipment_action("unmount",id):check(false,app.session.error);return false
		if app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==id):
			if not app.equipment_action("sell",id):check(false,app.session.error);return false
	quote=app.session.station_owner().snapshot()
	if quote.contracts.credits<price:check(false,"The earned sales cannot afford this turret and hull");return false
	# Own the turret before exchange to cover a legitimate no-slot refusal.
	if not app.equipment_action("buy",47):check(false,app.session.error);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	check(not app.equipment_action("mount",47) and app.session.station_owner().snapshot()==before,"Betty accepted a turret or lost the bought weapon")
	await capture_free_application("turret-no-slot-refusal")
	var index: int=quote.equipment.market_ships.find(offer)
	await activate_ship_control(app.equipment_panel._ship_offers[index].button,true)
	await activate_ship_control(app.equipment_panel._replacement.get_ok_button())
	check(app.session.station_owner().snapshot().loadout.ship_id==offer.ship_id,"The turret hull exchange failed")
	if failures or not app.equipment_action("mount",47):check(false,app.session.error);return false
	if app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==2):
		if not app.equipment_action("mount",2):check(false,app.session.error);return false
	app.equipment_panel.select_tab("ship")
	await capture_free_application("turret-bought-fitted")
	if not app.equipment_action("close"):check(false,app.session.error);return false
	return true

func turret_key(code:=KEY_T) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down
		app._unhandled_input(event)
	await process_frame;resume_application_focus()

func enter_turret() -> bool:
	if OS.get_environment("GOF2_TURRET_MOUSE")=="1":
		await turret_key(KEY_E)
		var rows: Array=app.flight_menu.snapshot().rows
		var index: int=rows.find(rows.filter(func(row):return row.action=="turret").front()) if rows.any(func(row):return row.action=="turret") else -1
		if index<0:check(false,"The equipped turret is absent from the flight menu");return false
		var point: Vector2=root.get_final_transform()*app.flight_menu._buttons[index].get_global_rect().get_center()
		for down in [true,false]:
			var click:=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
			root.push_input(click,true)
		await process_frame;resume_application_focus()
	else:await turret_key()
	check(app.session.turret_state().active,"The turret control did not enter the mounted view")
	# UI pause edges sample wall time; the deterministic pilot resumes its own
	# monotonic clock before delivering the next high-rate steering sample.
	app.session.rebase_time(now_us)
	var before: Dictionary=app.session.snapshot()
	var event:=InputEventKey.new();event.physical_keycode=KEY_RIGHT;event.pressed=true;app._unhandled_input(event)
	var input: Dictionary=app._controls.snapshot()
	if not pirate_step({"commands":input.command,"throttle":0.0,"fire":false,"strafe":0.0}):return false
	event.pressed=false;app._unhandled_input(event)
	check(app.session.turret_state().yaw!=before.turret.yaw and app.session.snapshot().player_pose.basis.is_equal_approx(before.player_pose.basis),"Keyboard steering failed to turn only the turret")
	return failures==0

func fire_turret() -> bool:
	var initial: Dictionary=app.session.snapshot()
	check(initial.turret.ready and not initial.turret.active,"Fresh flight retained turret mode or lost its equipped mount")
	# Approach a real destructible asteroid, then stop and aim rearward at it.
	var candidates: Array=initial.scenery.objects.filter(func(row):return row.source_size_value!=7 and initial.scenery.bodies.objects[row.index].active)
	candidates.sort_custom(func(a,b):return a.position.distance_squared_to(initial.player_pose.origin)<b.position.distance_squared_to(initial.player_pose.origin))
	if candidates.is_empty():check(false,"The flight has no destructible target");return false
	var target: int=candidates[0].index;var position: Vector3=candidates[0].position
	var started:=now_us;var next_yield:=now_us
	while now_us-started<180000000:
		var state: Dictionary=app.session.snapshot();var distance: float=state.player_pose.origin.distance_to(position)
		var direction: Vector3=(position-state.player_pose.origin).normalized()
		if distance<14000 and state.player_pose.basis.z.dot(direction)>0.99995:break
		if not pirate_step({"commands":PiratePilot.Steering.steering_toward(state.player_pose,position),"throttle":1.0 if distance>=14000 else 0.0,"fire":false,"strafe":0.0}):return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	for tick in 5:
		if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
	if not await enter_turret():return false
	var hull_pose: Transform3D=app.session.snapshot().player_pose
	print("Turret target: ",{"index":target,"position":position,"distance":position.distance_to(hull_pose.origin)})
	started=now_us;next_yield=now_us;var shot_seen:=false
	while now_us-started<45000000:
		var state: Dictionary=app.session.snapshot();var mounted: Dictionary=state.turret
		var aim: Transform3D=app.session.flight_owner().encounter_owner().turret_aim_pose(state.player_pose)
		var local: Vector3=aim.basis.inverse()*(position-aim.origin)
		var angle:=Vector2(-atan2(local.y,sqrt(local.x*local.x+local.z*local.z)),atan2(local.x,local.z))
		var command:=Vector2(clampf(angle.x*2,-1,1),clampf(angle.y*2,-1,1))
		if not pirate_step({"commands":command,"throttle":0.0,"fire":angle.length()<0.035,"strafe":0.0}):return false
		var after: Dictionary=app.session.snapshot()
		check(after.player_pose.basis.is_equal_approx(hull_pose.basis),"Manual turret input rotated the hull")
		var gun: Dictionary=after.encounter.primaries.guns.filter(func(row):return row.equipment.category==2)[0]
		if not shot_seen and gun.projectiles.slots.any(func(slot):return slot!=null):
			shot_seen=true;await capture_free_application("turret-firing")
		var hits: Array=after.encounter.primary_contacts.filter(func(row):return row.item_id==47 and not row.contacts.is_empty())
		if hits.any(func(row):return row.contacts.any(func(hit):return hit.get("target",{}).get("group")=="scenery" or hit.get("group")=="scenery")) or not after.scenery.bodies.objects[target].active:
			check(shot_seen,"A target was damaged before a visible turret shot")
			var sound:=int(definitions.weapon_parameters.audio.player_event_ids[47])
			check(app.session.flight_audio.snapshot().history.any(func(event):return event.get("source_id")==sound and event.get("item_id")==47),"Turret fire omitted its original sound")
			await capture_free_application("turret-impact")
			await turret_key()
			check(not app.session.turret_state().active,"T did not restore the flight view")
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	await capture_free_application("turret-target-missed")
	check(false,"Input-aimed turret shots did not hit the real scenery")
	return false
