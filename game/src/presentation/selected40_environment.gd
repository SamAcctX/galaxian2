extends Node3D
## Original ordinary-location background and station, bound to a native selected
## entry rather than a rewritten origin cache. Docking and caller routing
## remain separate: this compositor does not pretend to be a complete flight scene.
const Frame=preload("res://src/simulation/selected40_flight_frame.gd")
const Background=preload("res://src/presentation/opening_sky.gd")
const Planets=preload("res://src/presentation/opening_planet_geometry.gd")
const Sun=preload("res://src/presentation/opening_sun_geometry.gd")
const Lighting=preload("res://src/presentation/opening_lighting.gd")
const Station=preload("res://src/presentation/station_exterior_geometry.gd")
const Portal=preload("res://src/presentation/void_portal_geometry.gd")
var error:=""
var sky: Node3D
var planets: Node3D
var sun: Node3D
var lights: Node3D
var station: Node3D
var portal: Node3D
var _identity: RefCounted
var _entry:={}
var _revision:=-1
var _elapsed_ms:=-1
var _intensity:=0.0
var _camera:={}
var _viewport:=Vector2i.ZERO
var _portal_state:={}

func configure(library: RefCounted,visuals: RefCounted,bindings: RefCounted,catalogues: RefCounted,world: RefCounted) -> bool:
	error=""
	if _identity!=null or not world is Frame:return reject("Selected40 environment requires its unregistered native flight")
	var state: Dictionary=world.environment_state()
	if state.is_empty():return reject("Selected40 environment has no prepared native entry")
	var entry: Dictionary=state.entry
	if entry.get("selected40")!=true or entry.get("mission_kind")!=161 or entry.get("world_type")!=3:return reject("Selected40 environment lost its source-selected ordinary world")
	for key in ["base_content_id","binding_id"]:
		if entry.get(key)!=bindings.get(key):return reject("Selected40 environment belongs to another source")
	var exterior: RefCounted=world.station_owner()
	if exterior==null or exterior.snapshot().station_id!=entry.station_id or exterior.snapshot().system_id!=entry.system_id:return reject("Selected40 station differs from its native entry")
	var native_portal: RefCounted=world.portal_owner()
	if native_portal==null or native_portal.selected40_construction_owner()!=world.player_owner().selected40_construction_owner():return reject("Selected40 environment lost its native portal generation")
	sky=Background.new();planets=Planets.new();sun=Sun.new();lights=Lighting.new();station=Station.new();portal=Portal.new()
	for node in [sky,planets,sun,lights,station,portal]:add_child(node)
	if not sky.build_station(library,visuals,bindings,catalogues,int(entry.station_id)):return fail(sky.error)
	if not sky.enable_space_fog(library,visuals,bindings,catalogues):return fail(sky.error)
	if not planets.build_station(library,visuals,bindings,catalogues,int(entry.station_id),int(entry.campaign_cursor)):return fail(planets.error)
	if not sun.build_station(library,visuals,bindings,catalogues,int(entry.station_id),int(entry.campaign_cursor)):return fail(sun.error)
	if not lights.build_station(bindings,catalogues,int(entry.station_id)):return fail(lights.error)
	if not station.build(library,visuals,bindings,exterior):return fail(station.error)
	if not portal.build_selected40(library,visuals,bindings,native_portal):return fail(portal.error)
	_identity=world.presentation_identity();_entry=entry.duplicate(true)
	return true

func present(world: RefCounted,viewport: Vector2i) -> bool:
	error=""
	if not world is Frame or _identity==null or world.presentation_identity()!=_identity:return reject("Selected40 background rejected another native flight")
	var state: Dictionary=world.environment_state()
	if state.is_empty() or state.entry!=_entry or state.revision<_revision or state.elapsed_ms<_elapsed_ms or not Frame.valid_viewport(viewport):return reject("Selected40 background lost its retained entry, clock or viewport")
	if state.revision==_revision:
		if state.elapsed_ms!=_elapsed_ms or state.camera!=_camera or viewport!=_viewport or state.portal!=_portal_state:return reject("Repeated selected40 background changed its accepted view")
		return true
	if state.portal.animation_elapsed_ms!=state.elapsed_ms:return reject("Selected40 portal animation diverged from its native environment clock")
	var portal_frame: Dictionary=portal.prepare_state(state.portal)
	if portal_frame.is_empty():return reject(portal.error)
	# Validate the unchanged station owner before any camera-dependent child is
	# moved. A rejected native frame must not partially update the background.
	if not station.apply_state(world.station_owner().snapshot()):return reject(station.error)
	var prepared: Dictionary=sun.prepare_frame(state.camera,viewport,_intensity)
	if prepared.has("error"):return reject(sun.error)
	var sky_frame: Dictionary=sky.prepare_view(state.camera)
	if sky_frame.is_empty() or not planets.apply_view(state.camera):return reject(sky.error+planets.error)
	sky.commit_view(sky_frame)
	sun.commit_frame(prepared)
	portal.commit_state(portal_frame);_portal_state=state.portal.duplicate(true)
	_intensity=prepared.next_intensity;_revision=state.revision;_elapsed_ms=state.elapsed_ms;_camera=state.camera.duplicate(true);_viewport=viewport
	return true

func snapshot() -> Dictionary:
	if _identity==null:return {}
	return {"entry":_entry.duplicate(true),"revision":_revision,"elapsed_ms":_elapsed_ms,"intensity":_intensity,
		"sky":sky.selection.duplicate(true),"planets":planets.selection.duplicate(true),"sun":sun.selection.duplicate(true),"lights":lights.state.duplicate(true),"portal":_portal_state.duplicate(true)}

func fail(message: String) -> bool:
	for node in get_children():node.free()
	sky=null;planets=null;sun=null;lights=null;station=null;portal=null
	return reject(message)
func reject(message: String) -> bool:error=message;return false
