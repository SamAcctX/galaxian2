extends "res://tests/post_probe_application.gd"
## Pay for the original cargo extension through the real application. Retain the
## occupied cabin, fit the owned drill, clear only saleable cargo, then fly and
## dock at the system's gate station. No selected cursor, source or cargo proposal.

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	check(not saved.is_empty(),"Resume the genuine paid Alioth32 station archive")
	if failures:return
	var input_hash:=FileAccess.get_sha256(saved)
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.campaign_cursor==32 and original.loadout.station_id==98 and original.loadout.ship_id==0 and original.mission==PostProbeCampaign.mission(definitions.mido_travel,32),"Crystal preparation requires the earned paid Alioth32 ship")
	check(original.contracts.passengers==3 and original.contracts.mission.station_id==99 and original.contracts.void_source.source_station_id==91,"Preparation lost the actual passenger job or retained Dima source")
	check(original.cargo.capacity==25 and original.loadout.equipment_ids==[2,41,81,91,55] and original.cargo.entries==[{"item_id":86,"quantity":1},{"item_id":144,"quantity":9},{"item_id":68,"quantity":1}],"Use the earned inventory, not a pre-fitted or fabricated crystal hold")
	if failures:return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if chapter_directory.is_empty() or not FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"):check(false,"Set a fresh private crystal preparation save directory");return
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	if not await prepare_crystal_hold(original):return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	if not retain_chapter_save("alioth32-crystal-fitted"):return
	check(FileAccess.get_sha256(saved)==input_hash,"The application overwrote its immutable paid32 input")
	if failures:return
	await verify_crystal_departure(fitted)
	check(FileAccess.get_sha256(saved)==input_hash,"Crystal preparation or travel changed the original paid32 archive")

func prepare_crystal_hold(original: Dictionary) -> bool:
	if not app.equipment_action("open"):check(false,app.status.text);return false
	var quoted: Dictionary=app.session.station_owner().snapshot()
	var rows: Array=quoted.equipment.market_rows.filter(func(row):return row.item_id==64 and row.stock>0 and row.unit_price>0)
	check(rows.size()==1 and quoted.contracts.credits>=int(rows[0].unit_price),"The retained Alioth market cannot supply the original cargo extension")
	if failures:return false
	var offer: Dictionary=rows[0].duplicate(true)
	var panel: Control=app.equipment_panel
	panel.select_tab("shop")
	check(panel._rows.has(64) and not panel._rows[64].actions.buy.disabled and quoted.equipment.fitting_support[64].is_empty(),"The quoted cargo extension is unavailable in the real shop")
	if failures:return false
	panel._rows[64].actions.buy.pressed.emit()
	var bought: Dictionary=app.session.station_owner().snapshot()
	check(bought.contracts.credits==quoted.contracts.credits-int(offer.unit_price) and bought.cargo.used==quoted.cargo.used+1 and bought.loadout==quoted.loadout,"Buying the extension changed the wrong balance or silently fitted it")
	if failures:return false
	# Use the same normal demount/mount actions as other earned equipment trips.
	if not mount_owned_device(86,17) or not mount_owned_device(64,10):return false
	var mounted: Dictionary=app.session.station_owner().snapshot()
	check(mounted.loadout.equipment_ids==[2,41,86,91,64] and mounted.cargo.capacity==50 and mounted.equipment.fitting_stats.passenger_capacity>=3 and mounted.equipment.fitting_stats.armor==0,"The original fitting did not exchange scanner/armor for drill/+25t while retaining the cabin")
	check(not app.equipment_action("unmount",91) and app.session.station_owner().snapshot()==mounted,"An occupied passenger cabin was removed or a rejected action changed the career")
	if failures:return false
	panel.select_tab("cargo")
	check(panel._rows.has(55),"The demounted armor disappeared instead of joining cargo")
	if failures:return false
	check(panel._rows[55].actions.mount.disabled,"The full three-slot ship still exposes an enabled fourth-device Mount button")
	check(not app.equipment_action("mount",55) and app.status.text=="No compatible ship slot is free" and app.session.station_owner().snapshot()==mounted,"The application admitted a fourth device or changed state on a refused mount")
	if failures:return false
	var proceeds:=0
	for item_id in [81,55,144,68]:
		var current: Dictionary=app.session.station_owner().snapshot()
		var sale_rows: Array=current.equipment.market_rows.filter(func(row):return row.item_id==item_id and row.owned>0 and not row.mission and row.unit_price>0)
		check(sale_rows.size()==1,"Preparation lost its actual unprotected cargo for sale: "+str(item_id))
		if failures:return false
		var sale: Dictionary=sale_rows[0].duplicate(true)
		for unit in int(sale.owned):
			check(panel._rows.has(item_id) and not panel._rows[item_id].actions.sell.disabled,"The actual cargo cannot be sold through the station UI")
			if failures:return false
			panel._rows[item_id].actions.sell.pressed.emit()
		proceeds+=int(sale.owned)*int(sale.unit_price)
	var ready: Dictionary=app.session.station_owner().snapshot()
	check(ready.cargo.entries.is_empty() and ready.cargo.used==0 and ready.cargo.free_space==50 and ready.cargo.capacity==50,"Saleable cargo still occupies space needed for fifty crystals")
	check(ready.contracts.credits==quoted.contracts.credits-int(offer.unit_price)+proceeds and ready.loadout==mounted.loadout,"Preparing the hold changed equipment or miscounted paid trades")
	var stock: Array=ready.equipment.market_rows.filter(func(row):return row.item_id==64)
	check(stock.size()==1 and stock[0].stock==offer.stock-1 and stock[0].owned==0,"Fitting/selling duplicated the purchased extension or supplier stock")
	check(ready.mission==original.mission and ready.campaign_cursor==32 and ready.progress==original.progress,"A paid equipment refit granted campaign progress")
	for key in ["mission","passengers","blueprints","void_source","travel_statistics"]:
		check(ready.contracts[key]==original.contracts[key],"Paid preparation changed retained "+key)
	if failures:return false
	panel.select_tab("ship")
	await capture_free_application("crystal-preparation-fitted")
	panel.select_tab("cargo")
	await capture_free_application("crystal-preparation-empty-hold")
	if not app.equipment_action("close"):check(false,app.status.text);return false
	route_credits=int(ready.contracts.credits)
	print("Earned crystal preparation: extension64 cost ",offer.unit_price,"; cargo sales ",proceeds,"; wallet ",route_credits,"; hold 0/50t; cabin retained, armor 0")
	return true

func verify_crystal_departure(fitted: Dictionary) -> void:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	var departed: Dictionary=app.session.snapshot()
	check(departed.cargo==fitted.cargo and departed.equipment.loadout==fitted.loadout and departed.player.equipment_ids==fitted.loadout.equipment_ids,"Flight lost the purchased hold or real fitted equipment")
	check(departed.player.vitals.armor==0 and departed.mining_targeting.duration_ms==8000,"The fitted departure retained removed armor or invented scanner acquisition")
	check(departed.campaign_cursor==32 and departed.contracts.credits==route_credits and departed.contracts.passengers==3 and departed.contracts.void_source==fitted.contracts.void_source,"Departure changed the paid career, passenger cabin or source selection")
	check(PostProbeNavigation.destination_supported(definitions,32,fitted.mission,10),"Paid preparation lost the supported expedition's pending Thynome course")
	if failures:return
	await capture_free_application("crystal-preparation-flight")
	if not await travel_application(95) or not await dock_with_paid_emp(2147483647):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout.station_id==95 and landed.loadout.system_id==19 and landed.campaign_cursor==32 and landed.mission==fitted.mission,"The actual local flight did not reach the gate station with its pending mission")
	check(landed.cargo==fitted.cargo and landed.loadout.equipment_ids==fitted.loadout.equipment_ids and landed.contracts.credits==route_credits and landed.contracts.mission==retained_job and landed.contracts.passengers==3,"Local flight/docking lost the paid preparation or passenger job")
	check(landed.contracts.travel_statistics==fitted.contracts.travel_statistics and landed.player_cache.values.hull>0,"A local trip counted an unflown gate or saved a destroyed pilot")
	check(landed.contracts.void_source.source_station_id==91 and landed.contracts.void_source.eligible_selection_count==fitted.contracts.void_source.eligible_selection_count+1,"The actual changed location reset or skipped the retained Void source counter")
	if failures or not retain_chapter_save("thynome32-route-95"):return
	await capture_free_application("crystal-preparation-gate-station")
	print("Earned Alioth32 paid 50t fitting -> actual local flight -> station95 docking and save/load; pending Thynome visit retained")
