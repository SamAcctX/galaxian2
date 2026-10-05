extends RefCounted
## Presentation-scoped preferences shared by existing and newly created views.
signal changed(enabled: bool)
signal upscaling_changed(mode: String,scale: float)
signal antialiasing_changed(mode: String)
var bloom_enabled:=false
var upscaler:="off"
var render_scale:=1.0
var antialiasing:="off"

func apply(values: Dictionary) -> void:
	preload("res://src/presentation/graphics_quality.gd").level=float(values.get("graphics_quality",1.0))
	preload("res://src/presentation/flight_hud_style.gd").apply(values)
	var aa: String=values.get("antialiasing","off")
	if aa!=antialiasing:antialiasing=aa;antialiasing_changed.emit(aa)
	var mode: String=values.get("upscaler","off")
	var scale: float=float(values.get("render_scale",1.0))
	if not mode in supported_upscalers():mode="off"
	if mode!=upscaler or scale!=render_scale:
		upscaler=mode;render_scale=scale;upscaling_changed.emit(upscaler,render_scale)
	var enabled: bool=values.get("bloom",false)
	if enabled==bloom_enabled:return
	bloom_enabled=enabled;changed.emit(enabled)

func bind(view: Node) -> void:
	changed.connect(view.apply_bloom_preference)
	view.apply_bloom_preference(bloom_enabled)
	upscaling_changed.connect(view.apply_upscaling)
	view.apply_upscaling(upscaler,render_scale)
	antialiasing_changed.connect(view.apply_antialiasing)
	view.apply_antialiasing(antialiasing)

static func configure_antialiasing(viewport: Viewport,mode: String) -> void:
	if viewport==null:return
	viewport.msaa_3d={"msaa2":Viewport.MSAA_2X,"msaa4":Viewport.MSAA_4X,"msaa8":Viewport.MSAA_8X}.get(mode,Viewport.MSAA_DISABLED)
	viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA if mode=="fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED

## Godot's built-in 3D upscalers available to the running renderer: FSR 1.0
## outside Compatibility, FSR 2.2 on Forward+ only, MetalFX on Metal only.
static func supported_upscalers() -> Array:
	var method:=RenderingServer.get_current_rendering_method()
	var result:=["off"]
	if method=="gl_compatibility" or method.is_empty():return result
	result.append("fsr1")
	if method=="forward_plus":result.append("fsr2")
	if RenderingServer.get_current_rendering_driver_name()=="metal":result.append_array(["metalfx_spatial","metalfx_temporal"])
	return result

static func configure_viewport(viewport: Viewport,mode: String,scale: float) -> void:
	if viewport==null:return
	var modes:={"off":Viewport.SCALING_3D_MODE_BILINEAR,"fsr1":Viewport.SCALING_3D_MODE_FSR,"fsr2":Viewport.SCALING_3D_MODE_FSR2,
		"metalfx_spatial":Viewport.SCALING_3D_MODE_METALFX_SPATIAL,"metalfx_temporal":Viewport.SCALING_3D_MODE_METALFX_TEMPORAL}
	viewport.scaling_3d_mode=modes.get(mode,Viewport.SCALING_3D_MODE_BILINEAR)
	viewport.scaling_3d_scale=1.0 if mode=="off" else clampf(scale,0.25,1.0)

static func for_view(view: Node) -> RefCounted:
	var ancestor:=view.get_parent()
	while ancestor!=null:
		if ancestor.has_method("scene_effect_settings"):return ancestor.scene_effect_settings()
		ancestor=ancestor.get_parent()
	return null
