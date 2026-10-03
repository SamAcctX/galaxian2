extends RefCounted
## Timed kill score with a combo window (recipe "kill_score"; Supernova
## Challenge). Each player kill scores base + bonus x the share of the combo
## window still left, restarts the window, and inside the window raises the
## combo (with its voice line). When the window runs out with a combo above 1,
## the combo bonus unit x combo x (1 + growth x combo) is added. The run ends
## at duration_ms, cashing any running combo.
var error:=""
var _rules:={}
var _state:={}

func configure(rules: Dictionary) -> bool:
	error=""
	for key in ["window_ms","kill_base","kill_bonus","combo_bonus_unit","combo_bonus_growth","voice_base","voice_last_combo","voice_max","duration_ms"]:
		if not rules.has(key):error="Kill score needs %s"%key;return false
	_rules=rules.duplicate(true)
	_state={"score":0,"combo":0,"last_combo":0,"clock_ms":0,"elapsed_ms":0,"kills":0,"finished":false,"last_bonus":0}
	return true

static func combo_bonus(rules: Dictionary,combo: int) -> int:
	return int((float(combo)*float(rules.combo_bonus_growth)+1.0)*float(combo*int(rules.combo_bonus_unit)))

## Advance the run clock. Returns true on the step that finishes the run.
func advance(delta_ms: int) -> bool:
	if _state.is_empty() or _state.finished or delta_ms<=0:return false
	_state.elapsed_ms+=delta_ms
	var ended: bool=int(_state.elapsed_ms)>=int(_rules.duration_ms)
	_state.clock_ms=-1 if ended else int(_state.clock_ms)-delta_ms
	if int(_state.clock_ms)<0:
		if int(_state.combo)>1:
			_state.last_bonus=combo_bonus(_rules,int(_state.combo))
			_state.score+=int(_state.last_bonus);_state.combo=1
		_state.clock_ms=-1
	if ended:_state.finished=true;_state.elapsed_ms=int(_rules.duration_ms)
	return ended

## A player kill. Returns the voice event to play, or -1.
func kill() -> int:
	if _state.is_empty() or _state.finished:return -1
	var share: float=clampf(float(_state.clock_ms)/float(_rules.window_ms),0.0,1.0)
	_state.score+=int(_rules.kill_base)+int(share*float(_rules.kill_bonus))
	_state.kills+=1
	if int(_state.clock_ms)>0:_state.combo+=1
	var voice:=-1
	if int(_state.combo)>0:
		_state.last_combo=int(_state.combo)
		voice=int(_rules.voice_base)+int(_state.combo) if int(_state.combo)<=int(_rules.voice_last_combo) else int(_rules.voice_max)
	_state.clock_ms=int(_rules.window_ms)
	return voice

## HUD readout: score, the combo shown while its window runs, the pending
## combo bonus and the time left.
func readout() -> Dictionary:
	if _state.is_empty():return {}
	var showing: bool=int(_state.clock_ms)>0 and int(_state.last_combo)>1
	return {"kind":"kill_score","score":int(_state.score),"combo":int(_state.last_combo) if showing else 0,
		"combo_clock_ms":maxi(0,int(_state.clock_ms)),"pending_bonus":combo_bonus(_rules,int(_state.last_combo)) if showing else 0,
		"window_ms":int(_rules.window_ms),"remaining_ms":maxi(0,int(_rules.duration_ms)-int(_state.elapsed_ms)),"kills":int(_state.kills),"finished":bool(_state.finished)}

func snapshot() -> Dictionary:return _state.duplicate(true)
func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._rules=_rules;copy._state=_state.duplicate(true)
	return copy
