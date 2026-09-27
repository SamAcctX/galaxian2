extends "res://tests/void_ambush_application.gd"
## Earned mission41 success through ordinary desktop Host events at variable
## cadence. Keep the legacy100ms route separate and stop in the living world42.
const CADENCE_US=[4000,17000,31000,9000,67000]
const MAX_FLIGHT_US=600000000
const DesktopPilot=preload("res://tests/fixtures/mission_pilot_input.gd")
const PilotObservation=preload("res://tests/fixtures/mission_pilot_observation.gd")
const EscortTargets=preload("res://tests/fixtures/mission_escort_targets.gd")
const EscortTactics=preload("res://tests/fixtures/mission_escort_tactics.gd")
const EscortPilot=preload("res://tests/fixtures/mission_escort_pilot.gd")
var cadence_frames:=0
var cadence_elapsed_us:=0
var cadence_kinds:={}
var controlled_frames:=0
var firing_frames:=0
var emitted_primary_shots:=0
var primary_captured:=false
var strafe_frames:={-1:0,1:0}
var throttle_frames:={}

func verify_free_application() -> void:
	var original:=await enter_earned_ambush()
	if original.is_empty():return
	var session: Node3D=app.session;var scene: Node3D=session.scene
	var camera: Camera3D=session.camera
	var parent: RefCounted=session.flight_owner();var initial: Dictionary=parent.snapshot()
	var world: RefCounted=parent.initialized_world_owner()
	app._mouse_steering=true;app.set_player_mode(true)
	resume_application_focus();app.present_session()
	root_press(KEY_ENTER);await process_frame
	check(session.snapshot().entry_skipped and session.snapshot().dialogue.get("text_id")==2038,"Earned cadence arrival skip lost the first briefing")
	if failures:return
	for page in 3:
		if not await acknowledge_cadence_page(2038+page,185+page,"briefing"):return
	check(session.can_control() and app._mouse_captured,"Earned briefing did not release desktop mouse flight")
	if failures:return
	if not await exercise_cadence_controls():return
	var pilot:=EscortPilot.new();var tactics:=EscortTactics.new();var phases:={}
	await fly_cadence_loop(session,pilot,tactics,phases)
	if failures:return
	await finish_cadence_flight(session,scene,camera,parent,initial,world,pilot,phases)

func exercise_cadence_controls() -> bool:return true

## The earned driver and bounded integration check execute this same loop.
## A component may stop at a sample limit; earned verification has no such limit
## and still requires the complete result and same-world continuation below.
func fly_cadence_loop(session: Node3D,pilot: RefCounted,tactics: RefCounted,phases: Dictionary,frame_limit: int=-1) -> void:
	var next_report_ms:=0
	while cadence_elapsed_us<MAX_FLIGHT_US and (frame_limit<0 or cadence_frames<frame_limit):
		resume_application_focus()
		check(app.session==session,"Earned cadence replaced its retained session before observation")
		if failures:return
		var observation:=PilotObservation.new(session)
		var state: Dictionary=observation.read(session)
		if session.status!="running" or state.player.vitals.hull<=0:
			print("Cadence loss at ",state.elapsed_ms,"ms; controlled/fire ",controlled_frames,"/",firing_frames," strafe ",strafe_frames," throttle ",throttle_frames," retreat ",tactics.retreating)
			await capture_free_application("void41-cadence-failed")
			check(false,"Earned cadence stopped: "+session.status+" pools "+str(state.player.vitals));return
		if state.dialogue.visible:
			check(state.dialogue.text_id==2047 and state.campaign_cursor==41,"Cadence flight opened failure or an unexpected result")
			break
		var phase: int=state.encounter.sequence.phase
		if not phases.has(phase):
			phases[phase]=state.elapsed_ms
			print("Cadence phase ",phase," at ",state.elapsed_ms,"ms; player ",state.player.vitals," freighter ",state.encounter.combat.actors[0].vitals)
			observation.invalidate()
			await capture_free_application("void41-cadence-phase-"+str(phase))
			# Capture can yield or navigate. Plan only from a fresh observation;
			# no root sample or Host frame has been issued by this iteration yet.
			continue
		var input:={"commands":Vector2.ZERO,"fire":false,"throttle":1.0,"strafe":0.0}
		if session.can_control():
			var freighter: Dictionary=state.encounter.combat.actors[0]
			var threats: Array=EscortTargets.select_ids(state.encounter.combat.actors)
			if not threats.is_empty():
				input=pilot.controls_at_time(state,float(state.elapsed_ms),threats,true)
				check(pilot.previous_observed_ms==float(state.elapsed_ms),"Pilot did not sample the actual accepted observation time")
			else:
				input.commands=ExpeditionPilot.steering_toward(state.player_pose,freighter.position+Vector3(0,1500,-3000))
				input.throttle=1.0 if state.player_pose.origin.distance_to(freighter.position)>5000.0 else 0.3
			if emitted_primary_shots==0:input=EscortPilot.request_trigger_sample(state,input)
			var was_retreating: bool=tactics.retreating
			var was_regrouping: bool=tactics.regrouping
			input=tactics.apply(state,input)
			if tactics.regrouping!=was_regrouping:print("Cadence regroup ",tactics.regrouping," at ",state.elapsed_ms,"ms; escort distance ",tactics.escort_distance," pools ",state.player.vitals)
			if tactics.retreating and not was_retreating:print("Cadence return to escort at ",state.elapsed_ms,"ms; pools ",state.player.vitals," controlled/fire ",controlled_frames,"/",firing_frames," strafe ",strafe_frames," throttle ",throttle_frames)
		var report_due: bool=state.elapsed_ms>=next_report_ms
		if report_due:
			next_report_ms=int(state.elapsed_ms)+10000
			print("Cadence frame ",cadence_frames," observed ",state.elapsed_ms,"ms phase ",phase," target ",input.get("target",-1)," distance ",input.get("distance",-1)," throttle ",input.throttle," retreat ",tactics.retreating," regroup ",tactics.regrouping," escort distance ",tactics.escort_distance," pools ",state.player.vitals," fire frames ",firing_frames)
		if failures or not cadence_host_step(input,observation):return
		# Yield after consuming this sample, never between planning and delivery.
		if report_due:await process_frame
		if emitted_primary_shots>0 and not primary_captured:
			primary_captured=true
			await capture_free_application("void41-cadence-primary-emission")

func finish_cadence_flight(session: Node3D,scene: Node3D,camera: Camera3D,parent: RefCounted,initial: Dictionary,world: RefCounted,pilot: RefCounted,phases: Dictionary) -> void:
	var result: Dictionary=session.snapshot()
	print("Cadence result observation: ",result.dialogue.get("text_id",-1)," at ",result.elapsed_ms,"ms; controlled/fire ",controlled_frames,"/",firing_frames," strafe ",strafe_frames," throttle ",throttle_frames," pilot observed ",pilot.previous_observed_ms)
	check(result.dialogue.get("text_id")==2047 and result.player.vitals.hull>0 and result.encounter.combat.actors[0].vitals.hull>0,"Cadence earned flight did not reach the living freighter result")
	for phase in [1,2,3,4,5]:check(phases.has(phase),"Earned cadence omitted cinematic phase "+str(phase))
	if failures:return
	check(phases[3]-phases[2]>15000 and phases[5]-phases[4]>15000,"Cadence flight shortened the two independently timed shots")
	check_cadence_coverage()
	check(controlled_frames>0 and firing_frames>0 and strafe_frames[-1]>0 and strafe_frames[1]>0,"Earned battle did not exercise firing and both evasive directions")
	check(throttle_frames.has(0) and throttle_frames.has(10),"Earned battle did not deliver both stopped and full throttle through keys")
	check(emitted_primary_shots>0 and primary_captured,"Earned held input lacked a native projectile and its capture")
	check(parent.snapshot()==initial and result.equipment==initial.equipment,"Earned cadence mutated its retained incoming frame or inventory")
	if failures:return
	for page in 4:
		if not await acknowledge_cadence_page(2047+page,416+page,"result"):return
	var final_owner: RefCounted=session.flight_owner();var before: Dictionary=final_owner.snapshot()
	if not await acknowledge_cadence_page(2051,420,"result"):return
	var after: Dictionary=session.snapshot()
	check(after.campaign_cursor==42 and session.status=="running" and session.can_control() and not after.dialogue.visible,"Final root Next did not release living mission42")
	check(app.session==session and session.scene==scene and session.camera==camera and session.flight_owner().initialized_world_owner()==world,"Result41 rebuilt the earned world, scene or camera")
	check(session.flight_owner().encounter_owner().snapshot()==final_owner.encounter_owner().snapshot() and after.player==before.player and after.player_pose==before.player_pose and after.scenery==before.scenery,"Final root Next changed the retained cast, player or scenery")
	check(after.equipment==before.equipment and after.career.mission==before.career.mission and after.career.credits==before.career.credits,"Result41 altered equipment, the independent job or money")
	check(after.runner.mode==0 and not after.runner.retired and after.runner.clock_ms==0 and after.damage_particles==before.damage_particles,"Living42 retained an old result clock or lost the attached fire")
	check(session.flight_owner().station_response_flags()==void_route_history and final_owner.snapshot()==before,"Earned continuation changed navigation history or its retained parent")
	if failures:return
	root_press(KEY_ENTER);await process_frame
	check(session.snapshot()==after,"A repeated root Next advanced the earned career twice")
	if failures or not cadence_host_step({"commands":Vector2(.1,-.1),"fire":false,"throttle":0.0,"strafe":0.0}):return
	var living: Dictionary=session.snapshot()
	check(living.campaign_cursor==42 and living.player.vitals.hull>0 and living.encounter.combat.actors[0].vitals.hull>0 and session.can_control(),"First ordinary Host frame did not keep mission42 alive")
	await capture_free_application("void41-cadence-living42")
	if not failures:print("Earned cadence mission41 success: ",cadence_frames," Host frames / ",cadence_elapsed_us/1000,"ms; controlled/fire ",controlled_frames,"/",firing_frames," strafes ",strafe_frames," throttle samples ",throttle_frames," result416-420 -> living42 pools ",living.player.vitals,"; no mission42 escape or successor save")

func root_press(code: Key) -> void:
	DesktopPilot.press(root,code)

func acknowledge_cadence_page(text_id: int,voice_id: int,label: String) -> bool:
	resume_application_focus();app.present_session();await process_frame
	var before: Dictionary=session_dialogue()
	check(before.get("text_id")==text_id and before.get("voice_event_id")==voice_id,"Earned "+label+" lost its ordered text or voice")
	if failures:return false
	if label=="result":await capture_free_application("void41-cadence-result-"+str(text_id))
	root_press(KEY_ENTER);await process_frame
	check(session_dialogue()!=before,"Root Enter did not acknowledge earned "+label)
	return failures==0

func session_dialogue() -> Dictionary:
	return observed_dialogue(app.session)

func cadence_host_step(input: Dictionary,observation: RefCounted=null) -> bool:
	resume_application_focus()
	var delta_us: int=cadence_delta_us(cadence_frames)
	if observation==null:observation=PilotObservation.new(app.session)
	check(observation.matches(app.session),"Earned cadence planned input from an expired observation")
	if failures:return false
	var before: Dictionary=observation.read(app.session);var controlling: bool=app.session.can_control()
	var delivered: Dictionary=DesktopPilot.apply(app,root,input,delta_us,observation)
	check(not delivered.has("error"),str(delivered.get("error","")))
	if failures:return false
	if controlling:
		check(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,"Root pilot sample mismatch: expected "+str(input)+" delivered "+str(delivered))
		if failures:return false
		controlled_frames+=1
		if input.fire:
			var eligible: Array=EscortTargets.select_ids(before.encounter.combat.actors.filter(func(actor):return actor.actor_id!=0))
			check(input.get("target",-1) in eligible or input.get("free_fire",false),"Earned aimed primary input lacked an actual living active hostile")
			if failures:return false
			firing_frames+=1
		if input.strafe!=0:strafe_frames[int(input.strafe)]+=1
		var level:=roundi(float(input.throttle)*10.0);throttle_frames[level]=int(throttle_frames.get(level,0))+1
	now_us+=delta_us;app._selected40_tick(now_us)
	if app._transition_failed:check(false,app.status.text);return false
	if app.session==null:check(false,"Earned cadence lost its Host session");return false
	var after: Dictionary=app.session.snapshot()
	check_cadence_step(int(before.elapsed_ms),int(after.elapsed_ms),now_us-delta_us,delta_us)
	check(not after.input.secondary_requested,"Cadence Host invented a paid secondary request")
	for shot in after.encounter.get("primary_fire",{}).get("weapons",[]):
		if not shot.result.get("fired",false):continue
		check(controlling and input.fire and delivered.held.fire and after.input.primary_held,"Earned native shot bypassed ordinary root primary input")
		var mounts: Array=after.encounter.primaries.guns.filter(func(gun):return gun.mount_id==shot.mount_id)
		check(mounts.size()==1 and mounts[0].projectiles.slots.any(func(slot):return slot!=null),"Earned native fired event lacked its mounted live projectile")
		emitted_primary_shots+=1
		print("Earned actual primary emission ",emitted_primary_shots," at ",after.elapsed_ms,"ms; mount ",shot.mount_id," item ",shot.item_id," target ",input.get("target",-1),"; trigger sample, not a hit claim")
	if controlling and app.session.can_control():check(after.input.commands.is_equal_approx(input.commands) and after.input.primary_held==input.fire and is_equal_approx(float(after.throttle),float(input.throttle)),"Native pilot sample mismatch: expected "+str(input)+" consumed "+str(after.input)+" throttle "+str(after.throttle))
	cadence_frames+=1;cadence_elapsed_us+=delta_us;cadence_kinds[delta_us]=true
	return failures==0

func cadence_delta_us(index: int) -> int:
	return CADENCE_US[index%CADENCE_US.size()]

func check_cadence_step(before_ms: int,after_ms: int,_start_us: int,delta_us: int) -> void:
	check(after_ms-before_ms==delta_us/1000,"Cadence Host dropped or accumulated simulation time")

func check_cadence_coverage() -> void:
	check(cadence_kinds.size()==CADENCE_US.size(),"Earned battle did not exercise every variable interval")

func cadence_capture_label(label: String) -> String:return label

func capture_free_application(label: String) -> void:
	# The unchanged earned prefix is necessary, but has no new capture claim.
	if label=="void41-arrival":await super.capture_free_application(cadence_capture_label("void41-cadence-earned-entry"))
	elif label.begins_with("void41-cadence-"):await super.capture_free_application(cadence_capture_label(label))
