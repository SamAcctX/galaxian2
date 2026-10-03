extends RefCounted
## Original mesh ribbons; texture rectangles are in source mesh coordinates.
const MATERIAL_ID:=20090
const TEXTURE_ID:=24202
const VALKYRIE_MATERIAL_ID:=24096
const VALKYRIE_TEXTURE_ID:=24095

static func trail(preset_id: int) -> Dictionary:
	if preset_id==39:
		return {"preset_id":39,"material_id":MATERIAL_ID,"capacity":29,
			"lifetime_ms":3000,"section_interval_ms":125,"minimum_squared_distance":6000.0,
			"half_width":100.0,"cap_length":125.0,"tail_visibility_ms":2000,"progressive_uv":true,
			"uv_rect":Vector4(0.751953125,0.498046875,0.998046875,0.001953125)}
	# The Valkyrie thermal ribbon (SunFire o50) uses the thermal shape with a
	# 70-unit half-width, drawn from the Valkyrie projectile atlas.
	if preset_id==28:
		return {"preset_id":28,"material_id":VALKYRIE_MATERIAL_ID,"capacity":25,
			"lifetime_ms":1000,"section_interval_ms":50,"minimum_squared_distance":6000.0,
			"half_width":70.0,"cap_length":125.0,
			"uv_rect":Vector4(0.75,0.5,0.87109375,0.0)}
	if preset_id<25 or preset_id>27:return {}
	var index:=preset_id-25
	return {"preset_id":preset_id,"material_id":MATERIAL_ID,"capacity":25,
		"lifetime_ms":1000,"section_interval_ms":50,"minimum_squared_distance":6000.0,
		"half_width":50.0*float(index+1),"cap_length":125.0,
		"uv_rect":Vector4(0.001953125 if index==0 else float(index)*0.125,0.875,float(index+1)*0.125,0.625)}
