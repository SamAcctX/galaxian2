extends SceneTree
## Imported hangar templates at real catalogue locations. This component does
## not create a career or claim travel to those locations has been accepted.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Geometry=preload("res://src/presentation/hangar_geometry.gd")
const Lighting=preload("res://src/presentation/opening_lighting.gd")
const Reflection=preload("res://src/presentation/environment_reflection.gd")
const Surfaces=preload("res://src/presentation/surface_response.gd")
const Views=preload("res://src/content/station_presentation_definitions.gd")
const Motion=preload("res://src/simulation/station_camera.gd")
var checks:=0
var failures:=0
var viewport: SubViewport
var capture_dir:=""

func _initialize() -> void:
	create_timer(180).timeout.connect(func():push_error("Interior render checks timed out");quit(1))
	call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3 or DisplayServer.get_name()=="headless":push_error("Expected GPU and content/binding/visuals");quit(1);return
	var library:=Library.new();var bindings:=Bindings.new();var visuals:=Visuals.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not visuals.open(args[2],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+visuals.error+cat.error);quit(1);return
	capture_dir=OS.get_environment("GOF2_CAPTURE_DIR")
	if not capture_dir.is_empty():DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var locations:={}
	for station in cat.tables.stations:
		var system: Dictionary=cat.tables.systems[station.system_id]
		var faction:=int(system.fields[int(bindings.hangars.system_field)])
		if faction in [0,1,2,3] and int(system.sky_index)<11 and not locations.has(faction):locations[faction]=int(station.id)
	check(locations.size()==4,"Missing an ordinary source faction location")
	for faction in locations:
		var station_id: int=locations[faction]
		var scene:=Node3D.new();viewport.add_child(scene)
		var selected: Dictionary=bindings.resolve_hangar(station_id,cat)
		selected.ship=bindings.resolve_hangar_ship(0)
		var geometry:=Geometry.new();scene.add_child(geometry)
		var lighting:=Lighting.new();scene.add_child(lighting)
		var reflection:=Reflection.new()
		if not geometry.build(selected,library,visuals,bindings) or not lighting.build_station(bindings,cat,station_id,"hangar") or not reflection.build(library,bindings,cat,int(lighting.state.system_id),false):check(false,geometry.error+lighting.error+reflection.error);scene.free();break
		var original: Dictionary=bindings.surface_material.duplicate(true)
		var surfaces:=Surfaces.new()
		check(surfaces.apply_branches([geometry],bindings,lighting.state,reflection),surfaces.error)
		check(bindings.surface_material==original,"Interior light override changed the shared content declarations")
		var shaded:=0;var emissive:=0
		for model in geometry.models:
			for material in model.materials:
				check(material.shader!=Surfaces.ImportedShader,"Hangar or fitted ship retained the generic PBR material")
				if material.shader==Surfaces.ShaderSource:shaded+=1
				if material.shader in [preload("res://src/presentation/material_additive.gdshader"),preload("res://src/presentation/material_additive_twosided.gdshader")]:emissive+=1
		check(shaded>0 and emissive>0,"Hangar lost its native solid or additive layers")
		var view:=Views.ordinary_view(bindings.station_presentation,station_id,int(faction))
		var motion:=Motion.new();check(motion.configure(view,42),motion.error)
		var camera:=Camera3D.new();scene.add_child(camera)
		camera.set_perspective(rad_to_deg(view.camera.projection[0]),view.camera.projection[1],view.camera.projection[2]);camera.transform=motion.snapshot().pose;camera.make_current()
		var shown:=await frame()
		if faction==1:
			# Retain visible rear-wall texture between the additive lamps. A
			# lounge-strength fog setting collapses this whole patch to one color.
			var wall_colors:={}
			for y in range(180,270,2):
				for x in range(170,290,2):wall_colors[shown.get_pixel(x,y).to_rgba32()]=true
			check(wall_colors.size()>32,"Hangar fog erased the rear wall's visible texture")
		if not capture_dir.is_empty():check(shown.save_png(capture_dir.path_join("hangar-"+str(faction)+".png"))==OK,"Could not capture hangar")
		var unfogged: Dictionary=lighting.state.duplicate(true);unfogged.fog={}
		check(surfaces.apply_branches([geometry],bindings,unfogged,reflection),surfaces.error)
		var cleared:=await frame();var changed:=0
		for y in range(0,720,8):
			for x in range(0,1280,8):
				var a:=shown.get_pixel(x,y);var b:=cleared.get_pixel(x,y)
				if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>0.02:changed+=1
		check(changed>100 if faction==1 else changed==0,"Fog failed to distinguish Vossk and clear hangars: "+str(changed))
		print("Hangar ",faction," station ",station_id,": ",shaded," shaded, ",emissive," additive, ",changed," fog samples")
		scene.free()
	viewport.free();print("Interior rendering: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func frame() -> Image:
	for index in 20:await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
