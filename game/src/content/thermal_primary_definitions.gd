extends RefCounted
## Thermal fitting adds guidance and an original atlas trail to normal contacts.
const DISPERSION := {"steps":20,"draw_scale":0.01,"center_scale":0.005}

static func primary(item_id: int, kind: int) -> Dictionary:
	if kind!=3 or item_id<28 or item_id>30:return {}
	return {"trail_id":25+item_id-28,"camera_facing":true}

static func resolved(weapon: Dictionary) -> bool:
	var row:=primary(int(weapon.get("item_id",-1)),int(weapon.get("kind",-1)))
	return not row.is_empty() and weapon.get("category")==0 and weapon.get("launch_mode")=="ordinary" and weapon.get("projectile_capacity")==20 and weapon.get("thermal")==row and weapon.get("dispersion")==DISPERSION and not weapon.get("nonplayer_source",false)
