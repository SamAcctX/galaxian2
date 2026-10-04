extends Control
## In-flight pause window (original MenuTouchWindow pause entries) over the
## frozen flight. The career is shown read-only; the frontend owns the actions.
signal action_requested(action: String)
signal view_changed(view: String)
const MissionsPanel=preload("res://src/presentation/missions_panel.gd")
## Original string ids (Mac table): Pause, Resume, Options, Missions, Cargo
## hold, Back to Main Menu, its confirmation, OK, Back, Action Freeze.
const TEXT:={"title":40,"resume":41,"options":31,"missions":128,"cargo":165,"main_menu":511,"confirm":512,"ok":513,"back":169,"freeze":58,"skip":384}
## Original order; Resume is the remake's keyboard/controller-friendly first row.
const ENTRIES:=["resume","options","missions","cargo","main_menu","freeze","skip"]
## Missions appears after the training flights, Cargo hold after the opening.
const MISSIONS_CURSOR:=16
const CARGO_CURSOR:=2
## Action Freeze orbit distance limits (original free camera).
const ZOOM_MIN:=1500.0
const ZOOM_MAX:=20000.0
var error:=""
var view:="":
	set(value):
		view=value;view_changed.emit(value)
var _library: RefCounted
var _item_text_offset:=-1
var _ui: RefCounted
var _mobile:=false
var _state:={}
var _backdrop: ColorRect
var _window: PanelContainer
var _title: Label
var _list: VBoxContainer
var _buttons:={}
var _missions: Control
var _missions_ready:=false
var _freeze_back: Button
var _camera: Camera3D
var _saved_camera:=Transform3D()
var _pivot:=Vector3.ZERO
var _yaw:=0.0
var _pitch:=0.0
var distance:=3000.0

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP
	_backdrop=ColorRect.new();_backdrop.color=Color(0.0,0.0,0.0,0.45);_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop);_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window=PanelContainer.new();add_child(_window)
	var margins:=MarginContainer.new();_window.add_child(margins)
	for side in ["left","right","top","bottom"]:margins.add_theme_constant_override("margin_"+side,14)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);margins.add_child(column)
	_title=Label.new();_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(_title)
	_list=VBoxContainer.new();_list.add_theme_constant_override("separation",6);column.add_child(_list)
	_missions=MissionsPanel.new();_missions.read_only=true;add_child(_missions);_missions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_missions.close_requested.connect(show_menu)
	_freeze_back=Button.new();_freeze_back.pressed.connect(end_freeze);_freeze_back.hide();add_child(_freeze_back)
	resized.connect(_layout)

## `status` is a configured Status panel: its font, button art and catalogues.
func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,status: Control,mobile: bool) -> bool:
	error=""
	if library==null or status==null or status._ui==null:return reject("Pause needs the configured Status interface")
	_library=library;_item_text_offset=int(bindings.station_equipment.get("item_text_offset",-1));_ui=status._ui;_mobile=mobile
	_missions_ready=_missions.configure(status,library,bindings,visuals)
	theme=Theme.new();theme.default_font=_ui.font
	_window.add_theme_stylebox_override("panel",_ui.styles[mobile].panel)
	_title.add_theme_font_size_override("font_size",22 if mobile else 16)
	_title.add_theme_color_override("font_color",Color(0.9,0.96,1.0))
	_freeze_back.text=text("back");_ui.apply_button(_freeze_back,mobile,true)
	return true

func text(key: String) -> String:
	var id: int=TEXT[key]
	return _library.strings[id] if id<_library.strings.size() else ""

## state: career observation (campaign_cursor, mission, contracts, loadout,
## station_id) plus the current `cargo` hold.
func present(state: Dictionary) -> void:
	_state=state;visible=true;show_menu()

func entries() -> Array:
	var cursor:=int(_state.get("campaign_cursor",0))
	var shown:=[]
	for key in ENTRIES:
		if key=="missions" and (cursor<MISSIONS_CURSOR or not _missions_ready or not _state.get("contracts") is Dictionary):continue
		if key=="cargo" and cursor<CARGO_CURSOR:continue
		# The Supernova Challenge (mission type 0xb7) hides Missions and Cargo
		# hold; the alien world hides Missions.
		var challenge: bool=_state.get("mission") is Dictionary and _state.mission.get("supernova_challenge",false)==true
		if key in ["missions","cargo"] and challenge:continue
		if key=="missions" and _state.get("alien_orbit",false):continue
		if key=="skip" and not _state.get("skip_available",false):continue
		shown.append(key)
	return shown

func show_menu() -> void:
	view="menu";_missions.clear();_title.text=text("title")
	var keys:=entries();var rows:=[]
	for key in keys:rows.append([text(key),_request.bind(key),key=="resume"])
	_fill(rows)

func _request(key: String) -> void:
	match key:
		"missions":show_missions()
		"cargo":show_cargo()
		"main_menu":show_confirm()
		"freeze":action_requested.emit("freeze")
		_:action_requested.emit(key)

func show_missions() -> bool:
	if not _missions_ready or not _missions.present(_state):return false
	view="missions";_window.hide();_missions.show()
	var back: Button=_missions._back
	_focus.call_deferred(back)
	return true

func show_cargo() -> void:
	view="cargo";_title.text=text("cargo")
	_fill([])
	for row in cargo_rows():_list.add_child(_row(row.name,str(row.quantity)))
	var hold: Dictionary=_state.get("cargo",{})
	_list.add_child(_row("","%d/%d"%[int(hold.get("used",0)),int(hold.get("capacity",0))]))
	_add_button(text("back"),show_menu,true).grab_focus()

## Hold rows in stored order: item name and quantity.
func cargo_rows() -> Array:
	var rows:=[]
	for entry in _state.get("cargo",{}).get("entries",[]):
		var id:=int(entry.get("item_id",-1))
		rows.append({"item_id":id,"name":item_name(id),"quantity":int(entry.get("quantity",0))})
	return rows

## Localized item names follow the station equipment text offset.
func item_name(id: int) -> String:
	var text_id:=_item_text_offset+id
	return _library.strings[text_id] if _item_text_offset>=0 and id>=0 and text_id<_library.strings.size() else ""

func show_confirm() -> void:
	view="confirm";_title.text=text("main_menu")
	_fill([])
	var label:=Label.new();label.text=text("confirm");label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=220
	label.add_theme_font_size_override("font_size",18 if _mobile else 13);_list.add_child(label)
	_add_button(text("ok"),func():action_requested.emit("main_menu"))
	_add_button(text("back"),show_menu,true).grab_focus()

func _focus(button: Control) -> void:
	if is_instance_valid(button) and button.is_visible_in_tree():button.grab_focus()

func _fill(rows: Array) -> void:
	_window.show();_freeze_back.hide();_backdrop.show()
	for child in _list.get_children():_list.remove_child(child);child.queue_free()
	_buttons={}
	var first: Button
	for row in rows:
		var button:=_add_button(row[0],row[1])
		if first==null:first=button
	if first!=null:_focus.call_deferred(first)
	_layout.call_deferred()

func _add_button(caption: String,callback: Callable,back:=false) -> Button:
	var button:=Button.new();button.text=caption;button.pressed.connect(callback)
	if _ui!=null:_ui.apply_button(button,_mobile,back)
	_list.add_child(button);_buttons[caption]=button
	return button

func _row(caption: String,value: String) -> HBoxContainer:
	var row:=HBoxContainer.new()
	var name_label:=Label.new();name_label.text=caption;name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var value_label:=Label.new();value_label.text=value;value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for label in [name_label,value_label]:
		label.add_theme_font_size_override("font_size",18 if _mobile else 13);row.add_child(label)
	return row

## Texts of the visible buttons, in order (tests and accessibility).
func button_texts() -> Array:
	return _list.get_children().filter(func(node):return node is Button).map(func(node):return node.text)

func press(caption: String) -> bool:
	if not _buttons.has(caption):return false
	_buttons[caption].pressed.emit();return true

## Escape / controller B: step back inside the window. False means resume.
func back() -> bool:
	match view:
		"missions":
			_missions.handle_event(_cancel_event());return true
		"cargo","confirm":show_menu();return true
		"freeze":end_freeze();return true
	return false

static func _cancel_event() -> InputEvent:
	var event:=InputEventAction.new();event.action="ui_cancel";event.pressed=true;return event

# --- Action Freeze: frozen world, hidden HUD, orbit camera around the ship.

func begin_freeze(camera: Camera3D,pivot: Vector3) -> bool:
	if camera==null:return false
	_camera=camera;_saved_camera=camera.global_transform;_pivot=pivot
	var offset:=camera.global_position-pivot
	if offset.length()<1.0:offset=Vector3(0,0.3,1)
	distance=clampf(offset.length(),ZOOM_MIN,ZOOM_MAX)
	_yaw=atan2(offset.x,offset.z);_pitch=asin(clampf(offset.normalized().y,-1.0,1.0))
	view="freeze";_window.hide();_backdrop.hide();_freeze_back.show();_layout()
	_focus.call_deferred(_freeze_back)
	_apply_orbit();return true

func end_freeze() -> void:
	if view!="freeze":return
	if is_instance_valid(_camera):_camera.global_transform=_saved_camera
	_camera=null;action_requested.emit("unfreeze");show_menu()

func orbit(yaw_delta: float,pitch_delta: float,zoom_factor:=1.0) -> void:
	if view!="freeze":return
	_yaw+=yaw_delta;_pitch=clampf(_pitch+pitch_delta,-1.45,1.45)
	distance=clampf(distance*zoom_factor,ZOOM_MIN,ZOOM_MAX)
	_apply_orbit()

func _apply_orbit() -> void:
	if not is_instance_valid(_camera):return
	var direction:=Vector3(cos(_pitch)*sin(_yaw),sin(_pitch),cos(_pitch)*cos(_yaw))
	_camera.global_position=_pivot+direction*distance
	_camera.look_at(_pivot,Vector3.UP)

func _gui_input(event: InputEvent) -> void:
	if view!="freeze":return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		orbit(-event.relative.x*0.006,event.relative.y*0.006);accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		orbit(0.0,0.0,0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/0.9);accept_event()
	elif event is InputEventScreenDrag:
		orbit(-event.relative.x*0.006,event.relative.y*0.006);accept_event()
	elif event is InputEventMagnifyGesture:
		orbit(0.0,0.0,1.0/maxf(event.factor,0.01));accept_event()

func _process(delta: float) -> void:
	if view!="freeze" or not is_visible_in_tree():return
	var turn:=Vector2.ZERO;var zoom:=0.0
	for device in Input.get_connected_joypads():
		var stick:=Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
		var right:=Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
		if right.length()>stick.length():stick=right
		if stick.length()>0.2:turn+=stick
		zoom+=Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT)-Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT)
	turn.x+=Input.get_axis("ui_left","ui_right");turn.y+=Input.get_axis("ui_up","ui_down")
	if turn!=Vector2.ZERO or absf(zoom)>0.1:
		orbit(-turn.x*1.8*delta,turn.y*1.8*delta,pow(2.0,-zoom*delta) if absf(zoom)>0.1 else 1.0)

func set_mobile_layout(value: bool) -> void:
	_mobile=value
	if _ui!=null:
		_window.add_theme_stylebox_override("panel",_ui.styles[value].panel)
		for button in _list.get_children():
			if button is Button:_ui.apply_button(button,value)
		_ui.apply_button(_freeze_back,value,true)
	_layout()

func _layout() -> void:
	if size.x<=0 or size.y<=0:return
	_window.reset_size()
	var width:=maxf(_window.get_combined_minimum_size().x,minf(320.0 if _mobile else 240.0,size.x-32))
	_window.size=Vector2(width,_window.get_combined_minimum_size().y)
	_window.position=((size-_window.size)*0.5).round()
	_freeze_back.size=Vector2(100 if _mobile else 80,44 if _mobile else 30)
	_freeze_back.position=size-_freeze_back.size-Vector2(12,12)

func window_rect() -> Rect2:return Rect2(_window.position,_window.size)

func snapshot() -> Dictionary:
	return {"view":view,"title":_title.text,"buttons":button_texts(),"missions":_missions.snapshot() if view=="missions" else {},"distance":distance}

func clear() -> void:
	if view=="freeze" and is_instance_valid(_camera):_camera.global_transform=_saved_camera
	_camera=null;view="";_missions.clear();visible=false

func reject(message: String) -> bool:error=message;return false
