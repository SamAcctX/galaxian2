extends RefCounted
## Installed manual turrets use the hull attachment and ordinary projectiles.
const ROWS={47:{"base_model":6770,"gun_model":6771,"height":60.0,"barrel_spacing":0.0},
	48:{"base_model":6772,"gun_model":6773,"height":55.0,"barrel_spacing":80.0},
	49:{"base_model":6774,"gun_model":6775,"height":60.0,"barrel_spacing":0.0}}
const CAPACITY=15
const PITCH_SPEED=TAU/4096.0*1000.0
const CAMERA_OFFSET=Vector3(0,200,500)

static func declaration(item_id: int) -> Dictionary:return ROWS.get(item_id,{}).duplicate()

static func resolved(weapon: Dictionary) -> bool:
	return weapon.get("category")==2 and weapon.get("kind")==8 and ROWS.has(weapon.get("item_id")) and weapon.get("manual_turret")==true and weapon.get("launch_mode")=="ordinary" and weapon.get("projectile_capacity")==CAPACITY

static func model(bindings: RefCounted,weapon: Dictionary,impact: bool) -> Dictionary:
	if not resolved(weapon):return {}
	var table: Dictionary=bindings.mido_travel.get("ordinary_fitting",{}).get("primary",{})
	var ids: Array=table.get("impact_model_ids" if impact else "projectile_model_ids",[])
	if weapon.item_id>=ids.size():return {}
	var id:=int(ids[weapon.item_id]);var path: String=bindings.resolve(id,"mesh")
	return {} if path.is_empty() else {"id":id,"resource":path,"captured_up":true}
