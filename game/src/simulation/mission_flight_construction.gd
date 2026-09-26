extends RefCounted
## Prepare the complete native candidate before the application swaps worlds.
const Frame=preload("res://src/simulation/mission_flight_frame.gd")
var error:=""
var _world: RefCounted
func prepare(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,context: RefCounted,initialized_world: RefCounted,sensitivity:=1.0,viewport:=Vector2i(1440,900)) -> bool:
	error=""
	if _world!=null:return reject("Mission flight construction is already prepared")
	var frame:=Frame.new()
	if not frame.prepare(bindings,catalogues,library,context,initialized_world,sensitivity,viewport):return reject(frame.error)
	_world=frame
	return true
func world_owner() -> RefCounted:return null if _world==null else _world.fork_for_frame()
func snapshot() -> Dictionary:return {} if _world==null else _world.frame_context()
func reject(message: String) -> bool:error=message;return false
