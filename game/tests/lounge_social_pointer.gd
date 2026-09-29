extends "res://tests/lounge_social_application.gd"
## Pointer coverage after the existing lounge entrance has actually finished.

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if directory.is_empty():check(false,"Pointer checks require isolated autosaves");return
	var source_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(source_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false):
		if not app.equipment_action("close"):check(false,app.session.error);return
	var original: Dictionary=app.session.station_owner().snapshot()
	var people: Array=original.contracts.population.contacts.filter(func(row):return row.get("role")==1)
	if people.size()!=1:check(false,"The earned pointer visit lost its social contact");return
	var id:=int(people[0].contact_id)
	var record:=social_record(original,id)
	if record.is_empty():check(false,"Pointer coverage requires an earned conversation");return
	for touch in [false,true]:
		if not app.contract_action("open",-1):check(false,app.session.error);return
		# Four seconds of normal application time, without altering camera state.
		for step in 40:
			if not application_step():return
		await process_frame;resume_application_focus()
		var point:=social_pointer_point(id)
		if point.x<0:
			print("Settled social projections: ",app.lounge_panel._scene.screen_contacts())
			await capture_free_application("social-settled-pick-failure")
			check(false,"The settled social contact has no visible pointer target");return
		point=root.get_final_transform()*(app.lounge_panel.global_position+point)
		for down in [true,false]:
			if touch:
				var event:=InputEventScreenTouch.new();event.position=point;event.pressed=down
				Input.parse_input_event(event)
			else:
				var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
				Input.parse_input_event(event)
			Input.flush_buffered_events()
		await process_frame;resume_application_focus()
		check(app.lounge_panel.snapshot().selected==id,"Pointer input selected another contact")
		var shown: Dictionary=app.session.station_owner().snapshot()
		check(social_record(shown,id)==record and social_career_unchanged(original,shown),"Pointer selection changed the earned conversation or career")
		var body: String=app.lounge_panel.snapshot().body
		check(not body.is_empty() and not body.contains("#") and not app.lounge_panel.snapshot().accept_visible,"Pointer selection lost the original social text")
		for cadence in [[6944,6945],[3700,21000,1000,9000,15000]]:
			for frame in 144:
				now_us+=int(cadence[frame%cadence.size()])
				if not app.session.step(now_us):check(false,app.session.error);return
				app.present_session()
			check(social_record(app.session.station_owner().snapshot(),id)==record and app.session.station_owner().snapshot().contracts.lounges.random==shown.contracts.lounges.random and app.lounge_panel.snapshot().body==body,"High-rate or variable display timing changed the conversation")
		await capture_free_application("social-touch" if touch else "social-mouse")
		await click_coordinate_button(app.lounge_panel._back)
		check(not app.lounge_panel.visible,"Pointer Back did not close the conversation")
		if failures or not verify_social_autosave(id,record):return
	check(FileAccess.get_sha256(source_path)==input_hash,"Pointer checks changed their earned input")
	print("Settled social pointer accepted: ",{"contact":id,"mouse":true,"touch":true,"input_sha256":input_hash})

func social_pointer_point(id: int) -> Vector2:
	var rows: Array=app.lounge_panel._scene.screen_contacts()
	var screen:=Rect2(Vector2.ZERO,app.lounge_panel.size-Vector2(0,50))
	for row in rows:
		if row.id!=id:continue
		for x in [0.5,0.25,0.75]:
			for y in [0.5,0.25,0.75]:
				var point: Vector2=row.rect.position+row.rect.size*Vector2(x,y)
				if not screen.has_point(point):continue
				for hit in rows:
					if hit.rect.grow(3).has_point(point):
						if hit.id==id:return point
						break
	return Vector2(-1,-1)
