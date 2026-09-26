extends RefCounted
## Independent native predicates for the original Dekato convoy cast.
## The enclosing live frame must retain actor ownership, resolve simultaneous
## success/failure and acknowledge the result. This object cannot advance a save.
const Definitions=preload("res://src/content/dekato_convoy_definitions.gd")
const Conditions=preload("res://src/simulation/mission_result_condition.gd")
var error:=""
var _rules:={}

func configure(declarations: Variant) -> bool:
	error="";_rules={}
	if not Definitions.parameters(declarations):return reject("Dekato requires its verified source declarations")
	_rules=declarations.objectives.duplicate(true)
	return true

func observe(actors: Variant) -> Dictionary:
	error=""
	if _rules.is_empty() or not actors is Array or actors.size()!=int(_rules.actor_count):
		reject("Dekato requires its complete seven-actor observation");return {}
	var success:=Conditions.evaluate(_rules.success,{"actors":actors})
	var failure:=Conditions.evaluate(_rules.failure,{"actors":actors})
	if success.is_empty() or failure.is_empty():reject("Dekato received an invalid native actor mode");return {}
	# The original predicates are independent. In particular, losing one convoy
	# ship is not condition7; do not invent a priority when both predicates hold.
	return {"kind":int(_rules.success.kind),"failure_kind":int(_rules.failure.kind),
		"defeated":success.retired,"required":success.required,
		"convoy_destroyed":failure.retired,"convoy_count":failure.required,
		"satisfied":success.satisfied,"failed":failure.satisfied}

func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._rules=_rules
	return copy

func reject(message: String) -> bool:error=message;return false
