extends RefCounted
## Medal announcements at docking (original station hints). At most one per
## docking, in this order:
##  - 638 every base medal earned (any tier), once per game run
##  - 639 every base medal gold (Deep Science's Void fighter), once per run
##  - 640 all gold and every add-on medal while the fireworks blueprint (232)
##    is still locked: unlocks it, saved with the station
##  - 3222 after cursor 161 with all gold and add-on medals (the Specter at
##    Katashán), once per run
## Assumption: the hardcore-only route to 3222 is not built (no hardcore mode).

const EliteMedals=preload("res://src/simulation/elite_medal_progress.gd")
const SPEAKER:=16
const ALL_MEDALS_TEXT:=638
const ALL_GOLD_TEXT:=639
const FIREWORKS_TEXT:=640
const FIREWORKS_BLUEPRINT:=232
const SPECTER_TEXT:=3222
const SPECTER_AFTER_CURSOR:=161

## {} or {"text_id", "blueprint"?}; shown holds this run's once-only text ids.
static func next(career: Dictionary,shown: Dictionary) -> Dictionary:
	var cursor:=int(career.get("campaign_cursor",0))
	var levels: Array=career.get("base_medals",{}).get("levels",[])
	var all_medals:=not levels.is_empty() and levels.all(func(level):return int(level) in [1,2,3])
	var all_gold:=all_medals and levels.all(func(level):return int(level)==1)
	var add_ons: bool=EliteMedals.earned(career).size()==EliteMedals.TOTAL-EliteMedals.FIRST
	if all_medals and not shown.has(ALL_MEDALS_TEXT):return {"text_id":ALL_MEDALS_TEXT}
	if all_gold and not shown.has(ALL_GOLD_TEXT):return {"text_id":ALL_GOLD_TEXT}
	if all_gold and add_ons:
		for row in career.get("blueprints",{}).get("entries",[]):
			if int(row.item_id)==FIREWORKS_BLUEPRINT and not row.available:return {"text_id":FIREWORKS_TEXT,"blueprint":FIREWORKS_BLUEPRINT}
		if cursor>SPECTER_AFTER_CURSOR and not shown.has(SPECTER_TEXT):return {"text_id":SPECTER_TEXT}
	return {}
