extends Control
## Docked Missions log: the story objective beside the accepted freelance job.
## The station career owns both missions; this view only shows them and asks
## the host to open the map or discard the freelance job.
signal close_requested
signal map_requested
signal discard_requested
const Lounge=preload("res://src/presentation/lounge_panel.gd")
const Portraits=preload("res://src/presentation/portrait_compositor.gd")
const Medals=preload("res://src/simulation/base_medal_progress.gd")
const TEXT:={"title":128,"story":544,"freelance":545,"no_job":173,"map":413,"discard":412,"confirm":853,"yes":133,"no":134,"back":169,"won":659,"won_gold":639}
## Story text per campaign cursor; cursors without their own line use 738.
const STORY_TEXT:={10:641,11:642,12:643,13:644,14:645,16:646,18:647,20:648,21:648,23:649,24:650,28:651,32:652,33:653,34:654,35:655,36:656,38:657,40:658,44:659,45:659,46:660,48:661,49:661}
const STORY_DEFAULT:=738
## The epilogue hands the career on at cursor 45 with no further story target.
const WON_CURSOR:=45
const GOLD_EXCEPTION_SHIP:=8
var error:=""
var _status: Control
var _library: RefCounted
var _catalogues: RefCounted
var _bindings: RefCounted
var _visuals: RefCounted
var _client:={}
var _client_portrait: Texture2D
var _state:={}
var _confirming:=false
var _header: Label
var _story_bar: Label
var _story_text: Label
var _story_map: Button
var _job_bar: Label
var _job_portrait: TextureRect
var _job_name: Label
var _job_text: Label
var _job_map: Button
var _job_discard: Button
var _yes: Button
var _no: Button
var _back: Button

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop:=ColorRect.new();backdrop.color=Color(0.0,0.02,0.05,0.96);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root:=MarginContainer.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:root.add_theme_constant_override("margin_"+side,16)
	var column:=VBoxContainer.new();root.add_child(column)
	_header=_bar(column)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",16);column.add_child(body)
	var story:=VBoxContainer.new();story.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(story)
	_story_bar=_bar(story)
	_story_text=_body(story)
	_story_map=Button.new();_story_map.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;_story_map.pressed.connect(func():map_requested.emit());story.add_child(_story_map)
	var job:=VBoxContainer.new();job.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(job)
	_job_bar=_bar(job)
	var client:=HBoxContainer.new();client.add_theme_constant_override("separation",8);job.add_child(client)
	_job_portrait=TextureRect.new();_job_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_job_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT;_job_portrait.custom_minimum_size=Vector2(72,84);client.add_child(_job_portrait)
	_job_name=Label.new();_job_name.size_flags_vertical=Control.SIZE_SHRINK_END;client.add_child(_job_name)
	_job_text=_body(job)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",8);job.add_child(actions)
	_job_map=Button.new();_job_map.pressed.connect(func():map_requested.emit());actions.add_child(_job_map)
	_job_discard=Button.new();_job_discard.add_theme_color_override("font_color",Color8(255,42,0));_job_discard.pressed.connect(ask_discard);actions.add_child(_job_discard)
	_yes=Button.new();_yes.pressed.connect(confirm_discard);actions.add_child(_yes)
	_no=Button.new();_no.pressed.connect(cancel_discard);actions.add_child(_no)
	var footer:=HBoxContainer.new();column.add_child(footer)
	_back=Button.new();_back.pressed.connect(func():close_requested.emit());footer.add_child(_back)

func _bar(parent: Control) -> Label:
	var label:=Label.new();label.add_theme_color_override("font_color",Color(0.85,0.93,1.0))
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.07,0.2,0.36,0.9);style.content_margin_left=6;style.content_margin_top=1;style.content_margin_bottom=1
	label.add_theme_stylebox_override("normal",style);parent.add_child(label)
	return label

func _body(parent: Control) -> Label:
	var label:=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_vertical=Control.SIZE_EXPAND_FILL;label.custom_minimum_size.x=200;parent.add_child(label)
	return label

func text(key: String) -> String:
	var id: int=TEXT[key]
	return _library.strings[id] if id<_library.strings.size() else ""

## `status` is the configured Status panel; its font and button art are shared.
func configure(status: Control,library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> bool:
	error=""
	if status==null or status._identity.is_empty() or library==null or bindings==null:return reject("Missions needs the configured Status interface")
	_status=status;_library=library;_bindings=bindings;_visuals=visuals;_catalogues=status._catalogues;theme=status.theme
	_header.text=text("title");_story_bar.text=text("story");_job_bar.text=text("freelance")
	_story_map.text=text("map");_job_map.text=text("map");_job_discard.text=text("discard")
	_yes.text=text("yes");_no.text=text("no");_back.text=text("back")
	if status._ui!=null:
		for button in [_story_map,_job_map,_job_discard,_yes,_no,_back]:status._ui.apply_button(button,status._mobile)
	return true

func story_text(state: Dictionary) -> String:
	var career: Dictionary=state.get("contracts",{})
	var cursor: int=int(state.get("campaign_cursor",career.get("campaign_cursor",0)))
	if cursor>=WON_CURSOR:
		var levels: Array=career.get("base_medals",{}).get("levels",[])
		var all_gold: bool=levels.size()>=Medals.BASE_COUNT and levels.slice(0,Medals.BASE_COUNT).all(func(level):return int(level)==1)
		return text("won_gold") if all_gold and int(state.get("loadout",{}).get("ship_id",-1))!=GOLD_EXCEPTION_SHIP else text("won")
	var id: int=STORY_TEXT.get(cursor,STORY_DEFAULT)
	var line: String=_library.strings[id] if id<_library.strings.size() else ""
	var mission: Dictionary=state.get("mission",{})
	if line.contains("#Q"):return line.replace("#Q",str(int(mission.get("quantity",0))))
	var station: int=int(mission.get("station_id",-1))
	return line.replace("#",_catalogues.tables.stations[station].name if station>=0 and station<_catalogues.tables.stations.size() else "")

func job_text(mission: Dictionary) -> String:
	if mission.is_empty():return text("no_job")
	var id: int=int(mission.get("briefing_text_id",-1))
	var template: String=_library.strings[id] if id>=0 and id<_library.strings.size() else ""
	return Lounge.format_job_text(_library,_catalogues,_bindings,template,mission)

## state: the station snapshot (story in `mission`, freelance job in `contracts`).
func present(state: Dictionary) -> bool:
	error=""
	if _library==null:return reject("Configure Missions before presenting it")
	var career: Variant=state.get("contracts")
	if not career is Dictionary:return reject("Missions needs the docked career")
	_state=state
	var job: Dictionary=career.get("mission",{})
	var contact: Dictionary=career.get("accepted_contact",{})
	var client: Dictionary=contact.get("portrait",{})
	if client!=_client:
		_client_portrait=null
		if not client.is_empty():
			var composite: Dictionary=Portraits.new().compose_definition(_library,_bindings,_visuals,0,"large",client)
			if not composite.is_empty():_client_portrait=ImageTexture.create_from_image(composite.image)
		_client=client.duplicate(true)
	var won: bool=int(state.get("campaign_cursor",0))>=WON_CURSOR
	_story_text.text=story_text(state)
	_story_map.visible=not won
	_job_portrait.texture=null if job.is_empty() else _client_portrait
	_job_portrait.visible=_job_portrait.texture!=null
	_job_name.text="" if job.is_empty() else str(contact.get("name",""))
	_job_text.text=job_text(job)
	if _confirming and not job.is_empty():_job_text.text=text("confirm")
	else:_confirming=false
	_job_map.visible=not job.is_empty() and not _confirming
	_job_discard.visible=not job.is_empty() and not _confirming
	_yes.visible=_confirming;_no.visible=_confirming
	visible=true
	return true

func ask_discard() -> void:
	if _state.get("contracts",{}).get("mission",{}).is_empty():return
	_confirming=true;present(_state);_yes.grab_focus()

func confirm_discard() -> void:
	if not _confirming:return
	_confirming=false;discard_requested.emit()

func cancel_discard() -> void:
	_confirming=false;present(_state)

func snapshot() -> Dictionary:
	return {"story":_story_text.text,"job":_job_text.text,"client":_job_name.text,"confirming":_confirming,"discard":_job_discard.visible,"story_map":_story_map.visible}

func handle_event(event: InputEvent) -> bool:
	if not visible:return false
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B):
		if _confirming:cancel_discard()
		else:close_requested.emit()
	return true

func clear() -> void:
	visible=false;_state={};_confirming=false

func reject(message: String) -> bool:error=message;return false
