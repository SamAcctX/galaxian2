extends Node3D
## Original beam and muzzle animations follow the retained shot clock.
const Beam=preload("res://src/simulation/beam_primary.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
var error:=""
var _models:=[]
var _samplers:=[]
var _ranges:=[]
var _surface: RefCounted

func build(row: Dictionary, library: RefCounted, visuals: RefCounted, bindings: RefCounted) -> bool:
	var resources:=Models.new();var paths:=[row.resource,bindings.resolve(row.beam.muzzle_model_id,"mesh")]
	if not resources.prepare(paths,library,visuals,bindings,"high",false,true):return reject(resources.error)
	_surface=Surface.new()
	for path in paths:
		var model: Node3D=resources.instantiate(path)
		if model==null:return reject(resources.error)
		add_child(model);model.visible=false
		if not _surface.prepare_model(model):return reject(_surface.error)
		var sampler:=Sampler.new()
		if not sampler.configure(model.surfaces):return reject(sampler.error)
		_models.append(model);_samplers.append(sampler);_ranges.append(sampler.snapshot().range)
	resources.clear()
	if _ranges[0]!={"start_ms":row.start_ms,"end_ms":row.end_ms}:return reject("Beam animation metadata changed")
	return true

func prepare(weapon: Dictionary, parent_rgba: PackedByteArray, tint: Vector4) -> Dictionary:
	error=""
	var shot: Dictionary=weapon.get("beam",{})
	var prepared:=[];var samplers:=[]
	for i in _models.size():
		var sampler: RefCounted=_samplers[i].fork_for_frame()
		var visible:=not shot.is_empty()
		if visible:
			visible=shot.age_ms<=_ranges[i].end_ms-_ranges[i].start_ms
			if i==1:visible=visible and shot.age_ms<weapon.weapon.interval_ms
		var surfaces:=[]
		if visible:
			var animation: Dictionary=sampler.sample(int(_ranges[i].start_ms)+int(shot.age_ms),Transform3D.IDENTITY)
			if animation.is_empty():return failed(sampler.error)
			surfaces=_surface.prepare_surfaces(animation,Beam.presentation(shot,i==1),parent_rgba,tint)
			if surfaces.is_empty():return failed(_surface.error)
		prepared.append({"visible":visible,"surfaces":surfaces,"time_ms":int(_ranges[i].start_ms)+int(shot.age_ms)});samplers.append(sampler)
	return {"models":prepared,"samplers":samplers}

func commit(prepared: Dictionary, darken: float) -> void:
	for i in _models.size():
		var row: Dictionary=prepared.models[i]
		_models[i].visible=row.visible
		if row.visible:
			_surface.apply_surfaces(_models[i],row.surfaces,darken)
			_surface.apply_uv(_models[i],float(row.get("time_ms",0)))
	_samplers=prepared.samplers

func reject(message: String) -> bool:error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
