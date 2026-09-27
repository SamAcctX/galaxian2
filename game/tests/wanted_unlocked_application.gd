extends "res://tests/freelance_unlocked_application.gd"
## Generated bounty acceptance and input-only combat from an earned career.

func requested_contract_kind() -> int:return 6
func contract_search_stations() -> Array:return [-1,97]

func accepts_requested_contract(mission: Dictionary) -> bool:
	return mission.kind==6 and mission.difficulty<=3 and not mission.get("target_name","").is_empty()

func visit_delivery_station(destination: int) -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	return await release_application_flight() and await travel_application(destination) and await dock_application()

func contract_cast_valid(actors: Array) -> bool:
	return actors.size()==1 and actors[0].population_group=="pirate" and actors[0].actor_kind==8

func fly_contract_job(initial: Dictionary) -> bool:
	var job: Dictionary=initial.contracts.mission
	check(not job.target_name.is_empty() and initial.contracts.accepted_contact.offer.mission==job,"The Wanted job lost its retained briefing identity")
	# Resume can launch the accepted job without opening a lounge. Inspect the
	# actual briefing only on the acceptance path, where its panel was prepared.
	if app.lounge_panel._catalogues!=null:
		var briefing: String=app.lounge_panel.format_job(source.strings[job.briefing_text_id],job)
		check(briefing.contains(job.target_name) and not briefing.contains("#N"),"The Wanted briefing omitted its criminal's name")
	if failures:return false
	return await super.fly_contract_job(initial)
