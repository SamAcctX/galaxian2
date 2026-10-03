extends Node
## Sounds for the Emergency System (1115 while it runs) and the Shield
## Injector (2258 start, 2257 loop while filling, 2259 full). Fed the frame's
## player_devices() after every committed frame; plays on state changes.
## While the Emergency System runs, its bubble model (14374) surrounds the
## ship: centred on the ship's bounds at radius/500 + 0.1 scale, growing over
## the first 5% of the run and shrinking over the last 5%.

const Emergency=preload("res://src/simulation/emergency_system.gd")
const Injector=preload("res://src/simulation/shield_injector.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")

var _sounds: RefCounted
var _clips:={}
var _playing:={}
var _emergency:=false
var _filling:=false
const BUBBLE_MODEL:=14374
var _bubble: Node3D
var _bubble_surface: RefCounted
var _bubble_sampler: RefCounted
var _bubble_range:={}
var _bubble_scale:=0.0
var _bubble_center:=Vector3.ZERO
var _white:=PackedByteArray([255,255,255,255])

## Optional art: attaches the bubble to the player's ship node. A missing
## model leaves only the sound, as before.
func attach_bubble(player: Node3D,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> void:
	if player==null or visuals==null:return
	var path: String=bindings.resolve(BUBBLE_MODEL,"mesh")
	var resources:=preload("res://src/presentation/model_resources.gd").new()
	if path.is_empty() or not resources.prepare([path],library,visuals,bindings,"high",false,true):return
	var model: Node3D=resources.instantiate(path);resources.clear()
	if model==null:return
	var surface:=preload("res://src/presentation/animated_additive_model.gd").new()
	var sampler:=preload("res://src/presentation/scenery_animation.gd").new()
	if not surface.prepare_model(model) or not sampler.configure(model.surfaces,true):model.free();return
	var bounds:=_ship_bounds(player)
	_bubble_scale=bounds.size.length()*0.5/500.0+0.1;_bubble_center=bounds.get_center()
	player.add_child(model);model.visible=false
	_bubble=model;_bubble_surface=surface;_bubble_sampler=sampler;_bubble_range=sampler.time_range()

static func _ship_bounds(root: Node3D) -> AABB:
	var merged:=AABB();var first:=true
	for node in root.find_children("*","MeshInstance3D",true,false):
		var local: Transform3D=root.global_transform.affine_inverse()*node.global_transform if root.is_inside_tree() else Transform3D.IDENTITY
		var box: AABB=local*node.get_aabb()
		if first:merged=box;first=false
		else:merged=merged.merge(box)
	return merged

func _present_bubble(emergency: Dictionary) -> void:
	if _bubble==null or not is_instance_valid(_bubble):return
	var duration:=int(emergency.get("duration_ms",0));var remaining:=int(emergency.get("remaining_ms",0))
	if not emergency.get("active",false) or duration<=0:_bubble.visible=false;return
	var envelope:=1.0
	if remaining>duration*0.95:envelope=float(duration-remaining)/(duration*0.05)
	elif remaining<duration*0.05:envelope=float(remaining)/(duration*0.05)
	var span:=maxi(1,int(_bubble_range.end_ms)-int(_bubble_range.start_ms))
	var animation: Dictionary=_bubble_sampler.sample(int(_bubble_range.start_ms)+(duration-remaining)%span,Transform3D.IDENTITY)
	var surfaces: Array=[] if animation.is_empty() else _bubble_surface.prepare_surfaces(animation,Transform3D(Basis.from_scale(Vector3.ONE*maxf(0.0001,envelope*_bubble_scale)),_bubble_center),_white,Vector4.ONE)
	_bubble.visible=not surfaces.is_empty()
	if _bubble.visible:_bubble_surface.apply_surfaces(_bubble,surfaces,1.0)

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
	_present_bubble(devices.get("emergency",{}))
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

func snapshot() -> Dictionary:return {"clips":_clips.keys(),"emergency":_emergency,"filling":_filling,"bubble_visible":_bubble!=null and is_instance_valid(_bubble) and _bubble.visible,"bubble_scale":_bubble_scale}

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
