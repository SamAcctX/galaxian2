extends "res://tests/post_probe_application.gd"
## Follow the earned cargo-fit career into the supported crystal expedition.
## Every retained checkpoint follows real gate, docking and station-save input.
const CRYSTAL_ROUTE=[[14,70],[11,55],[7,35]]

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(saved)
	var original: Dictionary=app.session.station_owner().snapshot()
	var current: int=int(original.loadout.station_id)
	var index:=-1
	for position in CRYSTAL_ROUTE.size():
		if CRYSTAL_ROUTE[position][1]==current:index=position;break
	check(not input_hash.is_empty() and original.campaign_cursor==32 and index>=0,"Resume the actual fitted mission32 route station")
	check(original.cargo.capacity==50 and original.cargo.used==0 and original.loadout.equipment_ids.has(86) and original.loadout.equipment_ids.has(64),"The earned route lost its empty50t hold or installed drill")
	check(original.contracts.passengers==3 and original.contracts.mission.kind==11 and original.contracts.mission.station_id==99 and original.contracts.has("void_source"),"The route lost its retained passenger job or Void source")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Set a private crystal-route save directory")
	var clock:=OS.get_environment("GOF2_ALIOTH_WORLD_BASE")
	if not clock.is_empty():
		check(clock.is_valid_int() and clock.to_int()>=0 and clock.to_int()<2147480000,"Use the recorded route clock base")
		_world_clock_base=clock.to_int()
	if failures:return
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	var starting_index:=index
	while index<CRYSTAL_ROUTE.size()-1:
		if not await depart_crystal_route():return
		index+=1
		var destination: Array=CRYSTAL_ROUTE[index]
		if not await expedition_gate(int(destination[0]),int(destination[1])) or not await dock_with_paid_emp(2147483647):return
		var landed: Dictionary=app.session.station_owner().snapshot()
		check(landed.campaign_cursor==32 and landed.loadout.station_id==destination[1] and landed.mission==original.mission,"The actual route changed the pending Thynome mission or missed its station")
		check(landed.cargo==original.cargo and landed.loadout.equipment_ids==original.loadout.equipment_ids and landed.player_cache.values.hull>0,"The route lost the living player or paid mining fit")
		check(landed.contracts.credits==route_credits and landed.contracts.mission==retained_job and landed.contracts.passengers==3 and landed.contracts.blueprints==original.contracts.blueprints,"Gate travel changed the retained wallet, passengers or blueprint materials")
		check(landed.contracts.travel_statistics.jumpgates_used==original.contracts.travel_statistics.jumpgates_used+index-starting_index,"The route did not retain its actual number of gates")
		var source_expected: Dictionary=original.contracts.void_source.duplicate(true)
		source_expected.eligible_selection_count+=index-starting_index
		check(landed.contracts.void_source==source_expected,"The actual short route rerolled or overcounted the Void source")
		if failures or not retain_chapter_save("thynome32-route-"+str(destination[1])):return
		await capture_free_application("earned-crystal-route-"+str(destination[1]))
	check(FileAccess.get_sha256(saved)==input_hash,"The route overwrote its immutable earned input")
	if failures:return
	await verify_thynome_boundary()
	check(FileAccess.get_sha256(saved)==input_hash,"The Thynome visit changed its immutable earned input")

func depart_crystal_route() -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	return await release_application_flight()

func verify_thynome_boundary() -> void:
	var station: Dictionary=app.session.station_owner().snapshot()
	check(station.loadout.station_id==35 and station.campaign_cursor==32,"The retained route did not reach Aquila with mission32 pending")
	if failures or OS.get_environment("GOF2_CRYSTAL_AQUILA_ONLY")=="1":return
	# The mining fit has no defensive passive slot. Buy real transit armor,
	# carry the owned drill, and restore the empty mining fit at Thynome.
	if not fit_route_armor():return
	var transit: Dictionary=app.session.station_owner().snapshot()
	if not await depart_crystal_route():return
	var departure: Dictionary=app.session.snapshot()
	var neutrals: Array=departure.encounter.combat.actors.filter(func(actor):return actor.active and not actor.hostile and actor.vitals.hull>0)
	# Clear the actual attackers with the shared combat pilot before guidance;
	# neutral traffic constrains defensive EMP use along the gate corridor.
	if not await clear_route_attackers("Aquila crystal transit"):return
	var cleared: Dictionary=app.session.snapshot()
	for actor in neutrals:
		check(not cleared.encounter.combat.actors[int(actor.actor_id)].hostile,"Aquila's paid transit defence provoked neutral traffic")
	if failures:return
	check(PostProbeCampaign.ordinary_story_at(definitions.mido_travel,32,10) and PostProbeNavigation.destination_supported(definitions,32,station.mission,10),"The earned crystal route cannot enter its supported Thynome visit")
	if failures:return
	if not app.open_map(now_us) or not app.switch_map_system(6):check(false,app.status.text);return
	var held: Dictionary=app.session.snapshot()
	var mapped: Dictionary=app.map_panel.snapshot()
	check(mapped.rows.any(func(row):return row.station_id==10 and row.supported),"The neighboring Thynome map has no selectable story target")
	check(mapped.void_warning.system_id==station.contracts.void_source.source_system_id and mapped.void_warning.station_id==-1,"Mission32 revealed its source station before the visit")
	app.map_panel.select_station(10);app.map_panel.request_confirmation()
	check(app.map_panel.snapshot().confirmation_visible and app.session.snapshot()==held,"Selecting Thynome traveled before confirmation")
	app.map_panel.back()
	check(not app.map_panel.snapshot().confirmation_visible and app.session.snapshot()==held,"Cancelling Thynome changed the earned flight or source")
	if failures:return
	await capture_free_application("earned-thynome32-admission")
	if not app.close_map(now_us):check(false,app.status.text);return
	if not await follow_gate_course(6,10):return
	var arrival: Dictionary=app.session.snapshot()
	check(arrival.campaign_cursor==32 and arrival.location.station_id==10 and arrival.encounter.combat.actors.is_empty(),"Thynome did not select its original empty story cast")
	check(arrival.cargo==transit.cargo and arrival.player.equipment_ids.has(57) and arrival.player.vitals.hull>0,"The Thynome gate lost its surviving transit fit or retained drill")
	check(arrival.contracts.void_source==station.contracts.void_source and arrival.contracts.travel_statistics.jumpgates_used==station.contracts.travel_statistics.jumpgates_used+1,"The story-target arrival rerolled its Void source or lost the actual gate")
	if failures:return
	if not await acknowledge_story_lines(definitions.mido_travel.post_probe_visits.missions["32"].briefing_events):return
	if not await release_application_flight() or not await dock_application() or not await acknowledge_station_chapter(32):return
	var acknowledged: Dictionary=app.session.station_owner().snapshot()
	check(acknowledged.cargo==transit.cargo and acknowledged.loadout.equipment_ids==transit.loadout.equipment_ids and acknowledged.contracts.credits==route_credits,"The zero-reward Thynome acknowledgement changed transit cargo, equipment or money")
	if failures or not restore_crystal_mining_fit():return
	var ready: Dictionary=app.session.station_owner().snapshot()
	check(ready.mission==acknowledged.mission and ready.progress==acknowledged.progress,"Restoring the mining fit changed the acknowledged mission or progress")
	check(ready.campaign_cursor==33 and ready.loadout.station_id==10 and ready.mission==PostProbeCampaign.mission(definitions.mido_travel,33),"Thynome's final Next did not retain the original50-crystal objective")
	check(ready.cargo==station.cargo and ready.loadout.equipment_ids==station.loadout.equipment_ids and ready.contracts.credits==route_credits and ready.contracts.passengers==3 and ready.contracts.mission==retained_job,"Thynome's zero-reward visit changed the paid fit, empty hold or accepted job")
	check(ready.contracts.void_source==station.contracts.void_source and ready.contracts.blueprints==station.contracts.blueprints,"The visit granted a drive recipe or changed its retained Void source")
	if failures or not retain_chapter_save("thynome33-crystals-pending"):return
	await capture_free_application("earned-thynome33-crystals-pending")
	var owner: RefCounted=app.session.station_owner()
	check(not owner.acknowledge() and not owner.begin_campaign_conversation(definitions,catalogue,source) and owner.snapshot()==ready,"The acknowledged visit repeated or opened the crystal hand-in with an empty hold")
	if failures or not await depart_crystal_route():return
	var departed: Dictionary=app.session.snapshot()
	check(departed.campaign_cursor==33 and departed.mission==ready.mission and departed.location.station_id==10 and app.session.can_control(),"The accepted crystal mission cannot depart normally from Thynome")
	check(departed.cargo==ready.cargo and departed.contracts.credits==ready.contracts.credits and departed.contracts.mission==retained_job and departed.contracts.passengers==3 and departed.contracts.blueprints==ready.contracts.blueprints,"Thynome departure changed the earned cargo, wallet, passengers or blueprint materials")
	check(not departed.dialogue.visible and not departed.has("void_probe") and not departed.has("void_portal"),"Ordinary crystal departure replayed authored probe content")
	if failures or not app.open_map(now_us):check(false,app.status.text);return
	var revealed: Dictionary=app.map_panel.snapshot()
	check(revealed.void_warning.system_id==ready.contracts.void_source.source_system_id and revealed.void_warning.station_id==ready.contracts.void_source.source_station_id,"The acknowledged briefing did not reveal its retained source station")
	await capture_free_application("earned-thynome33-source-hint")
	if not app.close_map(now_us):check(false,app.status.text);return
	print("Earned Thynome32 visit -> mission33, paid transit armor and restored empty50t mining fit, save/reload, ordinary departure and source hint ",ready.contracts.void_source)

## Shared paid transit refit for the Thynome visit and later source expedition.
func fit_route_armor() -> bool:
	if not app.equipment_action("open"):check(false,app.status.text);return false
	var quote: Dictionary=app.session.station_owner().snapshot()
	var offers: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==57 and row.stock>0 and row.unit_price>0 and row.unit_price<=quote.contracts.credits)
	check(offers.size()==1,"The earned station no longer has its affordable 110-armor transit option")
	if failures:return false
	var offer: Dictionary=offers[0].duplicate(true)
	var panel: Control=app.equipment_panel
	panel.select_tab("shop")
	check(panel._rows.has(57) and quote.equipment.fitting_support.get(57,"unsupported").is_empty() and not panel._rows[57].actions.buy.disabled,"The real 110-armor row cannot be bought or fitted")
	if failures:return false
	panel._rows[57].actions.buy.pressed.emit()
	var bought: Dictionary=app.session.station_owner().snapshot()
	check(bought.contracts.credits==quote.contracts.credits-int(offer.unit_price) and bought.cargo.used==quote.cargo.used+1 and bought.loadout==quote.loadout,"Buying transit armor changed the wrong balance or silently fitted it")
	if failures:return false
	var drill_slot:=-1
	for i in bought.loadout.slots.size():
		if bought.loadout.slots[i]!=null and int(bought.loadout.slots[i].item_id)==86:drill_slot=i;break
	check(drill_slot>=0 and panel._installed_rows.has(drill_slot),"The earned drill has no removable ship slot")
	if failures:return false
	panel.select_tab("ship");panel._installed_rows[drill_slot].button.pressed.emit()
	var unmounted: Dictionary=app.session.station_owner().snapshot()
	check(not unmounted.loadout.equipment_ids.has(86) and unmounted.cargo.used==bought.cargo.used+1,"The transit refit did not demount the actual drill into cargo")
	if failures:return false
	panel.select_tab("cargo")
	check(panel._rows.has(57) and not panel._rows[57].actions.mount.disabled,"The purchased 110-armor unit cannot enter the vacated passive slot")
	if failures:return false
	panel._rows[57].actions.mount.pressed.emit()
	var fitted: Dictionary=app.session.station_owner().snapshot()
	var drill_rows: Array=fitted.cargo.entries.filter(func(row):return row.item_id==86 and row.quantity==1)
	check(fitted.loadout.equipment_ids.has(57) and not fitted.loadout.equipment_ids.has(86) and drill_rows.size()==1,"The transit refit did not exchange exactly the drill for armor")
	check(fitted.cargo.capacity==50 and fitted.cargo.used==1 and fitted.equipment.fitting_stats.armor==110 and fitted.equipment.fitting_stats.passenger_capacity>=3,"The transit armor changed hold capacity, cabin capacity or its verified armor value")
	check(fitted.contracts.mission==retained_job and fitted.contracts.passengers==3 and fitted.mission==quote.mission and fitted.progress==quote.progress,"The transit refit changed the accepted job or campaign progress")
	if failures or not app.equipment_action("close"):check(false,app.status.text);return false
	route_credits=int(fitted.contracts.credits)
	print("Earned source-route transit armor57: ",offer.unit_price," credits; armor ",fitted.equipment.fitting_stats.armor,"; drill retained in 50t hold; wallet ",route_credits)
	return failures==0

func restore_crystal_mining_fit() -> bool:
	if not app.equipment_action("open"):check(false,app.status.text);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	var armor_slot:=-1
	for i in before.loadout.slots.size():
		if before.loadout.slots[i]!=null and int(before.loadout.slots[i].item_id)==57:armor_slot=i;break
	var drill_rows: Array=before.cargo.entries.filter(func(row):return row.item_id==86 and row.quantity==1)
	check(armor_slot>=0 and drill_rows.size()==1,"The source arrival lost its reversible armor/drill exchange")
	if failures:return false
	var panel: Control=app.equipment_panel
	panel.select_tab("ship")
	check(panel._installed_rows.has(armor_slot),"The transit armor has no removable source-station slot")
	if failures:return false
	panel._installed_rows[armor_slot].button.pressed.emit()
	var unmounted: Dictionary=app.session.station_owner().snapshot()
	check(not unmounted.loadout.equipment_ids.has(57) and unmounted.cargo.used==before.cargo.used+1,"The source station did not demount transit armor into cargo")
	if failures:return false
	panel.select_tab("cargo")
	check(panel._rows.has(86) and not panel._rows[86].actions.mount.disabled,"The retained drill cannot be restored at the selected Void source")
	if failures:return false
	panel._rows[86].actions.mount.pressed.emit()
	var remounted: Dictionary=app.session.station_owner().snapshot()
	check(remounted.loadout.equipment_ids.has(86) and not remounted.loadout.equipment_ids.has(57) and remounted.cargo.capacity==50,"The source station did not restore the paid drill and 50t hold")
	var sale_rows: Array=remounted.equipment.market_rows.filter(func(row):return row.item_id==57 and row.owned==1 and not row.mission and row.unit_price>0)
	check(sale_rows.size()==1 and panel._rows.has(57) and not panel._rows[57].actions.sell.disabled,"The temporary armor cannot be sold from the source-station hold")
	if failures:return false
	var sale_price: int=int(sale_rows[0].unit_price)
	panel._rows[57].actions.sell.pressed.emit()
	var restored: Dictionary=app.session.station_owner().snapshot()
	check(restored.contracts.credits==remounted.contracts.credits+sale_price and restored.cargo.used==0 and restored.cargo.entries.is_empty(),"Selling transit armor did not restore an empty mining hold at the quoted source price")
	check(restored.equipment.fitting_stats.armor==0 and restored.equipment.fitting_stats.passenger_capacity>=3 and restored.contracts.mission==retained_job and restored.contracts.passengers==3,"Restoring the mining fit changed the cabin, accepted job or defensive state")
	if failures or not app.equipment_action("close"):check(false,app.status.text);return false
	route_credits=int(restored.contracts.credits)
	print("Earned Void-source mining fit restored: drill86 mounted, armor57 sold for ",sale_price," credits, empty 50t hold, wallet ",route_credits)
	return failures==0
