extends RefCounted
## Explicit detached component inventory, never an earned purchase or save.
## Slot layout and equipment statistics still come from their native owners.
const Equipment=preload("res://src/simulation/station_equipment.gd")
const Categories=preload("res://src/simulation/opening_loadout.gd")
var error:=""

func create(bindings: RefCounted,cat: RefCounted,seed: Dictionary) -> RefCounted:
	error=""
	var equipment:=Equipment.new();var scene_seed:=equipped_seed(bindings,cat,seed)
	if scene_seed.is_empty():error="Cannot build a valid B'akka equipped component loadout";return null
	var capacity:=int(cat.tables.ships[int(scene_seed.ship_id)].stats.cargo_capacity)
	equipment._rules=bindings.station_equipment.duplicate(true);equipment._items={};equipment._completion_prices=[];equipment._catalogue_size=cat.tables.items.size()
	for id in scene_seed.equipment_ids:equipment._items[id]=equipment._item_metadata(cat,int(id),equipment._rules)
	equipment._completion_prices=Equipment.prototype_prices(bindings,cat)
	equipment._recovery_cargo_ids=bindings.mido_travel.tractor_recovery.transfer.special_item_ids.map(func(id):return int(id))
	equipment._state={"loadout":scene_seed,"cargo":{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"ship_id":int(scene_seed.ship_id),"capacity":capacity,"entries":[],"used":0,"free_space":capacity},"cargo_cache_stale":false,"prototype_drill_replaced":true}
	if not equipment.complete_training(equipment.snapshot().cargo):error=equipment.error;return null
	return equipment

static func equipped_seed(bindings: RefCounted,cat: RefCounted,source: Dictionary) -> Dictionary:
	var result:=source.duplicate(true);var counts:=[];var offsets:=[];var used:=[];var total:=0
	for property in Categories.SLOT_PROPERTIES:
		offsets.append(total);var count:=int(cat.tables.ships[int(result.ship_id)].stats[property]);counts.append(count);used.append(0);total+=count
	var slots:=[];slots.resize(total)
	for id in result.equipment_ids:
		if id<0 or id>=cat.tables.items.size():return {}
		var category:=int(cat.tables.items[id].arrays[2][int(bindings.weapon_parameters.item_category_value_index)])
		if category<0 or category>=counts.size() or used[category]>=counts[category]:return {}
		var slot: int=int(used[category]);used[category]+=1
		slots[offsets[category]+slot]={"item_id":id,"category":category,"slot":slot,"quantity":1}
	var ids:=[]
	for slot in slots:
		if slot!=null:ids.append(slot.item_id)
	result.slots=slots;result.equipment_ids=ids
	return result
