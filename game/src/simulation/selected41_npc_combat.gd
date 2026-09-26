extends RefCounted
## Ordered native41 NPC contacts -> movement/guidance -> newly fired shots.
## Radio observes completed weapon contacts, BEFORE the late NPC motion pass.
## The native cinematic hook runs after radio and before late NPC motion.
## The parent owns result polling, player flight and atomic Host activation.
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
var _stage:="ready"
var _frame_ms:=0

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

## Compose retained native owners after the enclosing flight's player/contact
## or weapon-input pass. A value-equivalent regenerated cast is not authority.
func compose(player: RefCounted,combat: RefCounted,weapons: RefCounted,random_state: Dictionary) -> RefCounted:
	error=""
	if _state.is_empty() or not is_instance_of(player,load("res://src/simulation/opening_player_state.gd")) or not is_instance_of(combat,load("res://src/simulation/opening_combat_group.gd")) or not weapons is Weapons:return failed("Compose native player, combat and weapon owners")
	if player.selected41_construction_owner()!=_world.construction_owner().npc_construction_owner() or combat.selected41_world_owner()!=_world or weapons._selected41_world!=_world:return failed("Composition changed the initialized native generation")
	var random: RefCounted=load("res://src/simulation/seeded_random.gd").new()
	if not random.restore(random_state):return failed(random.error)
	var next:=fork_for_frame()
	next._player=player.fork_for_frame();next._combat=combat.fork_for_frame();next._weapons=weapons.fork_for_frame();next._random=random.snapshot()
	return next

func evaluate(milliseconds: Variant,player_pose: Variant,display_available:=true) -> RefCounted:
	var contacts:=evaluate_contacts(milliseconds,player_pose,display_available)
	if contacts==null:return null
	var sequence: RefCounted=contacts.evaluate_sequence()
	if sequence==null:return failed(contacts.error)
	var result: RefCounted=sequence.evaluate_motion()
	if result==null:return failed(sequence.error)
	return result

## Contacts/radio end before the parent's result visit. The sequence flag is
## still the preceding completed frame's flag, including on its release tick.
func evaluate_contacts(milliseconds: Variant,player_pose: Variant,display_available:=true) -> RefCounted:
	error=""
	if _state.is_empty() or _stage!="ready" or not Numbers.integer(milliseconds,0,_max_ms) or _state.elapsed_ms>2147483647-milliseconds or not Flight.rigid_pose(player_pose):return failed("Invalid source41 NPC contact frame")
	if _combat.selected41_world_owner()!=_world or _control.selected41_world_owner()!=_world:return failed("Source41 radio/NPC frame changed its initialized generation")
	var observed_result:=result_observation()
	var combat: RefCounted=_combat.fork_for_frame()
	if not combat.begin_contact_pass(_random,display_available):return failed(combat.error)
	var contacts: Dictionary=_weapons.evaluate_selected41_update(_player,player_pose,combat,milliseconds)
	if contacts.is_empty():return failed(_weapons.error)
	var radio: RefCounted=_radio.fork_for_frame()
	var transmissions: Array=radio.step_selected41(_state.elapsed_ms+milliseconds,contacts.combat)
	if not radio.error.is_empty():return failed(radio.error)
	var next:=fork_for_frame()
	next._combat=contacts.combat;next._weapons=contacts.weapons;next._player=contacts.player;next._radio=radio
	next._random=contacts.combat.contact_random_state();next._frame_ms=int(milliseconds);next._stage="contacts"
	next._state.player_pose=player_pose
	next._events={"contacts":contacts.actors,"radio":transmissions,"result_observation":observed_result}
	return next

func evaluate_sequence(preceding_camera: RefCounted=null) -> RefCounted:
	error=""
	if _stage!="contacts":return failed("Visit source41 sequence after contacts exactly once")
	var sequence: RefCounted=_sequence.fork_for_frame()
	if preceding_camera!=null:
		if not is_instance_of(preceding_camera,load("res://src/simulation/camera_rig.gd")):return failed("Sequence composition requires the native preceding camera")
		for key in ["base_content_id","binding_id"]:
			if preceding_camera.snapshot().get(key)!=_state[key]:return failed("Sequence camera belongs to another content identity")
		# Free flight supplies its current response/history before the first cut;
		# the hook alone owns every intermediate cinematic eye and clock.
		if sequence.snapshot().phase in [0,5]:sequence._camera=preceding_camera.fork_for_frame()
	if not sequence.advance(_frame_ms,_radio,_combat,_state.player_pose):return failed(sequence.error)
	var choreography: Dictionary=_control.evaluate_selected41_sequence(sequence,_combat,_weapons)
	if choreography.is_empty():return failed(_control.error)
	var next:=fork_for_frame();var cue: Dictionary=sequence.snapshot()
	next._control=choreography.controller;next._combat=choreography.combat;next._weapons=choreography.weapons
	next._sequence=sequence;next._stage="sequence"
	if cue.frame.cancel_actions or cue.frame.restore_control:
		if not next._player.set_permissions(next._player.snapshot().active,cue.player_damage_allowed):return failed(next._player.error)
	next._random=next._combat.contact_random_state()
	next._events.sequence=cue.frame
	return next

## Late player triggers can compose their changed combat/weapons/player before
## this visit. NPC motion and the camera then consume those same candidates.
func evaluate_motion() -> RefCounted:
	error=""
	if _stage!="sequence":return failed("Visit source41 movement after the late sequence exactly once")
	var state: Dictionary=_player.snapshot()
	var target:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"ship_id":state.ship_id,
		"pose":_state.player_pose,"active":state.active,"hull":state.vitals.hull,"targeting_blocked":false,"special_flight":false,"alternate_position":null}
	var operation: Dictionary=_control.evaluate(_combat,_weapons,_frame_ms,target,_random,_player)
	if operation.is_empty():return failed(_control.error)
	var sequence: RefCounted=_sequence.fork_for_frame()
	if not sequence.finish_camera(_frame_ms,operation.combat,_state.player_pose):return failed(sequence.error)
	var next:=fork_for_frame()
	next._control=operation.controller;next._combat=operation.combat;next._weapons=operation.weapons;next._sequence=sequence
	next._state.revision+=1;next._state.elapsed_ms+=_frame_ms
	next._random=operation.random_state.duplicate(true);next._stage="ready";next._frame_ms=0
	next._events.actors=operation.actors
	return next

func controller_owner() -> RefCounted:return null if _control==null else _control.fork_for_frame(false,_combat)
func camera_owner() -> RefCounted:return null if _sequence==null else _sequence._camera.fork_for_frame()
func random_state() -> Dictionary:return _random.duplicate(true)
func composition_stage() -> String:return _stage
func failed(message: String) -> RefCounted:reject(message);return null

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
## Supply this to the parent's runner BEFORE evaluating the next component
## frame. Original condition25 is adapted only through sequence_complete.
func result_observation() -> Dictionary:
	if _state.is_empty():return {}
	return {"actors":_combat.actor_snapshots(),"sequences":_sequence.result_flags(),"npc_revision":_state.revision}
func completion_condition_observation() -> Dictionary:
	if _state.is_empty():return {}
	return {"kind":25,"parameter":0,"satisfied":_sequence.result_flags().sequence_complete,"npc_revision":_state.revision}
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
	copy._sequence=sequence_owner();copy._stage=_stage;copy._frame_ms=_frame_ms
	return copy
func reject(message: String) -> bool:error=message;return false
