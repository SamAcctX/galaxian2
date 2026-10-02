extends "res://tests/beam_primary_application.gd"
## Station Status screen from a real earned career: open from the station menu,
## read pilot/ship/statistics, select an earned medal, close, save and reload;
## then accept a job, read it in the Missions log and discard it.

func verify_free_application() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	# A finished career first takes the expansion story's incoming call.
	var clock:=Time.get_ticks_usec()
	for tick in 30:
		if app.session.snapshot().dialogue.visible:break
		clock+=100000;app.session.step(clock);app.present_session();await process_frame
	for line in 40:
		if not app.session.snapshot().dialogue.visible:break
		app.station_navigation("next");await process_frame
	print("CALL cursor=",app.session.station_owner().snapshot().campaign_cursor," phase=",app.session.station_owner().snapshot().phase," dialogue=",app.session.snapshot().dialogue.visible)
	# Room atmosphere: the main view loops its own event and fades it in.
	for frame in 30:
		await process_frame;app.session.step(Time.get_ticks_usec())
	var air: Dictionary=app.session.ambience.snapshot()
	print("AMBIENCE ",air)
	check(air.prepared.size()==3 and air.room=="main" and air.levels.get("main",0.0)>0.0 and air.playing_voices>0,"The station main view has no atmosphere")
	check(app.equipment_action("open"),"The hangar did not open: "+app.status.text+" paused="+str(app.session.is_paused()))
	for frame in 10:
		await process_frame;app.session.step(Time.get_ticks_usec())
	air=app.session.ambience.snapshot()
	check(air.room=="hangar" and air.levels.has("hangar"),"The hangar did not switch to its atmosphere")
	check(app.equipment_action("close"),"The hangar did not close")
	for frame in 3:
		await process_frame;app.session.step(Time.get_ticks_usec())
	check(app.session.ambience.snapshot().room=="main","Closing the hangar did not return to the main atmosphere")
	# Lounge room: authored room animation loops on the lounge clock.
	check(app.contract_action("open",-1),"The lounge did not open")
	var lounge: Node3D=app.session.lounge_scene
	var before_pose: Array=lounge.get_children().filter(func(node):return node.has_meta("source_resource_id") and "instances" in node).map(func(node):return node.instances.map(func(instance):return instance.transform))
	for frame in 20:
		await process_frame;app.session.step(Time.get_ticks_usec())
	var after_pose: Array=lounge.get_children().filter(func(node):return node.has_meta("source_resource_id") and "instances" in node).map(func(node):return node.instances.map(func(instance):return instance.transform))
	print("LOUNGE animated parts=",lounge.animated_parts()," moved=",before_pose!=after_pose)
	check(app.session.ambience.snapshot().room=="lounge","The lounge did not switch to its atmosphere")
	await capture("lounge-animated")
	check(app.contract_action("close",-1),"The lounge did not close")
	for frame in 3:
		await process_frame;app.session.step(Time.get_ticks_usec())
	# A newly reached tier pays its reward and shows one notice at the idle station.
	var wallet: int=app.session.station_owner().snapshot().contracts.credits
	check(app.session._world.record_stats({"max_free_cargo":101}),"Stats could not reach Space Saver bronze")
	app.present_session();await process_frame
	var docked: Dictionary=app.session.station_owner().snapshot()
	check(docked.contracts.credits==wallet+1000 and docked.contracts.base_medals.levels[31]==3,"Space Saver bronze did not pay its original 1000 credits")
	check(app.medal_notice.visible and app.medal_notice.shown()==[31,3],"The new medal notice did not appear")
	await capture("new-medal")
	var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.physical_keycode=KEY_ENTER;enter.pressed=true
	app._unhandled_input(enter);await process_frame
	check(not app.medal_notice.visible and not app.session.station_owner().snapshot().contracts.has("medal_notices"),"Enter did not acknowledge the medal notice")
	check(app.session._world.record_stats({"max_free_cargo":101}) and not app.session.station_owner().snapshot().contracts.has("medal_notices"),"The same tier was announced twice")
	await verify_elite_medals()
	var before: Dictionary=app.session.station_owner().snapshot()
	check(app.station_shell._actions.status.visible,"The station menu has no Status entry")
	var sounds: Array=preload("res://src/presentation/ui_sounds.gd").prepared()
	check([123,124,102,103,104,105,106,107,100,101].all(func(id):return id in sounds),"Original button and star map sounds are not prepared: "+str(sounds))
	var sounds_before: int=root.get_children().filter(func(node):return node is AudioStreamPlayer).size()
	app.station_shell._actions.status.pressed.emit()
	check(root.get_children().filter(func(node):return node is AudioStreamPlayer and node.playing).size()>sounds_before,"The station menu button made no sound")
	await process_frame
	check(app._status_open and app.status_panel.visible and app.session.is_paused(),"Status did not open from the station menu")
	var view: Dictionary=app.status_panel.snapshot()
	print("STATUS ",view)
	check(view.pilot.begins_with("%d$"%int(before.contracts.credits)),"Status shows the wrong wallet")
	check(view.stats_left.split("\n")[1]==str(before.contracts.progress.player_kills),"Status shows the wrong kill count")
	check(view.stats_right.split("\n")[0]==str(before.contracts.travel_statistics.jumpgates_used),"Status shows the wrong jumpgate count")
	check(not view.ship.strip_edges().is_empty(),"Status shows no ship values")
	var levels: Array=app.session.station_owner().snapshot().contracts.base_medals.levels
	app.status_panel.select_medal(1 if levels[1]<=0 else 0)
	if levels[1]<=0:check(app.status_panel.snapshot().selected==-1,"An unearned medal opened its description")
	app.status_panel.select_medal(10)
	check(app.status_panel.snapshot().hint.contains("Garbage Man") and app.status_panel.snapshot().hint.contains("30"),"Earned bronze Garbage Man lacks its original description")
	await capture("status-screen")
	# Add-on rows: all 45 cells; an earned and an unearned add-on medal both read.
	check(app.status_panel._medal_buttons.size()==45,"Status does not list the 45 medals")
	app.status_panel.select_medal(44)
	check(app.status_panel.snapshot().hint.contains("8"),"Hot Shot shows no description: "+app.status_panel.snapshot().hint)
	app.status_panel.select_medal(37)
	check(app.status_panel.snapshot().selected==37 and app.status_panel.snapshot().hint.contains("50"),"An unearned add-on medal is not readable")
	check(view.stats_left.split("\n").size()==6,"Status lacks the battleships line")
	app.status_panel._medal_buttons[44].grab_focus()
	await capture("status-elite-rows")
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	app._unhandled_input(escape)
	await process_frame
	check(not app._status_open and not app.status_panel.visible and not app.session.is_paused(),"Escape did not close Status")
	var stats: Dictionary=app.session.station_owner().snapshot().contracts.get("stats",{})
	check(stats.get("max_primaries",0)>=1 and stats.get("max_free_cargo",-1)>=0,"Opening Status did not bank the observed career stats")
	check(app.save_station(false),"Saving after Status failed")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.get("stats",{}).get("max_primaries",0)==stats.max_primaries,"The station save lost the career stats")
	await capture("station-after-status")
	# Missions log: story objective beside an accepted freelance job, then Discard.
	var career: Dictionary=app.session.station_owner().snapshot().contracts
	var accepted:=0 if not career.mission.is_empty() else -1
	for offer_id in career.offers.size():
		if accepted<0 and app.session._world.accept_contract(offer_id,true,app.bindings):accepted=offer_id
	check(accepted>=0,"No lounge job could be accepted for the Missions log")
	app.present_session();await process_frame
	check(app.station_shell._actions.missions.visible,"The station menu has no Missions entry")
	app.station_shell._actions.missions.pressed.emit();await process_frame
	check(app._missions_open and app.missions_panel.visible and app.session.is_paused(),"Missions did not open from the station menu")
	var log: Dictionary=app.missions_panel.snapshot()
	print("MISSIONS ",log)
	var docked_state: Dictionary=app.session.station_owner().snapshot()
	var target: int=int(docked_state.mission.get("station_id",-1))
	if app.missions_panel.won(int(docked_state.campaign_cursor)):check(log.story in [app.missions_panel.text("won"),app.missions_panel.text("won_gold")] and not log.story_map,"A won career does not show the original after-game line")
	else:check(not log.story.contains("#") and (target<0 or log.story.contains(app.status_panel._catalogues.tables.stations[target].name)),"Missions shows no story objective")
	check(log.discard and not log.job.is_empty() and not log.job.contains("#") and not log.client.is_empty(),"Missions does not show the accepted job and its client")
	await capture("missions-log")
	app.missions_panel._job_discard.pressed.emit();await process_frame
	check(app.missions_panel.snapshot().confirming,"Discard did not ask for confirmation")
	app.missions_panel._yes.pressed.emit();await process_frame
	var dropped: Dictionary=app.session.station_owner().snapshot()
	check(dropped.contracts.mission.is_empty() and dropped.contracts.active_offer_id==-1 and dropped.contracts.passengers==0,"Discard kept the freelance job")
	check(not dropped.cargo.entries.any(func(row):return row.get("mission",false)),"Discard kept the job's protected cargo")
	check(app.missions_panel.snapshot().job==app.missions_panel.text("no_job") and not app.missions_panel.snapshot().discard,"Missions still shows the discarded job")
	app._unhandled_input(escape);await process_frame
	check(not app._missions_open and not app.session.is_paused(),"Escape did not close Missions")
	var reloaded: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not reloaded.is_empty() and reloaded.career.mission.is_empty(),"The autosave kept the discarded job")

## Add-on medals: an in-flight Liberator streak latched by the flight tracker
## and a docked cargo hold over 3000 t each pay 5000 and show a notice once.
func verify_elite_medals() -> void:
	var Elite:=preload("res://src/simulation/elite_medal_progress.gd")
	var wallet: int=app.session.station_owner().snapshot().contracts.credits
	var blast:={"action":"detonated","item_id":179,"normal_hits":[]}
	for index in 8:blast.normal_hits.append({"target":{"group":"scenery","index":index},"result":{"destroyed_now":true}})
	app._elite_tracker.observe({"encounter":{"secondary_events":[blast]}})
	var mining:=["drilling","finished"]
	for mine in 3:
		for phase in mining:app._elite_tracker.observe({"mining_session":{"phase":phase,"last_drill":{"phase":"extracted"}}})
	check(app._elite_tracker.reached()==[44],"The flight tracker did not latch Hot Shot alone: "+str(app._elite_tracker.reached()))
	app.bank_career_stats(true)
	app.present_session();await process_frame
	var career: Dictionary=app.session.station_owner().snapshot().contracts
	print("ELITE ",career.get("elite_medals")," notices=",career.get("medal_notices")," credits=",career.credits-wallet)
	check(career.get("elite_medals")==[44] and career.credits==wallet+5000,"Hot Shot did not pay its 5000 credits")
	check(app.medal_notice.visible and app.medal_notice.shown()==[44,1],"The Hot Shot notice did not appear")
	await capture("new-elite-medal")
	check(app.session._world.record_elite_medals(Elite.dock_reached(3001)),"A 3001 t hold was refused")
	check(app.session.station_owner().snapshot().contracts.elite_medals==[36,44],"Space Saver Pro was not earned")
	check(app.session._world.record_elite_medals([37,43,44]) and app.session.station_owner().snapshot().contracts.credits==wallet+10000,"An unavailable or owned add-on medal paid again")
	var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.physical_keycode=KEY_ENTER;enter.pressed=true
	for notice in 2:
		app._unhandled_input(enter);await process_frame;app.present_session();await process_frame
	check(not app.session.station_owner().snapshot().contracts.has("medal_notices"),"The add-on notices were not acknowledged")
	check(app.save_station(false),"Saving the add-on medals failed")
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.career.get("elite_medals")==[36,44],"The save lost the add-on medals")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label+".png"))
