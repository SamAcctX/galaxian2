extends "res://tests/ship_purchase_application.gd"
## Reach a newly supported system through real travel from an earned save.
func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor>=18 and state.contracts.mission.is_empty()
func verify_free_application() -> void:
	app.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"))
	var original: Dictionary=app.session.station_owner().snapshot()
	if OS.get_environment("GOF2_BASE_DESTINATION_RESUMED")=="1":
		app.set_player_mode(true);app.present_session()
		check(original.loadout.station_id==61 and app.station_shell.visible,"Fresh Resume lost the earned destination or station interface")
		await capture_free_application("base-destination-fresh-resume")
		if not app.contract_action("open",-1):check(false,app.session.error);return
		for tick in 30:
			if not application_step():return
		var state: Dictionary=app.session.snapshot()
		var contacts: Array=state.contracts.offers.keys().filter(func(id):return not state.contracts.offers[id].consumed)
		check(not contacts.is_empty(),"The resumed destination lost its generated offers")
		if contacts.is_empty():return
		var id: int=contacts[0]
		check(app.session.lounge_scene.screen_contacts().any(func(row):return row.id==id),"The offered contract has no visible lounge contact")
		app.lounge_panel.select_contact(id)
		check(app.lounge_panel.snapshot().selected==id and not app.lounge_panel.snapshot().body.is_empty() and not state.contract_previews[id].has("unsupported_reason"),"The resumed lounge still reports an unavailable contract")
		await capture_free_application("base-destination-contract")
		return
	if not await visit_tractor_supplier(60):return
	var arrived: Dictionary=app.session.station_owner().snapshot()
	check(arrived.loadout.station_id==60 and arrived.campaign_cursor==original.campaign_cursor and arrived.contracts.credits==original.contracts.credits,"Ordinary travel lost the earned destination or career")
	if not app.contract_action("open",-1):check(false,app.session.error);return
	var offers: Dictionary=app.session.station_owner().snapshot().contracts.offers
	check(not offers.is_empty(),"The newly supported station generated no lounge offers")
	for id in offers:
		if offers[id].consumed:continue
		check(not app.session.station_owner().contract_preview(id,definitions).is_empty(),"A generated base-game offer is still reported as unsupported")
	await capture_free_application("base-destination-lounge")
	if not app.contract_action("close",-1):check(false,app.session.error);return
	if not retain_recovery_save("new-system"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	await capture_free_application("base-destination-flight")
	if not await travel_application(61) or not await dock_application():return
	if not retain_recovery_save("local-arrival"):return
	var final: Dictionary=app.session.station_owner().snapshot()
	check(final.loadout.station_id==61 and final.campaign_cursor==original.campaign_cursor and final.contracts.credits==original.contracts.credits,"Local arrival changed the retained career")
	if not app.load_station(now_us):check(false,app._save_notice.text);return
	check(app.session.station_owner().snapshot()==final,"Resume changed the saved destination, inventory or career")
	await capture_free_application("base-destination-resumed")
