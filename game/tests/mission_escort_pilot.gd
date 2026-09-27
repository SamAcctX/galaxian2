extends SceneTree
## Synthetic selection/lead regression, not native or earned survival.
const Escort=preload("res://tests/fixtures/mission_escort_pilot.gd")
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const Targets=preload("res://tests/fixtures/mission_escort_targets.gd")
const Tactics=preload("res://tests/fixtures/mission_escort_tactics.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var state:=observation();var before: Dictionary=state.duplicate(true)
	var preferred:=Targets.select_ids(state.encounter.combat.actors)
	check(preferred==[1],"Fixture lacks its distant escort-priority target")
	check(not Pilot.new().controls_at_time(state,0.0,preferred,true).fire,"Old distant pursuit unexpectedly has a firing solution")
	var pilot:=Escort.new();var ready:=pilot.controls_at_time(state,0.0,preferred,true)
	check(ready.target==2 and ready.fire,"Distant escort pursuit hid an actual nearby firing solution")
	check(ready.commands==Vector2.ZERO and ready.strafe==1.0,"Opportunity changed the combat pilot's real aim/evasion")
	check(pilot.previous_observed_ms==0.0 and state==before,"Opportunity changed its observation or clock")
	var latched:=Tactics.new();var protected_state: Dictionary=state.duplicate(true)
	protected_state.encounter.combat.actors[0].position=Vector3(0,0,-10000)
	var stopped:=latched.apply(protected_state,ready)
	check(stopped.fire and stopped.target==2 and stopped.throttle==0.0,"Genuine opportunity lost stand-off firing/zero throttle")
	state.elapsed_ms=1000
	var opposite:=pilot.controls_at_time(state,1000.0,preferred,true)
	check(opposite.target==2 and opposite.fire and opposite.strafe==-1.0,"Opportunity lost the opposite elapsed-time evasion")
	var turning:=observation();turning.encounter.combat.actors[2].position=Vector3(12000,0,0)
	turning.encounter.combat.actors[3].position=Vector3(5000,0,18000)
	var turn:=Escort.new().controls_at_time(turning,0.0,preferred,true)
	check(turn.target==3 and not turn.fire,"Nearby aiming did not choose the smaller real turn or invented fire")
	var saturated:=observation()
	saturated.encounter.combat.actors[1].position=Vector3(12000,12000,13000)
	saturated.encounter.combat.actors[2].position=Vector3(0,0,-5000)
	var diagonal:=Pilot.new().controls_at_time(saturated,0.0,[1],true)
	var behind:=Pilot.new().controls_at_time(saturated,0.0,[2],true)
	check(diagonal.commands.length_squared()>behind.commands.length_squared(),"Fixture no longer exposes saturated command ordering")
	var angular:=Escort.new().controls_at_time(saturated,0.0,[1,2],true)
	check(angular.target==1 and not angular.fire,"Clamped commands preferred a rear target over a smaller physical turn")
	var rotated: Dictionary=saturated.duplicate(true)
	var basis:=Basis(Vector3.UP,1.2)*Basis(Vector3.FORWARD,.6)
	rotated.player_pose.basis=basis
	for item in rotated.encounter.combat.actors:item.position=basis*item.position
	var local_bearing:=Escort.new().controls_at_time(rotated,0.0,[1,2],true)
	check(local_bearing.target==1 and local_bearing.commands.is_equal_approx(diagonal.commands),"Opportunity bearing ignored the player's rotated frame")
	var moving:=observation();var measured:=Escort.new();var reference:=Pilot.new()
	measured.controls_at_time(moving,0.0,preferred,true);reference.controls_at_time(moving,0.0,[2],true)
	moving.elapsed_ms=40;moving.encounter.combat.actors[2].position.x=100
	var updated:=measured.controls_at_time(moving,40.0,preferred,true)
	var expected:=reference.controls_at_time(moving,40.0,[2],true)
	check(updated==expected and measured.previous_observed_ms==40.0,"Opportunity lost the target's actual elapsed-time lead")
	var far:=observation();far.encounter.combat.actors[2].position=Vector3(200000,0,18000)
	check(Escort.new().controls_at_time(far,0.0,preferred,true)==Pilot.new().controls_at_time(far,0.0,preferred,true),"No-opportunity case changed established escort pursuit")
	for excluded in ["hostile","active","hull"]:
		var invalid:=observation()
		if excluded=="hull":invalid.encounter.combat.actors[2].vitals.hull=0
		else:invalid.encounter.combat.actors[2][excluded]=false
		var selected:=Escort.new().controls_at_time(invalid,0.0,Targets.select_ids(invalid.encounter.combat.actors),true)
		check(selected.target==1 and not selected.fire,"Opportunity selected an ineligible "+excluded+" target")
	var empty:=observation();empty.encounter.combat.actors.resize(1)
	var idle:=Escort.new().controls_at_time(empty,0.0,[],true)
	check(idle.target==-1 and not idle.fire,"Missing hostiles fabricated a firing target")
	protected_state.player.vitals.hull=60
	check(not latched.apply(protected_state,opposite).fire and latched.retreating,"Opportunity bypassed the damage reserve")
	var distant:=observation();var bounded:=Tactics.new().apply(distant,ready)
	check(bounded.target==-1 and not bounded.fire,"Opportunity bypassed spatial regrouping")
	check(before==observation(),"Regression cases corrupted their detached original observation")
	print("Escort opportunity pilot: ",checks," checks; ",failures," failures; synthetic observations only")
	quit(1 if failures else 0)

func observation() -> Dictionary:
	return {"elapsed_ms":0,"player_pose":Transform3D.IDENTITY,"player":{"vitals":{"hull":91}},"encounter":{"combat":{"actors":[actor(0,Vector3(100000,0,50000),false),actor(1,Vector3(100000,0,40000)),actor(2,Vector3(0,0,18000)),actor(3,Vector3(200000,0,50000))]},"primaries":{"guns":[{"projectiles":{"weapon":{"speed_units_per_millisecond":20.0}}}]}}}
func actor(id: int,position: Vector3,hostile:=true) -> Dictionary:
	return {"actor_id":id,"position":position,"hostile":hostile,"active":true,"vitals":{"hull":100}}
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr(message)
