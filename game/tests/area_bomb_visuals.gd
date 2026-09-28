extends "res://tests/conventional_secondary_geometry.gd"
## Detached original-art captures; these do not imply fitted AMR flight support.
const BombSim=preload("res://src/simulation/emp_bombs.gd")
const BombBody=preload("res://src/presentation/bomb_projectile_geometry.gd")
const BombBurst=preload("res://src/simulation/emp_detonation.gd")
const Explosion=preload("res://src/presentation/npc_death_effect_geometry.gd")
const BurstResources=preload("res://src/content/emp_detonation_resources.gd")

func _initialize() -> void:call_deferred("run_area_visuals")

func run_area_visuals() -> void:
	var args:=OS.get_cmdline_user_args()
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new();var resources:=BurstResources.new()
	if args.size()!=3 or not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not visuals.open(args[2],lib.manifest) or not resources.configure(lib,bindings,7):check(false,lib.error+bindings.error+cat.error+visuals.error+resources.error);finish_area();return
	root.size=Vector2i(1280,720)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.near=1;camera.far=1000000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);root.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();root.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.02,0.025,0.035)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.5
	for item in [44,45,46]:
		var bomb:=BombSim.new();var burst:=BombBurst.new();var body:=BombBody.new();var explosion:=Explosion.new()
		root.add_child(body);root.add_child(explosion)
		if not bomb.configure(bindings,cat,item,[]) or not bomb.prepare_visuals(lib,bindings) or not burst.configure(resources,item) or not body.build(bomb.snapshot(),lib,visuals,bindings) or not explosion.build(lib,visuals,bindings,burst):
			check(false,bomb.error+burst.error+body.error+explosion.error);body.free();explosion.free();continue
		bomb.advance(1,[])
		var launch:=bomb.trigger(Transform3D.IDENTITY,1,[])
		check(burst.begin_projectile(launch.shot),burst.error)
		var before:=bomb.snapshot()
		check(bomb.advance(600,[]).action=="none",bomb.error)
		check(not burst.advance(before,bomb.snapshot(),600,Vector3.ZERO).is_empty(),burst.error)
		var sample:=bomb.snapshot()
		var radius: float=maxf(body.models[0].source_bounds.size.length(),300.0)
		camera.look_at_from_position(sample.shot.position+Vector3(1.1,0.8,1.8)*radius,sample.shot.position)
		var frame:=body.prepare(sample)
		if frame.is_empty():check(false,body.error);body.free();explosion.free();continue
		check(not body.models[0].visible and bomb.snapshot()==sample,"Preparing bomb geometry altered accepted animation or visibility")
		body.commit(frame)
		check(body.models[0].visible and body.models[1].visible,"Original AMR body or glow is missing")
		await capture_geometry("amr-%d-body"%item)
		var paused:=bomb.snapshot();var pose: Transform3D=body.models[0].instances[0].transform
		for unused in 3:await process_frame
		check(bomb.snapshot()==paused and body.models[0].instances[0].transform==pose,"Rendering advanced paused AMR models")
		var previous_frame:=frame
		var parent:=bomb.snapshot();var candidate: RefCounted=bomb.fork()
		candidate.advance(2000,[])
		check(bomb.snapshot()==parent,"Speculative bomb animation changed its parent")
		var animated: Dictionary=candidate.snapshot()
		check(not animated.visuals.models[0].playing and animated.visuals.models[0].time_ms==animated.visuals.models[0].end_ms,"AMR body did not finish its deployment animation")
		check(animated.visuals.models[1].playing,"AMR attachment stopped its looping animation")
		check(bomb.trigger(Transform3D.IDENTITY,0,[]).action=="detonated",bomb.error)
		before=bomb.snapshot();bomb.advance(50,[])
		var cue:=burst.advance(before,bomb.snapshot(),50,Vector3.ZERO)
		check(cue.started and cue.audio.size()==1,"AMR explosion omitted its original one-shot sound")
		frame=body.prepare(bomb.snapshot());body.commit(frame)
		check(not body.models[0].visible and not body.models[1].visible,"Detonation left the projectile visible")
		body.commit(previous_frame)
		check(not body.error.is_empty() and not body.models[0].visible,"Stale geometry revived an exploded bomb")
		before=bomb.snapshot();bomb.advance(700,[])
		check(not burst.advance(before,bomb.snapshot(),700,Vector3.ZERO).is_empty(),burst.error)
		var center: Vector3=burst.snapshot().effect.position
		camera.look_at_from_position(center+Vector3(5000,2500,9000),center)
		var effect:=explosion.prepare_effect(burst,camera.transform,PackedByteArray([255,255,255,255]),Vector4.ONE,1.0)
		if effect.is_empty():check(false,explosion.error);body.free();explosion.free();continue
		explosion.commit_effect(effect)
		check(explosion.models.size()==2 and explosion.visible,"AMR explosion lost a layer or drew invented fragments")
		await capture_geometry("amr-%d-explosion"%item)
		body.free();explosion.free()
	finish_area()

func finish_area() -> void:
	print("Area bomb visuals: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
