extends Control
## Docked "New medal!" window: the medal's ribbon, name and description.
## The station career owns the reward and the queue; this view only shows one.
signal acknowledged
const Medals=preload("res://src/simulation/base_medal_progress.gd")
const NOTICE_TEXT:=342
const OK_TEXT:=130
var _status: Control
var _box: PanelContainer
var _title: Label
var _ribbon: TextureRect
var _icon: TextureRect
var _name: Label
var _text: Label
var _ok: Button
var _shown:=[]

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP
	var dim:=ColorRect.new();dim.color=Color(0,0,0,0.45);dim.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box=PanelContainer.new();add_child(_box)
	var column:=VBoxContainer.new();column.alignment=BoxContainer.ALIGNMENT_CENTER;column.add_theme_constant_override("separation",6);_box.add_child(column)
	_title=Label.new();_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(_title)
	_ribbon=TextureRect.new();_ribbon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_ribbon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_ribbon.custom_minimum_size=Vector2(160,59);column.add_child(_ribbon)
	_icon=TextureRect.new();_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_ribbon.add_child(_icon)
	_icon.set_anchors_preset(Control.PRESET_CENTER);_icon.offset_left=-19;_icon.offset_right=19;_icon.offset_top=-21;_icon.offset_bottom=17
	_name=Label.new();_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(_name)
	_text=Label.new();_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_text.custom_minimum_size.x=360;column.add_child(_text)
	_ok=Button.new();_ok.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;_ok.custom_minimum_size.x=120;_ok.pressed.connect(func():acknowledged.emit());column.add_child(_ok)
	resized.connect(_relayout)

## `status` is the configured Status panel; its imported art and text are shared.
func present(status: Control,notice: Array) -> bool:
	if status==null or status._identity.is_empty() or notice.size()!=2:return false
	_status=status;theme=status.theme
	var id: int=notice[0];var level: int=notice[1]
	_title.text=status._strings[NOTICE_TEXT];_ok.text=status._strings[OK_TEXT]
	_ribbon.texture=status._art[status.RIBBONS[level]]
	_icon.texture=status._art[status.MEDAL_ICON_BASE+id];_icon.modulate=status.TINTS[level]
	_name.text=status._strings[status.MEDAL_NAME_BASE+id]
	_text.text=status._strings[status.MEDAL_TEXT_BASE+id].replace("#",str(Medals.description_value(id,level)))
	if status._ui!=null:
		_box.add_theme_stylebox_override("panel",status._ui.styles[status._mobile].panel)
		status._ui.apply_button(_ok,status._mobile)
	_shown=notice.duplicate();visible=true;_relayout();_ok.grab_focus()
	return true

func shown() -> Array:return _shown if visible else []

func handle_event(event: InputEvent) -> bool:
	if not visible:return false
	var accept: bool=event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B])
	if accept:acknowledged.emit()
	return true

func _relayout() -> void:
	if size.x<=0:return
	_box.reset_size()
	_box.position=(size-_box.size)*0.5

func clear() -> void:
	visible=false;_shown=[]
