extends RefCounted
## Thermal fitting adds guidance and an original atlas trail to normal contacts.
const DISPERSION := {"steps":20,"draw_scale":0.01,"center_scale":0.005}
const MATERIAL_ID := 20090
const TEXTURE_ID := 24202

static func primary(item_id: int, kind: int) -> Dictionary:
	if kind!=3 or item_id<28 or item_id>30:return {}
	return {"trail_id":25+item_id-28,"camera_facing":true}

static func resolved(weapon: Dictionary) -> bool:
	var row:=primary(int(weapon.get("item_id",-1)),int(weapon.get("kind",-1)))
	return not row.is_empty() and weapon.get("category")==0 and weapon.get("launch_mode")=="ordinary" and weapon.get("projectile_capacity")==20 and weapon.get("thermal")==row and weapon.get("dispersion")==DISPERSION and not weapon.get("nonplayer_source",false)

static func trail(preset_id: int) -> Dictionary:
	if preset_id<25 or preset_id>27:return {}
	var index:=preset_id-25
	return {"preset_id":preset_id,"material_id":MATERIAL_ID,"capacity":25,
		"lifetime_ms":1000,"section_interval_ms":50,"minimum_squared_distance":6000.0,
		"half_width":50.0*float(index+1),"cap_length":125.0,
		"uv_rect":Vector4(0.001953125 if index==0 else float(index)*0.125,0.875,float(index+1)*0.125,0.625)}
