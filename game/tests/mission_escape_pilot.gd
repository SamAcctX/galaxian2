extends "res://tests/mission_normal_return.gd"
## Detached component approach, NOT an earned replay. The inherited setup
## runs the real cuts/result in one Host; only the initial approach pose is
## placed here. Controls, gun damage and enemy combat remain native.
const EscapePilot=preload("res://tests/fixtures/void_escape_pilot.gd")
var pilot_now:=1000000
var delivered_strafe:=0.0

func verify_retained_flight() -> void:
	var target: Dictionary=active.combat_owner().actor_snapshot(0)
	active=active.fork_for_frame()
	active._pose=Transform3D(Basis.IDENTITY,target.body_pose.origin+Vector3(1000,2000,-25000))
	active._pilot.angular_units=Vector2.ZERO;active._pilot.lateral_units_per_millisecond=0
	if not present():return
	if not application.session.rebase_time(pilot_now):check(false,application.session.error);return
	var world: RefCounted=active.initialized_world_owner()
	var pilot:=EscapePilot.new()
	var before: Dictionary=application.session.snapshot()
	var positive: Dictionary=pilot.controls(before,0,true)
	var negative: Dictionary=pilot.controls(before,10,true)
	check(positive.strafe==1.0 and negative.strafe==-1.0,"Close approach lost either evasive direction")
	check(pilot.controls(before,0,false)=={"commands":Vector2.ZERO,"fire":false,"throttle":0.0,"strafe":0.0},"Blocked cinematic accepted pilot controls")
	check(application.session.snapshot()==before,"Reading pilot controls mutated the live flight")
	for input in [positive,negative]:
		if not EscapePilot.advance(step_pilot,input):return
		check(delivered_strafe==input.strafe,"Escape adapter dropped the combat pilot's lateral input")
		check(active.snapshot().pilot.lateral_rate*input.strafe<0.0,"Forwarded evasive input did not reach native lateral motion")
	if failures:return
	await capture("escape-pilot-approach")
	var fired:=false
	for tick in 600:
		var state: Dictionary=application.session.snapshot()
		if state.encounter.combat.actors[0].vitals.hull<=0:break
		var input: Dictionary=pilot.controls(state,tick,application.session.can_control())
		fired=fired or input.fire
		if not EscapePilot.advance(step_pilot,input):return
		if tick%25==0:await process_frame
	var after: Dictionary=application.session.snapshot()
	check(fired and after.encounter.combat.actors[0].vitals.hull<=0,"Pilot failed to destroy the disabled freighter with the installed gun")
	check(after.player.vitals.hull>0 and active.initialized_world_owner()==world and after.campaign_cursor==42,"Approach replaced its world, advanced the story or lost the player")
	await capture("escape-pilot-freighter-destroyed")
	print("Detached escape pilot: hull ",after.player.vitals," freighter ",after.encounter.combat.actors[0].vitals.hull)
	if not failures and verify_escape_evasion(pilot):await verify_piloted_escape(pilot,world)
	application.free()

## The radio wait is still dangerous flight. Observe both directions in the
## actual motion owner after the native kill, not only in a control dictionary.
func verify_escape_evasion(pilot: RefCounted) -> bool:
	var observations:=[]
	for tick in [0,10]:
		var before: Dictionary=application.session.snapshot()
		var input: Dictionary=pilot.controls(before,tick,true)
		var read_only: bool=application.session.snapshot()==before
		if not EscapePilot.advance(step_pilot,input):return false
		observations.append({"tick":tick,"input":input,"read_only":read_only,
			"throttle":application.session.snapshot().throttle,"lateral":active.snapshot().pilot.lateral_rate})
	for observation in observations:
		var direction:=1.0 if observation.tick==0 else -1.0
		check(observation.read_only,"Escape control generation changed the live flight")
		check(observation.input.throttle==1.0 and is_equal_approx(observation.throttle,1.0),"Radio-wait pilot slowed the ship while fighters were still active")
		check(observation.input.strafe==direction and observation.lateral*direction<0.0,"Radio-wait evasion did not reach native lateral motion")
	return failures==0

## Exercise the same input-only pilot after the kill, not the inherited
## component's detached portal-contact stimulus. The initial approach above
## is still detached: this is not the earned campaign acceptance run.
func verify_piloted_escape(pilot: RefCounted,world: RefCounted) -> void:
	var seen:={};var opened:=false;var departure_pools:={}
	for tick in 2400:
		var state: Dictionary=application.session.snapshot()
		if application.session.status=="normal_space_return_required":
			check(opened and seen.has("explosion") and seen.has("fade"),"Piloted escape bypassed its portal, explosion or fade")
			check(active.initialized_world_owner()==world and state.campaign_cursor==42 and state.player.vitals==departure_pools,"Piloted escape replaced its world, advanced early or changed protected departure pools")
			print("Detached input-only escape reached normal-space boundary at tick ",tick," pools ",state.player.vitals)
			return
		if application.session.status!="running":check(false,"Piloted escape stopped: "+application.session.status);return
		var escape: Dictionary=state.escape
		var phase: int=int(escape.phase)
		if phase==6 and not opened:
			opened=true
			var radio: RefCounted=active.encounter_owner().radio_owner()
			check(state.encounter.combat.actors[0].vitals.hull<=0 and radio.event_state(6).playback_finished and radio.event_state(7).playback_finished,"Piloted exit opened before the kill and both radio lines finished")
			await capture("escape-pilot-exit-open")
		if phase==7:
			if departure_pools.is_empty():departure_pools=state.player.vitals.duplicate(true)
			check(not application.session.can_control(),"Explosion cinematic accepted flight controls")
			if escape.explosion_elapsed_ms>4000 and not seen.has("explosion"):
				seen.explosion=true;await capture("escape-pilot-mothership-explosion")
			if escape.fade_requested and escape.fade.elapsed_ms>=2000 and not seen.has("fade"):
				seen.fade=true;await capture("escape-pilot-fade")
		var input: Dictionary=pilot.controls(state,tick,application.session.can_control())
		if tick%100==0:
			print("Detached escape tick ",tick," phase ",phase," portal distance ",state.player_pose.origin.distance_to(state.portal.position)," pools ",state.player.vitals," input ",input)
			await process_frame
		if failures or not EscapePilot.advance(step_pilot,input):return
	check(false,"Input-only pilot never completed the native portal escape")

func step_pilot(commands: Vector2,fire: bool,throttle: float,strafe:=0.0) -> bool:
	delivered_strafe=strafe
	# Match the earned application's focus restoration after yielded GPU frames.
	application._focused=true
	if application.session._pauses.has("focus"):
		if not application.session.set_pause("focus",false,pilot_now) or not application.session.rebase_time(pilot_now):check(false,application.session.error);return false
	application.refresh_render_mode()
	# As in the earned driver, issue throttle actions only during player flight.
	# Portal departure and the following cinematic reject flight actions.
	if application.session.can_control():
		for adjustment in 10:
			var current: float=application.session.snapshot().throttle
			if absf(current-throttle)<0.01:break
			if not application.session.action("throttle_up" if current<throttle else "throttle_down"):check(false,application.session.error);return false
	pilot_now+=100000
	if not application.session.step(pilot_now,commands,fire,false,strafe):check(false,application.session.error);return false
	active=application.session.flight_owner()
	application.present_session()
	check(active.player_owner().snapshot().vitals.hull>0,"Detached approach pilot died under native combat")
	return failures==0

func capture(label: String) -> void:
	if label.begins_with("escape-pilot-") and DisplayServer.get_name()!="headless":await capture_normal_scene(application,label)
