extends Node
## Optional display-texture glare. Owns only filter targets, never the scene.
const RESPONSE=preload("res://src/presentation/bloom_response.gdshader")
const FILTER=preload("res://src/presentation/bloom_filter.gdshader")
const COMPOSITE=preload("res://src/presentation/bloom_composite.gdshader")
const TARGET_SIZE=Vector2i(256,256)
var error:=""
var composite: ShaderMaterial
var _targets: Array[SubViewport]=[]
var _active:=false

func build(source: Texture2D) -> bool:
	if not is_inside_tree() or source==null or source.get_width()<1 or source.get_height()<1:
		error="Bloom requires an attached owner and a nonempty display texture";return false
	if not _targets.is_empty():
		error="Bloom already owns its display texture";return false
	var response:=ShaderMaterial.new();response.shader=RESPONSE
	var previous: Texture2D=_append_target(source,response)
	# A general sampling graph expresses the tilted point spread without
	# changing the input camera, world, render format or texture interpretation.
	for repetition in 6:
		for direction in [Vector2.ONE,Vector2.DOWN]:
			var filter:=ShaderMaterial.new();filter.shader=FILTER
			var offsets:=PackedVector2Array([Vector2.ZERO])
			for distance in [18.0/13.0,-18.0/13.0,42.0/13.0,-42.0/13.0]:
				offsets.append(direction*distance/Vector2(TARGET_SIZE))
			filter.set_shader_parameter("sample_offsets",offsets)
			filter.set_shader_parameter("sample_weights",PackedFloat32Array([84.0/370.0,117.0/370.0,117.0/370.0,26.0/370.0,26.0/370.0]))
			previous=_append_target(previous,filter)
	composite=ShaderMaterial.new();composite.shader=COMPOSITE
	composite.set_shader_parameter("glare",previous)
	set_active(true);error="";return true

func _append_target(source: Texture2D,filter: ShaderMaterial) -> Texture2D:
	var target:=SubViewport.new();target.name="GlarePass%d"%_targets.size()
	target.size=TARGET_SIZE;target.disable_3d=true;target.use_hdr_2d=false
	target.gui_disable_input=true;target.handle_input_locally=false
	target.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var image:=TextureRect.new();image.size=Vector2(TARGET_SIZE)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_SCALE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	image.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	image.texture=source;image.material=filter
	add_child(target);target.add_child(image);_targets.append(target)
	return target.get_texture()

func set_active(value: bool) -> void:
	if value==_active:return
	_active=value
	for target in _targets:
		target.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func target_count() -> int:return _targets.size()

func glare_texture() -> Texture2D:
	return null if _targets.is_empty() else _targets[-1].get_texture()
