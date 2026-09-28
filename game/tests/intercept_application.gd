extends "res://tests/defense_unlocked_application.gd"
## Generated hostile convoy, player fire, ordinary results and saved payment.

func _initialize() -> void:
	if OS.get_environment("GOF2_INTERCEPT_RESUME")=="1":call_deferred("run_resumed_job")
	else:super._initialize()

func requested_contract_kind() -> int:return 10
func contract_search_stations() -> Array:return [-1,39]
func contract_destination_allowed(station_id: int) -> bool:return station_id in [35,36,37,38,39]
func accepts_requested_contract(mission: Dictionary) -> bool:return mission.kind==10 and mission.difficulty<=3

func verify_delivery_route(original: Dictionary,before: Dictionary,offer: Dictionary,accepted: Dictionary,requested_kind: int) -> void:
	if not app.equipment_action("open"):check(false,app.session.error);return
	for change in [[91,81],[86,55]]:
		if app.session.station_owner().snapshot().loadout.equipment_ids.has(change[0]):
			if not app.equipment_action("unmount",change[0]) or not app.equipment_action("mount",change[1]):check(false,app.session.error);return
	var fitting: Dictionary=app.session.station_owner().snapshot()
	var cost:=0
	if OS.get_environment("GOF2_INTERCEPT_BUY_SHIELD")=="1":
		var row: Array=fitting.equipment.market_rows.filter(func(item):return item.item_id==51)
		if row.size()!=1 or row[0].stock<1 or row[0].unit_price>fitting.contracts.credits:check(false,"The retained shop cannot supply the pilot's shield");return
		cost=int(row[0].unit_price)
		if not app.equipment_action("buy",51) or not app.equipment_action("unmount",68) or not app.equipment_action("mount",51):check(false,app.session.error);return
		check(app.session.station_owner().snapshot().loadout.equipment_ids.has(51),"The purchased shield was not mounted")
	if not app.equipment_action("close"):check(false,app.session.error);return
	accepted=app.session.station_owner().snapshot()
	check(accepted.loadout.equipment_ids.has(81) and accepted.loadout.equipment_ids.has(55) and accepted.contracts.credits==before.contracts.credits-cost,"The input pilot lost its fitted scanner, armor or purchase price")
	if cost>0:
		check(accepted.cargo.entries.has({"item_id":68,"quantity":1}) and accepted.contracts.mission==before.contracts.mission,"Buying a shield lost the owned tractor or changed the job")
		await capture_free_application("intercept-shield-purchased-fitted")
	if not failures:await super.verify_delivery_route(original,before,offer,accepted,requested_kind)

func contract_cast_valid(actors: Array) -> bool:
	var freight: Array=actors.filter(func(actor):return actor.population_group=="freighter")
	return freight.size() in [2,3] and actors.size()>freight.size() and actors.all(func(actor):return actor.hostile and not actor.friendly)

func contract_target_ids(actors: Array) -> Array:
	return actors.filter(func(actor):return actor.population_group=="freighter").map(func(actor):return actor.actor_id)

func contract_pilot_targets(actors: Array) -> Array:
	var guards: Array=actors.filter(func(actor):return actor.population_group!="freighter" and actor.vitals.hull>0)
	return guards.map(func(actor):return actor.actor_id) if not guards.is_empty() else contract_target_ids(actors)
