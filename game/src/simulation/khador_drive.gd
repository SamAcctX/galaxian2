extends RefCounted
## One transient trip: quote, atomic fuel debit, charge and departure. World
## admission and the surviving inventory/career transfer belong to the host.
const Definitions=preload("res://src/content/khador_drive_definitions.gd")
const Navigation=preload("res://src/simulation/system_navigation.gd")
var error:=""
var _device:={}
var _location:={}
var _return_location:={}
var _destinations:={}
var _navigation: RefCounted
var _phase:="ready"
var _elapsed_ms:=0
var _trip:={}
var _pose:=Transform3D.IDENTITY
var _effect_pose:=Transform3D.IDENTITY
var _camera:=Vector3.ZERO
var _audio_serial:=0
var _audio: Array=[]

func configure(bindings: RefCounted,cat: RefCounted,loadout: Dictionary,difficulty: float,navigation: RefCounted,destinations: Array,return_location: Dictionary={}) -> bool:
	error=""
	var device:=Definitions.resolve(bindings,cat,loadout,difficulty)
	if device.has("error"):return reject(device.error)
	if not navigation is Navigation:return reject("Khador Drive requires retained system navigation")
	var routing: Dictionary=navigation.snapshot()
	for key in ["base_content_id","binding_id"]:
		if routing.get(key)!=device[key]:return reject("Khador Drive navigation belongs to another content source")
	var choices:={}
	for id in destinations:
		if not Definitions.Numbers.integer(id,0,cat.tables.stations.size()-1):return reject("Khador Drive destination is absent from the catalogue")
		var station: Dictionary=cat.tables.stations[id]
		if routing.system_availability[station.system_id]:choices[id]={"station_id":id,"system_id":station.system_id,"no_gate":cat.tables.systems[station.system_id].linked_system_ids.is_empty()}
	_device=device;_location={"station_id":loadout.station_id,"system_id":loadout.system_id}
	_return_location=return_location.duplicate();_destinations=choices;_navigation=navigation.fork()
	return true

static func permits_mission(mission: Dictionary) -> bool:
	return mission.get("completed",mission.is_empty()) or mission.get("kind",-1) in [-1,0,11,13,171,172,189]

func available() -> bool:return _device.get("available",false)
func ready() -> bool:return available() and _phase=="ready"
func departing() -> bool:return _phase in ["departing","arrival"]

func quote(station_id: int,energy: int) -> Dictionary:
	error=""
	if not ready() or energy<0:return failed("Khador Drive is not ready for a destination")
	var destination: Dictionary
	var cost:=int(_device.void_fuel);var required:=cost;var mode:="normal"
	if _location.station_id<0:
		if _return_location.is_empty():return failed("Khador Drive lost its normal-space return location")
		destination=_return_location;mode="void_exit"
	elif station_id<0:
		destination={"station_id":-1,"system_id":-1};required=cost*2;mode="void_entry"
	else:
		if not _destinations.has(station_id):return failed("This Khador destination is unavailable")
		if station_id==_location.station_id:return failed("The ship is already at this planet")
		destination=_destinations[station_id]
		var route: Array=_navigation.route(_location.system_id,destination.system_id)
		cost=(4 if route.is_empty() else route.size()-1)*int(_device.fuel_multiplier);required=cost
		if destination.system_id==_location.system_id:mode="local"
	var result:=_device.duplicate()
	result.merge({"mode":mode,"from_station_id":_location.station_id,"from_system_id":_location.system_id,
		"station_id":destination.station_id,"system_id":destination.system_id,"cost":cost,"energy":energy,"required":required,"affordable":energy>=required,
		"return_warning":mode=="normal" and destination.get("no_gate",false) and energy<cost*2,
		"gate_alternative":mode=="normal" and cost==1 and energy<cost,
		"return_location":_location.duplicate() if mode=="void_entry" else _return_location.duplicate()})
	return result

func evaluate_request(station_id: int,cargo: RefCounted) -> Dictionary:
	error=""
	if not is_instance_of(cargo,load("res://src/simulation/flight_cargo.gd")):return failed("Khador Drive requires the current cargo owner")
	for key in ["base_content_id","binding_id"]:
		if cargo.snapshot().get(key)!=_device.get(key):return failed("Khador fuel belongs to another content source")
	var trip:=quote(station_id,cargo.quantity(Definitions.ENERGY_ITEM))
	if trip.is_empty():return {}
	var next:=fork_for_frame();var hold: RefCounted=cargo
	if trip.mode=="local":return failed("Local destinations use ordinary flight")
	if trip.affordable:
		hold=cargo.fork_for_frame()
		if trip.cost>0 and not hold.consume(Definitions.ENERGY_ITEM,trip.cost):return failed(hold.error)
		next._trip=trip;next._phase="charging";next._elapsed_ms=0
		next._audio_serial+=1;next._audio=[{"source_id":Definitions.CHARGE_SOUND,"phase":"charging"}]
	return {"drive":next,"cargo":hold,"started":trip.affordable,"quote":trip}

func advance(milliseconds: int,pose: Transform3D) -> bool:
	error=""
	if not Definitions.Numbers.integer(milliseconds,0,1000) or not pose.is_finite():return reject("Khador Drive requires a bounded finite flight frame")
	if _phase=="charging":
		_elapsed_ms+=milliseconds
		if _elapsed_ms>=int(_device.charge_ms):
			_phase="departing";_elapsed_ms=0;_pose=pose
			_effect_pose=Transform3D(Basis.looking_at(pose.basis.z,Vector3.UP,true),pose.origin+pose.basis.z*3000.0)
			_camera=_effect_pose.origin+pose.basis*Vector3(-2000,300,-2000)
			_audio_serial+=1;_audio=[{"source_id":Definitions.DEPARTURE_SOUND,"phase":"departing"}]
	elif _phase=="departing":
		var moving:=mini(milliseconds,maxi(0,Definitions.HIDE_PLAYER_MS-_elapsed_ms))
		_camera+=_pose.basis*Vector3(5,2,-5)*float(moving)
		_elapsed_ms+=milliseconds
		if _elapsed_ms>=Definitions.DEPARTURE_MS:_phase="arrival"
	return true

func arrival_request() -> Dictionary:return _trip.duplicate(true) if _phase=="arrival" else {}

func snapshot() -> Dictionary:
	if _device.is_empty():return {}
	var result:=_device.duplicate()
	result.merge({"phase":_phase,"elapsed_ms":_elapsed_ms,"progress":float(_elapsed_ms)/float(_device.charge_ms) if _phase=="charging" else 0.0,
		"trip":_trip.duplicate(true),"audio_serial":_audio_serial,"audio":_audio.duplicate(true),"camera_position":_camera,
		"player_visible":not departing() or _elapsed_ms<=Definitions.HIDE_PLAYER_MS,
		"effect":{"base_content_id":_device.base_content_id,"binding_id":_device.binding_id,"model_id":Definitions.MODEL_ID,
			"pose":_effect_pose,"scale":2.0,"visible":departing(),"animation":{"time_ms":_elapsed_ms if departing() else 0}}})
	return result

func fork_for_frame() -> RefCounted:
	var next: RefCounted=get_script().new()
	next._device=_device;next._location=_location;next._destinations=_destinations;next._navigation=_navigation;next._return_location=_return_location
	next._phase=_phase;next._elapsed_ms=_elapsed_ms;next._trip=_trip;next._pose=_pose;next._effect_pose=_effect_pose;next._camera=_camera
	next._audio_serial=_audio_serial;next._audio=_audio
	return next
func reject(message: String) -> bool:error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
