extends SceneTree
## Analytic observations, not a simulated or earned mission. The independent
## heading oracle describes a target travelling laterally at a known speed.
const Combat=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const Escape=preload("res://tests/fixtures/void_escape_pilot.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func run() -> void:
	verify_cadences()
	verify_observation_gaps()
	verify_escape_wait()
	verify_legacy()
	print("Flight pilot timing: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func observation(elapsed_ms: float) -> Dictionary:
	var position:=Vector3(elapsed_ms*0.8,0,12000)
	return {"player_pose":Transform3D.IDENTITY,"portal":{"position":Vector3(0,0,20000)},
		"encounter":{"combat":{"actors":[
			{"actor_id":0,"position":position,"vitals":{"hull":100}},
			{"actor_id":1,"position":position,"vitals":{"hull":100}}]},
			"primaries":{"guns":[{"projectiles":{"weapon":{"speed_units_per_millisecond":20.0}}}]}}}

func expected_heading(state: Dictionary,velocity: float) -> Vector2:
	var position: Vector3=state.encounter.combat.actors[0].position
	var intercept_x:=position.x+velocity*minf(position.length()/20.0,2000.0)
	return Vector2(0,sqrt(minf(2.0*atan2(intercept_x,position.z),1.0)))

func verify_cadences() -> void:
	for cadence in ["100ms","144Hz","variable"]:
		var combat:=Combat.new();var escape:=Escape.new()
		var elapsed_us:=0;var frame:=0;var directions:={}
		while elapsed_us<=2200000:
			var elapsed_ms:=float(elapsed_us/1000)
			var state:=observation(elapsed_ms);var before:=state.duplicate(true)
			var expected:=expected_heading(state,0.0 if frame==0 else 0.8)
			var direction:=1.0 if int(elapsed_ms/1000.0)%2==0 else -1.0
			var combat_input:=combat.controls_at_time(state,elapsed_ms,[1])
			var escape_input:=escape.controls_at_time(state,elapsed_ms,true)
			for input in [combat_input,escape_input]:
				check(input.commands.distance_to(expected)<0.00001,cadence+" aim used a frame count or upcoming step")
				check(input.strafe==direction and input.throttle==1.0,cadence+" changed elapsed evasion or approach speed")
				var angle:=atan2(state.encounter.combat.actors[0].position.x+(0.0 if frame==0 else 0.8)*state.encounter.combat.actors[0].position.length()/20.0,12000.0)
				check(input.fire==(angle<0.15),cadence+" firing ignored the predicted heading")
			check(combat_input.target==1 and escape_input.target==0 and state==before,cadence+" changed its target or mutated the observation")
			directions[direction]=true
			frame+=1
			if cadence=="144Hz":elapsed_us=int(round(float(frame)*1000000.0/144.0))
			else:elapsed_us+=100000 if cadence=="100ms" else [4000,17000,31000,9000,67000][(frame-1)%5]
		check(directions.size()==2,cadence+" did not cover both one-second evasive directions")
		print(cadence," analytic observations: ",frame)

func verify_observation_gaps() -> void:
	var pilot:=Combat.new()
	pilot.controls_at_time(observation(0),0,[1])
	pilot.controls_at_time(observation(100),100,[1])
	var gap:=observation(1100)
	var input:=pilot.controls_at_time(gap,1100,[1])
	check(input.commands.distance_to(expected_heading(gap,0.8))<0.00001,"Gap used only the last render step for target velocity")
	check(pilot.controls_at_time(gap,1100,[1])==input,"Repeated observation lost its predicted aim")
	var empty:=observation(1200)
	empty.encounter.combat.actors[1].vitals.hull=0
	check(pilot.controls_at_time(empty,1200,[1]).target==-1,"No-target sample fabricated a target")
	var returned:=observation(2000)
	check(pilot.controls_at_time(returned,2000,[1]).commands.distance_to(expected_heading(returned,0.8))<0.00001,"Empty target interval replaced the last actual observation time")
	var switched:=observation(2100)
	check(pilot.controls_at_time(switched,2100,[0]).commands.distance_to(expected_heading(switched,0.0))<0.00001,"New target inherited another target's velocity")
	var restarted:=observation(50)
	check(pilot.controls_at_time(restarted,50,[0]).commands.distance_to(expected_heading(restarted,0.0))<0.00001,"Restarted timeline retained a future velocity")
	var resumed:=observation(150)
	check(pilot.controls_at_time(resumed,150,[0]).commands.distance_to(expected_heading(resumed,0.8))<0.00001,"Restarted timeline could not observe motion again")

func verify_escape_wait() -> void:
	var pilot:=Escape.new()
	pilot.controls_at_time(observation(0),0,true)
	var blocked:=observation(1000);var before:=blocked.duplicate(true)
	check(pilot.controls_at_time(blocked,1000,false)=={"commands":Vector2.ZERO,"fire":false,"throttle":0.0,"strafe":0.0},"Blocked escape accepted a live control")
	var resumed:=observation(2000)
	check(pilot.controls_at_time(resumed,2000,true).commands.distance_to(expected_heading(resumed,0.8))<0.00001,"Blocked interval corrupted the next target velocity")
	check(blocked==before,"Blocked escape mutated its observation")
	for elapsed_ms in [999,1000,1999,2000]:
		var state:=observation(elapsed_ms)
		state.encounter.combat.actors[0].vitals.hull=0
		var original:=state.duplicate(true)
		var input:=pilot.controls_at_time(state,elapsed_ms,true)
		check(input.strafe==(1.0 if elapsed_ms in [999,2000] else -1.0),"Radio wait used combat-call count instead of elapsed evasion")
		check(input.throttle==1.0 and not input.fire and input.commands==Vector2.ZERO and state==original,"Radio wait stopped moving, fired or changed the world")

func verify_legacy() -> void:
	var legacy:=Combat.new();var timed:=Combat.new()
	var old_escape:=Escape.new();var new_escape:=Escape.new()
	for tick in 31:
		var state:=observation(tick*100)
		check(legacy.controls(state,tick,[1])==timed.controls_at_time(state,tick*100,[1]),"Legacy 100ms combat output changed at tick "+str(tick))
		check(old_escape.controls(state,tick,true)==new_escape.controls_at_time(state,tick*100,true),"Legacy 100ms escape output changed at tick "+str(tick))
	var explicit_delta:=Combat.new()
	explicit_delta.controls(observation(0),0,[1])
	var short_step:=observation(7)
	check(explicit_delta.controls(short_step,11,[1],false,7.0).commands.distance_to(expected_heading(short_step,0.8))<0.00001,"Legacy explicit observation delta stopped working")
