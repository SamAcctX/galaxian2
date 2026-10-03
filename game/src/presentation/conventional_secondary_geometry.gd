extends Node3D
## Retained rocket bodies, animated original attachments and crossed exhaust.
const Definitions=preload("res://src/content/conventional_secondary_definitions.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const Pose=preload("res://src/presentation/projectile_pose.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")
const Trail=preload("res://src/presentation/projectile_trail_geometry.gd")
const FireTrail=preload("res://src/presentation/bomb_trail_geometry.gd")
const Bombs=preload("res://src/content/emp_bombs_definitions.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
var error:=""
var bodies: Array[Node3D]=[]
var attachments: Array[Node3D]=[]
## Ribbon exhaust (null for launchers that trail fire sprites instead).
var trail: Node3D
## One fire-sprite trail per projectile slot (Ion Lambda), advanced by the
## launcher's own simulation clock.
var fire_trails: Array[Node3D]=[]
var _sampler: RefCounted
var _surface: RefCounted
var _descriptor:={}
var _weapon:={}

func build(gun: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	var weapon: Dictionary=gun.get("projectiles",{}).get("weapon",{})
	if not Definitions.resolved(weapon) or not gun.get("visuals") is Dictionary:return reject("Prepare conventional projectile clocks before their geometry")
	var descriptor: Dictionary=gun.visuals
	var expected:=Definitions.model(bindings,weapon)
	if expected.is_empty() or descriptor.get("resource")!=expected.resource or descriptor.get("attachment",{}).get("resource")!=expected.attached_resource:return reject("Conventional projectile art changed after preparation")
	var resources:=Models.new()
	if not resources.prepare([expected.resource,expected.attached_resource],library,visuals,bindings,"high",false,true):return reject(resources.error)
	_surface=Surface.new()
	for slot in int(weapon.projectile_capacity):
		var body: Node3D=resources.instantiate(expected.resource)
		var attached: Node3D=resources.instantiate(expected.attached_resource)
		if body==null or attached==null:
			if body!=null:body.free()
			if attached!=null:attached.free()
			resources.clear();return reject("Conventional model could not be instantiated")
		add_child(body);add_child(attached);body.hide();attached.hide()
		bodies.append(body);attachments.append(attached)
		if not _surface.prepare_model(attached):resources.clear();return reject(_surface.error)
	resources.clear()
	_sampler=Sampler.new()
	if not _sampler.configure(attachments[0].surfaces,descriptor.attachment.end_ms==0):return reject(_sampler.error)
	if _sampler.snapshot().range!={"start_ms":descriptor.attachment.start_ms,"end_ms":descriptor.attachment.end_ms}:return reject("Conventional attachment playback range changed")
	if int(weapon.secondary_projectile.trail_id)>=0:
		trail=Trail.new();add_child(trail)
		if not trail.build(int(weapon.secondary_projectile.trail_id),library,visuals,bindings):return reject(trail.error)
	var preset:=Bombs.flight_trail(int(weapon.item_id))
	if not preset.is_empty():
		for slot in int(weapon.projectile_capacity):
			var fire:=FireTrail.new();add_child(fire)
			if not fire.configure(preset,bindings,visuals,int(gun.projectiles.get("elapsed_ms",0))):return reject(fire.error)
			fire_trails.append(fire)
	_descriptor=descriptor.duplicate(true);_weapon=weapon.duplicate(true)
	return true

func prepare(gun: Dictionary,camera: Transform3D) -> Dictionary:
	error=""
	var shots: Dictionary=gun.get("projectiles",{})
	var visual: Dictionary=gun.get("visuals",{})
	if _descriptor.is_empty() or shots.get("weapon")!=_weapon or not shots.get("slots") is Array or shots.slots.size()!=bodies.size():return failed("Conventional projectile geometry lost its weapon or slots")
	for key in ["model_id","resource","rules"]:
		if visual.get(key)!=_descriptor[key]:return failed("Conventional projectile model changed")
	for key in ["model_id","resource","start_ms","end_ms"]:
		if visual.get("attachment",{}).get(key)!=_descriptor.attachment[key]:return failed("Conventional attachment identity changed")
	var sampler: RefCounted=_sampler.fork_for_frame()
	var sample: Dictionary=sampler.sample(visual.attachment.time_ms,Transform3D.IDENTITY)
	if sample.is_empty():return failed(sampler.error)
	var ribbon:={}
	if trail!=null:
		ribbon=trail.prepare(shots.get("trails",[]),Vector4.ONE)
		if ribbon.is_empty():return failed(trail.error)
	var fires:=[]
	for index in fire_trails.size():
		var fire: Dictionary=_prepare_fire(fire_trails[index],shots.slots[index],int(shots.get("elapsed_ms",0)))
		if fire.is_empty():return failed(fire_trails[index].error)
		fires.append(fire)
	var slots:=[]
	for slot in shots.slots:
		var root:=Pose.sample(slot,int(_weapon.kind),camera,false,_descriptor.rules,true)
		if root.has("error"):return failed(root.error)
		var surfaces:=[]
		if root.visible:
			surfaces=_surface.prepare_surfaces(sample,root.pose,PackedByteArray([255,255,255,255]),Vector4.ONE)
			if surfaces.is_empty():return failed(_surface.error)
		slots.append({"visible":root.visible,"pose":root.get("pose",Transform3D.IDENTITY),"surfaces":surfaces})
	return {"slots":slots,"sampler":sampler,"trail":ribbon,"fire_trails":fires}

## Fire sprites stream from a shot only while it flies; after a hit or the end
## of its flight the emitted sprites finish their lifetime.
static func _prepare_fire(fire: Node3D,slot: Variant,elapsed_ms: int) -> Dictionary:
	var pose: Variant=null
	var shot:={}
	if slot is Dictionary and int(slot.get("remaining_ms",0))>0 and slot.get("velocity") is Vector3 and Vector3(slot.velocity)!=Vector3.ZERO:
		var forward:=Vectors.normalized(slot.velocity)
		var side:=Vector3.UP if absf(forward.dot(Vector3.UP))<0.999 else Vector3.RIGHT
		var right:=Vectors.normalized(Vectors.cross(side,forward))
		pose=Transform3D(Basis(right,Vectors.normalized(Vectors.cross(forward,right)),forward),slot.position)
		shot={"id":int(slot.id)}
	return fire.prepare({"shot":shot,"elapsed_ms":elapsed_ms},pose)

func commit(prepared: Dictionary) -> void:
	for index in bodies.size():
		var row: Dictionary=prepared.slots[index]
		bodies[index].visible=row.visible;attachments[index].visible=row.visible
		if not row.visible:continue
		bodies[index].transform=row.pose
		_surface.apply_surfaces(attachments[index],row.surfaces,1.0)
	if trail!=null:trail.commit(prepared.trail)
	for index in fire_trails.size():fire_trails[index].commit(prepared.fire_trails[index])
	_sampler=prepared.sampler

func clear() -> void:
	for child in get_children():child.free()
	bodies.clear();attachments.clear();trail=null;fire_trails.clear();_sampler=null;_surface=null;_descriptor={};_weapon={};error=""

func reject(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
