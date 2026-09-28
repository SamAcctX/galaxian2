extends "res://tests/automatic_tractor_application.gd"
## Earned supplier travel, paid equipment/cells, flight input and saved fuel.
var _cloak_item:=94

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_CLOAK_RESUMED")=="1"
	if not resumed and OS.get_environment("GOF2_CLOAK_PREPARED")!="1":
		if energy(original.cargo)<4:
			if original.loadout.station_id!=19 and not await visit_tractor_supplier(19):return
			if not app.equipment_action("open"):check(false,app.session.error);return
			var quote: Dictionary=app.session.station_owner().snapshot()
			var cells: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==122 and row.stock>=4)
			if cells.size()!=1:check(false,"The earned supplier has no energy cells");return
			for unit in 4:
				if not app.equipment_action("buy",122):check(false,app.session.error);return
			check(app.session.station_owner().snapshot().contracts.credits==quote.contracts.credits-4*cells[0].unit_price,"Bought cells did not debit their actual quote")
			if not app.equipment_action("close") or not retain_recovery_save("cells-bought"):return
		if original.loadout.station_id!=26 and not await visit_tractor_supplier(26):return
		if not retain_recovery_save("supplier"):return
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		var offers: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==_cloak_item and row.stock>0 and row.unit_price<=quote.contracts.credits)
		print("Cloak supplier: ",{"station":quote.loadout.station_id,"offers":offers,"loadout":quote.loadout.equipment_ids,"cargo":quote.cargo.entries,"wallet":quote.contracts.credits})
		if offers.size()!=1:check(false,"The earned supplier has no affordable cloak");return
		if not app.equipment_action("buy",_cloak_item) or not app.equipment_action("unmount",57) or not app.equipment_action("mount",_cloak_item):check(false,app.session.error);return
		check(app.session.station_owner().snapshot().contracts.credits==quote.contracts.credits-offers[0].unit_price,"Cloak fitting changed its paid quote")
		app.equipment_panel.select_tab("ship")
		await capture_free_application("cloak-purchased-fitted")
		if not app.equipment_action("close"):check(false,app.session.error);return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(_cloak_item) and fitted.contracts.passengers==3 and fitted.contracts.mission==original.contracts.mission,"Cloak fitting or Resume lost the device or passenger job")
	check(energy(fitted.cargo)==(2 if resumed else 4),"Fresh fitting/Resume has the wrong paid energy quantity")
	if failures or not retain_recovery_save("fitted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight() or not await fly_cloaked(resumed):return
	var flown: Dictionary=app.session.snapshot()
	check(energy(flown.cargo)==energy(fitted.cargo)-2 and flown.cargo.used==fitted.cargo.used-2,"Cloaking did not spend exactly its purchased cells and cargo space")
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.cargo==flown.cargo and landed.contracts.credits==fitted.contracts.credits,"Docking lost the fitted cloak or restored spent energy")
	check(landed.campaign_cursor==original.campaign_cursor and landed.contracts.mission==original.contracts.mission and landed.contracts.passengers==3,"Cloaking changed the campaign or retained passenger job")
	check(not app._cloak_charge.visible,"Station retained flight cloak controls")
	if not retain_recovery_save("returned"):return
	var document: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not document.is_empty() and document.inventory.cargo==landed.cargo,"Station autosave failed to retain consumed cloak fuel")
	await capture_free_application("cloak-saved-station")
	print("Cloak saved: ",{"item":_cloak_item,"cells":energy(landed.cargo),"credits":landed.contracts.credits,"cursor":landed.campaign_cursor,"deltas":_pilot_deltas})

func energy(cargo: Dictionary) -> int:
	var total:=0
	for row in cargo.entries:
		if row.item_id==122 and not row.get("mission",false):total+=int(row.quantity)
	return total

func press_cloak(menu: bool) -> bool:
	resume_application_focus()
	var pointer:=OS.get_environment("GOF2_CLOAK_MOUSE")=="1"
	menu=menu or pointer
	if menu:
		press_cloak_key(KEY_E)
		if not app.flight_menu.visible:check(false,"E did not open flight actions");return false
		var rows: Array=app.flight_menu.snapshot().rows
		var index: int=rows.find(rows.filter(func(row):return row.action=="cloak").front()) if rows.any(func(row):return row.action=="cloak") else -1
		if index<0:check(false,"The ready cloak was absent from flight actions");return false
		if pointer:await click_cloak_control(app.flight_menu._buttons[index])
		else:press_cloak_key(KEY_1+index)
	else:press_cloak_key(KEY_C)
	if not app.session._cloak_requested:check(false,"C/action menu did not queue a cloak activation");return false
	return pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0})

func click_cloak_control(control: Control) -> void:
	await process_frame;resume_application_focus()
	var point: Vector2=root.get_final_transform()*control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	Input.parse_input_event(motion);Input.flush_buffered_events()
	for down in [true,false]:
		var click:=InputEventMouseButton.new();click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
		Input.parse_input_event(click);Input.flush_buffered_events()
	await process_frame;resume_application_focus()
	check(not app.session.snapshot().get("flight_notices",{}).get("pending",[]).any(func(row):return row.get("source_id") in [6,11]),"Closing the cloak menu/notice also requested mining")

func press_cloak_key(code: int) -> void:
	for down in [true,false]:
		var key:=InputEventKey.new();key.physical_keycode=code;key.pressed=down;app._unhandled_input(key)

func fly_cloaked(menu: bool) -> bool:
	var hostile:=OS.get_environment("GOF2_CLOAK_HOSTILE")=="1"
	if hostile and not await approach_cloak_enemy():return false
	var initial: Dictionary=app.session.snapshot()
	check(initial.cloak.ready and initial.cloak.activation==0,"Departure retained another flight's cloak phase")
	if not await press_cloak(menu):return false
	var started: Dictionary=app.session.snapshot()
	check(started.cloak.phase=="charging" and started.cloak.activation==1 and energy(started.cargo)==energy(initial.cargo)-2,"Cloak did not atomically charge and spend its energy")
	if OS.get_environment("GOF2_CLOAK_INPUT_ONLY")=="1":return failures==0
	var next_yield:=now_us+1000000;var charging_seen:=false;var active_seen:=false;var shots:=0;var suppressed:=0
	while not app.session.snapshot().cloak.ready:
		var before: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The cloak pilot died");return false
		if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":active_seen and (not hostile or shots==0),"strafe":PiratePilot.evasion_at(now_us/1000.0) if hostile else 0.0}):return false
		var state: Dictionary=app.session.snapshot()
		if state.cloak.phase=="charging" and state.cloak.progress>=0.5 and not charging_seen:
			charging_seen=true
			check(app._cloak_charge.visible and not app.session.flight_owner()._player.targeting_blocked(),"Charge progress is missing or already hides the player")
			await capture_free_application("cloak-charging")
		if state.cloak.active:
			for actor in state.encounter.actor_events:
				if actor.get("decision",{}).get("target_kind")=="player":
					suppressed+=1
					check(not actor.decision.get("fire_requested",false),"An NPC fired at the actively cloaked player")
			check(app.session.flight_owner()._player.targeting_blocked(),"Active cloak did not suppress enemy targeting")
			for fire in state.encounter.get("primary_fire",{}).get("weapons",[]):
				if fire.get("result",{}).get("fired",false):shots+=1
			if state.cloak.dissolve>=1.0 and not active_seen:
				active_seen=true
				check(not app._cloak_charge.visible,"Active cloak retained its charging bar or a placeholder action icon")
				await capture_free_application("cloak-active")
				var retained: RefCounted=app.session.flight_owner();var held: Dictionary=retained.snapshot()
				# Detached contact diagnostic: the live earned flight stays untouched.
				var struck: RefCounted=retained._player.fork_for_frame()
				var pools: Dictionary=struck.snapshot().vitals
				check(not struck.normal_hit(1).is_empty() and struck.snapshot().vitals!=pools and struck.targeting_blocked(),"Cloaking made physical/projectile contact invulnerable")
				check(retained._encounter.target(retained._player,held.player_pose).targeting_blocked,"The encounter dropped the player cloak's targeting flag")
				check(app.session.set_pause("user",true,now_us),app.session.error);now_us+=1000000
				check(app.session.step(now_us) and app.session.snapshot().cloak==held.cloak,"Pause advanced the timed cloak")
				check(app.session.set_pause("user",false,now_us),app.session.error)
				# The menu offers ready devices; a direct key still reaches the
				# lifecycle's no-op rule while this activation is in progress.
				press_cloak_key(KEY_C)
				if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
				check(app.session.snapshot().cloak.activation==1 and energy(app.session.snapshot().cargo)==energy(held.cargo) and retained.snapshot()==held,"Repeated input spent fuel, restarted the cloak or mutated its parent")
		if before.cloak.active and not state.cloak.active:
			check(state.cloak.phase=="cooldown" and not app.session.flight_owner()._player.targeting_blocked(),"Expiry did not restore targeting and start cooldown")
			await capture_free_application("cloak-restored-cooldown")
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	check(charging_seen and active_seen and shots>0,"The actual flight never charged, cloaked and fired while cloaked")
	if hostile:
		check(suppressed>0,"No enemy tried to target the cloaked player")
		if not await approach_cloak_enemy():return false
		print("Cloak hostile suppression: ",suppressed," accepted enemy decisions between observed firing before and after")
	check(app.session.flight_audio.snapshot().unsupported.is_empty(),"Cloak flight requested unsupported audio")
	check(app.session.flight_audio.snapshot().history.filter(func(row):return row.action=="start" and row.source_id==30).size()==2,"Cloak activation/expiry did not request both original sounds")
	if menu:
		var before: Dictionary=app.session.snapshot()
		if not await press_cloak(false):return false
		check(app._cloak_dialog.visible and app.session.is_paused(),"Insufficient energy did not open its original paused notice")
		check(app.session.snapshot().cloak.ready and app.session.snapshot().cloak.activation==1 and app.session.snapshot().cargo==before.cargo,"Insufficient energy changed fuel or restarted cloak")
		await capture_free_application("cloak-insufficient-energy")
		if OS.get_environment("GOF2_CLOAK_MOUSE")=="1":await click_cloak_control(app._cloak_dialog._yes)
		else:press_cloak_key(KEY_ENTER)
		check(not app._cloak_dialog.visible and not app.session.is_paused(),"Dismissing the energy notice did not resume flight")
	return failures==0

func approach_cloak_enemy() -> bool:
	var initial: Dictionary=app.session.snapshot()
	var candidates: Array=initial.encounter.combat.actors.filter(func(actor):return actor.active and actor.hostile and actor.vitals.hull>0)
	print("Cloak encounter: ",initial.encounter.combat.actors.map(func(actor):return {"id":actor.actor_id,"kind":actor.actor_kind,"hostile":actor.hostile,"active":actor.active}))
	# If this visit has no pirates, provoke a patrol through a real gun hit.
	# Its ordinary faction reaction, including the saved consequence, stays live.
	if candidates.is_empty():candidates=initial.encounter.combat.actors.filter(func(actor):return actor.active and actor.population_group!="freighter" and actor.vitals.hull>0)
	if candidates.is_empty():check(false,"The earned flight has no armed ship for cloak targeting acceptance");return false
	var ids: Array=candidates.map(func(actor):return actor.actor_id)
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us
	while now_us-started<180000000:
		var state: Dictionary=app.session.snapshot()
		if app.session.flight_owner().death_active():check(false,"The cloak pilot died before observing enemy fire");return false
		for actor in state.encounter.actor_events:
			var decision: Dictionary=actor.get("decision",{})
			if decision.get("target_kind")=="player" and decision.get("fire_requested",false):
				await capture_free_application("cloak-enemy-before" if state.cloak.activation==0 else "cloak-enemy-after")
				return true
		var input:=pilot.controls_at_time(state,(now_us-started)/1000.0,ids,true)
		input.fire=input.fire and not state.encounter.combat.actors[input.target].hostile
		if not pirate_step(input):return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
	check(false,"No enemy fired at the visible player on the input-only approach");return false

func follow_gate_course(system_id: int,station_id: int) -> bool:
	resume_application_focus()
	var accepted: bool=await super.follow_gate_course(system_id,station_id)
	if not accepted:
		print("Cloak gate diagnostic: ",{"system":system_id,"station":station_id,"map_error":app.map_panel.error,"session_error":app.session.error,"pauses":app.session._pauses,"choices":app.map_panel.snapshot().get("system_choices",[])})
	return accepted
