extends Node3D
## Original station assembly using the mesh's existing engine axes. Animated
## layers (the blinking additive lights) loop their authored keys on the flight clock.
const Resources=preload("res://src/content/station_exterior_resources.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
var error:=""
var station: Node3D
var layers: Array[Node3D]=[]
var _state:={}
var _loops:=[]

func build(library: RefCounted, visuals: RefCounted, bindings: RefCounted, resources: RefCounted) -> bool:
	clear()
	if resources==null or resources.get_script()!=Resources or resources.snapshot().is_empty():return fail("Prepare the current station exterior before rendering it")
	var state: Dictionary=resources.snapshot()
	if state.base_content_id!=bindings.base_content_id or state.binding_id!=bindings.binding_id:return fail("Station geometry belongs to another content identity")
	var paths:=[]
	for layer in state.layers:paths.append(layer.path)
	var models:=Models.new()
	if not models.prepare(paths,library,visuals,bindings,"high",false,true):return fail(models.error)
	station=Node3D.new();station.name="StationExterior";station.transform=state.pose;add_child(station)
	station.set_meta("source_station_id",state.station_id)
	var axes:=Node3D.new();axes.name="SourceMeshAxes";axes.basis=state.mesh_axes;station.add_child(axes)
	for layer in state.layers:
		var model: Node3D=models.instantiate(layer.path)
		if model==null:
			var reason: String=models.error;models.clear();return fail(reason)
		model.set_meta("source_resource_id",layer.resource_id);axes.add_child(model);layers.append(model)
		var sampler:=_sampler(model)
		if sampler!=null:_loops.append([model,sampler])
	models.clear();_state=state
	return true

func apply_state(state: Dictionary,time_ms:=-1) -> bool:
	error=""
	if station==null or state!=_state:return reject("Station geometry changed its prepared identity, pose or resources")
	if time_ms>=0:
		for row in _loops:
			var timing: Dictionary=row[1].snapshot().range
			var sample: Dictionary=row[1].sample(int(timing.start_ms)+time_ms%(int(timing.end_ms)-int(timing.start_ms)),Transform3D.IDENTITY)
			if sample.is_empty():return reject(row[1].error)
			for index in sample.surfaces.size():
				var surface: Dictionary=sample.surfaces[index]
				row[0].instances[index].transform=surface.pose
				var tint:=float(surface.get("color_byte",255))/255.0
				row[0].instances[index].visible=tint>0
				row[0].materials[index].set_shader_parameter("surface_tint",Vector4.ONE*tint)
	return true

## Layers with authored keys (geometry or light level) get a looping sampler.
func _sampler(model: Node3D) -> RefCounted:
	if not "surfaces" in model:return null
	var surfaces:=[]
	for surface in model.surfaces:
		var row: Dictionary=surface.duplicate();row.tracks=surface.tracks.duplicate();row.tracks.erase("uv");surfaces.append(row)
	var sampler:=Sampler.new()
	if not sampler.configure(surfaces,true):return null
	var timing: Dictionary=sampler.snapshot().range
	return sampler if int(timing.end_ms)>int(timing.start_ms) else null

func animated_layers() -> int:return _loops.size()

func clear() -> void:
	for child in get_children():child.free()
	station=null;layers=[];_state={};_loops=[];error=""
func fail(message: String) -> bool:clear();error=message;return false
func reject(message: String) -> bool:error=message;return false
