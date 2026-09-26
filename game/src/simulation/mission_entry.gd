extends RefCounted
## Prepare a complete admitted mission before the application replaces its
## living source world. The source entry owns all retained career and equipment.
const Context=preload("res://src/simulation/mission_context.gd")
const Frame=preload("res://src/simulation/mission_flight_frame.gd")
const AmbushWorld=preload("res://src/simulation/selected41_world_initialization.gd")
var error:=""
var _world: RefCounted

func prepare_portal(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,departure: RefCounted,environment_seconds: int,field_seconds: int,sensitivity:=1.0,viewport:=Vector2i(1440,900)) -> bool:
	if _world!=null or departure==null or not departure.has_method("prepare_successor41_entry"):return reject("Mission portal entry requires its living source transition")
	var entry: RefCounted=departure.prepare_successor41_entry(bindings)
	if entry==null:return reject(departure.error)
	var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):return reject(context.error)
	var initialized:=AmbushWorld.new()
	if not initialized.prepare(bindings,catalogues,library,entry,environment_seconds,field_seconds):return reject(initialized.error)
	var frame:=Frame.new()
	if not frame.configure(bindings,catalogues,library,context,initialized,sensitivity,viewport):return reject(frame.error)
	if not initialized.matches_departure(departure):return reject("The source flight changed while its successor was prepared")
	_world=frame
	return true

func world_owner() -> RefCounted:return null if _world==null else _world.fork_for_frame()
func reject(message: String) -> bool:error=message;return false
