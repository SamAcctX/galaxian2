extends RefCounted
## Fire-and-forget original 2D sound events (static clips or playlists).
const Audio=preload("res://src/content/audio_resources.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const Sequence=preload("res://src/simulation/audio_sequence.gd")
static var _random:=RandomNumberGenerator.new()
static var _last:={}

## Returns a playable clip, or {} when the event is missing or needs other behaviour.
static func prepare(resources: Audio,id: int) -> Dictionary:
	var clip: Dictionary=resources.prepare_trigger_once(id)
	if clip.is_empty() or clip.has("unsupported") or clip.get("spatial",false):return {}
	return clip if clip.get("stream") is AudioStream or clip.get("kind")=="playlist" else {}

## Plays under `parent` and frees itself when done. Returns the player.
static func play(parent: Node,clip: Dictionary) -> Node:
	var stream: AudioStream=clip.get("stream");var gain: float=float(clip.gain);var pitch:=1.0
	if clip.get("kind")=="playlist":
		# Variations follow the authored playlist, avoiding an immediate repeat where it says so.
		var id: int=int(clip.id)
		var choice: Dictionary=Sequence.sample(clip.definition,_random,_last.get(id,-1) if clip.definition.playlist_flags!=8 else -1)
		_last[id]=choice.playlist_index
		stream=choice.sample.stream;gain*=float(choice.gain);pitch=float(choice.pitch)
	var node: Node=Streams.player(stream,false)
	node.volume_db=linear_to_db(maxf(0.0001,gain));node.pitch_scale=pitch
	parent.add_child(node);node.finished.connect(node.queue_free);node.play()
	return node
