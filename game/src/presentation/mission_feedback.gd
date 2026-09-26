extends Control
## Original game-over and audio feedback for the selected40 native component.
## This is not a departure/scene capability. A caller receives source state1;
## it must route the menu itself, without fabricating a retry or saved result.
signal exit_requested(packet: Dictionary)
signal transition_rejected(message: String)
signal world_changed(world: RefCounted)
const Context=preload("res://src/simulation/mission_context.gd")
const Frame=preload("res://src/simulation/selected40_flight_frame.gd")
const GameOver=preload("res://src/presentation/game_over_panel.gd")
const Audio=preload("res://src/presentation/opening_audio.gd")
const Dialogue=preload("res://src/presentation/station_dialogue_panel.gd")
var error:=""
var panel: Control
var audio: Node3D
var dialogue: Control
var speech: Node
var _world: RefCounted
var _identity: RefCounted
var _absolute_ms:=0
var _active:=true
var _paused:=false

func _init() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE

func _configure_audio(owner: Node3D,library: RefCounted,bindings: RefCounted,world: RefCounted) -> bool:
	return owner.configure_selected40(library,bindings,world) if Context.from_owner(world)==null else owner.configure_mission(library,bindings,world)

func prepare_audio(world: RefCounted) -> Dictionary:
	return audio.prepare_selected40(world) if Context.from_owner(world)==null else audio.prepare_mission(world)

func _configure_dialogue(library: RefCounted,bindings: RefCounted,visuals: RefCounted,world: RefCounted) -> bool:
	var context:=Context.from_owner(world)
	if context==null:return dialogue.configure_campaign_failure(library,bindings,visuals)
	var recipe: Dictionary=context.recipe()
	var rules: Dictionary=load("res://src/content/kappa_outcome_definitions.gd").failure_presentation(bindings)
	rules=rules.duplicate(true);rules.events=recipe.briefing+recipe.result.lines
	return dialogue._configure_resources(library,bindings,visuals,rules)

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,world: RefCounted) -> bool:
	error=""
	if _world!=null or not (world is Frame or Context.from_owner(world)!=null):return reject("Configure selected40 feedback once with its native frame")
	var next_panel:=GameOver.new();add_child(next_panel)
	next_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var next_audio:=Audio.new();add_child(next_audio)
	if not next_panel.configure(library,bindings,visuals,world.destruction_owner()) or not _configure_audio(next_audio,library,bindings,world):
		var reason: String=next_panel.error+next_audio.error
		next_panel.free();next_audio.free();return reject(reason)
	panel=next_panel;audio=next_audio;_identity=world.presentation_identity()
	dialogue=Dialogue.new();add_child(dialogue);dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _configure_dialogue(library,bindings,visuals,world):
		var reason: String=dialogue.error
		dialogue.free();panel.free();audio.free();dialogue=null;panel=null;audio=null;_identity=null
		return reject(reason)
	var context:=Context.from_owner(world)
	if context!=null:
		speech=load("res://src/presentation/station_audio.gd").new();add_child(speech)
		if not speech.configure_mission(library,bindings,context):return reject(speech.error)
	dialogue.next_requested.connect(func():
		if not request_exit():transition_rejected.emit(error))
	dialogue.previous_requested.connect(func():
		if not request_navigation("previous"):transition_rejected.emit(error))
	panel.continue_requested.connect(func():
		if not request_exit():transition_rejected.emit(error))
	if not present(world,0):
		panel.free();audio.free();dialogue.free();panel=null;audio=null;dialogue=null;_identity=null;return false
	return true

func present(world: RefCounted,absolute_milliseconds: Variant) -> bool:
	error=""
	if not (world is Frame or Context.from_owner(world)!=null) or panel==null or audio==null or world.presentation_identity()!=_identity:return reject("Selected40 feedback belongs to another native flight")
	if _world!=null and not _world.prepare_game_over().is_empty() and world.prepare_game_over()!=_world.prepare_game_over():return reject("Accepted selected40 Continue cannot be undone by replaying its parent")
	# Nothing audible is committed until the LAST original panel accepts the
	# candidate. A bad clock/foreign destruction owner retains the old world,
	# art, sound serial, playback instances and audio random stream together.
	var sound: Dictionary=prepare_audio(world)
	if sound.is_empty():return reject(audio.error)
	if _paused and not sound.get("repeat",false):return reject("Paused selected40 feedback cannot accept a new simulation frame")
	if not panel.present(world.destruction_owner(),absolute_milliseconds):return reject(panel.error)
	if not dialogue.present(world.campaign_result()):return reject(dialogue.error)
	if speech!=null and not speech.present_mission(world.dialogue()):return reject(speech.error)
	_world=world.fork_for_frame();_absolute_ms=absolute_milliseconds
	audio.commit_frame(sound)
	_sync_input()
	return true

func request_exit() -> bool:
	error=""
	if _world==null or not _active or _paused:return reject("Selected40 Continue is inactive")
	if Context.from_owner(_world)!=null and _world.campaign_dialogue_visible():return request_navigation("next")
	var next: RefCounted=_world.request_campaign_failure_exit() if _world.campaign_dialogue_visible() else _world.request_game_over_exit()
	if next==null:return reject(_world.error)
	if not present(next,_absolute_ms):return false
	exit_requested.emit(next.prepare_game_over())
	return true

func request_navigation(action: String) -> bool:
	if _world==null or not _active or _paused or Context.from_owner(_world)==null:return reject("Mission conversation input is inactive")
	var next: RefCounted=_world.navigate(action)
	if next==null:return reject(_world.error)
	var exit_packet: Dictionary=next.prepare_game_over()
	if not exit_packet.is_empty():
		if not present(next,_absolute_ms):return false
		exit_requested.emit(exit_packet)
	else:world_changed.emit(next)
	return true

func handle_event(event: InputEvent) -> bool:
	# Observe release edges even when paused or before the death/fade boundary.
	if panel!=null and _world!=null and _world.campaign_dialogue_visible():
		var accepted: bool=panel.acknowledgement_edge(event)
		if not accepted or not _active or _paused or not dialogue.is_visible_in_tree():return false
		if not request_exit():transition_rejected.emit(error)
		return true
	return panel!=null and panel.handle_event(event)

func set_active(value: bool) -> void:_active=value;_sync_input()
func set_paused(value: bool) -> void:
	_paused=value
	_sync_input()

func _sync_input() -> void:
	var modal: bool=_world!=null and _world.campaign_dialogue_visible()
	var enabled: bool=_active and not _paused and _world!=null and _world.prepare_game_over().is_empty()
	if panel!=null:panel.set_active(enabled and not modal)
	if dialogue!=null:dialogue.set_active(enabled and modal)
	if audio!=null:audio.set_paused(_paused or modal)
	if speech!=null:speech.set_paused(_paused)

func world_owner() -> RefCounted:return null if _world==null else _world.fork_for_frame()
func prepare_game_over() -> Dictionary:return {} if _world==null else _world.prepare_game_over()
func snapshot() -> Dictionary:
	return {} if _world==null else {"revision":_world.frame_context().revision,"absolute_ms":_absolute_ms,"panel":panel.snapshot(),"audio":audio.snapshot(),"campaign_result":_world.campaign_result(),"transition":prepare_game_over()}
func reject(message: String) -> bool:error=message;return false
