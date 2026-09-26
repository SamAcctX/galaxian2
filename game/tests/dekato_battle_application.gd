extends "res://tests/dekato_arrival_application.gd"
## Genuine source202 career and local arrival, followed only by flight inputs.
const ConvoyPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
var pilot_timing:="100ms"
var pilot_losses:=0
var pilot_entry:="watch"
var pilot_frame:=0
var pilot_deltas:={}
var pilot_dialogue_inputs:=[]

func open_application_content(args: PackedStringArray) -> bool:
	if not super.open_application_content(args):return false
	if OS.has_environment("GOF2_DEKATO_TIMING"):pilot_timing=OS.get_environment("GOF2_DEKATO_TIMING")
	if OS.has_environment("GOF2_DEKATO_ENTRY"):pilot_entry=OS.get_environment("GOF2_DEKATO_ENTRY")
	var losses:=OS.get_environment("GOF2_DEKATO_LOSSES")
	check(losses in ["","0","1","2"],"Choose zero, one or two input-earned freighter losses")
	pilot_losses=losses.to_int()
	check(pilot_timing in ["100ms","144hz","variable"] and pilot_entry in ["watch","skip-request"],"Unknown Dekato player-path option")
	return failures==0

func verify_free_application() -> void:
	await super.verify_free_application()
	if failures:return
	var initial: Dictionary=app.session.snapshot()
	var retained_hash:=FileAccess.get_sha256(app.station_save_path())
	if not await win_earned_convoy(initial):return
	if pilot_losses==2:
		await acknowledge_earned_failure(initial,retained_hash)
		return
	var events: Array=DekatoArrival.declarations(definitions).mission.result_events
	check(events.size()==2,"The source victory must have its original two result pages")
	if failures:return
	for index in events.size():
		var pending: Dictionary=app.session.snapshot()
		check(pending.campaign_cursor==38 and pending.contracts.campaign_cursor==38 and pending.dialogue.text_id==int(events[index].text_id) and pending.dialogue.voice_event_id==int(events[index].voice_event_id),"Victory advanced before the original final acknowledgement")
		if index==events.size()-1:
			var original: RefCounted=app.session.flight_owner()
			var original_before: Dictionary=original.snapshot()
			var rejected: RefCounted=original.fork_for_frame()
			rejected._entry=original._entry.duplicate(true)
			rejected._entry.departure.dekato_source_receipt.source_binding_id="foreign"
			var refused_before: Dictionary=rejected.snapshot()
			check(rejected.navigate("next")==null and rejected.snapshot()==refused_before and original.snapshot()==original_before and app.session.snapshot()==pending,"A changed source receipt partially acknowledged the actual battle")
		await capture_free_application("earned202-dekato-result-"+str(index))
		if failures or not await pilot_dialogue_next("keyboard" if index==0 else "mouse"):return
	var completed: Dictionary=app.session.snapshot()
	check(completed.dekato_source_receipt==definitions.dekato_source_receipt(),"The earned result lost its original supplemental declaration receipt")
	check(completed.campaign_cursor==39 and completed.contracts.campaign_cursor==39 and completed.progress.campaign_cursor==39 and completed.combat_objective_acknowledged,"The actual victory did not commit cursor39 atomically")
	check(completed.mission=={"kind":11,"station_id":30,"reward":0,"bonus":0,"source_parameter":0} and completed.reward_credits==0,"The original result lost its pending station30 visit or paid an invented reward")
	check(completed.location.station_id==22 and completed.player.campaign_cursor==38 and app.session.flight_owner()._entry.campaign_cursor==38,"Acknowledgement rebuilt or relabelled the living world")
	for key in ["credits","passengers","mission","accepted_contact","blueprints","void_source","completed_side_missions","delivery_statistics","travel_statistics"]:
		check(completed.contracts[key]==initial.contracts[key],"The convoy result changed independent career: "+key)
	check(completed.cargo==initial.cargo and completed.player.vitals.hull>0,"Victory changed carried cargo or ignored player survival")
	check(app.session.flight_owner().prepare_station().is_empty(),"A result acknowledgement bypassed physical docking")
	check(PostProbeNavigation.destination_supported(definitions,39,completed.mission,30)==PostProbeCampaign.onward_available(definitions),"The pending Néhma destination disagrees with the attached source capability")
	check(not app.session.navigate("next") and app.session.snapshot()==completed,"Duplicate acknowledgement changed the completed career")
	if failures or not battle_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return
	check(app.session.snapshot().contracts.campaign_cursor==39 and app.session.snapshot().world_elapsed_ms>completed.world_elapsed_ms,"The living world stopped retaining its acknowledged career")
	check(FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==SOURCE_SHA and FileAccess.get_sha256(app.station_save_path())==retained_hash,"The flight-only victory overwrote its viable Eanya station checkpoint")
	await capture_free_application("earned202-dekato39-live")
	if not failures:print("Earned Eanya20->Dekato22 victory: losses=",pilot_losses," timing=",pilot_timing," entry=",pilot_entry,"; final38->39 acknowledgement, live career retained, dialogue inputs=",pilot_dialogue_inputs,"; host deltas_us=",pilot_deltas)

func pilot_delta_us() -> int:
	var delta:=100000
	if pilot_timing=="144hz":delta=int((pilot_frame+1)*1000000/144)-int(pilot_frame*1000000/144)
	elif pilot_timing=="variable":delta=[6944,16667,41667,8333,100000,11111][pilot_frame%6]
	pilot_frame+=1
	pilot_deltas[delta]=int(pilot_deltas.get(delta,0))+1
	return delta

func application_step() -> bool:
	# The inherited earned Eanya transit retains its proven cadence. The
	# selected matrix covers Dekato entry, briefing, combat, result and docking.
	if app.session.snapshot().get("location",{}).get("station_id")!=22:return super.application_step()
	resume_application_focus();now_us+=pilot_delta_us()
	if not app.session.step(now_us):check(false,app.session.error);return false
	app.present_session()
	check(not app._transition_failed,app.status.text)
	return failures==0

func pilot_key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()

func pilot_dialogue_next(device: String) -> bool:
	resume_application_focus();app.present_session();await process_frame
	var before: Dictionary=app.session.snapshot()
	check(before.dialogue.visible,"Input acknowledgement requires a visible original dialogue")
	if failures:return false
	if device=="keyboard":pilot_key(KEY_ENTER)
	else:
		var button: Button=app.session.scene.dialogue._next
		check(button.is_visible_in_tree() and not button.disabled,"The actual dialogue Next button is unavailable")
		if failures:return false
		# The dialogue lives inside NativeSceneView's viewport. Map its logical
		# coordinates through the real view, including the preview toolbar offset.
		var view: Control=app.viewport.get_parent()
		var point: Vector2=root.get_final_transform()*view.get_global_transform_with_canvas()*button.get_global_rect().get_center()
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
		Input.parse_input_event(motion);Input.flush_buffered_events()
		for pressed in [true,false]:
			var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=point;click.global_position=point;click.pressed=pressed
			Input.parse_input_event(click);Input.flush_buffered_events()
	await process_frame
	check(app.session.snapshot().dialogue!=before.dialogue,"The "+device+" input did not acknowledge exactly the visible page")
	pilot_dialogue_inputs.append(device)
	return failures==0

func acknowledge_story_lines(events: Array) -> bool:
	var incoming: Dictionary=app.session.snapshot()
	check(not incoming.entry_released and not incoming.dialogue.visible,"The convoy entry was already bypassed")
	if pilot_entry=="skip-request":
		check(not app.session.can_skip_cinematic(),"An unstarted arrival already offered cinematic skip")
		# The host clock's first sample only rebases time; a player's Enter
		# arrives some frames into the arrival, once its clock is running.
		for frame in 5:
			if failures or not application_step():return false
			if app.session.can_skip_cinematic():break
		var started: Dictionary=app.session.snapshot()
		check(app.session.can_skip_cinematic() and not started.entry_released and started.world_elapsed_ms>incoming.world_elapsed_ms,"The started arrival did not offer cinematic skip: "+str(skip_diagnostics()))
		if failures:return false
		await capture_free_application("earned202-dekato-skip-ready")
		resume_application_focus()
		var request_time:=now_us
		pilot_key(KEY_ENTER)
		var skipped: Dictionary=app.session.snapshot()
		check(skipped.entry_released and not skipped.dialogue.visible and app.session.can_control() and not app.session.can_skip_cinematic(),"Actual Enter did not release only the started arrival introduction")
		check(now_us==request_time and skipped.world_elapsed_ms==started.world_elapsed_ms and skipped.hud_elapsed_ms==started.hud_elapsed_ms and skipped.radio==started.radio,"Arrival skip advanced simulation time or the normal briefing/radio poll")
		for key in ["campaign_cursor","contracts","progress","mission","reward_credits","cargo","equipment","player_pose"]:
			check(skipped[key]==started[key],"Arrival skip changed earned state: "+key)
		# Release restores control and incoming damage, exactly as the normal
		# end of the introduction does; pools and gear stay untouched.
		var player_after: Dictionary=skipped.player.duplicate(true);var player_before: Dictionary=started.player.duplicate(true)
		for key in ["active","damage_allowed"]:player_after.erase(key);player_before.erase(key)
		check(player_after==player_before and skipped.player.active and skipped.player.damage_allowed,"Arrival skip changed the player beyond releasing control: "+str({"before":started.player,"after":skipped.player}))
		if failures:return false
		await capture_free_application("earned202-dekato-skipped")
		print("Actual Enter skipped the started arrival at world_ms=",skipped.world_elapsed_ms," without world/radio time or earned-state changes; briefing awaits its normal poll")
	var start:=now_us
	while now_us-start<20000000 and not app.session.snapshot().dialogue.visible:
		if not application_step():return false
	var first: Dictionary=app.session.snapshot()
	check(first.entry_released and first.dialogue.visible and first.dialogue.count==events.size(),"Arrival failed to release before the original delayed briefing")
	check(first.world_elapsed_ms>=12001 if pilot_entry=="watch" else first.world_elapsed_ms>=5001 and first.world_elapsed_ms<12001,"The original briefing did not wait for its normal poll after "+pilot_entry)
	if failures:return false
	await capture_free_application("earned202-dekato-briefing")
	for event in events:
		var shown: Dictionary=app.session.snapshot().dialogue
		check(shown.text_id==int(event.text_id) and shown.voice_event_id==int(event.voice_event_id),"The earned briefing selected another line or voice")
		if failures or not await pilot_dialogue_next("mouse"):return false
	return failures==0

func dock_application() -> bool:
	resume_application_focus()
	if not app.session.action("autopilot"):check(false,app.session.error);return false
	var start:=now_us;var next_yield:=now_us+2000000
	while now_us-start<200000000 and app.session.status!="station_transition_required":
		if not application_step():return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+2000000
	check(app.session.status=="station_transition_required","The input-earned convoy never reached physical station docking")
	if failures or not app.enter_station(now_us,42):check(false,app.status.text);return false
	app.session.rebase_time(now_us)
	return failures==0

func battle_step(input: Dictionary) -> bool:
	resume_application_focus()
	if app.session.can_control():
		for adjustment in 10:
			var current: float=app.session.snapshot().input_throttle
			if absf(current-float(input.throttle))<.01:break
			if not app.session.action("throttle_up" if current<float(input.throttle) else "throttle_down"):check(false,app.session.error);return false
	now_us+=pilot_delta_us()
	if not app.session.step(now_us,input.commands,input.fire,false,input.strafe):check(false,app.session.error);return false
	app.present_session()
	return true

func win_earned_convoy(initial: Dictionary) -> bool:
	var pilot:=ConvoyPilot.new();var firing_frames:=0
	if not select_paid_emp():return false
	print("Actual202 convoy initial pools ",initial.player.vitals,"; owned equipment ",initial.equipment.loadout.equipment_ids,"; paid EMP ",initial.encounter.secondaries.guns[0].ammunition)
	var started:=now_us;var tick:=0;var previous_world_ms: int=initial.world_elapsed_ms
	var next_log:=now_us;var next_yield:=now_us+2000000
	var live_captured:=false;var captured_losses:=0
	while now_us-started<600000000:
		var state: Dictionary=app.session.snapshot()
		var escorts: Array=state.encounter.combat.actors.filter(func(actor):return actor.actor_id in range(2,7))
		if state.dialogue.visible:
			var losses: int=state.encounter.combat.actors.slice(0,2).filter(func(actor):return actor.actor_mode==4).size()
			check(losses==pilot_losses and state.campaign_cursor==38,"The input pilot did not earn the requested exact freighter-loss count")
			if pilot_losses==2:
				check(state.phase=="failure_instructions" and not state.combat_objective_satisfied and escorts.any(func(actor):return actor.actor_mode!=4),"Two freighter losses did not open immediate failure while an escort remained")
			else:check(state.phase=="return_instructions" and state.combat_objective_satisfied and escorts.all(func(actor):return actor.actor_mode==4),"The actual input pilot did not earn the source five-escort victory")
			check(state.player.vitals.hull>0 and firing_frames>0 and state.progress.player_kills>initial.progress.player_kills,"Victory lacks surviving-player and real weapon-contact evidence")
			await capture_free_application("earned202-dekato-failure" if pilot_losses==2 else "earned202-dekato-victory")
			print("Actual202 convoy result: frames=",tick," firing=",firing_frames," player kills=",int(state.progress.player_kills)-int(initial.progress.player_kills)," pools=",state.player.vitals," actor hulls=",state.encounter.combat.actors.map(func(actor):return actor.vitals.hull))
			return failures==0
		if app.session.flight_owner().death_active():
			await capture_free_application("earned202-dekato-death")
			check(false,"The actual convoy pilot died at frame "+str(tick)+"; pools "+str(state.player.vitals));return false
		if not live_captured and state.encounter.primaries.guns[0].projectiles.slots.any(func(slot):return slot!=null):
			await capture_free_application("earned202-dekato-combat");live_captured=true
		var retired: int=state.encounter.combat.actors.slice(0,2).filter(func(actor):return actor.actor_mode==4).size()
		if retired>captured_losses:
			await capture_free_application("earned202-dekato-freighter-loss-"+str(retired));captured_losses=retired
		var targets: Array=range(2,7)
		if pilot_losses>0:
			# Leave one escort so success cannot race the deliberate losses.
			var attackers: Array=[2,3,4,6].filter(func(id):return state.encounter.combat.actors[id].vitals.hull>0)
			var freighters: Array=range(pilot_losses).filter(func(id):return state.encounter.combat.actors[id].actor_mode!=4)
			if not attackers.is_empty():targets=attackers
			elif not freighters.is_empty():targets=freighters
		var delta_ms:=maxi(1,int(state.world_elapsed_ms)-previous_world_ms)
		previous_world_ms=int(state.world_elapsed_ms)
		var input: Dictionary=pilot.controls(state,tick,targets,true,float(delta_ms))
		# A wider orbit avoids exceeding this equipped ship's angular tracking
		# speed when an EMP stops the target. Only ordinary control inputs change.
		input.strafe=1.0
		if input.target>=0:
			input.throttle=1.0 if input.distance>(14000.0 if input.target<2 else 10000.0) else 0.0
		if input.target>=2 and not try_paid_emp(state,9000,0.0,"Dekato escorts",true):return false
		if now_us>=next_log:
			print("Actual202 convoy pilot ",tick," target=",input.target," distance=",int(input.distance)," firing=",firing_frames," aim=",input.commands," pools=",state.player.vitals," actor hulls=",state.encounter.combat.actors.map(func(actor):return actor.vitals.hull))
			next_log=now_us+20000000
		if not battle_step(input):return false
		if input.fire:firing_frames+=1
		tick+=1
		if now_us>=next_yield:await process_frame;next_yield=now_us+2000000
	check(false,"The actual convoy pilot exhausted its normal-input allowance")
	return false

func acknowledge_earned_failure(initial: Dictionary,retained_hash: String) -> void:
	var failed: Dictionary=app.session.snapshot()
	check(failed.dialogue.count==1 and failed.dialogue.voice_event_id==-1 and failed.dialogue.text.contains("\n\n\n"),"Convoy failure lost its original silent combined page")
	if failures or not await pilot_dialogue_next("keyboard"):return
	var exited: Dictionary=app.session.snapshot()
	check(exited.campaign_cursor==38 and exited.contracts.campaign_cursor==38 and exited.reward_credits==0 and app.session.flight_owner().prepare_game_over().get("source_state")==1,"Failure advanced or rewarded the career instead of selecting game over")
	for key in ["credits","passengers","mission","accepted_contact","blueprints","void_source","completed_side_missions","delivery_statistics","travel_statistics"]:
		check(exited.contracts[key]==initial.contracts[key],"Failure changed independent career: "+key)
	check(not app.session.navigate("next") and app.session.snapshot()==exited,"Failure acknowledged twice")
	check(not app.save_station() and app.session.flight_owner().prepare_station().is_empty(),"The lost convoy overwrote its viable station checkpoint")
	check(FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==SOURCE_SHA and FileAccess.get_sha256(app.station_save_path())==retained_hash,"Failure overwrote the earned Eanya retry checkpoint")
	await capture_free_application("earned202-dekato-failed-acknowledgement")
	var exit_packet: Dictionary=app.session.prepare_game_over()
	if failures or not app.enter_game_over():check(false,app.status.text);return
	check(app.session==null and app.game_over_result().transition==exit_packet and app.game_over_result().flight==exited,"The actual Host did not leave the acknowledged failed convoy")
	check(FileAccess.get_sha256(app.station_save_path())==retained_hash,"The failed-flight exit overwrote its earned retry checkpoint")
	await capture_free_application("earned202-dekato-failed-exit")
	if failures or not app.load_station(now_us):check(false,app._save_notice.text);return
	var archive=load("res://src/simulation/station_archive.gd").new()
	var document: Dictionary=NativeSave.new().read_document(OS.get_environment("GOF2_SOURCE_SAVE"))
	check(archive.capture(app.session.station_owner(),definitions)==document,"Actual Retry did not restore the exact original Eanya checkpoint")
	await capture_free_application("earned202-dekato-failed-retry")
	if not failures:print("Earned input-only two-freighter failure -> actual Host exit -> exact Eanya Retry; no career advancement or payment; timing=",pilot_timing)

func skip_diagnostics() -> Dictionary:
	var world: RefCounted=app.session.flight_owner()
	return {"context":world._mission_context!=null,"released":world.entry_released(),"entry_ms":world._briefing.snapshot().entry_elapsed_ms if world._briefing!=null else -1,
		"dialogue":world.dialogue_visible(),"death":world.death_active(),"local":world.local_departing(),"blocked":world.cinematic_input_blocked(),"convoy":world.convoy_input_blocked(),"boundary":world._unsupported_boundary,"status":app.session.status}
