extends SceneTree
## Side-on views expose the three original ribbon bands and their fading tails.
const Trail=preload("res://src/simulation/projectile_trail.gd")
const Geometry=preload("res://src/presentation/projectile_trail_geometry.gd")
var checks:=0
var failures:=0
var _last_light:=-1.0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected content/binding/visual arguments");finish();return
	var library=load("res://src/content/library.gd").new()
	var bindings=load("res://src/content/resource_bindings.gd").new()
	var visuals=load("res://src/content/visual_library.gd").new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not visuals.open(args[2],library.manifest):check(false,library.error+bindings.error+visuals.error);finish();return
	root.size=Vector2i(1280,720)
	var camera:=Camera3D.new();root.add_child(camera)
	camera.position=Vector3(0,0,9000);camera.look_at(Vector3.ZERO);camera.far=30000;camera.current=true
	var environment:=WorldEnvironment.new();root.add_child(environment)
	environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.01,0.01,0.02)
	var owners:=[];var geometries:=[]
	for index in 3:
		var owner:=Trail.new();var geometry:=Geometry.new();root.add_child(geometry)
		if not geometry.build(25+index,library,visuals,bindings):check(false,geometry.error);continue
		var basis:=Basis(Vector3(0,0,-1),Vector3.UP,Vector3.RIGHT)
		var pose:=Transform3D(basis,Vector3(-5000,(1-index)*1700,0))
		check(owner.start(25+index,pose),owner.error)
		for frame in 20:
			pose.origin.x+=400
			pose.origin.y=(1-index)*1700+sin(float(frame)*0.25)*500.0
			pose.basis.z=Vector3(400,cos(float(frame)*0.25)*125,0).normalized()
			check(owner.advance(50,pose),owner.error)
		var prepared:=geometry.prepare([owner.snapshot()],Vector4.ONE)
		check(not prepared.is_empty() and prepared.quads>2 and prepared.mesh!=null,"Retained sections produced no visible ribbon mesh")
		if prepared.is_empty():continue
		geometry.commit(prepared)
		owners.append(owner);geometries.append(geometry)
	await capture("thermal-ribbon-bands")
	for index in owners.size():
		var owner: RefCounted=owners[index];var before: Dictionary=owner.snapshot()
		check(owner.advance(500),owner.error)
		var geometry: Geometry=geometries[index]
		var faded:=geometry.prepare([owner.snapshot()],Vector4.ONE)
		check(not faded.is_empty() and faded.mesh!=null,"Stopping a shot immediately removed its trail")
		geometry.commit(faded)
		check(before.emitting and not owner.snapshot().emitting,"Stopped trail lost snapshot isolation")
	await capture("thermal-ribbon-fade")
	for index in owners.size():
		check(owners[index].advance(1001),owners[index].error)
		var gone: Dictionary=geometries[index].prepare([owners[index].snapshot()],Vector4.ONE)
		check(gone.get("mesh")==null,"Expired trail retained drawable geometry")
	finish()

func capture(label: String) -> void:
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	await process_frame;RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image();pixels.convert(Image.FORMAT_RGBA8)
	var bytes:=pixels.get_data();var lit:=0;var energy:=0.0
	for offset in range(0,bytes.size(),16):
		var value:=int(bytes[offset])+int(bytes[offset+1])+int(bytes[offset+2])
		energy+=value
		if value>100:lit+=1
	check(lit>100,"Ribbon render has no visible colored trail pixels")
	if _last_light>=0:check(energy<_last_light,"Detached ribbons did not visibly fade")
	_last_light=energy
	check(pixels.save_png(directory.path_join(label+".png"))==OK,"Cannot retain ribbon render")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)

func finish() -> void:
	print("Thermal ribbon geometry: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
