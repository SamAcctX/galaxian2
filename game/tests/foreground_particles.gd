extends "res://tests/space_fog.gd"
## Field persistence, imported alpha/normal art, depth, and live opening wiring.
const Particles=preload("res://src/presentation/foreground_particle_field.gd")
const ParticleView=preload("res://src/presentation/foreground_particle_geometry.gd")
const Lighting=preload("res://src/presentation/opening_lighting.gd")
const Opening=preload("res://src/presentation/opening_session.gd")

func run() -> void:
	verify_field()
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3 or DisplayServer.get_name()=="headless":check(false,"Nearby particle checks require GPU and content/bindings/visuals");quit(1);return
	var library=load("res://src/content/library.gd").new()
	var bindings=load("res://src/content/resource_bindings.gd").new()
	var visuals=load("res://src/content/visual_library.gd").new()
	var cat=load("res://src/content/catalogues.gd").new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not visuals.open(args[2],library.manifest) or not cat.open(library) or not library.select_language("gb"):
		check(false,library.error+bindings.error+visuals.error+cat.error);quit(1);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,360);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var lights:=Lighting.new();viewport.add_child(lights)
	if not lights.build_station(bindings,cat,78):check(false,lights.error);viewport.free();quit(1);return
	lights.environment.environment.background_mode=Environment.BG_COLOR
	lights.environment.environment.background_color=Color(0.01,0.04,0.01)
	var camera:=Camera3D.new();camera.current=true;camera.near=1;camera.far=40000;viewport.add_child(camera)
	var parent:=Node3D.new();viewport.add_child(parent)
	var dust:=ParticleView.new();parent.add_child(dust)
	if not dust.build(library,visuals,bindings,lights.state,41):check(false,dust.error);viewport.free();quit(1);return
	dust.commit_view(dust.prepare_view(camera.global_transform,0))
	var accepted: Dictionary=dust.snapshot()
	check(dust.prepare_view(Transform3D(Basis.IDENTITY,Vector3(100,0,0)),100)!=null and dust.snapshot()==accepted,"Preparing dust moved the displayed field")
	check(dust.prepare_view(Transform3D(Basis.IDENTITY,Vector3(NAN,0,0)),100)==null and dust.snapshot()==accepted,"Rejected dust camera changed the displayed field")
	parent.transform=Transform3D(Basis(Vector3.UP,0.8),Vector3(90000,20000,-70000))
	check(dust.global_transform==Transform3D.IDENTITY,"Rotating the background dragged nearby dust")
	# Enlarged detached sprite makes texture masking, normals and depth visible.
	dust.multimesh.visible_instance_count=1
	dust.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*700),Vector3(0,0,-3000)))
	dust.multimesh.set_instance_color(0,Color.WHITE)
	dust.hide();var clear:=await capture(viewport);dust.show()
	var textured:=await capture(viewport)
	check(difference(textured,clear)>100 and variation(textured)>50,"Imported nearby dust became invisible or a flat rectangle")
	check(textured.get_pixel(0,0)==clear.get_pixel(0,0),"Dust alpha covered the surrounding view")
	check(textured.get_data()==(await capture(viewport)).get_data(),"Paused dust appearance changed")
	var normal_texture: Texture2D=dust.material_override.get_shader_parameter("normal_specular_texture")
	check(normal_texture!=null,"Nearby dust lost its normal/specular texture")
	var before_light: Vector3=dust.material_override.get_shader_parameter("light_direction")
	dust.material_override.set_shader_parameter("light_direction",Vector3.FORWARD)
	var dark:=await capture(viewport)
	dust.material_override.set_shader_parameter("light_direction",Vector3.BACK)
	check(difference(dark,await capture(viewport))>30,"Dust normal lighting ignored its key light")
	dust.material_override.set_shader_parameter("light_direction",before_light)
	await save_capture(textured,"dust-material")
	var blocker:=MeshInstance3D.new();blocker.mesh=QuadMesh.new();blocker.mesh.size=Vector2(30000,30000)
	var green:=StandardMaterial3D.new();green.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;green.albedo_color=Color(0,0.2,0)
	blocker.material_override=green;blocker.position.z=-1000;viewport.add_child(blocker)
	var foreground:=await capture(viewport);dust.hide();var foreground_clear:=await capture(viewport);dust.show()
	check(foreground.get_data()==foreground_clear.get_data(),"Distant dust painted over opaque foreground geometry")
	blocker.position.z=-10000
	var background:=await capture(viewport);dust.hide();var background_clear:=await capture(viewport);dust.show()
	check(difference(background,background_clear)>100,"Nearby dust disappeared behind more distant geometry")
	blocker.hide();camera.rotation.y=0.4
	check(difference(textured,await capture(viewport))>100,"Dust stayed attached to the screen during a turn")
	camera.rotation.y=0
	check(textured.get_data()==(await capture(viewport)).get_data(),"Turning the camera reseeded its nearby field")
	dust.hide()
	var sky:=Background.new();viewport.add_child(sky)
	if not sky.build_station(library,visuals,bindings,cat,78):check(false,sky.error);viewport.free();quit(1);return
	check(sky.foreground_particles==null,"An interior background silently acquired flight dust")
	var identity: String=bindings.binding_id;bindings.binding_id="0".repeat(64)
	check(not sky.enable_foreground_particles(library,visuals,bindings,lights.state,19) and sky.foreground_particles==null,"Another content pack supplied the flight's dust")
	bindings.binding_id=identity
	check(sky.enable_foreground_particles(library,visuals,bindings,lights.state,19) and sky.apply_view({"pose":camera.global_transform},{},0),sky.error)
	check(sky.apply_view({"pose":camera.global_transform},{},100),sky.error)
	var state: Dictionary=sky.foreground_particles.snapshot()
	var proposal: Dictionary=sky.prepare_view({"pose":Transform3D(Basis.IDENTITY,Vector3(1000000,0,0))},{},200)
	check(not proposal.is_empty() and sky.foreground_particles.snapshot()==state,"Preparing another scene consumed accepted dust state")
	check(sky.apply_view({"pose":camera.global_transform},{},100) and sky.foreground_particles.snapshot()==state,"Repeated presentation advanced nearby dust")
	check(not sky.apply_view({"pose":camera.global_transform},{},99) and sky.foreground_particles.snapshot()==state,"Rejected clock rewound nearby dust")
	sky.clear();check(sky.foreground_particles==null and sky.get_child_count()==0,"Changing locations retained the old nearby field")
	var void_world=load("res://src/simulation/void_environment.gd").new()
	if not void_world.configure(bindings,{"state":4096}) or not lights.build_void(bindings,void_world) or not sky.build_void(library,visuals,bindings,void_world):
		check(false,void_world.error+lights.error+sky.error);viewport.free();quit(1);return
	check(sky.enable_foreground_particles(library,visuals,bindings,lights.state,29),sky.error)
	for step_index in 21:
		camera.position.z=-400.0*step_index
		if not sky.apply_view({"pose":camera.global_transform},{},step_index*100):check(false,sky.error);viewport.free();quit(1);return
	var void_dust: Dictionary=sky.foreground_particles.snapshot()
	check(void_dust.elapsed_ms==2000 and Array(void_dust.weights).any(func(value):return value>0.1),"The moving Void camera omitted or froze its foreground field")
	await save_capture(await capture(viewport),"void-nearby-dust")
	viewport.free()
	await verify_opening(library,bindings,visuals)
	print("Foreground particles: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify_field() -> void:
	var field:=Particles.new();field.configure(34)
	var first: RefCounted=field.sample(Transform3D.IDENTITY,0)
	check(first!=null and field.snapshot().positions.is_empty(),"Initial particle preparation changed its parent")
	var initial: Dictionary=first.snapshot()
	check(initial.positions.size()>100 and initial.positions.size()<1000,"Nearby dust density is empty or unbounded")
	check(initial.weights.count(0.0)==initial.weights.size(),"Startup dust appeared before its first world update")
	check(first.sample(Transform3D(Basis(Vector3.UP,1.0),Vector3.ZERO),0)==first,"Camera-only rotation advanced the field")
	# Controlled moving point isolates elapsed time from random boundary recycling.
	first._positions[0]=Vector3(0,0,-3000);first._velocities[0]=Vector3(80,0,0)
	var before: Dictionary=first.snapshot()
	var moved: RefCounted=first.sample(Transform3D.IDENTITY,500)
	check(moved.snapshot().positions[0].is_equal_approx(Vector3(40,0,-3000)) and first.snapshot()==before,"Dust drift changed its parent or lost elapsed time")
	var split: RefCounted=first
	for elapsed in [7,23,30,87,187,194,247,347,447,500]:split=split.sample(Transform3D.IDENTITY,elapsed)
	check(split.snapshot().positions[0].is_equal_approx(moved.snapshot().positions[0]),"High-rate/variable steps changed visible dust speed")
	check(moved.sample(Transform3D.IDENTITY,500)==moved,"A paused field consumed another simulation step")
	check(moved.sample(Transform3D.IDENTITY,499)==null,"Nearby dust accepted backward game time")
	var shifted: RefCounted=moved.sample(Transform3D(Basis.IDENTITY,Vector3(100,0,0)),500)
	check(shifted.snapshot().positions[0]==moved.snapshot().positions[0],"Camera translation dragged nearby dust")
	var alpha:=[]
	var point: Vector3=moved.snapshot().positions[0]
	for distance in [0.0,1000.0,3000.0,4000.0,7000.0,10000.0]:
		alpha.append(moved.sample(Transform3D(Basis.IDENTITY,point+Vector3.RIGHT*distance),500).snapshot().weights[0])
	check(alpha[0]==0 and alpha[1]>0 and alpha[1]<alpha[2] and alpha[2]==alpha[3] and alpha[4]<alpha[3] and alpha[5]==0,"Dust did not fade at near and far camera boundaries")
	var recycled: RefCounted=moved.sample(Transform3D(Basis.IDENTITY,Vector3(1000000,0,0)),600)
	var next: Dictionary=recycled.snapshot()
	check(next.weights.count(0.0)==next.weights.size() and next.sizes==initial.sizes,"Recycling popped in brightly or changed sprite sizes")
	check(next.velocities.count(Vector3.ZERO)==next.velocities.size(),"Recycled particles kept the startup impulse")
	var settled: RefCounted=recycled.sample(Transform3D(Basis.IDENTITY,next.camera),5000)
	check(settled.snapshot().positions==next.positions,"Persistent dust expired or restarted with the camera still")
	var detached: Dictionary=settled.snapshot();detached.positions[0]=Vector3.ZERO
	check(settled.snapshot().positions[0]!=Vector3.ZERO,"A presentation observer rewrote the retained field")

func verify_opening(library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var session:=Opening.new();viewport.add_child(session)
	if not session.configure(library,bindings,visuals,1000000,0.5,1789103558,true,true,false):check(false,session.error);viewport.free();return
	var started: Dictionary=session.sky.foreground_particles.snapshot()
	var now:=1000000
	if not session.request_cinematic_skip():check(false,session.error);viewport.free();return
	for step_index in 100:
		if session.can_control():break
		now+=100000
		if not session.step(now):check(false,session.error);viewport.free();return
		if step_index%10==0:await process_frame
	check(session.can_control(),"The opening never released its moving player camera")
	for step_index in 30:
		now+=100000
		if not session.step(now):check(false,session.error);viewport.free();return
	var live: Dictionary=session.sky.foreground_particles.snapshot()
	print("Opening dust: ",{"elapsed_ms":live.elapsed_ms,"camera_motion":live.camera.distance_to(started.camera),"bright_particles":Array(live.weights).filter(func(value):return value>0.01).size()})
	check(live.elapsed_ms>started.elapsed_ms and live.positions!=started.positions,"Opening flight never advanced its nearby dust")
	var with_dust:=await capture(viewport)
	session.sky.foreground_particles.hide();var without_dust:=await capture(viewport);session.sky.foreground_particles.show()
	check(difference(with_dust,without_dust)>0,"The live opening's imported nearby dust never reached the screen")
	check(session.present() and session.sky.foreground_particles.snapshot()==live,"Repeated opening presentation advanced nearby particles")
	await save_capture(with_dust,"opening-nearby-dust")
	viewport.free()

func save_capture(image: Image,name: String) -> void:
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	check(image.save_png(directory.path_join(name+".png"))==OK,"Cannot save nearby particle capture")
