extends Node
## Plays a model's own looping clip on its mesh instances (additive overlays
## such as a ship's sweeping light, animated hulls, fire meshes) in scenes that
## otherwise draw models at a fixed pose. Pauses with the scene tree.
const SourceAnimation = preload("res://src/presentation/scenery_animation.gd")

var _model: Node3D
var _sampler: RefCounted
var _start:=0
var _span:=1
var _elapsed:=0.0

func configure(model: Node3D) -> bool:
	var sampler:=SourceAnimation.new()
	if model==null or not sampler.configure(model.surfaces):return false
	var clip: Dictionary=sampler.time_range()
	_model=model;_sampler=sampler;_start=int(clip.start_ms);_span=maxi(1,int(clip.end_ms)-_start)
	return true

func _process(delta: float) -> void:
	if _model==null or not is_instance_valid(_model) or not _model.is_visible_in_tree():return
	_elapsed=fmod(_elapsed+delta*1000.0,float(_span))
	var rows: Array=_sampler.sample(_start+int(_elapsed),Transform3D.IDENTITY).get("surfaces",[])
	for index in mini(rows.size(),_model.instances.size()):_model.instances[index].transform=rows[index].pose
