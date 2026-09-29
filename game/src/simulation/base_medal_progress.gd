extends RefCounted
## Cumulative native medal evidence, banked by the station career transaction.
## Unknown is not unearned: unsupported histories cannot grant or deny an award.
const UNKNOWN := -1
const BASE_COUNT := 36
const BLUEPRINT_GOLD_COUNT := 13
const COUNTERS := {
	4:{"path":["progress","player_kills"],"thresholds":[250,100,50],"strict":false},
	5:{"path":["delivery_statistics","cargo"],"thresholds":[200,100,25],"strict":true},
	10:{"path":["progress","debris_destroyed"],"thresholds":[150,100,30],"strict":true},
	13:{"path":["blueprints_owned"],"thresholds":[13,6,3],"strict":false},
	14:{"path":["blueprints_constructed"],"thresholds":[13,6,3],"strict":false},
	16:{"path":["completed_side_missions"],"thresholds":[50,25,5],"strict":true},
	17:{"path":["travel_statistics","jumpgates_used"],"thresholds":[100,50,10],"strict":false},
	18:{"path":["delivery_statistics","passengers"],"thresholds":[50,20,5],"strict":true},
	24:{"path":["progress","cargo_recovered"],"thresholds":[500,200,50],"strict":false},
	26:{"path":["conversations"],"thresholds":[100,50,20],"strict":true},
}

static func _count(value: Variant) -> bool:
	return value is int and value>=0 and value<=2147483647

static func blueprint_counts(state: Dictionary) -> Dictionary:
	if not state.get("entries") is Array:return {}
	var owned:=0;var built:=0
	for row in state.entries:
		if not row is Dictionary or not row.get("available") is bool or not _count(row.get("completed",0)):return {}
		owned+=int(row.available)
		built+=int(row.get("completed",0)>0)
	return {"blueprints_owned":owned,"blueprints_constructed":built}

static func _blueprint_counts_valid(counts: Dictionary) -> bool:
	if counts.size()!=2:return false
	for key in ["blueprints_owned","blueprints_constructed"]:
		if not _count(counts.get(key)):return false
	return counts.blueprints_constructed<=counts.blueprints_owned

static func _tier(value: int,rule: Dictionary) -> int:
	for index in rule.thresholds.size():
		var reached: bool=value>rule.thresholds[index] if rule.strict else value>=rule.thresholds[index]
		if reached:return index+1
	return 0

static func _champion_level(levels: Array) -> int:
	if levels.size()!=BASE_COUNT:return UNKNOWN
	for id in 35:
		if levels[id]==UNKNOWN:return UNKNOWN
		if levels[id]<=0:return 0
	return 1

static func observe(career: Dictionary,blueprints: Dictionary={}) -> Dictionary:
	if not _count(career.get("campaign_cursor")):return {}
	var counts:=blueprint_counts(blueprints)
	if not blueprints.is_empty() and not _blueprint_counts_valid(counts):return {}
	var levels: Array=[];levels.resize(BASE_COUNT);levels.fill(UNKNOWN)
	# The native campaign starts with its original service medal. Completion is
	# independent of every other medal and cannot establish the aggregate alone.
	levels[0]=1;levels[30]=1 if career.campaign_cursor>=45 else 0
	for id in COUNTERS:
		var rule: Dictionary=COUNTERS[id]
		var value: Variant=counts if id in [13,14] else career
		for key in rule.path:
			value=value.get(key) if value is Dictionary else null
		if value==null:continue
		if not _count(value):return {}
		levels[id]=_tier(value,rule)
	levels[35]=_champion_level(levels)
	return {"version":1,"levels":levels}

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=2 or not value.get("version") is int or value.version!=1 or not value.get("levels") is Array or value.levels.size()!=BASE_COUNT:return false
	for id in BASE_COUNT:
		var level: Variant=value.levels[id]
		if not level is int or level<UNKNOWN or level>3:return false
		if id==0:
			if level!=1:return false
		elif id==30:
			if level not in [0,1]:return false
		elif id==35:
			if level not in [UNKNOWN,0,1]:return false
		elif not COUNTERS.has(id) and level!=UNKNOWN:return false
	if value.levels[35]!=_champion_level(value.levels):return false
	return true

static func valid_retained(value: Variant,career: Dictionary,blueprints: Dictionary={}) -> bool:
	if not valid_state(value):return false
	var observed:=observe(career,blueprints)
	if observed.is_empty():return false
	for id in BASE_COUNT:
		var prior: int=value.levels[id];var current: int=observed.levels[id]
		# Every supported predicate is cumulative. A retained award needs at
		# least its original evidence; absent legacy fields do not mean zero.
		if prior!=UNKNOWN and current==UNKNOWN:return false
		if prior>0 and (current<=0 or current>prior):return false
	return true

static func commit(previous: Dictionary,career: Dictionary,blueprints: Dictionary={}) -> Dictionary:
	var observed:=observe(career,blueprints)
	if observed.is_empty():return {}
	if previous.is_empty():return observed
	if not valid_retained(previous,career,blueprints):return {}
	var retained:=previous.duplicate(true)
	for id in BASE_COUNT:
		var level: int=observed.levels[id];var prior: int=retained.levels[id]
		if prior==UNKNOWN or (level>0 and (prior==0 or level<prior)):
			retained.levels[id]=level
	return retained

static func stock_progress(career: Dictionary,blueprints: Dictionary={}) -> Dictionary:
	var counts:=blueprint_counts(blueprints)
	if career.has("base_medals"):counts.retained=career.base_medals.duplicate(true)
	return counts

static func valid_counts(counts: Dictionary) -> bool:
	if not counts.has("retained"):return _blueprint_counts_valid(counts)
	if not valid_state(counts.retained):return false
	var remaining:=counts.duplicate(true);remaining.erase("retained")
	if remaining.is_empty():return true
	if not _blueprint_counts_valid(remaining):return false
	# A stock receipt keeps the native evidence at generation, not a bare flag.
	for id in [13,14]:
		var level: int=counts.retained.levels[id]
		var observed:=_tier(remaining.blueprints_owned if id==13 else remaining.blueprints_constructed,COUNTERS[id])
		if level>0 and (observed==0 or observed>level):return false
	return true

static func all_base_gold(cursor: int,counts: Dictionary={}) -> Variant:
	if not counts.is_empty() and not valid_counts(counts):return null
	if cursor<45:return false
	if counts.has("blueprints_owned") and (counts.blueprints_owned<BLUEPRINT_GOLD_COUNT or counts.blueprints_constructed<BLUEPRINT_GOLD_COUNT):return false
	if not counts.has("retained"):return null
	var unknown:=false
	for level in counts.retained.levels:
		if level==UNKNOWN:unknown=true
		elif level!=1:return false
	return null if unknown else true
