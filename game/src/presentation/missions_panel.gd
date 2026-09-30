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
const Wanted=preload("res://src/simulation/wanted_board.gd")
const TEXT:={"wanted":3208,"wanted_list":3210,"wanted_details":3211,"departed":3212,"travelling":3213,"bounty":3214,"status":3215,"deceased":3216,"alive":3217,"unknown":3218,"title":128,"story":544,"freelance":545,"no_job":173,"map":413,"discard":412,"confirm":853,"yes":133,"no":134,"back":169,"won":659,"won_gold":639}
## Story text per campaign cursor, read from the original story table.
const STORY_TEXT:=[738,738,738,738,738,738,738,738,738,738,641,642,643,644,645,738,646,738,647,738,648,648,738,649,650,738,738,738,651,738,738,738,652,653,654,655,656,738,657,738,658,738,738,738,659,659,660,738,661,661,661,661,661,661,661,662,663,738,664,665,738,666,667,668,669,738,670,671,672,673,673,674,675,676,677,738,738,678,679,679,680,680,738,738,681,681,682,683,683,683,683,684,685,686,687,687,688,689,690,690,691,691,692,693,694,695,696,697,698,699,699,700,701,702,703,704,705,706,707,707,708,708,709,710,710,711,711,712,713,713,714,715,715,715,716,717,718,719,720,721,722,723,724,725,725,726,727,728,729,729,729,729,730,731,732,732,733,734,735,736,737,737,737]
const STORY_DEFAULT:=738
## The epilogue hands the career on at cursor 45; without the expansion story
## there is no further story target.
const WON_CURSOR:=45
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")
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
var _body_row: Control
var _wanted_view: Control
var _wanted_button: Button
var _wanted_list: VBoxContainer
var _wanted_details: Label
var _wanted_open:=false
var _wanted_selected:=-1
## Criminal biographies are texts WANTED_BIOGRAPHY + entry index.
const WANTED_BIOGRAPHY:=3163

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop:=ColorRect.new();backdrop.color=Color(0.0,0.02,0.05,0.96);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root:=MarginContainer.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:root.add_theme_constant_override("margin_"+side,16)
	var column:=VBoxContainer.new();root.add_child(column)
	_header=_bar(column)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",16);column.add_child(body)
	_body_row=body
	# Most Wanted: the board's names beside the selected criminal's details.
	var wanted:=HBoxContainer.new();wanted.size_flags_vertical=Control.SIZE_EXPAND_FILL;wanted.add_theme_constant_override("separation",16);wanted.visible=false;column.add_child(wanted)
	_wanted_view=wanted
	var list_column:=VBoxContainer.new();list_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;wanted.add_child(list_column)
	_bar(list_column).name="ListBar"
	_wanted_list=VBoxContainer.new();list_column.add_child(_wanted_list)
	var details_column:=VBoxContainer.new();details_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details_column.size_flags_stretch_ratio=2.0;wanted.add_child(details_column)
	_bar(details_column).name="DetailsBar"
	_wanted_details=_body(details_column)
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
	_wanted_button=Button.new();_wanted_button.visible=false;_wanted_button.pressed.connect(toggle_wanted);footer.add_child(_wanted_button)

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
	_yes.text=text("yes");_no.text=text("no");_back.text=text("back");_wanted_button.text=text("wanted")
	_wanted_view.find_child("ListBar",true,false).text=text("wanted_list");_wanted_view.find_child("DetailsBar",true,false).text=text("wanted_details")
	if status._ui!=null:
		for button in [_story_map,_job_map,_job_discard,_yes,_no,_back,_wanted_button]:status._ui.apply_button(button,status._mobile)
	return true

func story_text(state: Dictionary) -> String:
	var career: Dictionary=state.get("contracts",{})
	var cursor: int=int(state.get("campaign_cursor",career.get("campaign_cursor",0)))
	if won(cursor):
		var levels: Array=career.get("base_medals",{}).get("levels",[])
		var all_gold: bool=levels.size()>=Medals.BASE_COUNT and levels.slice(0,Medals.BASE_COUNT).all(func(level):return int(level)==1)
		return text("won_gold") if all_gold and int(state.get("loadout",{}).get("ship_id",-1))!=GOLD_EXCEPTION_SHIP else text("won")
	var id: int=STORY_TEXT[cursor] if cursor>=0 and cursor<STORY_TEXT.size() else STORY_DEFAULT
	var line: String=_library.strings[id] if id<_library.strings.size() else ""
	var mission: Dictionary=state.get("mission",{})
	if line.contains("#Q"):return line.replace("#Q",str(int(mission.get("quantity",0))))
	var station: int=int(mission.get("station_id",-1))
	return line.replace("#",_catalogues.tables.stations[station].name if station>=0 and station<_catalogues.tables.stations.size() else "")

func won(cursor: int) -> bool:
	return cursor>=WON_CURSOR and not Valkyrie.active(_bindings,cursor)

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
	var finished: bool=won(int(state.get("campaign_cursor",0)))
	_story_text.text=story_text(state)
	_story_map.visible=not finished
	_job_portrait.texture=null if job.is_empty() else _client_portrait
	_job_portrait.visible=_job_portrait.texture!=null
	_job_name.text="" if job.is_empty() else str(contact.get("name",""))
	_job_text.text=job_text(job)
	if _confirming and not job.is_empty():_job_text.text=text("confirm")
	else:_confirming=false
	_job_map.visible=not job.is_empty() and not _confirming
	_job_discard.visible=not job.is_empty() and not _confirming
	_yes.visible=_confirming;_no.visible=_confirming
	_present_wanted(state,career)
	visible=true
	return true

## The board shows at stations of a race whose list the story has reached.
func _present_wanted(state: Dictionary,career: Dictionary) -> void:
	var table: Array=_catalogues.tables.get("wanted",[])
	var cursor:=int(state.get("campaign_cursor",career.get("campaign_cursor",0)))
	var station:=int(career.get("station_id",state.get("station_id",-1)))
	var open: bool=not table.is_empty() and Valkyrie.saved_story(_bindings,cursor) and Wanted.accessible(table,_catalogues,cursor,station)
	_wanted_button.visible=open
	if not open:_wanted_open=false
	_wanted_view.visible=_wanted_open;_body_row.visible=not _wanted_open
	if not _wanted_open:return
	var board: Variant=career.get("progress",{}).get("wanted")
	var entries: Array=board.entries if Wanted.valid(board,table) else []
	var listed:=Wanted.listed(table,_catalogues,station)
	if not listed.has(_wanted_selected):_wanted_selected=listed[0] if not listed.is_empty() else -1
	for child in _wanted_list.get_children():child.queue_free()
	for index in listed:
		var active: bool=index<entries.size() and entries[index].active
		var button:=Button.new();button.text=String(table[index].name);button.flat=true;button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color",Color.WHITE if active else Color(0.55,0.55,0.55))
		if index==_wanted_selected:button.add_theme_color_override("font_color",Color(1.0,0.85,0.3) if active else Color(0.7,0.62,0.35))
		button.pressed.connect(select_wanted.bind(index))
		_wanted_list.add_child(button)
	_wanted_details.text=wanted_details(table,entries,_wanted_selected)

func wanted_details(table: Array,entries: Array,index: int) -> String:
	if index<0 or index>=table.size():return ""
	var row: Dictionary=table[index]
	var entry: Dictionary=entries[index] if index<entries.size() else {}
	var dead: bool=entry.get("dead",false)
	var lines:=[String(row.name),"%s %s"%[text("status"),text("deceased") if dead else text("alive")],"%s %d$"%[text("bounty"),int(row.reward)]]
	if dead:lines.append_array(["%s --"%text("departed"),"%s --"%text("travelling")])
	elif entry.get("active",false):lines.append_array(["%s %s"%[text("departed"),_place(int(entry.from))],"%s %s"%[text("travelling"),_place(int(entry.to))]])
	else:lines.append_array(["%s %s"%[text("departed"),text("unknown")],"%s %s"%[text("travelling"),text("unknown")]])
	var biography:=WANTED_BIOGRAPHY+index
	if biography<_library.strings.size():lines.append("\n"+_library.strings[biography])
	return "\n".join(lines)

## "Station (System)".
func _place(station_id: int) -> String:
	if station_id<0 or station_id>=_catalogues.tables.stations.size():return text("unknown")
	var system:=Wanted.system_of(_catalogues,station_id)
	return "%s (%s)"%[_catalogues.tables.stations[station_id].name,_catalogues.tables.systems[system].name]

func toggle_wanted() -> void:
	_wanted_open=not _wanted_open;_confirming=false
	if not _state.is_empty():present(_state)

func select_wanted(index: int) -> void:
	_wanted_selected=index
	if not _state.is_empty():present(_state)

func ask_discard() -> void:
	if _state.get("contracts",{}).get("mission",{}).is_empty():return
	_confirming=true;present(_state);_yes.grab_focus()

func confirm_discard() -> void:
	if not _confirming:return
	_confirming=false;discard_requested.emit()

func cancel_discard() -> void:
	_confirming=false;present(_state)

func snapshot() -> Dictionary:
	return {"story":_story_text.text,"job":_job_text.text,"client":_job_name.text,"confirming":_confirming,"discard":_job_discard.visible,"story_map":_story_map.visible,
		"wanted_available":_wanted_button.visible,"wanted_open":_wanted_open,"wanted":_wanted_details.text if _wanted_open else ""}

func handle_event(event: InputEvent) -> bool:
	if not visible:return false
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B):
		if _confirming:cancel_discard()
		elif _wanted_open:toggle_wanted()
		else:close_requested.emit()
	return true

func clear() -> void:
	visible=false;_state={};_confirming=false;_wanted_open=false

func reject(message: String) -> bool:error=message;return false
