extends "res://tests/secondary_weapons.gd"
## Detached launch/contact transactions use original mounts and real NPC pools.
## Shop, fitting and save acceptance are covered by the application pilot.
const Mounts=preload("res://src/content/weapon_mounts.gd")

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==3,"Expected one content/binding/visual triple")
	if args.size()==3:verify(args[0],args[1])
	print("Conventional secondary ownership: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(content: String,pack: String) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new()
	if not lib.open(content) or not bindings.open(pack,lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat):check(false,lib.error+bindings.error+cat.error+mounts.error);return
	var built:=construction(bindings,cat,0.5)
	if built==null:return
	var audio:=AudioResources.new()
	if not audio.configure(lib,bindings,21):check(false,audio.error);return
	for item in range(31,41):
		var initial:=equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":1}])
		var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
		if group==null or not owner.configure(bindings,cat,initial,mounts) or not owner.configure_projectile_visuals(lib,bindings):check(false,owner.error);return
		var target: Vector3=group.snapshot().actors[0].position
		var pose:=Transform3D(Basis.IDENTITY,target-mounts.resolve(0,1,0).position-Vector3(0,0,100))
		var before:=owner.snapshot();var combat_before: Dictionary=group.snapshot()
		var blocked:=owner.evaluate_trigger(pose,item,group,[0,1,2,3])
		check(not blocked.is_empty() and blocked.events.is_empty() and blocked.owner.snapshot()==before,"Conventional trigger consumed ammunition before cooldown")
		var step:=owner.evaluate_advance(1,group,[0,1,2,3])
		if step.is_empty():check(false,owner.error);return
		owner=step.owner;before=owner.snapshot()
		blocked=owner.evaluate_trigger(pose,item,group,[0,1,2,3],false)
		check(not blocked.is_empty() and blocked.owner.snapshot()==before,"Blocked conventional input changed ammunition or projectile state")
		var fired:=owner.evaluate_trigger(pose,item,group,[0,1,2,3])
		if fired.is_empty():check(false,owner.error);return
		check(owner.snapshot()==before and group.snapshot()==combat_before,"Conventional trigger mutated its retained parent")
		owner=fired.owner;group=fired.combat
		var shot: Dictionary=owner.snapshot().guns[0].projectiles.slots[0]
		var weapon: Dictionary=owner.snapshot().guns[0].projectiles.weapon
		check(fired.events.size()==1 and fired.events[0].action=="launched" and shot.position.is_equal_approx(target),"Last round failed to launch from the ship's secondary muzzle")
		check(owner.snapshot().guns[0].ammunition==0 and not owner.snapshot().loadout.equipment_ids.has(item) and owner.snapshot().guns[0].projectiles.slots[0]!=null,"Last ammunition removal also removed the flying projectile")
		check(owner.reconcile_loadout(initial)==owner.snapshot().loadout,"Conventional ammunition could not be retained in the inventory transaction")
		var sound:=audio.prepare(int(fired.events[0].audio.source_id))
		check(not sound.is_empty() and not sound.has("unsupported") and fired.events[0].audio.position==pose.origin,"Conventional launch lost its original sound or player origin")
		before=owner.snapshot();combat_before=group.snapshot()
		step=owner.evaluate_advance(0,group,[0,1,2,3])
		if step.is_empty():check(false,owner.error);return
		var hits: Array=step.events.filter(func(event):return event.action=="impact" and event.get("actor_id")==0)
		check(hits.size()==1 and hits[0].position.is_equal_approx(target) and hits[0].ammunition_consumed==0 and hits[0].audio.is_empty(),"Conventional contact did not produce one world impact without spending ammunition again")
		var damaged: Dictionary=step.combat.snapshot().actors[0]
		if weapon.damage>0:check(damaged.vitals!=combat_before.actors[0].vitals,"Conventional contact failed to change the target's normal damage pools")
		if weapon.ordinary_hit_policy.additional_damage_required:check(damaged.systems!=combat_before.actors[0].systems,"EMP missile failed to damage target systems")
		check(step.owner.snapshot().guns[0].projectiles.slots[0]==null and not step.owner.snapshot().guns[0].projectiles.trails[0].sections.is_empty(),"Impact failed to retire the body and retain its fading exhaust")
		check(owner.snapshot()==before and group.snapshot()==combat_before,"Conventional contact mutated a previous frame")
		owner=step.owner;group=step.combat
		step=owner.evaluate_advance(int(weapon.interval_ms)+1,group,[0,1,2,3])
		if step.is_empty():check(false,owner.error);return
		owner=step.owner
		blocked=owner.evaluate_trigger(pose,item,group,[0,1,2,3])
		check(not blocked.is_empty() and blocked.events.is_empty() and blocked.selection_exhausted and blocked.owner.snapshot().launches==1,"Empty conventional stack launched again or retained selection after the next ready attempt")
	verify_mixed(bindings,cat,mounts,built)
	verify_scenery(lib,bindings,cat)

func verify_scenery(lib: RefCounted,bindings: RefCounted,cat: RefCounted) -> void:
	var resources:=preload("res://src/content/scenery_body_resources.gd").new()
	var field_owner:=preload("res://src/simulation/scenery_field.gd").new()
	var resolver:=preload("res://src/simulation/weapon_loadout.gd").new()
	if not resources.configure(lib,bindings) or not field_owner.configure(bindings,cat,78,false,false,0) or not resolver.configure(bindings,cat,lib.manifest.content_id):check(false,resources.error+field_owner.error+resolver.error);return
	var random:=preload("res://src/simulation/seeded_random.gd").new();random.seed_from(12345)
	var field: Dictionary=field_owner.generate(Vector3.ZERO,random.snapshot())
	# Two deliberately overlapping copies of an original asteroid distinguish
	# first-contact processing from a splash or repeated same-frame strike.
	field.objects=[field.objects[0].duplicate(true),field.objects[0].duplicate(true)];field.objects[1].index=1
	for item in range(31,41):
		var bodies:=preload("res://src/simulation/scenery_bodies.gd").new()
		var shots:=preload("res://src/simulation/ordinary_projectiles.gd").new()
		var pass_owner:=preload("res://src/simulation/ordinary_scenery_contacts.gd").new()
		if not bodies.configure(bindings,field,resources) or not shots.configure(resolver.resolve(item,[item])):check(false,bodies.error+shots.error);return
		if shots.advance(1).is_empty() or not shots.fire(field.objects[0].position,Vector3.BACK,true).get("fired",false):check(false,shots.error);return
		var before:=bodies.snapshot();var flying:=shots.snapshot()
		var result:=pass_owner.evaluate(shots,bodies,[0,1])
		if result.is_empty():check(false,pass_owner.error);return
		var after: Dictionary=result.bodies.snapshot()
		check(after.objects[0].destruction_pending and after.objects[1].vitals==before.objects[1].vitals,"Rocket or missile failed to break exactly the first contacted asteroid")
		check(result.contacts.size()==1 and result.contacts[0].projectile_continues and result.last_contact_object_index==null and not after.objects[0].contact,"Asteroid destruction invented a projectile impact or additional burst")
		check(result.projectiles.snapshot()==flying and shots.snapshot()==flying and bodies.snapshot()==before,"Asteroid contact consumed the projectile or changed a retained parent")
		var second:=pass_owner.evaluate(result.projectiles,result.bodies,[0,1])
		check(not second.is_empty() and second.bodies.snapshot().objects[1].destruction_pending,"A continuing projectile could not break the next asteroid")
		check(not result.projectiles.advance(100).is_empty() and result.projectiles.snapshot().slots[0].position!=flying.slots[0].position,"Projectile stopped moving after breaking an asteroid")
		if not bodies.set_permissions(0,true,false):check(false,bodies.error);return
		result=pass_owner.evaluate(shots,bodies,[0,1])
		check(not result.is_empty() and result.contacts.size()==1 and not result.contacts[0].damage.accepted and result.bodies.snapshot().objects[0].vitals==before.objects[0].vitals,"Destructive asteroid contact bypassed damage permission")

func verify_mixed(bindings: RefCounted,cat: RefCounted,mounts: RefCounted,built: RefCounted) -> void:
	var ship:=-1
	for row in cat.tables.ships:
		if row.stats.primary_slots>0 and row.stats.secondary_slots>=2:ship=int(row.id);break
	if ship<0:check(false,"Missing hull for mixed launcher case");return
	var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
	if group==null or not owner.configure(bindings,cat,equipped(bindings,cat,[{"item_id":41,"slot":0,"quantity":1},{"item_id":36,"slot":1,"quantity":2}],ship),mounts):check(false,owner.error);return
	var step:=owner.evaluate_advance(1,group,[0,1,2,3])
	if step.is_empty():check(false,owner.error);return
	owner=step.owner
	var fired:=owner.evaluate_trigger(Transform3D.IDENTITY,41,group,[0,1,2,3])
	if fired.is_empty():check(false,owner.error);return
	owner=fired.owner;group=fired.combat
	fired=owner.evaluate_trigger(Transform3D.IDENTITY,36,group,[0,1,2,3])
	if fired.is_empty():check(false,owner.error);return
	owner=fired.owner;group=fired.combat
	check(fired.events.size()==1 and fired.events[0].item_id==36 and owner.snapshot().guns[1].bomb.shot.phase=="flying","Earlier selected missile did not stop the trigger before a later live EMP bomb")
	var shot: Dictionary=owner.snapshot().guns[0].projectiles.slots[0]
	var pulse:=owner.evaluate_trigger(Transform3D.IDENTITY,-1,group,[0,1,2,3])
	if pulse.is_empty():check(false,owner.error);return
	check(pulse.events.size()==1 and pulse.events[0].action=="detonated" and pulse.events[0].item_id==41,"Unselected trigger did not retain manual EMP detonation")
	check(pulse.owner.snapshot().guns[0].projectiles.slots[0]==shot and pulse.owner.snapshot().guns[0].ammunition==1,"Manual EMP detonation changed an unrelated missile or ammo stack")
