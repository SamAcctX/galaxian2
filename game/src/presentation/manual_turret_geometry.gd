extends Node3D
## Original base and barrel meshes follow the simulation's authored mount.
const Resources=preload("res://src/presentation/model_resources.gd")
const Definitions=preload("res://src/content/manual_turret_definitions.gd")
const SelfAnimation=preload("res://src/presentation/model_self_animation.gd")
var error:=""
var base: Node3D
var gun: Node3D
var view_child: Node3D
var _item_id:=-1

func build(state: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	var row:=Definitions.declaration(int(state.get("item_id",-1)))
	if row.is_empty():error="No manual turret model is declared";return false
	var paths: Array=[bindings.resolve(row.base_model,"mesh"),bindings.resolve(row.gun_model,"mesh")]
	# Child meshes (Matador TS, plasma collectors) ride on the base and barrel
	# at their own origin; a collector's nozzle shows only in turret view.
	var keys:=["base_child","gun_child","gun_extra","view_child"].filter(func(key):return row.has(key))
	for key in keys:paths.append(bindings.resolve(int(row[key]),"mesh"))
	var resources:=Resources.new()
	if not resources.prepare(paths,library,visuals,bindings,"high",true):error=resources.error;return false
	base=resources.instantiate(paths[0]);gun=resources.instantiate(paths[1])
	for index in keys.size():
		var child: Node3D=resources.instantiate(paths[index+2])
		(base if keys[index]=="base_child" else gun).add_child(child)
		if keys[index]=="view_child":view_child=child
	add_child(base);add_child(gun);resources.clear();_item_id=int(state.item_id)
	return present(state)

func present(state: Dictionary) -> bool:
	if state.get("item_id")!=_item_id or not state.get("mount") is Vector3:error="Turret model lost its installed mount";return false
	var row:=Definitions.declaration(_item_id)
	# Gun turrets are modelled facing backwards and turned half round; the
	# collector meshes are not.
	var turn:=0.0 if row.get("collector",false) else PI
	base.transform=Transform3D(Basis(Vector3.UP,turn+float(state.yaw)),state.mount)
	gun.transform=Transform3D(base.basis*Basis(Vector3.RIGHT,float(state.pitch)),state.mount+Vector3(0,row.height,0))
	# A collector's barrel and nozzle play their clip only in turret view.
	var active:=bool(state.get("active",false))
	if view_child!=null:view_child.visible=active
	for node in gun.find_children("*","Node",true,false):
		if node.get_script()==SelfAnimation:node.set_process(active)
	return true
