extends RefCounted
## Imported tractor meshes use the shared original model playback and additive
## surface rules; the expansion beam (type 3) is drawn two-sided. This preparation grants no equipment or recovery progress.
const Definitions=preload("res://src/content/tractor_recovery_definitions.gd")
const AEM=preload("res://src/content/aem.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
var error:=""

func prepare(library: RefCounted,bindings: RefCounted,model_id: int) -> Dictionary:
	error=""
	if library==null or bindings==null or not Definitions.available(bindings) or library.manifest.get("content_id")!=bindings.base_content_id:return fail("Tractor resources require matching imported content")
	var equipment: Dictionary=bindings.mido_travel.tractor_recovery.equipment
	if model_id<int(equipment.beam_model_base) or model_id>int(equipment.beam_model_base)+int(equipment.beam_fallback_selector):return fail("Unknown tractor beam model")
	var path: String=bindings.resolve(model_id,"mesh")
	var render_type:=int(bindings.material_for_mesh(path,"high").get("render_type",-1))
	if path.is_empty() or render_type not in [2,3]:return fail("Unsupported tractor beam material")
	var reader:=AEM.new();var mesh:=reader.decode(library.read_resource(path,AEM.MAX_BYTES))
	if mesh.is_empty():return fail(reader.error)
	if not mesh.surfaces.all(func(surface):return Surface.supported_surface(surface)):return fail("Unsupported tractor beam surface animation")
	var sampler:=Sampler.new()
	if not sampler.configure(mesh.surfaces,true):return fail(sampler.error)
	var timing: Dictionary=sampler.snapshot().range
	return {"model_id":model_id,"resource":path,"render_type":render_type,"start_ms":timing.start_ms,"end_ms":timing.end_ms}

func fail(message: String) -> Dictionary:error=message;return {}
