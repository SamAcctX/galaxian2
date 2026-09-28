extends RefCounted
## Deployed mines share one launcher capacity and contact pass. The outer weapon
## owner commits returned ammunition and radial hits with the rest of the frame.
const Definitions=preload("res://src/content/mine_definitions.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Bomb=preload("res://src/simulation/emp_bombs.gd")
const Blast=preload("res://src/simulation/area_weapon_blast.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Geometry=preload("res://src/simulation/ordinary_hit_geometry.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
var error:=""
var _weapon:={}
var _slots:=[]
var _elapsed_ms:=0
var _next_id:=1
var _random: RefCounted

func configure(bindings: RefCounted,cat: RefCounted,item_id: Variant,equipment_ids: Array,muzzle_offset:=Vector3.ZERO,seed_value: int=0) -> bool:
	error=""
	if not item_id is int or not muzzle_offset.is_finite():return reject("Invalid mine launcher or muzzle")
	var declaration:=Definitions.declaration(item_id)
	if declaration.is_empty():return reject("This item is not a supported mine")
	var resolver:=Weapons.new()
	if bindings==null or not resolver.configure(bindings,cat,bindings.base_content_id):return reject(resolver.error)
	var weapon:=resolver.resolve(item_id,equipment_ids)
	if weapon.get("launch_mode")!="mine":return reject("The mine has no supported catalogue configuration")
	var properties: Dictionary=cat.tables.items[item_id].properties
	var damage: Variant=properties.get(10,0)
	var radius: Variant=properties.get(14)
	if not Vitals.integer(damage) or not Vitals.integer(radius) or radius<1:return reject("The mine lacks supported systems damage or blast radius")
	weapon.system_damage=damage;weapon.radius=radius;weapon.muzzle_offset=muzzle_offset;weapon.model_id=declaration.model_id
	var random:=Random.new()
	if not random.seed_from(seed_value):return reject(random.error)
	_weapon=weapon;_random=random;_slots=[];_slots.resize(Definitions.CAPACITY)
	_elapsed_ms=weapon.interval_ms;_next_id=1
	return true

func trigger_action(ammunition: int,permitted:=true) -> String:
	if not permitted or _weapon.is_empty() or ammunition<=0 or _elapsed_ms<=_weapon.interval_ms:return "none"
	return "launched" if _available_slot()>=0 else "none"

func trigger(pose: Transform3D,ammunition: Variant,permitted: Variant=true) -> Dictionary:
	error=""
	if _weapon.is_empty() or not Vitals.integer(ammunition) or not permitted is bool or not pose.is_finite():return fail("Invalid mine launch context")
	var result:=_event()
	if trigger_action(ammunition,permitted)=="none":return result
	if _next_id>=Vitals.MAX_INTEGER:return fail("The mine projectile handle limit was reached")
	var direction:=Vectors.normalized(Vectors.added(pose.basis.z,pose.basis.y))
	var position:=pose*Vector3(_weapon.muzzle_offset)
	var velocity:=Vectors.scaled(direction,Definitions.SPEED)
	if direction==Vector3.ZERO or not position.is_finite() or not velocity.is_finite():return fail("Mine launch exceeds finite world coordinates")
	var angles:=Vector3.ZERO
	for axis in 3:angles[axis]=float(_random.next_int(200)-100)/50.0
	var shot:={"id":_next_id,"slot":_available_slot(),"phase":"flying","position":position,"previous_position":position,
		"velocity":velocity,"remaining_ms":_weapon.lifetime_ms,"angles":angles}
	_slots[shot.slot]=shot;_next_id+=1;_elapsed_ms=0
	result.action="launched";result.ammunition_consumed=1;result.shot=shot.duplicate(true)
	return result

func advance(delta_ms: Variant,targets: Variant) -> Dictionary:
	error=""
	if _weapon.is_empty() or not Vitals.integer(delta_ms) or _elapsed_ms>Vitals.MAX_INTEGER-delta_ms or not _valid_targets(targets):return fail("Invalid mine frame or target geometry")
	var slots: Array=_slots.duplicate(true)
	for index in slots.size():
		if slots[index]!=null and slots[index].phase=="detonated":slots[index]=null
	var result:=_event()
	var contact:=_contact(slots,targets)
	if contact.is_empty():return {}
	result.attraction=contact.get("attraction",{})
	if contact.detonate:
		var operation:=Blast.new()
		for shot in slots:
			if shot==null:continue
			var blast:=operation.evaluate(_weapon,shot,targets)
			if blast.is_empty():return fail(operation.error)
			if blast.hits.is_empty():continue
			shot.phase="detonated";shot.remaining_ms=-1
			blast.slot=shot.slot;result.blasts.append(blast)
		if not result.blasts.is_empty():result.action="detonated"
	for index in slots.size():
		var shot: Variant=slots[index]
		if shot==null or shot.phase!="flying":continue
		shot.previous_position=_slots[index].position
		shot.remaining_ms-=delta_ms
		var age: int=_weapon.lifetime_ms-shot.remaining_ms
		var fraction:=maxf(0.0,1.0-float(age)/Definitions.SETTLE_MS)
		shot.position=Vectors.added(shot.position,Vectors.scaled(shot.velocity,float(delta_ms)*fraction))
		if not shot.position.is_finite():return fail("Mine motion exceeds finite world coordinates")
		for axis in 3:shot.angles[axis]+=(1.0 if shot.angles[axis]>=0.0 else -1.0)*float(delta_ms)*0.0005
		if shot.remaining_ms<=0:slots[index]=null
	_slots=slots;_elapsed_ms+=delta_ms
	return result

## The complete target order and retained slot order decide the one contact
## action. Attraction is a discrete contact response, separate from free drift.
func _contact(slots: Array,targets: Array) -> Dictionary:
	var geometry:=Geometry.new()
	for target in targets:
		if not target.active or not target.mine_sensitive or not target.collision.eligible:continue
		var shape: Dictionary=target.collision
		for shot in slots:
			if shot==null:continue
			var broad: Dictionary=geometry.box_geometry(shot.position,shape.center,shape.boxes) if shape.path=="point_geometry" else geometry.bounds(shot.position,shot.velocity,shape.center,shape.half_extent*5)
			if broad.is_empty():return fail(geometry.error)
			if not broad.hit:continue
			var touch:=geometry.bounds(shot.position,shot.velocity,shape.center,shape.half_extent)
			if touch.is_empty():return fail(geometry.error)
			if touch.hit:return {"detonate":true}
			var direction:=Vectors.normalized(target.position-shot.position)
			var position:=Vectors.added(shot.position,Vectors.scaled(direction,Definitions.ATTRACTION_STEP))
			if direction==Vector3.ZERO or not position.is_finite():return fail("Mine attraction exceeds finite world coordinates")
			shot.velocity=direction;shot.position=position
			return {"detonate":false,"attraction":{"projectile_id":shot.id,"actor_id":target.actor_id}}
	return {"detonate":false}

static func _valid_targets(targets: Variant) -> bool:
	if not Bomb._valid_targets(targets):return false
	var geometry:=Geometry.new()
	for target in targets:
		if not target.get("mine_sensitive") is bool:return false
		if not target.mine_sensitive:continue
		var shape: Variant=target.get("collision")
		if not shape is Dictionary or not shape.get("eligible") is bool or not Vitals.integer(shape.get("half_extent")) or shape.half_extent>Vitals.MAX_INTEGER/5:return false
		if geometry.bounds(Vector3.ZERO,Vector3.ZERO,shape.get("center"),shape.half_extent).is_empty():return false
		if shape.get("path")=="point_geometry":
			if geometry.box_geometry(Vector3.ZERO,shape.center,shape.get("boxes")).is_empty():return false
		elif shape.get("path")!="bounds":return false
	return true

func _available_slot() -> int:
	for index in _slots.size():
		if _slots[index]==null or _slots[index].phase=="detonated":return index
	return -1

func discard_flying() -> void:
	for index in _slots.size():
		if _slots[index]!=null and _slots[index].phase=="flying":_slots[index]=null

static func _event() -> Dictionary:return {"action":"none","ammunition_consumed":0,"shot":{},"blasts":[],"attraction":{}}

func snapshot() -> Dictionary:
	return {"weapon":_weapon.duplicate(true),"slots":_slots.duplicate(true),"elapsed_ms":_elapsed_ms,"random_state":_random.snapshot() if _random!=null else {}}

func fork() -> RefCounted:
	var next: RefCounted=get_script().new()
	next._weapon=_weapon.duplicate(true);next._slots=_slots.duplicate(true);next._elapsed_ms=_elapsed_ms;next._next_id=_next_id
	next._random=_random.fork() if _random!=null else null
	return next

func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:error=message;return {}
