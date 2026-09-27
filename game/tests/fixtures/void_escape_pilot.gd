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
	return _escape_controls(state,float(tick)*100.0)

## Use one elapsed simulation clock for aiming and post-kill evasion alike.
func controls_at_time(state: Dictionary,elapsed_ms: float,enabled: bool) -> Dictionary:
	if not enabled:return {"commands":Vector2.ZERO,"fire":false,"throttle":0.0,"strafe":0.0}
	if state.encounter.combat.actors[0].vitals.hull>0:
		return combat.controls_at_time(state,elapsed_ms,[0])
	return _escape_controls(state,elapsed_ms)

func _escape_controls(state: Dictionary,elapsed_ms: float) -> Dictionary:
	var input:={"commands":Vector2.ZERO,"fire":false,"throttle":1.0,"strafe":0.0}
	input.commands=Steering.steering_toward(state.player_pose,state.portal.position)
	# The radio wait does not pause the fighters. Keep moving and evading
	# until portal departure actually takes control away from the player.
	input.strafe=Combat.evasion_at(elapsed_ms)
	return input

static func advance(step: Callable,input: Dictionary) -> bool:
	return step.call(input.commands,input.fire,input.throttle,input.strafe)
