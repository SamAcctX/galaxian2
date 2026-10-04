extends RefCounted
## One-time hint windows in flight. Each hint opens once per career as a
## pausing one-button message; the ids seen are saved in progress "hints_seen".
## Order and conditions follow the original's flight hint checks (behaviour
## list in the private flight-hints lead). The first unseen hint whose
## condition holds wins; at most one opens per check.

## Flight must be this old before any hint opens.
const ENTRY_DELAY_MS := 5000
## id, mobile text id (desktop alias comes from the content bindings).
const HINTS := [
	{"id":"booster","text_id":585},
	{"id":"khador_drive","text_id":579},
	{"id":"cloak","text_id":582},
	{"id":"planet_travel","text_id":573},
	{"id":"wingmen","text_id":626},
	{"id":"reputation","text_id":637},
	{"id":"ore_mining","text_id":609},
	{"id":"asteroid_classes","text_id":610},
	{"id":"cargo_full","text_id":625},
	{"id":"hacking","text_id":588},
	{"id":"gamma","text_id":589},
	{"id":"volatile_goods","text_id":591},
	{"id":"docking","text_id":592},
]
## Story beat for the docking/gamma hints: mission 91 at station 110 once its
## fifth radio message (index 4) has finished.
const DOCKING_CURSOR := 91
const DOCKING_STATION := 110
const DOCKING_RADIO_INDEX := 4
## Desktop key labels for the original's #KEY_ tokens (keyboard / controller).
const KEY_LABELS := {"#KEY_DOCK":"F / X","#KEY_ACTION_MENU":"E","#KEY_KHADOR_DRIVE":"K / RB","#KEY_CLOAK":"C",
	"#KEY_BOOST":"W / A","#KEY_AUTOPILOT":"Q / Y","#KEY_WINGMEN":"V","#KEY_FAST_FORWARD":"Tab / Back",
	"#KEY_PRIMARY":"Space / RT","#KEY_SECONDARY":"R / LT","#KEY_SECONDARY_WEAPONS":"G / D-pad right"}

var _pending: Array=[]

static func ids() -> Array:return HINTS.map(func(row):return row.id)

static func valid_seen(value: Variant) -> bool:
	if not value is Array or value.size()>HINTS.size():return false
	var known:=ids()
	for i in value.size():
		if not value[i] is String or not known.has(value[i]) or value.find(value[i])!=i:return false
	return true

## Saved list plus new ids, in table order; [] when either input is invalid.
static func merge_seen(saved: Variant,added: Variant) -> Array:
	if not valid_seen(saved) or not added is Array:return []
	var result: Array=[]
	for id in ids():
		if saved.has(id) or added.has(id):result.append(id)
	return result

## Plain facts read from a flight snapshot (FirstFlightSession state).
static func flight_facts(state: Dictionary,hacking:=false) -> Dictionary:
	var progress: Dictionary=state.get("progress",{}) if state.get("progress") is Dictionary else {}
	var axes: Variant=progress.get("reputation",{}).get("axes",[]) if progress.get("reputation") is Dictionary else []
	var cargo: Dictionary=state.get("cargo",{}) if state.get("cargo") is Dictionary else {}
	var wingmen: Dictionary=state.get("wingman_actors",{}) if state.get("wingman_actors") is Dictionary else {}
	var radio: Dictionary=state.get("radio",{}) if state.get("radio") is Dictionary else {}
	return {"elapsed_ms":int(state.get("world_elapsed_ms",0)),"cursor":int(state.get("campaign_cursor",-1)),
		"station_id":int(state.get("location",{}).get("station_id",-1)),
		"booster":bool(state.get("booster",{}).get("available",false)),
		"khador_drive":bool(state.get("khador",{}).get("available",false)),
		"cloak":not state.get("cloak",{}).is_empty(),
		"autopilot":bool(state.get("station_autopilot",{}).get("active",false)),
		"freelance":int(state.get("contracts",{}).get("active_offer_id",-1))>=0 if state.get("contracts") is Dictionary else false,
		"wingmen":wingmen.get("actors",[]).any(func(actor):return actor is Dictionary and actor.get("active",false)),
		"standing":axes if axes is Array else [],
		"mining":state.get("mining_session",{}).get("phase","")=="drilling" if state.get("mining_session") is Dictionary else false,
		"cargo_full":int(cargo.get("capacity",0))>0 and int(cargo.get("used",0))>=int(cargo.get("capacity",0)),
		"hacking":hacking,"gamma":float(state.get("gamma_rate",0.0))>0.0,"volatile":bool(state.get("volatile",false)),
		"radio_finished":radio.get("finished",[]) if radio.get("finished") is Array else [],
		"saved":progress.get("hints_seen",[]) if valid_seen(progress.get("hints_seen",[])) else []}

static func _docking_beat(facts: Dictionary) -> bool:
	var finished: Array=facts.get("radio_finished",[])
	return int(facts.cursor)==DOCKING_CURSOR and int(facts.station_id)==DOCKING_STATION and finished.size()>DOCKING_RADIO_INDEX and bool(finished[DOCKING_RADIO_INDEX])

static func holds(id: String,facts: Dictionary) -> bool:
	var cursor:=int(facts.get("cursor",-1))
	match id:
		"booster":return facts.booster and cursor>1
		"khador_drive":return facts.khador_drive
		"cloak":return facts.cloak
		"planet_travel":return not facts.autopilot and cursor>9 and not facts.freelance
		"wingmen":return facts.wingmen
		"reputation":return facts.standing.any(func(value):return absi(int(value))>70)
		"ore_mining":return facts.mining
		"asteroid_classes":return facts.mining and cursor>3
		"cargo_full":return facts.cargo_full and cursor>6
		"hacking":return facts.hacking
		"gamma":return _docking_beat(facts) if cursor==DOCKING_CURSOR else facts.gamma
		"volatile_goods":return facts.volatile
		"docking":return _docking_beat(facts)
	return false

## The next hint to open ({id, text_id}) or {}; it is marked seen at once.
func next_hint(facts: Dictionary) -> Dictionary:
	if int(facts.get("elapsed_ms",0))<ENTRY_DELAY_MS:return {}
	var saved: Array=facts.get("saved",[])
	for row in HINTS:
		if saved.has(row.id) or _pending.has(row.id):continue
		if holds(row.id,facts):
			_pending.append(row.id)
			return row.duplicate()
	return {}

## Ids seen since the last bank into the career.
func pending() -> Array:return _pending.duplicate()
func banked() -> void:_pending=[]
func reset() -> void:_pending=[]

## Hint text for the player: the desktop variant with key labels, or the touch text.
static func text(library: RefCounted,bindings: RefCounted,text_id: int,touch: bool) -> String:
	var id: int=text_id if touch else int(bindings.desktop_text_id(text_id))
	if id<0 or id>=library.strings.size():return ""
	var result: String=library.strings[id]
	for token in KEY_LABELS:result=result.replace(token,KEY_LABELS[token])
	return "" if "#KEY_" in result else result
