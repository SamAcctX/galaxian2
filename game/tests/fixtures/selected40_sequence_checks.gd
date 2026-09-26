extends RefCounted
## This is a sequence/actor composition, not an earned route or battle win.
## Projectile contacts are sampled separately; uninterrupted choreography does
## not apply damage. All placement, cruise, radio and reserve RNG are native.
const Sequence=preload("res://src/simulation/selected40_sequence.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Rules=preload("res://src/content/selected40_population_definitions.gd")
const Rig=preload("res://src/simulation/camera_rig.gd")
const Aim=preload("res://src/simulation/opening_aim.gd")
const View=preload("res://src/simulation/selected40_view.gd")
const VIEWPORT=Vector2i(1440,900)

static func run(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted,pose: Transform3D) -> Dictionary:
	var check: Callable=host.check
	var pilot: RefCounted=player.fork_for_frame();check.call(pilot.set_permissions(true,true),pilot.error)
	var encounter:=Encounter.new()
	if not encounter.configure_selected40(bindings,cat,library,pilot,scenery,equipment,reputation) or not encounter.prepare_selected40_sequence(bindings,library):check.call(false,encounter.error);return {}
	# This disclosed component seed is not an earned departure camera. The
	# reveal/translate/restore views below are produced by native owners.
	var camera:=Rig.new();var aim:=Aim.new()
	if not camera.configure(bindings) or not aim.configure(bindings):check.call(false,camera.error+aim.error);return {}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye","target":"player","actor_id":-1,"inherit_target_up":true,"eye":pose*Vector3(0,400,-1500)}
	var scene:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"player_pose":pose}
	if not camera.update(0,seed,scene,seed) or not aim.advance(pose,camera.snapshot().pose,VIEWPORT) or not encounter.prepare_selected40_view(bindings,camera,aim,pilot):check.call(false,camera.error+aim.error+encounter.error);return {}
	var parent: Dictionary=encounter.snapshot();var source: Dictionary=scenery.snapshot();var equipment_before: Dictionary=equipment.snapshot()
	var empty_contacts: Dictionary=encounter.evaluate_weapons(pilot,pose,100,scenery,scenery.random_state())
	check.call(not empty_contacts.is_empty(),"Native no-contact weapon pass failed: "+encounter.error)
	if not empty_contacts.is_empty():
		check.call(not empty_contacts.encounter.primary_contacts().is_empty() and not empty_contacts.encounter.primary_npc_contact(),"No-contact weapon record activated NPC feedback")
		var empty_view: Dictionary=empty_contacts.encounter.evaluate_selected40_sequence(100,empty_contacts.random_state,empty_contacts.player,pose,VIEWPORT)
		check.call(not empty_view.is_empty(),empty_contacts.encounter.error)
		if not empty_view.is_empty():check.call(not empty_view.encounter.snapshot().selected40_view.player_aim.contact_active and empty_view.encounter.snapshot().selected40_view.player_aim.visible,"Weapon -> sequence -> view displayed a false contact reticle")
	check.call(encounter.snapshot()==parent,"No-contact view probe mutated the parent encounter")
	check.call(not encounter.prepare_selected40_view(bindings,camera,aim,pilot) and encounter.snapshot()==parent,"Repeated view preparation replaced retained camera history")
	var zero: Dictionary=encounter.evaluate_selected40_sequence(0,scenery.random_state(),pilot,pose,VIEWPORT)
	check.call(not zero.is_empty(),"Native zero-time sequence/view failed: "+encounter.error)
	if not zero.is_empty():
		check.call(zero.encounter.evaluate_selected40_sequence(0,zero.random_state,pilot,pose,VIEWPORT).is_empty(),"Zero-time sequence replay bypassed the actor-frame gate")
		var zero_world: Dictionary=zero.encounter.evaluate_world(pilot,pose,0,zero.random_state)
		check.call(not zero_world.is_empty(),"Zero-time native actor frame failed")
		if not zero_world.is_empty():check.call(zero_world.encounter.evaluate_world(pilot,pose,0,zero_world.random_state).is_empty(),"Zero-time actor frame replay was accepted")
	check.call(encounter.evaluate_selected40_sequence(100,scenery.random_state(),pilot,pose,Vector2i.ZERO).is_empty() and encounter.snapshot()==parent,"Late invalid viewport committed radio, actors or camera")
	check.call(encounter.evaluate_selected40_sequence(100,scenery.random_state()).is_empty() and encounter.snapshot()==parent,"Prepared view allowed its native player to be omitted")
	check.call(encounter._control.evaluate_selected40_sequence(Sequence.new(),encounter._combat,scenery.random_state()).is_empty() and encounter.snapshot()==parent,"Unprepared native sequence changed the controller")
	check.call(not encounter._combat.apply_selected40_sequence(Sequence.new()) and encounter.snapshot()==parent,"Unprepared native sequence changed the cast")
	check.call(not encounter.prepare_selected40_sequence(bindings,library) and encounter.snapshot()==parent,"Repeated choreography replaced native owners")
	check.call(encounter.evaluate_world(pilot,pose,100,scenery.random_state()).is_empty(),"NPC motion ran before radio/choreography")
	for duration in [-1,encounter._selected40_sequence._max_ms+1,0.5,true,null]:
		check.call(encounter.evaluate_selected40_sequence(duration,scenery.random_state()).is_empty() and encounter.snapshot()==parent,"Invalid choreography frame changed retained actors or radio")
	var held: Dictionary=encounter._selected40_sequence.snapshot()
	var foreign: RefCounted=encounter._combat.fork_for_frame();foreign._selected40_world=load("res://src/simulation/opening_world_initialization.gd").new()
	check.call(not encounter._selected40_sequence.advance(100,foreign,scenery.random_state()) and encounter._selected40_sequence.snapshot()==held,"Foreign constructor advanced the radio clock")
	var proof:={"assembly":scenery.world_initialization_owner().snapshot().npc_construction.actors[0].assembly,"times":{},"initial":parent,"snapshots":{}}
	var random: Dictionary=scenery.random_state();var elapsed:=0;var previous_phase:=0
	var revealed: RefCounted;var reserve_parent: RefCounted
	for tick in 2400:
		if elapsed==37000:proof.snapshots.merge(check_auxiliary_reset(host,encounter,random,pilot,pose))
		var cue: Dictionary=encounter.evaluate_selected40_sequence(100,random,pilot,pose,VIEWPORT)
		if cue.is_empty():check.call(false,encounter.error);return {}
		var candidate: RefCounted=cue.encounter;var sequence: Dictionary=cue.sequence
		var view: Dictionary=candidate._selected40_view.snapshot()
		check.call(view.elapsed_ms==sequence.elapsed_ms and view.revision==sequence.revision and view.player_aim.visible==sequence.hud_visible,"Native camera/reticle drifted from its sequence frame")
		var expected_aim: RefCounted=encounter._selected40_view._aim.fork_for_frame()
		check.call(expected_aim.advance(pose,encounter._selected40_view.snapshot().camera.pose,VIEWPORT) and expected_aim.snapshot().point==view.player_aim.point,"Player aim used the new camera instead of the preceding view")
		if sequence.elapsed_ms==45000:proof.snapshots.view_pan=candidate.snapshot()
		if sequence.elapsed_ms==60000:proof.snapshots.player_follow=candidate.snapshot()
		if sequence.phase!=previous_phase:
			proof.times[str(sequence.phase)]=sequence.elapsed_ms
			check.call(sequence.phase==previous_phase+1,"Choreography skipped a source phase")
			check.call(candidate.evaluate_selected40_sequence(100,cue.random_state).is_empty(),"Repeated pre-NPC choreography frame was accepted")
			var changed: Dictionary=candidate.snapshot();var actor: Dictionary=changed.combat.actors[0]
			if sequence.phase==Sequence.Stage.FREIGHTER_VIEW:
				revealed=candidate;proof.snapshots.reveal=changed
				check.call(actor.body_pose.origin==Vector3(-20000,-3000,35000) and actor.actor_mode==1 and actor.active and actor.actor_kind==1,"Reveal did not place and reclassify the original freighter")
				check.call(actor.selected40_revealed and actor.hull_catalogue_id==13 and actor.vitals.hull==1825 and actor.max_hull==1825 and actor.model_draw_enabled,"Reveal rebuilt, healed or hid the Terran hull")
				check.call(sequence.radio.started[3] and not sequence.radio.finished[3] and sequence.input_blocked and not sequence.hud_visible,"Freighter reveal waited for playback finish or omitted cinematic gates")
				check.call(sequence.frame.camera_operations[0].position==Vector3(-27000,-2500,52000) and sequence.frame.cancel_actions and sequence.frame.refresh_geometry_detail,"Reveal lost source camera/action/geometry-detail commands")
				check.call(view.detail_refresh_reference==Vector3(-27000,-2500,52000),"Cinematic geometry refresh lost the immediately translated renderer eye")
				check.call(view.camera.eye==Vector3(-27000,-2500,52000) and view.camera.look==actor.body_pose.origin and view.shot.target=="actor" and not view.player_aim.visible,"Actual reveal camera/reticle did not consume the native cue")
				var hidden: RefCounted=encounter._selected40_view.fork_for_frame()
				check.call(hidden.advance(candidate._selected40_sequence,candidate._combat,pilot,pose,100,VIEWPORT,true) and hidden.snapshot().player_aim.contact_active and not hidden.snapshot().player_aim.visible,"Hidden native reticle dropped an incoming contact")
				var hidden_before: Dictionary=hidden.snapshot()
				check.call(not hidden.advance(candidate._selected40_sequence,candidate._combat,pilot,pose,100,VIEWPORT,false) and hidden.snapshot()==hidden_before,"Replayed sequence mutated its native view")
				var timed: Dictionary=candidate.evaluate_weapons(pilot,pose,400,scenery,cue.random_state)
				check.call(not timed.is_empty(),candidate.error)
				if not timed.is_empty():
					var suppressed: Dictionary=timed.encounter.evaluate_primary_fire(pilot,pose,true,true,timed.random_state)
					check.call(not suppressed.is_empty() and suppressed.encounter.snapshot().primary_fire.is_empty() and suppressed.encounter.snapshot().primaries==timed.encounter.snapshot().primaries and suppressed.random_state==timed.random_state,"Cinematic primary gate trusted caller input or consumed a projectile/RNG draw")
				check.call(candidate._weapons.snapshot()==encounter._weapons.snapshot(),"Reveal rebuilt weapons or their original target membership")
				var contact: Dictionary=candidate.evaluate_weapons(pilot,pose,0,scenery,cue.random_state)
				check.call(not contact.is_empty(),"Reclassified freighter broke shared contacts: "+candidate.error)
			elif sequence.phase==Sequence.Stage.ESCORT:
				check.call(sequence.radio.finished[4] and not sequence.input_blocked and sequence.hud_visible,"Camera restored before original radio4 finished")
				proof.snapshots.restore=changed
				check.call(view.shot.target=="player" and view.camera.mode=="follow" and view.player_aim.visible,"Native player-follow/reticle did not return after radio4")
				var previous: Dictionary=encounter._selected40_view.snapshot()
				var reference: RefCounted=encounter._selected40_view._camera.fork_for_frame();var translated: Dictionary=previous.shot.duplicate(true)
				translated.eye+=Vector3(0,0,-200)
				var restore_scene: Dictionary=scene.duplicate(true);restore_scene.actors=[{"actor_id":0,"pose":actor.body_pose}]
				check.call(reference.update(0,translated,restore_scene,translated),reference.error)
				translated.mode="follow";translated.target="player";translated.actor_id=-1
				check.call(reference.update(100,translated,restore_scene) and reference.snapshot()==view.camera,"Follow restoration discarded the translated freighter view history")
				var ready_to_fire: Dictionary=candidate.evaluate_weapons(pilot,pose,400,scenery,cue.random_state)
				check.call(not ready_to_fire.is_empty(),candidate.error)
				if not ready_to_fire.is_empty():
					var resumed_fire: Dictionary=ready_to_fire.encounter.evaluate_primary_fire(pilot,pose,true,true,ready_to_fire.random_state)
					check.call(not resumed_fire.is_empty() and resumed_fire.encounter.snapshot().primary_fire.weapons[0].result.fired,"Restored player input failed to release the native primary weapon")
			elif sequence.phase==Sequence.Stage.REINFORCEMENTS:
				reserve_parent=encounter;proof.snapshots.reserves=changed
				var expected:=Random.new();check.call(expected.restore(random),expected.error)
				for id in range(9,13):
					var position:=Vector3(-20000,-3000,200000)
					for axis in 3:position[axis]=Vitals.single(Vitals.single(position[axis]-10000.0)+float(expected.next_int(20000)))
					var reserve: Dictionary=changed.combat.actors[id]
					check.call(reserve.body_pose.origin==position and reserve.active and reserve.actor_mode==1,"Reserve activation lost exact XYZ stream/order")
					check.call(encounter._control._flight[id].snapshot().history==candidate._control._flight[id].snapshot().history,"Reserve placement reset bank history")
				check.call(cue.random_state==expected.snapshot(),"Reserve choreography did not consume exactly twelve original draws")
				check.call(encounter.snapshot().combat.actors[9].body_pose.origin==Vector3(-500000,-500000,-500000),"Reserve placement mutated the retained parent")
			elif sequence.phase==Sequence.Stage.ESCAPED:
				proof.snapshots.escaped=changed
				check.call(actor.body_pose.origin==Vector3(0,0,-200000) and not actor.active and actor.actor_mode==1 and actor.vitals.hull==1825,"Escape was treated as destruction, healing or the wrong relocation")
				check.call(actor.model_draw_enabled and actor.selected40_script_retired,"Escape incorrectly changed the original model draw flag")
				check.call(not sequence.radio.started[6],"Radio observed retirement before its own frame order")
			previous_phase=sequence.phase
		var frame: Dictionary=candidate.evaluate_world(pilot,pose,100,cue.random_state)
		if frame.is_empty():check.call(false,candidate.error);return {}
		if sequence.phase==Sequence.Stage.ESCAPED:
			var before: Dictionary=candidate._combat.actor_snapshot(0);var after: Dictionary=frame.encounter._combat.actor_snapshot(0)
			check.call(after.body_pose.origin==before.body_pose.origin+Vector3(0,0,100) and after.pose.origin==after.body_pose.origin,"Inactive escaped freighter stopped receiving its native cruise tick")
			check.call(not after.active and after.actor_mode==1 and after.vitals.hull==1825 and after.model_draw_enabled and after.selected40_script_retired,"Post-escape update reactivated, destroyed or hid the freighter")
			var bad_activity: RefCounted=candidate.fork_for_frame();bad_activity._combat=bad_activity._combat.fork_for_frame()
			bad_activity._combat._writable(0)._state.erase("selected40_script_retired")
			var immutable: Dictionary=candidate.snapshot()
			check.call(bad_activity.evaluate_world(pilot,pose,100,cue.random_state).is_empty() and candidate.snapshot()==immutable,"Inactive cruise bypass accepted an unscripted actor or mutated its parent")
		encounter=frame.encounter;random=frame.random_state;elapsed+=100
		if sequence.phase==Sequence.Stage.ESCAPED and encounter._selected40_sequence.radio_owner().event_state(6).condition_satisfied:
			proof.snapshots.departure_radio=encounter.snapshot();break
	check.call(previous_phase==Sequence.Stage.ESCAPED and proof.snapshots.has("departure_radio"),"Native cruise did not reach retirement and following radio")
	check.call(encounter.snapshot().controller.accounting.events.is_empty() and encounter.snapshot().controller.defeat_status.is_empty(),"Choreography awarded a combat result")
	check.call(scenery.snapshot()==source and equipment.snapshot()==equipment_before and parent.combat.actors[0].actor_kind==0,"Choreography rewrote origin equipment, source field or its parent")
	if revealed!=null:
		var component: RefCounted=revealed._selected40_sequence.radio_owner()
		var combat: RefCounted=revealed._combat.fork_for_frame()
		# Disclosed predicate/lifecycle boundary stimuli, not projectile evidence.
		for hull in [912,911]:
			combat._writable(0)._vitals.configure(hull,0,0)
			var radio: RefCounted=component.fork_for_frame();radio._active=-1;radio._started.fill(true);radio._started[5]=false
			var events: Array=radio.step_selected40(60000,combat)
			check.call(radio.error.is_empty() and radio.event_state(5).condition_satisfied==(hull==911),"Half-hull radio lost strict signed integer division")
		for row in [[59999,1,false],[60000,1,true],[60000,0,false]]:
			combat._writable(0)._state.active=false;combat._writable(0)._vitals.configure(row[1],0,0)
			var radio: RefCounted=component.fork_for_frame();radio._active=-1;radio._started.fill(true);radio._started[6]=false
			radio.step_selected40(row[0],combat)
			check.call(radio.error.is_empty() and radio.event_state(6).condition_satisfied==row[2],"Escape radio lost its inactive/alive/minute conjunction")
		var lost: RefCounted=revealed.fork_for_frame();lost._combat=lost._combat.fork_for_frame();lost._combat._writable(0)._vitals.configure(0,0,0)
		var failure_frame: Dictionary=lost.evaluate_world(pilot,pose,100,revealed._selected40_sequence.snapshot().frame.random_state)
		check.call(not failure_frame.is_empty(),"Revealed Vossk-affiliated Terran freighter lost original breakup resources: "+lost.error)
		if not failure_frame.is_empty():
			var damaged: Dictionary=failure_frame.encounter.snapshot()
			check.call(damaged.combat.actors[0].actor_mode==3 and damaged.combat.actors[0].actor_kind==1 and damaged.controller.accounting.events.size()==1,"Reclassified freighter death bypassed native accounting/animation")
			var dying: RefCounted=failure_frame.encounter;var death_random: Dictionary=failure_frame.random_state
			for step in 100:
				var was_destroyed: bool=dying.snapshot().combat.actors[0].actor_mode==4
				var observed: Dictionary=dying.evaluate_selected40_sequence(100,death_random,pilot,pose,VIEWPORT)
				if observed.is_empty():check.call(false,dying.error);break
				check.call(observed.sequence.failure_observed==was_destroyed,"Failure observation skipped or preceded native completed breakup")
				if was_destroyed:
					check.call(not observed.sequence.radio.started[6],"Destroyed freighter entered the alive-only escape radio")
					proof.snapshots.failure=observed.encounter.snapshot();break
				var advanced: Dictionary=observed.encounter.evaluate_world(pilot,pose,100,observed.random_state)
				if advanced.is_empty():check.call(false,observed.encounter.error);break
				dying=advanced.encounter;death_random=advanced.random_state
			check.call(proof.snapshots.has("failure") and dying.snapshot().controller.accounting.events.size()==1,"Native freighter failure did not follow breakup exactly once")
	if reserve_parent!=null:
		var unchanged: Dictionary=reserve_parent.snapshot();var bad: RefCounted=reserve_parent.fork_for_frame();bad._control=bad._control.fork_for_frame()
		bad._control._flight[12]._definition={}
		check.call(bad.evaluate_selected40_sequence(100,bad._control.snapshot().random_state,pilot,pose,VIEWPORT).is_empty() and reserve_parent.snapshot()==unchanged,"Late reserve motion failure mutated earlier actors or the parent")
	check.call(camera.snapshot()==parent.selected40_view.camera and aim.snapshot()==parent.selected40_view.player_aim,"View composition mutated the supplied camera or aim owner")
	proof.player_pose=pose
	print("Selected40 choreography: native radio -> reveal -> cruise -> four reserves -> portal escape; %d ms; %s; contacts disabled in uninterrupted sequence, explicit contact/death boundary probes"%[elapsed,JSON.stringify(proof.times)])
	return proof

static func check_auxiliary_reset(host: SceneTree,parent: RefCounted,random: Dictionary,pilot: RefCounted,pose: Transform3D) -> Dictionary:
	# Separate live-camera boundary probe. Supplying a rigid camera anchor does
	# not equip an action, change the canonical ship or admit a departure.
	var before: Dictionary=parent.snapshot();var player_before: Dictionary=pilot.snapshot()
	var branch: RefCounted=parent.fork_for_frame()
	branch._selected40_view=parent._selected40_view.fork_for_frame()
	var rig: RefCounted=branch._selected40_view._camera
	if not rig.set_auxiliary_anchor(pose) or not rig.set_auxiliary_enabled(true):host.check(false,rig.error);return {}
	var stream: Dictionary=random.duplicate(true);var shown: Dictionary={};var early: Dictionary={};var world: Dictionary={}
	for tick in 29:
		var active: Dictionary=branch.evaluate_selected40_sequence(100,stream,pilot,pose,VIEWPORT)
		if active.is_empty():host.check(false,branch.error);return {}
		shown=active.encounter.snapshot()
		var current_view: Dictionary=shown.selected40_view
		host.check(current_view.player_render_suppressed==current_view.auxiliary_camera.transition_pending,"Living player draw failed to sample the actual camera latch after each native update")
		if tick==0:early=shown
		world=active.encounter.evaluate_world(pilot,pose,100,active.random_state)
		if world.is_empty():host.check(false,active.encounter.error);return {}
		branch=world.encounter;stream=world.random_state
	var view: Dictionary=shown.selected40_view
	host.check(view.elapsed_ms==39900 and view.auxiliary_camera.enabled and view.auxiliary_camera.travelled>0 and view.auxiliary_camera.initial_distance>0,"Auxiliary reset probe never produced an active native camera")
	host.check(view.camera.eye!=before.selected40_view.camera.eye and view.camera.pose!=before.selected40_view.camera.pose,"Auxiliary mode was an inert flag without a renderer view")
	host.check(not early.selected40_view.player_render_suppressed and view.player_render_suppressed,"Native auxiliary interpolation never crossed the actual visible-to-suppressed draw threshold")
	var pending: RefCounted=world.encounter;var retained: Dictionary=pending.snapshot()
	# Force a late clock-validation fault AFTER the genuine reset command and
	# immediate fixed-eye refresh, not an early argument rejection.
	var broken: RefCounted=pending.fork_for_frame()
	broken._selected40_view=pending._selected40_view.fork_for_frame()
	broken._selected40_view._camera._max_ms=0
	var damaged: Dictionary=broken.snapshot()
	host.check(broken.evaluate_selected40_sequence(100,world.random_state,pilot,pose,VIEWPORT).is_empty() and broken.snapshot()==damaged and pending.snapshot()==retained,"Late cinematic failure leaked an auxiliary reset, radio or actor mutation")
	var reset: Dictionary=pending.evaluate_selected40_sequence(100,world.random_state,pilot,pose,VIEWPORT)
	if reset.is_empty():host.check(false,pending.error);return {}
	var finished: Dictionary=reset.encounter.snapshot();var current: Dictionary=finished.selected40_view
	host.check(current.elapsed_ms==40000 and reset.sequence.frame.reset_follow and not current.auxiliary_camera.enabled and current.auxiliary_camera.travelled==0 and current.auxiliary_camera.initial_distance==0 and not current.auxiliary_camera.transition_pending,"Actual reveal failed to cancel the active auxiliary camera")
	host.check(current.auxiliary_camera.anchor==view.auxiliary_camera.anchor and current.auxiliary_camera.offset==Vector3(0,150,-800),"Cinematic cancellation replaced its anchor or auxiliary offset")
	host.check(current.camera.mode=="fixed_eye" and current.camera.eye==Vector3(-27000,-2500,52000) and current.camera.look==finished.combat.actors[0].body_pose.origin,"Auxiliary cancellation did not precede the actual freighter view")
	host.check(not current.player_render_suppressed,"Cinematic reset did not release the living player's per-frame draw mask")
	host.check(parent.snapshot()==before and pending.snapshot()==retained and pilot.snapshot()==player_before,"Auxiliary probe mutated a retained parent or player")
	print("Selected40 auxiliary boundary: 29 native frames, actual visible-to-hidden draw transition -> cinematic reset40000; late failure rolls back; no equipment/journey mutation")
	return {"auxiliary_pending":early,"auxiliary_probe":shown,"auxiliary_reset":finished}

static func check_camera_draw_mask(host: SceneTree,body: Node3D) -> void:
	var retained: Dictionary=body.selection.duplicate(true);var authored: bool=body.visible
	host.check(body.apply_camera_suppression(true),body.error)
	for level in body.levels:host.check(not level.visible,"Camera mask left an original ship LOD drawable")
	if body.engine_glow!=null:host.check(not body.engine_glow.visible,"Camera mask left original nozzle glow drawable")
	var alternate:={"visible":true,"level":body.levels.size()-1}
	host.check(body.apply_selection(alternate),body.error)
	for level in body.levels:host.check(not level.visible,"LOD update bypassed an active camera mask")
	for invalid in [null,0,1,"false"]:
		host.check(not body.apply_camera_suppression(invalid) and body.selection==alternate,"Invalid camera mask changed the retained LOD")
		for level in body.levels:host.check(not level.visible,"Invalid camera mask partially changed mesh visibility")
	body.hide()
	host.check(body.apply_camera_suppression(false) and not body.visible,"Camera mask release overrode authored root invisibility")
	for index in body.levels.size():host.check(body.levels[index].visible==(index==alternate.level),"Camera release restored the wrong retained LOD")
	host.check(body.apply_selection({"visible":false,"level":-1}),body.error)
	host.check(body.apply_camera_suppression(true) and body.apply_camera_suppression(false),body.error)
	for level in body.levels:host.check(not level.visible,"Releasing camera suppression revived a distance-culled ship")
	if body.engine_glow!=null:host.check(not body.engine_glow.visible,"Releasing camera suppression revived culled engine glow")
	body.visible=authored
	host.check(body.apply_selection(retained) and body.selection==retained,"Camera-mask probe failed to restore original presentation selection")

static func render(host: SceneTree,library: RefCounted,bindings: RefCounted,art: String,proof: Dictionary,captures: String) -> void:
	if proof.is_empty():return
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(art,library.manifest):host.check(false,visuals.error);return
	for name in proof.get("render_names",["auxiliary_pending","auxiliary_probe","auxiliary_reset","reveal","view_pan","restore","player_follow","reserves"]):
		if not proof.snapshots.has(name):continue
		var state: Dictionary=proof.snapshots[name];var id:=9 if name=="reserves" else 0
		var actor: Dictionary=state.combat.actors[id]
		var selections: Dictionary=state.get("native_detail",{}).get("selections",{})
		var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;host.root.add_child(viewport)
		var native_hud: Control
		var native_exhaust: Node3D
		var native_effects: Node3D
		var native_game_over: Control
		var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=1;camera.far=500000
		if proof.get("moving_flight",false):
			var environment: Node3D=load("res://src/presentation/selected40_environment.gd").new();viewport.add_child(environment)
			var native_frame: RefCounted=state.native_flight_frame
			if not environment.configure(library,visuals,bindings,proof.catalogues,native_frame) or not environment.present(native_frame,VIEWPORT):host.check(false,environment.error);viewport.free();continue
			host.check(environment.station.station.transform==native_frame.station_owner().snapshot().pose,"Rendered station changed its original native physical pose")
			host.check(environment.sky.layers.size()==2 and environment.lights.lights.size()>0 and environment.lights.lights.size()==environment.lights.state.lights.size(),"Selected40 environment lost original stars/nebula or source lights")
		else:
			# Isolated actor-constructor captures, not an admitted world scene.
			var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
			var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
		var ship: Node3D=load("res://src/presentation/ship_geometry.gd").new();viewport.add_child(ship)
		var ready: bool=ship.build_population_assembly(proof.assembly,library,visuals,bindings) if id==0 else ship.build(int(actor.hull_catalogue_id),library,visuals,bindings)
		host.check(ready,ship.error)
		if not ready:viewport.free();continue
		ship.transform=actor.body_pose
		host.check(ship.apply_selection(selections.get(id,{"visible":true,"level":0})),ship.error)
		# Source model activity and distance-detail culling are independent.
		# A scripted hidden body does not create an invalid LOD(false,0).
		ship.visible=actor.model_draw_enabled
		host.check(ship.visible==actor.model_draw_enabled,"Freighter ignored native model visibility")
		if name=="reserves":
			# A labelled asset close-up, not a view from the player camera.
			camera.look_at_from_position(actor.body_pose.origin+Vector3(1800,1200,-2600),actor.body_pose.origin)
		else:
			var view: Dictionary=state.selected40_view
			var projection: RefCounted=load("res://src/presentation/flight_camera.gd").new()
			var problem: String=projection.configure(bindings.flight_projection,40,false)
			host.check(problem.is_empty(),problem)
			problem=projection.apply(camera,view.camera);host.check(problem.is_empty(),problem)
			# Node3D stores/reconstructs orientation components. Measure the
			# round trip rather than demand bitwise identity after that step.
			var readback:=camera.global_transform;var orientation_error:=0.0
			for axis in 3:orientation_error=maxf(orientation_error,(readback.basis[axis]-view.camera.pose.basis[axis]).length())
			host.check(readback.origin==view.camera.pose.origin and orientation_error<=0.000001,"Rendered camera changed native position/orientation: "+str(orientation_error))
			print("Selected40 renderer %s: exact eye=%s, maximum basis-column error=%.12f"%[name,str(readback.origin==view.camera.pose.origin),orientation_error])
			for row in state.combat.actors:
				if row.actor_id==0:continue
				var body: Node3D=load("res://src/presentation/ship_geometry.gd").new();viewport.add_child(body)
				host.check(body.build(int(row.hull_catalogue_id),library,visuals,bindings),body.error)
				body.transform=row.body_pose
				host.check(body.apply_selection(selections.get(row.actor_id,{"visible":true,"level":0})),body.error)
				body.visible=row.model_draw_enabled
			var pilot: Node3D=load("res://src/presentation/ship_geometry.gd").new();viewport.add_child(pilot)
			host.check(pilot.build(0,library,visuals,bindings),pilot.error);pilot.transform=state.get("player_pose",proof.player_pose)
			host.check(pilot.apply_selection(selections.get("player",{"visible":true,"level":0})),pilot.error)
			if name in ["auxiliary_pending","orbit_drag"]:check_camera_draw_mask(host,pilot)
			# Camera suppression is an independent draw gate, not a replacement
			# for the retained hull's distance LOD, activity or physical pose.
			var retained_selection: Dictionary=pilot.selection.duplicate(true)
			host.check(pilot.apply_camera_suppression(view.player_render_suppressed),pilot.error)
			host.check(pilot.selection==retained_selection and view.player_render_suppressed==view.auxiliary_camera.transition_pending,"Player draw changed its LOD or ignored the native per-frame camera suppression")
			for level in pilot.levels.size():host.check(pilot.levels[level].visible==(retained_selection.visible and retained_selection.level==level and not view.player_render_suppressed),"Native player mesh ignored combined camera/LOD visibility")
			if pilot.engine_glow!=null:host.check(pilot.engine_glow.visible==(retained_selection.visible and not view.player_render_suppressed),"Player nozzle glow bypassed the native camera draw mask")
			if state.has("scenery"):
				var field: Dictionary=state.scenery
				var scenery: Node3D=load("res://src/presentation/scenery_geometry.gd").new();viewport.add_child(scenery)
				host.check(scenery.build(field,library,visuals,bindings,"high",true),scenery.error)
				host.check(scenery.apply_state(field) and scenery.apply_activity(field.bodies) and scenery.apply_detail(field.detail),scenery.error)
			if proof.get("moving_flight",false):
				native_hud=load("res://src/presentation/selected40_hud.gd").new();viewport.add_child(native_hud);native_hud.size=Vector2(VIEWPORT)
				var frame: RefCounted=state.native_flight_frame
				if not native_hud.configure(library,bindings,visuals,frame) or not native_hud.present(frame):host.check(false,native_hud.error);viewport.free();continue
				check_hud(host,native_hud,frame)
				native_exhaust=load("res://src/presentation/selected40_exhaust.gd").new();viewport.add_child(native_exhaust)
				if not native_exhaust.configure(library,bindings,visuals,frame) or not native_exhaust.present(frame):host.check(false,native_exhaust.error);viewport.free();continue
				native_effects=load("res://src/presentation/selected40_effects.gd").new();viewport.add_child(native_effects)
				if not native_effects.configure(library,bindings,visuals,frame) or not native_effects.present(frame):host.check(false,native_effects.error);viewport.free();continue
				var destruction: Dictionary=frame.destruction_owner().snapshot()
				if name in ["death_fade","death_game_over"]:
					native_game_over=load("res://src/presentation/game_over_panel.gd").new();viewport.add_child(native_game_over);native_game_over.size=Vector2(VIEWPORT)
					if not native_game_over.configure(library,bindings,visuals,frame.destruction_owner()) or not native_game_over.present(frame.destruction_owner(),state.selected40_sequence.elapsed_ms):host.check(false,native_game_over.error);viewport.free();continue
					native_game_over.set_active(false)
					var screen: Dictionary=native_game_over.snapshot()
					host.check(screen.image_rect.size==Vector2(147,68) and screen.prompt_visible==(name=="death_game_over") and screen.continue_enabled==(name=="death_game_over"),"Selected40 game over lost original desktop sizing, fade or Continue gate")
					host.check(screen.alpha_byte==(255 if name=="death_game_over" else 127),"Selected40 game-over art ignored its native destruction alpha")
				pilot.visible=destruction.body_visible
				if destruction.phase!="ready" and pilot.engine_glow!=null:pilot.engine_glow.visible=false
				host.check(pilot.visible==destruction.body_visible and native_effects.explosion.body_visible==destruction.body_visible,"Original player body and explosion disagreed at native breakup")
				# Original EMP geometry reads the retained native launcher even
				# after its last paid ammunition slot has disappeared.
				var secondary_owner: RefCounted=frame.encounter_owner().secondary_owner()
				var secondary_geometry: Node3D=load("res://src/presentation/secondary_geometry.gd").new();viewport.add_child(secondary_geometry)
				if not secondary_geometry.build(secondary_owner,library,visuals,bindings):host.check(false,secondary_geometry.error);viewport.free();continue
				var effect: Dictionary=secondary_geometry.prepare_world(secondary_owner,view.camera.pose)
				if effect.is_empty():host.check(false,secondary_geometry.error);viewport.free();continue
				secondary_geometry.commit_world(effect)
				host.check(secondary_geometry.error.is_empty(),secondary_geometry.error)
				var shot: Dictionary=secondary_owner.snapshot().guns[0].bomb.shot
				host.check(secondary_geometry.bodies[0].visible==(shot.get("phase")=="flying"),"Native EMP renderer lost the actual projectile lifetime")
				if secondary_geometry.bodies[0].visible:host.check(secondary_geometry.bodies[0].transform.origin==shot.position,"Native EMP renderer replaced its physical position")
				if name.begins_with("emp_"):
					var secondary_panel: Control=load("res://src/presentation/secondary_weapon_panel.gd").new();viewport.add_child(secondary_panel);secondary_panel.size=Vector2(VIEWPORT)
					if not secondary_panel.configure(library,bindings,visuals) or not secondary_panel.present(frame.secondary_feedback()):host.check(false,secondary_panel.error);viewport.free();continue
					secondary_panel.set_interaction(not state.selected40_sequence.input_blocked,false)
					secondary_panel.set_hud_visible(state.selected40_sequence.hud_visible)
					# Compose with the already accepted HUD occupancy; do not move
					# its gauges/messages or rewrite the shared secondary widget.
					var occupied: Dictionary=native_hud.visible_state()
					var inset: float=maxf(occupied.gauges_bottom,maxf(occupied.notice_rect.end.y,occupied.radio_rect.end.y))
					secondary_panel.set_top_inset(inset+8)
					await host.process_frame;await host.process_frame
					var secondary_state: Dictionary=secondary_panel.snapshot()
					if secondary_panel.visible:
						host.check(secondary_state.panel_rect.position.y>=occupied.gauges_bottom and not secondary_state.panel_rect.intersects(occupied.notice_rect) and not secondary_state.panel_rect.intersects(occupied.radio_rect),"Native secondary feedback covers accepted gauges or messages")
						host.check(Rect2(Vector2.ZERO,Vector2(VIEWPORT)).encloses(secondary_state.panel_rect),"Native secondary feedback escapes the actual viewport")
					host.check(secondary_panel.visible==state.selected40_sequence.hud_visible,"EMP feedback ignored the native cinematic HUD gate")
			else:
				var reticle: Control=load("res://src/presentation/flight_aim_reticle.gd").new();viewport.add_child(reticle)
				reticle.size=Vector2(VIEWPORT)
				host.check(reticle.prepare(library,bindings,visuals),reticle.error)
				host.check(reticle.present(view.player_aim),reticle.error)
				host.check(reticle.visible==state.selected40_sequence.hud_visible,"Original reticle sprite ignored the cinematic visibility gate")
		var title:=Label.new();title.position=Vector2(24,20);title.add_theme_font_size_override("font_size",22);viewport.add_child(title)
		title.text="SELECTED 40 | NATIVE %s\n%d ms | Original model; actual scripted body pose, mode %d, hull %d\nCamera/aim/actor composition; no journey, battle success or successor save.\n%s"%[name.to_upper(),state.selected40_sequence.elapsed_ms,actor.actor_mode,actor.vitals.hull,"Retained native camera and original reticle; all thirteen actor bodies." if id==0 else "Reserve close-up; position comes from twelve original shared RNG draws."]
		if name.begins_with("auxiliary_"):
			title.text="SELECTED 40 | NATIVE %s | %d ms\nExplicit rigid-anchor camera probe -> actual cinematic cancellation.\nOriginal models and unchanged player; no equipped action, departure or result."%[name.to_upper(),state.selected40_sequence.elapsed_ms]
		if proof.get("moving_flight",false):
			title.position=Vector2(24,824);title.add_theme_font_size_override("font_size",16)
			title.text="NATIVE SELECTED40 | %s | %d ms | Controls %s\nOriginal HUD art, live vitals/cargo/radio; scanner not fitted. Component only: no admitted journey or result."%[name.to_upper(),state.selected40_sequence.elapsed_ms,"blocked" if state.selected40_sequence.input_blocked else "enabled"]
			if name.begins_with("asteroid_"):
				title.text="NATIVE SELECTED40 | %s | %d ms\nSeparate initial-heading component: native zero-throttle flight, unchanged position/loadout. No mining or mission result."%[name.to_upper(),state.selected40_sequence.elapsed_ms]
			if name.begins_with("emp_"):
				title.text="NATIVE SELECTED40 | %s | %d ms\nReal paid EMP input, original projectile/burst and retained ammunition. Separate component run; no grants or mission result."%[name.to_upper(),state.selected40_sequence.elapsed_ms]
			if name.begins_with("death_"):
				title.text="NATIVE SELECTED40 | %s | world %d ms | death %d ms\nDetached lethal-contact test: original effects, native clocks and frozen camera. No earned death, journey or mission result."%[name.to_upper(),state.selected40_sequence.elapsed_ms,state.player_destruction.elapsed_ms]
		var subtitle:=Label.new();subtitle.position=Vector2(24,780);subtitle.size=Vector2(1392,100);subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.add_theme_font_size_override("font_size",22);viewport.add_child(subtitle)
		subtitle.text=state.selected40_sequence.radio.get("text","") if state.selected40_sequence.radio.visible else ""
		if proof.get("moving_flight",false):subtitle.visible=false
		await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image();host.check(image!=null and not image.is_empty(),"Native sequence model did not render")
		if image!=null and not captures.is_empty():host.check(image.save_png(captures.path_join("%s-%s.png"%[proof.get("capture_prefix","selected40-sequence"),name]))==OK,"Could not retain native choreography image")
		if native_game_over!=null:
			var native_before: Dictionary=state.native_flight_frame.snapshot()
			native_game_over.hide()
			await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
			var without_panel: Image=viewport.get_texture().get_image()
			host.check(image.get_data()!=without_panel.get_data(),"Original selected40 game-over panel produced no actual pixels")
			if not captures.is_empty():host.check(without_panel.save_png(captures.path_join("selected40-flight-%s-no-panel.png"%name))==OK,"Could not retain original game-over pixel comparison")
			native_game_over.show()
			host.check(state.native_flight_frame.snapshot()==native_before,"Game-over drawing advanced the native world")
		if native_exhaust!=null and name=="moving":await check_exhaust_pixels(host,viewport,native_exhaust,state.native_flight_frame,image,captures)
		if native_effects!=null and name in ["death_trail","death_explosion"]:await check_destruction_pixels(host,viewport,native_effects,state.native_flight_frame,image,captures,name)
		if native_effects!=null and name=="death_explosion":check_destruction_rollback(host,native_effects,state.native_flight_frame)
		if native_hud!=null and name=="transmission":
			await check_hud_reflow(host,viewport,native_hud,state.native_flight_frame,captures)
		if native_hud!=null:
			var next: RefCounted=state.native_flight_frame.evaluate(0)
			host.check(next!=null,"Native HUD replay probe failed to evaluate a detached zero-time frame")
			if next!=null:
				host.check(native_hud.present(next),native_hud.error)
				var shown: Dictionary=native_hud.snapshot()
				host.check(not native_hud.present(state.native_flight_frame) and native_hud.snapshot()==shown,"HUD accepted an older native revision")
		# Replay/late-rejection probes follow the capture: a zero-time revision
		# can still consume camera input, so it must not replace the named view.
		if native_exhaust!=null:check_exhaust(host,native_exhaust,state.native_flight_frame)
		viewport.free()

static func check_destruction_pixels(host: SceneTree,viewport: SubViewport,effects: Node3D,frame: RefCounted,shown: Image,captures: String,name: String) -> void:
	var native: Dictionary=frame.snapshot();var sample: Dictionary=effects.snapshot()
	var count:=0
	for amount in effects.sprites.frame.counts:count+=int(amount)
	host.check(count>0 or effects.explosion.visible,"Native destruction supplied no drawable original effects")
	effects.hide()
	await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
	var hidden: Image=viewport.get_texture().get_image()
	if not captures.is_empty():host.check(hidden.save_png(captures.path_join("selected40-flight-%s-no-effects.png"%name))==OK,"Could not retain same native destruction frame without its effects")
	var left: Image=shown.duplicate();var right: Image=hidden.duplicate()
	left.resize(512,320,Image.INTERPOLATE_NEAREST);right.resize(512,320,Image.INTERPOLATE_NEAREST)
	left.convert(Image.FORMAT_RGBA8);right.convert(Image.FORMAT_RGBA8)
	var a:=left.get_data();var b:=right.get_data();var changed:=0
	for offset in range(0,a.size(),4):
		if a[offset]!=b[offset] or a[offset+1]!=b[offset+1] or a[offset+2]!=b[offset+2]:changed+=1
	host.check(changed>0,"Original destruction renderer produced no actual pixels in the retained native view")
	effects.show()
	host.check(frame.snapshot()==native and effects.snapshot()==sample,"Destruction pixel comparison altered native clocks, geometry or RNG")
	print("Selected40 original %s: %d live sprites, explosion=%s, %d changed pixels at512x320; same camera and no simulation tick"%[name,count,str(effects.explosion.visible),changed])

static func check_destruction_rollback(host: SceneTree,effects: Node3D,frame: RefCounted) -> void:
	var native: Dictionary=frame.snapshot();var sample: Dictionary=effects.snapshot()
	var meshes: Array=effects.sprites.items.map(func(item):return item.node.mesh)
	host.check(effects.present(frame) and effects.snapshot()==sample and effects.sprites.items.map(func(item):return item.node.mesh)==meshes,"Passive destruction replay rebuilt meshes or advanced native clocks")
	var next: RefCounted=frame.evaluate(0,Vector2.ZERO,frame.frame_context().throttle)
	if next==null:host.check(false,frame.error);return
	var duration: int=effects.explosion._descriptor.effect.duration_ms
	effects.explosion._descriptor.effect.duration_ms=-1
	host.check(not effects.present(next) and effects.snapshot()==sample and effects.sprites.items.map(func(item):return item.node.mesh)==meshes,"Late explosion rejection committed already prepared particle meshes")
	effects.explosion._descriptor.effect.duration_ms=duration
	host.check(effects.present(next),effects.error)
	var accepted: Dictionary=effects.snapshot()
	host.check(not effects.present(frame) and effects.snapshot()==accepted,"Original effect renderer accepted an older native revision")
	var foreign: RefCounted=next.fork_for_frame();foreign._presentation_identity=RefCounted.new()
	host.check(not effects.present(foreign) and effects.snapshot()==accepted and frame.snapshot()==native,"Foreign destruction renderer input changed accepted state")

static func check_exhaust_pixels(host: SceneTree,viewport: SubViewport,exhaust: Node3D,frame: RefCounted,with_exhaust: Image,captures: String) -> void:
	var native: Dictionary=frame.snapshot();var sample: Dictionary=exhaust.snapshot()
	var count:=0
	for value in exhaust.sprites.frame.counts:count+=int(value)
	host.check(count>0,"Moving native flight did not produce any drawable original exhaust sprites")
	exhaust.hide()
	await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
	var without_exhaust: Image=viewport.get_texture().get_image()
	if not captures.is_empty():host.check(without_exhaust.save_png(captures.path_join("selected40-flight-moving-no-exhaust.png"))==OK,"Could not retain the same native frame without its exhaust renderer")
	# Compare the same camera/geometry/frame at a bounded diagnostic resolution;
	# do not zoom, move the ship or fabricate brighter replacement particles.
	var left: Image=with_exhaust.duplicate();var right: Image=without_exhaust.duplicate()
	left.resize(512,320,Image.INTERPOLATE_BILINEAR);right.resize(512,320,Image.INTERPOLATE_BILINEAR)
	var changed:=0
	for y in 320:
		for x in 512:
			if left.get_pixel(x,y)!=right.get_pixel(x,y):changed+=1
	host.check(changed>0,"Original exhaust quads produced no actual pixels in the native moving-flight view")
	exhaust.show()
	host.check(frame.snapshot()==native and exhaust.snapshot()==sample,"Exhaust pixel comparison changed native state, camera, ages or private RNG")
	print("Selected40 original exhaust: %d live sprites across four native nozzles; %d changed pixels at512x320, same player/camera and no simulation tick"%[count,changed])

static func check_exhaust(host: SceneTree,exhaust: Node3D,frame: RefCounted) -> void:
	var sample: Dictionary=exhaust.snapshot();var native: Dictionary=frame.snapshot()
	host.check(sample.engine_particles==native.player_engines and sample.elapsed_ms==native.elapsed_ms,"Rendered exhaust substituted a particle clock, seed or population")
	host.check(exhaust.sprites.items.size()==4,"Betty exhaust did not render the four original nozzle owners")
	for index in exhaust.sprites.items.size():
		var item: Dictionary=exhaust.sprites.items[index]
		host.check(item.kind=="exhaust" and item.key=="player_nozzle%d"%index and item.preset.preset_id==29+index,"Exhaust renderer changed original nozzle/preset ordering")
		host.check(item.node.visible==(exhaust.sprites.frame.counts[index]>0),"Exhaust mesh ignored its native active sprite count")
		if item.node.mesh!=null:host.check(item.node.mesh.surface_get_array_len(0)==4*exhaust.sprites.frame.counts[index],"Original exhaust lost stable four-vertex sprite batching")
	var meshes: Array=exhaust.sprites.items.map(func(item):return item.node.mesh)
	host.check(exhaust.present(frame) and exhaust.snapshot()==sample and meshes==exhaust.sprites.items.map(func(item):return item.node.mesh),"Passive exhaust replay rebuilt meshes or advanced a native emitter")
	host.check(not exhaust.present(null) and exhaust.snapshot()==sample,"Invalid exhaust input replaced the displayed native plume")
	var next: RefCounted=frame.evaluate(0,Vector2.ZERO,native.throttle)
	host.check(next!=null,frame.error)
	if next!=null:
		var last: Dictionary=exhaust.sprites.items.back();var material: int=last.node.get_meta("source_material_id")
		last.node.set_meta("source_material_id",-1)
		host.check(not exhaust.present(next) and exhaust.snapshot()==sample and meshes==exhaust.sprites.items.map(func(item):return item.node.mesh),"Late nozzle failure partially committed earlier exhaust meshes")
		last.node.set_meta("source_material_id",material)
		host.check(exhaust.present(next),exhaust.error)
		var shown: Dictionary=exhaust.snapshot()
		host.check(not exhaust.present(frame) and exhaust.snapshot()==shown,"Exhaust renderer accepted a regressed native revision")
		host.check(shown.engine_particles==sample.engine_particles,"Zero-time render revision advanced exhaust births, ageing or RNG")
	host.check(frame.snapshot()==native,"Passive exhaust rendering changed the retained native flight")

static func check_hud_reflow(host: SceneTree,viewport: SubViewport,hud: Control,frame: RefCounted,captures: String) -> void:
	var native: Dictionary=frame.snapshot();var sample: Dictionary=hud.snapshot()
	host.check(sample.elapsed_ms==12100 and sample.radio.visible and sample.flight_notices.visible,"Overlap proof lost the actual simultaneous transmission/notice frame")
	for size in [Vector2i(960,540),Vector2i(640,360),Vector2i(320,180),VIEWPORT]:
		viewport.size=size;hud.size=Vector2(size)
		await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
		var shown: Dictionary=hud.visible_state();var bounds:=Rect2(Vector2.ZERO,Vector2(size))
		host.check(bounds.encloses(shown.notice_rect) and bounds.encloses(shown.radio_rect) and not shown.notice_rect.intersects(shown.radio_rect),"Native resized radio/notice overlaps or escapes the landscape viewport: "+str(size))
		host.check(shown.radio_rect.position.y>=shown.gauges_bottom,"Resized radio obscures the native hull/armor corner")
		host.check(hud.snapshot()==sample and frame.snapshot()==native,"Passive resize changed a native frame, transmission, acquisition or notice clock")
		var row: Dictionary=hud._layers[hud._front]
		host.check(row.notice._bar.get_rect().encloses(row.notice._label.get_rect()) and row.notice._label.get_content_height()<=row.notice._label.size.y,"Resized equipment notice clips its text")
		if size==Vector2i(640,360) and not captures.is_empty():
			host.check(viewport.get_texture().get_image().save_png(captures.path_join("selected40-flight-transmission-compact.png"))==OK,"Could not retain compact simultaneous radio/notice image")
	# A zero-time native revision exchanges the prepared layers, not the message.
	var row: Dictionary=hud._layers[hud._front]
	row.radio._body.get_v_scroll_bar().value=row.radio._body.get_v_scroll_bar().max_value
	var scroll: float=row.radio._body.get_v_scroll_bar().value
	var next: RefCounted=frame.evaluate(0)
	host.check(next!=null,"Native radio layout replay probe could not produce a zero-time revision")
	if next!=null:
		host.check(hud.present(next),hud.error)
		await host.process_frame;await host.process_frame
		var active: Dictionary=hud._layers[hud._front]
		host.check(active.radio._body.get_v_scroll_bar().value==scroll,"Prepared HUD layer exchange reset the retained transmission scroll")
		host.check(next.hud_state().radio==sample.radio and next.hud_state().flight_notices==sample.flight_notices,"Zero-time layout probe altered the native radio or notice timing")
		host.check(frame.snapshot()==native,"Radio layout probe mutated its parent native flight")

static func check_hud(host: SceneTree,hud: Control,frame: RefCounted) -> void:
	var sample: Dictionary=frame.hud_state();var shown: Dictionary=hud.visible_state()
	host.check(hud.snapshot()==sample,"Rendered HUD replaced native frame state")
	for key in ["gauges","target","reticle"]:host.check(shown[key]==sample.hud_visible,"Cinematic gate lost native "+key)
	host.check(shown.markers==sample.npc_scanner.visible and shown.radio==sample.radio.visible,"Scanner or radio inherited the wrong visibility gate")
	host.check(shown.scan==(sample.hud_visible and sample.mining_targeting.visible) and shown.notice==(sample.hud_visible and sample.flight_notices.visible),"Asteroid acquisition or notices lost their native cinematic visibility")
	if sample.hud_visible and sample.mining_targeting.animation_frame>=0:host.check(shown.scan_rect.has_area(),"Native asteroid acquisition did not draw its original filmstrip")
	if shown.notice:host.check(shown.notice_text==sample.flight_notices.current.text and is_equal_approx(shown.notice_alpha,float(sample.flight_notices.alpha)/255.0),"Original equipment notice changed its accepted text or fade")
	if shown.notice and shown.radio:
		host.check(shown.notice_rect.has_area() and shown.radio_rect.has_area() and not shown.notice_rect.intersects(shown.radio_rect),"Simultaneous native transmission covers the equipment notice")
		host.check(shown.radio_rect.position.y>=shown.notice_rect.end.y,"Radio did not reserve the native notice bar")
	if shown.radio:host.check(shown.radio_rect.position.y>=shown.gauges_bottom,"Transmission overlaps the retained player gauges")
	if not sample.hud_visible:
		host.check(shown.notice_rect==Rect2() and shown.gauges_bottom==0.0 and hud._layers[hud._front].radio._top_inset==0.0,"Cinematic hiding retained stale notice or gauge spacing")
	host.check(shown.hull_text=="%d/%d"%[sample.player.vitals.hull,sample.player.max_hull] and shown.cargo_text=="%d / %dt"%[sample.cargo.used,sample.cargo.capacity],"Original gauges show fabricated player or cargo totals")
	if sample.radio.visible:host.check(shown.transmission==sample.radio.text and not shown.speaker.is_empty() and shown.portrait,"Live transmission lost its source text, speaker or original portrait")
	var front: int=hud._front
	host.check(hud.present(frame) and hud._front==front and hud.snapshot()==sample,"Repeated HUD draws advanced or replaced native state")
	host.check(not hud.present(RefCounted.new()) and hud.snapshot()==sample and hud.visible_state()==shown,"HUD accepted a detached display dictionary/owner")
	var foreign: RefCounted=frame.fork_for_frame();foreign._presentation_identity=RefCounted.new()
	host.check(not hud.present(foreign) and hud.snapshot()==sample and hud.visible_state()==shown,"HUD accepted a different moving-flight generation")
	# Failure after staging gauges, reticle and markers must not replace the
	# previously visible layer. This is a UI fault probe, not campaign progress.
	var next: RefCounted=frame.evaluate(0)
	if next==null:host.check(false,frame.error);return
	var staged: Dictionary=hud._layers[1-front]
	var identity: Dictionary=staged.radio._identity.duplicate()
	staged.radio._identity.binding_id="0".repeat(64)
	host.check(not hud.present(next) and hud.snapshot()==sample and hud.visible_state()==shown and hud._layers[front].root.visible and not staged.root.visible,"Late radio rejection partially replaced the on-screen HUD")
	staged.radio._identity=identity
	var notice_identity: Dictionary=staged.notice._identity.duplicate()
	staged.notice._identity.binding_id="0".repeat(64)
	host.check(not hud.present(next) and hud.snapshot()==sample and hud.visible_state()==shown and hud._layers[front].root.visible and not staged.root.visible,"Last-phase notice rejection partially changed the visible scan, gauges or radio")
	staged.notice._identity=notice_identity
	var scan_source: Dictionary=staged.scan._source.duplicate()
	staged.scan._source.binding_id="0".repeat(64)
	host.check(not hud.present(next) and hud.snapshot()==sample and hud.visible_state()==shown,"Rejected asteroid filmstrip changed the accepted HUD")
	staged.scan._source=scan_source
	host.check(frame.hud_state()==sample,"Rendering mutated native flight or radio time")
