extends Node3D
## Passive original hulls for the retained wingman cast. No gameplay is inferred.
const Crew=preload("res://src/simulation/wingman_actors.gd")
const Ship=preload("res://src/presentation/ship_geometry.gd")
var error:=""
var actors:=[]
var _identity:={}

func build(owner: RefCounted,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	if not owner is Crew:return fail("Wingman geometry needs its retained actor owner")
	var state: Dictionary=owner.snapshot()
	if state.is_empty() or state.base_content_id!=bindings.base_content_id or state.binding_id!=bindings.binding_id:return fail("Wingman geometry belongs to another flight")
	for actor in state.actors:
		var ship:=Ship.new();add_child(ship)
		if not ship.build(int(actor.hull_catalogue_id),library,visuals,bindings):return fail(ship.error)
		ship.name="Wingman%d" % actor.wingman_index
		ship.set_meta("wingman_name",actor.name)
		actors.append({"ship":ship,"name":actor.name,"hull":actor.hull_catalogue_id})
	_identity={"base_content_id":state.base_content_id,"binding_id":state.binding_id}
	return true

func prepare(state: Dictionary) -> Dictionary:
	error=""
	for key in _identity:
		if state.get(key)!=_identity[key]:return failed("The wingman cast changed content identity")
	if not state.get("actors") is Array or state.actors.size()!=actors.size():return failed("The wingman cast changed within its flight")
	var prepared:=[]
	for index in actors.size():
		var actor: Dictionary=state.actors[index];var node: Dictionary=actors[index]
		var selection: Dictionary=state.get("detail",{}).get(index,{})
		if actor.get("name")!=node.name or actor.get("hull_catalogue_id")!=node.hull or actor.get("wingman_index")!=index or not actor.get("pose") is Transform3D or not actor.pose.is_finite() or not node.ship.valid_selection(selection):return failed("Wingman appearance lost its native pilot, hull or pose")
		prepared.append({"pose":actor.pose,"selection":selection,"visible":actor.active and actor.model_draw_enabled and actor.node_draw_requested})
	return {"actors":prepared}

func commit(frame: Dictionary) -> void:
	for index in actors.size():
		var current: Dictionary=frame.actors[index]
		actors[index].ship.transform=current.pose
		actors[index].ship.visible=current.visible
		actors[index].ship.apply_selection(current.selection)

func clear() -> void:
	for child in get_children():child.free()
	actors=[];_identity={};error=""

func fail(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
