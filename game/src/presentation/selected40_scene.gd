extends Node3D
## Persistent source-selected scene. Native frames own all gameplay and time;
## this view composes shared renderers, rather than rebuilding test snapshots.
## The application still owns travel admission, remaining actions and results.
signal exit_requested(packet: Dictionary)
const Frame=preload("res://src/simulation/selected40_flight_frame.gd")
const EnvironmentView=preload("res://src/presentation/selected40_environment.gd")
const EncounterView=preload("res://src/presentation/full_hold_encounter_geometry.gd")
const Ship=preload("res://src/presentation/ship_geometry.gd")
const Field=preload("res://src/presentation/scenery_geometry.gd")
const Hud=preload("res://src/presentation/selected40_hud.gd")
const Exhaust=preload("res://src/presentation/selected40_exhaust.gd")
const Effects=preload("res://src/presentation/selected40_effects.gd")
const Feedback=preload("res://src/presentation/selected40_feedback.gd")
const FlightProjection=preload("res://src/presentation/flight_camera.gd")
const SecondaryPanel=preload("res://src/presentation/secondary_weapon_panel.gd")
const SceneryEffects=preload("res://src/content/scenery_effect_resources.gd")
const Reflection=preload("res://src/presentation/environment_reflection.gd")
const OrdinaryScene=preload("res://src/presentation/first_flight_scene.gd")
var error:=""
var environment: Node3D
var encounter: Node3D
var player: Node3D
var scenery: Node3D
var exhaust: Node3D
var effects: Node3D
var camera: Camera3D
var hud: Control
var feedback: Control
var secondary_panel: Control
var overlay: Control
var _projection: RefCounted
var _identity: RefCounted
var _revision:=-1
var _elapsed_ms:=-1
var _viewport:=Vector2i.ZERO
var _transition:={}

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,catalogues: RefCounted,world: RefCounted,viewport:=Vector2i(1440,900)) -> bool:
	error=""
	if _identity!=null or not get_children().is_empty() or not world is Frame or not Frame.valid_viewport(viewport):return reject("Configure the selected scene once with its native initial frame")
	var state: Dictionary=world.frame_context()
	if state.is_empty() or state.revision!=0 or state.elapsed_ms!=0 or not state.boundary.is_empty():return reject("Register selected scene feedback before native flight time begins")
	_projection=FlightProjection.new()
	var problem: String=_projection.configure(bindings.flight_projection,40,false)
	if not problem.is_empty():return reject(problem)
	camera=Camera3D.new();add_child(camera);camera.current=true
	environment=EnvironmentView.new();encounter=EncounterView.new();player=Ship.new();scenery=Field.new();exhaust=Exhaust.new();effects=Effects.new()
	for node in [environment,encounter,player,scenery,exhaust,effects]:add_child(node)
	if not environment.configure(library,visuals,bindings,catalogues,world):return failed_build(environment.error)
	if not encounter.build_selected40(world.encounter_owner(),library,visuals,bindings):return failed_build(encounter.error)
	if not player.build(int(world.player_owner().loadout().ship_id),library,visuals,bindings,"high",null,true):return failed_build(player.error)
	var field: Dictionary=world.scenery_owner().read_snapshot()
	if not scenery.build(field,library,visuals,bindings,"high",true):return failed_build(scenery.error)
	var resources:=SceneryEffects.new();var reflection:=Reflection.new()
	if not resources.configure(library,bindings) or not reflection.build(library,bindings,catalogues,int(environment.lights.state.system_id),false):return failed_build(resources.error+reflection.error)
	if not scenery.prepare_destruction(field,library,visuals,bindings,resources,environment.lights.state,reflection,OrdinaryScene.EFFECT_RESPONSE):return failed_build(scenery.error)
	if not exhaust.configure(library,bindings,visuals,world) or not effects.configure(library,bindings,visuals,world):return failed_build(exhaust.error+effects.error)
	overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(overlay);overlay.size=Vector2(viewport)
	hud=Hud.new();feedback=Feedback.new();secondary_panel=SecondaryPanel.new()
	for node in [hud,secondary_panel,feedback]:
		overlay.add_child(node);node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not hud.configure(library,bindings,visuals,world) or not secondary_panel.configure(library,bindings,visuals) or not feedback.configure(library,bindings,visuals,world):return failed_build(hud.error+secondary_panel.error+feedback.error)
	feedback.exit_requested.connect(_request_exit)
	_identity=world.presentation_identity()
	if not present(world,viewport):return failed_build(error)
	return true

func present(world: RefCounted,viewport: Vector2i) -> bool:
	error=""
	if _identity==null or not world is Frame or world.presentation_identity()!=_identity or not _transition.is_empty() or not Frame.valid_viewport(viewport):return reject("Selected scene cannot substitute a flight, exit or viewport")
	var state: Dictionary=world.frame_context()
	if state.is_empty() or not state.boundary.is_empty() or state.phase!="ready" or state.revision<_revision or state.elapsed_ms<_elapsed_ms:return reject("Selected scene requires a complete forward native frame")
	# Prepare the entire shared cast, shots and impacts before any displayed
	# scene changes. A final-actor/resource failure must not leak half a cast.
	var owner: RefCounted=world.encounter_owner()
	var view: Dictionary=state.encounter.view
	var detail: Dictionary=world.detail_state()
	var cast: Dictionary=encounter.prepare_world(owner,view.camera.pose,detail)
	if cast.is_empty():return reject(encounter.error)
	var selection: Dictionary=detail.selections.get("player",{})
	if not player.valid_selection(selection):return reject("Selected scene lost its retained player detail")
	var sound: Dictionary=feedback.audio.prepare_selected40(world)
	if sound.is_empty():return reject(feedback.audio.error)
	if not environment.present(world,viewport):return reject(environment.error)
	var field_owner: RefCounted=world.scenery_owner();var field: Dictionary=field_owner.read_snapshot()
	if not scenery.apply_state(field) or not scenery.apply_detail(field.detail) or not scenery.apply_activity(field.bodies):return failed_display(scenery.error)
	if not scenery.apply_destruction(field_owner,view.camera.pose,PackedByteArray([255,255,255,255]),Vector4.ONE,1.0):return failed_display(scenery.error)
	if not exhaust.present(world) or not effects.present(world) or not hud.present(world):return failed_display(exhaust.error+effects.error+hud.error)
	if not secondary_panel.present(world.secondary_feedback()):return failed_display(secondary_panel.error)
	secondary_panel.set_interaction(not state.encounter.sequence.input_blocked and not world.campaign_dialogue_visible(),false)
	secondary_panel.set_hud_visible(state.encounter.sequence.hud_visible and not world.campaign_dialogue_visible())
	var occupied: Dictionary=hud.visible_state()
	secondary_panel.set_top_inset(maxf(occupied.gauges_bottom,maxf(occupied.notice_rect.end.y,occupied.radio_rect.end.y))+8)
	var problem: String=_projection.apply(camera,view.camera)
	if not problem.is_empty():return failed_display(problem)
	encounter.commit_world(cast)
	player.transform=state.player_pose;player.apply_selection(selection)
	player.apply_camera_suppression(view.player_render_suppressed)
	var destruction: Dictionary=world.destruction_owner().snapshot()
	player.visible=destruction.body_visible
	if destruction.phase!="ready" and player.engine_glow!=null:player.engine_glow.hide()
	# Audible events are committed last, only after the complete scene accepted.
	if not feedback.present(world,state.elapsed_ms):return failed_display(feedback.error)
	overlay.size=Vector2(viewport)
	_revision=state.revision;_elapsed_ms=state.elapsed_ms;_viewport=viewport
	return true

func _request_exit(packet: Dictionary) -> void:
	if not _transition.is_empty():return
	_transition=packet.duplicate(true)
	feedback.set_active(false)
	exit_requested.emit(packet.duplicate(true))

func handle_event(event: InputEvent) -> bool:return feedback!=null and feedback.handle_event(event)
func set_paused(value: bool) -> void:
	if feedback!=null:feedback.set_paused(value)
func world_owner() -> RefCounted:return null if feedback==null else feedback.world_owner()
func snapshot() -> Dictionary:
	return {} if _revision<0 else {"revision":_revision,"elapsed_ms":_elapsed_ms,"viewport":_viewport,"transition":_transition.duplicate(true),"camera":camera.global_transform,"player_pose":player.transform,"actor_count":encounter.actors.size(),"scenery_count":scenery.objects.size()}

func failed_display(message: String) -> bool:
	# A missing presentation resource is not a successful simulation/route
	# transition. Stop drawing rather than leave a misleading mixed frame.
	hide()
	if overlay!=null:overlay.hide()
	return reject(message)
func failed_build(message: String) -> bool:
	for child in get_children():child.free()
	environment=null;encounter=null;player=null;scenery=null;exhaust=null;effects=null;camera=null;hud=null;feedback=null;secondary_panel=null;overlay=null
	_identity=null;_projection=null;_revision=-1;_elapsed_ms=-1
	return reject(message)
func reject(message: String) -> bool:error=message;return false
