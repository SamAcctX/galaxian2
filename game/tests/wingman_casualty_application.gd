extends "res://tests/wingman_route_application.gd"
## Casualty accounting uses detached native bodies/objectives only. The real
## application never receives a manufactured death, career, pose or projectile.

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var input_hash:=FileAccess.get_sha256(input_path)
	var resumed:=OS.get_environment("GOF2_WINGMAN_CASUALTY_STAGE")=="resume"
	app.set_player_mode(true);app.show();app.present_session()
	await process_frame;resume_application_focus()
	var original: Dictionary=app.session.station_owner().snapshot()
	var document: Dictionary=app._save_file.load_document(input_path,definitions,catalogue,source)
	check(not document.is_empty() and document.career.wingmen==original.contracts.wingmen and document.career.mission==original.contracts.mission and document.career.credits==original.contracts.credits,"Resume changed the earned crew, wallet or unfinished job")
	check(original.contracts.wingmen.active.get("names",[]).size()==3 and original.contracts.wingmen.active.remaining_ms>0,"The earned input must retain its three living paid pilots")
	check(original.contracts.mission.get("kind")==2 and original.contracts.mission.station_id==original.loadout.station_id,"Casualty accounting must not replace the retained local Protection job")
	if failures or not await depart_for_lifetime():return
	var parent: RefCounted=app.session.flight_owner()
	var before: Dictionary=parent.snapshot()
	check(parent.wingman_owner().casualty_bodies().is_empty() and parent._objective._wingman_losses.is_empty(),"A fresh departure invented a casualty")
	if not resumed:verify_casualty_components(parent)
	else:verify_casualty_arrival_components(parent)
	check(parent.snapshot()==before and app.session.flight_owner().snapshot()==before,"Detached casualty checks modified the live earned flight")
	if failures:return
	var started:=now_us
	while now_us-started<3000000:
		var state: Dictionary=app.session.snapshot()
		var target: Vector3=state.wingman_actors.actors[0].pose.origin
		if not pirate_step({"commands":PiratePilot.Steering.steering_toward(state.player_pose,target),"throttle":0.0,"fire":false,"strafe":0.0}):return
	var live: Dictionary=app.session.snapshot()
	check(live.contracts.wingmen.active.names==original.contracts.wingmen.active.names and live.wingman_actors.actors.all(func(actor):return actor.vitals.hull>0),"The live casualty observer removed a living pilot")
	check(app.session.flight_owner()._objective._wingman_losses.is_empty(),"Live flight recorded a false loss")
	check(not live.wingman_actors.interactions_connected,"Accounting alone must not advertise full reciprocal combat")
	await capture_free_application("wingman-casualty-accounting-live")
	if failures or not await dock_application():return
	var returned: Dictionary=app.session.station_owner().snapshot()
	check(returned.contracts.mission==original.contracts.mission and returned.contracts.credits==original.contracts.credits,"Accounting observation changed the job or paid an unfinished contract")
	check(returned.contracts.wingmen.active.names==original.contracts.wingmen.active.names and returned.contracts.wingmen.hired_total==original.contracts.wingmen.hired_total,"Docking lost a living pilot or changed hire history")
	check(returned.contracts.wingmen.active.remaining_ms>0 and returned.contracts.wingmen.active.remaining_ms<original.contracts.wingmen.active.remaining_ms,"Flight refilled or stopped the paid timer")
	check(returned.cargo==original.cargo and returned.loadout.equipment_ids==original.loadout.equipment_ids and returned.campaign_cursor==original.campaign_cursor,"Accounting changed unrelated cargo, equipment or campaign")
	var automatic: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not automatic.is_empty() and automatic.career.wingmen==returned.contracts.wingmen and automatic.career.mission==returned.contracts.mission,"The actual docking autosave changed the crew or job")
	if failures or not retain_recovery_save("returned"):return
	check(FileAccess.get_sha256(input_path)==input_hash,"The immutable earned input was modified")
	await capture_free_application("wingman-casualty-accounting-returned")
	print("Casualty accounting application accepted: ",{"resume":resumed,"input_sha256":input_hash,"credits":returned.contracts.credits,"remaining_ms":returned.contracts.wingmen.active.remaining_ms,"names":returned.contracts.wingmen.active.names,"earned_casualties":0,"incoming_hits_accepted":false,"timing":_pilot_deltas})

func verify_casualty_components(parent: RefCounted) -> void:
	var crew: RefCounted=parent.wingman_owner()
	var cast_before: Dictionary=crew.snapshot()
	var objective: RefCounted=parent._objective.fork_for_frame()
	var original_objective: Dictionary=objective.snapshot()
	var original: Dictionary=objective.contract_owner().snapshot()
	check(not objective.record_wingman_loss(null),"Null was accepted as a casualty")
	check(not objective.record_wingman_loss(RefCounted.new()),"An unrelated object was accepted as a casualty")
	check(not objective.record_wingman_loss(crew.body_owner(0)),"A living paid pilot was accepted as dead")
	check(objective.snapshot()==original_objective,"Rejected casualties changed the objective")
	if failures:return
	var expected: Dictionary=original.duplicate(true)
	var survivors: Array=original.wingmen.active.names.duplicate()
	var dead_bodies:=[]
	# Public native damage on detached component bodies, not emitted projectiles
	# and not an earned combat result. Stable cast indices outlive roster removal.
	for index in [1,0,2]:
		var body: RefCounted=crew.body_owner(index)
		var hit: Dictionary=body.normal_hit(100000,true)
		check(not hit.is_empty() and body.snapshot().vitals.hull==0,"The detached native damage owner did not exhaust the hull")
		if failures:return
		dead_bodies.append(body)
		check(objective.record_wingman_loss(body),objective.error)
		survivors.erase(body.snapshot().name)
		if survivors.is_empty():expected.wingmen.active={}
		else:expected.wingmen.active.names=survivors.duplicate()
		check(objective.contract_owner().snapshot()==expected,"Casualty removal changed more than the matching paid name")
		check(load("res://src/simulation/wingman_contract.gd").valid_state(expected.wingmen,definitions),"A casualty produced an invalid saved crew shape")
		check(objective.record_wingman_loss(body) and objective.contract_owner().snapshot()==expected,"Repeated death notification removed another pilot")
		var sibling: RefCounted=objective.fork_for_frame()
		check(sibling.record_wingman_loss(body) and sibling.contract_owner().snapshot()==expected,"A fork forgot its processed casualty")
		if survivors.size()==2:
			var other: RefCounted=crew.body_owner(2)
			check(not other.normal_hit(100000,true).is_empty() and sibling.record_wingman_loss(other),"A detached sibling could not record its own casualty")
			check(objective.contract_owner().snapshot()==expected and sibling.contract_owner().snapshot().wingmen.active.names.size()==1,"Sibling loss leaked into its retained parent")
			check(objective.advance_wingmen(17),objective.error)
			expected.wingmen.active.remaining_ms-=17
			check(objective.contract_owner().snapshot()==expected,"A surviving crew lost its original timer after a casualty")
		if failures:return
	check(objective.contract_owner().snapshot().wingmen.active.is_empty(),"The final pilot left a ghost active crew")
	for body in dead_bodies:check(objective.record_wingman_loss(body),"A retired cast notification was not idempotent")
	check(objective.contract_owner().snapshot()==expected,"Repeated final notifications changed wallet, mission or hire history")
	# Construct an explicitly unearned native component with an unknown name.
	# It remains detached and cannot be substituted for this departure's cast.
	var initial: Dictionary=crew.body_owner(0).snapshot()
	initial.name="Unhired diagnostic pilot"
	var outsider: RefCounted=crew.body_owner(0).get_script().new()
	check(outsider._configure_wingman(definitions,catalogue,initial,initial.rank,initial.campaign_cursor,initial.difficulty),outsider.error)
	check(not outsider.normal_hit(100000,true).is_empty(),outsider.error)
	var fresh: RefCounted=parent._objective.fork_for_frame()
	check(not fresh.record_wingman_loss(outsider) and fresh.snapshot()==original_objective,"An unowned native casualty altered the paid cast")
	check(crew.snapshot()==cast_before and crew.casualty_bodies().is_empty(),"Detached damage changed the retained live bodies")
	check(parent._objective.snapshot()==original_objective,"Component casualties changed the live career")
	print("Detached casualty components accepted: ",{"order":[1,0,2],"native_depleted_bodies":dead_bodies.size(),"repeated_notifications":true,"fork_isolation":true,"earned_casualties":0})

func verify_casualty_arrival_components(parent: RefCounted) -> void:
	var before: Dictionary=parent.snapshot()
	var objective: RefCounted=parent._objective.fork_for_frame()
	var original: Dictionary=objective.contract_owner().snapshot()
	var crew: RefCounted=parent.wingman_owner()
	for index in 3:
		var body: RefCounted=crew.body_owner(index)
		check(not body.normal_hit(100000,true).is_empty() and objective.record_wingman_loss(body),"A detached arrival branch did not retain its native casualty")
		if failures:return
		var career: Dictionary=objective.contract_owner().snapshot()
		# This is the native arrival transaction on detached owners. It is not a
		# physical docking event and is never saved or installed in the application.
		var arrival: RefCounted=objective.retained_for_arrival(parent.encounter_owner())
		check(arrival!=null,objective.error)
		if failures:return
		var returned: Dictionary=arrival.snapshot()
		check(returned.wingmen==career.wingmen,"Arrival restored a lost pilot or changed surviving hire terms")
		check(returned.credits==original.credits and returned.mission==original.mission and returned.completed_side_missions==original.completed_side_missions,"A companion casualty was counted as a paid or completed mission")
		check(parent.snapshot()==before,"Detached casualty arrival changed the live flight")
		var forked: RefCounted=objective.fork_for_frame()
		check(forked.record_wingman_loss(body) and forked.contract_owner().snapshot()==career,"Arrival lost the duplicate-notification guard")
	print("Detached casualty arrivals accepted: ",{"surviving_counts":[2,1,0],"real_dockings":0,"saved_diagnostic_branches":0})
