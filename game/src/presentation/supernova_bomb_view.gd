extends Node3D
## The Naneroh implosion bomb (105): the flying bomb, its launch and implosion
## sounds, and the white flash. Timing comes from SUPERNOVA_BOMB.
const World=preload("res://src/content/valkyrie_world_definitions.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Audio=preload("res://src/content/audio_resources.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
var error:=""
var bomb: Node3D
var flash: ColorRect
var _clips:={}
var _last_ms:=-1

func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	var data: Dictionary=World.SUPERNOVA_BOMB
	var resource: String=bindings.resolve(int(data.model_id),"mesh")
	var models:=Models.new()
	if resource.is_empty() or not models.prepare([resource],library,visuals,bindings,"high",false,true):error="Supernova bomb model: "+models.error;return false
	bomb=models.instantiate(resource);models.clear();bomb.visible=false;add_child(bomb)
	var layer:=CanvasLayer.new();layer.layer=20;add_child(layer)
	flash=ColorRect.new();flash.color=Color(1,1,1,0);flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT);layer.add_child(flash)
	var resources:=Audio.new()
	if resources.configure(library,bindings):
		# The launch sound is a 3D event the original places at the camera: heard as 2D.
		for key in ["launch_sound","implode_sound"]:
			var clip: Dictionary=resources.prepare_trigger_once(int(data[key]))
			_clips[key]=clip if clip.get("stream") is AudioStream and not clip.has("unsupported") else {}
	return true

## t: ms since the launch. Returns the sun size factor for that moment.
func present(t: int,pose: Variant) -> float:
	var data: Dictionary=World.SUPERNOVA_BOMB
	bomb.visible=pose is Transform3D
	if bomb.visible:bomb.global_transform=pose
	for key in ["launch_sound","implode_sound"]:
		var at:=0 if key=="launch_sound" else int(data.implode_ms)
		if _last_ms<at and t>=at and not _clips.get(key,{}).is_empty():OneShot.play(self,_clips[key])
	_last_ms=t
	var white:=0.0
	if t>=int(data.flash_ms) and t<int(data.return_ms):white=float(t-int(data.flash_ms))/float(data.flash_in_ms)
	elif t>=int(data.return_ms):white=1.0-float(t-int(data.return_ms))/float(data.flash_out_ms)
	flash.color.a=clampf(white,0.0,1.0)
	var sizes: Array=World.SUPERNOVA.sun_scales
	if t>=int(data.return_ms):return float(sizes[-1][1])
	if t<int(data.implode_ms):return float(sizes[0][1])
	return float(sizes[0][1])*pow(float(data.shrink_per_frame),float(t-int(data.implode_ms))*0.06)
