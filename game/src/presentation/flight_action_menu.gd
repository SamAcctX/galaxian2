extends Control
## Paused flight choices. The host supplies available actions and owns execution.
signal chosen(action: String)
signal cancelled
const OriginalUI=preload("res://src/presentation/original_ui.gd")
var error:=""
var _art: RefCounted
var _panel: PanelContainer
var _column: VBoxContainer
var _rows_box: VBoxContainer
var _scroll: ScrollContainer
var _cancel: Button
var _rows: Array=[]
var _buttons: Array[Button]=[]
var _active:=false
var _mobile:=false
var _close_key:=KEY_Q
var _selection:=0

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP
	var dim:=ColorRect.new();dim.color=Color(0,0,0,0.32);dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel=PanelContainer.new();add_child(_panel)
	_column=VBoxContainer.new();_column.add_theme_constant_override("separation",6);_panel.add_child(_column)
	_scroll=ScrollContainer.new();_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_column.add_child(_scroll)
	_rows_box=VBoxContainer.new();_rows_box.add_theme_constant_override("separation",6);_rows_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_scroll.add_child(_rows_box)
	_cancel=Button.new();_cancel.focus_mode=Control.FOCUS_NONE;_cancel.pressed.connect(func():if _active:cancelled.emit());_column.add_child(_cancel)
	resized.connect(_layout)

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> bool:
	var art:=OriginalUI.new()
	if not art.configure(library,bindings,visuals):error=art.error;return false
	_art=art;_cancel.text=library.strings[414]
	var prepared:=Theme.new();prepared.default_font=art.font;theme=prepared
	return true

func present(rows: Array,close_key: int=KEY_Q) -> bool:
	if _art==null or rows.is_empty():error="No flight destinations are available";return false
	for button in _buttons:button.free()
	_buttons.clear();_rows=rows.duplicate(true);_close_key=close_key;_selection=0
	for index in rows.size():
		var row: Dictionary=rows[index]
		var button:=Button.new();button.text="%d.  %s"%[index+1,row.label]
		button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(func():_choose(index))
		_rows_box.add_child(button);_buttons.append(button);_art.apply_button(button,_mobile)
	visible=true;set_active(true);_layout();return true

func set_active(value: bool) -> void:
	_active=value
	for button in _buttons:button.disabled=not value
	_cancel.disabled=not value

func close() -> void:visible=false;set_active(false)
func set_mobile_layout(value: bool) -> void:_mobile=value;_layout()
func snapshot() -> Dictionary:return {"open":visible,"active":_active,"rows":_rows.duplicate(true),"selection":_selection}

func handle_event(event: InputEvent) -> bool:
	if not visible:return false
	if not _active:return true
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if key in [KEY_ESCAPE,_close_key]:cancelled.emit()
		elif key>=KEY_1 and key<=KEY_9:_choose(key-KEY_1)
		elif key==KEY_UP:_selection=posmod(_selection-1,_rows.size())
		elif key==KEY_DOWN:_selection=posmod(_selection+1,_rows.size())
		elif key in [KEY_ENTER,KEY_KP_ENTER]:_choose(_selection)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_Y]:cancelled.emit()
		elif event.button_index==JOY_BUTTON_A:_choose(_selection)
		elif event.button_index==JOY_BUTTON_DPAD_UP:_selection=posmod(_selection-1,_rows.size())
		elif event.button_index==JOY_BUTTON_DPAD_DOWN:_selection=posmod(_selection+1,_rows.size())
	for index in _buttons.size():_buttons[index].modulate=Color.WHITE if index==_selection else Color(0.8,0.86,0.9)
	if not _buttons.is_empty():_scroll.ensure_control_visible(_buttons[_selection])
	return true

func _choose(index: int) -> void:
	if _active and index>=0 and index<_rows.size():chosen.emit(_rows[index].action)

func _layout() -> void:
	if _panel==null:return
	var width:=320.0 if _mobile else 238.0
	if _art!=null:
		_panel.add_theme_stylebox_override("panel",_art.styles[_mobile].panel)
		for button in _buttons+[_cancel]:_art.apply_button(button,_mobile)
	var fixed_height:=_panel.get_theme_stylebox("panel").get_minimum_size().y+_cancel.get_combined_minimum_size().y+6.0
	_scroll.custom_minimum_size.y=minf(_rows_box.get_combined_minimum_size().y,maxf(1.0,size.y-48.0-fixed_height))
	_panel.size=Vector2(minf(width,maxf(0,size.x-32)),0)
	_panel.position=Vector2(20,maxf(16,size.y-_panel.get_combined_minimum_size().y-36))
