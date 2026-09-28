extends RefCounted
## Own one area bomb's motion and emit detached blast results. The flight owner
## supplies collision candidates and commits ammunition and target damage.
## This component does not select targets, alter inventory or complete missions.
const Definitions=preload("res://src/content/emp_bombs_definitions.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Geometry=preload("res://src/simulation/ordinary_hit_geometry.gd")
const Visuals=preload("res://src/content/bomb_projectile_resources.gd")
const Playback=preload("res://src/simulation/model_playback.gd")
var error:=""
var _weapon:={}
var _shot:={}
var _elapsed_ms:=0
var _next_id:=1
var _visuals:={}

func configure(bindings: RefCounted,cat: RefCounted,item_id: Variant,equipment_ids: Array,muzzle_offset:=Vector3(0,0,400)) -> bool:
	error=""
	if not Definitions.available(bindings) or cat==null or cat.content_id!=bindings.base_content_id or not item_id is int or not muzzle_offset.is_finite():return reject("This content has no supported area bomb")
	var declaration:=Definitions.declaration(item_id)
	if declaration.is_empty():return reject("This item has no supported area-bomb declaration")
	var resolver:=Weapons.new()
	if not resolver.configure(bindings,cat,bindings.base_content_id):return reject(resolver.error)
	var weapon:=resolver.resolve(item_id,equipment_ids)
	if weapon.is_empty() or weapon.category!=int(Definitions.VALUES.category) or weapon.kind!=declaration.kind:return reject("The equipped item is not an area bomb")
	var properties: Dictionary=cat.tables.items[item_id].properties
	var damage: Variant=properties.get(int(Definitions.VALUES.system_damage_property),0)
	var radius: Variant=properties.get(int(Definitions.VALUES.blast_radius_property))
	if not Vitals.integer(damage) or not Vitals.integer(radius) or radius<1:return reject("The bomb lacks its damage or blast radius")
	weapon.system_damage=damage;weapon.radius=radius;weapon.launch_mode="emp_bomb" if weapon.kind==6 else "antimatter_bomb"
	weapon.model_id=declaration.model_id;weapon.muzzle_offset=muzzle_offset
	_weapon=weapon;_shot={};_elapsed_ms=weapon.interval_ms;_visuals={}
	return true

func prepare_visuals(library: RefCounted,bindings: RefCounted) -> bool:
	if _weapon.is_empty() or not _shot.is_empty() or not _visuals.is_empty():return reject("Prepare bomb models once before the first launch")
	var prepared:=Visuals.prepare(library,bindings,_weapon)
	if prepared.is_empty():return reject("The bomb's original animated models are unavailable")
	_visuals=prepared
	return true

func discard_flying() -> void:
	_shot={}

func trigger(pose: Transform3D,ammunition: Variant,targets: Variant,permitted: Variant=true) -> Dictionary:
	error=""
	if _weapon.is_empty():return fail("Configure the EMP bomb before firing")
	if not Vitals.integer(ammunition) or not permitted is bool or not pose.origin.is_finite() or not pose.basis.is_finite() or not _valid_targets(targets):return fail("Invalid EMP firing context")
	var result:=_event()
	var action:=trigger_action(ammunition,permitted)
	if action=="none":return result
	if action=="detonated":return detonate(_shot.id,targets)
	if _next_id>=Vitals.MAX_INTEGER:return fail("The EMP projectile handle limit was reached")
	var position:=pose*Vector3(_weapon.muzzle_offset)
	var direction:=Vectors.normalized(pose.basis.z)
	var velocity:=Vectors.scaled(direction,_weapon.speed_units_per_millisecond)
	if not position.is_finite() or not velocity.is_finite() or direction==Vector3.ZERO:return fail("EMP launch exceeds finite world coordinates")
	_shot={"id":_next_id,"phase":"flying","position":position,"previous_position":position,"velocity":velocity,"remaining_ms":_weapon.lifetime_ms}
	_next_id+=1;_elapsed_ms=0
	result.action="launched";result.ammunition_consumed=int(Definitions.VALUES.ammunition_per_launch);result.shot=_shot.duplicate(true)
	return result

## Read-only readiness shared with the control display. A live last round is
## still detonatable; readiness never advances clocks or consumes ammunition.
func trigger_action(ammunition: int,permitted:=true) -> String:
	if not permitted or _weapon.is_empty():return "none"
	if _shot.get("phase")=="flying":return "detonated"
	if ammunition<=0 or _elapsed_ms<=_weapon.interval_ms:return "none"
	return "launched"

func advance(delta_ms: Variant,targets: Variant) -> Dictionary:
	error=""
	if _weapon.is_empty() or not Vitals.integer(delta_ms) or _elapsed_ms>Vitals.MAX_INTEGER-delta_ms or not _valid_targets(targets):return fail("Invalid EMP frame or collision candidates")
	var result:=_event();var next: Dictionary=_shot.duplicate(true)
	if next.get("phase")=="detonated":next={}
	elif not next.is_empty():
		var contact:=contact_target(next,targets)
		if contact.has("error"):return fail(contact.error)
		if contact.get("hit",false):
			var blast:=_blast(next,targets)
			if blast.is_empty():return {}
			next.phase="detonated";next.remaining_ms=int(Definitions.VALUES.detonated_lifetime)
			result.action="detonated";result.blast=blast
			_advance_visuals(delta_ms)
			_shot=next;_elapsed_ms+=delta_ms
			return result
		var position:=Vectors.added(next.position,Vectors.scaled(next.velocity,Vitals.single(float(delta_ms))))
		if not position.is_finite():return fail("EMP motion exceeds finite world coordinates")
		next.previous_position=next.position;next.position=position;next.remaining_ms-=delta_ms
		if next.remaining_ms<=0:
			var blast:=_blast(next,targets)
			if blast.is_empty():return {}
			next.phase="detonated";next.remaining_ms=int(Definitions.VALUES.detonated_lifetime)
			result.action="detonated";result.blast=blast
	_advance_visuals(delta_ms)
	_shot=next;_elapsed_ms+=delta_ms
	return result

func _advance_visuals(delta_ms: int) -> void:
	if _shot.is_empty() or _visuals.is_empty():return
	for model in _visuals.models:Playback.advance([model],delta_ms,model.loop)

func detonate(projectile_id: Variant,targets: Variant) -> Dictionary:
	error=""
	if _weapon.is_empty() or not projectile_id is int or _shot.get("id")!=projectile_id or _shot.get("phase")!="flying" or not _valid_targets(targets):return fail("EMP detonation requires a live projectile and current targets")
	var blast:=_blast(_shot,targets)
	if blast.is_empty():return {}
	_shot.phase="detonated";_shot.remaining_ms=int(Definitions.VALUES.detonated_lifetime)
	var result:=_event();result.action="detonated";result.blast=blast
	return result

func _blast(shot: Dictionary,targets: Array) -> Dictionary:
	var hits:=[]
	for target in targets:
		if not target.active or (_weapon.kind==6 and target.emp_immune):continue
		var difference: Vector3=target.position-shot.position
		var distance:=Vitals.single(sqrt(Vectors.dot(difference,difference)))
		if not is_finite(distance) or distance>Vitals.MAX_SHIELD:return fail("EMP target distance exceeds supported coordinates")
		var whole:=int(distance)
		if whole>=_weapon.radius:continue
		var fraction:=Vitals.single(Vitals.single(float(_weapon.radius-whole))/Vitals.single(float(_weapon.radius)))
		var amount:=fraction
		if _weapon.kind==7 and target.emp_immune:amount=Vitals.single(amount*Vitals.single(0.6))
		var hit:={"actor_id":target.actor_id,"system_damage":int(Vitals.single(float(_weapon.system_damage)*amount)),"distance":whole}
		if target.has("target"):hit.target=target.target.duplicate()
		if _weapon.kind==7:
			hit.normal_damage=int(Vitals.single(float(_weapon.damage)*amount))
			hit.impact_vector=Vectors.normalized(difference);hit.motion_scalar=fraction
		hits.append(hit)
	return {"base_content_id":_weapon.base_content_id,"binding_id":_weapon.binding_id,
		"projectile_id":shot.id,"item_id":_weapon.item_id,"position":shot.position,"hits":hits}

## Collision candidates are sampled before movement. A first physical contact
## produces one radial pulse; the same bomb cannot hit overlapping bodies twice.
static func contact_target(shot: Dictionary,targets: Array) -> Dictionary:
	var geometry:=Geometry.new()
	for target in targets:
		var shape: Dictionary=target.get("collision",{})
		if not target.active or not shape.get("eligible",false):continue
		var result: Dictionary
		if shape.get("path")=="point_geometry":result=geometry.box_geometry(shot.position,shape.center,shape.get("boxes"))
		elif shape.get("path")=="bounds":result=geometry.bounds(shot.position,shot.velocity,shape.center,shape.get("half_extent"))
		else:return {"error":"The bomb target has an unsupported collision provider"}
		if result.is_empty():return {"error":geometry.error}
		if result.hit:return {"hit":true,"actor_id":target.actor_id}
	return {"hit":false}

## Own-ship consequences use the effect wrapper's cached position. Its caller
## applies damage through the player owner only at the hardest difficulty.
static func self_hit(weapon: Dictionary,position: Vector3,observer: Vector3) -> Dictionary:
	if not Vitals.integer(weapon.get("damage")) or not Vitals.integer(weapon.get("radius")) or weapon.radius<1 or not position.is_finite() or not observer.is_finite():return {}
	var difference:=position-observer
	var distance:=Vitals.single(sqrt(Vectors.dot(difference,difference)))
	if not is_finite(distance):return {}
	var reach:=Vitals.single(float(weapon.radius)*0.5)
	var fraction:=clampf(Vitals.single(Vitals.single(Vitals.single(reach-distance)/reach)*0.5),0.0,1.0)
	return {"damage":int(Vitals.single(float(weapon.damage)*fraction)),"feedback":Vitals.single(fraction*3.0)}

static func _valid_targets(targets: Variant) -> bool:
	if not targets is Array or targets.size()>4096:return false
	var ids:={}
	for target in targets:
		if not target is Dictionary or not Vitals.integer(target.get("actor_id")) or ids.has(target.actor_id):return false
		if not target.get("position") is Vector3 or not target.position.is_finite() or not target.get("active") is bool or not target.get("emp_immune") is bool:return false
		if target.has("collision") and not target.collision is Dictionary:return false
		if target.has("target") and (not target.target is Dictionary or target.target.get("group") not in ["npc","scenery"] or not Vitals.integer(target.target.get("index"))):return false
		ids[target.actor_id]=true
	return true

static func _event() -> Dictionary:return {"action":"none","ammunition_consumed":0,"shot":{},"blast":{}}

func snapshot() -> Dictionary:
	return {"weapon":_weapon.duplicate(true),"shot":_shot.duplicate(true),"elapsed_ms":_elapsed_ms,"visuals":_visuals.duplicate(true)}

func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._weapon=_weapon.duplicate(true);copy._shot=_shot.duplicate(true);copy._elapsed_ms=_elapsed_ms;copy._next_id=_next_id
	copy._visuals=_visuals.duplicate(true)
	return copy

func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
