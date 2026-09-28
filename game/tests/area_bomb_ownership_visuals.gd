extends "res://tests/conventional_secondary_geometry.gd"
## Mixed fitted-owner presentation, including simultaneous live last rounds.
## This is a component fixture, not a paid fitting or saved-flight claim.
const BurstResources=preload("res://src/content/emp_detonation_resources.gd")

func _initialize() -> void:call_deferred("run_bomb_ownership")

func run_bomb_ownership() -> void:
	var args:=OS.get_cmdline_user_args()
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new();var visuals:=Visuals.new()
	if args.size()!=3 or not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+mounts.error+visuals.error);finish_geometry();return
	var built:=construction(bindings,cat,0.5)
	if built==null:finish_geometry();return
	var ship:=-1
	for row in cat.tables.ships:
		if row.stats.primary_slots>0 and row.stats.secondary_slots>=2:ship=int(row.id);break
	if ship<0:check(false,"The original catalogue has no mixed-secondary hull");finish_geometry();return
	root.size=Vector2i(1280,720)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.near=1;camera.far=1000000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);root.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();root.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.02,0.025,0.035)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.5
	for item in [44,46]:
		var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
		var initial:=equipped(bindings,cat,[{"item_id":41,"slot":0,"quantity":1},{"item_id":item,"slot":1,"quantity":1}],ship)
		if group==null or not owner.configure(bindings,cat,initial,mounts):check(false,owner.error);continue
		for kind in owner.bomb_kinds():
			var resources:=BurstResources.new()
			if not resources.configure(lib,bindings,kind) or not owner.configure_detonations(resources):check(false,resources.error+owner.error);finish_geometry();return
		check(owner.has_detonations(),"Mixed EMP and AMR lost a prepared burst family")
		if not owner.configure_projectile_visuals(lib,bindings):check(false,owner.error);continue
		var geometry:=Geometry.new();root.add_child(geometry)
		if not geometry.build(owner,lib,visuals,bindings):check(false,geometry.error);geometry.free();continue
		var step:=owner.evaluate_advance(1,group,[0,1,2,3],Vector3.ZERO)
		if step.is_empty():check(false,owner.error);geometry.free();continue
		owner=step.owner
		for id in [41,item]:
			var pose:=Transform3D(Basis.IDENTITY,Vector3(100000+(300 if id==41 else -300),0,100000))
			var fired:=owner.evaluate_trigger(pose,id,group,[0,1,2,3])
			if fired.is_empty():check(false,owner.error);geometry.free();finish_geometry();return
			owner=fired.owner
		step=owner.evaluate_advance(600,group,[0,1,2,3],Vector3.ZERO)
		if step.is_empty():check(false,owner.error);geometry.free();continue
		owner=step.owner
		var state:=owner.snapshot();var center:=Vector3.ZERO
		for gun in state.guns:center+=gun.bomb.shot.position/2.0
		var radius:=500.0
		for gun in state.guns:radius=maxf(radius,gun.bomb.shot.position.distance_to(center)+350.0)
		camera.look_at_from_position(center+Vector3(1.1,0.8,1.8)*radius,center)
		var frame:=geometry.prepare_world(owner,camera.transform)
		if frame.is_empty():check(false,geometry.error);geometry.free();continue
		geometry.commit_world(frame)
		check(geometry.error.is_empty() and geometry.bodies.size()==2 and geometry._bombs.size()==2 and geometry._bombs.values().all(func(body):return body.models.size()==2 and body.models.all(func(model):return model.visible)),"Combined presentation lost a live bomb body or its original glow")
		check(state.guns.all(func(gun):return gun.ammunition==0 and gun.bomb.shot.phase=="flying"),"Last-round removal discarded a live mixed-family projectile")
		await capture_geometry("mixed-amr-%d-live"%item)
		var previous:=frame
		var pulse:=owner.evaluate_trigger(Transform3D.IDENTITY,-1,group,[0,1,2,3])
		if pulse.is_empty():check(false,owner.error);geometry.free();continue
		owner=pulse.owner
		step=owner.evaluate_advance(750,pulse.combat,[0,1,2,3],center)
		if step.is_empty():check(false,owner.error);geometry.free();continue
		owner=step.owner
		check(step.events.is_empty() and owner.snapshot().detonation_audio.size()==2,"Mixed manual burst repeated target damage or lost a sound")
		camera.look_at_from_position(center+Vector3(4500,3500,6000),center)
		frame=geometry.prepare_world(owner,camera.transform)
		if frame.is_empty():check(false,geometry.error);geometry.free();continue
		geometry.commit_world(frame)
		check(geometry.error.is_empty() and geometry.detonations.all(func(effect):return effect.visible) and geometry._bombs[0].models.all(func(model):return not model.visible) and not geometry.bodies[1].visible,"Combined burst omitted an effect or left an exploded body visible")
		await capture_geometry("mixed-amr-%d-bursts"%item)
		var paused:=owner.snapshot()
		for unused in 3:await process_frame
		check(owner.snapshot()==paused,"Presentation advanced paused bomb clocks")
		geometry.commit_world(previous)
		check(not geometry.error.is_empty() and not geometry.bodies[1].visible,"A stale combined frame revived an exploded body")
		geometry.free()
	print("Mixed area bomb presentation: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
