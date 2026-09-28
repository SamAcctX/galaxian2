extends Control
## Passive native flight gauges, reticle, ship scanner and original radio art.
## The moving frame owns every sample and clock. This view cannot launch a trip,
## change ammunition, produce a result or stand in for missing flight systems.
const Context=preload("res://src/simulation/mission_context.gd")
const FlightFrame=preload("res://src/simulation/selected40_flight_frame.gd")
const Gauges=preload("res://src/presentation/flight_vitals_overlay.gd")
const Target=preload("res://src/presentation/flight_target_frame.gd")
const Reticle=preload("res://src/presentation/flight_aim_reticle.gd")
const Markers=preload("res://src/presentation/flight_npc_markers.gd")
const Radio=preload("res://src/presentation/radio_panel.gd")
const Resources=preload("res://src/presentation/opening_radio_resources.gd")
const Scan=preload("res://src/presentation/flight_scan_animation.gd")
const Notice=preload("res://src/presentation/flight_notice_panel.gd")
var error:=""
var _identity:={}
var _generation: RefCounted
var _context: RefCounted
var _layers: Array[Dictionary]=[]
var _front:=-1
var _sample:={}
var _layout_mode:=[]

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,frame: RefCounted) -> bool:
	error=""
	if not _layers.is_empty() or not (frame is FlightFrame or Context.from_owner(frame)!=null) or frame.presentation_identity()==null:return reject("Mission HUD requires one prepared native moving flight")
	var sample: Dictionary=frame.hud_state()
	if sample.is_empty() or library==null or bindings==null or visuals==null or sample.base_content_id!=bindings.base_content_id or sample.binding_id!=bindings.binding_id:return reject("Mission HUD lost its native flight content identity")
	var resources:=Resources.new()
	if not resources.prepare(library,bindings,visuals,int(sample.campaign_cursor)):return reject(resources.error)
	var pending: Array[Dictionary]=[]
	# Two prepared passive layers make a late rejected radio/marker sample
	# atomic: the previously accepted on-screen controls are never half updated.
	for index in 2:
		var layer:=Control.new();layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.visible=false
		var row:={"root":layer,"gauges":Gauges.new(),"target":Target.new(),"reticle":Reticle.new(),"markers":Markers.new(),"scan":Scan.new(),"notice":Notice.new(),"radio":Radio.new()}
		row.notice.layout_changed.connect(_layout_radio.bind(row))
		row.gauges.resized.connect(_layout_radio.bind(row))
		for key in ["gauges","target","reticle","markers","scan","notice","radio"]:
			layer.add_child(row[key]);row[key].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pending.append(row)
		var ready: bool=row.gauges.configure(library,bindings,visuals) and row.target.prepare(library,bindings,visuals) and row.reticle.prepare(library,bindings,visuals) and row.markers.prepare(library,bindings,visuals) and row.radio.configure(bindings.base_content_id,bindings.binding_id,library.active_language,resources.speakers,int(sample.campaign_cursor)) and row.radio.configure_art(library,bindings,visuals)
		ready=ready and row.scan.prepare(library,bindings,visuals,bindings.mining_targeting) and row.notice.configure(library,bindings,visuals)
		if not ready:
			var problem: String=row.gauges.error+row.target.error+row.reticle.error+row.markers.error+row.radio.error+row.scan.error+row.notice.error
			for staged in pending:staged.root.free()
			return reject(problem)
	for row in pending:
		add_child(row.root);row.root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layers=pending;_generation=frame.presentation_identity()
	_context=Context.from_owner(frame)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	# A retained world can outlive its active mission. Its capability and scene
	# generation remain authoritative; the radio keeps its own inherited queue.
	if _context==null:_identity.campaign_cursor=int(sample.campaign_cursor)
	return true

func present(frame: RefCounted) -> bool:
	error=""
	if _layers.is_empty() or not (frame is FlightFrame or Context.from_owner(frame)!=null) or frame.presentation_identity()!=_generation:return reject("Mission HUD cannot accept a detached or different flight generation")
	if _context!=null and Context.from_owner(frame)!=_context:return reject("Mission HUD cannot replace its admitted world")
	var sample: Dictionary=frame.hud_state()
	if sample.is_empty():return reject("Mission HUD requires a fully accepted native frame, not a pending result boundary")
	for key in _identity:
		if sample.get(key)!=_identity[key]:return reject("Mission HUD sample belongs to another content identity")
	if not _sample.is_empty():
		if sample.revision<_sample.revision or sample.elapsed_ms<_sample.elapsed_ms:return reject("Mission HUD rejected a regressed native frame")
		if sample.revision==_sample.revision:
			if sample!=_sample:return reject("Mission HUD frame revision was reused with different state")
			return true
	var index:=0 if _front<0 else 1-_front
	var staged: Dictionary=_layers[index]
	staged.root.visible=false
	if not staged.gauges.present(sample) or not staged.reticle.present(sample.player_aim) or not staged.markers.present(sample.npc_scanner,sample.mining_targeting.get("selected_object_index",-1)>=0) or not staged.radio.present(sample.radio):return reject(staged.gauges.error+staged.reticle.error+staged.markers.error+staged.radio.error)
	if not staged.scan.present(sample.mining_targeting) or not staged.notice.present(sample.flight_notices):return reject(staged.scan.error+staged.notice.error)
	staged.gauges.set_active(sample.hud_visible);staged.target.set_active(sample.hud_visible)
	if not sample.hud_visible:staged.reticle.visible=false;staged.markers.visible=false;staged.scan.visible=false;staged.notice.visible=false
	# Radio is intentionally independent of the flight-HUD cinematic gate.
	_layout_radio(staged)
	if _front>=0:
		staged.radio.inherit_scroll(_layers[_front].radio)
		_layers[_front].root.visible=false
	staged.root.visible=true;_front=index;_sample=sample.duplicate(true)
	return true

func snapshot() -> Dictionary:return _sample.duplicate(true)

## The source notice queue and radio have separate clocks and visibility gates.
## Keep both readable in the responsive native layout; do not hide a message,
## delay playback or restart a notice fade to compensate for overlapping art.
func _layout_radio(row: Dictionary) -> void:
	# Narrow desktop windows move the centered radio beneath the corner gauges.
	# Both components report their own actual layout, including hidden HUD frames.
	row.radio.set_top_inset(maxf(row.notice.bottom_inset(),row.gauges.top_inset()))

func visible_state() -> Dictionary:
	if _front<0:return {}
	var row: Dictionary=_layers[_front]
	return {"gauges":row.gauges.visible,"target":row.target.visible,"reticle":row.reticle.visible,"markers":row.markers.visible,"radio":row.radio.visible,
		"scan":row.scan.visible,"scan_rect":row.scan.frame_rect(),"notice":row.notice.visible,"notice_text":row.notice._label.text,"notice_alpha":row.notice.modulate.a,
		"notice_rect":row.notice.occupied_rect(),"radio_rect":row.radio.occupied_rect(),
		"gauges_bottom":row.gauges.top_inset(),
		"hull_text":row.gauges._hull_text.text,"armor_text":row.gauges._armor_text.text,"cargo_text":row.gauges._cargo_text.text,
		"speaker":row.radio._name.text,"transmission":row.radio._body.text,"portrait":row.radio._portrait.texture!=null}

func reject(message: String) -> bool:error=message;return false

func set_mobile_layout(mobile: bool,touch_actions:=false) -> void:
	if _layout_mode==[mobile,touch_actions]:return
	_layout_mode=[mobile,touch_actions]
	for row in _layers:
		for key in ["gauges","target","reticle","markers","notice","radio"]:
			if row[key].has_method("set_mobile_layout"):row[key].set_mobile_layout(mobile)
		row.gauges.set_touch_inset(touch_actions)
		_layout_radio(row)
