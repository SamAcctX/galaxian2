extends "res://tests/bakka_flight.gd"
## Focused full-distance return diagnostic. Controlled native combat contacts
## isolate guidance, contact and station presentation from the live gun pilot.
## This is not an earned battle or campaign checkpoint.

func resolve_contest(session: Node3D,player_wins: bool) -> RefCounted:
	return contest_outcome(session.flight_owner(),player_wins,present_contest_frame.bind(session))
