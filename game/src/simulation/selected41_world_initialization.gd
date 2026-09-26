extends RefCounted
## Complete source41 environment/field/cast/player/camera construction. This
## stages native owners only; a live flight must activate before Host swaps it.
const Entry=preload("res://src/simulation/selected41_portal_entry.gd")
const EnvironmentOwner=preload("res://src/simulation/void_environment.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const Builder=preload("res://src/simulation/selected41_construction.gd")
const InitialCamera=preload("res://src/simulation/flight_camera_initialization.gd")
const Bodies=preload("res://src/content/scenery_body_resources.gd")
const Effects=preload("res://src/content/scenery_effect_resources.gd")
const First=preload("res://src/content/first_flight_definitions.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
var error:=""
var _state:={}
var _entry: RefCounted
var _environment: RefCounted
var _scenery: RefCounted
var _components: RefCounted
var _camera: RefCounted

func prepare(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,entry: RefCounted,environment_seconds: Variant,field_seconds: Variant,large_display:=true) -> bool:
	error=""
	if not _state.is_empty():return reject("Prepare the native source41 world exactly once")
	if not entry is Entry or entry.snapshot().is_empty() or bindings==null or not First.parameters(bindings.first_flight):return reject("Source41 world requires its native late-portal entry and source construction rules")
	if not Numbers.integer(environment_seconds,0,2147483647) or not Numbers.integer(field_seconds,0,2147483647):return reject("Source41 requires separate explicit supported environment and field times")
	var random:=Random.new();random.seed_from(environment_seconds)
	var initial_random:=random.snapshot()
	var environment:=EnvironmentOwner.new()
	if not environment.configure_selected41(bindings,initial_random,entry):return reject(environment.error)
	if not random.restore(environment.snapshot().random_state):return reject(random.error)
	var portal_position:=Vector3.ZERO
	for axis in 3:portal_position[axis]=int(bindings.first_flight.environment_object_position_offsets[axis])+random.next_int(int(bindings.first_flight.environment_object_position_bounds[axis]))
	var portal_id: int=int(bindings.first_flight.environment_object_resource_id)
	if bindings.resolve(portal_id,"mesh").is_empty():return reject(bindings.error)
	var bodies:=Bodies.new();var effects:=Effects.new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):return reject(bodies.error+effects.error)
	var scenery:=Scenery.new()
	if not scenery.configure_selected41(bindings,catalogues,entry,field_seconds,large_display,bodies,effects):return reject(scenery.error)
	var components:=Builder.new()
	if not components.prepare_initialized(bindings,catalogues,entry,scenery.world_initialization_owner()):return reject(components.error)
	var camera:=InitialCamera.new()
	# The actual living portal sets the same source flag consumed by the late
	# camera constructor: two [500,1000) offsets, Z7000, then two sign draws.
	# The cast has already replaced the fallback gate pose with its script pose.
	if not camera.configure(bindings,components.snapshot().player_pose,scenery.random_state(),true):return reject(camera.error)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"scope":"selected41_world_initialization","campaign_cursor":41,
		"station_id":-1,"system_id":-1,"world_type":3,"environment_seconds":environment_seconds,"field_seconds":field_seconds,
		"entry_conditions":{"companions_empty":true,"location_match":true,"special_placement":true},
		"environment_input_random_state":initial_random,"environment_random_state":random.snapshot(),
		"environment_object":{"resource_id":portal_id,"position":portal_position},"random_state":camera.snapshot().random_state,
		"player_pose":components.snapshot().player_pose,"application_committed":false}
	_entry=entry.fork();_environment=environment;_scenery=scenery;_components=components;_camera=camera
	return true

func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate(true)
	result.entry=_entry.snapshot();result.environment=_environment.snapshot();result.scenery=_scenery.snapshot()
	result.components=_components.snapshot();result.camera=_camera.snapshot()
	return result

func matches_departure(departure: RefCounted) -> bool:return _entry!=null and _entry.matches_departure(departure)
func entry_owner() -> RefCounted:return null if _entry==null else _entry.fork()
func environment_owner() -> RefCounted:return null if _environment==null else _environment.fork()
func scenery_owner() -> RefCounted:return null if _scenery==null else _scenery.fork_for_frame()
func construction_owner() -> RefCounted:return _components
func camera_owner() -> RefCounted:return null if _camera==null else _camera.camera_owner()
func camera_initialization() -> RefCounted:return _camera
func reject(message: String) -> bool:error=message;return false
