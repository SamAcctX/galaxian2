extends "res://tests/void_crystal_route_application.gd"
## Return the genuinely mined hold through paid fitting and physical travel.
## Temporary market trades make fitting space; no cargo or progress is injected.
const ReturnNavigation=preload("res://src/simulation/system_navigation.gd")
var return_original: Dictionary={}

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(saved)
	return_original=app.session.station_owner().snapshot()
	var original: Dictionary=return_original
	check(not input_hash.is_empty() and original.campaign_cursor==33 and original.contracts.has("void_source"),"Resume the genuine mined crystal-return career")
	check(full_crystal_hold(original) and original.loadout.equipment_ids.has(64) and original.loadout.equipment_ids.has(91),"The return lost its fifty crystals, paid hold or occupied cabin")
	check(original.contracts.passengers==3 and original.contracts.mission.kind==11 and original.contracts.mission.station_id==99,"The return lost its accepted passenger job")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Set a private crystal-return save directory")
	if failures:return
	var clock:=OS.get_environment("GOF2_ALIOTH_WORLD_BASE")
	if not clock.is_empty():
		check(clock.is_valid_int() and clock.to_int()>=0 and clock.to_int()<2147480000,"Use the recorded return-route world clock")
		if failures:return
		_world_clock_base=clock.to_int()
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	var navigation:=ReturnNavigation.new()
	var gates:=0
	for hop in 16:
		var station: Dictionary=app.session.station_owner().snapshot()
		if station.loadout.station_id==10:break
		if not prepare_full_hold_return():return
		if not retain_chapter_save("crystal33-return-prepared-"+str(station.loadout.station_id)):return
		if OS.get_environment("GOF2_CRYSTAL_RETURN_PREPARATION_ONLY")=="1":
			check(FileAccess.get_sha256(saved)==input_hash,"Return fitting overwrote the immutable mined input")
			await capture_free_application("earned-crystal33-return-prepared")
			print("Earned full50t return fitting and save/reload only; travel and hand-in not exercised")
			return
		if not await depart_crystal_route():return
		var flying: Dictionary=app.session.snapshot()
		if not navigation.configure(definitions,catalogue,flying.contracts.lounges.system_availability):check(false,navigation.error);return
		var course: Dictionary=navigation.course(int(flying.location.station_id),10)
		if course.is_empty():check(false,navigation.error);return
		print("Earned full-hold crystal return ",flying.location.station_id," ->10 course ",course.system_path," guidance ",course.guidance)
		var target:=-1
		if course.guidance.kind=="planet":
			target=int(course.guidance.station_id)
			if not await travel_application(target):return
		elif course.guidance.kind=="gate":
			var system_id: int=int(course.system_path[1])
			target=int(catalogue.tables.systems[system_id].fields[int(definitions.mido_travel.free_navigation.gate_station_field)])
			if not await expedition_gate(system_id,target):return
			gates+=1
		else:check(false,"The crystal return has no real navigation leg");return
		var arrival: Dictionary=app.session.snapshot()
		check(arrival.campaign_cursor==33 and full_crystal_hold(arrival) and arrival.player.vitals.hull>0,"The real return lost crystals, the living ship or pending hand-in")
		check(arrival.contracts.credits==route_credits and arrival.contracts.mission==retained_job and arrival.contracts.passengers==3 and arrival.contracts.blueprints==original.contracts.blueprints,"The real return changed unrelated career progress")
		check(arrival.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+gates,"The real return lost an actual jumpgate")
		if failures or not await dock_with_paid_emp(10000,false,1000.0):return
		var landed: Dictionary=app.session.station_owner().snapshot()
		check(landed.loadout.station_id==target and full_crystal_hold(landed) and landed.contracts.credits==route_credits,"Actual return docking changed its station, full hold or paid wallet")
		if failures:return
		if target!=10 and not retain_chapter_save("crystal33-return-"+str(target)):return
		await capture_free_application("earned-crystal33-return-"+str(target))
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout.station_id==10 and landed.campaign_cursor==33 and full_crystal_hold(landed),"The actual full-hold journey did not reach Thynome")
	if failures or not await acknowledge_station_chapter(33):return
	var delivered: Dictionary=app.session.station_owner().snapshot()
	check(delivered.campaign_cursor==34 and delivered.loadout==landed.loadout and delivered.cargo.used==0 and delivered.cargo.entries.is_empty(),"Thynome final Next did not consume exactly the earned fifty crystals")
	check(delivered.mission==PostProbeCampaign.PostProbe.mission_values(definitions.mido_travel.void_crystals.next_mission) and delivered.contracts.credits==route_credits and delivered.reward_credits==0,"The crystal hand-in changed the next mission or invented a cash reward")
	check(delivered.contracts.mission==retained_job and delivered.contracts.passengers==3 and delivered.contracts.void_source==landed.contracts.void_source and delivered.contracts.travel_statistics==landed.contracts.travel_statistics,"The crystal hand-in changed unrelated passengers, source or travel history")
	var expected_blueprints: Dictionary=landed.contracts.blueprints.duplicate(true)
	var material_index: int=Array(catalogue.tables.items[85].arrays[0]).find(164)
	check(material_index>=0,"The source Khador Drive recipe lost its crystal material")
	if failures:return
	for row in expected_blueprints.entries:
		if row.item_id==85:
			row.available=true;row.remaining[material_index]-=50
			row.material_value+=50*int(catalogue.tables.items[164].properties[7])
	check(not delivered.loadout.equipment_ids.has(85) and delivered.contracts.blueprints==expected_blueprints,"The crystal hand-in changed the exact blueprint precredit or installed an unearned drive")
	var owner: RefCounted=app.session.station_owner()
	check(not owner.acknowledge() and not owner.begin_campaign_conversation(definitions,catalogue,source) and owner.snapshot()==delivered,"The crystal hand-in committed or opened twice")
	check(FileAccess.get_sha256(saved)==input_hash,"The return overwrote its immutable mined input")
	if failures or not retain_chapter_save("thynome34-crystals-delivered"):return
	await capture_free_application("earned-thynome34-crystals-delivered")
	if not app.equipment_action("open") or not app.equipment_action("close"):check(false,app.status.text);return
	check(app.session.station_owner().snapshot().contracts.blueprints==expected_blueprints,"Browsing the acknowledged hangar changed the credited blueprint")
	if failures or not await depart_crystal_route():return
	var departed: Dictionary=app.session.snapshot()
	check(departed.campaign_cursor==34 and departed.location.station_id==10 and departed.mission==delivered.mission and not departed.dialogue.visible and app.session.can_control(),"The acknowledged Thynome station could not release ordinary flight")
	check(departed.cargo==delivered.cargo and departed.contracts.blueprints==expected_blueprints and departed.contracts.credits==route_credits and departed.contracts.mission==retained_job and departed.contracts.passengers==3,"Ordinary departure lost the actual crystal hand-in or passenger career")
	if failures or not app.open_map(now_us):check(false,app.status.text);return
	var mapped: Dictionary=app.session.snapshot()
	check(PostProbeNavigation.destination_supported(definitions,34,delivered.mission,30)==PostProbeCampaign.nehma_available(definitions.mido_travel),"The retained next mission bypassed Nehma's station capability")
	# Nehma is still remote from Thynome's local map; chapter admission is not teleportation.
	check(not app.session.confirm_map_planet(30,now_us) and app.session.snapshot()==mapped,"The retained next mission bypassed actual travel to Nehma")
	if failures or not app.close_map(now_us):check(false,app.status.text);return
	await capture_free_application("earned-thynome34-ordinary-departure")
	print("Earned actual crystal return ->nine original lines ->atomic50-crystal hand-in ->mission34 save/reload, hangar and ordinary departure")

func full_crystal_hold(state: Dictionary) -> bool:
	var cargo: Dictionary=state.cargo
	return cargo.capacity==50 and cargo.used==50 and cargo.entries.size()==1 and cargo.entries[0].item_id==164 and cargo.entries[0].quantity==50

func prepare_full_hold_return() -> bool:
	if not app.equipment_action("open"):check(false,app.status.text);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	check(full_crystal_hold(before),"Return preparation requires its untouched full crystal hold")
	var panel: Control=app.equipment_panel
	var stock: Array=before.equipment.market_rows
	print("Earned return station ",before.loadout.station_id," defensive offers ",stock.filter(func(row):return row.item_id in [41,42,43,57,164]))
	if failures:return false
	# Selling and buying back through one real quote preserves the crystal stock
	# while making room for the ordinary cargo-first purchase/fitting controls.
	var crystal_stock: Array=stock.filter(func(row):return row.item_id==164)
	check(crystal_stock.size()==1,"The mined crystals have no ordinary market quote")
	if failures or not trade_return_item(164,"sell",20):return false
	if not before.loadout.equipment_ids.has(57):
		var slot:=-1
		for index in before.loadout.slots.size():
			if before.loadout.slots[index]!=null and before.loadout.slots[index].item_id==86:slot=index;break
		check(slot>=0 and panel._installed_rows.has(slot),"The full-hold return has neither transit armor nor its removable drill")
		if failures:return false
		panel.select_tab("ship");panel._installed_rows[slot].button.pressed.emit()
		var unmounted: Dictionary=app.session.station_owner().snapshot()
		check(not unmounted.loadout.equipment_ids.has(86) and unmounted.cargo.used==31,"The normal ship action did not demount the earned drill")
		if failures or not trade_return_item(86,"sell",1) or not trade_return_item(57,"buy",1):return false
		panel.select_tab("cargo")
		check(panel._rows.has(57) and not panel._rows[57].actions.mount.disabled,"The purchased return armor cannot enter the vacated drill slot")
		if failures:return false
		panel._rows[57].actions.mount.pressed.emit()
		var fitted: Dictionary=app.session.station_owner().snapshot()
		check(fitted.loadout.equipment_ids.has(57) and fitted.cargo.used==30 and fitted.equipment.fitting_stats.armor==110,"The purchased return armor was not fitted at its source-defined strength")
		if failures:return false
	var current: Dictionary=app.session.station_owner().snapshot()
	# The temporarily sold crystals are not a defence budget: reserve their
	# entire buyback cost before choosing any paid ammunition.
	var crystal_reserve:=20*int(crystal_stock[0].unit_price)
	var ammunition:=-1
	for candidate in [43,42,41]:
		if current.equipment.market_rows.any(func(row):return row.item_id==candidate and row.stock>0 and row.unit_price>0 and row.unit_price<=current.contracts.credits-crystal_reserve):ammunition=candidate;break
	if ammunition>=0:
		var launcher: Variant=current.loadout.slots[1]
		if launcher!=null:
			panel.select_tab("ship");panel._installed_rows[1].button.pressed.emit()
			var demounted: Dictionary=app.session.station_owner().snapshot()
			check(demounted.loadout.slots[1]==null and demounted.cargo.used==current.cargo.used+launcher.quantity,"The return launcher did not retain its actual remaining rounds")
			if failures:return false
			if launcher.item_id!=ammunition and not trade_return_item(int(launcher.item_id),"sell",int(launcher.quantity)):return false
		var quote: Dictionary=app.session.station_owner().snapshot()
		var offers: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==ammunition)
		var retained_rounds:=0
		for row in quote.cargo.entries:
			if row.item_id==ammunition:retained_rounds+=int(row.quantity)
		var quantity:=mini(maxi(0,12-retained_rounds),mini(int(offers[0].stock),mini(int(quote.cargo.free_space),int(float(quote.contracts.credits-crystal_reserve)/float(offers[0].unit_price)))))
		if quantity>0 and not trade_return_item(ammunition,"buy",quantity):return false
		panel.select_tab("cargo")
		check(panel._rows.has(ammunition) and not panel._rows[ammunition].actions.mount.disabled,"The paid return ammunition cannot be fitted")
		if failures:return false
		panel._rows[ammunition].actions.mount.pressed.emit()
		check(app.session.station_owner().snapshot().cargo.used==30,"Mounting return ammunition left unexpected cargo")
		if failures:return false
	if not trade_return_item(164,"buy",20):return false
	var after: Dictionary=app.session.station_owner().snapshot()
	var restored_stock: Array=after.equipment.market_rows.filter(func(row):return row.item_id==164)
	check(full_crystal_hold(after) and restored_stock.size()==1 and restored_stock[0].stock==crystal_stock[0].stock,"The paid refit did not restore all fifty mined crystals and original market quantity")
	check(after.loadout.equipment_ids.has(57) and after.loadout.equipment_ids.has(64) and after.loadout.equipment_ids.has(91) and after.equipment.fitting_stats.passenger_capacity>=3,"The paid return refit lost armor, expanded hold or occupied cabin")
	for key in ["mission","passengers","blueprints","void_source","progress","travel_statistics"]:
		check(after.contracts[key]==before.contracts[key],"The paid return refit changed retained "+key)
	if failures or not app.equipment_action("close"):check(false,app.status.text);return false
	route_credits=int(after.contracts.credits)
	print("Earned full50t return prepared at ",after.loadout.station_id," wallet ",route_credits," slots ",after.loadout.slots)
	return true

func trade_return_item(item_id: int,action: String,quantity: int) -> bool:
	var before: Dictionary=app.session.station_owner().snapshot()
	var rows: Array=before.equipment.market_rows.filter(func(row):return row.item_id==item_id)
	var panel: Control=app.equipment_panel
	panel.select_tab("cargo" if action=="sell" else "shop")
	check(rows.size()==1 and rows[0].unit_price>0 and quantity>0,"The return trade has no real positive quote")
	if failures:return false
	for index in quantity:
		if not panel._rows.has(item_id) or panel._rows[item_id].actions[action].disabled:check(false,"The real return "+action+" is unavailable for item "+str(item_id));return false
		panel._rows[item_id].actions[action].pressed.emit()
	var after: Dictionary=app.session.station_owner().snapshot()
	var sign_value:=1 if action=="sell" else -1
	check(after.contracts.credits==before.contracts.credits+sign_value*quantity*int(rows[0].unit_price) and after.cargo.used==before.cargo.used-sign_value*quantity and after.loadout==before.loadout,"The actual return trade changed the wrong wallet, cargo quantity or fitted ship")
	return failures==0

func reach_gate_confirmation() -> bool:
	return await reach_paid_gate_confirmation(10000,false,false,1000.0)
