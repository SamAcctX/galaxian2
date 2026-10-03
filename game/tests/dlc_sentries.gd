extends "res://tests/secondary_weapons.gd"
## Supernova sentry guns: one round places a friendly turret at the ship, it
## turns to the nearest hostile and shoots it; three per type at most; it can
## be destroyed after arming and its slot frees once the explosion ends.
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Fitting=preload("res://src/simulation/equipment_fitting.gd")
const Sentries=preload("res://src/simulation/sentry_guns.gd")
const SentryGeometry=preload("res://src/presentation/sentry_gun_geometry.gd")
const VisualLibrary=preload("res://src/content/visual_library.gd")
const ADMITTED:=[211,212,213]
const REFUSED:=[232]

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==3,"Expected one content/binding/visual triple")
	if args.size()==3:verify_sentries(args[0],args[1],args[2])
	print("DLC sentries: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_sentries(content: String,pack: String,visual_path: String) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new()
	if not lib.open(content) or not bindings.open(pack,lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat):check(false,lib.error+bindings.error+cat.error+mounts.error);return
	var fitting:=Fitting.new();var assets:=fitting.prepare_assets(bindings,cat,lib)
	if assets.is_empty():check(false,fitting.error);return
	for item in ADMITTED:
		var result:=fitting.inspect(bindings,cat,equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":2}]),assets)
		check(not result.is_empty() and result.support.get(item)=="","Sentry %d is not fittable: %s %s"%[item,fitting.error,str(result.get("support",{}))])
	var plain:=fitting.inspect(bindings,cat,equipped(bindings,cat,[]),assets)
	for item in REFUSED:check(not plain.is_empty() and plain.support.get(item,"")!="","Unbuilt item %d became fittable"%item)
	var built:=construction(bindings,cat,0.5)
	if built==null:return
	verify_owner(bindings,cat,mounts,built)
	verify_geometry(lib,bindings,visual_path)

func verify_owner(bindings: RefCounted,cat: RefCounted,mounts: RefCounted,built: RefCounted) -> void:
	var owner:=Ownership.new();var group:=active_group(bindings,cat,built,-50)
	if group==null or not owner.configure(bindings,cat,equipped(bindings,cat,[{"item_id":212,"slot":0,"quantity":5}]),mounts):check(false,owner.error);return
	var targets:=[0,1,2,3]
	var hostile:=targets.filter(func(id):return group.snapshot().actors[id].get("hostile",false))
	check(not hostile.is_empty(),"The test encounter has no hostile ship")
	if hostile.is_empty():return
	var victim: int=hostile[0]
	var start: Vector3=group.snapshot().actors[victim].position
	var pose:=Transform3D(Basis.IDENTITY,start+Vector3(0,0,-8000))
	# Place three; the fourth press is refused and spends nothing.
	for press in 4:
		var step:=owner.evaluate_advance(500,group,targets)
		if step.is_empty():check(false,owner.error);return
		owner=step.owner;group=step.combat
		var fired:=owner.evaluate_trigger(pose,212,group,targets)
		if fired.is_empty():check(false,owner.error);return
		owner=fired.owner;group=fired.combat
		var launched: bool=fired.events.size()==1 and fired.events[0].action=="launched"
		check(launched==(press<3),"Sentry press %d: launched=%s"%[press,str(launched)])
	var gun: Dictionary=owner.snapshot().guns[0]
	check(gun.ammunition==2 and gun.sentry.slots.all(func(slot):return slot!=null and slot.pose.origin==pose.origin),"Three sentries were not placed at the ship for three rounds")
	# Fly the ship away; the turrets keep shooting the hostile.
	var hull_before: int=group.snapshot().actors[victim].vitals.hull
	var shots:=0;var turned:=false
	for frame in 400:
		var step:=owner.evaluate_advance(16,group,targets)
		if step.is_empty():check(false,owner.error);return
		owner=step.owner;group=step.combat
		var state: Dictionary=owner.snapshot().guns[0].sentry
		shots=maxi(shots,state.shots.slots.filter(func(slot):return slot!=null).size())
		if absf(float(state.slots[0].aim.yaw))>0.01 or absf(float(state.slots[0].aim.pitch))>0.01:turned=true
	var hull_after: int=group.snapshot().actors[victim].vitals.hull
	check(turned and shots>0,"Sentries did not turn and shoot (turned %s, shots %d)"%[str(turned),shots])
	check(hull_after<hull_before,"Sentry shots did not damage the hostile (%d -> %d)"%[hull_before,hull_after])
	# Destruction: 100 hull, immune while arming; the slot frees after the explosion.
	var sentry_id: int=owner.snapshot().guns[0].sentry.slots[0].id
	var hit: Dictionary=owner.evaluate_sentry_damage(owner.snapshot().guns[0].slot_index,sentry_id,60)
	check(not hit.is_empty() and hit.hit.applied==60 and not hit.hit.destroyed,"Armed sentry did not take damage")
	if hit.is_empty():return
	hit=hit.owner.evaluate_sentry_damage(owner.snapshot().guns[0].slot_index,sentry_id,60)
	check(not hit.is_empty() and hit.hit.applied==40 and hit.hit.destroyed,"Sentry did not die at 0 hull")
	if hit.is_empty():return
	owner=hit.owner
	var refused:=owner.evaluate_trigger(pose,212,group,targets)
	check(not refused.is_empty() and refused.events.is_empty(),"A sentry slot freed before its explosion ended")
	var step:=owner.evaluate_advance(4600,group,targets)
	if step.is_empty():check(false,owner.error);return
	var again: Dictionary=step.owner.evaluate_trigger(pose,212,step.combat,targets)
	check(not again.is_empty() and again.events.size()==1 and again.events[0].action=="launched","The destroyed sentry's slot was not reused")
	if again.is_empty():return
	var fresh: Dictionary=again.owner.snapshot().guns[0].sentry.slots[0]
	var arming: Dictionary=again.owner.evaluate_sentry_damage(owner.snapshot().guns[0].slot_index,int(fresh.id),100)
	check(not arming.is_empty() and arming.hit.applied==0,"A new sentry took damage while arming")
	# Catalogue values carried by the turret's shot.
	var sentry:=Sentries.new()
	check(sentry.configure(bindings,cat,213),sentry.error)
	var weapon: Dictionary=sentry.snapshot().weapon;var shot: Dictionary=sentry.snapshot().shots.weapon
	check(weapon.damage==14 and weapon.interval_ms==250 and shot.damage==14 and shot.lifetime_ms==1000 and shot.speed_units_per_millisecond==28.0,"T'Suum lost its catalogue values: "+str(weapon))

func verify_geometry(lib: RefCounted,bindings: RefCounted,visual_path: String) -> void:
	var visuals:=VisualLibrary.new()
	if not visuals.open(visual_path,lib.manifest):check(false,visuals.error);return
	var cat:=Catalogues.new();cat.open(lib)
	var sentry:=Sentries.new()
	if not sentry.configure(bindings,cat,211):check(false,sentry.error);return
	sentry.advance(1000,[])
	sentry.trigger(Transform3D(Basis.IDENTITY,Vector3(100,0,0)),1)
	var geometry:=SentryGeometry.new()
	var ready: bool=geometry.build(sentry.snapshot(),lib,visuals,bindings)
	check(ready,"Sentry geometry: "+geometry.error)
	if ready:
		var frame: Dictionary=geometry.prepare(sentry.snapshot(),Transform3D.IDENTITY)
		check(not frame.is_empty() and frame.sentries[0].visible and not frame.sentries[1].visible,"Placed sentry is not drawn: "+geometry.error)
	geometry.free()
