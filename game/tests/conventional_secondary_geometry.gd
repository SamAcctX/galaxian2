extends "res://tests/conventional_secondaries.gd"
const Geometry=preload("res://src/presentation/secondary_geometry.gd")
const Visuals=preload("res://src/content/visual_library.gd")

func _initialize() -> void:call_deferred("run_geometry")

func run_geometry() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected one content/binding/visual triple");finish_geometry();return
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new();var visuals:=Visuals.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+mounts.error+visuals.error);finish_geometry();return
	var built:=construction(bindings,cat,0.5)
	if built==null:finish_geometry();return
	root.size=Vector2i(1280,720)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.near=1;camera.far=1000000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);root.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();root.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.02,0.025,0.035)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.5
	for item in [31,36]:
		var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
		if group==null or not owner.configure(bindings,cat,equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":1}]),mounts) or not owner.configure_projectile_visuals(lib,bindings):check(false,owner.error);continue
		var geometry:=Geometry.new();root.add_child(geometry)
		if not geometry.build(owner,lib,visuals,bindings):check(false,geometry.error);geometry.free();continue
		var step:=owner.evaluate_advance(1,group,[0,1,2,3])
		if step.is_empty():check(false,owner.error);geometry.free();continue
		owner=step.owner
		var pose:=Transform3D(Basis.IDENTITY,Vector3(100000,100000,100000))
		var fired:=owner.evaluate_trigger(pose,item,group,[0,1,2,3])
		if fired.is_empty():check(false,owner.error);geometry.free();continue
		owner=fired.owner;group=fired.combat
		var prior:=owner.snapshot();var shot: Dictionary=prior.guns[0].projectiles.slots[0]
		var renderer: Node3D=geometry._conventional[0]
		var bounds: AABB=renderer.bodies[0].source_bounds
		var center: Vector3=shot.position+bounds.get_center();var radius:=maxf(bounds.size.length(),1.0)
		camera.look_at_from_position(center+Vector3(1.2,0.7,1.8)*radius,center)
		var frame:=geometry.prepare_world(owner,camera.transform)
		if frame.is_empty():check(false,geometry.error);geometry.free();continue
		check(owner.snapshot()==prior and not renderer.bodies[0].visible,"Preparing original rocket geometry changed physics or drew before commit")
		geometry.commit_world(frame)
		check(renderer.bodies.filter(func(body):return body.visible).size()==1 and renderer.attachments[0].visible,"Last-round body or attached glow was missing")
		await capture_geometry("secondary-%d-original-body"%item)
		var retained_frame:=frame;var retained_pose: Transform3D=renderer.bodies[0].transform
		for idle in 3:await process_frame
		check(owner.snapshot()==prior and renderer.bodies[0].transform==retained_pose,"Rendering independently advanced a paused projectile")
		for count in 15:
			step=owner.evaluate_advance(50,group,[0,1,2,3])
			if step.is_empty():check(false,owner.error);break
			owner=step.owner;group=step.combat
		var state:=owner.snapshot();shot=state.guns[0].projectiles.slots[0]
		var middle: Vector3=(pose.origin+shot.position)*0.5
		var distance: float=maxf(pose.origin.distance_to(shot.position),1500.0)
		camera.look_at_from_position(middle+Vector3(distance*0.8,distance*0.4,-distance*0.15),middle)
		frame=geometry.prepare_world(owner,camera.transform)
		if frame.is_empty():check(false,geometry.error);geometry.free();continue
		geometry.commit_world(frame)
		check(frame.conventional[0].trail.quads>2,"Moving rocket or missile produced no crossed exhaust geometry")
		check(state.guns[0].visuals.attachment.time_ms!=prior.guns[0].visuals.attachment.time_ms,"Attached original model animation did not advance with flight")
		check(owner.snapshot().guns[0].ammunition==0,"Secondary geometry restored spent ammunition")
		await capture_geometry("secondary-%d-exhaust"%item)
		geometry.commit_world(retained_frame)
		check(not geometry.error.is_empty() and renderer.bodies[0].position==shot.position,"Stale prepared frame rewound a missile")
		var stopped:=owner.fork();stopped._guns[0].projectiles.mark_impact(shot.id)
		step=stopped.evaluate_advance(0,group,[0,1,2,3])
		if step.is_empty():check(false,stopped.error);geometry.free();continue
		stopped=step.owner
		frame=geometry.prepare_world(stopped,camera.transform)
		if frame.is_empty():check(false,geometry.error);geometry.free();continue
		geometry.commit_world(frame)
		check(not renderer.bodies[0].visible and not renderer.attachments[0].visible and frame.conventional[0].trail.mesh!=null,"An impact kept its body or immediately erased the exhaust")
		step=stopped.evaluate_advance(2000,group,[0,1,2,3])
		if step.is_empty():check(false,stopped.error);geometry.free();continue
		frame=geometry.prepare_world(step.owner,camera.transform)
		check(not frame.is_empty() and frame.conventional[0].trail.mesh==null,"Retired secondary exhaust retained GPU geometry")
		geometry.free()
	finish_geometry()

func capture_geometry(label: String) -> void:
	await process_frame;RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image();var background:=pixels.get_pixel(0,0);var lit:=0
	for y in range(0,pixels.get_height(),2):
		for x in range(0,pixels.get_width(),2):
			var color:=pixels.get_pixel(x,y)
			if absf(color.r-background.r)+absf(color.g-background.g)+absf(color.b-background.b)>0.15:lit+=1
	check(lit>40,"Original body/exhaust capture has no visible geometry")
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		check(pixels.save_png(directory.path_join(label+".png"))==OK,"Cannot save secondary GPU capture")

func finish_geometry() -> void:
	print("Conventional secondary geometry: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
