extends Node
## Docked room atmosphere: the main view, hangar and lounge each loop their own
## original FEV event. Changing room fades the old loop out and the new one in
## with the events' authored fade times; leaving the station stops them.
const Audio=preload("res://src/content/audio_resources.gd")
const Layered=preload("res://src/presentation/layered_audio.gd")
const ROOMS:={"main":122,"hangar":95,"lounge":108}
var error:=""
var diagnostics:={}
var _clips:={}
var _players:={}
var _room:=""
var _paused:=false

func configure(library: RefCounted,bindings: RefCounted) -> bool:
	error="";clear()
	var resources:=Audio.new()
	if not resources.configure(library,bindings):diagnostics.atmosphere=resources.error;return false
	for room in ROOMS:
		var clip: Dictionary=resources.prepare_constant_layers(ROOMS[room])
		if clip.is_empty() or clip.has("unsupported") or clip.get("kind")!="layered":
			diagnostics[room]=clip.get("unsupported",resources.error);continue
		_clips[room]=clip
	return not _clips.is_empty()

## Selects the audible room and advances fades and layer clocks.
func advance(room: String,delta_ms: int) -> void:
	if not ROOMS.has(room):room=""
	if room!=_room:
		if _players.has(_room):_players[_room].stopping=true
		_room=room
		if _clips.has(room):
			if _players.has(room):_players[room].stopping=false
			else:_start(room)
	if _paused:return
	for key in _players.keys():
		var record: Dictionary=_players[key]
		var clip: Dictionary=record.clip
		if record.stopping:record.level-=float(delta_ms)/maxf(1.0,float(clip.fade_out_ms))
		else:record.level+=float(delta_ms)/maxf(1.0,float(clip.fade_in_ms))
		record.level=clampf(record.level,0.0,1.0)
		if record.stopping and record.level<=0.0:_remove(key);continue
		var node: Node=record.node
		node.commit_step(node.prepare_step(delta_ms))
		var gain: float=float(clip.gain)*record.level
		node.volume_db=linear_to_db(gain) if gain>0 else -80.0

func _start(room: String) -> void:
	var node:=Layered.new();node.configure(_clips[room],ROOMS[room]);add_child(node)
	node.volume_db=-80.0
	_players[room]={"clip":_clips[room],"node":node,"level":0.0,"stopping":false}
	node.play()
	if _paused:node.stream_paused=true

func _remove(room: String) -> void:
	var node: Node=_players[room].node
	node.stop();node.queue_free();_players.erase(room)

func set_paused(value: bool) -> void:
	if _paused==value:return
	_paused=value
	for record in _players.values():record.node.stream_paused=value

func snapshot() -> Dictionary:
	var levels:={}
	var voices:=0
	for room in _players:
		levels[room]=_players[room].level
		voices+=_players[room].node.snapshot().voices.values().filter(func(voice):return voice.playing).size()
	return {"room":_room,"prepared":_clips.keys(),"levels":levels,"playing_voices":voices,"paused":_paused,"diagnostics":diagnostics.duplicate()}

func clear() -> void:
	for room in _players.keys():_remove(room)
	_clips={};_room="";diagnostics={}
