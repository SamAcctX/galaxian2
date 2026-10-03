extends Node3D
## Original locally imported sprites, batched in stable slot order. Camera-space
## square construction keeps particles facing the camera without rotating their
## velocity or source local offsets. Preparation never advances the simulation.
const State=preload("res://src/simulation/opening_damage_particles.gd")
const FullHold=preload("res://src/simulation/full_hold_particles.gd")
const Engines=preload("res://src/simulation/player_engine_particles.gd")
const EngineDefinitions=preload("res://src/content/engine_particle_definitions.gd")
const Appearance=preload("res://src/presentation/damage_particle_appearance.gd")
const Materials=preload("res://src/presentation/material_library.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const ReadCache=preload("res://src/simulation/read_cache.gd")
const CORNERS:=[Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
var error:=""
var items: Array=[]
var frame:={}
var _descriptor:={}
var _owner_identity: RefCounted

func build(owner: RefCounted,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	if not (owner is State or owner is FullHold or owner is Engines) or owner.presentation_identity()==null:return reject("Damage geometry requires its configured flight owner")
	var state: Dictionary=owner.snapshot()
	if library==null or visuals==null or bindings==null or library.manifest.get("content_id")!=state.base_content_id or visuals.base_content_id!=state.base_content_id or bindings.base_content_id!=state.base_content_id or bindings.binding_id!=state.binding_id:return reject("Damage sprite resources belong to another content identity")
	var materials:={}
	for kind in ["trail","smoke","fire","burst","junk_burst","emp17","emp18","exhaust"]:
		var preset: Dictionary
		for key in state.owners:
			if not state.owners[key].has(kind):continue
			var current: Dictionary=state.owners[key][kind].preset
			if not Appearance.Definitions.sprite_preset(current):return reject("Unsupported damage sprite preset")
			if kind=="exhaust":
				if not EngineDefinitions.parameters(bindings.engine_particles) or key!="player_nozzle%d"%(int(current.preset_id)-int(bindings.engine_particles.first_preset)) or int(current.preset_id)<int(bindings.engine_particles.first_preset) or int(current.preset_id)>=int(bindings.engine_particles.first_preset)+32 or not state.owners[key].get("draw_enabled") is bool:return reject("Unsupported player nozzle owner")
			# Registered emitters may use authored variants of the same sprite
			# kind. Each item retains and checks its own complete preset below.
			preset=current
			var descriptor: Dictionary=bindings.resolve_material(int(preset.material_id))
			var render_type:=3 if kind=="exhaust" else (1 if kind=="smoke" else 2)
			if descriptor.is_empty() or not Materials.supports(descriptor) or descriptor.render_type!=render_type or descriptor.parameter_bits.map(func(value):return int(value))!=[0,3240099840,0,0] or descriptor.texture_paths[0].is_empty():return reject("Unsupported damage sprite material")
			var material_id:=int(preset.material_id)
			if not materials.has(material_id):
				var image: Image=visuals.load_image(descriptor.texture_paths[0])
				if image==null:return reject(visuals.error)
				materials[material_id]=Materials.create(int(descriptor.render_type),ImageTexture.create_from_image(image),null,true)
			var instance:=MeshInstance3D.new();instance.name=key+"_"+kind
			instance.material_override=materials[material_id];instance.visible=false
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
			instance.set_meta("source_material_id",int(preset.material_id))
			instance.set_meta("source_texture_id",int(descriptor.texture_ids[0]))
			add_child(instance)
			items.append({"key":key,"kind":kind,"node":instance,"preset":preset.duplicate(true),"spare":[ArrayMesh.new(),ArrayMesh.new()]})
	_owner_identity=owner.presentation_identity();_descriptor=state
	return true

func prepare_world(owner: RefCounted,world: Dictionary,camera_pose: Variant) -> Dictionary:
	error=""
	if not (owner is State or owner is FullHold or owner is Engines) or _owner_identity==null or owner.presentation_identity()!=_owner_identity:return failed("Damage sprites follow one configured flight")
	# The frame already carries this owner's snapshot. Debug builds rebuild it
	# and compare; release reuses the observation instead of copying it again.
	var observed: Variant=world.get("engine_particles" if owner is Engines else "damage_particles")
	if not observed is Dictionary:return failed("Damage sprite presentation requires its current world clock")
	var state: Dictionary=observed
	if ReadCache.verify and owner.snapshot()!=state:return failed("Damage sprite presentation requires its current world clock")
	for key in ["base_content_id","binding_id"]:
		if state.get(key)!=_descriptor.get(key) or world.get(key)!=_descriptor.get(key):return failed("Damage sprite frame belongs to another identity")
	var elapsed: Variant=world.get("elapsed_ms")
	if owner is FullHold:
		# First mining has no encounter clock. Its accepted particle snapshot owns
		# the early simulation clock, including accelerated and modal-opening passes.
		elapsed=world.get("damage_particles",{}).get("elapsed_ms") if int(world.get("player_destruction",{}).get("departure_cursor",-1))==2 else world.get("encounter",{}).get("elapsed_ms")
	if elapsed!=state.elapsed_ms:return failed("Damage sprite presentation requires its current world clock")
	if not Flight.rigid_pose(camera_pose):return failed("Damage sprite camera must be finite and rigid")
	var cloak: Dictionary=world.get("cloak",{}) if owner is Engines else {}
	var exhaust_opacity: float=float(cloak.get("exhaust_alpha",221.0/255.0))/(221.0/255.0)
	var cloaked: bool=owner is Engines and cloak.get("active",false)
	var checked:=ReadCache.verify
	var prepared:=[];var counts:=[]
	var view: Transform3D=camera_pose.affine_inverse()
	for item in items:
		if not is_instance_valid(item.node) or item.node.get_meta("source_material_id",-1)!=int(item.preset.material_id):return failed("Damage sprite surface identity changed")
		var emitter: Dictionary=state.owners[item.key][item.kind]
		# The preset is fixed when the surface is built; release checks only its size.
		if (checked and emitter.preset!=item.preset) or emitter.slots.size()!=int(item.preset.capacity):return failed("Damage sprite population changed")
		var draw_enabled: bool=state.owners[item.key].get("draw_enabled",false) if item.kind=="exhaust" else true
		var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var colors:=PackedFloat32Array();var indices:=PackedInt32Array()
		var fade_in_rgb: bool=emitter.get("fade_in_rgb",false)
		var drawn: bool=emitter.visible and draw_enabled
		if (not drawn or emitter.get("idle",false)) and not checked:
			prepared.append(null);counts.append(0);continue
		var slots: Array=emitter.slots
		# Buffers are sized for every slot once, filled in place and trimmed.
		var capacity:=slots.size()
		vertices.resize(capacity*4);uvs.resize(capacity*4);colors.resize(capacity*16)
		var quads:=0
		for index in capacity:
			var slot: Dictionary=slots[index]
			# Idle slots draw nothing; release skips checking and sampling them.
			if not checked and int(slot.appearance.age_ms)==-1:continue
			if slot.appearance.slot!=index or not slot.position is Vector3 or not slot.position.is_finite():return failed("Invalid damage sprite slot")
			if not drawn:continue
			var appearance:=Appearance.sample_prepared(item.preset,slot.appearance,fade_in_rgb)
			if appearance.has("error"):return failed(appearance.error)
			if not appearance.active:continue
			var c: Color=appearance.color
			if cloaked:c.a*=exhaust_opacity
			var center: Vector3=view*slot.position
			var half:=float(int(appearance["size"])>>1)
			# Corners round each sum to binary32 like the source float casts.
			var left:=Vector3(center.x-half,center.y-half,center.z);var right:=Vector3(center.x+half,center.y+half,center.z)
			if not left.is_finite() or not right.is_finite():return failed("Damage sprite exceeded finite view bounds")
			var v:=quads*4
			vertices[v]=left;vertices[v+1]=Vector3(right.x,left.y,center.z);vertices[v+2]=right;vertices[v+3]=Vector3(left.x,right.y,center.z)
			var rect: Vector4=appearance.uv_rect
			uvs[v]=Vector2(rect.x,rect.y);uvs[v+1]=Vector2(rect.z,rect.y);uvs[v+2]=Vector2(rect.z,rect.w);uvs[v+3]=Vector2(rect.x,rect.w)
			var k:=quads*16
			for corner in 4:
				colors[k]=c.r;colors[k+1]=c.g;colors[k+2]=c.b;colors[k+3]=c.a;k+=4
			quads+=1
		vertices.resize(quads*4);uvs.resize(quads*4);colors.resize(quads*16)
		indices=_quad_indices(quads)
		var mesh: ArrayMesh
		if not vertices.is_empty():
			var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs
			arrays[Mesh.ARRAY_CUSTOM0]=colors;arrays[Mesh.ARRAY_INDEX]=indices
			# Two meshes per item alternate, so the committed one is never rebuilt
			# while it is still shown.
			var spare: Array=item.spare
			mesh=spare[0] if spare[0]!=item.node.mesh else spare[1]
			mesh.clear_surfaces()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		prepared.append(mesh);counts.append(vertices.size()>>2)
	return {"meshes":prepared,"counts":counts,"pose":camera_pose,"elapsed_ms":state.elapsed_ms}

static var _indices:=PackedInt32Array()

## Two triangles per quad; one shared template is sliced per mesh.
static func _quad_indices(quads: int) -> PackedInt32Array:
	if _indices.size()<quads*6:
		@warning_ignore("integer_division")
		for offset in range(_indices.size()/6*4,quads*4,4):
			_indices.append_array(PackedInt32Array([offset,offset+2,offset+1,offset,offset+3,offset+2]))
	return _indices.slice(0,quads*6)

static func sprite(center: Vector3,appearance: Dictionary) -> Dictionary:
	if not center.is_finite():return {}
	# The source renderer uses an arithmetic shift of signed 16-bit size, so odd
	# sizes lose one unit and negative odd sizes round toward negative infinity.
	var half:=int(appearance["size"])>>1
	var vertices:=PackedVector3Array()
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		# Vector components round each sum to binary32, like Appearance.single().
		var point:=Vector3(center.x+corner.x*half,center.y+corner.y*half,center.z)
		if not point.is_finite():return {}
		vertices.append(point)
	var rect: Vector4=appearance.uv_rect
	# The programmable sprite setter preserves V. Unlike imported mesh UVs,
	# these procedural atlas coordinates do not pass through the mesh row flip.
	var uvs:=PackedVector2Array([Vector2(rect.x,rect.y),Vector2(rect.z,rect.y),Vector2(rect.z,rect.w),Vector2(rect.x,rect.w)])
	var c: Color=appearance.color;var colors:=PackedFloat32Array()
	for index in 4:colors.append_array(PackedFloat32Array([c.r,c.g,c.b,c.a]))
	return {"vertices":vertices,"uvs":uvs,"colors":colors}

func commit_world(prepared: Dictionary) -> void:
	global_transform=prepared.pose
	for index in items.size():
		items[index].node.mesh=prepared.meshes[index]
		items[index].node.visible=prepared.meshes[index]!=null
	frame=prepared

func clear() -> void:
	for child in get_children():child.free()
	items=[];frame={};_descriptor={};_owner_identity=null;error=""

func reject(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
