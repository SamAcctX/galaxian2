extends RefCounted
## Retained body materials are restored exactly. No presentation clock or RNG.
const Definitions=preload("res://src/content/cloak_definitions.gd")
const Materials=preload("res://src/presentation/material_library.gd")
const SurfaceShader=preload("res://src/presentation/surface_response.gdshader")
const CloakedSurface=preload("res://src/presentation/cloaked_surface.gdshader")
const ShaderSource=preload("res://src/presentation/cloaked_ship.gdshader")
const Background=preload("res://src/presentation/cloak_background.gd")
var error:=""
var _surfaces: Array=[]
var _attachments: Array=[]
var _active:=false
var _sample:={}
var _background: SubViewport

func prepare(ship: Node3D,visuals: RefCounted) -> bool:
	if not _surfaces.is_empty() or visuals==null:return reject("Prepare a fresh cloak on original ship materials")
	var mask: Image=visuals.load_image(Definitions.CLOAK_MAP)
	if mask==null:return reject(visuals.error)
	var texture:=ImageTexture.create_from_image(mask)
	for node in ship.find_children("*","MeshInstance3D",true,false):
		var original: ShaderMaterial=node.material_override
		if original==null:return reject("Cloak requires the ship's retained material")
		if original.shader in [Materials.SHADERS[28],SurfaceShader]:
			var refracting:=ShaderMaterial.new();refracting.shader=CloakedSurface if original.shader==SurfaceShader else ShaderSource
			for uniform in original.shader.get_shader_uniform_list():
				var value: Variant=original.get_shader_parameter(uniform.name)
				if value!=null:refracting.set_shader_parameter(uniform.name,value)
			refracting.set_shader_parameter("cloak_mask",texture)
			_surfaces.append({"node":node,"original":original,"cloak":refracting})
		elif original.shader in [Materials.SHADERS[2],Materials.SHADERS[3],Materials.SHADERS[18]]:
			var tint: Variant=original.get_shader_parameter("surface_tint")
			_attachments.append({"material":original,"tint":Vector4.ONE if tint==null else tint})
	if _surfaces.is_empty():return reject("Cloak has no supported hull surface")
	_background=Background.new();_background.prepare(ship)
	for row in _surfaces:row.cloak.set_shader_parameter("background",_background.get_texture())
	return true

func present(state: Dictionary) -> bool:
	if _surfaces.is_empty():return reject("Prepare original cloak materials before presentation")
	for key in ["dissolve","animation_seconds","attachment_alpha"]:
		var value: Variant=state.get(key)
		if not (value is float or value is int) or not is_finite(value) or value<0.0 or value>1000.0:return reject("Invalid cloak appearance sample")
	if not state.get("active") is bool:return reject("Cloak visibility requires its accepted lifecycle")
	_background.set_active(state.active)
	for row in _surfaces:
		if state.active!=_active:row.node.material_override=row.cloak if state.active else row.original
		if state.active:
			row.cloak.set_shader_parameter("dissolve",state.dissolve)
			row.cloak.set_shader_parameter("animation_seconds",state.animation_seconds)
	for row in _attachments:
		var tint: Vector4=row.tint
		# Source additive attachment blending uses RGB, with no alpha factor.
		if state.active:tint=Vector4(tint.x*state.attachment_alpha,tint.y*state.attachment_alpha,tint.z*state.attachment_alpha,tint.w)
		row.material.set_shader_parameter("surface_tint",tint)
	_active=state.active;_sample=state.duplicate(true)
	return true

func snapshot() -> Dictionary:return _sample.duplicate(true)
func reject(message: String) -> bool:error=message;return false
