extends RefCounted
## A static object's own gun turret (80's Valkyrie weak points). Every
## `retarget_ms` it picks the nearest opposing body within `range`, then yaws
## its base and pitches its barrel toward a point `lead` units ahead of that
## body, one full turn per `turn_ms`. It fires when the aim point lies within
## `aim_tolerance` of the barrel's axis on both sides. Pitch stops at its limits.
## The aim state lives on the combat actor; this file owns only the rules.

static func initial() -> Dictionary:
	return {"yaw":0.0,"pitch":0.0,"target_id":-2,"clock_ms":0}

## The turret's swivel frame: the body turned by the current yaw.
static func group_pose(body: Transform3D,aim: Dictionary) -> Transform3D:
	return body*Transform3D(Basis(Vector3.UP,float(aim.yaw)),Vector3.ZERO)

## The barrel in its swivel frame (turned 180 deg like the base, then pitched).
static func barrel_local(rule: Dictionary,aim: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,PI)*Basis(Vector3.RIGHT,float(aim.pitch)),Vector3(rule.barrel_offset))

## Shots leave the barrel along its +Z axis.
static func barrel_pose(body: Transform3D,rule: Dictionary,aim: Dictionary) -> Transform3D:
	return group_pose(body,aim)*barrel_local(rule,aim)

## candidates: [{actor_id, position, forward}] of living, active, opposing
## bodies (the player is actor_id -1). Returns the next aim state, whether
## the gun fires this frame, at whom, and the barrel pose to fire from.
static func advance(aim: Dictionary,rule: Dictionary,body: Transform3D,candidates: Array,delta_ms: int) -> Dictionary:
	var next:=aim.duplicate()
	next.clock_ms=int(next.clock_ms)+delta_ms
	if int(next.clock_ms)>int(rule.retarget_ms):
		next.clock_ms=0;next.target_id=-2
		var nearest:=float(rule.range)
		for candidate in candidates:
			var distance: float=body.origin.distance_to(candidate.position)
			if distance<nearest:nearest=distance;next.target_id=int(candidate.actor_id)
	var target: Dictionary={}
	for candidate in candidates:
		if int(candidate.actor_id)==int(next.target_id):target=candidate
	var barrel:=barrel_pose(body,rule,next)
	if target.is_empty():return {"aim":next,"fire":false,"target_id":-2,"barrel":barrel}
	var point: Vector3=Vector3(target.position)+Vector3(target.forward).normalized()*float(rule.lead)
	var local:=(barrel.affine_inverse()*point).normalized()
	var tolerance:=float(rule.aim_tolerance)
	var step:=TAU*float(delta_ms)/float(rule.turn_ms)
	var on_target:=true
	# Positive yaw swings the barrel toward its local +X; positive pitch
	# toward its local -Y. Each turn stops at the remaining angle.
	if absf(local.x)>tolerance or local.z<=0.0:
		on_target=false
		var side:=-1.0 if local.x<0.0 else 1.0
		next.yaw=wrapf(float(next.yaw)+side*minf(step,absf(atan2(local.x,local.z))),-PI,PI)
	if absf(local.y)>tolerance:
		on_target=false
		var limit_up:=-TAU*float(rule.pitch_up_ms)/float(rule.turn_ms);var limit_down:=TAU*float(rule.pitch_down_ms)/float(rule.turn_ms)
		next.pitch=clampf(float(next.pitch)-signf(local.y)*minf(step,absf(atan2(local.y,Vector2(local.x,local.z).length()))),limit_up,limit_down)
	var fire: bool=on_target
	return {"aim":next,"fire":fire,"target_id":int(next.target_id),"barrel":barrel}
