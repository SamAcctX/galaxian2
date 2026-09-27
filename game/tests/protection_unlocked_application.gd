extends "res://tests/defense_unlocked_application.gd"
## Generated mining protection, including deliberate input-only failure.

func requested_contract_kind() -> int:return 2

func accepts_requested_contract(mission: Dictionary) -> bool:
	return mission.kind==2 and mission.difficulty<=3

func contract_cast_valid(actors: Array) -> bool:
	var attackers: Array=actors.filter(func(actor):return actor.population_group=="pirate")
	var protected: Array=actors.filter(func(actor):return actor.population_group=="protected")
	return not attackers.is_empty() and protected.size()>=2 and protected.size()<=5 \
		and attackers.size()+protected.size()==actors.size() \
		and attackers.all(func(actor):return actor.hostile and not actor.friendly) \
		and protected.all(func(actor):return not actor.hostile and actor.friendly)

func expects_contract_success() -> bool:return OS.get_environment("GOF2_PROTECTION_FAILURE")!="1"

func contract_target_ids(actors: Array) -> Array:
	var group: String="pirate" if expects_contract_success() else "protected"
	return actors.filter(func(actor):return actor.population_group==group).map(func(actor):return actor.actor_id)
