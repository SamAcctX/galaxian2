extends "res://tests/galaxy_application.gd"
## Constructed drive and paid fuel from the actual retained station career.
func verify_free_application() -> void:
	if is_instance_valid(app.session._blueprint_pickup) and app.session._blueprint_pickup.visible:await activate_ship_control(app.session._blueprint_pickup.get_ok_button())
	if OS.get_environment("GOF2_KHADOR_RESUMED")!="1":
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		var needed:=maxi(0,16-energy(quote.cargo))
		var cells: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==122 and row.stock>=needed)
		if cells.is_empty():
			if not app.equipment_action("close") or not await visit_tractor_supplier(19) or not app.equipment_action("open"):return
			quote=app.session.station_owner().snapshot();cells=quote.equipment.market_rows.filter(func(row):return row.item_id==122 and row.stock>=16)
		check(cells.size()==1,"The actual supplier has no energy-cell stock")
		if failures:return
		for unit in needed:
			if not app.equipment_action("buy",122):check(false,app.session.error);return
		check(app.session.station_owner().snapshot().contracts.credits==quote.contracts.credits-needed*cells[0].unit_price,"Energy purchase did not debit the actual quote")
		# Betty's three equipment slots are occupied; retain its armor in cargo.
		for item in quote.loadout.equipment_ids:
			if catalogue.tables.items[item].properties.get(2)==10:
				if not app.equipment_action("unmount",int(item)):check(false,app.session.error);return
				break
		if not app.equipment_action("mount",85):check(false,app.session.error);return
		app.equipment_panel.select_tab("ship")
		await capture_free_application("khador-constructed-fitted")
		if not app.equipment_action("close") or not retain_recovery_save("fitted"):return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(85),"Fitting or Resume lost the constructed drive")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	var navigation:=Navigation.new()
	if not navigation.configure(definitions,catalogue,fitted.contracts.lounges.system_availability):check(false,navigation.error);return
	var destination:=-1
	for id in app.session.flight_owner()._navigation_destinations:
		if navigation.route(fitted.loadout.system_id,catalogue.tables.stations[id].system_id).size()==3:destination=id;break
	check(destination>=0,"The earned career has no two-hop drive target")
	if failures or not await jump_drive(destination):return
	if not await dock_application() or not retain_recovery_save("outbound"):return
	var outbound: Dictionary=app.session.station_owner().snapshot()
	check(outbound.contracts.credits==fitted.contracts.credits and outbound.campaign_cursor==fitted.campaign_cursor,"Drive arrival altered wallet or story")
	check(outbound.contracts.travel_statistics.jumpgates_used==fitted.contracts.travel_statistics.jumpgates_used,"Drive jump counted as a physical jumpgate")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	if not await jump_drive(int(fitted.loadout.station_id)) or not await dock_application() or not retain_recovery_save("returned"):return
	var returned: Dictionary=app.session.station_owner().snapshot()
	check(energy(returned.cargo)==energy(fitted.cargo)-4,"Two two-hop drive jumps did not retain exactly four spent cells")
	check(returned.loadout==fitted.loadout and returned.contracts.credits==fitted.contracts.credits and returned.campaign_cursor==fitted.campaign_cursor,"Drive round trip lost the fitted hull or career")
	await capture_free_application("khador-round-trip-saved")

func energy(cargo: Dictionary) -> int:
	var total:=0
	for row in cargo.entries:
		if row.item_id==122:total+=int(row.quantity)
	return total

func jump_drive(destination: int) -> bool:
	var initial: Dictionary=app.session.snapshot();var owner: RefCounted=app.session.flight_owner()
	var parent: Dictionary=owner.snapshot()
	var quote: Dictionary=owner.drive_quote(destination)
	check(quote.get("affordable",false) and quote.get("cost")==2,"Earned flight lost its two-hop cost")
	if failures or not await open_drive_selector() or not await choose_map_destination(destination,true):check(false,app.status.text);return false
	var started: Dictionary=app.session.snapshot()
	check(started.khador.phase=="charging" and energy(started.cargo)==energy(initial.cargo)-2,"Charge did not debit exactly two cells")
	check(owner.snapshot()==parent,"Starting drive changed its retained parent flight")
	return await complete_drive(destination)

func open_drive_selector() -> bool:
	resume_application_focus()
	if OS.get_environment("GOF2_KHADOR_MENU")=="1":
		if not choose_free_keyboard_flight_action(KEY_E,"khador"):check(false,"Khador is absent from flight actions");return false
	else:drive_key(KEY_K)
	check(app.map_panel.visible and app.map_panel.snapshot().drive_mode,"Khador input did not open its galaxy selector")
	return failures==0

func drive_key(code: int) -> void:
	for pressed in [true,false]:
		var key:=InputEventKey.new();key.physical_keycode=code;key.keycode=code;key.pressed=pressed;app._unhandled_input(key)

func complete_drive(destination: int) -> bool:
	var started: Dictionary=app.session.snapshot()
	check(started.flight_notices.pending.any(func(row):return row.get("kind")=="energy_spent" and row.text.begins_with("-2t ")),"Charging omitted the spent-fuel notice")
	var phases:={};var began:=now_us
	app.session.rebase_time(now_us)
	while app.session.status=="running" and now_us-began<12000000:
		if not application_step():return false
		var state: Dictionary=app.session.snapshot();var drive: Dictionary=state.khador
		if drive.phase=="charging" and drive.elapsed_ms>=1000 and not phases.has("charging"):
			phases.charging=true;await capture_free_application("khador-charging")
			var held: Dictionary=app.session.snapshot()
			check(app.session.set_pause("user",true,now_us),app.session.error);now_us+=1000000;began+=1000000
			check(app.session.step(now_us) and app.session.snapshot().khador==held.khador,"Pause advanced drive charging")
			check(app.session.set_pause("user",false,now_us),app.session.error)
			drive_key(KEY_K)
			check(not app.map_panel.visible and app.session.snapshot().cargo==held.cargo and app.session.snapshot().khador==held.khador,"Repeated Khador input changed fuel or restarted the charge")
		if drive.phase=="departing" and drive.elapsed_ms>=500 and not phases.has("departing"):
			phases.departing=true;await capture_free_application("khador-tunnel")
		if drive.phase=="departing" and drive.elapsed_ms>1700 and not phases.has("hidden"):
			phases.hidden=true;check(not app.session.scene.geometry.player.visible,"Drive tunnel retained the player after departure");await capture_free_application("khador-player-left")
	check(app.session.status=="drive_arrival_transition_required" and phases.size()==3,"Drive did not complete charge and departure")
	if failures:return false
	var sounds: Array=app.session.flight_audio.snapshot().history
	for id in [32,33]:check(sounds.filter(func(row):return row.action=="start" and row.source_id==id).size()==1,"Khador charge/departure sound did not play exactly once")
	var departing: Dictionary=app.session.snapshot()
	if not app.enter_drive_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	var arrival: Dictionary=app.session.snapshot()
	check(arrival.location.station_id==destination and arrival.cargo==departing.cargo and arrival.player.vitals==departing.player.vitals,"Drive arrival lost the selected destination, cargo or surviving pools")
	if failures or not await release_application_flight():return false
	await capture_free_application("khador-selected-arrival")
	return true
