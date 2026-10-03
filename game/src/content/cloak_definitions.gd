extends RefCounted
## Device identity and presentation; timings and energy cost stay in the catalogue.
const Difficulty=preload("res://src/content/difficulty_definitions.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Library=preload("res://src/content/library.gd")
const ENERGY_ITEM:=122
const SOUND_ID:=30
const FADE_MS:=2000
const CLOAK_MAP:="resources/data/assets/main/3d/textures/high/dx5/fx/cloak_map.aei"

## Easy reuses the Normal cooldown (its own value is not recovered).
static func resolve(bindings: RefCounted,catalogues: RefCounted,equipment_ids: Array,ship_id: int,difficulty: Variant) -> Dictionary:
	if bindings==null or catalogues==null or not Library.valid_hash(bindings.binding_id) or bindings.base_content_id!=catalogues.content_id:return {"error":"Cloaking requires matching imported equipment"}
	if not Numbers.integer(ship_id,0,catalogues.tables.ships.size()-1) or not Difficulty.valid(difficulty):return {"error":"Cloaking requires the retained ship and difficulty"}
	var selected:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"item_id":-1,"builtin":ship_id in [44,49],"duration_ms":0,"charge_ms":0,"energy_cost":0,"cooldown_ms":9000 if difficulty==1.0 else 12000 if difficulty==1.5 else 7000}
	for id in equipment_ids:
		if not Numbers.integer(id,0,catalogues.tables.items.size()-1):return {"error":"Cloaking loadout contains an unknown item"}
		var properties: Dictionary=catalogues.tables.items[int(id)].properties
		if selected.item_id<0 and properties.get(1)==3 and properties.get(2)==21:selected.item_id=int(id)
	if selected.builtin:selected.item_id=95
	if selected.item_id<0:return selected
	if selected.item_id not in [94,95,96]:return {"error":"This cloaking device is unavailable"}
	var properties: Dictionary=catalogues.tables.items[selected.item_id].properties
	if not Numbers.integer(properties.get(35),FADE_MS*2,600000) or not Numbers.integer(properties.get(36),1,600000) or not Numbers.integer(properties.get(38),1,1000):return {"error":"Cloaking equipment has invalid timing or energy requirements"}
	selected.duration_ms=int(properties[35]);selected.charge_ms=int(properties[36]);selected.energy_cost=int(properties[38])
	return selected
