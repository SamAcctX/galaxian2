extends "res://src/simulation/full_hold_encounter.gd"
## Recipe-selected native hooks compose the shared weapon and visual owners.
## Contacts, the parent result visit, choreography and late motion are separate
## transactions; the enclosing flight commits their complete candidate once.
const MissionContext=preload("res://src/simulation/mission_context.gd")
const Ambush=preload("res://src/simulation/selected41_npc_combat.gd")
var _context: RefCounted
var _hook: RefCounted

func prepare(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,context: RefCounted,world: RefCounted) -> bool:
	error=""
	if _context!=null or not context is MissionContext:return reject("Prepare a fresh encounter from its admitted mission")
	var recipe: Dictionary=context.recipe()
	if recipe.get("sequences",[])!=["freighter_ambush"]:return reject("No native flight hook is prepared for this recipe")
	var hook:=Ambush.new()
	if not hook.prepare(bindings,catalogues,library,world):return reject(hook.error)
	var player: RefCounted=hook.player_owner();var scenery: RefCounted=world.scenery_owner()
	if not context.matches_loadout(player.loadout()):return reject("Mission player differs from its admitted equipment")
	for key in context.identity():
		if world.snapshot().get(key)!=context.identity()[key]:return reject("Initialized mission world differs from its admitted identity")
	var mounts:=Mounts.new();var primaries:=Primaries.new();var inventory:=Inventory.new()
	if not mounts.open(library,catalogues) or not primaries.configure_player(bindings,catalogues,mounts,player,context):return reject(mounts.error+primaries.error)
	if not inventory.has_method("configure_mission"):return reject("Mission flight needs OpeningTargetInventory.configure_mission(bindings,catalogues,context,player,scenery,combat)")
	var combat: RefCounted=hook.combat_owner();var control: RefCounted=hook.controller_owner()
	if not inventory.configure_mission(bindings,catalogues,context,player,scenery,combat):return reject(inventory.error)
	if not _accept_configuration(bindings,library,context.identity(),control,combat,hook.weapons_owner(),control.destruction_resources(),primaries,inventory,scenery.presentation_identity()):return false
	_context=context;_hook=hook
	if not configure_secondaries(bindings,catalogues,player,world.entry_owner().equipment_owner(),library):return false
	var data: Dictionary=load("res://src/content/selected41_population_definitions.gd").consequence_profile(bindings,catalogues,world)
	var freight:=FreightResources.new()
	if not freight._configure_story(library,bindings,data):return reject(freight.error)
	_freighter_resources=freight
	for row in world.construction_owner().npc_construction_owner().snapshot().actors:
		if row.population_group=="freighter":_freighter_assemblies[row.actor_id]=row.assembly.duplicate(true)
	return true

func target(player: RefCounted,pose: Transform3D) -> Dictionary:
	if _context==null or _hook==null or not player is Player or not Flight.rigid_pose(pose):return {}
	if player.selected41_construction_owner()!=_hook.world_owner().construction_owner().npc_construction_owner():return {}
	var state: Dictionary=player.snapshot()
	for key in _identity:
		if state.get(key)!=_identity[key]:return {}
	return {"base_content_id":_identity.base_content_id,"binding_id":_identity.binding_id,"ship_id":state.ship_id,
		"pose":pose,"active":state.active,"hull":state.vitals.hull,"targeting_blocked":false,"special_flight":false,"alternate_position":null}

func evaluate_weapons(player: RefCounted,pose: Transform3D,milliseconds: int,scenery: RefCounted=null,shared_random_state: Variant=null,display_available:=true,secondary_display_available:=true) -> Dictionary:
	error=""
	if _hook==null or _hook.composition_stage()!="ready" or not Numbers.integer(milliseconds,0,_max_ms) or target(player,pose).is_empty():return fail("Invalid mission contact frame")
	if not scenery is Scenery or scenery.presentation_identity()!=_scenery_identity or not shared_random_state is Dictionary:return fail("Mission contacts require the retained field and random stream")
	var prior:=_weapon_observation();var next:=fork_for_frame()
	next._projectiles=_projectiles.fork_for_frame();next._impacts=_impacts.fork_for_frame()
	if not next._projectiles.advance(milliseconds) or not next._impacts.advance(milliseconds):return fail(next._projectiles.error+next._impacts.error)
	var primary: Dictionary=scenery.evaluate_primary_contacts(_primaries,_combat,_inventory,milliseconds,shared_random_state,display_available)
	if primary.is_empty():return fail(scenery.error)
	next._primaries=primary.primaries;next._combat=primary.combat;next._primary_contacts=primary.weapons
	var secondary: Dictionary=next.evaluate_secondary_motion(milliseconds,primary.random_state,secondary_display_available,pose.origin)
	if secondary.is_empty():return fail(next.error)
	next=secondary.encounter
	var composed: RefCounted=_hook.compose(player,next._combat,next._weapons,secondary.random_state)
	if composed==null:return fail(_hook.error)
	var contacts: RefCounted=composed.evaluate_contacts(milliseconds,pose,display_available)
	if contacts==null:return fail(composed.error)
	next._adopt_hook(contacts)
	if not next._impacts.apply_contacts(prior,next._primary_contacts,next._weapon_events):return fail(next._impacts.error)
	next._elapsed_ms+=milliseconds;next._primary_fire={}
	return {"encounter":next,"player":contacts.player_owner(),"scenery":primary.scenery,"random_state":contacts.random_state()}

## Commit the already evaluated early frame when success interrupts the late
## pass. The native hook enforces the contact boundary and retains its cast.
func finish_before_sequence() -> Dictionary:
	error=""
	if _hook==null or _hook.composition_stage()!="contacts":return fail("A result must finish its ordered contact frame")
	var completed: RefCounted=_hook.finish_before_sequence()
	if completed==null:return fail(_hook.error)
	if completed.frame_context().elapsed_ms!=_elapsed_ms:return fail("Result completion lost its contact clock")
	var next:=fork_for_frame();next._adopt_hook(completed)
	next._world_elapsed_ms=next._elapsed_ms
	return {"encounter":next}

func evaluate_sequence(preceding_camera: RefCounted=null) -> Dictionary:
	error=""
	var hook: RefCounted=_hook.evaluate_sequence(preceding_camera)
	if hook==null:return fail(_hook.error)
	var next:=fork_for_frame();next._adopt_hook(hook)
	return {"encounter":next,"player":hook.player_owner(),"random_state":hook.random_state(),"sequence":hook.sequence_owner().snapshot()}

func evaluate_world(player: RefCounted,pose: Transform3D,milliseconds: int,random_state: Dictionary) -> Dictionary:
	error=""
	if target(player,pose).is_empty() or _elapsed_ms!=_world_elapsed_ms+milliseconds or _hook.composition_stage()!="sequence":return fail("Mission motion requires its ordered contact/sequence frame")
	var composed: RefCounted=_hook.compose(player,_combat,_weapons,random_state)
	if composed==null:return fail(_hook.error)
	var motion: RefCounted=composed.evaluate_motion()
	if motion==null:return fail(composed.error)
	var next:=fork_for_frame();next._adopt_hook(motion);next._world_elapsed_ms+=milliseconds
	return {"encounter":next,"random_state":motion.random_state()}

func _adopt_hook(hook: RefCounted) -> void:
	_hook=hook;_control=hook.controller_owner();_combat=hook.combat_owner();_weapons=hook.weapons_owner()
	var events: Dictionary=hook.event_observation()
	_weapon_events=events.get("contacts",[]);_actor_events=events.get("actors",[])

func frame_context() -> Dictionary:
	if _hook==null:return {}
	return {"elapsed_ms":_elapsed_ms,"world_elapsed_ms":_world_elapsed_ms,"pending_world":_hook.composition_stage()!="ready",
		"sequence":_hook.sequence_owner().snapshot(),"radio":_hook.radio_owner().snapshot(),"radio_events":_hook.event_observation().get("radio",[])}
func result_observation() -> Dictionary:return {} if _hook==null else _hook.result_observation()
func radio_owner() -> RefCounted:return null if _hook==null else _hook.radio_owner()
func camera_owner() -> RefCounted:return null if _hook==null else _hook.camera_owner()
func mission_context_owner() -> RefCounted:return _context
func world_owner() -> RefCounted:return null if _hook==null else _hook.world_owner()
func sequence_hook_owner() -> RefCounted:return null if _hook==null else _hook.fork_for_frame()

func snapshot() -> Dictionary:
	var state:=super.snapshot()
	if _hook!=null:state.merge(frame_context(),true);state.scope="mission_encounter"
	return state
func fork_for_frame() -> RefCounted:
	var copy: RefCounted=super.fork_for_frame()
	copy._context=_context;copy._hook=_hook
	return copy
