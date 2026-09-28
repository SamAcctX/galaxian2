extends "res://tests/freelance_unlocked_application.gd"
## A generated local spy job, input combat, physical docking and saved result.

func _initialize() -> void:
	if OS.get_environment("GOF2_INFORMER_RESUME")=="1":call_deferred("run_resumed_job")
	else:super._initialize()

func requested_contract_kind() -> int:return 13
func contract_search_stations() -> Array:return [-1]
func contract_destination_allowed(station_id: int) -> bool:return station_id in [35,36,37,38,39]
func accepts_requested_contract(mission: Dictionary) -> bool:return mission.kind==13
func expects_contract_success() -> bool:return OS.get_environment("GOF2_INFORMER_FAILURE")!="1"

func verify_delivery_route(original: Dictionary,before: Dictionary,offer: Dictionary,accepted: Dictionary,requested_kind: int) -> void:
	check(requested_kind==13,"The pilot selected a different contract")
	if not app.save_station(false):check(false,app._save_file.error);return
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("accepted.gof2save"))==OK,"Could not retain the accepted Informer checkpoint")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	if int(accepted.loadout.station_id)!=int(offer.mission.station_id) and not await travel_application(int(offer.mission.station_id)):return
	var arrived: Dictionary=app.session.snapshot();var actors: Array=arrived.encounter.combat.actors
	check(actors.size()==7 and actors[0].name_text_id==1652 and actors.all(func(actor):return actor.population_group=="patrol"),"The Informer flight constructed another cast")
	check(arrived.contracts.credits==accepted.contracts.credits and arrived.mission==original.mission,"Flight changed money or the pending story")
	await capture_free_application("informer-arrival")
	print("Informer accepted: ",offer.mission)
	if not await fly_informer(arrived):return
	var earned: Dictionary=app.session.snapshot()
	check(earned.contracts.pending_result.is_empty() and app.session.can_control() and earned.contracts.credits==accepted.contracts.credits,"The objective opened a flight result or paid before docking")
	await capture_free_application("informer-return-required")
	if not await dock_application() or not application_step():return
	app.present_session();await process_frame;resume_application_focus()
	var pending: Dictionary=app.session.station_owner().snapshot();var won:=expects_contract_success()
	check(app.lounge_panel.visible and not pending.contracts.pending_result.is_empty() and pending.contracts.pending_result.completed==won and pending.contracts.credits==accepted.contracts.credits,"Docking lost the outcome or paid before Close")
	if failures:return
	await capture_free_application("informer-result")
	var serial: int=pending.contracts.pending_result.serial
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
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(paid.contracts.mission.is_empty() and paid.contracts.pending_result.is_empty() and not paid.contracts.has("station_outcome"),"Acknowledgement kept the finished job or outcome")
	check(paid.contracts.credits==accepted.contracts.credits+(offer.mission.reward+offer.mission.bonus if won else 0) and paid.contracts.completed_side_missions==accepted.contracts.completed_side_missions+int(won),"The station settled the wrong payment or completion count")
	check(paid.campaign_cursor==original.campaign_cursor and paid.mission==original.mission and paid.cargo==pending.cargo and paid.contracts.delivery_statistics==accepted.contracts.delivery_statistics,"Informer settlement changed the campaign or cargo")
	check(not app.contract_action("result_close",serial) and app.session.station_owner().snapshot()==paid,"Repeated result input changed the paid career")
	await capture_free_application("informer-paid-station")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.credits==paid.contracts.credits and saved.career.completed_side_missions==paid.contracts.completed_side_missions and saved.career.mission.is_empty(),"The station autosave lost the earned Informer result")
	print("Informer saved: ",{"credits":paid.contracts.credits,"completed":paid.contracts.completed_side_missions,"campaign_cursor":paid.campaign_cursor,"deltas":_pilot_deltas,"path":app.station_save_path()})

func fly_informer(initial: Dictionary) -> bool:
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us+2000000;var next_log:=now_us
	var target:=0 if expects_contract_success() else 1
	var captured:=false;var shots:=0
	while now_us-started<600000000:
		var state: Dictionary=app.session.snapshot()
		if state.contracts.get("station_outcome",0)!=0:
			check(shots>0 and state.contracts.station_outcome==(1 if expects_contract_success() else 2),"The input pilot reached another Informer outcome")
			return failures==0
		if app.session.flight_owner().death_active():check(false,"The pilot died before finishing the spy objective");return false
		var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
		pilot.firing_range=float(weapon.speed_units_per_millisecond)*float(weapon.lifetime_ms)*0.9
		var input: Dictionary=pilot.controls_at_time(state,float(state.world_elapsed_ms),[target],false)
		if input.fire:shots+=1
		if not pirate_step(input):return false
		if not captured and input.fire:
			await capture_free_application("informer-target");captured=true
		if now_us>=next_yield:await process_frame;next_yield=now_us+2000000
		if now_us>=next_log:
			print("Informer pilot: ",{"elapsed":(now_us-started)/1000000.0,"player_hull":state.player.vitals.hull,"target":target,"distance":input.distance,"ships":state.encounter.combat.actors.map(func(actor):return actor.vitals.hull)})
			next_log=now_us+20000000
	check(false,"The input pilot did not finish the spy objective");return false
