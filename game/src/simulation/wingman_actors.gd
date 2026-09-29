extends RefCounted
## Paid companions are a separate cast, not extra ambient patrol slots.
## This owner admits ordinary-flight construction and detail selection only.
## Following, targeting, hit/loss accounting and commands are not connected yet.
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Contracts=preload("res://src/simulation/wingman_contract.gd")
const Ordinary=preload("res://src/content/contract_world_definitions.gd")
const FreeFlight=preload("res://src/content/free_flight_definitions.gd")
const Body=preload("res://src/simulation/opening_combat_actor.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Detail=preload("res://src/presentation/ship_detail_group.gd")
var error:=""
var _identity:={}
var _actors:=[]
var _detail: RefCounted
var _detail_positions:={}

func configure(bindings: RefCounted,catalogues: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not construction is Construction:return reject("Wingmen require the retained native departure")
	var career: RefCounted=construction.contract_owner()
	var roster: Dictionary={} if career==null else career.snapshot().get("wingmen",{}).get("active",{})
	var entry: Dictionary=construction.snapshot()
	if roster.is_empty() or not (Ordinary.ordinary_entry(bindings,entry) or FreeFlight.ordinary_entry(bindings,entry)):
		_identity={};_actors=[];_detail=null;_detail_positions={}
		return true
	if not Contracts.valid_active(roster,bindings) or not Flight.rigid_pose(entry.player_pose):return reject("The flight lost its paid roster or player pose")
	var retained: Dictionary=career.snapshot()
	var actors:=[];var ships:={};var positions:={}
	for index in roster.names.size():
		var hull:=hull_for_pilot(bindings,roster.names[index],int(roster.faction))
		if hull<0:return reject("The hired pilot has no eligible original fighter")
		var pose:=spawn_pose(entry.player_pose,index)
		var initial:={"actor_id":index,"actor_kind":int(roster.faction),"hull_catalogue_id":hull,
			"name":roster.names[index],"position":pose.origin,"pose":pose}
		var actor:=Body.new()
		if not actor._configure_wingman(bindings,catalogues,initial,int(retained.rank),int(entry.campaign_cursor),float(retained.difficulty)):return reject(actor.error)
		actors.append(actor)
		if int(bindings.ship_lod.body_resource_ids[hull][0])!=65535:
			ships[index]=hull;positions[index]=pose.origin
	var detail: RefCounted
	if not ships.is_empty():
		detail=Detail.new()
		if not detail.configure(bindings,ships) or not detail.refresh(positions,entry.player_pose.origin,1.0):return reject(detail.error)
	_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_actors=actors;_detail=detail;_detail_positions=positions
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

func snapshot() -> Dictionary:
	if _identity.is_empty():return {}
	var state:=_identity.duplicate()
	state.actors=_actors.map(func(actor):return actor.snapshot())
	state.detail={} if _detail==null else _detail.snapshot().selections
	for actor in state.actors:
		if not state.detail.has(actor.actor_id):state.detail[actor.actor_id]={"visible":true,"level":0}
	state.interactions_connected=false
	return state

func body_owner(index: int) -> RefCounted:
	return null if index<0 or index>=_actors.size() else _actors[index].fork_for_frame()

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._identity=_identity;copy._actors=_actors;copy._detail_positions=_detail_positions
	copy._detail=null if _detail==null else _detail.fork_for_frame()
	# Constructed bodies stay immutable here. Public observations and body owners
	# are detached; future motion/hit consumers must detach before writing.
	return copy

func reject(message: String) -> bool:error=message;return false
