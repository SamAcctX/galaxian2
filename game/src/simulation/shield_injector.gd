extends RefCounted
## Shield Injector (Supernova equipment sort 43). When the shield is empty
## and the hold carries the item's amount of Blue Plasma (attribute 59, 30 t)
## it takes that plasma and refills the shield at 0.15 points per ms (at least
## 1 per frame) until full. Sounds: 2258 when it starts, 2257 loops while it
## fills, 2259 when the shield is full. Notes: local/research/supernova-devices/leads.md.

const SORT:=43
const AMOUNT_PROPERTY:=59
const PLASMA_ITEM:=202
const RATE_PER_MS:=0.15
const START_SOUND:=2258
const LOOP_SOUND:=2257
const END_SOUND:=2259

var item_id:=-1
var amount:=0
var filling:=false

static func find(items: Array,equipment_ids: Array) -> int:
	for id in equipment_ids:
		if not id is int or id<0 or id>=items.size() or not items[id] is Dictionary:continue
		var properties: Variant=items[id].get("properties")
		if properties is Dictionary and int(properties.get(1,-1))==3 and int(properties.get(2,-1))==SORT:return id
	return -1

## The fitted injector, or null when none is fitted.
static func create(items: Array,equipment_ids: Array) -> RefCounted:
	var id:=find(items,equipment_ids)
	if id<0:return null
	var units:=int(items[id].properties.get(AMOUNT_PROPERTY,0))
	if units<=0:return null
	var owner: RefCounted=load("res://src/simulation/shield_injector.gd").new()
	owner.item_id=id;owner.amount=units
	return owner

## One frame. `plasma`: Blue Plasma tons in the hold. Returns
## {consume: tons to take from the hold now, shield: the new shield value,
## started, finished}.
func advance(delta_ms: int,shield: float,capacity: float,plasma: int) -> Dictionary:
	var result:={"consume":0,"shield":shield,"started":false,"finished":false}
	# Assumption: a ship without a fitted shield never injects (the original
	# would take plasma every frame for nothing).
	if capacity<=0.0:filling=false;return result
	if not filling and shield<1.0 and plasma>=amount:
		filling=true;result.started=true;result.consume=amount
	if not filling:return result
	if shield<capacity:
		result.shield=minf(capacity,floorf(shield+maxf(1.0,float(maxi(delta_ms,0))*RATE_PER_MS)))
	else:
		filling=false;result.finished=true
	return result

func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy.item_id=item_id;copy.amount=amount;copy.filling=filling
	return copy

func snapshot() -> Dictionary:return {"item_id":item_id,"amount":amount,"filling":filling}
