extends RefCounted
## A sentry launcher's placed turrets and their shots. One round places a
## turret at the ship's pose (up to three of a type alive or exploding); it
## re-picks the nearest hostile within range every 3 s, turns to it and fires
## ordinary shots. The outer weapon owner runs the shot contacts with the frame.
const Definitions=preload("res://src/content/sentry_gun_definitions.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Projectiles=preload("res://src/simulation/ordinary_projectiles.gd")
const Turret=preload("res://src/simulation/static_turret.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
var error:=""
var _weapon:={}
var _slots:=[]
var _shots: RefCounted
var _elapsed_ms:=0
var _next_id:=1

func configure(bindings: RefCounted,cat: RefCounted,item_id: Variant,campaign_cursor: Variant=null) -> bool:
	error=""
	if not item_id is int:return reject("Invalid sentry launcher")
	var declaration:=Definitions.declaration(item_id)
	if declaration.is_empty():return reject("This item is not a supported sentry gun")
	var resolver:=Weapons.new()
	if bindings==null or not resolver.configure(bindings,cat,bindings.base_content_id):return reject(resolver.error)
	var properties: Dictionary=cat.tables.items[item_id].properties
	for key in [9,11,12,13]:
		if not Vitals.integer(properties.get(key)) or properties[key]<1:return reject("The sentry gun lacks its catalogue damage, interval, lifetime or speed")
	# The turret's shot is the gun item's ordinary projectile carrying the
	# sentry item's own damage, lifetime and speed.
	var shot:=resolver.resolve(int(declaration.gun_item),[])
	if shot.get("launch_mode")!="ordinary" or not shot.get("ordinary_hit_policy") is Dictionary or int(shot.kind)!=int(declaration.kind):return reject("The sentry's shot has no supported ordinary declaration")
	shot.damage=int(properties[9]);shot.ordinary_hit_policy.nonplayer_damage=int(properties[9])
	shot.lifetime_ms=int(properties[12]);shot.speed_units_per_millisecond=float(properties[13])
	# Each turret keeps its own fire interval; the shared shot pool only spaces frames.
	shot.interval_ms=1
	if campaign_cursor!=null:shot.campaign_cursor=campaign_cursor
	var shots:=Projectiles.new()
	if not shots.configure(shot):return reject(shots.error)
	_weapon=declaration.duplicate(true)
	_weapon.merge({"item_id":item_id,"damage":int(properties[9]),"interval_ms":int(properties[11]),"lifetime_ms":int(properties[12]),"speed":float(properties[13])})
	_shots=shots;_slots=[];_slots.resize(Definitions.CAPACITY);_elapsed_ms=int(_weapon.interval_ms);_next_id=1
	return true

func live_count() -> int:return _slots.filter(func(slot):return slot!=null).size()

func trigger_action(ammunition: int,permitted:=true) -> String:
	if not permitted or _weapon.is_empty() or ammunition<=0 or _elapsed_ms<=int(_weapon.interval_ms):return "none"
	return "launched" if _slots.has(null) else "none"

## A fourth placement is refused (no round spent) while three are alive or exploding.
func trigger(pose: Transform3D,ammunition: Variant,permitted: Variant=true) -> Dictionary:
	error=""
	if _weapon.is_empty() or not Vitals.integer(ammunition) or not permitted is bool or not pose.is_finite():return fail("Invalid sentry placement context")
	var result:={"action":"none","ammunition_consumed":0,"shot":{}}
	if trigger_action(ammunition,permitted)=="none":return result
	var index: int=_slots.find(null)
	var sentry:={"id":_next_id,"slot":index,"phase":"active","pose":Transform3D(pose.basis.orthonormalized(),pose.origin),
		"aim":Turret.initial(),"hull":Definitions.HULL,"age_ms":0,"cooldown_ms":int(_weapon.interval_ms)+1,"dying_ms":0}
	_slots[index]=sentry;_next_id+=1;_elapsed_ms=0
	result.action="launched";result.ammunition_consumed=1;result.shot=sentry.duplicate(true)
	return result

## candidates: [{actor_id, position, forward}] of living, active hostile ships.
## Returns this frame's shots ({sentry_id, projectile}) and finished explosions.
func advance(delta_ms: Variant,candidates: Array) -> Dictionary:
	error=""
	if _weapon.is_empty() or not Vitals.integer(delta_ms) or delta_ms<0 or _elapsed_ms>Vitals.MAX_INTEGER-delta_ms:return fail("Invalid sentry frame")
	var result:={"fired":[],"removed":[]}
	for index in _slots.size():
		var sentry: Variant=_slots[index]
		if sentry==null:continue
		if sentry.phase=="dying":
			sentry.dying_ms+=delta_ms
			if sentry.dying_ms>=Definitions.DEATH_MS:_slots[index]=null;result.removed.append(sentry.id)
			continue
		sentry.age_ms=mini(Vitals.MAX_INTEGER,sentry.age_ms+delta_ms);sentry.cooldown_ms=mini(Vitals.MAX_INTEGER,sentry.cooldown_ms+delta_ms)
		var aimed: Dictionary=Turret.advance(sentry.aim,Definitions.AIM,sentry.pose,candidates,delta_ms)
		sentry.aim=aimed.aim
		if not aimed.fire or sentry.cooldown_ms<=int(_weapon.interval_ms):continue
		var barrel: Transform3D=aimed.barrel
		var shot: Dictionary=_shots.fire(barrel*Vector3(0,0,float(_weapon.muzzle)),barrel.basis.z,true)
		if shot.is_empty():return fail(_shots.error)
		if not shot.fired:continue
		sentry.cooldown_ms=0
		result.fired.append({"sentry_id":sentry.id,"target_id":int(aimed.target_id),"projectile":shot.projectile})
	_elapsed_ms+=delta_ms
	return result

## Damage from a hostile; ignored while arming or exploding.
func damage(sentry_id: int,amount: int) -> Dictionary:
	error=""
	if amount<0:return fail("Invalid sentry damage")
	for sentry in _slots:
		if sentry==null or sentry.id!=sentry_id:continue
		if sentry.phase!="active" or sentry.age_ms<Definitions.ARMING_MS:return {"applied":0,"destroyed":false}
		var applied: int=mini(amount,int(sentry.hull))
		sentry.hull-=applied
		if sentry.hull==0:sentry.phase="dying";sentry.dying_ms=0
		return {"applied":applied,"destroyed":sentry.hull==0}
	return fail("Sentry damage names an unavailable turret")

func projectiles() -> RefCounted:return _shots
func set_projectiles(shots: RefCounted) -> void:_shots=shots

func discard_flying() -> void:
	if _shots!=null:_shots.discard_flying()

func snapshot() -> Dictionary:
	return {"weapon":_weapon.duplicate(true),"slots":_slots.duplicate(true),"elapsed_ms":_elapsed_ms,"shots":_shots.snapshot() if _shots!=null else {}}

func fork() -> RefCounted:
	var next: RefCounted=get_script().new()
	next._weapon=_weapon.duplicate(true);next._slots=_slots.duplicate(true);next._elapsed_ms=_elapsed_ms;next._next_id=_next_id
	next._shots=_shots.fork_state() if _shots!=null else null
	return next

func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:error=message;return {}
