extends RefCounted
## Endpoint primaries share normal contacts, with a separate animated beam.
## Supernova's M6 A4 "Raccoon" (228) is the same endpoint beam with its own
## beam model and muzzle flash.
const MODELS := {9:[14229,14500],10:[14230,14503],11:[14231,14502],228:[19090,14501]}
const EMPTY_DISTANCE := 30000
const AIM_DISTANCE := 60000

static func primary(item_id: int, kind: int) -> Dictionary:
	if kind!=0 or not MODELS.has(item_id):return {}
	return {"model_id":MODELS[item_id][0],"muzzle_model_id":MODELS[item_id][1]}

static func resolved(weapon: Dictionary) -> bool:
	var row:=primary(int(weapon.get("item_id",-1)),int(weapon.get("kind",-1)))
	return not row.is_empty() and weapon.get("category")==0 and weapon.get("launch_mode")=="beam" and weapon.get("projectile_capacity")==1 and weapon.get("beam")==row and not weapon.get("nonplayer_source",false)
