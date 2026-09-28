extends RefCounted
## A complete candidate over admitted entry, pilot, scenery, combat and career.
## Host/renderers accept the candidate before consuming its one-shot directives.
const Context=preload("res://src/simulation/mission_context.gd")
const Runner=preload("res://src/simulation/mission_runner.gd")
const Encounter=preload("res://src/simulation/mission_encounter.gd")
const Pilot=preload("res://src/simulation/pilot_motion.gd")
const Contacts=preload("res://src/simulation/physical_scenery_contacts.gd")
const Aim=preload("res://src/simulation/opening_aim.gd")
const Engines=preload("res://src/simulation/player_engine_particles.gd")
const EngineAudio=preload("res://src/simulation/opening_engine_audio.gd")
const Music=preload("res://src/simulation/ordinary_music.gd")
const Radar=preload("res://src/simulation/fast_forward.gd")
const Death=preload("res://src/simulation/player_destruction.gd")
const Particles=preload("res://src/simulation/full_hold_particles.gd")
const Scanner=preload("res://src/simulation/opening_npc_scanner.gd")
const TargetFrame=preload("res://src/presentation/flight_target_frame.gd")
const ScanAnimation=preload("res://src/presentation/flight_scan_animation.gd")
const Targeting=preload("res://src/simulation/mining_targeting.gd")
const Notices=preload("res://src/simulation/flight_notices.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Detail=preload("res://src/presentation/ship_detail_group.gd")
const ShipDetail=preload("res://src/presentation/ship_detail.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Career=preload("res://src/simulation/opening_handoff.gd")
const VoidPortal=preload("res://src/simulation/void_portal.gd")
const Escape=preload("res://src/simulation/mission_escape_sequence.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
var error:=""
var _state:={}
var _context: RefCounted
var _world: RefCounted
var _runner: RefCounted
var _encounter: RefCounted
var _player: RefCounted
var _scenery: RefCounted
var _equipment: RefCounted
var _career: RefCounted
var _pilot: RefCounted
var _physical: RefCounted
var _camera: RefCounted
var _aim: RefCounted
var _engines: RefCounted
var _engine_audio: RefCounted
var _music: RefCounted
var _radar: RefCounted
var _music_context:={}
var _flight_music:={"operations":[]}
var _death: RefCounted
var _particles: RefCounted
var _scanner: RefCounted
var _targeting: RefCounted
var _notices: RefCounted
var _detail: RefCounted
var _bindings: RefCounted
var _library: RefCounted
var _portal: RefCounted
var _escape: RefCounted
var _presentation_identity: RefCounted
var _return_identity: RefCounted
var _pose:=Transform3D.IDENTITY
var _reference:=Vector3.ZERO
var _random:={}
var _initial_progress:={}
var _progress:={}
var _viewport:=Vector2i(1440,900)
var _throttle:=1.0
var _max_ms:=0
var _game_over:={}
var _primary_released:=true
var _secondary_released:=true

func configure(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,context: RefCounted,initialized_world: RefCounted,sensitivity:=1.0,viewport:=Vector2i(1440,900)) -> bool:
	error=""
	if not _state.is_empty() or not context is Context or not valid_viewport(viewport):return reject("Configure a fresh mission flight with its admitted context and viewport")
	var encounter:=Encounter.new()
	if not encounter.prepare(bindings,catalogues,library,context,initialized_world):return reject(encounter.error)
	var entry: RefCounted=initialized_world.entry_owner()
	var player: RefCounted=initialized_world.construction_owner().player_owner()
	var equipment: RefCounted=entry.equipment_owner();var career: RefCounted=entry.career_owner()
	if not context.matches_loadout(equipment.snapshot().loadout) or not equipment.cargo_cache_valid():return reject("Mission entry lost its retained equipment")
	var runner:=Runner.new();var pilot:=Pilot.new();var physical:=Contacts.new();var aim:=Aim.new()
	var pose: Transform3D=initialized_world.snapshot().player_pose
	var scenery: RefCounted=initialized_world.scenery_owner();var camera: RefCounted=initialized_world.camera_owner()
	var loadout: Dictionary=player.loadout()
	if not runner.configure(context) or not runner.prepare_conversations(bindings,library):return reject(runner.error)
	if not pilot.configure_vehicle(bindings,catalogues,bindings.base_content_id,int(loadout.ship_id),[],loadout.equipment_ids,sensitivity):return reject(pilot.error)
	if not physical.configure(bindings.physical_scenery_contacts,context.identity(),{},scenery.read_snapshot().bodies):return reject(physical.error)
	if not aim.configure(bindings) or not aim.advance(pose,camera.snapshot().pose,viewport):return reject(aim.error)
	var mounts:=Mounts.new();var engines:=Engines.new();var audio:=EngineAudio.new();var death:=Death.new()
	if not mounts.open(library,catalogues) or not engines.configure(bindings,mounts,int(loadout.ship_id),scenery.seed_seconds()):return reject(mounts.error+engines.error)
	if not audio.has_method("configure_mission") or not death.has_method("configure_mission"):return reject("Mission flight needs admitted configure_mission entry points on OpeningEngineAudio and PlayerDestruction")
	if not audio.configure_mission(bindings,catalogues,context,player,pose):return reject(audio.error)
	var music:=Music.new();var radar:=Radar.new()
	if not music.configure(bindings.ordinary_music) or not radar.configure(bindings) or not radar.configure_radar(catalogues,loadout.equipment_ids):return reject(music.error+radar.error)
	# This admitted route retains the preceding world's actual unequipped
	# scanner. Its source skip-NPC-loop branch does not count visible enemies.
	if not radar.publish_without_scanner(false):return reject(radar.error)
	var music_context:={"world_type":int(initialized_world.snapshot().world_type),"campaign_cursor":int(context.identity().campaign_cursor),
		"selected_station_id":int(context.recipe().station_id),"system_id":int(context.recipe().system_id),
		"retained_void_station_id":-1,"void_source_station_id":int(entry.snapshot().source_before.source_station_id)}
	if Music.context_kind(music_context,0).is_empty():return reject("Admitted mission lacks its source music location")
	if not death.configure_mission(bindings,encounter.destruction_resources(),catalogues,context,player,pose,camera.snapshot().pose):return reject(death.error)
	var particles:=Particles.new()
	if not particles.configure_mission(bindings,context,encounter.combat_owner(),death,scenery.seed_seconds()):return reject(particles.error)
	var detail:=Detail.new();var selectors:={};var positions:={};var player_detail:=ShipDetail.new()
	if not player_detail.configure(bindings.ship_lod,int(loadout.ship_id)):return reject(player_detail.error)
	if player_detail.has_alternates():selectors["player"]=player_detail;positions["player"]=pose.origin
	for actor in encounter.combat_snapshot().actors:
		var selector:=ShipDetail.new();var assembly: Dictionary=encounter.freighter_assembly(actor.actor_id)
		var ready: bool=selector.configure(bindings.ship_lod,int(actor.hull_catalogue_id)) if assembly.is_empty() else selector.configure_assembly(bindings,assembly)
		if not ready:return reject(selector.error)
		if selector.has_alternates():selectors[actor.actor_id]=selector;positions[actor.actor_id]=actor.body_pose.origin
	if not detail.configure_selectors(bindings,selectors) or not detail.refresh(positions,Vector3.ZERO,1.0):return reject(detail.error)
	var art:=TargetFrame.source_geometry(library,bindings)
	var strip:=ScanAnimation.source_geometry(library,bindings,bindings.opening_staging.npc_scanner)
	var asteroid_strip:=ScanAnimation.source_geometry(library,bindings,bindings.mining_targeting)
	if art.has("error") or strip.has("error") or asteroid_strip.has("error"):return reject("Mission scanner artwork declarations are unavailable")
	var radii:=TargetFrame.logical_radii(art.quarter_size,false)
	var scanner:=Scanner.new();var targeting:=Targeting.new();var notices:=Notices.new()
	if not scanner.configure_mission(bindings,catalogues,radii,int(strip.frames),equipment,encounter.combat_owner(),context) or not targeting.configure_mission(bindings,catalogues,equipment,scenery,radii,int(asteroid_strip.frames),context) or not notices.configure_mission(bindings,library,context):return reject(scanner.error+targeting.error+notices.error)
	if not scanner.advance_mission(encounter.combat_owner(),pose,camera.snapshot().pose,aim.snapshot(),0,false) or not targeting.advance(scenery,pose,camera.snapshot().pose,aim.snapshot(),0,false):return reject(scanner.error+targeting.error)
	var portal: RefCounted
	if context.has_feature("portal"):
		portal=VoidPortal.new()
		if not portal.configure_admitted_world(bindings,context,initialized_world.snapshot(),library):return reject(portal.error)
		if not portal.set_visible(context.recipe().get("portal_policy",{}).get("initially_visible",true)):return reject(portal.error)
	# Pools come from the actual living portal. Only permission changes at entry.
	if not player.set_permissions(player.snapshot().active,false):return reject(player.error)
	_context=context;_world=initialized_world;_bindings=bindings;_library=library;_runner=runner;_encounter=encounter
	_portal=portal
	_player=player;_scenery=scenery;_equipment=equipment;_career=career;_pilot=pilot;_physical=physical
	_camera=camera;_aim=aim;_engines=engines;_engine_audio=audio;_death=death;_particles=particles;_detail=detail
	_music=music;_radar=radar;_music_context=music_context
	_scanner=scanner;_targeting=targeting;_notices=notices
	_pose=pose;_viewport=viewport;_max_ms=Frames.simulation_limit(bindings);_random=initialized_world.snapshot().random_state.duplicate(true)
	_initial_progress=career.snapshot().progress.duplicate(true);_progress=_initial_progress.duplicate(true)
	_presentation_identity=RefCounted.new()
	_state=context.identity();_state.merge({"scope":"mission_flight","station_id":context.recipe().station_id,"system_id":context.recipe().system_id,
		"language":library.active_language,"mission":context.recipe().mission,
		"world_type":initialized_world.snapshot().world_type,"elapsed_ms":0,"revision":0,"phase":"ready","boundary":"",
		"entry_elapsed_ms":0,"entry_released":false,"entry_skipped":false,"physical_contacts":[],"input":{},"application_committed":false})
	return true

func prepare(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,context: RefCounted,initialized_world: RefCounted,sensitivity:=1.0,viewport:=Vector2i(1440,900)) -> bool:
	return configure(bindings,catalogues,library,context,initialized_world,sensitivity,viewport)

func evaluate(milliseconds: Variant,commands:=Vector2.ZERO,throttle:=1.0,primary_fire:=false,paused:=false,viewport:=Vector2i.ZERO,strafe:=0.0,secondary_fire:=false,current_music_id:=-1,relative_mouse_capture:=false) -> RefCounted:
	error=""
	var size:=_viewport if viewport==Vector2i.ZERO else viewport
	if _state.is_empty() or not Numbers.integer(milliseconds,0,_max_ms) or _state.elapsed_ms>2147483647-milliseconds or not valid_viewport(size) or not commands.is_finite() or absf(commands.x)>1 or absf(commands.y)>1 or not is_finite(throttle) or throttle<0 or throttle>1 or strafe not in [-1.0,0.0,1.0] or not Numbers.integer(current_music_id,-1,2292):return failed("Invalid mission flight time or pilot input")
	var next:=fork_for_frame()
	if paused or not _state.boundary.is_empty() or campaign_dialogue_visible():return next
	var prior: Dictionary=_encounter.frame_context()
	if prior.pending_world or prior.elapsed_ms!=_state.elapsed_ms or prior.world_elapsed_ms!=_state.elapsed_ms:return failed("Mission flight lost its completed encounter frame")
	var dying: bool=_death.snapshot().phase!="ready"
	var blocked: bool=prior.sequence.input_blocked or (_escape!=null and _escape.snapshot().input_blocked)
	var automatic: bool=_escape!=null and _escape.snapshot().automatic_forward
	var moving: bool=(not blocked or automatic) and (not dying or _death.player_updates_enabled())
	var enabled_before: bool=_state.entry_released and not blocked and not dying
	var seconds:=float(milliseconds)/1000.0
	next._state.physical_contacts=[]
	if moving:
		var response: Dictionary=next._camera.response_snapshot()
		if response.relative_capture!=relative_mouse_capture or response.player_handling!=next._pilot.response_factor():next._camera.mark_response_dirty()
		if not next._camera.refresh_player_response(relative_mouse_capture,next._pilot.response_factor()) or not next._engine_audio.before_ordinary_motion():return failed(next._camera.error+next._engine_audio.error)
		next._pose=next._pilot.advance_prepared(_pose,throttle if enabled_before else _throttle,seconds,strafe if enabled_before else 0.0)
		if not next._pilot.error.is_empty():return failed(next._pilot.error)
		var contact: Dictionary=next._physical.plan(next._player.collision_context(next._pose),next._scenery.read_snapshot().bodies,enabled_before)
		if contact.is_empty() or not next._scenery.apply_physical_contacts(contact.operations):return failed(next._physical.error+next._scenery.error)
		for operation in contact.operations:
			if operation.kind=="asteroid" and next._player.normal_hit(operation.player_damage).is_empty():return failed(next._player.error)
		next._pose.origin=contact.center_after;next._state.physical_contacts=contact.operations
		if next._player.advance_recharge(milliseconds).is_empty() or next._player.advance_repair(milliseconds).is_empty():return failed(next._player.error)
		if not next._aim.advance(next._pose,_camera.snapshot().pose,size):return failed(next._aim.error)
		# Contact samples the preceding portal clock, after solid scenery and
		# before weapons/radio. Opening later in this frame cannot teleport us.
		if next._portal!=null:
			if not next._portal.observe_contact({"player_pose":next._pose,"environment_contact_enabled":enabled_before and next._player.collision_context(next._pose).eligible,"mining_active":false}):return failed(next._portal.error)
			var portal_contact: Dictionary=next._portal.snapshot().contact
			if not portal_contact.is_empty() and portal_contact.pull_distance>0:
				next._pose.origin=VoidPortal.Vectors.added(next._pose.origin,VoidPortal.Vectors.scaled(VoidPortal.Vectors.normalized(-portal_contact.player_offset),float(portal_contact.pull_distance)))
			if next._escape==null and next._portal.transition_ready(next._player.snapshot().vitals.hull) and _context.recipe().get("portal_policy",{}).get("unauthorized_exit")=="destroy_player":
				if next._player.normal_hit(2147483647).is_empty():return failed(next._player.error)
	if dying:
		var tail: Dictionary=next._death.advance(milliseconds,next._pose,next._random,false,next._pose,moving)
		if tail.is_empty():return failed(next._death.error)
		next._random=tail.random_state
		if not next._particles.apply_player_tail(next._death):return failed(next._particles.error)
	var contacts: Dictionary=next._encounter.evaluate_weapons(next._player,next._pose,milliseconds,next._scenery,next._random,true,not prior.radio.visible)
	if contacts.is_empty():return failed(next._encounter.error)
	next._encounter=contacts.encounter;next._player=contacts.player;next._scenery=contacts.scenery;next._random=contacts.random_state
	if not dying and next._player.snapshot().vitals.hull<=0:
		if not next._death.start(next._player,next._pose,Vector3.ZERO,next._camera.snapshot().pose,_state.campaign_cursor,Basis.IDENTITY,next._pose,next._encounter.secondary_owner()):return failed(next._death.error)
		if not next._player.set_permissions(false,next._player.snapshot().damage_allowed) or not next._engines.set_engine_enabled(false):return failed(next._player.error+next._engines.error)
		dying=true
	if dying and not next._particles.apply_player_poll(next._death):return failed(next._particles.error)
	# This poll cannot observe completion produced by the late sequence below.
	var observation: Dictionary=next._encounter.result_observation()
	var radio: Dictionary=next._encounter.radio_owner().snapshot()
	if not next._runner.sample_clock(_state.elapsed_ms+milliseconds,int(_runner.snapshot().clock_ms)+milliseconds):return failed(next._runner.error)
	var result: Dictionary=next._runner.poll(observation.actors,radio.visible,_state.entry_released and not blocked,not dying,observation.sequences)
	if result.is_empty():return failed(next._runner.error)
	if result.mode!=0 and not next._runner.open_result():return failed(next._runner.error)
	# Success returns before the late script, new firing, NPCs and camera.
	# Failure has no corresponding early return. Preserve the completed early
	# player/contact work and close its staged frame for the retained world.
	if result.mode==1:
		var completed_result: Dictionary=next._encounter.finish_before_sequence()
		if completed_result.is_empty():return failed(next._encounter.error)
		next._encounter=completed_result.encounter
		if not next._engine_audio.retain_frame(milliseconds):return failed(next._engine_audio.error)
		if not next._particles.retain_frame(milliseconds) or not next._engines.retain_frame(milliseconds):return failed(next._particles.error+next._engines.error)
		next._viewport=size;next._flight_music={"operations":[]}
		next._state.elapsed_ms+=milliseconds;next._state.revision+=1
		next._state.input={"enabled":false,"commands":Vector2.ZERO,"primary_held":false,"secondary_requested":false,"throttle":next._throttle}
		if not next._observe_progress():return failed(next.error)
		return next
	var sequence: Dictionary=next._encounter.evaluate_sequence(next._camera)
	if sequence.is_empty():return failed(next._encounter.error)
	next._encounter=sequence.encounter;next._player=sequence.player;next._random=sequence.random_state
	var cue: Dictionary=sequence.sequence
	if next._escape!=null and not dying:
		var rng:=Random.new()
		if not rng.restore(next._random) or not next._escape.advance(milliseconds,next._encounter.radio_owner(),next._player,next._portal,next._pose,_world.environment_owner().object_state(0).pose,rng,_camera):return failed(rng.error+next._escape.error)
		var escape: Dictionary=next._escape.snapshot()
		next._random=escape.random_state
		for action in escape.frame.portal_actions:
			var accepted: bool=next._portal.open_at(action.position,action.hold_open) if action.action=="open_at" else next._portal.begin_closing(action.age_ms)
			if not accepted:return failed(next._portal.error)
		if not next._player.set_permissions(next._player.snapshot().active,escape.player_damage_allowed):return failed(next._player.error)
		if not escape.frame.input_actions.is_empty():
			next._pilot.angular_units=Vector2.ZERO;next._pilot.lateral_units_per_millisecond=0.0
			next._primary_released=false;next._secondary_released=false
	if cue.frame.cancel_actions:
		next._pilot.angular_units=Vector2.ZERO;next._pilot.lateral_units_per_millisecond=0.0
		next._primary_released=false;next._secondary_released=false
	if not primary_fire:next._primary_released=true
	if not secondary_fire:next._secondary_released=true
	if not _state.entry_released:
		next._state.entry_elapsed_ms+=milliseconds
		if next._state.entry_elapsed_ms>=int(_context.recipe().entry_release_ms) and not dying and not next.campaign_dialogue_visible():
			next._state.entry_released=true
			if not next._player.set_permissions(true,cue.player_damage_allowed) or not next._runner.open_briefing():return failed(next._player.error+next._runner.error)
	var enabled: bool=next._state.entry_released and not cue.input_blocked and (next._escape==null or not next._escape.snapshot().input_blocked) and not dying and not next.campaign_dialogue_visible()
	if not next._pilot.sample_commands(commands if enabled else Vector2.ZERO,seconds) or not next._engine_audio.sample_commands(commands if enabled else Vector2.ZERO):return failed(next._pilot.error+next._engine_audio.error)
	var fired: Dictionary=next._encounter.evaluate_primary_fire(next._player,next._pose,primary_fire and next._primary_released,enabled,next._random,[] if next._scanner==null else next._scanner.weapon_target_ids())
	if fired.is_empty():return failed(next._encounter.error)
	next._encounter=fired.encounter;next._random=fired.random_state
	var secondary: Dictionary=next._encounter.evaluate_secondary_fire(next._player,next._equipment,next._pose,secondary_fire and next._secondary_released,enabled,next._random,not radio.visible)
	if secondary.is_empty():return failed(next._encounter.error)
	next._encounter=secondary.encounter;next._player=secondary.player;next._equipment=secondary.equipment;next._random=secondary.random_state
	var before_actors: Dictionary=next._encounter.combat_snapshot()
	var motion: Dictionary=next._encounter.evaluate_world(next._player,next._pose,milliseconds,next._random)
	if motion.is_empty():return failed(next._encounter.error)
	if not next._particles.finish_npc_pass(before_actors,motion.encounter.combat_snapshot(),motion.encounter.actor_events(),milliseconds,1.0):return failed(next._particles.error)
	next._encounter=motion.encounter;next._random=motion.random_state
	if not next._particles.apply_sequence(cue.frame.get("effects",[]),next._encounter.combat_snapshot().actors):return failed(next._particles.error)
	var completed: Dictionary=next._encounter.frame_context().sequence
	if not dying:
		if completed.phase>0:next._camera=next._encounter.camera_owner()
		else:
			var scene: Dictionary=_context.identity();scene.player_pose=next._pose
			var shot: Dictionary=_context.identity();shot.merge({"target":"player","mode":"follow","inherit_target_up":true})
			if not next._state.entry_released:shot.merge({"mode":"fixed_eye","eye":_world.camera_initialization().snapshot().fixed_shot.eye},true)
			if not next._camera.update(milliseconds,shot,scene):return failed(next._camera.error)
	elif not next._death.sample_camera(next._camera.snapshot().pose,false):return failed(next._death.error)
	# Both native hooks sampled the same preceding camera, not each other's
	# already advanced follow pose. The active sequence owns the final view.
	if next._escape!=null and not dying:next._camera=next._escape.camera_owner()
	if not next._aim.sample_feedback(next._encounter.primary_npc_contact(),milliseconds,enabled):return failed(next._aim.error)
	if not next._engine_audio.follow_player(next._pose,int(next._player.snapshot().vitals.hull),milliseconds):return failed(next._engine_audio.error)
	if not dying and not next._engines.set_engine_enabled((throttle if enabled else _throttle)>0):return failed(next._engines.error)
	if not next._engines.advance(next._pose,milliseconds):return failed(next._engines.error)
	if not next._particles.advance(next._pose,milliseconds):return failed(next._particles.error)
	var positions:={};var registered: Dictionary=next._detail.snapshot().selections
	if registered.has("player"):positions["player"]=next._pose.origin
	for actor in next._encounter.combat_snapshot().actors:
		if registered.has(actor.actor_id):positions[actor.actor_id]=actor.body_pose.origin
	if not next._detail.update(milliseconds,positions,_reference,1.0,false):return failed(next._detail.error)
	var immediate: Variant=next._camera.snapshot().eye if cue.frame.refresh_geometry_detail else null
	if immediate!=null and not next._detail.refresh(positions,immediate,1.0):return failed(next._detail.error)
	if not next._scenery.update(milliseconds,_reference,1.0,immediate,next._random):return failed(next._scenery.error)
	next._random=next._scenery.random_state();next._reference=next._camera.snapshot().eye;next._viewport=size
	if next._portal!=null:
		var rng:=Random.new()
		if not rng.restore(next._random) or not next._portal.advance(milliseconds,next._camera.snapshot().pose,rng):return failed(rng.error+next._portal.error)
		next._random=rng.snapshot()
	# The shared HUD pass follows actor motion with the committed camera. Hidden
	# cinematic frames keep acquisition history without advancing selection.
	var hud_on: bool=next._state.entry_released and bool(next._encounter.frame_context().sequence.hud_visible) and (next._escape==null or next._escape.snapshot().hud_visible) and not dying and not next.campaign_dialogue_visible()
	var aim_state: Dictionary=next._aim.snapshot();var camera_pose: Transform3D=next._camera.snapshot().pose
	if not next._scanner.advance_mission(next._encounter.combat_owner(),next._pose,camera_pose,aim_state,milliseconds,hud_on):return failed(next._scanner.error)
	var scan: Dictionary=next._scanner.snapshot()
	if not next._notices.enqueue_scanner(scan.events,next._encounter):return failed(next._notices.error)
	if not next._targeting.advance(next._scenery,next._pose,camera_pose,aim_state,milliseconds,hud_on,false,scan.candidate_actor_id>=0 and scan.selected_actor_id<0,scan.get("found_actor_id",-1)>=0):return failed(next._targeting.error)
	for event in next._targeting.snapshot().events:
		if event.get("kind")=="notification" and not next._notices.enqueue(event.get("source_id")):return failed(next._notices.error)
	if not next._notices.advance(milliseconds,false):return failed(next._notices.error)
	if not next._radar.publish_without_scanner(hud_on,current_music_id):return failed(next._radar.error)
	next._music_context.campaign_cursor=int(next._state.campaign_cursor)
	var music: Dictionary=next._music.prepare_for_context(current_music_id,next._radar.battle_count(),-1,hud_on,next._music_context)
	if music.is_empty():return failed(next._music.error)
	next._flight_music={"operations":music.operations}
	if enabled:next._throttle=throttle
	next._state.elapsed_ms+=milliseconds;next._state.revision+=1
	next._state.input={"enabled":enabled,"commands":commands if enabled else Vector2.ZERO,"primary_held":primary_fire and enabled and next._primary_released,"secondary_requested":secondary_fire and enabled and next._secondary_released,"throttle":next._throttle}
	if not next._observe_progress():return failed(next.error)
	if next._escape!=null and not next._escape.snapshot().boundary.is_empty():
		next._state.boundary=next._escape.snapshot().boundary
		next._return_identity=RefCounted.new()
	return next

## Baseline plus native cumulative deltas, never last-frame totals plus totals.
## The independent passenger job is untouched until the career boundary commits.
func _observe_progress() -> bool:
	var state: Dictionary=_encounter.snapshot();var totals: Dictionary=state.controller.accounting.counter_deltas
	var progress:=_initial_progress.duplicate(true)
	for key in ["player_kills","pirate_kills","debris_destroyed","capital_ship_kills"]:
		if progress.has(key) or totals.has(key):progress[key]=int(_initial_progress.get(key,0))+int(totals.get(key,0))
	var recovered: int=_encounter.recovery_totals().get("accepted_quantity",0)
	if recovered>0 or progress.has("cargo_recovered"):progress.cargo_recovered=Career.recovered_cargo_total(int(_initial_progress.get("cargo_recovered",0)),recovered)
	progress.reputation=_encounter.combat_owner().reputation_after(_initial_progress.reputation)
	var score:=Career.calculate_progress(_bindings.opening_handoff,_state.campaign_cursor,progress.player_kills,progress.pirate_kills,progress.other_score)
	if score.is_empty() or progress.reputation.is_empty() or progress.get("cargo_recovered",0)<0:return reject("Mission combat lost its retained career counters")
	progress.merge(score,true);_progress=progress
	return true

func navigate(action: String) -> RefCounted:
	error=""
	if _state.is_empty() or not _state.boundary.is_empty():return failed("No mission conversation can be accepted")
	var next:=fork_for_frame();var outcome: Dictionary=next._runner.navigate(action)
	if outcome.is_empty():return failed(next._runner.error)
	# A page change is a new displayed frame at the same simulation time.
	next._state.revision+=1
	if outcome.acknowledged:
		if outcome.kind=="success":
			var completed_context: RefCounted=_runner.context_owner()
			var career: RefCounted=_career.fork()
			if not career.advance_mission_story(_bindings,completed_context,_progress):return failed(career.error)
			next._career=career;next._progress=career.snapshot().progress.duplicate(true)
			next._state.campaign_cursor=career.snapshot().campaign_cursor
			next._music_context.campaign_cursor=int(next._state.campaign_cursor)
			next._flight_music={"operations":[]}
			next._state.mission=completed_context.recipe().next_mission
			if completed_context.recipe().get("continuation",{}).get("kind")=="retained_world":
				var continuation: RefCounted=next._runner.continue_in_world(_bindings,_library,_equipment.snapshot().loadout)
				if continuation==null:return failed(next._runner.error)
				next._runner=continuation
				if continuation.context_owner().recipe().sequences.has("freighter_escape"):
					var escape:=Escape.new()
					if not escape.configure(_bindings,_context,_encounter.sequence_hook_owner(),next._portal,_camera,true):return failed(escape.error)
					next._escape=escape
			else:next._state.boundary="mission_continuation_required"
		elif outcome.kind=="failure":
			next._state.boundary="campaign_failure_transition_required";next._game_over=outcome.transition
	return next

func can_skip_entry() -> bool:
	return not _state.is_empty() and not _state.entry_released and _state.boundary.is_empty() and not _encounter.frame_context().sequence.input_blocked

func skip_entry(paused:=false) -> RefCounted:
	error=""
	if paused or not can_skip_entry():return failed("Only the ordinary mission arrival can be skipped")
	var next:=fork_for_frame()
	next._state.entry_elapsed_ms=int(_context.recipe().entry_release_ms);next._state.entry_skipped=true
	# Ordinary release/briefing still visits the complete zero-time frame.
	var result: RefCounted=next.evaluate(0)
	if result==null:return failed(next.error)
	return result

func select_secondary(item_id: int,paused:=false) -> RefCounted:
	if paused or _state.is_empty() or not _state.boundary.is_empty() or frame_context().encounter.sequence.input_blocked:return failed("Secondary selection requires player control")
	var selected: RefCounted=_encounter.select_secondary(item_id)
	if selected==null:return failed(_encounter.error)
	var next:=fork_for_frame();next._encounter=selected;return next

func cycle_secondary(paused:=false) -> RefCounted:return select_secondary(_encounter.next_secondary_id(),paused)
func secondary_feedback() -> Dictionary:return {} if _encounter==null else _encounter.secondary_feedback()
## A result stops flight time, but its ordinary follow view can finish returning
## to the stationary player. Keep that presentation change separate from flight.
func advance_result_view(milliseconds: int) -> RefCounted:
	error=""
	if not Numbers.integer(milliseconds,0,_max_ms):return failed("Invalid result view interval")
	if milliseconds==0 or not campaign_dialogue_visible() or _runner.snapshot().mode!=1 or _camera.snapshot().mode!="follow" or _death.snapshot().phase!="ready":return self
	var next:=fork_for_frame()
	var target: Dictionary=_context.identity();target.player_pose=_pose
	var shot: Dictionary=_context.identity();shot.merge({"target":"player","mode":"follow","inherit_target_up":true})
	if not next._camera.update(milliseconds,shot,target):return failed(next._camera.error)
	var positions:={};var registered: Dictionary=next._detail.snapshot().selections
	if registered.has("player"):positions["player"]=_pose.origin
	for actor in _encounter.combat_snapshot().actors:
		if registered.has(actor.actor_id):positions[actor.actor_id]=actor.body_pose.origin
	next._reference=next._camera.snapshot().eye
	if not next._detail.refresh(positions,next._reference,1.0):return failed(next._detail.error)
	next._state.revision+=1
	return next

func campaign_dialogue_visible() -> bool:return _runner!=null and _runner.dialogue().get("visible",false)
func dialogue() -> Dictionary:return {"visible":false} if _runner==null else _runner.dialogue()
func campaign_result() -> Dictionary:
	if _state.is_empty():return {}
	var line:=dialogue();var state: Dictionary=_context.identity()
	state.merge({"campaign_cursor":_state.campaign_cursor,"language":_state.language,"phase":"conversation" if line.get("visible",false) else "flying","dialogue":line},true)
	return state
func prepare_game_over() -> Dictionary:return _game_over.duplicate(true)
## The runner retains its campaign transition; the menu consumes a game-over
## receipt. Only this acknowledged native owner can adapt between the two.
func prepare_campaign_failure_exit() -> Dictionary:
	if _runner==null or _state.get("boundary","")!="campaign_failure_transition_required" or campaign_dialogue_visible():return {}
	var context: RefCounted=_runner.context_owner();var recipe: Dictionary=context.recipe()
	var runner: Dictionary=_runner.snapshot();var identity: Dictionary=context.identity()
	if runner.mode!=int(recipe.result.policy.failure_result_mode) or runner.retired or _state.campaign_cursor!=identity.campaign_cursor:return {}
	var rules: Dictionary=_bindings.mido_travel.kappa_outcome.failure
	var expected:={"base_content_id":identity.base_content_id,"binding_id":identity.binding_id,
		"from_cursor":identity.campaign_cursor,"previous_mission":_state.mission.duplicate(true),
		"outcome":"failed","source_state":int(rules.continue_source_state),"reward_credits":int(rules.reward_credits)}
	if _game_over!=expected:return {}
	var packet:={"base_content_id":identity.base_content_id,"binding_id":identity.binding_id,
		"campaign_cursor":identity.campaign_cursor,"source_state":int(rules.continue_source_state)}
	var failure:=packet.duplicate(true);failure.outcome="failed";failure.reward_credits=int(rules.reward_credits)
	packet.campaign_failure=failure
	return packet

func request_game_over_exit(paused:=false) -> RefCounted:
	if paused or _death==null or not _state.boundary.is_empty():return failed("Game over is not awaiting input")
	var next:=fork_for_frame();var packet: Dictionary=next._death.request_exit()
	if packet.is_empty():return failed(next._death.error)
	next._game_over=packet;next._state.boundary="game_over_transition_required"
	return next

func frame_context() -> Dictionary:
	if _state.is_empty():return {}
	var state:=_state.duplicate(true)
	state.player_pose=_pose;state.player=_player.snapshot();state.throttle=_throttle
	state.pilot={"angular_units":_pilot.angular_units,"lateral_rate":_pilot.lateral_units_per_millisecond}
	state.encounter=_encounter.frame_context()
	state.escape=escape_state()
	if _escape!=null:
		for key in ["input_blocked","hud_visible","player_damage_allowed","player_visible","player_particles_visible","cinematic"]:state.encounter.sequence[key]=state.escape[key]
	state.encounter.sequence.input_blocked=not _state.entry_released or state.encounter.sequence.input_blocked or campaign_dialogue_visible() or _death.snapshot().phase!="ready"
	state.encounter.sequence.hud_visible=_state.entry_released and state.encounter.sequence.hud_visible and not campaign_dialogue_visible() and _death.snapshot().phase=="ready"
	state.encounter.view={"camera":_camera.snapshot(),"player_aim":_aim.snapshot(),"player_render_suppressed":not state.encounter.sequence.get("player_visible",true),"camera_mode":0,"orbit_input":{"dragging":false}}
	if _portal!=null:state.portal=_portal.portal_snapshot();state.portal_contact=_portal.snapshot()
	state.encounter.sequence.radio=state.encounter.radio;state.encounter.sequence.radio_events=state.encounter.radio_events
	state.runner=_runner.snapshot();state.dialogue=dialogue();state.career=_career.snapshot();state.progress=_progress.duplicate(true)
	state.random_state=_random.duplicate(true)
	return state

func snapshot() -> Dictionary:
	var state:=frame_context()
	if state.is_empty():return state
	var view: Dictionary=state.encounter.view;var sequence: Dictionary=state.encounter.sequence
	state.encounter=_encounter.snapshot();state.encounter.view=view;state.encounter.sequence=sequence
	state.scenery=_scenery.snapshot();state.player_engines=_engines.snapshot();state.player_engine_audio=_engine_audio.snapshot()
	state.radar=_radar.snapshot();state.music_context=_music_context.duplicate(true);state.flight_music=_flight_music.duplicate(true)
	state.player_destruction=_death.snapshot();state.damage_particles=_particles.snapshot();state.npc_scanner=_scanner.snapshot();state.mining_targeting=_targeting.snapshot();state.flight_notices=_notices.snapshot();state.detail=_detail.snapshot();state.equipment=_equipment.snapshot()
	state.game_over_packet=prepare_game_over();state.initial_progress=_initial_progress.duplicate(true)
	return state

func hud_state() -> Dictionary:
	if _state.is_empty():return {}
	var state:=frame_context();var result: Dictionary=_context.identity()
	result.merge({"campaign_cursor":_state.campaign_cursor,"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,
		"hud_visible":state.encounter.sequence.hud_visible,"player":state.player,"cargo":_equipment.snapshot().cargo,
		"control_throttle":_throttle,"player_aim":_aim.snapshot(),"camera":_camera.snapshot(),"radio":state.encounter.radio,
		"npc_scanner":_scanner.snapshot(),"mining_targeting":_targeting.snapshot(),"flight_notices":_notices.snapshot()},true)
	return result
func audio_state() -> Dictionary:
	if _state.is_empty():return {}
	var state: Dictionary=_encounter.frame_context();var combat: Dictionary=_encounter.audio_snapshot()
	combat.player_engine=_engine_audio.snapshot()
	var actor_engines:={}
	for declaration in _context.recipe().get("actor_engines",[]):
		actor_engines[int(declaration.actor_id)]=_encounter.actor_engine_observation(int(declaration.actor_id))
	return {"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,"combat":combat,"camera_view":_camera.snapshot(),
		"actor_engines":actor_engines,
		"radio":state.radio,"radio_events":state.radio_events,"death_events":_death.snapshot().events,
		"sequence_revision":state.sequence.revision,"sequence_audio":state.sequence.frame.audio,"escape_audio":[] if _escape==null else _escape.snapshot().frame.audio,"dialogue":dialogue(),
		"scanner_events":_scanner.sound_events(),"flight_music":_flight_music.duplicate(true)}
func effects_state() -> Dictionary:
	if _state.is_empty():return {}
	var sequence: Dictionary=_encounter.frame_context().sequence
	return {"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,"sequence_revision":sequence.revision,
		"effects_enabled":sequence.effects_enabled,"directives":sequence.frame.effects,"input_actions":sequence.frame.input_actions,
		"camera_actions":sequence.frame.camera_actions,"camera_pose":_camera.snapshot().pose,"player_destruction":_death.snapshot(),
		"damage_particles":_particles.snapshot(),"encounter":{"elapsed_ms":_encounter.frame_context().elapsed_ms}}
func exhaust_state() -> Dictionary:
	if _state.is_empty():return {}
	var state: Dictionary=_context.identity()
	state.merge({"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,"engine_particles":_engines.snapshot(),"camera_pose":_camera.snapshot().pose})
	return state
func environment_state() -> Dictionary:return {} if _world==null else _world.environment_owner().snapshot()
func void_environment_owner() -> RefCounted:return null if _world==null else _world.environment_owner()
## The original portal is retained from entry; its successor enables it.
func portal_owner() -> RefCounted:return null if _portal==null else _portal.fork_for_frame()
func escape_state() -> Dictionary:return {} if _escape==null else _escape.snapshot()
func scanner_owner() -> RefCounted:return null if _scanner==null else _scanner.fork_for_frame()
func targeting_owner() -> RefCounted:return null if _targeting==null else _targeting.fork_for_frame()
func notices_owner() -> RefCounted:return null if _notices==null else _notices.fork_for_frame()
func damage_particles_owner() -> RefCounted:return null if _particles==null else _particles.fork_for_frame()
## The ambush keeps the ordinary follow camera; there is no player orbit view.
func camera_input(_mode: Variant=null,_pointer_kind:="",_position: Variant=Vector2i.ZERO,_paused:=false) -> RefCounted:
	return failed("This mission has no alternate camera view")
func prepare_portal_transition() -> Dictionary:
	if _escape==null or _state.boundary!="normal_space_return_required" or _escape.snapshot().boundary!=_state.boundary or _player.snapshot().vitals.hull<=0:return {}
	var retained: Dictionary=_world.entry_owner().snapshot()
	var packet: Dictionary=_context.identity()
	packet.merge({"kind":"mission_portal_return","campaign_cursor":_state.campaign_cursor,"return_station_id":retained.return_station_id,"return_system_id":retained.return_system_id,
		"source_before":retained.source_before.duplicate(true),"source_revision":_state.revision,"source_elapsed_ms":_state.elapsed_ms,
		"player":_player.snapshot(),"player_pose":_pose,"progress":_progress.duplicate(true),"request":_escape.snapshot().frame.return_request.duplicate(true)},true)
	return packet
func detail_state() -> Dictionary:return {} if _detail==null else _detail.snapshot()
func presentation_identity() -> RefCounted:return _presentation_identity
## Issued only by the evaluated living escape, never by a packet reader.
func portal_return_identity() -> RefCounted:return null if prepare_portal_transition().is_empty() else _return_identity
func mission_context_owner() -> RefCounted:return _context
func initialized_world_owner() -> RefCounted:return _world
## Station conversations belong to the retained entry, not the active mission.
func station_response_flags() -> Dictionary:return {} if _world==null else _world.entry_owner().snapshot().station_response_flags.duplicate(true)
func player_owner() -> RefCounted:return null if _player==null else _player.fork_for_frame()
func scenery_owner() -> RefCounted:return null if _scenery==null else _scenery.fork_for_frame()
func encounter_owner() -> RefCounted:return null if _encounter==null else _encounter.fork_for_frame()
func combat_owner() -> RefCounted:return null if _encounter==null else _encounter.combat_owner()
func equipment_owner() -> RefCounted:return null if _equipment==null else _equipment.fork()
func career_owner() -> RefCounted:return null if _career==null else _career.fork()
func runner_owner() -> RefCounted:return null if _runner==null else _runner.fork()
func pilot_owner() -> RefCounted:return null if _pilot==null else _pilot.fork_for_frame()
func destruction_owner() -> RefCounted:return null if _death==null else _death.fork_for_frame()
func engine_audio_owner() -> RefCounted:return null if _engine_audio==null else _engine_audio.fork_for_frame()
func engine_particles_owner() -> RefCounted:return null if _engines==null else _engines.fork_for_frame()

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate(true);copy._context=_context;copy._world=_world;copy._bindings=_bindings;copy._library=_library
	copy._pose=_pose;copy._reference=_reference;copy._random=_random.duplicate(true)
	copy._initial_progress=_initial_progress;copy._progress=_progress.duplicate(true);copy._viewport=_viewport
	copy._throttle=_throttle;copy._max_ms=_max_ms;copy._game_over=_game_over.duplicate(true)
	copy._primary_released=_primary_released;copy._secondary_released=_secondary_released
	copy._presentation_identity=_presentation_identity
	copy._return_identity=_return_identity
	copy._portal=null if _portal==null else _portal.fork_for_frame();copy._escape=null if _escape==null else _escape.fork_for_frame()
	if _state.is_empty():return copy
	copy._music=_music;copy._radar=_radar.fork_for_frame();copy._music_context=_music_context.duplicate(true);copy._flight_music=_flight_music.duplicate(true)
	copy._runner=_runner.fork();copy._encounter=_encounter.fork_for_frame();copy._player=_player.fork_for_frame();copy._scenery=_scenery.fork_for_frame()
	copy._equipment=_equipment;copy._career=_career
	copy._pilot=_pilot.fork_for_frame();copy._physical=_physical.fork_for_frame();copy._camera=_camera.fork_for_frame();copy._aim=_aim.fork_for_frame()
	copy._engines=_engines.fork_for_frame();copy._engine_audio=_engine_audio.fork_for_frame();copy._death=_death.fork_for_frame();copy._particles=_particles.fork_for_frame();copy._scanner=_scanner.fork_for_frame();copy._targeting=_targeting.fork_for_frame();copy._notices=_notices.fork_for_frame();copy._detail=_detail.fork_for_frame()
	return copy
static func valid_viewport(size: Vector2i) -> bool:return size.x>0 and size.y>0 and size.x<=32767 and size.y<=32767
func reject(message: String) -> bool:error=message;return false
func failed(message: String) -> RefCounted:reject(message);return null
