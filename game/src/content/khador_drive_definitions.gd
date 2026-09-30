extends RefCounted
## Authored device data and visible travel presentation. Fuel quantities and
## charge duration come from the player's imported catalogue.
const Numbers=preload("res://src/content/opening_definitions.gd")
const ITEM_ID:=85
const ENERGY_ITEM:=122
const MODEL_ID:=15026
const CHARGE_SOUND:=33
const DEPARTURE_SOUND:=32
const DEPARTURE_MS:=4000
const HIDE_PLAYER_MS:=1700
## Cronus, Typhon and Nemesis carry the drive built in (Valkyrie ships).
const INTEGRATED_SHIPS:=[37,38,40]

static func fitted(loadout: Dictionary) -> bool:
	return loadout.get("equipment_ids",[]).has(ITEM_ID) or int(loadout.get("ship_id",-1)) in INTEGRATED_SHIPS

static func resolve(bindings: RefCounted,cat: RefCounted,loadout: Dictionary,difficulty: float) -> Dictionary:
	if bindings==null or cat==null or cat.content_id!=bindings.base_content_id or difficulty not in [0.5,1.0,1.5]:return {"error":"Khador Drive requires imported equipment and the retained difficulty"}
	for key in ["base_content_id","binding_id"]:
		if loadout.get(key)!=bindings.get(key):return {"error":"Khador Drive belongs to another inventory"}
	if not loadout.get("equipment_ids") is Array or cat.tables.items.size()<=ITEM_ID:return {"error":"Khador Drive requires the equipped item catalogue"}
	var item: Dictionary=cat.tables.items[ITEM_ID].properties
	if item.get(1)!=3 or item.get(2)!=18 or not Numbers.integer(item.get(37),1,600000) or not Numbers.integer(item.get(38),1,1000):return {"error":"Khador Drive has invalid charge or fuel requirements"}
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"item_id":ITEM_ID,
		"available":fitted(loadout),"charge_ms":int(item[37]),
		"fuel_multiplier":2 if difficulty==1.5 else 1,"void_fuel":int(item[38])*(2 if difficulty==1.5 else 1)}
