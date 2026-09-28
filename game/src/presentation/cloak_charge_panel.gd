extends Control
## Original center-out charge artwork; elapsed time belongs to the player.
const OriginalUI=preload("res://src/presentation/original_ui.gd")
var error:=""
var _sprites:={}
var _label: Label
var _sample:={}
var _mobile:=false

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;hide()
	_label=Label.new();_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(_label)
	resized.connect(_layout)

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> bool:
	var art:=OriginalUI.new()
	if not art.configure(library,bindings,visuals):error=art.error;return false
	var sprites:=art.load_regions(library,bindings,visuals,[1337,1338],bindings.mido_travel.map.ui.atlas_resources)
	if sprites.is_empty():error=art.error;return false
	_sprites=sprites;_label.text=library.strings[306];_label.add_theme_font_override("font",art.font)
	return true

func present(state: Dictionary,enabled: bool,mobile: bool) -> void:
	_sample=state;_mobile=mobile
	visible=enabled and state.get("phase")=="charging" and not _sprites.is_empty()
	modulate.a=clampf(float(state.get("elapsed_ms",0))/1000.0,0.0,1.0)
	_layout()

func _layout() -> void:
	if _sprites.is_empty():return
	var scale_factor:=1.0 if _mobile else 0.5
	var extent: Vector2=_sprites[1338].get_size()*scale_factor
	var top:=160.0 if _mobile else 80.0
	_label.position=Vector2(0,top+extent.y*2.5)
	_label.size=Vector2(size.x,32 if _mobile else 20)
	_label.add_theme_font_size_override("font_size",20 if _mobile else 14)
	queue_redraw()

func _draw() -> void:
	if _sprites.is_empty():return
	var scale_factor:=1.0 if _mobile else 0.5
	var extent: Vector2=_sprites[1338].get_size()*scale_factor
	var center:=Vector2(size.x*0.5,160 if _mobile else 80)
	draw_texture_rect(_sprites[1338],Rect2(center-Vector2(extent.x*0.5,0),extent),false)
	var texture: Texture2D=_sprites[1337]
	var source:=texture.get_size()
	var width:=source.x*clampf(float(_sample.get("progress",0.0))*1.05,0.0,1.0)
	if width>0:
		var target:=Rect2(center-Vector2(width*scale_factor*0.5,0),Vector2(width,source.y)*scale_factor)
		draw_texture_rect_region(texture,target,Rect2(Vector2((source.x-width)*0.5,0),Vector2(width,source.y)))
