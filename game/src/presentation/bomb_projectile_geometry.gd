extends Node3D
## Original animated bomb body and glow. The weapon owns both clocks; geometry
## samples accepted state without advancing physics or restarting animation.
const Resources=preload("res://src/content/bomb_projectile_resources.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Additive=preload("res://src/presentation/animated_additive_model.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
var error:=""
var models: Array[Node3D]=[]
var _samplers:=[]
var _surface: RefCounted
var _weapon:={}
var _descriptor:={}
var _generation: RefCounted
var _revision:=0

func build(bomb: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	hide()
	var descriptor:=Resources.prepare(library,bindings,bomb.get("weapon",{}))
	if descriptor.is_empty() or bomb.get("visuals",{}).get("models",[]).size()!=2:return reject("Prepare the bomb's original model clocks before geometry")
	for index in 2:
		for key in ["model_id","resource","start_ms","end_ms","loop"]:
			if bomb.visuals.models[index].get(key)!=descriptor.models[index][key]:return reject("Bomb animation metadata changed")
	var resources:=Models.new()
	if not resources.prepare(descriptor.models.map(func(row):return row.resource),library,visuals,bindings,"high",false,true):return reject(resources.error)
	_surface=Additive.new()
	for index in 2:
		var model: Node3D=resources.instantiate(descriptor.models[index].resource)
		if model==null:resources.clear();return reject("Original bomb model could not be instantiated")
		models.append(model);add_child(model);model.hide()
		model.set_meta("source_resource_id",descriptor.models[index].model_id)
		var sampler:=Sampler.new()
		if not sampler.configure(model.surfaces,descriptor.models[index].end_ms==0):resources.clear();return reject(sampler.error)
		if index==1:
			if not _surface.prepare_model(model):resources.clear();return reject(_surface.error)
		else:
			for instance in model.instances:instance.top_level=true
		_samplers.append(sampler)
	resources.clear();_descriptor=descriptor;_weapon=bomb.weapon.duplicate(true);_generation=RefCounted.new()
	return true

func prepare(bomb: Dictionary) -> Dictionary:
	error=""
	if _generation==null or bomb.get("weapon")!=_weapon or not bomb.get("shot") is Dictionary:return failed("Bomb geometry lost its retained weapon")
	var clocks: Variant=bomb.get("visuals",{}).get("models")
	if not clocks is Array or clocks.size()!=2:return failed("Bomb geometry lost its model clocks")
	for index in 2:
		for key in ["model_id","resource","start_ms","end_ms","loop"]:
			if clocks[index].get(key)!=_descriptor.models[index][key]:return failed("Bomb geometry changed its model identity")
		# Shared playback wraps by the absolute end, then adds the start. A
		# looping clock may briefly pass its last key, which the sampler holds.
		var maximum: int=clocks[index].end_ms
		if clocks[index].loop:maximum+=maxi(0,clocks[index].start_ms-1)
		if not Numbers.integer(clocks[index].get("time_ms"),clocks[index].start_ms,maximum) or not clocks[index].get("playing") is bool:return failed("Invalid bomb animation time")
	var frame:={"generation":_generation,"revision":_revision+1,"visible":false}
	var shot: Dictionary=bomb.shot
	if shot.is_empty() or shot.get("phase")=="detonated":return frame
	if shot.get("phase")!="flying" or not shot.get("position") is Vector3 or not shot.position.is_finite() or not shot.get("velocity") is Vector3 or not shot.velocity.is_finite():return failed("Bomb geometry lost its finite flying body")
	var forward:=Vectors.normalized(shot.velocity)
	var right:=Vectors.normalized(Vectors.cross(Vector3.UP,forward))
	var up:=Vectors.normalized(Vectors.cross(forward,right))
	var pose:=Transform3D(Basis(right,up,forward),shot.position)
	if not pose.is_finite():return failed("Bomb pose exceeds finite world coordinates")
	var samplers:=[];var surfaces:=[]
	for index in 2:
		var sampler: RefCounted=_samplers[index].fork_for_frame()
		var sample: Dictionary=sampler.sample(clocks[index].time_ms,pose)
		if sample.is_empty():return failed(sampler.error)
		var rows: Array=sample.surfaces if index==0 else _surface.prepare_surfaces(sample,Transform3D.IDENTITY,PackedByteArray([255,255,255,255]),Vector4.ONE)
		if rows.is_empty():return failed(_surface.error)
		samplers.append(sampler);surfaces.append(rows)
	frame.visible=true;frame.samplers=samplers;frame.surfaces=surfaces
	return frame

func commit(frame: Dictionary) -> void:
	if _generation==null or frame.get("generation")!=_generation or frame.get("revision")!=_revision+1:error="Bomb geometry cannot commit a stale frame";return
	_revision+=1
	visible=frame.visible
	for model in models:model.visible=frame.visible
	if not frame.visible:return
	for index in models[0].instances.size():models[0].instances[index].transform=frame.surfaces[0][index].pose
	_surface.apply_surfaces(models[1],frame.surfaces[1],1.0)
	_samplers=frame.samplers

func clear() -> void:
	for child in get_children():child.free()
	models.clear();_samplers=[];_surface=null;_weapon={};_descriptor={};_generation=null;_revision=0;error=""
func reject(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
