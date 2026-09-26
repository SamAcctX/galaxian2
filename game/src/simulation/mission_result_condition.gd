extends RefCounted
## Mission-result conditions have a separate namespace from radio conditions.
const Retirement=preload("res://src/simulation/actor_retirement_condition.gd")

static func evaluate(condition: Dictionary,observation: Dictionary) -> Dictionary:
	var actors: Variant=observation.get("actors",[])
	# Named recipe predicates are independent of the imported numeric namespace.
	# An absent feature is not an error: the same mission can await a world change.
	if condition.get("kind") is String:
		match condition.kind:
			"never":return {"satisfied":false}
			"world_elapsed":
				var world: Dictionary=observation.get("world",{})
				if not world.get("features",{}).get(condition.get("feature",""),false):return {"satisfied":false}
				if not world.get("elapsed_ms") is int or not world.get("station_id") is int:return {}
				return {"satisfied":world.elapsed_ms>int(condition.after_ms) and world.station_id!=int(condition.different_station)}
		return {}
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
