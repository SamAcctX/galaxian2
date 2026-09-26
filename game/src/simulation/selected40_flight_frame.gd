extends RefCounted
## Moving selected40 composition over the shared native flight owners. This is
## not a departure capability. Its optional native career retains the separate
## passenger job while the selected story owns the world; it cannot settle that
## job. Story failure and portal arbitration use the native mission and cast;
## a prepared onward request is not a committed career or successor save.
const Rules=preload("res://src/content/selected40_population_definitions.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const Pilot=preload("res://src/simulation/pilot_motion.gd")
const Contacts=preload("res://src/simulation/physical_scenery_contacts.gd")
const Engines=preload("res://src/simulation/player_engine_particles.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Detail=preload("res://src/presentation/ship_detail_group.gd")
const ShipDetail=preload("res://src/presentation/ship_detail.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Scanner=preload("res://src/simulation/opening_npc_scanner.gd")
const Cargo=preload("res://src/simulation/flight_cargo.gd")
const TargetFrame=preload("res://src/presentation/flight_target_frame.gd")
const ScanAnimation=preload("res://src/presentation/flight_scan_animation.gd")
const Targeting=preload("res://src/simulation/mining_targeting.gd")
const Notices=preload("res://src/simulation/flight_notices.gd")
const EngineAudio=preload("res://src/simulation/opening_engine_audio.gd")
const Music=preload("res://src/simulation/ordinary_music.gd")
const Radar=preload("res://src/simulation/fast_forward.gd")
const StationResources=preload("res://src/content/station_exterior_resources.gd")
const VoidPortal=preload("res://src/simulation/void_portal.gd")
const CampaignFailure=preload("res://src/content/kappa_outcome_definitions.gd")
const Sequence=preload("res://src/simulation/selected40_sequence.gd")
var error:=""
var _state:={}
var _player: RefCounted
var _scenery: RefCounted
var _encounter: RefCounted
var _pilot: RefCounted
var _physical: RefCounted
var _engines: RefCounted
var _detail: RefCounted
var _equipment: RefCounted
var _scanner: RefCounted
var _cargo: RefCounted
var _targeting: RefCounted
var _notices: RefCounted
var _presentation_identity: RefCounted
var _death: RefCounted
var _particles: RefCounted
var _statistics_pose:=Transform3D.IDENTITY
var _pose:=Transform3D.IDENTITY
var _reference:=Vector3.ZERO
var _random:={}
var _throttle:=1.0
var _viewport:=Vector2i(1440,900)
var _max_ms:=0
var _game_over_packet:={}
var _engine_audio: RefCounted
var _music: RefCounted
var _radar: RefCounted
var _entry:={}
var _music_context:={}
var _music_faction:=-1
var _flight_music:={"operations":[]}
var _station: RefCounted
var _portal: RefCounted
var _career: RefCounted
var _failure_lines:=[]
var _language:=""

func configure(bindings: RefCounted,catalogues: RefCounted,library: RefCounted,player: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,pose: Transform3D,camera: RefCounted,aim: RefCounted,sensitivity:=1.0,viewport:=Vector2i(1440,900)) -> bool:
	error=""
	if not _state.is_empty() or not player is Player or not scenery is Scenery or not Flight.rigid_pose(pose) or not valid_viewport(viewport):return reject("Moving selected40 flight requires fresh native owners and a rigid player pose")
	var encounter:=Encounter.new();var pilot:=Pilot.new();var contacts:=Contacts.new()
	if not encounter.configure_selected40(bindings,catalogues,library,player,scenery,equipment,reputation) or not encounter.prepare_selected40_sequence(bindings,library) or not encounter.prepare_selected40_view(bindings,camera,aim,player):return reject(encounter.error)
	if not encounter.configure_secondaries(bindings,catalogues,player,equipment,library):return reject(encounter.error)
	var loadout: Dictionary=player.loadout()
	if not pilot.configure_vehicle(bindings,catalogues,bindings.base_content_id,int(loadout.ship_id),[],loadout.equipment_ids,sensitivity):return reject(pilot.error)
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	var entry: Dictionary=scenery.snapshot().get("departure_population",{}).get("selected40_entry",{})
	if entry.get("selected40")!=true or entry.get("world_type")!=3 or entry.get("base_content_id")!=bindings.base_content_id or entry.get("binding_id")!=bindings.binding_id:return reject("Selected40 environment lost its native prospective world entry")
	var station:=StationResources.new()
	if not station.configure_ordinary_location(library,bindings,catalogues,int(entry.station_id)):return reject(station.error)
	var portal:=VoidPortal.new()
	if not portal.configure_selected40(bindings,scenery,library):return reject(portal.error)
	if portal.selected40_construction_owner()!=player.selected40_construction_owner():return reject("Selected40 portal belongs to another generated world")
	# Actual source collision volumes join the asteroid contacts. This resource
	# owner grants neither docking nor a generic cursor40 departure.
	if not contacts.configure(bindings.physical_scenery_contacts,identity,station.snapshot(),scenery.read_snapshot().bodies):return reject(contacts.error)
	var mounts:=Mounts.new();var engines:=Engines.new();var detail:=Detail.new()
	if not mounts.open(library,catalogues) or not engines.configure(bindings,mounts,int(loadout.ship_id),scenery.seed_seconds()):return reject(mounts.error+engines.error)
	var positions:={};var selectors:={};var player_detail:=ShipDetail.new()
	if not player_detail.configure(bindings.ship_lod,int(loadout.ship_id)):return reject(player_detail.error)
	if player_detail.has_alternates():selectors["player"]=player_detail;positions["player"]=pose.origin
	for actor in encounter.combat_snapshot().actors:
		# This source-selected freighter retains statistics hull13 while its
		# original Terran assembly normally maps to free-traffic hull15. Build
		# the shared source-checked selector from that actual assembly; do not
		# relabel the physical ship or relax generic traffic identity guards.
		var selector:=ShipDetail.new()
		var ready: bool=selector.configure_assembly(bindings,encounter.freighter_assembly(0)) if actor.actor_id==0 else selector.configure(bindings.ship_lod,int(actor.hull_catalogue_id))
		if not ready:return reject(selector.error)
		# Source geometry without alternate meshes is never registered with
		# the periodic LOD manager. It remains a normal live/rendered actor.
		if selector.has_alternates():selectors[actor.actor_id]=selector;positions[actor.actor_id]=actor.body_pose.origin
	if not detail.configure_selectors(bindings,selectors) or not detail.refresh(positions,Vector3.ZERO,1.0):return reject(detail.error)
	var art:=TargetFrame.source_geometry(library,bindings)
	var strip:=ScanAnimation.source_geometry(library,bindings,bindings.opening_staging.npc_scanner)
	if art.has("error") or strip.has("error"):return reject("Selected40 native scanner artwork declarations are unavailable")
	var scanner:=Scanner.new();var cargo:=Cargo.new()
	if not scanner.configure_selected40(bindings,catalogues,TargetFrame.logical_radii(art.quarter_size,false),int(strip.frames),equipment,encounter.combat_owner()) or not cargo.configure_equipment(bindings,catalogues,equipment):return reject(scanner.error+cargo.error)
	if not scanner.advance_selected40(encounter.combat_owner(),pose,camera.snapshot().pose,aim.snapshot(),0,false):return reject(scanner.error)
	var asteroid_strip:=ScanAnimation.source_geometry(library,bindings,bindings.mining_targeting)
	if asteroid_strip.has("error"):return reject("Selected40 asteroid acquisition lacks its source filmstrip")
	var targeting:=Targeting.new();var notices:=Notices.new()
	if not targeting.configure_selected40(bindings,catalogues,equipment,scenery,TargetFrame.logical_radii(art.quarter_size,false),int(asteroid_strip.frames)) or not notices.configure_selected40(bindings,library,scenery.world_initialization_owner()):return reject(targeting.error+notices.error)
	if not targeting.advance(scenery,pose,camera.snapshot().pose,aim.snapshot(),0,false):return reject(targeting.error)
	var death: RefCounted=load("res://src/simulation/player_destruction.gd").new()
	var particles: RefCounted=load("res://src/simulation/full_hold_particles.gd").new()
	if not death.configure_selected40(bindings,encounter.destruction_resources(),catalogues,player,scenery,equipment,pose,camera.snapshot().pose):return reject(death.error)
	if not particles.configure_selected40(bindings,encounter.combat_owner(),death,scenery.seed_seconds()):return reject(particles.error)
	var engine_audio:=EngineAudio.new();var music:=Music.new();var radar:=Radar.new()
	if not engine_audio.configure_selected40(bindings,catalogues,player,pose) or not music.configure(bindings.ordinary_music):return reject(engine_audio.error+music.error)
	if not radar.configure(bindings) or not radar.configure_radar(catalogues,loadout.equipment_ids) or not radar.publish_without_scanner(false):return reject(radar.error)
	var music_context:={"world_type":entry.world_type,"campaign_cursor":entry.campaign_cursor,"selected_station_id":entry.station_id,"system_id":entry.system_id,
		"retained_void_station_id":-1,"void_source_station_id":entry.source_before.source_station_id}
	if Music.context_kind(music_context,0)!="portal":return reject("Selected40 music must use its retained source before reroll, not origin or a guessed faction")
	_station=station;_portal=portal;_engine_audio=engine_audio;_music=music;_radar=radar;_entry=entry.duplicate(true);_music_context=music_context
	_music_faction=int(catalogues.tables.systems[int(entry.system_id)].fields[int(bindings.station_exterior.system_faction_field)])
	_death=death;_particles=particles;_statistics_pose=pose
	_player=player.fork_for_frame();_scenery=scenery.fork_for_frame();_equipment=equipment.fork()
	_encounter=encounter;_pilot=pilot;_physical=contacts;_engines=engines;_detail=detail
	_scanner=scanner;_cargo=cargo;_presentation_identity=RefCounted.new()
	_targeting=targeting;_notices=notices
	_pose=pose;_reference=Vector3.ZERO;_random=scenery.random_state();_viewport=viewport
	_max_ms=int(bindings.frame_clock.max_frame_milliseconds)
	_state=identity.merged({"scope":"selected40_moving_flight_component","revision":0,"elapsed_ms":0,"boundary":"","phase":"ready","input":{},"physical_contacts":[]})
	_failure_lines=CampaignFailure.failure_lines(bindings,library);_language=library.active_language
	if _failure_lines.size()!=1:return reject("Selected story requires its original shared failure conversation")
	return true

## secondary_fire is a discrete activation request, not a held-button state.
## A second press detonates the retained live round, including the last one.
## Only the native initializer may replace the component's supplied test view
## with an application entry. The generated field stays untouched: its seed
## was consumed by construction; subsequent simulation starts after camera RNG.
func prepare_application_entry(initial: RefCounted) -> RefCounted:
	error=""
	if not is_instance_of(initial,load("res://src/simulation/flight_camera_initialization.gd")) or _state.is_empty() or _state.revision!=0 or _state.has("application_initialization"):reject("Application entry requires its native late camera constructor");return null
	var data: Dictionary=initial.snapshot()
	if data.is_empty() or data.base_content_id!=_state.base_content_id or data.binding_id!=_state.binding_id or data.player_pose!=_pose or data.input_random_state!=_random or data.special_placement!=_entry.special_placement or initial.camera_owner().snapshot()!=_encounter.selected40_frame_context().view.camera:reject("Application entry changed its pose, random tail, source or initial view");return null
	var next:=fork_for_frame()
	if not next._encounter.prepare_selected40_application_entry(data.entry_release_ms) or not next._player.set_permissions(false,false):reject(next._encounter.error+next._player.error);return null
	next._random=data.random_state.duplicate(true);next._state.application_initialization=data
	return next

## Bind the native retained career without moving its station or changing the
## accepted side slot. The encounter keeps its generation/accounting identity.
func prepare_career(bindings: RefCounted,career: RefCounted) -> bool:
	error=""
	if _state.is_empty() or _state.revision!=0 or _career!=null:return reject("Prepare selected40 career once before its first native frame")
	var encounter: RefCounted=_encounter.fork_for_frame()
	var retained: RefCounted=encounter.prepare_selected40_career(bindings,career,_scenery)
	if retained==null:return reject(encounter.error)
	_encounter=encounter;_career=retained
	return true

func evaluate(milliseconds: Variant,commands:=Vector2.ZERO,throttle:=1.0,primary_fire:=false,paused:=false,viewport:=Vector2i.ZERO,strafe:=0.0,secondary_fire:=false,current_music_id:=-1,relative_mouse_capture:=false) -> RefCounted:
	error=""
	var size:=_viewport if viewport==Vector2i.ZERO else viewport
	if not Rules.Numbers.integer(current_music_id,-1,2292):reject("Invalid retained playback music selection");return null
	if _state.is_empty() or not Rules.Numbers.integer(milliseconds,0,_max_ms) or not valid_viewport(size) or not commands.is_finite() or absf(commands.x)>1 or absf(commands.y)>1 or not is_finite(throttle) or throttle<0 or throttle>1 or not is_finite(strafe) or strafe not in [-1.0,0.0,1.0]:reject("Invalid moving selected40 frame or pilot input");return null
	var next:=fork_for_frame()
	if paused or not _state.boundary.is_empty() or campaign_dialogue_visible():return next
	if not prepare_portal_transition().is_empty():return next._stop("selected40_portal_transition_required",0,"before_player")
	next._flight_music={"operations":[]}
	var prior: Dictionary=_encounter.selected40_frame_context()
	if prior.is_empty() or prior.pending_world or prior.elapsed_ms!=_state.elapsed_ms or prior.world_elapsed_ms!=_state.elapsed_ms or prior.sequence.elapsed_ms!=_state.elapsed_ms or prior.sequence.revision!=_state.revision:reject("Moving selected40 frame lost its ordered native encounter clocks");return null
	var death_before: Dictionary=_death.snapshot()
	var dying: bool=death_before.phase!="ready"
	var player_updates: bool=not dying or _death.player_updates_enabled()
	var seconds:=float(milliseconds)/1000.0
	var blocked: bool=prior.sequence.input_blocked or dying
	var active_throttle: float=_throttle if blocked else throttle
	# The script does not enable scripted-coast or suspend ordinary movement.
	# Established angular response moves the root; NEW commands are sampled
	# only after this frame's radio/camera has decided whether input is allowed.
	next._state.physical_contacts=[]
	var aim_pose:=_pose
	if player_updates:
		if not next._encounter.refresh_selected40_player_response(relative_mouse_capture,next._pilot.response_factor()):reject(next._encounter.error);return null
		if not next._engine_audio.before_ordinary_motion():reject(next._engine_audio.error);return null
		next._pose=next._pilot.advance_prepared(_pose,active_throttle,seconds,0.0 if blocked else strafe)
		if not next._pilot.error.is_empty():reject(next._pilot.error);return null
		# The original environment pass shares one incoming entry permission
		# and active-statistics sample across solid scenery and the live portal.
		# A controller release later in this frame enables the NEXT player pass.
		var contact_player: Dictionary=next._player.collision_context(next._pose)
		var contact_enabled: bool=bool(prior.sequence.get("entry_released",true))
		var contact: Dictionary=next._physical.plan(contact_player,next._scenery.read_snapshot().bodies,contact_enabled)
		if contact.is_empty() or not next._scenery.apply_physical_contacts(contact.operations):reject(next._physical.error+next._scenery.error);return null
		for operation in contact.operations:
			# Station volumes only project the ship; only an asteroid contact
			# carries the shared planner's player-damage field.
			if operation.kind=="asteroid" and next._player.normal_hit(operation.player_damage).is_empty():reject(next._player.error);return null
		next._pose.origin=contact.center_after;next._state.physical_contacts=contact.operations
		aim_pose=next._pose
		next._statistics_pose=next._pose*Transform3D(death_before.rendered_model_basis if dying else Basis.IDENTITY,Vector3.ZERO)
		if next._player.advance_recharge(milliseconds).is_empty() or next._player.advance_repair(milliseconds).is_empty():reject(next._player.error);return null
		# The source reticle sampled the preceding view BEFORE portal pull.
		# Contact observes the previous portal clock; its animation/facing is
		# advanced with the environment only after the NPC/scenery pass below.
		if not next._portal.observe_contact({"player_pose":next._pose,"environment_contact_enabled":contact_enabled and contact_player.eligible,"mining_active":false}):reject(next._portal.error);return null
		var portal_contact: Dictionary=next._portal.snapshot().contact
		if not portal_contact.is_empty() and portal_contact.pull_distance>0:
			next._pose.origin=VoidPortal.Vectors.added(next._pose.origin,VoidPortal.Vectors.scaled(VoidPortal.Vectors.normalized(-portal_contact.player_offset),float(portal_contact.pull_distance)))
			next._statistics_pose=next._pose*Transform3D(death_before.rendered_model_basis if dying else Basis.IDENTITY,Vector3.ZERO)
	if dying:
		# The source player tail runs before weapon contact and the sprite
		# manager. Its one-shot burst uses statistics, not the rendered bank.
		var tail: Dictionary=next._death.advance(milliseconds,next._pose,next._random,false,next._statistics_pose,player_updates)
		if tail.is_empty():reject(next._death.error);return null
		next._random=tail.random_state
		if not next._particles.apply_player_tail(next._death):reject(next._particles.error);return null
	var weapons: Dictionary=next._encounter.evaluate_weapons(next._player,next._pose,milliseconds,next._scenery,next._random,true,not prior.sequence.radio.visible)
	if weapons.is_empty():reject(next._encounter.error);return null
	next._encounter=weapons.encounter;next._player=weapons.player;next._scenery=weapons.scenery;next._random=weapons.random_state
	# Transport time remains aligned after the player-update gate closes; the
	# stopped engine cannot restart, and the frozen pose does not move its sound.
	if not next._engine_audio.follow_player(next._pose,int(next._player.snapshot().vitals.hull),milliseconds):reject(next._engine_audio.error);return null
	if not dying and next._engines.engine_enabled()!=(active_throttle>0) and not next._engines.set_engine_enabled(active_throttle>0):reject(next._engines.error);return null
	if not next._engines.advance(next._statistics_pose,milliseconds):reject(next._engines.error);return null
	if not next._particles.advance(next._pose,milliseconds):reject(next._particles.error);return null
	var positions:={};var registered: Dictionary=next._detail.snapshot().selections
	if registered.has("player"):positions["player"]=next._pose.origin
	for actor in next._encounter.combat_snapshot().actors:
		if registered.has(actor.actor_id):positions[actor.actor_id]=actor.body_pose.origin
	if not next._detail.update(milliseconds,positions,_reference,1.0,false):reject(next._detail.error);return null
	if not dying and next._player.snapshot().vitals.hull<=0:
		if not next._death.start(next._player,next._pose,Vector3.ZERO,prior.view.camera.pose,40,Basis.IDENTITY,next._statistics_pose,next._encounter.secondary_owner()):reject(next._death.error);return null
		if not next._engines.set_engine_enabled(false) or not next._player.set_permissions(false,next._player.snapshot().damage_allowed):reject(next._engines.error+next._player.error);return null
		dying=true
	if dying and not next._particles.apply_player_poll(next._death):reject(next._particles.error);return null
	# Source result polling precedes the selected script and later portal tail.
	# Failure is completed freighter breakup (mode4), without the success
	# timer/radio gate. Finish this accepted frame, then freeze for explicit Next.
	if not next._death.snapshot().game_over_visible and next._encounter.selected40_frame_context().freighter_mode==int(Rules.VALUES.destroyed_mode):
		next._state.campaign_phase="failure_instructions"
	var cue: Dictionary=next._encounter.evaluate_selected40_sequence(milliseconds,next._random,next._player,next._pose,size,next._death if dying else null,player_updates,aim_pose)
	if cue.is_empty():reject(next._encounter.error);return null
	next._encounter=cue.encounter;next._random=cue.random_state
	if cue.sequence.frame.get("entry_released",false) and not dying and not next._player.set_permissions(true,true):reject(next._player.error);return null
	if dying and not next._death.sample_camera(next._encounter.selected40_frame_context().view.camera.pose,false):reject(next._death.error);return null
	var detail_reference: Variant=next._encounter.selected40_frame_context().view.detail_refresh_reference
	if detail_reference!=null:
		# The original cinematic refresh visits the same registered geometry
		# after reveal placement, before NPC motion. Reuse the native selectors;
		# an immediate visit neither resets their periodic clock nor draws RNG.
		for actor in next._encounter.combat_snapshot().actors:
			if registered.has(actor.actor_id):positions[actor.actor_id]=actor.body_pose.origin
		if not next._detail.refresh(positions,detail_reference,1.0):reject(next._detail.error);return null
	# Source damage permission is separate from activity/target eligibility.
	# Existing shots and ordinary player systems survive the cinematic switch.
	if cue.sequence.frame.cancel_actions:
		if not next._player.set_permissions(next._player.snapshot().active,false):reject(next._player.error);return null
	for operation in cue.sequence.frame.camera_operations:
		if operation.kind=="follow_player" and not next._player.set_permissions(next._player.snapshot().active,true):reject(next._player.error);return null
	var enabled: bool=not cue.sequence.input_blocked and next._player.snapshot().active and not next.campaign_dialogue_visible()
	if player_updates and not next._pilot.sample_commands(commands if enabled else Vector2.ZERO,seconds):reject(next._pilot.error);return null
	if player_updates and not next._engine_audio.sample_commands(commands if enabled else Vector2.ZERO):reject(next._engine_audio.error);return null
	var fired: Dictionary=next._encounter.evaluate_primary_fire(next._player,next._pose,primary_fire,enabled,next._random)
	if fired.is_empty():reject(next._encounter.error);return null
	next._encounter=fired.encounter;next._random=fired.random_state
	# The shared launcher owns ammunition and live projectile history. Keep all
	# four loadout views in this prospective frame, after primary input and
	# before actor motion. A late failure cannot spend a paid round.
	var secondary: Dictionary=next._encounter.evaluate_secondary_fire(next._player,next._equipment,next._pose,secondary_fire,enabled,next._random,not cue.sequence.radio.visible)
	if secondary.is_empty():reject(next._encounter.error);return null
	next._encounter=secondary.encounter;next._player=secondary.player;next._equipment=secondary.equipment;next._random=secondary.random_state
	var before_actors: Dictionary=next._encounter.combat_snapshot()
	var world: Dictionary=next._encounter.evaluate_world(next._player,next._pose,milliseconds,next._random)
	if world.is_empty():reject(next._encounter.error);return null
	if not next._particles.finish_npc_pass(before_actors,world.encounter.combat_snapshot(),world.encounter.actor_events(),milliseconds,1.0):reject(next._particles.error);return null
	next._encounter=world.encounter;next._random=world.random_state
	# Asteroid centers do not move in this owner. Its shared detail transaction
	# stages periodic selection before the optional cinematic refresh, exactly
	# once; a later scenery/HUD failure discards both along with the whole frame.
	if not next._scenery.update(milliseconds,_reference,1.0,detail_reference,next._random):reject(next._scenery.error);return null
	# The shared HUD pass follows actor motion and uses the newly committed
	# camera with the earlier player-aim sample. Hidden cinematic draws retain
	# acquisition history; neither rendering nor pause advances this clock.
	var view: Dictionary=next._encounter.selected40_frame_context().view
	var portal_random:=VoidPortal.Random.new()
	if not portal_random.restore(next._scenery.random_state()) or not next._portal.advance(milliseconds,view.camera.pose,portal_random):reject(portal_random.error+next._portal.error);return null
	if not next._scanner.advance_selected40(next._encounter.combat_owner(),next._pose,view.camera.pose,view.player_aim,milliseconds,bool(cue.sequence.hud_visible)):reject(next._scanner.error);return null
	var scan: Dictionary=next._scanner.snapshot()
	var blocked_target: bool=scan.candidate_actor_id>=0 and scan.selected_actor_id<0
	var suspended_target: bool=scan.get("found_actor_id",-1)>=0
	if not next._targeting.advance(next._scenery,next._pose,view.camera.pose,view.player_aim,milliseconds,bool(cue.sequence.hud_visible),false,blocked_target,suspended_target):reject(next._targeting.error);return null
	var target: Dictionary=next._targeting.snapshot()
	# Acquisition is not permission to perform the as-yet unprepared recovery
	# or mining action. Keep the source selection/notice without granting cargo.
	for event in target.events:
		if event.get("kind")=="notification" and not next._notices.enqueue(event.get("source_id")):reject(next._notices.error);return null
	if not next._notices.advance(milliseconds,false):reject(next._notices.error);return null
	# The saved ship has no scanner. Reuse the source's explicit skip-NPC-loop
	# branch; actual combat contacts do not substitute for a radar battle count.
	var radar_visible: bool=cue.sequence.hud_visible and not dying
	if not next._radar.publish_without_scanner(radar_visible,current_music_id):reject(next._radar.error);return null
	var selection: Dictionary=next._music.prepare_for_context(current_music_id,next._radar.battle_count(),_music_faction,radar_visible,_music_context)
	if selection.is_empty():reject(next._music.error);return null
	next._flight_music={"operations":selection.operations}
	next._random=portal_random.snapshot();next._viewport=size;next._throttle=active_throttle
	if milliseconds>0:next._reference=next._encounter.selected40_frame_context().view.camera.eye
	next._state.elapsed_ms+=int(milliseconds);next._state.revision+=1;next._state.phase="ready"
	next._state.input={"enabled":enabled,"commands":commands if enabled else Vector2.ZERO,"primary_held":primary_fire and enabled,"secondary_requested":secondary_fire and enabled,"throttle":active_throttle}
	if next._career!=null:
		var career: Dictionary=next._encounter.evaluate_contract_session(next._career,bool(cue.sequence.radio.visible),false,false)
		if career.is_empty():reject(next._encounter.error);return null
		next._career=career.session
	if not next._resolve_portal_tail():reject(next.error);return null
	return next

func _resolve_portal_tail() -> bool:
	# The original late portal transaction tests controller phase, not the
	# radio index, freighter visibility, or absence of enemies. It follows the
	# failure poll: an accepted onward request replaces the old modal/world.
	if portal_transition_required():
		var phase: int=_encounter.selected40_frame_context().sequence.phase
		if phase<Sequence.Stage.PORTAL_ESCAPE:
			if not _player.reject_selected40_portal(_portal):return reject(_player.error)
			_state.portal_outcome={"kind":"early_entry","script_phase":phase,"hull_after":0}
			_state.input.enabled=false
		else:
			var freighter: Dictionary=_encounter.combat_snapshot().actors[0]
			_state.campaign_phase="portal_ready"
			_state.portal_outcome={"kind":"prepared_onward","script_phase":phase,
				"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,
				"source_state":2,"from_cursor":40,"next_cursor":41,
				"mission":{"kind":4,"station_id":-1},
				"system_id":-1,"station_id":-1,"source_before":_entry.source_before.duplicate(true),
				"return_system_id":_entry.system_id,"return_station_id":_entry.station_id,
				"freighter_hull":freighter.vitals.hull,"player":_player.snapshot(),
				"loadout":_player.loadout(),"career_committed":false}
			_state.input.enabled=false
	return true

func campaign_dialogue_visible() -> bool:return _state.get("campaign_phase","")=="failure_instructions"

func campaign_result() -> Dictionary:
	if _state.is_empty():return {}
	var result:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"language":_language,
		"campaign_cursor":40,"phase":_state.get("campaign_phase","flying"),
		"dialogue":{"visible":campaign_dialogue_visible(),"index":0,"count":1,"previous_available":false}}
	if campaign_dialogue_visible():result.dialogue.merge(_failure_lines[0].duplicate(true))
	if _state.has("campaign_failure"):result.campaign_failure=_state.campaign_failure.duplicate(true)
	return result

func request_campaign_failure_exit(paused:=false) -> RefCounted:
	error=""
	if paused or not campaign_dialogue_visible() or not _state.boundary.is_empty() or not _game_over_packet.is_empty():reject("No selected story failure awaits acknowledgement");return null
	var next:=fork_for_frame()
	var receipt:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"campaign_cursor":40,"source_state":1,"outcome":"failed","reward_credits":0}
	next._state.campaign_phase="failure_acknowledged";next._state.campaign_failure=receipt
	next._game_over_packet={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"campaign_cursor":40,"source_state":1,"campaign_failure":receipt.duplicate(true)}
	next._state.boundary="game_over_transition_required"
	return next

## Prepared source-owned exit data only. Navigation must construct the actual
## Void/mission41 world before any career selection or persistence is allowed.
func prepare_portal_transition() -> Dictionary:
	return _state.portal_outcome.duplicate(true) if _state.get("campaign_phase","")=="portal_ready" else {}

## Only the physical late-portal owner can authorize successor preparation.
## Its observation is not a restore format and cannot replace this predicate.
func successor41_ready(bindings: RefCounted) -> bool:
	if not load("res://src/content/selected41_population_definitions.gd").available(bindings) or _career==null or not _state.has("application_initialization"):return false
	# A preselected scenery component can retain equipment at its earlier
	# origin. Only completed native navigation puts all owners at this source.
	var owned: Dictionary=_player.loadout()
	if owned.station_id!=_entry.station_id or owned.system_id!=_entry.system_id or _career.station_id()!=_entry.station_id:return false
	if _state.get("base_content_id")!=bindings.base_content_id or _state.get("binding_id")!=bindings.binding_id or _state.get("campaign_phase")!="portal_ready" or _state.get("boundary","") not in ["","selected40_portal_transition_required"] or not portal_transition_required():return false
	var outcome:=prepare_portal_transition()
	var sequence: Dictionary=_encounter.selected40_frame_context().sequence
	var actors: Array=_encounter.combat_snapshot().actors
	if sequence.phase<Sequence.Stage.PORTAL_ESCAPE or actors.size()!=13 or actors[0].actor_id!=0:return false
	return outcome.get("next_cursor")==41 and outcome.get("from_cursor")==40 and outcome.get("source_state")==2 and outcome.get("mission")=={"kind":4,"station_id":-1} and outcome.get("source_before")==_entry.source_before and outcome.get("freighter_hull")==actors[0].vitals.hull and outcome.get("player")==_player.snapshot() and outcome.get("loadout")==_player.loadout()

func successor41_controller_matches(controller: RefCounted) -> bool:
	return _encounter!=null and _encounter.selected40_controller_matches(controller)

func prepare_successor41_career(bindings: RefCounted) -> RefCounted:
	error=""
	if not successor41_ready(bindings):reject("No living native late portal owns a successor career");return null
	var next: RefCounted=_encounter.prepare_successor41_career(bindings,_career,self)
	if next==null:reject(_encounter.error)
	return next

func prepare_successor41_entry(bindings: RefCounted) -> RefCounted:
	error=""
	var next: RefCounted=load("res://src/simulation/selected41_portal_entry.gd").new()
	if not next.prepare(bindings,self):reject(next.error);return null
	return next

## Explicit control requests select only an installed paid stack. They do not
## fire, advance time or grant a missing launcher; None remains a valid choice.
func select_secondary(item_id: int,paused:=false) -> RefCounted:
	error=""
	if _state.is_empty() or paused or campaign_dialogue_visible() or not prepare_portal_transition().is_empty() or not _state.boundary.is_empty() or _encounter.selected40_frame_context().sequence.input_blocked or not _player.snapshot().active or _player.snapshot().vitals.hull<=0:reject("Secondary selection requires released living selected40 flight");return null
	var selected: RefCounted=_encounter.select_secondary(item_id)
	if selected==null:reject(_encounter.error);return null
	var next:=fork_for_frame();next._encounter=selected
	return next

func cycle_secondary(paused:=false) -> RefCounted:
	if _encounter==null:reject("Configure selected40 flight before selecting a secondary");return null
	return select_secondary(_encounter.next_secondary_id(),paused)

func secondary_feedback() -> Dictionary:return {} if _encounter==null else _encounter.secondary_feedback()

## Discrete view controls do not move the ship, spend ammunition or advance
## any clock. The next ordered native frame consumes the retained orbit input.
func camera_input(mode: Variant=null,pointer_kind: String="",position: Variant=Vector2i.ZERO,paused:=false) -> RefCounted:
	error=""
	if _state.is_empty() or paused or campaign_dialogue_visible() or not prepare_portal_transition().is_empty() or not _state.boundary.is_empty() or not _player.snapshot().active or _player.snapshot().vitals.hull<=0:reject("Camera input requires living unpaused selected40 flight");return null
	var encounter: RefCounted=_encounter.selected40_camera_input(mode,pointer_kind,position)
	if encounter==null:reject(_encounter.error);return null
	var next:=fork_for_frame();next._encounter=encounter
	return next

func _stop(boundary: String,milliseconds: int,phase: String) -> RefCounted:
	_state.boundary=boundary;_state.elapsed_ms+=milliseconds;_state.phase=phase
	return self

## Acknowledge only the native completed fade. Source state1 is a caller-owned
## menu transition, never an implicit retry, reward, inventory edit or save.
func request_game_over_exit(paused:=false) -> RefCounted:
	error=""
	if _state.is_empty() or paused or campaign_dialogue_visible() or not _state.boundary.is_empty() or not _game_over_packet.is_empty():reject("No active selected40 game-over acknowledgement is available");return null
	var next:=fork_for_frame()
	var packet: Dictionary=next._death.request_exit()
	if packet.is_empty():reject(next._death.error);return null
	next._game_over_packet=packet
	next._state.boundary="game_over_transition_required"
	return next

func prepare_game_over() -> Dictionary:return _game_over_packet.duplicate(true)

## Source events from this completed native revision. Presentation may consume
## them once; replay/Continue keeps the same serial and cannot replay a sound.
func audio_state() -> Dictionary:
	if _state.is_empty() or _state.boundary not in ["","game_over_transition_required"]:return {}
	var context: Dictionary=_encounter.selected40_frame_context()
	if context.is_empty() or context.pending_world or context.sequence.revision!=_state.revision or context.sequence.elapsed_ms!=_state.elapsed_ms or context.elapsed_ms!=_state.elapsed_ms or context.world_elapsed_ms!=_state.elapsed_ms:return {}
	var combat: Dictionary=_encounter.audio_snapshot()
	combat.merge({"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"elapsed_ms":_state.elapsed_ms,"player_engine":_engine_audio.snapshot()},true)
	return {"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,"combat":combat,
		"flight_music":_flight_music.duplicate(true),
		"camera_view":context.view.camera,"death_events":_death.snapshot().events,
		"radio":context.sequence.radio,"radio_events":context.sequence.radio_events,
		"scanner_events":_scanner.snapshot().events}

func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate(true)
	if _career!=null:result.career=_career.snapshot()
	result.player_pose=_pose;result.player=_player.snapshot();result.encounter=_encounter.snapshot()
	result.scenery=_scenery.snapshot();result.player_engines=_engines.snapshot();result.detail=_detail.snapshot()
	result.player_destruction=_death.snapshot();result.damage_particles=_particles.snapshot();result.statistics_pose=_statistics_pose
	result.random_state=_random.duplicate(true);result.reference=_reference;result.throttle=_throttle
	result.pilot={"angular_units":_pilot.angular_units,"lateral_rate":_pilot.lateral_units_per_millisecond}
	result.npc_scanner=_scanner.snapshot();result.cargo=_cargo.snapshot()
	result.mining_targeting=_targeting.snapshot();result.flight_notices=_notices.snapshot()
	result.game_over_packet=prepare_game_over()
	result.player_engine_audio=_engine_audio.snapshot();result.flight_music=_flight_music.duplicate(true)
	result.music_context=_music_context.duplicate(true);result.radar=_radar.snapshot()
	result.station_exterior=_station.snapshot()
	result.portal=_portal.portal_snapshot();result.portal_contact=_portal.snapshot()
	return result

func frame_context() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate(true)
	if _career!=null:result.career=_career.snapshot()
	result.player_pose=_pose;result.player=_player.snapshot();result.throttle=_throttle
	result.pilot={"angular_units":_pilot.angular_units,"lateral_rate":_pilot.lateral_units_per_millisecond}
	result.encounter=_encounter.selected40_frame_context();result.random_state=_random.duplicate(true)
	result.npc_scanner=_scanner.snapshot()
	result.mining_targeting=_targeting.snapshot();result.flight_notices=_notices.snapshot()
	result.player_engine_audio=_engine_audio.snapshot();result.flight_music=_flight_music.duplicate(true)
	result.portal=_portal.portal_snapshot();result.portal_contact=_portal.snapshot()
	return result

## The prospective native location stays separate from canonical equipment.
## This is presentation context, not a committed arrival or departure permit.
func environment_state() -> Dictionary:
	if _state.is_empty():return {}
	return {"entry":_entry.duplicate(true),"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,
		"camera":_encounter.selected40_frame_context().view.camera,"portal":_portal.portal_snapshot()}

func engine_audio_owner() -> RefCounted:return null if _engine_audio==null else _engine_audio.fork_for_frame()
func station_owner() -> RefCounted:return null if _station==null else _station.fork_for_frame()
func detail_state() -> Dictionary:return {} if _detail==null else _detail.snapshot()
func portal_owner() -> RefCounted:return null if _portal==null else _portal.fork_for_frame()
## A physical contact request, not a campaign result or successor-save permit.
func portal_transition_required() -> bool:
	return _portal!=null and _death.snapshot().phase=="ready" and _portal.transition_ready(int(_player.snapshot().vitals.hull))

## Passive, source-owned HUD input. No caller-supplied vitals, cargo, radio or
## projected markers can replace the native simulation owners in this frame.
func hud_state() -> Dictionary:
	if _state.is_empty() or not _state.boundary.is_empty():return {}
	var context: Dictionary=_encounter.selected40_frame_context()
	if context.is_empty() or context.pending_world or context.sequence.revision!=_state.revision or context.sequence.elapsed_ms!=_state.elapsed_ms or context.elapsed_ms!=_state.elapsed_ms or context.world_elapsed_ms!=_state.elapsed_ms:return {}
	return {"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,"campaign_cursor":40,
		"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,"hud_visible":context.sequence.hud_visible and not campaign_dialogue_visible(),
		"player":_player.snapshot(),"cargo":_cargo.snapshot(),"control_throttle":_throttle,
		"player_aim":context.view.player_aim,"camera":context.view.camera,
		"npc_scanner":_scanner.snapshot(),"radio":context.sequence.radio,
		"mining_targeting":_targeting.snapshot(),"flight_notices":_notices.snapshot()}

## Original exhaust has its own draw/emission flags and private RNG. The
## passive presenter does not infer particle visibility from HUD or hull LOD.
func exhaust_state() -> Dictionary:
	if _state.is_empty() or not _state.boundary.is_empty() or _state.phase!="ready":return {}
	var particles: Dictionary=_engines.snapshot()
	if particles.elapsed_ms!=_state.elapsed_ms:return {}
	return {"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,
		"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,"engine_particles":particles,
		"camera_pose":_encounter.selected40_frame_context().view.camera.pose}

func engine_particles_owner() -> RefCounted:return null if _engines==null else _engines.fork_for_frame()
func destruction_owner() -> RefCounted:return null if _death==null else _death.fork_for_frame()
func damage_particles_owner() -> RefCounted:return null if _particles==null else _particles.fork_for_frame()

## One accepted simulation revision supplies both the original explosion and
## shared sprites. Their renderers must prepare together before displaying it.
func effects_state() -> Dictionary:
	var accepted:=exhaust_state()
	if accepted.is_empty():return {}
	var particles: Dictionary=_particles.snapshot()
	if particles.elapsed_ms!=_state.elapsed_ms:return {}
	return {"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,
		"revision":_state.revision,"elapsed_ms":_state.elapsed_ms,"camera_pose":accepted.camera_pose,
		"damage_particles":particles,"player_destruction":_death.snapshot(),
		"encounter":{"elapsed_ms":_encounter.selected40_frame_context().elapsed_ms}}
func presentation_identity() -> RefCounted:return _presentation_identity
func scanner_owner() -> RefCounted:return null if _scanner==null else _scanner.fork_for_frame()
func targeting_owner() -> RefCounted:return null if _targeting==null else _targeting.fork_for_frame()
func notices_owner() -> RefCounted:return null if _notices==null else _notices.fork_for_frame()

func pilot_owner() -> RefCounted:return null if _pilot==null else _pilot.fork_for_frame()
func player_owner() -> RefCounted:return null if _player==null else _player.fork_for_frame()
func scenery_owner() -> RefCounted:return null if _scenery==null else _scenery.fork_for_frame()
func encounter_owner() -> RefCounted:return null if _encounter==null else _encounter.fork_for_frame()
func equipment_owner() -> RefCounted:return null if _equipment==null else _equipment.fork()
func career_owner() -> RefCounted:return null if _career==null else _career.fork()

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate(true);copy._pose=_pose;copy._reference=_reference;copy._random=_random.duplicate(true)
	copy._throttle=_throttle;copy._viewport=_viewport;copy._max_ms=_max_ms
	copy._presentation_identity=_presentation_identity
	copy._career=_career
	copy._failure_lines=_failure_lines;copy._language=_language
	copy._statistics_pose=_statistics_pose
	copy._game_over_packet=_game_over_packet.duplicate(true)
	copy._entry=_entry;copy._music_context=_music_context;copy._music_faction=_music_faction;copy._music=_music;copy._flight_music=_flight_music.duplicate(true)
	if _state.is_empty():return copy
	copy._engine_audio=_engine_audio.fork_for_frame();copy._radar=_radar.fork_for_frame();copy._station=_station
	copy._portal=_portal.fork_for_frame()
	copy._player=_player.fork_for_frame();copy._scenery=_scenery.fork_for_frame();copy._encounter=_encounter.fork_for_frame()
	copy._death=_death.fork_for_frame();copy._particles=_particles.fork_for_frame()
	copy._pilot=_pilot.fork_for_frame();copy._physical=_physical.fork_for_frame();copy._engines=_engines.fork_for_frame();copy._detail=_detail.fork_for_frame()
	copy._equipment=_equipment
	copy._scanner=_scanner.fork_for_frame();copy._cargo=_cargo
	copy._targeting=_targeting.fork_for_frame();copy._notices=_notices.fork_for_frame()
	return copy

static func valid_viewport(size: Vector2i) -> bool:return size.x>0 and size.y>0 and size.x<=32767 and size.y<=32767
func reject(message: String) -> bool:error=message;return false
