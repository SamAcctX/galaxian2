extends Control
## Orbit information shown while a flight's 7 s arrival sequence runs: the
## system owner's race logo, the station name, "<System> System" and the
## coloured security level (lines two and three from cursor 16 on).
const Definitions=preload("res://src/content/flight_hud_definitions.gd")
const OriginalUI=preload("res://src/presentation/original_ui.gd")
var error:=""
var mobile_layout:=false
var _ui:={}
var _strings: Array=[]
var _catalogues: RefCounted
var _logos:={}
var _logo: TextureRect
var _station: Label
var _system: Label
var _security: Label
var _key:=[]
var _gauge_rows:=1

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	visible=false
	_logo=TextureRect.new();_logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_logo)
	_station=_label(Color.WHITE);_system=_label(Definitions.ORBIT_SYSTEM_GREY);_security=_label(Color.WHITE)

func _label(colour: Color) -> Label:
	var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",colour)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	add_child(label);return label

func prepare(library: RefCounted,bindings: RefCounted,visuals: RefCounted,catalogues: RefCounted) -> bool:
	error=""
	var ui: Dictionary=bindings.mido_travel.get("map",{}).get("ui",{})
	if ui.is_empty() or catalogues==null:return reject("Orbit information needs the original map interface rules")
	var art:=OriginalUI.new()
	if not art.configure(library,bindings,visuals):return reject(art.error)
	var images:=art.load_regions(library,bindings,visuals,ui.faction_image_ids,ui.atlas_resources)
	if images.is_empty():return reject(art.error)
	_logos=images;_ui=ui;_strings=library.strings;_catalogues=catalogues
	var theme_value:=Theme.new();theme_value.default_font=art.font;theme=theme_value
	set_mobile_layout(mobile_layout)
	return true

## Shows or hides the banner for one flight snapshot.
func present(state: Dictionary) -> bool:
	error=""
	if _catalogues==null:return reject("Prepare the orbit information before presenting it")
	var cursor:=int(state.get("campaign_cursor",state.get("player",{}).get("campaign_cursor",-1)))
	var location: Variant=state.get("location",{})
	var elapsed:=int(state.get("world_phase_elapsed_ms",Definitions.ORBIT_MS))
	var shown: bool=cursor>=Definitions.ORBIT_MIN_CURSOR and elapsed<Definitions.ORBIT_MS and location is Dictionary \
		and typeof(location.get("station_id")) in [TYPE_INT,TYPE_FLOAT] and typeof(location.get("system_id")) in [TYPE_INT,TYPE_FLOAT] and not state.has("void_environment")
	if not shown:visible=false;return true
	var station_id:=int(location.station_id);var system_id:=int(location.system_id)
	if station_id<0 or station_id>=_catalogues.tables.stations.size() or system_id<0 or system_id>=_catalogues.tables.systems.size():visible=false;return true
	_gauge_rows=1+int(float(state.get("gamma_rate",0.0))>0.0)+int(bool(state.get("volatile",false)))
	var key:=[station_id,system_id,cursor>=Definitions.ORBIT_SYSTEM_LINE_MIN_CURSOR]
	if key!=_key:
		_key=key
		var system: Dictionary=_catalogues.tables.systems[system_id]
		var faction:=int(system.fields[2]);var security:=int(system.fields[1])
		# Systems without a race owner draw no logo (the source table stops at four races).
		_logo.texture=_logos.get(int(_ui.faction_image_ids[faction])) if faction>=0 and faction<_ui.faction_image_ids.size() else null
		_station.text=_catalogues.tables.stations[station_id].name
		_system.text="%s %s"%[system.name,_strings[Definitions.ORBIT_SYSTEM_WORD_TEXT]]
		var colours: Array=_ui.security_colors
		var known: bool=security>=0 and security*3+2<colours.size()
		_security.text=_strings[int(_ui.security_text_base)+security] if known else ""
		if known:_security.add_theme_color_override("font_color",Color8(int(colours[security*3]),int(colours[security*3+1]),int(colours[security*3+2])))
		_system.visible=key[2];_security.visible=key[2] and known
	visible=true;_relayout()
	return true

func set_mobile_layout(value: bool) -> void:
	mobile_layout=value
	for label in [_station,_system,_security]:label.add_theme_font_size_override("font_size",20 if value else 14)
	_relayout()

func _relayout() -> void:
	# The original shows this while its flight gauges are hidden; here the
	# gauges stay, so the banner sits below the gauge stack on the left.
	var margin:=16.0 if mobile_layout else 12.0
	var spacing:=34.0 if mobile_layout else 29.0
	var top:=margin+spacing*float(2+_gauge_rows)+8.0
	var logo:=48.0 if mobile_layout else 34.0
	_logo.position=Vector2(margin,top);_logo.size=Vector2.ONE*logo
	var line:=24.0 if mobile_layout else 17.0
	var left:=margin+(logo+8.0 if _logo.texture!=null else 0.0)
	for index in 3:
		var label: Label=[_station,_system,_security][index]
		label.position=Vector2(left,top+line*index);label.size=Vector2(360,line)

func clear() -> void:
	visible=false;_key=[]

func reject(message: String) -> bool:error=message;return false
