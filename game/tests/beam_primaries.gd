extends SceneTree
const Projectiles=preload("res://src/simulation/ordinary_projectiles.gd")
const Beam=preload("res://src/simulation/beam_primary.gd")
const Weapons=preload("res://src/simulation/weapon_loadout.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	check(args.size()==3,"Pass one content/binding/visual triple")
	if args.size()==3:verify(args[0],args[1])
	print("Beam primaries: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(content: String, pack: String) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var resolver:=Weapons.new()
	if not library.open(content) or not bindings.open(pack,library.manifest) or not cat.open(library) or not resolver.configure(bindings,cat,bindings.base_content_id):check(false,library.error+bindings.error+cat.error+resolver.error);return
	for item in [9,10,11]:
		var weapon:=resolver.resolve(item,[]);var owner:=Projectiles.new()
		if not owner.configure(weapon):check(false,owner.error);continue
		var mount:={"base_content_id":bindings.base_content_id,"category":0,"ship_id":0,"slot":0,"position":Vector3(100,20,30)}
		var pose:=Transform3D(Basis.IDENTITY,Vector3(500,0,0))
		var targets:=[target(0,pose.origin+Vector3(0,0,2000)),target(1,pose.origin+Vector3(0,0,900.8)),target(2,pose.origin+Vector3(0,0,900.2)),target(3,pose.origin+Vector3(0,0,100)),target(4,pose.origin+Vector3(0,0,200))]
		targets[3].vitals.hull=0;targets[4].active=false
		check(owner.fire_beam_from_mount(mount,pose,true,targets).get("reason")=="interval","Beam fired at exact initial cooldown")
		check(not owner.advance(1).is_empty(),owner.error)
		var parent:=owner.snapshot();var fork: RefCounted=owner.fork_state()
		var fired: Dictionary=fork.fire_beam_from_mount(mount,pose,true,targets)
		check(fired.get("fired",false) and fired.get("target_actor_id")==1,"Nearest live aim-window target or equal-distance ordering changed")
		if not fired.get("fired",false):continue
		check(fired.projectile.position==targets[1].pose.origin,"Beam did not place contact at the current target position")
		check(fired.projectile.velocity==Vector3.BACK,"Beam contact endpoint gained catalogue bolt speed")
		check(owner.snapshot()==parent,"Beam launch corrupted a retained parent")
		var shot: Dictionary=fork.snapshot().beam
		check(shot.length==900 and Beam.presentation(shot,false).origin==pose*mount.position,"Beam length or authored mount placement changed")
		var moved:=Transform3D(Basis(Vector3.UP,.3),Vector3(600,10,20))
		check(fork.observe_beam_pose(moved),fork.error)
		var observed: Dictionary=fork.snapshot().beam
		check(Beam.presentation(observed,false).origin==moved*mount.position and observed.direction==shot.direction and observed.length==shot.length,"Beam did not follow its moving mount with captured direction/length")
		check(fork.mark_impact(fired.projectile.id),fork.error)
		check(not fork.advance(0).is_empty() and fork.snapshot().slots[0]==null and not fork.snapshot().beam.is_empty(),"Hit cleanup discarded the visible beam fade")
		check(not fork.advance(weapon.interval_ms).is_empty(),fork.error)
		check(fork.fire_beam_from_mount(mount,moved,true,[]).get("reason")=="interval","Hit ignored strict refire interval")
		check(not fork.advance(1).is_empty(),fork.error)
		var miss: Dictionary=fork.fire_beam_from_mount(mount,moved,true,[])
		check(miss.get("fired",false) and miss.target_actor_id==-1,"Empty aim square failed to fire")
		var missed: Dictionary=fork.snapshot()
		check(miss.projectile.position.is_equal_approx(moved.origin+moved.basis.z*30000.0),"Unselected beam did not extend ahead of the ship")
		check(not fork.advance(1).is_empty() and fork.snapshot().slots[0].position.is_equal_approx(miss.projectile.position+moved.basis.z),"Uncontacted endpoint motion changed")
		if weapon.lifetime_ms>weapon.interval_ms+2:
			check(not fork.advance(weapon.interval_ms).is_empty(),fork.error)
			check(fork.fire_beam_from_mount(mount,moved,true,[]).get("reason")=="capacity","A miss released the single contact slot early")
		check(not fork.advance(weapon.lifetime_ms).is_empty(),fork.error)
		check(fork.fire_beam_from_mount(mount,moved,true,[]).get("fired",false),"Expired miss blocked the next beam")
		var before: Dictionary=fork.snapshot()
		check(fork.advance(-1).is_empty() and fork.snapshot()==before,"Rejected beam time corrupted retained state")
		fork.discard_flying()
		check(fork.snapshot().beam.is_empty() and fork.snapshot().slots[0]==null,"Discarding weapon effects left a beam behind")
		check(owner.snapshot()==parent,"Later beam frames corrupted the unfired parent")

func target(id: int, position: Vector3) -> Dictionary:
	return {"actor_id":id,"active":true,"pose":Transform3D(Basis.IDENTITY,position),"vitals":{"hull":100}}

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
