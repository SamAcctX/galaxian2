extends MeshInstance3D
## Crossed, diagonal ribbons use the imported additive atlas. Geometry consumes
## retained simulation sections and never advances an emission or fade clock.
const Definitions=preload("res://src/content/projectile_trail_definitions.gd")
const Materials=preload("res://src/presentation/material_library.gd")
var error:=""
var _preset:={}

static func supported_material(bindings: RefCounted) -> bool:
	var material: Dictionary=bindings.resolve_material(Definitions.MATERIAL_ID)
	return Materials.supports(material) and material.get("render_type")==3 and material.get("texture_ids",[])[0]==Definitions.TEXTURE_ID and not material.texture_paths[0].is_empty()

func build(preset_id: int, library: RefCounted, visuals: RefCounted, bindings: RefCounted) -> bool:
	_preset=Definitions.trail(preset_id)
	if _preset.is_empty() or library.manifest.get("content_id")!=bindings.base_content_id or visuals.base_content_id!=bindings.base_content_id or not supported_material(bindings):return reject("Projectile trails require their original additive atlas")
	var descriptor: Dictionary=bindings.resolve_material(Definitions.MATERIAL_ID)
	var pixels: Image=visuals.load_image(descriptor.texture_paths[0])
	if pixels==null:return reject(visuals.error)
	material_override=Materials.create(3,ImageTexture.create_from_image(pixels),null,true)
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	visible=false
	return true

func prepare(trails: Array, tint: Vector4) -> Dictionary:
	error=""
	var data:={"vertices":PackedVector3Array(),"uvs":PackedVector2Array(),"colors":PackedFloat32Array(),"indices":PackedInt32Array()}
	for trail in trails:
		if trail.is_empty():continue
		if trail.preset!=_preset or trail.sections.size()>_preset.capacity:return failed("Projectile trail population changed")
		for index in trail.sections.size():
			var section: Dictionary=trail.sections[index]
			var end:=_fade(section.age_ms)
			var start:=0.0 if index==0 else _fade(trail.sections[index-1].age_ms)
			var uv: Vector4=_preset.uv_rect
			uv.w=lerpf(uv.y,uv.w,float(section.get("uv_fraction",1.0)))
			if not append_section(data,section.from,section.to,start,end,uv,tint):return failed("Nonfinite projectile trail section")
		if trail.emitting:
			var head: Transform3D=trail.head
			var edge:=Transform3D(head.basis,head.origin-head.basis.z*float(_preset.cap_length))
			var uv: Vector4=_preset.uv_rect;uv.w=lerpf(uv.y,uv.w,0.05)
			if not append_section(data,edge,head,1.0,0.0,uv,tint):return failed("Nonfinite projectile trail cap")
	var result: ArrayMesh
	if not data.vertices.is_empty():
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_TEX_UV]=data.uvs
		arrays[Mesh.ARRAY_CUSTOM0]=data.colors;arrays[Mesh.ARRAY_INDEX]=data.indices
		result=ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return {"mesh":result,"quads":data.vertices.size()/4}

func _fade(age_ms: int) -> float:return clampf(1.0-float(age_ms)/float(_preset.lifetime_ms),0.0,1.0)

func append_section(data: Dictionary, start: Transform3D, end: Transform3D, start_fade: float, end_fade: float, uv: Vector4, tint: Vector4) -> bool:
	if not start.is_finite() or not end.is_finite():return false
	# Mesh coordinates pass through the source renderer's row flip. Sprite
	# atlas coordinates use a different setter and do not share this conversion.
	uv.y=1.0-uv.y;uv.w=1.0-uv.w
	var width:=float(_preset.half_width)*sqrt(0.5)
	for sign in [-1.0,1.0]:
		var a: Vector3=(start.basis.x+start.basis.y*sign)*width
		var b: Vector3=(end.basis.x+end.basis.y*sign)*width
		var vertices:=PackedVector3Array([start.origin-a,start.origin+a,end.origin+b,end.origin-b])
		for vertex in vertices:
			if not vertex.is_finite():return false
		var first: int=data.vertices.size()
		data.vertices.append_array(vertices)
		data.uvs.append_array(PackedVector2Array([Vector2(uv.x,uv.y),Vector2(uv.z,uv.y),Vector2(uv.z,uv.w),Vector2(uv.x,uv.w)]))
		for fade in [start_fade,start_fade,end_fade,end_fade]:
			var color: Vector4=tint*fade
			data.colors.append_array(PackedFloat32Array([color.x,color.y,color.z,color.w]))
		data.indices.append_array(PackedInt32Array([first,first+2,first+1,first,first+3,first+2]))
	return true

func commit(prepared: Dictionary) -> void:
	mesh=prepared.mesh;visible=mesh!=null

func reject(message: String) -> bool:error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
