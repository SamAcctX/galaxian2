extends "res://tests/mission_escape_sequence.gd"
## Native flight from the existing detached entry, not the earned Host route.
## No pose, pools, actors, clocks or outcomes are changed to help the pilot.
const FlightFrame=preload("res://src/simulation/mission_flight_frame.gd")
const Pilot=preload("res://tests/fixtures/mission_escort_pilot.gd")
const Targets=preload("res://tests/fixtures/mission_escort_targets.gd")
const Tactics=preload("res://tests/fixtures/mission_escort_tactics.gd")
const Steering=preload("res://tests/fixtures/expedition_flight_pilot.gd")
const CADENCE_MS=[4,17,31,9,67]

func frame_delta_ms(index: int) -> int:
	return CADENCE_MS[index%CADENCE_MS.size()]

func observe_phase(_frame: RefCounted,_phase: int) -> void:
	pass

func finish_component(_frame: RefCounted,_frames: int) -> void:
	pass

func verify_component(world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var parent:=FlightFrame.new()
	if not parent.configure(bindings,catalogues,library,context,world,1.0,Vector2i(1280,720)):check(false,parent.error);return
	var initial: Dictionary=parent.snapshot()
	var active: RefCounted=parent.skip_entry()
	if active==null:check(false,parent.error);return
	for page in 3:
		check(active.dialogue().get("text_id")==2038+page,"Detached pilot entry lost its ordinary briefing")
		var next: RefCounted=active.navigate("next")
		if next==null:check(false,active.error);return
		active=next
	if failures:return
	var pilot:=Pilot.new();var tactics:=Tactics.new()
	var frames:=0;var firing:=0;var regroup_frames:=0;var returns:=0
	var emitted:=0
	var strafes:={};var throttles:={};var max_distance:=0.0
	var next_report_ms:=0;var phases:={};var release_reported:=false
	var state: Dictionary=active.snapshot()
	print("Detached escort entry pools ",state.player.vitals,"; no earned-prefix or Host-input claim")
	while state.elapsed_ms<300000:
		check(state.player.vitals.hull>0 and state.encounter.combat.actors[0].vitals.hull>0,"Detached escort pilot lost a living participant at "+str(state.elapsed_ms)+"ms")
		if failures:return
		if state.dialogue.visible:break
		var phase: int=state.encounter.sequence.phase
		if not phases.has(phase):
			print("Detached escort phase ",phase," at ",state.elapsed_ms,"ms; fire ",firing," pools ",state.player.vitals)
			observe_phase(active,phase)
		phases[phase]=true
		var input:={"commands":Vector2.ZERO,"fire":false,"throttle":1.0,"strafe":0.0}
		if not state.encounter.sequence.input_blocked:
			var threats: Array=Targets.select_ids(state.encounter.combat.actors)
			if not threats.is_empty():input=pilot.controls_at_time(state,float(state.elapsed_ms),threats,true)
			else:
				var escort: Dictionary=state.encounter.combat.actors[0]
				input.commands=Steering.steering_toward(state.player_pose,escort.position+Vector3(0,1500,-3000))
				input.throttle=1.0 if state.player_pose.origin.distance_to(escort.position)>5000.0 else 0.3
			if emitted==0:input=Pilot.request_trigger_sample(state,input)
			var was_regrouping: bool=tactics.regrouping
			input=tactics.apply(state,input)
			if tactics.regrouping:regroup_frames+=1
			if was_regrouping and not tactics.regrouping:returns+=1
			max_distance=maxf(max_distance,tactics.escort_distance)
			if input.fire:
				var eligible: Array=Targets.select_ids(state.encounter.combat.actors.filter(func(actor):return actor.actor_id!=0))
				check(input.get("target",-1) in eligible,"Detached pilot fired without an actual living active hostile")
				firing+=1
			if input.strafe!=0:strafes[input.strafe]=true
			throttles[roundi(input.throttle*10.0)]=true
			if phase==5 and not release_reported:
				release_reported=true
				print("Detached release pose ",state.player_pose," input ",input," escort distance ",tactics.escort_distance," regroup ",tactics.regrouping)
				for actor in state.encounter.combat.actors:
					if actor.actor_id<=0:continue
					var offset: Vector3=actor.position-state.player_pose.origin
					print("Detached release target ",actor.actor_id," range ",offset.length()," angle ",state.player_pose.basis.z.angle_to(offset)," hull ",actor.vitals.hull," active ",actor.active," hostile ",actor.hostile)
			if phase==5 and input.get("target",-1)>0:
				var offset: Vector3=state.encounter.combat.actors[input.target].position-state.player_pose.origin
				print("Detached release control ",state.elapsed_ms,"ms target ",input.target," angle ",state.player_pose.basis.z.angle_to(offset)," commands ",input.commands," fire ",input.fire)
		if state.elapsed_ms>=next_report_ms:
			next_report_ms=state.elapsed_ms+10000
			print("Detached escort ",state.elapsed_ms,"ms phase ",phase," pools ",state.player.vitals," fire ",firing," target ",input.get("target",-1)," range ",input.get("distance",-1)," regroup ",tactics.regrouping," retreat ",tactics.retreating," distance ",tactics.escort_distance," max ",max_distance," completed returns ",returns)
		var delta: int=frame_delta_ms(frames)
		var next: RefCounted=active.evaluate(delta,input.commands,input.throttle,input.fire,false,Vector2i(1280,720),input.strafe,false,-1,true)
		if next==null:check(false,active.error);return
		var observed: Dictionary=next.snapshot()
		check(observed.elapsed_ms==state.elapsed_ms+delta,"Detached pilot lost its observed native cadence")
		for shot in observed.encounter.get("primary_fire",{}).get("weapons",[]):
			if not shot.result.get("fired",false):continue
			check(input.fire and observed.input.primary_held,"Native shot lacked ordinary held primary input")
			var mounts: Array=observed.encounter.primaries.guns.filter(func(gun):return gun.mount_id==shot.mount_id)
			check(mounts.size()==1 and mounts[0].projectiles.slots.any(func(slot):return slot!=null),"Native fired event lacked its mounted live projectile")
			emitted+=1
			print("Detached actual primary emission ",emitted," at ",observed.elapsed_ms,"ms; mount ",shot.mount_id," item ",shot.item_id," target ",input.get("target",-1),"; trigger while acquiring, not a hit claim")
		active=next;state=observed;frames+=1
		if failures:return
	var result: Dictionary=state
	check(result.dialogue.get("text_id")==2047 and result.campaign_cursor==41,"Detached escort did not reach the native living-freighter result")
	check(regroup_frames>0 and returns>0,"Native motion did not exercise and complete spatial regrouping")
	check(max_distance<80000.0,"Native regroup still allowed a runaway separation: "+str(max_distance))
	check(firing>0,"Detached pilot omitted real selected-target firing")
	check(emitted>0,"Detached primary input never emitted a native mounted projectile")
	check(strafes.has(-1.0) and strafes.has(1.0),"Detached pilot omitted an evasive direction: "+str(strafes))
	check(throttles.has(0) and throttles.has(10),"Detached pilot omitted zero/full throttle: "+str(throttles))
	for phase in [1,2,3,4,5]:check(phases.has(phase),"Detached pilot missed a native ambush shot")
	check(parent.snapshot()==initial and result.equipment==initial.equipment,"Detached pilot changed its retained parent or inventory")
	print("Detached escort result ",result.dialogue.get("text_id",-1)," at ",result.elapsed_ms,"ms; ",frames," frames, fire ",firing," emitted ",emitted," regroup ",regroup_frames," returns ",returns," max distance ",max_distance," pools ",result.player.vitals,"; not earned Host survival")
	if not failures:finish_component(active,frames)
