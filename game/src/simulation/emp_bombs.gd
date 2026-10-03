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
const Blast=preload("res://src/simulation/area_weapon_blast.gd")
var error:=""
var _weapon:={}
var _shot:={}
var _elapsed_ms:=0
var _next_id:=1
var _visuals:={}
var _steer:=Vector2.ZERO

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
	# Shock Blast: one pulse centred on the ship on the next update (its
	# original flight lasts 1 ms and never moves).
	if weapon.kind==int(Definitions.SHOCK.kind):weapon.launch_mode="shock_blast";weapon.lifetime_ms=1;weapon.muzzle_offset=Vector3.ZERO
	if properties.get(int(Definitions.GUIDED.guided_property))==1:weapon.guided=true
	_weapon=weapon;_shot={};_elapsed_ms=weapon.interval_ms;_visuals={};_steer=Vector2.ZERO
	return true

func prepare_visuals(library: RefCounted,bindings: RefCounted) -> bool:
	if _weapon.is_empty() or not _shot.is_empty() or not _visuals.is_empty():return reject("Prepare bomb models once before the first launch")
	var prepared:=Visuals.prepare(library,bindings,_weapon)
	if prepared.is_empty():return reject("The bomb's original animated models are unavailable")
	_visuals=prepared
	return true

func discard_flying() -> void:
	_shot={};_steer=Vector2.ZERO

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
	var velocity:=Vectors.scaled(direction,float(_weapon.speed_units_per_millisecond))
	if not position.is_finite() or not velocity.is_finite() or direction==Vector3.ZERO:return fail("EMP launch exceeds finite world coordinates")
	_shot={"id":_next_id,"phase":"flying","position":position,"previous_position":position,"velocity":velocity,"remaining_ms":_weapon.lifetime_ms}
	if _weapon.get("guided",false):_shot.basis=pose.basis.orthonormalized();_shot.bank=0.0;_steer=Vector2.ZERO
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
		var passes: bool=_weapon.kind==int(Definitions.ION_LAMBDA.kind)
		var contact:={"hit":false} if _weapon.launch_mode=="shock_blast" else contact_target(next,targets,passes)
		if contact.has("error"):return fail(contact.error)
		# Ion Lambda breaks each asteroid it touches and flies on.
		var struck: Array=_struck_hits(next,contact.get("passed",[]))
		if not struck.is_empty():result.blast={"base_content_id":_weapon.base_content_id,"binding_id":_weapon.binding_id,"projectile_id":next.id,"item_id":_weapon.item_id,"position":next.position,"hits":struck}
		if contact.get("hit",false):
			var blast:=_blast(next,targets)
			if blast.is_empty():return {}
			blast.hits=struck+blast.hits
			next.phase="detonated";next.remaining_ms=int(Definitions.VALUES.detonated_lifetime)
			result.action="detonated";result.blast=blast
			_advance_visuals(delta_ms)
			_shot=next;_elapsed_ms+=delta_ms
			return result
		if next.has("basis"):_steer_shot(next,delta_ms)
		var position:=Vectors.added(next.position,Vectors.scaled(next.velocity,Vitals.single(float(delta_ms))))
		if not position.is_finite():return fail("EMP motion exceeds finite world coordinates")
		next.previous_position=next.position;next.position=position;next.remaining_ms-=delta_ms
		if next.remaining_ms<=0:
			var blast:=_blast(next,targets)
			if blast.is_empty():return {}
			blast.hits=struck+blast.hits
			next.phase="detonated";next.remaining_ms=int(Definitions.VALUES.detonated_lifetime)
			result.action="detonated";result.blast=blast
	_advance_visuals(delta_ms)
	_shot=next;_elapsed_ms+=delta_ms
	return result

## Player guidance: pitch (x) and yaw (y) turn the missile like the ship's own
## stick, at stick x turn factor x speed radians per 60 Hz frame. Speed is kept.
func _steer_shot(shot: Dictionary,delta_ms: int) -> void:
	var rate: float=float(Definitions.GUIDED.turn_factor)*float(_weapon.speed_units_per_millisecond)*float(delta_ms)/float(Definitions.GUIDED.turn_frame_ms)
	var angles:=_steer*rate
	var basis: Basis=(shot.basis*Basis(Vector3.RIGHT,angles.x)*Basis(Vector3.UP,angles.y)).orthonormalized()
	shot.basis=basis;shot.bank=_steer.y
	shot.velocity=Vectors.scaled(Vectors.normalized(basis.z),_weapon.speed_units_per_millisecond)

func guided_live() -> bool:return _weapon.get("guided",false) and _shot.get("phase")=="flying"

## Stick input for the live guided missile; ignored when nothing is guided.
func set_steering(command: Vector2) -> bool:
	if not command.is_finite():return reject("Invalid missile steering")
	_steer=command.clamp(Vector2(-1,-1),Vector2.ONE) if guided_live() else Vector2.ZERO
	return true

## Chase view behind and above the missile, looking ahead with world up.
## Camera convention: basis.z points back from the view direction.
func guided_camera_pose() -> Transform3D:
	if not guided_live():return Transform3D()
	var basis: Basis=_shot.basis
	var eye: Vector3=_shot.position+basis*Vector3(Definitions.GUIDED.camera_offset[0],Definitions.GUIDED.camera_offset[1],Definitions.GUIDED.camera_offset[2])
	var look: Vector3=_shot.position+basis*Vector3(Definitions.GUIDED.camera_target[0],Definitions.GUIDED.camera_target[1],Definitions.GUIDED.camera_target[2])
	var direction:=(look-eye).normalized()
	var up:=Vector3.UP if absf(direction.dot(Vector3.UP))<0.999 else basis.y
	return Transform3D(Basis.looking_at(direction,up),eye)

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
	var operation:=Blast.new()
	var result:=operation.evaluate(_weapon,shot,targets)
	if result.is_empty():return fail(operation.error)
	return result

## Asteroids an Ion Lambda shot touched this frame: each takes the scenery
## damage once (no push) and is remembered so it is not struck again.
func _struck_hits(shot: Dictionary,passed: Array) -> Array:
	var hits:=[]
	for target in passed:
		shot.struck=shot.get("struck",[])+[target.actor_id]
		hits.append({"actor_id":target.actor_id,"target":target.target.duplicate(),"system_damage":0,"distance":0,
			"normal_damage":int(Definitions.ION_LAMBDA.scenery_damage),"impact_vector":Vector3.ZERO,"motion_scalar":0.0})
	return hits

## Collision candidates are sampled before movement. A first physical contact
## produces one radial pulse; the same bomb cannot hit overlapping bodies twice.
## With pass_scenery, touched asteroids are listed in "passed" instead.
static func contact_target(shot: Dictionary,targets: Array,pass_scenery:=false) -> Dictionary:
	var geometry:=Geometry.new()
	var passed:=[]
	for target in targets:
		var shape: Dictionary=target.get("collision",{})
		if not target.active or not shape.get("eligible",false):continue
		var scenery: bool=target.get("target",{}).get("group")=="scenery"
		if pass_scenery and scenery and target.actor_id in shot.get("struck",[]):continue
		var result: Dictionary
		if shape.get("path")=="point_geometry":result=geometry.box_geometry(shot.position,shape.center,shape.get("boxes"))
		elif shape.get("path")=="bounds":result=geometry.bounds(shot.position,shot.velocity,shape.center,shape.get("half_extent"))
		else:return {"error":"The bomb target has an unsupported collision provider"}
		if result.is_empty():return {"error":geometry.error}
		if result.hit and pass_scenery and scenery:passed.append(target);continue
		if result.hit:return {"hit":true,"actor_id":target.actor_id,"passed":passed}
	return {"hit":false,"passed":passed}

## Own-ship consequences use the effect wrapper's cached position. Its caller
## applies damage through the player owner only at the hardest difficulty.
static func self_hit(weapon: Dictionary,position: Vector3,observer: Vector3) -> Dictionary:
	if not Vitals.integer(weapon.get("damage")) or not Vitals.integer(weapon.get("radius")) or weapon.radius<1 or not position.is_finite() or not observer.is_finite():return {}
	var difference:=position-observer
	var distance:=Vitals.single(sqrt(Vectors.dot(difference,difference)))
	if not is_finite(distance):return {}
	var reach:=Vitals.single(float(weapon.radius)*0.5)
	var fraction:=clampf(Vitals.single(Vitals.single(Vitals.single(reach-distance)/reach)*0.5),0.0,1.0)
	if weapon.get("kind")==int(Definitions.SHOCK.kind):fraction=Vitals.single(fraction*float(Definitions.SHOCK.self_damage_factor))
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
	copy._visuals=_visuals.duplicate(true);copy._steer=_steer
	return copy

func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
