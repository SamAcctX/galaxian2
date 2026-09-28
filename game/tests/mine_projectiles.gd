extends "res://tests/emp_bombs.gd"
## Detached catalogue-backed mine physics. Inventory and career acceptance are
## exercised separately through the actual fitted secondary owner.
const Mines=preload("res://src/simulation/mine_projectiles.gd")

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Mine projectiles: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib):check(false,lib.error+bindings.error+cat.error);return
	var catalogue: Dictionary=cat.tables.duplicate(true)
	verify_launch(bindings,cat)
	verify_drift(bindings,cat)
	verify_contacts(bindings,cat)
	verify_blasts(bindings,cat)
	verify_rejection(bindings,cat)
	check(cat.tables==catalogue,"Mine operations modified imported catalogue prototypes")

func ready_mine(bindings: RefCounted,cat: RefCounted,item:=60,muzzle:=Vector3.ZERO) -> RefCounted:
	var mine:=Mines.new()
	if not mine.configure(bindings,cat,item,[],muzzle):check(false,mine.error);return null
	if mine.advance(1,[]).is_empty():check(false,mine.error);return null
	return mine

func verify_launch(bindings: RefCounted,cat: RefCounted) -> void:
	var mine:=Mines.new()
	check(mine.configure(bindings,cat,60,[],Vector3(20,-30,400)),mine.error)
	var state:=mine.snapshot()
	check(mine.trigger(Transform3D.IDENTITY,10).action=="none" and mine.snapshot()==state,"Mine launched at initial cooldown equality")
	check(not mine.advance(1,[]).is_empty(),mine.error)
	var pose:=Transform3D(Basis(Vector3.UP,PI/2),Vector3(5,10,15))
	var launch:=mine.trigger(pose,10)
	check(launch.action=="launched" and launch.ammunition_consumed==1 and launch.shot.position.is_equal_approx(pose*Vector3(20,-30,400)),"Mine lost its rotated authored muzzle or one-round consumption")
	check(launch.shot.velocity.is_equal_approx((pose.basis.z+pose.basis.y).normalized()*2),"Mine did not launch along ship forward plus up")
	check(mine.trigger(pose,9).action=="none","Second press remotely detonated a mine")
	check(not mine.advance(1000,[]).is_empty() and mine.trigger_action(9)=="none","Mine fired at exact cooldown equality")
	check(not mine.advance(1,[]).is_empty() and mine.trigger_action(9)=="launched",mine.error)
	state=mine.snapshot()
	check(mine.trigger(pose,0).action=="none" and mine.trigger(pose,9,false).action=="none" and mine.snapshot()==state,"Blocked or empty launcher changed its deployed mines")
	var branch: RefCounted=mine.fork()
	check(branch.trigger(pose,9).action=="launched" and mine.snapshot()==state,"Speculative mine launch changed the parent")
	for unused in 8:
		check(not branch.advance(1001,[]).is_empty() and branch.trigger(pose,10).action=="launched",branch.error)
	check(branch.snapshot().slots.filter(func(shot):return shot!=null).size()==10,"Launcher lost one of ten retained mines")
	check(not branch.advance(1001,[]).is_empty() and branch.trigger_action(10)=="none","Full mine launcher bypassed its capacity")
	check(branch.advance(40000,[]).blasts.is_empty() and branch.snapshot().slots.all(func(shot):return shot==null),"Unused mines detonated on lifetime expiry")
	check(branch.trigger(pose,1).shot.id==11,"Expired slot could not be reused with a fresh projectile handle")
	for id in [60,61,62]:
		var ordinary:=Mines.new();var upgraded:=Mines.new()
		var modifiers: Array=[]
		for item in cat.tables.items:
			if item.properties.get(2)==26:modifiers.append(int(item.id))
		check(ordinary.configure(bindings,cat,id,[]) and upgraded.configure(bindings,cat,id,modifiers),ordinary.error+upgraded.error)
		check(ordinary.snapshot().weapon.damage==upgraded.snapshot().weapon.damage and ordinary.snapshot().weapon.interval_ms==upgraded.snapshot().weapon.interval_ms,"Primary gun upgrades changed secondary mine damage or cooldown")

func verify_drift(bindings: RefCounted,cat: RefCounted) -> void:
	var mine: RefCounted=ready_mine(bindings,cat)
	if mine==null:return
	var launch: Dictionary=mine.trigger(Transform3D.IDENTITY,1)
	var angles: Vector3=launch.shot.angles
	for unused in 5:check(not mine.advance(100,[]).is_empty(),mine.error)
	var settled: Dictionary=mine.snapshot().slots[0]
	check(is_equal_approx(settled.position.length(),400.0),"Unattracted mine did not decelerate during its first half-second")
	check(not mine.advance(1000,[]).is_empty() and mine.snapshot().slots[0].position==settled.position,"A settled mine kept drifting")
	for axis in 3:
		check(is_equal_approx(mine.snapshot().slots[0].angles[axis]-angles[axis],0.75*(1 if angles[axis]>=0 else -1)),"Mine tumble clock did not progress with accepted time")
	var before: Dictionary=mine.snapshot()
	var detached: Dictionary=mine.snapshot();detached.slots[0].position=Vector3.ONE
	check(mine.snapshot()==before,"External presentation mutated a deployed mine")
	for steps in [[100,100,100,100,100],[7,7,6],[3,21,9,16,5]]:
		var timed: RefCounted=ready_mine(bindings,cat)
		if timed==null:return
		timed.trigger(Transform3D.IDENTITY,1)
		var elapsed:=0;var index:=0
		while elapsed<700:
			var delta: int=mini(700-elapsed,steps[index%steps.size()])
			if timed.advance(delta,[]).is_empty():check(false,timed.error);break
			elapsed+=delta;index+=1
		var end: Dictionary=timed.snapshot().slots[0]
		check(end.position.length()>=390 and end.position.length()<501 and end.remaining_ms==39300,"Fixed, high or variable steps lost mine settling or elapsed lifetime")
		check(timed.advance(39300,[]).blasts.is_empty() and timed.snapshot().slots[0]==null,"A timed-out mine emitted damage at a different frame rate")

func verify_contacts(bindings: RefCounted,cat: RefCounted) -> void:
	var mine: RefCounted=ready_mine(bindings,cat)
	if mine==null:return
	mine.trigger(Transform3D.IDENTITY,1);mine.advance(500,[])
	var far:=mine_target(0,Vector3(0,0,2000))
	var friendly:=mine_target(1,Vector3(0,0,1000),false)
	var dead:=mine_target(2,Vector3(0,0,1000));dead.collision.eligible=false
	var inactive:=mine_target(3,Vector3(0,0,1000));inactive.active=false
	var position: Vector3=mine.snapshot().slots[0].position
	check(mine.advance(100,[far,friendly,dead,inactive]).attraction.is_empty() and mine.snapshot().slots[0].position==position,"A distant, friendly, dead or inactive target attracted a mine")
	var point:=mine_target(0,Vector3(0,0,1000));point.collision.path="point_geometry"
	point.collision.boxes=[{"offset":Vector3.ZERO,"half_extents":Vector3.ONE}]
	check(mine.advance(100,[point]).attraction.is_empty() and mine.snapshot().slots[0].position==position,"Negative point geometry fell back to broad mine bounds")
	var x_target:=mine_target(4,Vector3(1000,0,0))
	var z_target:=mine_target(5,Vector3(0,0,1000))
	var attracted: Dictionary=mine.advance(7,[x_target,z_target])
	check(attracted.attraction=={"projectile_id":1,"actor_id":4} and mine.snapshot().slots[0].position==Vector3(200,0,0),"Mine attraction lost target order or its discrete approach step")
	var pulse: Dictionary
	for unused in 4:pulse=mine.advance(7,[x_target])
	check(pulse.action=="detonated" and pulse.blasts.size()==1,"Attracted mine did not detonate on close contact")
	check(mine.advance(7,[x_target]).blasts.is_empty() and mine.snapshot().slots[0]==null,"Consumed mine delivered a repeated contact pulse")
	var immediate: RefCounted=ready_mine(bindings,cat)
	if immediate==null:return
	immediate.trigger(Transform3D.IDENTITY,1)
	check(immediate.advance(1,[mine_target(0,Vector3.ZERO)]).blasts.size()==1,"A made-up arming timer blocked immediate mine contact")
	for steps in [[100],[7,7,7,6],[3,29,5,17]]:
		var pursuit: RefCounted=ready_mine(bindings,cat)
		if pursuit==null:return
		pursuit.trigger(Transform3D.IDENTITY,1);pursuit.advance(500,[])
		var detonated:=false
		for index in 8:
			var event: Dictionary=pursuit.advance(steps[index%steps.size()],[mine_target(0,Vector3(0,0,1000))])
			if not event.blasts.is_empty():detonated=true;break
		check(detonated,"Mine pursuit failed at a supported frame rate")

func verify_blasts(bindings: RefCounted,cat: RefCounted) -> void:
	var mine: RefCounted=ready_mine(bindings,cat)
	if mine==null:return
	for index in 3:
		mine.trigger(Transform3D(Basis.IDENTITY,Vector3(index*10000,0,0)),3-index)
		mine.advance(1001,[])
	var source:=mine_target(0,Vector3.ZERO)
	var friendly:=mine_target(1,Vector3(10500,0,0),false)
	var scenery:=mine_target(2,Vector3(10500,0,0),false);scenery.emp_immune=true;scenery.target={"group":"scenery","index":3}
	var before: Dictionary=mine.snapshot();var branch: RefCounted=mine.fork()
	var event: Dictionary=branch.advance(100,[source,friendly,scenery])
	check(event.blasts.size()==2 and branch.snapshot().slots[2].phase=="flying" and mine.snapshot()==before,"Launcher-wide pulse omitted collateral mines, consumed an isolated mine or mutated its parent")
	if event.blasts.size()==2:
		var hits: Array=event.blasts[1].hits
		check(hits.size()==2 and hits[0].normal_damage==332 and hits[1].normal_damage==199 and hits[1].target==scenery.target,"Mine collateral damage lost its fixed falloff or reduced scenery damage")
		check(hits[1].impact_vector==Vector3.RIGHT and is_equal_approx(hits[1].motion_scalar,0.95),"Mine outward motion incorrectly used reduced scenery damage")
	for item in [60,61,62]:
		var variant: RefCounted=ready_mine(bindings,cat,item)
		if variant==null:return
		variant.trigger(Transform3D.IDENTITY,1)
		var radius: int=variant.snapshot().weapon.radius
		var inside:=mine_target(1,Vector3(radius-0.25,0,0),false)
		var outside:=mine_target(2,Vector3(radius,0,0),false)
		var disabled:=mine_target(3,Vector3.ZERO,false);disabled.active=false
		var result: Dictionary=variant.advance(1,[mine_target(0,Vector3.ZERO),inside,outside,disabled])
		var hits: Array=result.blasts[0].hits
		check(hits.size()==2 and hits[1].distance==radius-1,"Mine radius was inclusive, untruncated, or included an inactive target")
		if item==61:check(hits[0].normal_damage==0 and hits[0].system_damage==500 and hits[1].system_damage==390,"EMP mine damaged hull or lost its systems-only radial pulse")
		else:check(hits[0].system_damage==0 and hits[1].normal_damage>0,"Normal mine omitted near-edge damage or invented EMP damage")

func verify_rejection(bindings: RefCounted,cat: RefCounted) -> void:
	var mine: RefCounted=ready_mine(bindings,cat)
	if mine==null:return
	mine.trigger(Transform3D.IDENTITY,1)
	var before: Dictionary=mine.snapshot()
	for delta in [-1,0.5,NAN,INF]:check(mine.advance(delta,[]).is_empty() and mine.snapshot()==before,"Invalid mine clock changed accepted state")
	var missing:=mine_target(0,Vector3.ZERO);missing.erase("mine_sensitive")
	var corrupt:=mine_target(0,Vector3(INF,0,0))
	var geometry:=mine_target(0,Vector3.ZERO);geometry.collision.half_extent=-1
	var duplicate:=mine_target(0,Vector3.ZERO)
	for targets in [[missing],[corrupt],[geometry],[duplicate,duplicate],[duplicate,mine_target(1,Vector3(1e30,0,0),false)]]:
		check(mine.advance(1,targets).is_empty() and mine.snapshot()==before,"Rejected mine geometry or blast partly mutated deployed mines")
	check(not mine.configure(bindings,cat,44,[]) and mine.snapshot()==before,"An area bomb silently replaced a mine launcher")
	var detached: RefCounted=mine.fork();detached.discard_flying()
	check(detached.snapshot().slots.all(func(shot):return shot==null) and mine.snapshot()==before,"Departure cleanup corrupted a retained mine frame")

static func mine_target(id: int,position: Vector3,sensitive:=true) -> Dictionary:
	return {"actor_id":id,"position":position,"active":true,"emp_immune":false,"mine_sensitive":sensitive,
		"collision":{"eligible":true,"path":"bounds","center":position,"half_extent":300}}
