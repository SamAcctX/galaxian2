extends TextureRect
## Keep 3D at physical resolution while the surrounding interface uses UI scale.
const Bloom=preload("res://src/presentation/scene_bloom.gd")
const Effects=preload("res://src/presentation/scene_effect_settings.gd")
var viewport: SubViewport
var owns_viewport:=true
var error:=""
var _bloom: Node
var _bloom_requested:=false
var _settings: RefCounted
var _overlays: Array[CanvasLayer]=[]
var _overlay_viewport: SubViewport
var _overlay_image: TextureRect

func _init() -> void:
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_SCALE
	# The 3D scene also owns native GUI panels (flight conversations). Forward
	# pointer events into its viewport while allowing outer controls to receive
	# events when no embedded GUI consumes them.
	mouse_filter=Control.MOUSE_FILTER_PASS

func _ready() -> void:
	if owns_viewport:
		viewport=SubViewport.new();viewport.own_world_3d=true;viewport.handle_input_locally=false
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(viewport);texture=viewport.get_texture()
	resized.connect(refresh_size);get_window().size_changed.connect(refresh_size)
	refresh_size()
	_settings=Effects.for_view(self)
	if _settings!=null:_settings.bind(self)

func set_external_viewport(source: SubViewport) -> bool:
	# Menu and credits keep their scene lifetime; this view owns only display.
	if owns_viewport or not is_inside_tree() or source==null or not source.is_inside_tree() or not _overlays.is_empty() or (material!=null and _bloom==null):
		error="External scene display requires a ready view without a different display owner";return false
	if viewport==source:return true
	var enabled:=_bloom_requested
	set_bloom_enabled(false)
	viewport=source;texture=source.get_texture();refresh_size()
	return set_bloom_enabled(enabled)

func apply_bloom_preference(enabled: bool) -> void:
	_bloom_requested=enabled
	if viewport!=null:set_bloom_enabled(enabled)

func set_bloom_enabled(enabled: bool) -> bool:
	# Activation is an explicit presentation choice, not a campaign capability.
	# Existing views stay unfiltered until their settings owner opts in.
	if not enabled:
		if _bloom!=null:
			if material==_bloom.composite:material=null
			_bloom.free();_bloom=null
		_restore_overlays()
		_bloom_requested=false
		error="";return true
	if _bloom!=null:return true
	if viewport==null or material!=null:
		error="Bloom requires a ready scene view without a different display effect";return false
	for canvas in _overlays:
		if canvas.custom_viewport!=null and canvas.custom_viewport!=viewport:
			error="Bloom cannot redirect an overlay owned by a different viewport";return false
	var candidate:=Bloom.new();add_child(candidate)
	if not candidate.build(viewport.get_texture()):
		error=candidate.error;candidate.free();return false
	_bloom=candidate;material=candidate.composite;_bloom_requested=true
	if not _overlays.is_empty():
		_prepare_overlay_target()
		for canvas in _overlays:canvas.custom_viewport=_overlay_viewport
	_bloom.set_active(is_visible_in_tree());error="";return true

func register_overlay(canvas: CanvasLayer) -> bool:
	if canvas in _overlays:
		var expected: Viewport=_overlay_viewport if _bloom!=null else viewport
		if canvas.custom_viewport==expected or (_bloom==null and canvas.custom_viewport==null):error="";return true
		error="Registered overlay changed its render owner";return false
	if viewport==null or not canvas.is_inside_tree() or canvas.get_viewport()!=viewport or (canvas.custom_viewport!=null and canvas.custom_viewport!=viewport):
		error="Scene overlay requires this view's canvas without a foreign destination";return false
	_overlays.append(canvas)
	if _bloom!=null:
		_prepare_overlay_target();canvas.custom_viewport=_overlay_viewport
	error="";return true

func unregister_overlay(canvas: CanvasLayer) -> void:
	if canvas not in _overlays:return
	if is_instance_valid(_overlay_viewport) and canvas.custom_viewport==_overlay_viewport:canvas.custom_viewport=viewport
	_overlays.erase(canvas)
	# Canvas exit can run while this view's own children are being removed.
	# Retire sibling targets immediately, but let the tree delete them safely.
	if _overlays.is_empty():_release_overlay_target(true)

func _prepare_overlay_target() -> void:
	if _overlay_viewport!=null:return
	_overlay_viewport=SubViewport.new();_overlay_viewport.name="SceneInterface"
	_overlay_viewport.disable_3d=true;_overlay_viewport.transparent_bg=true
	_overlay_viewport.handle_input_locally=false
	add_child(_overlay_viewport)
	_overlay_image=TextureRect.new();_overlay_image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_overlay_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_overlay_image.stretch_mode=TextureRect.STRETCH_SCALE
	_overlay_image.texture=_overlay_viewport.get_texture()
	# Transparent viewport pixels already contain their coverage. Composite
	# them without multiplying that coverage into their colors a second time.
	var alpha_material:=CanvasItemMaterial.new()
	alpha_material.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_overlay_image.material=alpha_material
	add_child(_overlay_image);_overlay_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh_size();_sync_overlay_activity()

func _restore_overlays() -> void:
	for canvas in _overlays:
		if is_instance_valid(_overlay_viewport) and canvas.custom_viewport==_overlay_viewport:canvas.custom_viewport=viewport
	_release_overlay_target()

func _release_overlay_target(deferred:=false) -> void:
	if is_instance_valid(_overlay_image):
		_overlay_image.hide()
		if deferred:_overlay_image.queue_free()
		else:_overlay_image.free()
	if is_instance_valid(_overlay_viewport):
		_overlay_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		if deferred:_overlay_viewport.queue_free()
		else:_overlay_viewport.free()
	_overlay_image=null;_overlay_viewport=null

func _sync_overlay_activity() -> void:
	if _overlay_viewport!=null:
		_overlay_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and _bloom!=null:
		_bloom.set_active(is_visible_in_tree())
		_sync_overlay_activity()

func refresh_size() -> void:
	if viewport==null:return
	var pixels: Vector2=get_global_transform_with_canvas().get_scale().abs()*get_viewport().get_stretch_transform().get_scale().abs()
	viewport.size=Vector2i(maxi(2,roundi(size.x*pixels.x)),maxi(2,roundi(size.y*pixels.y)))
	# Projection and HUD coordinates stay in the same logical coordinate space.
	viewport.size_2d_override=Vector2i(maxi(2,roundi(size.x)),maxi(2,roundi(size.y)))
	viewport.size_2d_override_stretch=true
	if _overlay_viewport!=null:
		_overlay_viewport.size=viewport.size
		_overlay_viewport.size_2d_override=viewport.size_2d_override
		_overlay_viewport.size_2d_override_stretch=true

func _unhandled_input(event: InputEvent) -> void:
	# Embedded controls retain their scene lifetime and focus when a canvas is
	# drawn into the sharp interface target. Keyboard input does not cross a
	# SubViewport boundary automatically as pointer input does here.
	if viewport==null or not is_visible_in_tree() or size.x<=0 or size.y<=0:return
	# Controller actions stay with the application's existing input owner.
	if not event is InputEventKey:return
	# Root GUI has already had its chance; a focused outer control must not
	# also activate the last selected control in the scene behind it.
	if get_viewport().gui_get_focus_owner()!=null:return
	var target: Viewport=viewport
	if _overlay_viewport!=null and _overlay_viewport.gui_get_focus_owner()!=null:target=_overlay_viewport
	var focused:=target.gui_get_focus_owner()
	if focused==null or not focused.is_visible_in_tree():return
	target.push_input(event.duplicate(),true)
	if target.is_input_handled():get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if viewport==null or size.x<=0 or size.y<=0 or not event is InputEventMouse:return
	var forwarded: InputEventMouse=event.duplicate()
	# Control input is already in the authored 2D coordinate space. The child
	# viewport maps that space to its physical render target itself.
	forwarded.position=event.position
	forwarded.global_position=forwarded.position
	if _overlay_viewport!=null:
		_overlay_viewport.push_input(forwarded,true)
		if _overlay_viewport.is_input_handled():accept_event();return
	viewport.push_input(forwarded,true)
	if viewport.is_input_handled():accept_event()
