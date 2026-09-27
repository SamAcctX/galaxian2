extends "res://tests/freelance_unlocked_application.gd"
## A generated contest played by flight input, with an independent living rival.

func requested_contract_kind() -> int:return 12
func contract_search_stations() -> Array:return [-1,99]
func expects_contract_success() -> bool:return OS.get_environment("GOF2_CHALLENGE_LOSS")!="1"

func accepts_requested_contract(mission: Dictionary) -> bool:
	return mission.kind==12 and mission.difficulty<=2

func visit_delivery_station(destination: int) -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	return await release_application_flight() and await travel_application(destination) and await dock_application()

func contract_cast_valid(actors: Array) -> bool:
	return actors.size() in [4,6,8] and actors[0].population_group=="rival" and actors.slice(1).all(func(actor):return actor.population_group=="pirate")

func contract_credit_delta(offer: Dictionary,won: bool) -> int:
	return int(offer.mission.reward)+int(offer.mission.bonus) if won else -int(offer.mission.reward)

func fly_contract_job(initial: Dictionary) -> bool:
	var targets: Array=initial.encounter.combat.actors.filter(func(actor):return actor.population_group=="pirate").map(func(actor):return actor.actor_id)
	check(initial.encounter.combat.actors[0].name==initial.contracts.accepted_contact.name,"The contest rival lost the accepted contact's name")
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us+1000000;var next_log:=now_us
	var shots:=0;var captured:=false
	while now_us-started<600000000:
		var state: Dictionary=app.session.snapshot()
		if not state.contracts.pending_result.is_empty():
			var earned: int=state.progress.player_kills-initial.progress.player_kills
			check(targets.all(func(id):return state.encounter.combat.actors[id].actor_mode==4),"The contest ended before its pirates finished destruction")
			check(state.encounter.combat.actors[0].vitals.hull>0,"The rival died during the contest")
			check((shots>0 and earned>targets.size()-earned) if expects_contract_success() else (shots==0 and earned==0),"The input pilot did not earn the expected contest score")
			return failures==0
		if app.session.flight_owner().death_active():check(false,"The Challenge pilot died before the contest result");return false
		var input: Dictionary=pilot.controls_at_time(state,float(state.world_elapsed_ms),targets,false)
		input.throttle=1.0 if input.distance>18000.0 else 0.0
		if input.distance<35000.0:input.strafe=1.0
		if not expects_contract_success():input.fire=false
		if input.fire:shots+=1
		if not pirate_step(input):return false
		if not captured and state.progress.pirate_kills>initial.progress.pirate_kills:
			await capture_free_application("challenge-live-contest");captured=true
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("Challenge pilot: ",{"elapsed":(now_us-started)/1000000.0,"hull":state.player.vitals.hull,"player_kills":state.progress.player_kills-initial.progress.player_kills,"pirates":targets.map(func(id):return state.encounter.combat.actors[id].vitals.hull)})
			next_log=now_us+15000000
	check(false,"The Challenge pilot never reached a contest result");return false
