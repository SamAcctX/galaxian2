extends "res://tests/mission_escape_pilot.gd"
## Detached short flight in the real session, not a complete battle or earned
## replay. Reuse the component's prepared mission42 and only place its approach.
var sample_step_us:=100000

func verify_retained_flight() -> void:
	var retained: RefCounted=active
	var retained_state: Dictionary=retained.snapshot().duplicate(true)
	var target: Dictionary=retained.combat_owner().actor_snapshot(0)
	active=retained.fork_for_frame()
	active._pose=Transform3D(Basis.IDENTITY,target.body_pose.origin+Vector3(1000,2000,-25000))
	active._pilot.angular_units=Vector2.ZERO
	active._pilot.lateral_units_per_millisecond=0
	if not present():return
	pilot_now=1000000
	if not application.session.rebase_time(pilot_now):check(false,application.session.error);return
	# Change cadence while continuing this living world. A presentation owner
	# must never be rewound to an older component frame for the next sample.
	for cadence in ["100ms","144Hz","variable"]:
		var initial: Dictionary=application.session.snapshot()
		var start_ms: int=int(initial.elapsed_ms)
		var pilot:=EscapePilot.new()
		var elapsed_us:=0;var frame:=0;var captured:=false
		var directions:={};var native_directions:={}
		while elapsed_us<2200000:
			var state: Dictionary=application.session.snapshot()
			var before: Dictionary=state.duplicate(true)
			var elapsed_ms:=float(state.elapsed_ms-start_ms)
			var input: Dictionary=pilot.controls_at_time(state,elapsed_ms,application.session.can_control())
			check(application.session.snapshot()==before,"Timed pilot changed its live observation")
			check(input.strafe==(1.0 if int(elapsed_ms/1000.0)%2==0 else -1.0),cadence+" live pilot lost elapsed evasion")
			directions[input.strafe]=true
			var previous_us:=elapsed_us
			frame+=1
			if cadence=="144Hz":elapsed_us=int(round(float(frame)*1000000.0/144.0))
			else:elapsed_us+=100000 if cadence=="100ms" else [4000,17000,31000,9000,67000][(frame-1)%5]
			sample_step_us=elapsed_us-previous_us
			if not EscapePilot.advance(step_timed_pilot,input):return
			var after: Dictionary=application.session.snapshot()
			check(int(after.elapsed_ms)-start_ms==int(elapsed_us/1000),cadence+" session used the wrong actual elapsed time")
			check(delivered_strafe==input.strafe,cadence+" adapter dropped elapsed evasion")
			var lateral: float=active.snapshot().pilot.lateral_rate
			if lateral*input.strafe<0.0:native_directions[input.strafe]=true
			if not captured and elapsed_us>=1100000:
				captured=true
				await capture_normal_scene(application,"pilot-timing-"+cadence)
			if frame%32==0:await process_frame
		var final: Dictionary=application.session.snapshot()
		check(directions.size()==2 and native_directions.size()==2,cadence+" did not deliver both evasive directions to native motion")
		check(final.player_pose!=initial.player_pose and final.campaign_cursor==42 and final.player.vitals.hull>0,cadence+" did not retain living native flight")
		check(retained.snapshot()==retained_state,cadence+" mutated the retained component parent")
		print("Timed live pilot ",cadence,": ",frame," frames / ",final.elapsed_ms-start_ms,"ms; native directions ",native_directions.keys()," pools ",final.player.vitals)
		if failures:return
	application.free()

func step_timed_pilot(commands: Vector2,fire: bool,throttle: float,strafe: float) -> bool:
	delivered_strafe=strafe
	application._focused=true
	if application.session._pauses.has("focus"):
		if not application.session.set_pause("focus",false,pilot_now) or not application.session.rebase_time(pilot_now):check(false,application.session.error);return false
	application.refresh_render_mode()
	if application.session.can_control():
		for adjustment in 10:
			var current: float=application.session.snapshot().throttle
			if absf(current-throttle)<0.01:break
			if not application.session.action("throttle_up" if current<throttle else "throttle_down"):check(false,application.session.error);return false
	pilot_now+=sample_step_us
	if not application.session.step(pilot_now,commands,fire,false,strafe):check(false,application.session.error);return false
	active=application.session.flight_owner()
	application.present_session()
	check(active.player_owner().snapshot().vitals.hull>0,"Timed detached approach lost the player")
	return failures==0

func capture(_label: String) -> void:
	# Only capture the new elapsed-time approach, not the inherited cut setup.
	pass
