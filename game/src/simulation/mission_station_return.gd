extends RefCounted
## Detached native transfer, committed only after the complete station scene is
## ready and the host has rechecked this exact pending source frame.
const Context=preload("res://src/simulation/mission_station_context.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
var error:=""
var _source: RefCounted
var _identity: RefCounted
var _before:={}
var _context: RefCounted
var _equipment: RefCounted
var _career: RefCounted
var _state:={}

func prepare(bindings: RefCounted,cat: RefCounted,library: RefCounted,flight: RefCounted,settings: Dictionary,unix_seconds: Variant) -> bool:
	if _source!=null:return reject("Prepare a station continuation only once")
	var context:=Context.new()
	if not context.admit(bindings,cat,flight):return reject(context.error)
	var next: RefCounted=get_script().new()
	next._source=flight.fork_for_frame();next._identity=flight.mission_station_return_identity()
	next._before=flight.snapshot();next._context=context
	var equipment: RefCounted=flight.equipment_owner()
	if not equipment.relocate_mission_station(bindings,next):return reject(equipment.error)
	var cached:=Cache._capture_arrival(bindings.mido_travel,flight.equipment_owner().snapshot().loadout,equipment.snapshot().loadout,next._before.player)
	if cached.is_empty():return reject("Station continuation lost the living player's pools")
	cached.campaign_cursor=context.snapshot().campaign_cursor
	var career: RefCounted=flight.contract_owner()
	if career==null or not career.enter_mission_station(bindings,cat,library,next,equipment,settings,unix_seconds):return reject("Station continuation career: "+("missing" if career==null else career.error))
	var original: Dictionary=flight.contract_owner().snapshot();var retained: Dictionary=career.snapshot()
	for key in ["mission","accepted_contact","passengers","credits","active_offer_id","result_serial","completed_side_missions","pending_result","last_result","blueprints","progress","travel_statistics","delivery_statistics"]:
		if original.get(key)!=retained.get(key):return reject("Station continuation changed independent career state: "+key)
	if not next.matches_departure(flight):return reject("The pending station source changed during preparation")
	_source=next._source;_identity=next._identity;_before=next._before;_context=context
	_equipment=equipment;_career=career
	_state={"continuation":context.snapshot(),"player_cache":cached,"arrival_player":_before.player.duplicate(true),"flight_elapsed_ms":_before.world_elapsed_ms,"station_response_flags":flight.station_response_flags()}
	return true

func matches_departure(flight: RefCounted) -> bool:
	return _source!=null and is_instance_of(flight,load("res://src/simulation/first_flight_frame.gd")) and _identity!=null and flight.mission_station_return_identity()==_identity and flight.snapshot()==_before
func matches_source_equipment(equipment: RefCounted) -> bool:return _source!=null and equipment!=null and equipment.snapshot()==_source.equipment_owner().snapshot()
func matches_source_career(career: RefCounted) -> bool:return _source!=null and career!=null and career.snapshot()==_source.contract_owner().snapshot()
func context_owner() -> RefCounted:return _context
func source_random() -> Dictionary:return _before.get("random_state",{}).duplicate(true)
func snapshot() -> Dictionary:return _state.duplicate(true)
func equipment_owner() -> RefCounted:return null if _equipment==null else _equipment.fork()
func career_owner() -> RefCounted:return null if _career==null else _career.fork()
func reject(message: String) -> bool:error=message;return false
