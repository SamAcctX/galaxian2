extends "res://tests/lounge_coordinates_application.gd"
## Real earned career only. Inputs may trade, fly and fight; observations never
## write wallet, affiliation, generated contacts, actors or save documents.
const Diplomacy=preload("res://src/simulation/faction_reputation.gd")

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var original: Dictionary=app.session.station_owner().snapshot()
	print("Earned diplomacy entry: ",{"station":original.loadout.station_id,"credits":original.contracts.credits,"reputation":original.contracts.reputation,"cargo":original.cargo,"equipment":original.loadout.equipment_ids})
	var stage:=OS.get_environment("GOF2_DIPLOMAT_STAGE")
	if stage in ["earn","advance"]:
		if OS.get_environment("GOF2_DIPLOMAT_OUTFIT")=="1" and not await outfit_combat():return
		if not await earn_fee():return
		if not retain_recovery_save("funded"):return
		var sortie_limit:=12 if stage=="earn" else 1
		if not OS.get_environment("GOF2_DIPLOMAT_SORTIES").is_empty():sortie_limit=clampi(OS.get_environment("GOF2_DIPLOMAT_SORTIES").to_int(),1,12)
		for sortie in sortie_limit:
			if Diplomacy.diplomat_quote(app.session.station_owner().snapshot().contracts.reputation,0).eligible:break
			if not await earn_hostility():return
			if not await withdraw_and_dock():return
			if not retain_recovery_save("sortie-"+str(sortie+1)):return
			print("Earned sortie docked: ",{"sortie":sortie+1,"standing":app.session.station_owner().snapshot().contracts.reputation})
		var earned: Dictionary=app.session.station_owner().snapshot()
		var eligible: bool=Diplomacy.diplomat_quote(earned.contracts.reputation,0).eligible
		check(earned.contracts.reputation.axes[0]<original.contracts.reputation.axes[0],"The bounded route banked no actual faction consequence")
		if stage=="earn":check(eligible,"The bounded earned sorties did not reach hostile standing")
		if failures:return
		if not retain_recovery_save("prepared" if eligible else "advanced"):return
		await capture_free_application("diplomat-earned-preparation" if eligible else "diplomat-earned-advance")
		print("Earned preparation boundary: ",{"eligible":eligible,"paid_diplomat":false,"sortie_limit":sortie_limit})
	elif stage=="resume_preparation":
		var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(saved.career.credits==original.contracts.credits and saved.career.reputation==original.contracts.reputation,"Fresh preparation Resume changed money or standing")
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight() or not await dock_application():return
		var returned: Dictionary=app.session.station_owner().snapshot()
		check(returned.contracts.credits==original.contracts.credits and returned.contracts.reputation==original.contracts.reputation and returned.loadout==original.loadout and returned.cargo==original.cargo,"Fresh preparation flight/docking changed its saved progress")
		if not retain_recovery_save("resumed-preparation"):return
		await capture_free_application("diplomat-preparation-resumed")
	elif stage=="buy":
		if not await find_and_pay_diplomat():return
	elif stage=="resume":
		var saved: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
		check(saved.career.credits==original.contracts.credits and saved.career.reputation==original.contracts.reputation,"Fresh Resume changed diplomat payment or standing")
		if not await check_consumed_diplomat():return
		await capture_free_application("diplomat-earned-resumed")
		if not retain_recovery_save("resumed"):return
	else:check(false,"Select an explicit earned diplomacy stage");return
	var final: Dictionary=app.session.station_owner().snapshot()
	check(final.contracts.mission==original.contracts.mission and final.contracts.passengers==original.contracts.passengers and final.contracts.blueprints==original.contracts.blueprints and final.campaign_cursor==original.campaign_cursor,"Diplomacy journey changed the unrelated job, recipe or campaign")
	check(FileAccess.get_sha256(input_path)==input_hash,"The earned input was modified")
	print("Earned diplomacy result: ",{"stage":stage,"credits":final.contracts.credits,"reputation":final.contracts.reputation,"station":final.loadout.station_id,"input_sha256":input_hash})

func outfit_combat() -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	print("Actual combat shop: ",before.equipment.market_rows.filter(func(row):return row.item_id in [2,4,51,57,64,94]))
	# Exchange the previous test's cloak for the armor it had displaced. These
	# are paid, ordinary Hangar operations, never a fabricated loadout.
	for item in [64,94]:
		if app.session.station_owner().snapshot().loadout.equipment_ids.has(item):
			if not app.equipment_action("unmount",item):check(false,app.session.error);return false
		if not app.equipment_action("sell",item):check(false,app.session.error);return false
	var chosen_primary:=2
	for requested_item in [57,-1]:
		var item: int=requested_item
		var quote: Dictionary=app.session.station_owner().snapshot()
		if item==-1:
			var damage_property:=int(definitions.weapon_parameters.damage_property)
			var interval_property:=int(definitions.weapon_parameters.interval_property)
			var current: Dictionary=catalogue.tables.items[2].properties
			var current_rate: float=float(current[damage_property])/maxf(1.0,float(current[interval_property]))
			var upgrades: Array=quote.equipment.market_rows.filter(func(row):return row.item_id in [0,1,3,4] and row.stock>0 and row.unit_price<=quote.contracts.credits-16000 and float(catalogue.tables.items[row.item_id].properties[damage_property])/maxf(1.0,float(catalogue.tables.items[row.item_id].properties[interval_property]))>current_rate)
			upgrades.sort_custom(func(a,b):return float(catalogue.tables.items[a.item_id].properties[damage_property])/maxf(1.0,float(catalogue.tables.items[a.item_id].properties[interval_property]))>float(catalogue.tables.items[b.item_id].properties[damage_property])/maxf(1.0,float(catalogue.tables.items[b.item_id].properties[interval_property])))
			print("Available earned gun upgrades: ",{"wallet":quote.contracts.credits,"offers":upgrades})
			if upgrades.is_empty():continue
			item=int(upgrades[0].item_id);chosen_primary=item
		var rows: Array=quote.equipment.market_rows.filter(func(row):return row.item_id==item and row.stock>0 and row.unit_price<=quote.contracts.credits-16000)
		if rows.is_empty():check(false,"Actual combat shop cannot supply item "+str(item)+" while reserving the fee");return false
		if not app.equipment_action("buy",item):check(false,app.session.error);return false
		check(app.session.station_owner().snapshot().contracts.credits==quote.contracts.credits-rows[0].unit_price,"Combat equipment changed its actual price")
		if requested_item==-1 and not app.equipment_action("unmount",2):check(false,app.session.error);return false
		if not app.equipment_action("mount",item):check(false,app.session.error);return false
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.contracts.credits>=16000 and fitted.loadout.equipment_ids.has(57) and fitted.loadout.equipment_ids.has(chosen_primary) and fitted.contracts.reputation==before.contracts.reputation,"Paid preparation changed standing or spent the reserved fee")
	check(fitted.contracts.mission==before.contracts.mission and fitted.contracts.passengers==before.contracts.passengers and fitted.contracts.blueprints==before.contracts.blueprints,"Combat fitting changed the unrelated job or recipe")
	app.equipment_panel.select_tab("ship")
	await capture_free_application("diplomat-combat-fitted")
	if failures or not app.equipment_action("close") or not retain_recovery_save("outfitted"):return false
	print("Earned combat outfit: ",{"credits":fitted.contracts.credits,"fitting":fitted.loadout.equipment_ids,"cargo":fitted.cargo.entries})
	return true

func earn_fee() -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	var sales:=[]
	while app.session.station_owner().snapshot().contracts.credits<16000:
		var state: Dictionary=app.session.station_owner().snapshot()
		var spares: Array=state.equipment.market_rows.filter(func(row):return row.owned>0 and not row.mission and not state.loadout.equipment_ids.has(row.item_id))
		spares.sort_custom(func(a,b):return a.unit_price>b.unit_price)
		if spares.is_empty():check(false,"No earned spare can fund the diplomat fee");return false
		var sale: Dictionary=spares[0]
		if not app.equipment_action("sell",sale.item_id):check(false,app.session.error);return false
		var after: Dictionary=app.session.station_owner().snapshot()
		check(after.contracts.credits==state.contracts.credits+sale.unit_price and after.loadout==state.loadout,"A real Hangar sale changed fitting or proceeds")
		sales.append({"item_id":sale.item_id,"price":sale.unit_price})
		if failures:return false
	print("Earned fee funding: ",{"credits_before":before.contracts.credits,"sales":sales,"credits_after":app.session.station_owner().snapshot().contracts.credits})
	await capture_free_application("diplomat-fee-funded")
	return app.equipment_action("close")

func earn_hostility() -> bool:
	var before: Dictionary=app.session.station_owner().snapshot()
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	if not await seek_smaller_patrol():return false
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us;var next_log:=now_us;var fired:=false
	var initial: Dictionary=app.session.snapshot()
	print("Native faction consequences: ",definitions.early_contracts.ship_lifecycle.reputation)
	print("Generated flight affiliations: ",initial.encounter.combat.actors.map(func(actor):return {"id":actor.actor_id,"kind":actor.actor_kind,"group":actor.population_group,"active":actor.active,"hull":actor.vitals.hull}))
	while now_us-started<480000000:
		var state: Dictionary=app.session.snapshot()
		# Bank each real combat consequence before another sortie, rather than
		# circling a crowded field indefinitely with the fragile starter hull.
		if state.progress.reputation.axes[0]<before.contracts.reputation.axes[0]:break
		if app.session.flight_owner().death_active():
			print("Defeated pilot state: ",{"vitals":state.player.vitals,"pose":state.player_pose,"phase":state.player_destruction.phase})
			await capture_free_application("diplomat-preparation-defeated")
			check(false,"The input pilot died while earning hostility; no save promoted");return false
		var targets: Array=state.encounter.combat.actors.filter(func(actor):return actor.active and actor.actor_kind==0 and actor.vitals.hull>0).map(func(actor):return actor.actor_id)
		if targets.is_empty():break
		var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
		var reach:=float(weapon.speed_units_per_millisecond)*float(weapon.lifetime_ms)
		pilot.firing_range=reach*0.9
		var input: Dictionary=pilot.controls_at_time(state,float(state.world_elapsed_ms),targets,false)
		input.throttle=1.0 if input.distance>minf(18000.0,reach*0.6) else 0.0
		if not pirate_step(input):return false
		if input.fire and not fired:
			fired=true;await capture_free_application("diplomat-earned-combat")
		if now_us>=next_yield:await process_frame;next_yield=now_us+2000000
		if now_us>=next_log:
			print("Diplomat preparation pilot: ",{"seconds":(now_us-started)/1000000.0,"target":input.target,"distance":input.distance,"hull":state.player.vitals.hull,"standing":state.progress.reputation,"target_hull":state.encounter.combat.actors[input.target].vitals.hull})
			next_log=now_us+30000000
	var after: Dictionary=app.session.snapshot()
	check(fired and after.progress.reputation.axes[0]<before.contracts.reputation.axes[0],"Real player fire did not earn faction consequences")
	check(after.contracts.credits==before.contracts.credits and after.cargo==before.cargo,"Combat changed wallet or unrecovered cargo")
	print("Earned hostility sortie: ",{"before":before.contracts.reputation,"after":after.progress.reputation,"kills":after.progress.player_kills})
	return failures==0 and pirate_step({"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0})

func seek_smaller_patrol() -> bool:
	# Observe a real encounter and decline a seven-ship patrol. Every retry
	# physically travels to another planet using the ordinary map controls;
	# no population, random seed, player pose or saved location is rewritten.
	for journey in 10:
		var state: Dictionary=app.session.snapshot()
		var patrols: Array=state.encounter.combat.actors.filter(func(actor):return actor.active and actor.actor_kind==0 and actor.population_group=="patrol" and actor.vitals.hull>0)
		print("Observed earned patrol: ",{"station":state.location.station_id,"count":patrols.size(),"journey":journey})
		if not patrols.is_empty() and patrols.size()<=2:return true
		var stations:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==state.location.system_id:stations.append(id)
		if stations.size()<2:check(false,"This system has no native alternate patrol route");return false
		var next: int=stations[(stations.find(state.location.station_id)+1)%stations.size()]
		if not await travel_application(next):return false
	check(false,"The bounded native planet route found no smaller patrol");return false

func withdraw_and_dock() -> bool:
	# Do not fly back through the patrol just attacked. Leave the live combat
	# through an ordinary planet journey, then dock from its normal arrival.
	var before: Dictionary=app.session.snapshot()
	var stations:=[]
	for id in catalogue.tables.stations.size():
		if catalogue.tables.stations[id].system_id==before.location.system_id:stations.append(id)
	if stations.size()<2:check(false,"No ordinary post-combat withdrawal destination exists");return false
	var destination: int=stations[(stations.find(before.location.station_id)+1)%stations.size()]
	if not await travel_application(destination):return false
	var arrived: Dictionary=app.session.snapshot()
	check(arrived.progress.reputation==before.progress.reputation and arrived.contracts.credits==before.contracts.credits and arrived.cargo==before.cargo,"Native post-combat travel changed the earned consequence")
	return failures==0 and await dock_application()

func find_and_pay_diplomat() -> bool:
	var visits: Array=Array(OS.get_environment("GOF2_DIPLOMAT_STATIONS").split(",",false))
	if visits.is_empty():
		var current: Dictionary=app.session.station_owner().snapshot()
		for station_id in catalogue.tables.stations.size():
			if catalogue.tables.stations[station_id].system_id==current.loadout.system_id and station_id!=current.loadout.station_id:visits.append(str(station_id))
	visits.push_front("-1")
	for value in visits:
		var destination:=int(value)
		if destination>=0 and not await visit_tractor_supplier(destination):return false
		var state: Dictionary=app.session.station_owner().snapshot()
		var contacts: Array=state.contracts.population.contacts.filter(func(row):return row.role==7 and Diplomacy.diplomat_quote(state.contracts.reputation,row.faction).eligible)
		print("Earned diplomat search: ",{"station":state.loadout.station_id,"contacts":state.contracts.population.contacts.map(func(row):return {"id":row.contact_id,"role":row.role,"faction":row.faction})})
		if contacts.is_empty():continue
		if not retain_recovery_save("eligible"):return false
		return await pay_diplomat(int(contacts[0].contact_id))
	check(false,"No eligible diplomat appeared on the actual visited route");return false

func pay_diplomat(id: int) -> bool:
	if not app.contract_action("open",-1):check(false,app.session.error);return false
	for step in 40:
		if not application_step():return false
	app.lounge_panel.select_contact(id)
	var before: Dictionary=app.session.station_owner().snapshot()
	var quote: Dictionary=app.session.station_owner().diplomat_preview(id,definitions)
	check(quote.can_accept and quote.total_price>0,"The genuine diplomat is not affordable")
	if failures:return false
	await capture_free_application("diplomat-earned-offer")
	check(not app.session.contract_action("buy_diplomat",id,app.lounge_panel,func(_candidate):return false),"A failed durable save accepted the earned payment")
	check(app.session.station_owner().snapshot()==before,"Failed save changed the earned career")
	press_coordinate_key(KEY_ENTER);press_coordinate_key(KEY_BACKSPACE)
	check(app.session.station_owner().snapshot()==before and not app.lounge_panel.snapshot().confirming,"Cancellation changed the earned career")
	await click_coordinate_button(app.lounge_panel._yes)
	await capture_free_application("diplomat-earned-confirmation")
	await click_coordinate_button(app.lounge_panel._yes)
	var paid: Dictionary=app.session.station_owner().snapshot()
	check(paid.contracts.credits==before.contracts.credits-quote.total_price and paid.contracts.reputation==quote.reputation_after,"Earned payment did not debit the exact fee and repair one axis")
	check(paid.cargo==before.cargo and paid.loadout==before.loadout and not app.lounge_panel.snapshot().accept_visible,"Diplomacy changed goods/fitting or left the contact reusable")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	var archive=load("res://src/simulation/station_archive.gd").new()
	var restored: RefCounted=archive.restore(definitions,catalogue,source,automatic)
	check(restored!=null and restored.snapshot()==paid,"The immediate native autosave lost paid service state")
	await capture_free_application("diplomat-earned-paid")
	if failures or not app.contract_action("close",-1) or not retain_recovery_save("paid"):return false
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight():return false
	await capture_free_application("diplomat-earned-departure")
	if not await dock_application():return false
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.contracts.credits==paid.contracts.credits and landed.contracts.reputation==paid.contracts.reputation and landed.cargo==paid.cargo,"Flight or docking reverted the earned diplomat payment")
	if not await check_consumed_diplomat() or not retain_recovery_save("returned"):return false
	await capture_free_application("diplomat-earned-returned")
	print("Earned diplomat paid: ",{"contact":id,"price":quote.total_price,"before":before.contracts.reputation,"after":paid.contracts.reputation,"credits":paid.contracts.credits})
	return failures==0

func check_consumed_diplomat() -> bool:
	if not app.contract_action("open",-1):check(false,app.session.error);return false
	var state: Dictionary=app.session.station_owner().snapshot()
	var consumed:=0
	for row in state.contracts.population.contacts:
		if row.role!=7:continue
		var quote: Dictionary=app.session.station_owner().diplomat_preview(row.contact_id,definitions)
		if not quote.get("consumed",false):continue
		consumed+=1;app.lounge_panel.select_contact(row.contact_id)
		check(not quote.can_accept and not app.lounge_panel.snapshot().accept_visible,"Saved diplomat consumption was lost")
		press_coordinate_key(KEY_ENTER)
		check(app.session.station_owner().snapshot()==state,"The used contact charged the earned career again")
	check(consumed==1,"The earned paid lounge lost its consumed diplomat")
	if failures:return false
	# Keep a viewed fresh-process proof of the used contact itself, not only
	# the station wallet after the lounge has already closed.
	for step in 40:
		if not application_step():return false
	check(not String(app.lounge_panel.snapshot().body).is_empty(),"The retained used diplomat lost its response")
	await capture_free_application("diplomat-consumed-contact")
	return app.contract_action("close",-1) and failures==0
