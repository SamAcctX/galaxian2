extends RefCounted
## Detached successor transaction owned by the actual late selected40 portal.
## A dictionary observation is not a restore format, save or world-swap grant.
const Rules=preload("res://src/content/selected41_population_definitions.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
var error:=""
var _state:={}
var _equipment: RefCounted
var _career: RefCounted
var _source_identity: RefCounted

func prepare(bindings: RefCounted,departure: RefCounted) -> bool:
	error=""
	if not _state.is_empty():return reject("Prepare the native successor entry exactly once")
	if not is_instance_of(departure,load("res://src/simulation/selected40_flight_frame.gd")) or not departure.successor41_ready(bindings):return reject("Successor41 requires the actual living late-portal frame")
	var equipment: RefCounted=departure.equipment_owner()
	# Frame evaluation already retains accepted cargo and paid ammo in this
	# inventory. Never copy cargo from an earlier save or constructor cache.
	if not equipment.relocate_selected41(bindings,departure):return reject(equipment.error)
	var cache: Dictionary=Cache.capture_selected41(bindings,departure,equipment)
	if cache.is_empty():return reject("Successor41 lost the actual living player cache")
	var career: RefCounted=departure.prepare_successor41_career(bindings)
	if career==null:return reject(departure.error)
	var before: Dictionary=departure.career_owner().snapshot()
	var after: Dictionary=career.snapshot()
	# Story entry does not settle, discard or reward the independently accepted
	# job. Keep its exact contact, passengers, balances and result serial.
	for key in ["mission","accepted_contact","passengers","credits","active_offer_id","result_serial","completed_side_missions","pending_result","last_result","void_source","blueprints","lounges"]:
		if before.get(key)!=after.get(key):return reject("Successor changed retained career state: "+key)
	var observation: Dictionary=departure.prepare_portal_transition()
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"campaign_cursor":41,"station_id":-1,"system_id":-1,"mission_kind":4,"mission_story":true,"mission_completed":false,"mission_failed":false,
		"rank":after.rank,"difficulty":after.difficulty,"retained_freighter_hull":observation.freighter_hull}
	if not Rules.context_valid(bindings,context):return reject("Successor41 lost its source-selected mission context")
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"source_state":2,"from_cursor":40,"campaign_cursor":41,
		"context":context,"mission":Rules.mission(bindings),"player_cache":cache,"freighter_hull":Rules.freighter_hull(observation.freighter_hull,after.rank),
		"source_before":observation.source_before.duplicate(true),"return_station_id":observation.return_station_id,"return_system_id":observation.return_system_id,
		"source_revision":departure.frame_context().revision,"source_elapsed_ms":departure.frame_context().elapsed_ms,"application_committed":false}
	_equipment=equipment;_career=career;_source_identity=departure.presentation_identity()
	return true

func matches_departure(departure: RefCounted) -> bool:
	return not _state.is_empty() and is_instance_of(departure,load("res://src/simulation/selected40_flight_frame.gd")) and departure.presentation_identity()==_source_identity and departure.frame_context().revision==_state.source_revision and departure.frame_context().elapsed_ms==_state.source_elapsed_ms and departure.prepare_portal_transition().get("freighter_hull")==_state.context.retained_freighter_hull

func snapshot() -> Dictionary:return _state.duplicate(true)
func equipment_owner() -> RefCounted:return null if _equipment==null else _equipment.fork()
func career_owner() -> RefCounted:return null if _career==null else _career.fork()
func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate(true);copy._source_identity=_source_identity
	copy._equipment=equipment_owner();copy._career=career_owner()
	return copy
func reject(message: String) -> bool:error=message;return false
