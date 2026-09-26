extends RefCounted
## Ordered native41 NPC contacts -> movement/guidance -> newly fired shots.
## Radio observes completed weapon contacts, BEFORE the late NPC motion pass.
## The first native attack shot runs after radio and before late NPC motion.
## Event5 and later cinematics, complete flight and Host activation stay closed.
const World=preload("res://src/simulation/selected41_world_initialization.gd")
const NPCControl=preload("res://src/simulation/combat_training_control.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Radio=preload("res://src/simulation/radio_sequence.gd")
const RadioResources=preload("res://src/presentation/opening_radio_resources.gd")
const Sequence=preload("res://src/simulation/selected41_sequence.gd")
var error:=""
var _world: RefCounted
var _control: RefCounted
var _combat: RefCounted
var _weapons: RefCounted
var _player: RefCounted
var _state:={}
var _random:={}
var _max_ms:=0
var _events:={}
var _radio: RefCounted
var _sequence: RefCounted

func prepare(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,world: RefCounted) -> bool:
	error=""
	if not _state.is_empty() or not world is World or world.snapshot().is_empty():return reject("Prepare source41 NPCs once from their complete native world")
	var control:=NPCControl.new()
	if not control.configure_selected41(bindings,catalogues,library,world):return reject(control.error)
	var combat: RefCounted=control.combat_owner();var weapons:=Weapons.new()
	if not weapons.configure_selected41(bindings,catalogues,world,combat):return reject(weapons.error)
	var player: RefCounted=world.construction_owner().player_owner()
	if player==null or player.selected41_construction_owner()!=world.construction_owner().npc_construction_owner():return reject("Source41 NPCs lost the retained native player generation")
	var resources:=RadioResources.new();var radio:=Radio.new()
	if not resources.prepare(library,bindings,null,41) or not radio.configure(bindings,library,resources.line_counts,41):return reject(resources.error+radio.error)
	var sequence:=Sequence.new()
	if not sequence.configure(bindings,world):return reject(sequence.error)
	_world=world;_control=control;_combat=combat;_weapons=weapons;_player=player
	_radio=radio
	_sequence=sequence
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":41,
		"scope":"selected41_native_npc_component","revision":0,"elapsed_ms":0,"player_pose":world.snapshot().player_pose,"application_committed":false}
	_random=world.snapshot().random_state.duplicate(true);_max_ms=Frames.simulation_limit(bindings)
	return true

func evaluate(milliseconds: Variant,player_pose: Variant,display_available:=true) -> RefCounted:
	error=""
	if _state.is_empty() or not Numbers.integer(milliseconds,0,_max_ms) or _state.elapsed_ms>2147483647-milliseconds or not Flight.rigid_pose(player_pose):reject("Invalid source41 NPC frame");return null
	if _combat.selected41_world_owner()!=_world or _control.selected41_world_owner()!=_world:reject("Source41 radio/NPC frame changed its initialized generation");return null
	var combat: RefCounted=_combat.fork_for_frame()
	if not combat.begin_contact_pass(_random,display_available):reject(combat.error);return null
	# Each retained gun visits player-first and then the other-kind actors.
	# Cleanup/movement occurs only after its complete inner target list.
	var contacts: Dictionary=_weapons.evaluate_selected41_update(_player,player_pose,combat,milliseconds)
	if contacts.is_empty():reject(_weapons.error);return null
	# The shared original outer flight tick completes projectiles before radio
	# and mission choreography. A lethal contact can start its hull-zero line
	# now, while completed-breakup mode4 still belongs to later NPC updates.
	var radio: RefCounted=_radio.fork_for_frame()
	var transmissions: Array=radio.step_selected41(_state.elapsed_ms+milliseconds,contacts.combat)
	if not radio.error.is_empty():reject(radio.error);return null
	var sequence: RefCounted=_sequence.fork_for_frame()
	if not sequence.advance(milliseconds,radio,contacts.combat,player_pose):reject(sequence.error);return null
	var choreography: Dictionary=_control.evaluate_selected41_sequence(sequence,contacts.combat,contacts.weapons)
	if choreography.is_empty():reject(_control.error);return null
	var player: RefCounted=contacts.player;var state: Dictionary=player.snapshot()
	if sequence.snapshot().frame.cancel_actions and not player.set_permissions(state.active,false):reject(player.error);return null
	var target:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"ship_id":state.ship_id,
		"pose":player_pose,"active":state.active,"hull":state.vitals.hull,"targeting_blocked":false,"special_flight":false,"alternate_position":null}
	var operation: Dictionary=choreography.controller.evaluate(choreography.combat,choreography.weapons,milliseconds,target,choreography.combat.contact_random_state(),player)
	if operation.is_empty():reject(choreography.controller.error);return null
	if not sequence.finish_camera(milliseconds,operation.combat,player_pose):reject(sequence.error);return null
	var next: RefCounted=get_script().new()
	next._world=_world;next._control=operation.controller;next._combat=operation.combat;next._weapons=operation.weapons;next._player=player
	next._radio=radio
	next._sequence=sequence
	next._state=_state.duplicate();next._state.revision+=1;next._state.elapsed_ms+=milliseconds
	next._state.player_pose=player_pose
	next._random=operation.random_state.duplicate(true);next._max_ms=_max_ms
	next._events={"contacts":contacts.actors,"actors":operation.actors,"radio":transmissions,"sequence":sequence.snapshot().frame}
	return next

func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate()
	result.merge({"random_state":_random.duplicate(true),"player":_player.snapshot(),"combat":_combat.snapshot(),
		"controller":_control.snapshot(),"weapons":_weapons.snapshot(),"events":_events.duplicate(true),"radio":_radio.snapshot(),"failure_condition":failure_condition_observation()})
	result.sequence=_sequence.snapshot()
	return result
## A read-only predicate over the CURRENT native body, not a mission result.
## Hull-zero radio can start before this completed-breakup mode4 observation.
## Its active cargo wreck may remain active for another 60000 milliseconds.
func failure_condition_observation() -> Dictionary:
	if _state.is_empty():return {}
	return {"kind":7,"parameter":1,"satisfied":_combat.actor_snapshot(0).actor_mode==4,"npc_revision":_state.revision}
func radio_owner() -> RefCounted:return null if _radio==null else _radio.fork_for_frame()
func sequence_owner() -> RefCounted:return null if _sequence==null else _sequence.fork_for_frame()
func frame_context() -> Dictionary:return _state.duplicate()
func world_owner() -> RefCounted:return _world
func combat_owner() -> RefCounted:return null if _combat==null else _combat.fork_for_frame()
func weapons_owner() -> RefCounted:return null if _weapons==null else _weapons.fork_for_frame()
func player_owner() -> RefCounted:return null if _player==null else _player.fork_for_frame()
func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate();copy._random=_random.duplicate(true);copy._max_ms=_max_ms;copy._world=_world;copy._events=_events.duplicate(true)
	copy._control=null if _control==null else _control.fork_for_frame(false)
	copy._combat=combat_owner();copy._weapons=weapons_owner();copy._player=player_owner()
	copy._radio=radio_owner()
	copy._sequence=sequence_owner()
	return copy
func reject(message: String) -> bool:error=message;return false
