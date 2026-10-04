extends "res://tests/lounge_coordinates_application.gd"
## Social conversation on an unchanged earned visit, through real app input.
const Social=preload("res://src/simulation/lounge_dialogue.gd")
const Medals=preload("res://src/simulation/base_medal_progress.gd")

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if directory.is_empty():check(false,"Social checks require isolated autosaves");return
	var source_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(source_path)
	var resumed:=OS.get_environment("GOF2_SOCIAL_RESUMED")=="1"
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false):
		if not app.equipment_action("close"):check(false,app.session.error);return
	var parent: RefCounted=app.session.station_owner()
	var original: Dictionary=parent.snapshot()
	var people: Array=original.contracts.population.contacts.filter(func(row):return row.get("role")==1)
	if people.size()!=1:check(false,"The earned lounge has no unique social contact");return
	var person: Dictionary=people[0]
	var id:=int(person.contact_id)
	var initial:=social_record(original,id)
	var initial_conversations:=conversation_count(original)
	check((not initial.is_empty())==resumed,"The earned input has the wrong conversation lifetime")
	if resumed:
		check(initial_conversations>=21 and medal_level(original,26)==3,"Fresh Resume lost the earned Chatterbox bronze history")
	else:
		check(initial_conversations==0,"The immutable pre-Chatterbox source unexpectedly contains conversation history")
	check(not app.session.contract_action("select",id,null),"A closed lounge selected a social contact")
	check(app.session.set_pause("user",true,now_us),app.session.error)
	check(not app.contract_action("select",id),"Paused input selected a conversation")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	check(parent.snapshot()==original,"Rejected input mutated its retained parent")
	if not resumed:verify_social_pool(person,original)
	if failures or not app.contract_action("open",-1):check(false,app.session.error);return
	for step in 20:
		if not application_step():return
	var opened: Dictionary=app.session.station_owner().snapshot()
	check(not app.session.contract_action("select",-1,app.lounge_panel) and app.session.station_owner().snapshot()==opened,"Invalid input changed a lounge")
	if not await select_social_keys(id,false):return
	var first: Dictionary=app.session.station_owner().snapshot()
	check(conversation_count(first)>initial_conversations,"Successful lounge-contact navigation did not increment durable conversation history")
	var record:=social_record(first,id)
	if record.is_empty():check(false,"Contact selection did not retain a social topic");return
	var body: String=app.lounge_panel.snapshot().body
	check(not body.is_empty() and not body.contains("#") and not body.contains("not yet available"),"The original social line is absent or has unresolved placeholders")
	check(not app.lounge_panel.snapshot().accept_visible and not app.lounge_panel.snapshot().confirming,"Social dialogue exposes a purchase action")
	check(social_career_unchanged(original,first),"Talking changed earned goods, money, recipe, job or story")
	check(parent.snapshot()==original,"Talking mutated its retained parent")
	if resumed:check(record==initial,"Fresh Resume changed the retained topic or references")
	if not resumed:
		# Exercise the real contact-selection producer up to the strict original
		# bronze boundary. The medal itself is banked later at the station boundary.
		check(conversation_count(first)<=20,"Initial earned lounge navigation skipped past the Chatterbox bronze boundary")
		while conversation_count(app.session.station_owner().snapshot())<20:
			var previous_count:=conversation_count(app.session.station_owner().snapshot())
			app.lounge_panel.select_contact(id)
			var advanced: Dictionary=app.session.station_owner().snapshot()
			check(conversation_count(advanced)==previous_count+1,"Repeated successful conversation did not advance its lifetime counter exactly once")
			if failures:return
		var before_threshold: Dictionary=app.session.station_owner().snapshot()
		check(conversation_count(before_threshold)==20 and observed_level(before_threshold,26)==0,"Chatterbox awarded at the strict threshold instead of beyond it")
		app.lounge_panel.select_contact(id)
		var crossed: Dictionary=app.session.station_owner().snapshot()
		check(conversation_count(crossed)==21 and observed_level(crossed,26)==3,"The real 20-to-21 conversation crossing did not earn Chatterbox bronze")
		first=crossed
	for frame in 30:app.present_session()
	check(app.session.station_owner().snapshot()==first and app.lounge_panel.snapshot().body==body,"Display refresh rerolled the conversation or advanced the career")
	press_coordinate_key(KEY_ENTER)
	var controller:=InputEventJoypadButton.new();controller.button_index=JOY_BUTTON_A;controller.pressed=true
	check(app.lounge_panel.handle_event(controller),"Controller confirm was not handled")
	check(app.session.station_owner().snapshot()==first,"Confirming social text charged or accepted a job")
	await capture_free_application("social-resumed" if resumed else "social-first")
	# Explicit rereading keeps the topic; first references may be reconstructed.
	app.lounge_panel.select_contact(id)
	var reread: Dictionary=app.session.station_owner().snapshot()
	var repeated:=social_record(reread,id)
	check(repeated.topic==record.topic and repeated.revisited,"Rereading replaced the selected social topic")
	var stable_body: String=app.lounge_panel.snapshot().body
	var reread_count:=conversation_count(reread)
	app.lounge_panel.select_contact(id)
	var reread_again: Dictionary=app.session.station_owner().snapshot()
	check(social_record(reread_again,id)==repeated and conversation_count(reread_again)==reread_count+1 and app.lounge_panel.snapshot().body==stable_body,"Repeated contact input changed stable dialogue or lost its conversation event")
	reread=reread_again
	press_coordinate_key(KEY_BACKSPACE)
	check(not app.lounge_panel.visible,"Keyboard Back did not close social dialogue")
	if not verify_social_autosave(id,repeated):return
	if not resumed:
		var cache: RefCounted=app.session.station_owner().contract_owner()._lounges.fork()
		var intact: Dictionary=cache.snapshot()
		var invalid:=repeated.duplicate(true);invalid.station_id=-1
		check(not cache.restore_dialogues(definitions,catalogue,source,int(original.loadout.station_id),{id:invalid}) and cache.snapshot()==intact,"Invalid saved dialogue changed the retained location")
		check(not cache.restore_dialogues(definitions,catalogue,source,int(original.loadout.station_id),{-1:repeated}) and cache.snapshot()==intact,"A saved dialogue was attached to a nonexistent person")
	if not app.contract_action("open",-1):check(false,app.session.error);return
	for step in 20:
		if not application_step():return
	check(app.session.station_owner().contract_owner()._lounges._social_used.is_empty(),"Reopening retained the transient topic exclusion pool")
	if not await select_social_keys(id,true):return
	var reopened: Dictionary=app.session.station_owner().snapshot()
	check(social_record(reopened,id)==repeated and conversation_count(reopened)>conversation_count(reread) and app.lounge_panel.snapshot().body==stable_body,"Controller reopening changed the retained social dialogue or failed to count lounge-contact navigation")
	await capture_free_application("social-reread-resumed" if resumed else "social-reread")
	await click_coordinate_button(app.lounge_panel._back)
	check(not app.lounge_panel.visible,"Mouse Back did not close social dialogue")
	if failures:return
	if resumed:
		check(social_career_unchanged(original,app.session.station_owner().snapshot()),"Fresh Resume social input changed the earned career")
		if not retain_recovery_save("resumed"):return
	else:
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight():return
		await capture_free_application("social-departure")
		if not await dock_application():return
		var landed: Dictionary=app.session.station_owner().snapshot()
		check(social_record(landed,id)==repeated and social_career_unchanged(original,landed),"Departure or docking lost the conversation or changed unrelated earned progress")
		check(conversation_count(landed)>=21 and medal_level(landed,26)==3,"Physical docking did not bank the earned Chatterbox bronze medal")
		if not verify_social_autosave(id,repeated) or not retain_recovery_save("returned"):return
		await capture_free_application("social-docked")
	check(FileAccess.get_sha256(source_path)==input_hash,"The earned source save was modified")
	print("Social conversation accepted: ",{"resumed":resumed,"name":person.name,"contact":id,"dialogue":repeated,"credits":original.contracts.credits,"input_sha256":input_hash})

func social_record(state: Dictionary,id: int) -> Dictionary:
	for place in state.contracts.lounges.locations:
		if place.station_id==state.contracts.station_id:return place.get("dialogues",{}).get(id,{}).duplicate(true)
	return {}

func conversation_count(state: Dictionary) -> int:
	return int(state.get("contracts",{}).get("conversations",0))

func medal_level(state: Dictionary,id: int) -> int:
	var levels: Variant=state.get("contracts",{}).get("base_medals",{}).get("levels")
	return int(levels[id]) if levels is Array and id>=0 and id<levels.size() else Medals.UNKNOWN

func observed_level(state: Dictionary,id: int) -> int:
	var career: Dictionary=state.get("contracts",{})
	var observed:=Medals.observe(career,career.get("blueprints",{}))
	return int(observed.levels[id]) if not observed.is_empty() else Medals.UNKNOWN

func social_career_unchanged(before: Dictionary,after: Dictionary) -> bool:
	for key in ["credits","blueprints","mission","passengers","population"]:
		if before.contracts[key]!=after.contracts[key]:return false
	return before.cargo==after.cargo and before.campaign_cursor==after.campaign_cursor and before.loadout.ship_id==after.loadout.ship_id and before.loadout.equipment_ids==after.loadout.equipment_ids and before.contracts.lounges.system_availability==after.contracts.lounges.system_availability

func verify_social_autosave(id: int,expected: Dictionary) -> bool:
	var document: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	var archive=load("res://src/simulation/station_archive.gd").new()
	var restored: RefCounted=archive.restore(definitions,catalogue,source,document)
	check(restored!=null and restored.snapshot()==app.session.station_owner().snapshot() and social_record(restored.snapshot(),id)==expected,"Automatic save lost the social dialogue: "+archive.error)
	return failures==0

func verify_social_pool(person: Dictionary,state: Dictionary) -> void:
	# Detached topic choices never enter the live career or a saved fixture.
	var used:=[];var random: Dictionary=state.contracts.lounges.random.duplicate(true)
	for count in Social.TOPIC_COUNT:
		var choice:=Social.prepare(person,random,used)
		if choice.is_empty() or choice.raw_topic in used:check(false,"New conversations reused an excluded topic");return
		used.append(choice.raw_topic);random=choice.random
		check(Social.valid(choice.dialogue,person,catalogue,source),"A social topic failed its source-text boundary")
	check(Social.prepare(person,random,used).is_empty(),"An exhausted social pool did not fail cleanly")
	check(not Social.prepare(person,random,[]).is_empty(),"A fresh lounge could not choose a social topic")
	var woman:=person.duplicate(true);woman.faction=0;woman.male=false
	var alien:=person.duplicate(true);alien.faction=2;alien.male=true
	var terran:=woman.duplicate(true);terran.male=true
	check(Social.eligible_topic(13,woman)!=13 and Social.eligible_topic(13,terran)==13,"A male-only line was not restricted by the speaker")
	check(Social.eligible_topic(16,alien)!=16 and Social.eligible_topic(16,terran)==16,"A Terran-only line was not restricted by the speaker")

func select_social_keys(id: int,controller: bool) -> bool:
	await process_frame;resume_application_focus()
	for step in app.lounge_panel._contact_ids.size():
		if controller:
			var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_DPAD_RIGHT;event.pressed=true
			app.lounge_panel.handle_event(event)
		else:press_coordinate_key(KEY_RIGHT)
		if app.lounge_panel.snapshot().selected==id:break
	await process_frame;resume_application_focus()
	check(app.lounge_panel.snapshot().selected==id,"Native contact input selected another person")
	return failures==0
