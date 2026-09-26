extends "res://tests/void_crystal_route_application.gd"
## Earn crystals through real portal contact, asteroid acquisition and drilling.
## No fixture placement, cursor edits, hostile removal or cargo injection.

func verify_free_application() -> void:
	var saved:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(saved)
	var original: Dictionary=app.session.station_owner().snapshot()
	check(not input_hash.is_empty() and original.campaign_cursor==33 and original.contracts.has("void_source"),"Resume the earned crystal mission at its actual source station")
	if failures:return
	check(original.loadout.station_id==original.contracts.void_source.source_station_id and original.cargo.capacity==50 and original.cargo.used==0 and original.loadout.equipment_ids.has(86),"The actual source departure lost its empty paid50t mining fit")
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Set a private crystal mining save directory")
	if failures:return
	app.enable_saves(chapter_directory)
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.show();app.present_session();await process_frame;resume_application_focus()
	var stock: Array=app.session.station_owner().contract_owner().location_owner().item_stock(int(original.loadout.station_id))
	var ammunition:=-1
	var launcher: Variant=original.loadout.slots[1]
	# Refill the already paid launcher when possible. A different local EMP
	# offer cannot occupy that slot, and buying it needlessly fills the hold.
	if launcher!=null and launcher.item_id in [43,42,41] and launcher.quantity>0:
		ammunition=int(launcher.item_id)
	else:
		for candidate in [43,42,41]:
			if stock.any(func(row):return row.item_id==candidate and row.quantity>0 and row.unit_price>0 and row.unit_price<=original.contracts.credits):ammunition=candidate;break
	check(ammunition>=0,"The actual Void-source station has neither retained nor affordable defensive ammunition")
	if failures or not purchase_route_emp(12,false,ammunition):return
	var prepared: Dictionary=app.session.station_owner().snapshot()
	var fitted_launcher: Variant=prepared.loadout.slots[1]
	check(fitted_launcher!=null and fitted_launcher.item_id==ammunition and fitted_launcher.quantity>0,"Mining defence lost its retained or newly purchased EMP rounds")
	print("Earned mining defence: ",fitted_launcher,"; wallet ",prepared.contracts.credits)
	check(prepared.cargo==original.cargo and prepared.loadout.equipment_ids.has(86) and prepared.loadout.equipment_ids.has(64) and prepared.contracts.void_source==original.contracts.void_source and prepared.contracts.blueprints==original.contracts.blueprints,"Paid mining defence changed the empty50t fit or retained source/blueprints")
	if failures or not retain_chapter_save("crystal33-mining-prepared"):return
	if OS.get_environment("GOF2_CRYSTAL_PREPARATION_ONLY")=="1":
		print("Earned mining defence preparation and save/reload only; portal travel and drilling not exercised")
		return
	if not await depart_crystal_route() or not select_paid_emp() or not await fly_void_portal():return
	if not accept_crystal_portal(true):return
	if not await release_application_flight():return
	if app.session.snapshot().encounter.has("secondaries") and not select_paid_emp():return
	await capture_free_application("earned-crystal33-void-entry")
	# Defeat the generated fighters through the existing real-input combat pilot;
	# mining autopilot alone cannot defend this unarmoured cargo/drill fit.
	if not await clear_route_attackers("Void crystal field"):return
	for attempt in 12:
		var state: Dictionary=app.session.snapshot()
		if state.cargo.free_space==0:break
		var asteroid:={}
		for body in state.scenery.bodies.objects:
			if body.get("mined",false) or body.item_id!=164 or body.source_size_value!=6 or body.vitals.hull<=0:continue
			# Prefer the early source rows: the original scanner admits only its
			# first four in-window candidates, not every visible asteroid.
			asteroid=body;break
		if asteroid.is_empty():check(false,"The actual Void field has no remaining non-core six-layer asteroid");return
		if not await acquire_crystal_asteroid(asteroid):return
		if not await drill_crystal_asteroid(state.cargo.used):return
	var mined: Dictionary=app.session.snapshot()
	var rows: Array=mined.cargo.entries.filter(func(row):return row.item_id==164)
	check(rows.size()==1 and rows[0].quantity==50 and mined.cargo.used==50,"Actual drilling did not earn the single50-crystal row required by Thynome")
	check(mined.campaign_cursor==33 and mined.mission==original.mission and mined.contracts.blueprints==original.contracts.blueprints and mined.contracts.credits==route_credits,"Mining granted premature campaign progress, money or a drive")
	if failures:return
	await capture_free_application("earned-crystal33-full-hold")
	if not await fly_void_portal() or not accept_crystal_portal(false) or not await release_application_flight():return
	if not await dock_with_paid_emp(2147483647):return
	var landed: Dictionary=app.session.station_owner().snapshot()
	check(landed.campaign_cursor==33 and landed.loadout.station_id==original.loadout.station_id and landed.cargo.entries==mined.cargo.entries and landed.contracts.void_source==original.contracts.void_source,"The actual return lost mined crystals, source or pending hand-in")
	check(landed.contracts.credits==route_credits and landed.contracts.mission==retained_job and landed.contracts.passengers==original.contracts.passengers and landed.contracts.blueprints==original.contracts.blueprints,"The actual crystal roundtrip changed its unrelated career")
	check(FileAccess.get_sha256(saved)==input_hash,"Crystal mining overwrote the immutable earned source input")
	if failures or not retain_chapter_save("crystal33-source-mined50"):return
	await capture_free_application("earned-crystal33-source-mined50")
	print("Earned50 Void crystals through real approach, drilling and portal return; Thynome hand-in remains pending")

func accept_crystal_portal(entering: bool) -> bool:
	var before: Dictionary=app.session.snapshot()
	if not app.enter_portal_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	var after: Dictionary=app.session.snapshot()
	var pools: Dictionary=before.player.vitals.duplicate()
	pools.shield=float(int(pools.shield))
	check(after.campaign_cursor==33 and after.player.vitals==pools and after.cargo.entries==before.cargo.entries,"The actual crystal portal changed surviving pools or cargo")
	check(after.location.station_id==(-1 if entering else before.contracts.void_source.source_station_id) and after.contracts.void_source==before.contracts.void_source,"The actual crystal portal lost its retained source destination")
	check(after.contracts.credits==before.contracts.credits and after.contracts.mission==retained_job and after.contracts.blueprints==before.contracts.blueprints,"The actual portal changed the retained career")
	return failures==0

func acquire_crystal_asteroid(asteroid: Dictionary) -> bool:
	var started:=false
	for tick in 3000:
		var state: Dictionary=app.session.snapshot()
		var selected: int=int(state.mining_targeting.selected_object_index)
		if selected>=0:
			var acquired: Dictionary=state.scenery.bodies.objects[selected]
			if acquired.item_id==164 and acquired.source_size_value==6 and not acquired.get("mined",false) and acquired.vitals.hull>0:
				# Guidance retains the throttle at request time. Restore thrust
				# through player input before handing control to mining autopilot.
				if state.input_throttle<.99:
					var heading: Vector2=preload("res://tests/fixtures/expedition_flight_pilot.gd").steering_toward(state.player_pose,acquired.position)
					# Input is queued by the session; commit one real flight frame
					# so the approach receives the restored, not preceding, throttle.
					if advance_story(app.session.flight_owner(),100,heading,1.0)==null:return false
					continue
				if not app.session.action("dock"):check(false,app.session.error);return false
				var request: Dictionary=app.session.snapshot().mining_approach
				check(request.phase=="approach" and request.object_index==selected and is_equal_approx(float(request.throttle),1.0),"The actual mining action did not start the selected asteroid with restored thrust")
				if failures:return false
				print("Earned crystal mining request for acquired asteroid ",selected)
				started=true;break
		var distance: float=state.player_pose.origin.distance_to(asteroid.position)
		var command: Vector2=preload("res://tests/fixtures/expedition_flight_pilot.gd").steering_toward(state.player_pose,asteroid.position)
		# Hold aim while the actual eight-second scanner acquires its target,
		# instead of overshooting into a full-throttle orbit around the asteroid.
		if advance_story(app.session.flight_owner(),100,command,0.0 if distance<20000.0 else 1.0)==null:return false
		if tick%100==0:
			var targeting: Dictionary=state.mining_targeting
			var markers: Array=targeting.markers.filter(func(row):return row.object_index==asteroid.index)
			print("Earned crystal asteroid ",asteroid.index," approach ",tick," distance ",int(distance)," candidate ",targeting.candidate_object_index," elapsed ",targeting.elapsed_ms," marker ",markers," aim ",targeting.aim_pixels)
		if tick%20==0:await process_frame
	if not started:check(false,"The real pilot did not acquire the chosen crystal asteroid");return false
	for tick in 1500:
		var state: Dictionary=app.session.snapshot()
		if not state.mining_session.drill.is_empty():
			await capture_free_application("earned-crystal33-drilling-"+str(state.mining_approach.object_index))
			return true
		if advance_story(app.session.flight_owner(),100,Vector2.ZERO,1)==null:return false
		if tick%200==0:print("Earned mining guidance ",tick," target ",state.mining_approach.object_index," phase ",state.mining_approach.phase," throttle ",state.mining_approach.throttle)
		if tick%20==0:await process_frame
	check(false,"The actual crystal mining approach never reached drilling");return false

func drill_crystal_asteroid(before_used: int) -> bool:
	for tick in 1000:
		var drill: Dictionary=app.session.snapshot().mining_session.drill
		if drill.is_empty():break
		var desired: Vector2=-(drill.point-drill.center+(drill.input+drill.drift)*5.0)*.2-drill.drift
		var command:=Vector2.ZERO
		for axis in 2:command[axis]=signf(desired[axis])*sqrt(minf(1,absf(desired[axis])/3.0))
		if advance_story(app.session.flight_owner(),100,command,0)==null:return false
		if tick%20==0:await process_frame
	var mined: Dictionary=app.session.snapshot()
	var receipt: Dictionary=mined.mining_session.extraction
	check(not receipt.is_empty() and receipt.ore_item_id==164 and receipt.ore_tons>0 and receipt.core_item_id==-1 and mined.cargo.used==before_used+receipt.cargo_added,"The actual drill failed to retain its crystal-only receipt")
	print("Earned crystal drill receipt ",receipt," hold ",mined.cargo.used)
	return failures==0

func advance_story(frame: RefCounted,milliseconds: int,commands: Vector2,throttle: float,fire:=false) -> RefCounted:
	var state: Dictionary=app.session.snapshot()
	if app.session.can_control() and state.mining_session.drill.is_empty() and not try_paid_emp(state,2147483647,1000.0,"crystal expedition",false):return null
	return super.advance_story(frame,milliseconds,commands,throttle,fire)
