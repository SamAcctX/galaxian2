extends "res://tests/ordinary_contract_application.gd"
## A native saved career, generated lounge offer and real local travel.
const PiratePilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
var _pilot_frames:=0
var _pilot_deltas:={}

func application_step() -> bool:
	if not app.session is FlightSession:return super.application_step()
	var admitted: RefCounted=app.session._world.mission_context_owner()
	if admitted==null or admitted.advances_campaign():return super.application_step()
	resume_application_focus();now_us+=pirate_delta_us()
	if not app.session.step(now_us):check(false,app.session.error);return false
	app.present_session()
	if app._transition_failed:check(false,app.status.text);return false
	return true

func release_application_flight() -> bool:
	var admitted: RefCounted=app.session._world.mission_context_owner()
	if admitted==null or admitted.advances_campaign():return await super.release_application_flight()
	app.session.rebase_time(now_us)
	var started:=now_us;var next_yield:=now_us+1000000
	while not app.session.can_control() and now_us-started<20000000:
		if not application_step():return false
		if OS.get_environment("GOF2_PIRATE_ENTRY")=="skip" and app.session.can_skip_cinematic():
			var before: Dictionary=app.session.snapshot()
			var key:=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.pressed=true;app._unhandled_input(key)
			var after: Dictionary=app.session.snapshot()
			check(after.entry_released and after.world_elapsed_ms==before.world_elapsed_ms and after.contracts==before.contracts and after.player.vitals==before.player.vitals,"Enter skipped more than the ordinary introduction")
			await capture_free_application("freelance-pirate-skipped-entry")
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	check(app.session.can_control() and app.session.flight_audio!=null,"The freelance introduction did not release original flight controls and sound")
	return failures==0

func requested_contract_kind() -> int:return 4

func contract_cast_valid(actors: Array) -> bool:
	return not actors.is_empty() and actors.all(func(actor):return actor.actor_kind==8)

func contract_target_ids(actors: Array) -> Array:return range(actors.size())

func contract_targets_retired(actors: Array,targets: Array) -> bool:
	return targets.all(func(id):return actors[id].actor_mode==4)

func expects_contract_success() -> bool:return true

func contract_credit_delta(offer: Dictionary,won: bool) -> int:
	return int(offer.mission.reward)+int(offer.mission.bonus) if won else 0

func accepts_requested_contract(mission: Dictionary) -> bool:
	var selected:=OS.get_environment("GOF2_PIRATE_DIFFICULTY")
	return super.accepts_requested_contract(mission) and (selected.is_empty() or mission.difficulty==selected.to_int())

func flight_world_seconds() -> int:
	var selected:=OS.get_environment("GOF2_PIRATE_VISIT_TIME")
	return 1789100029 if selected.is_empty() else selected.to_int()

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if directory.is_empty():check(false,"The freelance playtest requires isolated autosaves");return
	app.enable_saves(directory)
	var starter:=OS.get_environment("GOF2_PIRATE_STARTER")
	if starter in ["standard","alternate"]:
		app.show();app.present_session();await process_frame;resume_application_focus()
		var before: Dictionary=app.session.station_owner().snapshot()
		var selected:=0 if starter=="standard" else 22
		var previous:=22 if starter=="standard" else 0
		if not app.equipment_action("open") or not app.equipment_action("unmount",previous) or not app.equipment_action("mount",selected) or not app.equipment_action("close"):
			check(false,app.session.error);return
		var fitted: Dictionary=app.session.station_owner().snapshot()
		check(fitted.loadout.equipment_ids.has(selected) and not fitted.loadout.equipment_ids.has(previous) and fitted.cargo.entries.has({"item_id":previous,"quantity":1}) and fitted.contracts.credits==before.contracts.credits and fitted.contracts.mission==before.contracts.mission,"Fitting the owned starter gun changed the accepted career")
		await capture_free_application("freelance-"+starter+"-starter-fitted")
	var saved: Dictionary=app.session.station_owner().snapshot()
	if saved.contracts.mission.get("kind")==requested_contract_kind():
		app.show();app.present_session();await process_frame;resume_application_focus()
		await verify_delivery_route(saved,saved,{"mission":saved.contracts.mission},saved,requested_contract_kind())
	else:await super.verify_free_application()

func verify_delivery_route(original: Dictionary,before: Dictionary,offer: Dictionary,accepted: Dictionary,requested_kind: int) -> void:
	check(requested_kind==requested_contract_kind(),"The freelance pilot selected another job")
	if not app.save_station(false):check(false,app._save_file.error);return
	check(DirAccess.copy_absolute(app.station_save_path(),OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("accepted.gof2save"))==OK,"The playtest could not retain the accepted autosave")
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	if int(accepted.loadout.station_id)!=int(offer.mission.station_id) and not await travel_application(int(offer.mission.station_id)):return
	var arrived: Dictionary=app.session.snapshot()
	check(arrived.contracts.mission==offer.mission and arrived.contracts.credits==accepted.contracts.credits,"Arriving in space paid or discarded the Pirate job")
	check(arrived.campaign_cursor==original.campaign_cursor and arrived.mission==original.mission,"The freelance target replaced the pending campaign")
	check(contract_cast_valid(arrived.encounter.combat.actors),"The freelance target constructed the wrong cast")
	await capture_free_application("freelance-pirate-arrival")
	print("Freelance arrival: ",{"difficulty":offer.mission.difficulty,"pirates":arrived.encounter.combat.actors.size(),"credits_before":before.contracts.credits})
	if not await fly_contract_job(arrived):return
	if OS.get_environment("GOF2_PIRATE_FAILURE")=="1":return
	var pending: Dictionary=app.session.snapshot()
	var result: Dictionary=pending.contracts.pending_result
	var won:=expects_contract_success()
	check(not result.is_empty() and result.get("completed",false)==won and app.lounge_panel.visible and not app.session.can_control(),"The job did not open its expected modal result")
	check(pending.contracts.credits==accepted.contracts.credits and pending.contracts.completed_side_missions==accepted.contracts.completed_side_missions+int(won),"The result lost its success count or paid before acknowledgement")
	await capture_free_application("freelance-pirate-result")
	var serial: int=result.serial
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
	var paid: Dictionary=app.session.snapshot()
	if not paid.contracts.pending_result.is_empty():
		check(false,"Acknowledgement retained the finished job: "+app.session.error+" · "+str({"status":app.session.status,"active":app.lounge_panel._active,"focus":app._focused,"pauses":app.session._pauses}));return
	check(paid.contracts.mission.is_empty(),"Acknowledgement retained the finished job")
	var reward:=contract_credit_delta(offer,won)
	check(paid.contracts.credits==maxi(0,accepted.contracts.credits+reward) and paid.contracts.completed_side_missions==accepted.contracts.completed_side_missions+int(won),"The freelance result paid another reward or count")
	check(paid.mission==original.mission and paid.campaign_cursor==original.campaign_cursor,"Freelance payment advanced the campaign")
	check(not app.contract_action("result_close",serial) and app.session.snapshot()==paid,"Repeated acknowledgement changed the career")
	check(app.session.flight_audio.snapshot().history.filter(func(row):return row.get("source_id")==36).size()==int(won),"The result played the wrong number of payment sounds")
	if not application_step() or not await dock_application():return
	var docked: Dictionary=app.session.station_owner().snapshot()
	check(docked.contracts.credits==paid.contracts.credits and docked.contracts.mission.is_empty() and docked.mission==original.mission,"Docking changed the settled freelance career")
	await capture_free_application("freelance-pirate-paid-station")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.credits==paid.contracts.credits and saved.career.completed_side_missions==paid.contracts.completed_side_missions and saved.career.mission.is_empty(),"Autosave lost the earned Pirate payment")
	print("Freelance saved: ",{"path":app.station_save_path(),"credits":paid.contracts.credits,"completed":paid.contracts.completed_side_missions,"campaign_cursor":paid.campaign_cursor,"deltas":_pilot_deltas})

func dock_application() -> bool:
	resume_application_focus()
	if not app.session.action("autopilot"):check(false,app.session.error);return false
	var started:=now_us;var next_yield:=now_us+2000000
	while now_us-started<200000000 and app.session.status!="station_transition_required":
		if not application_step():return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+2000000
	check(app.session.status=="station_transition_required","The paid freelance pilot never reached physical station docking")
	if failures or not app.enter_station(now_us,42):check(false,app.status.text);return false
	app.session.rebase_time(now_us)
	return failures==0

func pirate_delta_us() -> int:
	var delta:=100000
	var timing:=OS.get_environment("GOF2_PIRATE_TIMING")
	if timing=="144hz":delta=int((_pilot_frames+1)*1000000/144)-int(_pilot_frames*1000000/144)
	elif timing=="variable":delta=[6944,16667,41667,8333,100000,11111][_pilot_frames%6]
	_pilot_frames+=1;_pilot_deltas[delta]=int(_pilot_deltas.get(delta,0))+1
	return delta

func pirate_step(input: Dictionary) -> bool:
	resume_application_focus()
	if app.session.can_control():
		for adjustment in 10:
			var throttle: float=app.session.snapshot().input_throttle
			if absf(throttle-float(input.throttle))<.01:break
			if not app.session.action("throttle_up" if throttle<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
	now_us+=pirate_delta_us()
	if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
	app.present_session()
	return true

func fly_contract_job(initial: Dictionary) -> bool:
	if OS.get_environment("GOF2_PIRATE_RESULT_FIXTURE")=="1":
		if not await damage_contract_targets(4):return false
		for tick in 160:
			if not application_step():return false
			if not app.session.snapshot().contracts.pending_result.is_empty():return true
		check(false,"The explicit result fixture did not retire its pirates");return false
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us+2000000;var next_log:=now_us
	var failure: bool=OS.get_environment("GOF2_PIRATE_FAILURE")=="1"
	var live_captured:=false;var shots:=0
	var targets: Array=contract_target_ids(initial.encounter.combat.actors)
	while now_us-started<600000000:
		var state: Dictionary=app.session.snapshot()
		if not state.contracts.pending_result.is_empty():
			var won:=expects_contract_success()
			check(not failure and shots>0 and state.contracts.pending_result.completed==won and contract_targets_retired(state.encounter.combat.actors,targets),"The input pilot did not reach the expected freelance result")
			if won:check(state.progress.player_kills>initial.progress.player_kills,"The input pilot did not defeat a hostile fighter")
			return failures==0
		if app.session.flight_owner().death_active():
			check(failure,"The input pilot died before defeating the pirates")
			check(state.contracts.credits==initial.contracts.credits and state.contracts.mission==initial.contracts.mission,"Player death paid or removed the unfinished Pirate job")
			while app.session.snapshot().player_destruction.phase!="game_over":
				if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
				if now_us-started>=600000000:break
			await capture_free_application("freelance-pirate-game-over")
			check(app.session.snapshot().player_destruction.phase=="game_over","Pirate death did not reach Game Over")
			var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
			check(not saved.is_empty() and saved.career.mission==initial.contracts.mission and saved.career.credits==initial.contracts.credits,"Game Over replaced the accepted retry checkpoint")
			if failures:return false
			var fire:=InputEventKey.new();fire.physical_keycode=KEY_SPACE;fire.pressed=true;app._unhandled_input(fire)
			if not app.enter_game_over():check(false,app.status.text);return false
			var resume:=InputEventKey.new();resume.physical_keycode=KEY_F9;resume.pressed=true;app._unhandled_input(resume)
			if app.session==null:check(false,app._save_notice.text);return false
			var retry: Dictionary=app.session.station_owner().snapshot()
			check(retry.contracts.mission==initial.contracts.mission and retry.contracts.credits==initial.contracts.credits and retry.contracts.completed_side_missions==initial.contracts.completed_side_missions,"Resume after Game Over lost or completed the retry job")
			await capture_free_application("freelance-pirate-retry-station")
			return failures==0
		if not live_captured and state.encounter.primaries.guns[0].projectiles.slots.any(func(slot):return slot!=null):
			await capture_free_application("freelance-pirate-combat");live_captured=true
		var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
		var reach:=float(weapon.speed_units_per_millisecond)*float(weapon.lifetime_ms)
		pilot.firing_range=reach*0.9
		var input: Dictionary=pilot.controls_at_time(state,float(state.world_elapsed_ms),targets,false)
		# Keep the orbit within the fitted gun's reach. The close approach uses
		# the pilot's pursuit and alternating strafes for a single opponent.
		if OS.get_environment("GOF2_PIRATE_APPROACH")!="close":
			input.throttle=1.0 if input.distance>minf(18000.0,reach*0.6) else 0.0
			if input.distance<35000.0:input.strafe=1.0
		if failure:input.fire=false;input.strafe=0.0
		if input.fire:shots+=1
		if not pirate_step(input):return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+2000000
		if now_us>=next_log:
			print("Freelance pilot: ",{"elapsed":(now_us-started)/1000000.0,"hull":state.player.vitals.hull,"pirates":state.encounter.combat.actors.map(func(actor):return actor.vitals.hull),"target":input.target,"distance":input.distance})
			next_log=now_us+20000000
	check(false,"The input-only Pirate pilot did not reach an outcome");return false

func run_resumed_job() -> void:
	if not open_application_content(OS.get_cmdline_user_args()):quit(1);return
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	if directory.is_empty() or saved.is_empty():check(false,"Resume requires an earned source file and an isolated destination");quit(1);return
	app=Host.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(source,definitions,visual);app.set_process(false);app.enable_saves(directory)
	DirAccess.make_dir_recursive_absolute(app.station_save_path().get_base_dir())
	if DirAccess.copy_absolute(saved,app.station_save_path())!=OK:check(false,"Could not retain the source checkpoint for Resume");app.free();quit(1);return
	app.show();app.present_session();await process_frame;resume_application_focus()
	check(app.session==null and app._load_button.visible,"A fresh application omitted Resume")
	var key:=InputEventKey.new();key.physical_keycode=KEY_F9;key.pressed=true;app._unhandled_input(key)
	if app.session==null:check(false,app._save_notice.text);app.free();quit(1);return
	var restored: Dictionary=app.session.station_owner().snapshot()
	check(not app.session.snapshot().dialogue.visible and not app.session.snapshot().lounge_open,"Resume replayed a modal conversation")
	await capture_free_application("freelance-resumed-station")
	if OS.get_environment("GOF2_PIRATE_RESUME_PAID")=="1":
		var document: Dictionary=app._save_file.load_document(saved,definitions,catalogue,source)
		if document.is_empty():check(false,app._save_file.error);app.free();quit(1);return
		check(restored.campaign_cursor==document.career.campaign_cursor and restored.contracts.credits==document.career.credits and restored.contracts.completed_side_missions==document.career.completed_side_missions and restored.contracts.mission.is_empty(),"Fresh Resume lost or repeated the saved freelance payment")
		if app.request_departure() and app.enter_first_flight(now_us,4096,flight_world_seconds()) and await release_application_flight():
			var flight: Dictionary=app.session.snapshot()
			check(flight.contracts.credits==restored.contracts.credits and flight.contracts.completed_side_missions==restored.contracts.completed_side_missions and flight.mission==restored.mission,"Departure after Resume repeated the payment or advanced the campaign")
			check(flight.player.equipment_ids==restored.loadout.equipment_ids,"Departure after Resume lost the saved fitted equipment")
			check(flight.encounter.combat.get("contract_encounter",{}).is_empty() and flight.encounter.combat.free_context.mission_kind==-1,"The paid job respawned its mission pirates")
			await capture_free_application("freelance-paid-resumed-flight")
		else:check(false,app.status.text)
	else:
		check(restored.contracts.mission.get("kind")==requested_contract_kind(),"Fresh Resume discarded the accepted freelance job")
		if failures==0:await verify_free_application()
	app.free();print("Freelance Resume: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
