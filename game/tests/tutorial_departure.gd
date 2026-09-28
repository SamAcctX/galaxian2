extends "res://tests/station_equipment.gd"
## Exercise a fresh tutorial inventory through the real departure preparation.
const TutorialFlight=preload("res://src/presentation/first_flight_session.gd")

func choose_starter_gun(state: Dictionary) -> Dictionary:
	if OS.get_environment("GOF2_STARTER_GUN")!="standard":return state
	check(host.equipment_action("unmount",22) and host.equipment_action("mount",0),host.session.error)
	return host.session.snapshot()

func after_second_return(args: PackedStringArray):
	await super.after_second_return(args)
	if failures:return
	var before: Dictionary=host.session.snapshot()
	check(host.request_departure(),host.session.error)
	host.choose_departure(1)
	check(host.session is TutorialFlight,"Fresh equipped departure failed: "+host.status.text)
	if not host.session is TutorialFlight:return
	check(host.session._world._equipment.snapshot().loadout==before.loadout,"Departure changed the chosen starter gun")
	check(host.session._world._equipment.snapshot().cargo==before.cargo,"Departure changed the spare cargo")
	if args.size()==4:await capture(args[3],"tutorial-departure")
