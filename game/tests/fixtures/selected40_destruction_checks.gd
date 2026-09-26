extends RefCounted
## Explicit detached lethal-contact stimulus, NOT an earned campaign death.
## Every later pose, effect, clock and NPC frame comes from native evaluation.
const FlightChecks=preload("res://tests/fixtures/selected40_flight_checks.gd")
const Random=preload("res://src/simulation/seeded_random.gd")

static func run(host: SceneTree,origin: RefCounted,bindings: RefCounted,cat: RefCounted,before_reveal: RefCounted,library: RefCounted) -> Dictionary:
	var check: Callable=host.check;var result:={}
	check_reveal_boundary(host,before_reveal)
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):check.call(false,visuals.error);return {}
	var feedback: Control=load("res://src/presentation/selected40_feedback.gd").new();host.root.add_child(feedback);feedback.size=Vector2(1440,900)
	if not feedback.configure(library,bindings,visuals,origin):check.call(false,feedback.error);feedback.free();return {}
	check.call(not feedback.configure(library,bindings,visuals,origin),"Feedback replaced an already registered native lifetime")
	var held:=acknowledgements()
	for event in held:check.call(not feedback.handle_event(event),"Living selected40 accepted Continue")
	var exits:=[];feedback.exit_requested.connect(func(packet):exits.append(packet))
	var preserved: Dictionary=origin.snapshot()
	var frame: RefCounted=origin.evaluate(100,Vector2.ZERO,0.0)
	if frame==null:check.call(false,origin.error);feedback.free();return {}
	check.call(feedback.present(frame,100),feedback.error)
	check.call(feedback.audio.snapshot().active.has("player_engine"),"Living death-test origin never played its retained engine")
	var initial: Dictionary=frame.effects_state()
	check.call(initial.damage_particles.owners.size()==14 and not initial.damage_particles.owners.has("npc0") and not initial.damage_particles.owners.player.has("smoke"),"Selected40 registered a freighter/player as opening fighter smoke")
	var death: RefCounted=frame.destruction_owner();var before: Dictionary=death.snapshot()
	check.call(not death.configure_selected40(bindings,frame.encounter_owner().destruction_resources(),cat,frame.player_owner(),frame.scenery_owner(),frame.equipment_owner(),frame.frame_context().player_pose,initial.camera_pose) and death.snapshot()==before,"Repeated destruction setup replaced its native lifetime")
	var foreign: RefCounted=frame.player_owner();foreign._selected40_construction=RefCounted.new()
	check.call(not foreign.normal_hit(100000).is_empty(),foreign.error)
	check.call(not death.start(foreign,frame.frame_context().player_pose,Vector3.ZERO,initial.camera_pose,40) and death.snapshot()==before,"Destruction admitted an unrelated native player with copied content IDs")
	var particles: RefCounted=frame.damage_particles_owner();var particles_before: Dictionary=particles.snapshot()
	check.call(not particles.configure_selected40(bindings,frame.encounter_owner().combat_owner(),death,1) and particles.snapshot()==particles_before,"Particle setup replaced existing lifetimes")
	var untouched: Dictionary=frame.snapshot()
	var damaged: RefCounted=frame.fork_for_frame()
	check.call(not damaged._player.normal_hit(100000).is_empty(),damaged._player.error)
	var started: RefCounted=damaged.evaluate(100,Vector2.ZERO,0.0)
	if started==null:check.call(false,damaged.error);feedback.free();return {}
	frame=started
	check.call(feedback.present(frame,200),feedback.error)
	check.call(not frame.engine_audio_owner().snapshot().active and not feedback.audio.snapshot().active.has("player_engine"),"Late lethal contact left the retained player engine playing")
	var stops: Array=feedback.audio.snapshot().history.filter(func(event):return event.revision==frame.frame_context().revision)
	check.call(stops.size()>=10 and stops[0].action=="stop_music" and stops[1].action=="stop_player_engine" and stops.slice(2,10).map(func(event):return event.source_id)==Array(bindings.player_destruction.stop_sound_ids).map(func(id):return int(id)),"Selected40 death lost original current-music/engine and cached sound stop order")
	var start: Dictionary=frame.destruction_owner().snapshot();var frozen_camera: Transform3D=frame.frame_context().encounter.view.camera.pose
	check.call(start.phase=="tumble" and start.elapsed_ms==0 and start.events.started and not frame.player_owner().snapshot().active,"Lethal contact failed to start native destruction at the late zero-age poll")
	check.call(frame.frame_context().boundary.is_empty() and not frame.frame_context().input.enabled and not frame.engine_particles_owner().engine_enabled(),"Death retained input/exhaust or stopped at the old unsupported boundary")
	check.call(frame._particles.snapshot().births.get("player",0)==0 and frame._particles._emitters.player.snapshot().enabled,"The late death poll emitted particles during the already completed manager pass")
	check.call(frame.camera_input(3)==null and frame.select_secondary(42)==null,"Destroyed player accepted a new camera/equipment action")
	result.death_start=FlightChecks.render_state(frame)
	var paused: RefCounted=frame.evaluate(100,Vector2.ONE,1.0,true,true)
	check.call(paused!=null and paused.snapshot()==frame.snapshot(),"Paused destruction advanced clocks, RNG, particles or world actors")
	var zero: RefCounted=frame.evaluate(0,Vector2.ZERO,0.0)
	check.call(zero!=null,frame.error)
	if zero!=null:
		var zero_death: Dictionary=zero.destruction_owner().snapshot()
		check.call(zero_death.elapsed_ms==0 and zero_death.player_updates==start.player_updates+1 and zero_death.model_rotation!=start.model_rotation,"Zero-time death lost its source per-update Euler spin")
		check_zero_particle_time(host,frame.damage_particles_owner().snapshot(),zero.damage_particles_owner().snapshot())
		var smoke_before: Dictionary=frame._particles._smoke.snapshot();var smoke_after: Dictionary=zero._particles._smoke.snapshot()
		check.call(smoke_before.elapsed_ms==smoke_after.elapsed_ms and smoke_before.manager_ms==smoke_after.manager_ms,"Zero-time world advanced the separate smoke/fire manager clocks")
	var breakup_count:=0;var frozen_pose: Variant=null;var stopped_updates:=-1
	for tick in 160:
		var prior: Dictionary=frame.destruction_owner().snapshot()
		if prior.elapsed_ms==2900:
			var broken: RefCounted=frame.fork_for_frame();broken._notices._rules={}
			var bad_before: Dictionary=broken.snapshot();var good_before: Dictionary=frame.snapshot()
			check.call(broken.evaluate(100,Vector2.ONE,1.0,true)==null and broken.snapshot()==bad_before and frame.snapshot()==good_before,"Last-phase failure leaked a staged breakup, burst, shared sound RNG or NPC motion")
			var late_particles: RefCounted=frame.fork_for_frame();late_particles._particles._smoke._npc_count=12
			var late_before: Dictionary=late_particles.snapshot()
			check.call(late_particles.evaluate(100,Vector2.ONE,1.0,true)==null and late_particles.snapshot()==late_before and frame.snapshot()==good_before,"Rejected late NPC particle pass partially committed destruction")
		var next: RefCounted=frame.evaluate(100,Vector2.ONE,1.0,true,false,Vector2i.ZERO,1.0,true)
		if next==null:check.call(false,frame.error);feedback.free();return result
		if prior.elapsed_ms in [2900,8000]:
			var old_feedback: Dictionary=feedback.snapshot();var old_world: Dictionary=feedback.world_owner().snapshot()
			var invalid_sound: RefCounted=next.fork_for_frame();invalid_sound._death._state.events.audio_events[0].source_id=-99
			check.call(not feedback.present(invalid_sound,200+100*(tick+1)) and feedback.snapshot()==old_feedback and feedback.world_owner().snapshot()==old_world,"Invalid native sound committed the game-over panel or world")
			check.call(not feedback.present(next,-1) and feedback.snapshot()==old_feedback and feedback.world_owner().snapshot()==old_world,"Late panel rejection committed a prepared breakup/failure sound or world revision")
			var foreign_feedback: RefCounted=next.fork_for_frame();foreign_feedback._presentation_identity=RefCounted.new()
			check.call(not feedback.present(foreign_feedback,200+100*(tick+1)) and feedback.snapshot()==old_feedback,"Foreign audio frame replaced accepted feedback")
		check.call(feedback.present(next,200+100*(tick+1)),feedback.error)
		check.call(not next.engine_audio_owner().snapshot().active and next.engine_audio_owner().snapshot().elapsed_ms==next.frame_context().elapsed_ms and not feedback.audio.snapshot().active.has("player_engine"),"Continuing death clocks restarted the stopped engine")
		var once: Dictionary=feedback.snapshot()
		check.call(feedback.present(next,200+100*(tick+1)) and feedback.snapshot()==once,"Passive feedback replay advanced audio RNG or repeated native sounds")
		var state: Dictionary=next.destruction_owner().snapshot();var context: Dictionary=next.frame_context()
		check.call(context.boundary.is_empty() and context.encounter.elapsed_ms==context.elapsed_ms and context.encounter.world_elapsed_ms==context.elapsed_ms and next._particles._elapsed_ms==context.elapsed_ms and next._particles._smoke._elapsed_ms==context.elapsed_ms,"Death desynchronized weapon/world/general/smoke clocks")
		check.call(context.encounter.view.camera.pose==frozen_camera and not context.input.enabled and not context.encounter.sequence.hud_visible and context.encounter.sequence.frame.camera_operations.is_empty(),"Death allowed cinematic/follow input or changed its frozen source camera")
		check.call(context.throttle==0.0 and not next.engine_particles_owner().engine_enabled(),"Held controls re-enabled movement throttle or exhaust during destruction")
		if prior.player_updates_enabled:
			check.call(state.player_updates==prior.player_updates+1 and state.statistics_pose.basis==context.player_pose.basis*prior.rendered_model_basis,"Destruction statistics used the new rendered bank instead of the preceding player sample")
		else:
			if frozen_pose==null:frozen_pose=context.player_pose;stopped_updates=int(state.player_updates)
			check.call(context.player_pose==frozen_pose and state.player_updates==stopped_updates,"Player continued updating after the source fade-end gate")
		if state.events.get("breakup",false):
			breakup_count+=1
			check.call(state.elapsed_ms==3000 and not state.body_visible,"Breakup failed its exact three-second body gate")
			check_breakup_order(host,frame,next)
			var trail: Dictionary=next._particles._emitters.player.snapshot()
			check.call(trail.enabled and not trail.visible and next._particles._burst_count==1,"Late poll restored particle drawing or omitted its one-shot world burst")
			result.death_breakup=FlightChecks.render_state(next)
		if state.elapsed_ms==3100:check.call(state.effect==prior.effect,"Effect advanced at the excluded exact-3000 preceding-clock boundary")
		if state.elapsed_ms==8000:check.call(not state.failed,"Player failure crossed the strict eight-second threshold early")
		if state.elapsed_ms==8100:check.call(state.failed and state.failure_elapsed_ms==0,"Native death failed to start its independent delayed failure clock")
		if state.elapsed_ms==1500:result.death_trail=FlightChecks.render_state(next)
		if state.elapsed_ms==3300:result.death_explosion=FlightChecks.render_state(next)
		if state.fade_elapsed_ms==2000:result.death_fade=FlightChecks.render_state(next)
		frame=next
	check.call(breakup_count==1 and frame._particles._burst_count==1 and frame.destruction_owner().snapshot().phase=="game_over" and frozen_pose!=null,"Native death did not reach its single breakup and stopped-player/world-continuing fade boundary")
	check.call(frame.player_owner().snapshot().campaign_cursor==40 and not frame.frame_context().encounter.sequence.failure_observed and frame.equipment_owner().snapshot()==origin.equipment_owner().snapshot(),"Player destruction spent paid ammunition or invented a mission result")
	check.call(origin.snapshot()==preserved and damaged._death.snapshot().phase=="ready" and untouched.player_destruction.phase=="ready","Detached destruction changed the supplied living flight")
	result.death_game_over=FlightChecks.render_state(frame)
	check_feedback_exit(host,feedback,frame,origin,held,exits,bindings)
	feedback.free()
	print("Selected40 destruction: 160 ordered native frames; one3000ms breakup, strict>8000 failure, frozen camera, stopped player after fade with world continuing; explicit detached lethal stimulus, no result/save")
	return result

static func acknowledgements() -> Array[InputEvent]:
	var key:=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true
	var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=true
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
	var touch:=InputEventScreenTouch.new();touch.index=3;touch.pressed=true
	var trigger:=InputEventJoypadMotion.new();trigger.axis=JOY_AXIS_TRIGGER_RIGHT;trigger.axis_value=1.0
	return [key,pad,mouse,touch,trigger]

static func check_feedback_exit(host: SceneTree,feedback: Control,frame: RefCounted,origin: RefCounted,held: Array,exits: Array,bindings: RefCounted) -> void:
	var before: Dictionary=frame.snapshot();var source: Dictionary=origin.snapshot()
	var history: Array=feedback.audio.snapshot().history
	var player_sounds: Array=history.filter(func(event):return event.get("actor_id")=="player" and event.action in ["start","start_spatial"])
	host.check(player_sounds.size()==2 and player_sounds[0].source_id in [18,19] and player_sounds[0].action=="start_spatial" and player_sounds[1].source_id==37 and player_sounds[1].action=="start","Native selected40 death did not play exactly one spatial breakup and one delayed failure sound")
	host.check(history.any(func(event):return event.has("radio_event")),"Death feedback lost independently continuing original timed radio")
	for event in held:host.check(not feedback.handle_event(event) and exits.is_empty(),"Held pre-death input crossed the fade into Continue")
	for event in held:
		var released: InputEvent=event.duplicate()
		if released is InputEventJoypadMotion:released.axis_value=0.0
		else:released.pressed=false
		host.check(not feedback.handle_event(released),"Input release acknowledged selected40 game over")
	feedback.set_paused(true)
	host.check(not feedback.request_exit() and not feedback.handle_event(held[0]) and exits.is_empty(),"Paused feedback acknowledged Continue")
	feedback.set_paused(false)
	host.check(not feedback.handle_event(held[0]) and exits.is_empty(),"Enter held through pause became a fresh acknowledgement")
	var released: InputEvent=held[0].duplicate();released.pressed=false;feedback.handle_event(released)
	var old_feedback: Dictionary=feedback.snapshot()
	var accepted_clock: int=feedback._absolute_ms;feedback._absolute_ms=-1
	host.check(not feedback.request_exit() and feedback.world_owner().snapshot()==before and feedback.prepare_game_over().is_empty() and exits.is_empty(),"Failed Continue display consumed native exit or emitted a caller transition")
	feedback._absolute_ms=accepted_clock
	host.check(feedback.snapshot()==old_feedback,"Rejected Continue changed the original screen or audio")
	host.check(feedback.handle_event(held[0]) and exits.size()==1,"A fresh original Continue did not reach its caller exactly once")
	var packet: Dictionary=feedback.prepare_game_over()
	host.check(packet=={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"source_state":1,"campaign_cursor":40} and exits[0]==packet,"Continue invented a retry/result instead of source menu state1")
	var stopped: RefCounted=feedback.world_owner();var stopped_state: Dictionary=stopped.snapshot()
	host.check(stopped.frame_context().boundary=="game_over_transition_required" and stopped.destruction_owner().snapshot().exit_requested and stopped.evaluate(100).snapshot()==stopped_state,"Accepted Continue allowed another world/particle/audio frame")
	host.check(not feedback.request_exit() and not feedback.handle_event(held[0]) and exits.size()==1 and feedback.audio.snapshot().history==history,"Continue replay emitted duplicate exit or audio")
	var committed: Dictionary=feedback.snapshot()
	host.check(not feedback.present(frame,accepted_clock) and feedback.snapshot()==committed and exits.size()==1,"Replaying the pre-exit parent reopened an acknowledged Continue")
	packet.source_state=99
	host.check(feedback.prepare_game_over().source_state==1 and frame.snapshot()==before and origin.snapshot()==source and stopped.equipment_owner().snapshot()==frame.equipment_owner().snapshot(),"Continue mutated parent flight, retained equipment or a detached packet")
	print("Selected40 feedback: original radio/weapon/death audio, same-revision no replay, held inputs blocked, late sound/panel/Continue rollback, exactly one caller-owned state1; no retry, reward or save")

static func check_reveal_boundary(host: SceneTree,origin: RefCounted) -> void:
	if origin==null:host.check(false,"Missing the actually reached pre-reveal frame");return
	var before: Dictionary=origin.snapshot();var context: Dictionary=origin.frame_context()
	host.check(context.elapsed_ms==39900 and context.encounter.sequence.phase==0,"Death boundary probe requires the retained native frame before reveal")
	var living: RefCounted=origin.evaluate(100,Vector2.ZERO,context.throttle)
	var candidate: RefCounted=origin.fork_for_frame()
	host.check(not candidate._player.normal_hit(100000).is_empty(),candidate._player.error)
	var dying: RefCounted=candidate.evaluate(100,Vector2.ZERO,context.throttle)
	if living==null or dying==null:host.check(false,origin.error+candidate.error);return
	var normal: Dictionary=living.frame_context();var stopped: Dictionary=dying.frame_context()
	host.check(normal.elapsed_ms==40000 and stopped.elapsed_ms==40000 and normal.encounter.sequence.radio==stopped.encounter.sequence.radio,"Death gate suspended or replaced the independently advancing native radio")
	host.check(normal.encounter.sequence.phase==1 and not normal.encounter.sequence.frame.camera_operations.is_empty(),"Living control did not actually reach the native reveal")
	host.check(stopped.encounter.sequence.phase==0 and stopped.encounter.sequence.frame.camera_operations.is_empty() and stopped.encounter.view.camera.pose==context.encounter.view.camera.pose,"Late lethal poll did not suppress the otherwise due reveal/camera cut")
	host.check(dying.destruction_owner().snapshot().events.started and dying.encounter_owner().combat_snapshot().actors[0].body_pose==origin.encounter_owner().combat_snapshot().actors[0].body_pose,"Death reveal guard moved the still-held freighter or skipped native destruction")
	host.check(origin.snapshot()==before,"Paired reveal/death boundary probe mutated its retained native parent")
	print("Selected40 death/reveal boundary40000: paired native radio clocks identical, living reveal executes, lethal late poll retains camera and held freighter")

static func check_zero_particle_time(host: SceneTree,before: Dictionary,after: Dictionary) -> void:
	# A zero-time WORLD frame still runs native NPC flag/root setters and the
	# repeated late player-emission poll. Only particle time/age/RNG is frozen.
	host.check(after.elapsed_ms==before.elapsed_ms and after.manager_ms==before.manager_ms and after.owners.keys()==before.owners.keys(),"Zero-time frame changed particle clocks or registrations")
	var changed:=[]
	for key in before.owners:
		for kind in ["trail","smoke","fire","burst"]:
			if not before.owners[key].has(kind):continue
			var a: Dictionary=before.owners[key][kind];var b: Dictionary=after.owners[key][kind]
			for field in ["slots","random","cursor","remainder_ms","baseline","velocity"]:
				host.check(a[field]==b[field],"Zero-time particle manager advanced %s/%s/%s"%[key,kind,field])
			for field in a:
				if a[field]!=b[field]:changed.append("%s/%s/%s"%[key,kind,field])
		for field in ["root_pose","damaged","mode","death_phase"]:
			if before.owners[key].get(field)!=after.owners[key].get(field):changed.append(key+"/"+field)
	print("Selected40 zero-time particle metadata (no ageing/private RNG): "+str(changed))

static func check_breakup_order(host: SceneTree,before: RefCounted,after: RefCounted) -> void:
	# Independently decompose the critical shared-RNG frame. Particle streams
	# are private; the single sound draw must precede weapon/sequence/NPC RNG.
	var check: Callable=host.check;var dt:=100
	var death: RefCounted=before.destruction_owner();var effects: RefCounted=before.damage_particles_owner()
	var pose: Transform3D=after.frame_context().player_pose
	var stats:=pose*Transform3D(death.snapshot().rendered_model_basis,Vector3.ZERO)
	var tail: Dictionary=death.advance(dt,pose,before.frame_context().random_state,false,stats)
	if tail.is_empty():check.call(false,death.error);return
	var random:=Random.new();check.call(random.restore(before.frame_context().random_state),random.error);random.next_int(2)
	check.call(tail.random_state==random.snapshot(),"Player breakup consumed more than its single shared sound draw")
	check.call(effects.apply_player_tail(death) and effects.advance(pose,dt) and effects.apply_player_poll(death),effects.error)
	var prior: Dictionary=before.frame_context().encounter
	var weapons: Dictionary=before.encounter_owner().evaluate_weapons(after.player_owner(),pose,dt,before.scenery_owner(),tail.random_state,true,not prior.sequence.radio.visible)
	if weapons.is_empty():check.call(false,"Reference breakup weapon phase failed");return
	var sequence: Dictionary=weapons.encounter.evaluate_selected40_sequence(dt,weapons.random_state,weapons.player,pose,Vector2i(1440,900),death,true)
	if sequence.is_empty():check.call(false,"Reference breakup sequence phase failed");return
	var fire: Dictionary=sequence.encounter.evaluate_primary_fire(weapons.player,pose,true,false,sequence.random_state)
	var secondary: Dictionary=fire.encounter.evaluate_secondary_fire(weapons.player,before.equipment_owner(),pose,true,false,fire.random_state,not sequence.sequence.radio.visible)
	var actors_before: Dictionary=secondary.encounter.combat_snapshot()
	var world: Dictionary=secondary.encounter.evaluate_world(secondary.player,pose,dt,secondary.random_state)
	if world.is_empty():check.call(false,"Reference breakup NPC phase failed");return
	check.call(effects.finish_npc_pass(actors_before,world.encounter.combat_snapshot(),world.encounter.actor_events(),dt,1.0),effects.error)
	check.call(weapons.scenery.update(dt,before.frame_context().get("reference",before._reference),1.0,null,world.random_state),weapons.scenery.error)
	check.call(after.frame_context().random_state==weapons.scenery.random_state() and after.encounter_owner().snapshot()==world.encounter.snapshot(),"Integrated breakup changed sound-before-weapon/sequence/NPC shared RNG ordering")
	check.call(after.damage_particles_owner().snapshot()==effects.snapshot(),"Integrated breakup reordered general manager, late poll, or NPC particle roots")
