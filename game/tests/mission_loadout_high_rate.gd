extends "res://tests/mission_pilot_high_rate.gd"
## The existing one-second Host input check, now with a legally bought gun
## of another primary class. Detached arrival, not an earned battle or save.
const PaidLoadout=preload("res://tests/fixtures/mission_paid_loadout.gd")

func component_station(station: RefCounted) -> RefCounted:
	var purchase:=PaidLoadout.new()
	var fitted: RefCounted=purchase.prepare(bindings,catalogues,library,station,check)
	if fitted==null:check(false,purchase.error)
	return fitted
