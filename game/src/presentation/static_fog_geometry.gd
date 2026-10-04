extends MultiMeshInstance3D
## A fixed cloud of the sky's additive fog sprites around one object (pirate
## outposts). The sprites are scattered once and never move, fade or expire.
const Sprites=preload("res://src/presentation/opening_damage_geometry.gd")
const SHADER=preload("res://src/presentation/space_fog.gdshader")
var error:=""

## rule: count, size, scatter (half extent of the cube around center), rgb.
func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted,sky_index: int,center: Vector3,rule: Dictionary,seed_value: int) -> bool:
	if library==null or visuals==null or bindings==null or library.manifest.get("content_id")!=bindings.base_content_id or visuals.base_content_id!=bindings.base_content_id:
		return reject("Object fog resources belong to another content identity")
	if not center.is_finite() or int(rule.get("count",0))<=0 or int(rule.get("size",0))<=0 or float(rule.get("scatter",0))<=0.0:return reject("Invalid object fog rule")
	var descriptor: Dictionary=bindings.resolve_material(20137 if sky_index==12 else 20095)
	if descriptor.is_empty() or descriptor.render_type!=2 or descriptor.texture_paths[0].is_empty():return reject("Object fog requires the additive cloud material")
	var image: Image=visuals.load_image(descriptor.texture_paths[0])
	if image==null:return reject(visuals.error)
	var material:=ShaderMaterial.new();material.shader=SHADER
	material.set_shader_parameter("diffuse_texture",ImageTexture.create_from_image(image))
	var quad:=Sprites.sprite(Vector3.ZERO,{"size":int(rule.size),"uv_rect":Vector4(0,0,1,1),"color":Color.WHITE})
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=quad.vertices;arrays[Mesh.ARRAY_TEX_UV]=quad.uvs
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var count:=int(rule.count);var scatter:=float(rule.scatter);var rgb:=int(rule.rgb)
	var color:=Color(float((rgb>>16)&255)/255.0,float((rgb>>8)&255)/255.0,float(rgb&255)/255.0)
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_colors=true
	batch.mesh=mesh;batch.instance_count=count
	var random:=RandomNumberGenerator.new();random.seed=seed_value
	for index in count:
		var offset:=Vector3(random.randf_range(-scatter,scatter),random.randf_range(-scatter,scatter),random.randf_range(-scatter,scatter))
		batch.set_instance_transform(index,Transform3D(Basis.IDENTITY,center+offset))
		batch.set_instance_color(index,color)
	# Billboards turn on the GPU; cover every orientation of each square.
	var radius:=scatter+float(rule.size)
	batch.custom_aabb=AABB(center-Vector3.ONE*radius,Vector3.ONE*radius*2.0)
	multimesh=batch;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	top_level=true;transform=Transform3D.IDENTITY
	error="";return true

func reject(message: String) -> bool:error=message;return false
