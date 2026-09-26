extends Node3D
## Passive retained AEM models. The admitted sequence supplies clocks and gates.
const Context=preload("res://src/simulation/mission_context.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Resources=preload("res://src/content/sequence_mesh_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Facing=preload("res://src/presentation/scenery_effect_pose.gd")
const Colors=preload("res://src/presentation/effect_color.gd")
var error:=""
var models: Array[Node3D]=[]
var _context: Context
var _generation: RefCounted
var _declarations: Array=[]
var _samplers: Array=[]
var _sample:={}
var _receipt:={}

## Declarations: model_id, face_forward, forward_offset. All clips play once.
func configure(context: Context,library: RefCounted,visuals: RefCounted,bindings: RefCounted,declarations: Array,supplement_path:="",quality:="high") -> bool:
	error=""
	if _context!=null or context==null or context.recipe().is_empty():return reject("Sequence effects require a fresh admitted mission context")
	for key in ["base_content_id","binding_id"]:
		if context.identity().get(key)!=bindings.get(key):return reject("Sequence effects belong to another admitted source")
	if declarations.is_empty() or declarations.size()>32:return reject("Invalid sequence model population")
	var source:=Resources.new()
	if not source.configure(bindings,library.manifest,supplement_path):return reject(source.error)
	var paths:=[];var ids:={}
	for row in declarations:
		if not row is Dictionary or not row.get("model_id") is int or ids.has(row.model_id) or not row.get("face_forward") is bool or not (row.get("forward_offset") is float or row.get("forward_offset") is int) or not is_finite(float(row.forward_offset)):return reject("Invalid sequence model declaration")
		var path:=source.resolve(row.model_id,"mesh")
		if path.is_empty():return reject(source.error)
		paths.append(path);ids[row.model_id]=true
	var resources:=Models.new()
	if not resources.prepare(paths,library,visuals,source,quality,false,true):return reject(resources.error)
	var pending: Array[Node3D]=[];var samplers:=[]
	for path in paths:
		var model: Node3D=resources.instantiate(path)
		var sampler:=Sampler.new()
		pending.append(model)
		if not sampler.configure(model.surfaces):
			for node in pending:node.free()
			resources.clear();return reject(sampler.error)
		samplers.append(sampler)
	resources.clear()
	models=pending;_samplers=samplers;_declarations=declarations.duplicate(true)
	_context=context;_generation=RefCounted.new();_receipt=source.receipt()
	for model in models:
		add_child(model);model.visible=false
		for instance in model.instances:instance.top_level=true
	return true

## State: revision, models[{model_id,visible,time_ms}], optional mothership_visible.
## renderer_forward is the renderer's actual forward vector, in world axes.
func prepare_state(context: Context,state: Dictionary,renderer_forward: Vector3) -> Dictionary:
	error=""
	if context!=_context or _generation==null:return failed("Sequence effects require their retained admitted context")
	if not state.get("revision") is int or state.revision<0 or not state.get("models") is Array or state.models.size()!=models.size():return failed("Invalid sequence effect state")
	if state.has("mothership_visible") and not state.mothership_visible is bool:return failed("Invalid mothership visibility directive")
	if not renderer_forward.is_finite() or renderer_forward.is_zero_approx():return failed("Sequence effects require a finite renderer direction")
	var sample:=state.duplicate(true);sample.renderer_forward=renderer_forward
	if not _sample.is_empty():
		if sample.revision<_sample.revision or (sample.revision==_sample.revision and sample!=_sample):return failed("Sequence effect revision regressed or changed")
		if sample==_sample:return {"repeat":true,"identity":_generation}
	var prepared:=[];var samplers:=[]
	for i in models.size():
		var row: Variant=state.models[i];var declaration: Dictionary=_declarations[i]
		if not row is Dictionary or row.get("model_id")!=declaration.model_id or not row.get("visible") is bool or not row.get("time_ms") is int or row.time_ms<0:return failed("Invalid retained model clock or visibility")
		if not _sample.is_empty() and row.time_ms<_sample.models[i].time_ms:return failed("Play-once sequence animation cannot rewind")
		var root:=Transform3D.IDENTITY
		root.origin=renderer_forward*float(declaration.forward_offset)
		if declaration.face_forward:
			var right:=Facing.normalized(Facing.cross(Vector3.UP,renderer_forward))
			root.basis=Basis(right,Facing.normalized(Facing.cross(renderer_forward,right)),renderer_forward)
		var sampler: RefCounted=_samplers[i].fork_for_frame()
		var animated: Dictionary=sampler.sample(row.time_ms,root)
		if animated.is_empty():return failed(sampler.error)
		for surface in animated.surfaces:
			var color:=Colors.tint(PackedByteArray([255,255,255,255]),Vector4.ONE,surface.get("color_byte",-1))
			if color.is_empty():return failed("Invalid authored sequence animation color")
			surface.tint=color.value
		prepared.append({"root":root,"surfaces":animated.surfaces,"visible":row.visible,"animation_range":sampler.snapshot().range})
		samplers.append(sampler)
	return {"identity":_generation,"previous_revision":_sample.get("revision",-1),"sample":sample,"models":prepared,"samplers":samplers}

func commit_state(frame: Dictionary) -> bool:
	if frame.get("identity")!=_generation or frame.get("repeat",false) or frame.get("previous_revision")!=_sample.get("revision",-1):return false
	for i in models.size():
		models[i].visible=frame.models[i].visible
		for j in models[i].instances.size():
			var surface: Dictionary=frame.models[i].surfaces[j]
			models[i].instances[j].transform=surface.pose
			models[i].materials[j].set_shader_parameter("surface_tint",surface.tint)
	_samplers=frame.samplers;_sample=frame.sample.duplicate(true)
	_sampled_models=frame.models.duplicate(true)
	return true

var _sampled_models: Array=[]
func snapshot() -> Dictionary:
	return {"state":_sample.duplicate(true),"models":_sampled_models.duplicate(true),"resource_supplement":_receipt.duplicate(true)}
func failed(message: String) -> Dictionary:error=message;return {}
func reject(message: String) -> bool:error=message;return false
