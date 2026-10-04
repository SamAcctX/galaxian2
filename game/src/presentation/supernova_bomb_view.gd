extends Node3D
## A supernova scene: the Naneroh implosion bomb (105) or the Naneroh blast
## (89): the flying object and its beam trail, the launch and implosion
## sounds, and the white flash (and closing black fade). Timing comes from
## the scene's data (valkyrie_world_definitions supernova_scene).
const World=preload("res://src/content/valkyrie_world_definitions.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Audio=preload("res://src/content/audio_resources.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
var WHITE:=PackedByteArray([255,255,255,255])
var error:=""
var bomb: Node3D
var trail:={}
var flash: ColorRect
var _data:={}
var _clips:={}
var _last_ms:=-1

func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted,scene:="") -> bool:
	_data=World.supernova_scene(scene)
	bomb=_model(int(_data.model_id),library,visuals,bindings)
	if bomb==null:return false
	if _data.has("trail_model_id"):
		var node:=_model(int(_data.trail_model_id),library,visuals,bindings)
		if node==null:return false
		var surface:=Surface.new();surface.use_two_sided();var sampler:=Sampler.new()
		if not surface.prepare_model(node) or not sampler.configure(node.surfaces,true):error=surface.error+sampler.error;return false
		trail={"node":node,"surface":surface,"sampler":sampler,"start_ms":int(sampler.snapshot().range.start_ms)}
	var layer:=CanvasLayer.new();layer.layer=20;add_child(layer)
	flash=ColorRect.new();flash.color=Color(1,1,1,0);flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT);layer.add_child(flash)
	var resources:=Audio.new()
	if resources.configure(library,bindings):
		# The launch sound is a 3D event the original places at the camera: heard as 2D.
		for key in ["launch_sound","implode_sound"]:
			if int(_data[key])<0:continue
			var clip: Dictionary=resources.prepare_trigger_once(int(_data[key]))
			_clips[key]=clip if clip.get("stream") is AudioStream and not clip.has("unsupported") else {}
	return true

func _model(id: int,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> Node3D:
	var resource: String=bindings.resolve(id,"mesh");var models:=Models.new()
	if resource.is_empty() or not models.prepare([resource],library,visuals,bindings,"high",false,true):error="Supernova model %d: %s"%[id,models.error];return null
	var node: Node3D=models.instantiate(resource);models.clear();node.visible=false;add_child(node)
	return node

## t: ms since the launch. Returns the sun size factor for that moment.
func present(t: int,pose: Variant) -> float:
	var data: Dictionary=_data
	bomb.visible=pose is Transform3D
	if bomb.visible:bomb.global_transform=pose
	if not trail.is_empty():
		# The trail sits on the object facing back the way it came, at half speed.
		trail.node.visible=bomb.visible
		if bomb.visible:
			var sampler: RefCounted=trail.sampler.fork_for_frame()
			var animation: Dictionary=sampler.sample(int(trail.start_ms)+int(t*0.5),Transform3D.IDENTITY)
			var back: Transform3D=pose
			back.basis=back.basis.rotated(back.basis.y.normalized(),PI)
			var surfaces: Array=trail.surface.prepare_surfaces(animation,back,WHITE,Vector4.ONE) if not animation.is_empty() else []
			if not surfaces.is_empty():trail.surface.apply_surfaces(trail.node,surfaces,1.0)
			trail.sampler=sampler
	for key in ["launch_sound","implode_sound"]:
		var at:=0 if key=="launch_sound" else int(data.implode_ms)
		if _last_ms<at and t>=at and not _clips.get(key,{}).is_empty():OneShot.play(self,_clips[key])
	_last_ms=t
	var white:=0.0
	if t>=int(data.flash_ms) and t<int(data.return_ms):white=float(t-int(data.flash_ms))/float(data.flash_in_ms)
	elif t>=int(data.return_ms):white=1.0-float(t-int(data.return_ms))/float(data.flash_out_ms)
	flash.color=Color(1,1,1,clampf(white,0.0,1.0))
	if data.has("black_ms") and t>=int(data.black_ms):flash.color=Color(0,0,0,clampf(float(t-int(data.black_ms))/float(data.black_in_ms),0.0,1.0))
	var sizes: Array=World.SUPERNOVA.sun_scales
	if t>=int(data.return_ms):
		if data.has("after_scale"):return float(data.after_scale)+float(data.after_growth_per_ms)*float(t-int(data.return_ms))
		return float(sizes[-1][1])
	if t<int(data.implode_ms):return float(sizes[0][1])
	return float(sizes[0][1])*pow(float(data.shrink_per_frame),float(t-int(data.implode_ms))*0.06)
