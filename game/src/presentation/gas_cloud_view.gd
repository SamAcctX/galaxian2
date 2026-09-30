extends Node3D
## Draws gas clouds and plasma sparks from GasClouds.snapshot_for_view: the
## plasma's core mesh at every un-ionized cloud and each spark as an instance
## of its plasma's spark mesh (one multimesh per colour and surface). Ionized
## clouds are hidden; their sparks remain. Both are camera-facing ("lookat")
## when the view carries "camera" (Transform3D).
## Assumptions:
## - The level also gives each cloud geometry 14289, which resolves to the
##   misc "bra" mesh; the cloud object draws only its core, so it is taken as
##   an undrawn target body and not shown.
## - Source material mode 39 ("lookat add") is drawn with the native additive
##   family and the diffuse texture only.
## - Meshes show their first animation pose; a fading spark shrinks by its
##   alpha, since the imported materials read no per-instance colour.
const AEM=preload("res://src/content/aem.gd")
const Model=preload("res://src/presentation/imported_model.gd")
const Materials=preload("res://src/presentation/material_library.gd")
const Audio=preload("res://src/content/audio_resources.gd")
const OneShot=preload("res://src/presentation/one_shot_audio.gd")
## Plasma extractor "suck" played for each caught spark.
const CATCH_EVENT:=2256
const CORE_MESHES:={201:18997,202:18998,203:18999,204:19000}
const SPARK_MESHES:={201:19001,202:19002,203:19003,204:19004}
const LOOKAT_ADD:=39
const ADDITIVE:=2
const POOL_STEP:=8
var error:=""
var _prototypes:={}
var _clouds: Array[Node3D]=[]
var _sparks:={}
var _catch_clip:={}
var _caught:=-1

func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	var holder:=Node3D.new();holder.visible=false;add_child(holder)
	for id in CORE_MESHES.values()+SPARK_MESHES.values():
		var model:=_load(id,library,visuals,bindings)
		if model==null:return false
		holder.add_child(model);_prototypes[id]=model
	for item in SPARK_MESHES:
		var layers:=[]
		for instance in _prototypes[SPARK_MESHES[item]].instances:
			var multi:=MultiMeshInstance3D.new()
			multi.multimesh=MultiMesh.new()
			multi.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			multi.multimesh.mesh=instance.mesh
			multi.material_override=instance.material_override
			multi.set_meta("pose",instance.transform)
			add_child(multi);layers.append(multi)
		_sparks[item]=layers
	var resources:=Audio.new()
	if resources.configure(library,bindings):_catch_clip=OneShot.prepare(resources,CATCH_EVENT)
	return true

func _load(id: int,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> Node3D:
	var path: String=bindings.resolve(id,"mesh")
	if path.is_empty():reject("Gas cloud mesh %d is not available: %s"%[id,bindings.error]);return null
	var descriptor: Dictionary=bindings.material_for_mesh(path,"high")
	var mode:=int(descriptor.get("render_type",-1))
	if mode==LOOKAT_ADD:mode=ADDITIVE
	if not Materials.SHADERS.has(mode):reject("Gas cloud mesh %d: material mode %d is not supported"%[id,mode]);return null
	var image: Image=visuals.load_image(descriptor.texture_paths[0])
	if image==null:reject("Gas cloud mesh %d texture: %s"%[id,visuals.error]);return null
	var reader:=AEM.new()
	var decoded:=reader.decode(library.read_resource(path,AEM.MAX_BYTES))
	if decoded.is_empty():reject("Gas cloud mesh %d: %s"%[id,reader.error]);return null
	var model:=Model.new()
	model.build(decoded,image,null,mode,{},true)
	return model

func present(view: Dictionary) -> void:
	if _prototypes.is_empty():error="Gas cloud view was not built";return
	var caught:=int(view.get("caught",0))
	if _caught>=0 and caught>_caught and not _catch_clip.is_empty() and is_inside_tree():OneShot.play(self,_catch_clip)
	_caught=caught
	var facing:=Basis.IDENTITY
	if view.get("camera") is Transform3D:facing=view.camera.basis.orthonormalized()
	var shown:=0
	for cloud in view.get("clouds",[]):
		if cloud.ionized:continue
		var mesh_id: int=CORE_MESHES.get(int(cloud.item_id),-1)
		if not _prototypes.has(mesh_id):error="No gas cloud mesh for plasma %d"%int(cloud.item_id);return
		if shown<_clouds.size() and int(_clouds[shown].get_meta("mesh_id"))!=mesh_id:
			_clouds[shown].free();_clouds.remove_at(shown)
		if shown>=_clouds.size():
			var made:=Model.new();made.copy_from(_prototypes[mesh_id]);made.set_meta("mesh_id",mesh_id)
			add_child(made);_clouds.insert(shown,made)
		_clouds[shown].transform=Transform3D(facing,cloud.position);_clouds[shown].visible=true
		shown+=1
	for index in range(shown,_clouds.size()):_clouds[index].visible=false
	var rows:={}
	for spark in view.get("sparks",[]):
		if not rows.has(spark.item_id):rows[spark.item_id]=[]
		rows[spark.item_id].append(spark)
	for item in _sparks:
		var sparks: Array=rows.get(item,[])
		for multi in _sparks[item]:
			var mesh: MultiMesh=multi.multimesh
			@warning_ignore("integer_division")
			if mesh.instance_count<sparks.size():mesh.instance_count=(sparks.size()/POOL_STEP+1)*POOL_STEP
			mesh.visible_instance_count=sparks.size()
			var pose: Transform3D=multi.get_meta("pose")
			for index in sparks.size():
				var scale:=maxf(float(sparks[index].alpha),0.001)
				mesh.set_instance_transform(index,Transform3D(facing.scaled(Vector3.ONE*scale),sparks[index].position)*pose)

func clear() -> void:
	for child in get_children():child.free()
	_prototypes={};_clouds.clear();_sparks={};error=""

func reject(message: String) -> bool:
	clear();error=message;return false
