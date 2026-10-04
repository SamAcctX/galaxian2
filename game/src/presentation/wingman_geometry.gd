extends Node3D
## Passive original hulls for the retained wingman cast. No gameplay is inferred.
const Crew=preload("res://src/simulation/wingman_actors.gd")
const Ship=preload("res://src/presentation/ship_geometry.gd")
const Projectiles=preload("res://src/presentation/projectile_geometry.gd")
const Impacts=preload("res://src/presentation/ordinary_impact_geometry.gd")
const DeathEffect=preload("res://src/presentation/npc_death_effect_geometry.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const DeathResources=preload("res://src/content/npc_destruction_resources.gd")
var error:=""
var actors:=[]
var _identity:={}
var projectiles: Node3D
var impacts: Node3D
var systems_projectiles: Node3D
var systems_impacts: Node3D
var death_effects:=[]

func build(owner: RefCounted,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	clear()
	if not owner is Crew:return fail("Wingman geometry needs its retained actor owner")
	var state: Dictionary=owner.snapshot()
	if state.is_empty() or state.base_content_id!=bindings.base_content_id or state.binding_id!=bindings.binding_id:return fail("Wingman geometry belongs to another flight")
	for actor in state.actors:
		var ship:=Ship.new();add_child(ship)
		if not ship.build(int(actor.hull_catalogue_id),library,visuals,bindings):return fail(ship.error)
		ship.name="Wingman%d" % actor.wingman_index
		ship.set_meta("wingman_name",actor.name)
		actors.append({"ship":ship,"name":actor.name,"hull":actor.hull_catalogue_id})
	_identity={"base_content_id":state.base_content_id,"binding_id":state.binding_id}
	if owner.destruction_owner(0)!=null:
		var models:=Models.new()
		if not models.prepare(DeathResources.PATHS,library,visuals,bindings,"high",false,true):return fail(models.error)
		for index in actors.size():
			var effect:=DeathEffect.new();add_child(effect);death_effects.append(effect)
			if not effect.build(library,visuals,bindings,owner.destruction_owner(index),"high",models):models.clear();return fail(effect.error)
		models.clear()
	if owner.projectile_visual_owner()!=null:
		projectiles=Projectiles.new();add_child(projectiles)
		impacts=Impacts.new();add_child(impacts)
		if not projectiles.build(owner.projectile_visual_owner(),library,visuals,bindings):return fail(projectiles.error)
		if not impacts.build(owner.impact_visual_owner(),library,visuals,bindings):return fail(impacts.error)
	if owner.systems_projectile_visual_owner()!=null:
		systems_projectiles=Projectiles.new();add_child(systems_projectiles)
		systems_impacts=Impacts.new();add_child(systems_impacts)
		if not systems_projectiles.build(owner.systems_projectile_visual_owner(),library,visuals,bindings):return fail(systems_projectiles.error)
		if not systems_impacts.build(owner.systems_impact_visual_owner(),library,visuals,bindings):return fail(systems_impacts.error)
	return true

func prepare(state: Dictionary,owner: RefCounted=null,camera:=Transform3D.IDENTITY) -> Dictionary:
	error=""
	for key in _identity:
		if state.get(key)!=_identity[key]:return failed("The wingman cast changed content identity")
	if not state.get("actors") is Array or state.actors.size()!=actors.size():return failed("The wingman cast changed within its flight")
	var prepared:=[]
	for index in actors.size():
		var actor: Dictionary=state.actors[index];var node: Dictionary=actors[index]
		var selection: Dictionary=state.get("detail",{}).get(index,{})
		if actor.get("name")!=node.name or actor.get("hull_catalogue_id")!=node.hull or actor.get("wingman_index")!=index or not actor.get("pose") is Transform3D or not actor.pose.is_finite() or not node.ship.valid_selection(selection):return failed("Wingman appearance lost its native pilot, hull or pose")
		prepared.append({"pose":actor.pose,"selection":selection,"visible":actor.active and actor.model_draw_enabled and actor.node_draw_requested})
	var frame:={"actors":prepared}
	if not death_effects.is_empty():
		if not owner is Crew or state.get("destruction",[]).size()!=death_effects.size():return failed("Companion death presentation lost its native owners")
		frame.deaths=[]
		for index in death_effects.size():
			var death: RefCounted=owner.destruction_owner(index)
			var body: Dictionary=state.destruction[index]
			if death==null or death.snapshot()!=body:return failed("Companion wreck presentation changed its retained frame")
			var sample: Dictionary=death_effects[index].prepare_effect(death,camera,PackedByteArray([255,255,255,255]),Vector4.ONE,1.0)
			if sample.is_empty():return failed(death_effects[index].error)
			frame.deaths.append(sample)
			frame.actors[index].visible=frame.actors[index].visible and sample.body_visible
			if body.phase!="ready":frame.actors[index].pose=body.pose*Transform3D(body.bank_basis,Vector3.ZERO)
	if projectiles!=null:
		if not owner is Crew or owner.weapon_world()!=state.get("weapon_world"):return failed("Companion shots lost their retained native owner")
		frame.projectiles=projectiles.prepare_world(owner.projectile_visual_owner(),state.weapon_world,camera)
		if frame.projectiles.is_empty():return failed(projectiles.error)
		frame.impacts=impacts.prepare_world(owner.impact_visual_owner(),state.weapon_world,camera)
		if frame.impacts.is_empty():return failed(impacts.error)
	if systems_projectiles!=null:
		if not owner is Crew or owner.systems_weapon_world()!=state.get("systems_weapon_world"):return failed("Companion systems shots lost their native owner")
		frame.systems_projectiles=systems_projectiles.prepare_world(owner.systems_projectile_visual_owner(),state.systems_weapon_world,camera)
		if frame.systems_projectiles.is_empty():return failed(systems_projectiles.error)
		frame.systems_impacts=systems_impacts.prepare_world(owner.systems_impact_visual_owner(),state.systems_weapon_world,camera)
		if frame.systems_impacts.is_empty():return failed(systems_impacts.error)
	return frame

func commit(frame: Dictionary) -> void:
	for index in actors.size():
		var current: Dictionary=frame.actors[index]
		actors[index].ship.transform=current.pose
		actors[index].ship.visible=current.visible
		actors[index].ship.apply_selection(current.selection)
	if projectiles!=null:projectiles.commit_world(frame.projectiles);impacts.commit_world(frame.impacts)
	if systems_projectiles!=null:systems_projectiles.commit_world(frame.systems_projectiles);systems_impacts.commit_world(frame.systems_impacts)
	for index in death_effects.size():death_effects[index].commit_effect(frame.deaths[index])

func clear() -> void:
	for child in get_children():child.free()
	actors=[];_identity={};error=""
	projectiles=null;impacts=null
	systems_projectiles=null;systems_impacts=null
	death_effects=[]

func fail(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
