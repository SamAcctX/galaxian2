extends RefCounted
## In-flight streaks for the add-on medals. Fed every committed flight frame;
## a streak that reaches its threshold latches its row until the next docking,
## where the station career awards it. Not saved, as in the original.
const Elite=preload("res://src/simulation/elite_medal_progress.gd")
const LIBERATOR_ITEM:=179
var _reached:={}
var _mines:=0
var _blind_kills:=0
var _mining_phase:=""
var _kills:=-1

## Docking (and leaving the station) resets the docking-bound streaks.
func reset() -> void:
	_mines=0;_blind_kills=0;_mining_phase="";_kills=-1

func take_reached() -> Array:
	var ids: Array=_reached.keys();ids.sort();_reached={}
	return ids

func reached() -> Array:
	var ids: Array=_reached.keys();ids.sort();return ids

func _latch(id: int) -> void:_reached[id]=true

func observe(state: Dictionary) -> void:
	_observe_mining(state.get("mining_session",{}))
	var encounter: Dictionary=state.get("encounter",{})
	# 40 Blindfolded Killer: player kills while no scanner is fitted.
	var kills: Variant=encounter.get("controller",{}).get("accounting",{}).get("counter_deltas",{}).get("player_kills")
	if kills is int:
		var scanner: Variant=state.get("fast_forward",{}).get("scanner_present")
		if scanner==true:_blind_kills=0
		elif scanner==false and _kills>=0 and kills>_kills:
			_blind_kills+=kills-_kills
			if _blind_kills>=Elite.THRESHOLDS[40]:_latch(40)
		_kills=kills
	else:_kills=-1
	# 42 Jammer: ships disabled by EMP at the same moment.
	var stunned:=0
	for actor in state.get("actors",[]):
		if actor is Dictionary and actor.get("active",false)==true and actor.get("systems_disabled",false)==true:stunned+=1
	if stunned>=Elite.THRESHOLDS[42]:_latch(42)
	# 41 Asteroid Hazard: asteroids broken by one penetrating rocket.
	var secondaries: Dictionary=encounter.get("secondaries",{})
	if int(secondaries.get("max_projectile_scenery_breaks",0))>=Elite.THRESHOLDS[41]:_latch(41)
	# 44 Hot Shot: asteroids destroyed by one Liberator blast.
	for event in encounter.get("secondary_events",[]):
		if not event is Dictionary or event.get("action")!="detonated" or int(event.get("item_id",-1))!=LIBERATOR_ITEM:continue
		var destroyed:=0
		for hit in event.get("normal_hits",[]):
			if hit.get("target",{}).get("group")=="scenery" and hit.get("result",{}).get("destroyed_now",false):destroyed+=1
		if destroyed>=Elite.THRESHOLDS[44]:_latch(44)

## 38 Ore Athlete: completed (extracted) mines in a row; a failed, stopped or
## interrupted mine resets the streak.
func _observe_mining(mining: Dictionary) -> void:
	var phase: String=str(mining.get("phase",""))
	if phase==_mining_phase:return
	if _mining_phase=="drilling":
		if phase=="finished" and mining.get("last_drill",{}).get("phase")=="extracted":
			_mines+=1
			if _mines>=Elite.THRESHOLDS[38]:_latch(38)
		else:_mines=0
	_mining_phase=phase
