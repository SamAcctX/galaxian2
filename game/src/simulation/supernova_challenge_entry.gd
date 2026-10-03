extends RefCounted
## Builds the Supernova Challenge flight from a fresh in-memory career, like the
## original resets its game state. Nothing here reads or writes the player's
## career or save; the run's career is discarded with the flight.
const Rules=preload("res://src/content/supernova_challenge_definitions.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
const Locations=preload("res://src/simulation/lounge_cache.gd")
const Career=preload("res://src/simulation/opening_handoff.gd")
const Loadout=preload("res://src/simulation/opening_loadout.gd")
const Stats=preload("res://src/simulation/equipment_stats.gd")
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Arrival=preload("res://src/simulation/local_arrival_environment.gd")
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")
var error:=""
var equipment: RefCounted
var contracts: RefCounted

## The challenge needs the expansion story world (station 111 at cursor 152).
static func available(bindings: RefCounted) -> bool:
	return bindings!=null and Archive.available(bindings) and Valkyrie.saved_story(bindings,Rules.CURSOR)

func prepare_owners(bindings: RefCounted,cat: RefCounted) -> bool:
	error=""
	if not available(bindings) or cat==null or not bindings.bind_catalogues(cat):return reject("The Supernova Challenge needs the imported Supernova content")
	var installed:=[]
	for row in Rules.EQUIPMENT:installed.append({"item_id":int(row[0]),"slot":int(row[1]),"quantity":int(row[2])})
	var loadout:=Loadout.new()
	if not loadout.assemble({"ship_id":Rules.SHIP_ID,"station_id":Rules.STATION_ID,"equipment":installed,"item_category_value_index":int(bindings.station_equipment.item_category_value_index)},cat,bindings.base_content_id,bindings.binding_id):return reject(loadout.error)
	var seed: Dictionary=loadout.snapshot()
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	var cargo:=identity.merged({"ship_id":Rules.SHIP_ID,"capacity":Stats.cargo_capacity(bindings,cat,seed),"entries":[],"used":0})
	cargo.free_space=cargo.capacity
	var prices:={"cargo":[],"installed":seed.slots.map(func(slot):return null if slot==null else {"item_id":slot.item_id,"unit_price":0})}
	var archive:=Archive.new()
	var owned: RefCounted=archive._inventory_base(bindings,cat,{"loadout":seed,"cargo":cargo,"stock":[],"cargo_cache_stale":false,"credit_delta":0,"transactions":0,
		"prices":prices,"protected_item_ids":[],"training_inventory_released":true,"prototype_drill_replaced":true})
	if owned==null:return reject(archive.error)
	var earned:=Career.calculate_progress(bindings.opening_handoff,Rules.CURSOR,0,0,0)
	if earned.is_empty():return reject("The challenge career has no rank rules")
	var reputation:={"axes":[0,0],"override":-1}
	var progress: Dictionary=earned.merged({"campaign_cursor":Rules.CURSOR,"reputation":reputation.duplicate(true),"debris_destroyed":0,"capital_ship_kills":0,"supernova_challenge":true},true)
	var lounges:=Locations.new()
	if not lounges.configure(bindings):return reject(lounges.error)
	var system_id: int=int(seed.system_id)
	# Only the challenge's own system is known to this career.
	var available:=[]
	for index in int(bindings.early_contracts.base_navigation.system_count):available.append(index==system_id)
	lounges._state.system_availability=available;lounges._state.current_station_id=Rules.STATION_ID;lounges._read={}
	var career:=Contracts.new()
	career._state=identity.merged({"campaign_cursor":Rules.CURSOR,"station_id":Rules.STATION_ID,"rank":int(progress.rank),"reputation":reputation,
		"difficulty":0.5,"credits":0,"passengers":0,"mission":{},"active_offer_id":-1,"offers":{},"progress":progress,"completed_side_missions":4,
		"delivery_statistics":{"cargo":0,"passengers":0},"pending_result":{},"result_serial":0,"accepted_contact":{},
		"travel_statistics":{"jumpgates_used":0,"visited_station_ids":[Rules.STATION_ID],"visited_system_ids":[system_id]}})
	career._rules=bindings.early_contracts.duplicate(true)
	career._cabins=Contracts.cabin_catalogue(cat,bindings.early_contracts.acceptance)
	career._progress_rules=bindings.opening_handoff.duplicate(true)
	career._stations=cat.tables.systems[int(bindings.early_contracts.system_id)].station_ids.duplicate()
	career._catalogues=cat
	career._lounges=lounges
	equipment=owned;contracts=career
	return true

## A prepared flight construction for FirstFlightSession.configure_prepared_arrival.
func prepare(bindings: RefCounted,cat: RefCounted,environment_seconds: int,unix_seconds: int,bodies: RefCounted,effects: RefCounted) -> RefCounted:
	if not prepare_owners(bindings,cat):return null
	var construction:=Construction.new()
	var mission: Dictionary=Valkyrie.mission(Rules.CURSOR)
	# The run starts in space at its fixed point, not with a launch.
	var arrival:=Arrival.new()
	if not arrival.configure(bindings,cat,Rules.STATION_ID,contracts.location_owner(),Rules.CURSOR) or not arrival.relocate(Rules.PLAYER_POSITION):reject(arrival.error);return null
	if not construction._prepare_free_owned(bindings,cat,equipment,contracts,mission,{},environment_seconds,unix_seconds,true,bodies,effects,null,arrival,-1):
		reject(construction.error);return null
	return construction

func reject(message: String) -> bool:error=message;return false
