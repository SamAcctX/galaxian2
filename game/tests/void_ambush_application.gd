extends "res://tests/nehma_onward_application.gd"
## Continue the earned Néhma40 station through real departure, the Void portal
## and the mission 41 ambush. Only application input drives the journey.
const ExpeditionPilot=preload("res://tests/fixtures/expedition_flight_pilot.gd")
const CombatPilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
var combat_pilot:=CombatPilot.new()
var pending_emp:=false

func verify_free_application() -> void:
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	var original: Dictionary=app.session.station_owner().snapshot()
	check(FileAccess.get_sha256(input_path)==OS.get_environment("GOF2_SOURCE_SAVE_SHA256") and definitions.binding_id==SOURCE_BINDING,"Use the exact earned Néhma40 checkpoint")
	check(original.campaign_cursor==40 and original.loadout.station_id==30 and original.loadout.system_id==2,"Resume the acknowledged Néhma40 station")
	if failures:return
	chapter_directory=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	check(not chapter_directory.is_empty() and FreePlayCheckpoint.private_path(chapter_directory+"/save.bin"),"Use isolated Void ambush output")
	if failures:return
	_world_clock_base=1789105600
	retained_job=original.contracts.mission.duplicate(true);route_credits=int(original.contracts.credits)
	app.enable_saves(chapter_directory)
	app.show();app.present_session();await process_frame;resume_application_focus()
	await capture_free_application("void41-nehma40-source")
	if not await depart_onward():return
	# Every station launch restores the equipped ship, including this one.
	check(app.session.snapshot().player.vitals.armor==110,"The Néhma launch kept arrival damage instead of the station launch reset")
	if not await enter_mission40_gate():return
	await capture_free_application("void41-selected40-arrival")
	if not await fly_mission40_to_portal():return
	await capture_free_application("void41-m40-portal-contact")
	if not app.enter_mission_portal(now_us,flight_world_seconds(),flight_world_seconds()):check(false,app.status.text);return
	var ambush: Dictionary=app.session.snapshot()
	check(ambush.campaign_cursor==41 and ambush.encounter.combat.actors.size()==8 and ambush.player.vitals.hull>0,"The portal did not enter the eight-actor Void ambush with the surviving ship")
	await capture_free_application("void41-arrival")
	if failures or not await fly_mission41():return
	# Final result Next advances the career once to 42 in the SAME Void world;
	# the freighter kill, portal escape and Thynome docking follow (mission 42).
	var after: Dictionary=app.session.snapshot()
	check(after.campaign_cursor==42 and app.session.status=="running" and after.encounter.combat.actors[0].vitals.hull>0,"Result 41 did not continue into mission 42 in the living Void world")
	if not failures:print("Earned Néhma40 -> mission 40 escort -> portal -> Void ambush cinematic -> result41 -> cursor42")

func dialogue_visible() -> bool:
	return app.session.flight_owner().campaign_dialogue_visible()

## Acknowledge the visible page with the keyboard, as a player would.
func acknowledge_page(label: String) -> bool:
	var before: Dictionary=app.session.flight_owner().dialogue()
	resume_application_focus();app.present_session();await process_frame
	press_key(KEY_ENTER);await process_frame
	var after: Dictionary=app.session.flight_owner().dialogue()
	print(label," page ",before.get("text_id")," voice ",before.get("voice_event_id")," -> ",after.get("text_id")," visible ",after.get("visible"))
	if after==before and app.session.status=="running":print("Acknowledgement diagnostics: scene ",app.session.scene.error," status ",app.status.text," session ",app.session.error)
	check(after!=before or app.session.status!="running","Enter did not acknowledge the visible "+label+" page")
	return failures==0

## Protect Errkt's freighter until the scripted attack and its cinematic end.
func fly_mission41() -> bool:
	var last_phase:=-1;var captured:={}
	for tick in 20000:
		var state: Dictionary=app.session.snapshot()
		if last_phase==5 and state.campaign_cursor==42:
			print("Mission 41 result acknowledged at tick ",tick," status ",app.session.status)
			return true
		if app.session.status!="running":check(false,"Mission 41 stopped at boundary "+app.session.status);return false
		if state.player.vitals.hull<=0:check(false,"Mission 41 pilot died at tick "+str(tick)+" "+str(state.player_pose.origin));return false
		var sequence: Dictionary=state.encounter.sequence
		if int(sequence.get("phase",-1))!=last_phase:
			last_phase=int(sequence.get("phase",-1))
			print("M41 phase ",last_phase," at tick ",tick," elapsed ",state.elapsed_ms," freighter ",state.encounter.combat.actors[0].position," hull ",state.encounter.combat.actors[0].vitals.hull," blocked ",sequence.input_blocked)
			await capture_free_application("void41-phase-"+str(last_phase))
		if dialogue_visible():
			var line: Dictionary=app.session.flight_owner().dialogue()
			if not captured.has(line.get("text_id")):
				captured[line.get("text_id")]=true
				await capture_free_application("void41-dialogue-"+str(line.get("text_id")))
			if not await acknowledge_page("M41"):return false
			continue
		var freighter: Dictionary=state.encounter.combat.actors[0]
		var commands:=Vector2.ZERO;var fire:=false;var throttle:=1.0;var strafe:=0.0
		var threats: Array=state.encounter.combat.actors.filter(func(actor):return actor.actor_id>0 and actor.get("hostile",false) and actor.vitals.hull>0 and actor.position.distance_to(freighter.position)<20000.0).map(func(actor):return actor.actor_id)
		if app.session.can_control():
			if not threats.is_empty():
				var input: Dictionary=combat_pilot.controls(state,tick,threats,true)
				commands=input.commands;fire=input.fire;throttle=input.throttle;strafe=input.strafe
			else:
				commands=ExpeditionPilot.steering_toward(state.player_pose,freighter.position+Vector3(0,1500,-3000))
				throttle=1.0 if state.player_pose.origin.distance_to(freighter.position)>5000.0 else 0.3
		if tick%100==0:
			print("M41 tick ",tick," elapsed ",state.elapsed_ms," phase ",sequence.get("phase")," control ",app.session.can_control()," hull ",state.player.vitals," freighter ",freighter.position," fhull ",freighter.vitals.hull," threats ",threats," radio ",state.encounter.radio.get("started",[])," runner ",state.runner)
			await process_frame
		if not flight_step(commands,fire,throttle,strafe):return false
	check(false,"Mission 41 did not reach its result")
	return false

## Select the installed EMP launcher through the real secondary menu once, then
## launch a paid round when several attackers close in.
func use_emp(state: Dictionary) -> bool:
	if not state.encounter.has("secondaries") or state.encounter.secondaries.guns.is_empty():return true
	var gun: Dictionary=state.encounter.secondaries.guns[0]
	var item_id: int=int(gun.equipment.item_id)
	if state.encounter.selected_secondary!=item_id:
		if not app.session.action("secondary_menu") or not app.session.confirm_secondary(item_id):check(false,app.session.error);return false
		print("Selected EMP launcher ",item_id," ammunition ",gun.ammunition)
		return true
	# Checked again inside flight_step after focus is restored, so the request
	# reaches the same frame as a player's key press would.
	pending_emp=true
	return true

func press_key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()

func flight_step(commands: Vector2,fire:=false,throttle:=1.0,strafe:=0.0) -> bool:
	resume_application_focus()
	if app.session.can_control():
		for adjustment in 10:
			var current: float=float(app.session.snapshot().throttle)
			if absf(current-throttle)<.01:break
			if not app.session.action("throttle_up" if current<throttle else "throttle_down"):check(false,app.session.error);return false
	if pending_emp:
		pending_emp=false
		if app.session.can_control() and not try_paid_emp(app.session.snapshot(),9000,0.0,"mission 40 attackers",true):return false
	now_us+=100000
	if not app.session.step(now_us,commands,fire,false,strafe):check(false,app.session.error);return false
	app.present_session()
	check(not app._transition_failed,app.status.text)
	return failures==0

## Mission 40 as a player can survive it with this ship: the fighters hunt the
## player, so circle outside the portal's reach, spend the EMP rounds on close
## attackers, and follow the freighter in once it starts its escape. Entering
## first is the original's early-entry death.
func fly_mission40_to_portal() -> bool:
	var history:=[]
	for tick in 6000:
		var state: Dictionary=app.session.snapshot()
		var near: Array=state.encounter.combat.actors.filter(func(actor):return actor.vitals.hull>0).map(func(actor):return [actor.actor_id,int(actor.position.distance_to(state.player_pose.origin)),actor.vitals.hull])
		near.sort_custom(func(a,b):return a[1]<b[1])
		history.append([tick,state.player.vitals.hull,near.slice(0,3),state.encounter.controller.get("accounting",{}).get("counter_deltas",{})])
		if history.size()>40:history.pop_front()
		if app.session.status=="selected40_portal_transition_required":
			print("Mission 40 portal contact at tick ",tick," hull ",state.player.vitals)
			return true
		if state.player.vitals.hull<=0:
			for row in history:print("  hist ",row)
			print("Death state: contacts ",state.physical_contacts," destruction ",state.player_destruction.get("phase")," portal_contact ",state.portal_contact," seq ",state.encounter.selected40_sequence.phase," pose ",state.player_pose.origin)
			await capture_free_application("void41-m40-death")
			check(false,"Mission 40 pilot died at tick "+str(tick));return false
		if state.get("dialogue",{}).get("visible",false) or app.session.flight_owner().campaign_dialogue_visible():
			if tick%10==0:
				print("Dialogue at tick ",tick," ",state.get("dialogue",{}))
				resume_application_focus();app.present_session();await process_frame
				press_key(KEY_ENTER);await process_frame
			if not flight_step(Vector2.ZERO):return false
			continue
		var phase: int=int(state.encounter.selected40_sequence.phase)
		var freighter: Dictionary=state.encounter.combat.actors[0]
		# Race ahead of the attackers and circle outside the portal's contact
		# range until the freighter starts its escape, then follow it in.
		var target: Vector3=state.portal.position
		if phase<4:
			var hold: Vector3=state.portal.position+Vector3(0,0,-14000)
			var offset: Vector3=state.player_pose.origin-hold
			if offset.length()<9000.0:
				var angle:=atan2(offset.y,offset.x)+0.6
				target=hold+Vector3(cos(angle),sin(angle),0)*7000.0
			else:target=hold
		var commands:=Vector2.ZERO;var fire:=false;var throttle:=1.0;var strafe:=0.0
		var threats: Array=state.encounter.combat.actors.filter(func(actor):return actor.actor_id>0 and actor.get("hostile",false) and actor.get("active",true) and actor.vitals.hull>0 and actor.position.distance_to(state.player_pose.origin)<16000.0).map(func(actor):return actor.actor_id)
		if app.session.can_control():
			commands=ExpeditionPilot.steering_toward(state.player_pose,target)
			if not await use_emp(state):return false
		if tick%50==0:
			print("M40 tick ",tick," phase ",state.encounter.selected40_sequence.phase," freighter ",state.encounter.combat.actors[0].position," mode ",state.encounter.combat.actors[0].get("actor_mode")," control ",app.session.can_control()," hull ",state.player.vitals," threats ",threats," dist ",int(state.player_pose.origin.distance_to(target))," status ",app.session.status)
			await process_frame
		if not flight_step(commands,fire,throttle,strafe):return false
	check(false,"Mission 40 never reached its portal")
	return false

## The final hop enters the authored mission 40 world rather than an ordinary system.
func enter_mission40_gate() -> bool:
	if not app.open_map() or not app.switch_map_system(8):check(false,app.status.text);return false
	app.map_panel.select_station(42);app.map_panel.request_confirmation()
	if not app.confirm_map_planet(42,now_us):check(false,app.map_panel.error);return false
	if not await reach_gate_confirmation():return false
	if not app.choose_gate_confirmation(0,now_us):check(false,app.session.error);return false
	app.session.rebase_time(now_us)
	for tick in 90:
		if app.session.status!="running":break
		now_us+=100000
		if not app.session.step(now_us):check(false,app.session.error);return false
	if app.session.status!="gate_arrival_transition_required":check(false,"The actual gate did not complete its animation");return false
	if not app.enter_gate_arrival(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	check(app.session.get_script().resource_path.ends_with("_session.gd") and app.session.has_method("flight_owner") and app.session.flight_owner().get_script().resource_path.contains("selected40"),"The Néhma gate did not enter the authored mission 40 world")
	return failures==0
