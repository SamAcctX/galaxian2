extends SceneTree
const Projectiles=preload("res://src/simulation/ordinary_projectiles.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Trail=preload("res://src/simulation/projectile_trail.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==3,"Pass one content/binding/visual triple")
	if args.size()==3:verify(args[0],args[1])
	verify_trail()
	print("Conventional projectiles: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(content: String, pack: String) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var resolver:=Weapons.new()
	if not library.open(content) or not bindings.open(pack,library.manifest) or not cat.open(library) or not resolver.configure(bindings,cat,bindings.base_content_id):check(false,library.error+bindings.error+cat.error+resolver.error);return
	for item in range(31,41):
		var weapon:=resolver.resolve(item,[]);var owner:=Projectiles.new()
		if not owner.configure(weapon):check(false,owner.error);continue
		var mount:={"base_content_id":bindings.base_content_id,"category":1,"ship_id":0,"slot":0,"position":Vector3(100,20,30)}
		var pose:=Transform3D(Basis(Vector3.BACK,0.4),Vector3(500,0,0))
		check(not owner.fire_forward_from_mount(mount,pose,true).get("fired",false),"Launcher fired at cooldown equality")
		check(not owner.advance(1).is_empty(),owner.error)
		var parent:=owner.snapshot();var fork: RefCounted=owner.fork_state()
		var fired: Dictionary=fork.fire_forward_from_mount(mount,pose,true)
		check(fired.get("fired",false) and not fired.has("random_state"),"Conventional launch failed or used spread")
		if not fired.get("fired",false):continue
		var first: Dictionary=fired.projectile
		check(first.position.is_equal_approx(pose*(mount.position+Vector3(0,0,100))) and first.up==pose.basis.y,"Secondary did not use its authored muzzle and firing up axis")
		check(first.velocity.is_equal_approx(pose.basis.z*weapon.speed_units_per_millisecond),"Rocket or missile launched with spread")
		var target: Vector3=first.position+Vector3(10000,0,20000)
		check(not fork.advance(100,target).is_empty(),fork.error)
		var moved: Dictionary=fork.snapshot().slots[0]
		check(moved.position.is_equal_approx(first.position+first.velocity*100),"Guidance preceded projectile movement")
		check(is_equal_approx(moved.velocity.length(),first.velocity.length()),"Guidance changed missile speed")
		check(moved.velocity.x>first.velocity.x if item>=36 else moved.velocity==first.velocity,"Missile failed to guide, or rocket incorrectly guided")
		check(not fork.advance(1).is_empty() and fork.snapshot().slots[0].velocity==moved.velocity,"Losing the target changed heading")
		check(fork.mark_impact(first.id),fork.error)
		check(not fork.advance(0).is_empty() and fork.snapshot().slots[0]==null,"Impact retained a missile body")
		check(not fork.snapshot().trails[0].emitting and not fork.snapshot().trails[0].sections.is_empty(),"Impact erased the exhaust immediately")
		check(owner.snapshot()==parent,"Secondary movement or impact changed the previous frame")
		var wrong_mount:=mount.duplicate();wrong_mount.category=0
		check(owner.fire_forward_from_mount(wrong_mount,pose,true).is_empty() and owner.snapshot()==parent,"Secondary fired from a primary attachment")
		verify_retention(weapon)

func verify_retention(resolved: Dictionary) -> void:
	# A compact clock makes capacity and the post-lifetime window observable
	# without depending on a catalogue weapon's particular firing cadence.
	var weapon:=resolved.duplicate(true);weapon.interval_ms=1;weapon.lifetime_ms=1000
	var owner:=Projectiles.new()
	if not owner.configure(weapon):check(false,owner.error);return
	for index in 5:
		owner.advance(2)
		check(owner.fire(Vector3.ZERO,Vector3.BACK,true).get("fired",false),"Launcher could not fill its five retained slots")
	owner.advance(2)
	check(owner.fire(Vector3.ZERO,Vector3.BACK,true).get("reason")=="capacity","Sixth simultaneous projectile exceeded capacity")
	var first: Dictionary=owner.snapshot().slots[0]
	owner.advance(first.remaining_ms+1999)
	check(owner.snapshot().available_slots==0 and owner.snapshot().slots[0].remaining_ms==-1999,"Natural expiry freed the launch slot before retained travel ended")
	var position: Vector3=owner.snapshot().slots[0].position
	owner.advance(1)
	check(owner.snapshot().available_slots==1 and owner.snapshot().slots[0].position.z>position.z,"Retained missile stopped moving or failed to free its slot at the boundary")
	check(owner.fire(Vector3.ZERO,Vector3.BACK,true).get("fired",false) and owner.snapshot().trails[0].sections.size()==1,"Reused missile inherited retired trail history")
	var id: int=owner.snapshot().slots[0].id
	owner.mark_impact(id);owner.advance(2)
	check(owner.fire(Vector3.ZERO,Vector3.BACK,true).get("fired",false),"Collision blocked immediate slot reuse after cooldown")
	owner.discard_flying()
	check(owner.snapshot().slots.all(func(slot):return slot==null) and owner.snapshot().trails.all(func(trail):return trail.is_empty()),"Discarding launchers left bodies or exhaust")

func verify_trail() -> void:
	var trail:=Trail.new()
	check(trail.start(39,Transform3D.IDENTITY),trail.error)
	trail.advance(50,Transform3D(Basis.IDENTITY,Vector3(0,0,100)))
	check(is_equal_approx(trail.snapshot().sections[0].uv_fraction,0.4),"Growing exhaust stretched the full texture immediately")
	trail.advance(75,Transform3D(Basis.IDENTITY,Vector3(0,0,500)))
	check(trail.snapshot().sections.size()==1,"Exhaust split at the inclusive interval boundary")
	trail.advance(1,Transform3D(Basis.IDENTITY,Vector3(0,0,510)))
	check(trail.snapshot().sections.size()==2 and trail.snapshot().sections[-1].uv_fraction==0.0,"Moving exhaust failed to start a fresh texture section")
	var before:=trail.snapshot();var fork: RefCounted=trail.fork_for_frame()
	fork.advance(1999)
	check(not fork.snapshot().sections.is_empty() and not fork.snapshot().emitting,"Stopped rocket exhaust vanished too soon")
	fork.advance(1)
	check(fork.snapshot().sections.is_empty() and trail.snapshot()==before,"Stopped exhaust did not retire independently of its parent")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
