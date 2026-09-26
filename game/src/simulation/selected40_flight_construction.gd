extends RefCounted
## Compose the already generated source-selected world for an application.
## Retains canonical origin equipment and post-field RNG. It does not admit
## generic departure, independently complete a passenger job, or write a save.
const Frame=preload("res://src/simulation/selected40_flight_frame.gd")
const InitialView=preload("res://src/simulation/flight_camera_initialization.gd")
const Aim=preload("res://src/simulation/opening_aim.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
var error:=""
var _world: RefCounted

func prepare(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,pose: Transform3D,sensitivity:=1.0,viewport:=Vector2i(1440,900),career: RefCounted=null) -> bool:
	error=""
	if _world!=null or not player is Player or not scenery is Scenery or not Frame.valid_viewport(viewport):return reject("Application flight requires fresh retained native owners")
	var entry: Dictionary=scenery.snapshot().get("departure_population",{}).get("selected40_entry",{})
	if entry.get("selected40")!=true or not entry.get("special_placement") is bool or entry.get("entry_event") not in ["station_departure","travel_arrival"]:return reject("Application flight requires the actual selected native entry")
	var initial:=InitialView.new();var aim:=Aim.new()
	if not initial.configure(bindings,pose,scenery.random_state(),entry.special_placement) or not aim.configure(bindings):return reject(initial.error+aim.error)
	var camera: RefCounted=initial.camera_owner()
	if not aim.advance(pose,camera.snapshot().pose,viewport):return reject(aim.error)
	var frame:=Frame.new()
	if not frame.configure(bindings,catalogues,library,player,scenery,equipment,reputation,pose,camera,aim,sensitivity,viewport):return reject(frame.error)
	var prepared: RefCounted=frame.prepare_application_entry(initial)
	if prepared==null:return reject(frame.error)
	if career!=null and not prepared.prepare_career(bindings,career):return reject(prepared.error)
	_world=prepared
	return true

func world_owner() -> RefCounted:return null if _world==null else _world.fork_for_frame()
func snapshot() -> Dictionary:return {} if _world==null else _world.frame_context().application_initialization.duplicate(true)
func reject(message: String) -> bool:error=message;return false
