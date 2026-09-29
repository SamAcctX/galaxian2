extends "res://tests/wingman_waypoint_application.gd"
## Earned mission preparation and live waypoint orders. No career, random,
## route, actor or position fields are installed by this pilot.

func resumed_contract_valid(state: Dictionary) -> bool:
	return state.campaign_cursor==45

func verify_free_application() -> void:
	if not OS.get_environment("GOF2_WINGMAN_ROUTE_STAGE").is_empty():
		await verify_earned_route_flight();return
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var original: Dictionary=app.session.station_owner().snapshot()
	var mission: Dictionary=original.contracts.mission
	if not mission.is_empty():
		check(mission.kind==11,"Preparation must complete the retained passenger job, not replace it")
		if failures or not await visit_tractor_supplier(int(mission.station_id)):return
		if not application_step():return
		var landed: Dictionary=app.session.station_owner().snapshot()
		check(landed.contracts.pending_result.get("completed",false) and landed.contracts.credits==original.contracts.credits,"Passenger arrival did not await its earned result")
		await capture_free_application("wingman-route-passengers-delivered")
		if failures:return
		await acknowledge_recovery_result()
		var paid: Dictionary=app.session.station_owner().snapshot()
		check(paid.contracts.mission.is_empty() and paid.contracts.passengers==0,"Acknowledgement retained the delivered job")
		check(paid.contracts.credits==original.contracts.credits+int(mission.reward)+int(mission.bonus) and paid.contracts.completed_side_missions==original.contracts.completed_side_missions+1,"Passenger payment or completion count is wrong")
		check(paid.cargo==original.cargo and paid.loadout.equipment_ids==original.loadout.equipment_ids and paid.campaign_cursor==original.campaign_cursor,"Delivery changed unrelated cargo, fitting or campaign")
		if failures or not retain_recovery_save("delivered"):return
		print("Earned passenger preparation: ",{"credits":paid.contracts.credits,"station":paid.loadout.station_id,"wingmen":paid.contracts.wingmen})
	if not app.contract_action("open",-1):check(false,app.session.error);return
	for tick in 40:
		if not application_step():return
	var station: RefCounted=app.session.station_owner()
	var career: Dictionary=station.snapshot().contracts
	for id in career.offers:
		var row: Dictionary=career.offers[id]
		print("Route offer: ",{"id":id,"consumed":row.consumed,"mission":row.offer.mission,"preview":station.contract_preview(id,definitions)})
	print("Route contacts: ",career.population.contacts)
	await capture_free_application("wingman-route-earned-lounge")
	if not app.contract_action("close",-1):check(false,app.session.error);return
	if failures or not retain_recovery_save("prepared"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"Preparation changed the immutable earned input")
	print("Earned route preparation complete: ",{"input_sha256":input_hash,"station":career.station_id,"credits":career.credits,"wingmen":career.wingmen})

func verify_earned_route_flight() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	var resumed:=OS.get_environment("GOF2_WINGMAN_ROUTE_STAGE")=="resume"
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var original: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==original.contracts.wingmen and document.career.mission==original.contracts.mission and document.career.credits==original.contracts.credits,"Fresh Resume did not restore the exact earned job, wallet and crew")
	check(not original.contracts.wingmen.active.is_empty() and original.contracts.wingmen.active.names.size()==3,"The real route career lost its three paid pilots")
	if failures:return
	if not resumed:
		check(original.contracts.mission.is_empty() and original.contracts.passengers==0,"A pending career job would be replaced")
		if failures or not await accept_route_contract():return
	var accepted: Dictionary=app.session.station_owner().snapshot()
	check(accepted.contracts.mission.get("kind")==2 and accepted.contracts.mission.station_id==accepted.loadout.station_id,"The earned local route contract was not retained")
	check(accepted.contracts.wingmen==original.contracts.wingmen and accepted.contracts.credits==original.contracts.credits,"Accepting or resuming the route changed its crew or wallet")
	if failures or not await depart_for_lifetime():return
	var parent: RefCounted=app.session.flight_owner()
	var before: Dictionary=parent.snapshot()
	var path: Array=before.get("world_path",[])
	check(path.size()==2 and before.wingman_actors.actors.size()==3,"The actual contract did not construct its route and paid cast")
	if failures:return
	if resumed:command_key(KEY_V)
	else:
		command_key(KEY_E)
		var index: int=app.flight_menu.snapshot().rows.map(func(row):return row.action).find("wingmen")
		check(index>=0,"The flight menu omitted paid wingmen")
		if failures:return
		command_key(KEY_1+index)
	await capture_free_application("wingman-route-order-menu")
	resume_application_focus()
	if resumed:
		for button in [JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_A]:
			var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true;app._unhandled_input(event)
	else:command_key(KEY_3)
	app.session.rebase_time(now_us)
	var ordered: Dictionary=app.session.snapshot().wingman_actors
	check(not app.flight_menu.visible and parent.snapshot()==before,"Waypoint input remained modal or changed its retained parent")
	check(ordered.actors.all(func(actor):return actor.wingman_command==2),"Secure next waypoint ignored the real mission route")
	for route in ordered.waypoint_routes:check(not route.is_empty() and route.index==0 and route.waypoints==path,"A pilot did not retain an independent copy of the real route")
	if failures:return
	var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var completed_at:={};var closest:={};var active_frames:=0;var independent_seen:=false
	var suppression_ok:=true;var world_unchanged:=true;var moved:={};var live_captured:=false
	while now_us-started<100000000 and completed_at.size()<3:
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The route pilot died before waypoint completion");return
		if not state.contracts.pending_result.is_empty():
			check(false,"The contract resolved before waypoint acceptance: "+str(state.contracts.pending_result));return
		var cast: Dictionary=state.wingman_actors
		var target: Vector3=cast.actors[0].pose.origin
		if not pirate_step({"commands":PiratePilot.Steering.steering_toward(state.player_pose,target),"throttle":0.0,"fire":false,"strafe":0.0}):return
		var after: Dictionary=app.session.snapshot()
		cast=after.wingman_actors
		world_unchanged=world_unchanged and after.world_path==path
		for i in 3:
			var position: Vector3=cast.following.motion[i].root_pose.origin
			var distance: float=position.distance_to(path[0])
			closest[i]=minf(float(closest.get(i,INF)),distance)
			if position.distance_to(ordered.following.motion[i].root_pose.origin)>5000.0:moved[i]=true
			if cast.actors[i].wingman_command==2:
				active_frames+=1
				if cast.primary_firing.actors.any(func(row):return row.actor_id==i) or cast.systems_firing.actors.any(func(row):return row.actor_id==i):suppression_ok=false
			elif not completed_at.has(i):
				check(cast.actors[i].wingman_command==1 and cast.waypoint_routes[i].is_empty() and closest[i]<4000.0,"A pilot cleared its route without physically reaching the waypoint")
				completed_at[i]=int((now_us-started)/1000)
		if completed_at.size()>0 and completed_at.size()<3:independent_seen=true
		if now_us>=next_log:
			print("Live wingman route: ",{"elapsed_ms":int((now_us-started)/1000),"commands":cast.actors.map(func(actor):return actor.wingman_command),"closest":closest,"completed":completed_at,"player_hull":after.player.vitals.hull})
			next_log=now_us+15000000
		if now_us>=next_yield:
			await process_frame;next_yield=now_us+1000000
			if not live_captured and now_us-started>=3000000:
				await capture_free_application("wingman-route-live-flight");live_captured=true
		if failures:return
	check(completed_at.size()==3 and moved.size()==3 and active_frames>0,"Not every paid pilot physically completed its actual waypoint")
	check(independent_seen,"All pilot routes appeared to share one completion state")
	check(suppression_ok and world_unchanged and parent.snapshot()==before,"Waypoint flight fired early or mutated its shared route/retained parent")
	await capture_free_application("wingman-route-completed")
	if failures:return
	resume_application_focus();command_key(KEY_V)
	var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=true;app._unhandled_input(pad)
	app.session.rebase_time(now_us)
	check(not app.flight_menu.visible and app.session.snapshot().wingman_actors.actors.all(func(actor):return actor.wingman_command==1),"Controller Fire at will did not close the actual command menu")
	if failures or not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	check(returned.contracts.mission==accepted.contracts.mission and returned.contracts.credits==accepted.contracts.credits,"Waypoint use changed the retained job or paid an unfinished contract")
	check(returned.contracts.wingmen.active.names==accepted.contracts.wingmen.active.names and returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<accepted.contracts.wingmen.active.remaining_ms,"Docking lost or refilled the paid crew")
	check(returned.cargo==accepted.cargo and returned.loadout.equipment_ids==accepted.loadout.equipment_ids and returned.campaign_cursor==accepted.campaign_cursor,"Route flight changed unrelated cargo, equipment or campaign")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen and automatic.career.mission==returned.contracts.mission,"The actual docking autosave lost the route career")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"The route pilot modified its earned input")
	await capture_free_application("wingman-route-returned")
	print("Earned waypoint flight accepted: ",{"resumed":resumed,"input_sha256":input_hash,"world_path":path,"completed_ms":completed_at,"active_frames":active_frames,"credits":returned.contracts.credits,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"timing":_pilot_deltas,"mission_completed":false})

func accept_route_contract() -> bool:
	if not app.contract_action("open",-1):check(false,app.session.error);return false
	for tick in 40:
		if not application_step():return false
	var station: RefCounted=app.session.station_owner()
	var before: Dictionary=station.snapshot();var chosen:=-1
	for id in before.contracts.offers:
		var row: Dictionary=before.contracts.offers[id]
		var quote: Dictionary=station.contract_preview(id,definitions)
		if not row.consumed and row.offer.mission.kind==2 and row.offer.mission.station_id==before.loadout.station_id and quote.get("can_accept",false) and not quote.get("replacement_required",true):chosen=int(id);break
	check(chosen>=0,"No actual local protection contract is available")
	if failures:return false
	var offer: Dictionary=before.contracts.offers[chosen].offer
	app.lounge_panel.select_contact(chosen)
	for tick in 40:
		if not application_step():return false
	press_coordinate_key(KEY_ENTER)
	check(app.lounge_panel.snapshot().confirming,"The earned contract skipped player consent")
	await capture_free_application("wingman-route-contract-quote")
	if failures:return false
	resume_application_focus();press_coordinate_key(KEY_ENTER)
	var accepted: Dictionary=app.session.station_owner().snapshot()
	check(accepted.contracts.mission==offer.mission and accepted.contracts.accepted_contact.offer==offer,"Consent did not preserve the real quoted job")
	if failures or not app.contract_action("close",-1):return false
	return retain_recovery_save("accepted")
