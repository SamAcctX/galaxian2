extends SceneTree
const Projectiles=preload("res://src/simulation/ordinary_projectiles.gd")
const Trail=preload("res://src/simulation/projectile_trail.gd")
const Pose=preload("res://src/presentation/projectile_pose.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const Timeline=preload("res://src/simulation/opening_timeline.gd")
const Contacts=preload("res://src/simulation/ordinary_npc_contacts.gd")
const VisualState=preload("res://src/simulation/projectile_visual_state.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==3,"Pass one content/binding/visual triple")
	if args.size()==3:verify(args[0],args[1])
	verify_trail()
	print("Thermal primaries: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(content: String, pack: String) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var resolver:=Weapons.new()
	if not library.open(content) or not library.select_language("gb") or not bindings.open(pack,library.manifest) or not cat.open(library) or not resolver.configure(bindings,cat,bindings.base_content_id):check(false,library.error+bindings.error+cat.error+resolver.error);return
	for item in [28,29,30]:
		var weapon:=resolver.resolve(item,[]);var owner:=Projectiles.new()
		if not owner.configure(weapon):check(false,owner.error);continue
		var mount:={"base_content_id":bindings.base_content_id,"category":0,"ship_id":0,"slot":0,"position":Vector3(100,20,30)}
		var pose:=Transform3D(Basis(Vector3.BACK,0.4),Vector3(500,0,0))
		check(owner.fire_forward_from_mount(mount,pose,true,{"state":1234}).get("reason")=="interval","Thermal cooldown fired at equality")
		check(not owner.advance(1).is_empty(),owner.error)
		var parent:=owner.snapshot();var fork: RefCounted=owner.fork_state()
		var fired: Dictionary=fork.fire_forward_from_mount(mount,pose,true,{"state":1234})
		check(fired.get("fired",false) and fired.has("random_state"),"Thermal launch did not consume its spread stream")
		if not fired.get("fired",false):continue
		check(fired.projectile.position.is_equal_approx(pose*(mount.position+Vector3(0,0,100))),"Thermal fitted muzzle differs from its ship mount")
		var first: Dictionary=fork.snapshot().slots[0]
		check(is_equal_approx(first.velocity.length(),weapon.speed_units_per_millisecond),"Thermal spread changed projectile speed")
		var target: Vector3=first.position+Vector3(10000,0,20000)
		check(not fork.advance(100,target).is_empty(),fork.error)
		var guided: Dictionary=fork.snapshot().slots[0]
		check(guided.position.is_equal_approx(first.position+first.velocity*100),"Guidance ran before ordinary movement")
		check(guided.velocity.normalized().dot((target-guided.position).normalized())>first.velocity.normalized().dot((target-guided.position).normalized()),"Acquired target did not bend the shot toward it")
		check(is_equal_approx(guided.velocity.length(),first.velocity.length()),"Guidance accelerated the projectile")
		check(not fork.advance(100).is_empty() and fork.snapshot().slots[0].velocity==guided.velocity,"Loss of guidance changed free-flight direction")
		var camera:=Transform3D(Basis(Vector3.UP,0.7),Vector3.ZERO)
		var draw:=Pose.sample(guided,3,camera,false,bindings.opening_staging.projectile_visuals,true,true)
		check(draw.get("visible",false) and draw.pose.basis.x.is_equal_approx(camera.basis.x),"Thermal body did not face the camera")
		check(fork.mark_impact(first.id),fork.error)
		check(not fork.advance(0).is_empty() and fork.snapshot().slots[0]==null,"Thermal impact left a live collision body")
		var tail: Dictionary=fork.snapshot().trails[0]
		check(not tail.emitting and not tail.sections.is_empty(),"Thermal impact erased its fading trail")
		check(not fork.advance(1001).is_empty() and fork.snapshot().trails[0].sections.is_empty(),"Detached trail failed to retire")
		check(owner.snapshot()==parent,"Thermal flight or impact corrupted an unfired parent")
		var before: Dictionary=fork.snapshot()
		check(fork.advance(1,Vector3(INF,0,0)).is_empty() and fork.snapshot()==before,"Invalid guidance changed retained projectile state")
		check(fork.fire_forward_from_mount(mount,pose,true,{"state":4321}).get("fired",false),"Expired thermal shot prevented slot reuse")
		check(fork.snapshot().trails[0].sections.size()==1,"Reused shot inherited an old trail")
		fork.discard_flying()
		check(fork.snapshot().trails.all(func(trail):return trail.is_empty()),"Clearing weapons left thermal trails")
		for steps in [[100],[7,7,6],[5,40,17,90]]:verify_timing(weapon,steps)
		verify_shared_contact(weapon,bindings,cat,library)

func verify_shared_contact(weapon: Dictionary, bindings: RefCounted, cat: RefCounted, library: RefCounted) -> void:
	var combat:=Combat.new();var timeline:=Timeline.new();var shots:=Projectiles.new()
	var counts:=[];counts.resize(23);counts.fill(1)
	if not combat.configure(bindings,cat,0.5) or not timeline.configure(bindings,cat,library,counts) or not shots.configure(weapon):check(false,combat.error+timeline.error+shots.error);return
	shots.advance(1)
	if not shots.fire(Vector3.ZERO,Vector3.BACK,true,{"state":1234}).get("fired",false):check(false,shots.error);return
	var scene: Dictionary=timeline.snapshot().scene;var radio: Dictionary=timeline.snapshot().radio
	radio.finished[7]=true
	for actor in scene.actors:
		actor.position=Vector3.ZERO;actor.erase("pose")
	if not combat.update(scene,3,radio):check(false,combat.error);return
	var before:=combat.snapshot();var before_shots:=shots.snapshot();var operation:=Contacts.new()
	var result:=operation.evaluate(shots,combat,[0])
	check(not result.is_empty(),"Fitted thermal gun was rejected by a different encounter: "+operation.error)
	if result.is_empty():return
	var damaged: Dictionary=result.combat.snapshot().actors[0]
	check(result.contacts.size()==1 and damaged.vitals.hull<before.actors[0].vitals.hull and damaged.get("systems")==before.actors[0].get("systems"),"Thermal contact failed to damage an opening target normally")
	check(combat.snapshot()==before and shots.snapshot()==before_shots,"Shared thermal contact changed its input frame")
	var animation:=VisualState.new()
	var world:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":0,"primaries":{"guns":[{"projectiles":shots.snapshot()}]}}
	check(animation.configure(bindings,library,world),"Fitted thermal model required a mission-specific declaration: "+animation.error)
	if not animation.snapshot().is_empty():check(animation.advance(100) and animation.snapshot().models[0].playing,"Thermal model did not animate in a shared world")

func verify_timing(weapon: Dictionary, steps: Array) -> void:
	var owner:=Projectiles.new()
	if not owner.configure(weapon):check(false,owner.error);return
	owner.advance(1)
	owner.fire(Vector3.ZERO,Vector3.BACK,true,{"state":789})
	var time:=0;var index:=0;var old:=owner.snapshot()
	while time<600:
		var dt:=int(steps[index%steps.size()]);index+=1;time+=dt
		if owner.advance(dt,Vector3(10000,0,20000) if time<200 else Vector3(-20000,0,30000)).is_empty():check(false,owner.error);return
	var current:=owner.snapshot()
	check(current.slots[0].velocity.x<0,"An acquired replacement did not redirect a shot already in flight")
	check(is_equal_approx(current.slots[0].velocity.length(),weapon.speed_units_per_millisecond),"Frame timing changed thermal speed")
	check(current.trails[0].sections.size()>1 and current.trails[0].sections.size()<=25,"Moving shot left no bounded ribbon history")
	check(old.slots[0].position==Vector3.ZERO and old.trails[0].sections.size()==1,"Later thermal frames mutated a captured observation")

func verify_trail() -> void:
	var trail:=Trail.new()
	check(trail.start(25,Transform3D.IDENTITY),trail.error)
	var slow:=Transform3D(Basis.IDENTITY,Vector3(0,0,50))
	check(trail.advance(51,slow) and trail.snapshot().sections.size()==1,"Stationary/short movement created a ribbon section")
	check(trail.advance(0,Transform3D(Basis.IDENTITY,Vector3(0,0,100))) and trail.snapshot().sections.size()==2,"Elapsed section did not wait for sufficient travel")
	var parent:=trail.snapshot();var fork: RefCounted=trail.fork_for_frame()
	check(fork.advance(100) and not fork.snapshot().emitting,"Stopped projectile continued emitting")
	check(trail.snapshot()==parent,"Detached trail ageing corrupted a paused parent")
	check(fork.advance(900) and not fork.snapshot().sections.is_empty(),"Trail vanished before its inclusive lifetime")
	check(fork.advance(1) and fork.snapshot().sections.is_empty(),"Expired trail retained live ribbon sections")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
