extends Control
## The hacking puzzle over the docked ship view: the player's 3x2 board above
## the centre panel, the target pattern below it, and the two turn buttons.
## Original art from the third interface atlas; layout sizes are the remake's.
const OriginalUI=preload("res://src/presentation/original_ui.gd")
const Audio=preload("res://src/content/audio_resources.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
## Original sounds: a turn starts; the board is solved.
const TURN_EVENT:=2274
const SOLVED_EVENT:=2273
const ATLAS:={"10089":"resources/data/textures/gof2_interface3_ipad_large.aei"}
const TILES:=[8010,8011,8012,8013,8014,8015]
const TILES_LIT:=[8016,8017,8018,8019,8020,8021]
const IMAGES:={"marker":8004,"target_marker":8005,"marker_turning":8006,"panel":8007,"bottom":8008,"top":8009,"button":8023,"button_held":8024}
signal turn_requested(button: String)

var error:=""
var _art:={}
var _state:={}
var _board:=[]
var _target:=[]
var _markers:=[]
var _target_markers:=[]
var _panel: TextureRect
var _buttons:={}
var _held:=""
var _clips:={}
var _sounded:={}

func _init() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_IGNORE
	_panel=_texture()
	for index in 6:_board.append(_texture());_target.append(_texture())
	for index in 2:_markers.append(_texture());_target_markers.append(_texture())
	for button in ["left","right"]:
		var node:=_texture();node.mouse_filter=Control.MOUSE_FILTER_STOP
		node.gui_input.connect(_on_button_input.bind(button))
		_buttons[button]=node
	resized.connect(_relayout)

func _texture() -> TextureRect:
	var node:=TextureRect.new();node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(node);return node

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> bool:
	error=""
	var art:=OriginalUI.new()
	if not art.configure(library,bindings,visuals):return _reject(art.error)
	_clips={}
	var resources:=Audio.new()
	if resources.configure(library,bindings):
		for id in [TURN_EVENT,SOLVED_EVENT]:
			var clip:=OneShot.prepare(resources,id)
			if not clip.is_empty():_clips[id]=clip
	var atlases: Dictionary=bindings.mido_travel.map.ui.atlas_resources.duplicate();atlases.merge(ATLAS)
	var ids:=TILES+TILES_LIT+IMAGES.values()
	var images:=art.load_regions(library,bindings,visuals,ids,atlases)
	# Packs without the third atlas have no hacking art (no Supernova).
	if images.is_empty():_art={};return true
	_art=images
	_panel.texture=images.get(IMAGES.panel)
	for button in _buttons:_buttons[button].texture=images.get(IMAGES.button)
	return true

func available() -> bool:return not _art.is_empty()

## `state` is the hacking game's snapshot; an empty one hides the panel.
func present(state: Dictionary,highlighted:=false) -> void:
	_state=state
	visible=not state.is_empty()
	if not visible:_sounded={};return
	var solved:=int(state.get("solved_ms",-1))>=0
	# One sound as each turn starts and once when the board is solved.
	var turn_key:=[int(state.get("moves",0)),String(state.get("turning",""))]
	if not String(state.get("turning","")).is_empty() and _sounded.get("turn")!=turn_key:_sounded.turn=turn_key;_play(TURN_EVENT)
	if solved and not _sounded.get("solved",false):_sounded.solved=true;_play(SOLVED_EVENT)
	elif not solved:_sounded.solved=false
	for index in 6:
		var symbol:=int(state.board[index])
		_board[index].texture=_art.get((TILES_LIT if highlighted else TILES)[symbol])
		_target[index].texture=_art.get(TILES[int(state.target[index])])
		_target[index].visible=not solved
	for index in 2:
		var turning: bool=String(state.get("turning",""))==["left","right"][index]
		_markers[index].texture=_art.get(IMAGES.marker_turning if turning else IMAGES.marker)
		_target_markers[index].texture=_art.get(IMAGES.target_marker);_target_markers[index].visible=not solved
	_panel.visible=not solved
	for button in _buttons:
		_buttons[button].visible=not solved
		_buttons[button].texture=_art.get(IMAGES.button_held if _held==button else IMAGES.button)
	_relayout()

func _relayout() -> void:
	if _state.is_empty():return
	var tile:=clampf(size.y*0.09,36.0,96.0)
	var center:=size*0.5
	var board_origin:=center+Vector2(-1.5*tile,-2.2*tile)
	var target_origin:=center+Vector2(-1.5*tile,0.4*tile)
	_panel.position=center-Vector2(2.0*tile,0.2*tile);_panel.size=Vector2(4.0*tile,0.6*tile)
	# While a turn runs, its four tiles slide one cell along the turn.
	var turning:=String(_state.get("turning",""))
	var progress:=clampf(float(_state.get("turn_ms",0))/300.0,0.0,1.0)
	var cycle: Array={"left":[0,1,4,3],"right":[1,2,5,4]}.get(turning,[])
	for index in 6:
		var cell:=_cell(board_origin,index,tile)
		var at:=cycle.find(index)
		if at>=0:cell=cell.lerp(_cell(board_origin,cycle[(at+1)%4],tile),progress)
		_board[index].position=cell;_board[index].size=Vector2(tile,tile)
		_target[index].position=_cell(target_origin,index,tile)+Vector2(tile*0.15,tile*0.15);_target[index].size=Vector2(tile*0.7,tile*0.7)
	for index in 2:
		var mark:=Vector2(tile*0.35,tile*0.35)
		_markers[index].position=board_origin+Vector2((index+1)*tile,tile)-mark*0.5;_markers[index].size=mark
		_target_markers[index].position=target_origin+Vector2((index+1)*tile,tile)-mark*0.5;_target_markers[index].size=mark
	var button_size:=Vector2(tile*1.3,tile*1.3)
	_buttons.left.position=center+Vector2(-3.4*tile,-1.6*tile)-button_size*0.5;_buttons.left.size=button_size
	_buttons.right.position=center+Vector2(3.4*tile,-1.6*tile)-button_size*0.5;_buttons.right.size=button_size

static func _cell(origin: Vector2,index: int,tile: float) -> Vector2:
	return origin+Vector2((index%3)*tile,(index/3)*tile)

## Presses act on release, as the original's buttons do.
func _on_button_input(event: InputEvent,button: String) -> void:
	var pressed:=false;var released:=false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:pressed=event.pressed;released=not event.pressed
	elif event is InputEventScreenTouch:pressed=event.pressed;released=not event.pressed
	else:return
	if pressed:_held=button
	elif released and _held==button:_held="";turn_requested.emit(button)
	accept_event()

func _play(id: int) -> void:
	if _clips.has(id) and is_inside_tree():OneShot.play(get_tree().root,_clips[id])

func _reject(message: String) -> bool:
	error=message;return false
