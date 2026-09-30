extends "res://tests/automatic_tractor_application.gd"
## Valkyrie begins from a finished main career: the incoming call plays at the
## docked station, the talk mission to Kanado is set, and it survives a save
## and a fresh Resume.
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")

func verify_free_application() -> void:
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var before: Dictionary=app.session.station_owner().snapshot()
	check(before.campaign_cursor==45,"The source career has not finished the main story")
	var rules: Dictionary=load("res://src/content/free_campaign_definitions.gd").dialogue_rules(definitions,45,before.mission,true)
	check(not rules.is_empty() and rules.next_cursor==47,"No Valkyrie call is declared for a finished career")
	if failures:return
	var now_us:=Time.get_ticks_usec()
	for tick in 30:
		if app.session.snapshot().dialogue.visible:break
		now_us+=100000;app.session.step(now_us);app.present_session();await process_frame
	var lines:=0
	for event in rules.events:
		var current: Dictionary=app.session.snapshot()
		check(current.dialogue.visible and current.dialogue.text_id==int(event.text_id),"The Valkyrie call lost its original line order at "+str(event.text_id))
		if failures:return
		if lines==0:await capture_free_application("valkyrie-call")
		app.station_navigation("next");lines+=1
		await process_frame
	var after: Dictionary=app.session.station_owner().snapshot()
	print("VALKYRIE after call cursor=",after.campaign_cursor," mission=",after.mission," phase=",after.phase," conversation=",after.get("campaign_conversation")," line=",after.get("line_index")," dialogue=",app.session.snapshot().dialogue)
	check(after.campaign_cursor==47 and after.mission==Valkyrie.mission(47),"The call did not set the Kanado talk mission")
	app.open_missions();await process_frame
	var log: Dictionary=app.missions_panel.snapshot()
	print("VALKYRIE log ",log.story)
	check(log.story.contains("Kanado") and log.story_map,"The Missions log does not point at Kanado")
	app.close_missions();await process_frame
	check(app.save_station(false),"Saving the Valkyrie career failed: "+app._save_notice.text)
	if failures:return
	check(app.load_station(),"Fresh Resume of the Valkyrie career failed: "+app._save_notice.text)
	var resumed: Dictionary=app.session.station_owner().snapshot()
	check(resumed.campaign_cursor==47 and resumed.mission==after.mission,"Fresh Resume lost the Valkyrie mission")
	await capture_free_application("valkyrie-resumed")

func take_station_talk(cursor: int,next: int) -> bool:
	var state: Dictionary=app.session.station_owner().snapshot()
	var rules: Dictionary=load("res://src/content/free_campaign_definitions.gd").dialogue_rules(definitions,cursor,state.mission,true)
	check(state.campaign_cursor==cursor and not rules.is_empty(),"No station talk is declared at cursor "+str(cursor))
	if failures:return false
	var clock:=Time.get_ticks_usec()
	for tick in 30:
		if app.session.snapshot().dialogue.visible:break
		clock+=100000;app.session.step(clock);app.present_session();await process_frame
	for event in rules.events:
		var current: Dictionary=app.session.snapshot()
		check(current.dialogue.visible and current.dialogue.text_id==int(event.text_id),"The station talk lost its original line order at "+str(event.text_id))
		if failures:return false
		if event==rules.events[0]:await capture_free_application("valkyrie-talk-%d"%cursor)
		app.station_navigation("next");await process_frame
	var after: Dictionary=app.session.station_owner().snapshot()
	check(after.campaign_cursor==next,"The station talk did not advance the story to "+str(next)+": "+app.session.error+" "+app.status.text)
	return failures==0
