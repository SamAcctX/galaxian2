extends "res://tests/void_crystal_route_application.gd"
## Navigate from the actual Thynome conversation to the retained Void source.
## Source selection is allowed to move; every leg follows the current native map.
const CrystalNavigation=preload("res://src/simulation/system_navigation.gd")

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(saved)
	var original: Dictionary=app.session.station_owner().snapshot()
	check(not input_hash.is_empty() and original.campaign_cursor==33 and original.contracts.has("void_source"),"Resume the earned crystal mission and retained Void source")
	check(original.cargo.capacity==50 and original.cargo.used==0 and original.loadout.equipment_ids.has(86) and original.loadout.equipment_ids.has(64),"The source journey requires its paid empty mining fit")
	check(original.contracts.passengers==3 and original.contracts.mission.kind==11 and original.contracts.mission.station_id==99,"The source journey lost the accepted passenger job")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Set a private source-route save directory")
	if failures:return
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	if not prepare_crystal_defence():return
	var transit: Dictionary=app.session.station_owner().snapshot()
	check(transit.cargo.capacity==50 and transit.cargo.used==1 and transit.loadout.equipment_ids.has(57) and not transit.loadout.equipment_ids.has(86),"The paid transit refit did not retain the 50t hold with the drill safely in cargo")
	check(transit.contracts.passengers==3 and transit.contracts.mission==retained_job,"The paid transit refit lost its cabin or accepted job")
	if failures or not retain_chapter_save("crystal33-source-fitted"):return
	check(FileAccess.get_sha256(saved)==input_hash,"Defence preparation overwrote its immutable earned input")
	if failures:return
	if OS.get_environment("GOF2_CRYSTAL_PREPARATION_ONLY")=="1":
		print("Earned crystal defence preparation and v8 save/reload only; source travel not exercised")
		return
	if not await depart_crystal_route():return
	var navigation:=CrystalNavigation.new()
	var reached:=false
	var gates:=0
	for hop in 24:
		var flying: Dictionary=app.session.snapshot()
		var retained: Dictionary=flying.contracts.void_source
		if flying.location.station_id==retained.source_station_id and flying.location.system_id==retained.source_system_id:
			reached=true;break
		if not navigation.configure(definitions,catalogue,flying.contracts.lounges.system_availability):check(false,navigation.error);return
		var course: Dictionary=navigation.course(flying.location.station_id,retained.source_station_id)
		if course.is_empty():check(false,navigation.error);return
		print("Earned crystal source route ",flying.location.station_id," -> ",retained.source_station_id," selection ",retained.eligible_selection_count," course ",course.system_path)
		if course.guidance.kind=="planet":
			if not await travel_application(int(course.guidance.station_id)):return
		elif course.guidance.kind=="gate":
			var system_id: int=int(course.system_path[1])
			var station_id: int=int(catalogue.tables.systems[system_id].fields[int(definitions.mido_travel.free_navigation.gate_station_field)])
			if not await expedition_gate(system_id,station_id):return
			gates+=1
		else:check(false,"The source course did not produce a real travel leg");return
		var arrived: Dictionary=app.session.snapshot()
		check(arrived.campaign_cursor==33 and arrived.mission==original.mission and arrived.cargo==transit.cargo and arrived.player.equipment_ids.has(57) and arrived.player.vitals.hull>0,"The source journey lost the living ship, paid transit armor, retained drill or crystal objective")
		check(arrived.contracts.credits==route_credits and arrived.contracts.mission==retained_job and arrived.contracts.passengers==3 and arrived.contracts.blueprints==original.contracts.blueprints,"The source journey changed unrelated career progress")
		check(arrived.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+gates,"The source journey lost an actual jumpgate")
		if failures:return
	check(reached,"The current Void source was not reached within the bounded route")
	if failures:return
	var source_flight: Dictionary=app.session.snapshot()
	check(not source_flight.void_portal.is_empty() and source_flight.void_portal.ordinary_mode=="source_entry","The earned source world did not contain its ordinary entry portal")
	if failures or not await dock_with_paid_emp(2147483647):return
	if not restore_crystal_mining_fit():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.campaign_cursor==33 and landed.loadout.station_id==source_flight.contracts.void_source.source_station_id and landed.contracts.void_source==source_flight.contracts.void_source,"Docking lost the selected source or crystal mission")
	check(landed.cargo==original.cargo and landed.loadout.equipment_ids.has(86) and landed.loadout.equipment_ids.has(64) and not landed.loadout.equipment_ids.has(57),"The source station did not restore the empty 50t mining fit")
	check(landed.contracts.blueprints==original.contracts.blueprints and landed.contracts.credits==route_credits,"Source docking or the reversible transit refit changed unrelated career progress")
	check(FileAccess.get_sha256(saved)==input_hash,"The source journey overwrote its immutable earned input")
	if failures or not retain_chapter_save("crystal33-source-ready"):return
	await capture_free_application("earned-crystal33-source-ready")
	print("Earned crystal source station ",landed.loadout.station_id," after ",gates," actual gates, retained source ",landed.contracts.void_source)

func reach_gate_confirmation() -> bool:
	var state: Dictionary=app.session.snapshot()
	if state.location.station_id==45 and state.encounter.has("secondaries") and state.encounter.secondaries.guns[0].ammunition>0:
		# EMP42 cannot always disable Weymire traffic in one pulse. Keep the real
		# gate guidance moving and let successive safe pulses accumulate systems damage.
		return await reach_paid_gate_confirmation(10000,false,false,1000.0)
	return await super.reach_gate_confirmation()

func prepare_crystal_defence() -> bool:
	var before: Dictionary=app.session.station_owner().snapshot()
	var launcher: Variant=before.loadout.slots[1]
	if launcher!=null and launcher.item_id in [42,43] and launcher.quantity>0:return true
	var stock: Array=app.session.station_owner().contract_owner().location_owner().item_stock(int(before.loadout.station_id))
	var defensive_stock:=[]
	for row in stock:
		var item: Dictionary=catalogue.tables.items[int(row.item_id)]
		if int(item.arrays[2][5]) not in [9,10]:continue
		defensive_stock.append({"item_id":row.item_id,"quantity":row.quantity,"unit_price":row.unit_price,"subtype":item.arrays[2][5],"shield":item.properties.get(18,0),"armor":item.properties.get(20,0)})
	print("Earned station ",before.loadout.station_id," defensive stock: ",defensive_stock)
	if not app.equipment_action("open"):check(false,app.status.text);return false
	var fitting: Dictionary=app.session.station_owner().snapshot()
	print("Earned shield50 fitting support ",fitting.equipment.fitting_support.get(50,[])," conflicts ",fitting.equipment.fitting_conflicts.get(50,[])," slots ",fitting.loadout.slots)
	if not app.equipment_action("close"):check(false,app.status.text);return false
	var replacement:=-1
	for id in [43,42]:
		var offers:=stock.filter(func(row):return row.item_id==id and row.quantity>0 and row.unit_price>0 and row.unit_price<=before.contracts.credits)
		if offers.size()==1:replacement=id;break
	if replacement<0:check(false,"The actual source-route supplier has no affordable longer-range EMP");return false
	if launcher!=null:
		if not app.equipment_action("open"):check(false,app.status.text);return false
		var panel: Control=app.equipment_panel
		panel.select_tab("ship");panel._installed_rows[1].button.pressed.emit()
		var unmounted: Dictionary=app.session.station_owner().snapshot()
		check(unmounted.loadout.slots[1]==null and unmounted.cargo.used==before.cargo.used+launcher.quantity and unmounted.contracts.credits==before.contracts.credits,"Defence preparation did not demount its actual remaining ammunition")
		if failures:return false
		panel.select_tab("cargo")
		for round_index in int(launcher.quantity):
			if not panel._rows.has(int(launcher.item_id)) or panel._rows[int(launcher.item_id)].actions.sell.disabled:check(false,"The old paid EMP rounds cannot be sold through Hangar");return false
			panel._rows[int(launcher.item_id)].actions.sell.pressed.emit()
		if not app.equipment_action("close"):check(false,app.status.text);return false
		var sold: Dictionary=app.session.station_owner().snapshot()
		check(sold.cargo==before.cargo and sold.contracts.credits>=before.contracts.credits and sold.contracts.mission==retained_job and sold.contracts.passengers==3,"Selling the old launcher changed the mining hold or accepted job")
		if failures:return false
		route_credits=int(sold.contracts.credits)
	if not purchase_route_emp(12,false,replacement):return false
	return fit_route_armor()
