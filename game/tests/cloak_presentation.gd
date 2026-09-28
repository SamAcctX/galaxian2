extends "res://tests/player_cloak.gd"
## Original resources and accepted-time rendering; no earned purchase claim.
const Ship=preload("res://src/presentation/ship_geometry.gd")
const Playback=preload("res://src/presentation/opening_audio.gd")
const Charge=preload("res://src/presentation/cloak_charge_panel.gd")
const Fitting=preload("res://src/simulation/equipment_fitting.gd")
const Preview=preload("res://src/presentation/opening_preview.gd")

func _initialize() -> void:call_deferred("run_presentation")
func run_presentation() -> void:
	var args:=OS.get_cmdline_user_args()
	var visuals=preload("res://src/content/visual_library.gd").new()
	if args.size()!=3 or not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not catalogues.open(library) or not visuals.open(args[2],library.manifest):
		check(false,library.error+bindings.error+catalogues.error+visuals.error)
	else:await verify_presentation(visuals)
	print("Cloak presentation: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify_presentation(visuals: RefCounted) -> void:
	root.size=Vector2i(1280,720)
	var fitting:=Fitting.new();var assets:=fitting.prepare_assets(bindings,catalogues,library)
	check(not assets.is_empty(),fitting.error)
	for id in [94,95,96]:check(assets.get("items",{}).get(id)=="","Fitted cloak is missing original mask or audio: "+str(assets.get("items",{}).get(id)))
	var ship:=Ship.new();root.add_child(ship)
	if not ship.build(0,library,visuals,bindings,"high",null,true) or not ship.apply_detail(0.0,1.0):check(false,ship.error);ship.free();return
	var lights=preload("res://src/presentation/opening_lighting.gd").new()
	var reflection=preload("res://src/presentation/environment_reflection.gd").new()
	var surfaces=preload("res://src/presentation/surface_response.gd").new()
	if not lights.build_station(bindings,catalogues,26) or not reflection.build(library,bindings,catalogues,int(lights.state.system_id),false) or not surfaces.apply_branches([ship],bindings,lights.state,reflection):
		check(false,lights.error+reflection.error+surfaces.error);lights.free();ship.free();return
	lights.free()
	var radius: float=maxf(ship.levels[0].source_bounds.size.length(),300.0)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.near=1;camera.far=100000
	camera.look_at_from_position(Vector3(0,radius*0.3,-radius*1.5),Vector3.ZERO)
	# A transparent sky layer must remain visible through the completed cloak.
	# Godot's opaque-only screen sample omits this observable background.
	var backdrop:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE*radius*6
	backdrop.mesh=quad;root.add_child(backdrop)
	backdrop.global_transform=Transform3D(camera.global_transform.basis,-camera.global_transform.basis.z*radius)
	var pigment:=StandardMaterial3D.new();pigment.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	pigment.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;pigment.albedo_color=Color(0.15,0.65,0.35)
	backdrop.material_override=pigment
	var light:=DirectionalLight3D.new();root.add_child(light);light.rotation=Vector3(-0.65,-0.6,0)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();root.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.03,0.12,0.24)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.5
	var panel:=Charge.new();root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.configure(library,bindings,visuals):check(false,panel.error);return
	var audio:=Playback.new();root.add_child(audio)
	if not audio.configure(library,bindings):check(false,audio.error);return
	audio.set_paused(true)
	var owner:=configured([95]);var clock:=0;var revision:=0
	check(ship.apply_cloak(owner.snapshot()),ship.error)
	await capture_cloak("cloak-ready")
	owner.request_start(1);advance(owner,1000);clock+=1000
	panel.present(owner.snapshot(),true,false)
	check(panel.visible and is_equal_approx(panel.modulate.a,0.999),"Charging lost its accepted fade time")
	await capture_cloak("cloak-charging")
	advance(owner,1002);clock+=1002
	for time in [0,1000,3000,9000,10001]:
		var delta: int=time-int(owner.snapshot().elapsed_ms)
		if delta>0:advance(owner,delta);clock+=delta
		var state: Dictionary=owner.snapshot()
		check(ship.apply_cloak(state),ship.error);panel.present(state,true,false)
		check(not panel.visible,"Active cloak retained the charging widget")
		var frame: Dictionary=audio.prepare_frame(revision,{"elapsed_ms":clock,"cloak":state})
		if frame.is_empty():check(false,audio.error);break
		audio.commit_frame(frame);revision+=1
		check(audio.snapshot().unsupported.is_empty(),"Cloak commands did not reach a supported audio player")
		if state.audio_serial>0:
			check(audio._players.has(30) and audio._players[30].pending_resume,"Cloak sound was logged without a playable original clip")
			if audio._players.has(30):
				var played: Dictionary=audio._players[30]
				check(played.clip.gain>0.0 and played.clip.gain<float(bindings.audio.events[30].properties.volume),"Authored cloak volume variation was discarded")
		var before: Dictionary=ship._cloak.snapshot()
		await capture_cloak("cloak-%d"%time)
		check(ship._cloak.snapshot()==before and owner.snapshot()==state,"Rendering advanced the retained cloak")
		for row in ship._cloak._surfaces:check(row.node.material_override==(row.cloak if state.active else row.original),"Cloak did not swap or restore the original hull material")
		var repeated: Dictionary=audio.prepare_frame(revision,{"elapsed_ms":clock,"cloak":state})
		check(not repeated.is_empty() and repeated.operations.is_empty(),"Presenting cloak twice replayed its sound")
	check(audio.snapshot().history.filter(func(row):return row.action=="start" and row.source_id==30).size()==2,"Cloak start and expiry did not play exactly two original samples")
	var preview:=Preview.new();root.add_child(preview);preview.set_context(library,bindings,visuals)
	check(preview._cloak_charge._sprites.size()==2,"Application could not prepare the original cloak controls")
	preview.free();audio.free();panel.free();ship.free();backdrop.free();camera.free();light.free();environment.free()

func capture_cloak(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var rendered:=root.get_texture().get_image()
	if label=="cloak-3000":
		var reference:=rendered.get_pixel(640,250);var dark:=0
		for y in range(310,405):
			for x in range(490,790):
				if rendered.get_pixel(x,y).g<reference.g*0.25:dark+=1
		check(reference.g>0.3 and dark<100,"The cloak occluded its transparent sky with an opaque hull silhouette")
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	check(rendered.save_png(directory.path_join(label+".png"))==OK,"Could not preserve cloak appearance")
