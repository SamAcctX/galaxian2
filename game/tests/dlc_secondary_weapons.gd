extends "res://tests/secondary_weapons.gd"
## Supernova secondaries: cluster missiles launch a corkscrewing guided salvo
## for one round, the Shock Blast hits everything around the ship once, the
## Ion Lambda Mk2 is a wider Ion Lambda, and the hangar fits all of them.
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Fitting=preload("res://src/simulation/equipment_fitting.gd")
const ShockBombs=preload("res://src/simulation/emp_bombs.gd")
const Conventional=preload("res://src/content/conventional_secondary_definitions.gd")
const BurstResources=preload("res://src/content/emp_detonation_resources.gd")
const Burst=preload("res://src/simulation/emp_detonation.gd")
const BombBody=preload("res://src/presentation/bomb_projectile_geometry.gd")
const VisualLibrary=preload("res://src/content/visual_library.gd")
const ADMITTED:=[214,215,216,221,226,232]
const REFUSED:=[]

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==3,"Expected one content/binding/visual triple")
	if args.size()==3:verify_dlc(args[0],args[1],args[2])
	print("DLC secondary weapons: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_dlc(content: String,pack: String,visual_pack: String) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new()
	if not lib.open(content) or not bindings.open(pack,lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat):check(false,lib.error+bindings.error+cat.error+mounts.error);return
	verify_fitting(lib,bindings,cat)
	var built:=construction(bindings,cat,0.5)
	if built==null:return
	for item in [214,215,216]:verify_cluster(lib,bindings,cat,mounts,built,item)
	verify_ion(bindings,cat)
	verify_shock(lib,bindings,cat,mounts,built)
	var visuals:=VisualLibrary.new()
	check(visuals.open(visual_pack,lib.manifest),visuals.error)
	verify_fireworks(lib,bindings,cat,mounts,built,visuals)

func verify_fitting(lib: RefCounted,bindings: RefCounted,cat: RefCounted) -> void:
	var fitting:=Fitting.new();var assets:=fitting.prepare_assets(bindings,cat,lib)
	if assets.is_empty():check(false,fitting.error);return
	for item in ADMITTED:
		var loadout:=equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":2}])
		var result:=fitting.inspect(bindings,cat,loadout,assets)
		check(not result.is_empty() and result.support.get(item)=="","Item %d is not fittable: %s %s"%[item,fitting.error,str(result.get("support",{}).get(item))])
	var plain:=fitting.inspect(bindings,cat,equipped(bindings,cat,[]),assets)
	for item in REFUSED:
		check(not plain.is_empty() and plain.support.get(item,"")!="","Unbuilt item %d became fittable"%item)

func verify_cluster(lib: RefCounted,bindings: RefCounted,cat: RefCounted,mounts: RefCounted,built: RefCounted,item: int) -> void:
	var count: int=item-211
	var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
	if group==null or not owner.configure(bindings,cat,equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":2}]),mounts) or not owner.configure_projectile_visuals(lib,bindings):check(false,owner.error);return
	var targets:=[0,1,2,3]
	var pose:=Transform3D(Basis.IDENTITY,group.snapshot().actors[0].position-Vector3(0,30000,0))
	var step:=owner.evaluate_advance(100000,group,targets)
	if step.is_empty():check(false,owner.error);return
	owner=step.owner
	var fired:=owner.evaluate_trigger(pose,item,group,targets)
	if fired.is_empty():check(false,owner.error);return
	owner=fired.owner
	var gun: Dictionary=owner.snapshot().guns[0]
	var live: Array=gun.projectiles.slots.filter(func(slot):return slot!=null)
	check(fired.events.size()==1 and fired.events[0].action=="launched" and fired.events[0].ammunition_consumed==1 and gun.ammunition==1,"Cluster %d did not spend one round for its salvo"%item)
	check(live.size()==count and gun.projectiles.weapon.secondary_projectile.guided,"Cluster %d launched %d missiles, not a guided salvo of %d"%[item,live.size(),count])
	step=owner.evaluate_advance(600,group,targets)
	if step.is_empty():check(false,owner.error);return
	var moved: Array=step.owner.snapshot().guns[0].projectiles.slots.filter(func(slot):return slot!=null)
	var spread:=0.0
	for slot in moved:spread=maxf(spread,Vector3(slot.position).distance_to(moved[0].position))
	var forward: float=moved[0].position.z-pose.origin.z
	check(moved.size()==count and spread>300.0 and forward>1000.0,"Cluster %d salvo did not fly ahead in a spreading corkscrew (spread %.0f, ahead %.0f)"%[item,spread,forward])

func verify_ion(bindings: RefCounted,cat: RefCounted) -> void:
	var resolver:=preload("res://src/simulation/weapon_loadout.gd").new()
	if not resolver.configure(bindings,cat,bindings.base_content_id):check(false,resolver.error);return
	var weapon: Dictionary=resolver.resolve(221,[])
	check(Conventional.resolved(weapon) and Conventional.ion_radius(221)==15000.0 and Conventional.ion_radius(197)==10000.0,"Ion Lambda Mk2 is not a wider Ion Lambda")

func verify_shock(lib: RefCounted,bindings: RefCounted,cat: RefCounted,mounts: RefCounted,built: RefCounted) -> void:
	var bomb:=ShockBombs.new()
	if not bomb.configure(bindings,cat,226,[]):check(false,bomb.error);return
	check(bomb.prepare_visuals(lib,bindings),"Shock Blast visuals unavailable: "+bomb.error)
	var weapon: Dictionary=bomb.snapshot().weapon
	check(weapon.radius==80000 and weapon.damage==140 and weapon.system_damage==80 and weapon.interval_ms==7000,"Shock Blast lost its catalogue values: "+str(weapon))
	var near:={"actor_id":0,"position":Vector3(0,0,20000),"active":true,"emp_immune":false}
	var rock:={"actor_id":1,"position":Vector3(20000,0,0),"active":true,"emp_immune":true}
	var far:={"actor_id":2,"position":Vector3(0,90000,0),"active":true,"emp_immune":false}
	var origin:=Transform3D(Basis.IDENTITY,Vector3(0,0,0))
	bomb.advance(8000,[near,rock,far])
	var launch:=bomb.trigger(origin,1,[near,rock,far])
	check(launch.action=="launched" and launch.ammunition_consumed==1 and launch.shot.position==Vector3.ZERO,"Shock Blast did not start at the ship")
	var blast:=bomb.advance(16,[near,rock,far])
	var hits: Array=blast.get("blast",{}).get("hits",[])
	var by_id:={}
	for hit in hits:by_id[hit.actor_id]=hit
	check(blast.action=="detonated" and by_id.has(0) and by_id.has(1) and not by_id.has(2),"Shock Blast did not hit only targets inside 80000: "+str(by_id.keys()))
	if by_id.has(0) and by_id.has(1):
		check(by_id[0].normal_damage==105 and by_id[0].system_damage==60 and by_id[1].normal_damage==63,"Shock Blast falloff wrong: "+str(by_id))
	check(bomb.advance(5000,[near]).action=="none","Shock Blast pulsed twice")
	check(ShockBombs.self_hit(weapon,Vector3.ZERO,Vector3.ZERO).get("damage")==14,"Shock Blast self damage is not a fifth of a bomb's")
	# Owner path: real ships around the player take damage; burst resources load.
	var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
	if group==null or not owner.configure(bindings,cat,equipped(bindings,cat,[{"item_id":226,"slot":0,"quantity":1}]),mounts):check(false,owner.error);return
	var bursts:=BurstResources.new()
	check(bursts.configure(lib,bindings,42) and owner.configure_detonations(bursts) and owner.configure_projectile_visuals(lib,bindings),"Shock Blast burst unavailable: "+bursts.error+owner.error)
	var targets:=[0,1,2,3]
	var pose:=Transform3D(Basis.IDENTITY,group.snapshot().actors[0].position-Vector3(0,0,5000))
	var step:=owner.evaluate_advance(8000,group,targets,pose.origin)
	if step.is_empty():check(false,owner.error);return
	var fired: Dictionary=step.owner.evaluate_trigger(pose,226,group,targets)
	if fired.is_empty():check(false,step.owner.error);return
	step=fired.owner.evaluate_advance(16,fired.combat,targets,pose.origin)
	if step.is_empty():check(false,fired.owner.error);return
	var events: Array=step.events.filter(func(event):return event.action=="detonated")
	check(events.size()==1 and not events[0].normal_hits.is_empty() and fired.owner.snapshot().guns[0].ammunition==0,"Shock Blast owner did not damage nearby ships")
	var burst: RefCounted=step.owner.detonation_owner(step.owner.snapshot().guns[0].slot_index)
	check(burst!=null and burst.snapshot().effect.active and burst.snapshot().effect.get("scale")==50000.0,"Shock Blast glow did not start at 50000x")

## Fireworks: one round flies off the ship and bursts as the quarter-size
## firework glow when its fuse runs out. Its sparks trail while it flies and
## have faded out shortly after the burst.
func verify_fireworks(lib: RefCounted,bindings: RefCounted,cat: RefCounted,mounts: RefCounted,built: RefCounted,visuals: RefCounted) -> void:
	var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
	if group==null or not owner.configure(bindings,cat,equipped(bindings,cat,[{"item_id":232,"slot":0,"quantity":2}]),mounts):check(false,owner.error);return
	var bursts:=BurstResources.new()
	check(bursts.configure(lib,bindings,43) and owner.configure_detonations(bursts) and owner.configure_projectile_visuals(lib,bindings),"Fireworks burst unavailable: "+bursts.error+owner.error)
	var targets:=[0,1,2,3]
	var pose:=Transform3D(Basis.IDENTITY,group.snapshot().actors[0].position+Vector3(0,0,300000))
	var step:=owner.evaluate_advance(20000,group,targets,pose.origin)
	if step.is_empty():check(false,owner.error);return
	var fired: Dictionary=step.owner.evaluate_trigger(pose,232,group,targets)
	if fired.is_empty():check(false,step.owner.error);return
	var current: RefCounted=fired.owner;var combat: RefCounted=fired.combat;var burst_at:=-1
	var body:=BombBody.new()
	if not body.build(current.snapshot().guns[0].bomb,lib,visuals,bindings) or body.trail==null:check(false,"Fireworks trail unavailable: "+body.error);body.free();return
	var flying:=0
	for tick in 700:
		step=current.evaluate_advance(16,combat,targets,pose.origin)
		if step.is_empty():check(false,current.error);body.free();return
		current=step.owner;combat=step.get("combat",combat)
		var frame:=body.prepare(current.snapshot().guns[0].bomb)
		if frame.is_empty():check(false,body.error);body.free();return
		body.commit(frame)
		if tick==60:flying=body.trail.sprites
		if step.events.any(func(event):return event.action=="detonated"):burst_at=tick*16;break
	check(burst_at>=6000 and burst_at<=9000,"Fireworks did not burst on its fuse: %d ms"%burst_at)
	check(flying>=40,"Fireworks drew %d trail sparks in flight"%flying)
	var repeat:=body.prepare(current.snapshot().guns[0].bomb);body.commit(repeat)
	var lingering: int=body.trail.sprites
	check(lingering>0,"Fireworks sparks vanished at the burst instead of fading out")
	for tick in 90:
		step=current.evaluate_advance(16,combat,targets,pose.origin)
		if step.is_empty():check(false,current.error);body.free();return
		current=step.owner;combat=step.get("combat",combat)
		body.commit(body.prepare(current.snapshot().guns[0].bomb))
	check(body.trail.sprites==0,"Fireworks still drew %d trail sparks 1.4 s after the burst"%body.trail.sprites)
	body.free()
	var burst: RefCounted=current.detonation_owner(current.snapshot().guns[0].slot_index)
	check(burst!=null and burst.snapshot().effect.active and burst.snapshot().effect.get("scale")==0.25,"Fireworks glow did not start at quarter size")
