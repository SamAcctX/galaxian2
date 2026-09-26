extends RefCounted
## A detached transfer from a living mission's completed portal departure.
## Preparation is not a world swap or a restore format. The application must
## construct and present normal space before releasing this exact source frame.
const Cache=preload("res://src/simulation/flight_player_cache.gd")
const Recipe=preload("res://src/content/mission_recipe.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
var error:=""
var _departure: RefCounted
var _generation: RefCounted
var _terminal: RefCounted
var _observation:={}
var _state:={}
var _equipment: RefCounted
var _career: RefCounted

func prepare(bindings: RefCounted,catalogues: RefCounted,departure: RefCounted) -> bool:
	error=""
	if _departure!=null:return reject("Prepare a mission return only once")
	if not is_instance_of(departure,load("res://src/simulation/mission_flight_frame.gd")):return reject("A mission return requires the actual departing flight, not an observation")
	var observation: Dictionary=departure.prepare_portal_transition()
	if observation.is_empty() or departure.portal_return_identity()==null:return reject("The living escape has not completed its return boundary")
	if bindings==null or catalogues==null or catalogues.content_id!=bindings.base_content_id:return reject("Return catalogues belong to another source")
	for key in ["base_content_id","binding_id"]:
		if observation.get(key)!=bindings.get(key):return reject("The return belongs to another content identity")
	var recipe: Dictionary=departure.runner_owner().context_owner().recipe()
	if recipe!=Recipe.select(bindings,observation.campaign_cursor) or recipe.get("world_return",{})!={"kind":"normal_space","location":"retained_entry"}:return reject("The active mission has no retained normal-space return")
	var station: int=observation.return_station_id
	var system: int=observation.return_system_id
	if not Numbers.integer(station,0,catalogues.tables.stations.size()-1) or not Numbers.integer(system,0,catalogues.tables.systems.size()-1):return reject("The retained return location is absent from the catalogue")
	if int(catalogues.tables.stations[station].system_id)!=system or not catalogues.tables.systems[system].station_ids.has(station):return reject("The retained return station and system disagree")
	var random:=Random.new()
	var source: Dictionary=departure.frame_context()
	var flags: Dictionary=departure.station_response_flags()
	if not load("res://src/content/free_flight_definitions.gd").response_flags(bindings,flags):return reject("Normal return lost its retained station responses")
	if not random.restore(source.random_state):return reject(random.error)
	var next: RefCounted=get_script().new()
	next._departure=departure.fork_for_frame();next._generation=departure.presentation_identity();next._terminal=departure.portal_return_identity()
	next._observation=observation.duplicate(true)
	var equipment: RefCounted=departure.equipment_owner()
	if not equipment.relocate_mission_return(bindings,next):return reject(equipment.error)
	var cache:=Cache.capture_mission_return(bindings,next,equipment)
	if cache.is_empty():return reject("The return lost its living equipped player cache")
	var career: RefCounted=departure.career_owner()
	if not career.transfer_mission_return(bindings,next):return reject(career.error)
	var before: Dictionary=departure.career_owner().snapshot();var after: Dictionary=career.snapshot()
	for key in ["mission","accepted_contact","passengers","credits","active_offer_id","result_serial","completed_side_missions","pending_result","last_result","void_source","blueprints","lounges"]:
		if before.get(key)!=after.get(key):return reject("The return changed independent career state: "+key)
	if not next.matches_departure(departure):return reject("The departing world changed during return preparation")
	next._state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":observation.campaign_cursor,
		"return_station_id":station,"return_system_id":system,"mission":recipe.mission.duplicate(true),
		"player_cache":cache,"progress":after.progress.duplicate(true),"random_state":source.random_state.duplicate(true),"station_response_flags":flags,
		"source_before":observation.source_before.duplicate(true),"source_revision":observation.source_revision,
		"source_elapsed_ms":observation.source_elapsed_ms,"source_player_pose":observation.player_pose}
	_departure=next._departure;_generation=next._generation;_terminal=next._terminal;_observation=next._observation
	_state=next._state;_equipment=equipment;_career=career
	return true

func matches_departure(departure: RefCounted) -> bool:
	if _departure==null or not is_instance_of(departure,load("res://src/simulation/mission_flight_frame.gd")):return false
	if departure.presentation_identity()!=_generation or departure.portal_return_identity()!=_terminal or _terminal==null:return false
	return departure.prepare_portal_transition()==_observation and departure.equipment_owner().snapshot()==_departure.equipment_owner().snapshot() and departure.career_owner().snapshot()==_departure.career_owner().snapshot() and departure.frame_context().random_state==_departure.frame_context().random_state and departure.station_response_flags()==_departure.station_response_flags()

func matches_source_equipment(equipment: RefCounted) -> bool:
	return _departure!=null and is_instance_of(equipment,load("res://src/simulation/station_equipment.gd")) and equipment.snapshot()==_departure.equipment_owner().snapshot()
func matches_source_career(career: RefCounted) -> bool:
	return _departure!=null and is_instance_of(career,load("res://src/simulation/contract_session.gd")) and career.snapshot()==_departure.career_owner().snapshot()
func source_observation() -> Dictionary:return _observation.duplicate(true)
func source_player_owner() -> RefCounted:return null if _departure==null else _departure.player_owner()
func snapshot() -> Dictionary:return _state.duplicate(true)
func equipment_owner() -> RefCounted:return null if _equipment==null else _equipment.fork()
func career_owner() -> RefCounted:return null if _career==null else _career.fork()
func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._departure=null if _departure==null else _departure.fork_for_frame()
	copy._generation=_generation;copy._terminal=_terminal
	copy._observation=_observation.duplicate(true);copy._state=_state.duplicate(true)
	copy._equipment=equipment_owner();copy._career=career_owner()
	return copy
func reject(message: String) -> bool:error=message;return false
