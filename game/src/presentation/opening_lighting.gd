extends Node3D
## Location light state consumed by the native material renderer. Interior
## overrides retain the source location's fill, global ambient and rim.
const Lighting = preload("res://src/simulation/environment_lighting.gd")
const Loadout = preload("res://src/simulation/opening_loadout.gd")
const ArrivalLocation = preload("res://src/simulation/arrival_location.gd")
const Definitions = preload("res://src/content/opening_sky_definitions.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")
const StationView = preload("res://src/content/station_presentation_definitions.gd")
const Fog = preload("res://src/simulation/distance_fog.gd")
var error := ""
var state := {}
var lights: Array[DirectionalLight3D] = []
var environment: WorldEnvironment

func build(bindings: RefCounted, catalogues: RefCounted, content_id: String, campaign_cursor: Variant, world_type: Variant, location_match: Variant) -> bool:
	clear()
	if not Definitions.parameters(bindings.opening_sky) or not Numbers.integer(campaign_cursor,0,0) or not Numbers.integer(world_type,3,3) or not location_match is bool or location_match:
		return reject("Opening lighting requires the verified fresh opening context")
	var loadout := Loadout.new()
	if not loadout.configure(bindings,catalogues,content_id): return reject(loadout.error)
	return _build_station(bindings,catalogues,loadout.snapshot())

func build_arrival(bindings: RefCounted, catalogues: RefCounted, cache: Variant) -> bool:
	clear()
	var location:=ArrivalLocation.new()
	var context:=location.resolve(bindings,catalogues,cache)
	if context.is_empty():return reject(location.error)
	return _build_station(bindings,catalogues,context)

func build_departure(bindings: RefCounted, catalogues: RefCounted, cache: Variant, equipment: RefCounted=null, mission_context: RefCounted=null) -> bool:
	clear()
	var location:=ArrivalLocation.new()
	var context:=location.resolve_departure(bindings,catalogues,cache,equipment,mission_context)
	if context.is_empty():return reject(location.error)
	return _build_station(bindings,catalogues,context)

func _build_station(bindings: RefCounted, catalogues: RefCounted, context: Dictionary, interior:="") -> bool:
	var station: Dictionary = catalogues.tables.stations[context.station_id]
	var system: Dictionary = catalogues.tables.systems[context.system_id]
	var model := Lighting.new()
	var staged := model.for_station(bindings.environment_colors,context.station_id,station.get("planet_type"),system.get("sky_index"))
	if staged.is_empty(): return reject(model.error)
	if not interior.is_empty():
		var faction:=int(system.fields[int(bindings.hangars.system_field)])
		var surface: Dictionary=bindings.surface_material.duplicate(true)
		if interior=="hangar":
			var view:=StationView.ordinary_view(bindings.station_presentation,int(context.station_id),faction)
			if view.is_empty():return reject("Hangar lighting requires its bound station view")
			var data: Dictionary=view.light
			staged.lights[0]={"direction_to_light":-(Basis(Vector3.UP,float(data.initial_camera_yaw)).z+model.rgb(data.direction_bias)).normalized(),
				"ambient":model.rgb(data.ambient),"diffuse":model.rgb(data.diffuse),"specular":model.rgb(data.specular)}
			surface.ambient_rgb=[data.material_ambient,data.material_ambient,data.material_ambient]
			surface.specular_power=data.specular_power
		elif interior=="lounge":
			# Historical declaration name: this is the light's specular strength.
			staged.lights[0].specular=model.rgb(bindings.early_contracts.lounge_presentation.light_diffuse)
		else:return reject("Unknown interior light context")
		staged.surface_material=surface
		staged.fog=Fog.for_interior(staged.fog,faction,interior)
	return _build_state(bindings,context,staged)

func build_void(bindings: RefCounted,source: RefCounted) -> bool:
	clear()
	if bindings==null or not is_instance_of(source,load("res://src/simulation/void_environment.gd")):return reject("Void lighting requires its generated native environment")
	var context: Dictionary=source.snapshot()
	if context.get("base_content_id")!=bindings.base_content_id or context.get("binding_id")!=bindings.binding_id:return reject("Void lighting belongs to another content identity")
	var model:=Lighting.new()
	var staged:=model.for_void(bindings.environment_colors)
	if staged.is_empty():return reject(model.error)
	return _build_state(bindings,context,staged)

func _build_state(bindings: RefCounted,context: Dictionary,staged: Dictionary) -> bool:
	environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	var ambient: Vector3 = staged.global_ambient
	var strength := maxf(ambient.x,maxf(ambient.y,ambient.z))
	environment.environment.ambient_light_energy=strength
	environment.environment.ambient_light_color=encoded_color(ambient/strength if strength>0 else Vector3.ZERO)
	add_child(environment)
	for row in staged.lights:
		var light := DirectionalLight3D.new()
		var energy: float = maxf(row.diffuse.x,maxf(row.diffuse.y,row.diffuse.z))
		light.light_color=encoded_color(row.diffuse/energy if energy>0 else Vector3.ZERO)
		light.light_energy=energy
		light.light_specular=1.0
		light.basis=Basis.looking_at(-row.direction_to_light,Vector3.UP)
		light.shadow_enabled=false
		add_child(light);lights.append(light)
	state=staged
	state.base_content_id=bindings.base_content_id;state.binding_id=bindings.binding_id
	state.station_id=context.station_id;state.system_id=context.system_id
	return true

## Location resource preparation is not a departure or arrival permission.
func build_station(bindings: RefCounted,catalogues: RefCounted,station_id: int,interior:="") -> bool:
	clear()
	if bindings==null or catalogues==null or catalogues.content_id!=bindings.base_content_id or station_id<0 or station_id>=catalogues.tables.stations.size():return reject("Lighting requires a matching catalogue station")
	var system_id:=int(catalogues.tables.stations[station_id].system_id)
	if system_id<0 or system_id>=catalogues.tables.systems.size():return reject("Lighting station has no catalogue system")
	var context:={"station_id":station_id,"system_id":system_id}
	return _build_station(bindings,catalogues,context,interior)

func encoded_color(linear: Vector3) -> Color:
	return Color(linear.x,linear.y,linear.z).linear_to_srgb()

func clear() -> void:
	for child in get_children(): child.free()
	lights.clear();environment=null;state.clear();error=""

func reject(message: String) -> bool:
	clear();error=message
	return false
