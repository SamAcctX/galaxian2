extends Node3D
## A sentry launcher's placed turrets (original mesh and glow at half size,
## turned with their aim) and their ordinary shots. Presentation reads the
## accepted sentry state and never advances it. Exploding turrets are hidden.
const Definitions=preload("res://src/content/sentry_gun_definitions.gd")
const Turret=preload("res://src/simulation/static_turret.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
const Pose=preload("res://src/presentation/projectile_pose.gd")
var error:=""
var bodies: Array[Node3D]=[]
var heads: Array[Node3D]=[]
var shots: Array[Node3D]=[]
var _surface: RefCounted
var _head_sample:={}
var _shot_sample:={}
var _rules:={}
var _weapon:={}

func build(sentry: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	var weapon: Dictionary=sentry.get("weapon",{})
	if Definitions.declaration(int(weapon.get("item_id",-1))).is_empty() or not sentry.get("shots") is Dictionary:return reject("Sentry geometry requires a configured launcher")
	var paths:=[bindings.resolve(int(weapon.base),"mesh"),bindings.resolve(int(weapon.head),"mesh"),bindings.resolve(int(weapon.shot_model),"mesh")]
	if paths.has(""):return reject("The sentry's original meshes are unavailable")
	var resources:=Models.new()
	if not resources.prepare(paths,library,visuals,bindings,"high",false,true):return reject(resources.error)
	_surface=Surface.new()
	for unused in Definitions.CAPACITY:
		var body: Node3D=resources.instantiate(paths[0]);var head: Node3D=resources.instantiate(paths[1])
		if body==null or head==null:resources.clear();return reject("The sentry mesh could not be instantiated")
		add_child(body);add_child(head);body.hide();head.hide();bodies.append(body);heads.append(head)
		if not _surface.prepare_model(head):resources.clear();return reject(_surface.error)
	for unused in int(sentry.shots.weapon.projectile_capacity):
		var shot: Node3D=resources.instantiate(paths[2])
		if shot==null:resources.clear();return reject("The sentry shot mesh could not be instantiated")
		add_child(shot);shot.hide();shots.append(shot)
		if not _surface.prepare_model(shot):resources.clear();return reject(_surface.error)
	resources.clear()
	for pair in [[heads[0],"head"],[shots[0] if not shots.is_empty() else null,"shot"]]:
		if pair[0]==null:continue
		var sampler:=Sampler.new()
		if not sampler.configure(pair[0].surfaces,true):return reject(sampler.error)
		var sample: Dictionary=sampler.sample(0,Transform3D.IDENTITY)
		if sample.is_empty():return reject(sampler.error)
		if pair[1]=="head":_head_sample=sample
		else:_shot_sample=sample
	_rules=bindings.opening_staging.projectile_visuals.duplicate(true);_weapon=weapon.duplicate(true)
	return true

func prepare(sentry: Dictionary,camera: Transform3D) -> Dictionary:
	error=""
	if _weapon.is_empty() or sentry.get("weapon")!=_weapon or not sentry.get("slots") is Array or sentry.slots.size()!=bodies.size():return failed("Sentry geometry lost its prepared launcher")
	var rows:=[]
	for slot in sentry.slots:
		if slot==null or slot.get("phase")!="active":rows.append({"visible":false});continue
		var pose: Transform3D=Turret.barrel_pose(slot.pose,Definitions.AIM,slot.aim)
		pose.basis=pose.basis.scaled(Vector3.ONE*Definitions.SCALE)
		var surfaces: Array=_surface.prepare_surfaces(_head_sample,pose,PackedByteArray([255,255,255,255]),Vector4.ONE)
		if surfaces.is_empty():return failed(_surface.error)
		rows.append({"visible":true,"pose":pose,"surfaces":surfaces})
	var fired:=[]
	var slots: Array=sentry.shots.get("slots",[])
	if slots.size()!=shots.size():return failed("Sentry shots changed capacity")
	for slot in slots:
		var root:=Pose.sample(slot,int(_weapon.kind),camera,false,_rules)
		if root.has("error"):return failed(root.error)
		if not root.visible:fired.append({"visible":false});continue
		var surfaces: Array=_surface.prepare_surfaces(_shot_sample,root.pose,PackedByteArray([255,255,255,255]),Vector4.ONE)
		if surfaces.is_empty():return failed(_surface.error)
		fired.append({"visible":true,"surfaces":surfaces})
	return {"sentries":rows,"shots":fired}

func commit(frame: Dictionary) -> void:
	for index in bodies.size():
		var row: Dictionary=frame.sentries[index]
		bodies[index].visible=row.visible;heads[index].visible=row.visible
		if not row.visible:continue
		bodies[index].transform=row.pose
		_surface.apply_surfaces(heads[index],row.surfaces,1.0)
	for index in shots.size():
		var row: Dictionary=frame.shots[index]
		shots[index].visible=row.visible
		if row.visible:_surface.apply_surfaces(shots[index],row.surfaces,1.0)

func clear() -> void:
	for child in get_children():child.free()
	bodies.clear();heads.clear();shots.clear();_surface=null;_head_sample={};_shot_sample={};_rules={};_weapon={};error=""
func reject(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
