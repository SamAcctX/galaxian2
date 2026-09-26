extends RefCounted
## Detached original-world test: accelerated radio clock and independently
## placed statistics are disclosed stimuli, not an input-earned mission41 run.
const NPC=preload("res://src/simulation/selected41_npc_combat.gd")
const Sequence=preload("res://src/simulation/selected41_sequence.gd")
const Rules=preload("res://src/content/selected41_population_definitions.gd")
const Dialogue=preload("res://src/content/dialogue_definitions.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")

static func run(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,visuals: RefCounted,world: RefCounted,other: RefCounted) -> void:
	var original: Dictionary=world.snapshot();var retained: Dictionary=world.entry_owner().snapshot()
	var npc:=NPC.new()
	if not npc.prepare(bindings,cat,library,world):host.check(false,npc.error);return
	var initial: Dictionary=npc.snapshot();var pose: Transform3D=initial.player_pose
	var sequence: RefCounted=npc.sequence_owner();var initial_sequence: Dictionary=sequence.snapshot()
	host.check(initial_sequence.camera==world.camera_owner().snapshot() and initial_sequence.phase==0 and initial_sequence.complete_cinematic_supported and not initial_sequence.sequence_complete,"Source41 sequence replaced arrival camera or completed before its cinematic")
	for bad in [null,RefCounted.new()]:
		host.check(not sequence.advance(0,npc.radio_owner(),bad,pose) and sequence.snapshot()==initial_sequence,"Unrelated combat drove source41 choreography")
	var foreign:=NPC.new();host.check(foreign.prepare(bindings,cat,library,other),foreign.error)
	host.check(not sequence.advance(0,npc.radio_owner(),foreign.combat_owner(),pose) and sequence.snapshot()==initial_sequence,"Equal-context regenerated bodies drove source41 choreography")
	# A real lethal hit enters the ordinary native destruction and accounting
	# pass before the cinematic. Reset must revive this SAME fighter identity.
	var damaged: RefCounted=npc.fork_for_frame()
	var hit: Dictionary=damaged._combat._writable(1).normal_hit(2147483647,true)
	if hit.is_empty():host.check(false,damaged._combat.error);return
	var dying: RefCounted=damaged.evaluate(1,pose,false)
	if dying==null:host.check(false,damaged.error);return
	damaged=dying.fork_for_frame()
	damaged._control=damaged._control.fork_for_frame()
	host.check(damaged.snapshot().controller.accounting.events.size()==1 and damaged.combat_owner().actor_snapshot(1).vitals.hull==0,"Attack reset probe did not create an actual recorded fighter death")
	var actor: RefCounted=damaged._combat._writable(2)
	host.check(not actor.systems_hit(2147483647).is_empty() and actor.advance_systems(123),actor.error)
	host.check(actor.snapshot().systems.disabled and actor.snapshot().systems.elapsed_ms==123,"Attack reset probe did not retain a live systems recovery clock")
	# Disclosed dirty controller state probes fields that the original reset
	# intentionally RETAINS. These are not claims of player-earned boosting.
	var guidance: RefCounted=damaged._control._guidance[2]
	guidance._state.selection_elapsed_ms=321;guidance._state.boost_elapsed_ms=123
	guidance._state.boost_active=true;guidance._state.boost_duration_ms=10000
	guidance._state.speed_target=4.0;guidance._state.damage_accumulated=99;guidance._state.damage_boost=true
	damaged._control._flight[2]._bank=0.2;damaged._control._flight[2]._target_bank=0.4
	damaged._control._flight[2]._history[0]=0.25
	# Allocate an actual native projectile; no fabricated pool snapshot.
	var gun: RefCounted=damaged._weapons._guns[3]
	host.check(not gun.advance(1).is_empty(),gun.error)
	var gun_pose: Transform3D=damaged.combat_owner().actor_snapshot(3).pose
	var fired: Dictionary=damaged._weapons.fire_selected41(damaged._combat,damaged._player,[{"actor_id":3,"target_actor_id":0,"pose":gun_pose}])
	if fired.is_empty() or not fired.actors[0].outcome.fired:host.check(false,"Attack reset failed to allocate its real projectile stimulus: "+damaged._weapons.error);return
	var next_handle: int=damaged._weapons._guns[3]._next_id
	# Drive the actual scheduler through the first four messages, then move
	# ONLY freighter statistics to the radio boundary. Physical placement is
	# deliberately different, catching a wrong-coordinate cinematic origin.
	var radio: RefCounted=damaged.radio_owner();var time:=80000
	var rules: Dictionary=Dialogue.select(bindings,41)
	for event in 4:
		host.check(radio.step_selected41(time,damaged._combat)==[{"kind":"started","event":event}],"Attack fixture lost original radio start order")
		var visible: int=time+int(rules.timing.display_delay_ms)+1
		host.check(radio.step_selected41(visible,damaged._combat)==[{"kind":"display","event":event,"text_id":int(rules.events[event].text_id)}],"Attack fixture failed original delayed display")
		time+=int(rules.timing.display_delay_ms)+int(rules.timing.base_duration_ms)+int(rules.timing.per_line_ms)*int(radio._lines[event])+1
		host.check(radio.step_selected41(time,damaged._combat)==[{"kind":"finished","event":event}],"Attack fixture failed original playback finish")
	var freighter: Dictionary=damaged.combat_owner().actor_snapshot(0)
	var statistics: Transform3D=freighter.pose;statistics.origin.z=-100000
	host.check(damaged._combat.set_pose(0,statistics,freighter.body_pose),damaged._combat.error)
	damaged._radio=radio;damaged._state.elapsed_ms=time
	var before: Dictionary=damaged.snapshot()
	var cue_radio: RefCounted=radio.fork_for_frame()
	host.check(cue_radio.step_selected41(time,damaged._combat)==[{"kind":"started","event":4}],"Attack shot did not use event4 START rather than finish")
	sequence=damaged.sequence_owner()
	if not sequence.advance(0,cue_radio,damaged._combat,pose):host.check(false,sequence.error);return
	var cue: Dictionary=sequence.snapshot()
	host.check(cue.phase==1 and cue.input_blocked and not cue.hud_visible and cue.frame.cancel_actions and not cue_radio.event_state(4).playback_finished,"Attack phase0 did not use the source start latch and control flags")
	var prepared: Dictionary=damaged._control.evaluate_selected41_sequence(sequence,damaged._combat,damaged._weapons)
	if prepared.is_empty():host.check(false,damaged._control.error);return
	var reset: Dictionary=prepared.controller.snapshot();var weapons: Dictionary=prepared.weapons.snapshot()
	for id in range(1,4):
		var row: Dictionary=reset.combat.actors[id];var offset: Array=Rules.ATTACK_OFFSETS[id-1]
		var displacement:=Vector3(offset[0],offset[1],offset[2])
		host.check(row.body_pose.origin==freighter.body_pose.origin+displacement and row.pose.origin==freighter.body_pose.origin and row.pose.basis==before.combat.actors[id].body_pose.basis,"Attack reset lost absolute-then-relative root/statistics order")
		host.check(row.body_pose.basis.z.is_equal_approx(Vectors.normalized(-displacement)) and row.body_pose.basis.determinant()>0,"Attack fighter did not aim toward the actual freighter")
		host.check(row.vitals.hull==row.max_hull and row.active and row.damage_allowed and row.actor_mode==1 and row.engine_draw_enabled and row.model_draw_enabled and row.node_draw_requested,"Attack reset did not restore native fighter lifecycle, hull and render flags")
		host.check(row.systems.integrity==row.systems.capacity and not row.systems.disabled and row.script_hostile==before.combat.actors[id].script_hostile,"Attack reset lost systems capacity or persistent faction force")
		host.check(reset.destruction[id].phase=="ready" and weapons.actors[id].projectiles.elapsed_ms==0 and weapons.actors[id].projectiles.slots.all(func(slot):return slot==null),"Attack reset retained old breakup or projectile lifetime")
		host.check(weapons.target_memberships[id]==[0] and prepared.controller._guidance[id]._training.target_memberships[id]==[0],"Attack did not replace both target lists with only the freighter")
	host.check(reset.combat.actors[2].systems.elapsed_ms==123,"Attack systems reset incorrectly zeroed its retained recovery elapsed field")
	for key in ["selection_elapsed_ms","boost_elapsed_ms","boost_active","boost_duration_ms","speed_target"]:
		host.check(prepared.controller._guidance[2]._state[key]==guidance._state[key],"Attack reset erased retained guidance "+key)
	host.check(prepared.controller._guidance[2]._state.damage_accumulated==0 and not prepared.controller._guidance[2]._state.damage_boost and prepared.controller._guidance[2]._state.speed==prepared.controller._guidance[2]._definition.cruise_speed,"Attack failed to restore its represented damage/cruise state")
	host.check(prepared.controller._flight[2]._bank==0.2 and prepared.controller._flight[2]._target_bank==0.4 and prepared.controller._flight[2]._history==damaged._control._flight[2]._history,"Attack reset rerolled or erased untouched banking history")
	host.check(prepared.weapons._guns[3]._next_id==next_handle and reset.accounting.events==before.controller.accounting.events and reset.accounting.counter_deltas==before.controller.accounting.counter_deltas,"Attack reset reused projectile handles or erased already earned accounting")
	for id in [0,4,5,6,7]:host.check(reset.combat.actors[id]==before.combat.actors[id] and weapons.actors[id]==before.weapons.actors[id],"Attack reset modified an unrelated native actor or gun")
	host.check(weapons.selected41.weapon_effects==before.weapons.selected41.weapon_effects and reset.random_state==before.controller.random_state and world.snapshot()==original,"Attack reset regenerated effects, world or shared random stream")
	var offset: Array=Rules.ATTACK_CAMERA_OFFSET
	host.check(cue.camera.eye==freighter.body_pose.origin+Vector3(offset[0],offset[1],offset[2]) and cue.camera.look==freighter.body_pose.origin,"Attack camera used a guessed position instead of the source eye/target")
	host.check(prepared.controller.evaluate_selected41_sequence(sequence,prepared.combat,prepared.weapons).is_empty(),"Repeated cinematic revision reset fighters twice")
	host.check(damaged.snapshot()==before and npc.snapshot()==initial,"Attack preparation mutated retained sibling owners")
	# Integration requires a self-consistent physical/statistics/cruise owner.
	# Accelerate ONLY its native cruise here as an explicit component stimulus;
	# unlike the coordinate-isolation probe above, radio sees the actual body.
	var integration: RefCounted=damaged.fork_for_frame();integration._control=integration._control.fork_for_frame()
	var cruise: RefCounted=integration._control._flight[0]
	var distance:=int(-100000-cruise.snapshot().body_pose.origin.z)
	if distance<0:host.check(false,"Unexpected attack fixture freighter position");return
	while distance>0:
		var step:=mini(distance,100)
		if not cruise.update(step,true):host.check(false,cruise.error);return
		distance-=step
	var placement: Dictionary=cruise.snapshot()
	host.check(integration._combat.set_pose(0,placement.statistics_pose,placement.body_pose),integration._combat.error)
	var integration_before: Dictionary=integration.snapshot()
	# Late failure must roll back the staged radio start, camera, reset, guns
	# and accounting ledger together, not merely return an error afterward.
	var broken: RefCounted=integration.fork_for_frame();broken._control._rules=broken._control._rules.duplicate(true);broken._control._rules.actor_count=9
	var broken_before: Dictionary=broken.snapshot()
	host.check(broken.evaluate(0,pose,false)==null and broken.snapshot()==broken_before and damaged.snapshot()==before,"Late NPC failure leaked the attack transaction")
	var active: RefCounted=integration.evaluate(0,pose,false)
	if active==null:host.check(false,integration.error);return
	var attack: Dictionary=active.snapshot()
	host.check(attack.sequence.phase==1 and attack.radio.started[4] and not attack.player.damage_allowed and attack.events.sequence.reset_fighters.size()==3,"Native frame did not commit radio, attack reset and player damage suppression together")
	var replay: RefCounted=integration.evaluate(0,pose,false)
	host.check(replay!=null and replay.snapshot()==attack and integration.snapshot()==integration_before and damaged.snapshot()==before,"Attack replay consumed a parent or changed RNG")
	# A second native death is allowed only after this exact one-time reset.
	var killed: RefCounted=active.fork_for_frame()
	host.check(not killed._combat._writable(1).normal_hit(2147483647,true).is_empty(),"Could not create post-reset death")
	var killed_next: RefCounted=killed.evaluate(1,pose,false)
	if killed_next==null:host.check(false,killed.error);return
	host.check(killed_next.snapshot().controller.accounting.events.filter(func(event):return event.actor_id==1).size()==2,"Reset fighter death was lost or counted more than once")
	for _frame in 20:
		var next: RefCounted=active.evaluate(100,pose,false)
		if next==null:host.check(false,active.error);return
		active=next
		host.check(active.snapshot().sequence.camera.look==active.combat_owner().actor_snapshot(0).body_pose.origin,"Source41 camera used the pre-motion rather than current freighter target")
	host.check(active.snapshot().sequence.phase==1 and active.snapshot().events.sequence.reset_fighters.is_empty() and active.combat_owner().actor_snapshot(1).body_pose!=attack.combat.actors[1].body_pose,"Attack failed to retain its shot while continuing ordinary NPC motion")
	_complete_sequence(host,active,pose)
	if DisplayServer.get_name()!="headless":await load("res://tests/fixtures/selected41_construction_checks.gd").render(host,library,bindings,visuals,world.construction_owner(),world,active,[],true)
	host.check(world.snapshot()==original and world.entry_owner().snapshot()==retained and npc.snapshot()==initial and damaged.snapshot()==before,"Attack checks changed initialized content, passengers, wallet or canonical parent")
	print("Source41 native SEQUENCE: original attack retained; event5 enables damage effects, stops cruise, protects hull; timed drift/fixed pose, seven existing fighters retarget, timed pullback, player restore and semantic completion; transactional rollback. Detached components, no earned41/Host/result/save acceptance")

static func _complete_sequence(host: SceneTree,attack: RefCounted,pose: Transform3D) -> void:
	# Disclosed radio-finish stimulus, continuing the actual native component.
	# A stopped freighter must never satisfy the semantic completion adapter.
	var later: RefCounted=attack.fork_for_frame()
	later._radio._active=-1;later._radio._finished[4]=true
	later._control=later._control.fork_for_frame()
	later._control._flight[0]._state.speed=0.0;later._combat._writable(0)._state.speed=0.0
	var condition=load("res://src/simulation/mission_result_condition.gd")
	var predicate:={"kind":25,"sequence_flag":"sequence_complete"}
	host.check(not condition.evaluate(predicate,later.result_observation()).satisfied and not later.completion_condition_observation().satisfied,"Incidental zero speed completed the sequence")
	_reject_tail(host,later,pose,"event5")
	var before: Dictionary=later.snapshot()
	var active: RefCounted=later.evaluate(0,pose,false)
	if active==null:host.check(false,later.error);return
	var entered: Dictionary=active.snapshot();var cue: Dictionary=entered.sequence
	host.check(cue.phase==2 and cue.phase_elapsed_ms==0 and entered.radio.started[5] and not entered.radio.finished[5],"Event5 must start the next shot before its playback finishes")
	host.check(cue.effects_enabled==[40,41] and cue.frame.effects.all(func(effect):return effect.enabled) and cue.frame.effects.size()==2,"Event5 removed damage effects instead of enabling them")
	host.check(cue.frame.audio==[{"action":"play","sound_id":155},{"action":"stop_actor_engine","actor_id":0}],"Event5 lost the sound/engine-stop directives")
	host.check(entered.combat.actors[0].vitals.hull==9999999 and entered.combat.actors[0].max_hull==9999999 and not entered.controller.flight[0].cruise_enabled,"Event5 did not protect current/max hull and stop ordinary cruise")
	host.check(entered.combat.actors[0].body_pose==before.combat.actors[0].body_pose and cue.camera.eye==before.combat.actors[0].body_pose.origin+Vector3(-3000,-2000,12000),"Event5 moved the freighter early or misplaced the damage shot")
	host.check(entered.weapons.actors==before.weapons.actors and entered.player.vitals==before.player.vitals and active.player_owner().loadout()==later.player_owner().loadout(),"Event5 reset weapons, player pools or retained loadout")
	var replay: RefCounted=later.evaluate(0,pose,false)
	host.check(replay!=null and replay.snapshot()==entered and later.snapshot()==before,"Event5 replay consumed a parent")
	var start: Transform3D=entered.combat.actors[0].body_pose
	for _step in 150:
		var next: RefCounted=active.evaluate(100,pose,false)
		if next==null:host.check(false,active.error);return
		active=next
	var drift: Dictionary=active.snapshot()
	host.check(drift.sequence.phase==2 and drift.sequence.phase_elapsed_ms==15000 and not active.completion_condition_observation().satisfied,"Drift must last strictly more than 15000ms")
	host.check(drift.combat.actors[0].body_pose.origin.is_equal_approx(start.origin+Vector3(0,-15000,30000)) and drift.combat.actors[0].body_pose.basis.is_equal_approx(start.basis*Basis(Vector3.BACK,0.45)),"Disabled freighter did not drift and roll independently of automatic cruise")
	host.check(drift.sequence.camera.eye==cue.camera.eye and drift.sequence.camera.look==drift.combat.actors[0].body_pose.origin,"Drift shot stopped tracking the current freighter")
	var crossed: RefCounted=active.evaluate(1,pose,false)
	if crossed==null:host.check(false,active.error);return
	active=crossed
	host.check(active.snapshot().sequence.phase==3 and active.snapshot().combat.actors[0].body_pose.origin!=Vector3(2006,-31500,-86720),"Drift crossing skipped the next-frame placement boundary")
	# Retargeting must preserve an injured fighter and every retained projectile,
	# including their elapsed intervals, handles, systems and accounting history.
	var cut: RefCounted=active.fork_for_frame()
	host.check(not cut._combat._writable(2).normal_hit(1,true).is_empty(),"Cannot injure the retained retarget probe")
	var cut_before: Dictionary=cut.snapshot()
	var sequence: RefCounted=cut.sequence_owner()
	if not sequence.advance(0,cut.radio_owner(),cut._combat,pose):host.check(false,sequence.error);return
	var prepared: Dictionary=cut._control.evaluate_selected41_sequence(sequence,cut._combat,cut._weapons)
	if prepared.is_empty():host.check(false,cut._control.error);return
	for id in range(1,8):
		host.check(prepared.combat.actor_snapshot(id)==cut_before.combat.actors[id],"Retarget reset an existing fighter lifecycle/pool/pose")
		host.check(prepared.weapons.snapshot().target_memberships[id]==[-1] and prepared.controller._guidance[id]._training.target_memberships[id]==[-1],"Retarget did not update both native player target lists")
	host.check(prepared.weapons.snapshot().actors==cut_before.weapons.actors and prepared.controller.snapshot().accounting==cut_before.controller.accounting,"Retarget reset weapon state or accounted history")
	host.check(cut.snapshot()==cut_before,"Retarget preparation mutated its parent")
	_reject_tail(host,cut,pose,"fixed pose and retarget")
	var placed: RefCounted=cut.evaluate(0,pose,false)
	if placed==null:host.check(false,cut.error);return
	active=placed
	var fixed: Dictionary=active.snapshot();var fixed_pose: Transform3D=fixed.combat.actors[0].body_pose
	host.check(fixed.sequence.phase==4 and fixed.sequence.phase_elapsed_ms==0 and fixed_pose.origin==Vector3(2006,-31500,-86720) and fixed_pose.basis.is_equal_approx(Basis(Vector3.RIGHT,-0.4)*Basis(Vector3.BACK,1.8)),"Freighter final pose or shot boundary changed")
	host.check(not fixed.combat.actors[0].engine_draw_enabled and not fixed.sequence.shot.inherit_target_up and fixed.sequence.camera.eye==fixed_pose.origin+Vector3(3000,1000,2000),"Final shot lost engine visibility, upright camera or authored eye")
	for _step in 150:
		var next: RefCounted=active.evaluate(100,pose,false)
		if next==null:host.check(false,active.error);return
		active=next
	var pullback: Dictionary=active.snapshot()
	host.check(pullback.sequence.phase==4 and pullback.sequence.phase_elapsed_ms==15000 and pullback.sequence.camera.eye==fixed.sequence.camera.eye+Vector3(15000,15000,-30000),"Pullback must move the eye and last strictly more than 15000ms")
	host.check(pullback.combat.actors[0].body_pose==fixed_pose and not pullback.player.damage_allowed,"Freighter resumed cruise or player damage returned during the shot")
	_reject_tail(host,active,pose,"completion")
	var finished: RefCounted=active.evaluate(1,pose,false)
	if finished==null:host.check(false,active.error);return
	var done: Dictionary=finished.snapshot()
	host.check(done.sequence.phase==5 and done.sequence.sequence_complete and done.sequence.shot.target=="player" and done.sequence.camera.mode=="follow","Final shot failed to restore the native player camera and semantic completion")
	host.check(done.combat.actors[0].vitals.hull==100 and done.combat.actors[0].max_hull==9999999 and done.combat.actors[0].speed==0.0,"Final hull setter lowered capacity or failed to stop the freighter")
	host.check(done.player.damage_allowed and not done.sequence.input_blocked and done.sequence.hud_visible and done.sequence.frame.restore_control and done.sequence.frame.audio==[{"action":"stop","sound_id":156}],"Player control/damage/HUD or completion audio was not restored")
	host.check(done.player.vitals==before.player.vitals and finished.player_owner().loadout()==later.player_owner().loadout(),"Cinematic changed retained player pools/loadout")
	host.check(not condition.evaluate(predicate,done.events.result_observation).satisfied and condition.evaluate(predicate,finished.result_observation()).satisfied,"Parent result poll saw completion early or lacked the next-frame semantic flag")
	var continued: RefCounted=finished.evaluate(0,pose,false)
	if continued==null:host.check(false,finished.error);return
	host.check(continued.snapshot().sequence.phase==5 and continued.snapshot().sequence.frame.actor_actions.is_empty() and continued.snapshot().sequence.frame.audio.is_empty() and not continued.snapshot().sequence.frame.restore_control,"Completed sequence repeated rewards, audio or restore actions")
	host.check(later.snapshot()==before and cut.snapshot()==cut_before,"Later cinematic frames changed retained parent owners")

static func _reject_tail(host: SceneTree,parent: RefCounted,pose: Transform3D,label: String) -> void:
	var broken: RefCounted=parent.fork_for_frame()
	broken._control._rules=broken._control._rules.duplicate(true);broken._control._rules.actor_count=9
	var before: Dictionary=broken.snapshot()
	host.check(broken.evaluate(0 if label!="completion" else 1,pose,false)==null and broken.snapshot()==before,"Late NPC failure leaked "+label+" actions")
