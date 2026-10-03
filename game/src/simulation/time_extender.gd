extends RefCounted
## Time Extender (equipment sort 26). Ready at launch; a press slows the world
## to 30% for the item's duration, a second press or running out stops it and
## starts the cooldown. Durations count real (unscaled) time.

const SORT:=26
const DURATION_PROPERTY:=42
const COOLDOWN_PROPERTY:=43
const SCALE:=0.3
const PLAYER_SCALE:=0.7
const START_SOUND:=1120
const STOP_SOUND:=1119
const DENIED_SOUND:=124

var item_id:=-1
var duration_ms:=0
var cooldown_ms:=0
var phase:="ready"
var remaining_ms:=0
var _carry:=0.0

static func find(items: Array,equipment_ids: Array) -> int:
	for id in equipment_ids:
		if int(id)<0 or int(id)>=items.size():continue
		var item: Dictionary=items[int(id)]
		if int(item.arrays[2][3])==3 and int(item.arrays[2][5])==SORT:return int(id)
	return -1

func configure(items: Array,equipment_ids: Array) -> bool:
	item_id=find(items,equipment_ids)
	if item_id<0:return false
	var properties: Dictionary=items[item_id].properties
	duration_ms=int(properties.get(DURATION_PROPERTY,0));cooldown_ms=int(properties.get(COOLDOWN_PROPERTY,0))
	phase="ready";remaining_ms=0;_carry=0.0
	return duration_ms>0

## Returns the sound event to play for the press.
func press() -> int:
	match phase:
		"ready":phase="active";remaining_ms=duration_ms;return START_SOUND
		"active":_stop();return STOP_SOUND
	return DENIED_SOUND

## Advances real time; returns STOP_SOUND when it runs out this frame, else -1.
func advance(real_ms: int) -> int:
	if phase=="ready" or real_ms<=0:return -1
	remaining_ms-=real_ms
	if remaining_ms>0:return -1
	if phase=="active":_stop();return STOP_SOUND
	phase="ready";remaining_ms=0
	return -1

## World milliseconds for this frame's real milliseconds.
func scale(real_ms: int) -> int:
	if phase!="active":return real_ms
	_carry+=real_ms*SCALE
	var whole:=floori(_carry);_carry-=whole
	return whole

## Player motion multiplier on top of the scaled world time.
func player_scale() -> float:return PLAYER_SCALE/SCALE if phase=="active" else 1.0

func _stop() -> void:
	phase="cooldown";remaining_ms=cooldown_ms;_carry=0.0

func snapshot() -> Dictionary:
	return {"item_id":item_id,"phase":phase,"remaining_ms":remaining_ms,"ready":phase=="ready","active":phase=="active"}
