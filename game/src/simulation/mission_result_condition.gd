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
			"station":
				var world: Dictionary=observation.get("world",{})
				if not world.get("docked") is bool or not world.get("station_id") is int or not observation.get("elapsed_ms") is int:return {}
				return {"satisfied":world.docked and world.station_id==int(condition.station_id) and observation.elapsed_ms>int(condition.after_ms)}
			"elapsed":
				if not observation.get("elapsed_ms") is int:return {}
				return {"satisfied":observation.elapsed_ms>int(condition.after_ms)}
			"world_elapsed":
				var world: Dictionary=observation.get("world",{})
				if not world.get("features",{}).get(condition.get("feature",""),false):return {"satisfied":false}
				if not world.get("elapsed_ms") is int or not world.get("station_id") is int:return {}
				return {"satisfied":world.elapsed_ms>int(condition.after_ms) and world.station_id!=int(condition.different_station)}
		return {}
	match int(condition.get("kind",-1)):
		1:
			var id:=int(condition.get("actor_id",-1))
			return Retirement.range_status(actors,id,id+1,4)
		7:
			return Retirement.range_status(actors,0,int(condition.get("end_actor",-1)),4)
		11,12:
			var id:=int(condition.get("actor_id",-1))
			if not actors is Array or id<0 or id>=actors.size():return {}
			var flag: String="special_cargo_accepted" if int(condition.kind)==11 else "special_cargo_rejected"
			if not actors[id].get(flag) is bool:return {}
			return {"satisfied":actors[id][flag]}
		18:
			return Retirement.range_status(actors,int(condition.get("first_actor",-1)),int(condition.get("end_actor",-1)),4)
		20,21:
			var totals: Dictionary=observation.get("world",{}).get("counters",{})
			if not totals.get("world_player_kills") is int or not totals.get("world_other_kills") is int:return {}
			var rules: Dictionary=condition.get("rules",{})
			var retirement:=Retirement.range_status(actors,int(rules.get("challenge_first_actor",-1)),actors.size(),int(rules.get("destroyed_mode",-1)))
			if retirement.is_empty():return {}
			for actor in actors:
				if not actor.get("actor_kind") is int:return {}
			var result:=preload("res://src/simulation/pirate_defeat_condition.gd").evaluate(actors,totals,rules,true)
			return {"satisfied":result.satisfied if int(condition.kind)==20 else result.failed,"retired":result.defeated,"required":result.required}
		25:
			# The recipe names the native sequence adapter. This is deliberately
			# not a universal interpretation of the original script field.
			var flag: String=condition.get("sequence_flag","")
			var value: Variant=observation.get("sequences",{}).get(flag)
			if flag.is_empty() or not value is bool:return {}
			return {"satisfied":value}
	return {}
