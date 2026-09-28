extends "res://tests/emp_bombs.gd"
## Detached radius, contact and effect timing checks. Fitting and earned flight
## are separate acceptance boundaries; these fixtures do not grant equipment.
const Resources=preload("res://src/content/emp_detonation_resources.gd")
const Burst=preload("res://src/simulation/emp_detonation.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Ownership=preload("res://src/simulation/secondary_weapons.gd")
const Loadouts=preload("res://tests/secondary_weapons.gd")

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:
		verify(args)
		verify_area(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Area bomb components: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_area(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib):check(false,lib.error+bindings.error+cat.error);return
	var resources:=Resources.new()
	if not resources.configure(lib,bindings,7):check(false,resources.error);return
	var mounts:=Mounts.new()
	if not mounts.open(lib,cat):check(false,mounts.error);return
	var equipment: Dictionary=Loadouts.equipped(bindings,cat,[{"item_id":41,"slot":0,"quantity":2}])
	var owner:=Ownership.new()
	check(owner.configure(bindings,cat,equipment,mounts),owner.error)
	var emitted: Dictionary=owner.snapshot().guns[0].bomb.weapon
	var mount:=mounts.resolve(equipment.ship_id,1,0)
	check(emitted.muzzle_offset==mount.position+Vector3(0,0,100),"Equipped EMP kept its factory fallback instead of the ship mount")
	for id in [44,45,46]:
		var bomb:=Bombs.new()
		check(bomb.configure(bindings,cat,id,[],Vector3(20,-30,140)),bomb.error)
		var weapon: Dictionary=bomb.snapshot().weapon
		var radius: int=weapon.radius
		check(bomb.advance(1,[]).action=="none",bomb.error)
		var launch:=bomb.trigger(Transform3D.IDENTITY,1,[])
		check(launch.action=="launched" and launch.ammunition_consumed==1 and launch.shot.position==Vector3(20,-30,140),"An AMR launch lost its fitted muzzle or ammunition")
		var origin: Vector3=launch.shot.position
		var near:=target(0,origin)
		var half:=target(1,origin+Vector3(radius/2.0,0,0))
		var edge:=target(2,origin+Vector3(radius,0,0))
		var rock:=target(3,origin+Vector3(radius/2.0,0,0),true,true)
		rock.target={"group":"scenery","index":0}
		var inactive:=target(4,origin,false)
		var before:=bomb.snapshot()
		var fork: RefCounted=bomb.fork()
		var pulse: Dictionary=fork.trigger(Transform3D.IDENTITY,0,[near,half,edge,rock,inactive])
		check(pulse.action=="detonated" and pulse.ammunition_consumed==0 and bomb.snapshot()==before,"Last-round AMR detonation consumed ammo or changed its parent")
		check(pulse.blast.hits.size()==3,"Radius boundary or inactive target took AMR damage")
		if pulse.blast.hits.size()!=3:continue
		var hits: Array=pulse.blast.hits
		check(hits[0].normal_damage==weapon.damage and hits[1].normal_damage==int(weapon.damage/2.0),"Near and half-radius ships did not receive normal falloff damage")
		check(hits[2].normal_damage==int(float(weapon.damage)*0.3) and hits[2].target==rock.target,"Asteroid did not receive reduced ordinary damage")
		check(hits.all(func(hit):return hit.system_damage==0),"AMR unexpectedly disabled ship systems")
		check(hits[1].impact_vector==Vector3.RIGHT and hits[1].motion_scalar==0.5 and hits[2].motion_scalar==0.5,"Radial impact direction or pre-scenery strength changed")
		check(fork.advance(0,[]).action=="none" and fork.snapshot().shot.is_empty(),"AMR radius was applied again after detonation")
		verify_contacts(bomb,origin)
		verify_effect(bomb,resources,launch,origin,weapon)

func verify_contacts(initial: RefCounted,origin: Vector3) -> void:
	var target_row:=target(0,origin)
	target_row.collision={"eligible":true,"path":"bounds","center":origin,"half_extent":100}
	var contact: RefCounted=initial.fork()
	var result: Dictionary=contact.advance(100,[target_row,target(1,origin)])
	check(result.action=="detonated" and result.blast.position==origin and result.blast.hits.size()==2,"Contact did not pulse once before motion across overlapping targets")
	var miss: RefCounted=initial.fork()
	target_row.collision={"eligible":true,"path":"point_geometry","center":origin,"boxes":[{"offset":Vector3(1000,0,0),"half_extents":Vector3.ONE*100}]}
	result=miss.advance(100,[target_row])
	check(result.action=="none" and miss.snapshot().shot.position!=origin,"Negative point geometry was replaced by a bounds contact")
	var expiry: RefCounted=initial.fork()
	var state: Dictionary=expiry.snapshot()
	var endpoint: Vector3=origin+state.shot.velocity*state.weapon.lifetime_ms
	result=expiry.advance(state.weapon.lifetime_ms,[target(0,endpoint)])
	check(result.action=="detonated" and result.blast.position==endpoint and result.blast.hits[0].normal_damage==state.weapon.damage,"Expiry did not use the position after full-step motion")
	var before: Dictionary=initial.snapshot()
	target_row.collision={"eligible":true,"path":"invalid"}
	check(initial.advance(100,[target_row]).is_empty() and initial.snapshot()==before,"Rejected collision provider partly advanced a bomb")

func verify_effect(initial: RefCounted,resources: RefCounted,launch: Dictionary,origin: Vector3,weapon: Dictionary) -> void:
	var burst:=Burst.new()
	check(burst.configure(resources,int(weapon.item_id)) and burst.begin_projectile(launch.shot),burst.error)
	var body: RefCounted=initial.fork()
	var before: Dictionary=body.snapshot()
	check(body.advance(100,[]).action=="none",body.error)
	var event:=burst.advance(before,body.snapshot(),100,origin)
	check(not event.started and event.self_hit.is_empty() and event.audio.is_empty(),"Flying bomb produced an early burst or self hit")
	check(body.trigger(Transform3D.IDENTITY,0,[]).action=="detonated",body.error)
	before=body.snapshot()
	check(body.advance(50,[]).action=="none",body.error)
	event=burst.advance(before,body.snapshot(),50,origin)
	check(event.started and event.audio.size()==1 and event.audio[0].position==origin,"Manual pulse lost its pre-movement visual cache or one-shot sound")
	check(event.self_hit.damage==int(weapon.damage/2.0) and event.self_hit.feedback==1.5,"Own-ship blast did not use the cached position or maximum half damage")
	var state:=burst.snapshot()
	check(state.effect.models.size()==2 and state.effect_type==0 and state.effect.position==origin,"AMR omitted an original explosion layer or invented debris")
	var near: Dictionary=Bombs.self_hit(weapon,origin,origin+Vector3(weapon.radius/4.0,0,0))
	var edge: Dictionary=Bombs.self_hit(weapon,origin,origin+Vector3(weapon.radius/2.0,0,0))
	check(near.damage==int(weapon.damage/4.0) and edge.damage==0 and edge.feedback==0.0,"Own blast did not fall off to zero at half radius")
	before=body.snapshot();body.advance(100,[])
	event=burst.advance(before,body.snapshot(),100,origin+Vector3(100000,0,0))
	check(not event.started and event.audio.is_empty() and event.self_hit.is_empty() and event.camera.strength>0.0,"Burst repeated its damage/sound or resampled the observer")
	var remaining: int=state.effect.duration_ms-burst.snapshot().effect.elapsed_ms
	before=body.snapshot();body.advance(remaining+1,[])
	event=burst.advance(before,body.snapshot(),remaining+1,origin)
	check(event.retired and not burst.snapshot().effect.active and event.camera.strength==0.0,"AMR animation or camera outlived the original effect")
	check(not burst.configure(Resources.new(),int(weapon.item_id)),"Unprepared original explosion resources were accepted")
