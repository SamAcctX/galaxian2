extends RefCounted
## Source conditions 7/18 observe retired actor modes, not hit points or faction.
## This predicate owns neither damage nor mission/career settlement.
const Numbers=preload("res://src/content/opening_definitions.gd")

static func range_status(actors: Variant,first: int,end: int,destroyed_mode: int) -> Dictionary:
	if not actors is Array or first<0 or end<=first or end>actors.size():return {}
	var retired:=0
	for id in range(first,end):
		var actor: Variant=actors[id]
		if not actor is Dictionary or not Numbers.integer(actor.get("actor_mode"),0,5):return {}
		if actor.actor_mode==destroyed_mode:retired+=1
	return {"retired":retired,"required":end-first,"satisfied":retired==end-first}
