extends "res://tests/lounge_coordinates_application.gd"
## Ordinary hiring on a byte-copied earned career. No actor, wallet, contact,
## seed or save-document edits are installed into the running application.
const WingmanTerms=preload("res://src/simulation/wingman_contract.gd")

func flight_world_seconds() -> int:
	# The normal application samples a new clock at each world entry. Use the
	# inherited baseline plus actual piloted elapsed time, never a roster seed.
	var seconds:=super.flight_world_seconds()+int(now_us/1000000)
	print("Earned wingman world Unix time ",seconds)
	return seconds

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	if directory.is_empty() or input_path.is_empty():check(false,"Wingman checks require isolated earned saves");return
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	if OS.get_environment("GOF2_WINGMEN_STAGE")=="resume":
		var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(not entry.contracts.get("wingmen",{}).get("active",{}).is_empty(),"Fresh Resume lost the hired roster")
		if failures:return
		verify_contract_validation(entry.contracts.wingmen.active)
		check(saved.career.wingmen==entry.contracts.wingmen and saved.career.credits==entry.contracts.credits,"Fresh Resume changed the paid contract or wallet")
		if not await check_active_roster() or not retain_recovery_save("resumed"):return
		await capture_free_application("wingmen-fresh-resume")
	else:
		var id:=await find_roster()
		if id<0:return
		if not await hire_roster(id):return
	var final: Dictionary=app.session.station_owner().snapshot()
	check(final.contracts.mission==entry.contracts.mission and final.contracts.passengers==entry.contracts.passengers and final.contracts.blueprints==entry.contracts.blueprints and final.progress==entry.progress,"Hiring changed the unrelated passenger job, recipe or campaign")
	check(final.cargo==entry.cargo and final.loadout.equipment_ids==entry.loadout.equipment_ids,"Hiring changed cargo or fitted equipment")
	check(FileAccess.get_sha256(input_path)==input_hash,"The earned input file was changed")
	print("Wingman hiring boundary: ",{"station":final.loadout.station_id,"credits":final.contracts.credits,"wingmen":final.contracts.get("wingmen"),"input_sha256":input_hash,"flight_behavior_accepted":false})

func find_roster() -> int:
	var initial: Dictionary=app.session.station_owner().snapshot()
	var visits: Array=[-1]
	for id in catalogue.tables.stations.size():
		if catalogue.tables.stations[id].system_id==initial.loadout.system_id and id!=initial.loadout.station_id:visits.append(id)
	var navigation:=Navigation.new()
	if not navigation.configure(definitions,catalogue,initial.contracts.lounges.system_availability):check(false,navigation.error);return -1
	# Ordinary input visits nearby known systems; it never rerolls a lounge.
	# The initial local-system sweep may contain no service at all.
	for system_id in catalogue.tables.systems.size():
		var route: Array=navigation.route(initial.loadout.system_id,system_id)
		if route.size()!=2:continue
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==system_id and visits.size()<13:visits.append(id)
	for destination in visits:
		if destination>=0 and not await visit_tractor_supplier(destination):return -1
		var state: Dictionary=app.session.station_owner().snapshot()
		print("Actual wingman lounge: ",{"station":state.loadout.station_id,"contacts":state.contracts.population.contacts.map(func(row):return {"id":row.contact_id,"role":row.role,"roster":row.get("roster",{})})})
		for contact in state.contracts.population.contacts:
			if contact.role==6 and contact.get("roster",{}).get("price",2147483647)<=state.contracts.credits:
				if not retain_recovery_save("eligible"):return -1
				return int(contact.contact_id)
	check(false,"The bounded native route found no affordable wingman roster")
	return -1

func hire_roster(id: int) -> bool:
	var retained: RefCounted=app.session.station_owner()
	var initial: Dictionary=retained.snapshot()
	check(not app.session.contract_action("hire_wingmen",id,null),"A closed lounge accepted a hire")
	check(app.session.set_pause("user",true,now_us),app.session.error)
	check(not app.contract_action("hire_wingmen",id) and retained.snapshot()==initial,"Paused input hired a roster")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	if not app.contract_action("open",-1):check(false,app.session.error);return false
	for step in 40:
		if not application_step():return false
	app.lounge_panel.select_contact(id)
	for step in 40:
		if not application_step():return false
	var quote: Dictionary=app.session.station_owner().wingman_preview(id,definitions)
	if quote.is_empty():check(false,app.session.station_owner().error);return false
	var contacts: Array=initial.contracts.population.contacts.filter(func(row):return row.contact_id==id)
	var names: Array=[contacts[0].name];names.append_array(contacts[0].roster.extra_names)
	check(quote.can_accept and quote.total_price==contacts[0].roster.price and quote.contract.names==names,"The hire changed the actual generated roster or price")
	check(quote.contract.faction==contacts[0].faction and quote.contract.portrait==contacts[0].portrait,"The hire changed the offered faction or captain")
	var body: String=app.lounge_panel.snapshot().body
	check(not body.is_empty() and body.contains(str(quote.total_price)) and not body.contains("#C") and not body.contains("not yet available"),"The original priced wingman introduction is absent")
	await capture_free_application("wingmen-offer")
	# Detached negative cases are never installed or saved as this career.
	var unfunded: RefCounted=retained.contract_owner().fork()
	unfunded._state.credits=int(quote.total_price)-1
	var unfunded_before: Dictionary=unfunded.snapshot()
	check(not unfunded.wingman_preview(definitions,id,retained._equipment).can_accept and not unfunded.hire_lounge_wingmen(definitions,id,retained._equipment),"An insufficient wallet hired wingmen")
	check(unfunded.snapshot()==unfunded_before and retained.snapshot()==initial,"A refused detached hire changed the retained parent")
	verify_contract_validation(quote.contract)
	var before: Dictionary=app.session.station_owner().snapshot()
	var frozen: Dictionary=app.session.location_owner().read_snapshot()
	check(not app.session.contract_action("hire_wingmen",id,app.lounge_panel,func(_candidate):return false),"A failed durable save accepted a hire")
	check(app.session.station_owner().snapshot()==before and app.lounge_panel.snapshot().accept_visible,"Failed saving changed the wallet, roster or offer")
	press_coordinate_key(KEY_ENTER)
	check(app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Keyboard skipped wingman consent")
	press_coordinate_key(KEY_BACKSPACE)
	check(not app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Keyboard cancellation charged a hire")
	for button in [JOY_BUTTON_A,JOY_BUTTON_B]:
		var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true
		check(app.lounge_panel.handle_event(event),"Controller did not handle wingman consent")
	check(not app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Controller cancellation changed the contract")
	await click_coordinate_button(app.lounge_panel._yes)
	check(app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Mouse did not open passive hire confirmation")
	check(not String(app.lounge_panel.snapshot().body).contains("#Q") and not String(app.lounge_panel.snapshot().body).contains("#C"),"The hire confirmation retains tokens")
	await capture_free_application("wingmen-confirmation")
	if failures:return false
	await click_coordinate_button(app.lounge_panel._yes)
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(paid.contracts.credits==before.contracts.credits-quote.total_price and paid.contracts.get("wingmen",{}).get("active")==quote.contract,"Payment and the complete roster were not atomic")
	if failures:return false
	check(paid.contracts.wingmen.hired_total==int(before.contracts.get("wingmen",{}).get("hired_total",0))+names.size(),"Hiring did not count every offered pilot")
	check(paid.cargo==before.cargo and paid.loadout==before.loadout and paid.progress==before.progress and paid.contracts.mission==before.contracts.mission,"The hire changed goods, fittings, progression or the job")
	check(retained.snapshot()==initial and app.session.location_owner().read_snapshot()==frozen,"Hiring changed its parent frame or generated lounge")
	var repeated: RefCounted=app.session.station_owner().fork()
	check(not repeated.hire_lounge_wingmen(id,definitions) and repeated.snapshot()==paid,"A second active roster charged the player")
	check(not repeated.hire_lounge_wingmen(-1,definitions) and repeated.snapshot()==paid,"An invalid contact changed the paid career")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	var archive=load("res://src/simulation/station_archive.gd").new()
	var restored: RefCounted=archive.restore(definitions,catalogue,source,automatic)
	check(restored!=null and restored.snapshot()==paid,"Immediate native autosave lost the paid roster: "+archive.error)
	await capture_free_application("wingmen-hired")
	if failures or not app.contract_action("close",-1) or not retain_recovery_save("hired"):return false
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	await capture_free_application("wingmen-retention-departure")
	if not await dock_application():return false
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.contracts.credits==paid.contracts.credits and landed.contracts.get("wingmen",{}).get("active",{}).get("names")==names and landed.contracts.wingmen.hired_total==paid.contracts.wingmen.hired_total,"Departure or docking lost the paid roster")
	if not await check_active_roster() or not retain_recovery_save("returned"):return false
	await capture_free_application("wingmen-returned")
	return failures==0

func check_active_roster() -> bool:
	if not app.contract_action("open",-1):check(false,app.session.error);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	var id: int=before.contracts.wingmen.active.contact_id
	app.lounge_panel.select_contact(id)
	for step in 40:
		if not application_step():return false
	var quote: Dictionary=app.session.station_owner().wingman_preview(id,definitions)
	check(not quote.is_empty() and quote.busy and not quote.can_accept and not app.lounge_panel.snapshot().accept_visible,"An active roster was lost from the lounge refusal")
	check(app.lounge_panel.snapshot().body==app.lounge_panel.text(774),"The original active-wingmen response is absent")
	press_coordinate_key(KEY_ENTER)
	check(app.session.station_owner().snapshot()==before,"The busy contact charged again")
	await capture_free_application("wingmen-active-roster")
	return app.contract_action("close",-1) and failures==0

func verify_contract_validation(active: Dictionary) -> void:
	var record:={"hired_total":active.names.size(),"active":active.duplicate(true)}
	check(WingmanTerms.valid_state(record,definitions),"The actual offered contract is invalid")
	for key in ["price","remaining_ms","faction","contact_id","station_id"]:
		var invalid: Dictionary=record.duplicate(true);invalid.active[key]=-1
		check(not WingmanTerms.valid_state(invalid,definitions),"Negative "+key+" entered the saved contract")
	for names in [[],[""],["a","b","c","d"]]:
		var invalid: Dictionary=record.duplicate(true);invalid.active.names=names
		check(not WingmanTerms.valid_state(invalid,definitions),"An invalid pilot roster entered the saved contract")
	var malformed: Dictionary=record.duplicate(true);malformed.active.portrait.parts[0]=-1
	check(not WingmanTerms.valid_state(malformed,definitions),"An invalid captain portrait entered the saved contract")
	malformed=record.duplicate(true);malformed.hired_total=0
	check(not WingmanTerms.valid_state(malformed,definitions),"The saved total omits active pilots")
	var faction_count:=int(definitions.early_contracts.generation.identity.faction_bound)
	malformed=record.duplicate(true);malformed.active.faction=faction_count-1
	check(WingmanTerms.valid_state(malformed,definitions),"The validator excludes source minor-faction pilots")
	malformed.active.faction=faction_count
	check(not WingmanTerms.valid_state(malformed,definitions),"A faction outside the imported population entered the roster")
	malformed=record.duplicate(true);malformed.active.remaining_ms=WingmanTerms.DURATION_MS+1
	check(not WingmanTerms.valid_state(malformed,definitions),"A save lengthened the source contract duration")
