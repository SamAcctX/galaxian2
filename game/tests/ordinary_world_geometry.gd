extends "res://tests/gate_transit_geometry.gd"
## Original destination resources in diagnostic views, without an earned arrival.
const Planets=preload("res://src/presentation/opening_planet_geometry.gd")
const SkyGeometry=preload("res://src/presentation/opening_sky.gd")
const Exterior=preload("res://src/presentation/station_exterior_geometry.gd")
const ExteriorResources=preload("res://src/content/station_exterior_resources.gd")
const Hangar=preload("res://src/presentation/hangar_geometry.gd")
const StationView=preload("res://src/content/station_presentation_definitions.gd")
const StationMotion=preload("res://src/simulation/station_camera.gd")
const StationScene=preload("res://src/presentation/station_session.gd")
const Reflection=preload("res://src/presentation/environment_reflection.gd")
const Surfaces=preload("res://src/presentation/surface_response.gd")

func _initialize():
	create_timer(120).timeout.connect(func():push_error("Destination geometry timed out");quit(1))
	call_deferred("run")

func run():
	var args:=OS.get_cmdline_user_args()
	if args.size() in [3,4]:await render_worlds(args)
	else:check(false,"Expected content, bindings, visuals and optional captures")
	print("Ordinary destination geometry: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func geometry_specs() -> Array:
	var result:=[]
	for station in [70,71,72,73,74]:
		result.append({"station_id":station,"system_id":14,"planet_count":5,"hangar_row":0,"gate":station==70})
	return result

func geometry_cursor() -> int:return 18
func geometry_name(station: int) -> String:return "magnetar-%d"%station
func geometry_available(bindings: RefCounted) -> bool:return load("res://src/content/ordinary_world_definitions.gd").available(bindings)

func render_worlds(args: PackedStringArray):
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest,lib) or not cat.open(lib) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+visuals.error);return
	if not geometry_available(bindings):check(false,"Supply ordinary destination declarations");return
	var specs:=geometry_specs()
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();camera.current=true;camera.near=10;camera.far=250000;viewport.add_child(camera)
	var flight_light:=StationScene.Lighting.new();viewport.add_child(flight_light)
	var reflection:=Reflection.new();var surfaces:=Surfaces.new()
	var sky:=SkyGeometry.new();var planets:=Planets.new();var exterior:=Exterior.new();var gates:=Geometry.new()
	for node in [sky,planets,exterior,gates]:viewport.add_child(node)
	for spec in specs:
		var station: int=int(spec.station_id)
		if not sky.build_lounge(lib,visuals,bindings,cat,station,geometry_cursor()) or not planets.build_lounge(lib,visuals,bindings,cat,station,geometry_cursor()):check(false,sky.error+planets.error);break
		if not flight_light.build_station(bindings,cat,station) or not reflection.build(lib,bindings,cat,int(spec.system_id),false):check(false,flight_light.error+reflection.error);break
		if not surfaces.apply_branches([planets],bindings,flight_light.state,reflection):check(false,surfaces.error);break
		var index: int=planets.selection.selected_index-1
		check(planets.models.size()==int(spec.planet_count) and planets.selection.system_id==int(spec.system_id) and sky.selection.system_id==int(spec.system_id),"Destination rendered the wrong world")
		camera.position=Vector3.ZERO;camera.look_at(planets._layout.entries[index+1].origin)
		check(sky.apply_view({"pose":camera.transform}) and planets.apply_view({"pose":camera.transform}),sky.error+planets.error)
		await capture(viewport,args,geometry_name(station)+"-planet")
		var with_planet:=await pixels(viewport)
		planets.models[index].hide()
		check((await pixels(viewport))!=with_planet,"Current planet contributed no pixels at%d"%station)
		planets.models[index].show()
		var resources:=ExteriorResources.new()
		if not resources.configure_ordinary_location(lib,bindings,cat,station) or not exterior.build(lib,visuals,bindings,resources):check(false,resources.error+exterior.error);break
		if not surfaces.apply_branches([exterior],bindings,flight_light.state,reflection):check(false,surfaces.error);break
		var state:=resources.snapshot();var radius:=float(state.sphere.w)
		camera.look_at_from_position(Vector3(radius*1.5,radius*0.75,-radius*1.8),state.pose.origin)
		check(sky.apply_view({"pose":camera.transform}) and planets.apply_view({"pose":camera.transform}),sky.error+planets.error)
		check(exterior.layers.size()==state.layers.size() and exterior.layers.size()>=2 and exterior.station.get_meta("source_station_id")==station,"Destination exterior layer identity changed")
		await capture(viewport,args,geometry_name(station)+"-exterior")
		var with_exterior:=await pixels(viewport)
		exterior.hide()
		check((await pixels(viewport))!=with_exterior,"Station exterior contributed no pixels at%d"%station)
		exterior.show()
		exterior.clear()
		if bool(spec.gate):
			var clock:=GateAnimation.new()
			if not clock.configure(bindings,cat,lib,station) or not gates.build(lib,visuals,bindings,cat,clock.snapshot().layout):check(false,clock.error+gates.error);break
			if not surfaces.apply_branches([gates],bindings,flight_light.state,reflection):check(false,surfaces.error);break
			check(gates.apply_animation(clock),gates.error)
			var gate: Dictionary=clock.snapshot().layout.objects[0]
			camera.look_at_from_position(gate.pose.origin+Vector3(17000,13000,-21000),gate.pose.origin)
			check(sky.apply_view({"pose":camera.transform}) and planets.apply_view({"pose":camera.transform}),sky.error+planets.error)
			await capture(viewport,args,geometry_name(station)+"-gate")
			gates.clear()
	flight_light.free();sky.free();planets.free();exterior.free();gates.free()
	# Each destination independently resolves its original row and source light.
	var lighting: Node3D
	var hangar:=Hangar.new();viewport.add_child(hangar)
	for spec in specs:
		var station: int=int(spec.station_id)
		var selected: Dictionary=bindings.resolve_hangar(station,cat)
		selected.ship=bindings.resolve_hangar_ship(0)
		var view:=StationView.select(bindings,station,geometry_cursor())
		var motion:=StationMotion.new()
		if not motion.configure(view,13) or not hangar.build(selected,lib,visuals,bindings):check(false,motion.error+hangar.error);break
		if lighting!=null:lighting.free()
		lighting=StationScene.Lighting.new();viewport.add_child(lighting)
		check(lighting.build_station(bindings,cat,station,"hangar"),lighting.error)
		check(reflection.build(lib,bindings,cat,int(spec.system_id),false),reflection.error)
		check(surfaces.apply_branches([hangar],bindings,lighting.state,reflection),surfaces.error)
		camera.set_perspective(rad_to_deg(view.camera.projection[0]),view.camera.projection[1],view.camera.projection[2])
		camera.transform=motion.snapshot().pose
		check(selected.row==int(spec.hangar_row) and selected.station_id==station and not hangar.models.is_empty(),"Destination hangar lost its original selection")
		await capture(viewport,args,geometry_name(station)+"-hangar")
	viewport.free()

func pixels(viewport: SubViewport) -> PackedByteArray:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image().get_data()
