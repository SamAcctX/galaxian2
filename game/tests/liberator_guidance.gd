extends "res://tests/secondary_weapons.gd"
## Liberator (guided antimatter missile): catalogue guidance, chase view,
## steering, manual/expiry detonation and kill credit to its item.
const GuidedBombs=preload("res://src/simulation/emp_bombs.gd")
const BombRules=preload("res://src/content/emp_bombs_definitions.gd")
const LIBERATOR:=179
const FlightAudio=preload("res://src/presentation/opening_audio.gd")

func _initialize() -> void:call_deferred("run_liberator")

func run_liberator() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_liberator(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Liberator guidance: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_liberator(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib):check(false,lib.error+bindings.error+cat.error);return
	check(not BombRules.declaration(LIBERATOR).is_empty(),"The Liberator has no bomb declaration")
	var bomb:=GuidedBombs.new()
	if not bomb.configure(bindings,cat,LIBERATOR,[]):check(false,bomb.error);return
	check(bomb.prepare_visuals(lib,bindings),"Liberator body/glow unavailable: "+bomb.error)
	var weapon: Dictionary=bomb.snapshot().weapon
	check(weapon.get("guided",false) and weapon.kind==7 and weapon.radius==25000 and weapon.damage==850 and weapon.lifetime_ms==20000 and weapon.interval_ms==10000,"Liberator lost its catalogue guidance or values: "+str(weapon))
	var plain:=GuidedBombs.new()
	check(plain.configure(bindings,cat,44,[]) and not plain.snapshot().weapon.get("guided",false),"An ordinary antimatter bomb became guided")
	check(bomb.advance(1,[]).action=="none" and bomb.trigger(Transform3D.IDENTITY,0,[]).action=="none","Empty launcher fired")
	var launch:=bomb.trigger(Transform3D.IDENTITY,1,[])
	check(launch.action=="launched" and launch.ammunition_consumed==1 and bomb.guided_live(),"Liberator did not launch a guided missile")
	var speed: float=weapon.speed_units_per_millisecond
	# Chase camera: above and behind, looking along the missile.
	var cam:=bomb.guided_camera_pose()
	var shot: Dictionary=bomb.snapshot().shot
	var local: Vector3=cam.origin-shot.position
	check(local.y>400.0 and local.z<-1300.0 and (-cam.basis.z).dot(Vector3(0,0,1))>0.9,"Missile camera is not behind/above looking ahead: "+str(cam))
	# No stick: straight flight.
	check(bomb.set_steering(Vector2.ZERO) and bomb.advance(100,[]).action=="none","Straight flight failed: "+bomb.error)
	check(bomb.snapshot().shot.velocity.normalized().is_equal_approx(Vector3(0,0,1)),"Missile turned without input")
	# Right stick (yaw) turns right, keeps speed; the ship pose is not involved.
	check(bomb.set_steering(Vector2(0,1)),bomb.error)
	for i in 10:bomb.advance(50,[])
	var velocity: Vector3=bomb.snapshot().shot.velocity
	check(velocity.x>0.3*speed and is_equal_approx(velocity.length(),speed),"Right stick did not turn the missile right at constant speed: "+str(velocity))
	# Down stick (pitch) noses down like the ship.
	var pitch: RefCounted=bomb.fork()
	pitch.set_steering(Vector2(1,0));pitch.advance(200,[])
	check(pitch.snapshot().shot.velocity.y<0.0,"Down stick did not pitch the missile down")
	# Second press detonates in place.
	var pulse: Dictionary=bomb.fork().trigger(Transform3D.IDENTITY,0,[])
	check(pulse.action=="detonated","Second trigger did not detonate the live missile")
	var expiry: RefCounted=bomb.fork()
	var result: Dictionary=expiry.advance(20000,[])
	check(result.action=="detonated" and not expiry.guided_live(),"Lifetime expiry did not end guidance with a blast")
	# Steering an unguided bomb does nothing.
	plain.advance(1,[]);plain.trigger(Transform3D.IDENTITY,1,[]);plain.set_steering(Vector2(0,1));plain.advance(500,[])
	check(plain.snapshot().shot.velocity.normalized().is_equal_approx(Vector3(0,0,1)) and not plain.guided_live(),"Ordinary bomb accepted guidance")
	var audio:=AudioResources.new()
	if not audio.configure(lib,bindings,21):check(false,audio.error)
	else:
		for id in [int(BombRules.GUIDED.launch_sound),int(BombRules.GUIDED.burst_sound)]:
			var sound:=audio.prepare(id)
			check(not sound.is_empty() and not sound.has("unsupported"),"Liberator sound could not be decoded: "+str(id)+" "+str(sound.get("unsupported",audio.error)))
	verify_owner(lib,bindings,cat)

## Owner path: fit, launch, steer, manual detonation with kill credit to 179.
func verify_owner(lib: RefCounted,bindings: RefCounted,cat: RefCounted) -> void:
	var built:=construction(bindings,cat,0.5)
	if built==null:return
	var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
	if group==null or not owner.configure(bindings,cat,equipped(bindings,cat,[{"item_id":LIBERATOR,"slot":0,"quantity":2}])):check(false,owner.error);return
	var targets:=[0,1,2,3]
	var actor: Dictionary=group.snapshot().actors[0]
	var pose:=Transform3D(Basis.IDENTITY,actor.position-Vector3(0,0,3000))
	var operation:=owner.evaluate_advance(10001,group,targets)
	if operation.is_empty():check(false,owner.error);return
	owner=operation.owner
	operation=owner.evaluate_trigger(pose,LIBERATOR,group,targets)
	if operation.is_empty():check(false,owner.error);return
	check(operation.events.size()==1 and operation.events[0].action=="launched" and operation.owner.guided_active(),"Owner did not launch a guided Liberator")
	owner=operation.owner;group=operation.combat
	# Guidance loop 1116 plays while the missile flies and stops on its blast.
	var audio:=FlightAudio.new();root.add_child(audio)
	if not audio.configure(lib,bindings,730):check(false,audio.error)
	var world:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":1,"actor_events":[],"secondaries":owner.snapshot(),"secondary_events":operation.events}
	var frame:=audio.prepare_frame(0,{"elapsed_ms":1},world)
	if frame.is_empty():check(false,"Guided launch audio frame rejected: "+audio.error)
	else:audio.commit_frame(frame)
	var loop: Dictionary=audio._players.get(FlightAudio.GUIDANCE_SOUND,{})
	check(not loop.is_empty() and loop.node.playing and loop.clip.looping and audio.snapshot().unsupported.is_empty(),"Guidance loop did not start with the guided missile")
	var steered: RefCounted=owner.steer_guided(Vector2(0,0.5))
	check(steered!=null and steered.guided_active() and owner.guided_camera_pose()!=Transform3D(),"Owner steering or camera unavailable")
	var hull: Variant=group.actor_snapshot(0).get("vitals",{}).get("hull")
	if hull is int and hull>1:
		var weakened: Dictionary=group.normal_hit(0,hull-1,true)
		check(not weakened.is_empty(),group.error)
	operation=owner.evaluate_trigger(pose,LIBERATOR,group,targets)
	if operation.is_empty():check(false,owner.error);return
	var event: Dictionary=operation.events[0] if operation.events.size()==1 else {}
	check(event.get("action")=="detonated" and event.get("item_id")==LIBERATOR and not event.normal_hits.is_empty(),"Manual Liberator blast did not hit nearby ships")
	var lethal: Array=operation.combat.career_snapshot().get("lethal_items",[])
	check(not lethal.is_empty() and lethal.all(func(row):return row.item_id==LIBERATOR),"Liberator kill was not credited to item 179: "+str(lethal)+" hull "+str(hull))
	check(not operation.owner.guided_active() and operation.owner.snapshot().nuclear_bomb_detonations==1,"Guidance outlived the blast or the kind-7 statistic missed it")
	world.elapsed_ms=2;world.secondaries=operation.owner.snapshot();world.secondary_events=operation.events
	frame=audio.prepare_frame(1,{"elapsed_ms":2},world)
	if frame.is_empty():check(false,"Detonation audio frame rejected: "+audio.error)
	else:audio.commit_frame(frame)
	check(not audio._players.has(FlightAudio.GUIDANCE_SOUND),"Guidance loop outlived the blast")
	audio.free()
	var gone: RefCounted=owner.discard_guided()
	check(not gone.guided_active() and owner.guided_active(),"Silent removal changed the parent owner or kept guidance")
