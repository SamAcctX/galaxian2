extends "res://tests/wingman_command_application.gd"
## New behavior-order coverage. The live application earns its scanner target
## through steering; detached adversarial components never enter its career.
var ordered_target:=-1
var pursued_frames:=0
var scanner_visits:=[]

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"));app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var entry: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==entry.contracts.wingmen and not entry.contracts.wingmen.active.is_empty(),"Resume lost the paid crew")
	if failures or not await prepare_order_scanner():return
	entry=app.session.station_owner().snapshot()
	if failures or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
	var initial: Dictionary=app.session.flight_owner().snapshot()
	var resumed:=OS.get_environment("GOF2_WINGMEN_ORDER_STAGE")=="resume"
	if not resumed:
		verify_order_components(app.session.flight_owner().wingman_owner(),initial)
		check(app.session.flight_owner().snapshot()==initial,"Detached order checks changed the earned flight")
	if failures or not await release_application_flight():return
	var before: Dictionary=app.session.snapshot().wingman_actors
	check(before.actors.all(func(actor):return actor.wingman_command==1 and actor.wingman_target_actor_id== -1),"Departure retained another world's command target")
	command_key(KEY_V)
	check(app.flight_menu.visible and app.session.is_paused(),"V did not open wingman orders")
	var rows: Array=app.flight_menu.snapshot().rows
	check(rows.map(func(row):return row.label)==[app.library.strings[296],app.library.strings[297],app.library.strings[298],app.library.strings[300]],"Order menu labels changed")
	check(not rows[0].get("disabled",false) and not rows[1].get("disabled",false) and rows[2].disabled,"Supported behavior orders are disabled or waypoint is falsely enabled")
	command_key(KEY_3)
	check(app.flight_menu.visible and app.session.snapshot().wingman_actors==before,"Disabled waypoint changed the cast")
	await capture_free_application("wingman-orders-menu")
	resume_application_focus();command_key(KEY_V);app.session.rebase_time(now_us)
	check(not app.flight_menu.visible and app.session.snapshot().wingman_actors==before,"Cancel mutated the order")
	if failures:return
	if not await acquire_order_target():return
	var parent: RefCounted=app.session.flight_owner()
	var prior: Dictionary=parent.snapshot().wingman_actors
	ordered_target=int(app.session.snapshot().npc_scanner.selected_actor_id)
	command_key(KEY_E)
	var index: int=app.flight_menu.snapshot().rows.map(func(row):return row.action).find("wingmen")
	check(index>=0,"The action menu lost the wingman entry")
	if failures:return
	command_key(KEY_1+index);command_key(KEY_2);app.session.rebase_time(now_us)
	var commanded: Dictionary=app.session.snapshot().wingman_actors
	check(not app.flight_menu.visible and commanded.actors.all(func(actor):return actor.wingman_command==3 and actor.wingman_target_actor_id==ordered_target),"Attack my target ignored the native acquired ship")
	check(parent.snapshot().wingman_actors==prior,"The order mutated the retained parent")
	for key in ["following","weapon_world","systems_weapon_world","weapon_groups"]:check(commanded[key]==prior[key],"Issuing the order prematurely advanced "+key)
	if failures:return
	for tick in (30 if resumed else 50):
		var state: Dictionary=app.session.snapshot()
		if not pirate_step({"commands":PiratePilot.Steering.steering_toward(state.player_pose,state.wingman_actors.actors[0].pose.origin),"throttle":0.0,"fire":false,"strafe":0.0}):return
		var cast: Dictionary=app.session.snapshot().wingman_actors
		if cast.targeting.selections[0].target_actor_id==ordered_target:pursued_frames+=1
	check(pursued_frames>0,"The real companion never pursued the commanded ship")
	await capture_free_application("wingman-orders-pursuit")
	resume_application_focus()
	command_key(KEY_V)
	var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=true;app._unhandled_input(pad)
	app.session.rebase_time(now_us)
	check(not app.flight_menu.visible and app.session.snapshot().wingman_actors.actors.all(func(actor):return actor.wingman_command==1 and actor.wingman_target_actor_id== -1),"Controller Fire at will did not clear the explicit order")
	var paused: Dictionary=app.session.snapshot().wingman_actors
	check(app.session.set_pause("user",true,now_us),app.session.error)
	command_key(KEY_V)
	check(not app.flight_menu.visible,"User pause admitted an order menu")
	for tick in 3:
		if not application_step():return
	check(app.session.snapshot().wingman_actors==paused,"Pause advanced the commanded cast")
	check(app.session.set_pause("user",false,now_us),app.session.error)
	if failures:return
	var airborne: Dictionary=app.session.snapshot()
	if airborne.encounter.combat.actors.any(func(row):return row.active and row.hostile and row.vitals.hull>0):
		var stations:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==airborne.location.system_id:stations.append(id)
		if not await travel_application(stations[(stations.find(airborne.location.station_id)+1)%stations.size()]):return
	if not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	for key in ["mission","passengers","blueprints"]:check(returned.contracts[key]==entry.contracts[key],"Orders changed unrelated career field "+key)
	check(returned.cargo==entry.cargo and returned.loadout.equipment_ids==entry.loadout.equipment_ids and returned.campaign_cursor==entry.campaign_cursor,"Orders changed cargo, fitting or campaign")
	check(returned.contracts.credits>=entry.contracts.credits and returned.contracts.wingmen.hired_total==entry.contracts.wingmen.hired_total,"Orders changed payment or hire count")
	check(returned.contracts.wingmen.active.names==entry.contracts.wingmen.active.names and returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"The real paid lifetime or roster was not preserved")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen,"Order autosave lost the retained career")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"Order testing edited the earned input")
	await capture_free_application("wingman-orders-returned")
	print("Earned wingman orders: ",{"resumed":resumed,"input_sha256":input_hash,"ordered_target":ordered_target,"pursued_frames":pursued_frames,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"credits":returned.contracts.credits,"timing":_pilot_deltas,"full_combat_accepted":false})

func prepare_order_scanner() -> bool:
	var original: Dictionary=app.session.station_owner().snapshot()
	if original.loadout.equipment_ids.any(func(id):return catalogue.tables.items[id].properties.get(2)==17):return true
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	scanner_visits.append(int(before.loadout.station_id))
	var offers: Array=before.equipment.market_rows.filter(func(row):return row.stock>0 and row.unit_price<=before.contracts.credits and catalogue.tables.items[row.item_id].properties.get(2)==17)
	offers.sort_custom(func(a,b):return a.unit_price<b.unit_price)
	if offers.is_empty():
		var candidates:=[]
		for id in catalogue.tables.stations.size():
			if catalogue.tables.stations[id].system_id==before.loadout.system_id and id not in scanner_visits:candidates.append(id)
		var tech_field:=int(definitions.early_contracts.station_generation.catalogue.station_tech_field)
		candidates.sort_custom(func(a,b):return int(catalogue.tables.stations[a].fields[tech_field])>int(catalogue.tables.stations[b].fields[tech_field]))
		check(not candidates.is_empty() and before.contracts.wingmen.active.remaining_ms>=70000,"Nearby scanner shopping exhausted its bounded paid-flight allowance")
		if failures:return false
		var destination:=int(candidates[0])
		print("Earned scanner shopping leg: ",{"from":before.loadout.station_id,"to":destination,"tech":catalogue.tables.stations[destination].fields[tech_field],"remaining_ms":before.contracts.wingmen.active.remaining_ms})
		if not app.equipment_action("close") or not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
		if not await release_application_flight() or not await travel_application(destination) or not await dock_application():return false
		return await prepare_order_scanner()
	var item:=int(offers[0].item_id);var price:=int(offers[0].unit_price)
	# Keep the occupied passenger cabin and shield. Store, never sell, the armor
	# to free one genuine equipment slot for this newly purchased scanner.
	if not app.equipment_action("buy",item) or not app.equipment_action("unmount",57) or not app.equipment_action("mount",item):check(false,app.session.error);return false
	var fitted: Dictionary=app.session.station_owner().snapshot()
	check(fitted.contracts.credits==original.contracts.credits-price and fitted.loadout.equipment_ids.has(item),"Scanner preparation did not use the quoted native transaction")
	check(fitted.contracts.wingmen==original.contracts.wingmen and fitted.contracts.passengers==original.contracts.passengers and fitted.contracts.mission==original.contracts.mission,"Scanner preparation changed paid time or the earned job")
	check(fitted.cargo.entries.any(func(row):return row.item_id==57 and row.quantity==1),"Scanner fitting discarded the owned armor")
	print("Earned scanner preparation: ",{"item_id":item,"price":price,"credits":fitted.contracts.credits,"stored_armor":57,"remaining_ms":fitted.contracts.wingmen.active.remaining_ms})
	await capture_free_application("wingman-orders-scanner-fitted")
	if not app.equipment_action("close"):check(false,app.session.error);return false
	return failures==0

func acquire_order_target() -> bool:
	var started:=now_us;var next_yield:=now_us
	while now_us-started<45000000:
		var state: Dictionary=app.session.snapshot()
		if state.npc_scanner.equipment_id<0:check(false,"Order acquisition requires an actually fitted scanner");return false
		if state.npc_scanner.selected_actor_id>=0:
			print("Earned scanner target: ",{"actor_id":state.npc_scanner.selected_actor_id,"seconds":(now_us-started)/1000000.0})
			return true
		var targets: Array=state.encounter.combat.actors.filter(func(actor):return actor.active and actor.vitals.hull>0 and not actor.get("contract_debris",false))
		if targets.is_empty():check(false,"No native ship to acquire");return false
		var target: Dictionary=targets[0]
		var distance: float=state.player_pose.origin.distance_to(target.pose.origin)
		if not pirate_step({"commands":PiratePilot.Steering.steering_toward(state.player_pose,target.pose.origin),"throttle":1.0 if distance>10000.0 else 0.0,"fire":false,"strafe":0.0}):return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+500000
	check(false,"Bounded steering did not acquire a real scanner target")
	await capture_free_application("wingman-orders-no-target")
	return false

func verify_order_components(crew: RefCounted,initial: Dictionary) -> void:
	var original: Dictionary=crew.snapshot();var sibling: RefCounted=crew.fork_for_frame()
	var peaceful: Dictionary=original.actors[0].duplicate(true)
	peaceful.actor_id=11;peaceful.hostile=false;peaceful.pose.origin+=peaceful.pose.basis.z*4000.0
	var hostile: Dictionary=peaceful.duplicate(true);hostile.actor_id=7;hostile.hostile=true
	var candidate: RefCounted=crew.fork_for_frame()
	check(candidate.issue_order(3,11),candidate.error)
	var ordered: Dictionary=candidate.snapshot()
	for key in ["following","weapon_world","systems_weapon_world","weapon_groups"]:check(ordered[key]==original[key],"Detached order prematurely advanced "+key)
	check(candidate.toggle_weapon_group(0) and candidate.snapshot().actors[0].wingman_command==3,"Gun selection cancelled an explicit order")
	var random:=CrewActors.Random.new();check(random.seed_from(17),random.error)
	var next: Dictionary=candidate.advance_targeting(1,initial.player_pose,initial.player,[hostile,peaceful],random.snapshot())
	check(not next.is_empty(),candidate.error)
	if failures:return
	check(candidate.snapshot().targeting.selections[0].target_actor_id==11,"Explicit peaceful target was replaced by the first hostile")
	check(candidate.issue_order(1),candidate.error)
	check(not candidate.advance_targeting(1,initial.player_pose,initial.player,[hostile,peaceful],next.random_state).is_empty(),candidate.error)
	check(candidate.snapshot().targeting.selections[0].target_actor_id==7,"Fire at will did not restore hostile selection")
	check(candidate.issue_order(3,11),candidate.error)
	var dying: Dictionary=peaceful.duplicate(true);dying.actor_mode=3;dying.vitals.hull=0
	check(not candidate.advance_targeting(1,initial.player_pose,initial.player,[hostile,dying],next.random_state).is_empty(),candidate.error)
	check(candidate.snapshot().actors[0].wingman_command==3,"A dying target reset its command before source retirement")
	check(candidate.issue_order(3,11),candidate.error)
	var retired: Dictionary=dying.duplicate(true);retired.active=false;retired.actor_mode=4
	check(not candidate.advance_targeting(1,initial.player_pose,initial.player,[hostile,retired],next.random_state).is_empty(),candidate.error)
	check(candidate.snapshot().actors[0].wingman_command==1 and candidate.snapshot().targeting.selections[0].target_actor_id==7,"Retired explicit target did not restore autonomous pursuit")
	var far: Dictionary=peaceful.duplicate(true);far.pose.origin+=Vector3.ONE*float(peaceful.spatial_half_extent)*4.0
	var ranged: RefCounted=crew.fork_for_frame();check(ranged.issue_order(3,11),ranged.error)
	check(not ranged.advance_targeting(1,initial.player_pose,initial.player,[hostile,far],random.snapshot()).is_empty(),ranged.error)
	check(ranged.snapshot().targeting.selections[0].target_actor_id== -1,"Explicit orders bypassed the ordinary range gate")
	var no_target: RefCounted=crew.fork_for_frame();check(no_target.issue_order(3),no_target.error)
	check(no_target.snapshot().actors[0].wingman_command==1,"A missing player target invented an attack order")
	var guarded: Dictionary=candidate.snapshot()
	check(not candidate.issue_order(2) and not candidate.issue_order(3,"11") and not candidate.issue_order(3,-2),"Malformed or unsupported behavior order was accepted")
	check(candidate.snapshot()==guarded,"Rejected orders leaked partial state")
	check(crew.snapshot()==original and sibling.snapshot()==original,"Order/target updates mutated a retained parent or sibling")
	for delta in [7,17,100]:
		var cadence: RefCounted=crew.fork_for_frame();check(cadence.issue_order(3,11),cadence.error)
		check(not cadence.advance_targeting(delta,initial.player_pose,initial.player,[hostile,peaceful],random.snapshot()).is_empty(),cadence.error)
		check(cadence.snapshot().targeting.selections[0].target_actor_id==11,"Command acquisition failed at a supported frame duration")
