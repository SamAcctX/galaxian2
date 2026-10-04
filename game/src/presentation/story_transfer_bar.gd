extends Control
## Story dock Loading/Unloading bar: the dock icon fades in over a second,
## the fill grows from the left edge, and the label sits below with the
## cargo icon beside it (original Hud artwork 1338/1337/8001/8000).
const OriginalUI=preload("res://src/presentation/original_ui.gd")
const Atlas=preload("res://src/content/atlas_region.gd")
var error:=""
var _sprites:={}
var _label: Label
var _sample:={}
var _mobile:=false
var _labels:={}

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
	var reader:=Atlas.new()
	for id in [8000,8001]:
		var alias: Dictionary=bindings.resolve_image_region(id)
		if alias.is_empty():continue
		for record in bindings.records.get(int(alias.texture_id),[]):
			if record.kind!="texture":continue
			var texture: AtlasTexture=reader.load(library,visuals,record.resource,int(alias.region))
			if texture!=null:sprites[id]=texture;break
	if not sprites.has(8001):error="Transfer bar artwork is missing";return false
	for id in [3193,3194]:
		if id>=library.strings.size() or library.strings[id].is_empty():error="Transfer bar text is missing in this language";return false
	_labels={true:library.strings[3193]+" ",false:library.strings[3194]+" "}
	_sprites=sprites;_label.add_theme_font_override("font",art.font)
	return true

func present(state: Dictionary,enabled: bool,mobile: bool) -> void:
	_sample=state;_mobile=mobile
	visible=enabled and not state.is_empty() and not _sprites.is_empty()
	if not visible:return
	_label.text=_labels.get(bool(state.get("loading",true)),"")
	modulate.a=clampf(float(state.get("elapsed_ms",0))/1000.0,0.0,1.0)
	_layout()

func _scale() -> float:return 1.0 if _mobile else 0.5
func _top() -> float:return 160.0 if _mobile else 80.0

func _layout() -> void:
	if _sprites.is_empty():return
	var frame: Vector2=_sprites[1337].get_size()*_scale()
	_label.position=Vector2(0,_top()+frame.y*2.5)
	_label.size=Vector2(size.x,32 if _mobile else 20)
	_label.add_theme_font_size_override("font_size",20 if _mobile else 14)
	queue_redraw()

func _draw() -> void:
	if _sprites.is_empty():return
	var center:=Vector2(size.x*0.5,_top())
	var icon: Vector2=_sprites[1338].get_size()*_scale()
	draw_texture_rect(_sprites[1338],Rect2(center-Vector2(icon.x*0.5,0),icon),false)
	var frame: Vector2=_sprites[1337].get_size()*_scale()
	var fill: Texture2D=_sprites[8001]
	var source:=fill.get_size()
	var fraction:=clampf(float(_sample.get("progress",0.0)),0.0,1.0)
	if fraction>0:
		var target:=Rect2(center-Vector2(frame.x*0.5,0),Vector2(frame.x*fraction,frame.y))
		draw_texture_rect_region(fill,target,Rect2(Vector2.ZERO,Vector2(source.x*fraction,source.y)))
	if _sprites.has(8000):
		var cargo: Vector2=_sprites[8000].get_size()*_scale()
		var font: Font=_label.get_theme_font("font")
		var text_width:=font.get_string_size(_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,_label.get_theme_font_size("font_size")).x
		var left:=Vector2(size.x*0.5-text_width*0.5-cargo.x-4,_label.position.y+(_label.size.y-cargo.y)*0.5)
		draw_texture_rect(_sprites[8000],Rect2(left,cargo),false)
