extends "res://tests/bakka_arrival_application.gd"
## Continue the unchanged earned save's staged arrival with real controls.
## Deliberately pulse the nearby authored rival to exercise primary-faction
## reactions and retained friendship. This is not contest victory or a new save.
const EmpPilot=preload("res://tests/fixtures/expedition_flight_pilot.gd")

func verify_arrival_briefing() -> void:
	await super.verify_arrival_briefing()
	if not failures:await verify_live_emp()

func emp_input_step(commands:=Vector2.ZERO,throttle:=0.0) -> bool:
	resume_application_focus()
	for adjustment in 10:
		var current: float=app.session.snapshot().input_throttle
		if absf(current-throttle)<.01:break
		if not app.session.action("throttle_up" if current<throttle else "throttle_down"):check(false,app.session.error);return false
	now_us+=100000
	if not app.session.step(now_us,commands):check(false,app.session.error);return false
	app.present_session()
	if app.session.flight_owner().death_active():check(false,"The real EMP pilot died before contact");return false
	return true

func verify_live_emp() -> void:
	var initial: Dictionary=app.session.snapshot()
	check(initial.encounter.combat.provocation.initial_reputation==initial.progress.reputation,"The story reaction owner reset the saved career's standing")
	check(initial.encounter.has("secondaries") and initial.encounter.secondaries.guns[0].ammunition>0,"Use only EMP ammunition retained by the earned ship")
	if failures or not select_paid_emp():return
	var ready:=false
	for tick in 2000:
		var state: Dictionary=app.session.snapshot()
		var rival: Dictionary=state.encounter.combat.actors[0]
		var gun: Dictionary=state.encounter.secondaries.guns[0]
		var radius:=float(catalogue.tables.items[int(gun.equipment.item_id)].properties[14])
		var damage:=float(catalogue.tables.items[int(gun.equipment.item_id)].properties[10])
		var distance: float=rival.position.distance_to(state.player_pose.origin)
		var contact_radius: float=radius*clampf(1.0-(float(rival.systems.capacity)+8.0)/damage,.15,.5)
		if rival.active and distance<contact_radius and gun.bomb.elapsed_ms>gun.bomb.weapon.interval_ms:
			ready=true;break
		if not emp_input_step(EmpPilot.steering_toward(state.player_pose,rival.position),1.0 if distance>=contact_radius else 0.0):return
		if tick%100==0:print("Saved202 EMP approach ",tick," rival distance ",int(distance)," pulse radius ",int(radius)," player ",state.player.vitals)
		if tick%20==0:await process_frame
	check(ready,"Normal steering did not reach an actual B'akka EMP target")
	if failures:return
	var before: Dictionary=app.session.snapshot()
	var retained: RefCounted=app.session.flight_owner()
	var retained_state: Dictionary=retained.snapshot()
	var rounds: int=int(before.encounter.secondaries.guns[0].ammunition)
	if not app.session.action("missiles") or not emp_input_step():check(false,app.session.error);return
	var launched: Dictionary=app.session.snapshot()
	check(launched.encounter.secondaries.guns[0].ammunition==rounds-1 and launched.encounter.secondaries.guns[0].bomb.shot.get("phase")=="flying","Actual secondary input did not launch exactly one retained round")
	if failures:return
	if not app.session.action("missiles") or not emp_input_step():check(false,app.session.error);return
	var contacted:=false
	for tick in 30:
		var state: Dictionary=app.session.snapshot()
		var rival: Dictionary=state.encounter.combat.actors[0]
		if rival.systems.integrity<before.encounter.combat.actors[0].systems.integrity:
			contacted=true
			var reaction: Dictionary=state.encounter.combat.provocation
			check(reaction.systems_requested_damage[0]>0 and reaction.requested_damage[0]==0,"The real EMP contact entered the normal-damage counter")
			check(rival.friendly and not rival.hostile,"EMP provocation overrode the original rival friendship")
			check(not reaction.response_issued and not reaction.station_response_flag and reaction.radio_serial==0,"Story EMP damage invented ordinary response radio or a station alert")
			check(state.encounter.secondaries.guns[0].ammunition==rounds-1,"Manual detonation consumed another round")
			var expected: Dictionary=before.progress.reputation.duplicate(true)
			if rival.systems.integrity==0:expected.axes[0]=mini(100,int(expected.axes[0])+2)
			check(state.progress.reputation==expected,"Actual EMP depletion lost or reset the retained Vossk standing change")
			check(state.campaign_cursor==36 and not state.dialogue.visible and state.contracts.credits==before.contracts.credits and state.contracts.passengers==3,"An EMP contact completed or paid the unplayed contest")
			check(retained.snapshot()==retained_state,"The live pulse mutated its retained pre-launch frame")
			await capture_free_application("saved202-bakka-real-emp")
			print("Saved202 real EMP contact: item ",before.encounter.secondaries.guns[0].equipment.item_id," rounds ",rounds," -> ",state.encounter.secondaries.guns[0].ammunition," rival systems ",before.encounter.combat.actors[0].systems," -> ",rival.systems," standing ",before.progress.reputation," -> ",state.progress.reputation)
			break
		if not emp_input_step():return
	check(contacted,"Real launch/detonation never damaged the nearby B'akka ship systems")
