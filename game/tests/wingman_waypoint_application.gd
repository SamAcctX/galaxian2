extends "res://tests/wingman_orders_application.gd"
## New waypoint coverage, with genuine paid preparation. Synthetic route
## boundaries are detached candidates and never replace the live application.
var rehire_price:=0
var route_frames:=0

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	app.enable_saves(OS.get_environment("GOF2_SAVE_TEST_DIRECTORY"));app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	if app.session.station_owner().snapshot().get("hangar_open",false) and not app.equipment_action("close"):check(false,app.session.error);return
	var original: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==original.contracts.wingmen,"Fresh Resume changed the earned crew")
	var resumed:=OS.get_environment("GOF2_WINGMEN_WAYPOINT_STAGE")=="resume"
	if failures:return
	if not resumed and OS.get_environment("GOF2_WINGMEN_WAYPOINT_STAGE")!="prepared" and not await prepare_paid_waypoint_flight():return
	var entry: Dictionary=app.session.station_owner().snapshot()
	check(not entry.contracts.wingmen.active.is_empty() and entry.contracts.wingmen.active.remaining_ms>60000,"No genuine paid time remains for waypoint acceptance")
	if failures or not await depart_for_lifetime():return
	var initial: Dictionary=app.session.flight_owner().snapshot()
	if not resumed:
		verify_waypoint_components(app.session.flight_owner().wingman_owner(),initial)
		check(app.session.flight_owner().snapshot()==initial,"Detached waypoint checks changed the earned flight")
	if resumed:
		verify_waypoint_journey_components(app.session.flight_owner(),initial)
		check(app.session.flight_owner().snapshot()==initial,"Detached route journey changed the earned application")
	if failures:return
	var parent: RefCounted=app.session.flight_owner()
	var before: Dictionary=parent.snapshot()
	command_key(KEY_E)
	var index: int=app.flight_menu.snapshot().rows.map(func(row):return row.action).find("wingmen")
	check(index>=0,"E lost the wingman menu")
	if failures:return
	command_key(KEY_1+index)
	var rows: Array=app.flight_menu.snapshot().rows
	check(rows[2].action=="wingman_secure_waypoint" and not rows[2].get("disabled",false) and rows[2].label==app.library.strings[298],"The original waypoint command is unavailable")
	await capture_free_application("wingman-waypoint-menu")
	resume_application_focus();command_key(KEY_3);app.session.rebase_time(now_us)
	check(not app.flight_menu.visible and parent.snapshot()==before,"Waypoint input left the menu open or mutated its parent")
	var commanded: Dictionary=app.session.snapshot().wingman_actors
	for key in ["following","weapon_world","systems_weapon_world","weapon_groups"]:check(commanded[key]==before.wingman_actors[key],"Waypoint input advanced "+key)
	var has_route: bool=not before.get("world_path",[]).is_empty() or not before.get("player_route",{}).is_empty()
	check(commanded.actors.all(func(actor):return actor.wingman_command==(2 if has_route else 1)),"A missing world route invented a destination, or an existing route was ignored")
	for tick in 40:
		var state: Dictionary=app.session.snapshot()
		if not pirate_step({"commands":PiratePilot.Steering.steering_toward(state.player_pose,state.wingman_actors.actors[0].pose.origin),"throttle":0.0,"fire":false,"strafe":0.0}):return
		if app.session.snapshot().wingman_actors.actors[0].wingman_command==2:route_frames+=1
	await capture_free_application("wingman-waypoint-flight")
	resume_application_focus();command_key(KEY_V)
	var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_DPAD_DOWN;pad.pressed=true
	app._unhandled_input(pad);app._unhandled_input(pad)
	pad=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=true;app._unhandled_input(pad)
	app.session.rebase_time(now_us)
	check(not app.flight_menu.visible,"Controller did not accept Secure next waypoint")
	if failures or not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	for key in ["mission","passengers","blueprints"]:check(returned.contracts[key]==original.contracts[key],"Waypoint work changed unrelated "+key)
	check(returned.cargo==original.cargo and returned.loadout.equipment_ids==original.loadout.equipment_ids and returned.campaign_cursor==original.campaign_cursor,"Waypoint work changed the cargo, fitting or campaign")
	check(returned.contracts.credits==original.contracts.credits-rehire_price,"The paid preparation wallet does not reconcile")
	check(returned.contracts.wingmen.active.names==entry.contracts.wingmen.active.names and returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<entry.contracts.wingmen.active.remaining_ms,"Waypoint flight lost or refilled the paid roster")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen,"Waypoint autosave lost the paid career")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"Waypoint testing changed the earned input")
	await capture_free_application("wingman-waypoint-returned")
	print("Earned wingman waypoint boundary: ",{"resumed":resumed,"rehire_price":rehire_price,"credits":returned.contracts.credits,"names":returned.contracts.wingmen.active.names,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"has_route":has_route,"route_frames":route_frames,"timing":_pilot_deltas,"input_sha256":input_hash})

func prepare_paid_waypoint_flight() -> bool:
	if not await depart_for_lifetime():return false
	var start:=now_us
	while app.session.snapshot().contracts.wingmen.active.remaining_ms>0 and now_us-start<15000000:
		if not application_step():return false
	check(app.session.snapshot().contracts.wingmen.active.remaining_ms==0,"The old paid hire did not genuinely expire")
	if failures or not await dock_application():return false
	for tick in 30:
		if app.session.snapshot().get("wingman_notice",false):break
		if not application_step():return false
	check(app.session.snapshot().get("wingman_notice",false),"Docking did not make the expired roster available for replacement")
	if failures:return false
	press_coordinate_key(KEY_ENTER)
	check(app.session.station_owner().snapshot().contracts.wingmen.active.is_empty(),"Farewell retained the expired roster")
	if failures:return false
	var id:=await find_roster()
	if id<0:return false
	var before: Dictionary=app.session.station_owner().snapshot()
	if not app.contract_action("open",-1):check(false,app.session.error);return false
	for tick in 40:
		if not application_step():return false
	app.lounge_panel.select_contact(id)
	for tick in 40:
		if not application_step():return false
	var quote: Dictionary=app.session.station_owner().wingman_preview(id,definitions)
	check(not quote.is_empty() and quote.can_accept,"The actual lounge has no affordable rehire")
	if failures:return false
	press_coordinate_key(KEY_ENTER)
	check(app.lounge_panel.snapshot().confirming,"Rehire skipped the consent prompt")
	await capture_free_application("wingman-waypoint-rehire")
	resume_application_focus();press_coordinate_key(KEY_ENTER)
	var paid: Dictionary=app.session.station_owner().snapshot()
	rehire_price=int(quote.total_price)
	check(paid.contracts.credits==before.contracts.credits-rehire_price and paid.contracts.wingmen.active==quote.contract,"Rehire did not atomically pay for the offered roster")
	check(paid.contracts.wingmen.hired_total==before.contracts.wingmen.hired_total+quote.contract.names.size(),"Rehire lost the durable hire count")
	if failures or not app.contract_action("close",-1) or not retain_recovery_save("rehired"):return false
	print("Genuine waypoint rehire: ",{"price":rehire_price,"station":paid.loadout.station_id,"wingmen":paid.contracts.wingmen,"credits":paid.contracts.credits})
	return true

func verify_waypoint_components(crew: RefCounted,initial: Dictionary) -> void:
	var original: Dictionary=crew.snapshot();var sibling: RefCounted=crew.fork_for_frame()
	var root: Vector3=original.following.motion[0].root_pose.origin
	var route:=CrewActors.Route.new()
	check(route.configure_world_path(definitions,[root+Vector3(2000,0,0),root+Vector3(8000,0,0)]),route.error)
	var candidate: RefCounted=crew.fork_for_frame()
	check(candidate.issue_order(2,-1,route),candidate.error)
	var ordered: Dictionary=candidate.snapshot()
	for key in ["following","weapon_world","systems_weapon_world","weapon_groups"]:check(ordered[key]==original[key],"Detached waypoint input advanced "+key)
	var random:=CrewActors.Random.new();check(random.seed_from(17),random.error)
	check(not candidate.advance_targeting(0,initial.player_pose,initial.player,[],random.snapshot()).is_empty(),candidate.error)
	check(candidate.snapshot().actors[0].wingman_command==2 and candidate.snapshot().following.targets[0]==root+Vector3(2000,0,0),"Equality at an arrival-box face incorrectly completed the waypoint")
	check(route.advance(root+Vector3(2000,0,0)).index==1,route.error)
	check(candidate.snapshot().waypoint_routes[0].index==0,"The world route advanced a private pilot copy")
	var observation: Dictionary=candidate.snapshot();observation.waypoint_routes[0].waypoints[0]=Vector3.ZERO
	check(candidate.snapshot().waypoint_routes[0].waypoints[0]==root+Vector3(2000,0,0),"A snapshot changed a private route")
	var inside:=CrewActors.Route.new()
	check(inside.configure_world_path(definitions,[root+Vector3(1999,1999,1999),root+Vector3(9000,0,0)]),inside.error)
	var reached: RefCounted=crew.fork_for_frame();check(reached.issue_order(2,-1,inside),reached.error)
	check(not reached.advance_targeting(0,initial.player_pose,initial.player,[],random.snapshot()).is_empty(),reached.error)
	check(reached.snapshot().actors[0].wingman_command==1 and reached.snapshot().waypoint_routes[0].is_empty(),"A zero-time arrival inside the box did not finish exactly one waypoint")
	check(inside.snapshot().index==0,"Pilot arrival changed the world route")
	var indexed:=CrewActors.Route.new();check(indexed.configure_world_path(definitions,[root+Vector3(10000,0,0),root]),indexed.error)
	check(indexed.advance(root+Vector3(10000,0,0)).index==1,indexed.error)
	var second: RefCounted=crew.fork_for_frame();check(second.issue_order(2,-1,indexed),second.error)
	check(second.snapshot().waypoint_start_indices[0]==1,"A command reset an advanced world route to its first point")
	check(not second.advance_targeting(0,initial.player_pose,initial.player,[],random.snapshot()).is_empty() and second.snapshot().actors[0].wingman_command==1,"The copied nonzero index never completed")
	# A detached looping patrol covers the source wrap comparison, not a save.
	indexed._loop=true
	var wrapped: RefCounted=crew.fork_for_frame();check(wrapped.issue_order(2,-1,indexed),wrapped.error)
	check(not wrapped.advance_targeting(0,initial.player_pose,initial.player,[],random.snapshot()).is_empty(),wrapped.error)
	check(wrapped.snapshot().actors[0].wingman_command==2 and wrapped.snapshot().waypoint_routes[0].index==0,"Wrapping was incorrectly treated as an increasing index")
	var wrong:=indexed.fork_for_frame();wrong._identity.binding_id="other"
	var frozen: Dictionary=candidate.snapshot()
	check(not candidate.issue_order(2,-1,wrong) and not candidate.issue_order(4) and candidate.snapshot()==frozen,"A refused waypoint request leaked state")
	var absent: RefCounted=crew.fork_for_frame();check(absent.issue_order(2),absent.error)
	check(absent.snapshot().actors[0].wingman_command==1,"Missing route invented a waypoint order")
	for delta in [7,17,100]:
		var flight: RefCounted=crew.fork_for_frame();check(flight.issue_order(2,-1,route),flight.error)
		var result: Dictionary=flight.advance_targeting(delta,initial.player_pose,initial.player,[],random.snapshot())
		check(not result.is_empty() and flight.snapshot().following.motion[0].root_pose.origin!=root,"Waypoint steering failed at an accepted duration")
	check(crew.snapshot()==original and sibling.snapshot()==original,"Waypoint progress mutated a retained parent or sibling")

func verify_waypoint_journey_components(parent: RefCounted,initial: Dictionary) -> void:
	var crew: RefCounted=parent.wingman_owner()
	var original: Dictionary=crew.snapshot()
	var pose: Transform3D=original.actors[0].pose
	var root: Transform3D=original.following.motion[0].root_pose
	var route:=CrewActors.Route.new()
	check(route.configure_world_path(definitions,[root.origin+root.basis.z*12000.0]),route.error)
	var frame: RefCounted=parent.fork_for_frame()
	frame._world_route=route
	var before: Dictionary=frame.snapshot()
	var commanded: RefCounted=frame.command_wingmen(2)
	check(commanded!=null,frame.error)
	if failures:return
	check(commanded.snapshot().wingman_actors.actors.all(func(actor):return actor.wingman_command==2),"The retained world frame did not broadcast its native route")
	frame._world_route=null
	check(commanded.snapshot().wingman_actors.waypoint_routes.all(func(copy):return copy.index==0),"Clearing the parent world route changed pilot copies")
	check(parent.snapshot()==initial and before.wingman_actors==original,"Route input leaked into a retained frame")
	var candidate: RefCounted=commanded.wingman_owner()
	var random:=CrewActors.Random.new();check(random.seed_from(17),random.error)
	var remaining: int=candidate.snapshot().actors.size()
	for tick in 400:
		var result: Dictionary=candidate.advance_targeting(100,initial.player_pose,initial.player,[],random.snapshot())
		if result.is_empty():check(false,candidate.error);return
		if not random.restore(result.random_state):check(false,random.error);return
		remaining=candidate.snapshot().actors.filter(func(actor):return actor.wingman_command==2).size()
		if remaining==0:break
	check(remaining==0,"Native steering never completed every pilot's private waypoint")
	check(route.snapshot().index==0 and commanded.snapshot().wingman_actors.actors.all(func(actor):return actor.wingman_command==2),"Pilot motion advanced its parent or shared route")
	# Only detached candidates receive these exact contact/guidance boundaries.
	var hostile: Dictionary=original.actors[0].duplicate(true)
	hostile.actor_id=91;hostile.hostile=true;hostile.pose.origin=pose.origin+pose.basis.z*4000.0
	var aimed:=CrewActors.Route.new()
	check(aimed.configure_world_path(definitions,[hostile.pose.origin]),aimed.error)
	var gated: RefCounted=crew.fork_for_frame();check(gated.issue_order(2,-1,aimed),gated.error)
	var result: Dictionary=gated.advance_targeting(100,initial.player_pose,initial.player,[hostile],random.snapshot())
	check(not result.is_empty(),gated.error)
	check(gated.snapshot().targeting.selections[0].target_actor_id==91,"Waypoint gate discarded ordinary enemy selection")
	check(gated.snapshot().primary_firing.actors.is_empty() and gated.snapshot().systems_firing.actors.is_empty(),"A pilot fired while securing its waypoint")
	var systems: RefCounted=crew.fork_for_frame()
	check(systems.toggle_weapon_group(0) and systems.issue_order(2,-1,aimed),systems.error)
	check(not systems.advance_targeting(100,initial.player_pose,initial.player,[hostile],random.snapshot()).is_empty(),systems.error)
	check(systems.snapshot().systems_firing.actors.is_empty(),"A waypoint pilot fired the selected EMP group")
	var lateral:=CrewActors.Route.new()
	check(lateral.configure_world_path(definitions,[root.origin+root.basis.x*4000.0+root.basis.z*4000.0]),lateral.error)
	var turning: RefCounted=crew.fork_for_frame();check(turning.issue_order(2,-1,lateral),turning.error)
	turning._selections=turning._selections.duplicate(true)
	turning._selections[0].merge({"selection_elapsed_ms":0,"straight":false,"fire_desired":true,"target_index":1},true)
	check(not turning.advance_targeting(100,initial.player_pose,initial.player,[hostile],random.snapshot()).is_empty(),turning.error)
	var reference: RefCounted=crew.fork_for_frame();check(reference.issue_order(2,-1,lateral),reference.error)
	reference._selections=reference._selections.duplicate(true)
	reference._selections[0].merge({"selection_elapsed_ms":0,"straight":false,"fire_desired":false,"target_index":-1},true)
	check(not reference.advance_targeting(100,initial.player_pose,initial.player,[],random.snapshot()).is_empty(),reference.error)
	check(turning.snapshot().following.motion[0]==reference.snapshot().following.motion[0],"A nearby selected enemy suppressed waypoint turning")
	check(parent.snapshot()==initial,"Detached hostile/waypoint checks changed the earned flight")
