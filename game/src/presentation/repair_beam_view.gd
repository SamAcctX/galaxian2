extends Node3D
## Repair/transfusion beams (repair_beams.gd): the original beam model per
## active slot, stretched from the player's ship to its target, and one loop
## sound per fitted beam while any of its slots is active.
const Models=preload("res://src/presentation/model_resources.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
const AudioResources=preload("res://src/content/audio_resources.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const BeamShape=preload("res://src/simulation/beam_primary.gd")
## The original scales the beam model to 0.5 across and the target distance along.
const WIDTH:=0.5
var _white:=PackedByteArray([255,255,255,255])

var error:=""
var _rows:=[]
var _surface: RefCounted

## `state`: the player's beam snapshot. Returns false when the art is missing.
func build(state: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	_surface=Surface.new()
	var sounds:=AudioResources.new()
	var audio: bool=sounds.configure(library,bindings)
	for beam in state.get("beams",[]):
		var path: String=bindings.resolve(int(beam.model_id),"mesh")
		var resources:=Models.new()
		if path.is_empty() or not resources.prepare([path],library,visuals,bindings,"high",false,true):return reject("Beam model unavailable: "+resources.error)
		var models:=[];var sampler:=Sampler.new()
		for slot in int(beam.slot_count):
			var model: Node3D=resources.instantiate(path)
			if model==null:return reject(resources.error)
			add_child(model);model.visible=false
			if not _surface.prepare_model(model):return reject(_surface.error)
			models.append(model)
		resources.clear()
		if models.is_empty() or not sampler.configure(models[0].surfaces,true):return reject("Beam model has no supported animation")
		var row:={"models":models,"sampler":sampler,"range":sampler.snapshot().range,"sound":null}
		if audio and int(beam.sound_id)>=0:row.sound=_loop(sounds,int(beam.sound_id))
		_rows.append(row)
	return true

## Plays the beam's loop event once. The transfusion loops allow several
## playbacks of the event; one beam only ever starts one, so that limit is moot.
func _loop(sounds: RefCounted,id: int) -> Node:
	var clip: Dictionary=sounds.prepare_plain_loop(id)
	if clip.has("unsupported"):
		var event: Dictionary=sounds._definitions.events[id].duplicate(true)
		event.properties.max_playbacks=1;sounds.unsupported.erase(id)
		clip=sounds._prepare_event(id,event)
	if not clip.get("stream") is AudioStream:return null
	var node: Node=Streams.player(clip.stream,false)
	node.volume_db=linear_to_db(maxf(0.0001,float(clip.get("gain",1.0))))
	add_child(node)
	return node

func present(state: Dictionary) -> void:
	var beams: Array=state.get("beams",[])
	var elapsed: int=int(state.get("elapsed_ms",0))
	for index in mini(beams.size(),_rows.size()):
		var row: Dictionary=_rows[index];var lines: Array=beams[index].get("lines",[])
		var span: int=maxi(1,int(row.range.end_ms)-int(row.range.start_ms))
		var animation: Dictionary=row.sampler.sample(int(row.range.start_ms)+elapsed%span,Transform3D.IDENTITY)
		for slot in row.models.size():
			var model: Node3D=row.models[slot]
			model.visible=slot<lines.size() and not animation.is_empty()
			if not model.visible:continue
			var from: Vector3=lines[slot].from;var to: Vector3=lines[slot].to
			var length:=from.distance_to(to)
			if length<=0.0:model.visible=false;continue
			var basis:=BeamShape.basis((to-from)/length)
			var root:=Transform3D(Basis(basis.x*WIDTH,basis.y*WIDTH,basis.z*length),from)
			var surfaces: Array=_surface.prepare_surfaces(animation,root,_white,Vector4.ONE)
			if surfaces.is_empty():model.visible=false;continue
			_surface.apply_surfaces(model,surfaces,1.0)
		var sound: Node=row.sound
		if sound!=null:
			if lines.is_empty():
				if sound.playing:sound.stop()
			elif not sound.playing:sound.play()

func silence() -> void:
	for row in _rows:
		if row.sound!=null and row.sound.playing:row.sound.stop()

func reject(message: String) -> bool:error=message;return false
