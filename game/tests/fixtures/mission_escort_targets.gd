extends RefCounted
## Test-pilot priorities, not native mission conditions or combat permissions.
## Defend the escort when threatened; otherwise intercept living hostiles
## rather than letting a proximity filter turn the whole test into no-fire flight.

static func select_ids(actors: Array) -> Array:
	var fighters: Array=actors.filter(func(actor):return actor.actor_id>0 and actor.get("hostile",false) and actor.get("active",true) and actor.vitals.hull>0)
	var escort: Dictionary={}
	for actor in actors:
		if actor.actor_id==0:escort=actor;break
	if not escort.is_empty():
		var nearby: Array=fighters.filter(func(actor):return actor.position.distance_to(escort.position)<20000.0)
		if not nearby.is_empty():return nearby.map(func(actor):return int(actor.actor_id))
	return fighters.map(func(actor):return int(actor.actor_id))
