extends RefCounted
## Input-only contest pilot. Reads the real world without changing its actors,
## pools, inventory, clocks or outcome. Shared with saved-career acceptance.
const Steering=preload("res://tests/fixtures/expedition_flight_pilot.gd")
var target_id:=-1
var previous: Variant=null
var previous_observed_ms:=-1.0
var observed_velocity:=Vector3.ZERO
var firing_range:=22000.0

func controls(state: Dictionary,tick: int,target_actor_ids: Array=[],reacquire_nearer:=false,delta_ms:=100.0) -> Dictionary:
	return _sample(state,float(tick)*100.0,target_actor_ids,reacquire_nearer,delta_ms)

## Supply the time of this observation, not the duration of the next step.
## Missing samples still count toward the target's measured travel time.
func controls_at_time(state: Dictionary,elapsed_ms: float,target_actor_ids: Array=[],reacquire_nearer:=false) -> Dictionary:
	return _sample(state,elapsed_ms,target_actor_ids,reacquire_nearer,0.0,true)

static func evasion_at(elapsed_ms: float) -> float:
	return 1.0 if fmod(elapsed_ms,2000.0)<1000.0 else -1.0

func _sample(state: Dictionary,elapsed_ms: float,target_actor_ids: Array,reacquire_nearer: bool,delta_ms: float,timed:=false) -> Dictionary:
	var result:={"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0,"target":-1,"distance":0.0}
	var actors: Array=state.encounter.combat.actors
	var living: Array=actors.filter(func(actor):return (actor.actor_id>0 if target_actor_ids.is_empty() else actor.actor_id in target_actor_ids) and actor.vitals.hull>0)
	if living.is_empty():return result
	if reacquire_nearer and target_id>=0:
		living.sort_custom(func(a,b):return a.position.distance_squared_to(state.player_pose.origin)<b.position.distance_squared_to(state.player_pose.origin))
		if actors[target_id].position.distance_to(state.player_pose.origin)>22000.0 and living[0].actor_id!=target_id and living[0].position.distance_to(state.player_pose.origin)<actors[target_id].position.distance_to(state.player_pose.origin)*0.65:target_id=-1
	if target_id<0 or actors[target_id].vitals.hull<=0 or (not target_actor_ids.is_empty() and target_id not in target_actor_ids):
		living.sort_custom(func(a,b):return a.position.distance_squared_to(state.player_pose.origin)<b.position.distance_squared_to(state.player_pose.origin))
		target_id=living[0].actor_id;previous=null
	var target: Dictionary=actors[target_id]
	var offset: Vector3=target.position-state.player_pose.origin
	var aim: Vector3=target.position
	var weapon: Dictionary=state.encounter.primaries.guns[0].projectiles.weapon
	var lead_ms:=minf(offset.length()/float(weapon.speed_units_per_millisecond),2000.0)
	if timed:
		if previous==null or previous_observed_ms<0.0 or elapsed_ms<previous_observed_ms:
			observed_velocity=Vector3.ZERO
		elif elapsed_ms>previous_observed_ms:
			observed_velocity=(target.position-previous)/(elapsed_ms-previous_observed_ms)
		# A second read of the same simulation frame must not drop its lead.
		aim+=observed_velocity*lead_ms
		previous_observed_ms=elapsed_ms
	else:
		# Preserve the original fixed-step interface, including explicit deltas.
		if previous!=null and delta_ms>0.0:aim+=(target.position-previous)/delta_ms*lead_ms
		previous_observed_ms=-1.0
	previous=target.position
	result.commands=Steering.steering_toward(state.player_pose,aim)
	result.throttle=1.0 if offset.length()>6000.0 else 0.0
	if offset.length()<35000.0:result.strafe=evasion_at(elapsed_ms)
	result.fire=offset.length()<firing_range and state.player_pose.basis.z.angle_to(aim-state.player_pose.origin)<0.15
	result.target=target_id;result.distance=offset.length()
	return result
