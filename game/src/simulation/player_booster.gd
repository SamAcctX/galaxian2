extends RefCounted
## One fitted device, shared by motion, exhaust, sound and the flight button.
## World owners advance it before motion and submit input in their late pass.
const Definitions=preload("res://src/content/booster_definitions.gd")
const Readonly=preload("res://src/simulation/readonly_state.gd")
var error:=""
var _equipment:={}
var _active:=false
var _elapsed_ms:=0
var _remaining_ms:=0
var _activation:=0
var _audio_serial:=0
var _audio: Array=[]

func configure(bindings: RefCounted,catalogues: RefCounted,equipment_ids: Array) -> bool:
	error=""
	var selected:=Definitions.resolve(bindings,catalogues,equipment_ids)
	if selected.has("error"):return reject(selected.error)
	_equipment=Readonly.freeze(selected);_active=false;_elapsed_ms=0;_remaining_ms=0
	_activation=0;_audio_serial=0;_audio=[]
	return true

func available() -> bool:return not _equipment.is_empty() and _equipment.item_id>=0
func active() -> bool:return _active
func ready() -> bool:return available() and not _active and _remaining_ms==0
func speed_multiplier() -> float:return float(_equipment.speed_multiplier) if _active else 1.0

func advance(milliseconds: Variant) -> bool:
	error=""
	if _equipment.is_empty() or not Definitions.Numbers.integer(milliseconds,0,1000):return reject("Booster requires a configured device and bounded frame time")
	if milliseconds==0:return true
	_audio=[]
	if _active:
		_elapsed_ms+=int(milliseconds)
		if _elapsed_ms>int(_equipment.duration_ms):
			_active=false;_elapsed_ms=0;_remaining_ms=int(_equipment.cooldown_ms)
	elif _remaining_ms>0:
		_remaining_ms=0 if _remaining_ms<int(milliseconds)*3 else maxi(0,_remaining_ms-int(milliseconds))
	return true

## A valid unavailable/blocked press is consumed without changing any state.
func request_start(permitted: Variant=true) -> bool:
	error=""
	if _equipment.is_empty() or not permitted is bool:return reject("Booster input requires its flight permission")
	if not permitted or not ready():return true
	_active=true;_elapsed_ms=0;_activation+=1
	_emit_audio("start")
	return true

func cancel() -> bool:
	error=""
	if _equipment.is_empty():return reject("Configure the booster before cancelling it")
	if not _active:return true
	_active=false;_elapsed_ms=0
	_emit_audio("stop")
	return true

func _emit_audio(action: String) -> void:
	# A late activation and a departure can share one frame. Keep both cues;
	# the presenter consumes only the suffix after its last accepted serial.
	_audio_serial+=1
	_audio.append({"action":action,"source_id":int(_equipment.sound_id)})
	if _audio.size()>2:_audio.pop_front()

## Approaching a mining berth runs the remaining exhaust fade before drilling.
func finish_soon() -> void:
	if _active:_elapsed_ms=maxi(_elapsed_ms,int(_equipment.duration_ms)-int(_equipment.duration_ms)/6)

func envelope() -> float:
	if not _active:return 0.0
	var sixth: int=int(_equipment.duration_ms)/6
	var progress:=float(_elapsed_ms)/float(sixth)
	return clampf(minf(progress,6.0-progress),0.0,1.0)

func snapshot() -> Dictionary:
	if _equipment.is_empty():return {}
	var result:=_equipment.duplicate()
	var charge:=1.0 if not available() else 1.0-float(_remaining_ms)/float(_equipment.cooldown_ms)
	result.merge({"available":available(),"active":_active,"ready":ready(),"elapsed_ms":_elapsed_ms,"remaining_ms":_remaining_ms,"activation":_activation,
		"envelope":envelope(),"motion_multiplier":speed_multiplier(),"charge":charge,"icon_alpha":(55.0 if _active else 55.0+float(int(charge*75.0)) if charge<1.0 else 255.0)/255.0,
		"audio_serial":_audio_serial,"audio":_audio.duplicate(true)})
	return result

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._equipment=_equipment;copy._active=_active;copy._elapsed_ms=_elapsed_ms;copy._remaining_ms=_remaining_ms
	copy._activation=_activation;copy._audio_serial=_audio_serial;copy._audio=_audio.duplicate(true)
	return copy

func reject(message: String) -> bool:error=message;return false
