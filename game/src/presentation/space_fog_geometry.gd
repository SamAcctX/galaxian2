extends MultiMeshInstance3D
## One instanced draw for the nearby cloud field. The sky's rotating/translated
## parent never transforms world-space centers; camera facing is done on the GPU.
const Field=preload("res://src/presentation/space_fog_field.gd")
const Sprites=preload("res://src/presentation/opening_damage_geometry.gd")
const SHADER=preload("res://src/presentation/space_fog.gdshader")
var error:=""
var selection:={}
var _field: RefCounted

func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted,sky_index: int,seed_value: int,velocity:=Vector3.ZERO,color_scale:=0.6) -> bool:
	if library==null or visuals==null or bindings==null or library.manifest.get("content_id")!=bindings.base_content_id or visuals.base_content_id!=bindings.base_content_id:
		return reject("Space cloud resources belong to another content identity")
	var field:=Field.new()
	if not field.configure(sky_index,seed_value,velocity,color_scale):return reject(field.error)
	var material_id:=20137 if sky_index==12 else 20095
	var descriptor: Dictionary=bindings.resolve_material(material_id)
	if descriptor.is_empty() or descriptor.render_type!=2 or descriptor.texture_paths[0].is_empty():return reject("Space clouds require their additive texture material")
	var image: Image=visuals.load_image(descriptor.texture_paths[0])
	if image==null:return reject(visuals.error)
	var material:=ShaderMaterial.new();material.shader=SHADER
	material.set_shader_parameter("diffuse_texture",ImageTexture.create_from_image(image))
	var quad:=Sprites.sprite(Vector3.ZERO,{"size":int(Field.SIZE),"uv_rect":Vector4(0.01,0.01,0.99,0.99),"color":Color.WHITE})
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=quad.vertices;arrays[Mesh.ARRAY_TEX_UV]=quad.uvs
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_colors=true
	batch.mesh=mesh;batch.instance_count=Field.COUNT;batch.visible_instance_count=0
	multimesh=batch;material_override=material;_field=field
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	top_level=true;transform=Transform3D.IDENTITY
	selection={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"sky_index":sky_index,"material_id":material_id,"texture_id":int(descriptor.texture_ids[0])}
	error="";return true

func prepare_view(pose: Transform3D,elapsed_ms:=0) -> RefCounted:
	error=""
	if _field==null:error="Space clouds have not been built";return null
	var candidate: RefCounted=_field.sample(pose.origin,elapsed_ms)
	if candidate==null:error=_field.error
	return candidate

func commit_view(candidate: RefCounted) -> void:
	if candidate==_field:return
	var state: Dictionary=candidate.snapshot()
	for index in Field.COUNT:
		multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,state.positions[index]))
		var color: Color=state.tint*float(state.weights[index]);color.a=1.0
		multimesh.set_instance_color(index,color)
	# Billboard rotation can extend beyond the mesh's unrotated instance AABBs.
	var radius:=Field.RADIUS+Field.SIZE
	multimesh.custom_aabb=AABB(state.camera-Vector3.ONE*radius,Vector3.ONE*radius*2.0)
	multimesh.visible_instance_count=Field.COUNT;_field=candidate

func snapshot() -> Dictionary:return {} if _field==null else _field.snapshot()
func reject(message: String) -> bool:error=message;return false
