extends "res://tests/beam_primary_application.gd"
## Paid original launchers, real selection/R input, contacts and saved ammunition.
var _secondary_kind:=5
var _secondary_item:=-1
var _secondary_slot:=-1

func verify_free_application() -> void:
	_secondary_kind=4 if OS.get_environment("GOF2_CONVENTIONAL_KIND")=="4" else 5
	var original: Dictionary=app.session.station_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_CONVENTIONAL_RESUMED")=="1"
	var price:=0
	if not resumed:
		var purchase: Dictionary=await buy_secondary()
		if purchase.is_empty():return
		_secondary_item=purchase.item_id;price=purchase.price
	else:
		var installed: Array=original.loadout.slots.filter(func(slot):return slot!=null and slot.category==1 and catalogue.tables.items[slot.item_id].arrays[2][5]==_secondary_kind)
		if installed.size()!=1:check(false,"Fresh Resume lost its purchased conventional launcher");return
		_secondary_item=int(installed[0].item_id)
	var fitted: Dictionary=app.session.station_owner().snapshot()
	for index in fitted.loadout.slots.size():
		if fitted.loadout.slots[index]!=null and fitted.loadout.slots[index].item_id==_secondary_item:_secondary_slot=index;break
	if _secondary_slot<0:check(false,"The paid launcher has no installed secondary slot");return
	check(fitted.loadout.equipment_ids.has(81) and fitted.contracts.passengers==3 and fitted.contracts.mission==original.contracts.mission,"Secondary fitting lost the scanner or earned passenger job")
	if failures or not retain_recovery_save("fitted"):return
	var quantity:=int(fitted.loadout.slots[_secondary_slot].quantity)
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	if not await release_application_flight():return
	check(app.session.secondary_available() and app.session.snapshot().encounter.selected_secondary==-1,"Equipped departure lost its launcher or invented a selection")
	if not app.open_secondary_menu(now_us) or not app.session.confirm_secondary(_secondary_item,now_us):check(false,app.session.error);return
	app.present_session();resume_application_focus()
	if not await fire_secondary_input():return
	var spent: Dictionary=app.session.snapshot().encounter.secondaries
	var remaining:=int(spent.guns[0].ammunition)
	check(remaining==quantity-spent.launches and spent.launches>0,"Actual input spent ammunition without a successful launch")
	if failures or not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	var expected: Dictionary=fitted.loadout.duplicate(true)
	if remaining==0:expected.slots[_secondary_slot]=null;expected.equipment_ids.erase(_secondary_item)
	else:expected.slots[_secondary_slot].quantity=remaining
	check(landed.loadout==expected and landed.cargo==fitted.cargo and landed.contracts.credits==fitted.contracts.credits,"Docking restored spent ammunition or changed unrelated equipment, cargo or credits")
	check(landed.contracts.passengers==3 and landed.contracts.mission==original.contracts.mission and landed.campaign_cursor==45,"Secondary flight changed the earned campaign or passenger job")
	if not retain_recovery_save("returned"):return
	var save: Dictionary=app._save_file.load_document(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY").path_join("returned.gof2save"),definitions,catalogue,source)
	check(not save.is_empty(),"The actual returned ammunition save could not be reopened")
	await capture_free_application("secondary-saved-station")
	print("Conventional saved: ",{"item":_secondary_item,"kind":_secondary_kind,"price":price,"bought":quantity,"launched":spent.launches,"remaining":remaining,"credits":landed.contracts.credits,"cursor":landed.campaign_cursor,"passengers":landed.contracts.passengers})

func buy_secondary() -> Dictionary:
	for destination in [-1,36,38,39]:
		if destination>=0:
			if app.session.station_owner().snapshot().loadout.station_id==destination:continue
			if not await visit_delivery_station(destination):return {}
		if not app.equipment_action("open"):check(false,app.session.error);return {}
		var quote: Dictionary=app.session.station_owner().snapshot()
		var available: Array=quote.equipment.market_rows.filter(func(row):return catalogue.tables.items[row.item_id].arrays[2][3]==1 and catalogue.tables.items[row.item_id].arrays[2][5]==_secondary_kind)
		print("Actual secondary shop: ",{"station":quote.loadout.station_id,"kind":_secondary_kind,"stock":available.map(func(row):return {"item":row.item_id,"price":row.unit_price,"stock":row.stock}),"credits":quote.contracts.credits})
		var offers: Array=available.filter(func(row):return row.stock>=3 and row.unit_price*3<=quote.contracts.credits and quote.equipment.fitting_support[row.item_id].is_empty())
		offers.sort_custom(func(a,b):return a.unit_price<b.unit_price)
		if offers.is_empty():
			if not app.equipment_action("close"):check(false,app.session.error);return {}
			continue
		var offer: Dictionary=offers[0];var item:=int(offer.item_id);var quantity:=3
		app.equipment_panel.select_tab("shop")
		for unit in quantity:app.equipment_panel._rows[item].actions.buy.pressed.emit()
		var bought: Dictionary=app.session.station_owner().snapshot()
		check(bought.contracts.credits==quote.contracts.credits-quantity*offer.unit_price and not bought.loadout.equipment_ids.has(item),"Secondary purchase lost its quoted price or silently installed cargo")
		app.equipment_panel.select_tab("cargo");app.equipment_panel._rows[item].actions.mount.pressed.emit()
		var fitted: Dictionary=app.session.station_owner().snapshot()
		check(fitted.loadout.equipment_ids.has(item) and fitted.cargo==quote.cargo,"Mount button did not move the purchased ammunition stack into the ship")
		app.equipment_panel.select_tab("ship")
		await capture_free_application("secondary-purchased-fitted")
		if failures or not app.equipment_action("close"):return {}
		return {"item_id":item,"price":quantity*int(offer.unit_price)}
	check(false,"The earned local shops offered no affordable conventional launcher stack");return {}

func fire_secondary_input() -> bool:
	var initial: Dictionary=app.session.snapshot()
	var candidates: Array=initial.encounter.combat.actors.filter(func(actor):return actor.active and actor.population_group=="freighter" and actor.vitals.hull>0)
	candidates.sort_custom(func(a,b):return a.pose.origin.distance_squared_to(initial.player_pose.origin)<b.pose.origin.distance_squared_to(initial.player_pose.origin))
	if candidates.is_empty():check(false,"The generated flight has no living target");return false
	var id:=int(candidates[0].actor_id);var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var captured:=false;var guided:=false;var first_shot_us:=-1;var launches:=0;var hit:=false
	var previous_position: Vector3=candidates[0].pose.origin;var previous_us:=now_us
	while now_us-started<240000000:
		var state: Dictionary=app.session.snapshot();var actor: Dictionary=state.encounter.combat.actors[id]
		if app.session.flight_owner().death_active():check(false,"The secondary pilot died before contact");return false
		var distance: float=actor.pose.origin.distance_to(state.player_pose.origin)
		var acquired: bool=state.npc_scanner.selected_actor_id==id
		var input:={"commands":PiratePilot.Steering.steering_toward(state.player_pose,actor.pose.origin),"throttle":1.0 if distance>16000.0 else 0.0,"fire":false,"strafe":0.0}
		var markers: Array=state.npc_scanner.markers.filter(func(marker):return marker.actor_id==id and marker.in_view)
		var offset:=Vector2(INF,INF)
		if not markers.is_empty():
			offset=Vector2(markers[0].pixels-state.npc_scanner.aim_pixels)
			input.commands=Vector2(clampf(offset.y/300.0,-1.0,1.0),clampf(-offset.x/300.0,-1.0,1.0))
		var key: InputEventKey
		var shots: Dictionary=state.encounter.secondaries.guns[0].projectiles
		var aimed: bool=offset.length()<120.0
		if _secondary_kind==4:
			var lead: Vector3=actor.pose.origin
			if now_us>previous_us:lead+=(actor.pose.origin-previous_position)/float(now_us-previous_us)*1000.0*distance/float(shots.weapon.speed_units_per_millisecond)
			input.commands=PiratePilot.Steering.steering_toward(state.player_pose,lead)
			aimed=state.player_pose.basis.z.angle_to(lead-state.player_pose.origin)<0.035
		previous_position=actor.pose.origin;previous_us=now_us
		if not hit and acquired and distance<16500.0 and aimed and shots.slots.all(func(slot):return slot==null) and state.encounter.secondaries.guns[0].ammunition>0 and shots.time_ready:
			resume_application_focus();key=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true;app._unhandled_input(key)
			check(app.session._secondary_requested,"R did not queue the selected equipped launcher")
			print("Conventional launch input: ",{"distance":distance,"offset":offset,"speed":shots.weapon.speed_units_per_millisecond,"lifetime":shots.weapon.lifetime_ms})
		if not pirate_step(input):return false
		if key!=null:key.pressed=false;app._unhandled_input(key)
		var after: Dictionary=app.session.snapshot();var current: Dictionary=after.encounter.secondaries.guns[0].projectiles
		for index in current.slots.size():
			var shot: Variant=current.slots[index];var old: Variant=shots.slots[index]
			if shot==null:continue
			if first_shot_us<0:first_shot_us=now_us
			if old!=null and old.id==shot.id and not old.velocity.is_equal_approx(shot.velocity) and acquired:guided=true
		launches=int(after.encounter.secondaries.launches)
		if not captured and first_shot_us>=0 and now_us-first_shot_us>=250000:
			check(current.trails.any(func(trail):return not trail.is_empty() and trail.sections.size()>1),"Launched secondary has no retained exhaust ribbon")
			await capture_free_application("secondary-live-exhaust")
			var paused: Dictionary=after.encounter.secondaries.duplicate(true)
			check(app.session.set_pause("user",true,now_us),app.session.error);now_us+=1000000
			check(app.session.step(now_us) and app.session.snapshot().encounter.secondaries==paused,"Pause moved missiles, exhaust or attached animation")
			check(app.session.set_pause("user",false,now_us),app.session.error)
			captured=true
		var impacts: Array=after.encounter.secondary_events.filter(func(event):return event.action=="impact" and event.get("target",{}).get("group")=="npc" and event.target.index==id)
		if not impacts.is_empty():
			hit=true
			var damaged: Dictionary=after.encounter.combat.actors[id]
			check(damaged.vitals!=candidates[0].vitals,"Conventional contact failed to damage the real target")
			var burst: Dictionary=after.damage_particles.owners.world.burst
			check(burst.slots.any(func(slot):return slot.appearance.age_ms>=0),"Conventional impact did not emit the original world explosion")
			var sound:=int(definitions.weapon_parameters.audio.player_event_ids[_secondary_item])
			check(app.session.flight_audio.snapshot().history.any(func(event):return event.get("source_id")==sound and event.get("item_id")==_secondary_item),"Conventional launch omitted its original sound")
			await capture_free_application("secondary-original-impact")
			print("Conventional hit: ",{"item":_secondary_item,"target":id,"before":candidates[0].vitals,"after":damaged.vitals,"launches":launches,"guided":guided,"elapsed":(now_us-started)/1000000.0})
		if hit and captured:
			check(guided if _secondary_kind==5 else not guided,"Missile guidance or straight rocket flight did not match the installed family")
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("Conventional pilot: ",{"elapsed":(now_us-started)/1000000.0,"target":id,"distance":distance,"acquired":acquired,"launches":launches,"guided":guided,"hit":hit})
			next_log=now_us+10000000
	check(false,"Input-fired conventional launcher did not hit its generated target");return false
