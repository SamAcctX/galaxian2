extends SceneTree
## Inspect original Betty geometry from behind. This isolated view tests its
## additive nozzle mesh and LOD ownership, not the missing exhaust emitters.
const Geometry=preload("res://src/presentation/ship_geometry.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Visuals=preload("res://src/content/visual_library.gd")
var failures:=0
var checks:=0
var viewport: SubViewport

func _initialize():
	create_timer(30).timeout.connect(func():push_error("Player engine-glow checks timed out");quit(1))
	call_deferred("run")

func run():
	var args:=OS.get_cmdline_user_args()
	check(args.size() in [3,4],"Expected explicit Mac content, bindings, visuals and optional captures")
	if args.size() in [3,4]:await verify(args)
	print("Player engine glow: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray):
	# The maintained check runner supplies its private capture directory by
	# environment; keep the explicit fourth argument supported for direct runs.
	var captures:=args[3] if args.size()==4 else OS.get_environment("GOF2_CAPTURE_DIR")
	var library:=Library.new();var bindings:=Bindings.new();var visuals:=Visuals.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not visuals.open(args[2],library.manifest):
		check(false,library.error+bindings.error+visuals.error);return
	check(bindings.source_architecture=="x86_64","This fixture only verifies the Mac player")
	if bindings.source_architecture!="x86_64":return
	viewport=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0,320,-1400),Vector3(0,30,0));camera.near=1;camera.far=10000;camera.current=true
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.3,PI,0);viewport.add_child(light)
	var ship:=Geometry.new();viewport.add_child(ship)
	check(not ship.apply_camera_suppression(true) and ship.get_child_count()==0,"Unbuilt geometry accepted a camera mask")
	check(ship.build(0,library,visuals,bindings,"high",null,true),ship.error)
	check(ship.engine_glow!=null,"Player geometry omitted the original glow required by this regression")
	if ship.engine_glow==null:ship.free();viewport.free();return
	var glow: Node3D=ship.engine_glow
	check(glow.get_meta("source_resource_id")==17900 and glow.transform==Transform3D.IDENTITY,"Player glow lost its original resource or inherited an invented offset")
	check(not glow.visible,"An unselected ship rendered its nozzle glow")
	for level in ship.levels.size():
		check(ship.apply_selection({"visible":true,"level":level}),ship.error)
		check(glow==ship.engine_glow and glow.visible and ship.levels.filter(func(node):return node.visible).size()==1,"LOD transition lost or duplicated the glow")
	check(ship.apply_selection({"visible":false,"level":-1}) and not glow.visible,"Culled ship retained its glow")
	check(not ship.apply_selection({"visible":true,"level":ship.levels.size()}) and not glow.visible,"Rejected detail selection changed glow visibility")
	check(ship.apply_selection({"visible":true,"level":0}),ship.error)
	ship.hide();check(not glow.is_visible_in_tree(),"Hidden player retained a floating nozzle glow");ship.show()
	check_camera_mask(ship)
	if DisplayServer.get_name()!="headless":
		var with_glow:=await rendered()
		glow.hide()
		var without_glow:=await rendered()
		var changed:=0
		for y in with_glow.get_height():
			for x in with_glow.get_width():
				var a:=with_glow.get_pixel(x,y);var b:=without_glow.get_pixel(x,y)
				if a.r-b.r+a.g-b.g+a.b-b.b>0.08:changed+=1
		check(changed>100,"Original nozzle mesh contributed too few additive pixels: "+str(changed))
		check(ship.apply_selection(ship.selection),ship.error)
		var restored:=await rendered()
		check(restored.get_data()==with_glow.get_data(),"Restoring the same selection changed original glow appearance")
		var selected: Dictionary=ship.selection.duplicate(true)
		check(ship.apply_camera_suppression(true),ship.error)
		var masked:=await rendered()
		ship.hide()
		var authored_hidden:=await rendered()
		check(masked.get_data()==authored_hidden.get_data() and masked.get_data()!=with_glow.get_data(),"Camera mask did not suppress the same original body/glow pixels as authored hiding")
		ship.show()
		check(ship.apply_camera_suppression(false) and ship.selection==selected,ship.error)
		var unmasked:=await rendered()
		check(unmasked.get_data()==with_glow.get_data(),"Camera mask release changed the original body/glow appearance")
		if not captures.is_empty():
			DirAccess.make_dir_recursive_absolute(captures)
			check(with_glow.save_png(captures.path_join("betty-original-nozzle-glow.png"))==OK,"Glow capture failed")
			check(without_glow.save_png(captures.path_join("betty-without-nozzle-glow.png"))==OK,"Comparison capture failed")
			check(masked.save_png(captures.path_join("betty-camera-suppressed.png"))==OK,"Camera-mask capture failed")
		print("Original nozzle additive pixels: ",changed)
	check(ship.apply_camera_suppression(true),ship.error)
	ship.clear()
	check(ship.get_child_count()==0 and ship.engine_glow==null and ship.selection.is_empty() and not ship.apply_camera_suppression(false),"Cleared geometry retained drawable children or accepted a camera mask")
	check(ship.build(0,library,visuals,bindings,"high",null,true) and ship.apply_selection({"visible":true,"level":0}),ship.error)
	check(ship.engine_glow!=null and ship.engine_glow.visible and ship.levels.filter(func(node):return node.visible).size()==1,"Rebuilding geometry retained its previous camera mask")
	# Every purchasable base hull has a glow now; NPC-only hulls stay excluded.
	var unsupported:=13 # excluded from every shipyard
	check(not ship.build(unsupported,library,visuals,bindings,"high",null,true) and ship.get_child_count()==0 and ship.engine_glow==null,"Unsupported player hull reused Betty's glow")
	var material: Array=bindings.materials[34813].duplicate(true)
	for row in bindings.materials[34813]:row.render_type=1
	check(not ship.build(0,library,visuals,bindings,"high",null,true) and ship.get_child_count()==0,"Changed source glow material built a partial ship")
	bindings.materials[34813]=material
	ship.free();viewport.free()

func check_camera_mask(ship: Node3D) -> void:
	var selected: Dictionary=ship.selection.duplicate(true)
	var glow: Node3D=ship.engine_glow;var pose: Transform3D=ship.transform
	check(ship.apply_camera_suppression(true),ship.error)
	for level in ship.levels.size():
		var detail:={"visible":true,"level":level}
		check(ship.apply_selection(detail) and ship.selection==detail,ship.error)
		check(ship.levels.all(func(node):return not node.visible) and not glow.visible,"Retained LOD update bypassed the camera body/glow mask")
	for invalid in [null,0,1,"false",Vector2.ZERO]:
		check(not ship.apply_camera_suppression(invalid) and not glow.visible and ship.levels.all(func(node):return not node.visible),"Invalid camera mask partially revealed original body/glow geometry")
	var retained: Dictionary=ship.selection.duplicate(true)
	check(not ship.apply_selection({"visible":false,"level":0}) and ship.selection==retained and not glow.visible,"Rejected LOD changed the camera-masked glow")
	ship.hide()
	check(ship.apply_camera_suppression(false) and not ship.visible and glow.visible and not glow.is_visible_in_tree(),"Camera-mask release overrode authored root invisibility")
	ship.show()
	check(ship.apply_selection({"visible":false,"level":-1}) and ship.apply_camera_suppression(true) and ship.apply_camera_suppression(false),ship.error)
	check(not glow.visible and ship.levels.all(func(node):return not node.visible),"Camera-mask release revived distance-culled body/glow geometry")
	check(ship.apply_selection(selected) and ship.engine_glow==glow and glow.visible and ship.transform==pose,"Camera-mask regression changed original glow ownership, pose or retained selection")
	print("Player camera mask: original glow17900, all body LODs, invalid inputs, authored hiding and distance culling verified")

func rendered() -> Image:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func check(value: bool,message: String):
	checks+=1
	if not value:failures+=1;push_error(message)
