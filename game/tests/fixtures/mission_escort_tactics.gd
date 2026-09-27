extends RefCounted
## Conservative test-pilot choices, not mission rules or native damage policy.
## Intercept briefly, but preserve the damaged player's hull for its escort.
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const Steering=preload("res://tests/fixtures/expedition_flight_pilot.gd")
var initial_hull:=-1.0
var retreating:=false

func apply(state: Dictionary,sample: Dictionary) -> Dictionary:
	var result: Dictionary=sample.duplicate(true)
	var hull:=float(state.player.vitals.hull)
	if initial_hull<0.0:initial_hull=hull
	if initial_hull>0.0 and hull<=initial_hull*0.75:retreating=true
	if not retreating:
		# Stand off while the combat pilot has a real aligned firing solution;
		# do not keep charging into the target just to reach its 6km stop range.
		if int(result.get("target",-1))>=0 and result.get("fire",false):result.throttle=0.0
		return result
	result.fire=false;result.target=-1;result.distance=0.0
	result.commands=Vector2.ZERO;result.throttle=1.0
	result.strafe=Pilot.evasion_at(float(state.elapsed_ms))
	for actor in state.encounter.combat.actors:
		if actor.actor_id!=0 or actor.vitals.hull<=0 or not actor.get("active",true):continue
		var formation: Vector3=actor.position+Vector3(0,1500,-3000)
		result.commands=Steering.steering_toward(state.player_pose,formation)
		result.distance=state.player_pose.origin.distance_to(formation)
		result.throttle=1.0 if result.distance>5000.0 else 0.3
		break
	return result
