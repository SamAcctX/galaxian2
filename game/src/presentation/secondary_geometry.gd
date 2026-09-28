extends Node3D
## Original secondary bodies and effects share one accepted frame.
## Removing the last ammunition slot never removes a live projectile or effect.
const Ownership=preload("res://src/simulation/secondary_weapons.gd")
const Burst=preload("res://src/presentation/emp_detonation_geometry.gd")
const AreaBurst=preload("res://src/presentation/npc_death_effect_geometry.gd")
const BombBody=preload("res://src/presentation/bomb_projectile_geometry.gd")
const Conventional=preload("res://src/presentation/conventional_secondary_geometry.gd")
var error:=""
var bodies: Array[Node3D]=[]
var detonations: Array[Node3D]=[]
var _conventional:={}
var _bombs:={}
var _detonation_slots: Array[int]=[]
var _identity: RefCounted
var _content:={}
var _launchers:=[]
var _generation: RefCounted
var _revision:=0

func build(owner: RefCounted,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	if not owner is Ownership or owner.presentation_identity()==null or not Ownership.Definitions.available(bindings):return fail("EMP geometry requires its configured launcher")
	var state: Dictionary=owner.snapshot();var launchers:=[]
	for key in ["base_content_id","binding_id"]:
		if state.loadout.get(key)!=bindings.get(key):return fail("EMP geometry belongs to another content identity")
	for gun in state.guns:
		if gun.has("projectiles"):
			if not gun.get("visuals") is Dictionary:return fail("Conventional secondary model clocks were not prepared")
			launchers.append({"slot_index":gun.slot_index,"item_id":gun.equipment.item_id,"model_id":gun.visuals.model_id,"resource":gun.visuals.resource,"conventional":true})
			continue
		var weapon: Dictionary=gun.bomb.weapon
		launchers.append({"slot_index":gun.slot_index,"item_id":gun.equipment.item_id,"model_id":weapon.model_id,"bomb_kind":weapon.kind})
	if launchers.is_empty():return fail("EMP geometry has no installed launcher")
	for index in launchers.size():
		var launcher: Dictionary=launchers[index]
		if launcher.has("bomb_kind"):
			var projectile:=BombBody.new();add_child(projectile);bodies.append(projectile);_bombs[index]=projectile
			if not projectile.build(state.guns[index].bomb,library,visuals,bindings):return fail(projectile.error)
			continue
		var projectile:=Conventional.new();add_child(projectile);bodies.append(projectile);_conventional[index]=projectile
		if not projectile.build(state.guns[index],library,visuals,bindings):return fail(projectile.error)
	if owner.has_detonations():
		for launcher in launchers:
			if launcher.get("conventional",false):continue
			var area: bool=launcher.bomb_kind==7
			var burst: Node3D=AreaBurst.new() if area else Burst.new()
			add_child(burst);detonations.append(burst)
			_detonation_slots.append(launcher.slot_index)
			var ready: bool=burst.build(library,visuals,bindings,owner.detonation_owner(launcher.slot_index)) if area else burst.build(owner.detonation_owner(launcher.slot_index),library,visuals,bindings)
			if not ready:return fail(burst.error)
	_identity=owner.presentation_identity();_launchers=launchers
	_content={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_generation=RefCounted.new()
	return true

func prepare_world(owner: RefCounted,camera: Variant=null) -> Dictionary:
	error=""
	if _identity==null or not owner is Ownership or owner.presentation_identity()!=_identity:return failed("EMP geometry follows one retained launcher generation")
	var state: Dictionary=owner.snapshot()
	for key in _content:
		if state.loadout.get(key)!=_content[key]:return failed("EMP presentation changed content identity")
	if state.guns.size()!=_launchers.size():return failed("EMP presentation changed launcher count")
	if owner.has_detonations()!=(not detonations.is_empty()):return failed("EMP presentation lost its prepared burst wrappers")
	if not detonations.is_empty() and not camera is Transform3D:return failed("EMP bursts require the accepted flight camera")
	var poses:=[];var projectiles:={};var bombs:={}
	for index in state.guns.size():
		var gun: Dictionary=state.guns[index];var launcher: Dictionary=_launchers[index]
		if gun.slot_index!=launcher.slot_index or gun.equipment.item_id!=launcher.item_id:return failed("Secondary presentation changed the source launcher order")
		if launcher.has("bomb_kind"):
			var projectile: Dictionary=_bombs[index].prepare(gun.bomb)
			if projectile.is_empty():return failed(_bombs[index].error)
			bombs[index]=projectile;poses.append({"visible":projectile.visible,"pose":Transform3D.IDENTITY})
			continue
		var projectile: Dictionary=_conventional[index].prepare(gun,camera if camera is Transform3D else Transform3D.IDENTITY)
		if projectile.is_empty():return failed(_conventional[index].error)
		projectiles[index]=projectile;poses.append({"visible":true,"pose":Transform3D.IDENTITY})
	var frame:={"identity":_identity,"generation":_generation,"revision":_revision+1,"bodies":poses,"conventional":projectiles,"bombs":bombs}
	if not detonations.is_empty():
		var effects:=[]
		for index in detonations.size():
			var effect: Dictionary=detonations[index].prepare_effect(owner.detonation_owner(_detonation_slots[index]),camera,PackedByteArray([255,255,255,255]),Vector4.ONE,1.0)
			if effect.is_empty():return failed(detonations[index].error)
			effects.append(effect)
		frame.detonations=effects
	return frame

func commit_world(frame: Dictionary) -> void:
	error=""
	# Retired bodies and rebuilt launchers must not consume an older prepared
	# view. Owner identity alone also survives rebuilding this geometry.
	if _generation==null or frame.get("identity")!=_identity or frame.get("generation")!=_generation or frame.get("revision")!=_revision+1:
		error="EMP geometry cannot commit a stale prepared frame";return
	_revision+=1
	for index in bodies.size():
		bodies[index].transform=frame.bodies[index].pose
		bodies[index].visible=frame.bodies[index].visible
	for index in detonations.size():detonations[index].commit_effect(frame.detonations[index])
	for index in _conventional:_conventional[index].commit(frame.conventional[index])
	for index in _bombs:_bombs[index].commit(frame.bombs[index])

func clear() -> void:
	for child in get_children():child.free()
	bodies.clear();detonations.clear();_identity=null;_content={};_launchers=[];error=""
	_conventional={};_bombs={};_detonation_slots=[]
	_generation=null;_revision=0

func fail(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
