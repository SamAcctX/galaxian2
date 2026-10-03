extends Control
## Station news ticker: the strip above the station footer that scrolls
## "+++"-separated headlines composed from the imported ticker table and texts.
const LoungeContacts=preload("res://src/simulation/lounge_contacts.gd")
const ContactRules=preload("res://src/content/lounge_contact_definitions.gd")
const Encounters=preload("res://src/content/contract_encounter_definitions.gd")
const TABLE="resources/data/bin/ticker.bin"
const RECORD_INTS=7
const RULES={
	"item_count":59,"text_base":3251,"separator":"    +++    ",
	"speed":50.0,"background":Color(0,0,0,0x6f/255.0),"text":Color8(0x77,0x77,0x77),
	"hidden_stations":[101,108],"hidden_systems":[25],
	"random_items":2,"random_tries":100,"random_percent":50,"always_last_cursor":161,
	"drink_item":13,"drink_systems":22,"random_stations":135,"flag_repeat_ms":600000,
	"texts":{"drink":1395,"ship":902,"catastrophe":[3225,5],"berger":[1268,4],"vossk_ship":911,"item":1263,
		"billion":3231,"profession":[3232,4],"activity":[3236,4],"race":[395,4],"crime":[3240,5],"poll_topic":[3245,6]},
	"vossk_ship_percent":40,"vossk_ship_revenue":140,"vossk_item_revenue":12,"vossk_item_property":60,
	"item_type_property":1,"excluded_item_type":4,"vossk_race":1,"vossk_fighter":9,"nivelian_race":2,
}
# A flagged story seen in the last ten minutes of play returns unchanged.
static var _flag_shown_ms:=-1
static var _flag_text:=""
var error:=""
var speed:=50.0
var font_size:=15
var _separator:=","
var _strings:Array=[]
var _cat: RefCounted
var _items:=[]
var _names:=[]
var _text:=""
var _width:=0.0
var _offset:=0.0
var _key:=""
var _rng:=RandomNumberGenerator.new()

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true;visible=false

func configure(library: RefCounted,cat: RefCounted) -> bool:
	error="";_items=[];_names=[];_key="";_text="";visible=false
	var data: PackedByteArray=library.read_resource(TABLE,64*1024)
	if data.size()!=RULES.item_count*RECORD_INTS*4:return reject("Ticker table is unavailable")
	for index in RULES.item_count:
		var row:=[]
		for field in RECORD_INTS:row.append(_be(data,4*(index*RECORD_INTS+field)))
		_items.append({"index":index,"flag":row[0]!=0,"races":[row[1]!=0,row[2]!=0,row[3]!=0,row[4]!=0],"first":row[5],"last":row[6]})
	# The drink story anchors the text layout: a shifted language table disables the strip.
	var base: int=RULES.text_base
	if library.strings.size()<=base+RULES.item_count or not String(library.strings[base+RULES.drink_item]).contains("#DRINK_NAME"):return reject("Ticker texts do not match this content")
	for resource in ContactRules.VALUES.names.resources:
		var names:=LoungeContacts.decode_names(library.read_resource(resource,1024*1024))
		if names.is_empty():return reject("Ticker name table is unavailable")
		_names.append(names)
	# English groups thousands with commas, other languages with points.
	_separator="," if library.active_language=="gb" else "."
	_strings=library.strings;_cat=cat;_rng.randomize()
	return true

func present(station_id: int,cursor: int) -> void:
	if _items.is_empty() or _cat==null or station_id<0 or station_id>=_cat.tables.stations.size():visible=false;return
	var system_id: int=int(_cat.tables.stations[station_id].system_id)
	if station_id in RULES.hidden_stations or system_id in RULES.hidden_systems:visible=false;return
	var key:="%d:%d"%[station_id,cursor]
	if key!=_key:
		_key=key;_text=compose(system_id,cursor,Time.get_ticks_msec())
		_width=0.0
	visible=not _text.is_empty();queue_redraw()

func compose(system_id: int,cursor: int,now_ms: int) -> String:
	var race: int=int(_cat.tables.systems[system_id].fields[2])
	var picked:=[]
	for item in _items:
		if item.first>0 and item.first<=cursor and cursor<=item.last and _allowed(item,race):picked.append(item)
	var chosen:={};var added:=0;var repeat:=false;var fresh_flag:=-1
	for attempt in RULES.random_tries:
		if added>=RULES.random_items:break
		var item: Dictionary=_items[_rng.randi_range(0,_items.size()-1)]
		while item.index==RULES.drink_item and system_id>=RULES.drink_systems:item=_items[_rng.randi_range(0,_items.size()-1)]
		if item.last<RULES.always_last_cursor or item.first>cursor or _rng.randi_range(0,99)>=RULES.random_percent or not _allowed(item,race) or chosen.has(item.index):continue
		if item.flag:
			if _flag_shown_ms>=0 and now_ms-_flag_shown_ms<RULES.flag_repeat_ms:repeat=true;continue
			_flag_shown_ms=now_ms;fresh_flag=item.index
		picked.append(item);chosen[item.index]=true;added+=1
	var parts:=[]
	for item in picked:
		var line:=_tokens(String(_strings[RULES.text_base+item.index]),system_id,race,now_ms)
		if item.index==fresh_flag:_flag_text=line
		parts.append(line)
	if repeat and not _flag_text.is_empty():parts.append(_flag_text)
	if parts.is_empty():return ""
	return RULES.separator.join(parts)+RULES.separator

func text() -> String:return _text

func _allowed(item: Dictionary,race: int) -> bool:
	return race<0 or race>=item.races.size() or item.races[race]

func _tokens(line: String,system_id: int,race: int,now_ms: int) -> String:
	var t: Dictionary=RULES.texts
	var stations: Array=_cat.tables.stations;var systems: Array=_cat.tables.systems
	if line.contains("#PLANET_NAME"):
		var station: Dictionary=stations[_rng.randi_range(0,mini(RULES.random_stations,stations.size())-1)]
		line=_first(line,"#PLANET_NAME",station.name)
		if line.contains("#SYSTEM_NAME"):line=_first(line,"#SYSTEM_NAME",systems[int(station.system_id)].name)
	if line.contains("#SYSTEM_NAME"):
		var named:=system_id
		if line.contains("#DRINK_NAME"):line=_first(line,"#DRINK_NAME",_text_at(t.drink+system_id))
		else:named=_rng.randi_range(0,RULES.drink_systems-1)
		line=_first(line,"#SYSTEM_NAME",systems[named].name)
	if line.contains("#CHILD_NAME"):line=_first(line,"#CHILD_NAME",_name(race).get_slice(" ",0))
	if line.contains("#SHIP_NAME"):line=_first(line,"#SHIP_NAME",_text_at(t.ship+_fighter(_rng.randi_range(0,3))))
	if line.contains("#PLATFORM_NUMBER"):line=_first(line,"#PLATFORM_NUMBER","ABCDEF"[_rng.randi_range(0,5)]+str(_rng.randi_range(0,9)))
	line=_pick(line,"#CATASTROPHE",t.catastrophe)
	if line.contains("#VICTIMS"):line=_first(line,"#VICTIMS",_number((_rng.randi_range(0,98999)+100000)/1000*1000))
	line=_pick(line,"#BERGER_LASER",t.berger)
	if line.contains("#VOSSK_SHIP_OR_ITEM"):
		var ship:=_rng.randi_range(0,99)<RULES.vossk_ship_percent
		line=_first(line,"#VOSSK_SHIP_OR_ITEM",_text_at(t.vossk_ship) if ship else _vossk_item())
		var revenue: int=now_ms/1000000+(RULES.vossk_ship_revenue if ship else RULES.vossk_item_revenue)
		line=_first(line,"#VOSSK_REVENUE",_number(revenue)+" "+_text_at(t.billion))
	line=_pick(line,"#PROFESSION",t.profession)
	if line.contains("#NAME"):line=_first(line,"#NAME",_name(_rng.randi_range(0,7)))
	line=_pick(line,"#ACTIVITY",t.activity)
	line=_pick(line,"#RACE_NAME",t.race)
	line=_pick(line,"#CRIME",t.crime)
	if line.contains("#NIVELIAN_PLANET"):
		var choices:=[]
		for system in systems:
			if int(system.fields[2])==RULES.nivelian_race and not system.station_ids.is_empty():choices.append(system)
		if not choices.is_empty():
			var ids: PackedInt32Array=choices[_rng.randi_range(0,choices.size()-1)].station_ids
			line=_first(line,"#NIVELIAN_PLANET",stations[ids[_rng.randi_range(0,ids.size()-1)]].name)
		line=_first(line,"#DEMONSTRATORS",_number((_rng.randi_range(0,989999)+1000000)/1000*1000))
	if line.contains("#POLL_PERCENTAGE"):
		line=_first(line,"#POLL_PERCENTAGE",str(_rng.randi_range(10,89)))
		line=_pick(line,"#POLL_TOPIC",t.poll_topic)
	if line.contains("#CASUALTIES"):line=_first(line,"#CASUALTIES","2"+str(_rng.randi_range(0,47)))
	return line

func _pick(line: String,token: String,span: Array) -> String:
	if not line.contains(token):return line
	return _first(line,token,_text_at(int(span[0])+_rng.randi_range(0,int(span[1])-1)))

func _first(line: String,token: String,value: String) -> String:
	var at:=line.find(token)
	return line if at<0 else line.substr(0,at)+value+line.substr(at+token.length())

func _text_at(id: int) -> String:return String(_strings[id]) if id>=0 and id<_strings.size() else ""

func _name(race: int) -> String:
	var pools: Array=ContactRules.VALUES.names.pool_choices_by_faction[clampi(race,0,7)]
	var parts:=[]
	for choices in pools:
		if choices.is_empty():continue
		var names: Array=_names[int(choices[_rng.randi_range(0,choices.size()-1)])]
		parts.append(names[_rng.randi_range(0,names.size()-1)])
	return " ".join(parts)

func _fighter(race: int) -> int:
	if race==RULES.vossk_race:return RULES.vossk_fighter
	var hulls: Dictionary=Encounters.VALUES.hulls;var choices:=[]
	for hull in hulls.factions.size():
		if int(hulls.factions[hull])==race and not (hull<=int(hulls.mask_limit) and (int(hulls.excluded_mask)>>hull)&1):choices.append(hull)
	return RULES.vossk_fighter if choices.is_empty() else int(choices[_rng.randi_range(0,choices.size()-1)])

func _vossk_item() -> String:
	var choices:=[]
	for item in _cat.tables.items:
		if int(item.properties.get(RULES.vossk_item_property,0))==1 and item.arrays[0].is_empty() and int(item.properties.get(RULES.item_type_property,-1))!=RULES.excluded_item_type:choices.append(int(item.id))
	return "" if choices.is_empty() else _text_at(RULES.texts.item+int(choices[_rng.randi_range(0,choices.size()-1)]))

func _number(value: int) -> String:
	var digits:=str(value);var separator:=_separator
	var out:=""
	while digits.length()>3:out=separator+digits.substr(digits.length()-3)+out;digits=digits.substr(0,digits.length()-3)
	return digits+out

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _text.is_empty():return
	if _width<=0.0:
		_width=get_theme_default_font().get_string_size(_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x;_offset=size.x
		# A short story list is repeated so the strip never runs empty.
		if _width>0.0 and _width<size.x:_text+=_text;_width*=2.0
	if _width<=0.0:return
	_offset-=speed*delta
	if _offset< -_width:_offset=0.0
	queue_redraw()

func _draw() -> void:
	if _text.is_empty():return
	draw_rect(Rect2(Vector2.ZERO,size),RULES.background)
	var font:=get_theme_default_font()
	var baseline:=2.0+font.get_ascent(font_size)
	draw_string(font,Vector2(_offset,baseline),_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,RULES.text)
	if _width>0.0 and _offset<size.x-_width:draw_string(font,Vector2(_offset+_width,baseline),_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,RULES.text)

static func _be(data: PackedByteArray,at: int) -> int:
	var value:=(data[at]<<24)|(data[at+1]<<16)|(data[at+2]<<8)|data[at+3]
	return value-0x100000000 if value>=0x80000000 else value

func reject(message: String) -> bool:error=message;return false
