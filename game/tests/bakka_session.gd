extends "res://tests/bakka_population.gd"
## Selected-world diagnostic, not earned travel or a campaign save. Controlled
## native contacts feed the actual scene, speech, input and main-menu consumer.
const Frontend=preload("res://src/presentation/player_frontend.gd")
const FlightSession=preload("res://src/presentation/first_flight_session.gd")
const PathGuard=preload("res://tests/fixtures/free_play_station_scenario.gd")
var app: Control
var captures: String
var initial_frame: RefCounted
var pilot_now_us:=0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	captures=OS.get_environment("GOF2_CAPTURE_DIR")
	if args.size()!=3 or captures.is_empty() or not PathGuard.private_path(captures.path_join("image.png")):
		check(false,"Supply content and a private test output directory");quit(1);return
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720);root.grab_focus()
	app=Frontend.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await verify_application(args)
	app.free();await process_frame
	print("Bakka session/application diagnostic: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_result_transaction(_bindings: RefCounted,initial: RefCounted,_cat: RefCounted,_library: RefCounted) -> void:
	initial_frame=initial

func verify_application(args: PackedStringArray) -> void:
	var directory:=captures.path_join("menu")
	if FileAccess.file_exists(directory.path_join("player.json")):check(false,"Use a fresh diagnostic profile");return
	check(not app.boot(PackedStringArray(),directory),"A fresh profile invented an installation")
	var selection:=Frontend.Preferences.defaults()
	selection.content=args[0];selection.bindings=args[1];selection.visuals=args[2];selection.language="gb"
	if not app.select_content(selection):check(false,app.error);return
	if not Bakka.available(app.bindings):check(false,"This diagnostic requires the isolated contest capability");return
	var cat:=Catalogues.new()
	if not cat.open(app.library):check(false,cat.error);return
	verify_composition(app.bindings,cat,app.library)
	if failures or initial_frame==null or selected_construction==null:return
	app.show_menu()
	# Follow the real title dismissal and menu button instead of bypassing
	# the title screen with a direct frontend action.
	var start_event:=InputEventKey.new();start_event.physical_keycode=KEY_ENTER;start_event.pressed=true
	app.menu._unhandled_input(start_event)
	check(app.menu._buttons.new_game.is_visible_in_tree() and not app.menu._buttons.new_game.disabled,"Title dismissal did not expose New Game")
	app.menu._buttons.new_game.pressed.emit();app.choose_difficulty(0.5)
	if not app.has_session():check(false,"Cannot start native player host: "+app.error);return
	app.game.set_process(false);app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not app.has_save(),"A new diagnostic profile contains unearned saved progress")
	if OS.get_environment("GOF2_BAKKA_INCOMING_ONLY")=="1":
		if selected_arrival_construction==null:check(false,"The incoming scene lost its native prepared world");return
		var incoming_session:=FlightSession.new();app.game.viewport.add_child(incoming_session)
		if not incoming_session.configure_bakka_selected(app.library,app.bindings,app.visuals,selected_arrival_construction,0,123):check(false,incoming_session.error);incoming_session.free();return
		if not app.game._accept_first_flight(incoming_session,0):check(false,app.game.status.text);return
		var incoming_state: Dictionary=incoming_session.snapshot();var prepared: Dictionary=selected_arrival_construction.snapshot()
		check(incoming_state.player_pose==prepared.player_pose and incoming_state.campaign_cursor==36 and incoming_state.actors.size()==8,"Incoming scene changed its selected pose or contest cast")
		check(not incoming_session.can_control() and not app.has_save() and incoming_session.flight_owner().prepare_station().is_empty(),"Incoming camera invented a completed contest or earned checkpoint")
		await capture("bakka-native-incoming")
		# Removed: the Bakka route is finished and playable now, so the navigator supports it.
		print("Selected native incoming scene only; no journey, contest outcome or earned save exercised")
		return
	for player_wins in [true,false]:
		var session:=FlightSession.new();app.game.viewport.add_child(session)
		check(not session.configure_bakka_selected(app.library,app.bindings,app.visuals,RefCounted.new(),0,123) and session.snapshot().is_empty(),"Selected session admitted a nonnative world")
		if not session.configure_bakka_selected(app.library,app.bindings,app.visuals,selected_construction,0,123):
			check(false,"Selected B'akka session: "+session.error);session.free();return
		if not app.game._accept_first_flight(session,0):check(false,app.game.status.text);return
		session.rebase_time(0);pilot_now_us=0
		var before: Dictionary=session.snapshot()
		check(not session.configure_bakka_selected(app.library,app.bindings,app.visuals,selected_construction,0,123) and session.snapshot()==before,"Reconfiguration discarded the accepted flight")
		if not await acknowledge_entry_briefing(session):return
		var result: RefCounted=await resolve_contest(session,player_wins)
		if result==null:return
		var state: Dictionary=session.snapshot();var held: Dictionary=session.flight_owner().contract_owner().snapshot()
		check(session.scene.dialogue.visible and not session.can_control(),"The result failed to own the live flight controls")
		var frozen: Dictionary=session.flight_owner().snapshot()
		pilot_now_us+=9000000
		if not session.step(pilot_now_us):check(false,session.error);return
		var stopped: Dictionary=session.flight_owner().snapshot()
		# Presentation serials/one-frame changes retire while gameplay is modal.
		check(stopped.encounter.controller.bakka_result==frozen.encounter.controller.bakka_result and stopped.encounter.world_elapsed_ms==frozen.encounter.world_elapsed_ms and stopped.progress==frozen.progress and stopped.mining_objective==frozen.mining_objective and stopped.player_pose==frozen.player_pose,"The result modal advanced gameplay, clocks or counters")
		app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(not session.navigate("next") and session.flight_owner().snapshot()==stopped,"An unfocused result accepted acknowledgement")
		app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		if player_wins:
			check(session.objective_audio.snapshot().history.map(func(event):return event.source_id)==[389],"Victory omitted or replaced its first original voice")
			await capture("bakka-success-first")
			if not session.navigate("next"):check(false,session.error);return
			check(session.snapshot().campaign_cursor==36 and session.snapshot().dialogue.index==1 and session.objective_audio.snapshot().history.map(func(event):return event.source_id)==[389,390],"First Next completed the contest or lost its second voice")
			await capture("bakka-success-second")
			if not session.navigate("next"):check(false,"Victory acknowledgement: "+session.error);return
			check(session.snapshot().campaign_cursor==37 and session.flight_owner().contract_owner().snapshot().credits==held.credits and session.snapshot().station_return_supported,"Final Next paid or omitted its physical return")
			var arrived: RefCounted=await return_to_station(session)
			if arrived==null:return
			check(session.flight_owner().prepare_station()==arrived.prepare_station(),"The visible session lost its accepted station packet")
			await capture("bakka-return-contact")
			if FreeFlight.Campaign.BakkaReturn.available(app.bindings):
				await verify_station_presentation()
				if failures:return
		else:
			check(state.phase=="failure_instructions" and state.dialogue.speaker_id==16 and state.dialogue.voice_event_id==-1,"The session replaced the source failure page")
			check(session.objective_failure_audio.snapshot().line==0 and session.objective_failure_audio.snapshot().history.is_empty() and session.objective_audio.snapshot().history.is_empty(),"The silent failure played a victory voice")
			await capture("bakka-failure-desktop")
			root.size=Vector2i(960,540);app.set_mobile_layout(true)
			await capture("bakka-failure-landscape")
			check(session.scene.dialogue._next.size.y>=44,"Landscape failure lost its touch target")
			root.size=Vector2i(1280,720);app.set_mobile_layout(false)
			var event:=InputEventKey.new();event.physical_keycode=KEY_ENTER;event.pressed=true
			app.game._unhandled_input(event)
			check(session.status=="game_over_transition_required" and session.flight_owner().contract_owner().snapshot()==held,"Failure input did not retain the career and request main-menu exit")
			if failures:return
			var packet: Dictionary=session.prepare_game_over()
			root.grab_focus();app.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			if not app.game.enter_game_over():check(false,app.game.status.text);return
			check(app.phase=="menu" and not app.has_session() and app.game.game_over_result().transition==packet,"The actual failure signal did not return to the main menu")
			app.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
			check(app.music.player.stream_paused,"Menu music ignored loss of application focus")
			app.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			check(app.music.player.playing and not app.music.player.stream_paused,"Menu music did not resume with application focus")
			check(app.menu._buttons.new_game.is_visible_in_tree() and not app.menu._buttons.new_game.disabled and app.menu._buttons.load.is_visible_in_tree(),"Failure returned to a hidden title screen instead of usable menu controls")
			await capture("bakka-failure-menu")
	check(not app.has_save() and not app.menu._buttons.resume.visible and app.menu._buttons.load.disabled,"Diagnostic loss created unearned retry progress")
	# Complete202 already has an independently earned public contest/return.
	# This detached diagnostic must neither close it nor open the next encounter.
	check(Navigation.destination_supported(app.bindings,36,MISSION,27)==Navigation.Campaign.BakkaReturn.available(app.bindings),"Contest admission differs from its complete return capability")
	check(not Navigation.destination_supported(app.bindings,38,Navigation.Campaign.mission(app.bindings.mido_travel,38),22),"Session support opened the incomplete next encounter")

func acknowledge_entry_briefing(session: Node3D) -> bool:
	var before: Dictionary=session.snapshot()
	for tick in 200:
		if session.snapshot().dialogue.visible:break
		app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		pilot_now_us+=100000
		if not session.step(pilot_now_us):check(false,session.error);return false
	var state: Dictionary=session.snapshot()
	check(state.phase=="briefing" and state.dialogue.count==2 and state.campaign_cursor==36,"Selected scene lost the source entry briefing")
	if failures:return false
	if not session.navigate("next") or not session.navigate("next"):check(false,session.error);return false
	check(session.briefing_audio.snapshot().history.map(func(event):return event.source_id)==[182,183] and session.can_control(),"Original entry voices or final flight release were lost")
	check(session.snapshot().campaign_cursor==36 and session.snapshot().contracts.credits==before.contracts.credits and session.flight_owner().prepare_station().is_empty(),"Entry briefing completed or paid an unplayed contest")
	return failures==0

## The default diagnostic uses controlled contacts. A live-input variant can
## reuse the same result, station, audio and failure assertions without copying them.
func resolve_contest(session: Node3D,player_wins: bool) -> RefCounted:
	return contest_outcome(session.flight_owner(),player_wins,present_contest_frame.bind(session))

## The component diagnostic keeps its close-approach fixture. Live pilots can
## retain the complete battle-to-station journey through this same consumer.
func return_to_station(session: Node3D) -> RefCounted:
	return verify_physical_return(app.bindings,session.flight_owner(),present_contest_frame.bind(session))

func verify_station_presentation() -> void:
	if not app.game.enter_station(0,0,1700000000):check(false,"Rendered B'akka station: "+app.game.status.text);return
	var session=app.game.session
	var opened: Dictionary=session.snapshot();var career: Dictionary=session.contract_owner().snapshot()
	var panel=app.game.station_panel
	check(not panel.is_visible_in_tree(),"Station dialogue appeared before its authored delay")
	check(opened.campaign_cursor==37 and opened.phase=="conversation" and opened.dialogue.count==8 and opened.loadout.station_id==27,"The player host did not open Brent's station return")
	app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	session.rebase_time(0)
	for step in range(1,101):
		if not session.step(step*150000):check(false,"Station camera/audio start: "+session.error);return
		# Deterministic stepping must retain the host's normal presentation pass.
		app.game.present_session()
		if session._dialogue_started:break
	if not session._dialogue_started:check(false,"Station dialogue never reached its authored opening delay");return
	check(session.audio.snapshot().history.map(func(event):return event.source_id)==[391],"Brent's first original voice did not start")
	check(app.game.station_panel.is_visible_in_tree() and app.game.station_panel._body.text==session.snapshot().dialogue.text and app.game.station_panel._counter.text=="1 / 8" and app.game.station_panel._previous.disabled and not app.game.station_panel._next.disabled,"Brent's first line is not visible with usable station controls")
	await capture("bakka-brent-first")
	app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var paused: Dictionary=session.station_owner().snapshot()
	check(panel._next.disabled,"Unfocused station controls remained enabled")
	panel._next.pressed.emit()
	check(session.station_owner().snapshot()==paused,"Unfocused station dialogue accepted Next through the host")
	app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	var events: Array=app.bindings.mido_travel.bakka_return.mission.result_events
	for index in range(1,8):
		check(not panel._next.disabled,"A visible station Next control is disabled")
		panel._next.pressed.emit()
		var state: Dictionary=session.snapshot()
		check(state.campaign_cursor==37 and state.dialogue.index==index and state.dialogue.text_id==int(events[index].text_id) and state.dialogue.speaker_id==int(events[index].speaker_id),"Rendered station line changed speaker, text or campaign stage")
		check(panel.is_visible_in_tree() and panel._body.text==state.dialogue.text and panel._name.text==state.dialogue.speaker_name and panel._counter.text=="%d / 8"%(index+1) and not panel._previous.disabled,"Station controls did not present the accepted original line")
		check(session.audio.snapshot().history.map(func(event):return event.source_id)==range(391,392+index),"Station dialogue omitted or reordered original speech")
	await capture("bakka-brent-last")
	check(panel._next.text==panel._labels.final_text_id,"Final station line did not offer its original Close action")
	panel._next.pressed.emit()
	var completed: Dictionary=session.snapshot();var retained: Dictionary=session.contract_owner().snapshot()
	check(not panel.is_visible_in_tree(),"Acknowledged station dialogue remained on screen")
	check(completed.campaign_cursor==38 and not completed.dialogue.visible and completed.acknowledged and completed.mission.station_id==22,"The visible station lost its acknowledged next mission")
	for key in ["credits","passengers","mission","active_offer_id","accepted_contact","completed_side_missions","delivery_statistics","travel_statistics","pending_result","result_serial"]:
		check(retained[key]==career[key],"Visible station dialogue changed retained career: "+key)
	check(not app.has_save(),"A component station diagnostic produced an earned save")
	await capture("bakka-brent-acknowledged")

func present_contest_frame(frame: RefCounted,session: Node3D) -> bool:
	var accepted: bool=session._commit(frame,true)
	if not accepted:check(false,"Present contest frame: "+session.error)
	return accepted

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	# Window-manager focus is asynchronous, especially across viewport resize.
	root.grab_focus()
	for attempt in 20:
		if root.has_focus():break
		await create_timer(0.05).timeout
	check(root.has_focus(),"Diagnostic capture window did not acquire focus: "+name)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(captures.path_join(name+".png"))==OK,"Cannot capture "+name)
	if app.has_session():app.game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
