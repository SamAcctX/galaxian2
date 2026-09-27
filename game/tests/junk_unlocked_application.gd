extends "res://tests/freelance_unlocked_application.gd"
## Earn a generated Junk contract from a saved career using flight input only.

func requested_contract_kind() -> int:return 7

func contract_search_stations() -> Array:return [-1,95]

func accepts_requested_contract(mission: Dictionary) -> bool:
	var selected:=OS.get_environment("GOF2_JUNK_DIFFICULTY")
	return mission.kind==7 and (int(mission.difficulty)>=5 if selected.is_empty() else int(mission.difficulty)==selected.to_int())

func expects_contract_success() -> bool:return OS.get_environment("GOF2_JUNK_TIMEOUT")!="1"

func visit_delivery_station(destination: int) -> bool:
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return false
	if not await release_application_flight() or not await travel_application(destination) or not await dock_application():return false
	return true

func contract_cast_valid(actors: Array) -> bool:
	return not actors.is_empty() and actors.any(func(actor):return actor.get("population_group")=="debris") and actors.all(func(actor):return actor.get("population_group") in ["debris","pirate"])

func fly_contract_job(initial: Dictionary) -> bool:
	var debris: Array=initial.encounter.combat.actors.filter(func(actor):return actor.population_group=="debris").map(func(actor):return actor.actor_id)
	var ships: Array=initial.encounter.combat.actors.filter(func(actor):return actor.population_group=="pirate").map(func(actor):return actor.actor_id)
	check(debris.size()>=17 and debris.size()<=33 and ships.size()==(1 if initial.contracts.mission.difficulty>=5 else 0),"Junk lost its debris field or difficulty-dependent pirate")
	var pilot:=PiratePilot.new();var started:=now_us;var next_yield:=now_us+1000000;var next_log:=now_us
	var live_captured:=false;var shots:=0
	while now_us-started<150000000:
		var state: Dictionary=app.session.snapshot()
		if not state.contracts.pending_result.is_empty():
			if expects_contract_success():
				check(shots>0 and debris.all(func(id):return state.encounter.combat.actors[id].actor_mode==4),"The input pilot did not clear its assigned debris")
				check(state.progress.debris_destroyed==initial.progress.debris_destroyed+debris.size(),"The clearance lost debris statistics")
				check(state.progress.player_kills==initial.progress.player_kills and state.progress.pirate_kills==initial.progress.pirate_kills,"Debris clearance granted ship kill credit")
				check(ships.all(func(id):return state.encounter.combat.actors[id].vitals.hull>0),"The pilot did not prove clearance with a living pirate")
				check(app.session.flight_audio.snapshot().history.any(func(row):return row.get("source_id")==22),"Debris did not play its authored destruction sound")
			else:
				check(state.world_elapsed_ms>121000 and debris.any(func(id):return state.encounter.combat.actors[id].actor_mode!=4),"Junk failed before its deadline or after all debris cleared")
				check(state.progress.player_kills==initial.progress.player_kills and state.contracts.credits==initial.contracts.credits,"An idle deadline failure invented player ship kills or a penalty")
			return failures==0
		if app.session.flight_owner().death_active():check(false,"The Junk pilot died before the contract result");return false
		var input: Dictionary=pilot.controls_at_time(state,float(state.world_elapsed_ms),debris,true)
		input.throttle=1.0 if input.distance>14000.0 else 0.0
		input.strafe=0.0
		if not expects_contract_success():input={"commands":Vector2.ZERO,"throttle":1.0,"fire":false,"strafe":0.0,"target":-1,"distance":0.0}
		if input.fire:shots+=1
		if not pirate_step(input):return false
		if not live_captured and state.progress.debris_destroyed>initial.progress.debris_destroyed:
			await capture_free_application("junk-debris-clearance");live_captured=true
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("Junk pilot: ",{"elapsed":(now_us-started)/1000000.0,"hull":state.player.vitals.hull,"debris":state.progress.debris_destroyed-initial.progress.debris_destroyed,"target":input.target,"distance":input.distance})
			next_log=now_us+15000000
	check(false,"The Junk pilot never reached its timed result");return false
