extends SubViewport
## Menu-owned source sky and camera. This scene is independent of a career save;
## the original title chooses one of the first 100 catalogue stations.
const Catalogues=preload("res://src/content/catalogues.gd")
const SourceSky=preload("res://src/presentation/opening_sky.gd")
const Orientation=preload("res://src/simulation/scenery_orientation.gd")
const Population=preload("res://src/simulation/scenery_population.gd")
const Field=preload("res://src/simulation/scenery_field.gd")
const Motion=preload("res://src/simulation/scenery_motion.gd")
const SourceRandom=preload("res://src/simulation/seeded_random.gd")
const Scenery=preload("res://src/presentation/scenery_geometry.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Lighting=preload("res://src/presentation/opening_lighting.gd")
const Reflection=preload("res://src/presentation/environment_reflection.gd")
const SurfaceResponse=preload("res://src/presentation/surface_response.gd")
const SCENERY_STEP_LIMIT_MS:=150.0
const CAMERA_YAW_RATE:=0.00005
var error:=""
var selection:={}
var camera: Camera3D
var sky: Node3D
var scenery: Node3D
var station: Node3D
var lighting: Node3D
var reflection: RefCounted
var _world: Node3D
var _motion: RefCounted
var _yaw:=0.0
var _yaw_rate:=CAMERA_YAW_RATE
var planets: Node3D
var _active:=false
var _focused:=true

func _init() -> void:
	disable_3d=false;own_world_3d=true;transparent_bg=false
	size=Vector2i(1280,720);render_target_update_mode=SubViewport.UPDATE_DISABLED

func _ready() -> void:_focused=get_window().has_focus()

func _notification(what: int) -> void:
	if what in [MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN,MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_focused=what==MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN;_refresh_update_mode()

func _process(delta: float) -> void:
	if _active and _focused:advance(delta*1000.0)

func build(library: RefCounted,bindings: RefCounted,visuals: RefCounted,chosen_station: int=-1,camera_seed: int=-1) -> bool:
	if library==null or bindings==null or visuals==null or library.manifest.get("profile",{}).get("edition")!="mac-full-hd" or library.manifest.get("content_id")!=bindings.base_content_id or visuals.base_content_id!=bindings.base_content_id:return reject("Menu background requires matching Mac Full HD resources")
	var catalogues:=Catalogues.new()
	if not catalogues.open(library):return reject(catalogues.error)
	var random:=RandomNumberGenerator.new();random.randomize()
	if camera_seed>=0:random.seed=camera_seed
	var station_id:=chosen_station
	if station_id<0:station_id=random.randi_range(0,99)
	if station_id<0 or station_id>=100:return reject("Menu station choice is outside the source title range")
	var requested_station:=station_id
	var station_ids:=[];var paths:=[]
	if station_id!=int(bindings.first_flight.station_id):
		station_ids=[21000+station_id,21800+station_id,22000+station_id]
		if not bindings.records.has(station_ids[0]):station_ids=[16436,16439,16442]
		for id in station_ids:
			var path: String=bindings.resolve(id,"mesh")
			if path.is_empty():
				# Some original registrations name station light meshes absent
				# from the bundle. Decorative menu art must not block a save.
				# The baseline title background has no station exterior.
				station_id=int(bindings.first_flight.station_id)
				station_ids=[];paths=[];break
			paths.append(path)
	var station_row: Dictionary=catalogues.tables.stations[station_id]
	var system_id:=int(station_row.system_id)
	var system: Dictionary=catalogues.tables.systems[system_id]
	var sky_index:=int(system.sky_index)
	if sky_index<0 or sky_index>18:return reject("Menu system has no supported source sky")
	var scene:=Node3D.new();scene.name="MenuWorld";add_child(scene)
	var prepared_sky:=SourceSky.new();scene.add_child(prepared_sky)
	var orientation:=Orientation.new()
	var rotation: Dictionary=orientation.for_location(station_id,system_id,sky_index,int(station_row.get("planet_type",0)))
	if rotation.is_empty():scene.free();return reject(orientation.error)
	var star_variant:=system_id%3
	var descriptors:=[{"mesh_id":17850+star_variant,"texture_id":10086+star_variant,"mode":0},
		{"mesh_id":17800+sky_index,"texture_id":10065+sky_index,"mode":2}]
	# The source's baseline-station branch uses its fixed opening sky pair.
	if station_id==int(bindings.first_flight.station_id):
		descriptors=[{"mesh_id":17852,"texture_id":10088,"mode":0},{"mesh_id":17810,"texture_id":10075,"mode":2}]
	if not prepared_sky._build_layers(library,visuals,bindings,{"station_id":station_id,"system_id":system_id},"high",descriptors,rotation,star_variant):
		var message: String=prepared_sky.error;scene.free();return reject(message)
	if not prepared_sky.enable_space_fog(library,visuals,bindings,catalogues):
		var message: String=prepared_sky.error;scene.free();return reject(message)
	var population:=Population.new()
	if not population.configure(bindings):scene.free();return reject(population.error)
	var count_state: Dictionary=population.for_station(station_id)
	if count_state.is_empty():scene.free();return reject(population.error)
	var center:=Vector3(-30000,0,30000)
	if station_id!=int(bindings.first_flight.station_id):
		var center_random:=SourceRandom.new()
		if not center_random.restore(count_state.random_state):scene.free();return reject(center_random.error)
		center=Vector3(center_random.next_int(100000)-50000,center_random.next_int(100000)-50000,center_random.next_int(100000)+20000)
	var field:=Field.new()
	if not field.configure(bindings,catalogues,station_id,false,false,0):scene.free();return reject(field.error)
	var construction_random:=SourceRandom.new();construction_random.seed_from(int(Time.get_unix_time_from_system()))
	var generated: Dictionary=field.generate(center,construction_random.snapshot())
	if generated.is_empty():scene.free();return reject(field.error)
	var prepared_scenery:=Scenery.new();scene.add_child(prepared_scenery)
	if not prepared_scenery.build(generated,library,visuals,bindings,"high",false):
		var message: String=prepared_scenery.error;scene.free();return reject(message)
	var prepared_motion:=Motion.new()
	if not prepared_motion.configure(bindings,generated):scene.free();return reject(prepared_motion.error)
	var prepared_station: Node3D
	if station_id!=int(bindings.first_flight.station_id):
		var station_models:=Models.new()
		if not station_models.prepare(paths,library,visuals,bindings,"high",false,true):scene.free();return reject(station_models.error)
		prepared_station=Node3D.new();prepared_station.name="SourceStation";prepared_station.rotation.y=3.1415927410125732
		prepared_station.set_meta("source_station_id",station_id);scene.add_child(prepared_station)
		for index in paths.size():
			var model: Node3D=station_models.instantiate(paths[index])
			if model==null:
				var message: String=station_models.error;station_models.clear();scene.free();return reject(message)
			model.set_meta("source_resource_id",station_ids[index]);prepared_station.add_child(model)
		station_models.clear()
	var prepared_camera:=Camera3D.new();scene.add_child(prepared_camera);prepared_camera.current=true
	prepared_camera.keep_aspect=Camera3D.KEEP_HEIGHT
	prepared_camera.set_perspective(rad_to_deg(0.92),200.0,200000.0)
	var origin:=Vector3(float(random.randi_range(0,19999)-20000),0.0,float(random.randi_range(0,59999)+40000))
	_yaw=-PI/4.0;prepared_camera.transform=Transform3D(Basis(Vector3.UP,_yaw),origin)
	if not prepared_sky.apply_view({"pose":prepared_camera.global_transform}):
		var message: String=prepared_sky.error;scene.free();return reject(message)
	var prepared_lighting:=Lighting.new();scene.add_child(prepared_lighting)
	if not prepared_lighting.build_station(bindings,catalogues,station_id):
		var message: String=prepared_lighting.error;scene.free();return reject(message)
	var prepared_reflection:=Reflection.new()
	if not prepared_reflection.build(library,bindings,catalogues,system_id,false):scene.free();return reject(prepared_reflection.error)
	var surfaces:=SurfaceResponse.new()
	if not surfaces.apply_branches([prepared_station,prepared_scenery],bindings,prepared_lighting.state,prepared_reflection):scene.free();return reject(surfaces.error)
	lighting=prepared_lighting;reflection=prepared_reflection
	_world=scene;sky=prepared_sky;scenery=prepared_scenery;station=prepared_station;camera=prepared_camera;_motion=prepared_motion
	selection={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":station_id,"system_id":system_id,"requested_station_id":requested_station,
		"camera_origin":origin,"camera_yaw":_yaw,"camera_fov":0.92,"camera_near":200.0,"camera_far":200000.0,
		"sky":descriptors.duplicate(true),"scenery_center":center,"scenery_count":generated.objects.size(),"station_models":station_ids}
	error="";return true

func advance(milliseconds: float) -> void:
	if camera==null or not is_finite(milliseconds) or milliseconds<0.0:return
	_yaw=wrapf(_yaw+milliseconds*_yaw_rate,-PI,PI)
	camera.basis=Basis(Vector3.UP,_yaw)
	if sky!=null:sky.apply_view({"pose":camera.global_transform})
	if planets!=null:planets.apply_view({"pose":camera.global_transform})
	if _motion!=null and _motion.update(mini(roundi(milliseconds),int(SCENERY_STEP_LIMIT_MS))):
		if not scenery.apply_state(_motion.frame_snapshot()):error=scenery.error
	selection.camera_yaw=_yaw

func set_camera_yaw_rate(value: float) -> bool:
	if not is_finite(value) or absf(value)>1.0:return reject("Invalid background camera speed")
	_yaw_rate=value
	return true

func build_planets(library: RefCounted,bindings: RefCounted,visuals: RefCounted,cursor: int) -> bool:
	if _world==null or planets!=null:return reject("Prepare the background before adding its planets")
	var catalogues:=Catalogues.new()
	if not catalogues.open(library):return reject(catalogues.error)
	var candidate=preload("res://src/presentation/opening_planet_geometry.gd").new();_world.add_child(candidate)
	if not candidate.build_station(library,visuals,bindings,catalogues,int(selection.station_id),cursor) or not candidate.apply_view({"pose":camera.global_transform}):
		var problem: String=candidate.error;candidate.free();return reject(problem)
	var surfaces:=SurfaceResponse.new()
	if not surfaces.apply_branches([candidate],bindings,lighting.state,reflection):candidate.free();return reject(surfaces.error)
	planets=candidate
	return true

func set_active(value: bool) -> void:
	_active=value
	_refresh_update_mode()

func _refresh_update_mode() -> void:
	render_target_update_mode=SubViewport.UPDATE_ALWAYS if _active and _focused else SubViewport.UPDATE_DISABLED

func reject(message: String) -> bool:error=message;return false
