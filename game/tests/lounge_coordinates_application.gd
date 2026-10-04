extends "res://tests/automatic_tractor_application.gd"
## An unchanged earned seller visit: consent, debit, unlock, flight and Resume.
## Only the explicitly detached insufficient-wallet branch is a unit stimulus.

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if directory.is_empty():check(false,"Coordinate checks require isolated autosaves");return
	var source_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(source_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false):
		if not app.equipment_action("close"):check(false,app.session.error);return
	if not OS.get_environment("GOF2_COORDINATE_JOURNEY").is_empty():
		await verify_coordinate_journey(source_path,input_hash)
		return
	var retained: RefCounted=app.session.station_owner()
	var original: Dictionary=retained.snapshot()
	var contacts: Array=original.contracts.population.contacts.filter(func(row):return row.get("role")==4 and row.has("service"))
	if contacts.size()!=1:check(false,"The earned save has no unique authored coordinate seller");return
	var id:=int(contacts[0].contact_id)
	var quote: Dictionary=retained.coordinate_preview(id,definitions)
	if quote.is_empty():check(false,retained.error);return
	var target:=int(contacts[0].service.parameter)
	var price:=int(contacts[0].service.price)
	var flags: Array=original.contracts.lounges.system_availability.duplicate()
	var resumed:=OS.get_environment("GOF2_COORDINATES_RESUMED")=="1"
	check(quote.kind=="coordinates" and quote.total_price==price and quote.system_id==target,"The quote changed the retained source terms")
	check(not app.session.contract_action("buy_coordinates",id,null) and retained.snapshot()==original,"A closed lounge accepted payment")
	check(app.session.set_pause("user",true,now_us),app.session.error)
	check(not app.contract_action("buy_coordinates",id) and retained.snapshot()==original,"Paused input bought coordinates")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	if failures:return
	if not app.contract_action("open",-1):check(false,app.session.error);return
	for step in 20:
		if not application_step():return
	app.lounge_panel.select_contact(id)
	var title: String=catalogue.tables.systems[target].name
	var body: String=app.lounge_panel.snapshot().body
	check((resumed or body.contains(title)) and not body.contains("#S") and not body.contains("#C") and not body.contains("not yet available"),"The source coordinate confirmation is absent or has unresolved tokens")
	await capture_free_application("coordinate-resumed" if resumed else "coordinate-offer")
	if resumed:
		check(flags[target] and quote.consumed and not quote.can_accept and not app.lounge_panel.snapshot().accept_visible,"Fresh Resume resurrected the coordinate purchase")
		var unchanged: Dictionary=app.session.station_owner().snapshot()
		press_coordinate_key(KEY_ENTER)
		check(app.session.station_owner().snapshot()==unchanged,"Enter charged again after fresh Resume")
		check(int(unchanged.contracts.credits)==int(OS.get_environment("GOF2_COORDINATES_EXPECTED_CREDITS")),"Fresh Resume changed the earned paid wallet")
		if not app.contract_action("close",-1) or not retain_recovery_save("resumed"):return
		check(FileAccess.get_sha256(source_path)==input_hash,"Resume modified its immutable input")
		print("Coordinates fresh Resume: ",{"system":target,"credits":unchanged.contracts.credits,"input_sha256":input_hash})
		return
	check(not flags[target] and quote.can_accept and not quote.consumed,"The earned career cannot buy these unknown coordinates")
	if failures:return
	# This fork is never installed into the application or written as a save.
	var unfunded: RefCounted=retained.contract_owner().fork()
	unfunded._state.credits=price-1
	var rejected: Dictionary=unfunded.snapshot()
	check(not unfunded.coordinate_preview(definitions,id,retained._equipment).can_accept,"An insufficient wallet was quoted as affordable")
	check(not unfunded.purchase_lounge_coordinates(definitions,id,retained._equipment) and unfunded.snapshot()==rejected,"A refused purchase mutated its detached wallet or coordinates")
	check(retained.snapshot()==original,"The detached insufficient-wallet case changed the earned input")
	var before: Dictionary=app.session.station_owner().snapshot()
	var frozen: Dictionary=app.session.location_owner().read_snapshot()
	# A refused durable checkpoint must roll back the candidate AND its preview.
	check(not app.session.contract_action("buy_coordinates",id,app.lounge_panel,func(_candidate):return false),"A failed save checkpoint accepted payment")
	check(app.session.station_owner().snapshot()==before and app.lounge_panel.snapshot().accept_visible,"Save failure changed the wallet, unlock or live purchase preview")
	press_coordinate_key(KEY_ENTER)
	check(app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Enter skipped consent or charged before acceptance")
	press_coordinate_key(KEY_BACKSPACE)
	check(not app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Cancel charged or unlocked coordinates")
	for button in [JOY_BUTTON_A,JOY_BUTTON_B]:
		var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true
		check(app.lounge_panel.handle_event(event),"Controller did not handle coordinate consent")
	check(not app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Controller cancellation changed the purchase")
	await click_coordinate_button(app.lounge_panel._yes)
	check(app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Mouse did not open passive purchase confirmation")
	await capture_free_application("coordinate-confirmation")
	if failures:return
	await click_coordinate_button(app.lounge_panel._yes)
	var bought: Dictionary=app.session.station_owner().snapshot()
	flags[target]=true
	check(bought.contracts.credits==before.contracts.credits-price and bought.contracts.lounges.system_availability==flags,"Payment and the single coordinate unlock were not atomic")
	check(bought.cargo==before.cargo and bought.loadout==before.loadout and bought.contracts.mission==before.contracts.mission and bought.contracts.passengers==before.contracts.passengers and bought.progress==before.progress,"Coordinate purchase changed cargo, equipment, campaign, passengers or the active job")
	check(not app.lounge_panel.snapshot().accept_visible,"The used coordinate seller still permits payment")
	check(not frozen.system_availability[target] and retained.snapshot()==original,"Coordinate purchase mutated a retained parent or frozen observation")
	var repeated: RefCounted=app.session.station_owner().fork()
	check(not repeated.purchase_lounge_coordinates(id,definitions) and repeated.snapshot()==bought,"Duplicate purchase changed the career")
	check(not repeated.purchase_lounge_coordinates(-1,definitions) and repeated.snapshot()==bought,"An invalid contact changed the career")
	# Inspect the automatic write before any explicit retain/save helper can mask it.
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty(),"Accepted purchase did not autosave: "+app._save_file.error)
	if automatic.is_empty():return
	var archive=load("res://src/simulation/station_archive.gd").new()
	var restored: RefCounted=archive.restore(definitions,catalogue,source,automatic)
	if restored!=null and restored.snapshot()!=bought:coordinate_difference(bought,restored.snapshot())
	check(restored!=null and restored.snapshot()==bought,"Immediate autosave lost wallet or coordinate state: "+archive.error)
	await capture_free_application("coordinate-purchased")
	if failures or not app.contract_action("close",-1) or not retain_recovery_save("purchased"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	await capture_free_application("coordinate-departure")
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.contracts.credits==bought.contracts.credits and landed.contracts.lounges.system_availability==flags,"Flight/docking refunded payment or forgot the coordinate unlock")
	check(landed.contracts.passengers==before.contracts.passengers and landed.contracts.mission==before.contracts.mission and landed.campaign_cursor==original.campaign_cursor,"Coordinate journey changed the retained job or story")
	if not retain_recovery_save("returned"):return
	await capture_free_application("coordinate-saved-station")
	check(FileAccess.get_sha256(source_path)==input_hash,"The earned input save was modified")
	print("Coordinates earned purchase: ",{"station":landed.loadout.station_id,"system":target,"price":price,"credits_before":before.contracts.credits,"credits_after":landed.contracts.credits,"input_sha256":input_hash})

func verify_coordinate_journey(source_path: String,input_hash: String) -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var target:=1
	var gate_field:=int(definitions.mido_travel.free_navigation.gate_station_field)
	var destination:=int(catalogue.tables.systems[target].fields[gate_field])
	var resumed:=OS.get_environment("GOF2_COORDINATE_JOURNEY")=="resume"
	check(original.contracts.lounges.system_availability[target],"The earned career lost its purchased destination")
	check(original.contracts.credits==16626 and original.campaign_cursor==45,"The paid career changed its wallet or story before travel")
	print("Coordinate journey retained cargo: ",original.cargo,"; equipment: ",original.loadout.equipment_ids)
	if failures:return
	if not resumed:
		if not await visit_tractor_supplier(destination):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout.system_id==target and landed.loadout.station_id==destination,"The purchased destination did not survive travel or fresh Resume")
	check(landed.contracts.credits==original.contracts.credits and landed.contracts.lounges.system_availability==original.contracts.lounges.system_availability,"Travel charged again or changed the purchased coordinates")
	check(landed.cargo==original.cargo and landed.loadout.equipment_ids==original.loadout.equipment_ids,"Travel lost earned cargo or equipment")
	check(landed.campaign_cursor==original.campaign_cursor and landed.contracts.mission==original.contracts.mission and landed.contracts.passengers==original.contracts.passengers,"Travel changed the retained story or passenger job")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	var archive=load("res://src/simulation/station_archive.gd").new()
	var restored: RefCounted=archive.restore(definitions,catalogue,source,automatic)
	check(restored!=null and restored.snapshot()==landed,"Destination autosave lost the actual docked career: "+archive.error)
	await capture_free_application("pan-resumed" if resumed else "pan-docked")
	if failures or not retain_recovery_save("pan-resumed" if resumed else "pan"):return
	if OS.get_environment("GOF2_COORDINATE_MAP_UI")=="1":
		if not app.open_map():check(false,app.status.text);return
		check(app.map_panel.snapshot().get("selected_system_id")==target,"The galaxy overview did not select the visited purchased system")
		await capture_free_application("pan-galaxy-overview")
		await click_coordinate_button(app.map_panel._galaxy._open)
		check(app.map_panel.snapshot().get("system_id")==target and app.map_panel._local.visible,"The actual overview Open button did not reveal Pan's planets")
		await capture_free_application("pan-system-map")
		if not app.close_map(now_us):check(false,app.status.text);return
		check(app.session.station_owner().snapshot()==landed,"Browsing the purchased system changed the docked career")
	if not app.contract_action("open",-1):check(false,app.session.error);return
	for step in 20:
		if not application_step():return
	var population: Array=app.session.station_owner().snapshot().contracts.population.contacts
	print("Earned Pan lounge: ",population)
	await capture_free_application("pan-lounge-resumed" if resumed else "pan-lounge")
	if not app.contract_action("close",-1):check(false,app.session.error);return
	check(FileAccess.get_sha256(source_path)==input_hash,"The journey modified its immutable earned input")
	print("Coordinate destination accepted: ",{"resumed":resumed,"system":target,"station":destination,"credits":landed.contracts.credits,"input_sha256":input_hash})

func follow_gate_course(system_id: int,station_id: int) -> bool:
	if not await super.follow_gate_course(system_id,station_id):return false
	if OS.get_environment("GOF2_COORDINATE_JOURNEY")=="travel" and system_id==1:
		await capture_free_application("pan-gate-arrival")
	return true

func press_coordinate_key(code: int) -> void:
	resume_application_focus()
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
		app._unhandled_input(event)

func coordinate_difference(expected: Variant,actual: Variant,path: String="state") -> void:
	if expected==actual:return
	if expected is Dictionary and actual is Dictionary:
		for key in expected:
			if not actual.has(key):print("Coordinate restore missing: ",path,"/",key)
			else:coordinate_difference(expected[key],actual[key],path+"/"+str(key))
		for key in actual:
			if not expected.has(key):print("Coordinate restore added: ",path,"/",key," = ",str(actual[key]).left(160))
	elif expected is Array and actual is Array and expected.size()==actual.size():
		for index in expected.size():coordinate_difference(expected[index],actual[index],path+"/"+str(index))
	else:print("Coordinate restore differs: ",path," live=",str(expected).left(160)," saved=",str(actual).left(160))

func click_coordinate_button(control: Control) -> void:
	await process_frame;resume_application_focus()
	var point: Vector2=root.get_final_transform()*control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	Input.parse_input_event(motion);Input.flush_buffered_events()
	for down in [true,false]:
		var click:=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
		Input.parse_input_event(click);Input.flush_buffered_events()
	await process_frame;resume_application_focus()
