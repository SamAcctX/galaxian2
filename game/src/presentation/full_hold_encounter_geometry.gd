extends Node3D
## Original NPC hulls, lights, engines, cargo and effects. Each complete cast is
## prepared before drawing; lifetime and gameplay stay in the encounter owner.
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const Ship=preload("res://src/presentation/ship_geometry.gd")
const Models=preload("res://src/presentation/model_resources.gd")
const DeathEffect=preload("res://src/presentation/npc_death_effect_geometry.gd")
const Projectiles=preload("res://src/presentation/projectile_geometry.gd")
const Impacts=preload("res://src/presentation/ordinary_impact_geometry.gd")
const Secondaries=preload("res://src/presentation/secondary_geometry.gd")
const Pose=preload("res://src/presentation/opening_geometry.gd")
const OrdinaryFlight=preload("res://src/content/ordinary_flight_definitions.gd")
const FreightGeometry=preload("res://src/presentation/freighter_destruction_geometry.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Junk=preload("res://src/content/contract_junk_definitions.gd")
const Selected=preload("res://src/content/selected40_population_definitions.gd")
const MissionContext=preload("res://src/simulation/mission_context.gd")
const Statics=preload("res://src/content/static_object_definitions.gd")
const Sampler=preload("res://src/presentation/scenery_animation.gd")
const ENGINES={2:{"id":18002,"path":"resources/data/assets/main/3d/meshes/ships/ship_002_pirates_engine_add.aem"},
	30:{"id":18030,"path":"resources/data/assets/main/3d/meshes/ships/ship_030_midorian_engine_add.aem"}}
var error:=""
# The first assembly remains directly accessible to the existing single-NPC
# scene inspections. All gameplay/presentation traversals use the complete list.
var hull: Node3D
var engine: Node3D
var cargo: Node3D
var explosion: Node3D
var projectiles: Node3D
var impacts: Node3D
var secondaries: Node3D
var actors: Array=[]
var _identity:={}
var _library: RefCounted
var _visuals: RefCounted
var _bindings: RefCounted
var _selected40_generation: RefCounted

func build(owner: RefCounted, library: RefCounted, visuals: RefCounted, bindings: RefCounted) -> bool:
	return _build(owner,library,visuals,bindings,false)

## This explicit renderer entry consumes the native selected cast. It does not
## admit cursor40 through ordinary travel or grant any mission-result authority.
func build_selected40(owner: RefCounted,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	return _build(owner,library,visuals,bindings,true)

func _build(owner: RefCounted,library: RefCounted,visuals: RefCounted,bindings: RefCounted,selected40: bool) -> bool:
	clear()
	if not owner is Encounter or owner.snapshot().is_empty():return fail("Prepare the ordinary encounter before its geometry")
	var state: Dictionary=owner.snapshot()
	if bindings==null or state.base_content_id!=bindings.base_content_id or state.binding_id!=bindings.binding_id:return fail("NPC geometry belongs to another content identity")
	var local_traffic: bool=OrdinaryFlight.combat_population(bindings,state.combat)
	# A cast admitted by the mission entry is drawn from its native actors.
	var admitted: RefCounted=MissionContext.from_owner(owner) if not selected40 else null
	if admitted!=null:
		if state.combat.actors.size()!=int(admitted.recipe().result.actor_count):return fail("Mission geometry differs from its admitted cast")
	elif selected40:
		var generation: RefCounted=owner.selected40_construction_owner()
		if generation==null or state.campaign_cursor!=40 or not Selected.context_valid(bindings,generation.snapshot().get("selected40_context",{})) or state.combat.actors.size()!=int(Selected.VALUES.actor_count):return fail("Selected40 geometry requires its original native cast")
		_selected40_generation=generation
	elif local_traffic:
		if not OrdinaryFlight.combat_population(bindings,state.combat):return fail("Unsupported local encounter population")
	elif state.campaign_cursor not in [4,7] or state.combat.actors.size()!=(4 if state.campaign_cursor==7 else 1):return fail("Unsupported ordinary encounter population")
	for id in state.combat.actors.size():
		var actor: Dictionary=state.combat.actors[id]
		if actor.get("population_group")=="debris":
			if not _build_debris(owner,id,actor,library,visuals,bindings):return false
			continue
		if actor.get("population_group")=="static":
			if not _build_static(owner,id,actor,library,visuals,bindings):return false
			continue
		var native_cast: bool=local_traffic or selected40 or admitted!=null
		var ship_id: int=int(actor.hull_catalogue_id) if native_cast else (30 if id==3 else 2)
		if actor.actor_id!=id or actor.hull_catalogue_id!=ship_id or (not native_cast and actor.actor_kind!=(3 if id==3 else 8)):return fail("Unsupported ordinary NPC model construction")
		if selected40:
			var constructed: Dictionary=_selected40_generation.snapshot().actors[id]
			if actor.hull_catalogue_id!=constructed.hull_catalogue_id or actor.population_group!=constructed.population_group or not Selected.constructed_kind_matches(actor,int(constructed.actor_kind)):return fail("Selected40 model differs from its constructed hull or faction")
		if actor.get("population_group") in ["freighter","capital"]:
			if not _build_freighter(owner,id,actor,library,visuals,bindings):return false
			continue
		var exhaust: Dictionary
		if native_cast:
			var engine_id:=int(bindings.mido_travel.traffic_presentation.engine_model_base)+ship_id
			exhaust={"id":engine_id,"path":bindings.resolve(engine_id,"mesh")}
		else:exhaust=ENGINES[ship_id]
		if bindings.resolve(exhaust.id,"mesh")!=exhaust.path or bindings.material_for_mesh(exhaust.path,"high").get("render_type")!=2:return fail("Unsupported NPC engine model/material mapping")
		var death: RefCounted=owner.npc_destruction_owner(id)
		if death==null:return fail("NPC model lacks its retained destruction owner")
		var held: Dictionary=death.snapshot().cargo
		if bindings.resolve(held.model_id,"mesh")!=held.resource or bindings.material_for_mesh(held.resource,"high").get("render_type")!=28:return fail("Unsupported NPC cargo model/material mapping")
		var body:=Ship.new();add_child(body)
		if not body.build(ship_id,library,visuals,bindings):return fail(body.error)
		var resources:=Models.new()
		if not resources.prepare([exhaust.path,held.resource],library,visuals,bindings,"high",true,true):return fail(resources.error)
		var motor: Node3D=resources.instantiate(exhaust.path);var container: Node3D=resources.instantiate(held.resource)
		resources.clear();add_child(motor);add_child(container);motor.hide();container.hide()
		motor.set_meta("source_resource_id",exhaust.id);container.set_meta("source_resource_id",held.model_id)
		var effect:=DeathEffect.new();add_child(effect)
		if not effect.build(library,visuals,bindings,death):return fail(effect.error)
		actors.append({"hull":body,"engine":motor,"cargo":container,"explosion":effect,
			"ship_id":ship_id,"hull_resource":actor.hull_resource,"cargo_resource":held.resource})
	if not actors.is_empty():
		hull=actors[0].hull;engine=actors[0].engine;cargo=actors[0].cargo;explosion=actors[0].explosion
	projectiles=Projectiles.new();add_child(projectiles)
	if not projectiles.build(owner.projectile_visual_owner(),library,visuals,bindings):return fail(projectiles.error)
	impacts=Impacts.new();add_child(impacts)
	if not impacts.build(owner.impact_visual_owner(),library,visuals,bindings):return fail(impacts.error)
	if _draws_launchers(owner):
		secondaries=Secondaries.new();add_child(secondaries)
		if not secondaries.build(owner.secondary_owner(),library,visuals,bindings):return fail(secondaries.error)
	_identity={"base_content_id":state.base_content_id,"binding_id":state.binding_id,"campaign_cursor":state.campaign_cursor}
	_library=library;_visuals=visuals;_bindings=bindings
	return true

## A launcher whose last round was spent before this flight has left the
## loadout; there is nothing to draw, but the secondary owner still exists.
func _draws_launchers(owner: RefCounted) -> bool:
	return owner.has_secondaries() and not owner.secondary_owner().snapshot().guns.is_empty()

func _build_debris(owner: RefCounted,id: int,actor: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	if not Junk.available(bindings) or actor.actor_kind!=-1 or actor.actor_id!=id:return fail("Debris geometry requires its original contract construction")
	var rules: Dictionary=bindings.early_contracts.junk_lifecycle
	var death: RefCounted=owner.npc_destruction_owner(id)
	if death==null or death.snapshot().resource_id!=actor.resource_id or bindings.resolve(actor.resource_id,"mesh")!=actor.hull_resource:return fail("Debris geometry lost its original body or lifecycle")
	if bindings.resolve(int(rules.cargo_model_id),"mesh")!=rules.cargo_model_resource:return fail("Debris cargo lost its original container")
	var resources:=Models.new()
	if not resources.prepare([actor.hull_resource,rules.cargo_model_resource],library,visuals,bindings,"high",true,true):return fail(resources.error)
	var body: Node3D=resources.instantiate(actor.hull_resource)
	var container: Node3D=resources.instantiate(rules.cargo_model_resource)
	resources.clear();add_child(body);add_child(container);container.hide()
	body.set_meta("source_resource_id",actor.resource_id);container.set_meta("source_resource_id",int(rules.cargo_model_id))
	actors.append({"hull":body,"engine":null,"cargo":container,"explosion":null,"debris":true,
		"ship_id":-1,"resource_id":actor.resource_id,"hull_resource":actor.hull_resource,"cargo_resource":rules.cargo_model_resource})
	return true

## Static objects draw their model layers; after death the wreck animation
## replaces them and holds its last pose.
func _build_static(owner: RefCounted,id: int,actor: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	var death: RefCounted=owner.npc_destruction_owner(id)
	if death==null or not actor.get("static_object",false) or actor.actor_id!=id:return fail("Static geometry requires its object and destruction owner")
	var reader:=Statics.new();var placed: Dictionary=reader.resolve(library,bindings,int(actor.static_model))
	if placed.is_empty():return fail(reader.error)
	var paths: Array=placed.layers.map(func(layer):return layer.path)
	var wrecked: bool=not placed.wreck.path.is_empty()
	if wrecked:paths.append(placed.wreck.path)
	var resources:=Models.new()
	if not resources.prepare(paths,library,visuals,bindings,"high",false,true):return fail(resources.error)
	var body:=Node3D.new();body.name="StaticObject%d"%id;add_child(body)
	for layer in placed.layers:
		var model: Node3D=resources.instantiate(layer.path)
		if model==null:
			var reason: String=resources.error;resources.clear();return fail(reason)
		model.set_meta("source_resource_id",layer.resource_id);body.add_child(model)
	# Without a wreck the object just vanishes (80's weak points).
	var wreck: Node3D=resources.instantiate(placed.wreck.path) if wrecked else Node3D.new()
	resources.clear()
	if wreck==null:return fail("Static wreck model preparation failed")
	add_child(wreck);wreck.hide();wreck.set_meta("source_resource_id",placed.wreck.resource_id)
	var sampler: RefCounted=null
	if wrecked:
		for instance in wreck.instances:instance.top_level=true
		sampler=Sampler.new()
		if not sampler.configure(wreck.surfaces):return fail(sampler.error)
	actors.append({"hull":body,"engine":null,"cargo":wreck,"explosion":null,"static":true,"sampler":sampler,
		"ship_id":-1,"resource_id":int(actor.resource_id),"hull_resource":actor.hull_resource})
	return true

func _prepare_static(actor: Dictionary,nodes: Dictionary,death: RefCounted) -> Dictionary:
	var state: Dictionary=death.snapshot()
	if state.get("pose")!=actor.body_pose or state.get("static_model")!=actor.static_model:return failed("Static presentation lost its object or pose")
	var wrecked: bool=state.phase!="ready" and nodes.sampler!=null
	var sampler: RefCounted=nodes.sampler
	var animated:={}
	if wrecked:
		sampler=nodes.sampler.fork_for_frame()
		animated=sampler.sample(int(state.animation.time_ms),state.pose)
		if animated.is_empty():return failed(sampler.error)
	return {"pose":actor.body_pose,"body_visible":actor.model_draw_enabled,"cargo_visible":wrecked,"cargo_pose":state.pose,"animated":animated,"sampler":sampler}

func _prepare_debris(actor: Dictionary,nodes: Dictionary,death: RefCounted) -> Dictionary:
	var state: Dictionary=death.snapshot()
	if actor.resource_id!=nodes.resource_id or state.resource_id!=nodes.resource_id or state.pose!=actor.body_pose or state.statistics_pose!=actor.pose or state.active!=actor.active or state.model_draw_enabled!=actor.model_draw_enabled:return failed("Debris presentation lost its retained body or lifecycle")
	var held: Dictionary=state.cargo
	if not held.is_empty() and (held.get("resource")!=nodes.cargo_resource or held.get("pose")!=state.pose or not held.get("model_exists") is bool):return failed("Debris container lost its source identity or stationary pose")
	return {"pose":state.pose,"body_visible":state.model_draw_enabled,
		"cargo_visible":held.get("model_exists",false),"cargo_pose":state.pose}

func _build_freighter(owner: RefCounted,id: int,actor: Dictionary,library: RefCounted,visuals: RefCounted,bindings: RefCounted) -> bool:
	var assembly: Dictionary=owner.freighter_assembly(id)
	var body:=Ship.new();add_child(body)
	if not body.build_population_assembly(assembly,library,visuals,bindings):return fail(body.error)
	if owner.freighter_resources()==null or owner.npc_destruction_owner(id)==null:return fail("Freighter has no retained destruction resources")
	var effect:=FreightGeometry.new();add_child(effect);effect.hide()
	actors.append({"hull":body,"engine":null,"cargo":null,"explosion":effect,"freighter":true,
		"ship_id":int(actor.hull_catalogue_id),"hull_resource":actor.hull_resource,
		"constructed_kind":int(_selected40_generation.snapshot().actors[id].actor_kind) if _selected40_generation!=null else int(actor.actor_kind)})
	return true

func _prepare_freighter(owner: RefCounted,actor: Dictionary,nodes: Dictionary,death: RefCounted,camera: Transform3D,selection: Dictionary) -> Dictionary:
	var state: Dictionary=death.snapshot()
	if not Pose.valid_pose(actor.get("body_pose")):return failed("Freighter lost its logical model root")
	var effect:={}
	if state.phase!="ready":
		# Stage invisible resources at lethal entry, after native debris sampling.
		# Model/material poses become visible only with the accepted scene frame.
		# A selected story may reclassify the living ship without rebuilding its
		# original Terran assembly. Debris must retain the constructor's faction.
		var resource_kind:=int(actor.actor_kind)
		if _selected40_generation!=null:
			if not Selected.constructed_kind_matches(actor,int(nodes.constructed_kind)):return failed("Freighter destruction changed its constructed faction")
			resource_kind=int(nodes.constructed_kind)
		var resources: RefCounted=owner.freighter_resources().faction_owner(resource_kind)
		if resources==null:return failed("Freighter destruction lost its faction resources")
		if not nodes.explosion.is_built() and not nodes.explosion.build(_library,_visuals,_bindings,resources,death):return failed(nodes.explosion.error)
		effect=nodes.explosion.prepare_state(death,camera)
		if effect.is_empty():return failed(nodes.explosion.error)
	return {"pose":actor.body_pose,"body_visible":state.phase=="ready" and actor.active and actor.node_draw_requested and actor.model_draw_enabled,
		"selection":selection.duplicate(true),"effect":effect,"engine_draw_enabled":actor.engine_draw_enabled}

## `observed` is the flight's own encounter snapshot for this owner, when the
## caller already holds it; it contains every presentation field.
func prepare_world(owner: RefCounted, camera: Transform3D, detail: Dictionary, observed: Dictionary={}) -> Dictionary:
	error=""
	if _identity.is_empty() or not owner is Encounter:return failed("Build the NPC assemblies before presenting them")
	if owner.selected40_construction_owner()!=_selected40_generation:return failed("NPC geometry belongs to another selected cast generation")
	var state: Dictionary=owner.presentation_snapshot() if observed.is_empty() else observed
	for key in _identity:
		if state.get(key)!=_identity[key]:return failed("NPC frame belongs to another encounter")
	if state.combat.actors.size()!=actors.size():return failed("NPC population changed")
	if detail.get("base_content_id")!=_identity.base_content_id or detail.get("binding_id")!=_identity.binding_id:return failed("NPC detail selections belong to another geometry manager")
	var prepared:=[]
	for id in actors.size():
		var nodes: Dictionary=actors[id];var actor: Dictionary=state.combat.actors[id]
		if actor.actor_id!=id or actor.hull_catalogue_id!=nodes.ship_id or actor.hull_resource!=nodes.hull_resource or not Pose.valid_pose(actor.pose):return failed("NPC hull or statistics pose changed")
		var death: RefCounted=owner.npc_destruction_owner(id)
		if death==null:return failed("NPC lost its destruction owner")
		if nodes.get("debris",false):
			var current:=_prepare_debris(actor,nodes,death)
			if current.is_empty():return {}
			prepared.append(current);continue
		if nodes.get("static",false):
			var current:=_prepare_static(actor,nodes,death)
			if current.is_empty():return {}
			prepared.append(current);continue
		for key in ["active","node_draw_requested","model_draw_enabled","engine_draw_enabled"]:
			if not actor.get(key) is bool:return failed("NPC visibility flag is missing")
		var selection: Dictionary=detail.get("selections",{}).get(id,{})
		# The source never registers geometry with no alternate meshes in the
		# periodic LOD manager. Its sole detailed body still renders normally.
		if selection.is_empty() and nodes.hull.levels.size()==1:selection={"visible":true,"level":0}
		if not nodes.hull.valid_selection(selection):return failed("NPC detail selection is unavailable")
		if nodes.get("freighter",false):
			var current:=_prepare_freighter(owner,actor,nodes,death,camera,selection)
			if current.is_empty():return {}
			prepared.append(current);continue
		var held: Dictionary=death.snapshot().cargo
		if held.get("resource")!=nodes.cargo_resource or not held.get("model_exists") is bool or not Pose.valid_pose(held.get("pose")):return failed("NPC cargo presentation lost its retained model")
		var effect_node: Node3D=nodes.explosion
		if not effect_node.follows(death):
			# Recycled slots retain their hull but acquire a fresh cargo/death
			# owner. Stage that owner's effect without replacing accepted art.
			var pending: Variant=nodes.get("pending_effect")
			if pending!=null and not pending.follows(death):pending.free();pending=null
			if pending==null:
				pending=DeathEffect.new();add_child(pending)
				if not pending.build(_library,_visuals,_bindings,death):
					var reason: String=pending.error;pending.free();nodes.erase("pending_effect");return failed(reason)
				nodes.pending_effect=pending
			effect_node=pending
		var effect: Dictionary=effect_node.prepare_effect(death,camera,PackedByteArray([255,255,255,255]),Vector4.ONE,1.0)
		if effect.is_empty():return failed(effect_node.error)
		var body_visible: bool=actor.active and actor.node_draw_requested and actor.model_draw_enabled and effect.body_visible
		prepared.append({"pose":actor.body_pose if _selected40_generation!=null else actor.pose,"body_visible":body_visible,"engine_visible":body_visible and actor.engine_draw_enabled,
			"cargo_visible":held.model_exists,"cargo_pose":held.pose,"selection":selection.duplicate(true),"effect":effect,"effect_node":effect_node})
	var shots: Dictionary=projectiles.prepare_world(owner.projectile_visual_owner(),state,camera)
	if shots.is_empty():return failed(projectiles.error)
	var hits: Dictionary=impacts.prepare_world(owner.impact_visual_owner(),state,camera)
	if hits.is_empty():return failed(impacts.error)
	var result: Dictionary={} if prepared.is_empty() else prepared[0].duplicate(true)
	result.merge({"actors":prepared,"shots":shots,"hits":hits})
	if secondaries==null and _draws_launchers(owner):return failed("EMP presentation lost its equipped owner")
	if secondaries!=null:
		result.secondaries=secondaries.prepare_world(owner.secondary_owner(),camera)
		if result.secondaries.is_empty():return failed(secondaries.error)
	return result

func commit_world(frame: Dictionary) -> void:
	for id in actors.size():
		var nodes: Dictionary=actors[id];var current: Dictionary=frame.actors[id]
		nodes.hull.transform=current.pose;nodes.hull.visible=current.body_visible
		if nodes.get("debris",false):
			nodes.cargo.transform=current.cargo_pose;nodes.cargo.visible=current.cargo_visible
			continue
		if nodes.get("static",false):
			nodes.cargo.visible=current.cargo_visible
			if not current.animated.is_empty():
				for i in nodes.cargo.instances.size():nodes.cargo.instances[i].transform=current.animated.surfaces[i].pose
			nodes.sampler=current.sampler
			continue
		nodes.hull.apply_selection(current.selection)
		if nodes.get("freighter",false):
			nodes.hull.apply_engine_draw(current.engine_draw_enabled)
			if not current.effect.is_empty():nodes.explosion.commit_state(current.effect)
			continue
		nodes.engine.transform=current.pose;nodes.engine.visible=current.engine_visible
		# Source draws a retained cargo model before testing the NPC's activity.
		nodes.cargo.transform=current.cargo_pose;nodes.cargo.visible=current.cargo_visible
		if current.effect_node!=nodes.explosion:
			nodes.explosion.free();nodes.explosion=current.effect_node;nodes.erase("pending_effect")
			if id==0:explosion=nodes.explosion
		nodes.explosion.commit_effect(current.effect)
	projectiles.commit_world(frame.shots);impacts.commit_world(frame.hits)
	if secondaries!=null:secondaries.commit_world(frame.secondaries)

func clear() -> void:
	for child in get_children():child.free()
	hull=null;engine=null;cargo=null;explosion=null;projectiles=null;impacts=null;secondaries=null
	actors=[];_identity={};_library=null;_visuals=null;_bindings=null;_selected40_generation=null;error=""
func fail(message: String) -> bool:clear();error=message;return false
func failed(message: String) -> Dictionary:error=message;return {}
