extends RefCounted
## Fitted booster declarations. Performance values belong to the item catalogue.
const Numbers=preload("res://src/content/opening_definitions.gd")
const Library=preload("res://src/content/library.gd")
const SOUND_IDS={71:38,72:39,73:40,74:41,195:1102}
const NORMAL_SPEED:=2.0
const ICON_NORMAL:=1202
const ICON_PRESSED:=1203

static func resolve(bindings: RefCounted,catalogues: RefCounted,equipment_ids: Array) -> Dictionary:
	if bindings==null or catalogues==null or not Library.valid_hash(bindings.binding_id) or bindings.base_content_id!=catalogues.content_id:return {"error":"Booster equipment belongs to another content identity"}
	var selected:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"item_id":-1,"sound_id":-1,"duration_ms":0,"cooldown_ms":0,"speed_multiplier":1.0}
	for id in equipment_ids:
		if not Numbers.integer(id,0,catalogues.tables.items.size()-1):return {"error":"Booster selection contains an unknown item"}
		var properties: Dictionary=catalogues.tables.items[int(id)].properties
		if properties.get(1)!=3 or properties.get(2)!=14:continue
		if not SOUND_IDS.has(int(id)):return {"error":"This booster's presentation is unavailable"}
		if not Numbers.integer(properties.get(25),0,1000) or not Numbers.integer(properties.get(26),1,600000) or not Numbers.integer(properties.get(27),6,600000):return {"error":"Invalid booster speed or timing"}
		selected.item_id=int(id);selected.sound_id=SOUND_IDS[int(id)]
		selected.duration_ms=int(properties[27]);selected.cooldown_ms=int(properties[26])
		selected.speed_multiplier=(NORMAL_SPEED+floori(float(properties[25])*2.0/100.0))/NORMAL_SPEED
	return selected
