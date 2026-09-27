extends Node3D
## Application lifetime for an explicitly prepared native selected flight.
## The host owns controls and the menu. Original failure needs acknowledgement;
## onward travel still waits for its native world/career transaction.
signal transition_rejected(message: String)
const Context=preload("res://src/simulation/mission_context.gd")
const Construction=preload("res://src/simulation/selected40_flight_construction.gd")
const Scene=preload("res://src/presentation/mission_scene.gd")
const Clock=preload("res://src/simulation/frame_clock.gd")
const Controls=preload("res://src/input/flight_controls.gd")
const ACTIONS=["fire","brake","mouse_mode","throttle_up","throttle_down","missiles","secondary_next","secondary_menu","change_view"]
var error:=""
var status:="idle"
var scene: Node3D
var camera: Camera3D
var _clock: RefCounted
var _world: RefCounted
var _pauses:={}
var _active:=false
var _secondary_pending:=false
var _throttle:=1.0
var _observed_world: RefCounted
var _flight_read:={}

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,catalogues: RefCounted,construction: RefCounted,now_microseconds: int,viewport: Vector2i) -> bool:
	error=""
	if _world!=null or construction==null or not construction.has_method("world_owner"):return reject("Application session requires its native prepared flight constructor")
	var prepared: RefCounted=construction.world_owner()
	if prepared==null or (not construction is Construction and Context.from_owner(prepared)==null):return reject("Application session requires an admitted mission flight")
	var world: RefCounted=construction.world_owner();var clock:=Clock.new()
	if not clock.configure(bindings,library.manifest.content_id) or not clock.rebase(now_microseconds):return reject(clock.error)
	var next_scene:=Scene.new();add_child(next_scene)
	if not next_scene.configure(library,bindings,visuals,catalogues,world,viewport):
		var reason: String=next_scene.error;next_scene.free();return reject(reason)
	next_scene.feedback.set_active(false);next_scene.camera.current=false
	next_scene.secondary_panel.action_requested.connect(func(action_name):
		if not action(action_name):transition_rejected.emit(error))
	next_scene.secondary_panel.selection_requested.connect(func(item_id):
		if not confirm_secondary(item_id):transition_rejected.emit(error))
	next_scene.secondary_panel.selection_cancelled.connect(close_secondary)
	next_scene.exit_requested.connect(_accepted_exit)
	next_scene.world_changed.connect(_accepted_world)
	_world=world;_clock=clock;scene=next_scene;camera=scene.camera;status="prepared"
	return true

func activate() -> bool:
	if _world==null or _active or status!="prepared":return reject("Activate a prepared application flight exactly once")
	_active=true;status="running";camera.make_current();scene.feedback.set_active(true);scene.set_paused(is_paused())
	return true

func step(now_microseconds: int,commands:=Vector2.ZERO,primary_fire:=false,mouse_captured:=false,strafe:=0.0,brake:=false) -> bool:
	error=""
	if not _active or _world==null:return reject("Activate the selected application session before stepping")
	var clock: RefCounted=_clock.fork_for_frame()
	var seconds: float=clock.sample(now_microseconds,is_paused() or status!="running" or _world.campaign_dialogue_visible())
	if not clock.error.is_empty():return reject(clock.error)
	if is_paused() or status!="running" or _world.campaign_dialogue_visible():_clock=clock;clear_flight_input();return true
	var viewport:=Vector2i(get_viewport().get_visible_rect().size)
	var current_music: int=scene.feedback.audio.current_music_id()
	var next: RefCounted=_world.evaluate(int(round(seconds*1000.0)),commands,0.0 if brake else _throttle,primary_fire,false,viewport,strafe,_secondary_pending,current_music,mouse_captured)
	if next==null:return reject(_world.error)
	var state: Dictionary=next.frame_context()
	if not state.boundary.is_empty():
		# Preserve the final accepted display. This is a pending native boundary,
		# not permission to draw a partial frame or award a mission/job result.
		_world=next;_clock=clock;status=state.boundary;clear_flight_input();scene.set_paused(true)
		return true
	if not scene.present(next,viewport):return reject(scene.error)
	_world=next;_clock=clock;_secondary_pending=false
	if not can_control():clear_flight_input()
	return true

func action(name: String) -> bool:
	error=""
	if not can_control() or name not in ACTIONS:return reject("This action is unavailable in the current selected flight")
	var next: RefCounted
	match name:
		"secondary_menu":
			if not scene.secondary_panel.open_selection():return reject(scene.secondary_panel.error)
			return set_pause("secondary_menu",true,Time.get_ticks_usec())
		"missiles":_secondary_pending=true;return true
		"throttle_up":_throttle=minf(1.0,_throttle+0.1);return true
		"throttle_down":_throttle=maxf(0.0,_throttle-0.1);return true
		"change_view":next=_world.camera_input(3 if _flight_observation().camera_mode==0 else 0)
		"secondary_next":next=_world.cycle_secondary()
		_:return true # Held primary, brake and mouse steering belong to controls.
	if next==null:return reject(_world.error)
	if not scene.present(next,Vector2i(get_viewport().get_visible_rect().size)):return reject(scene.error)
	_world=next
	return true

func supports_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		return key in Controls.DIRECTIONS or Controls.KEY_ACTIONS.get(key) in ACTIONS
	if event is InputEventJoypadButton:return Controls.BUTTON_ACTIONS.get(event.button_index) in ACTIONS
	if event is InputEventJoypadMotion:return event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_TRIGGER_RIGHT,JOY_AXIS_TRIGGER_LEFT]
	return event is InputEventMouseMotion

func orbit_event(event: InputEvent) -> bool:
	if not can_control() or _flight_observation().camera_mode!=3:return false
	var input: Dictionary=_flight_observation().orbit_input
	var kind:="";var position:=Vector2i.ZERO
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed==bool(input.dragging):return false
		kind="press" if event.pressed else "release";position=Vector2i(event.position)
	elif event is InputEventMouseMotion and input.dragging:kind="move";position=Vector2i(event.position)
	else:return false
	var next: RefCounted=_world.camera_input(null,kind,position)
	if next==null:return reject(_world.error)
	if not scene.present(next,Vector2i(get_viewport().get_visible_rect().size)):return reject(scene.error)
	_world=next
	return true

func confirm_secondary(item_id: int) -> bool:
	error=""
	if not _pauses.get("secondary_menu",false) or _external_pause():return reject("Secondary selection is inactive")
	var next: RefCounted=_world.select_secondary(item_id)
	if next==null:return reject(_world.error)
	# This same-time selection is prepared before relinquishing the modal hold.
	# A rejected choice retains both the accepted world and the active menu.
	scene.feedback.set_paused(false)
	if not scene.present(next,Vector2i(get_viewport().get_visible_rect().size)):
		scene.feedback.set_paused(true);return reject(scene.error)
	_world=next;close_secondary()
	return true

func close_secondary() -> void:
	if scene==null or not _pauses.get("secondary_menu",false):return
	scene.secondary_panel.close_selection()
	set_pause("secondary_menu",false,Time.get_ticks_usec())

func handle_selection_event(event: InputEvent) -> bool:return scene!=null and scene.secondary_panel.handle_selection_event(event)
func _external_pause() -> bool:
	for reason in _pauses:
		if reason!="secondary_menu" and _pauses[reason]:return true
	return false

func set_pause(reason: String,value: bool,now_microseconds: int) -> bool:
	if _clock==null or reason not in ["user","focus","hidden","transition","secondary_menu"]:return reject("Unknown selected-flight pause reason")
	var clock: RefCounted=_clock.fork_for_frame()
	if not clock.rebase(now_microseconds):return reject(clock.error)
	_pauses[reason]=value;_clock=clock;clear_flight_input();scene.set_paused(is_paused() or status not in ["prepared","running"])
	scene.secondary_panel.set_selection_active(_active and not _external_pause())
	return true

func can_skip_cinematic() -> bool:
	return _active and status=="running" and not is_paused() and _world!=null and _world.has_method("can_skip_entry") and _world.can_skip_entry()

func cinematic_skipping() -> bool:return false

func request_cinematic_skip() -> bool:
	error=""
	if not can_skip_cinematic():return reject("No arrival introduction can be skipped")
	var next: RefCounted=_world.skip_entry()
	if next==null:return reject(_world.error)
	# The existing ordinary release owns briefing, damage permission and time.
	# Commit its zero-time candidate only after the retained scene accepts it.
	if not scene.present(next,Vector2i(get_viewport().get_visible_rect().size)):return reject(scene.error)
	_accepted_world(next)
	return true

func rebase_time(now_microseconds: int) -> bool:return _clock!=null and _clock.rebase(now_microseconds)
func clear_flight_input() -> void:_secondary_pending=false
func is_paused() -> bool:return _pauses.values().has(true)
func can_control() -> bool:
	if not _active or status!="running" or is_paused() or _world==null:return false
	var state:=_flight_observation()
	return not state.dialogue_visible and not state.portal_pending and not state.input_blocked and state.player_active and state.player_alive
func flight_hud_visible() -> bool:
	if not _active or _world==null:return false
	var state:=_flight_observation()
	return not state.dialogue_visible and state.hud_visible

## Small read-only observations of an accepted immutable flight. Session pause,
## activation and pending controls remain live, outside this owner-keyed memo.
func flight_observation() -> Dictionary:return _flight_observation().duplicate(true)
func _flight_observation() -> Dictionary:
	if _world==null:return {}
	if _world==_observed_world:return _flight_read
	var state: Dictionary=_world.frame_context()
	var sequence: Dictionary=state.encounter.sequence;var view: Dictionary=state.encounter.view
	var destruction: Dictionary=_world.destruction_owner().snapshot()
	_flight_read={"dialogue_visible":_world.campaign_dialogue_visible(),
		"portal_pending":not _world.prepare_portal_transition().is_empty(),
		"input_blocked":sequence.input_blocked,"hud_visible":sequence.hud_visible,
		"player_active":state.player.active,"player_alive":state.player.vitals.hull>0,
		"entry_released":sequence.get("entry_released",false),
		"camera_mode":view.camera_mode,"orbit_input":view.orbit_input.duplicate(true),
		"destruction_phase":destruction.phase,"game_over_visible":destruction.game_over_visible}
	_observed_world=_world
	return _flight_read
func flight_owner() -> RefCounted:return null if _world==null else _world.fork_for_frame()
func handle_game_over_event(event: InputEvent) -> bool:return scene!=null and scene.handle_event(event)
func prepare_game_over() -> Dictionary:return {} if _world==null else _world.prepare_game_over()

func _accepted_world(next: RefCounted) -> void:
	_world=next;clear_flight_input()
	_clock.rebase(Time.get_ticks_usec())

func _accepted_exit(packet: Dictionary) -> void:
	var next: RefCounted=scene.world_owner()
	if next==null or packet!=next.prepare_game_over() or packet.is_empty():reject("Selected application exit lost its native acknowledgement");transition_rejected.emit(error);return
	_world=next;status="game_over_transition_required";clear_flight_input()

func snapshot() -> Dictionary:
	if _world==null:return {}
	var state: Dictionary=_world.snapshot()
	# A living world can advance the story without replacing its player. The
	# player's entry cursor is not the current campaign observation.
	state.campaign_cursor=int(_world.campaign_result().campaign_cursor)
	state.status=status;state.paused=is_paused()
	return state
func reject(message: String) -> bool:error=message;return false
