extends "res://tests/cargo_scanner_application.gd"
## Earned purchase and input-only beam contact, with the retained passenger job.

func open_application_content(args: PackedStringArray) -> bool:
	if not super.open_application_content(args):return false
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array or supplement.size()!=3:check(false,"Missing the paid career's declared source");return false
		var accepted: bool=definitions.attach_dekato_source(supplement[1],source.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else definitions.attach_nehma_source(supplement[1],source.manifest)
		if not accepted:check(false,definitions.error);return false
	return true

func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor==45 and state.contracts.passengers==3

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_BEAM_RESUMED")=="1"
	var item:=9;var price:=0
	if not resumed:
		if original.loadout.station_id!=37 and not await visit_delivery_station(37):return
		if not app.equipment_action("open"):check(false,app.session.error);return
		var quote: Dictionary=app.session.station_owner().snapshot()
		var offers: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==item and row.stock>0 and row.unit_price<=quote.contracts.credits)
		if offers.size()!=1:check(false,"The earned destination shop lacks an affordable M6");return
		price=int(offers[0].unit_price)
		if not app.equipment_action("buy",item):check(false,app.session.error);return
		for slot in quote.loadout.slots:
			if slot!=null and slot.category==0:
				if not app.equipment_action("unmount",slot.item_id):check(false,app.session.error);return
		if not app.equipment_action("mount",item):check(false,app.session.error);return
		var bought: Dictionary=app.session.station_owner().snapshot()
		check(bought.contracts.credits==quote.contracts.credits-price and bought.cargo.entries.has({"item_id":2,"quantity":1}),"The M6 purchase lost the quoted price or retained gun")
		await capture_free_application("beam-purchased")
		app.equipment_panel.select_tab("ship")
		await capture_free_application("beam-fitted")
		if not app.equipment_action("close"):check(false,app.session.error);return
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.loadout.equipment_ids.has(item) and fitted.contracts.passengers==3 and fitted.contracts.mission==original.contracts.mission,"Fitting the beam lost the passenger job or cabin")
	check(fitted.loadout.equipment_ids.all(func(id):return catalogue.tables.items[id].properties.get(2)!=17),"The no-scanner aim-window route unexpectedly fitted a scanner")
	if failures or not retain_recovery_save("fitted"):return
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	if not await fire_beam_input(item):return
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.loadout==fitted.loadout and landed.cargo==fitted.cargo and landed.contracts.credits==fitted.contracts.credits,"Beam fire changed fitting, cargo or credits")
	check(landed.contracts.passengers==3 and landed.contracts.mission==original.contracts.mission and landed.campaign_cursor==45,"Beam flight changed the passenger or completed campaign state")
	if not retain_recovery_save("returned"):return
	await capture_free_application("beam-saved-station")
	print("Beam saved: ",{"item":item,"price":price,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor,"passengers":landed.contracts.passengers})

func fire_beam_input(item: int) -> bool:
	var initial: Dictionary=app.session.snapshot()
	var candidates: Array=initial.encounter.combat.actors.filter(func(actor):return actor.active and actor.population_group=="freighter" and actor.vitals.hull>0)
	candidates.sort_custom(func(a,b):return a.pose.origin.distance_squared_to(initial.player_pose.origin)<b.pose.origin.distance_squared_to(initial.player_pose.origin))
	if candidates.is_empty():check(false,"The generated flight has no living freighter for aimed beam contact");return false
	var id:=int(candidates[0].actor_id);var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	while now_us-started<180000000:
		var state: Dictionary=app.session.snapshot();var actor: Dictionary=state.encounter.combat.actors[id]
		if app.session.flight_owner().death_active():check(false,"The beam pilot died before an aimed hit");return false
		var distance: float=actor.pose.origin.distance_to(state.player_pose.origin)
		var eligible: Array=state.npc_scanner.weapon_target_ids.duplicate()
		eligible.sort_custom(func(a,b):return int(state.encounter.combat.actors[a].pose.origin.distance_to(state.player_pose.origin))<int(state.encounter.combat.actors[b].pose.origin.distance_to(state.player_pose.origin)))
		var input:={"commands":PiratePilot.Steering.steering_toward(state.player_pose,actor.pose.origin),"throttle":1.0 if distance>28000.0 else 0.0,"fire":not eligible.is_empty() and eligible[0]==id,"strafe":0.0}
		if not pirate_step(input):return false
		var after: Dictionary=app.session.snapshot();var projectile: Dictionary=after.encounter.primaries.guns[0].projectiles
		if not projectile.beam.is_empty() and projectile.beam.target_actor_id==id:
			# Input is late in the player frame; its next weapon pass owns contact.
			if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
			after=app.session.snapshot()
			var damaged: Dictionary=after.encounter.combat.actors[id]
			check(damaged.vitals!=actor.vitals and damaged.systems==actor.systems,"Input-fired M6 did not apply its normal damage contact")
			check(after.npc_scanner.selected_actor_id<0 and after.npc_scanner.equipment_id<0,"M6 hit depended on a fitted scanner or acquired lock")
			var sound:=int(definitions.weapon_parameters.audio.player_event_ids[item])
			check(app.session.flight_audio.snapshot().history.any(func(event):return event.get("source_id")==sound and event.get("item_id")==item),"M6 omitted its original firing sound")
			await capture_free_application("beam-hit-without-lock")
			for tick in 3:
				if not pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0}):return false
			await capture_free_application("beam-fading")
			print("Beam hit: ",{"target":id,"before":actor.vitals,"after":damaged.vitals,"length":projectile.beam.length,"elapsed":(now_us-started)/1000000.0})
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("Beam aim: ",{"elapsed":(now_us-started)/1000000.0,"target":id,"distance":distance,"eligible":eligible})
			next_log=now_us+10000000
	check(false,"Input aiming did not put the generated target in the beam window");return false
