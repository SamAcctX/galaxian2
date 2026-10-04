extends SceneTree
## Supernova meshes registered with their material in the registration payload
## (the burning Luur platform, 89's burning twin) resolve and build with a
## material, and a newer import still accepts an earlier import's saves.
## Args: content, bindings, visuals [, earlier bindings].
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Statics=preload("res://src/content/static_object_definitions.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Update=preload("res://src/content/import_update.gd")
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()<3:check(false,"Expected content, bindings and visuals");finish();return
	var lib:=Library.new();var bindings:=Bindings.new();var visuals:=Visuals.new()
	check(lib.open(args[0]),lib.error)
	check(bindings.open(args[1],lib.manifest,lib),bindings.error)
	check(visuals.open(args[2],lib.manifest),visuals.error)
	if failures:finish();return
	var path:=bindings.resolve(18781,"mesh")
	check(path.ends_with("sn_burning_station.aem"),"Burning station mesh does not resolve: "+bindings.error)
	var material:=bindings.material_for_mesh(path)
	check(int(material.get("render_type",-1))==28 and not material.texture_paths[0].is_empty(),"Burning station lost its payload material: "+bindings.error)
	var reader:=Statics.new()
	for model in [18781,21876]:
		var placed:=reader.resolve(lib,bindings,model)
		check(not placed.is_empty(),reader.error)
		if placed.is_empty():continue
		var paths: Array=placed.layers.map(func(layer):return layer.path)
		var fire:=paths.filter(func(item):return item.get_file().begins_with("sn_burning_station"))
		check(fire.size()==(4 if model==18781 else 2),"Model %d lost its burning layers"%model)
		var resources:=Models.new()
		check(resources.prepare(paths,lib,visuals,bindings,"high",false,true),resources.error)
		for item in fire:
			var built: Node3D=resources.instantiate(item)
			check(built!=null and not built.instances.is_empty(),"No mesh built for "+item.get_file())
			if built==null:continue
			for instance in built.instances:
				check(instance.mesh!=null and instance.mesh.get_surface_count()>0 and instance.material_override!=null,"Mesh without material: "+item.get_file())
			built.free()
		resources.clear()
	if DisplayServer.get_name()!="headless":await capture(lib,visuals,bindings,reader)
	if args.size()>=4:
		# The player's earlier import stays readable; the newer extraction
		# attaches as an update because earlier rows are unchanged.
		var earlier:=Bindings.new()
		check(earlier.open(args[3],lib.manifest,lib),earlier.error)
		check(earlier.resolve(18781,"mesh").is_empty(),"Earlier import unexpectedly knows the payload material")
		var plain:=reader.resolve(lib,earlier,18781)
		check(plain.get("layers",[]).size()==3,"An earlier import must still place the platform without its fire: "+reader.error)
		check(earlier.attach_import_update(args[1],lib.manifest,lib),earlier.error)
		check(not earlier.import_update_receipt().is_empty() and earlier.binding_id!=bindings.binding_id,"Update did not keep the saved identity")
		check(not earlier.material_for_mesh(path).is_empty(),"Updated import lacks the payload material: "+earlier.error)
	finish()
## GPU only: draw the burning Luur platform and save it for a look.
func capture(lib: RefCounted,visuals: RefCounted,bindings: RefCounted,reader: RefCounted) -> void:
	var placed: Dictionary=reader.resolve(lib,bindings,18781)
	var resources:=Models.new()
	if placed.is_empty() or not resources.prepare(placed.layers.map(func(layer):return layer.path),lib,visuals,bindings,"high",false,true):check(false,resources.error);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var body:=Node3D.new();viewport.add_child(body)
	var bounds:=AABB()
	for layer in placed.layers:
		var model: Node3D=resources.instantiate(layer.path);body.add_child(model)
		for instance in model.instances:bounds=bounds.merge(instance.get_aabb())
	resources.clear()
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=10;camera.far=200000
	var reach:=bounds.size.length()
	camera.look_at_from_position(bounds.get_center()+Vector3(0.55,0.3,0.75)*reach*0.35,bounds.get_center())
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.4
	viewport.add_child(environment)
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	var captures:=OS.get_environment("GOF2_PAYLOAD_MESH_CAPTURES")
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures)
		check(image.save_png(captures.path_join("burning-luur-platform.png"))==OK,"Burning platform capture failed")
	viewport.free()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func finish() -> void:
	print("payload_meshes: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
