extends Node3D
## A launcher shares decoded original meshes across ten independently tumbling
## mines. Presentation reads accepted poses and never advances their clocks.
const Resources=preload("res://src/content/bomb_projectile_resources.gd")
const Definitions=preload("res://src/content/mine_definitions.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
var error:=""
var bodies: Array[Node3D]=[]
var attachments: Array[Node3D]=[]
var _surface: RefCounted
var _sample:={}
var _weapon:={}
var _visuals:={}
var _generation: RefCounted
var _revision:=0

func build(mine: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	var descriptor:=Resources.prepare(library,bindings,mine.get("weapon",{}))
	if descriptor.is_empty() or mine.get("weapon",{}).get("kind")!=11 or mine.get("visuals")!=descriptor:return reject("Prepare original mine models before geometry")
	var resources:=Models.new()
	if not resources.prepare(descriptor.models.map(func(model):return model.resource),library,visuals,bindings,"high",false,true):return reject(resources.error)
	_surface=Surface.new()
	for unused in Definitions.CAPACITY:
		var body: Node3D=resources.instantiate(descriptor.models[0].resource)
		var attached: Node3D=resources.instantiate(descriptor.models[1].resource)
		if body==null or attached==null:
			if body!=null:body.free()
			if attached!=null:attached.free()
			resources.clear();return reject("Original mine mesh could not be instantiated")
		add_child(body);add_child(attached);body.hide();attached.hide()
		bodies.append(body);attachments.append(attached)
		if not _surface.prepare_model(attached):resources.clear();return reject(_surface.error)
	resources.clear()
	var sampler:=Sampler.new()
	if not sampler.configure(attachments[0].surfaces,true):return reject(sampler.error)
	_sample=sampler.sample(0,Transform3D.IDENTITY)
	if _sample.is_empty():return reject(sampler.error)
	_weapon=mine.weapon.duplicate(true);_visuals=descriptor;_generation=RefCounted.new()
	return true

func prepare(mine: Dictionary) -> Dictionary:
	error=""
	if _generation==null or mine.get("weapon")!=_weapon or mine.get("visuals")!=_visuals or not mine.get("slots") is Array or mine.slots.size()!=bodies.size():return failed("Mine geometry lost its prepared launcher or slots")
	var rows:=[]
	for shot in mine.slots:
		if shot==null or shot.get("phase")=="detonated":rows.append({"visible":false});continue
		if shot.get("phase")!="flying" or not shot.get("angles") is Vector3 or not shot.angles.is_finite() or not shot.get("position") is Vector3 or not shot.position.is_finite():return failed("Mine geometry lost its finite tumble pose")
		var pose:=Transform3D(Basis.from_euler(shot.angles,EULER_ORDER_XYZ),shot.position)
		var surfaces: Array=_surface.prepare_surfaces(_sample,pose,PackedByteArray([255,255,255,255]),Vector4.ONE)
		if surfaces.is_empty():return failed(_surface.error)
		rows.append({"visible":true,"pose":pose,"surfaces":surfaces})
	return {"generation":_generation,"revision":_revision+1,"slots":rows}

func commit(frame: Dictionary) -> void:
	if _generation==null or frame.get("generation")!=_generation or frame.get("revision")!=_revision+1:error="Mine geometry cannot commit a stale frame";return
	_revision+=1
	for index in bodies.size():
		var row: Dictionary=frame.slots[index]
		bodies[index].visible=row.visible;attachments[index].visible=row.visible
		if not row.visible:continue
		bodies[index].transform=row.pose
		_surface.apply_surfaces(attachments[index],row.surfaces,1.0)

func clear() -> void:
	for child in get_children():child.free()
	bodies.clear();attachments.clear();_surface=null;_sample={};_weapon={};_visuals={};_generation=null;_revision=0;error=""
func reject(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
