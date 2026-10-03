extends Node
## Sounds and pitch for the Time Extender. The original lowers the pitch of
## all sound while the world is slowed; the amount is an assumption.

const Extender=preload("res://src/simulation/time_extender.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
const SLOW_PITCH:=0.75

var _clips:={}
var _slow:=false

func configure(library: RefCounted,bindings: RefCounted) -> void:
	_clips={}
	var sounds:=preload("res://src/content/audio_resources.gd").new()
	if not sounds.configure(library,bindings):return
	for id in [Extender.START_SOUND,Extender.STOP_SOUND,Extender.DENIED_SOUND]:
		var clip:=OneShot.prepare(sounds,id)
		if not clip.is_empty():_clips[id]=clip

func present(extender: RefCounted,sound: int) -> void:
	if _clips.has(sound):OneShot.play(self,_clips[sound])
	var slow: bool=extender!=null and extender.phase=="active"
	if slow!=_slow:_slow=slow;AudioServer.playback_speed_scale=SLOW_PITCH if slow else 1.0

func _exit_tree() -> void:
	if _slow:_slow=false;AudioServer.playback_speed_scale=1.0
