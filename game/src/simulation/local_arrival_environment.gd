extends RefCounted
## Derive the incoming position from generated scenery and retained location order.
## Travel owns authorization, equipment relocation and the final state transaction.
const Definitions=preload("res://src/content/local_arrival_environment_definitions.gd")
const Planets=preload("res://src/simulation/opening_planet_layout.gd")
const Gates=preload("res://src/simulation/gate_environment.gd")
const Cache=preload("res://src/simulation/lounge_cache.gd")
var error:=""
var _state:={}

func configure(bindings: RefCounted,catalogues: RefCounted,station_id: int,locations: RefCounted,cursor: int=18,mission_context: RefCounted=null) -> bool:
	error=""
	if not Definitions.location_supported(bindings,catalogues,station_id,cursor,mission_context) or not locations is Cache:return reject("Local arrival requires matching ordinary scenery and retained locations")
	var cache: Dictionary=locations.snapshot()
	if cache.get("base_content_id")!=bindings.base_content_id or cache.get("binding_id")!=bindings.binding_id or cache.get("current_station_id")!=station_id:return reject("Local arrival locations do not select this destination")
	var cache_index:=int(bindings.mido_travel.local_arrival_environment.arrival.cache_index)
	var cached_station: int=int(cache.locations[cache_index].station_id) if cache.locations.size()>cache_index else -1
	if not _configure_selected(bindings,catalogues,station_id,cursor,cached_station,cache.locations.size()>cache_index,mission_context):return false
	_state.location_order=cache.locations.map(func(entry):return int(entry.station_id))
	return true

## Early travel has a departure packet before it has a retained lounge history.
## Its source station supplies the incoming planet to the same pose owner.
func configure_transit(bindings: RefCounted,catalogues: RefCounted,packet: Dictionary,equipment: RefCounted) -> bool:
	error=""
	if bindings==null or catalogues==null or not Definitions.available(bindings):return reject("Incoming travel requires its original environment")
	for key in ["base_content_id","binding_id"]:
		if packet.get(key)!=bindings.get(key):return reject("Incoming travel belongs to another content source")
	var travel=load("res://src/content/mido_travel_definitions.gd")
	var cursor:=int(packet.get("campaign_cursor",-1));var destination:=int(packet.get("station_id",-1));var source:=int(packet.get("from_station_id",-1))
	var stations: Array=travel.navigation_stations(bindings,cursor,source)
	if source==destination or not stations.has(source) or not stations.has(destination) or catalogues.tables.stations[destination].system_id!=packet.get("system_id"):return reject("Incoming travel lost its admitted local route")
	var planets:=Planets.new()
	var layout:=planets.for_departure(bindings,catalogues,packet.get("player_cache"),"high",equipment)
	if layout.is_empty():return reject(planets.error)
	return _configure_selected(bindings,catalogues,destination,cursor,source,true,null,layout)

func _configure_selected(bindings: RefCounted,catalogues: RefCounted,station_id: int,cursor: int,cached_station: int,has_cached_planet: bool,mission_context: RefCounted=null,prepared_layout: Dictionary={}) -> bool:
	var gates:=Gates.new()
	if not gates.configure(bindings,catalogues,station_id):return reject(gates.error)
	var planets:=Planets.new();var layout:=prepared_layout if not prepared_layout.is_empty() else planets.for_lounge(bindings,catalogues,station_id,cursor,"high",mission_context)
	if layout.is_empty():return reject(planets.error)
	var rules: Dictionary=bindings.mido_travel.local_arrival_environment.arrival
	var gate_state: Dictionary=gates.snapshot()
	var position:=Vector3.ZERO;var facing:=false;var source:="gate";var planet_index:=-1
	if station_id==int(gate_state.gate_station_id) or not has_cached_planet:
		var incoming: Variant=gates.arrival_position()
		if not incoming is Vector3:return reject(gates.error)
		position=incoming
	else:
		var system: Dictionary=catalogues.tables.systems[int(layout.system_id)]
		var source_index: int=system.arrays[int(rules.system_station_array)].find(cached_station)
		position=Vector3(rules.fallback_planet_position[0],rules.fallback_planet_position[1],rules.fallback_planet_position[2])
		source="fallback_planet"
		if source_index>=0:
			planet_index=source_index+int(rules.planet_index_offset)
			if planet_index>=layout.entries.size():return reject("The cached station's planet index is absent from generated scenery")
			position=layout.entries[planet_index].origin;source="cached_planet"
		position*=float(rules.planet_multiplier)
		facing=bool(rules.face_origin)
	if not position.is_finite() or (facing and position.is_zero_approx()):return reject("The original arrival position cannot define a flight heading")
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":cursor,
		"station_id":station_id,"system_id":int(layout.system_id),"position":position,"face_origin":facing,
		"source":source,"cache_station_id":cached_station,"planet_index":planet_index,
		"planets":layout,"gates":gate_state}
	return true

func player_pose(initial_basis: Basis) -> Variant:
	if _state.is_empty() or not initial_basis.is_finite() or absf(initial_basis.determinant()-1.0)>0.0001:
		reject("Arrival requires the ordinary initial player heading");return null
	# Flight's forward direction is positive local Z. Looking toward the origin
	# therefore uses the model-front convention; gate arrivals keep source yaw.
	var basis: Basis=Basis.looking_at(-_state.position,Vector3.UP,true) if _state.face_origin else initial_basis
	return Transform3D(basis,_state.position)

## A run that starts at a fixed point (Supernova Challenge) keeps its heading.
func relocate(position: Vector3) -> bool:
	if _state.is_empty() or not position.is_finite():return reject("Relocate a configured arrival to a finite point")
	_state.position=position;_state.face_origin=false;_state.source="fixed"
	return true

func snapshot() -> Dictionary:return _state.duplicate(true)
func reject(message: String) -> bool:error=message;return false
