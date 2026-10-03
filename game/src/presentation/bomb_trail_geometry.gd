extends Node3D
## Sprite trail emitted by a flying bomb (fire or firework sparks). It reuses the
## shared sprite emitter and appearance rules and advances only by the bomb
## owner's simulation clock (its elapsed milliseconds), never by wall time.
## Preparation forks the emitter; commit adopts the fork and draws it.
const Emitter=preload("res://src/simulation/damage_particle_emitter.gd")
const Appearance=preload("res://src/presentation/damage_particle_appearance.gd")
const Materials=preload("res://src/presentation/material_library.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
## A long stall (load, debugger) only needs to age the trail out, not replay it.
const MAX_CATCH_UP_MS:=5000
var error:=""
var sprites:=0
var _emitter: RefCounted
var _instance: MeshInstance3D
var _elapsed_ms:=0
var _shot_id:=-1
var _pose:=Transform3D.IDENTITY

func configure(preset: Dictionary,bindings: RefCounted,visuals: RefCounted,elapsed_ms: int) -> bool:
	var descriptor: Dictionary=bindings.resolve_material(int(preset.material_id)) if bindings!=null else {}
	if descriptor.is_empty() or not Materials.supports(descriptor) or descriptor.texture_paths[0].is_empty():error="Bomb trail material is unavailable";return false
	var image: Image=visuals.load_image(descriptor.texture_paths[0]) if visuals!=null else null
	if image==null:error="Bomb trail texture is unavailable";return false
	var emitter:=Emitter.new()
	if not emitter.configure_declared(bindings,preset,int(preset.preset_id)):error=emitter.error;return false
	_emitter=emitter;_elapsed_ms=elapsed_ms
	_instance=MeshInstance3D.new();_instance.name="trail";_instance.top_level=true
	_instance.material_override=Materials.create(int(descriptor.render_type),ImageTexture.create_from_image(image),null,true)
	_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	_instance.set_meta("source_material_id",int(preset.material_id))
	add_child(_instance)
	return true

## `pose` is the flying bomb's pose, or null once it has burst or gone.
func prepare(bomb: Dictionary,pose: Variant) -> Dictionary:
	if _emitter==null:return {}
	var shot: Dictionary=bomb.get("shot",{})
	var elapsed: int=int(bomb.get("elapsed_ms",_elapsed_ms))
	var next: RefCounted=_emitter.fork_for_frame()
	var shot_id: int=int(shot.get("id",_shot_id)) if pose is Transform3D else _shot_id
	var delta: int=elapsed-_elapsed_ms
	# A new launch restarts the owner's clock and starts a fresh trail.
	if shot_id!=_shot_id or delta<0:
		if shot_id!=_shot_id and not next.reset():error=next.error;return {}
		delta=maxi(0,elapsed) if delta<0 else delta
	delta=mini(delta,MAX_CATCH_UP_MS)
	var root: Transform3D=pose if pose is Transform3D else _pose
	if not next.set_emitting(pose is Transform3D):error=next.error;return {}
	while delta>0:
		var step:=mini(delta,1000)
		if next.advance_in_frame(root,step,step).has("error"):error=next.error;return {}
		delta-=step
	return {"emitter":next,"elapsed_ms":elapsed,"shot_id":shot_id,"pose":root}

func commit(frame: Dictionary) -> void:
	if frame.is_empty() or _emitter==null:return
	_emitter=frame.emitter;_elapsed_ms=frame.elapsed_ms;_shot_id=frame.shot_id;_pose=frame.pose
	var basis:=Basis.IDENTITY
	var camera: Camera3D=get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera!=null:basis=camera.global_basis.orthonormalized()
	var state: Dictionary=_emitter.snapshot(true)
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedFloat32Array();var indices:=PackedInt32Array()
	for slot in state.slots:
		if int(slot.appearance.age_ms)<0:continue
		var look: Dictionary=Appearance.sample_prepared(state.preset,slot.appearance)
		var half: float=float(int(look.get("size",0))>>1)
		if not look.get("active",false) or half<=0:continue
		var base:=vertices.size()
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			vertices.append(slot.position+(basis.x*corner.x+basis.y*corner.y)*half)
		var rect: Vector4=look.uv_rect;var c: Color=look.color
		# Same corner-to-cell mapping as the shared damage sprites.
		uvs.append_array(PackedVector2Array([Vector2(rect.x,rect.y),Vector2(rect.z,rect.y),Vector2(rect.z,rect.w),Vector2(rect.x,rect.w)]))
		for index in 4:colors.append_array(PackedFloat32Array([c.r,c.g,c.b,c.a]))
		indices.append_array(PackedInt32Array([base,base+2,base+1,base,base+3,base+2]))
	sprites=vertices.size()>>2
	if sprites==0:_instance.mesh=null;_instance.visible=false;return
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_CUSTOM0]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	_instance.mesh=mesh;_instance.visible=true
