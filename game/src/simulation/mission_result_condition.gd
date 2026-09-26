extends RefCounted
## Mission-result conditions have a separate namespace from radio conditions.
const Retirement=preload("res://src/simulation/actor_retirement_condition.gd")

static func evaluate(condition: Dictionary,observation: Dictionary) -> Dictionary:
	var actors: Variant=observation.get("actors",[])
	match int(condition.get("kind",-1)):
		7:
			return Retirement.range_status(actors,0,int(condition.get("end_actor",-1)),4)
		18:
			return Retirement.range_status(actors,int(condition.get("first_actor",-1)),int(condition.get("end_actor",-1)),4)
		25:
			# The recipe names the native sequence adapter. This is deliberately
			# not a universal interpretation of the original script field.
			var flag: String=condition.get("sequence_flag","")
			var value: Variant=observation.get("sequences",{}).get(flag)
			if flag.is_empty() or not value is bool:return {}
			return {"satisfied":value}
	return {}
