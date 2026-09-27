extends RefCounted
## Test-only escort pilot; native owners still decide motion, firing and damage.
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const Targets=preload("res://tests/fixtures/mission_escort_targets.gd")
const NEARBY_DISTANCE=22000.0
var previous_observed_ms:=-1.0
var _pursuit:=Pilot.new()
var _opportunities:={}

func controls_at_time(state: Dictionary,elapsed_ms: float,preferred: Array=[],reacquire_nearer:=false) -> Dictionary:
	previous_observed_ms=elapsed_ms
	# Reuse the eligibility owner without its escort-proximity preference.
	# This is a filtered observation, never a changed native cast.
	var hostiles: Array=Targets.select_ids(state.encounter.combat.actors.filter(func(actor):return actor.actor_id!=0))
	for id in _opportunities.keys():
		if id not in hostiles:_opportunities.erase(id)
	if hostiles.is_empty():return {"commands":Vector2.ZERO,"throttle":0.0,"fire":false,"strafe":0.0,"target":-1,"distance":0.0}
	var ready: Dictionary={};var nearby: Dictionary={}
	for id in hostiles:
		if not _opportunities.has(id):_opportunities[id]=Pilot.new()
		# Keep each ship's measured lead even while another target is selected.
		var sample: Dictionary=_opportunities[id].controls_at_time(state,elapsed_ms,[id],true)
		if sample.fire and (ready.is_empty() or sample.distance<ready.distance):ready=sample
		if sample.distance>=NEARBY_DISTANCE:continue
		if nearby.is_empty() or sample.commands.length_squared()<nearby.commands.length_squared():nearby=sample
	if not ready.is_empty():return ready
	if not nearby.is_empty():return nearby
	return _pursuit.controls_at_time(state,elapsed_ms,preferred,reacquire_nearer)
