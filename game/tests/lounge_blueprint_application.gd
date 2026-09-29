extends "res://tests/lounge_coordinates_application.gd"
## A real authored recipe purchase, using the shared earned-career pilot only.

func verify_free_application() -> void:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if directory.is_empty():check(false,"Blueprint checks require isolated autosaves");return
	var source_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(source_path)
	var resumed:=OS.get_environment("GOF2_BLUEPRINT_RESUMED")=="1"
	app.enable_saves(directory);app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false):
		if not app.equipment_action("close"):check(false,app.session.error);return
	var retained: RefCounted=app.session.station_owner()
	var original: Dictionary=retained.snapshot()
	var sellers: Array=original.contracts.population.contacts.filter(func(row):return row.get("role")==3 and row.has("blueprint"))
	if sellers.size()!=1:check(false,"The earned visit has no unique authored blueprint seller");return
	var id:=int(sellers[0].contact_id)
	var item:=int(sellers[0].blueprint.item_id)
	var price:=int(sellers[0].blueprint.price)
	var quote: Dictionary=retained.blueprint_preview(id,definitions)
	if quote.is_empty():check(false,retained.error);return
	check(quote.kind=="blueprint" and quote.item_id==item and quote.total_price==price,"The recipe quote changed the retained contact terms")
	check(not app.session.contract_action("buy_blueprint",id,null),"A closed lounge accepted payment")
	check(app.session.set_pause("user",true,now_us),app.session.error)
	check(not app.contract_action("buy_blueprint",id),"Paused input bought a blueprint")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	check(retained.snapshot()==original,"Rejected input mutated the retained parent")
	if failures or not app.contract_action("open",-1):check(false,app.session.error);return
	for step in 20:
		if not application_step():return
	app.lounge_panel.select_contact(id)
	var before: Dictionary=app.session.station_owner().snapshot()
	var body: String=app.lounge_panel.snapshot().body
	var name: String=source.strings[int(definitions.station_equipment.item_text_offset)+item]
	check((resumed or (body.contains(name) and body.contains(str(price)))) and not body.contains("#P") and not body.contains("#C") and not body.contains("not yet available"),"The source blueprint confirmation is absent or unresolved")
	await capture_free_application("blueprint-resumed" if resumed else "blueprint-offer")
	if resumed:
		check(quote.consumed and not quote.can_accept and not app.lounge_panel.snapshot().accept_visible,"Fresh Resume resurrected the blueprint purchase")
		press_coordinate_key(KEY_ENTER)
		check(app.session.station_owner().snapshot()==before,"Enter charged again after fresh Resume")
		check(before.contracts.credits==int(OS.get_environment("GOF2_BLUEPRINT_EXPECTED_CREDITS")),"Fresh Resume changed the paid wallet")
		if not app.contract_action("close",-1) or not await show_purchased_blueprint(item,"blueprint-hangar-resumed"):return
		if not retain_recovery_save("resumed"):return
		check(FileAccess.get_sha256(source_path)==input_hash,"Resume changed its immutable source save")
		print("Blueprint fresh Resume: ",{"item":item,"credits":before.contracts.credits,"input_sha256":input_hash})
		return
	check(not quote.consumed and quote.can_accept,"The earned recipe cannot be purchased")
	if failures:return
	# Deliberately unfunded unit fork: never installed in the app or saved.
	var unfunded: RefCounted=retained.contract_owner().fork()
	unfunded._state.credits=price-1
	var poor: Dictionary=unfunded.snapshot()
	check(not unfunded.blueprint_preview(definitions,id,retained._equipment).can_accept,"Insufficient funds were quoted as affordable")
	check(not unfunded.purchase_lounge_blueprint(definitions,id,retained._equipment) and unfunded.snapshot()==poor,"An unfunded refusal changed its detached career")
	check(not app.session.contract_action("buy_blueprint",-1,app.lounge_panel),"An invalid contact accepted payment")
	check(app.session.station_owner().snapshot()==before,"Invalid contact input mutated the live career")
	check(not app.session.contract_action("buy_blueprint",id,app.lounge_panel,func(_candidate):return false),"A failed durable checkpoint accepted payment")
	check(app.session.station_owner().snapshot()==before and app.lounge_panel.snapshot().accept_visible,"Save failure changed the wallet, recipe or purchase preview")
	press_coordinate_key(KEY_ENTER)
	check(app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Enter skipped consent or charged early")
	press_coordinate_key(KEY_BACKSPACE)
	check(not app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Keyboard cancellation charged the wallet")
	for button in [JOY_BUTTON_A,JOY_BUTTON_B]:
		var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true
		check(app.lounge_panel.handle_event(event),"Controller did not handle blueprint consent")
	check(not app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Controller cancellation changed the career")
	await click_coordinate_button(app.lounge_panel._yes)
	check(app.lounge_panel.snapshot().confirming and app.session.station_owner().snapshot()==before,"Mouse did not request consent")
	await capture_free_application("blueprint-confirmation")
	if failures:return
	await click_coordinate_button(app.lounge_panel._yes)
	var bought: Dictionary=app.session.station_owner().snapshot()
	var expected: Dictionary=before.contracts.blueprints.duplicate(true)
	for row in expected.entries:
		if row.item_id==item:row.available=true
	check(bought.contracts.credits==before.contracts.credits-price and bought.contracts.blueprints==expected,"The purchase failed to debit and unlock only its recipe")
	check(bought.cargo==before.cargo and bought.loadout==before.loadout and bought.progress==before.progress,"The purchase changed goods, fittings or campaign progress")
	check(bought.contracts.mission==before.contracts.mission and bought.contracts.passengers==before.contracts.passengers and bought.contracts.lounges==before.contracts.lounges,"The purchase changed the passenger job, population or known systems")
	check(retained.snapshot()==original,"The purchase mutated the retained parent")
	check(not app.lounge_panel.snapshot().accept_visible,"The purchased recipe still has a buy button")
	var repeated: RefCounted=app.session.station_owner().fork()
	check(not repeated.purchase_lounge_blueprint(id,definitions) and repeated.snapshot()==bought,"A repeat purchase charged or changed the recipe")
	# Read the automatic write before an explicit save helper could conceal failure.
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	var archive=load("res://src/simulation/station_archive.gd").new()
	var restored: RefCounted=archive.restore(definitions,catalogue,source,automatic)
	if restored!=null and restored.snapshot()!=bought:coordinate_difference(bought,restored.snapshot())
	check(restored!=null and restored.snapshot()==bought,"Immediate autosave lost the paid recipe: "+archive.error)
	await capture_free_application("blueprint-purchased")
	if failures or not app.contract_action("close",-1):return
	if not await show_purchased_blueprint(item,"blueprint-hangar"):return
	if not retain_recovery_save("purchased"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	await capture_free_application("blueprint-departure")
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.contracts.credits==bought.contracts.credits and landed.contracts.blueprints==expected,"Flight/docking lost the purchase or changed recipe materials")
	check(landed.cargo==before.cargo and landed.loadout.equipment_ids==before.loadout.equipment_ids and landed.contracts.mission==before.contracts.mission and landed.contracts.passengers==before.contracts.passengers and landed.campaign_cursor==before.campaign_cursor,"The journey changed retained goods, equipment, job or story")
	if not retain_recovery_save("returned"):return
	await capture_free_application("blueprint-saved-station")
	check(FileAccess.get_sha256(source_path)==input_hash,"The earned source save was modified")
	print("Blueprint earned purchase: ",{"item":item,"price":price,"credits_before":before.contracts.credits,"credits_after":landed.contracts.credits,"station":landed.loadout.station_id,"input_sha256":input_hash})

func show_purchased_blueprint(item: int,capture: String) -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	await process_frame
	await click_coordinate_button(app.equipment_panel._tabs.blueprints)
	check(app.equipment_panel._tab=="blueprints" and app.equipment_panel._blueprint_rows.has(item),"The purchased recipe did not appear in Hangar construction")
	if failures:return false
	await click_coordinate_button(app.equipment_panel._blueprint_rows[item])
	check(app.equipment_panel._selected_blueprint==item,"The native Hangar recipe selection failed")
	await capture_free_application(capture)
	if not app.equipment_action("close"):check(false,app.session.error);return false
	return true
