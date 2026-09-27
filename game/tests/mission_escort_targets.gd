extends SceneTree
## Synthetic observation contract only: no native world, earned progress,
## actor mutation or claim that the full application battle has passed.
const Targets=preload("res://tests/fixtures/mission_escort_targets.gd")
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("verify")

func verify() -> void:
	var actors: Array=[make_actor(0,Vector3.ZERO),make_actor(1,Vector3(0,0,100000)),make_actor(2,Vector3(3000,0,150000)),make_actor(3,Vector3(0,0,1000),100,false),make_actor(4,Vector3(0,0,2000),100,true,false),make_actor(5,Vector3(0,0,3000),0)]
	var original: Array=actors.duplicate(true)
	check(Targets.select_ids([]).is_empty(),"Empty observation invented a target")
	check(Targets.select_ids(actors)==[1,2],"Distant living fighters were hidden, or escort/friendly/inactive/dead actors were selected")
	check(actors==original,"Target selection changed the observed actor array")
	var state:=observation(actors);var pilot:=Pilot.new()
	var approach: Dictionary=pilot.controls_at_time(state,417.0,Targets.select_ids(actors),true)
	check(approach.target==1,"Timed pilot did not select the closest allowed interception")
	check(approach.throttle==1.0 and not approach.fire and approach.strafe==0.0,"Distant interception fired out of range or failed to approach")
	check(pilot.previous_observed_ms==417.0,"Interception did not use the actual observation time")
	check(actors==original,"Timed interception mutated the input actors")
	var threatened: Array=actors.duplicate(true);threatened[2].position=Vector3(19999,0,0)
	check(Targets.select_ids(threatened)==[2],"A nearby escort threat did not take priority over remote fighters")
	threatened[2].position=Vector3(20000,0,0)
	check(Targets.select_ids(threatened)==[1,2],"The strict proximity edge suppressed all interception candidates")
	check(Targets.select_ids(actors.slice(1))==[1,2],"Missing escort suppressed living hostile candidates")
	var defeated: Array=actors.duplicate(true);defeated[1].vitals.hull=0;defeated[2].active=false
	check(Targets.select_ids(defeated).is_empty(),"Finished hostiles kept the test pilot fighting")
	var close: Array=actors.duplicate(true);close[1].position=Vector3(0,0,5000)
	var close_before: Array=close.duplicate(true);var close_pilot:=Pilot.new()
	check(Targets.select_ids(close)==[1],"Close living target was lost to the remote fighter")
	var first: Dictionary=close_pilot.controls_at_time(observation(close),4000.0,Targets.select_ids(close),true)
	var second: Dictionary=close_pilot.controls_at_time(observation(close),5000.0,Targets.select_ids(close),true)
	check(first.target==1 and first.fire and first.throttle==0.0 and first.strafe==1.0,"Close observed target did not produce firing, stopped throttle and first evasive direction")
	check(second.target==1 and second.fire and second.throttle==0.0 and second.strafe==-1.0,"Later observation did not produce the opposite evasive direction")
	check(close_pilot.previous_observed_ms==5000.0,"Close steering used a tick instead of observed elapsed time")
	check(close==close_before and actors==original,"Engagement samples mutated their observations")
	print("Escort interception: ",checks," checks; ",failures," failures; distant approach and close timed fire/evasion are synthetic observations, not an earned battle")
	quit(0 if failures==0 else 1)

func make_actor(id: int,position: Vector3,hull:=100,hostile:=true,active:=true) -> Dictionary:
	return {"actor_id":id,"position":position,"vitals":{"hull":hull},"hostile":hostile,"active":active}

func observation(actors: Array) -> Dictionary:
	return {"player_pose":Transform3D.IDENTITY,"encounter":{"combat":{"actors":actors},"primaries":{"guns":[{"projectiles":{"weapon":{"speed_units_per_millisecond":40.0}}}]}}}

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr(message)
