extends "res://tests/ship_purchase_application.gd"
## Freshly resumed purchased hull, an actual local client and earned payment.

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	check(original.loadout.ship_id!=0 and original.loadout.has("ship_instance"),"Resume did not retain the purchased hull")
	app.show();app.present_session();await process_frame;resume_application_focus()
	var destinations:=[int(original.loadout.station_id)]
	var home_system: Dictionary=catalogue.tables.systems[int(catalogue.tables.stations[int(original.loadout.station_id)].system_id)]
	for system in [home_system.id]+Array(home_system.linked_system_ids):
		for station in catalogue.tables.systems[int(system)].station_ids:
			if int(station) not in destinations:destinations.append(int(station))
	print("Purchased ship's local routes: ",destinations)
	var chosen:=-1
	for destination in destinations:
		if app.session.station_owner().snapshot().loadout.station_id!=destination and not await visit_tractor_supplier(destination):return
		if not app.contract_action("open",-1):check(false,app.session.error);return
		var station: RefCounted=app.session.station_owner()
		var career: Dictionary=station.snapshot().contracts
		for kind in [0,1]:
			for id in career.offers:
				var row: Dictionary=career.offers[id];var mission: Dictionary=row.offer.mission
				var quote: Dictionary=station.contract_preview(id,definitions)
				print("Purchased hull's client: ",{"origin":destination,"contact":id,"mission":mission,"can_accept":quote.get("can_accept",false)})
				if not row.consumed and mission.kind==kind and mission.station_id in destinations and (kind==0 or mission.difficulty<=2) and quote.get("can_accept",false):chosen=id;break
			if chosen>=0:break
		if chosen>=0:break
		if not app.contract_action("close",-1):check(false,app.session.error);return
	if chosen<0:check(false,"The actual local lounges supplied no affordable courier or patrol-defense job");return
	var before: Dictionary=app.session.station_owner().snapshot()
	var offer: Dictionary=before.contracts.offers[chosen].offer
	var quote: Dictionary=app.session.station_owner().contract_preview(chosen,definitions)
	app.lounge_panel.select_contact(chosen)
	await capture_free_application("purchased-ship-client")
	app.lounge_panel.confirm();app.lounge_panel.confirm()
	var accepted: Dictionary=app.session.station_owner().snapshot()
	check(accepted.contracts.mission==offer.mission and accepted.contracts.credits==before.contracts.credits-int(quote.fee),"The new hull accepted another job or fee")
	if not app.contract_action("close",-1):check(false,app.session.error);return
	if offer.mission.kind==1:
		if not app.equipment_action("open") or not app.equipment_action("mount",55) or not app.equipment_action("close"):check(false,app.session.error);return
		accepted=app.session.station_owner().snapshot()
	if not retain_recovery_save("accepted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	if accepted.loadout.station_id!=offer.mission.station_id and not await travel_application(int(offer.mission.station_id)):return
	var arrived: Dictionary=app.session.snapshot()
	check(arrived.player.ship_id==original.loadout.ship_id and arrived.contracts.credits==accepted.contracts.credits,"Travel replaced the new hull or paid the job early")
	await capture_free_application("purchased-ship-job-flight")
	if offer.mission.kind==1:
		check(contract_cast_valid(arrived.encounter.combat.actors),"The new hull lost its defense cast")
		if not await fly_contract_job(arrived):return
	else:
		if not await dock_application() or not application_step():return
	var pending: Dictionary=app.session.snapshot().contracts.pending_result
	check(not pending.is_empty() and pending.get("completed",false),"The new hull did not finish its real freelance job")
	if pending.is_empty():return
	await capture_free_application("purchased-ship-job-result")
	await acknowledge_recovery_result()
	if offer.mission.kind==1 and (not application_step() or not await dock_application()):return
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(paid.contracts.mission.is_empty() and paid.contracts.pending_result.is_empty() and paid.contracts.credits==accepted.contracts.credits+offer.mission.reward+offer.mission.bonus,"The purchased hull lost its acknowledged reward")
	check(paid.contracts.completed_side_missions==before.contracts.completed_side_missions+1 and paid.campaign_cursor==original.campaign_cursor and paid.mission==original.mission,"Freelance payment changed story or completion count")
	check(paid.loadout.ship_id==original.loadout.ship_id and paid.loadout.ship_instance==accepted.loadout.ship_instance,"The completed job lost the purchased ship instance")
	if not retain_recovery_save("paid"):return
	await capture_free_application("purchased-ship-job-saved")
	print("Purchased ship earned: ",{"hull":paid.loadout.ship_id,"kind":offer.mission.kind,"reward":offer.mission.reward+offer.mission.bonus,"wallet":paid.contracts.credits,"cursor":paid.campaign_cursor,"deltas":_pilot_deltas})
