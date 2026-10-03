extends Node
## Sounds for the Emergency System (1115 while it runs) and the Shield
## Injector (2258 start, 2257 loop while filling, 2259 full). Fed the frame's
## player_devices() after every committed frame; plays on state changes.
## The emergency bubble model (14374) is not drawn yet.

const Emergency=preload("res://src/simulation/emergency_system.gd")
const Injector=preload("res://src/simulation/shield_injector.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")

var _sounds: RefCounted
var _clips:={}
var _playing:={}
var _emergency:=false
var _filling:=false

func configure(library: RefCounted,bindings: RefCounted) -> void:
	_clips={};_playing={}
	var sounds:=preload("res://src/content/audio_resources.gd").new()
	if not sounds.configure(library,bindings):return
	_sounds=sounds
	for id in [Emergency.SOUND,Injector.START_SOUND,Injector.END_SOUND]:
		var clip:=OneShot.prepare(sounds,id)
		if not clip.is_empty():_clips[id]=clip
	var loop: Dictionary=sounds.prepare_plain_loop(Injector.LOOP_SOUND)
	if loop.get("stream") is AudioStream:_clips[Injector.LOOP_SOUND]=loop

func present(devices: Dictionary) -> void:
	var emergency: bool=devices.get("emergency",{}).get("active",false)
	if emergency!=_emergency:
		_emergency=emergency
		if emergency:_start(Emergency.SOUND)
		else:_stop(Emergency.SOUND)
	var filling: bool=devices.get("injector",{}).get("filling",false)
	if filling!=_filling:
		_filling=filling
		if filling:_start(Injector.START_SOUND);_start(Injector.LOOP_SOUND,true)
		else:_stop(Injector.LOOP_SOUND);_start(Injector.END_SOUND)

func snapshot() -> Dictionary:return {"clips":_clips.keys(),"emergency":_emergency,"filling":_filling}

func _start(id: int,loop:=false) -> void:
	if not _clips.has(id):return
	_stop(id)
	if loop:
		var clip: Dictionary=_clips[id]
		var node: Node=Streams.player(clip.stream,false)
		node.volume_db=linear_to_db(maxf(0.0001,float(clip.get("gain",1.0))))
		add_child(node);node.play();_playing[id]=node
	else:_playing[id]=OneShot.play(self,_clips[id])

func _stop(id: int) -> void:
	var node: Variant=_playing.get(id)
	_playing.erase(id)
	if node is Node and is_instance_valid(node):
		node.stop();node.queue_free()
