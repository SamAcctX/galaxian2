extends Node3D
## Original base and barrel meshes follow the simulation's authored mount.
const Resources=preload("res://src/presentation/model_resources.gd")
const Definitions=preload("res://src/content/manual_turret_definitions.gd")
var error:=""
var base: Node3D
var gun: Node3D
var _item_id:=-1

func build(state: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	var row:=Definitions.declaration(int(state.get("item_id",-1)))
	if row.is_empty():error="No manual turret model is declared";return false
	var paths: Array=[bindings.resolve(row.base_model,"mesh"),bindings.resolve(row.gun_model,"mesh")]
	# Child meshes (Matador TS) ride on the base and barrel at their own origin.
	for key in ["base_child","gun_child"]:
		if row.has(key):paths.append(bindings.resolve(int(row[key]),"mesh"))
	var resources:=Resources.new()
	if not resources.prepare(paths,library,visuals,bindings,"high",true):error=resources.error;return false
	base=resources.instantiate(paths[0]);gun=resources.instantiate(paths[1])
	var index:=2
	for key in ["base_child","gun_child"]:
		if row.has(key):(base if key=="base_child" else gun).add_child(resources.instantiate(paths[index]));index+=1
	add_child(base);add_child(gun);resources.clear();_item_id=int(state.item_id)
	return present(state)

func present(state: Dictionary) -> bool:
	if state.get("item_id")!=_item_id or not state.get("mount") is Vector3:error="Turret model lost its installed mount";return false
	var row:=Definitions.declaration(_item_id)
	base.transform=Transform3D(Basis(Vector3.UP,PI+float(state.yaw)),state.mount)
	gun.transform=Transform3D(base.basis*Basis(Vector3.RIGHT,float(state.pitch)),state.mount+Vector3(0,row.height,0))
	return true
