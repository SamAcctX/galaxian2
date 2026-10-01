extends RefCounted
## Original interface button sounds: one on touch-down, one when the press
## activates the button. Shared by every button styled with the original art.
const Audio=preload("res://src/content/audio_resources.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
const PRESS_EVENT:=124
const ACTIVATE_EVENT:=123
## Star map (StarMap touch handling): pick a system, pick a station, confirm a
## station, zoom into a system, zoom out. The drag whoosh (102) is driven by a
## native FMOD parameter and is left out.
const MAP_SYSTEM:=103
const MAP_STATION:=104
const MAP_CONFIRM:=105
const MAP_ZOOM_IN:=106
const MAP_ZOOM_OUT:=107
## Hangar item window (HangarWindow touch handling): buy, sell. Its info
## sound (97) has no counterpart: item details are shown inline.
const HANGAR_BUY:=100
const HANGAR_SELL:=101
static var _identity:={}
static var _clips:={}

static func configure(library: RefCounted,bindings: RefCounted) -> void:
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	if identity==_identity:return
	_identity=identity;_clips={}
	var resources:=Audio.new()
	if not resources.configure(library,bindings):return
	for id in [PRESS_EVENT,ACTIVATE_EVENT,MAP_SYSTEM,MAP_STATION,MAP_CONFIRM,MAP_ZOOM_IN,MAP_ZOOM_OUT,HANGAR_BUY,HANGAR_SELL]:
		var clip:=OneShot.prepare(resources,id)
		if not clip.is_empty():_clips[id]=clip

static func attach(button: Button) -> void:
	if button.has_meta("original_ui_sounds"):return
	button.set_meta("original_ui_sounds",true)
	button.button_down.connect(play.bind(button,PRESS_EVENT))
	button.pressed.connect(play.bind(button,ACTIVATE_EVENT))

static func play(button: Button,id: int) -> void:
	if not _clips.has(id) or not button.is_inside_tree():return
	# Parent to the tree root so the sound finishes even when the press closes its panel.
	OneShot.play(button.get_tree().root,_clips[id])

## Plays a prepared interface event under the tree root of `node`.
static func event(node: Node,id: int) -> Node:
	if not _clips.has(id) or node==null or not node.is_inside_tree():return null
	return OneShot.play(node.get_tree().root,_clips[id])

static func prepared() -> Array:return _clips.keys()
