extends RefCounted
## Add-on ("elite") medals 36-44: one gold tier each, always listed beside the
## 36 base medals. The career keeps the earned ids in `elite_medals` (absent in
## older saves: none earned). Earning one pays the gold reward and queues the
## same "New medal!" notice as a base medal.
const FIRST := 36
const TOTAL := 45
const GOLD := 1
## Description threshold per row ("#" in the original text).
const THRESHOLDS := {36:3000,37:50,38:10,39:20,40:100,41:3,42:15,43:5,44:8}
## The emergency system (43) does not exist in the remake: shown on Status,
## never awarded.
const UNAVAILABLE := [43]
## Earned-medal frame, unearned frame and the first row icon.
const FRAME_EARNED := 8035
const FRAME_NONE := 8045
const ICON_BASE := 8036

static func is_elite(id: int) -> bool:return id>=FIRST and id<TOTAL

static func icon_id(id: int) -> int:return ICON_BASE+id-FIRST

static func earned(career: Dictionary) -> Array:
	var value: Variant=career.get("elite_medals",[])
	return value if valid_earned(value) else []

static func valid_earned(value: Variant) -> bool:
	if not value is Array or value.size()>TOTAL-FIRST:return false
	var previous:=FIRST-1
	for id in value:
		if not id is int or id<=previous or not is_elite(id) or id in UNAVAILABLE:return false
		previous=id
	return true

## Rows the career itself establishes (saved lifetime counters).
static func career_reached(career: Dictionary) -> Array:
	var reached:=[]
	if int(career.get("progress",{}).get("capital_ship_kills",0))>=THRESHOLDS[39]:reached.append(39)
	# 37: different ships parked at the owned Kaamo Club (one per type).
	var parked: Variant=career.get("progress",{}).get("kaamo_storage",{}).get("ships",[])
	if parked is Array and parked.size()>=THRESHOLDS[37]:reached.append(37)
	return reached

## Checked at docking: the docked ship's cargo capacity (the original reads the
## ship's maximum load, not its free space).
static func dock_reached(cargo_capacity: int) -> Array:
	return [36] if cargo_capacity>THRESHOLDS[36] else []

## Award each newly reached row once: append it, pay the gold reward and queue
## its notice. Returns false for an invalid id list.
static func bank(state: Dictionary,reached: Array,reward: int) -> bool:
	var owned: Array=earned(state)
	if state.has("elite_medals") and not valid_earned(state.elite_medals):return false
	var added:=[]
	for id in reached+career_reached(state):
		if not id is int or not is_elite(id):return false
		if id in UNAVAILABLE or id in owned or id in added:continue
		added.append(id)
	if added.is_empty():return true
	added.sort()
	var notices: Array=state.get("medal_notices",[]).duplicate()
	for id in added:
		notices.append([id,GOLD])
		if state.has("credits"):state.credits=mini(int(state.credits)+reward,2147483647)
	owned=owned+added;owned.sort()
	state.elite_medals=owned;state.medal_notices=notices
	return true
