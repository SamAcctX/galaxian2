extends SceneTree
## Synthetic policy observations only; survival still requires the earned run.
const Tactics=preload("res://tests/fixtures/mission_escort_tactics.gd")
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("verify")

func verify() -> void:
	var approach:=observation(80,50000.0,0)
	var approach_before: Dictionary=approach.duplicate(true)
	var pilot:=Pilot.new();var tactics:=Tactics.new()
	var sample: Dictionary=pilot.controls_at_time(approach,0.0,[1],true)
	var sample_before: Dictionary=sample.duplicate(true)
	check(tactics.apply(approach,sample)==sample,"Healthy distant approach changed its combat pilot sample")
	check(not tactics.retreating and tactics.initial_hull==80.0,"Pilot did not retain its observed entry hull")
	check(approach==approach_before and sample==sample_before,"Approach policy mutated its inputs")
	var close:=observation(80,18000.0,4000)
	var close_before: Dictionary=close.duplicate(true)
	var close_pilot:=Pilot.new();var stance:=Tactics.new()
	var firing: Dictionary=close_pilot.controls_at_time(close,4000.0,[1],true)
	var firing_before: Dictionary=firing.duplicate(true)
	check(firing.fire and firing.throttle==1.0 and firing.target==1,"Expected a real aligned firing solution before the old close-stop range")
	var stopped:=stance.apply(close,firing)
	check(stopped.fire and stopped.target==1 and stopped.commands==firing.commands,"Stand-off invented firing or changed its actual aim/target")
	check(stopped.throttle==0.0 and stopped.strafe==1.0,"Actual firing did not stop forward throttle while retaining lateral evasion")
	check(close==close_before and firing==firing_before,"Firing policy mutated its observation or pilot sample")
	var later:=close.duplicate(true);later.elapsed_ms=5000
	var second:=stance.apply(later,close_pilot.controls_at_time(later,5000.0,[1],true))
	check(second.fire and second.throttle==0.0 and second.strafe==-1.0,"Stand-off lost the later opposite evasive direction")
	var partial:=close.duplicate(true);partial.player.vitals.hull=61;partial.elapsed_ms=5100
	check(stance.apply(partial,firing).fire and not stance.retreating,"Hull above the reserve triggered premature withdrawal")
	var damaged:=close.duplicate(true);damaged.player.vitals.hull=60;damaged.elapsed_ms=6000
	var damaged_before: Dictionary=damaged.duplicate(true)
	var returned:=stance.apply(damaged,firing)
	check(stance.retreating and not returned.fire and returned.target==-1,"Observed reserve boundary did not cease pursuit and firing")
	check(returned.commands.y>0.9 and returned.commands.x<0.0,"Withdrawal did not turn toward the escort behind and above the player")
	check(returned.throttle==1.0 and returned.distance>30000.0 and returned.strafe==1.0,"Withdrawal lost travel throttle or elapsed-time evasion")
	check(damaged==damaged_before and firing==firing_before,"Withdrawal repaired or changed the observed player/sample")
	var recovered:=close.duplicate(true);recovered.elapsed_ms=7000
	var latched:=stance.apply(recovered,firing)
	check(stance.retreating and not latched.fire and latched.strafe==-1.0,"Withdrawal re-entered the dangerous pursuit or lost its timed strafe")
	var near:=damaged.duplicate(true);near.player_pose.origin=Vector3(0,1500,-33500)
	check(stance.apply(near,firing).throttle==0.3,"Close formation did not slow down on its own observed distance")
	var missing:=damaged.duplicate(true);missing.encounter.combat.actors.remove_at(0)
	var missing_result:=stance.apply(missing,firing)
	check(missing_result.commands==Vector2.ZERO and not missing_result.fire and missing_result.target==-1,"Missing escort fabricated a return target or resumed firing")
	var dead:=damaged.duplicate(true);dead.encounter.combat.actors[0].vitals.hull=0
	check(stance.apply(dead,firing).commands==Vector2.ZERO,"Withdrawal steered toward a defeated escort")
	var inactive:=damaged.duplicate(true);inactive.encounter.combat.actors[0].active=false
	check(stance.apply(inactive,firing).commands==Vector2.ZERO,"Withdrawal steered toward an inactive escort")
	check(close==close_before and damaged==damaged_before and firing==firing_before,"Policy cases changed retained observations or the original firing sample")
	var separated:=observation(91,50000.0,4000)
	separated.encounter.combat.actors[0].position=Vector3(0,-1500,-122000)
	var separated_before: Dictionary=separated.duplicate(true)
	var outbound: Dictionary=Pilot.new().controls_at_time(separated,4000.0,[1],true)
	var outbound_before: Dictionary=outbound.duplicate(true)
	var regroup:=Tactics.new();var bounded:=regroup.apply(separated,outbound)
	check(bounded.target==-1 and not bounded.fire and bounded.commands.y>0.9,"Healthy pilot continued a remote pursuit instead of returning to its separated escort")
	check(bounded.throttle==1.0 and bounded.distance==125000.0 and bounded.strafe==1.0,"Separated escort return lost its actual distance, travel or timed evasion")
	check(separated==separated_before and outbound==outbound_before,"Regrouping changed its observed world or original pilot sample")
	var boundary:=separated.duplicate(true);boundary.encounter.combat.actors[0].position.z=-37000
	var boundary_tactics:=Tactics.new()
	check(boundary_tactics.apply(boundary,outbound)==outbound,"An escort exactly on the outer boundary changed the valid approach")
	boundary.encounter.combat.actors[0].position.z=-37001
	check(boundary_tactics.apply(boundary,outbound).target==-1,"Crossing the outer boundary did not stop remote pursuit")
	var middle:=separated.duplicate(true);middle.elapsed_ms=5000
	middle.encounter.combat.actors[0].position.z=-7000
	var midway:=regroup.apply(middle,firing)
	check(midway.target==-1 and not midway.fire and midway.commands.y>0.9 and midway.strafe==-1.0,"Regroup resumed pursuit too early or lost the opposite timed strafe")
	var arrived:=middle.duplicate(true);arrived.encounter.combat.actors[0].position.z=-2000
	var released:=regroup.apply(arrived,firing)
	check(released.target==1 and released.fire and released.throttle==0.0,"Reaching the inner boundary did not restore a real aligned firing solution")
	arrived.player.vitals.hull=60
	check(not regroup.apply(arrived,firing).fire and regroup.retreating,"Regroup completion overrode the damage reserve")
	var abandoned:=separated.duplicate(true);abandoned.encounter.combat.actors.remove_at(0)
	var stranded:=boundary_tactics.apply(abandoned,firing)
	check(stranded.target==-1 and not stranded.fire and stranded.commands==Vector2.ZERO,"A missing escort cancelled regroup and resumed firing")
	var lost:=separated.duplicate(true);lost.encounter.combat.actors[0].vitals.hull=0
	check(boundary_tactics.apply(lost,firing).commands==Vector2.ZERO,"Regroup steered toward a defeated escort")
	lost.encounter.combat.actors[0].vitals.hull=100;lost.encounter.combat.actors[0].active=false
	check(boundary_tactics.apply(lost,firing).commands==Vector2.ZERO,"Regroup steered toward an inactive escort")
	check(separated==separated_before and outbound==outbound_before and firing==firing_before,"Leash boundary cases mutated retained input data")
	print("Escort tactics: ",checks," checks; ",failures," failures; stand-off and damage-aware withdrawal are synthetic input policy, not earned survival")
	quit(0 if failures==0 else 1)

func observation(hull: int,distance: float,elapsed_ms: int) -> Dictionary:
	return {"elapsed_ms":elapsed_ms,"player_pose":Transform3D.IDENTITY,"player":{"vitals":{"hull":hull}},"encounter":{"combat":{"actors":[{"actor_id":0,"position":Vector3(0,0,-30000),"vitals":{"hull":100},"active":true},{"actor_id":1,"position":Vector3(0,0,distance),"vitals":{"hull":100},"active":true}]},"primaries":{"guns":[{"projectiles":{"weapon":{"speed_units_per_millisecond":40.0}}}]}}}

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr(message)
