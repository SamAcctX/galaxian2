extends "res://tests/freelance_unlocked_application.gd"
## Real generated defense job, friendly patrols and input-only combat.

func requested_contract_kind() -> int:return 1

func accepts_requested_contract(mission: Dictionary) -> bool:
	return mission.kind==1 and mission.difficulty<=3

func visit_delivery_station(destination: int) -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	return await release_application_flight() and await travel_application(destination) and await dock_application()

func contract_cast_valid(actors: Array) -> bool:
	var attackers: Array=actors.filter(func(actor):return actor.population_group=="pirate")
	var defenders: Array=actors.filter(func(actor):return actor.population_group=="patrol")
	return not attackers.is_empty() and defenders.size()>=3 and defenders.size()<=7 \
		and attackers.size()+defenders.size()==actors.size() \
		and attackers.all(func(actor):return actor.hostile and not actor.friendly) \
		and defenders.all(func(actor):return not actor.hostile and actor.friendly)

func contract_target_ids(actors: Array) -> Array:
	return actors.filter(func(actor):return actor.population_group=="pirate").map(func(actor):return actor.actor_id)
