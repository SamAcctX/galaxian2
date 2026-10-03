extends RefCounted
## Installed manual turrets use the hull attachment and ordinary projectiles.
const ROWS={47:{"base_model":6770,"gun_model":6771,"height":60.0,"barrel_spacing":0.0},
	48:{"base_model":6772,"gun_model":6773,"height":55.0,"barrel_spacing":80.0},
	49:{"base_model":6774,"gun_model":6775,"height":60.0,"barrel_spacing":0.0},
	# Expansion automatic turrets aim and fire by themselves outside turret view.
	180:{"base_model":6805,"gun_model":6806,"height":84.0,"barrel_spacing":0.0,"auto":true},
	181:{"base_model":6807,"gun_model":6808,"height":88.0,"barrel_spacing":0.0,"auto":true},
	182:{"base_model":6809,"gun_model":6810,"height":88.0,"barrel_spacing":0.0,"auto":true},
	# Supernova Matador TS: base and barrel each carry a child mesh; its shots
	# alternate 45 left and right of the barrel axis.
	224:{"base_model":18842,"gun_model":18843,"base_child":18844,"gun_child":18845,"height":82.0,"barrel_spacing":45.0}}
## Automatic aim: pick the nearest awake hostile within range every 3 s, lead
## it along its heading, and fire once both turret axes are within tolerance.
const AUTO_RETARGET_MS=3000
const AUTO_RANGE=60000.0
const AUTO_LEAD=1500.0
const AUTO_TOLERANCE=0.05
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
