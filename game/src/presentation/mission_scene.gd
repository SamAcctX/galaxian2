extends Node3D
## Persistent source-selected scene. Native frames own all gameplay and time;
## this view composes shared renderers, rather than rebuilding test snapshots.
## The application still owns travel admission, remaining actions and results.
signal exit_requested(packet: Dictionary)
signal world_changed(world: RefCounted)
const Context=preload("res://src/simulation/mission_context.gd")
const Frame=preload("res://src/simulation/selected40_flight_frame.gd")
const EnvironmentView=preload("res://src/presentation/mission_environment.gd")
const EncounterView=preload("res://src/presentation/full_hold_encounter_geometry.gd")
const Ship=preload("res://src/presentation/ship_geometry.gd")
const Field=preload("res://src/presentation/scenery_geometry.gd")
const Hud=preload("res://src/presentation/mission_hud.gd")
const Exhaust=preload("res://src/presentation/mission_exhaust.gd")
const Effects=preload("res://src/presentation/mission_effects.gd")
const Feedback=preload("res://src/presentation/mission_feedback.gd")
const FlightProjection=preload("res://src/presentation/flight_camera.gd")
const SecondaryPanel=preload("res://src/presentation/secondary_weapon_panel.gd")
const SceneryEffects=preload("res://src/content/scenery_effect_resources.gd")
const SurfaceResponse=preload("res://src/presentation/surface_response.gd")
const ImportedModel=preload("res://src/presentation/imported_model.gd")
const OrdinaryScene=preload("res://src/presentation/first_flight_scene.gd")
const SequenceEffects=preload("res://src/presentation/mission_sequence_effects.gd")
const SequenceAudio=preload("res://src/presentation/mission_sequence_audio.gd")
const AudioResources=preload("res://src/content/audio_resources.gd")
const OverlayLayer=preload("res://src/presentation/scene_overlay.gd")
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
var overlay_layer: CanvasLayer
var sequence_effects: Node3D
var sequence_audio: Node3D
var sequence_fade: ColorRect
var _sequence_context: RefCounted
var _escape_sound_revision:=-1
var _sequence_sound_revision:=-1
var _projection: RefCounted
var _identity: RefCounted
var _revision:=-1
var _elapsed_ms:=-1
var _viewport:=Vector2i.ZERO
var _transition:={}

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,catalogues: RefCounted,world: RefCounted,viewport:=Vector2i(1440,900)) -> bool:
	error=""
	if _identity!=null or not get_children().is_empty() or not (world is Frame or Context.from_owner(world)!=null) or not Frame.valid_viewport(viewport):return reject("Configure the selected scene once with its native initial frame")
	var state: Dictionary=world.frame_context()
	if state.is_empty() or state.revision!=0 or state.elapsed_ms!=0 or not state.boundary.is_empty():return reject("Register selected scene feedback before native flight time begins")
	_projection=FlightProjection.new()
	var context:=Context.from_owner(world)
	var problem: String=_projection.configure(bindings.flight_projection,int(state.player.campaign_cursor),context!=null and context.has_feature("void_environment"))
	if not problem.is_empty():return reject(problem)
	camera=Camera3D.new();add_child(camera);camera.current=true
	environment=EnvironmentView.new();encounter=EncounterView.new();player=Ship.new();scenery=Field.new();exhaust=Exhaust.new();effects=Effects.new()
	for node in [environment,encounter,player,scenery,exhaust,effects]:add_child(node)
	if not environment.configure(library,visuals,bindings,catalogues,world):return failed_build(environment.error)
	var cast_ready: bool=encounter.build(world.encounter_owner(),library,visuals,bindings) if context!=null else encounter.build_selected40(world.encounter_owner(),library,visuals,bindings)
	if not cast_ready:return failed_build(encounter.error)
	if not player.build(int(world.player_owner().loadout().ship_id),library,visuals,bindings,"high",null,true):return failed_build(player.error)
	var field: Dictionary=world.scenery_owner().read_snapshot()
	if not scenery.build(field,library,visuals,bindings,"high",true):return failed_build(scenery.error)
	var resources:=SceneryEffects.new();var reflection: RefCounted=environment.reflection
	if environment.lights!=null:
		if not resources.configure(library,bindings):return failed_build(resources.error)
		if not scenery.prepare_destruction(field,library,visuals,bindings,resources,environment.lights.state,reflection,OrdinaryScene.EFFECT_RESPONSE):return failed_build(scenery.error)
		var models:=[]
		for branch in [player,encounter]+environment.surface_roots():
			for child in branch.find_children("*","",true,false):
				if child.get_script()==ImportedModel:models.append(child)
		var adapter:=SurfaceResponse.new()
		var response: Dictionary=OrdinaryScene.EFFECT_RESPONSE
		var materials:=adapter.prepare_models(models,bindings.surface_material,environment.lights.state,reflection.texture,response.diffuse_bias,response.normal_bias,"two_light_cube")
		if materials.is_empty():return failed_build(adapter.error)
		SurfaceResponse.commit_models(materials)
	if not exhaust.configure(library,bindings,visuals,world) or not effects.configure(library,bindings,visuals,world):return failed_build(exhaust.error+effects.error)
	if context!=null:
		var recipe: Dictionary=context.recipe()
		if not recipe.get("sequence_models",[]).is_empty():
			sequence_effects=SequenceEffects.new();add_child(sequence_effects)
			# Old imported packs may supply a separately validated same-source mesh
			# supplement. New imports resolve these records normally; never relabel.
			if not sequence_effects.configure(context,library,visuals,bindings,recipe.sequence_models,OS.get_environment("GOF2_SEQUENCE_MESH_SUPPLEMENT")):return failed_build(sequence_effects.error)
		var sound_ids: Array=recipe.get("sequence_sounds",[]).duplicate()
		for id in recipe.get("escape_sounds",[]):
			if id not in sound_ids:sound_ids.append(id)
		if not sound_ids.is_empty():
			var resources_audio:=AudioResources.new()
			sequence_audio=SequenceAudio.new();add_child(sequence_audio)
			if not resources_audio.configure(library,bindings,int(context.identity().campaign_cursor)) or not sequence_audio.configure(context,resources_audio,bindings,sound_ids):return failed_build(resources_audio.error+sequence_audio.error)
		_sequence_context=context
	overlay_layer=OverlayLayer.new();add_child(overlay_layer)
	if not overlay_layer.error.is_empty():return failed_build(overlay_layer.error)
	overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay_layer.add_child(overlay);overlay.size=Vector2(viewport)
	hud=Hud.new();feedback=Feedback.new();secondary_panel=SecondaryPanel.new()
	for node in [hud,secondary_panel,feedback]:
		overlay.add_child(node);node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not hud.configure(library,bindings,visuals,world) or not secondary_panel.configure(library,bindings,visuals) or not feedback.configure(library,bindings,visuals,world):return failed_build(hud.error+secondary_panel.error+feedback.error)
	feedback.exit_requested.connect(_request_exit)
	if feedback.has_signal("world_changed"):feedback.world_changed.connect(_request_world)
	sequence_fade=ColorRect.new();overlay.add_child(sequence_fade)
	sequence_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sequence_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;sequence_fade.color=Color(0,0,0,0);sequence_fade.hide()
	_identity=world.presentation_identity()
	if not present(world,viewport):return failed_build(error)
	return true

func present(world: RefCounted,viewport: Vector2i) -> bool:
	error=""
	if _identity==null or not (world is Frame or Context.from_owner(world)!=null) or world.presentation_identity()!=_identity or not _transition.is_empty() or not Frame.valid_viewport(viewport):return reject("Selected scene cannot substitute a flight, exit or viewport")
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
	var sound: Dictionary=feedback.prepare_audio(world)
	if sound.is_empty():return reject(feedback.audio.error)
	var escape: Dictionary=state.get("escape",{})
	var animation:={};var sequence_sound:={}
	if sequence_effects!=null:
		var models:=[]
		for declaration in _sequence_context.recipe().sequence_models:
			models.append({"model_id":declaration.model_id,"visible":escape.get("explosions_visible",false),"time_ms":int(escape.get("explosion_elapsed_ms",0))})
		animation=sequence_effects.prepare_state(_sequence_context,{"revision":state.revision,"models":models,"mothership_visible":escape.get("mothership_visible",true)},-view.camera.pose.basis.z)
		if animation.is_empty():return reject(sequence_effects.error)
	var audio_state: Dictionary=world.audio_state()
	if sequence_audio!=null:
		var cues:=[]
		# Conversation navigation has a new flight revision but retains the last
		# choreography frame. Only a new sequence revision owns new sound cues.
		if int(audio_state.get("sequence_revision",-1))>_sequence_sound_revision:
			cues.append_array(audio_state.get("sequence_audio",[]).duplicate(true))
		if not escape.is_empty() and escape.revision>_escape_sound_revision:
			for cue in escape.frame.audio:
				if cue.action=="update":
					cues.append({"action":"position","sound_id":cue.sound_id,"position":cue.position,"velocity":cue.velocity})
					for index in cue.parameters:cues.append({"action":"parameter","sound_id":cue.sound_id,"index":index,"value":cue.parameters[index]})
				else:cues.append(cue.duplicate(true))
		sequence_sound={"repeat":true} if state.revision==_revision else sequence_audio.prepare_frame(_sequence_context,{"revision":state.revision,"delta_ms":0 if _elapsed_ms<0 else int(state.elapsed_ms)-_elapsed_ms,"cues":cues,"actor_engines":audio_state.get("actor_engines",{}),"stopped":world.destruction_owner().snapshot().phase!="ready"},view.camera.pose)
		if sequence_sound.is_empty():return reject(sequence_audio.error)
	if not environment.present(world,viewport):return reject(environment.error)
	var field_owner: RefCounted=world.scenery_owner();var field: Dictionary=field_owner.read_snapshot()
	if not scenery.apply_state(field) or not scenery.apply_detail(field.detail) or not scenery.apply_activity(field.bodies):return failed_display(scenery.error)
	if environment.lights!=null and not scenery.apply_destruction(field_owner,view.camera.pose,PackedByteArray([255,255,255,255]),Vector4.ONE,1.0):return failed_display(scenery.error)
	if not exhaust.present(world) or not effects.present(world) or not hud.present(world):return failed_display(exhaust.error+effects.error+hud.error)
	if not secondary_panel.present(world.secondary_feedback()):return failed_display(secondary_panel.error)
	secondary_panel.set_interaction(not state.encounter.sequence.input_blocked and not world.campaign_dialogue_visible(),false)
	secondary_panel.set_hud_visible(state.encounter.sequence.hud_visible and not world.campaign_dialogue_visible())
	var occupied: Dictionary=hud.visible_state()
	secondary_panel.set_top_inset(maxf(occupied.gauges_bottom,maxf(occupied.notice_rect.end.y,occupied.radio_rect.end.y))+8)
	var problem: String=_projection.apply(camera,view.camera)
	if not problem.is_empty():return failed_display(problem)
	if float(escape.get("vertical_fov_radians",0.0))>0:camera.fov=rad_to_deg(float(escape.vertical_fov_radians))
	encounter.commit_world(cast)
	if not animation.is_empty() and not animation.get("repeat",false) and not sequence_effects.commit_state(animation):return failed_display("Sequence model frame was superseded")
	player.transform=state.player_pose;player.apply_selection(selection)
	player.apply_camera_suppression(view.player_render_suppressed)
	var destruction: Dictionary=world.destruction_owner().snapshot()
	player.visible=destruction.body_visible and state.encounter.sequence.get("player_visible",true)
	exhaust.visible=state.encounter.sequence.get("player_particles_visible",true)
	var alpha: float=float(escape.get("fade",{}).get("alpha_byte",0))/255.0
	sequence_fade.color=Color(0,0,0,alpha);sequence_fade.visible=alpha>0
	if destruction.phase!="ready" and player.engine_glow!=null:player.engine_glow.hide()
	# Audible events are committed last, only after the complete scene accepted.
	if not feedback.present(world,state.elapsed_ms):return failed_display(feedback.error)
	if not sequence_sound.is_empty() and not sequence_sound.get("repeat",false) and not sequence_audio.commit_frame(sequence_sound):return failed_display("Sequence sound frame was superseded")
	_escape_sound_revision=int(escape.get("revision",-1))
	_sequence_sound_revision=int(audio_state.get("sequence_revision",-1))
	overlay.size=Vector2(viewport)
	_revision=state.revision;_elapsed_ms=state.elapsed_ms;_viewport=viewport
	return true

func _request_exit(packet: Dictionary) -> void:
	if not _transition.is_empty():return
	_transition=packet.duplicate(true)
	feedback.set_active(false)
	exit_requested.emit(packet.duplicate(true))

func _request_world(candidate: RefCounted) -> void:
	if not present(candidate,_viewport):return
	world_changed.emit(candidate)

func handle_event(event: InputEvent) -> bool:return feedback!=null and feedback.handle_event(event)
func set_paused(value: bool) -> void:
	if feedback!=null:feedback.set_paused(value)
	if sequence_audio!=null:sequence_audio.set_paused(value)
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
	overlay_layer=null
	sequence_effects=null;sequence_audio=null;sequence_fade=null;_sequence_context=null;_escape_sound_revision=-1;_sequence_sound_revision=-1
	_identity=null;_projection=null;_revision=-1;_elapsed_ms=-1
	return reject(message)
func reject(message: String) -> bool:error=message;return false
