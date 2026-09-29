extends RefCounted
## Original interface button sounds: one on touch-down, one when the press
## activates the button. Shared by every button styled with the original art.
const Audio=preload("res://src/content/audio_resources.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const Sequence=preload("res://src/simulation/audio_sequence.gd")
const PRESS_EVENT:=124
const ACTIVATE_EVENT:=123
static var _identity:={}
static var _clips:={}
static var _random:=RandomNumberGenerator.new()
static var _last:={}

static func configure(library: RefCounted,bindings: RefCounted) -> void:
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	if identity==_identity:return
	_identity=identity;_clips={}
	var resources:=Audio.new()
	if not resources.configure(library,bindings):return
	for id in [PRESS_EVENT,ACTIVATE_EVENT]:
		var clip: Dictionary=resources.prepare(id)
		if not clip.is_empty() and not clip.has("unsupported") and (clip.get("stream") is AudioStream or clip.get("kind")=="playlist"):_clips[id]=clip

static func attach(button: Button) -> void:
	if button.has_meta("original_ui_sounds"):return
	button.set_meta("original_ui_sounds",true)
	button.button_down.connect(play.bind(button,PRESS_EVENT))
	button.pressed.connect(play.bind(button,ACTIVATE_EVENT))

static func play(button: Button,id: int) -> void:
	if not _clips.has(id) or not button.is_inside_tree():return
	var clip: Dictionary=_clips[id]
	var stream: AudioStream=clip.get("stream");var gain: float=float(clip.gain);var pitch:=1.0
	if clip.get("kind")=="playlist":
		# Variations follow the authored playlist, avoiding an immediate repeat where it says so.
		var choice: Dictionary=Sequence.sample(clip.definition,_random,_last.get(id,-1) if clip.definition.playlist_flags!=8 else -1)
		_last[id]=choice.playlist_index
		stream=choice.sample.stream;gain*=float(choice.gain);pitch=float(choice.pitch)
	var node: Node=Streams.player(stream,false)
	node.volume_db=linear_to_db(maxf(0.0001,gain));node.pitch_scale=pitch
	# Parent to the tree root so the sound finishes even when the press closes its panel.
	button.get_tree().root.add_child(node)
	node.finished.connect(node.queue_free)
	node.play()

static func prepared() -> Array:return _clips.keys()
