extends Node3D
## Original animated bomb body and glow. The weapon owns both clocks; geometry
## samples accepted state without advancing physics or restarting animation.
## Visual roll at full left/right stick (assumption: the original amount is not recovered).
const BANK_RADIANS:=0.6
const Resources=preload("res://src/content/bomb_projectile_resources.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Additive=preload("res://src/presentation/animated_additive_model.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Definitions=preload("res://src/content/emp_bombs_definitions.gd")
const Trail=preload("res://src/presentation/bomb_trail_geometry.gd")
var error:=""
var models: Array[Node3D]=[]
var _samplers:=[]
var _surface: RefCounted
var _weapon:={}
var _descriptor:={}
var _generation: RefCounted
var _revision:=0
## The sprite trail of a bomb that emits one in flight (Fireworks), else null.
var trail: Node3D

func build(bomb: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	hide()
	var descriptor:=Resources.prepare(library,bindings,bomb.get("weapon",{}))
	# A bodiless blast (Shock Blast) draws nothing in flight.
	if not descriptor.is_empty() and descriptor.models.is_empty() and bomb.get("visuals",{}).get("models",[]).is_empty():
		_descriptor=descriptor;_weapon=bomb.weapon.duplicate(true);_generation=RefCounted.new()
		return true
	# A body and its glow, or a body alone (Fireworks).
	if descriptor.is_empty() or bomb.get("visuals",{}).get("models",[]).size()!=descriptor.models.size():return reject("Prepare the bomb's original model clocks before geometry")
	for index in descriptor.models.size():
		for key in ["model_id","resource","start_ms","end_ms","loop"]:
			if bomb.visuals.models[index].get(key)!=descriptor.models[index][key]:return reject("Bomb animation metadata changed")
	var resources:=Models.new()
	if not resources.prepare(descriptor.models.map(func(row):return row.resource),library,visuals,bindings,"high",false,true):return reject(resources.error)
	_surface=Additive.new()
	for index in descriptor.models.size():
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
	var preset:=Definitions.flight_trail(int(bomb.weapon.get("item_id",-1)))
	if not preset.is_empty():
		var built:=Trail.new();add_child(built)
		if not built.configure(preset,bindings,visuals,int(bomb.get("elapsed_ms",0))):return reject(built.error)
		trail=built
	return true

func prepare(bomb: Dictionary) -> Dictionary:
	error=""
	if _generation==null or bomb.get("weapon")!=_weapon or not bomb.get("shot") is Dictionary:return failed("Bomb geometry lost its retained weapon")
	var clocks: Variant=bomb.get("visuals",{}).get("models")
	if _descriptor.models.is_empty():return {"generation":_generation,"revision":_revision+1,"visible":false}
	if not clocks is Array or clocks.size()!=_descriptor.models.size():return failed("Bomb geometry lost its model clocks")
	for index in clocks.size():
		for key in ["model_id","resource","start_ms","end_ms","loop"]:
			if clocks[index].get(key)!=_descriptor.models[index][key]:return failed("Bomb geometry changed its model identity")
		# Shared playback wraps by the absolute end, then adds the start. A
		# looping clock may briefly pass its last key, which the sampler holds.
		var maximum: int=clocks[index].end_ms
		if clocks[index].loop:maximum+=maxi(0,clocks[index].start_ms-1)
		if not Numbers.integer(clocks[index].get("time_ms"),clocks[index].start_ms,maximum) or not clocks[index].get("playing") is bool:return failed("Invalid bomb animation time")
	var frame:={"generation":_generation,"revision":_revision+1,"visible":false}
	var shot: Dictionary=bomb.shot
	if shot.is_empty() or shot.get("phase")=="detonated":return _with_trail(frame,bomb,null)
	if shot.get("phase")!="flying" or not shot.get("position") is Vector3 or not shot.position.is_finite() or not shot.get("velocity") is Vector3 or not shot.velocity.is_finite():return failed("Bomb geometry lost its finite flying body")
	var forward:=Vectors.normalized(shot.velocity)
	var right:=Vectors.normalized(Vectors.cross(Vector3.UP,forward))
	var up:=Vectors.normalized(Vectors.cross(forward,right))
	var pose:=Transform3D(Basis(right,up,forward),shot.position)
	# A guided missile banks into its turns (left/right stick).
	var bank: float=float(shot.get("bank",0.0))
	if bank!=0.0:pose.basis=pose.basis*Basis(Vector3(0,0,1),-bank*BANK_RADIANS)
	if not pose.is_finite():return failed("Bomb pose exceeds finite world coordinates")
	var samplers:=[];var surfaces:=[]
	for index in clocks.size():
		var sampler: RefCounted=_samplers[index].fork_for_frame()
		var sample: Dictionary=sampler.sample(clocks[index].time_ms,pose)
		if sample.is_empty():return failed(sampler.error)
		var rows: Array=sample.surfaces if index==0 else _surface.prepare_surfaces(sample,Transform3D.IDENTITY,PackedByteArray([255,255,255,255]),Vector4.ONE)
		if rows.is_empty():return failed(_surface.error)
		samplers.append(sampler);surfaces.append(rows)
	frame.visible=true;frame.samplers=samplers;frame.surfaces=surfaces
	return _with_trail(frame,bomb,pose)

## The trail follows the bomb's own simulation clock, before and after the burst.
func _with_trail(frame: Dictionary,bomb: Dictionary,pose: Variant) -> Dictionary:
	if trail==null:return frame
	var prepared: Dictionary=trail.prepare(bomb,pose)
	if prepared.is_empty():return failed(trail.error)
	frame.trail=prepared
	return frame

func commit(frame: Dictionary) -> void:
	if _generation==null or frame.get("generation")!=_generation or frame.get("revision")!=_revision+1:error="Bomb geometry cannot commit a stale frame";return
	_revision+=1
	# A trail outlives the body, so its parent stays shown.
	if trail!=null:trail.commit(frame.get("trail",{}))
	visible=frame.visible or (trail!=null and trail.sprites>0)
	if models.is_empty():return
	for model in models:model.visible=frame.visible
	if not frame.visible:return
	for index in models[0].instances.size():models[0].instances[index].transform=frame.surfaces[0][index].pose
	if models.size()>1:_surface.apply_surfaces(models[1],frame.surfaces[1],1.0)
	_samplers=frame.samplers

func clear() -> void:
	for child in get_children():child.free()
	models.clear();trail=null;_samplers=[];_surface=null;_weapon={};_descriptor={};_generation=null;_revision=0;error=""
func reject(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
