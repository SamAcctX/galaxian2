extends RefCounted
## Supernova repair beams (equipment sort 37) and transfusion beams (sort 41).
## Every 2.5 s each fitted beam picks up to its beam count of NPCs in range:
## repair heals damaged friendly ships, transfusion drains hostile hull into
## the player's shield while the shield is below full. Behaviour notes:
## local/research/supernova-devices/leads.md.

const REPAIR_SORT:=37
const TRANSFUSION_SORT:=41
const RANGE_PROPERTY:=53
const RATE_PROPERTY:=54
const COUNT_PROPERTY:=55
const RETARGET_MS:=2500
## Per-item looping sound events (original per-item loop table).
const LOOP_SOUNDS:={207:2271,208:2272,222:2267,223:2268}
## Beam meshes: repair, transfusion.
const MODEL_IDS:={REPAIR_SORT:19092,TRANSFUSION_SORT:19093}
const MAX_SLOTS:=8

## One row per fitted beam: item, sort, range, rate, slot target keys and
## per-slot transfusion carry.
var beams:=[]
var elapsed_ms:=0
var _timer_ms:=RETARGET_MS
## Fractional repair per target (the original keeps it on the healed ship).
var _heal_carry:={}

## The first fitted item of each beam sort, or null when none is fitted.
static func create(items: Array,equipment_ids: Array) -> RefCounted:
	var owner: RefCounted=load("res://src/simulation/repair_beams.gd").new()
	for sort in [REPAIR_SORT,TRANSFUSION_SORT]:
		for id in equipment_ids:
			if not id is int or id<0 or id>=items.size() or not items[id] is Dictionary:continue
			var properties: Variant=items[id].get("properties")
			if not properties is Dictionary or int(properties.get(1,-1))!=3 or int(properties.get(2,-1))!=sort:continue
			var count:=clampi(int(properties.get(COUNT_PROPERTY,0)),0,MAX_SLOTS)
			var reach:=int(properties.get(RANGE_PROPERTY,0));var rate:=int(properties.get(RATE_PROPERTY,0))
			if count>0 and reach>0 and rate>0:
				var slots:=[];slots.resize(count)
				var carry:=[];carry.resize(count);carry.fill(0.0)
				owner.beams.append({"item_id":id,"sort":sort,"range":reach,"rate":rate,"model_id":MODEL_IDS[sort],"sound_id":int(LOOP_SOUNDS.get(id,-1)),"slots":slots,"carry":carry,"lines":[]})
			break
	return owner if not owner.beams.is_empty() else null

## `player`: {alive, shield, capacity, shield_fitted}. `candidates`: NPC rows
## {key, position, hull, max_hull, friendly, hostile, cloaked, alive}.
## Returns {heal: {key: points}, drain: {key: points}, shield: amount}.
func advance(delta_ms: int,origin: Vector3,player: Dictionary,candidates: Array) -> Dictionary:
	var effects:={"heal":{},"drain":{},"shield":0.0}
	delta_ms=maxi(delta_ms,0);elapsed_ms+=delta_ms
	if not player.get("alive",false):
		for beam in beams:_clear(beam)
		return effects
	_timer_ms-=delta_ms
	var retarget:=_timer_ms<0
	if retarget:_timer_ms+=RETARGET_MS
	var by_key:={}
	for row in candidates:by_key[row.key]=row
	var shield:=float(player.get("shield",0.0));var capacity:=float(player.get("capacity",0))
	var fitted: bool=player.get("shield_fitted",false) and capacity>0.0
	for beam in beams:
		if retarget:_retarget(beam,origin,fitted and shield<capacity,candidates)
		beam.lines=[]
		for i in beam.slots.size():
			var key: Variant=beam.slots[i]
			if key==null:continue
			var target: Dictionary=by_key.get(key,{})
			# Assumption: a beam lets go of a ship that died or left before the next scan.
			if target.is_empty() or not target.alive:beam.slots[i]=null;continue
			beam.lines.append({"key":key,"from":origin,"to":target.position})
			if beam.sort==REPAIR_SORT:
				var carry: float=float(_heal_carry.get(key,0.0))+float(beam.rate)*float(delta_ms)*0.03/100.0
				if carry>1.0:
					var whole:=int(carry);carry-=whole
					effects.heal[key]=int(effects.heal.get(key,0))+whole
				_heal_carry[key]=carry
			elif fitted and shield<capacity:
				var amount:=float(beam.rate)*float(delta_ms)*0.01/100.0
				beam.carry[i]+=amount
				if beam.carry[i]>=1.0:
					beam.carry[i]-=1.0
					effects.drain[key]=int(effects.drain.get(key,0))+1
				var gained:=minf(amount,capacity-shield)
				shield+=gained;effects.shield+=gained
	return effects

func _retarget(beam: Dictionary,origin: Vector3,drain_allowed: bool,candidates: Array) -> void:
	_clear(beam)
	var hulls:={}
	for row in candidates:
		if not row.alive:continue
		if beam.sort==REPAIR_SORT:
			if not row.friendly or int(row.hull)>=int(row.max_hull):continue
		elif not row.hostile or row.cloaked or not drain_allowed:continue
		if origin.distance_to(row.position)>float(beam.range):continue
		hulls[row.key]=int(row.hull)
		var free: int=beam.slots.find(null)
		if free>=0:beam.slots[free]=row.key;continue
		# Full: replace the slot whose hull is the lowest still above this one.
		var replace:=-1;var lowest:=2147483647
		for i in beam.slots.size():
			var hull: int=hulls[beam.slots[i]]
			if hull>int(row.hull) and hull<lowest:lowest=hull;replace=i
		if replace>=0:beam.slots[replace]=row.key

func _clear(beam: Dictionary) -> void:
	beam.slots.fill(null);beam.carry.fill(0.0);beam.lines=[]

func active() -> bool:
	for beam in beams:
		if not beam.lines.is_empty():return true
	return false

func snapshot() -> Dictionary:
	return {"elapsed_ms":elapsed_ms,"timer_ms":_timer_ms,"beams":beams.map(func(beam):return {"item_id":beam.item_id,"sort":beam.sort,"model_id":beam.model_id,"sound_id":beam.sound_id,"slot_count":beam.slots.size(),"targets":beam.slots.duplicate(),"lines":beam.lines.duplicate(true)})}

func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy.beams=beams.duplicate(true);copy.elapsed_ms=elapsed_ms;copy._timer_ms=_timer_ms;copy._heal_carry=_heal_carry.duplicate()
	return copy

## One flight frame: gathers NPCs from the encounter and wingmen, applies the
## beams' healing and draining to them and the drained charge to the shield.
## Never fails the flight; owners that refuse a change simply keep their state.
static func advance_flight(player: RefCounted,pose: Transform3D,encounter: RefCounted,wingmen: RefCounted,delta_ms: int) -> void:
	if player==null or not player.has_method("beams_owner"):return
	var owner: RefCounted=player.beams_owner()
	if owner==null:return
	var state: Dictionary=player.snapshot()
	var vitals: Dictionary=state.get("vitals",{});var capacities: Dictionary=state.get("capacities",{})
	var facts:={"alive":float(vitals.get("hull",0))>0,"shield":float(vitals.get("shield",0.0)),"capacity":int(capacities.get("shield",0)),"shield_fitted":int(capacities.get("shield_item_id",-1))>=0}
	var rows:=[]
	if encounter!=null and encounter.has_method("beam_bodies"):
		for actor in encounter.beam_bodies():_append(rows,"npc",actor)
	if wingmen!=null and wingmen.has_method("beam_bodies"):
		var bodies: Array=wingmen.beam_bodies()
		for index in bodies.size():_append(rows,"wingman",bodies[index],index)
	var effects: Dictionary=owner.advance(delta_ms,pose.origin,facts,rows)
	var npc_heal:={};var npc_drain:={}
	for key in effects.heal:
		var parts: PackedStringArray=String(key).split(":")
		if parts[0]=="wingman":wingmen.beam_heal(int(parts[1]),int(effects.heal[key]))
		else:npc_heal[int(parts[1])]=int(effects.heal[key])
	for key in effects.drain:npc_drain[int(String(key).split(":")[1])]=int(effects.drain[key])
	if not npc_heal.is_empty() or not npc_drain.is_empty():encounter.apply_beam_effects(npc_heal,npc_drain)
	if effects.shield>0.0:player.add_shield(effects.shield)

static func _append(rows: Array,kind: String,actor: Dictionary,index:=-1) -> void:
	if actor.is_empty() or not actor.has("max_hull") or not actor.get("pose") is Transform3D:return
	if actor.get("contract_debris",false) or actor.get("population_group","")=="debris":return
	var hull:=int(actor.get("vitals",{}).get("hull",0))
	var alive: bool=actor.get("active",false) and hull>0 and int(actor.get("actor_mode",0)) not in [3,4] and not actor.get("hidden",false)
	var id: int=index if kind=="wingman" else int(actor.get("actor_id",-1))
	rows.append({"key":"%s:%d"%[kind,id],"position":actor.get("body_pose",actor.pose).origin,"hull":hull,"max_hull":int(actor.max_hull),
		"friendly":bool(actor.get("friendly",false)),"hostile":bool(actor.get("hostile",false)),"cloaked":bool(actor.get("cloaked",false)),"alive":alive})
