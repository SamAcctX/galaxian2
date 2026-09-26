extends RefCounted
## An uninterrupted native moving-player/contact sequence, not an earned trip.
## All pilot poses come from ordinary controls. No cast teleport, health reset,
## forced AI request or disabled weapon-contact pass is used in the flight run.
const Frame=preload("res://src/simulation/selected40_flight_frame.gd")
const Rig=preload("res://src/simulation/camera_rig.gd")
const Aim=preload("res://src/simulation/opening_aim.gd")
const Sequence=preload("res://src/simulation/selected40_sequence.gd")
const VIEWPORT=Vector2i(1440,900)

static func run(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted,pose: Transform3D,career: RefCounted=null) -> Dictionary:
	var check: Callable=host.check
	var pilot: RefCounted=player.fork_for_frame();check.call(pilot.set_permissions(true,true),pilot.error)
	var camera:=Rig.new();var aim:=Aim.new()
	if not camera.configure(bindings) or not aim.configure(bindings):check.call(false,camera.error+aim.error);return {}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye","target":"player","actor_id":-1,"inherit_target_up":true,"eye":pose*Vector3(0,400,-1500)}
	var camera_context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"player_pose":pose}
	if not camera.update(0,seed,camera_context,seed) or not aim.advance(pose,camera.snapshot().pose,VIEWPORT):check.call(false,camera.error+aim.error);return {}
	var frame:=Frame.new()
	if not frame.configure(bindings,cat,library,pilot,scenery,equipment,reputation,pose,camera,aim,0.5,VIEWPORT):check.call(false,frame.error);return {}
	if career!=null and not frame.prepare_career(bindings,career):check.call(false,frame.error);return {}
	if career!=null:
		load("res://tests/fixtures/selected40_application_checks.gd").check_career_retained(check,frame,career.snapshot(),"before continuous flight")
		load("res://tests/fixtures/selected40_application_checks.gd").check_career_binding(check,frame,bindings,career)
	var secondary_origin: RefCounted=frame.fork_for_frame()
	var original: Dictionary=frame.snapshot();var field: Dictionary=scenery.snapshot();var gear: Dictionary=equipment.snapshot();var parent: Dictionary=pilot.snapshot()
	await check_portal(host,frame,library,bindings,cat,scenery,equipment,reputation,pilot)
	if OS.get_environment("GOF2_SELECTED40_PORTAL_PROBE")=="1":return {"portal_only":true}
	var engine: RefCounted=frame.engine_audio_owner();var retained_engine: Dictionary=engine.snapshot()
	check.call(not engine.configure_selected40(bindings,cat,pilot,pose) and engine.snapshot()==retained_engine,"Retained engine admitted a repeated constructor")
	var engine_selector: RefCounted=load("res://src/simulation/engine_audio.gd").new()
	check.call(engine_selector.configure(bindings,cat),engine_selector.error)
	var chosen: Dictionary=engine_selector.select(int(gear.loadout.ship_id),bindings.opening_actors.player_initialization.repair.initial_upgrades,gear.loadout.equipment_ids)
	check.call(not chosen.is_empty() and retained_engine.initial_source_id==chosen.source_id and retained_engine.parameters==[0.0,0.0,0.0] and retained_engine.position==pose.origin,"Engine selection substituted fresh equipment, position or parameter defaults")
	check.call(engine.sample_commands(Vector2.ONE) and frame.engine_audio_owner().snapshot()==retained_engine,"Detached engine controls mutated the retained world")
	var entry: Dictionary=frame.environment_state().entry
	check.call(entry.station_id==entry.source_before.source_station_id and original.music_context.selected_station_id==entry.station_id and original.music_context.void_source_station_id==entry.source_before.source_station_id,"Music substituted origin equipment location or post-reroll source")
	check.call(original.station_exterior.station_id==entry.station_id and not original.station_exterior.collision.is_empty() and not original.station_exterior.docking_transition_supported,"Native station omitted original volumes or invented docking")
	check.call(not original.radar.scanner_present and original.radar.battle_count==0,"Native radar granted an absent scanner")
	var guarded_radar: RefCounted=frame._radar.fork_for_frame();guarded_radar._scanner_present=true
	var guarded_before: Dictionary=guarded_radar.snapshot()
	check.call(not guarded_radar.publish_without_scanner(true) and guarded_radar.snapshot()==guarded_before,"No-scanner helper silently admitted special radar equipment")
	var held_music: RefCounted=frame.evaluate(100,Vector2.ZERO,1.0,false,false,VIEWPORT,0.0,false,143)
	check.call(held_music!=null and held_music.frame_context().flight_music.operations.is_empty(),"Original intro-hold music was replaced by source-location ambience")
	var retained_music: RefCounted=frame.evaluate(100,Vector2.ZERO,1.0,false,false,VIEWPORT,0.0,false,139)
	check.call(retained_music!=null and retained_music.frame_context().flight_music.operations.is_empty(),"Source peace retention replaced an already accepted peace track")
	for bad_music in [-2,2293]:check.call(frame.evaluate(100,Vector2.ZERO,1.0,false,false,VIEWPORT,0.0,false,bad_music)==null and frame.snapshot()==original,"Invalid playback music input changed the native world")
	var initial_hud: Dictionary=frame.hud_state()
	var initial_exhaust: Dictionary=frame.exhaust_state()
	check.call(initial_exhaust.engine_particles==original.player_engines and initial_exhaust.camera_pose==original.encounter.selected40_view.camera.pose,"Exhaust presentation substituted its native owner or camera")
	var detached_engine: RefCounted=frame.engine_particles_owner()
	check.call(detached_engine.set_engine_enabled(false) and frame.exhaust_state()==initial_exhaust,"Changing a detached exhaust owner mutated the native frame")
	var editable_exhaust: Dictionary=frame.exhaust_state();editable_exhaust.engine_particles.elapsed_ms=-1
	check.call(frame.exhaust_state()==initial_exhaust,"Editing an exhaust snapshot changed its native simulation clock")
	check.call(not initial_hud.is_empty() and initial_hud.player==parent and initial_hud.cargo==gear.cargo,"Native HUD substituted starting vitals or relabelled origin cargo")
	check_scanner(host,frame,bindings)
	check_targeting(host,frame,bindings,library,cat)
	check.call(original.encounter.combat.actors[0].hull_catalogue_id==13 and original.detail.selections.has(0) and original.detail.selections.has("player"),"Native LOD composition relabelled the special hull or omitted player/freighter selectors")
	var reactions: RefCounted=frame._encounter._combat._provocation.fork_for_frame();var reactions_before: Dictionary=reactions.snapshot()
	check.call(not reactions.apply_selected40_sequence(Sequence.new()) and reactions.snapshot()==reactions_before,"Unprepared sequence relabelled reaction factions")
	check.call(not frame.configure(bindings,cat,library,pilot,scenery,equipment,reputation,pose,camera,aim) and frame.snapshot()==original,"Repeated moving-flight configuration replaced native owners")
	for duration in [-1,frame._max_ms+1,0.5,true,null]:check.call(frame.evaluate(duration)==null and frame.snapshot()==original,"Invalid moving-flight time mutated native state")
	for command in [Vector2(1.1,0),Vector2.INF]:check.call(frame.evaluate(100,command)==null and frame.snapshot()==original,"Invalid moving-flight steering mutated native state")
	for throttle in [-0.1,1.1,INF]:check.call(frame.evaluate(100,Vector2.ZERO,throttle)==null and frame.snapshot()==original,"Invalid moving-flight throttle mutated native state")
	check.call(frame.evaluate(100,Vector2.ZERO,1,false,false,Vector2i(-1,900))==null and frame.snapshot()==original,"Invalid moving-flight viewport mutated native state")
	check.call(frame.evaluate(100,Vector2.ZERO,1,false,false,VIEWPORT,0.5)==null and frame.snapshot()==original,"Invalid moving-flight lateral command mutated native state")
	check.call(frame.evaluate(100,Vector2.ONE,0,true,true).snapshot()==original,"Pause advanced motion, radio, damage, exhaust or random state")
	var zero: RefCounted=frame.evaluate(0)
	check.call(zero!=null,frame.error)
	if zero!=null:
		var zero_state: Dictionary=zero.frame_context()
		check.call(zero_state.elapsed_ms==0 and zero_state.revision==1 and zero_state.player_pose==pose and zero_state.encounter.sequence.revision==1 and not zero_state.encounter.pending_world,"Zero-time flight lost exactly one ordered native sequence/world visit")
	# Break the LAST scenery/detail phase on a detached fork. Motion, player
	# pools, gun slots, radio/camera and every NPC have already been staged when
	# it rejects. Neither the malformed parent nor the good flight may change.
	var broken: RefCounted=frame.fork_for_frame()
	# Scenery detaches sub-owners at its mutation boundary, not on a cheap
	# enclosing fork. A deliberately malformed private fixture must do the same.
	broken._scenery._detail=broken._scenery._detail.fork_for_frame()
	broken._scenery._detail.clear();broken._scenery._read_snapshot={}
	var broken_before: Dictionary=broken.snapshot()
	check.call(broken.evaluate(100,Vector2.ONE,1,true)==null,"Unprepared late scenery detail accepted a moving-flight frame")
	check.call(broken.snapshot()==broken_before and frame.snapshot()==original,"Late scenery failure leaked an earlier staged player, projectile, camera or NPC mutation")
	var late_hud: RefCounted=frame.fork_for_frame();late_hud._scanner._perspective={}
	var late_hud_before: Dictionary=late_hud.snapshot()
	check.call(late_hud.evaluate(100,Vector2.ONE,1,true)==null and late_hud.snapshot()==late_hud_before and frame.snapshot()==original,"Late scanner failure committed movement, contacts, camera, actors or scenery")
	var late_target: RefCounted=frame.fork_for_frame();late_target._targeting._perspective={}
	var late_target_before: Dictionary=late_target.snapshot()
	check.call(late_target.evaluate(100,Vector2.ONE,1,true)==null and late_target.snapshot()==late_target_before and frame.snapshot()==original,"Late asteroid acquisition failure partially committed the native frame")
	var late_notice: RefCounted=frame.fork_for_frame();late_notice._notices._rules={}
	var late_notice_before: Dictionary=late_notice.snapshot()
	check.call(late_notice.evaluate(100,Vector2.ONE,1,true)==null and late_notice.snapshot()==late_notice_before and frame.snapshot()==original,"Last-phase notice failure leaked targeting, damage, camera, actors or scenery")
	if career!=null:
		var late_career: RefCounted=frame.fork_for_frame();late_career._career=frame.career_owner()
		late_career._career._flight_identity=RefCounted.new()
		var late_career_before: Dictionary=late_career.snapshot()
		check.call(late_career.evaluate(100,Vector2.ONE,1,true)==null and late_career.snapshot()==late_career_before and frame.snapshot()==original,"Last-phase career identity failure committed flight, contacts, input or accounting")
	var detached_hud: Dictionary=frame.hud_state();detached_hud.player.vitals.hull=0;detached_hud.radio.visible=true
	check.call(frame.hud_state()==initial_hud,"Editing a HUD snapshot mutated native flight owners")
	var proof:={"assembly":scenery.world_initialization_owner().snapshot().npc_construction.actors[0].assembly,"catalogues":cat,"player_pose":pose,"snapshots":{},"render_names":["moving","transmission","reveal","view_pan","restore","player_follow"],"capture_prefix":"selected40-flight","moving_flight":true}
	var actual_contacts:=0;var frames:=0;var revealed: RefCounted;var restored: RefCounted
	var marker_frames:=0;var acquired:=0
	var emp_contact: RefCounted;var emp_distance:=INF;var before_reveal: RefCounted
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):check.call(false,visuals.error);return {}
	var viewport:=SubViewport.new();viewport.size=VIEWPORT;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;host.root.add_child(viewport)
	var scene: Node3D=load("res://src/presentation/selected40_scene.gd").new();viewport.add_child(scene)
	if not scene.configure(library,bindings,visuals,cat,frame,VIEWPORT):check.call(false,scene.error);viewport.free();return {}
	var feedback: Control=scene.feedback
	var audio: Node3D=feedback.audio
	var environment: Node3D=scene.environment
	var scene_initial: Dictionary=scene.snapshot()
	var actor_nodes: Array=scene.encounter.actors.map(func(row):return row.hull.get_instance_id())
	check.call(scene_initial.actor_count==13 and scene_initial.scenery_count==90 and scene_initial.player_pose==pose,"Persistent scene did not compose the actual native cast, field and retained player")
	check.call(scene.present(frame,VIEWPORT) and scene.snapshot()==scene_initial,"Redrawing the initial scene advanced gameplay or camera")
	var ordinary_view: Node3D=load("res://src/presentation/full_hold_encounter_geometry.gd").new()
	check.call(not ordinary_view.build(frame.encounter_owner(),library,visuals,bindings),"Selected scene weakened the ordinary encounter admission gate")
	ordinary_view.free()
	var observed: Dictionary=frame.encounter_owner().presentation_snapshot()
	observed.combat.actors[-1].hull_resource="foreign"
	var held_poses: Array=scene.encounter.actors.map(func(row):return row.hull.transform)
	check.call(scene.encounter.prepare_world(frame.encounter_owner(),frame.frame_context().encounter.view.camera.pose,frame.detail_state(),observed).is_empty() and scene.encounter.actors.map(func(row):return row.hull.transform)==held_poses,"Last-actor rejection partially moved the persistent cast")
	var other_cast: RefCounted=frame.encounter_owner();other_cast._selected40_world=load("res://src/simulation/opening_world_initialization.gd").new()
	check.call(scene.encounter.prepare_world(other_cast,frame.frame_context().encounter.view.camera.pose,frame.detail_state()).is_empty(),"Persistent renderer accepted another cast generation")
	var prepared_environment: Dictionary=environment.snapshot()
	check.call(prepared_environment.sky.station_id==entry.station_id and prepared_environment.planets.station_id==entry.station_id and prepared_environment.sun.station_id==entry.station_id and prepared_environment.lights.station_id==entry.station_id,"Environment mixed the fresh opening, retained origin and selected source locations")
	check.call(environment.present(frame,VIEWPORT) and environment.snapshot()==prepared_environment,"Repeated sky draw advanced retained sun intensity")
	var foreign_environment: RefCounted=frame.fork_for_frame();foreign_environment._presentation_identity=RefCounted.new()
	check.call(not scene.present(foreign_environment,VIEWPORT) and scene.snapshot()==scene_initial,"Persistent scene admitted another native flight identity")
	check.call(not scene.present(frame,Vector2i.ZERO) and scene.snapshot()==scene_initial,"Invalid scene viewport changed the retained display")
	check.call(not environment.present(foreign_environment,VIEWPORT) and environment.snapshot()==prepared_environment,"Environment admitted another native flight identity")
	check.call(not environment.present(frame,Vector2i.ZERO) and environment.snapshot()==prepared_environment,"Invalid environment viewport partially changed the source scene")
	var bad_portal: RefCounted=frame.evaluate(100)
	if bad_portal!=null:
		bad_portal._portal._state.animation.time_ms=-1
		var previous_sky: Transform3D=environment.sky.transform
		check.call(not environment.present(bad_portal,VIEWPORT) and environment.snapshot()==prepared_environment and environment.sky.transform==previous_sky,"Invalid portal animation partially changed the accepted native background")
	var bad_station: RefCounted=frame.evaluate(100)
	check.call(bad_station!=null,frame.error)
	if bad_station!=null:
		bad_station._station=bad_station.station_owner();bad_station._station._state.pose.origin.x+=1.0
		var sky_pose: Transform3D=environment.sky.transform
		var planet_poses: Array=environment.planets.models.map(func(model):return model.transform)
		check.call(not environment.present(bad_station,VIEWPORT) and environment.snapshot()==prepared_environment and environment.sky.transform==sky_pose and environment.planets.models.map(func(model):return model.transform)==planet_poses,"Rejected station identity partially moved accepted sky or planet geometry")
	var heard:={"primary":0,"npc":0,"radio":0}
	for tick in 650:
		var before: Dictionary=frame.frame_context();var t: int=before.elapsed_ms
		var commands:=Vector2(0.3,0) if t<3000 else Vector2(0.18,-0.14) if t>=35000 and t<40000 else Vector2.ZERO
		if before.encounter.sequence.input_blocked:commands=Vector2(-0.8,0.9)
		elif t>=53300:commands=Vector2(-0.1,0.2)
		var throttle:=0.1 if before.encounter.sequence.input_blocked else 1.0
		var strafe: float=1.0 if before.encounter.sequence.input_blocked else -1.0 if t>=39000 and t<40000 else 0.0
		var expected: RefCounted=frame.pilot_owner()
		var expected_engine: RefCounted=frame.engine_audio_owner()
		check.call(expected_engine.before_ordinary_motion(),expected_engine.error)
		var expected_pose: Transform3D=expected.advance_prepared(before.player_pose,before.throttle if before.encounter.sequence.input_blocked else throttle,0.1,0.0 if before.encounter.sequence.input_blocked else strafe)
		check.call(expected.error.is_empty(),expected.error)
		var next: RefCounted=frame.evaluate(100,commands,throttle,t>=39000,false,VIEWPORT,strafe,false,int(audio.snapshot().music_id))
		if next==null:check.call(false,frame.error);return {}
		var current: Dictionary=next.frame_context()
		if not current.boundary.is_empty():check.call(false,"Native moving-flight run reached "+current.boundary+" at "+str(current.elapsed_ms));return {}
		var sound: Dictionary=audio.prepare_selected40(next)
		if sound.is_empty():check.call(false,audio.error);feedback.free();return {}
		if t==0:
			var accepted_feedback: Dictionary=feedback.snapshot();var accepted_world: Dictionary=feedback.world_owner().snapshot()
			var bad_engine: RefCounted=next.fork_for_frame();bad_engine._engine_audio._state.parameters[0]=1.1
			check.call(not feedback.present(bad_engine,current.elapsed_ms) and feedback.snapshot()==accepted_feedback and feedback.world_owner().snapshot()==accepted_world,"Invalid retained engine parameters committed world, music, sounds or panel")
		for event in sound.operations:
			if event.has("mount_id"):heard.primary+=1
			if event.get("actor_id") is int and event.action=="start_spatial":heard.npc+=1
			if event.has("radio_event"):heard.radio+=1
		if not scene.present(next,VIEWPORT):check.call(false,"Persistent scene: "+scene.error);viewport.free();return {}
		check.call(scene.encounter.actors.map(func(row):return row.hull.get_instance_id())==actor_nodes,"Scene rebuilt its thirteen ships instead of updating persistent native bodies")
		check.call(scene.world_owner().frame_context()==current and scene.snapshot().elapsed_ms==current.elapsed_ms,"Scene/audio caller retained a different native revision")
		var presented_actors: Array=next.encounter_owner().combat_snapshot().actors
		for id in 13:
			check.call(scene.encounter.actors[id].hull.transform.is_equal_approx(presented_actors[id].body_pose),"Persistent selected actor ignored its logical model pose: "+str(id))
		check.call(expected_engine.follow_player(current.player_pose,int(current.player.vitals.hull),100) and expected_engine.sample_commands(commands if current.input.enabled else Vector2.ZERO),expected_engine.error)
		check.call(current.player_engine_audio==expected_engine.snapshot(),"Retained engine lost previous-command consumption, source squaring, late input or native position/clock")
		var playback: Dictionary=audio.snapshot()
		check.call(playback.engine_id==chosen.source_id and playback.engine_generation==0 and playback.active.has("player_engine"),"Ordinary engine restarted, disappeared or became the fresh escape engine")
		check.call(playback.active.player_engine.position==current.player_pose.origin,"Retained engine sound stopped following the actual player")
		check.call(environment.present(next,VIEWPORT),environment.error)
		check.call(current.player_pose==expected_pose,"Player movement consumed this frame's late input or used scripted-coast/frozen movement")
		check.call(expected.sample_commands(commands if current.input.enabled else Vector2.ZERO,0.1) and current.pilot.angular_units==expected.angular_units and current.pilot.lateral_rate==expected.lateral_units_per_millisecond,"Cinematic input gating sampled steering twice or lost native lateral decay")
		check.call(current.elapsed_ms==t+100 and current.encounter.elapsed_ms==current.elapsed_ms and current.encounter.world_elapsed_ms==current.elapsed_ms and current.encounter.sequence.elapsed_ms==current.elapsed_ms and not current.encounter.pending_world,"Moving player, contacts, sequence and NPC clocks diverged")
		check.call(current.portal.animation_elapsed_ms==current.elapsed_ms and current.portal.elapsed_ms==mini(current.elapsed_ms,60000) and current.portal.visible and current.portal.extent==4096 and current.portal.position==original.portal.position,"Selected40 portal closed, relocated or stopped its original animation clock")
		var expected_aim: RefCounted=aim.fork_for_frame()
		check.call(expected_aim.advance(current.player_pose,before.encounter.view.camera.pose,VIEWPORT) and expected_aim.snapshot().point==current.encounter.view.player_aim.point,"Moving player aim used the new camera instead of the preceding view")
		aim=expected_aim
		if before.encounter.sequence.input_blocked:
			check.call(current.throttle==before.throttle and current.player_pose.origin!=before.player_pose.origin,"Cinematic request stopped the retained player cruise")
		var encounter: RefCounted=next.encounter_owner();var combat: Dictionary=encounter.snapshot()
		# Retain a physically reached, released-input frame for the separate EMP
		# contact test. All poses/pools still come from this uninterrupted run.
		if current.elapsed_ms>=53300 and current.input.enabled:
			for actor in combat.combat.actors:
				if not actor.active or actor.scenery:continue
				var distance: float=current.player_pose.origin.distance_to(actor.position)
				if distance<emp_distance:emp_distance=distance;emp_contact=next
		if current.elapsed_ms==39900:before_reveal=next
		var expected_scan: RefCounted=frame.scanner_owner()
		check.call(expected_scan.advance_selected40(encounter.combat_owner(),current.player_pose,current.encounter.view.camera.pose,current.encounter.view.player_aim,100,current.encounter.sequence.hud_visible) and expected_scan.snapshot()==current.npc_scanner,"HUD scanner did not consume the final actor poses/new camera/preceding aim exactly once")
		var hud: Dictionary=next.hud_state()
		check.call(hud.player==current.player and hud.radio==current.encounter.sequence.radio and hud.cargo==gear.cargo and hud.control_throttle==current.throttle,"Live HUD drifted from native vitals, cargo, radio or throttle")
		var expected_target: RefCounted=frame.targeting_owner();var npc_scan: Dictionary=current.npc_scanner
		check.call(expected_target.advance(next.scenery_owner(),current.player_pose,current.encounter.view.camera.pose,current.encounter.view.player_aim,100,current.encounter.sequence.hud_visible,false,npc_scan.candidate_actor_id>=0 and npc_scan.selected_actor_id<0,npc_scan.get("found_actor_id",-1)>=0) and expected_target.snapshot()==current.mining_targeting,"Asteroid acquisition did not consume the final field/new camera/preceding aim exactly once after ship scanning")
		check.call(hud.mining_targeting==current.mining_targeting and hud.flight_notices==current.flight_notices,"Native target/notice HUD drifted from its simulation owners")
		if not current.encounter.sequence.hud_visible:
			check.call(not current.mining_targeting.visible and current.mining_targeting.markers.is_empty() and current.mining_targeting.elapsed_ms==before.mining_targeting.elapsed_ms,"Cinematic asteroid acquisition lost the retained timer or published markers")
		marker_frames+=int(not current.npc_scanner.markers.is_empty());acquired+=current.npc_scanner.events.size()
		if not current.encounter.sequence.hud_visible:
			check.call(not current.npc_scanner.visible and current.npc_scanner.markers.is_empty() and current.npc_scanner.elapsed_ms==before.npc_scanner.elapsed_ms and current.npc_scanner.selected_actor_id==before.npc_scanner.selected_actor_id,"Cinematic HUD advanced or cleared retained acquisition")
		for event in combat.weapon_events:actual_contacts+=event.npc_contacts.size()
		if current.encounter.sequence.input_blocked:
			check.call(not current.player.damage_allowed and current.player.active and not current.input.primary_held and combat.primary_fire.is_empty(),"Reveal conflated player activity with damage protection or retained a primary trigger")
		if current.encounter.sequence.phase==Sequence.Stage.FREIGHTER_VIEW and before.encounter.sequence.phase==Sequence.Stage.WAITING:
			revealed=next
			check_detail_refresh(host,frame,next,bindings)
			var prior_reactions: Dictionary=frame.encounter_owner().combat_snapshot().provocation
			var changed_reactions: Dictionary=combat.combat.provocation
			var expected_reactions:=prior_reactions.duplicate(true);expected_reactions.actor_kinds[0]=1
			check.call(changed_reactions==expected_reactions,"Reveal failed to reclassify reaction factions or reset damage/hostility/radio state")
			var reaction: RefCounted=encounter._combat._provocation.fork_for_frame()
			check.call(not reaction.apply_selected40_sequence(encounter._selected40_sequence) and reaction.snapshot()==changed_reactions,"Reaction owner accepted a replayed native reveal")
			var false_actor: Dictionary=combat.combat.actors[0].duplicate(true);false_actor.actor_kind=2
			check.call(reaction.evaluate(false_actor,1,true,current.random_state,true).is_empty() and reaction.snapshot()==changed_reactions,"Reclassification weakened rejection of an unrelated actor kind")
			check.call(current.elapsed_ms==40000 and current.player.vitals==before.player.vitals,"Reveal altered the retained hull/armor/shield instead of changing damage permission")
			check.call(current.player_pose.basis!=before.player_pose.basis,"Reveal froze the established angular motion on its own frame")
			proof.snapshots.reveal=render_state(next)
		if current.encounter.sequence.phase==Sequence.Stage.ESCORT and before.encounter.sequence.phase==Sequence.Stage.FREIGHTER_VIEW:
			restored=next
			check.call(current.elapsed_ms==53300 and current.player.damage_allowed and current.input.enabled and current.input.primary_held,"Restoration did not release damage and held input on the actual radio boundary")
			check.call(not combat.primary_fire.is_empty() and combat.primary_fire.weapons[0].result.fired,"Restored input failed to fire the original mounted primary on the same frame")
			proof.snapshots.restore=render_state(next)
		for pair in [[10000,"moving"],[45000,"view_pan"],[60000,"player_follow"]]:
			if current.elapsed_ms==pair[0]:proof.snapshots[pair[1]]=render_state(next)
		if current.elapsed_ms in [10000,40000,45000,53300,60000] and DisplayServer.get_name()!="headless":
			await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			check.call(image!=null and not image.is_empty(),"Persistent native scene produced no GPU image")
			if image!=null and not host.captures.is_empty():check.call(image.save_png(host.captures.path_join("selected40-live-scene-%d.png"%current.elapsed_ms))==OK,"Could not retain live native scene capture")
		if current.encounter.sequence.radio.visible and not proof.snapshots.has("transmission"):proof.snapshots.transmission=render_state(next)
		frame=next;frames+=1
	check.call(revealed!=null and restored!=null and actual_contacts>0,"Continuous moving flight did not reach both native cinematic gates with live mixed NPC contacts")
	check.call(frame.frame_context().player_pose!=pose and frame.snapshot().player_engines.elapsed_ms==65000,"Player remained stationary or exhaust did not follow the native flight clock")
	if career!=null:
		load("res://tests/fixtures/selected40_application_checks.gd").check_career_retained(check,frame,career.snapshot(),"after continuous 65000ms flight")
		var retained: Dictionary=frame.career_owner().snapshot();var origin: Dictionary=career.snapshot()
		var control: Dictionary=frame.encounter_owner()._control.career_snapshot();var delta: Dictionary=control.accounting.counter_deltas
		check.call(retained.progress.player_kills==origin.progress.player_kills+delta.player_kills and retained.progress.pirate_kills==origin.progress.pirate_kills+delta.pirate_kills and retained.reputation==control.combat.current_reputation,"Story combat did not retain its native career counters and current reputation exactly once")
	check.call(frame.equipment_owner().snapshot()==gear and pilot.snapshot()==parent and scenery.snapshot()==field and equipment.snapshot()==gear,"Moving flight mutated supplied origin equipment, player or generated field")
	check.call(frame.encounter_owner().snapshot().controller.defeat_status.is_empty(),"Moving/contact composition awarded a mission result")
	var final_combat: Dictionary=frame.encounter_owner().combat_snapshot()
	check.call(final_combat.actors[0].vitals.hull<1825 and final_combat.actors[0].actor_kind==1 and final_combat.provocation.actor_kinds[0]==1,"No real post-reveal hit reached the reclassified freighter with coherent faction reactions")
	# Explicit permission-boundary stimuli, separate from the uninterrupted run.
	if revealed!=null and restored!=null:
		var protected: RefCounted=revealed.player_owner();var immune: Dictionary=protected.snapshot().vitals
		check.call(not protected.normal_hit(15).is_empty() and protected.snapshot().vitals==immune,"Native cinematic damage gate did not protect real player pools")
		var vulnerable: RefCounted=restored.player_owner();var exposed: Dictionary=vulnerable.snapshot().vitals
		check.call(not vulnerable.normal_hit(15).is_empty() and vulnerable.snapshot().vitals!=exposed,"Native restoration left the player invulnerable")
		check.call(revealed.player_owner().snapshot().vitals==immune and restored.player_owner().snapshot().vitals==exposed,"Permission probes mutated their retained cinematic parents")
	check.call(heard.primary>0 and heard.npc>0 and heard.radio>=5,"Continuous selected40 flight failed to consume its actual player/NPC shots and original radio")
	var music_history: Array=audio.snapshot().history.filter(func(event):return event.action=="replace_music")
	check.call(music_history.size()==1 and music_history[0].source_id==145 and audio.snapshot().music_id==145,"No-scanner native source flight failed to start and retain exactly one original portal peace loop")
	check.call(frame._radar.snapshot().battle_count==0 and not frame._radar.snapshot().scanner_present,"Real weapon contacts fabricated a scanner battle count")
	check.call(not environment.present(secondary_origin,VIEWPORT),"Environment accepted an older native revision")
	check.call(not scene.present(secondary_origin,VIEWPORT),"Persistent scene accepted an older native revision")
	print("Selected40 persistent scene: 650 native revisions, 13 retained ship nodes, 90 source asteroids, shared NPC/primary/EMP projectiles, impacts, HUD, environment, audio and player effects; no admitted journey or result")
	print("Selected40 environment/audio: retained engine%d, one source portal music145, no-scanner NPC-loop skip; actual station%d/system%d sky, planets, sun, lighting and collision volumes, 650 native revisions"%[chosen.source_id,entry.station_id,entry.system_id])
	print("Selected40 live audio: %d player shots, %d NPC spatial sounds, %d original voice displays; native revisions and shared playback"%[heard.primary,heard.npc,heard.radio])
	await check_reclassified_freighter_death(host,frame,scene,viewport,library,bindings,visuals)
	viewport.free()
	var destruction: Dictionary=load("res://tests/fixtures/selected40_destruction_checks.gd").run(host,secondary_origin,bindings,cat,before_reveal,library)
	for name in destruction:
		proof.snapshots[name]=destruction[name];proof.render_names.append(name)
	print("Selected40 moving flight: %d continuous contact-enabled frames, %d real NPC contacts, reveal40000/restore53300, retained player movement and native exhaust; no travel or mission result"%[frames,actual_contacts])
	print("Selected40 native HUD: scanner%d, duration%d ms, %d marker frames, %d acquisition events; actual pools, retained cargo and cinematic freeze"%[frame.scanner_owner().snapshot().equipment_id,frame.scanner_owner().snapshot().duration_ms,marker_frames,acquired])
	var targets: Dictionary=run_asteroid_flight(host,library,bindings,cat,scenery,equipment,reputation,pilot,pose)
	for name in targets:
		proof.snapshots[name]=targets[name];proof.render_names.append(name)
	check.call(emp_contact!=null,"Continuous flight produced no released native EMP contact frame")
	if emp_contact==null:return proof
	print("Selected40 EMP reached contact frame: %d ms, nearest active non-scenery actor %.3f units"%[emp_contact.frame_context().elapsed_ms,emp_distance])
	var secondaries:=run_secondary_flight(host,secondary_origin,revealed,restored,emp_contact,before_reveal)
	for name in secondaries:
		proof.snapshots[name]=secondaries[name];proof.render_names.append(name)
	var cameras:=run_camera_flight(host,secondary_origin,revealed,restored,before_reveal)
	for name in cameras:
		proof.snapshots[name]=cameras[name];proof.render_names.append(name)
	return proof

static func check_reclassified_freighter_death(host: SceneTree,parent: RefCounted,scene: Node3D,viewport: SubViewport,library: RefCounted,bindings: RefCounted,visuals: RefCounted) -> void:
	var check: Callable=host.check;var original: Dictionary=parent.snapshot()
	var ids: Array=scene.encounter.actors.map(func(row):return row.hull.get_instance_id())
	var lethal: RefCounted=parent.fork_for_frame();var combat: RefCounted=lethal._encounter.combat_owner()
	check.call(combat.actor_snapshot(0).actor_kind==1 and scene.encounter.actors[0].constructed_kind==0,"Lethal renderer probe requires the already reclassified original Terran freighter")
	var ledger: RefCounted=combat._reputation.fork_for_frame();var history: Dictionary=ledger.snapshot()
	check.call(history.actor_kinds[0]==1 and not ledger.apply_selected40_sequence(RefCounted.new()) and ledger.snapshot()==history,"Reclassification lost native ledger affiliation or admitted a forged sequence")
	# Only this detached branch receives direct lethal damage. Reclassification
	# was earned by native contacts in the preceding uninterrupted65-second run.
	if not combat.begin_contact_pass(lethal.frame_context().random_state,true) or combat.normal_hit(0,1000000,false).is_empty():check.call(false,combat.error);return
	var kills: Array=combat._reputation.snapshot().events.filter(func(event):return event.actor_id==0 and event.get("event_kind","")=="")
	check.call(kills.size()==1 and kills[0].actor_kind==1 and kills[0].nonplayer_kill==false,"Reclassified lethal contact lost or duplicated the actual live-faction attribution")
	var duplicate: RefCounted=combat._reputation.fork_for_frame();var credited: Dictionary=duplicate.snapshot()
	check.call(not duplicate.record_lethal(combat.actor_snapshot(0)) and duplicate.snapshot()==credited,"Repeated exhausted-actor accounting duplicated the reputation event")
	lethal._encounter._combat=combat;lethal._random=combat.contact_random_state()
	var frame: RefCounted=lethal.evaluate(100)
	if frame==null:check.call(false,lethal.error);return
	var owner: RefCounted=frame.encounter_owner();var death: RefCounted=owner.npc_destruction_owner(0)
	var state: Dictionary=death.snapshot()
	check.call(state.phase=="animation" and state.actor_kind==0 and owner.combat_snapshot().actors[0].actor_kind==1,"Native lethal transition confused living allegiance with constructed destruction resources")
	if not scene.present(frame,VIEWPORT):check.call(false,"Reclassified lethal scene: "+scene.error);return
	var effect: Node3D=scene.encounter.actors[0].explosion
	check.call(effect.is_built() and effect.visible and not scene.encounter.actors[0].hull.visible,"Actual reclassified lethal scene failed to replace the hull with its original animated wreck")
	check.call(effect._descriptor.actor_kind==0 and effect._identity==death.presentation_identity() and scene.encounter.actors.map(func(row):return row.hull.get_instance_id())==ids,"Lethal rendering rebuilt the cast or changed the original Terran lifecycle")
	var drawn: Dictionary=scene.snapshot()
	check.call(scene.present(frame,VIEWPORT) and scene.snapshot()==drawn and parent.snapshot()==original,"Repeated lethal rendering changed gameplay or its living parent")
	# The authoritative scene above uses the native player camera. This second,
	# explicitly labelled inspection view makes the same real wreck easy to see;
	# neither camera nor simulation state is substituted in the running scene.
	if DisplayServer.get_name()!="headless":
		await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
		var live: Image=viewport.get_texture().get_image()
		check.call(live!=null and not live.is_empty(),"Lethal persistent scene produced no image")
		if live!=null and not host.captures.is_empty():check.call(live.save_png(host.captures.path_join("selected40-reclassified-lethal-live.png"))==OK,"Lethal scene capture failed")
		var inspection:=SubViewport.new();inspection.size=VIEWPORT;inspection.own_world_3d=true;inspection.render_target_update_mode=SubViewport.UPDATE_ALWAYS;host.root.add_child(inspection)
		var camera:=Camera3D.new();inspection.add_child(camera);camera.current=true;camera.near=1;camera.far=50000
		camera.look_at_from_position(state.pose.origin+Vector3(7000,4200,-9000),state.pose.origin)
		var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);inspection.add_child(light)
		var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=0.7;inspection.add_child(world)
		var closeup:=preload("res://src/presentation/freighter_destruction_geometry.gd").new();inspection.add_child(closeup)
		if not closeup.build(library,visuals,bindings,owner.freighter_resources().faction_owner(0),death) or not closeup.apply_state(death,camera.global_transform):check.call(false,closeup.error);inspection.free();return
		var label:=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",22);inspection.add_child(label)
		label.text="SELECTED40 | RECLASSIFIED FREIGHTER DESTRUCTION\nNative living allegiance1; retained Terran constructor0.\nExplicit detached lethal stimulus; inspection camera, not a mission result."
		await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
		var image: Image=inspection.get_texture().get_image()
		check.call(image!=null and not image.is_empty(),"Original reclassified-freighter wreck produced no inspection image")
		if image!=null and not host.captures.is_empty():check.call(image.save_png(host.captures.path_join("selected40-reclassified-lethal-inspection.png"))==OK,"Wreck inspection capture failed")
		inspection.free()
	print("Selected40 lethal reclassified freighter: native allegiance1 / constructor0, original Terran animated wreck, retained13nodes and unchanged living parent; detached damage, no mission result")

static func check_targeting(host: SceneTree,frame: RefCounted,bindings: RefCounted,library: RefCounted,cat: RefCounted) -> void:
	var check: Callable=host.check
	var owner: RefCounted=frame.targeting_owner();var before: Dictionary=owner.snapshot()
	check.call(before.scanner_id==-1 and before.duration_ms==8000,"Asteroid acquisition invented a scanner or lost the source default duration")
	check.call(not owner.configure_selected40(bindings,cat,frame.equipment_owner(),frame.scenery_owner(),owner._radii,owner._frames) and owner.snapshot()==before,"Repeated target configuration replaced retained native selection")
	var field: RefCounted=frame.scenery_owner();var hud: Dictionary=frame.hud_state()
	var foreign: RefCounted=field.fork_for_frame();foreign._world_initialization=load("res://src/simulation/opening_world_initialization.gd").new()
	# A field with another constructor must fail even when its presentation
	# identity is retained. No actual generated scenery or equipment is edited.
	check.call(not owner.advance(foreign,frame.frame_context().player_pose,hud.camera.pose,hud.player_aim,100,true) and owner.snapshot()==before,"Asteroid acquisition accepted an unrelated native world")
	var notices: RefCounted=frame.notices_owner();var initial: Dictionary=notices.snapshot()
	check.call(not notices.configure_selected40(bindings,library,field.world_initialization_owner()) and notices.snapshot()==initial,"Repeated notice configuration reset its retained clock")
	check.call(not notices.enqueue(-1) and not notices.enqueue(65535) and notices.snapshot()==initial,"Invalid notice fabricated equipment feedback")
	check.call(notices.enqueue(20) and notices.advance(100),notices.error)
	var once: Dictionary=notices.snapshot()
	check.call(notices.enqueue(20) and notices.snapshot()==once,"Duplicate missing-drill notice restarted its source fade")
	check.call(notices.advance(100,false,true) and notices.snapshot()==once,"Paused notice advanced its source timer")
	check.call(frame.notices_owner().snapshot()==initial and frame.targeting_owner().snapshot()==before,"Detached target/notice checks mutated the retained flight")

static func run_asteroid_flight(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted,origin: Transform3D) -> Dictionary:
	# Separate native component run with an explicitly chosen INITIAL heading.
	# The actual source field, player position, loadout and pools are unchanged.
	# All later poses come from ordinary zero-throttle flight, not camera/actor
	# teleports or edited target samples. This is not an earned journey.
	var check: Callable=host.check;var result:={}
	var field: Dictionary=scenery.snapshot();var pose:=origin
	pose.basis=Basis.looking_at(field.objects[0].position-origin.origin,Vector3.UP,true)
	var camera:=Rig.new();var aim:=Aim.new();var frame:=Frame.new()
	if not camera.configure(bindings) or not aim.configure(bindings):check.call(false,camera.error+aim.error);return {}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye","target":"player","actor_id":-1,"inherit_target_up":true,"eye":pose*Vector3(0,400,-1500)}
	var scene:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"player_pose":pose}
	if not camera.update(0,seed,scene,seed) or not aim.advance(pose,camera.snapshot().pose,VIEWPORT):check.call(false,camera.error+aim.error);return {}
	if not frame.configure(bindings,cat,library,player,scenery,equipment,reputation,pose,camera,aim,0.5,VIEWPORT):check.call(false,frame.error);return {}
	var source_gear: Dictionary=equipment.snapshot();var initial_pose:=pose
	var max_elapsed:=0;var selected:=-1;var notifications:=0
	for tick in 200:
		var prior_pose: Transform3D=frame.frame_context().player_pose
		var expected_pilot: RefCounted=frame.pilot_owner()
		var expected_pose: Transform3D=expected_pilot.advance_prepared(prior_pose,0.0,0.1)
		var next: RefCounted=frame.evaluate(100,Vector2.ZERO,0,false,false,VIEWPORT)
		if next==null:check.call(false,frame.error);return {}
		frame=next
		var current: Dictionary=frame.frame_context();var target: Dictionary=current.mining_targeting
		if not current.boundary.is_empty():check.call(false,"Targeting component reached "+current.boundary);return {}
		# Native movement orthonormalizes its float basis even at zero input.
		# Compare the exact shared motion result, not an unrounded initial basis.
		check.call(current.player_pose==expected_pose and current.player_pose.origin==initial_pose.origin,"Zero-throttle asteroid flight diverged from its native pilot or changed position")
		check.call(current.npc_scanner.equipment_id==-1 and current.npc_scanner.selected_actor_id==-1 and current.npc_scanner.markers.is_empty(),"Asteroid targeting incorrectly enabled an unequipped ship scanner")
		max_elapsed=maxi(max_elapsed,int(target.elapsed_ms))
		if target.animation_frame>=0 and target.selected_object_index<0 and not result.has("asteroid_acquisition") and target.elapsed_ms>=3000:result.asteroid_acquisition=render_state(frame)
		if target.elapsed_ms==target.duration_ms-200:check.call(target.selected_object_index==-1 and target.events.is_empty(),"Asteroid lock crossed its strict source threshold early")
		for event in target.events:
			if event.kind=="notification":notifications+=1
		if target.selected_object_index>=0:
			selected=target.selected_object_index
			check.call(target.drill_id in source_gear.loadout.equipment_ids and target.elapsed_ms>target.duration_ms-200,"Asteroid acquisition supplied an unfitted drill or an early lock")
			if not result.has("asteroid_acquired"):result.asteroid_acquired=render_state(frame)
		elif current.flight_notices.visible and current.flight_notices.alpha>=192 and not result.has("asteroid_equipment_notice"):result.asteroid_equipment_notice=render_state(frame)
	check.call(max_elapsed>8000 and result.has("asteroid_acquisition") and (selected>=0 or notifications>0),"Native initial-heading flight never acquired an actual source asteroid")
	check.call(notifications==0 or result.has("asteroid_equipment_notice"),"Missing-device notification never reached a legible native fade frame")
	check.call(frame.equipment_owner().snapshot()==source_gear and scenery.snapshot()==field and equipment.snapshot()==source_gear,"Asteroid flight awarded cargo, relocated inventory or changed its supplied field")
	print("Selected40 asteroid flight: 200 native frames, scanner -1, drill %d, max acquisition %d ms, selected %d, %d equipment notices; no mining/cargo/result"%[frame.targeting_owner().snapshot().drill_id,max_elapsed,selected,notifications])
	return result

static func check_scanner(host: SceneTree,frame: RefCounted,bindings: RefCounted) -> void:
	var check: Callable=host.check
	var scanner: RefCounted=frame.scanner_owner();var before: Dictionary=scanner.snapshot()
	var combat: RefCounted=frame.encounter_owner().combat_owner();var hud: Dictionary=frame.hud_state()
	check.call(not scanner.advance(combat.snapshot(),frame.frame_context().player_pose,hud.camera.pose,hud.player_aim,1,true) and scanner.snapshot()==before,"Selected scanner accepted a caller-supplied combat dictionary")
	var foreign: RefCounted=combat.fork_for_frame();foreign._selected40_world=load("res://src/simulation/opening_world_initialization.gd").new()
	check.call(not scanner.advance_selected40(foreign,frame.frame_context().player_pose,hud.camera.pose,hud.player_aim,1,true) and scanner.snapshot()==before,"Scanner accepted an unrelated native world generation")
	# The exact earned loadout has no ship scanner. An explicitly centered
	# escort is still not permission to invent markers or acquire a target.
	# This is an isolated camera/aim stimulus, not a changed actor or flight.
	check.call(before.equipment_id==-1,"The retained loadout unexpectedly gained a ship scanner")
	var cast: Dictionary=combat.snapshot();var actor: Dictionary=cast.actors[2]
	var rig:=Rig.new();check.call(rig.configure(bindings),rig.error)
	var shot:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye","target":"actor","actor_id":2,"inherit_target_up":true,"eye":actor.body_pose.origin+Vector3(0,0,-2000)}
	var scene:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"player_pose":frame.frame_context().player_pose,"actors":cast.actors.map(func(row):return {"actor_id":row.actor_id,"pose":row.body_pose})}
	if not rig.update(0,shot,scene,shot):check.call(false,rig.error);return
	var projection: RefCounted=scanner.prepare_projection(VIEWPORT)
	if projection==null:check.call(false,scanner.error);return
	var point: Dictionary=projection.project(rig.snapshot().pose,actor.body_pose.origin)
	if point.has("error"):check.call(false,projection.error);return
	var aim: Dictionary=hud.player_aim.duplicate(true);aim.point=Vector3(point.pixels.x,point.pixels.y,1)
	for row in [[before.duration_ms,true],[10000,true],[10000,false],[1,true]]:
		check.call(scanner.advance_selected40(combat,frame.frame_context().player_pose,rig.snapshot().pose,aim,row[0],row[1]),scanner.error)
		var sample: Dictionary=scanner.snapshot()
		check.call(not sample.visible and sample.markers.is_empty() and sample.events.is_empty() and sample.selected_actor_id==-1 and sample.candidate_actor_id==-1 and sample.elapsed_ms==0,"An unequipped scanner invented markers, acquisition time, a target lock or sound")
	check.call(frame.scanner_owner().snapshot()==before and combat.snapshot()==cast,"Acquisition stimulus mutated the moving flight or original cast")

## Consume only the actual three paid rounds in a separate native input run.
## Contact input starts from an actually reached frame of the continuous run.
## No player/NPC teleport or health reset is used; subsequent poses still come
## from the ordinary zero-throttle physical/weapon/camera/actor passes.
static func run_secondary_flight(host: SceneTree,origin: RefCounted,revealed: RefCounted,restored: RefCounted,contact: RefCounted,before_reveal: RefCounted) -> Dictionary:
	var check: Callable=host.check;var captures:={}
	var original: Dictionary=origin.snapshot();var gear: Dictionary=origin.equipment_owner().snapshot()
	var initial: Dictionary=origin.secondary_feedback()
	check.call(initial.selected_item_id==-1 and initial.weapons.size()==1 and initial.weapons[0].item_id==42 and initial.weapons[0].quantity==3,"Selected40 EMP changed the earned three-round stack or auto-selected it")
	check.call(origin.select_secondary(43)==null and origin.select_secondary(42,true)==null and origin.snapshot()==original,"Invalid or paused secondary selection mutated the source flight")
	var frame: RefCounted=origin.cycle_secondary()
	if frame==null:check.call(false,origin.error);return {}
	check.call(frame.secondary_feedback().selected_item_id==42 and frame.cycle_secondary().secondary_feedback().selected_item_id==-1,"Native secondary cycle did not visit the earned launcher then None")
	var selected: Dictionary=frame.snapshot()
	check.call(frame.evaluate(100,Vector2.ZERO,0,false,true,VIEWPORT,0,true).snapshot()==selected,"Paused secondary request consumed ammunition, motion or time")
	var zero: RefCounted=frame.evaluate(0,Vector2.ZERO,0,false,false,VIEWPORT,0,true)
	if zero==null:check.call(false,frame.error);return {}
	check.call(zero.secondary_feedback().weapons[0].quantity==3 and zero.encounter_owner().secondary_owner().snapshot().launches==0,"EMP fired at equality instead of the source strict cooldown threshold")
	# Invalidate the final notice phase after the prospective launch has already
	# changed ammo. Every native inventory and the parent must remain untouched.
	var malformed: RefCounted=frame.fork_for_frame();malformed._notices._rules={}
	var malformed_before: Dictionary=malformed.snapshot()
	check.call(malformed.evaluate(100,Vector2.ZERO,0,false,false,VIEWPORT,0,true)==null and malformed.snapshot()==malformed_before and frame.snapshot()==selected,"Late rejected EMP launch spent a round or leaked a prospective body")
	var contact_parent: Dictionary=contact.snapshot()
	frame=contact.select_secondary(42)
	if frame==null:check.call(false,contact.error);return {}
	var systems_hits:=0;var shake_frames:=0;var elapsed:=0
	for round_index in 3:
		# Advance actual cooldown time; no counter editing or restored ammunition.
		for waiting in 100:
			if frame.secondary_feedback().weapons[0].wait_ms==0:break
			var tick: RefCounted=frame.evaluate(100,Vector2.ZERO,0)
			if tick==null:check.call(false,frame.error);return {}
			frame=tick;elapsed+=100
		check.call(frame.secondary_feedback().weapons[0].wait_ms==0,"EMP cooldown never became ready within the bounded native run")
		var next: RefCounted=frame.evaluate(100,Vector2.ZERO,0,false,false,VIEWPORT,0,true)
		if next==null:check.call(false,frame.error);return {}
		frame=next;elapsed+=100
		var launched: Dictionary=frame.encounter_owner().snapshot()
		check.call(launched.secondaries.launches==round_index+1 and launched.secondary_events.size()==1 and launched.secondary_events[0].action=="launched","Real selected40 secondary input failed to launch exactly one paid round")
		check.call(frame.secondary_feedback().weapons[0].quantity==2-round_index and frame.secondary_feedback().weapons[0].live,"Launch feedback lost remaining ammunition or the real flying body")
		check_secondary_retention(host,frame,2-round_index)
		if round_index==0:
			captures.emp_launch=render_state(frame)
			var bad: RefCounted=frame.fork_for_frame();bad._notices._rules={}
			var before: Dictionary=bad.snapshot();var accepted: Dictionary=frame.snapshot()
			check.call(bad.evaluate(100,Vector2.ZERO,0,false,false,VIEWPORT,0,true)==null and bad.snapshot()==before and frame.snapshot()==accepted,"Late rejected EMP detonation leaked target systems, ammo or RNG")
		if round_index==2:
			check.call(frame.select_secondary(42)==null,"An exhausted EMP stack remained selectable as installed ammunition")
			frame=frame.select_secondary(-1)
			check.call(frame!=null and frame.secondary_feedback().actions[0].action=="detonated","Removing the last paid slot discarded its live detonation action")
			next=frame.evaluate(100,Vector2.ZERO,0)
			if next==null:check.call(false,frame.error);return {}
			frame=next;elapsed+=100;captures.emp_last_live=render_state(frame)
		next=frame.evaluate(100,Vector2.ZERO,0,false,false,VIEWPORT,0,true)
		if next==null:check.call(false,frame.error);return {}
		frame=next;elapsed+=100
		var detonated: Dictionary=frame.encounter_owner().snapshot()
		check.call(detonated.secondary_events.size()==1 and detonated.secondary_events[0].action=="detonated" and detonated.secondaries.launches==round_index+1,"Manual EMP detonation relaunched or lost its retained projectile")
		for hit in detonated.secondary_events[0].systems_hits:
			systems_hits+=1
			var target: Dictionary=detonated.combat.actors[hit.actor_id]
			check.call(target.active and not target.scenery,"EMP hit an immune or inactive source actor")
		check_secondary_retention(host,frame,2-round_index)
		for burst_tick in 8:
			next=frame.evaluate(100,Vector2.ZERO,0)
			if next==null:check.call(false,frame.error);return {}
			frame=next;elapsed+=100
			var owner: RefCounted=frame.encounter_owner().secondary_owner()
			for command in owner.snapshot().detonation_camera:
				if command.strength>0:shake_frames+=1
			if round_index==0 and burst_tick==2:captures.emp_burst=render_state(frame)
	check.call(systems_hits>0 and shake_frames>0,"Earned EMP input never reached actual NPC systems or its native burst camera")
	check.call(frame.secondary_feedback().selected_item_id==-1 and frame.secondary_feedback().weapons[0].quantity==0,"Exhausted secondary feedback invented ammunition")
	check.call(origin.snapshot()==original and origin.equipment_owner().snapshot()==gear,"Secondary run changed its canonical parent or source inventory")
	check.call(contact.snapshot()==contact_parent,"EMP contact run changed the retained continuous-flight parent")
	if before_reveal!=null:
		var before: Dictionary=before_reveal.snapshot()
		var armed: RefCounted=before_reveal.select_secondary(42)
		if armed==null:check.call(false,before_reveal.error);return {}
		# The actual native clock is already beyond the launch cooldown. A
		# zero-time input visit launches without fabricating motion or a timer.
		var flying: RefCounted=armed.evaluate(0,Vector2.ZERO,1,false,false,VIEWPORT,0,true)
		if flying==null:check.call(false,armed.error);return {}
		check.call(flying.secondary_feedback().weapons[0].live and flying.secondary_feedback().weapons[0].quantity==2,"Pre-cinematic EMP input did not retain its paid flying round")
		var blocked: RefCounted=flying.evaluate(100,Vector2.ZERO,1,false,false,VIEWPORT,0,true)
		if blocked==null:check.call(false,flying.error);return {}
		check.call(blocked.frame_context().elapsed_ms==40000 and not blocked.frame_context().input.enabled and blocked.secondary_feedback().weapons[0].live and blocked.secondary_feedback().weapons[0].quantity==2,"Cinematic reset discarded an existing EMP body or admitted a new detonation request")
		check.call(before_reveal.snapshot()==before,"Cinematic EMP probe changed the original uninterrupted run")
		captures.emp_cinematic=render_state(blocked)
	if revealed!=null:
		var protected: Dictionary=revealed.snapshot()
		check.call(revealed.select_secondary(42)==null,"Cinematic input admitted a secondary selection")
		var encounter: RefCounted=revealed.encounter_owner()
		var refused: Dictionary=encounter.evaluate_secondary_fire(revealed.player_owner(),revealed.equipment_owner(),revealed.frame_context().player_pose,true,true,revealed.frame_context().random_state)
		check.call(not refused.is_empty() and refused.encounter.secondary_owner().snapshot().launches==0 and revealed.snapshot()==protected,"A stale true input flag bypassed the native selected40 cinematic gate")
	if restored!=null:
		var selected_after: RefCounted=restored.select_secondary(42)
		check.call(selected_after!=null,"Native cinematic restoration left paid secondaries inaccessible")
		if selected_after!=null:
			var active: RefCounted=selected_after.evaluate(100,Vector2.ZERO,0,false,false,VIEWPORT,0,true)
			check.call(active!=null,selected_after.error)
			if active!=null:check.call(active.secondary_feedback().weapons[0].quantity==2,"Restored native input failed to fire its real earned launcher")
	print("Selected40 EMP input: 3 paid launches, 3 manual detonations, %d real systems contacts, %d burst-camera frames, %d ms; last-slot retention and late rollback; no grants/result"%[systems_hits,shake_frames,elapsed])
	return captures

static func check_secondary_retention(host: SceneTree,frame: RefCounted,remaining: int) -> void:
	var player: Dictionary=frame.player_owner().loadout()
	var equipment: Dictionary=frame.equipment_owner().snapshot().loadout
	var encounter: RefCounted=frame.encounter_owner()
	var expected:=player.duplicate(true);expected.erase("campaign_cursor")
	host.check(expected==equipment,"EMP player and station inventory disagree after consumption")
	var primary: Dictionary=encounter._primaries.snapshot().loadout
	for key in primary:host.check(primary[key]==player[key],"EMP primary loadout is stale: "+str(key))
	host.check(encounter._inventory.validate_loadout(primary),"EMP target inventory disagrees with its retained primaries")
	var quantity:=0
	for slot in player.slots:
		if slot!=null and slot.item_id==42:quantity+=int(slot.quantity)
	host.check(quantity==remaining and (42 in player.equipment_ids)==(remaining>0),"EMP consumption refilled or retained an exhausted installed slot")

static func run_camera_flight(host: SceneTree,origin: RefCounted,revealed: RefCounted,restored: RefCounted,before_reveal: RefCounted) -> Dictionary:
	var check: Callable=host.check;var captures:={}
	var original: Dictionary=origin.snapshot();var gear: Dictionary=origin.equipment_owner().snapshot()
	for mode in [true,null,-1,1,4,"3"]:
		check.call(origin.camera_input(mode)==null and origin.snapshot()==original,"Unavailable/non-native camera mode changed flight or admitted mode2 auxiliary")
	check.call(origin.camera_input(3,"",Vector2i.ZERO,true)==null and origin.snapshot()==original,"Paused camera selection changed the flight")
	var frame: RefCounted=origin.camera_input(3)
	if frame==null:check.call(false,origin.error);return {}
	var selected: Dictionary=frame.frame_context().encounter.view
	var initial_view: Dictionary=original.encounter.selected40_view
	var initial_radius: float=initial_view.orbit_camera.distance
	check.call(selected.camera_mode==3 and selected.orbit_camera.enabled and not selected.auxiliary_camera.enabled and selected.orbit_input.units==Vector2(25,-50) and selected.orbit_camera.angles==initial_view.orbit_camera.angles and selected.orbit_camera.distance==initial_radius,"Normal mode3 selection applied a player-event preset or replaced retained input/distance")
	var redirected: RefCounted=origin.camera_input(2)
	check.call(redirected!=null and redirected.frame_context().encounter.view==selected,"Mac mode2 request did not normalize to the identical ordinary mode3 without an auxiliary action")
	check.call(selected.camera==original.encounter.selected40_view.camera and frame.frame_context().random_state==origin.frame_context().random_state,"Camera selection advanced the view or native RNG")
	var parent: Dictionary=frame.snapshot()
	for pair in [["move",Vector2i(50,50)],["release",Vector2i.ZERO],["press",Vector2(50,50)],["unknown",Vector2i.ZERO]]:
		check.call(frame.camera_input(null,pair[0],pair[1])==null and frame.snapshot()==parent,"Malformed pointer event changed native orbit state")
	frame=frame.camera_input(null,"press",Vector2i(200,200))
	if frame==null:check.call(false,"Native orbit press rejected");return {}
	var pressed: Dictionary=frame.snapshot()
	check.call(frame.camera_input(null,"press",Vector2i(200,200))==null and frame.snapshot()==pressed,"Repeated pointer press reset a retained native drag")
	frame=frame.camera_input(null,"move",Vector2i(240,210))
	if frame==null:check.call(false,"Native orbit drag rejected");return {}
	check.call(frame.frame_context().encounter.view.orbit_input.units==Vector2(65,-40),"Native drag changed source integer-delta accumulation")
	var reference: RefCounted=origin.fork_for_frame();var inertia_frames:=0
	for tick in 70:
		if tick==10:
			frame=frame.camera_input(null,"release")
			if frame==null:check.call(false,"Native orbit release rejected");return {}
			check.call(frame.frame_context().encounter.view.orbit_input.units==Vector2(105,-30) and frame.frame_context().encounter.view.orbit_input.velocity==Vector2(40,10),"Native release omitted the last delta or its launch velocity")
		var prior: Dictionary=frame.frame_context();var input: Dictionary=prior.encounter.view.orbit_input
		var units: Vector2=input.units;var velocity: Vector2=input.velocity
		if not input.dragging:
			velocity=Vector2(Rig.single(velocity.x*Rig.single(0.9)),Rig.single(velocity.y*Rig.single(0.9)))
			for axis in 2:
				if absf(velocity[axis])>1:units[axis]=Rig.single(units[axis]+velocity[axis])
			units.y=clampf(units.y,-200,200)
		var next: RefCounted=frame.evaluate(100,Vector2.ZERO,0)
		var ordinary: RefCounted=reference.evaluate(100,Vector2.ZERO,0)
		if next==null or ordinary==null:check.call(false,frame.error+reference.error);return {}
		var now: Dictionary=next.frame_context();var normal: Dictionary=ordinary.frame_context();var view: Dictionary=now.encounter.view
		check.call(view.orbit_input.units==units and view.orbit_input.velocity==velocity,"Orbit input lost per-frame float32 damping, strict >1 threshold or drag hold")
		check.call(view.orbit_camera.angles==Vector3(units.y*Rig.single(-0.005),units.x*Rig.single(-0.005),0),"Orbit input used degrees or exchanged its pointer axes")
		check.call(now.player_pose==normal.player_pose and now.player==normal.player and now.random_state==normal.random_state and next.encounter_owner().combat_snapshot()==ordinary.encounter_owner().combat_snapshot(),"View-only input changed native physics, vitals, NPC contacts or RNG")
		check.call(not view.player_render_suppressed and not view.auxiliary_camera.enabled,"Reachable mode3 hid the player or entered the auxiliary path")
		if not input.dragging and velocity.length()>1:inertia_frames+=1
		frame=next;reference=ordinary
		if tick==9:captures.orbit_drag=render_state(frame)
		if tick==35:captures.orbit_coast=render_state(frame)
	check.call(inertia_frames>0 and absf(frame.frame_context().encounter.view.orbit_input.velocity.x)<1,"Released camera failed to coast to the source threshold")
	var retained: Dictionary=frame.snapshot()
	check.call(frame.evaluate(100,Vector2.ONE,1,false,true).snapshot()==retained,"Pause advanced retained orbit input or view")
	var broken: RefCounted=frame.fork_for_frame();broken._notices._rules={}
	var malformed: Dictionary=broken.snapshot()
	check.call(broken.evaluate(100,Vector2.ZERO,0)==null and broken.snapshot()==malformed and frame.snapshot()==retained,"Late frame failure committed prospective orbit input, camera or render suppression")
	frame=frame.camera_input(0)
	if frame==null:check.call(false,"Native return to follow rejected");return {}
	var radius: Vector3=frame.frame_context().encounter.view.orbit_camera.eye_offset
	check.call(not frame.frame_context().encounter.view.orbit_camera.enabled and absf(radius.length()-initial_radius)<0.01,"Returning to mode0 reset source follow distance")
	var toggled: RefCounted=frame.camera_input(3)
	check.call(toggled!=null and toggled.frame_context().encounter.view.orbit_input==retained.encounter.selected40_view.orbit_input and toggled.frame_context().encounter.view.orbit_camera.distance==initial_radius,"Re-entering normal orbit invented new angles, pointer state or distance")
	for tick in 35:
		var next: RefCounted=frame.evaluate(100,Vector2.ZERO,0)
		var ordinary: RefCounted=reference.evaluate(100,Vector2.ZERO,0)
		if next==null or ordinary==null:check.call(false,frame.error+reference.error);return {}
		var now: Dictionary=next.frame_context();var normal: Dictionary=ordinary.frame_context()
		check.call(now.player_pose==normal.player_pose and now.player==normal.player and now.random_state==normal.random_state and next.encounter_owner().combat_snapshot()==ordinary.encounter_owner().combat_snapshot(),"Returning from orbit changed native physics, vitals, NPC contacts or RNG")
		check.call(not now.encounter.view.orbit_camera.enabled and not now.encounter.view.player_render_suppressed,"Returning to follow retained orbit or hid the living player")
		frame=next;reference=ordinary
	captures.orbit_return=render_state(frame)
	# Exact release threshold and held-vs-released vertical clamp. These are
	# separate native pointer actions on unchanged source-origin flight.
	for delta in [Vector2i(3,4),Vector2i(0,1000),Vector2i(0,-1000)]:
		var probe: RefCounted=origin.camera_input(3)
		probe=probe.camera_input(null,"press",Vector2i.ZERO);probe=probe.camera_input(null,"move",delta)
		var held: RefCounted=probe.evaluate(100,Vector2.ZERO,0)
		if held==null:check.call(false,probe.error);return {}
		check.call(held.frame_context().encounter.view.orbit_input.units==Vector2(25,-50)+Vector2(delta),"Held pointer was prematurely clamped or damped")
		probe=held.camera_input(null,"release")
		var release: Dictionary=probe.frame_context().encounter.view.orbit_input
		check.call(release.velocity==Vector2(delta.x if absi(delta.x)>=4 else 0,delta.y if absi(delta.y)>=4 else 0),"Release changed the inclusive four-unit inertia threshold")
		var next: RefCounted=probe.evaluate(100,Vector2.ZERO,0)
		if next==null:check.call(false,probe.error);return {}
		if absi(delta.y)>200:check.call(next.frame_context().encounter.view.orbit_input.units.y==200*signi(delta.y),"Released orbit did not clamp to +/-200 source input units")
	if before_reveal!=null:
		var staged: RefCounted=before_reveal.camera_input(3)
		staged=staged.camera_input(null,"press",Vector2i(10,10));staged=staged.camera_input(null,"move",Vector2i(20,20))
		var cinematic: RefCounted=staged.evaluate(100,Vector2.ZERO,1)
		if cinematic==null:check.call(false,staged.error);return {}
		var view: Dictionary=cinematic.frame_context().encounter.view
		check.call(view.input_blocked and not view.orbit_input.dragging and view.camera.mode=="fixed_eye" and view.camera_mode==3 and not view.player_render_suppressed,"Cinematic cancellation retained a drag or confused orbit/HUD suppression with player visibility")
		captures.orbit_cinematic=render_state(cinematic)
	if revealed!=null:check.call(revealed.camera_input(3)==null and revealed.camera_input(null,"press",Vector2i.ZERO)==null,"Cinematic admitted a manual camera action")
	if restored!=null:check.call(restored.camera_input(3)!=null,"Native restoration failed to release camera input")
	check.call(origin.snapshot()==original and origin.equipment_owner().snapshot()==gear and frame.equipment_owner().snapshot()==gear,"Camera input mutated canonical origin or retained equipment")
	print("Selected40 mode3: 105 native frames, %d inertial frames, real press/drag/release, follow return, pointer thresholds/clamps, cinematic cancellation and late rollback; identical paired physics/RNG; no mode2 or grants"%inertia_frames)
	return captures

static func check_detail_refresh(host: SceneTree,prior: RefCounted,current: RefCounted,bindings: RefCounted,crossing_probe:=true) -> void:
	var check: Callable=host.check
	var before: Dictionary=prior.snapshot();var after: Dictionary=current.snapshot()
	var reference: Variant=after.encounter.selected40_view.detail_refresh_reference
	check.call(reference==Vector3(-27000,-2500,52000),"Reveal detail refresh used a later camera or an invented starfield reference")
	var positions:={};var registered: Dictionary=before.detail.selections
	if registered.has("player"):positions.player=after.player_pose.origin
	for actor in before.encounter.combat.actors:
		if registered.has(actor.actor_id):positions[actor.actor_id]=actor.body_pose.origin
	var detail: RefCounted=prior._detail.fork_for_frame()
	check.call(detail.update(100,positions,before.reference,1.0,false),detail.error)
	var periodic: Dictionary=detail.snapshot()
	# The source reveals actor0 before its camera/geometry call. All other
	# actor roots here remain pre-NPC; a post-motion refresh is not equivalent.
	positions[0]=Vector3(-20000,-3000,35000)
	check.call(detail.refresh(positions,reference,1.0),detail.error)
	check.call(detail.snapshot()==after.detail,"Cinematic ship detail did not use post-reveal/pre-NPC roots and the actual immediate camera")
	check.call(after.detail.counter_ms==periodic.counter_ms,"Immediate ship detail reset or double-ticked the periodic clock")
	var scenery: RefCounted=prior._scenery._detail.fork_for_frame()
	check.call(scenery.update(100,before.reference,1.0,false),scenery.error)
	var old_field: Dictionary=scenery.snapshot()
	check.call(scenery.refresh(reference,1.0),scenery.error)
	check.call(scenery.snapshot()==after.scenery.detail and after.scenery.detail.counter_ms==old_field.counter_ms,"Cinematic asteroid detail was overwritten by a later periodic selection or changed its clock")
	var changed_ships:=0;var changed_rocks:=0
	for id in after.detail.selections:changed_ships+=int(after.detail.selections[id]!=periodic.selections[id])
	for id in after.scenery.detail.selections:changed_rocks+=int(after.scenery.detail.selections[id]!=old_field.selections[id])
	check.call(changed_ships+changed_rocks>0,"Cinematic detail regression did not exercise a real retained mesh-selection change")
	var zero: RefCounted=current.evaluate(0)
	check.call(zero!=null,current.error)
	if zero!=null:check.call(zero.frame_context().encounter.view.detail_refresh_reference==null and zero.snapshot().detail==after.detail and zero.snapshot().scenery.detail==after.scenery.detail,"The one-shot cinematic detail refresh leaked into the following zero-time frame")
	if crossing_probe:
		var broken: RefCounted=prior.fork_for_frame();broken._notices._rules={}
		var broken_before: Dictionary=broken.snapshot()
		check.call(broken.evaluate(100)==null and broken.snapshot()==broken_before and prior.snapshot()==before,"Late cinematic failure committed revealed LOD, camera, random state or actor placement")
		var crossing: RefCounted=prior.fork_for_frame()
		crossing._detail._counter=int(bindings.lod_refresh.refresh_at_milliseconds)-1
		crossing._scenery._detail=crossing._scenery._detail.fork_for_frame()
		crossing._scenery._detail._group._counter=int(bindings.lod_refresh.refresh_at_milliseconds)-1
		# Replay the continuous frame's identical prior-to-reveal controls,
		# including its live lateral command. Only the LOD counters differ.
		var crossed: RefCounted=crossing.evaluate(100,Vector2(0.18,-0.14),1,true,false,VIEWPORT,-1.0)
		check.call(crossed!=null,crossing.error)
		if crossed!=null:
			check_detail_refresh(host,crossing,crossed,bindings,false)
			check.call(crossed.snapshot().detail.counter_ms==0 and crossed.snapshot().scenery.detail.counter_ms==0,"Coincident periodic/cinematic refresh did not retain exactly one periodic reset")
			check.call(crossed.frame_context().random_state==after.random_state and crossed.snapshot().player_engines==after.player_engines,"Changing only LOD clock alignment changed shared combat or private exhaust RNG")
		check.call(prior.snapshot()==before and current.snapshot()==after,"Detached detail probes modified the accepted continuous flight")
		print("Selected40 immediate geometry detail: %d ship and %d asteroid selections changed; exact reveal eye, periodic overlap, one-shot reset and late rollback verified"%[changed_ships,changed_rocks])

static func check_portal(host: SceneTree,origin: RefCounted,library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted) -> void:
	# Independent contact/clock stimuli, not an earned portal journey. No
	# canonical save, cast, health, selected cursor or source location is edited.
	var check: Callable=host.check
	var original: Dictionary=origin.snapshot()
	var portal: RefCounted=origin.portal_owner()
	var initial: Dictionary=portal.snapshot()
	var initial_state: Dictionary=portal.portal_snapshot()
	check.call(initial_state.campaign_cursor==40 and initial_state.mission_kind==161 and initial.scope=="selected40_source_portal_component" and not initial.has("ordinary_mode"),"Portal substituted the ordinary33 story sentinel")
	check.call(portal.selected40_construction_owner()==player.selected40_construction_owner(),"Portal lost the actual selected actor generation")
	check.call(not portal.configure_selected40(bindings,scenery,library) and portal.snapshot()==initial and portal.portal_snapshot()==initial_state,"Repeated selected40 portal construction replaced its live state")
	check.call(not Frame.VoidPortal.new().configure_selected40(bindings,null,library),"Unprepared field admitted a selected40 portal")
	var random:=Frame.VoidPortal.Random.new();check.call(random.restore(original.random_state),random.error)
	var camera:=Transform3D(Basis.IDENTITY,initial_state.position+Vector3(30000,20000,35000))
	for tick in 1500:
		if not portal.advance(150,camera,random):check.call(false,portal.error);return
	var held: Dictionary=portal.portal_snapshot()
	check.call(held.animation_elapsed_ms==225000 and held.elapsed_ms==60000 and held.extent==4096 and held.visible and held.position==initial_state.position and random.snapshot()==original.random_state,"Source40 hold-open branch relocated, consumed RNG or used a frozen model clock")
	for duration in [-1,portal._max_ms+1,0.5,true,null]:
		var before: Dictionary=portal.snapshot()
		check.call(not portal.advance(duration,camera,random) and portal.snapshot()==before and portal.portal_snapshot()==held and random.snapshot()==original.random_state,"Invalid portal frame changed retained state or random stream")
	for distance in [40000,39999,1000,999]:
		var probe: RefCounted=origin.portal_owner()
		var observation:={"player_pose":Transform3D(Basis.IDENTITY,initial_state.position+Vector3(distance,0,0)),"environment_contact_enabled":true,"mining_active":false}
		check.call(probe.observe_contact(observation),probe.error)
		check.call(probe.transition_ready(1)==(distance<1000) and not probe.transition_ready(0),"Portal entry ignored the source integer threshold or living-player guard")
		if distance==40000:check.call(probe.snapshot().contact.is_empty(),"Portal admitted its exclusive cube boundary")
		else:check.call(probe.snapshot().contact.pull_distance==((40000-distance)>>8),"Portal pull was scaled by frame time or rounded instead of truncated")
	for flags in [[false,false],[true,true]]:
		var probe: RefCounted=origin.portal_owner()
		check.call(probe.observe_contact({"player_pose":Transform3D(Basis.IDENTITY,initial_state.position),"environment_contact_enabled":flags[0],"mining_active":flags[1]}) and not probe.transition_ready(1),"Portal ignored physical-contact or active-mining gating")
	var broken: RefCounted=origin.fork_for_frame();broken._portal._max_ms=0
	var broken_before: Dictionary=broken.snapshot()
	check.call(broken.evaluate(100)==null and broken.snapshot()==broken_before and origin.snapshot()==original,"Late portal failure leaked motion, contacts, NPCs, scenery, audio or RNG")
	# A fresh source-native field/player constructor at a disclosed near-portal
	# test pose checks ordering without teleporting the continuous flight run.
	var near_pose:=Transform3D(Basis.IDENTITY,initial_state.position+Vector3(1000,0,0))
	var rig:=Rig.new();var aim:=Aim.new()
	check.call(rig.configure(bindings) and aim.configure(bindings),rig.error+aim.error)
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye","target":"player","actor_id":-1,"inherit_target_up":true,"eye":near_pose*Vector3(0,400,-1500)}
	check.call(rig.update(0,seed,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"player_pose":near_pose},seed) and aim.advance(near_pose,rig.snapshot().pose,VIEWPORT),rig.error+aim.error)
	var near_frame:=Frame.new()
	if not near_frame.configure(bindings,cat,library,player,scenery,equipment,reputation,near_pose,rig,aim,0.0,VIEWPORT):check.call(false,near_frame.error);return
	var contact_frame: RefCounted=near_frame.evaluate(0,Vector2.ZERO,0)
	if contact_frame==null:check.call(false,near_frame.error);return
	var contact: Dictionary=contact_frame.frame_context()
	var expected_aim: RefCounted=aim.fork_for_frame();var incorrect_aim: RefCounted=aim.fork_for_frame()
	check.call(expected_aim.advance(near_pose,rig.snapshot().pose,VIEWPORT) and incorrect_aim.advance(contact.player_pose,rig.snapshot().pose,VIEWPORT),expected_aim.error+incorrect_aim.error)
	check.call(contact.player_pose.origin==near_pose.origin-Vector3(152,0,0) and not contact_frame.portal_transition_required(),"Portal pull or distance1000 admission differs: "+str(contact.player_pose.origin))
	check.call(contact.encounter.view.player_aim.point==expected_aim.snapshot().point and contact.encounter.view.player_aim.raw_point==expected_aim.snapshot().raw_point and expected_aim.snapshot().point!=incorrect_aim.snapshot().point,"Portal pull changed the earlier smoothed reticle sample")
	var entered: RefCounted=contact_frame.evaluate(0,Vector2.ZERO,0)
	check.call(entered!=null and entered.frame_context().portal_contact.portal_entered and entered.frame_context().portal_outcome.kind=="early_entry" and entered.player_owner().snapshot().vitals.hull==0 and not entered.portal_transition_required(),"Real second contact below1000 failed to apply the source's early-entry hull rejection")
	if entered!=null:
		check.call(entered.player_owner().snapshot().vitals.armor==contact.player.vitals.armor and entered.player_owner().snapshot().vitals.shield==contact.player.vitals.shield and entered.prepare_portal_transition().is_empty(),"Early portal consumed armor/shield or prepared an unearned successor")
		var dying: RefCounted=entered.evaluate(100)
		check.call(dying!=null and dying.frame_context().boundary.is_empty() and dying.frame_context().elapsed_ms==entered.frame_context().elapsed_ms+100 and dying.destruction_owner().snapshot().phase!="ready" and dying.equipment_owner().snapshot()==equipment.snapshot() and dying.prepare_game_over().is_empty(),"Early portal failed to run native destruction or fabricated an acknowledgement, successor or equipment change")
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):check.call(false,visuals.error);return
	var geometry: Node3D=load("res://src/presentation/void_portal_geometry.gd").new()
	var viewport:=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;host.root.add_child(viewport);viewport.add_child(geometry)
	var view:=Camera3D.new();viewport.add_child(view);view.far=500000;view.global_position=camera.origin;view.look_at(initial_state.position);view.current=true
	if not geometry.build_selected40(library,visuals,bindings,portal):check.call(false,geometry.error);viewport.free();return
	check.call(portal.advance(0,view.global_transform,random),portal.error)
	var prepared: Dictionary=geometry.prepare_state(portal.portal_snapshot())
	check.call(not prepared.is_empty(),geometry.error)
	if not prepared.is_empty():geometry.commit_state(prepared)
	check.call(geometry.model.get_child_count()>0 and geometry.visible,"Selected40 portal has no original animated geometry")
	if DisplayServer.get_name()!="headless":
		await host.process_frame;await host.process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		var min_red:=1.0;var max_red:=0.0
		for y in range(0,image.get_height(),3):
			for x in range(0,image.get_width(),3):
				var red:=image.get_pixel(x,y).r;min_red=minf(min_red,red);max_red=maxf(max_red,red)
		check.call(max_red-min_red>0.1,"Original selected40 portal rendered no visible variation")
		if not host.captures.is_empty():check.call(image.save_png(host.captures.path_join("selected40-portal-held225s.png"))==OK,"Portal capture failed")
	viewport.free()
	check.call(origin.snapshot()==original,"Detached portal probes modified the retained native flight")
	print("Selected40 portal: original40/kind161/source generation;225000ms animation/60000ms hold,zero RNG; contact thresholds/pull/pre-pull aim,early-entry hull-only rejection and native destruction,rollback and original two-surface geometry; no successor save")

static func render_state(frame: RefCounted) -> Dictionary:
	var state: Dictionary=frame.snapshot();var result: Dictionary=state.encounter
	result.player_pose=state.player_pose;result.moving_player=state.player;result.scenery=state.scenery;result.player_engines=state.player_engines
	result.native_detail=state.detail
	result.player_destruction=state.player_destruction
	if state.player_destruction.phase!="ready":result.player_pose=state.player_destruction.body_pose
	result.native_flight_frame=frame.fork_for_frame()
	return result
