extends RefCounted
## Retained native prerequisites for the base medal aggregate. A missing
## prerequisite proves the ordinary stock branch without guessing other awards.
const BLUEPRINT_GOLD_COUNT := 13

static func blueprint_counts(state: Dictionary) -> Dictionary:
	if not state.get("entries") is Array:return {}
	var owned:=0;var built:=0
	for row in state.entries:
		owned+=int(row.available)
		built+=int(row.get("completed",0)>0)
	return {"blueprints_owned":owned,"blueprints_constructed":built}

static func valid_counts(counts: Dictionary) -> bool:
	if counts.size()!=2:return false
	for key in ["blueprints_owned","blueprints_constructed"]:
		if not counts.get(key) is int or counts[key]<0 or counts[key]>2147483647:return false
	return counts.blueprints_constructed<=counts.blueprints_owned

static func all_base_gold(cursor: int,counts: Dictionary={}) -> Variant:
	if not counts.is_empty() and not valid_counts(counts):return null
	if cursor<45:return false
	if valid_counts(counts) and (counts.blueprints_owned<BLUEPRINT_GOLD_COUNT or counts.blueprints_constructed<BLUEPRINT_GOLD_COUNT):return false
	# The other retained awards must establish the aggregate in this case.
	return null
