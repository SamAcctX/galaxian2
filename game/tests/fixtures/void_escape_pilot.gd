extends RefCounted
## Input-only escape pilot. Keep the combat pilot's whole control sample,
## including its evasive movement, rather than dropping lateral input.
const Combat=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const Steering=preload("res://tests/fixtures/expedition_flight_pilot.gd")
var combat:=Combat.new()

func controls(state: Dictionary,tick: int,enabled: bool) -> Dictionary:
	var input:={"commands":Vector2.ZERO,"fire":false,"throttle":0.0,"strafe":0.0}
	if not enabled:return input
	if state.encounter.combat.actors[0].vitals.hull>0:
		return combat.controls(state,tick,[0])
	input.commands=Steering.steering_toward(state.player_pose,state.portal.position)
	# The radio wait does not pause the fighters. Keep moving and evading
	# until portal departure actually takes control away from the player.
	input.throttle=1.0
	input.strafe=1.0 if tick%20<10 else -1.0
	return input

static func advance(step: Callable,input: Dictionary) -> bool:
	return step.call(input.commands,input.fire,input.throttle,input.strafe)
