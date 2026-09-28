extends Control
## One map interaction: overview, local planets, confirmation, and back.
## Neither child can mutate live flight while the map owns input.
signal destination_requested(station_id: int)
signal close_requested
signal system_requested(system_id: int)
const Local=preload("res://src/presentation/local_map_panel.gd")
const Galaxy=preload("res://src/presentation/galaxy_map_panel.gd")
var error:=""
var _local: Control
var _galaxy: Control
var _sources:={}
var _observation:={}
var _overview:=false
var _active:=false
var _galaxy_ready:=false
var _drive_question: Control
var _drive_modal:=""
# Controls used by native application pilots still belong to the local view.
var _yes: Button:
	get:return _drive_question._yes if not _drive_modal.is_empty() else _local._yes
var _no: Button:
	get:return _drive_question._no if not _drive_modal.is_empty() else _local._no
var _back: Button:
	get:return _galaxy._back if _overview else _local._back
var _status: Label:
	get:return _galaxy._message if _overview else _local._status
var _void_warning: Label:
	get:return _local._void_warning

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP
	_local=Local.new();_galaxy=Galaxy.new()
	for child in [_local,_galaxy]:add_child(child);child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_local.destination_requested.connect(func(id):destination_requested.emit(id))
	_local.close_requested.connect(back_to_overview)
	_local.system_requested.connect(show_system)
	_galaxy.system_requested.connect(show_system)
	_galaxy.close_requested.connect(func():close_requested.emit())
	_drive_question=load("res://src/presentation/gate_confirmation_panel.gd").new();add_child(_drive_question)
	_drive_question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drive_question.choice_requested.connect(_choose_drive)

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,cat: RefCounted,flight: Dictionary,display_system_id: int=-1) -> bool:
	error="";_drive_modal="";_drive_question.clear()
	_sources={"library":library,"bindings":bindings,"visuals":visuals,"cat":cat};_observation=flight.duplicate(true)
	if flight.get("drive_mode",false) and flight.get("location",{}).get("station_id",0)<0:
		_drive_modal="exit_fuel";_overview=false;_galaxy_ready=false;visible=true
		if not _drive_question.present_message(library,bindings,visuals,568):return reject(_drive_question.error)
		_present();return true
	if not _local.configure(library,bindings,visuals,cat,flight,display_system_id):return reject(_local.error)
	_galaxy_ready=int(flight.get("campaign_cursor",-1))>=int(bindings.mido_travel.map.galaxy_cursor) and not flight.get("contracts",{}).get("lounges",{}).get("system_availability",[]).is_empty()
	if _galaxy_ready and not _galaxy.configure(library,bindings,visuals,cat,flight):_local.clear();return reject(_galaxy.error)
	_sources={"library":library,"bindings":bindings,"visuals":visuals,"cat":cat};_observation=flight.duplicate(true)
	visible=true;_overview=_galaxy_ready and display_system_id<0
	if flight.get("drive_void_prompt",false):
		var packet:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"confirmation_text_id":411}
		if not _drive_question.present_departure(library,bindings,visuals,packet):return reject(_drive_question.error)
		_drive_modal="question"
	_present()
	return true

func show_system(id: int) -> void:
	if not _active or not _galaxy_ready or not _drive_modal.is_empty():return
	if not _galaxy._navigation.select_system(id):set_error(_galaxy._navigation.error);return
	if _galaxy._navigation.open_selected()!=id:_galaxy._present();return
	if not _local.configure(_sources.library,_sources.bindings,_sources.visuals,_sources.cat,_observation,id):set_error(_local.error);return
	error="";_overview=false;_present()

func back_to_overview() -> void:
	if _galaxy_ready:_overview=true;_present()
	else:close_requested.emit()

func _present() -> void:
	_local.visible=visible and not _overview and _drive_modal!="exit_fuel";_galaxy.visible=visible and _overview
	_local.set_active(_active and not _overview and _drive_modal.is_empty());_galaxy.set_active(_active and _overview and _drive_modal.is_empty())
	_drive_question.set_active(_active and not _drive_modal.is_empty())

func handle_event(event: InputEvent) -> bool:
	return _drive_question.handle_event(event) if not _drive_modal.is_empty() else _galaxy.handle_event(event) if _overview else _local.handle_event(event)
func set_active(value: bool) -> void:_active=value and visible;_present()
func set_mobile_layout(value: bool) -> void:_local.set_mobile_layout(value);_galaxy.set_mobile_layout(value);_drive_question.set_mobile_layout(value)
func snapshot() -> Dictionary:
	var result: Dictionary=_galaxy.snapshot() if _overview else _local.snapshot()
	if not _drive_modal.is_empty():
		result.merge({"drive_mode":true,"void_prompt":_drive_modal=="question","drive_message":_drive_modal,"confirmation_visible":_drive_modal=="question","selected_station_id":-1,"system_id":-1,"confirmation_text":_drive_question.snapshot().text},true)
	return result

func _choose_drive(result: int) -> void:
	if not _active or _drive_modal.is_empty():return
	if _drive_modal=="exit_fuel":close_requested.emit();return
	if _drive_modal=="question" and result==1:
		var quote: Dictionary=_observation.get("drive_void_quote",{})
		if quote.get("affordable",false):destination_requested.emit(-1);return
		var text_id:=569 if quote.get("cost")==1 and quote.get("energy")==1 else 568
		if not _drive_question.present_message(_sources.library,_sources.bindings,_sources.visuals,text_id):set_error(_drive_question.error);return
		_drive_modal="fuel";_present();return
	_drive_modal="";_drive_question.clear();_present()
func set_error(message: String) -> void:
	error=message
	if _overview:_galaxy.set_error(message)
	else:_local.set_error(message)
func select_station(id: int) -> void:
	if _overview and id>=0 and id<_sources.cat.tables.stations.size():show_system(int(_sources.cat.tables.stations[id].system_id))
	if not _overview:_local.select_station(id)
func request_confirmation() -> void:
	if _overview:_galaxy.open_selected()
	else:_local.request_confirmation()
func confirm_destination() -> void:
	if not _drive_modal.is_empty():_choose_drive(1)
	elif not _overview:_local.confirm_destination()
func back() -> void:
	if not _drive_modal.is_empty():_choose_drive(0)
	elif _overview:close_requested.emit()
	else:_local.back()
func clear() -> void:
	_local.clear();_galaxy.clear();_drive_question.clear();_drive_modal="";_sources={};_observation={};_overview=false;_active=false;_galaxy_ready=false;visible=false;error=""
func reject(message: String) -> bool:error=message;return false
