extends RefCounted
## Mine family identity and authored presentation. Damage and timing come from
## the imported catalogue; possession and fitting belong to equipment owners.
const CAPACITY:=10
const SPEED:=2.0
const SETTLE_MS:=500
const ATTRACTION_STEP:=200.0
const FALLOFF_DISTANCE:=10000.0

static func declaration(item_id: int) -> Dictionary:
	if item_id not in [60,61,62]:return {}
	return {"kind":11,"model_id":14050+(item_id-60)*2,"attachment_id":14051+(item_id-60)*2,
		"effect_type":7 if item_id==61 else 0,"launch_sound":[1098,1100,1099][item_id-60],"burst_sound":22}
