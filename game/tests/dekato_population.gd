extends SceneTree
## Detached construction components, not an earned cursor38 career or arrival.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Rules=preload("res://src/content/dekato_convoy_definitions.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Route=preload("res://src/simulation/npc_route.gd")
const World=preload("res://src/simulation/opening_world_initialization.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Motion=preload("res://src/simulation/freighter_motion.gd")
const Geometry=preload("res://src/presentation/ship_geometry.gd")
const CONDITIONS={"companions_empty":true,"location_match":false,"special_placement":false}
var checks:=0
var failures:=0
var captures:=""

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()%3==1:captures=args.pop_back()
	check(not args.is_empty() and args.size()%3==0,"Expected explicit content/binding/visual triples")
	for i in range(0,args.size()-2,3):await verify(args[i],args[i+1],args[i+2])
	print("Dekato population: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(content: String,pack: String,art: String) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(content) or not bindings.open(pack,library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":38,"station_id":22,"system_id":4,
		"mission_kind":4,"mission_story":true,"mission_completed":false,"mission_failed":false,"rank":10,"difficulty":0.5}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":22,"system_id":4,"ship_id":0,"equipment_ids":[]}
	if not Rules.available(bindings):
		check(not Factory.new().configure_dekato(bindings,cat,seed,context),"Earlier pack admitted the Dekato cast")
		check(not World.new().configure_dekato(bindings,cat,seed,context,CONDITIONS),"Earlier pack admitted the Dekato world")
		check(not Route.new().configure_dekato_generated(bindings,2),"Earlier pack admitted a Dekato route")
		return
	var rules:=Rules.construction_recipe(bindings,context)
	check(not rules.is_empty(),"Source-bound construction recipe unavailable")
	if rules.is_empty():return
	for key in ["binding_id","base_content_id","station_id","system_id","campaign_cursor","mission_kind","mission_story","mission_completed","mission_failed","rank","difficulty"]:
		var bad:=context.duplicate(true)
		bad[key]={"binding_id":"foreign","base_content_id":"foreign","station_id":27,"system_id":5,"campaign_cursor":39,"mission_kind":11,
			"mission_story":false,"mission_completed":true,"mission_failed":true,"rank":21,"difficulty":0.75}[key]
		check(not Factory.new().configure_dekato(bindings,cat,seed,bad),"Invalid Dekato context admitted: "+key)
	for key in ["binding_id","base_content_id","station_id","system_id","ship_id","equipment_ids"]:
		var bad:=seed.duplicate(true)
		bad[key]={"binding_id":"foreign","base_content_id":"foreign","station_id":27,"system_id":5,"ship_id":-1,"equipment_ids":[-1]}[key]
		check(not Factory.new().configure_dekato(bindings,cat,bad,context),"Invalid Dekato loadout admitted: "+key)
	for id in range(-1,9):check(Route.new().configure_dekato_generated(bindings,id)==(id>=2 and id<7),"Wrong Dekato route scope: "+str(id))
	var bad_entry:=CONDITIONS.duplicate();bad_entry.companions_empty=false
	check(not World.new().configure_dekato(bindings,cat,seed,context,bad_entry),"Dekato ignored extra companion population")
	var shown:={}
	var cargo_rows:=0
	for number in [1,42,4096,2147483647]:
		var owner:=Factory.new()
		if not owner.configure_dekato(bindings,cat,seed,context):check(false,owner.error);return
		var configured:=owner.snapshot()
		check(owner.generate({"state":-1}).is_empty() and owner.snapshot()==configured,"Invalid RNG partially committed Dekato")
		var state:=owner.generate({"state":number})
		if state.is_empty():check(false,owner.error);return
		check(state.campaign_cursor==38 and state.station_id==22 and state.system_id==4 and state.dekato_context==context and state.actors.size()==7,"Dekato cast identity changed")
		var oracle:=ordered_factory(bindings,cat,seed,context,number)
		check(not oracle.is_empty() and oracle.random_state==state.random_state,"Dekato changed shared-factory random ordering")
		if oracle.is_empty():return
		for id in 7:
			var row: Dictionary=state.actors[id];var expected: Dictionary=oracle.actors[id]
			check(row.actor_id==id and row.actor_kind==(2 if id<2 else 3) and row.subtype==(1 if id<2 else 0),"Original actor order/type changed")
			for key in ["factory_position","cargo","fragments","route","hull_catalogue_id","body_pose"]:check(row[key]==expected[key],"Factory ordering changed "+key+" for "+str(id))
			check(row.body_pose==row.statistics_pose and row.model_local_pose==Transform3D.IDENTITY and row.body_pose.basis==Basis.IDENTITY,"Actor pose spaces diverged")
			check(not row.has("hull_divisors") and not row.has("current_hull_override") and row.discarded_cargo.is_empty(),"Unrelated mission overrides leaked into Dekato")
			cargo_rows+=row.cargo.size()
			if id<2:
				check(row.friendly and not row.cruise_enabled and row.assembly==rules.freighter_assembly and row.model_assembly_required,"Freighter lost friendly/stationary/source assembly")
				check(row.route.is_empty() and row.fragments.is_empty() and owner.route(id)==null,"Freighter consumed patrol or initial-fragment draws")
				var delta: Vector3=row.body_pose.origin-Vector3(90000,10000,80000)
				check(delta.x>=-10000 and delta.x<10000 and delta.y>=-10000 and delta.y<10000 and delta.z>=-10000 and delta.z<10000,"Freighter scripted displacement changed")
				var motion:=Motion.new()
				check(motion._configure_story(bindings,context,row),motion.error)
				var before:=motion.snapshot()
				for tick in 20:check(motion.update(16,true),motion.error)
				check(motion.snapshot()==before,"Cruise-disabled Dekato freighter drifted")
			else:
				check(row.script_hostile and row.population_group=="fighter" and row.body_pose.origin==row.factory_position,"Escort lost hostility or gained scripted relocation")
				var route: RefCounted=owner.route(id)
				check(route!=null and route.snapshot()==row.route and not row.route.waypoints.is_empty(),"Escort lost its shared generated patrol")
		check(owner.generate({"state":number}).is_empty() and owner.snapshot()==state,"Dekato generated twice")
		var detached:=owner.snapshot();detached.actors[2].route.waypoints.clear()
		check(owner.snapshot()==state,"Detached snapshot changed retained routes")
		var world:=World.new()
		if not world.configure_dekato(bindings,cat,seed,context,CONDITIONS):check(false,world.error);return
		var complete:=world.generate({"state":number})
		check(not complete.is_empty() and complete.npc_construction==state and complete.weapon_effects.size()==7,"World changed the accepted seven-actor ledger")
		if complete.is_empty():return
		var random:=Random.new();random.restore(state.random_state)
		var shared: Dictionary=bindings.opening_actors.npc_initialization.world_initialization
		for id in 7:
			var effects: Dictionary=complete.weapon_effects[id]
			if id<2:check(effects=={"actor_id":id,"unarmed":true},"Freighter allocated a weapon pool")
			else:
				var expected_item: int=int(bindings.early_contracts.ship_combat.weapons.factions.filter(func(row):return int(row.actor_kind)==3)[0].item_id)
				check(effects.discarded_default.item_id==0 and effects.primary.item_id==expected_item,"Escort faction weapon selection changed")
				for key in ["discarded_default","primary"]:
					var flips:=[]
					for slot in int(shared.weapon_effect_capacity):flips.append(random.next_int(int(shared.weapon_effect_random_bound))==0)
					check(effects[key].flipped==flips,"Weapon pool was allocated before the full cast")
		check(complete.random_state==random.snapshot(),"Final world RNG differs from actor-then-weapon ordering")
		var held:=world.snapshot()
		check(world.generate({"state":number}).is_empty() and world.snapshot()==held,"World accepted a second allocation")
		if number==42:shown=state
	check(cargo_rows>0,"Cargo-retention checks never exercised actual generated cargo")
	var missing: Array=bindings.records[17060];bindings.records.erase(17060)
	check(not Factory.new().configure_dekato(bindings,cat,seed,context),"Missing original Nivelian body was silently accepted")
	bindings.records[17060]=missing
	if DisplayServer.get_name()!="headless":await render_cast(library,bindings,art,shown)

## Independent mission-level sequencing over the already-tested shared samplers.
## This does not call the new mission generator or allocate world weapon effects.
func ordered_factory(bindings: RefCounted,cat: RefCounted,seed: Dictionary,context: Dictionary,value: int) -> Dictionary:
	var factory:=Factory.new()
	if not factory.configure_dekato(bindings,cat,seed,context):check(false,factory.error);return {}
	var random:=Random.new();random.restore({"state":value})
	var rows:=[];var point:=Vector3(90000,10000,80000)
	for id in 7:
		var hull: int=15 if id<2 else Factory._select_hull(random,3,bindings.early_contracts.encounter_construction.hulls)
		var sample:=factory._sample_actor(id,point,random,id<2)
		if sample.is_empty():check(false,factory.error);return {}
		var row: Dictionary=sample.actor;var at: Vector3=row.factory_position
		if id<2:
			# Two independent quantity draws for each retained cargo row, before
			# the scripted three-axis relocation; these are not discarded draws.
			for cargo in row.discarded_cargo:
				var multiplied: int=int(cargo.quantity)*(2+random.next_int(4))
				cargo.quantity=maxi(multiplied,8+random.next_int(5))
			at=point
			for axis in 3:at[axis]+=-10000+random.next_int(20000)
		row.cargo=row.discarded_cargo;row.hull_catalogue_id=hull;row.body_pose=Transform3D(Basis.IDENTITY,at)
		rows.append(row)
	return {"actors":rows,"random_state":random.snapshot()}

func render_cast(library: RefCounted,bindings: RefCounted,art: String,state: Dictionary) -> void:
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=10;camera.far=300000
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=42000
	var center:=Vector3(90000,10000,80000)
	camera.look_at_from_position(center+Vector3(47000,64000,-72000),center)
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.65;viewport.add_child(environment)
	var ships:=[];var labels:=[];var label_rects:=[]
	for row in state.actors:
		var ship:=Geometry.new();viewport.add_child(ship)
		var ready: bool=ship.build_population_assembly(row.assembly,library,visuals,bindings) if row.actor_id<2 else ship.build(int(row.hull_catalogue_id),library,visuals,bindings)
		check(ready,ship.error)
		if not ready:viewport.free();return
		ship.transform=row.body_pose
		ships.append(ship)
		check(ship.apply_selection({"visible":true,"level":0}),ship.error)
		var label:=Label.new();label.text="%d / %s"%[row.actor_id,"FREIGHTER" if row.actor_id<2 else "ESCORT"]
		label.position=camera.unproject_position(row.body_pose.origin)+Vector2(8,-22)
		var rectangle:=Rect2(label.position,Vector2(150,22))
		while label_rects.any(func(other):return rectangle.intersects(other)):
			rectangle.position.y-=24
		label.position=rectangle.position;label_rects.append(rectangle);labels.append(label);viewport.add_child(label)
	var title:=Label.new();title.text="DEKATO 38  |  SOURCE CONSTRUCTION FIXTURE\nTwo stationary freighters + five escorts. Campaign route remains closed."
	title.position=Vector2(24,20);title.add_theme_font_size_override("font_size",22);viewport.add_child(title)
	await capture_view(viewport,"dekato38-construction.png")
	# Diagnostic close-ups change only the camera/visibility, never the source
	# poses, model transforms, simulation state or campaign selection.
	for label in labels:label.visible=false
	for id in [0,2]:
		for index in ships.size():ships[index].visible=index==id
		var at: Vector3=state.actors[id].body_pose.origin
		camera.look_at_from_position(at+Vector3(12000,10000,-18000),at)
		camera.size=10000 if id==0 else 1200
		title.text="DEKATO 38  |  ORIGINAL %s MODEL\nConstruction fixture, actor %d. Camera close-up only; original model scale retained."%["NIVELIAN FREIGHTER" if id==0 else "MIDO ESCORT",id]
		await capture_view(viewport,"dekato38-actor-%d.png"%id)
	viewport.free()

func capture_view(viewport: SubViewport,name: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	check(not image.is_empty(),"Dekato original cast failed to render")
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures)
		check(image.save_png(captures.path_join(name))==OK,"Could not retain Dekato visual proof")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
