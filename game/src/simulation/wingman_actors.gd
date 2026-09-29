extends RefCounted
## Paid companions are a separate cast, not extra ambient patrol slots.
## Ordinary flight retains unboosted formation steering and detail selection.
## Targeting, boosts, hit/loss accounting and command changes remain separate.
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
var error:=""
var _identity:={}
var _actors:=[]
var _flight:=[]
var _follow_targets:=[]
var _cruise_speed:=0.0
var _detail: RefCounted
var _detail_positions:={}

func configure(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not construction is Construction:return reject("Wingmen require the retained native departure")
	var career: RefCounted=construction.contract_owner()
	var roster: Dictionary={} if career==null else career.snapshot().get("wingmen",{}).get("active",{})
	var entry: Dictionary=construction.snapshot()
	if roster.is_empty() or not (Ordinary.ordinary_entry(bindings,entry) or FreeFlight.ordinary_entry(bindings,entry)):
		_identity={};_actors=[];_flight=[];_follow_targets=[];_cruise_speed=0.0;_detail=null;_detail_positions={}
		return true
	if not Contracts.valid_active(roster,bindings) or not Flight.rigid_pose(entry.player_pose):return reject("The flight lost its paid roster or player pose")
	var speed: Variant=bindings.opening_actors.npc_initialization.get("guidance",{}).get("cruise_speed")
	if (not speed is float and not speed is int) or not is_finite(float(speed)) or speed<=0:return reject("Wingmen require the retained ordinary fighter cruise speed")
	var retained: Dictionary=career.snapshot()
	var actors:=[];var flights:=[];var targets:=[];var ships:={};var positions:={}
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
		if int(bindings.ship_lod.body_resource_ids[hull][0])!=65535:
			ships[index]=hull;positions[index]=pose.origin
	var detail: RefCounted
	if not ships.is_empty():
		detail=Detail.new()
		if not detail.configure(bindings,ships) or not detail.refresh(positions,entry.player_pose.origin,1.0):return reject(detail.error)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_actors=actors;_detail=detail;_detail_positions=positions
	_flight=flights;_follow_targets=targets;_cruise_speed=float(speed)
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
		var destination:=follow_position(player,index)
		var root: Transform3D=motion.snapshot().root_pose
		var direction:=Vectors.added(destination,-root.origin)
		var moving: bool=body.active and body.vitals.hull>0
		var moved: Dictionary=motion.advance(milliseconds,direction,_cruise_speed,moving,moving)
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
	state.following={"cruise_speed":_cruise_speed,"targets":_follow_targets.duplicate(),"motion":_flight.map(func(motion):return motion.snapshot())}
	return state

func body_owner(index: int) -> RefCounted:
	return null if index<0 or index>=_actors.size() else _actors[index].fork_for_frame()

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._identity=_identity;copy._actors=_actors;copy._detail_positions=_detail_positions
	copy._flight=_flight;copy._follow_targets=_follow_targets;copy._cruise_speed=_cruise_speed
	copy._detail=null if _detail==null else _detail.fork_for_frame()
	# Shared bodies and flight state stay immutable until advance_follow stages
	# detached writers. Public observations/body owners are detached as well.
	return copy

func reject(message: String) -> bool:error=message;return false
