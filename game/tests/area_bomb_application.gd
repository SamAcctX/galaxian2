extends "res://tests/conventional_secondary_application.gd"
## Real paid fitting and R-key launch/manual detonation. The inherited route
## docks and reopens the actual save, preserving the earned passenger job.
const BombRules=preload("res://src/content/emp_bombs_definitions.gd")

func secondary_kind() -> int:return 7
func secondary_resumed() -> bool:return OS.get_environment("GOF2_AMR_RESUMED")=="1"

func fire_secondary_input() -> bool:
	var initial: Dictionary=app.session.snapshot()
	var candidates: Array=initial.encounter.combat.actors.filter(func(actor):return actor.active and actor.population_group=="freighter" and actor.vitals.hull>0)
	candidates.sort_custom(func(a,b):return a.pose.origin.distance_squared_to(initial.player_pose.origin)<b.pose.origin.distance_squared_to(initial.player_pose.origin))
	if candidates.is_empty():check(false,"The generated flight has no living AMR target");return false
	var id:=int(candidates[0].actor_id);var started:=now_us;var next_yield:=now_us;var next_log:=now_us
	var captured:=false;var launched_us:=-1;var detonation_us:=-1;var manual:=false;var target_hit:={}
	var declaration:=BombRules.declaration(_secondary_item)
	while now_us-started<240000000:
		var state: Dictionary=app.session.snapshot();var actor: Dictionary=state.encounter.combat.actors[id]
		if app.session.flight_owner().death_active():check(false,"The AMR pilot died before detonation");return false
		var distance: float=actor.pose.origin.distance_to(state.player_pose.origin)
		var gun: Dictionary=state.encounter.secondaries.guns[0];var bomb: Dictionary=gun.bomb
		var input:={"commands":PiratePilot.Steering.steering_toward(state.player_pose,actor.pose.origin),"throttle":1.0 if distance>15000.0 else 0.0,"fire":false,"strafe":0.0}
		var key: InputEventKey
		var ready: bool=bomb.elapsed_ms>bomb.weapon.interval_ms and bomb.shot.is_empty()
		var aimed: bool=state.player_pose.basis.z.angle_to(actor.pose.origin-state.player_pose.origin)<0.1
		var trigger: bool=launched_us<0 and ready and distance<16000.0 and aimed
		if captured and not manual and bomb.shot.get("phase")=="flying":trigger=true;manual=true
		if trigger:
			resume_application_focus();key=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true;app._unhandled_input(key)
			check(app.session._secondary_requested,"R did not queue the selected AMR launcher")
		if not pirate_step(input):return false
		if key!=null:key.pressed=false;app._unhandled_input(key)
		var after: Dictionary=app.session.snapshot();var current: Dictionary=after.encounter.secondaries.guns[0]
		if launched_us<0 and after.encounter.secondaries.launches==1:launched_us=now_us
		if not captured and launched_us>=0 and now_us-launched_us>=300000:
			check(current.bomb.shot.get("phase")=="flying" and current.bomb.visuals.models.size()==2,"AMR disappeared before its manual input or lost body/glow animation")
			await capture_free_application("amr-live-body")
			var paused: Dictionary=after.encounter.secondaries.duplicate(true)
			check(app.session.set_pause("user",true,now_us),app.session.error);now_us+=1000000
			check(app.session.step(now_us) and app.session.snapshot().encounter.secondaries==paused,"Pause advanced the AMR projectile or its original animation")
			check(app.session.set_pause("user",false,now_us),app.session.error)
			captured=true
		for event in after.encounter.secondary_events:
			if event.action!="detonated":continue
			check(manual and event.ammunition_consumed==0,"AMR did not use its second input or spent a second round")
			var hits: Array=event.normal_hits.filter(func(hit):return hit.target.group=="npc" and hit.target.index==id)
			check(hits.size()==1 and hits[0].result.accepted and hits[0].result.before!=hits[0].result.after,"AMR manual pulse did not damage the real nearby target")
			if not hits.is_empty():target_hit=hits[0]
			detonation_us=now_us
			print("AMR radius hit: ",{"item":_secondary_item,"target":id,"result":target_hit,"nearby":event.normal_hits.size(),"elapsed":(now_us-started)/1000000.0})
		if detonation_us>=0 and now_us-detonation_us>=400000:
			check(current.detonation.effect.active and current.detonation.effect_type==0 and current.detonation.effect.models.size()==2,"AMR omitted its original two-layer explosion")
			check(after.encounter.secondaries.launches==1 and not target_hit.is_empty(),"The manual detonation launched another bomb or lost its target hit")
			var history: Array=app.session.flight_audio.snapshot().history
			for sound in [declaration.launch_sound,declaration.burst_sound]:
				check(history.any(func(event):return event.get("source_id")==sound and event.get("item_id")==_secondary_item),"AMR omitted its original launch or explosion sound")
			await capture_free_application("amr-manual-explosion")
			return failures==0
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("AMR pilot: ",{"elapsed":(now_us-started)/1000000.0,"distance":distance,"launched":launched_us>=0,"manual":manual,"hit":not target_hit.is_empty()})
			next_log=now_us+10000000
	check(false,"The paid AMR flight did not complete its manual radius hit");return false
