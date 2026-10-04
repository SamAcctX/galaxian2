extends RefCounted
## Emergency System (Supernova equipment sort 27). When the player's hull
## would reach 0 it leaves 1 hull instead and makes the ship invulnerable for
## the item's duration (attribute 41, 10 s), with sound 1115 for as long as it
## runs. It works once: the item is used up and must be bought again.
## Behaviour notes: local/research/supernova-devices/leads.md.

const SORT:=27
const DURATION_PROPERTY:=41
const SOUND:=1115

var item_id:=-1
var duration_ms:=0
var remaining_ms:=0
## Set when it has fired; the item no longer counts as fitted.
var used:=false

static func find(items: Array,equipment_ids: Array) -> int:
	for id in equipment_ids:
		if not id is int or id<0 or id>=items.size() or not items[id] is Dictionary:continue
		var properties: Variant=items[id].get("properties")
		if properties is Dictionary and int(properties.get(1,-1))==3 and int(properties.get(2,-1))==SORT:return id
	return -1

## The fitted emergency system, or null when none is fitted.
static func create(items: Array,equipment_ids: Array) -> RefCounted:
	var id:=find(items,equipment_ids)
	if id<0:return null
	var duration:=int(items[id].properties.get(DURATION_PROPERTY,0))
	if duration<=0:return null
	var owner: RefCounted=load("res://src/simulation/emergency_system.gd").new()
	owner.item_id=id;owner.duration_ms=duration
	return owner

func active() -> bool:return remaining_ms>0

## Called with the hull after this frame's damage. True when it fires now:
## the caller then sets the hull to 1.
func try_start(hull: int) -> bool:
	if used or active() or hull>=1:return false
	used=true;remaining_ms=duration_ms
	return true

## Counts the invulnerability down; true on the frame it ends.
func advance(delta_ms: int) -> bool:
	if remaining_ms<=0 or delta_ms<=0:return false
	remaining_ms-=delta_ms
	if remaining_ms>0:return false
	remaining_ms=0
	return true

func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy.item_id=item_id;copy.duration_ms=duration_ms;copy.remaining_ms=remaining_ms;copy.used=used
	return copy

func snapshot() -> Dictionary:
	return {"item_id":item_id,"active":active(),"used":used,"remaining_ms":remaining_ms,"duration_ms":duration_ms}
