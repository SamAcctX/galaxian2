extends Control
## Native acknowledged conversation with original localized text and portraits.
## Layout remains crisp at compact desktop and larger phone composition sizes.
signal next_requested
signal previous_requested
const Portraits=preload("res://src/presentation/portrait_compositor.gd")
const Definitions=preload("res://src/content/station_presentation_definitions.gd")
const MiningStory=preload("res://src/content/ordinary_flight_definitions.gd")
const StationReturn=preload("res://src/content/ordinary_flight_definitions.gd")
const Art=preload("res://src/presentation/original_ui.gd")
var error:=""
var portrait_diagnostics:={}
var _art: RefCounted
var _identity:={}
var _portraits:={}
var _labels:={}
var _mobile:=false
var _centered:=false
var _snapshot:={}
var _contact_portrait: Texture2D
var _contact_final_text:=""
var _active:=true
var _panel: PanelContainer
var _body: RichTextLabel
var _portrait: TextureRect
var _name: Label
var _next: Button
var _previous: Button
var _counter: Label

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;visible=false
	_panel=PanelContainer.new();add_child(_panel)
	var margin:=MarginContainer.new();_panel.add_child(margin)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,12)
	var column:=VBoxContainer.new();margin.add_child(column)
	var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(row)
	_portrait=TextureRect.new();_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(_portrait)
	var text_column:=VBoxContainer.new();text_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text_column)
	_name=Label.new();_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;text_column.add_child(_name)
	_body=RichTextLabel.new();_body.bbcode_enabled=false;_body.scroll_active=true
	_body.size_flags_vertical=Control.SIZE_EXPAND_FILL;_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text_column.add_child(_body)
	var buttons:=HBoxContainer.new();column.add_child(buttons)
	_previous=Button.new();_previous.text="‹";_previous.tooltip_text="Previous line · Left / controller B"
	_previous.pressed.connect(func():previous_requested.emit());buttons.add_child(_previous)
	_counter=Label.new();_counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_counter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.add_child(_counter)
	_next=Button.new();_next.pressed.connect(func():next_requested.emit());buttons.add_child(_next)
	resized.connect(_relayout)
	_panel.minimum_size_changed.connect(_relayout)
	_panel.resized.connect(_place_panel)
	set_mobile_layout(false)

func configure(library: RefCounted, bindings: RefCounted, visuals: RefCounted) -> bool:
	if library==null or bindings==null or visuals==null or not Definitions.parameters(bindings.station_presentation):return reject("Station conversation resources are unavailable")
	return _configure_resources(library,bindings,visuals,bindings.station_presentation.dialogue)

func configure_empty(library: RefCounted,bindings: RefCounted) -> bool:
	clear()
	if library.manifest.get("content_id")!=bindings.base_content_id:return reject("Station dialogue belongs to another content identity")
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"language":library.active_language}
	return true

func configure_mining_briefing(library: RefCounted, bindings: RefCounted, visuals: RefCounted, campaign_cursor:=2, ordinary_world:=false) -> bool:
	if library==null or bindings==null or visuals==null or not Definitions.parameters(bindings.station_presentation):return reject("Mining briefing resources are unavailable")
	var rules:=MiningStory.briefing_presentation(bindings,campaign_cursor,ordinary_world)
	if rules.is_empty():return reject("Mining briefing resources are unavailable for this departure")
	return _configure_resources(library,bindings,visuals,rules)

func configure_mining_objective(library: RefCounted, bindings: RefCounted, visuals: RefCounted, campaign_cursor:=2) -> bool:
	if library==null or bindings==null or visuals==null or not Definitions.parameters(bindings.station_presentation):return reject("Mining return resources are unavailable")
	var rules:=MiningStory.objective(bindings,campaign_cursor)
	if rules.is_empty():return reject("Mining return resources are unavailable for this departure")
	return _configure_resources(library,bindings,visuals,rules)

func configure_campaign_visit(library: RefCounted,bindings: RefCounted,visuals: RefCounted,cursor: int,mission: Dictionary,station_only:=false) -> bool:
	if library==null or bindings==null or visuals==null:return reject("Campaign conversation resources are unavailable")
	var rules: Dictionary=load("res://src/content/free_campaign_definitions.gd").dialogue_presentation(bindings,cursor,mission,station_only)
	if rules.is_empty():return reject("Campaign conversation navigation is unavailable")
	return _configure_resources(library,bindings,visuals,rules)

func configure_campaign_result(library: RefCounted,bindings: RefCounted,visuals: RefCounted,cursor: int,mission: Dictionary,failed:=false) -> bool:
	if library==null or bindings==null or visuals==null:return reject("Campaign result resources are unavailable")
	var rules: Dictionary=load("res://src/content/free_campaign_definitions.gd").result_presentation(bindings,cursor,mission,failed)
	if rules.is_empty():return reject("Campaign result navigation is unavailable")
	return _configure_resources(library,bindings,visuals,rules)

func configure_station_return(library: RefCounted, bindings: RefCounted, visuals: RefCounted, campaign_cursor:=3) -> bool:
	if library==null or bindings==null or visuals==null or not Definitions.parameters(bindings.station_presentation):return reject("Station return resources are unavailable")
	var rules:=StationReturn.station_conversation(bindings,campaign_cursor)
	if rules.is_empty():return reject("Station return resources are unavailable for this visit")
	return _configure_resources(library,bindings,visuals,rules)

func configure_campaign_failure(library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> bool:
	if library==null or bindings==null or visuals==null:return reject("Campaign failure resources are unavailable")
	var rules: Dictionary=load("res://src/content/kappa_outcome_definitions.gd").failure_presentation(bindings)
	if rules.is_empty():return reject("Original campaign failure navigation is unavailable")
	return _configure_resources(library,bindings,visuals,rules)

func configure_flight(library: RefCounted,bindings: RefCounted,visuals: RefCounted,state: Dictionary,mission_context: RefCounted=null) -> bool:
	if state.is_empty() or not state.get("player") is Dictionary:return reject("Flight conversation has no player state")
	var cursor:=int(state.player.get("campaign_cursor",-1))
	if state.player.has("void_context"):
		if not MiningStory.Authored.VoidCrystals.selected_void(bindings.mido_travel,state.player.void_context):return reject("Void dialogue lost its admitted world")
		return configure(library,bindings,visuals)
	if mission_context!=null and mission_context.advances_campaign():
		if not is_instance_of(mission_context,load("res://src/simulation/mission_context.gd")) or mission_context.identity().campaign_cursor!=cursor:return reject("Flight dialogue lost its admitted mission")
		return _configure_resources(library,bindings,visuals,load("res://src/content/mission_recipe.gd").objective(bindings,mission_context.recipe()))
	# Story encounters keep the ordinary career owner, but their modal lines
	# belong to the story objective, not the independent retained delivery.
	if state.has("void_environment") or state.player.has("bakka_context") or state.player.has("dekato_context"):return configure_mining_objective(library,bindings,visuals,cursor)
	if state.has("kappa_rescue") or state.has("sahi_stage") or cursor==26:return configure_mining_briefing(library,bindings,visuals,cursor)
	if state.get("mining_objective",{}).has("campaign_visit"):
		return configure_campaign_visit(library,bindings,visuals,int(state.campaign_cursor),state.mission)
	if state.has("mining_objective") and not state.has("contracts"):
		return configure_mining_objective(library,bindings,visuals,cursor)
	return configure_mining_briefing(library,bindings,visuals,cursor,state.has("contracts"))

func _configure_resources(library: RefCounted, bindings: RefCounted, visuals: RefCounted, rules: Dictionary) -> bool:
	clear();_identity={};_portraits={};_labels={};portrait_diagnostics={}
	_art=null;theme=null
	if library.manifest.get("content_id")!=bindings.base_content_id or visuals.base_content_id!=bindings.base_content_id:return reject("Station conversation belongs to another base content")
	for key in ["next_text_id","final_text_id"]:
		var id:=int(rules[key])
		if id>=library.strings.size() or library.strings[id].is_empty():return reject("Station navigation text is unavailable")
		_labels[key]=library.strings[id]
	var composer:=Portraits.new()
	var speakers:=[0,2,16]
	for event in rules.get("events",[]):
		var id:=int(event.speaker_id)
		if not speakers.has(id):speakers.append(id)
	for id in speakers:
		var definition: Dictionary=rules.get("portraits",{}).get(str(id),bindings.station_presentation.portraits.get(str(id),{}))
		if definition.is_empty():definition=bindings.resolve_speaker_portrait(id)
		if definition.is_empty():return reject(bindings.error)
		var portrait: Dictionary=composer.compose_definition(library,bindings,visuals,id,"large",definition)
		if portrait.is_empty():return reject(composer.error)
		_portraits[id]=ImageTexture.create_from_image(portrait.image)
	if not bindings.mido_travel.get("map",{}).get("ui",{}).is_empty():
		var art:=Art.new()
		if not art.configure(library,bindings,visuals):return reject(art.error)
		_art=art
		var original:=Theme.new();original.default_font=art.font;theme=original
	set_mobile_layout(_mobile)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"language":library.active_language}
	return true

## A generated contact can speak without replacing the campaign's speaker
## catalogue. The notice lifetime belongs to the station session, not this view.
func prepare_contact_notice(library: RefCounted,bindings: RefCounted,visuals: RefCounted,portrait: Dictionary) -> bool:
	var composer:=Portraits.new()
	var composed: Dictionary=composer.compose_definition(library,bindings,visuals,0,"large",portrait)
	if composed.is_empty():return reject(composer.error)
	var label_id:=int(bindings.station_presentation.dialogue.final_text_id)
	if label_id<0 or label_id>=library.strings.size() or library.strings[label_id].is_empty():return reject("The contact notice has no acknowledgement label")
	if _art==null:
		var art:=Art.new()
		if not art.configure(library,bindings,visuals):return reject(art.error)
		_art=art
		var original:=Theme.new();original.default_font=art.font;theme=original
		set_mobile_layout(_mobile)
	_contact_portrait=ImageTexture.create_from_image(composed.image)
	_contact_final_text=library.strings[label_id]
	return true

func present(state: Dictionary) -> bool:
	error=""
	if state.is_empty():clear();return true
	for key in _identity:
		if state.get(key)!=_identity[key]:return reject("Station conversation belongs to another session")
	if _identity.is_empty() or not state.get("dialogue") is Dictionary:return reject("Invalid station conversation")
	var line: Dictionary=state.dialogue
	if not line.get("visible",false):clear();return true
	var contact_notice: bool=line.get("contact_notice",false)
	if (_contact_portrait==null if contact_notice else not _portraits.has(line.get("speaker_id"))) or not line.get("text") is String or not line.get("speaker_name") is String:return reject("Invalid station conversation line")
	if not line.get("desktop_text",line.text) is String:return reject("Invalid desktop station text")
	if _snapshot==line:return true
	_snapshot=line.duplicate(true);_name.text=line.speaker_name;_body.text=line.text
	_body.scroll_to_line(0);_portrait.texture=_contact_portrait if contact_notice else _portraits.get(int(line.speaker_id))
	_portrait.visible=_portrait.texture!=null
	_next.text=_contact_final_text if contact_notice else (_labels.final_text_id if line.index==line.count-1 else _labels.next_text_id)
	_counter.text="%d / %d"%[int(line.index)+1,int(line.count)]
	visible=true;set_active(_active);_relayout()
	return true

func set_active(value: bool) -> void:
	_active=value
	_next.disabled=not value
	_previous.disabled=not value or not _snapshot.get("previous_available",false)

func set_centered(value: bool) -> void:
	_centered=value;_place_panel()

func set_mobile_layout(value: bool) -> void:
	_mobile=value
	if _art!=null:
		_panel.add_theme_stylebox_override("panel",_art.styles[value].panel)
		_name.add_theme_color_override("font_color",Color.WHITE)
		for label in [_name,_counter]:label.add_theme_font_size_override("font_size",20 if value else 14)
		_art.apply_button(_previous,value,true);_art.apply_button(_next,value)
		_relayout();return
	var scale:=1.0 if value else 0.5
	_body.add_theme_font_size_override("normal_font_size",int(30*scale))
	_name.add_theme_font_size_override("font_size",int(32*scale))
	for button in [_next,_previous]:button.add_theme_font_size_override("font_size",int(30*scale))
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.025,0.055,0.085,0.96)
	style.border_color=Color(0.24,0.53,0.65,0.95);style.set_border_width_all(1);style.set_corner_radius_all(int(12*scale))
	_panel.add_theme_stylebox_override("panel",style)
	_name.add_theme_color_override("font_color",Color(0.68,0.86,0.93));_relayout()

func _relayout() -> void:
	if not visible:return
	var selected: String=_snapshot.get("text","") if _mobile else _snapshot.get("desktop_text",_snapshot.get("text",""))
	if _body.text!=selected:_body.text=selected;_body.scroll_to_line(0)
	if size.x<1 or size.y<1:return
	var scale:=1.0 if _mobile else 0.5
	var width:=minf(1120*scale,maxf(1,size.x-24))
	var height:=minf(390*scale,maxf(1,size.y-24))
	var narrow:=_mobile and width<600
	_body.add_theme_font_size_override("normal_font_size",(20 if _mobile else 14) if _art!=null else (24 if narrow else int(30*scale)))
	_name.add_theme_font_size_override("font_size",(20 if _mobile else 14) if _art!=null else (24 if narrow else int(32*scale)))
	_portrait.custom_minimum_size=Vector2(104,130) if narrow else Vector2(160*scale,180*scale)
	_body.custom_minimum_size.y=32*scale
	for button in [_next,_previous]:button.custom_minimum_size=Vector2(44,44) if _mobile else Vector2(0,30 if _art!=null else 0)
	# Child font/touch-target changes invalidate the container's minimum size.
	# Apply the requested compact size after them and again when that minimum
	# settles. Position from the actual panel size, including translated labels.
	_panel.size=Vector2(width,height)
	_place_panel()

func _place_panel() -> void:
	if not visible:return
	var bottom_margin:=24.0 if _mobile else 12.0
	var top: float=(size.y-_panel.size.y)/2 if _centered else size.y-_panel.size.y-bottom_margin
	_panel.position=Vector2(maxf(0,(size.x-_panel.size.x)/2),maxf(0,top))

func clear() -> void:
	error="";_snapshot={};visible=false;_name.text="";_body.text="";_portrait.texture=null
func reject(message: String) -> bool:error=message;return false
