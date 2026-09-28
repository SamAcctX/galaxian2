extends "res://tests/defense_unlocked_application.gd"
## Generated convoy job, original large ships and actual player input.

func _initialize() -> void:
	if OS.get_environment("GOF2_ESCORT_RESUME")=="1":call_deferred("run_resumed_job")
	else:super._initialize()

func requested_contract_kind() -> int:return 9
func contract_search_stations() -> Array:return [-1,38]
func contract_destination_allowed(station_id: int) -> bool:return station_id in [35,36,37,38,39]
func accepts_requested_contract(mission: Dictionary) -> bool:return mission.kind==9 and mission.difficulty<=3
func expects_contract_success() -> bool:return OS.get_environment("GOF2_ESCORT_FAILURE")!="1"

func contract_cast_valid(actors: Array) -> bool:
	var attackers: Array=actors.filter(func(actor):return actor.population_group=="pirate")
	var convoy: Array=actors.filter(func(actor):return actor.population_group=="freighter")
	return not attackers.is_empty() and convoy.size()==5 and attackers.size()+convoy.size()==actors.size() \
		and attackers.all(func(actor):return actor.hostile and not actor.friendly) \
		and convoy.all(func(actor):return not actor.hostile and actor.friendly)

func contract_target_ids(actors: Array) -> Array:
	var group: String="pirate" if expects_contract_success() else "freighter"
	return actors.filter(func(actor):return actor.population_group==group).map(func(actor):return actor.actor_id)
