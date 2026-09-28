extends RefCounted
## An accepted activation quotes one cargo debit. The enclosing flight commits
## it together with this owner; blocked requests never spend or restart a device.
const Definitions=preload("res://src/content/cloak_definitions.gd")
const Readonly=preload("res://src/simulation/readonly_state.gd")
var error:=""
var _equipment:={}
var _phase:="ready"
var _elapsed_ms:=-1
var _cooldown_ms:=0
var _activation:=0
var _audio_serial:=0
var _audio: Array=[]
var _ready_serial:=0
var _failure_serial:=0

func configure(bindings: RefCounted,catalogues: RefCounted,equipment_ids: Array,ship_id: int,difficulty: Variant) -> bool:
	error=""
	var device:=Definitions.resolve(bindings,catalogues,equipment_ids,ship_id,difficulty)
	if device.has("error"):return reject(device.error)
	_equipment=Readonly.freeze(device);_phase="ready";_elapsed_ms=-1;_cooldown_ms=0;_activation=0;_audio_serial=0;_audio=[];_ready_serial=0;_failure_serial=0
	return true

func available() -> bool:return not _equipment.is_empty() and _equipment.item_id>=0
func active() -> bool:return _phase=="active"
func ready() -> bool:return available() and _phase=="ready"

func request_start(energy_units: Variant,permitted: Variant=true) -> Dictionary:
	error=""
	if _equipment.is_empty() or not Definitions.Numbers.integer(energy_units,0,2147483647) or not permitted is bool:return failed("Cloak activation requires a retained cargo quantity and input permission")
	var result:={"started":false,"energy_item":Definitions.ENERGY_ITEM,"consumed":0,"insufficient_energy":false}
	if not permitted or not ready():return result
	if energy_units<_equipment.energy_cost:
		_failure_serial+=1;result.insufficient_energy=true;return result
	_phase="charging";_activation+=1
	result.started=true;result.consumed=int(_equipment.energy_cost)
	return result

func evaluate_request(cargo: RefCounted,permitted: Variant=true) -> Dictionary:
	error=""
	if _equipment.is_empty() or not is_instance_of(cargo,load("res://src/simulation/flight_cargo.gd")):return failed("Cloaking requires its retained flight cargo")
	var hold: Dictionary=cargo.snapshot()
	for key in ["base_content_id","binding_id"]:
		if hold.get(key)!=_equipment[key]:return failed("Cloak energy belongs to another content identity")
	var next: RefCounted=fork_for_frame()
	var request: Dictionary=next.request_start(cargo.quantity(Definitions.ENERGY_ITEM),permitted)
	if request.is_empty():return failed(next.error)
	var owned: RefCounted=cargo
	if request.started:
		owned=cargo.fork_for_frame()
		if not owned.consume(request.energy_item,request.consumed):return failed(owned.error)
	request.cloak=next;request.cargo=owned
	return request

func advance(milliseconds: Variant) -> bool:
	error=""
	if _equipment.is_empty() or not Definitions.Numbers.integer(milliseconds,0,1000):return reject("Cloaking requires a configured device and bounded frame")
	if milliseconds==0:return true
	_audio=[]
	match _phase:
		"charging":
			_elapsed_ms+=int(milliseconds)
			if _elapsed_ms>_equipment.charge_ms:
				_phase="active";_elapsed_ms=0;_emit_audio()
		"active":
			_elapsed_ms+=int(milliseconds)
			if _elapsed_ms>_equipment.duration_ms:
				_phase="cooldown";_elapsed_ms=0;_cooldown_ms=int(_equipment.cooldown_ms);_emit_audio()
		"cooldown":
			_cooldown_ms=maxi(0,_cooldown_ms-int(milliseconds))
			if _cooldown_ms==0:_phase="ready";_ready_serial+=1
	return true

func _emit_audio() -> void:
	_audio_serial+=1
	_audio=[{"source_id":Definitions.SOUND_ID,"phase":_phase}]

func dissolve() -> float:
	if not active():return 0.0
	return clampf(minf(float(_elapsed_ms),float(_equipment.duration_ms-_elapsed_ms))/Definitions.FADE_MS,0.0,1.0)

func snapshot() -> Dictionary:
	if _equipment.is_empty():return {}
	var result:=_equipment.duplicate()
	var amount:=dissolve()
	result.merge({"available":available(),"phase":_phase,"active":active(),"ready":ready(),"elapsed_ms":_elapsed_ms,"remaining_ms":_cooldown_ms,"activation":_activation,
		"progress":clampf(float(_elapsed_ms)/float(_equipment.charge_ms),0.0,1.0) if _phase=="charging" else 0.0,
		"charge":1.0-float(_cooldown_ms)/float(_equipment.cooldown_ms),"dissolve":amount,"animation_seconds":float(_elapsed_ms)/1000.0 if active() else 0.0,
		"attachment_alpha":maxf(50.0/255.0,1.0-amount),"exhaust_alpha":(221.0-201.0*amount)/255.0,
		"audio_serial":_audio_serial,"audio":_audio.duplicate(true),"ready_serial":_ready_serial,"failure_serial":_failure_serial})
	return result

func fork_for_frame() -> RefCounted:
	var next: RefCounted=get_script().new()
	next._equipment=_equipment;next._phase=_phase;next._elapsed_ms=_elapsed_ms;next._cooldown_ms=_cooldown_ms;next._activation=_activation
	next._audio_serial=_audio_serial;next._audio=_audio.duplicate(true);next._ready_serial=_ready_serial;next._failure_serial=_failure_serial
	return next
func reject(message: String) -> bool:error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
