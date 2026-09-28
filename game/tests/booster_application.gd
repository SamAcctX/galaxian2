extends "res://tests/beam_primary_application.gd"
## Actual earned purchase, input, boosted flight, pause, docking and saved fitting.

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_BOOSTER_RESUMED")=="1"
	var item:=-1;var price:=0
	if not resumed:
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		var offers: Array=quote.equipment.market_rows.filter(func(row):return row.stock>0 and row.unit_price<=quote.contracts.credits and catalogue.tables.items[row.item_id].properties.get(2)==14 and quote.equipment.fitting_support[row.item_id].is_empty())
		offers.sort_custom(func(a,b):return a.unit_price<b.unit_price)
		print("Actual booster shop: ",offers.map(func(row):return {"item":row.item_id,"price":row.unit_price,"stock":row.stock}))
		if offers.is_empty():check(false,"The earned supplier offered no affordable admitted booster");return
		item=int(offers[0].item_id);price=int(offers[0].unit_price)
		if not app.equipment_action("buy",item) or not app.equipment_action("unmount",57) or not app.equipment_action("mount",item):check(false,app.session.error);return
		var bought: Dictionary=app.session.station_owner().snapshot()
		check(bought.contracts.credits==quote.contracts.credits-price and bought.cargo.entries.has({"item_id":57,"quantity":1}),"Booster purchase changed its quote or discarded the removed armor")
		app.equipment_panel.select_tab("ship")
		await capture_free_application("booster-purchased-fitted")
		if not app.equipment_action("close"):check(false,app.session.error);return
	else:
		var equipped: Array=original.loadout.equipment_ids.filter(func(id):return catalogue.tables.items[id].properties.get(2)==14)
		if equipped.size()!=1:check(false,"Fresh Resume lost the purchased booster");return
		item=equipped[0]
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(item) and fitted.contracts.passengers==3 and fitted.contracts.mission==original.contracts.mission,"Booster fitting changed its device or the passenger job")
	if failures or not retain_recovery_save("fitted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await boost_with_input(resumed):return
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.cargo==fitted.cargo and landed.contracts.credits==fitted.contracts.credits,"Boosting or docking changed equipment, cargo or wallet")
	check(landed.contracts.passengers==3 and landed.contracts.mission==original.contracts.mission and landed.campaign_cursor==45,"Booster flight changed the campaign or passenger job")
	if not retain_recovery_save("returned"):return
	var document: Dictionary=app._save_file.load_document(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("returned.gof2save"),definitions,catalogue,source)
	check(not document.is_empty(),"The actual booster return save could not be reopened")
	await capture_free_application("booster-saved-station")
	print("Booster saved: ",{"item":item,"price":price,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor,"passengers":landed.contracts.passengers,"cadence":_pilot_deltas})

func boost_with_input(controller: bool) -> bool:
	var initial: Dictionary=app.session.snapshot()
	check(initial.booster.ready and initial.booster.activation==0,"Station departure retained a previous flight's cooldown")
	check(app._boost_button.visible,"The fitted original booster indicator is missing")
	await capture_free_application("booster-ready")
	for adjustment in 6:
		if not app.session.action("throttle_down"):check(false,app.session.error);return false
	var input: InputEvent
	if controller:
		var button:=InputEventJoypadButton.new();button.button_index=JOY_BUTTON_A;button.pressed=true;input=button
	else:
		var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=true;input=key
	resume_application_focus();app._unhandled_input(input)
	check(app.session._boost_requested,"W/controller A did not queue boost")
	now_us+=pirate_delta_us()
	if not app.session.step(now_us):check(false,app.session.error);return false
	input.pressed=false;app._unhandled_input(input);app.present_session()
	var active: Dictionary=app.session.snapshot()
	check(active.booster.active and active.booster.activation==1 and active.input_throttle==1.0,"Boost did not start on the late input pass at full throttle")
	var source_id:=int(active.booster.sound_id)
	check(app.session.flight_audio.snapshot().history.any(func(event):return event.get("source_id")==source_id and event.get("action")=="start"),"Boost omitted its original sample")
	var captured:=false;var measured:=false;var next_yield:=now_us+1000000
	while app.session.snapshot().booster.active:
		var before: Dictionary=app.session.snapshot()
		if not pirate_step({"commands":Vector2.ZERO,"throttle":1.0,"fire":false,"strafe":0.0}):return false
		var after: Dictionary=app.session.snapshot()
		if after.booster.active and not measured:
			var expected:=2.0*float(after.booster.motion_multiplier)*float(after.world_elapsed_ms-before.world_elapsed_ms)
			check(absf(after.player_pose.origin.distance_to(before.player_pose.origin)-expected)<0.2,"Actual booster travel did not use its original forward speed")
			measured=true
		if after.booster.envelope>=0.9 and not captured:
			captured=true
			check(after.engine_particles.mode=="boost" and after.engine_particles.boost_envelope>=0.9,"Visible exhaust did not follow the booster envelope")
			await capture_free_application("booster-active-exhaust")
			var held: Dictionary=app.session.snapshot()
			check(app.session.set_pause("user",true,now_us),app.session.error);now_us+=1000000
			check(app.session.step(now_us) and app.session.snapshot().booster==held.booster and app.session.snapshot().engine_particles==held.engine_particles,"Pause advanced boost, recharge or exhaust")
			check(app.session.set_pause("user",false,now_us),app.session.error)
			# Repeated discrete input must not extend boost or replay its sample.
			var activation: int=held.booster.activation
			if not app.session.action("boost") or not pirate_step({"commands":Vector2.ZERO,"throttle":1.0,"fire":false,"strafe":0.0}):return false
			check(app.session.snapshot().booster.activation==activation,"Active boost restarted on another press")
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	check(captured and measured,"Boost never reached visible and moving flight")
	var cooling: Dictionary=app.session.snapshot()
	check(cooling.booster.remaining_ms>0 and cooling.engine_particles.mode=="normal","Expiry did not restore ordinary exhaust and start recharge")
	await capture_free_application("booster-recharging")
	if not app.session.action("boost") or not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
	check(app.session.snapshot().booster.activation==1,"Cooldown press consumed another activation")
	while not app.session.snapshot().booster.ready:
		if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	await capture_free_application("booster-recharged")
	print("Booster flight: ",app.session.snapshot().booster)
	return failures==0
