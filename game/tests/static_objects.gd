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
	finish()

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)

func finish() -> void:
	print("static_objects: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
