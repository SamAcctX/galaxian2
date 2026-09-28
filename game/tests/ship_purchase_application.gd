extends "res://tests/automatic_tractor_application.gd"
## Paid native career, real supplier travel, confirmed trade-in and saved flight.

func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor>=18 and state.contracts.mission.is_empty() and state.contracts.passengers==0

func uses_pilot_cadence() -> bool:return app.session is FlightSession

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	if OS.get_environment("GOF2_SHIP_RESUMED")!="1":
		if original.loadout.station_id!=10 and not await visit_tractor_supplier(10):return
		if not retain_recovery_save("supplier"):return
		if not app.equipment_action("open"):check(false,app.session.error);return
		var starter:=OS.get_environment("GOF2_SHIP_STARTER")
		if starter in ["standard","alternate"]:
			var weapon:=0 if starter=="standard" else 22
			if not app.equipment_action("unmount",2) or not app.equipment_action("sell",2) or not app.equipment_action("mount",weapon):check(false,app.session.error);return
		var quoted: Dictionary=app.session.station_owner().snapshot();var selected:=-1
		print("Available earned sales: ",quoted.equipment.market_rows.filter(func(row):return row.owned>0))
		if not quoted.equipment.market_ships.any(func(row):return row.ship_id!=quoted.loadout.ship_id and row.unit_price<=quoted.contracts.credits+quoted.loadout.ship_instance.unit_price):
			check(not app.equipment_action("buy_ship",0) and app.session.station_owner().snapshot()==quoted,"An unaffordable hull changed the real wallet or inventory")
			await capture_free_application("ship-purchase-unaffordable")
			# Sell only actual spares, then the unoccupied cabin if still needed.
			for id in [22,0,91]:
				var current: Dictionary=app.session.station_owner().snapshot()
				if current.equipment.market_ships.any(func(row):return row.ship_id!=current.loadout.ship_id and row.unit_price<=current.contracts.credits+current.loadout.ship_instance.unit_price):break
				if id==91 and current.loadout.equipment_ids.has(id):
					if not app.equipment_action("unmount",id):check(false,app.session.error);return
				if app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==id):
					if not app.equipment_action("sell",id):check(false,app.session.error);return
			quoted=app.session.station_owner().snapshot()
		for i in quoted.equipment.market_ships.size():
			var offer: Dictionary=quoted.equipment.market_ships[i]
			if offer.ship_id!=quoted.loadout.ship_id and int(offer.unit_price)<=int(quoted.contracts.credits)+int(quoted.loadout.ship_instance.unit_price):selected=i;break
		print("Purchase supplier: ",{"wallet":quoted.contracts.credits,"current":quoted.loadout.ship_instance,"offers":quoted.equipment.market_ships})
		if selected<0:check(false,"The earned supplier has no affordable hull");return
		var offer: Dictionary=quoted.equipment.market_ships[selected]
		await capture_free_application("ship-market-offers")
		await activate_ship_control(app.equipment_panel._ship_offers[selected].button,true)
		check(app.equipment_panel._replacement.visible and app.session.station_owner().snapshot()==quoted,"Selecting Buy skipped confirmation")
		await capture_free_application("ship-purchase-confirmation")
		await activate_ship_control(app.equipment_panel._replacement.get_cancel_button())
		await process_frame;resume_application_focus()
		check(app.session.station_owner().snapshot()==quoted and not app.equipment_panel._replacement.visible,"Cancelling the trade-in changed ownership or kept confirmation open")
		if failures:return
		await activate_ship_control(app.equipment_panel._ship_offers[selected].button)
		check(app.equipment_panel._replacement.visible and not app.equipment_panel._pending_replace.is_empty(),"Keyboard Purchase did not reopen confirmation")
		if failures:return
		await activate_ship_control(app.equipment_panel._replacement.get_ok_button(),true)
		await process_frame;resume_application_focus()
		var bought: Dictionary=app.session.station_owner().snapshot()
		check(bought.loadout.ship_id==offer.ship_id and bought.contracts.credits==quoted.contracts.credits+quoted.loadout.ship_instance.unit_price-offer.unit_price,"The confirmed exchange did not buy its exact quoted hull")
		check(quantities(bought.equipment)==quantities(quoted.equipment),"The exchange lost owned equipment or cargo")
		check(bought.contracts.mission==original.contracts.mission and bought.campaign_cursor==original.campaign_cursor,"Buying a ship changed a mission")
		check(app.session.geometry.ship_model.get_meta("source_ship_id")==offer.ship_id,"The station still displays the old hull")
		app.equipment_panel.select_tab("ship");await capture_free_application("ship-purchased-fitted")
		if failures or not app.equipment_action("close"):return
		if not retain_recovery_save("purchased"):return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var flown: Dictionary=app.session.snapshot()
	check(flown.player.ship_id==fitted.loadout.ship_id and flown.player.equipment_ids==fitted.loadout.equipment_ids,"Flight lost the purchased hull or fitting")
	for i in 25:
		if not pirate_step({"commands":Vector2(0.15,-0.25),"throttle":1.0,"fire":i<3,"strafe":0.0}):return
	await capture_free_application("purchased-ship-flight")
	if OS.get_environment("GOF2_SHIP_TRACTOR")=="1" and not await recover_automatic_scenery(false):return
	var returning: Dictionary=app.session.snapshot()
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.cargo==returning.cargo and landed.contracts.credits==fitted.contracts.credits,"Docking lost the purchased hull/cargo or repeated the exchange")
	if not retain_recovery_save("returned"):return
	await capture_free_application("purchased-ship-saved")
	print("Purchased ship returned: ",{"ship":landed.loadout.ship_id,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor,"timing":_pilot_deltas})

func activate_ship_control(control: Control,pointer:=false) -> void:
	await process_frame;resume_application_focus()
	var viewport:=control.get_viewport()
	control.grab_focus()
	if pointer:
		var point:=control.get_global_rect().get_center()
		if viewport!=root:point+=Vector2(viewport.position)
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
		root.push_input(motion,true)
		for down in [true,false]:
			var click:=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
			root.push_input(click,true)
	else:
		for down in [true,false]:
			var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=down
			viewport.push_input(key,true)
	await process_frame;resume_application_focus()

func quantities(state: Dictionary) -> Dictionary:
	var result:={}
	for row in state.cargo.entries:result[row.item_id]=int(result.get(row.item_id,0))+int(row.quantity)
	for slot in state.loadout.slots:
		if slot!=null:result[slot.item_id]=int(result.get(slot.item_id,0))+int(slot.quantity)
	return result
