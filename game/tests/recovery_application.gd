extends "res://tests/defense_unlocked_application.gd"
## Earned equipment, a generated client, player fire and timed tractor aiming.
const RecoverySteering=preload("res://tests/fixtures/expedition_flight_pilot.gd")

func requested_contract_kind() -> int:return 5 if OS.get_environment("GOF2_SALVAGE_TEST")=="1" else 3
func contract_search_stations() -> Array:return [-1,36,38,39,35]
func contract_destination_allowed(station_id: int) -> bool:return station_id in [35,36,37,38,39]
func accepts_requested_contract(mission: Dictionary) -> bool:return mission.kind==requested_contract_kind() and mission.difficulty<=2

func resumed_contract_valid(state: Dictionary) -> bool:
	return super.resumed_contract_valid(state) or (state.contracts.get("contract_phase")=="return_delivery" and state.contracts.accepted_contact.offer.mission.kind==requested_contract_kind())

func verify_free_application() -> void:
	var state: Dictionary=app.session.station_owner().snapshot()
	if state.contracts.get("contract_phase")=="return_delivery":
		app.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"))
		check(state.contracts.passengers==0 and state.cargo.entries.any(func(row):return row.get("mission",false) and row.item_id in [116,117]),"Fresh Resume lost the recovery container or invented passengers")
		await verify_return_delivery(state,state,{"mission":state.contracts.accepted_contact.offer.mission})
	else:await super.verify_free_application()

func verify_delivery_route(original: Dictionary,_before: Dictionary,offer: Dictionary,accepted: Dictionary,requested_kind: int) -> void:
	check(requested_kind==requested_contract_kind(),"The recovery pilot accepted another kind")
	if not app.equipment_action("open"):check(false,app.session.error);return
	for change in [[91,81],[86,55]]:
		if app.session.station_owner().snapshot().loadout.equipment_ids.has(change[0]):
			if not app.equipment_action("unmount",change[0]) or not app.equipment_action("mount",change[1]):check(false,app.session.error);return
	if not app.equipment_action("close"):check(false,app.session.error);return
	accepted=app.session.station_owner().snapshot()
	check(accepted.loadout.equipment_ids.has(68) and accepted.loadout.equipment_ids.has(81) and accepted.contracts.passengers==0,"The recovery departure lost its owned tractor/scanner or retained replaced passengers")
	if not retain_recovery_save("accepted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	if int(accepted.loadout.station_id)!=int(offer.mission.station_id) and not await travel_application(int(offer.mission.station_id)):return
	var initial: Dictionary=app.session.snapshot()
	check(initial.encounter.combat.actors.size()==offer.mission.quantity and initial.encounter.combat.actors.back().name_text_id==1600,"Recovery did not construct its quoted pirates and Hijacker")
	await capture_free_application("recovery-arrival")
	if not await fly_recovery_job(initial):return
	var picked: Dictionary=app.session.snapshot();var pending: Dictionary=picked.contracts.pending_result
	var won:=OS.get_environment("GOF2_RECOVERY_FAILURE")!="1"
	check(pending.get("completed",false)==won and picked.contracts.credits==accepted.contracts.credits and picked.contracts.completed_side_missions==accepted.contracts.completed_side_missions,"The pickup result paid, counted or misreported the job")
	if won:
		check(pending.result_text_id==378 and picked.contracts.mission.kind==11 and picked.contracts.mission.station_id==accepted.contracts.accepted_contact.station_id,"Pickup did not redirect the job to its client")
	await capture_free_application("recovery-pickup-result")
	var serial: int=pending.serial
	await acknowledge_recovery_result()
	var resumed: Dictionary=app.session.snapshot()
	check(resumed.contracts.pending_result.is_empty() and resumed.contracts.credits==accepted.contracts.credits,"Pickup acknowledgement paid or remained open")
	check(not app.contract_action("result_close",serial) and app.session.snapshot()==resumed,"Pickup acknowledged twice")
	if not application_step() or not await dock_application():return
	if not won:
		check(app.session.station_owner().snapshot().contracts.mission.is_empty(),"Container loss kept the failed job")
		await capture_free_application("recovery-failed-station")
		retain_recovery_save("failed");return
	if not retain_recovery_save("return"):return
	await capture_free_application("recovery-return-checkpoint")
	await verify_return_delivery(original,accepted,offer)

func verify_return_delivery(original: Dictionary,accepted: Dictionary,offer: Dictionary) -> void:
	var client:=int(accepted.contracts.accepted_contact.station_id)
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await travel_application(client) or not await dock_application() or not application_step():return
	var delivered: Dictionary=app.session.station_owner().snapshot();var pending: Dictionary=delivered.contracts.pending_result
	check(not pending.is_empty() and pending.get("completed",false) and delivered.contracts.credits==accepted.contracts.credits,"The client did not await acknowledgement before paying")
	await capture_free_application("recovery-delivery-result")
	var serial: int=pending.serial
	await acknowledge_recovery_result()
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(paid.contracts.mission.is_empty() and paid.contracts.credits==accepted.contracts.credits+offer.mission.reward+offer.mission.bonus and paid.contracts.completed_side_missions==accepted.contracts.completed_side_missions+1,"The return delivery paid the wrong amount or completion count")
	check(paid.campaign_cursor==original.campaign_cursor and paid.mission==original.mission and paid.contracts.passengers==0,"Recovery advanced the story or invented passengers")
	check(not paid.cargo.entries.any(func(row):return row.get("mission",false) and row.item_id in [116,117]),"The client retained delivered mission cargo")
	check(not app.contract_action("result_close",serial) and app.session.station_owner().snapshot()==paid,"Client delivery paid twice")
	await capture_free_application("recovery-paid-station")
	if not retain_recovery_save("paid"):return
	print("Recovery earned: ",{"credits":paid.contracts.credits,"jobs":paid.contracts.completed_side_missions,"cursor":paid.campaign_cursor,"client":client,"target":offer.mission.station_id,"deltas":_pilot_deltas})

func acknowledge_recovery_result() -> void:
	resume_application_focus();app.present_session()
	if OS.get_environment("GOF2_PIRATE_RESULT_INPUT")=="mouse":
		var point: Vector2=root.get_final_transform()*app.lounge_panel._yes.get_global_rect().get_center()
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
		Input.parse_input_event(motion);Input.flush_buffered_events()
		for down in [true,false]:
			var click:=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
			Input.parse_input_event(click);Input.flush_buffered_events()
		await process_frame;resume_application_focus()
	else:
		var key:=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.pressed=true;app._unhandled_input(key)

func retain_recovery_save(label: String) -> bool:
	if not app.save_station(false):check(false,app._save_file.error);return false
	var destination:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join(label+".gof2save")
	check(DirAccess.copy_absolute(app.station_save_path(),destination)==OK,"The recovery checkpoint could not be retained")
	var restored: Dictionary=app._save_file.load_document(destination,definitions,catalogue,source)
	var state: Dictionary=app.session.station_owner().snapshot()
	check(not restored.is_empty() and restored.career.mission==state.contracts.mission and restored.career.credits==state.contracts.credits and restored.career.completed_side_missions==state.contracts.completed_side_missions,"Recovery autosave lost its active phase or reward")
	return failures==0

func dock_application() -> bool:
	var before: Dictionary=app.session.snapshot()
	print("Recovery docking entry: ",{"position":before.player_pose.origin,"guidance":before.station_autopilot})
	var docked: bool=await super.dock_application()
	if not docked:
		var after: Dictionary=app.session.snapshot()
		print("Recovery docking stopped: ",{"position":after.player_pose.origin,"guidance":after.station_autopilot,"hull":after.player.vitals.hull})
		await capture_free_application("recovery-docking-stopped")
	return docked

func fly_recovery_job(initial: Dictionary) -> bool:
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us+1000000;var next_log:=now_us
	var carrier: int=initial.encounter.combat.actors.size()-1
	var beam_seen:=false;var combat_seen:=false
	var won:=OS.get_environment("GOF2_RECOVERY_FAILURE")!="1"
	while now_us-started<600000000:
		var state: Dictionary=app.session.snapshot()
		if not state.contracts.pending_result.is_empty():
			check(state.contracts.pending_result.completed==won and state.progress.player_kills>initial.progress.player_kills,"Recovery did not reach its input-earned outcome")
			if won:check(beam_seen and state.cargo.entries.any(func(row):return row.get("mission",false) and row.item_id in [116,117]),"Recovery succeeded without its actual tractor transfer")
			return failures==0
		if app.session.flight_owner().death_active():check(false,"The recovery pilot died before its container result");return false
		var actor: Dictionary=state.encounter.combat.actors[carrier]
		var input: Dictionary
		if actor.vitals.hull>0:
			var escorts: Array=range(carrier).filter(func(id):return state.encounter.combat.actors[id].vitals.hull>0)
			var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
			var reach:=float(weapon.speed_units_per_millisecond)*float(weapon.lifetime_ms)
			pilot.firing_range=reach*0.9
			input=pilot.controls_at_time(state,float(state.world_elapsed_ms),escorts if not escorts.is_empty() else [carrier],false)
			input.throttle=1.0 if input.distance>minf(18000.0,reach*0.6) else 0.0
			if input.distance<35000.0:input.strafe=1.0
		else:
			var distance: float=state.player_pose.origin.distance_to(actor.position)
			input={"commands":RecoverySteering.steering_toward(state.player_pose,actor.position) if won else Vector2(0,1),"throttle":1.0 if not won or distance>2500.0 else 0.0,"fire":false,"strafe":0.0,"target":carrier,"distance":distance}
			if won and state.tractor.active:input.commands=Vector2.ZERO;input.throttle=0.0
		if not pirate_step(input):return false
		if not combat_seen and input.fire:await capture_free_application("recovery-combat");combat_seen=true
		if not beam_seen and app.session.snapshot().tractor_frame.get("phase")=="pulling":await capture_free_application("recovery-tractor");beam_seen=true
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("Recovery pilot: ",{"seconds":(now_us-started)/1000000.0,"hull":state.player.vitals.hull,"actors":state.encounter.combat.actors.map(func(row):return row.vitals.hull),"target":input.target,"distance":input.distance,"tractor":state.tractor.get("elapsed_ms",0),"phase":state.tractor_frame.get("phase","")})
			next_log=now_us+20000000
	check(false,"The recovery pilot did not reach its container result");return false
