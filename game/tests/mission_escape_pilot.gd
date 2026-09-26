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
	application.free()

func step_pilot(commands: Vector2,fire: bool,throttle: float,strafe:=0.0) -> bool:
	delivered_strafe=strafe
	# Match the earned application's focus restoration after yielded GPU frames.
	application._focused=true
	if application.session._pauses.has("focus"):
		if not application.session.set_pause("focus",false,pilot_now) or not application.session.rebase_time(pilot_now):check(false,application.session.error);return false
	application.refresh_render_mode()
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
