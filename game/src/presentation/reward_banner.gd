extends Control
## Reward banner (verified Layout::showMissionRewardMessage): when a freelance
## job pays or a Most Wanted bounty is collected, the emblem (image 1325) with
## "Mission accomplished!" (205) or "Bounty collected" (3195) and "+ N$" fades
## in over 2 s at the top centre, holds until 5 s and is gone at 7 s.
const OriginalUI=preload("res://src/presentation/original_ui.gd")
const UISounds=preload("res://src/presentation/ui_sounds.gd")
const IMAGE_ID:=1325
const TITLES:={false:205,true:3195}
const FADE_MS:=2000
const HOLD_END_MS:=5000
const END_MS:=7000
var error:=""
var _emblem: Texture2D
var _titles:={}
var _title: Label
var _amount: Label
var _started_ms:=-1
var _mobile:=false
var _shown:={}

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;hide()
	for index in 2:
		var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(label)
		if index==0:_title=label
		else:_amount=label
	resized.connect(_layout)

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> bool:
	var art:=OriginalUI.new()
	if not art.configure(library,bindings,visuals):error=art.error;return false
	var sprites:=art.load_regions(library,bindings,visuals,[IMAGE_ID],bindings.mido_travel.map.ui.atlas_resources)
	if sprites.is_empty():error=art.error;return false
	for bounty in TITLES:
		var id: int=TITLES[bounty]
		if id>=library.strings.size() or library.strings[id].is_empty():error="Reward banner text is missing in this language";return false
		_titles[bounty]=library.strings[id]
	_emblem=sprites[IMAGE_ID]
	for label in [_title,_amount]:label.add_theme_font_override("font",art.font)
	return true

## Starts the banner; a zero reward shows nothing (as in the original). A
## freelance result already plays the payment sound when it is closed.
func show_reward(credits: int,bounty:=false) -> bool:
	if credits==0 or _emblem==null:return false
	_title.text=_titles[bounty];_amount.text="+ "+str(credits)+"$"
	_shown={"credits":credits,"bounty":bounty}
	_started_ms=Time.get_ticks_msec();modulate.a=0.0;show();_layout()
	if bounty:UISounds.event(self,UISounds.REWARD)
	return true

func snapshot() -> Dictionary:return _shown.merged({"visible":visible,"alpha":modulate.a}) if visible else {}

func set_mobile_layout(value: bool) -> void:_mobile=value;_layout()

func _process(_delta: float) -> void:
	if not visible:return
	var elapsed:=Time.get_ticks_msec()-_started_ms
	if elapsed>=END_MS:hide();_shown={};return
	modulate.a=clampf(float(elapsed)/FADE_MS,0.0,1.0) if elapsed<HOLD_END_MS else clampf(float(END_MS-elapsed)/FADE_MS,0.0,1.0)

func _scale() -> float:return 1.0 if _mobile else 0.5
func _top() -> float:return 100.0 if _mobile else 50.0

func _layout() -> void:
	if _emblem==null:return
	var emblem: Vector2=_emblem.get_size()*_scale()
	var line:=32.0 if _mobile else 20.0
	for index in 2:
		var label: Label=[_title,_amount][index]
		label.position=Vector2(0,_top()+emblem.y+4.0+line*index);label.size=Vector2(size.x,line)
		label.add_theme_font_size_override("font_size",20 if _mobile else 14)
	queue_redraw()

func _draw() -> void:
	if _emblem==null:return
	var emblem: Vector2=_emblem.get_size()*_scale()
	draw_texture_rect(_emblem,Rect2(Vector2(size.x*0.5-emblem.x*0.5,_top()),emblem),false)
