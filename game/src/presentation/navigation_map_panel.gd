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
# Controls used by native application pilots still belong to the local view.
var _yes: Button:
	get:return _local._yes
var _no: Button:
	get:return _local._no
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

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,cat: RefCounted,flight: Dictionary,display_system_id: int=-1) -> bool:
	error=""
	if not _local.configure(library,bindings,visuals,cat,flight,display_system_id):return reject(_local.error)
	_galaxy_ready=int(flight.get("campaign_cursor",-1))>=int(bindings.mido_travel.map.galaxy_cursor) and not flight.get("contracts",{}).get("lounges",{}).get("system_availability",[]).is_empty()
	if _galaxy_ready and not _galaxy.configure(library,bindings,visuals,cat,flight):_local.clear();return reject(_galaxy.error)
	_sources={"library":library,"bindings":bindings,"visuals":visuals,"cat":cat};_observation=flight.duplicate(true)
	visible=true;_overview=_galaxy_ready and display_system_id<0;_present()
	return true

func show_system(id: int) -> void:
	if not _active or not _galaxy_ready:return
	if not _galaxy._navigation.select_system(id):set_error(_galaxy._navigation.error);return
	if _galaxy._navigation.open_selected()!=id:_galaxy._present();return
	if not _local.configure(_sources.library,_sources.bindings,_sources.visuals,_sources.cat,_observation,id):set_error(_local.error);return
	error="";_overview=false;_present()

func back_to_overview() -> void:
	if _galaxy_ready:_overview=true;_present()
	else:close_requested.emit()

func _present() -> void:
	_local.visible=visible and not _overview;_galaxy.visible=visible and _overview
	_local.set_active(_active and not _overview);_galaxy.set_active(_active and _overview)

func handle_event(event: InputEvent) -> bool:
	return _galaxy.handle_event(event) if _overview else _local.handle_event(event)
func set_active(value: bool) -> void:_active=value and visible;_present()
func set_mobile_layout(value: bool) -> void:_local.set_mobile_layout(value);_galaxy.set_mobile_layout(value)
func snapshot() -> Dictionary:return _galaxy.snapshot() if _overview else _local.snapshot()
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
	if not _overview:_local.confirm_destination()
func back() -> void:
	if _overview:close_requested.emit()
	else:_local.back()
func clear() -> void:
	_local.clear();_galaxy.clear();_sources={};_observation={};_overview=false;_active=false;_galaxy_ready=false;visible=false;error=""
func reject(message: String) -> bool:error=message;return false
