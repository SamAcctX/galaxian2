extends Node3D
## The Valkyrie finale (157): Valkyrie burning, the array beam, the stage
## sounds and the closing white flash. Timing comes from VALKYRIE_FINALE.
const World=preload("res://src/content/valkyrie_world_definitions.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Audio=preload("res://src/content/audio_resources.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
var WHITE:=PackedByteArray([255,255,255,255])
var error:=""
var beams:=[]
var burns:={}
var bursts:=[]
var flash: ColorRect
var _clips:={}
var _last_ms:=-1

func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	var data: Dictionary=World.VALKYRIE_FINALE
	for id in data.beam:
		var node:=_model(int(id),library,visuals,bindings)
		if node==null:return false
		var surface:=Surface.new();surface.use_two_sided();var sampler:=Sampler.new()
		if not surface.prepare_model(node) or not sampler.configure(node.surfaces,true):error=surface.error+sampler.error;return false
		beams.append({"node":node,"surface":surface,"sampler":sampler,"start_ms":int(sampler.snapshot().range.start_ms)})
	# The burning stages need an import that lists payload meshes; skipped otherwise.
	for key in ["burn","burn_hard"]:
		var parts:=[]
		for id in data[key]:
			if bindings.resolve(int(id),"mesh").is_empty():parts=[];break
			var node:=_model(int(id),library,visuals,bindings)
			if node==null:parts=[];error="";break
			parts.append(node)
		burns[key]=parts
	for row in data.bursts:
		var node:=_model(int(data.burst_model),library,visuals,bindings)
		if node==null:error="";break
		var surface:=Surface.new();surface.use_two_sided();var sampler:=Sampler.new()
		if not surface.prepare_model(node) or not sampler.configure(node.surfaces,true):node.queue_free();break
		var span: Dictionary=sampler.snapshot().range
		bursts.append({"node":node,"surface":surface,"sampler":sampler,"start_ms":int(span.start_ms),"length_ms":int(span.end_ms)-int(span.start_ms),"row":row})
	var layer:=CanvasLayer.new();layer.layer=20;add_child(layer)
	flash=ColorRect.new();flash.color=Color(1,1,1,0);flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT);layer.add_child(flash)
	var resources:=Audio.new()
	if resources.configure(library,bindings):
		for row in data.sounds:
			var clip: Dictionary=resources.prepare_trigger_once(int(row[2]))
			if clip.get("stream") is AudioStream and not clip.has("unsupported"):_clips[int(row[2])]=clip
	return true

func _model(id: int,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> Node3D:
	var resource: String=bindings.resolve(id,"mesh");var models:=Models.new()
	if resource.is_empty() or not models.prepare([resource],library,visuals,bindings,"high",false,true):error="Finale model %d: %s"%[id,models.error];return null
	var node: Node3D=models.instantiate(resource);models.clear();node.visible=false;add_child(node)
	return node

func present(finale: Dictionary) -> void:
	var data: Dictionary=World.VALKYRIE_FINALE
	var now:=int(finale.now);var anchor: Transform3D=finale.anchor
	var times:={"hit":int(finale.get("hit",-1)),"charge":int(finale.get("charge",-1))}
	times.fly=times.charge+int(data.fly_ms) if times.charge>=0 else -1
	var gone: bool=times.fly>=0 and now>=times.fly+int(data.vanish_ms)
	var burning: bool=times.hit>=0 and now>=times.hit+int(data.burn_after_ms) and not gone
	var hard: bool=finale.has("burn")
	for key in burns:
		for node in burns[key]:
			node.visible=burning and (key=="burn_hard")==hard
			if node.visible:node.global_transform=anchor
	# The beam points along -z (setDirection (0,0,-1), up y).
	var fired: bool=times.charge>=0 and now>=times.charge+int(data.fire_ms) and not gone
	var pose:=Transform3D(Basis(Vector3(-1,0,0),Vector3.UP,Vector3(0,0,-1)),anchor.origin)
	for row in beams:
		row.node.visible=fired
		if not fired:continue
		var sampler: RefCounted=row.sampler.fork_for_frame()
		var animation: Dictionary=sampler.sample(int(row.start_ms)+now-times.charge-int(data.fire_ms),Transform3D.IDENTITY)
		if animation.is_empty():continue
		var surfaces: Array=row.surface.prepare_surfaces(animation,pose,WHITE,Vector4.ONE)
		if not surfaces.is_empty():row.surface.apply_surfaces(row.node,surfaces,1.0)
		row.sampler=sampler
	var camera:=get_viewport().get_camera_3d()
	for burst in bursts:
		var row: Array=burst.row;var base: int=int(times.get(row[0],-1))
		var age: int=now-base-int(row[1])
		burst.node.visible=base>=0 and age>=0 and age<=int(burst.length_ms) and camera!=null
		if not burst.node.visible:continue
		# A look-at explosion faces the camera.
		var at: Vector3=anchor.origin+Vector3(row[2][0],row[2][1],row[2][2])
		var facing:=Basis.looking_at(camera.global_position-at,Vector3.UP).scaled(Vector3.ONE*float(row[3]))
		var sampler: RefCounted=burst.sampler.fork_for_frame()
		var animation: Dictionary=sampler.sample(int(burst.start_ms)+age,Transform3D.IDENTITY)
		if animation.is_empty():burst.node.visible=false;continue
		var surfaces: Array=burst.surface.prepare_surfaces(animation,Transform3D(facing,at),WHITE,Vector4.ONE)
		if not surfaces.is_empty():burst.surface.apply_surfaces(burst.node,surfaces,1.0);burst.surface.apply_uv(burst.node,float(int(burst.start_ms)+age))
		burst.sampler=sampler
	for row in data.sounds:
		var base: int=int(times.get(row[0],-1))
		if base<0:continue
		var at: int=base+int(row[1])
		if _last_ms<at and now>=at and _clips.has(int(row[2])):OneShot.play(self,_clips[int(row[2])])
	_last_ms=now
	var white:=0.0
	if gone:white=float(now-times.fly-int(data.vanish_ms))/float(int(data.white_end_ms)-int(data.vanish_ms))
	flash.color.a=clampf(white,0.0,1.0)
