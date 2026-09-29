extends RefCounted
## Paid companions are a separate cast, not extra ambient patrol slots.
## Ordinary flight retains unboosted formation steering and detail selection.
## Command-one pursuit shares ordinary targeting; weapons and loss are separate.
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Contracts=preload("res://src/simulation/wingman_contract.gd")
const Ordinary=preload("res://src/content/contract_world_definitions.gd")
const FreeFlight=preload("res://src/content/free_flight_definitions.gd")
const Body=preload("res://src/simulation/opening_combat_actor.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Detail=preload("res://src/presentation/ship_detail_group.gd")
const Targeting=preload("res://src/simulation/ordinary_npc_targeting.gd")
const Guidance=preload("res://src/content/opening_npc_guidance_definitions.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const ProjectileVisuals=preload("res://src/simulation/projectile_visual_state.gd")
const ImpactVisuals=preload("res://src/simulation/ordinary_impact_state.gd")
var error:=""
var _identity:={}
var _actors:=[]
var _flight:=[]
var _follow_targets:=[]
var _cruise_speed:=0.0
var _detail: RefCounted
var _detail_positions:={}
var _selections:=[]
var _targeting_tuning:={}
var _targeting_rules:={}
var _weapons: RefCounted
var _projectiles: RefCounted
var _impacts: RefCounted
var _weapon_elapsed_ms:=0
var _weapon_events:=[]
var _firing:={"actors":[]}
var _systems_weapons: RefCounted
var _systems_projectiles: RefCounted
var _systems_impacts: RefCounted
var _systems_events:=[]
var _systems_firing:={"actors":[]}
var _weapon_groups:=[]

func configure(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted,library: RefCounted=null) -> bool:
	error=""
	if not construction is Construction:return reject("Wingmen require the retained native departure")
	var career: RefCounted=construction.contract_owner()
	var roster: Dictionary={} if career==null else career.snapshot().get("wingmen",{}).get("active",{})
	var entry: Dictionary=construction.snapshot()
	if roster.is_empty() or not (Ordinary.ordinary_entry(bindings,entry) or FreeFlight.ordinary_entry(bindings,entry)):
		_identity={};_actors=[];_flight=[];_follow_targets=[];_cruise_speed=0.0;_detail=null;_detail_positions={}
		_selections=[];_targeting_tuning={};_targeting_rules={}
		_weapons=null;_projectiles=null;_impacts=null;_weapon_elapsed_ms=0;_weapon_events=[];_firing={"actors":[]}
		_systems_weapons=null;_systems_projectiles=null;_systems_impacts=null;_systems_events=[];_systems_firing={"actors":[]};_weapon_groups=[]
		return true
	if not Contracts.valid_active(roster,bindings) or not Flight.rigid_pose(entry.player_pose):return reject("The flight lost its paid roster or player pose")
	var speed: Variant=bindings.opening_actors.npc_initialization.get("guidance",{}).get("cruise_speed")
	if (not speed is float and not speed is int) or not is_finite(float(speed)) or speed<=0:return reject("Wingmen require the retained ordinary fighter cruise speed")
	var tuning: Dictionary=bindings.opening_actors.npc_initialization.guidance
	if not Guidance.parameters(tuning):return reject("Wingmen require ordinary target-selection tuning")
	var retained: Dictionary=career.snapshot()
	var actors:=[];var flights:=[];var targets:=[];var ships:={};var positions:={};var selections:=[]
	for index in roster.names.size():
		var hull:=hull_for_pilot(bindings,roster.names[index],int(roster.faction))
		if hull<0:return reject("The hired pilot has no eligible original fighter")
		var pose:=spawn_pose(entry.player_pose,index)
		var initial:={"actor_id":index,"actor_kind":int(roster.faction),"hull_catalogue_id":hull,
			"name":roster.names[index],"position":pose.origin,"pose":pose}
		var actor:=Body.new()
		if not actor._configure_wingman(bindings,catalogues,initial,int(retained.rank),int(entry.campaign_cursor),float(retained.difficulty)):return reject(actor.error)
		var motion:=Flight.new()
		if not motion.configure(bindings,pose):return reject(motion.error)
		actors.append(actor)
		flights.append(motion);targets.append(follow_position(entry.player_pose,index))
		selections.append({"target_index":int(bindings.combat_training_control.initial_target_index),"target_actor_id":-1,
			"selection_elapsed_ms":int(bindings.opening_actors.npc_initialization.get("holding",{}).get("selection_elapsed_ms",0)),
			"straight":false,"fire_desired":false,"target_selected":false})
		if int(bindings.ship_lod.body_resource_ids[hull][0])!=65535:
			ships[index]=hull;positions[index]=pose.origin
	var detail: RefCounted
	if not ships.is_empty():
		detail=Detail.new()
		if not detail.configure(bindings,ships) or not detail.refresh(positions,entry.player_pose.origin,1.0):return reject(detail.error)
	var weapons:=Weapons.new()
	if not weapons.configure_wingmen(bindings,catalogues,construction,actors):return reject(weapons.error)
	var systems_weapons:=Weapons.new()
	if not systems_weapons.configure_wingmen(bindings,catalogues,construction,actors,true):return reject(systems_weapons.error)
	var projectiles: RefCounted;var impacts: RefCounted
	var systems_projectiles: RefCounted;var systems_impacts: RefCounted
	if library!=null:
		var world:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":0,"weapons":weapons.snapshot()}
		projectiles=ProjectileVisuals.new();impacts=ImpactVisuals.new()
		if not projectiles.configure(bindings,library,world) or not impacts.configure(bindings,library,world):return reject(projectiles.error+impacts.error)
		if not systems_weapons.wingman_systems_declarations().is_empty():
			var systems_world:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":0,"weapons":systems_weapons.snapshot()}
			systems_projectiles=ProjectileVisuals.new();systems_impacts=ImpactVisuals.new()
			if not systems_projectiles.configure(bindings,library,systems_world) or not systems_impacts.configure(bindings,library,systems_world):return reject(systems_projectiles.error+systems_impacts.error)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_actors=actors;_detail=detail;_detail_positions=positions
	_flight=flights;_follow_targets=targets;_cruise_speed=float(speed)
	_selections=selections;_targeting_tuning=tuning
	_targeting_rules={"random_selection_chance":int(bindings.combat_training_control.random_selection_chance),
		"random_selection_attempts":int(bindings.combat_training_control.random_selection_attempts)}
	_weapons=weapons;_projectiles=projectiles;_impacts=impacts;_weapon_elapsed_ms=0;_weapon_events=[];_firing={"actors":[]}
	_systems_weapons=systems_weapons;_systems_projectiles=systems_projectiles;_systems_impacts=systems_impacts
	_systems_events=[];_systems_firing={"actors":[]};_weapon_groups=[]
	for actor in actors:_weapon_groups.append(0)
	return true

## Existing shots contact retained NPC bodies before movement. The outer frame
## commits both successors; a rejected candidate cannot leak damage or slots.
func advance_weapons(milliseconds: int,encounter: RefCounted) -> Dictionary:
	if _weapons==null or milliseconds<0 or _weapon_elapsed_ms>Vitals.MAX_INTEGER-milliseconds:reject("Invalid companion weapon clock");return {}
	var prior:=weapon_world()
	var systems_prior:=systems_weapon_world()
	var result: Dictionary=_weapons.evaluate_wingman_contacts(null,milliseconds,_systems_weapons) if encounter==null else encounter.evaluate_wingman_contacts(_weapons,milliseconds,_systems_weapons)
	if result.is_empty():reject(_weapons.error if encounter==null else encounter.error);return {}
	var projectiles: RefCounted=null if _projectiles==null else _projectiles.fork_for_frame()
	var impacts: RefCounted=null if _impacts==null else _impacts.fork_for_frame()
	if projectiles!=null and not projectiles.advance(milliseconds):reject(projectiles.error);return {}
	if impacts!=null and (not impacts.advance(milliseconds) or not impacts.apply_contacts(prior,[],result.actors)):reject(impacts.error);return {}
	var systems_projectiles: RefCounted=null if _systems_projectiles==null else _systems_projectiles.fork_for_frame()
	var systems_impacts: RefCounted=null if _systems_impacts==null else _systems_impacts.fork_for_frame()
	if systems_projectiles!=null and not systems_projectiles.advance(milliseconds):reject(systems_projectiles.error);return {}
	if systems_impacts!=null and (not systems_impacts.advance(milliseconds) or not systems_impacts.apply_contacts(systems_prior,[],result.systems_actors)):reject(systems_impacts.error);return {}
	_weapons=result.weapons;_weapon_events=result.actors;_projectiles=projectiles;_impacts=impacts;_weapon_elapsed_ms+=milliseconds
	_firing={"actors":[]}
	_systems_weapons=result.systems_weapons;_systems_events=result.systems_actors
	_systems_projectiles=systems_projectiles;_systems_impacts=systems_impacts;_systems_firing={"actors":[]}
	return {"encounter":result.get("encounter",encounter)}

func weapon_world() -> Dictionary:
	if _weapons==null:return {}
	var result:=_identity.duplicate()
	result.elapsed_ms=_weapon_elapsed_ms;result.weapons=_weapons.snapshot()
	if _projectiles!=null:result.projectile_visuals=_projectiles.snapshot()
	if _impacts!=null:result.impact_visuals=_impacts.snapshot()
	return result

func projectile_visual_owner() -> RefCounted:return null if _projectiles==null else _projectiles.fork_for_frame()
func impact_visual_owner() -> RefCounted:return null if _impacts==null else _impacts.fork_for_frame()
func primary_weapon_owner() -> RefCounted:return null if _weapons==null else _weapons.fork_for_frame()

func systems_weapon_world() -> Dictionary:
	if _systems_weapons==null:return {}
	var result:=_identity.duplicate()
	result.elapsed_ms=_weapon_elapsed_ms;result.weapons=_systems_weapons.snapshot()
	if _systems_projectiles!=null:result.projectile_visuals=_systems_projectiles.snapshot()
	if _systems_impacts!=null:result.impact_visuals=_systems_impacts.snapshot()
	return result

func systems_weapon_owner() -> RefCounted:return null if _systems_weapons==null else _systems_weapons.fork_for_frame()
func systems_projectile_visual_owner() -> RefCounted:return null if _systems_projectiles==null else _systems_projectiles.fork_for_frame()
func systems_impact_visual_owner() -> RefCounted:return null if _systems_impacts==null else _systems_impacts.fork_for_frame()

## Command zero switches guns without replacing the current follow/attack order.
## The flight-command UI must stage this capability; snapshots are observations.
func toggle_weapon_group(index: Variant) -> bool:
	error=""
	if not index is int or index<0 or index>=_actors.size() or _systems_weapons==null or not _systems_weapons.has_wingman_gun(index):return reject("Weapon switching requires an armed native companion")
	var groups:=_weapon_groups.duplicate()
	groups[index]=1 if groups[index]==0 else 0
	_weapon_groups=groups
	return true

static func hull_for_pilot(bindings: RefCounted,pilot_name: String,faction: int) -> int:
	if bindings==null or pilot_name.is_empty() or faction<0 or faction>=int(bindings.early_contracts.generation.identity.faction_bound):return -1
	var rules: Dictionary=bindings.early_contracts.encounter_construction.hulls
	var hull_faction:=faction if faction<=3 else 8
	var random:=Random.new()
	if not random.seed_from(pilot_name.length()*5):return -1
	return Factory._select_hull(random,hull_faction,rules)

static func spawn_pose(player: Transform3D,index: int) -> Transform3D:
	var sideways: float=[-1000.0,2000.0,0.0][index]
	var position:=player.origin+player.basis.x*sideways-player.basis.z*2000.0
	if index==2:position.y+=1000.0
	var forward:=player.basis.z.normalized()
	var right:=Vector3.UP.cross(forward)
	# Keep a finite frame at the world-up pole without inheriting player roll.
	if right.length_squared()<0.000001:right=player.basis.x
	right=right.normalized()
	return Transform3D(Basis(right,forward.cross(right).normalized(),forward),position)

func advance_detail(milliseconds: int,reference: Vector3) -> bool:
	return true if _detail==null or _detail.update(milliseconds,_detail_positions,reference,1.0,false) else reject(_detail.error)

static func follow_position(player: Transform3D,index: int) -> Vector3:
	var side:=Vectors.scaled(player.basis.y,2000.0) if index==2 else Vectors.scaled(player.basis.x,-4000.0 if index==0 else 4000.0)
	var behind:=Vectors.scaled(Vectors.normalized(player.basis.z),2000.0 if index==2 else 3000.0)
	return Vectors.added(Vectors.added(player.origin,side),-behind)

func advance_follow(milliseconds: Variant,player: Variant) -> bool:
	return _advance_motion(milliseconds,player,[])

## The flight supplies retained statistics in encounter order. A candidate owns
## both its selection history and movement; no failed frame leaks either one.
func advance_targeting(milliseconds: Variant,player_pose: Variant,player: Dictionary,opponents: Array,random_state: Dictionary) -> Dictionary:
	error=""
	if _identity.is_empty() or not Vitals.integer(milliseconds) or milliseconds<0 or milliseconds>2147483647 or not Flight.rigid_pose(player_pose):
		reject("Wingman targeting requires an accepted duration and player frame");return {}
	if not player.get("active") is bool or not Vitals.integer(player.get("vitals",{}).get("hull")):
		reject("Wingman targeting lost the player's native statistics");return {}
	var targets:=[{"actor_id":-1,"actor_kind":0,"pose":player_pose,"active":player.active,"hull":int(player.vitals.hull),"hostile":false}]
	for row in opponents:
		if not row is Dictionary or not row.get("actor_id") is int or not row.get("actor_kind") is int or not row.get("active") is bool or not row.get("hostile") is bool or not Vitals.integer(row.get("vitals",{}).get("hull")) or not Flight.rigid_pose(row.get("pose")):
			reject("Wingman targeting requires native encounter statistics");return {}
		if row.get("base_content_id")!=_identity.base_content_id or row.get("binding_id")!=_identity.binding_id:
			reject("Wingman target statistics belong to another content identity");return {}
		# Debris has a combat body for weapon hits, but is not a pilot opponent.
		targets.append({"actor_id":row.actor_id,"actor_kind":row.actor_kind,"pose":row.pose,
			"active":row.active and not row.get("contract_debris",false),"hull":int(row.vitals.hull),"hostile":row.hostile,
			"targeting_blocked":row.get("targeting_blocked",false) or row.get("statistics_targeting_blocked",false)})
	var random:=Random.new()
	if not random.restore(random_state):reject(random.error);return {}
	var selections:=[];var decisions:=[];var requests:=[];var systems_requests:=[];var poses:={}
	for index in _actors.size():
		var prior: Dictionary=_selections[index].duplicate(true)
		if prior.selection_elapsed_ms>Vitals.MAX_INTEGER-milliseconds:reject("Wingman target clock overflow");return {}
		prior.selection_elapsed_ms+=milliseconds
		var body: Dictionary=_actors[index].snapshot()
		var selected:=Targeting.select(prior,body,targets,random,_targeting_tuning,_targeting_rules)
		var destination:=follow_position(player_pose,index)
		selected.target_actor_id=-1
		if selected.target_index>0:
			var target: Dictionary=targets[selected.target_index]
			selected.target_actor_id=target.actor_id;destination=target.pose.origin
		var root: Transform3D=_flight[index].snapshot().root_pose
		var direction:=Vectors.added(destination,-root.origin)
		var close_extent:=float(_targeting_tuning.close_half_extent)
		if selected.target_selected and direction.abs().x<close_extent and direction.abs().y<close_extent and direction.abs().z<close_extent:direction=root.basis.z
		# Shared ordinary fighter window: strict local X/Y alignment, a source
		# per-axis range, and the retained pre-motion statistics pose.
		if selected.target_selected and selected.target_index>0:
			var target: Dictionary=targets[selected.target_index]
			var heading:=Vectors.normalized(direction)
			var aim:=Vector2(Vectors.dot(body.pose.basis.x,heading),-Vectors.dot(body.pose.basis.y,heading))
			var separation:=Vectors.added(target.pose.origin,-body.pose.origin).abs()
			var reach:=float(_targeting_tuning.fire_half_extent)
			var aligned: bool=absf(aim.x)<float(_targeting_tuning.fire_alignment) and absf(aim.y)<float(_targeting_tuning.fire_alignment)
			var fire: bool=selected.fire_desired and aligned and separation.x<reach and separation.y<reach and separation.z<reach
			if target.targeting_blocked or (fire and (not target.active or target.hull<=0)):
				fire=false;selected.fire_desired=false
			if fire:
				poses[index]=body.pose
				if _weapon_groups[index]==0:requests.append(index)
				elif _systems_weapons.has_wingman_gun(index):systems_requests.append(index)
		decisions.append({"destination":destination,"direction":direction,"steering":not selected.target_selected or not selected.straight})
		selections.append(selected)
	var weapons: RefCounted=_weapons.fork_for_frame()
	var firing: Dictionary=weapons.fire_wingmen(_actors,requests,poses)
	if firing.is_empty():reject(weapons.error);return {}
	var systems_weapons: RefCounted=_systems_weapons.fork_for_frame()
	var systems_firing: Dictionary=systems_weapons.fire_wingmen(_actors,systems_requests,poses)
	if systems_firing.is_empty():reject(systems_weapons.error);return {}
	if not _advance_motion(milliseconds,player_pose,decisions):return {}
	_selections=selections
	_weapons=weapons;_firing=firing
	_systems_weapons=systems_weapons;_systems_firing=systems_firing
	return {"random_state":random.snapshot()}

func _advance_motion(milliseconds: Variant,player: Variant,decisions: Array) -> bool:
	error=""
	if _identity.is_empty() or not Vitals.integer(milliseconds) or milliseconds<0 or milliseconds>2147483647 or not Flight.rigid_pose(player):return reject("Following requires an accepted duration and finite player frame")
	# Fork each writer into this candidate. An invalid later pilot must not
	# partially move an earlier one or alter a retained parent/sibling frame.
	var actors:=[];var flights:=[];var targets:=[];var positions:=_detail_positions.duplicate()
	for index in _actors.size():
		var actor: RefCounted=_actors[index].fork_for_frame()
		var motion: RefCounted=_flight[index].fork_for_frame()
		var body: Dictionary=actor.snapshot()
		if body.wingman_command!=1:return reject("This wingman owner only admits the retained follow command")
		var destination: Vector3=follow_position(player,index) if decisions.is_empty() else decisions[index].destination
		var root: Transform3D=motion.snapshot().root_pose
		var direction: Vector3=Vectors.added(destination,-root.origin) if decisions.is_empty() else decisions[index].direction
		var moving: bool=body.active and body.vitals.hull>0
		var steering: bool=moving and (decisions.is_empty() or decisions[index].steering)
		var moved: Dictionary=motion.advance(milliseconds,direction,_cruise_speed,steering,moving)
		if moved.is_empty():return reject(motion.error)
		if not actor.set_pose(moved.pose):return reject(actor.error)
		actors.append(actor);flights.append(motion);targets.append(destination)
		if positions.has(index):positions[index]=moved.root_pose.origin
	_actors=actors;_flight=flights;_follow_targets=targets;_detail_positions=positions
	return true

func snapshot() -> Dictionary:
	if _identity.is_empty():return {}
	var state:=_identity.duplicate()
	state.actors=_actors.map(func(actor):return actor.snapshot())
	state.detail={} if _detail==null else _detail.snapshot().selections
	for actor in state.actors:
		if not state.detail.has(actor.actor_id):state.detail[actor.actor_id]={"visible":true,"level":0}
	state.interactions_connected=false
	state.following_connected=true
	state.targeting_connected=true
	state.weapons_connected=false
	state.primary_weapons_connected=_weapons!=null
	state.systems_weapons_connected=_systems_weapons!=null
	state.weapon_command_input_connected=true
	state.systems_audio_connected=true
	state.weapon_groups=_weapon_groups.duplicate()
	state.systems_weapon_world=systems_weapon_world()
	state.systems_firing=_systems_firing.duplicate(true);state.systems_contacts=_systems_events.duplicate(true)
	state.weapon_world=weapon_world()
	state.primary_firing=_firing.duplicate(true)
	state.primary_contacts=_weapon_events.duplicate(true)
	state.targeting={"selections":_selections.duplicate(true)}
	state.following={"cruise_speed":_cruise_speed,"targets":_follow_targets.duplicate(),"motion":_flight.map(func(motion):return motion.snapshot())}
	return state

func body_owner(index: int) -> RefCounted:
	return null if index<0 or index>=_actors.size() else _actors[index].fork_for_frame()

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._identity=_identity;copy._actors=_actors;copy._detail_positions=_detail_positions
	copy._flight=_flight;copy._follow_targets=_follow_targets;copy._cruise_speed=_cruise_speed
	copy._selections=_selections;copy._targeting_tuning=_targeting_tuning;copy._targeting_rules=_targeting_rules
	copy._detail=null if _detail==null else _detail.fork_for_frame()
	copy._weapons=_weapons;copy._projectiles=_projectiles;copy._impacts=_impacts
	copy._weapon_elapsed_ms=_weapon_elapsed_ms;copy._weapon_events=_weapon_events;copy._firing=_firing
	copy._systems_weapons=_systems_weapons;copy._systems_projectiles=_systems_projectiles;copy._systems_impacts=_systems_impacts
	copy._systems_events=_systems_events;copy._systems_firing=_systems_firing;copy._weapon_groups=_weapon_groups
	# Shared bodies and flight state stay immutable until advance_follow stages
	# detached writers. Public observations/body owners are detached as well.
	return copy

func reject(message: String) -> bool:error=message;return false
