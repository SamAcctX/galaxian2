extends MultiMeshInstance3D
## The imported nearby dust sprite, with its own normal map and one key light.
## Billboard work stays on the GPU and the complete population uses one draw.
const Field=preload("res://src/presentation/foreground_particle_field.gd")
const LightState=preload("res://src/presentation/material_light_state.gd")
const Response=preload("res://src/presentation/surface_response.gd")
const SHADER=preload("res://src/presentation/foreground_particles.gdshader")
var error:=""
var selection:={}
var _field: RefCounted

func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted,environment: Dictionary,seed_value: int) -> bool:
	if _field!=null:return reject("Nearby particles already belong to a flight")
	if library==null or visuals==null or bindings==null or library.manifest.get("content_id")!=bindings.base_content_id or visuals.base_content_id!=bindings.base_content_id:
		return reject("Nearby particle resources belong to another content identity")
	for key in ["base_content_id","binding_id"]:
		if environment.get(key)!=bindings.get(key):return reject("Nearby particle lighting belongs to another content identity")
	var descriptor: Dictionary=bindings.resolve_material(20092)
	if descriptor.is_empty() or descriptor.render_type!=36 or descriptor.texture_paths[0].is_empty() or descriptor.texture_paths[1].is_empty() or not descriptor.texture_paths.slice(2).all(func(path):return path.is_empty()):
		return reject("Nearby particles require their diffuse and normal/specular material")
	var diffuse: Image=visuals.load_image(descriptor.texture_paths[0])
	if diffuse==null:return reject(visuals.error)
	var detail: Image=visuals.load_image(descriptor.texture_paths[1])
	if detail==null:return reject(visuals.error)
	var lights:=LightState.new()
	if not lights.build(environment.get("surface_material",bindings.surface_material),environment):return reject(lights.error)
	var material:=ShaderMaterial.new();material.shader=SHADER
	material.set_shader_parameter("diffuse_texture",ImageTexture.create_from_image(diffuse))
	material.set_shader_parameter("normal_specular_texture",ImageTexture.create_from_image(detail))
	material.set_shader_parameter("specular_power",lights.state.specular_power)
	material.set_shader_parameter("diffuse_bias",Response.HIGH_QUALITY.diffuse_bias)
	material.set_shader_parameter("normal_bias",Response.HIGH_QUALITY.normal_bias)
	var light: Dictionary=lights.state.lights[0]
	material.set_shader_parameter("light_direction",light.direction_to_light)
	for kind in ["ambient","diffuse","specular"]:material.set_shader_parameter(kind+"_color",light[kind])
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(1,1,0),Vector3(-1,1,0)])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_colors=true
	batch.mesh=mesh;batch.instance_count=Field.COUNT;batch.visible_instance_count=0
	multimesh=batch;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	top_level=true;transform=Transform3D.IDENTITY
	_field=Field.new();_field.configure(seed_value)
	selection={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"material_id":int(descriptor.id),"texture_ids":descriptor.texture_ids.slice(0,2)}
	error="";return true

func prepare_view(pose: Transform3D,elapsed_ms: int) -> RefCounted:
	error=""
	if _field==null:error="Nearby particles have not been built";return null
	var candidate: RefCounted=_field.sample(pose,elapsed_ms)
	if candidate==null:error=_field.error
	return candidate

func commit_view(candidate: RefCounted) -> void:
	if candidate==_field:return
	multimesh.buffer=candidate.instance_buffer()
	var radius:=Field.RADIUS+60.0
	multimesh.custom_aabb=AABB(candidate._camera-Vector3.ONE*radius,Vector3.ONE*radius*2.0)
	multimesh.visible_instance_count=Field.COUNT;_field=candidate

func snapshot() -> Dictionary:return {} if _field==null else _field.snapshot()
func reject(message: String) -> bool:error=message;return false
