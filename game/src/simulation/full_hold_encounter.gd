extends RefCounted
const Frames=preload("res://src/simulation/frame_clock.gd")
var _max_ms:=0
## Retained combat for supported early flights. The enclosing flight stages
## weapon contacts, late player input and the later NPC pass, then commits them
## together with player, camera and scenery. No mission rewards live here.
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const NpcControl=preload("res://src/simulation/opening_npc_control.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const Resources=preload("res://src/content/npc_destruction_resources.gd")
const FreightResources=preload("res://src/content/freighter_destruction_resources.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Appearance=preload("res://src/content/full_hold_appearance_definitions.gd")
const Projectiles=preload("res://src/simulation/projectile_visual_state.gd")
const Impacts=preload("res://src/simulation/ordinary_impact_state.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const TrainingControl=preload("res://src/simulation/combat_training_control.gd")
const Primaries=preload("res://src/simulation/primary_weapons.gd")
const Secondaries=preload("res://src/simulation/secondary_weapons.gd")
const DetonationResources=preload("res://src/content/emp_detonation_resources.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Inventory=preload("res://src/simulation/opening_target_inventory.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Convoy=preload("res://src/content/convoy_world_definitions.gd")
const ContractWorld=preload("res://src/content/contract_world_definitions.gd")
const KappaRescue=preload("res://src/simulation/kappa_rescue.gd")
const Route=preload("res://src/simulation/npc_route.gd")
const Recovery=preload("res://src/simulation/tractor_recovery.gd")
const Cargo=preload("res://src/simulation/flight_cargo.gd")
const NpcDeath=preload("res://src/simulation/npc_destruction.gd")
const FreightDeath=preload("res://src/simulation/freighter_destruction.gd")
const Story=preload("res://src/content/story_encounter_definitions.gd")
const Bakka=preload("res://src/content/bakka_contest_definitions.gd")
const DebrisDeath=preload("res://src/simulation/debris_destruction.gd")
var error:=""
var _identity:={}
var _control: RefCounted
var _combat: RefCounted
var _weapons: RefCounted
var _projectiles: RefCounted
var _impacts: RefCounted
var _freighter_resources: RefCounted
var _freighter_assemblies:={}
var _resources: RefCounted
var _elapsed_ms:=0
var _world_elapsed_ms:=0
var _weapon_events:=[]
var _actor_events:=[]
var _primaries: RefCounted
var _inventory: RefCounted
var _scenery_identity: RefCounted
var _primary_contacts:=[]
var _primary_fire:={}
var _contract_context:={}
var _secondaries: RefCounted
var _selected_secondary:=-1
var _secondary_events:=[]
var _difficulty:=0.5
var _selected40_world: RefCounted
var _selected40_context:={}
var _selected40_sequence: RefCounted
var _selected40_view: RefCounted
var _selected40_pending_world:=false

## Explicit capability: the old standalone contact component stays unchanged.
func prepare_selected40_sequence(bindings: RefCounted,library: RefCounted) -> bool:
	error=""
	if _selected40_world==null or _selected40_sequence!=null or _world_elapsed_ms!=0 or _elapsed_ms!=0:return reject("Prepare selected40 sequence once before encounter time starts")
	var owner: RefCounted=load("res://src/simulation/selected40_sequence.gd").new()
	if not owner.configure(bindings,library,_selected40_world):return reject(owner.error)
	_selected40_sequence=owner
	return true

## Optional renderer composition. Standalone contacts/sequence remain usable;
## once attached, every sequence frame must advance this retained native view.
func prepare_selected40_view(bindings: RefCounted,camera: RefCounted,aim: RefCounted,player: RefCounted) -> bool:
	error=""
	if _selected40_sequence==null or _selected40_view!=null or _selected40_sequence.snapshot().revision!=0:return reject("Prepare selected40 view before the first sequence frame")
	var owner: RefCounted=load("res://src/simulation/selected40_view.gd").new()
	if not owner.configure(bindings,_selected40_world,camera,aim,player):return reject(owner.error)
	_selected40_view=owner
	return true

func prepare_selected40_application_entry(release_ms: int) -> bool:
	error=""
	if _selected40_sequence==null or _selected40_view==null or _selected40_pending_world or _elapsed_ms!=0:return reject("Application entry requires fresh selected camera and sequence owners")
	var sequence: RefCounted=_selected40_sequence.fork_for_frame();var view: RefCounted=_selected40_view.fork_for_frame()
	if not sequence.prepare_application_entry(release_ms) or not view.prepare_application_entry():return reject(sequence.error+view.error)
	_selected40_sequence=sequence;_selected40_view=view
	return true

## Player response is prepared before motion, not after this frame's camera.
func refresh_selected40_player_response(relative_capture: bool,handling: float) -> bool:
	error=""
	if _selected40_view==null or _selected40_pending_world:return reject("Player camera response requires a completed selected40 frame")
	var view: RefCounted=_selected40_view.fork_for_frame()
	if not view.refresh_player_response(relative_capture,handling):return reject(view.error)
	_selected40_view=view
	return true

func selected40_camera_input(mode: Variant=null,pointer_kind: String="",position: Variant=Vector2i.ZERO) -> RefCounted:
	error=""
	if _selected40_view==null or _selected40_pending_world:return _camera_input_failure("Camera input requires a completed selected40 native frame")
	var view: RefCounted=_selected40_view.fork_for_frame()
	if mode!=null:
		if not pointer_kind.is_empty() or not view.select_camera(mode):return _camera_input_failure(view.error if not view.error.is_empty() else "Conflicting camera input")
	elif not view.orbit_pointer(pointer_kind,position):return _camera_input_failure(view.error)
	var next:=fork_for_frame();next._selected40_view=view
	return next

func _camera_input_failure(message: String) -> RefCounted:
	reject(message)
	return null

func evaluate_selected40_sequence(milliseconds: Variant,random_state: Dictionary,player: RefCounted=null,pose:=Transform3D.IDENTITY,viewport:=Vector2i.ZERO,destruction: RefCounted=null,player_updated:=true,aim_pose: Variant=null) -> Dictionary:
	error=""
	if _selected40_sequence==null or _selected40_pending_world or _selected40_sequence.snapshot().elapsed_ms!=_world_elapsed_ms:return fail("Selected40 sequence must precede exactly one native actor frame")
	var owner: RefCounted=_selected40_sequence.fork_for_frame()
	if not owner.advance(milliseconds,_combat,random_state,destruction):return fail(owner.error)
	var operation: Dictionary=_control.evaluate_selected40_sequence(owner,_combat,random_state)
	if operation.is_empty():return fail(_control.error)
	var next:=fork_for_frame()
	next._selected40_sequence=owner;next._control=operation.controller;next._combat=operation.combat
	var view_random: Dictionary=operation.random_state
	if _selected40_view!=null:
		if target(player,pose).is_empty():return fail("Selected40 view requires its current retained player pose")
		var view: RefCounted=_selected40_view.fork_for_frame()
		var look_jitter:=Vector3.ZERO
		if _secondaries!=null and milliseconds>0 and destruction==null:
			var sampled: Dictionary=_secondaries.evaluate_camera(view_random)
			if sampled.is_empty():return fail(_secondaries.error)
			look_jitter=sampled.offset;view_random=sampled.random_state
		if not view.advance(owner,operation.combat,player,pose,milliseconds,viewport,primary_npc_contact(),look_jitter,destruction,player_updated,aim_pose):return fail(view.error)
		next._selected40_view=view
	next._selected40_pending_world=true
	return {"encounter":next,"random_state":view_random,"sequence":owner.snapshot()}

## Join the generated selected source with retained origin equipment. This
## component owns contacts and their effects, not travel or mission results.
func configure_selected40(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	error=""
	if _control!=null or not player is Player or not scenery is Scenery:return reject("Selected40 contacts require fresh native encounter owners")
	var rules=load("res://src/content/selected40_population_definitions.gd")
	var data: Dictionary=rules.consequence_profile(bindings,catalogues,scenery,equipment)
	if data.is_empty():return reject("Selected40 contacts require their complete source field and retained equipment")
	var world: RefCounted=scenery.world_initialization_owner();var construction: RefCounted=world.npc_construction_owner()
	var initial: Dictionary=world.snapshot();var seed: Dictionary=equipment.snapshot().loadout.duplicate(true)
	seed.campaign_cursor=40
	if scenery.random_state()!=initial.random_state or player.selected40_construction_owner()!=construction or player.snapshot().get("selected40_context")!=data.context or player.loadout()!=seed:return reject("Selected40 contacts differ from their fresh generated world or retained player")
	var control:=TrainingControl.new();var weapons:=Weapons.new();var mounts:=Mounts.new();var primaries:=Primaries.new();var inventory:=Inventory.new()
	if not control.configure_selected40(bindings,catalogues,world) or not control.prepare_selected40_consequences(library,bindings,catalogues,scenery,equipment,reputation):return reject(control.error)
	var combat: RefCounted=control.combat_owner()
	if not weapons.configure_selected40(bindings,catalogues,world,combat) or not mounts.open(library,catalogues):return reject(weapons.error+mounts.error)
	if not primaries.configure_selected40(bindings,catalogues,mounts,player,construction) or not inventory.configure_selected40(bindings,catalogues,player,scenery,equipment,combat):return reject(primaries.error+inventory.error)
	var freight:=FreightResources.new()
	if not freight._configure_story(library,bindings,data):return reject(freight.error)
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":40}
	if not _accept_configuration(bindings,library,identity,control,combat,weapons,control.destruction_resources(),primaries,inventory,scenery.presentation_identity()):return false
	_selected40_world=world;_selected40_context=data.context.duplicate(true)
	_difficulty=float(data.difficulty)
	_freighter_resources=freight;_freighter_assemblies={0:initial.npc_construction.actors[0].assembly.duplicate(true)}
	return true

func configure(bindings: RefCounted, catalogues: RefCounted, library: RefCounted, construction: RefCounted, difficulty: float) -> bool:
	error=""
	if bindings==null or not construction is Construction or not Appearance.parameters(bindings.full_hold_appearance):return reject("The second mining encounter requires verified construction and appearance")
	var control:=NpcControl.new();var combat:=Combat.new();var weapons:=Weapons.new();var resources:=Resources.new()
	if not resources.configure_full_hold(library,bindings):return reject(resources.error)
	if not control.configure_full_hold(bindings,catalogues,construction,difficulty) or not control.set_full_hold_destruction(resources):return reject(control.error)
	if not combat.configure_full_hold(bindings,catalogues,construction,difficulty):return reject(combat.error)
	if not weapons.configure_full_hold(bindings,catalogues,construction):return reject(weapons.error)
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":4}
	return _accept_configuration(bindings,library,identity,control,combat,weapons,resources)

func configure_combat_training(bindings: RefCounted, catalogues: RefCounted, library: RefCounted, player: RefCounted, scenery: RefCounted, rank: Variant, difficulty: Variant) -> bool:
	return _configure_equipped(bindings,catalogues,library,player,scenery,rank,difficulty,7)

func configure_ambient_traffic(bindings: RefCounted, catalogues: RefCounted, library: RefCounted, player: RefCounted, scenery: RefCounted, rank: Variant, difficulty: Variant, equipment: RefCounted, reputation: Dictionary) -> bool:
	error=""
	if bindings==null or not player is Player or equipment==null or Travel.journey(bindings.mido_travel,11).is_empty():return reject("Mixed flight requires its equipped player and visit declarations")
	var seed: Dictionary=equipment.snapshot().get("loadout",{}).duplicate(true)
	seed.campaign_cursor=11
	if player.loadout()!=seed:return reject("Mixed flight player and retained equipment disagree")
	return _configure_equipped(bindings,catalogues,library,player,scenery,rank,difficulty,11,equipment,reputation)

func configure_local_traffic(bindings: RefCounted, catalogues: RefCounted, library: RefCounted, construction: RefCounted, difficulty: Variant) -> bool:
	error=""
	if not construction is Construction:return reject("Local combat requires its prepared departure")
	var entry: Dictionary=construction.snapshot()
	var cursor: Variant=entry.get("campaign_cursor")
	if not cursor is int or cursor not in [10,11,12] or Travel.flight(bindings,int(entry.get("location",{}).get("station_id",-1)),cursor).is_empty():return reject("Local combat requires a supported Mido flight")
	var progress: Dictionary=entry.get("departure",{}).get("progress",{})
	return _configure_equipped(bindings,catalogues,library,construction.player_owner(),construction.scenery_owner(),progress.get("rank"),difficulty,cursor,construction.equipment_owner(),progress.get("reputation",{}))

func configure_contract_world(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not construction is Construction or not ContractWorld.available(bindings) or construction.contract_owner()==null:return reject("Ordinary contract combat requires its prepared native world")
	var state: Dictionary=construction.contract_owner().snapshot()
	if not _configure_equipped(bindings,catalogues,library,construction.player_owner(),construction.scenery_owner(),state.rank,state.difficulty,state.campaign_cursor,construction.equipment_owner(),state.reputation):return false
	_contract_context=construction.scenery_owner().world_initialization_owner().snapshot().contract_context.duplicate(true)
	if load("res://src/content/free_flight_definitions.gd").ordinary_entry(bindings,construction.snapshot()):_contract_context=construction.contract_owner().free_flight_context(bindings,int(state.station_id))
	return true

func configure_convoy(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not construction is Construction or construction.snapshot().get("campaign_cursor")!=14 or construction.contract_owner()==null:return reject("Convoy combat requires its prepared earned departure")
	var state: Dictionary=construction.contract_owner().snapshot()
	return _configure_equipped(bindings,catalogues,library,construction.player_owner(),construction.scenery_owner(),state.rank,state.difficulty,14,construction.equipment_owner(),state.reputation)

func configure_alioth(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not construction is Construction or construction.snapshot().get("campaign_cursor")!=16 or construction.contract_owner()==null:return reject("Alioth combat requires its earned prepared departure")
	var state: Dictionary=construction.contract_owner().snapshot()
	return _configure_equipped(bindings,catalogues,library,construction.player_owner(),construction.scenery_owner(),state.rank,state.difficulty,16,construction.equipment_owner(),state.reputation)

func configure_free(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not construction is Construction or not load("res://src/content/free_flight_definitions.gd").ordinary_entry(bindings,construction.snapshot()) or construction.contract_owner()==null:return reject("Ordinary combat requires its earned prepared departure")
	var state: Dictionary=construction.contract_owner().snapshot()
	var career: RefCounted=construction.contract_owner()
	var context: Dictionary=career.free_flight_context(bindings,int(state.station_id))
	if context.is_empty():return reject(career.error)
	if not _configure_equipped(bindings,catalogues,library,construction.player_owner(),construction.scenery_owner(),state.rank,state.difficulty,state.campaign_cursor,construction.equipment_owner(),state.reputation):return false
	_contract_context=context
	return true

## Prepare once from actual generated scenery and the corresponding equipped
## player. This does not select a mission or authorize a campaign departure.
func configure_bakka(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,construction: RefCounted) -> bool:
	error=""
	if not construction is Construction:return reject("B'akka encounter requires its selected native construction")
	var entry: Dictionary=construction.snapshot();var context: Dictionary=entry.get("bakka_context",{})
	if entry.get("campaign_cursor")!=36 or not Bakka.context_valid(bindings,context):return reject("B'akka encounter requires its selected story context")
	var equipment: RefCounted=construction.equipment_owner()
	if equipment==null:return reject("B'akka encounter requires its retained equipped inventory")
	return _configure_equipped(bindings,catalogues,library,construction.player_owner(),construction.scenery_owner(),context.rank,context.difficulty,36,equipment,entry.departure.progress.reputation)

func configure_kappa_rescue(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	error=""
	if _control!=null or not player is Player or not scenery is Scenery or not is_instance_of(equipment,load("res://src/simulation/station_equipment.gd")):return reject("Kappa encounter requires fresh native equipped owners")
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null:return reject("Kappa encounter requires its generated world")
	var packet: Dictionary=world.snapshot().get("npc_construction",{})
	var data: Dictionary=load("res://src/content/kappa_population_definitions.gd").lifecycle(bindings,packet)
	if data.is_empty() or player.snapshot().get("kappa_context")!=packet.kappa_context:return reject("Kappa encounter differs from its initialized player")
	var owned: Dictionary=equipment.snapshot();var seed: Dictionary=owned.get("loadout",{}).duplicate(true)
	seed.campaign_cursor=int(data.campaign_cursor)
	if not equipment.cargo_cache_valid() or player.loadout()!=seed:return reject("Kappa encounter differs from retained equipment")
	return _configure_equipped(bindings,catalogues,library,player,scenery,data.rank,data.difficulty,data.campaign_cursor,equipment,reputation)

## Join the complete source-selected convoy with its actual player and scenery.
## The shared contact and NPC phases below remain the sole combat implementation.
func configure_dekato(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	if scenery==null or equipment==null:return reject("Mission entry requires native scenery and equipment")
	var context: RefCounted=load("res://src/simulation/mission_context.gd").new()
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null or not context.admit(bindings,catalogues,world.snapshot().get("dekato_context",{}),equipment.snapshot().loadout):return reject(context.error)
	return configure_mission(bindings,catalogues,library,player,scenery,equipment,reputation,context)

func mission_context_owner() -> RefCounted:
	return load("res://src/simulation/mission_context.gd").from_owner(_control)

func configure_mission(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,mission_context: RefCounted) -> bool:
	error=""
	if _control!=null or not player is Player or not scenery is Scenery or not is_instance_of(equipment,load("res://src/simulation/station_equipment.gd")):return reject("Dekato encounter requires fresh native equipped owners")
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null:return reject("Dekato encounter requires its generated world")
	if not is_instance_of(mission_context,load("res://src/simulation/mission_context.gd")):return reject("Mission encounter requires its native capability")
	var data:=Story.compose_normal_return(bindings,catalogues,world.npc_construction_owner(),mission_context) if mission_context.has_feature("normal_space") else Story.compose_dekato(bindings,catalogues,world.npc_construction_owner())
	if data.is_empty():return reject("Dekato encounter has no supported selected population")
	if not is_instance_of(mission_context,load("res://src/simulation/mission_context.gd")) or not mission_context.matches_loadout(equipment.snapshot().loadout):return reject("Encounter requires its admitted mission equipment")
	data.mission_context=mission_context
	if player.snapshot().get(data.context_key)!=data.context:return reject("Dekato encounter differs from its initialized player")
	var seed: Dictionary=equipment.snapshot().get("loadout",{}).duplicate(true)
	seed.campaign_cursor=int(data.campaign_cursor)
	if not equipment.cargo_cache_valid() or player.loadout()!=seed:return reject("Dekato encounter differs from retained equipment")
	return _configure_equipped(bindings,catalogues,library,player,scenery,data.rank,data.difficulty,data.campaign_cursor,equipment,reputation,data)

func configure_story(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary) -> bool:
	error=""
	if _control!=null or not player is Player or not scenery is Scenery or not is_instance_of(equipment,load("res://src/simulation/station_equipment.gd")):return reject("Story encounter requires fresh native equipped owners")
	var world: RefCounted=scenery.world_initialization_owner()
	if world==null:return reject("Story encounter requires its generated world")
	var data:=Story.compose(bindings,catalogues,world.snapshot().get("npc_construction",{}))
	if data.is_empty():return reject("Story encounter has no supported population")
	if player.snapshot().get(data.context_key)!=data.context:return reject("Story encounter differs from its initialized player")
	var seed: Dictionary=equipment.snapshot().get("loadout",{}).duplicate(true)
	seed.campaign_cursor=int(data.campaign_cursor)
	if not equipment.cargo_cache_valid() or player.loadout()!=seed:return reject("Story encounter differs from retained equipment")
	return _configure_equipped(bindings,catalogues,library,player,scenery,data.rank,data.difficulty,data.campaign_cursor,equipment,reputation,data)

## The source-selected Void is an ordinary nonstory flight. Its retained
## source owner gives faction context while the generated world remains -1/-1.
func configure_ordinary_void(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,ordinary_void_source: RefCounted,difficulty: Variant) -> bool:
	error=""
	if _control!=null or not player is Player or not scenery is Scenery:return reject("Void combat requires fresh native player and scenery owners")
	var world: RefCounted=scenery.world_initialization_owner()
	var data: Dictionary=Story.compose_void(bindings,catalogues,world,equipment,ordinary_void_source,difficulty)
	if data.is_empty():return reject("Void combat requires its retained source and generated fighters")
	var loadout: Dictionary=equipment.snapshot().loadout
	if loadout.station_id!=-1 or loadout.system_id!=-1:return reject("Void combat requires equipment relocated by the source portal")
	var initial: Dictionary=world.snapshot()
	if player.snapshot().get("void_context")!=initial.void_context:return reject("Void combat differs from the player's selected flight")
	var seed: Dictionary=loadout.duplicate(true);seed.campaign_cursor=33
	if player.loadout()!=seed:return reject("Void combat differs from its earned equipment")
	return _configure_equipped(bindings,catalogues,library,player,scenery,data.rank,data.difficulty,33,equipment,reputation,data)

func apply_sahi_view(stage: RefCounted) -> bool:
	if not is_instance_of(stage,load("res://src/simulation/sahi_encounter_stage.gd")):return reject("Sahi target changes require their native stage")
	var state: Dictionary=stage.snapshot()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if state.get(key)!=_identity.get(key):return reject("Sahi stage belongs to another encounter")
	if not state.frame.cues.any(func(cue):return cue.kind=="clear_npc_weapon_targets"):return reject("Sahi has no new target-clear cue")
	_control=_control.fork_for_frame(false,_combat.fork_for_frame());_control._clear_story_targets()
	_combat=_control.combat_owner()
	_weapons=_weapons.fork_for_frame();_weapons._clear_story_targets()
	if _primaries!=null:_primaries=_primaries.fork_state();_primaries.discard_flying()
	if _secondaries!=null:_secondaries=_secondaries.fork();_secondaries.discard_flying()
	return true

func apply_alioth_sequence(attack: RefCounted,random_state: Dictionary) -> bool:
	error=""
	if _identity.get("campaign_cursor")!=16:return reject("This encounter has no Alioth choreography")
	var control: RefCounted=_control.fork_for_frame();control._combat=_combat.fork_for_frame()
	var candidate: Dictionary=control.evaluate_alioth_sequence(attack,_weapons,random_state)
	if candidate.is_empty():return reject(control.error)
	_control=candidate.controller;_combat=_control.combat_owner();_weapons=candidate.weapons
	return true

func apply_convoy_capture(capture: RefCounted) -> bool:
	error=""
	if _identity.get("campaign_cursor")!=14:return reject("This encounter has no convoy choreography")
	var control: RefCounted=_control.fork_for_frame()
	if not control.apply_convoy_capture(capture,_combat):return reject(control.error)
	_control=control;_combat=control.combat_owner()
	return true

func kappa_radio_context(route: RefCounted) -> Dictionary:
	error=""
	if _identity.get("campaign_cursor")!=21 or _combat==null or _inventory==null or not route is Route:return fail("Kappa radio requires its retained encounter and player route")
	var path: Dictionary=route.snapshot()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if path.get(key)!=_identity[key]:return fail("Kappa radio route belongs to another encounter")
	if path.get("owner")!="player":return fail("Kappa radio cannot observe an NPC patrol route")
	var context: Dictionary=_combat.kappa_actor_context()
	if context.is_empty() or _inventory.npc_ids()!=context.actors.map(func(actor):return actor.get("actor_id")):return fail("Kappa radio lost the player's original NPC target order")
	# The original target list starts with these NPCs. All predicates discard
	# its scenery suffix; project only the relevant prefix without sorting it.
	context.player_targets=context.actors
	context.erase("actors")
	context.route_index=int(path.index)
	return context

## Completion/failure is polled before choreography. A prospective observation
## can open the result without applying cues from the later controller phase.
func observe_kappa_rescue(rescue: RefCounted,radio: RefCounted) -> RefCounted:
	error=""
	if _identity.get("campaign_cursor")!=21 or _control==null or _combat==null or not rescue is KappaRescue:
		reject("Kappa observations require its native rescue and encounter");return null
	var observation: RefCounted=rescue.fork()
	if not observation.bind_flight(_control) or not observation.advance(radio,_combat.kappa_actor_context()):reject(observation.error);return null
	return observation

func evaluate_kappa_sequence(rescue: RefCounted,radio: RefCounted) -> Dictionary:
	var observation:=observe_kappa_rescue(rescue,radio)
	if observation==null:return {}
	var next:=fork_for_frame()
	if not observation.snapshot().force_hostile_actor_ids.is_empty():
		var control: RefCounted=_control.evaluate_kappa_sequence(observation,_combat)
		if control==null:return fail(_control.error)
		next._control=control;next._combat=control.combat_owner()
	return {"encounter":next,"rescue":observation}

func _configure_equipped(bindings: RefCounted, catalogues: RefCounted, library: RefCounted, player: RefCounted, scenery: RefCounted, rank: Variant, difficulty: Variant, cursor: int, equipment: RefCounted=null, reputation: Dictionary={},story: Dictionary={}) -> bool:
	error=""
	if bindings==null or not player is Player or not scenery is Scenery:return reject("Equipped combat requires its player and constructed scenery")
	var world: RefCounted=scenery.world_initialization_owner()
	var initial: Dictionary={} if world==null else world.snapshot()
	if initial.is_empty() or scenery.snapshot().random_state!=initial.random_state:return reject("Equipped combat must join its fresh constructed world")
	var control:=TrainingControl.new();var weapons:=Weapons.new();var resources:=Resources.new()
	var freight_resources: RefCounted
	var contract_world: bool=initial.has("contract_context")
	var contract_mission: Dictionary=initial.get("contract_context",{}).get("mission",{})
	var population_owner: RefCounted=world.npc_construction_owner()
	var capability: RefCounted=null if population_owner==null else population_owner.mission_context_owner()
	var ambient: bool=(load("res://src/content/free_campaign_definitions.gd").supported(bindings,cursor) and not contract_world) or (contract_world and contract_mission.is_empty()) or (cursor in [11,12] and initial.station_id==int(Travel.journey(bindings.mido_travel,cursor).from_station_id))
	var rescue: bool=cursor==21 and initial.get("npc_construction",{}).has("kappa_context")
	var bakka: bool=cursor==36 and initial.get("bakka_context") is Dictionary and Bakka.context_valid(bindings,initial.bakka_context)
	if not story.is_empty():
		var population: RefCounted=world.npc_construction_owner()
		if not story.get("ordinary_void",false) and not story.get("actors",[]).is_empty():freight_resources=FreightResources.new()
		if not resources._configure_story(library,bindings,population,story):return reject(resources.error)
		if freight_resources!=null and not freight_resources._configure_story(library,bindings,story):return reject(freight_resources.error)
		if not control._configure_story(bindings,catalogues,population,equipment,reputation,story) or not weapons._configure_encounter_weapons(bindings,catalogues,story):return reject(control.error+weapons.error)
	elif bakka:
		var population: RefCounted=world.npc_construction_owner()
		if population==null:return reject("B'akka encounter lost its generated population")
		if not resources.configure_bakka(library,bindings,population):return reject(resources.error)
		if not control.configure_bakka(bindings,catalogues,population,equipment,reputation) or not weapons.configure_bakka(bindings,catalogues,population):return reject(control.error+weapons.error)
	elif rescue:
		var population: RefCounted=world.npc_construction_owner()
		if not resources.configure_kappa_rescue(library,bindings,population):return reject(resources.error)
		if not control.configure_kappa_rescue(bindings,catalogues,population,reputation) or not weapons.configure_kappa_rescue(bindings,catalogues,population):return reject(control.error+weapons.error)
	elif cursor==16:
		var population: RefCounted=world.npc_construction_owner()
		freight_resources=FreightResources.new()
		if not resources.configure_alioth_attack(library,bindings,population) or not freight_resources.configure_alioth_attack(library,bindings):return reject(resources.error+freight_resources.error)
		if not control.configure_alioth_attack(bindings,catalogues,population,equipment,reputation) or not weapons.configure_alioth_attack(bindings,catalogues,population):return reject(control.error+weapons.error)
	elif cursor==14 and initial.get("npc_construction",{}).has("convoy_context"):
		var population: RefCounted=world.npc_construction_owner()
		freight_resources=FreightResources.new()
		if not resources.configure_convoy(library,bindings,population) or not freight_resources.configure_convoy(library,bindings):return reject(resources.error+freight_resources.error)
		if not control.configure_convoy(bindings,catalogues,population,equipment,reputation) or not weapons.configure_convoy(bindings,catalogues,population):return reject(control.error+weapons.error)
	elif ambient:
		var population: RefCounted=world.npc_construction_owner()
		if population==null:return reject("The mixed encounter requires its retained generated actors")
		freight_resources=FreightResources.new()
		var ready: bool=resources.configure_free(library,bindings,population) and freight_resources.configure_free(library,bindings,population) if load("res://src/content/free_campaign_definitions.gd").supported(bindings,cursor) else resources.configure_ambient(library,bindings,cursor) and freight_resources.configure(library,bindings,cursor)
		if not ready:return reject(resources.error+freight_resources.error)
		if not control.configure_ambient(bindings,catalogues,population,rank,difficulty,equipment,reputation):return reject(control.error)
		if not weapons.configure_ambient(bindings,catalogues,population,rank,difficulty):return reject(weapons.error)
	elif contract_world and capability!=null and capability.has_contract_actors():
		var population: RefCounted=world.npc_construction_owner()
		if not resources.configure_contract(library,bindings,population):return reject(resources.error)
		if population.snapshot().actors.any(func(row):return row.get("subtype",0)==1):
			freight_resources=FreightResources.new()
			if not freight_resources.configure_contract(library,bindings,population):return reject(freight_resources.error)
		if not control.configure_contract(bindings,catalogues,population,equipment):return reject(control.error)
		if not weapons.configure_contract(bindings,catalogues,population):return reject(weapons.error)
	elif cursor in [10,11,12] or (contract_world and contract_mission.get("kind")==0):
		if not resources.configure_local_traffic(library,bindings):return reject(resources.error)
		if not control.configure_local_traffic(bindings,catalogues,world,rank,difficulty,equipment,reputation):return reject(control.error)
		if not weapons.configure_local_traffic(bindings,catalogues,world,rank,difficulty):return reject(weapons.error)
	else:
		if not resources.configure_combat_training(library,bindings):return reject(resources.error)
		if not control.configure(bindings,catalogues,world,rank,difficulty):return reject(control.error)
		if not weapons.configure_combat_training(bindings,catalogues,world,rank,difficulty):return reject(weapons.error)
	if not control.set_destruction(bindings,resources,freight_resources):return reject(control.error)
	var mounts:=Mounts.new();var primaries:=Primaries.new();var inventory:=Inventory.new()
	if not mounts.open(library,catalogues):return reject(mounts.error)
	if not primaries.configure_player(bindings,catalogues,mounts,player,story.get("mission_context")):return reject(primaries.error)
	var targets:=inventory.configure_ordinary_void(bindings,catalogues,player,scenery,story) if story.get("ordinary_void",false) else inventory._configure_story(bindings,catalogues,player,scenery,story) if not story.is_empty() else inventory.configure_kappa_rescue(bindings,catalogues,player,scenery) if rescue else (inventory.configure_local_travel(bindings,catalogues,player,scenery,cursor) if cursor!=7 else inventory.configure_combat_training(bindings,catalogues,player,scenery))
	if not targets:return reject(inventory.error)
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":cursor}
	if not _accept_configuration(bindings,library,identity,control,control.combat_owner(),weapons,resources,primaries,inventory,scenery.presentation_identity()):return false
	_difficulty=float(difficulty)
	if player.loadout().slots.any(func(slot):return slot!=null and slot.category==1):
		if not configure_secondaries(bindings,catalogues,player,equipment,library):return false
	_freighter_resources=freight_resources;_freighter_assemblies={}
	if freight_resources!=null:
		for actor in initial.npc_construction.actors:
			if actor.population_group in ["freighter","capital"]:_freighter_assemblies[int(actor.actor_id)]=actor.assembly.duplicate(true)
	return true

func _accept_configuration(bindings: RefCounted, library: RefCounted, identity: Dictionary, control: RefCounted, combat: RefCounted, weapons: RefCounted, resources: RefCounted, primaries: RefCounted=null, inventory: RefCounted=null, scenery_identity: RefCounted=null) -> bool:
	var initial:=identity.duplicate();initial.merge({"elapsed_ms":0,"weapons":weapons.snapshot()})
	if primaries!=null:initial.primaries=primaries.snapshot()
	var projectiles:=Projectiles.new();var impacts:=Impacts.new()
	if not projectiles.configure(bindings,library,initial):return reject(projectiles.error)
	if not impacts.configure(bindings,library,initial):return reject(impacts.error)
	_identity=identity;_control=control;_combat=combat;_weapons=weapons;_projectiles=projectiles;_impacts=impacts
	_max_ms=Frames.simulation_limit(bindings,150)
	_resources=resources
	_elapsed_ms=0;_world_elapsed_ms=0;_weapon_events=[];_actor_events=[]
	_primaries=primaries;_inventory=inventory;_scenery_identity=scenery_identity;_primary_contacts=[];_primary_fire={}
	_contract_context={};_secondaries=null;_selected_secondary=-1;_secondary_events=[]
	_selected40_world=null;_selected40_context={}
	return true

## Observe the ordered native population at HUD time. Acquisition only replaces
## the device candidate; the next player phase owns motion and cargo changes.
func acquire_cargo_target(tractor: RefCounted,delta_ms: int,projection: RefCounted,camera: Transform3D,context: Dictionary) -> Dictionary:
	error=""
	if not tractor is Recovery or _control==null or _combat==null or not tractor.same_identity(_identity) or not tractor.same_identity(context):
		return fail("Cargo targeting requires its native tractor, encounter and HUD context")
	if not projection is Recovery.TargetProjection:return fail("Cargo targeting requires the original flight projection")
	var combat:=_identity.duplicate();combat.actors=_combat.actor_snapshots()
	var observations:=[]
	# These native ordinary populations retain the constructor's clear scanner
	# exclusion and theft flags. Dormant AI targeting is a separate permission.
	for actor in combat.actors:
		if not actor.active:continue
		var eligible:=false
		if actor.actor_mode in [3,4]:
			var death: RefCounted=_control.destruction_owner(int(actor.actor_id))
			if not _supports_cargo_lifecycle(death,actor):return fail("This cargo target needs its separate actor lifecycle")
			var life: Dictionary=death.snapshot()
			eligible=life.get("cargo",{}).get("eligible",false)
		var projected: Dictionary=projection.project(camera,actor.pose.origin)
		if projected.has("error"):return fail(projection.error)
		observations.append({"base_content_id":_identity.base_content_id,"binding_id":_identity.binding_id,
			"actor_id":actor.actor_id,"actor_mode":actor.actor_mode,"active":actor.active,
			"cargo_eligible":eligible,"excluded":false,"scan_blocked":false,
			"priority":false,"pixels":projected.pixels,"in_view":projected.in_view})
	var next: RefCounted=tractor.fork_for_frame()
	if not next.acquire(delta_ms,observations,context):return fail(next.error)
	# The ordinary scanner consumes the same detached population, not another
	# full combat snapshot with career, weapon and event histories.
	return {"tractor":next,"combat":combat}

## Player-phase recovery publishes the wreck, combat body, cargo, tractor and
## world quantities together. A failed later flight phase discards this result.
func evaluate_cargo_recovery(tractor: RefCounted,cargo: RefCounted,delta_ms: int,player: Dictionary,scenery: RefCounted=null) -> Dictionary:
	error=""
	if not tractor is Recovery or not cargo is Cargo or _control==null or not tractor.same_identity(_identity):return fail("Wreck recovery requires its native equipped tractor, hold and encounter")
	if tractor.target_group()=="scenery":return _evaluate_scenery_recovery(tractor,cargo,delta_ms,player,scenery)
	var retained: Dictionary=tractor.snapshot()
	var id: int=retained.current_actor_id if retained.current_actor_id>=0 else retained.request_actor_id
	var actor: Dictionary={};var observation: Dictionary={};var life: Dictionary={};var death: RefCounted
	if id>=0:
		actor=_combat.actor_snapshot(id)
		if not actor.is_empty():
			death=_control.destruction_owner(id)
			if not _supports_cargo_lifecycle(death,actor):return fail("This cargo needs its separate actor lifecycle")
			life=death.snapshot()
			if actor.actor_mode not in [3,4] or not life.has("cargo") or life.mode!=actor.actor_mode or actor.vitals.hull!=0:return fail("Tractor recovery requires the current cargo-bearing wreck")
			var active: bool=life.phase!="retired" if death is NpcDeath else life.active
			if actor.get("body_pose")!=life.pose or actor.pose!=life.statistics_pose or actor.active!=active:return fail("The wreck body diverged from its retained cargo lifecycle")
			if not life.cargo.eligible:return fail("This wreck no longer offers recoverable cargo")
			# Freighter contact boxes are body-relative. Their separate wreck
			# volumes retain the lifecycle's source-set origin during pulling.
			if actor.has("point_boxes") and not death is FreightDeath:return fail("This wreck needs its retained collision-box adapter")
			observation={"base_content_id":_identity.base_content_id,"binding_id":_identity.binding_id,
				"actor_id":id,"actor_kind":actor.actor_kind,"actor_mode":actor.actor_mode,"hull":actor.vitals.hull,
				"active":actor.active,"cargo_eligible":life.cargo.eligible,"cargo_model_exists":life.cargo.model_exists,
				"retire_on_transfer":life.retire_on_transfer,"body_pose":life.pose,"cargo_pose":life.cargo.pose,
				"cargo_entries":life.cargo.entries,"collision_centers":[],"friendly":actor.get("friendly",false),
				"statistics_exempt":false,"body_motion_blocked":false,"body_motion_detached":false,"special_cargo":actor.get("special_cargo",false)}
			if death is FreightDeath:observation.freighter_position=_control._flight[id].source_position()
	var next_tractor: RefCounted=tractor.fork_for_frame()
	if not next_tractor.advance(delta_ms,player,observation,cargo.snapshot()):return fail(next_tractor.error)
	var frame: Dictionary=next_tractor.snapshot().frame
	var next: RefCounted=fork_for_frame();var next_cargo: RefCounted=cargo
	if not frame.actor_changes.is_empty():
		if frame.actor_changes.has("cargo_model_id") and frame.actor_changes.cargo_model_id!=life.cargo.model_id:return fail("Tractor recreation differs from the prepared wreck model")
		if frame.phase=="pickup":
			next_cargo=cargo.fork_for_frame()
			if not next_cargo.retain_recovery(next_tractor):return fail(next_cargo.error)
		# Retain one consistent combat branch in both encounter and controller.
		if _control is TrainingControl:
			next._control=_control.fork_for_frame(false,_combat)
			next._combat=next._control._combat
		else:
			next._control=_control.fork_for_frame();next._combat=_combat.fork_for_frame()
		if frame.phase=="pickup" and not next._combat.record_cargo_recovery(actor,frame.transfer.events):return fail(next._combat.error)
		death._retain_recovery_frame(frame)
		next._combat._writable(id)._retain_recovery_frame(frame)
		next._control._destruction[id]=death
		if frame.actor_changes.has("freighter_position"):
			var motion: RefCounted=_control._flight[id].fork_for_frame()
			motion._retain_recovery_frame(frame);next._control._flight[id]=motion
	return {"encounter":next,"tractor":next_tractor,"cargo":next_cargo,"frame":frame}

## Scenery uses the same one-shot hold transaction and career accounting, but
## retains its own physical-model, collision-statistics and destruction owners.
func _evaluate_scenery_recovery(tractor: RefCounted,cargo: RefCounted,delta_ms: int,player: Dictionary,scenery: RefCounted) -> Dictionary:
	if not scenery is Scenery or _scenery_identity==null or scenery.presentation_identity()!=_scenery_identity:return fail("Scenery recovery belongs to another prepared flight")
	var retained: Dictionary=tractor.snapshot()
	var index: int=retained.current_actor_id if retained.current_actor_id>=0 else retained.request_actor_id
	var actor: Dictionary=scenery.recovery_observation(index)
	if actor.is_empty():return fail(scenery.error)
	var next_tractor: RefCounted=tractor.fork_for_frame()
	if not next_tractor.advance(delta_ms,player,actor,cargo.snapshot()):return fail(next_tractor.error)
	var frame: Dictionary=next_tractor.snapshot().frame
	var next: RefCounted=fork_for_frame();var next_cargo: RefCounted=cargo;var next_scenery: RefCounted=scenery
	if not frame.actor_changes.is_empty():
		if frame.actor_changes.has("cargo_model_id") and frame.actor_changes.cargo_model_id!=actor.cargo_model_id:return fail("Tractor recreation differs from the prepared scenery model")
		if frame.phase=="pickup":
			next_cargo=cargo.fork_for_frame()
			if not next_cargo.retain_recovery(next_tractor):return fail(next_cargo.error)
			# The encounter and its controller observe one combat history, also
			# when scenery is the source of the accepted recovery quantity.
			if _control is TrainingControl:
				next._control=_control.fork_for_frame(false,_combat);next._combat=next._control._combat
			else:
				next._control=_control.fork_for_frame();next._combat=_combat.fork_for_frame()
			if not next._combat.record_cargo_recovery(actor,frame.transfer.events):return fail(next._combat.error)
		next_scenery=scenery.fork_for_frame()
		if not next_scenery._retain_recovery_frame(index,frame):return fail(next_scenery.error)
	return {"encounter":next,"tractor":next_tractor,"cargo":next_cargo,"scenery":next_scenery,"frame":frame}

func _supports_cargo_lifecycle(death: RefCounted,actor: Dictionary) -> bool:
	if death is NpcDeath:return true
	if death is DebrisDeath:return _control is TrainingControl and actor.get("population_group")=="debris" and actor.actor_kind==-1
	if not death is FreightDeath or actor.get("population_group")!="freighter" or actor.actor_kind not in [0,1,2,3]:return false
	return _control is TrainingControl and _control._flight[actor.actor_id] is TrainingControl.FreightMotion

## Join the existing encounter using its actual equipped player and complete
## target membership. Unsupported systems owners cannot acquire EMP behavior.
func configure_secondaries(bindings: RefCounted,cat: RefCounted,player: RefCounted,equipment: RefCounted,library: RefCounted=null) -> bool:
	error=""
	if _control==null or _combat==null or _secondaries!=null or _elapsed_ms!=0 or _world_elapsed_ms!=0 or _primaries==null or _inventory==null:return reject("Secondaries must join the prepared equipped encounter before flight")
	if target(player,Transform3D.IDENTITY).is_empty() or not Secondaries.Definitions.available(bindings):return reject("This encounter has no supported equipped secondary capability")
	var expected: Array=_inventory.snapshot().get("npc_ids",[])
	var actors: Array=_combat.snapshot().actors
	if expected.size()!=actors.size():return reject("Secondary targets omit part of the encounter")
	for id in expected.size():
		if expected[id]!=id or _combat.systems_for_frame(id)==null:return reject("This encounter lacks supported target systems")
	var owner:=Secondaries.new()
	var mounts: RefCounted
	if library!=null:
		mounts=preload("res://src/content/weapon_mounts.gd").new()
		if not mounts.open(library,cat):return reject(mounts.error)
	if not owner.configure(bindings,cat,player.loadout(),mounts):return reject(owner.error)
	if owner.evaluate_retention(player,equipment,_primaries,_inventory).is_empty():return reject(owner.error)
	# Detached physics checks may omit art. Every actual equipped departure
	# supplies its library and prepares retained bursts before the first launch.
	# A launcher whose last round was spent has left the loadout; no burst to prepare.
	if library!=null and owner.has_bombs():
		for kind in owner.bomb_kinds():
			var bursts:=DetonationResources.new()
			if not bursts.configure(library,bindings,kind):return reject(bursts.error)
			if not owner.configure_detonations(bursts):return reject(owner.error)
	if library!=null and not owner.configure_projectile_visuals(library,bindings):return reject(owner.error)
	_secondaries=owner;_selected_secondary=-1;_secondary_events=[]
	return true

func has_secondaries() -> bool:return _secondaries!=null

func secondary_feedback() -> Dictionary:
	return {} if _secondaries==null else _secondaries.selection_feedback(_selected_secondary)

func clear_secondary_events() -> void:
	_secondary_events=[]
	if _secondaries!=null:
		_secondaries=_secondaries.fork();_secondaries.clear_frame_cues()

func secondary_choices() -> Array:
	if _secondaries==null:return []
	return _secondaries.snapshot().guns.filter(func(gun):return gun.ammunition>0).map(func(gun):return {"item_id":int(gun.equipment.item_id),"quantity":int(gun.ammunition),"slot_index":int(gun.slot_index)})

## Native desktop/controller selection visits equipped launchers then None.
## This is an explicit player choice, not source automatic weapon selection.
func next_secondary_id() -> int:
	var ids: Array=secondary_choices().map(func(choice):return choice.item_id)
	ids.append(-1)
	return int(ids[(ids.find(_selected_secondary)+1)%ids.size()])

func select_secondary(item_id: int) -> RefCounted:
	error=""
	if _secondaries==null or (item_id!=-1 and not secondary_choices().any(func(choice):return choice.item_id==item_id)):reject("Select an installed secondary ammunition stack");return null
	var next:=fork_for_frame();next._selected_secondary=item_id
	return next

## Late secondary input is evaluated after primary input and before the NPC pass.
## Selection is explicit; an exhausted attempt clears it, never equips or refills.
func evaluate_secondary_fire(player: RefCounted,equipment: RefCounted,pose: Transform3D,requested: bool,input_enabled: bool,random_state: Dictionary,display_available:=true,scenery: RefCounted=null) -> Dictionary:
	error=""
	if _secondaries==null or target(player,pose).is_empty():return fail("Late secondary input requires an equipped encounter")
	if scenery!=null and (not scenery is Scenery or scenery.presentation_identity()!=_scenery_identity):return fail("Secondary input requires this encounter's retained scenery")
	# The selected40 script can change permission during the same frame. Do
	# not let a caller's stale pre-radio input override its cinematic gate.
	if _selected40_sequence!=null:input_enabled=input_enabled and not _selected40_sequence.snapshot().input_blocked
	var next:=fork_for_frame()
	next._combat=_combat.fork_for_frame()
	if not next._combat.begin_contact_pass(random_state,display_available):return fail(next._combat.error)
	var operation: Dictionary=next._secondaries.evaluate_player_trigger(pose,next._selected_secondary,next._combat,next._inventory.snapshot().npc_ids,player,equipment,next._primaries,next._inventory,requested and input_enabled) if scenery==null else scenery.evaluate_secondary_trigger(next._secondaries,next._combat,next._inventory,player,equipment,next._primaries,pose,next._selected_secondary,requested and input_enabled)
	if operation.is_empty():return fail(next._secondaries.error if scenery==null else scenery.error)
	next._secondaries=operation.owner;next._combat=operation.combat
	if not next._retain_blast_motion(operation.events):return fail(next.error)
	next._primaries=operation.primaries;next._inventory=operation.targets
	next._secondary_events.append_array(operation.events)
	if operation.selection_exhausted:next._selected_secondary=-1
	var result:={"encounter":next,"player":operation.player,"equipment":operation.equipment,"random_state":next._combat.contact_random_state()}
	if operation.has("scenery"):result.scenery=operation.scenery
	return result

## Existing bombs advance even without a new input edge. The shared early
## weapon pass calls this before NPC projectiles and the later actor update.
func evaluate_secondary_motion(milliseconds: int,random_state: Dictionary,display_available:=true,observer_position: Variant=null,scenery: RefCounted=null,guidance_actor_id: int=-1) -> Dictionary:
	error=""
	if _secondaries==null or not Numbers.integer(milliseconds,0,_max_ms):return fail("Secondary motion requires a supported encounter frame")
	var next:=fork_for_frame()
	next._combat=_combat.fork_for_frame()
	if not next._combat.begin_contact_pass(random_state,display_available):return fail(next._combat.error)
	var operation: Dictionary=next._secondaries.evaluate_advance(milliseconds,next._combat,next._inventory.snapshot().npc_ids,observer_position,null,null,guidance_actor_id) if scenery==null else scenery.evaluate_secondary_contacts(next._secondaries,next._combat,next._inventory,milliseconds,observer_position,guidance_actor_id)
	if operation.is_empty():return fail(next._secondaries.error if scenery==null else scenery.error)
	next._secondaries=operation.owner;next._combat=operation.combat;next._secondary_events=operation.events
	if not next._retain_blast_motion(operation.events):return fail(next.error)
	var result:={"encounter":next,"random_state":next._combat.contact_random_state(),"self_hits":operation.self_hits}
	if operation.has("scenery"):result.scenery=operation.scenery
	return result

func secondary_owner() -> RefCounted:return null if _secondaries==null else _secondaries.fork()

func _retain_blast_motion(events: Array) -> bool:
	if not _control is TrainingControl:return true
	var next: RefCounted=_control.evaluate_blast_motion(events)
	if next==null:return reject(_control.error)
	_control=next
	return true

func secondary_impacts() -> Array:return _secondary_events.filter(func(event):return event.action=="impact").duplicate(true)

func bind_contract_session(session: RefCounted,bindings: RefCounted=null) -> bool:
	error=""
	if _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):return reject("The encounter has no retained contract world")
	return true if session.bind_world(_control,_contract_context,bindings) else reject(session.error)

func bind_campaign_session(session: RefCounted,bindings: RefCounted,mission: Dictionary) -> bool:
	error=""
	if _identity.get("campaign_cursor")!=21 or _control==null or not _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):return reject("Bind the prepared rescue once to its earned campaign career")
	if not session.bind_campaign_world(bindings,_control,mission):return reject(session.error)
	_contract_context=_control.kappa_context()
	return true

func sample_contract_clock(world_ms: int,poll_ms: int) -> bool:
	error=""
	if _contract_context.is_empty():return reject("This encounter has no ordinary contract scene clock")
	return _sample_scene_clock(world_ms,poll_ms)

func sample_bakka_clock(world_ms: int,poll_ms: int) -> bool:
	error=""
	if _identity.get("campaign_cursor")!=36 or not _control is TrainingControl:return reject("This encounter has no B'akka scene clock")
	return _sample_scene_clock(world_ms,poll_ms)

func sample_mission_clock(world_ms: int,poll_ms: int) -> bool:
	error=""
	if not _control is TrainingControl or _control._mission_runner==null:return reject("This encounter has no mission clock")
	return _sample_scene_clock(world_ms,poll_ms)

func _sample_scene_clock(world_ms: int,poll_ms: int) -> bool:
	var control: RefCounted=_control.fork_for_frame(false)
	if not control.sample_scene_clock(world_ms,poll_ms):return reject(control.error)
	_control=control
	return true

func poll_bakka_result(radio_active: bool,periodic_poll_allowed: bool) -> Dictionary:
	error=""
	if _identity.get("campaign_cursor")!=36 or not _control is TrainingControl:return fail("This encounter has no B'akka result")
	var control: RefCounted=_control.fork_for_frame(false,_combat)
	var result: Dictionary=control.poll_bakka_result(radio_active,periodic_poll_allowed)
	if result.is_empty():return fail(control.error)
	_control=control
	return result

func acknowledge_bakka_result() -> bool:
	error=""
	if _identity.get("campaign_cursor")!=36 or not _control is TrainingControl:return reject("This encounter has no B'akka result")
	var control: RefCounted=_control.fork_for_frame(false,_combat)
	if not control.acknowledge_bakka_result():return reject(control.error)
	_control=control
	return true

func poll_mission_result(radio_active: bool,periodic_poll_allowed: bool) -> Dictionary:
	error=""
	if not _control is TrainingControl or _control._mission_runner==null:return fail("This encounter has no mission result")
	var control: RefCounted=_control.fork_for_frame(false,_combat)
	var result: Dictionary=control.poll_mission_result(radio_active,periodic_poll_allowed)
	if result.is_empty():return fail(control.error)
	_control=control
	return result

func acknowledge_mission_result() -> bool:
	error=""
	if not _control is TrainingControl or _control._mission_runner==null:return reject("This encounter has no mission result")
	var control: RefCounted=_control.fork_for_frame(false,_combat)
	if not control.acknowledge_mission_result():return reject(control.error)
	_control=control
	return true

func prepare_selected40_career(bindings: RefCounted,session: RefCounted,scenery: RefCounted) -> RefCounted:
	error=""
	if _selected40_world==null or _selected40_sequence==null or _selected40_sequence.snapshot().revision!=0 or not _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):reject("Bind selected40 career once before its first frame");return null
	var career: RefCounted=session.fork()
	if not career.bind_selected40_world(bindings,_control,scenery):reject(career.error);return null
	_contract_context=career.snapshot().flight.ordinary_context.duplicate(true)
	return career

func evaluate_contract_session(session: RefCounted,radio_active: bool=false,poll_results: bool=true,periodic_poll_allowed: bool=true) -> Dictionary:
	error=""
	if _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):return fail("The encounter has no retained contract career")
	# Contacts have already changed the encounter bodies. Retain that exact
	# body state without inserting an extra actor/guidance update before polling.
	var control: RefCounted=_control.fork_for_frame(false,_combat)
	var result: Dictionary=session.evaluate_flight(control,radio_active,poll_results,periodic_poll_allowed)
	if result.is_empty():return fail(session.error)
	_control=result.controller;_combat=_control.combat_owner()
	return {"session":result.session,"opened":result.opened}

func acknowledge_contract_result(session: RefCounted,serial: int) -> Dictionary:
	error=""
	if _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):return fail("No retained contract result is available")
	var result: Dictionary=session.acknowledge_flight_result(_control,serial)
	if result.is_empty():return fail(session.error)
	_control=result.controller;_combat=_control.combat_owner()
	return result

func selected40_controller_matches(controller: RefCounted) -> bool:
	if _selected40_world==null or _control==null or not is_instance_of(controller,load("res://src/simulation/combat_training_control.gd")):return false
	var current: RefCounted=_control.fork_for_frame(false,_combat)
	return controller.flight_identity()==current.flight_identity() and controller.career_snapshot()==current.career_snapshot()

func prepare_successor41_career(bindings: RefCounted,session: RefCounted,departure: RefCounted) -> RefCounted:
	error=""
	if _selected40_world==null or _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):reject("Successor41 requires its retained selected40 ledger");return null
	var control: RefCounted=_control.fork_for_frame(false,_combat)
	var result: RefCounted=session.transfer_selected40_portal(bindings,control,departure)
	if result==null:reject(session.error)
	return result

func finish_contract_session(session: RefCounted) -> RefCounted:
	error=""
	if _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):reject("The encounter has no retained contract career");return null
	var control: RefCounted=_control.fork_for_frame();control._combat=_combat.fork_for_frame()
	var result: RefCounted=session.finish_flight(control,true)
	if result==null:reject(session.error)
	return result

func acknowledge_campaign_visit(bindings: RefCounted,session: RefCounted,visit: RefCounted) -> RefCounted:
	error=""
	if _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):reject("The encounter has no retained campaign career");return null
	var control: RefCounted=_control.fork_for_frame();control._combat=_combat.fork_for_frame()
	var result: RefCounted=session.acknowledge_campaign_visit(bindings,control,visit)
	if result==null:reject(session.error)
	return result

func acknowledge_campaign_result(bindings: RefCounted,session: RefCounted,visit: RefCounted,rescue: RefCounted) -> RefCounted:
	error=""
	if _contract_context.is_empty() or not is_instance_of(session,load("res://src/simulation/contract_session.gd")):reject("The rescue result has no retained campaign career");return null
	var control: RefCounted=_control.fork_for_frame(false,_combat)
	var result: RefCounted=session.acknowledge_campaign_result(bindings,control,visit,rescue)
	if result==null:reject(session.error)
	return result

func evaluate_weapons(player: RefCounted, pose: Transform3D, milliseconds: int, scenery: RefCounted=null, shared_random_state: Variant=null, display_available:=true, secondary_display_available:=true,guidance_actor_id: int=-1) -> Dictionary:
	error=""
	if _control==null or not Numbers.integer(milliseconds,0,_max_ms) or target(player,pose).is_empty():return fail("Invalid encounter weapon frame")
	if _primaries!=null and (not scenery is Scenery or scenery.presentation_identity()!=_scenery_identity):return fail("Equipped contacts require the retained complete scenery")
	var prior:=_weapon_observation();var next:=fork_for_frame()
	next._projectiles=_projectiles.fork_for_frame();next._impacts=_impacts.fork_for_frame()
	if not next._projectiles.advance(milliseconds):return fail(next._projectiles.error)
	if not next._impacts.advance(milliseconds):return fail(next._impacts.error)
	var field: RefCounted=scenery
	var pilot: RefCounted=player
	var contact_random:={}
	if next._primaries!=null:
		if _selected40_view!=null and _selected40_view.snapshot().camera_mode!=0:guidance_actor_id=-1
		var primary: Dictionary=field.evaluate_primary_contacts(next._primaries,next._combat,next._inventory,milliseconds,shared_random_state,display_available,guidance_actor_id)
		if primary.is_empty():return fail(field.error)
		field=primary.scenery;next._primaries=primary.primaries;next._combat=primary.combat;next._primary_contacts=primary.weapons
		contact_random=primary.get("random_state",{})
	next._secondary_events=[]
	if next._secondaries!=null:
		var random_for_secondary: Variant=contact_random if not contact_random.is_empty() else shared_random_state
		if not random_for_secondary is Dictionary:return fail("Secondary motion requires the shared world random state")
		var secondary: Dictionary=next.evaluate_secondary_motion(milliseconds,random_for_secondary,secondary_display_available,pose.origin,field,guidance_actor_id)
		if secondary.is_empty():return fail(next.error)
		next=secondary.encounter;contact_random=secondary.random_state
		if secondary.has("scenery"):field=secondary.scenery
		pilot=next._evaluate_bomb_damage(player,secondary.self_hits)
		if pilot==null:return fail(next.error)
	var pass_result: Dictionary
	if next._primaries==null:
		pass_result=next._weapons.evaluate_player_update(pilot,pose,next._combat.shooter_states(),false,milliseconds)
	else:
		pass_result=next._weapons.evaluate_selected40_update(pilot,pose,next._combat,milliseconds) if _selected40_world!=null else next._weapons.evaluate_combat_training_update(pilot,pose,next._combat,false,milliseconds)
	if pass_result.is_empty():return fail(next._weapons.error)
	if not next._impacts.apply_contacts(prior,next._primary_contacts,pass_result.actors):return fail(next._impacts.error)
	if next._primaries!=null:next._combat=pass_result.combat
	next._weapons=pass_result.weapons;next._weapon_events=pass_result.actors;next._elapsed_ms+=milliseconds
	next._primary_fire={}
	var result:={"encounter":next,"player":pass_result.player}
	if field!=null:result.scenery=field
	if not contact_random.is_empty():result.random_state=contact_random
	return result

func _evaluate_bomb_damage(player: RefCounted,hits: Array) -> RefCounted:
	if _difficulty!=1.5 or hits.is_empty():return player
	var next: RefCounted=player.fork_for_frame()
	for hit in hits:
		if next.normal_hit(hit.damage).is_empty():reject(next.error);return null
	return next

func evaluate_world_logic(milliseconds: int, random_state: Dictionary, player_pose: Variant=null) -> Dictionary:
	error=""
	if _control==null or not Numbers.integer(milliseconds,0,_max_ms):return fail("Invalid encounter world-logic frame")
	var random:=Random.new()
	if not random.restore(random_state):return fail(random.error)
	var next:=fork_for_frame()
	if _control.has_method("runs_ambient_traffic") and _control.runs_ambient_traffic():
		var result: Dictionary=_control.evaluate_ambient_world_logic(milliseconds,_combat,random_state,player_pose)
		if result.is_empty():return fail(_control.error)
		next._control=result.controller;next._combat=result.combat
		return {"encounter":next,"random_state":result.random_state}
	return {"encounter":next,"random_state":random.snapshot()}

func reset_primary_fire_intervals() -> bool:
	error=""
	if _primaries==null:return reject("This encounter has no equipped primary owner")
	var primaries: RefCounted=_primaries.fork_state()
	if not primaries.reset_fire_intervals():return reject(primaries.error)
	_primaries=primaries
	return true

func evaluate_primary_fire(player: RefCounted, pose: Transform3D, requested: bool, input_enabled: bool, random_state: Dictionary, weapon_targets: Array=[]) -> Dictionary:
	error=""
	var input:=target(player,pose);var random:=Random.new()
	if _primaries==null or input.is_empty():return fail("Late primary input requires an equipped encounter")
	if not random.restore(random_state):return fail(random.error)
	var next:=fork_for_frame();var result:=random.snapshot()
	next._primary_fire={}
	var sequence_enabled: bool=_selected40_sequence==null or not _selected40_sequence.snapshot().input_blocked
	var firing: bool=requested and input_enabled and sequence_enabled and input.active and input.hull>0
	var beams: bool=_primaries.has_beams()
	if firing or beams:
		next._primaries=_primaries.fork_state()
		if beams and not next._primaries.observe_beam_pose(pose):return fail(next._primaries.error)
	if firing:
		var targets:=[]
		if beams:
			for id in weapon_targets:
				if not id is int:return fail("Weapon aim window contains an invalid actor")
				var actor: Dictionary=_combat.actor_snapshot(id)
				if actor.is_empty():return fail(_combat.error)
				targets.append(actor)
		next._primary_fire=next._primaries.fire(pose,true,result,targets)
		if next._primary_fire.is_empty():return fail(next._primaries.error)
		result=next._primary_fire.random_state
	return {"encounter":next,"random_state":result}

func evaluate_cue(player: RefCounted, pose: Transform3D, cursor: int) -> RefCounted:
	error=""
	var input:=target(player,pose)
	if _control==null or input.is_empty():reject("Invalid second-trip cue player");return null
	if _primaries!=null:reject("Training mission cues belong to its flight controller");return null
	var operation: Dictionary=_control.apply_full_hold_appearance(_combat,cursor,input)
	if operation.is_empty():reject(_control.error);return null
	var next:=fork_for_frame();next._control=operation.controller;next._combat=operation.combat
	return next

func evaluate_world(player: RefCounted, pose: Transform3D, milliseconds: int, random_state: Dictionary) -> Dictionary:
	error=""
	if _selected40_sequence!=null and (not _selected40_pending_world or _selected40_sequence.snapshot().elapsed_ms!=_world_elapsed_ms+milliseconds):return fail("Selected40 actor frame requires its ordered radio and choreography frame")
	var input:=target(player,pose)
	if _control==null or not Numbers.integer(milliseconds,0,_max_ms) or input.is_empty():return fail("Invalid encounter NPC frame")
	var operation: Dictionary=_control.evaluate(_combat,_weapons,milliseconds,input,random_state,player) if _selected40_world!=null else _control.evaluate(_combat,_weapons,milliseconds,input,random_state)
	if operation.is_empty():return fail(_control.error)
	var next:=fork_for_frame()
	next._control=operation.controller;next._combat=operation.combat;next._weapons=operation.weapons
	next._actor_events=operation.actors;next._world_elapsed_ms+=milliseconds
	next._selected40_pending_world=false
	return {"encounter":next,"random_state":operation.random_state}

func target(player: RefCounted, pose: Transform3D) -> Dictionary:
	if not player is Player or not Flight.rigid_pose(pose):return {}
	var state: Dictionary=player.snapshot()
	if _selected40_world!=null and (player.selected40_construction_owner()!=_selected40_world.npc_construction_owner() or state.get("selected40_context")!=_selected40_context):return {}
	for key in _identity:
		if state.get(key)!=_identity[key]:return {}
	if state.get("ship_id")!=0:return {}
	# Ordinary starter construction keeps these source flags clear. Damage
	# permission is independently controlled by the departure controller.
	return {"base_content_id":_identity.base_content_id,"binding_id":_identity.binding_id,
		"ship_id":0,"pose":pose,"active":state.active,"hull":state.vitals.hull,
		"targeting_blocked":false,"special_flight":false,"alternate_position":null}

func snapshot() -> Dictionary:
	if _control==null:return {}
	var result:=_identity.duplicate()
	var combat: Dictionary=_combat.snapshot()
	if _selected40_world!=null:result.scope="selected40_mixed_contact_component"
	if _selected40_sequence!=null:result.selected40_sequence=_selected40_sequence.snapshot()
	if _selected40_view!=null:result.selected40_view=_selected40_view.snapshot()
	var shared: bool=_control.has_method("shares_combat") and _control.shares_combat(_combat)
	result.merge({"elapsed_ms":_elapsed_ms,"world_elapsed_ms":_world_elapsed_ms,
		"combat":combat,"controller":_control.snapshot(combat.duplicate(true)) if shared else _control.snapshot(),"weapons":_weapons.snapshot(),
		"weapon_events":_weapon_events.duplicate(true),"actor_events":_actor_events.duplicate(true),
		"projectile_visuals":_projectiles.snapshot(),"impact_visuals":_impacts.snapshot()})
	if _primaries!=null:
		result.primaries=_primaries.snapshot();result.primary_contacts=_primary_contacts.duplicate(true);result.primary_fire=_primary_fire.duplicate(true)
	if _secondaries!=null:
		result.secondaries=_secondaries.snapshot();result.selected_secondary=_selected_secondary;result.secondary_events=_secondary_events.duplicate(true)
	return result

## Detached model/weapon observations for the retained NPC renderer. Controller,
## career and event histories are not needed to prepare a geometry frame.
func presentation_snapshot() -> Dictionary:
	if _control==null:return {}
	var result:=_identity.duplicate()
	result.merge({"elapsed_ms":_elapsed_ms,"combat":{"actors":_combat.actor_snapshots()},
		"weapons":_weapons.snapshot(),"projectile_visuals":_projectiles.snapshot(),
		"impact_visuals":_impacts.snapshot()})
	if _primaries!=null:result.primaries=_primaries.snapshot()
	return result

## The weapon slots and clock that impact contacts read, without actor state.
func _weapon_observation() -> Dictionary:
	var result:=_identity.duplicate()
	result.merge({"elapsed_ms":_elapsed_ms,"weapons":_weapons.snapshot()})
	if _primaries!=null:result.primaries=_primaries.snapshot()
	return result

func combat_snapshot() -> Dictionary:return {} if _combat==null else _combat.snapshot()
## Accounting/provocation only; skips per-actor pose and systems copies.
func career_snapshot() -> Dictionary:return {} if _combat==null else _combat.career_snapshot()
func primary_contacts() -> Array:return _primary_contacts.duplicate(true)
## Every mounted gun emits a record, even without a hit. Only an actual NPC
## contact sets the hit reticle; asteroid hits retain ordinary aim feedback.
func primary_npc_contact() -> bool:
	for weapon in _primary_contacts:
		for hit in weapon.contacts:
			if hit.target.group=="npc":return true
	return false

## Small detached observation for the enclosing native flight transaction.
## Do not duplicate the cast, destruction pools or career just to read clocks.
func selected40_frame_context() -> Dictionary:
	if _selected40_sequence==null or _selected40_view==null:return {}
	return {"elapsed_ms":_elapsed_ms,"world_elapsed_ms":_world_elapsed_ms,
		"pending_world":_selected40_pending_world,"sequence":_selected40_sequence.snapshot(),
		"view":_selected40_view.snapshot(),"freighter_mode":_combat.actor_snapshot(0).actor_mode}
func actor_events() -> Array:return _actor_events.duplicate(true)
func actor_engine_observation(actor_id: int) -> Dictionary:
	return {} if _control==null else _control.actor_engine_observation(actor_id)

## Sound does not need full actor/system/particle/controller snapshots.
func audio_snapshot() -> Dictionary:
	if _control==null:return {}
	var result:=_identity.duplicate()
	result.elapsed_ms=_elapsed_ms;result.actor_events=_actor_events.duplicate(true)
	if _primaries!=null:result.primaries=_primaries.snapshot();result.primary_fire=_primary_fire.duplicate(true)
	if _secondaries!=null:result.secondaries=_secondaries.snapshot();result.secondary_events=_secondary_events.duplicate(true)
	return result

func projectile_visual_owner() -> RefCounted:return null if _projectiles==null else _projectiles.fork_for_frame()
func combat_owner() -> RefCounted:return null if _combat==null else _combat.fork_for_frame()
func impact_visual_owner() -> RefCounted:return null if _impacts==null else _impacts.fork_for_frame()
func npc_destruction_owner(actor_id: int) -> RefCounted:return null if _control==null else _control.destruction_owner(actor_id)
func recovery_totals() -> Dictionary:
	return Combat.EMPTY_RECOVERY.duplicate(true) if _combat==null else _combat.recovery_totals()
func freighter_assembly(actor_id: int) -> Dictionary:return _freighter_assemblies.get(actor_id,{}).duplicate(true)
func freighter_resources() -> RefCounted:return _freighter_resources
## Stable identity of the selected source cast, including across frame forks.
func selected40_construction_owner() -> RefCounted:return null if _selected40_world==null else _selected40_world.npc_construction_owner()
func destruction_resources() -> RefCounted:return null if _resources==null else _resources.fork_for_frame()
func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._contract_context=_contract_context.duplicate(true)
	copy._max_ms=_max_ms
	copy._difficulty=_difficulty
	copy._selected40_world=_selected40_world
	copy._selected40_context=_selected40_context
	copy._selected40_sequence=_selected40_sequence
	copy._selected40_view=_selected40_view;copy._selected40_pending_world=_selected40_pending_world
	if _control==null:return copy
	# Each phase replaces its changed owners with detached candidates. Sharing
	# the others avoids copying every NPC's motion and effects for weapon input,
	# scene observation, and clock updates that never change them.
	copy._identity=_identity;copy._control=_control;copy._combat=_combat
	copy._weapons=_weapons;copy._projectiles=_projectiles;copy._impacts=_impacts
	copy._resources=_resources;copy._freighter_resources=_freighter_resources;copy._freighter_assemblies=_freighter_assemblies
	copy._primaries=_primaries
	copy._inventory=_inventory;copy._scenery_identity=_scenery_identity
	copy._secondaries=_secondaries
	copy._selected_secondary=_selected_secondary;copy._secondary_events=_secondary_events.duplicate(true)
	copy._primary_contacts=_primary_contacts.duplicate(true);copy._primary_fire=_primary_fire.duplicate(true)
	copy._elapsed_ms=_elapsed_ms;copy._world_elapsed_ms=_world_elapsed_ms
	copy._weapon_events=_weapon_events.duplicate(true);copy._actor_events=_actor_events.duplicate(true)
	return copy
func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:reject(message);return {}
