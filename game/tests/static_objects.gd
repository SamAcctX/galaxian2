extends SceneTree
## The Valkyrie pirate outpost as a cast static object: imported art and
## collision, hull, sleep/wake, damage and destruction with its wreck.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Statics=preload("res://src/content/static_object_definitions.gd")
const Actor=preload("res://src/simulation/opening_combat_actor.gd")
const Death=preload("res://src/simulation/static_object_destruction.gd")
const Geometry=preload("res://src/simulation/ordinary_hit_geometry.gd")
const Turret=preload("res://src/simulation/static_turret.gd")
const Combat=preload("res://src/content/contract_ship_combat_definitions.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()<2:check(false,"Expected content and bindings");finish();return
	var lib:=Library.new();var bindings:=Bindings.new()
	check(lib.open(args[0]),lib.error)
	check(bindings.open(args[1],lib.manifest,lib),bindings.error)
	if failures:finish();return
	var reader:=Statics.new()
	var outpost:=reader.resolve(lib,bindings,14243)
	check(not outpost.is_empty(),reader.error)
	if outpost.is_empty():finish();return
	print(outpost.layers.map(func(layer):return layer.path),outpost.wreck,outpost.boxes.size())
	check(outpost.boxes.size()==12,"Record 1002 lost shapes")
	check(outpost.layers[0].path.ends_with("station_pirates.aem") and outpost.wreck.path.ends_with("station_pirates_explosion_anim.aem"),"Outpost art changed")
	check(reader.resolve(lib,bindings,999).is_empty(),"Unknown static models must be refused")
	check(Statics.hull(14243,20,63,0.5)==2500 and Statics.hull(14243,20,63,1.0)==3750 and Statics.hull(14243,5,63,0.5)==1375,"Outpost hull formula")
	# Pirate outpost of mission 63: asleep, hostile, level 20, normal difficulty.
	var data: Dictionary=bindings.combat_training_control.duplicate(true)
	data.merge({"campaign_cursor":63,"station_id":103,"rank":20,"difficulty":0.5,"actor_policies":[{"initial_hostile":true,"updated_hostile":true,"friendly":false}]},true)
	var body:=Transform3D(Basis.IDENTITY,Vector3(4000,-3000,2000))
	var row:={"actor_id":0,"actor_kind":8,"hull_catalogue_id":-1,"subtype":0,"population_group":"static","static_model":14243,"resource_id":14243,
		"hull_override":Statics.hull(14243,20,63,0.5),"name_text_id":430,"mode":5,"active":false,"targeting_blocked":true,"body_pose":body,"statistics_pose":body}
	var actor:=Actor.new()
	check(actor._configure_static(bindings,data,row,0) and actor.enable_contract_combat(bindings),actor.error)
	if failures:finish();return
	var state: Dictionary=actor.snapshot()
	check(state.vitals.hull==2500 and state.max_hull==2500 and state.name_text_id==430 and state.hostile and state.hull_resource==outpost.layers[0].path,"Outpost body, hull, name or hostility")
	check(not actor.collision_context().eligible,"A sleeping outpost without geometry must not be hittable")
	check(actor.set_static_geometry(outpost.boxes) and not actor.set_static_geometry(outpost.boxes),"Geometry is set exactly once")
	check(not actor.collision_context().eligible,"A sleeping outpost cannot be hit")
	actor.normal_hit(500)
	check(actor.snapshot().vitals.hull==2500,"Sleeping outpost took damage")
	check(Statics.within_reach(body.origin,body.origin+Vector3(49000,-49000,49000),50000.0) and not Statics.within_reach(body.origin,body.origin+Vector3(10000,60000,0),50000.0),"Wake range is 50 km on every axis")
	check(actor.wake_static() and actor.snapshot().active and actor.snapshot().actor_mode==1,"Outpost did not wake")
	var context: Dictionary=actor.collision_context()
	check(context.eligible and context.path=="point_geometry" and context.boxes.size()==12,"Awake outpost lost its collision boxes")
	var geometry:=Geometry.new()
	var inside: Dictionary=geometry.box_geometry(body.origin+outpost.boxes[0].offset,context.center,context.boxes)
	var outside: Dictionary=geometry.box_geometry(body.origin+Vector3(0,60000,0),context.center,context.boxes)
	check(inside.get("hit")==true and outside.get("hit")==false,"Outpost collision boxes misplaced")
	actor.normal_hit(100)
	check(actor.snapshot().vitals.hull==2400,"Awake outpost ignores hits: "+actor.error)
	# Destruction: sound, wreck animation, then a resting wreck.
	var death:=Death.new()
	check(death.setup({"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":63},0,body,outpost,1000),death.error)
	var calm: Dictionary=death.advance(16,actor.snapshot())
	check(not calm.is_empty() and not calm.started and calm.state.phase=="ready",death.error)
	actor.normal_hit(999999)
	var lethal: Dictionary=death.advance(16,actor.snapshot())
	check(lethal.get("started",false) and lethal.sound_events==[20] and lethal.state.mode==3,"Lethal update lost its sound or phase: "+death.error)
	check(actor.apply_static_destruction(death) and actor.snapshot().actor_mode==3 and not actor.snapshot().active and not actor.snapshot().model_draw_enabled,"Body not replaced by its wreck: "+actor.error)
	var frames:=0
	while death.snapshot().phase=="wrecking" and frames<40:
		var step: Dictionary=death.advance(1000,actor.snapshot())
		if step.is_empty() or step.started:break
		frames+=1
	check(death.snapshot().phase=="wreck" and death.snapshot().mode==4 and frames==20,"Wreck animation should end after 20 s, took %d"%frames)
	check(actor.apply_static_destruction(death) and actor.snapshot().actor_mode==4,"Wreck rest mode")
	var cat:=Catalogues.new()
	check(cat.open(lib),cat.error)
	if not failures:turret(lib,bindings,cat,data)
	pirate_bases(bindings)
	finish()

## The outposts stand from a new game: base-game careers meet them too, and
## their stations stay unmanned until each is destroyed.
func pirate_bases(bindings: RefCounted) -> void:
	var Flights=load("res://src/content/valkyrie_flight_definitions.gd")
	var Campaign=load("res://src/content/valkyrie_campaign_definitions.gd")
	# Without the expansion content there is no outpost, so nothing may block docking.
	check(not Campaign.available(bindings) or not Flights.story_job(bindings,20,33,{}).is_empty(),"Expansion pack lost its pirate base")
	check(Flights.story_job(bindings,20,33,{"pirate_bases":2}).get("pirate_base")==null,"A destroyed base returned")
	# A Most Wanted criminal fires his gun at x4 damage; his wingmen do not.
	var job:={"campaign_cursor":131,"station_id":5,"wanted":{"index":2,"hull":6500,"after":{},"stats":{"ship":21,"name":"Gendol Ethor","loot":[137,2],"wingmen":1,"reward":75000}}}
	var recipe: Dictionary=Flights._wanted_recipe(job)
	var cast:={"rival_actor_id":-1,"ship_state":{},"ship_groups":recipe.get("ship_groups",[])}
	var Recipe=load("res://src/content/mission_recipe.gd")
	check(int(Recipe.contract_ship_options(cast,0,8,0).gun_damage_scale)==4 and int(Recipe.contract_ship_options(cast,1,8,0).gun_damage_scale)==1,"The wanted criminal's gun is not x4 (or his wingman's is)")
	var live: bool=Campaign.available(bindings)
	check(Flights.unmanned_station(bindings,33,{})==live and not Flights.unmanned_station(bindings,33,{"pirate_bases":2}) and Flights.unmanned_station(bindings,1,{"pirate_bases":2})==live and not Flights.unmanned_station(bindings,4,{}),"Unmanned stations do not follow the outposts")

## 80's weak-point turret: picks the player within 50 km every 3 s, turns at
## one turn per 4.096 s, fires only on aim, with its own 1.7x gun.
func turret(lib: RefCounted,bindings: RefCounted,cat: RefCounted,data: Dictionary) -> void:
	var reader:=Statics.new();var placed:=reader.resolve(lib,bindings,14363)
	check(not placed.is_empty() and placed.turret.path.ends_with("turret_gun.aem") and placed.turret.offset==Vector3(0,565,-528),"Turret barrel art: "+reader.error)
	var rule: Dictionary=Statics.rules(14363).turret
	check(Statics.rules(14365).get("turret",{}).is_empty(),"The shield never aims")
	# Mounted on an arm rolled 90 degrees, like the recipe's weak points.
	var body:=Transform3D(Basis.from_euler(Vector3(0,0,1.5708)),Vector3(-3995,23359,152622))
	var row:={"actor_id":0,"actor_kind":8,"hull_catalogue_id":-1,"subtype":0,"population_group":"static","static_model":14363,"resource_id":14363,
		"hull_override":Statics.hull(14363,20,80,0.5),"name_text_id":1655,"mode":1,"active":true,"targeting_blocked":false,"body_pose":body,"statistics_pose":body}
	var actor:=Actor.new()
	check(actor._configure_static(bindings,data,row,0),actor.error)
	var aim: Dictionary=actor.snapshot().get("turret_aim",{})
	check(aim==Turret.initial(),"Turret actor lacks its aim state")
	var far:=[{"actor_id":-1,"position":body.origin+Vector3(0,0,-60000),"forward":Vector3.FORWARD}]
	# The arm's outward side is world -X here: the player above the turret.
	var near:=[{"actor_id":-1,"position":body.origin+Vector3(-20000,-15000,-25000),"forward":Vector3(0,0,1)}]
	# Under the arm the barrel stops at its ~9 degree depression and holds fire.
	var below:=[{"actor_id":-1,"position":body.origin+Vector3(20000,-15000,-25000),"forward":Vector3(0,0,1)}]
	var held: Dictionary=Turret.advance(aim,rule,body,below,3001)
	var held_fire:=false
	for frame in 400:
		held=Turret.advance(held.aim,rule,body,below,16);held_fire=held_fire or held.fire
	check(not held_fire and is_equal_approx(held.aim.pitch,TAU*100.0/4096.0),"A target under the arm must not be hit (pitch %f)"%held.aim.pitch)
	var step: Dictionary=Turret.advance(aim,rule,body,near,2900)
	check(step.target_id==-2 and not step.fire,"Turret picked before its first 3 s")
	step=Turret.advance(step.aim,rule,body,far,200)
	check(step.target_id==-2,"Turret picked a target beyond 50 km")
	step=Turret.advance(step.aim,rule,body,near,2990)
	check(step.target_id==-2,"Turret picked again before 3 s")
	step=Turret.advance(step.aim,rule,body,near,16)
	check(step.target_id==-1,"Turret did not pick the player within 50 km")
	var before: Dictionary=step.aim
	step=Turret.advance(before,rule,body,near,100)
	var turn:=TAU*100.0/4096.0
	check(absf(angle_difference(before.yaw,step.aim.yaw))<=turn+0.0001 and absf(step.aim.pitch-before.pitch)<=turn+0.0001,"Turret turned faster than 88 deg/s")
	check(absf(angle_difference(before.yaw,step.aim.yaw))>turn*0.99 or absf(step.aim.pitch-before.pitch)>turn*0.99,"Turret did not turn at full rate")
	var fired_after:=-1
	for frame in 300:
		step=Turret.advance(step.aim,rule,body,near,16)
		if step.fire:fired_after=frame;break
	check(fired_after>=0 and fired_after<200,"Turret never came on aim")
	var point: Vector3=near[0].position+Vector3(near[0].forward)*1500.0
	var axis: Vector3=step.barrel.basis.z.normalized()
	check(axis.dot((point-step.barrel.origin).normalized())>0.99,"Turret fired off its aim")
	print("turret on aim after %d frames, yaw %.3f pitch %.3f"%[fired_after,step.aim.yaw,step.aim.pitch])
	check(actor.set_turret_aim(step.aim) and actor.snapshot().turret_aim==step.aim,"Aim state not retained: "+actor.error)
	# Its gun: item 20, shot 6796, ordinary level 20 race-8 damage x1.7.
	var plain:=Combat.shared_weapon(Combat.VALUES.weapons,45,20,0.5,8)
	var gun:=Combat.turret_weapon(Combat.VALUES.weapons,45,20,0.5,8,rule.weapon)
	check(gun.item_id==20 and gun.model_resource_id==6796 and gun.damage==int(plain.damage*1.7) and gun.damage>plain.damage and gun.interval_ms==510,"Turret gun: %s"%gun)
	gun.merge({"actor_id":0,"actor_kind":8,"hull_catalogue_id":-1},true)
	var weapons:=Weapons.new()
	check(weapons._configure_rows(bindings,cat,[gun],80),weapons.error)
	if failures:return
	weapons._guns[0].advance(16)
	var shot: Dictionary=weapons._guns[0].fire(step.barrel.origin,step.barrel.basis.z,true)
	check(shot.get("fired",false),"Turret gun did not fire: %s"%weapons._guns[0].error)
	weapons._guns[0].advance(1000)
	var slot: Variant=weapons._guns[0].snapshot().slots.filter(func(entry):return entry!=null)
	check(slot.size()==1 and slot[0].position.distance_to(step.barrel.origin)>15000.0 and int(weapons._guns[0].snapshot().weapon.damage)==gun.damage,"Turret shot did not travel with its damage")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)

func finish() -> void:
	print("static_objects: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
