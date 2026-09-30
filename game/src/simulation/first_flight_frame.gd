extends RefCounted
const FlightStages=preload("res://src/content/flight_stages.gd")
## Live motion, scenery and entry control for supported early ordinary flights.
## Mining approach, drilling and cargo share one field and random stream.
## The first-flight session owns application input and accepted presentation.
## Cargo completion selects the return mission after explicit acknowledgement.
const Alioth=preload("res://src/simulation/alioth_attack.gd")
const Kappa=preload("res://src/content/kappa_population_definitions.gd")
const Rescue=preload("res://src/simulation/kappa_rescue.gd")
const Story=preload("res://src/content/story_encounter_definitions.gd")
const Bakka=preload("res://src/content/bakka_contest_definitions.gd")
const Sahi=preload("res://src/simulation/sahi_encounter_stage.gd")
const VoidPortal=preload("res://src/simulation/void_portal.gd")
const ProbeStage=preload("res://src/simulation/void_probe_stage.gd")
const VoidTargeting=preload("res://src/simulation/void_station_targeting.gd")
const Portal=preload("res://src/simulation/alioth_portal.gd")
const Capture=preload("res://src/simulation/convoy_capture.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Construction=preload("res://src/simulation/first_flight_construction.gd")
const Briefing=preload("res://src/simulation/mining_briefing.gd")
const Route=preload("res://src/simulation/npc_route.gd")
const TrainingStory=preload("res://src/content/combat_training_story_definitions.gd")
const Pilot=preload("res://src/simulation/pilot_motion.gd")
const Detail=preload("res://src/presentation/ship_detail_group.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Cargo=preload("res://src/simulation/flight_cargo.gd")
const Tractor=preload("res://src/simulation/tractor_recovery.gd")
const Aim=preload("res://src/simulation/opening_aim.gd")
const Targeting=preload("res://src/simulation/mining_targeting.gd")
const TargetFrame=preload("res://src/presentation/flight_target_frame.gd")
const ScanAnimation=preload("res://src/presentation/flight_scan_animation.gd")
const Approach=preload("res://src/simulation/mining_approach.gd")
const Mining=preload("res://src/simulation/mining_session.gd")
const MiningExtraction=preload("res://src/simulation/mining_extraction.gd")
const Notices=preload("res://src/simulation/flight_notices.gd")
const Objective=preload("res://src/simulation/mining_objective.gd")
const ContractObjective=preload("res://src/simulation/contract_flight_objective.gd")
const Wingmen=preload("res://src/simulation/wingman_actors.gd")
var _wingmen: RefCounted
const ContractWorld=preload("res://src/content/contract_world_definitions.gd")
const FreeFlight=preload("res://src/content/free_flight_definitions.gd")
const DeathResources=preload("res://src/content/npc_destruction_resources.gd")
const StationTargeting=preload("res://src/simulation/station_targeting.gd")
const Station=preload("res://src/content/station_exterior_resources.gd")
const StationFlight=preload("res://src/content/station_flight_definitions.gd")
const Autopilot=preload("res://src/simulation/station_autopilot.gd")
const StationReturn=preload("res://src/content/station_return_definitions.gd")
const FullHoldReturn=preload("res://src/content/full_hold_return_definitions.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const OrdinaryFlight=preload("res://src/content/ordinary_flight_definitions.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const Particles=preload("res://src/simulation/full_hold_particles.gd")
const Booster=preload("res://src/simulation/player_booster.gd")
const Engines=preload("res://src/simulation/player_engine_particles.gd")
const EngineAudio=preload("res://src/simulation/opening_engine_audio.gd")
var _engine_audio: RefCounted
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Death=preload("res://src/simulation/player_destruction.gd")
const Radio=preload("res://src/simulation/radio_sequence.gd")
const LocalRadio=preload("res://src/simulation/local_traffic_radio.gd")
const RadioResources=preload("res://src/presentation/opening_radio_resources.gd")
const Scanner=preload("res://src/simulation/opening_npc_scanner.gd")
const LocalTravel=preload("res://src/simulation/local_travel.gd")
const GateAnimation=preload("res://src/simulation/gate_animation.gd")
const GateTransit=preload("res://src/simulation/gate_transit.gd")
const GateArrival=preload("res://src/content/gate_arrival_definitions.gd")
const Drive=preload("res://src/simulation/khador_drive.gd")
const SystemNavigation=preload("res://src/simulation/system_navigation.gd")
const Context=preload("res://src/simulation/mission_context.gd")
const FastForward=preload("res://src/simulation/fast_forward.gd")
var _drive: RefCounted
var _drive_arrival: RefCounted
var error:=""
const PhysicalContacts=preload("res://src/simulation/physical_scenery_contacts.gd")
const Music=preload("res://src/simulation/ordinary_music.gd")
var _physical_contacts: RefCounted
var _music: RefCounted
var _music_context:={}
var _music_faction:=-1
var _flight_music:={}
var _entry:={}
var _pose:=Transform3D.IDENTITY
var _shot:={}
var _random:={}
var _reference:=Vector3.ZERO
var _briefing: RefCounted
var _route: RefCounted
var _rescue: RefCounted
var _sahi: RefCounted
var _void_environment: RefCounted
var _ordinary_void_source: RefCounted
var _void_portal: RefCounted
var _probe: RefCounted
var _void_targeting: RefCounted
var _navigation:={}
var _world_path:=[]
var _world_route: RefCounted
var _player: RefCounted
var _scenery: RefCounted
var _camera: RefCounted
var _pilot: RefCounted
var _detail: RefCounted
var _cargo: RefCounted
var _tractor: RefCounted
var _tractor_frame:={}
var _aim: RefCounted
var _targeting: RefCounted
var _approach: RefCounted
var _mining: RefCounted
var _mining_audio:={}
var _notices: RefCounted
var _objective: RefCounted
var _station: RefCounted
var _station_targeting: RefCounted
var _autopilot: RefCounted
var _preceding_commands:=Vector2.ZERO
var _return_rules:={}
var _departure_station: RefCounted
var _station_contact:=false
## Where retired story ships are parked, far outside any scene.
const Worlds=preload("res://src/content/valkyrie_world_definitions.gd")
## Remake docking reach beyond a story docking point's hit box (the original's
## docking point distance was not recovered) and the original 1.5 s per person.
const STORY_DOCK_RANGE:=2500.0
const STORY_TRANSFER_MS:=1500
const RETIRE_POINT:=Vector3(800000,800000,800000)
## The station has left this flight (a story action): not drawn, no docking.
var _station_hidden:=false
var _station_packet:={}
var _model_basis:=Basis.IDENTITY
var _throttle:=1.0
var _viewport:=Vector2i(1280,720)
var _collision_enabled:=false
var _encounter: RefCounted
var _world_elapsed_ms:=0
var _unsupported_boundary:=""
var _death: RefCounted
var _particles: RefCounted
var _booster: RefCounted
var _engine_particles: RefCounted
var _equipment: RefCounted
var _radio: RefCounted
var _radio_events:=[]
var _scanner: RefCounted
var _scanner_events:=[]
# Action-only forks retain this serial. The audio presenter commits each native
# pass once, after the corresponding scene has been accepted.
var _audio_frame:={}
var _statistics_pose:=Transform3D.IDENTITY
var _camera_follow_enabled:=true
var _game_over_packet:={}
var _local_travel: RefCounted
var _station_response_flags:={}
var _alioth: RefCounted
var _portal: RefCounted
var _alioth_camera:={}
var _convoy: RefCounted
var _convoy_camera:={}
var _convoy_career: RefCounted
var _selected_locations: RefCounted
var _story_bindings: RefCounted
var _story_catalogues: RefCounted
var _gate_animation: RefCounted
var _gate_transit: RefCounted
var _gate_destinations:=[]
var _gate_cruise_speed:=0.0
var _system_navigation: RefCounted
var _navigation_destinations: Array=[]
var _pending_destination:=-1
var _queued_drive:=false
## A free story jump waiting to start (STORY_JUMP / an automatic Void exit); -2 = none.
var _story_jump:=-2
## A story scene holds the player (89: the supernova), set by lock_player.
var _story_locked:=false
## Supernova people-moving flights: docking points, people aboard, the story
## status and the flight time a delayed radio action was first cued.
var _story_dock:={}
var _action_marks:={}
var _story_cloaks:={}
## 105: the player's route toward the sun (N3); its end point is set from
## where the flight starts.
var _story_route:={}
## The hacking puzzle while docked at a story "hack" point (125, 139, 154).
var _story_hack: RefCounted
## Assumption: a story course point counts as reached within 5 km (the
## original's waypoint radius is not recovered).
const STORY_ROUTE_REACH:=5000.0
const STORY_DELIVER_MS:=1000
var _line_marks:={"started":{},"finished":{}}
## Gamma radiation in this orbit: loss per second after the fitted gamma
## shield's cut (0 = no radiation). Fixed for the flight.
var _gamma_rate:=0.0
## Volatile cargo (V2): instability 0..1 while the Mutagen or Red Plasma is
## aboard; the ship explodes at 1.
var _instability:=0.0
## The last frame's steering, for the volatile cargo's steering term.
var _volatile_steer:=Vector2.ZERO
var _navigation_applied:=false
var _fast_forward: RefCounted
var _near_target:=false
var _camera_ms:=0
var _camera_passes:=1
var _mission_context: RefCounted
var _mission_station_return:={}
var _mission_station_identity: RefCounted

func configure(bindings: RefCounted, catalogues: RefCounted, library: RefCounted, construction: RefCounted, dock_key: String, sensitivity: float, viewport_size:=Vector2i(1280,720), mobile_layout:=false, hard_difficulty:=false, autopilot_key:="Q", primary_key:="Space", fast_forward_key:="Tab") -> bool:
	error=""
	if construction==null or construction.get_script()!=Construction:return reject("First flight requires a prepared departure owner")
	var entry: Dictionary=construction.snapshot()
	var ordinary_world:=ContractWorld.ordinary_entry(bindings,entry)
	var free_world:=FreeFlight.ordinary_entry(bindings,entry)
	var rescue_world:=Kappa.prepared_entry(bindings,entry)
	var sahi_world:=Story.prepared_entry(bindings,entry)
	var bakka_world: bool=entry.get("campaign_cursor")==36 and Bakka.context_valid(bindings,entry.get("bakka_context",{}))
	var mission_context: RefCounted=construction.mission_context_owner()
	var mission_world: bool=mission_context!=null and mission_context.advances_campaign()
	if mission_world:
		if not mission_context.matches_source(bindings,entry.departure):return reject("The prepared convoy changed its explicit source provenance")
	var ordinary_void:=Story.prepared_ordinary_void(bindings,entry)
	var void_source: RefCounted=construction.ordinary_void_source_owner()
	var void_world: bool=ordinary_void or (sahi_world and entry.campaign_cursor in [25,29])
	if ordinary_void and construction.contract_owner()!=null and entry.departure.difficulty!=construction.contract_owner().snapshot().difficulty:return reject("Ordinary Void flight changed its retained difficulty")
	var void_environment: RefCounted=construction.void_environment_owner() if void_world else null
	if void_world and void_environment==null:return reject("Void flight requires its generated special environment")
	if OrdinaryFlight.for_departure(bindings,entry).is_empty():return reject("This construction has no supported ordinary departure")
	var briefing:=Briefing.new()
	if not briefing.configure(bindings,library,construction,primary_key if construction.snapshot().campaign_cursor==7 else dock_key,fast_forward_key,{"#KEY_SECONDARY":"R / B / LT","#KEY_SECONDARY_WEAPONS":"G / D-pad right"}):return reject(briefing.error)
	var cargo:=Cargo.new()
	if not cargo.configure_departure(bindings,catalogues,construction):return reject(cargo.error)
	var player: RefCounted=construction.player_owner()
	if not player.configure_cloak(bindings,catalogues,entry.departure.get("difficulty",1.0 if hard_difficulty else 0.5)):return reject(player.error)
	var equipment: RefCounted=construction.equipment_owner()
	if entry.campaign_cursor==7 and equipment!=null and not equipment.prepare_training_completion(bindings,catalogues):return reject(equipment.error)
	var encounter: RefCounted
	var route: RefCounted
	var navigation:={}
	if entry.campaign_cursor==7:
		navigation=TrainingStory.navigation(bindings)
		if not navigation.is_empty():
			route=Route.new()
			if not route.configure_training_player(bindings):return reject(route.error)
		encounter=Encounter.new()
		if not encounter.configure_combat_training(bindings,catalogues,library,player,construction.scenery_owner(),int(entry.departure.progress.rank),1.0 if hard_difficulty else .5):return reject(encounter.error)
	elif entry.campaign_cursor==4:
		encounter=Encounter.new()
		if not encounter.configure(bindings,catalogues,library,construction,1.0 if hard_difficulty else .5):return reject(encounter.error)
	elif entry.campaign_cursor in [10,11,12]:
		encounter=Encounter.new()
		if not encounter.configure_local_traffic(bindings,catalogues,library,construction,1.0 if hard_difficulty else .5):return reject(encounter.error)
	elif bakka_world:
		encounter=Encounter.new()
		if not encounter.configure_bakka(bindings,catalogues,library,construction) or not encounter.sample_bakka_clock(0,0):return reject(encounter.error)
	elif mission_world:
		encounter=Encounter.new()
		if not encounter.configure_mission(bindings,catalogues,library,player,construction.scenery_owner(),equipment,entry.departure.progress.reputation,mission_context) or not encounter.sample_mission_clock(0,0):return reject(encounter.error)
	elif ordinary_void:
		encounter=Encounter.new()
		if not encounter.configure_ordinary_void(bindings,catalogues,library,player,construction.scenery_owner(),equipment,entry.departure.progress.reputation,void_source,entry.departure.difficulty):return reject(encounter.error)
	elif sahi_world:
		encounter=Encounter.new()
		if not encounter.configure_story(bindings,catalogues,library,player,construction.scenery_owner(),equipment,entry.departure.progress.reputation):return reject(encounter.error)
	elif ordinary_world:
		encounter=Encounter.new()
		if not encounter.configure_contract_world(bindings,catalogues,library,construction) or not encounter.sample_contract_clock(0,0):return reject(encounter.error)
	elif entry.campaign_cursor==14 and not ordinary_world:
		encounter=Encounter.new()
		if not encounter.configure_convoy(bindings,catalogues,library,construction):return reject(encounter.error)
	elif entry.campaign_cursor==16:
		encounter=Encounter.new()
		if not encounter.configure_alioth(bindings,catalogues,library,construction):return reject(encounter.error)
	elif free_world:
		encounter=Encounter.new()
		if not encounter.configure_free(bindings,catalogues,library,construction) or not encounter.sample_contract_clock(0,0):return reject(encounter.error)
	elif rescue_world:
		encounter=Encounter.new();route=Route.new()
		var career: Dictionary=construction.contract_owner().snapshot()
		if not encounter.configure_kappa_rescue(bindings,catalogues,library,player,construction.scenery_owner(),equipment,career.reputation) or not route.configure_kappa_player(bindings):return reject(encounter.error+route.error)
	var rescue: RefCounted
	if rescue_world:
		rescue=Rescue.new()
		if not rescue.configure(bindings):return reject(rescue.error)
	var sahi: RefCounted
	if sahi_world and entry.campaign_cursor==24:
		sahi=Sahi.new()
		var selected: Dictionary=entry.sahi_context.duplicate(true)
		selected.current_station_id=int(entry.location.station_id)
		selected.void_station_id=-1
		selected.current_station_special=false
		selected.environment_object=entry.environment_object
		if not sahi.configure(bindings,selected,library):return reject(sahi.error)
	var void_portal: RefCounted
	if void_source!=null:
		void_portal=VoidPortal.new()
		if not void_portal.configure_ordinary(bindings,entry,void_source,library):return reject(void_portal.error)
	elif void_world or (sahi_world and entry.campaign_cursor==28):
		void_portal=VoidPortal.new()
		var selected: Dictionary=entry.sahi_context.duplicate(true)
		selected.current_station_id=int(entry.location.station_id)
		selected.void_station_id=-1
		selected.environment_object=entry.environment_object
		if entry.campaign_cursor==29:selected.return_station_id=int(entry.void_environment.return_station_id)
		if not void_portal.configure(bindings,selected,library):return reject(void_portal.error)
	var probe: RefCounted
	if void_world and entry.campaign_cursor==29:
		probe=ProbeStage.new()
		var selected: Dictionary=entry.sahi_context.duplicate(true)
		selected.current_station_id=-1;selected.void_station_id=-1
		selected.return_station_id=int(entry.void_environment.return_station_id)
		if not probe.configure(bindings,selected):return reject(probe.error)
	var alioth: RefCounted;var portal: RefCounted
	if entry.campaign_cursor==16:
		alioth=Alioth.new();portal=Portal.new()
		if not alioth.configure(bindings) or not portal.configure(bindings,entry,library):return reject(alioth.error+portal.error)
	var convoy: RefCounted
	if entry.campaign_cursor==14 and not ordinary_world:
		convoy=Capture.new()
		if not convoy.configure(bindings):return reject(convoy.error)
	var death: RefCounted
	var first_mining_contacts: bool=entry.campaign_cursor==2 and not bindings.physical_scenery_contacts.is_empty()
	if (encounter!=null or first_mining_contacts) and not bindings.player_destruction.is_empty():
		death=Death.new()
		var resources: RefCounted=encounter.destruction_resources() if encounter!=null else null
		if resources==null or mission_world or free_world or entry.campaign_cursor in FlightStages.FACTIONS:
			resources=DeathResources.new()
			if not resources.configure(library,bindings):return reject(resources.error)
		if not death.configure(bindings,resources,construction,catalogues):return reject(death.error)
	var particles: RefCounted
	if death!=null and not bindings.full_hold_particles.is_empty():
		particles=Particles.new()
		var prepared: bool=particles.configure_first_mining(bindings,death,int(entry.unix_seconds)) if encounter==null else particles.configure(bindings,encounter.snapshot().combat,death,int(entry.unix_seconds),mission_context)
		if not prepared:return reject(particles.error)
	var radio: RefCounted
	if entry.campaign_cursor in [7,16] or (mission_world and not mission_context.recipe().radio.is_empty()) or rescue_world or (sahi_world and entry.campaign_cursor in [24,25,28,29]) or (entry.campaign_cursor==14 and not ordinary_world):
		var resources:=RadioResources.new();radio=Radio.new()
		if not resources.prepare(library,bindings,null,int(entry.campaign_cursor)) or not radio.configure(bindings,library,resources.line_counts,int(entry.campaign_cursor)):return reject(resources.error+radio.error)
	elif ordinary_void and not load("res://src/content/valkyrie_flight_definitions.gd").void_radio(int(entry.campaign_cursor)).is_empty():
		var resources:=RadioResources.new();radio=Radio.new()
		var layout:=resources.prepare_layout(library,bindings)
		if layout==null or not radio.configure_scripted(bindings,library,layout,int(entry.campaign_cursor),load("res://src/content/valkyrie_flight_definitions.gd").void_radio(int(entry.campaign_cursor))):return reject(resources.error+radio.error)
	elif mission_context!=null and not mission_world and not mission_context.recipe().radio.is_empty():
		var resources:=RadioResources.new();radio=Radio.new()
		var layout:=resources.prepare_layout(library,bindings)
		if layout==null or not radio.configure_scripted(bindings,library,layout,int(entry.campaign_cursor),mission_context.recipe().radio):return reject(resources.error+radio.error)
	elif entry.campaign_cursor in [10,11,12] or ordinary_world or free_world:
		var resources:=RadioResources.new();radio=LocalRadio.new()
		var layout:=resources.prepare_layout(library,bindings)
		if layout==null or not radio.configure(bindings,library,layout,int(entry.campaign_cursor)):return reject(resources.error+radio.error)
	var pilot:=Pilot.new();var detail:=Detail.new()
	var loadout: Dictionary=entry.departure.loadout
	var booster:=Booster.new()
	if not booster.configure(bindings,catalogues,loadout.equipment_ids):return reject(booster.error)
	var tractor: RefCounted
	if equipment!=null and encounter!=null and Tractor.Definitions.available(bindings):
		var candidate:=Tractor.new()
		if not candidate.configure(bindings,catalogues,loadout,library):return reject(candidate.error)
		if candidate.snapshot().equipment_id>=0:
			tractor=candidate
			if not cargo.bind_recovery(tractor):return reject(cargo.error)
	var engine_particles: RefCounted
	if Engines.Definitions.available_for(bindings,int(loadout.ship_id)):
		var mounts:=Mounts.new();engine_particles=Engines.new()
		if not mounts.open(library,catalogues) or not engine_particles.configure(bindings,mounts,int(loadout.ship_id),int(entry.unix_seconds)):return reject(mounts.error+engine_particles.error)
	if not pilot.configure_vehicle(bindings,catalogues,bindings.base_content_id,int(loadout.ship_id),preload("res://src/simulation/ship_instance.gd").upgrades(loadout),loadout.equipment_ids,sensitivity):return reject(pilot.error)
	if not player.set_permissions(true,false):return reject(player.error)
	var ships:={"player":int(loadout.ship_id)};var positions:={"player":entry.player_pose.origin};var freighters:=[];var assemblies:={}
	if encounter!=null:
		for actor in encounter.snapshot().combat.actors:
			if actor.get("population_group") in ["debris","static"]:continue
			ships[actor.actor_id]=int(actor.hull_catalogue_id);positions[actor.actor_id]=actor.position
			if actor.get("population_group") in ["freighter","capital"]:
				freighters.append(actor.actor_id);assemblies[actor.actor_id]=encounter.freighter_assembly(actor.actor_id)
	if not detail.configure(bindings,ships,freighters,assemblies) or not detail.refresh(positions,Vector3.ZERO,1.0):return reject(detail.error)
	var camera: RefCounted=construction.camera_owner()
	var shot: Dictionary=entry.camera_shot.duplicate(true)
	shot.merge({"mode":"fixed_eye","eye":entry.camera_view.eye,"inherit_target_up":true},true)
	if not camera.update(0,shot,entry,shot):return reject(camera.error)
	var aim: RefCounted;var targeting: RefCounted
	if viewport_size.x<1 or viewport_size.y<1 or viewport_size.x>32767 or viewport_size.y>32767:return reject("Invalid first-flight viewport")
	if not bindings.mining_targeting.is_empty():
		var frame_art:=TargetFrame.source_geometry(library,bindings)
		if frame_art.has("error"):return reject(frame_art.error)
		var animation:=ScanAnimation.source_geometry(library,bindings,bindings.mining_targeting)
		if animation.has("error"):return reject(animation.error)
		aim=Aim.new();targeting=Targeting.new()
		if not aim.configure(bindings) or not aim.advance(entry.player_pose,camera.snapshot().pose,viewport_size) or not aim.sample_feedback(false,0,false):return reject(aim.error)
		if not targeting.configure(bindings,catalogues,construction,TargetFrame.logical_radii(frame_art.quarter_size,mobile_layout),animation.frames):return reject(targeting.error)
		if not targeting.advance(construction.scenery_owner(),entry.player_pose,camera.snapshot().pose,aim.snapshot(),0,false):return reject(targeting.error)
	var scanner: RefCounted
	if equipment!=null:
		var art:=TargetFrame.source_geometry(library,bindings)
		var strip:=ScanAnimation.source_geometry(library,bindings,bindings.opening_staging.npc_scanner)
		if art.has("error") or strip.has("error"):return reject("Training NPC acquisition art is unavailable")
		scanner=Scanner.new()
		if not scanner.configure(bindings,catalogues,TargetFrame.logical_radii(art.quarter_size,mobile_layout),int(strip.frames),equipment,encounter.snapshot().combat if encounter!=null and equipment!=null and entry.campaign_cursor!=7 else {},tractor,mission_context):return reject(scanner.error)
		if not scanner.advance(encounter.snapshot().combat,entry.player_pose,camera.snapshot().pose,aim.snapshot(),0,false):return reject(scanner.error)
	var void_targeting: RefCounted
	if probe!=null:
		var art:=TargetFrame.source_geometry(library,bindings)
		if art.has("error"):return reject(art.error)
		void_targeting=VoidTargeting.new()
		if not void_targeting.configure(bindings,catalogues,loadout,void_environment,TargetFrame.logical_radii(art.quarter_size,mobile_layout)):return reject(void_targeting.error)
	var approach: RefCounted
	if not bindings.mining_approach.is_empty():
		approach=Approach.new()
		if not approach.configure(bindings,catalogues,construction):return reject(approach.error)
	var mining: RefCounted
	if not bindings.mining_session.is_empty():
		mining=Mining.new()
		if not mining.configure(bindings,catalogues,construction,hard_difficulty):return reject(mining.error)
	var notices: RefCounted
	# Shared station guidance names this constructed location; it does not
	# add mission-specific B'akka dialogue or change result ownership.
	if not bindings.flight_notices.is_empty():
		notices=Notices.new()
		if not notices.configure(bindings,library,construction,catalogues):return reject(notices.error)
	var objective: RefCounted
	if ordinary_world or free_world or rescue_world:
		objective=ContractObjective.new()
		if not objective.configure(bindings,construction,encounter,library):return reject(objective.error)
	elif not bindings.mining_objective.is_empty():
		objective=Objective.new()
		if not objective.configure(bindings,library,construction,autopilot_key,dock_key):return reject(objective.error)
	var station: RefCounted
	var flight_context: RefCounted=construction.flight_context_owner()
	if not void_world and not bindings.station_exterior.is_empty() and (flight_context==null or not flight_context.has_method("station_present") or flight_context.station_present()):
		station=Station.new()
		if not station.configure(library,bindings,catalogues,construction):return reject(station.error)
	var station_targeting: RefCounted
	if station!=null and targeting!=null:
		var art:=TargetFrame.source_geometry(library,bindings)
		if art.has("error"):return reject(art.error)
		station_targeting=StationTargeting.new()
		if not station_targeting.configure_ordinary(bindings,station.snapshot(),targeting.snapshot(),TargetFrame.logical_radii(art.quarter_size,mobile_layout),int(entry.campaign_cursor)):return reject(station_targeting.error)
	var autopilot: RefCounted
	if not bindings.station_flight.is_empty():
		if not StationFlight.parameters(bindings.station_flight) or notices==null:return reject("This departure has incomplete station flight declarations")
		autopilot=Autopilot.new()
		if not autopilot.configure(bindings,catalogues,construction,station):return reject(autopilot.error)
		if not pilot.set_response_factor(autopilot.snapshot().response_factor):return reject(pilot.error)
	if not bindings.station_return.is_empty() and (not StationReturn.parameters(bindings.station_return) or autopilot==null or objective==null):return reject("This departure has incomplete station return support")
	var fast_forward: RefCounted
	if not bakka_world and FastForward.Definitions.radar_available(bindings.fast_forward) and FastForward.supported_population([] if encounter==null else encounter.combat_snapshot().actors):
		if autopilot==null:return reject("Fast Forward requires the native player response owner")
		fast_forward=FastForward.new()
		if not fast_forward.configure(bindings) or not fast_forward.configure_radar(catalogues,loadout.equipment_ids):return reject(fast_forward.error)
	var local_travel: RefCounted
	var trip:=Travel.journey(bindings.mido_travel,int(entry.campaign_cursor))
	if not trip.is_empty() and entry.location.station_id==int(trip.from_station_id):
		local_travel=LocalTravel.new()
		if aim==null or autopilot==null or not local_travel.configure_flight(bindings,catalogues,equipment,entry):return reject(local_travel.error)
		if not local_travel.sample_frame(camera.snapshot().pose,aim.snapshot(),0,-1,false):return reject(local_travel.error)
	elif ordinary_world or (free_world and Travel.free_local_navigation(bindings,int(entry.campaign_cursor))):
		local_travel=LocalTravel.new()
		if aim==null or autopilot==null or not local_travel.configure_flight(bindings,catalogues,equipment,entry):return reject(local_travel.error)
		if not local_travel.sample_frame(camera.snapshot().pose,aim.snapshot(),0,-1,false):return reject(local_travel.error)
	# Keep the shared contact handler during the contest: unfinished kind12
	# receives the original refusal notice, never a station-arrival packet.
	# Only final result acknowledgement selects the permitted kind160 return.
	var return_rules: Dictionary={} if sahi_world or void_world else OrdinaryFlight.docking(bindings,int(entry.campaign_cursor)+1)
	var gate_animation: RefCounted;var gate_transit: RefCounted;var gate_destinations:=[]
	var system_navigation: RefCounted;var navigation_destinations:=[];var drive: RefCounted
	if free_world or (ordinary_void and construction.contract_owner()!=null):
		system_navigation=SystemNavigation.new()
		var career: Dictionary=construction.contract_owner().snapshot()
		if not system_navigation.configure(bindings,catalogues,career.get("lounges",{}).get("system_availability")):return reject(system_navigation.error)
		var observation:=entry.duplicate();observation.contracts=career;observation.mission=entry.departure.mission
		navigation_destinations=[] if ordinary_void else Context.navigation_destinations(bindings,catalogues,observation)
		var return_route:=Context.ordinary_void_route(bindings,void_source)
		var return_location: Dictionary={} if return_route.is_empty() else {"station_id":return_route.source_station_id,"system_id":return_route.source_system_id}
		drive=Drive.new()
		if not drive.configure(bindings,catalogues,loadout,career.difficulty,system_navigation,navigation_destinations,return_location):return reject(drive.error)
	if void_world:
		var layout: RefCounted=load("res://src/simulation/gate_environment.gd").new()
		gate_animation=GateAnimation.new()
		if not layout.configure_void(bindings,void_environment) or not gate_animation.configure_layout(bindings,library,layout):return reject(layout.error+gate_animation.error)
	if (free_world or (mission_world and mission_context.has_feature("normal_space"))) and GateArrival.available(bindings):
		gate_animation=GateAnimation.new()
		if not gate_animation.configure(bindings,catalogues,library,int(entry.location.station_id)):return reject(gate_animation.error)
		if free_world and gate_animation.snapshot().layout.objects.any(func(gate):return gate.index==1 and gate.interactive):
			gate_transit=GateTransit.new()
			if not gate_transit.configure(bindings,gate_animation,system_navigation):return reject(gate_transit.error)
			for destination in navigation_destinations:
				var destination_system:=int(catalogues.tables.stations[destination].system_id)
				if destination!=entry.location.station_id and (destination_system==entry.location.system_id or catalogues.tables.systems[entry.location.system_id].linked_system_ids.has(destination_system)):gate_destinations.append(destination)
			gate_animation=null # Transit now owns the one animation clock.
	if not trip.is_empty():
		return_rules=OrdinaryFlight.docking(bindings,int(entry.campaign_cursor)) if entry.location.station_id==int(trip.station_id) else {}
	elif mission_context!=null and not mission_context.advances_campaign():return_rules=mission_context.ordinary_docking_rules()
	elif ordinary_world:return_rules=ContractWorld.docking(bindings,int(entry.location.station_id),entry.campaign_cursor)
	elif free_world:return_rules=FreeFlight.docking(bindings,int(entry.location.station_id),entry.campaign_cursor)
	elif sahi_world and entry.campaign_cursor==26:return_rules=OrdinaryFlight.docking(bindings,26)
	if entry.campaign_cursor==4 and not bindings.full_hold_return.is_empty() and (return_rules.is_empty() or autopilot==null or objective==null):return reject("This departure has incomplete second station return support")
	var wingmen:=Wingmen.new()
	if not wingmen.configure(bindings,catalogues,construction,library):return reject(wingmen.error)
	# Every mutable owner is detached from the station and construction. Failed
	# preparation cannot replace the current good flight.
	_entry=entry;_pose=entry.player_pose;_shot=shot;_random=entry.random_state.duplicate(true)
	_reference=Vector3.ZERO;_briefing=briefing;_player=player;_pilot=pilot;_detail=detail
	_scenery=construction.scenery_owner();_camera=camera;_collision_enabled=false
	_cargo=cargo;_tractor=tractor;_tractor_frame={}
	_aim=aim;_targeting=targeting;_viewport=viewport_size
	_approach=approach;_model_basis=Basis.IDENTITY;_throttle=1.0
	_mining=mining;_notices=notices;_objective=objective
	_wingmen=null if wingmen.snapshot().is_empty() else wingmen
	_station=station;_station_targeting=station_targeting
	_autopilot=autopilot;_preceding_commands=Vector2.ZERO
	# Docking needs a station; an empty orbit has none to return to.
	_return_rules=return_rules if station!=null else {};_departure_station=null
	_station_contact=false;_station_packet={};_encounter=encounter;_world_elapsed_ms=0
	_mission_context=mission_context
	_story_dock=_story_people(catalogues,entry)
	if _mining!=null and _mission_context!=null and int(_mission_context.recipe().get("asteroid_ore",-1))>=0:_mining.ore_override=int(_mission_context.recipe().asteroid_ore)
	_story_route=_player_route(catalogues,entry)
	_engine_audio=EngineAudio.new()
	if not _engine_audio.configure_player(bindings,catalogues,player,_pose):return reject(_engine_audio.error)
	_unsupported_boundary=""
	_death=death;_statistics_pose=entry.player_pose;_camera_follow_enabled=true;_game_over_packet={}
	_particles=particles;_equipment=equipment
	_gamma_rate=_radiation(bindings,catalogues,entry,equipment)
	_engine_particles=engine_particles;_booster=booster
	_radio=radio;_radio_events=[]
	_scanner=scanner;_scanner_events=[]
	_route=route;_navigation=navigation;_rescue=rescue;_sahi=sahi;_void_environment=void_environment;_void_portal=void_portal;_ordinary_void_source=void_source
	_probe=probe;_void_targeting=void_targeting
	_world_path=entry.scenery.world_initialization.npc_construction.get("contract_encounter",{}).get("path",[]).duplicate(true) if ordinary_world else []
	_world_route=null
	if not _world_path.is_empty():
		_world_route=Route.new()
		if not _world_route.configure_world_path(bindings,_world_path):return reject(_world_route.error)
	_audio_frame={} if death==null else {"serial":0,"player_tail":{},"player_poll":{},"actors":[]}
	_local_travel=local_travel
	_station_response_flags=entry.departure.get("station_response_flags",{}).duplicate(true)
	_alioth=alioth;_portal=portal;_alioth_camera={}
	_convoy=convoy;_convoy_camera={}
	_convoy_career=construction.contract_owner() if convoy!=null or alioth!=null or sahi_world or ordinary_void or bakka_world or mission_world else null
	_selected_locations=construction.selected_locations_owner() if sahi_world and _convoy_career==null else null
	_story_bindings=bindings if free_world or rescue_world or sahi_world or ordinary_void or bakka_world or mission_world or return_rules.get("alioth_return",false) else null
	_story_catalogues=catalogues if sahi_world or free_world or ordinary_void else null
	_gate_animation=gate_animation;_gate_transit=gate_transit;_gate_destinations=gate_destinations
	_system_navigation=system_navigation;_navigation_destinations=navigation_destinations
	_drive=drive;_drive_arrival=null
	_pending_destination=int(entry.get("navigation_destination_id",-1));_navigation_applied=false;_queued_drive=false;_story_jump=-2;_story_locked=false;_action_marks={};_story_cloaks={};_line_marks={"started":{},"finished":{}}
	# A story waiting in another orbit (89: Naneroh) takes the ship there at once.
	var move: Dictionary=load("res://src/content/valkyrie_campaign_definitions.gd").story_move(int(entry.get("campaign_cursor",-1)))
	# "launch" (126) arrives the same way: in flight at the story's station.
	if move.get("arrive","") in ["gate","launch"] and _drive!=null and int(entry.get("location",{}).get("station_id",-1))!=int(move.station_id):_story_jump=int(move.station_id)
	_gate_cruise_speed=float(bindings.cruise.speed_units_per_millisecond)
	_fast_forward=fast_forward;_near_target=false;_camera_ms=0;_camera_passes=1
	_mining_audio={} if targeting==null else {"serial":0,"events":[]}
	_physical_contacts=null
	if not bindings.physical_scenery_contacts.is_empty():
		_physical_contacts=PhysicalContacts.new()
		if not _physical_contacts.configure(bindings.physical_scenery_contacts,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id},{} if station==null else station.snapshot(),_scenery.read_snapshot().get("bodies",{})):return reject(_physical_contacts.error)
	_music=null;_music_context={};_music_faction=-1;_flight_music={}
	# The source station is fixed before cursor32. From32 onward, the career
	# must supply its actual rerolling Void-source owner before music can attach.
	if not bindings.ordinary_music.is_empty() and fast_forward!=null and int(entry.campaign_cursor)<32:
		_music_context={"world_type":int(entry.world_type),"campaign_cursor":int(entry.campaign_cursor),"selected_station_id":int(entry.location.station_id),"system_id":int(entry.location.system_id),"retained_void_station_id":-1,
			"void_source_station_id":int(bindings.mido_travel.thynome_expedition.mission28.station_id) if int(entry.campaign_cursor)>=28 else -1}
		if not Music.context_kind(_music_context,0).is_empty():
			_music=Music.new()
			if not _music.configure(bindings.ordinary_music):return reject(_music.error)
			if int(entry.location.system_id)>=0:_music_faction=int(catalogues.tables.systems[int(entry.location.system_id)].fields[int(bindings.station_exterior.system_faction_field)])
			_flight_music={"operations":[]}
	return true

func evaluate(milliseconds: Variant, commands:=Vector2.ZERO, throttle:=1.0, paused:=false, viewport_size:=Vector2i.ZERO, drill_command:=Vector2.ZERO, primary_fire:=false, secondary_fire:=false, relative_mouse_capture:=false, current_music_id:=-1, strafe:=0.0, boost_requested:=false,cloak_requested:=false,turret_inverted:=false) -> RefCounted:
	error=""
	if _briefing==null or not Numbers.integer(milliseconds,0,150) or not commands.is_finite() or absf(commands.x)>1.0 or absf(commands.y)>1.0 or not is_finite(throttle) or throttle<0.0 or throttle>1.0:
		reject("Invalid first-flight frame, command or throttle");return null
	if not drill_command.is_finite() or absf(drill_command.x)>1 or absf(drill_command.y)>1:reject("Invalid first-flight drilling command");return null
	var viewport:=_viewport if viewport_size==Vector2i.ZERO else viewport_size
	if viewport.x<1 or viewport.y<1 or viewport.x>32767 or viewport.y>32767:reject("Invalid first-flight viewport");return null
	var next:=fork_for_frame()
	if paused or not _station_packet.is_empty() or not _game_over_packet.is_empty() or not _unsupported_boundary.is_empty() or mission_station_return_required():return next
	if contract_result_pending() or convoy_arrival_required() or sahi_arrival_required() or void_return_required():return next
	if gate_modal() or not prepare_gate_arrival().is_empty() or not prepare_drive_arrival().is_empty():return next
	if _local_travel!=null and _local_travel.snapshot().phase=="arrival_required" and not death_active():return next
	next._radio_events=[];next._scanner_events=[]
	next._begin_mining_audio_batch()
	if next._music!=null:next._flight_music={"operations":[]}
	next._tractor_frame={}
	if next._encounter!=null:next._encounter.clear_secondary_events()
	if next._convoy!=null:next._convoy.clear_frame_cues()
	if next._alioth!=null:next._alioth.clear_frame_cues()
	if next._sahi!=null:next._sahi.clear_frame_cues()
	if next._void_portal!=null:next._void_portal.clear_frame_cues()
	if next._probe!=null:next._probe.clear_frame_cues()
	if not next._audio_frame.is_empty():next._audio_frame={"serial":int(_audio_frame.serial)+1,"player_tail":{},"player_poll":{},"actors":[]}
	if dialogue_visible():
		# Source modal frames omit ordinary logic, but visit NPC/scenery with
		# zero time. Activation and retained per-pass state can still change.
		if not next._advance_world(0,_reference):reject(next.error);return null
		if not next._observe_radio():reject(next.error);return null
		return next
	# Earlier packs keep their explicit pre-drill support boundary.
	if _mining==null and _approach!=null and _approach.snapshot().phase=="drill_required":return next
	next._viewport=viewport
	if not next._briefing.advance(milliseconds,false,true):reject(next._briefing.error);return null
	var delta_ms: int=next._briefing.simulation_delta_ms()
	next._camera_ms=delta_ms;next._camera_passes=1
	if next._fast_forward!=null:
		var timing: Dictionary=next._fast_forward.frame(delta_ms,_fast_forward.battle(),_near_target,_radio!=null and _radio.snapshot().get("visible",false))
		if timing.is_empty():reject(next._fast_forward.error);return null
		if timing.reset and not next._camera.set_fast_forward(false):reject(next._camera.error);return null
		delta_ms=timing.simulation_ms;next._camera_ms=timing.camera_ms;next._camera_passes=timing.camera_passes
	if next._objective is ContractObjective:
		if not next._objective.advance_wingmen(delta_ms):reject(next._objective.error);return null
	if _mission_context!=null and _mission_context.advances_campaign():
		var timing: Dictionary=next._briefing.snapshot()
		if not next._encounter.sample_mission_clock(int(timing.world_elapsed_ms),int(timing.hud_elapsed_ms)):reject(next._encounter.error);return null
	elif _objective is ContractObjective or _entry.has("bakka_context"):
		var timing: Dictionary=next._briefing.snapshot()
		var accepted: bool=next._encounter.sample_bakka_clock(int(timing.world_elapsed_ms),int(timing.hud_elapsed_ms)) if _entry.has("bakka_context") else next._encounter.sample_contract_clock(int(timing.world_elapsed_ms),int(timing.hud_elapsed_ms))
		if not accepted:reject(next._encounter.error);return null
	# The world traffic clock precedes player and weapon phases.
	if next._encounter!=null:
		var world_logic: Dictionary=next._encounter.evaluate_world_logic(delta_ms,next._random,_pose,next._cargo.quantity(Drive.Definitions.ENERGY_ITEM))
		if world_logic.is_empty():reject(next._encounter.error);return null
		next._encounter=world_logic.encounter;next._random=world_logic.random_state
	var cues: Dictionary=next._briefing.snapshot()
	# The player moves with the preceding angular response. Input is consumed
	# after the entry controller; release may enable it on this very frame.
	# Modal UI owns input as soon as its panel opens. Player/camera logic may
	# already have elapsed, while the later world phase then receives zero.
	var alive: bool=_player.snapshot().vitals.hull>0
	var player_updates: bool=(not death_active() or _death.player_updates_enabled()) and not (_alioth!=null and _alioth.snapshot().player_update_suspended and not death_active())
	var player_tail:=player_updates
	if not next._booster.advance(delta_ms if player_updates else 0):reject(next._booster.error);return null
	if not alive or cinematic_input_blocked() or local_departing() or gate_departing():
		if not next._booster.cancel():reject(next._booster.error);return null
	if player_updates and next._fast_forward!=null:
		next._near_target=false
		if not next._camera.refresh_player_response(relative_mouse_capture,next._autopilot.snapshot().response_factor):reject(next._camera.error);return null
	var manual: bool=alive and cues.entry_released and not cues.dialogue.visible and not local_departing() and not cinematic_input_blocked()
	var turret_active: bool=_encounter!=null and _encounter.turret_active()
	if turret_active:
		next._encounter=next._encounter.advance_turret(commands if manual else Vector2.ZERO,delta_ms,turret_inverted)
		if not manual or (_autopilot!=null and _autopilot.snapshot().active) or (_approach!=null and _approach.snapshot().phase!="idle"):
			next._encounter=next._encounter.set_turret_active(false);turret_active=false
		else:commands=Vector2.ZERO;strafe=0.0
	# A live guided missile takes the stick; the ship keeps its motion.
	var guided_missile: bool=next._encounter!=null and next._encounter.guided_missile_active()
	if guided_missile:
		if not alive or local_departing() or cinematic_input_blocked():
			next._encounter=next._encounter.discard_guided_missile();guided_missile=false
		else:
			next._encounter=next._encounter.steer_guided_missile(commands if manual else Vector2.ZERO)
			commands=Vector2.ZERO;strafe=0.0
	var active_throttle: float=(throttle if _briefing.snapshot().entry_released else 1.0) if alive else _throttle
	if convoy_input_blocked() or story_dock_held():active_throttle=0.0
	var ordinary_motion:=false
	var visual_response: Vector2=next._pilot.angular_units
	# Proximity uses the cached position; physical hull contact can also set this
	# flag after movement, before the arrival query checks the current boxes.
	if not _return_rules.is_empty() and _collision_enabled and _player.snapshot().active:
		var length:=Autopilot.single(sqrt(Vectors.dot(_pose.origin,_pose.origin)))
		if not is_finite(length):reject("Station contact exceeds source coordinates");return null
		next._station_contact=length<float(_return_rules.contact_radius)
	if not player_updates:
		pass
	elif drive_departing():
		pass
	elif gate_departing():
		if not next._gate_transit.advance(delta_ms):reject(next._gate_transit.error);return null
		next._pose=next._gate_transit.snapshot().player_pose;next._model_basis=Basis.IDENTITY;next._statistics_pose=next._pose
		next._shot.eye=next._gate_transit.snapshot().camera_position
	elif local_departing():
		# Ordinary launch bypasses steering and moves along the retained root
		# forward axis. HUD acquisition began it at the end of the prior frame.
		var speed:=float(_local_travel.snapshot().launch_speed_per_ms)
		next._pose.origin=Vectors.added(_pose.origin,Vectors.scaled(Vectors.normalized(_pose.basis.z),Autopilot.single(float(delta_ms)*speed)))
		next._statistics_pose=next._pose*Transform3D(_model_basis,Vector3.ZERO)
		if not next._local_travel.advance_launch(delta_ms):reject(next._local_travel.error);return null
	elif _mining!=null and _mining.has_active_drill():
		var operation: Dictionary=next._mining.evaluate(next._scenery,next._cargo,delta_ms,next._random,drill_command,false,false)
		if operation.is_empty():reject(next._mining.error);return null
		next._mining=operation.session;next._scenery=operation.scenery;next._cargo=operation.cargo;next._random=operation.random_state
		if next._equipment!=null and not next._equipment.retain_flight_cargo(next._cargo.snapshot()):reject(next._equipment.error);return null
		var mining_events: Array=next._mining.snapshot().events
		next._queue_mining_audio(mining_events)
		if not next._queue_notice_events(mining_events):reject(next.error);return null
		if operation.release_approach:
			if not next._retain_mining_extraction(next._mining.snapshot().extraction):reject(next.error);return null
			if not next._release_mining_approach():reject(next.error);return null
			ordinary_motion=operation.resume_motion and not convoy_input_blocked()
			player_tail=operation.outcome!="target_unavailable"
			# Automatic completion clears the movement gate within the player
			# update. Its remaining ordinary movement uses retained throttle.
			active_throttle=next._throttle
	elif _approach!=null and _approach.snapshot().phase!="idle":
		var index: int=_approach.snapshot().object_index
		if not next._approach.advance(next._scenery,delta_ms,false,next._booster.speed_multiplier()):reject(next._approach.error);return null
		var sample: Dictionary=next._approach.last_guidance_sample()
		if next._fast_forward!=null and not sample.is_empty():next._near_target=sample.near_target
		if next._autopilot!=null and not sample.is_empty():
			if not next._autopilot.observe_mining_guidance(sample.before,sample.after):reject(next._autopilot.error);return null
		var approach: Dictionary=next._approach.snapshot()
		if not approach.engine_visible and _approach.snapshot().engine_visible:next._booster.finish_soon()
		next._queue_mining_audio(approach.events)
		if next._engine_particles!=null and (approach.phase=="idle" or approach.engine_visible!=_approach.snapshot().engine_visible):
			if not next._engine_particles.set_engine_enabled(approach.engine_visible):reject(next._engine_particles.error);return null
		next._pose=approach.player_pose;next._model_basis=approach.model_basis;next._throttle=approach.throttle
		if approach.camera_update_enabled!=_approach.snapshot().camera_update_enabled:next._camera_follow_enabled=approach.camera_update_enabled
		if not next._scenery.set_spin_enabled(index,approach.spin_enabled):reject(next._scenery.error);return null
		if approach.phase=="idle":
			next._targeting.clear_selection();next._camera_follow_enabled=true;player_tail=false
		if approach.phase=="drill_required" and next._mining!=null:
			if not next._mining.begin(next._approach,next._scenery,next._cargo):reject(next._mining.error);return null
			if next._mining.has_failure_instruction():next._retain_mining_hint(next._mining.failure_instruction_shown())
	elif convoy_input_blocked():
		# Source capture gates ordinary flight through the movement flag. The
		# earlier approach/drill branch still runs with its retained command.
		pass
	elif (_alioth!=null and _alioth.snapshot().input_blocked) or (_sahi!=null and _sahi.snapshot().scripted_coast) or (_probe!=null and _probe.snapshot().scripted_coast):
		next._pose=next._pilot.coast(_pose,_throttle,float(delta_ms)/1000.0)
		if not next._pilot.error.is_empty():reject(next._pilot.error);return null
		next._statistics_pose=next._pose*Transform3D(_model_basis,Vector3.ZERO)
		if next._autopilot!=null and not next._autopilot.observe_scripted_pose(next._pose):reject(next._autopilot.error);return null
	elif gate_coasting():
		var speed: float=_gate_transit.snapshot().speed
		next._pose.origin=Vectors.added(_pose.origin,Vectors.scaled(Vectors.normalized(_pose.basis.z),float(delta_ms)*speed))
		next._statistics_pose=next._pose*Transform3D(_model_basis,Vector3.ZERO)
		if not next._autopilot.observe_scripted_pose(next._pose):reject(next._autopilot.error);return null
	elif _autopilot!=null and _autopilot.snapshot().active:
		if _local_travel!=null and _autopilot.snapshot().target_kind=="planet":
			var destination: Variant=_local_travel.target_position(int(_autopilot.snapshot().station_id))
			if destination==null or not next._autopilot.refresh_planet_position(destination):reject(_local_travel.error+next._autopilot.error);return null
		if not next._autopilot.advance(delta_ms,next._pilot.angular_units.x,active_throttle,false,next._booster.speed_multiplier()):reject(next._autopilot.error);return null
		var guide: Dictionary=next._autopilot.snapshot()
		if next._engine_particles!=null and next._engine_particles.engine_enabled()!=(guide.throttle>0.0) and not next._engine_particles.set_engine_enabled(guide.throttle>0.0):reject(next._engine_particles.error);return null
		if next._fast_forward!=null:next._near_target=guide.near_target
		next._pose=guide.player_pose;next._model_basis=guide.model_basis;next._throttle=guide.throttle
		next._statistics_pose=next._pose*Transform3D(next._model_basis,Vector3.ZERO)
		if not next._pilot.accept_visual_response(guide.angular_units,float(delta_ms)/1000.0,_preceding_commands):reject(next._pilot.error);return null
		next._preceding_commands=Vector2.ZERO
	else:
		ordinary_motion=true
	if ordinary_motion:
		if not next._engine_audio.before_ordinary_motion():reject(next._engine_audio.error);return null
		if next._engine_particles!=null and next._engine_particles.engine_enabled()!=(active_throttle>0.0) and not next._engine_particles.set_engine_enabled(active_throttle>0.0):reject(next._engine_particles.error);return null
		next._pose=next._pilot.advance(_pose,commands if manual else Vector2.ZERO,active_throttle,float(delta_ms)/1000.0,strafe if manual else 0.0,next._booster.speed_multiplier(),relative_mouse_capture)
		if not next._pilot.error.is_empty():reject(next._pilot.error);return null
		next._statistics_pose=next._pose*Transform3D(_model_basis,Vector3.ZERO)
		next._model_basis=Basis.IDENTITY;next._throttle=active_throttle
		if next._autopilot!=null:
			if not next._autopilot.observe_manual(next._pose,visual_response):reject(next._autopilot.error);return null
			next._model_basis=next._autopilot.snapshot().model_basis
			next._preceding_commands=commands if manual else Vector2.ZERO
	if next._drive!=null and not next.death_active():
		if not next._advance_drive(delta_ms):reject(next.error);return null
	if _gate_transit!=null and not gate_departing():
		if not next._gate_transit.advance(delta_ms):reject(next._gate_transit.error);return null
	elif _gate_animation!=null:
		if not next._gate_animation.advance(delta_ms):reject(next._gate_animation.error);return null
	# Physical response reads the current root after all movement/approach work.
	# The earlier station proximity fallback intentionally keeps its old sample.
	if player_updates and not next._advance_physical_contacts():reject(next.error);return null
	# Aim is retained during player motion, using the preceding camera. Targets
	# are projected only after this frame's scenery and camera have advanced.
	if player_updates:
		if player_tail and next._route!=null:
			# The source caches this root position at the start of its player pass.
			var arrival: Dictionary=next._route.advance(_pose.origin)
			if arrival.is_empty():reject(next._route.error);return null
			if arrival.arrived and next._notices!=null and _navigation.has("progress_notice"):
				if not next._notices.enqueue(int(_navigation.progress_notice.source_id)):reject(next._notices.error);return null
		if next._aim!=null and not next._aim.advance(next._encounter.turret_aim_pose(next._pose) if next._encounter!=null else next._pose,_camera.snapshot().pose,viewport,commands,relative_mouse_capture and manual and not turret_active):reject(next._aim.error);return null
		if next._player.advance_recharge(delta_ms).is_empty() or next._player.advance_repair(delta_ms).is_empty() or not next._player.advance_cloak(delta_ms,next._notices):reject(next._player.error);return null
		if not next._advance_tractor(delta_ms):reject(next.error);return null
		var portal_contact: RefCounted=next._sahi if next._sahi!=null else next._void_portal
		if portal_contact!=null and not next._apply_portal_contact(portal_contact):reject(next.error);return null
	if death_active():
		var destruction: Dictionary=next._death.advance(delta_ms,next._pose,next._random,false,next._statistics_pose,player_tail)
		if destruction.is_empty():reject(next._death.error);return null
		next._random=destruction.random_state;next._model_basis=destruction.state.rendered_model_basis
		next._audio_frame.player_tail=destruction.events.duplicate(true)
		if next._particles!=null and not next._particles.apply_player_tail(next._death):reject(next._particles.error);return null
		if next._approach!=null and next._approach.snapshot().phase!="idle":
			if not next._approach.accept_model_basis(next._model_basis):reject(next._approach.error);return null
	# Existing projectile slots contact the current player before advancing.
	# The later mission cue must not move their retained shooter/launch poses.
	if next._encounter!=null:
		var guidance_id: int=-1 if next._scanner==null else next._scanner.guidance_target_id(not next._camera.orbit_snapshot().get("enabled",false))
		var weapon_pass: Dictionary=next._encounter.evaluate_weapons(next._player,next._pose,delta_ms,next._scenery if _equipment!=null else null,next._random,true,next._radio==null or not next._radio.snapshot().get("visible",false),guidance_id,next._wingmen)
		if weapon_pass.is_empty():reject(next._encounter.error);return null
		next._encounter=weapon_pass.encounter;next._player=weapon_pass.player
		if weapon_pass.has("wingmen"):next._wingmen=weapon_pass.wingmen
		if weapon_pass.has("scenery"):next._scenery=weapon_pass.scenery
		if weapon_pass.has("random_state"):next._random=weapon_pass.random_state
	if next._wingmen!=null:
		var companion_pass: Dictionary=next._wingmen.advance_weapons(delta_ms,next._encounter)
		if companion_pass.is_empty():reject(next._wingmen.error);return null
		next._encounter=companion_pass.encounter
	if not next._engine_audio.follow_player(next._statistics_pose,int(next._player.snapshot().vitals.hull),delta_ms):reject(next._engine_audio.error);return null
	if next._player.snapshot().vitals.hull<=0 and next._death==null:
		if not next._booster.cancel():reject(next._booster.error);return null
		# Any lethal damage belongs to the same death boundary, including scenery
		# contacts in content that has no supported destruction presentation.
		next._unsupported_boundary="player_death_required"
		return next
	# Geometry managers run in the early weapon phase, using preceding NPC
	# roots and renderer reference. Scenery lifecycle belongs to the later pass.
	if next._engine_particles!=null and not next._engine_particles.advance(next._statistics_pose,delta_ms,next._booster.envelope()):reject(next._engine_particles.error);return null
	if next._particles!=null:
		if next._encounter!=null and not next._particles.apply_weapon_impacts(next._encounter.secondary_impacts()):reject(next._particles.error);return null
		if not next._particles.advance(next._pose,delta_ms):reject(next._particles.error);return null
	var positions:={"player":next._pose.origin}
	if next._encounter!=null:
		for actor in next._encounter.combat_snapshot().actors:
			if actor.get("population_group") in ["debris","static"]:continue
			positions[actor.actor_id]=actor.get("body_pose",actor.pose).origin
	if not next._detail.update(delta_ms,positions,_reference,1.0,false):reject(next._detail.error);return null
	if next._wingmen!=null and not next._wingmen.advance_detail(delta_ms,_reference):reject(next._wingmen.error);return null
	if next._death!=null and next._player.snapshot().vitals.hull<=0 and not next.death_active():
		var secondaries: RefCounted=next._encounter.secondary_owner() if next._encounter!=null else null
		if not next._death.start(next._player,next._pose,Vector3.ZERO,next._camera.snapshot().pose,int(next._objective.snapshot().campaign_cursor),next._model_basis,next._statistics_pose,secondaries):reject(next._death.error);return null
		if next._engine_particles!=null and not next._engine_particles.set_engine_enabled(false):reject(next._engine_particles.error);return null
		next._camera_follow_enabled=false
		if not next._player.set_permissions(false,next._player.snapshot().damage_allowed):reject(next._player.error);return null
		# Current commands were prepared before contact in the ordinary native
		# pilot owner. The source's later input gate now omits that preparation.
		if ordinary_motion:
			if not next._pilot.accept_visual_response(visual_response,float(delta_ms)/1000.0):reject(next._pilot.error);return null
			next._preceding_commands=Vector2.ZERO
	if next.death_active():
		if not next._booster.cancel():reject(next._booster.error);return null
		# The later poll follows every accepted destruction pass, including
		# breakup; its emitted cue restores emission without restoring drawing.
		if next._particles!=null and not next._particles.apply_player_poll(next._death):reject(next._particles.error);return null
		next._audio_frame.player_poll=next._death.snapshot().events
	if next.sahi_arrival_required() or next.void_return_required():
		if not next._objective.observe_combat(next._encounter):reject(next._objective.error);return null
		return next
	if not next.prepare_gate_arrival().is_empty():
		if not next._objective.observe_combat(next._encounter):reject(next._objective.error);return null
		return next
	if next._local_travel!=null and next._local_travel.snapshot().phase=="arrival_required" and not next.death_active():
		if not next._objective.observe_combat(next._encounter):reject(next._objective.error);return null
		return next
	if not next._return_rules.is_empty() and next._player.snapshot().vitals.hull>0:
		if not next._evaluate_station_return():reject(next.error);return null
		if not next._station_packet.is_empty():
			# Station transition exits before mission/camera logic and the later
			# NPC/scenery pass. Preserve current player pools and weapon contacts.
			return next
	if next._probe!=null and not next.death_active():
		if not next._advance_probe_sequence(delta_ms):reject(next.error);return null
	# The failure hint precedes the source's mission poll and camera/input pass.
	# The timed failure notice remains queued independently behind this modal.
	var instruction_opened:=false
	if next._mining!=null and next._mining.failure_instruction_pending() and next._player.snapshot().vitals.hull>0 and not next.death_active():
		var cursor: int=next._objective.snapshot().campaign_cursor if next._objective!=null else next._briefing.snapshot().campaign_cursor
		if next._mining.failure_instruction_due(cursor):
			if not next._briefing.show_mining_failure_instruction() or not next._mining.mark_failure_instruction_shown(cursor):reject(next._briefing.error+next._mining.error);return null
			next._retain_mining_hint(true);instruction_opened=true
	var completion_opened:=false
	if not instruction_opened and _mission_context!=null and _mission_context.advances_campaign():
		var radio_active: bool=next._radio!=null and next._radio.snapshot().get("visible",false)
		if not next._objective.poll_mission(next._encounter,radio_active,next._briefing.mission_poll_due(),not next.death_active() and next._player.snapshot().vitals.hull>0):reject(next._objective.error);return null
		completion_opened=next._objective.snapshot().dialogue.visible
	elif not instruction_opened and _entry.has("bakka_context"):
		var radio_active: bool=next._radio!=null and next._radio.snapshot().get("visible",false)
		if not next._objective.poll_bakka(next._encounter,radio_active,next._briefing.mission_poll_due(),not next.death_active() and next._player.snapshot().vitals.hull>0):reject(next._objective.error);return null
		completion_opened=next._objective.snapshot().dialogue.visible
	elif not instruction_opened and next._objective is ContractObjective:
		var radio_active: bool=next._radio!=null and next._radio.snapshot().get("visible",false)
		var before_cursor: int=next._objective.snapshot().campaign_cursor
		var radio_finished: Array=next._radio.snapshot().get("finished",[]) if next._radio!=null else []
		if not next._objective.poll_contract(next._cargo,next._scenery,next._encounter,next._player.snapshot().vitals.hull>0,radio_active,next._briefing.mission_poll_due(),radio_finished,{"drive_started":next._drive!=null and next._drive.snapshot().get("phase","ready")!="ready"}):reject(next._objective.error);return null
		var story_state: Dictionary=next._objective.snapshot()
		if story_state.campaign_cursor!=before_cursor:
			# A story flight has moved on in space: navigation and docking follow it.
			if next._local_travel==null or not next._local_travel.rebase_story_flight(_story_bindings,story_state.campaign_cursor,story_state.mission):reject("Story navigation: "+str(next._local_travel.error if next._local_travel!=null else "missing travel"));return null
			next._return_rules={} if next._station==null or next._station_hidden else FreeFlight.docking(_story_bindings,int(_entry.location.station_id),story_state.campaign_cursor)
			if next._drive_arrival is Context:next._drive_arrival=next._drive_arrival.rebased_void_story(story_state.campaign_cursor)
			var jump: Dictionary=load("res://src/content/valkyrie_flight_definitions.gd").story_jump(story_state.campaign_cursor)
			if not jump.is_empty():next._story_jump=int(jump.destination)
			if next._system_navigation!=null and _story_catalogues!=null and not next._refresh_story_navigation(story_state):return null
			var disarm: Array=_mission_context.recipe().get("disarm_on_advance",[]) if _mission_context!=null else []
			if not disarm.is_empty() and not next._encounter.disarm_story_actors(int(disarm[0]),int(disarm[1])):reject(next._encounter.error);return null
		var visit_clock: Dictionary=next._briefing.snapshot()
		if next._rescue!=null:
			if not next._objective.poll_campaign_result(next._encounter,next._radio,next._rescue,next._briefing.mission_poll_due() and not next.death_active() and not next.contract_result_pending()):reject(next._objective.error);return null
		elif not next._objective.poll_visit(int(visit_clock.world_elapsed_ms),int(visit_clock.hud_elapsed_ms),not next._briefing.mission_poll_due() or next.death_active() or next.contract_result_pending()):reject(next._objective.error);return null
		completion_opened=next.contract_result_pending() or next._objective.snapshot().dialogue.visible
	elif not instruction_opened and next._objective!=null and next._briefing.mission_poll_due():
		var accepted: bool=next._objective.poll_probe(next._probe,next._encounter,int(next._player.snapshot().vitals.hull)) if next._probe!=null else next._objective.poll(next._cargo,next._scenery,next._player.snapshot().vitals.hull>0,next._encounter,next._radio,int(next._briefing.snapshot().world_elapsed_ms))
		if not accepted:reject(next._objective.error);return null
		completion_opened=next._objective.snapshot().dialogue.visible
	next._briefing.finish_mission_poll(completion_opened or instruction_opened)
	if completion_opened or instruction_opened:
		if not next._booster.cancel():reject(next._booster.error);return null
		if ordinary_motion and next._autopilot!=null:
			# Ordinary movement already cleared its input flags. Its rendered
			# response settles, but opening a modal bypasses late commands.
			if not next._pilot.accept_visual_response(visual_response,float(delta_ms)/1000.0):reject(next._pilot.error);return null
			next._preceding_commands=Vector2.ZERO
		if completion_opened:next._briefing.retire_dialogue()
		if next.contract_result_pending():return next
		# Completion bypasses controller/camera/input; the later world phase
		# still visits its owners with zero time after the modal flag is set.
		if not next._advance_world(0,_reference):reject(next.error);return null
		if not next._observe_radio():reject(next.error);return null
		return next
	if next._rescue!=null and not next.death_active() and not cues.dialogue.visible:
		var sequence: Dictionary=next._encounter.evaluate_kappa_sequence(next._rescue,next._radio)
		if sequence.is_empty():reject(next._encounter.error);return null
		next._encounter=sequence.encounter;next._rescue=sequence.rescue
	if next._alioth!=null and not next.death_active() and not cues.dialogue.visible:
		if not next._advance_alioth(delta_ms):reject(next.error);return null
		if ordinary_motion and next.cinematic_input_blocked():
			if not next._pilot.accept_visual_response(visual_response,float(delta_ms)/1000.0):reject(next._pilot.error);return null
			next._preceding_commands=Vector2.ZERO
	if next._convoy!=null and not next.death_active() and not cues.dialogue.visible:
		if not next._advance_convoy(delta_ms):reject(next.error);return null
		if next.convoy_arrival_required():
			if not next._booster.cancel():reject(next._booster.error);return null
			return next
	if next._sahi!=null and not next.death_active() and not cues.dialogue.visible:
		if not next._advance_sahi(delta_ms):reject(next.error);return null
		if ordinary_motion and next.cinematic_input_blocked():
			if not next._pilot.accept_visual_response(visual_response,float(delta_ms)/1000.0):reject(next._pilot.error);return null
			next._preceding_commands=Vector2.ZERO
	if cues.entry_released and not next.local_departing() and not next.cinematic_input_blocked():
		next._shot.mode="follow"
		next._collision_enabled=true
		if not next.death_active() and not next._player.set_permissions(true,true):reject(next._player.error);return null
	if next._encounter!=null and _equipment==null:
		var cued: RefCounted=next._encounter.evaluate_cue(next._player,next._pose,int(next._objective.snapshot().campaign_cursor))
		if cued==null:reject(next._encounter.error);return null
		next._encounter=cued
	var scene:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"player_pose":next._pose}
	if next.drive_departing():
		scene.player_pose=next._drive.snapshot().effect.pose
		if not next._camera.update(0,next._shot,scene,next._shot):reject(next._camera.error);return null
	elif next.gate_departing():
		# The original translation setter forces a positive fixed-eye refresh.
		# Rebuild the view directly, without advancing a synthetic camera clock.
		if not next._camera.update(0,next._shot,scene,next._shot):reject(next._camera.error);return null
	if next._camera_follow_enabled and not next.cinematic_input_blocked():
		if not next._advance_follow_camera(next._camera_ms,scene,next._camera_passes):reject(next.error);return null
	if turret_active:
		if not next._encounter.present_turret_camera(next._camera,next._pose) or not next._aim.advance(next._encounter.turret_aim_pose(next._pose),next._camera.snapshot().pose,viewport):reject(next._camera.error+next._aim.error);return null
	if next._encounter!=null and next._encounter.guided_missile_active():
		if not next._encounter.present_guided_camera(next._camera):reject(next._camera.error);return null
	if next.death_active() and not next._death.sample_camera(next._camera.snapshot().pose,next._camera_follow_enabled):reject(next._death.error);return null
	if next._mining!=null and next._mining.has_active_drill() and next._player.snapshot().vitals.hull>0 and not cues.dialogue.visible and not next.cinematic_input_blocked():
		if not next._mining.set_command(drill_command):reject(next._mining.error);return null
	if next._equipment!=null:
		var fired: Dictionary=next._encounter.evaluate_primary_fire(next._player,next._pose,primary_fire or (secondary_fire and turret_active),cues.entry_released and not cues.dialogue.visible and not next.death_active() and not next.local_departing() and not next.cinematic_input_blocked(),next._random,[] if next._scanner==null else next._scanner.weapon_target_ids(),delta_ms)
		if fired.is_empty():reject(next._encounter.error);return null
		next._encounter=fired.encounter;next._random=fired.random_state
		if next._encounter.has_secondaries():
			var enabled: bool=cues.entry_released and not cues.dialogue.visible and not next.death_active() and not next.local_departing() and not next.cinematic_input_blocked()
			if not next._apply_secondary_input(secondary_fire and not turret_active,enabled):reject(next.error);return null
	if next.cinematic_input_blocked():
		if not next._booster.cancel():reject(next._booster.error);return null
	if cloak_requested:
		var activation: Dictionary=next._player.evaluate_cloak_request(next._cargo,next.cloak_input_permitted())
		if activation.is_empty():reject(next._player.error);return null
		next._player=activation.player;next._cargo=activation.cargo
		if activation.started:
			next._equipment=next._equipment.fork()
			if not next._equipment.retain_flight_cargo(next._cargo.snapshot()):reject(next._equipment.error);return null
			if not next._notices.enqueue_energy_spent(activation.consumed):reject(next._notices.error);return null
	if boost_requested and not guided_missile and next.booster_input_permitted():
		var activation: int=next._booster.snapshot().activation
		if not next._booster.request_start():reject(next._booster.error);return null
		if next._booster.snapshot().activation!=activation:
			next._throttle=1.0
			if next._approach!=null and next._approach.snapshot().phase=="approach" and not next._approach.set_throttle(1.0):reject(next._approach.error);return null
	if delta_ms>0:next._reference=next._camera.snapshot().eye
	if not next._advance_world(0 if cues.dialogue.visible else delta_ms,_reference):reject(next.error);return null
	if next._gate_transit!=null and not next.gate_departing() and not next.death_active() and cues.entry_released:
		var guide: Dictionary=next._autopilot.snapshot()
		var target_is_gate: bool=guide.active and guide.target_kind=="gate"
		if not next._gate_transit.observe_contact(next._pose,next._gate_cruise_speed*next._throttle,guide.active,target_is_gate,{"kind":-1,"completed":true}):reject(next._gate_transit.error);return null
		if next.gate_modal() and not next._autopilot.clear_target():reject(next._autopilot.error);return null
		if next.gate_modal() and not next._booster.cancel():reject(next._booster.error);return null
	if next._local_travel!=null:
		var selected_planet:=-1
		if next._autopilot.snapshot().active and next._autopilot.snapshot().target_kind=="planet":selected_planet=int(next._autopilot.snapshot().station_id)
		var planet_hud: bool=not next.death_active() and cues.entry_released and not cues.dialogue.visible and not next.local_departing() and not next.cinematic_input_blocked()
		var mining_selected: bool=next._targeting!=null and next._targeting.selected_object_index()>=0
		if not next._local_travel.sample_frame(next._camera.snapshot().pose,next._aim.snapshot(),delta_ms,selected_planet,planet_hud,mining_selected):reject(next._local_travel.error);return null
		if not local_departing() and next.local_departing():
			if not next._begin_local_departure():reject(next.error);return null
	if next._targeting!=null:
		var hud_enabled: bool=not next.death_active() and cues.entry_released and not cues.dialogue.visible and not next.cinematic_input_blocked()
		var contact: bool=next._equipment!=null and next._encounter.primary_npc_contact()
		if not next._aim.sample_feedback(contact,delta_ms,hud_enabled):reject(next._aim.error);return null
		var hud_camera: Transform3D=next._camera.snapshot().pose
		var hud_aim: Dictionary=next._aim.snapshot()
		if not next._advance_npc_hud(delta_ms,hud_enabled,hud_camera,hud_aim):reject(next.error);return null
		if not next._advance_scenery_hud(delta_ms,hud_enabled,hud_camera,hud_aim):reject(next.error);return null
		if next._station_targeting!=null and not next._advance_station_targeting(delta_ms,hud_enabled,primary_fire,hud_camera,hud_aim):reject(next.error);return null
		if next._void_targeting!=null and not next._advance_void_targeting(delta_ms,hud_enabled,primary_fire,hud_camera,hud_aim):reject(next.error);return null
	if next._notices!=null:
		if not next._notices.advance(delta_ms,next._mining!=null and next._mining.has_active_drill()):reject(next._notices.error);return null
	if not next._observe_radio():reject(next.error);return null
	if not next.death_active() and cues.entry_released and next._volatile_carried():
		var rules: Dictionary=Worlds.VOLATILE_GOODS
		if next._booster.active():
			var boost_id:=int(next._booster.snapshot().get("item_id",-1))
			next._instability=minf(1.0,next._instability+float(rules.boost_rates.get(boost_id,rules.boost_rate))*float(delta_ms)/1000.0)
		# Sharp steering shakes it too: twice the largest change this frame.
		var change: Vector2=(commands-next._volatile_steer).abs()
		next._instability=minf(1.0,next._instability+2.0*maxf(change.x,change.y))
		next._volatile_steer=commands
		if next._instability>=1.0 and not next._player.destroy_hull():reject(next._player.error);return null
	elif not next._volatile_carried():next._instability=0.0;next._volatile_steer=Vector2.ZERO
	if next._gamma_rate>0.0 and not next.death_active() and cues.entry_released and not next.local_departing() and not next.drive_departing():
		var hit: Dictionary=next._player.drain_gamma(next._gamma_rate*float(delta_ms)/1000.0,float(Worlds.GAMMA_WARNING))
		if hit.is_empty():reject(next._player.error);return null
		if hit.warned and not next._notices.enqueue(Worlds.GAMMA_NOTICE):reject(next._notices.error);return null
	if next._fast_forward!=null:
		var radar_visible: bool=not next.death_active() and cues.entry_released and not cues.dialogue.visible and not next.cinematic_input_blocked() and not next.local_departing()
		if not next._fast_forward.publish_radar([] if next._encounter==null else next._encounter.combat_snapshot().actors,radar_visible,current_music_id):reject(next._fast_forward.error);return null
		if next._music!=null:
			var context: Dictionary=next._music_context.merged(next._fast_forward.radar_music_context())
			var selection: Dictionary=next._music.prepare_for_context(current_music_id,next._fast_forward.battle_count(),next._music_faction,radar_visible,context)
			if selection.is_empty():reject(next._music.error);return null
			next._flight_music={"operations":selection.operations}
	if next._pending_destination>=0 and not next._navigation_applied and cues.entry_released and not next.dialogue_visible() and not next.death_active() and not next.cinematic_input_blocked():
		var guided: RefCounted=next.start_drive(next._pending_destination) if next._queued_drive else next.select_map_destination(next._pending_destination)
		if guided==null:reject(next.error);return null
		next=guided
	# A move inside this system goes by ordinary local travel (91: Valpatro to
	# Tadram); a jump the drive cannot make otherwise is left to the player.
	if next._story_jump>=0 and next._drive!=null and next._drive.ready() and next.drive_quote(next._story_jump).get("mode","local")=="local":
		if next._local_travel!=null and next._local_travel.supports_destination(next._story_jump):
			if cues.entry_released and not next.dialogue_visible() and not next.death_active() and not next.cinematic_input_blocked() and not next.local_departing():
				var travel: RefCounted=next.select_planet(next._story_jump)
				if travel==null:reject(next.error);return null
				next=travel;next._story_jump=-2
		else:next._story_jump=-2
	if next._story_jump>-2 and cues.entry_released and not next.dialogue_visible() and not next.death_active() and not next.cinematic_input_blocked() and next.drive_available() and next._drive.snapshot().get("phase","")=="ready":
		var jumped: RefCounted=next.start_drive(next._story_jump,true)
		if jumped==null:reject(next.error);return null
		next=jumped;next._story_jump=-2
	if player_updates and not next._engine_audio.sample_commands(commands if manual and not turret_active else Vector2.ZERO):reject(next._engine_audio.error);return null
	return next

## The ordinary-flight vibration write replaces earlier wrapper camera fields
## before the controller/follow pass. Do not replay retained EMP requests here:
## doing so invents a later setter and advances the shared random stream again.
## Explicit camera effects remain on the shared rig for their own verified phase;
## independent ordinary damage/boost vibration is not supplied by EMP ownership.
func _advance_physical_contacts() -> bool:
	if _physical_contacts==null:return true
	var selected: int=-1
	if _approach!=null:
		var approach: Dictionary=_approach.snapshot()
		if approach.phase!="idle":selected=int(approach.object_index)
	var plan: Dictionary=_physical_contacts.plan(_player.collision_context(_pose),_scenery.read_snapshot().get("bodies",{}),_collision_enabled,selected)
	if plan.is_empty():return reject(_physical_contacts.error)
	if not _scenery.apply_physical_contacts(plan.operations):return reject(_scenery.error)
	for operation in plan.operations:
		if operation.kind=="asteroid" and _player.normal_hit(operation.player_damage).is_empty():return reject(_player.error)
		# Projection puts the ship on a strict volume boundary. Retain the actual
		# contact so a selected station can dock after that point leaves its box.
		if operation.kind=="station" and operation.center_after!=operation.center_before:_station_contact=true
	if plan.center_after!=plan.center_before:
		_pose.origin=plan.center_after
		_statistics_pose.origin=plan.center_after
		if _autopilot!=null and not _autopilot.observe_scripted_pose(_pose):return reject(_autopilot.error)
	return true

func _advance_follow_camera(delta_ms: int,scene: Dictionary,passes:=1) -> bool:
	error=""
	for pass_index in passes:
		if not _camera.update(delta_ms,_shot,scene):return reject(_camera.error)
	return true

## HUD follows the player phase. Publish only acquisition here; keep the earlier
## player sample intact for the beam and one-shot/loop audio transaction.
func _advance_npc_hud(delta_ms: int,enabled: bool,camera: Transform3D,aim: Dictionary) -> bool:
	if _scanner==null:return true if _tractor==null else reject("A fitted tractor needs its native NPC scanner")
	var combat: Dictionary;var ordinary_candidate:=-2;var projection: RefCounted
	if _tractor!=null:
		projection=_scanner.prepare_projection(aim.viewport_size)
		if projection==null:return reject(_scanner.error)
		var point: Vector3=aim.point
		var context:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,
			"enabled":enabled,"guidance_active":_route!=null,"alternate_operation_active":false,
			"mining_approach_active":_approach!=null and _approach.snapshot().phase!="idle",
			"alternate_approach_active":false,"autopilot":_autopilot!=null and _autopilot.snapshot().active,
			"other_target_selected":_targeting!=null and _targeting.selected_object_index()>=0,
			"ordinary_scan_enabled":true,"ordinary_scan_blocked":false,
			"aim_pixels":Vector2(point.x,point.y),"viewport_size":aim.viewport_size}
		var acquired: Dictionary=_encounter.acquire_cargo_target(_tractor,delta_ms,projection,camera,context)
		if acquired.is_empty():return reject(_encounter.error)
		_tractor=acquired.tractor;combat=acquired.combat
		ordinary_candidate=int(_tractor.snapshot().frame.ordinary_candidate_actor_id)
	else:combat=_encounter.combat_snapshot()
	if not _scanner.advance(combat,_pose,camera,aim,delta_ms,enabled,ordinary_candidate,projection):return reject(_scanner.error)
	_scanner_events=_scanner.sound_events()
	if _notices!=null and not _notices.enqueue_scanner(_scanner.snapshot().events,_encounter):return reject(_notices.error)
	return true

func _advance_tractor(delta_ms: int) -> bool:
	if _tractor==null:return true
	var player:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,
		"pose":_pose,"autopilot":_autopilot!=null and _autopilot.snapshot().active}
	var operation: Dictionary=_encounter.evaluate_cargo_recovery(_tractor,_cargo,delta_ms,player,_scenery)
	if operation.is_empty():return reject(_encounter.error)
	_encounter=operation.encounter;_tractor=operation.tractor;_cargo=operation.cargo
	if operation.has("scenery"):_scenery=operation.scenery
	# HUD acquisition replaces the tractor's observation later in this frame.
	# Preserve this one player-phase sample for presentation and sound.
	_tractor_frame=operation.frame
	if _tractor_frame.phase=="pickup" and _equipment!=null and not _equipment.retain_flight_cargo(_cargo.snapshot()):return reject(_equipment.error)
	return true

func _advance_scenery_hud(delta_ms: int,enabled: bool,camera: Transform3D,aim: Dictionary) -> bool:
	var approaching: bool=_approach!=null and _approach.snapshot().phase!="idle"
	var suspended: bool=_autopilot!=null and _autopilot.snapshot().active
	var blocked: bool=_route!=null
	var recovery_pending:=false
	if _local_travel!=null:blocked=blocked or _local_travel.snapshot().acquired_station_id>=0
	if _scanner!=null:
		var scan: Dictionary=_scanner.snapshot()
		suspended=suspended or scan.get("found_actor_id",-1)>=0
		blocked=blocked or (scan.candidate_actor_id>=0 and scan.selected_actor_id<0)
	if _tractor!=null:
		var recovery: Dictionary=_tractor.snapshot()
		suspended=suspended or recovery.frame.get("found_actor_id",-1)>=0
		recovery_pending=recovery.request_actor_id>=0
		blocked=blocked or recovery_pending
	if not _targeting.advance(_scenery,_pose,camera,aim,delta_ms,enabled,approaching,blocked,suspended,recovery_pending):return reject(_targeting.error)
	var events: Array=_targeting.selection_events()
	_queue_mining_audio(events)
	if not _queue_notice_events(events):return false
	var recovery_index: int=_targeting.recovery_object_index()
	if recovery_index>=0:
		if _tractor==null:return reject("Acquired scenery cargo has no fitted tractor")
		var actor: Dictionary=_scenery.recovery_observation(recovery_index)
		if actor.is_empty():return reject(_scenery.error)
		if not _tractor.queue_acquired_wreck(actor):return reject(_tractor.error)
	return true

func _advance_station_targeting(delta_ms: int,enabled: bool,held_primary: bool,camera: Transform3D,aim: Dictionary) -> bool:
	var scanner: Dictionary={} if _scanner==null else _scanner.snapshot()
	var recovery: Dictionary={} if _tractor==null else _tractor.snapshot()
	# A retained ship scan is not a target found in this HUD pass. Only the
	# current NPC/cargo/asteroid acquisition may preempt the environment slot.
	var other: bool=scanner.get("found_actor_id",-1)>=0 \
		or recovery.get("request_actor_id",-1)>=0 or _targeting.selected_object_index()>=0
	var observation:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":int(_entry.campaign_cursor),
		"delta_ms":delta_ms,"viewport_size":aim.viewport_size,"camera_pose":camera,"aim_point":aim.point,
		"station":{"environment_slot":0,"pose":_station.snapshot().pose,"active":true},
		"controller_enabled":enabled and not local_departing(),"held_primary":held_primary,
		"other_selected_target":other,"mining_approach_active":_approach!=null and _approach.snapshot().phase!="idle",
		"alternate_operation_active":false,"selected_target_active":_autopilot!=null and _autopilot.snapshot().active}
	return true if _station_targeting.advance(observation) else reject(_station_targeting.error)

func _advance_void_targeting(delta_ms: int,enabled: bool,held_primary: bool,camera: Transform3D,aim: Dictionary) -> bool:
	var station: Dictionary=_void_environment.object_state(0)
	var scanner: Dictionary={} if _scanner==null else _scanner.snapshot()
	var recovery: Dictionary={} if _tractor==null else _tractor.snapshot()
	var other: bool=scanner.get("found_actor_id",-1)>=0 or scanner.get("selected_actor_id",-1)>=0 \
		or recovery.get("request_actor_id",-1)>=0 or (_targeting!=null and _targeting.selected_object_index()>=0)
	var observation:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":29,
		"delta_ms":delta_ms,"viewport_size":aim.viewport_size,"camera_pose":camera,"aim_point":aim.point,
		"station":{"environment_slot":0,"pose":station.pose,"active":true},
		"controller_enabled":enabled and _probe.snapshot().environment_targeting_enabled,"held_primary":held_primary,
		"other_selected_target":other,"mining_approach_active":_approach!=null and _approach.snapshot().phase!="idle",
		"alternate_operation_active":false,"selected_target_active":_autopilot!=null and _autopilot.snapshot().active}
	return true if _void_targeting.advance(observation) else reject(_void_targeting.error)

func fast_forward_available() -> bool:return _fast_forward!=null

func fast_forward_state() -> Dictionary:
	if _fast_forward==null:return {}
	var state: Dictionary=_fast_forward.snapshot()
	var approach: bool=_approach!=null and _approach.snapshot().phase=="approach"
	var navigation: bool=(_autopilot!=null and _autopilot.snapshot().active) or approach
	state.merge({"navigation":navigation,"near_target":_near_target,"enabled":navigation and not _fast_forward.battle() and not _near_target and not (_radio!=null and _radio.snapshot().get("visible",false))})
	return state

func press_fast_forward() -> RefCounted:
	error=""
	if _fast_forward==null or not entry_released() or dialogue_visible() or death_active() or local_departing() or cinematic_input_blocked():reject("Fast Forward requires supported released flight input");return null
	var next:=fork_for_frame()
	if not next._fast_forward.press(fast_forward_state().navigation,_fast_forward.battle(),_near_target):reject(next._fast_forward.error);return null
	if next._fast_forward.active() and not _fast_forward.active() and not next._camera.set_fast_forward(true):reject(next._camera.error);return null
	return next

func release_flight_action(time_released:=false) -> RefCounted:
	error=""
	var next:=fork_for_frame()
	if next._fast_forward!=null:
		if not next._fast_forward.release(time_released) or not next._camera.set_fast_forward(false):reject(next._fast_forward.error+next._camera.error);return null
	return next

## Input boundary reset on an already detached candidate; the session commits
## the candidate with its presentation, just like a normal flight action.
func clear_fast_forward_input() -> bool:
	if _fast_forward==null or (not _fast_forward.held() and not _fast_forward.active()):return true
	if not _fast_forward.release() or not _camera.set_fast_forward(false):return reject(_fast_forward.error+_camera.error)
	return true

## Keep the player, station inventory and target/weapon views in the same
## prospective frame. Audio and geometry are published by the session afterward.
func _apply_secondary_input(requested: bool,input_enabled: bool) -> bool:
	if _encounter==null or not _encounter.has_secondaries():return reject("This flight has no equipped secondary owner")
	var radio_free: bool=_radio==null or not _radio.snapshot().get("visible",false)
	var operation: Dictionary=_encounter.evaluate_secondary_fire(_player,_equipment,_pose,requested,input_enabled,_random,radio_free,_scenery)
	if operation.is_empty():return reject(_encounter.error)
	_encounter=operation.encounter;_player=operation.player;_equipment=operation.equipment;_random=operation.random_state
	_scenery=operation.scenery
	return true

func secondary_available() -> bool:return _encounter!=null and _encounter.has_secondaries()

func wingmen_available() -> bool:
	if _wingmen==null:return false
	var cast: Dictionary=_wingmen.snapshot()
	return cast.actors.any(func(actor):return actor.active and actor.vitals.hull>0)

## The original menu broadcasts its weapon toggle to eligible companions.
## Stage the complete cast before publishing any pilot's changed selection.
func switch_wingman_weapons(paused:=false) -> RefCounted:
	return command_wingmen(0,paused)

func command_wingmen(command: int,paused:=false) -> RefCounted:
	error=""
	if command not in [0,1,2,3]:reject("Unsupported companion order");return null
	if paused or not wingmen_available() or dialogue_visible() or death_active() or cinematic_input_blocked() or local_departing() or not _briefing.snapshot().entry_released or not _station_packet.is_empty() or not _unsupported_boundary.is_empty() or contract_result_pending():reject("Companion commands are unavailable in this flight phase");return null
	var crew: RefCounted=_wingmen.fork_for_frame()
	if command==0:
		var actors: Array=crew.snapshot().actors
		for index in actors.size():
			if actors[index].active and actors[index].vitals.hull>0 and not crew.toggle_weapon_group(index):reject(crew.error);return null
	else:
		var target_id: int=-1 if command!=3 or _scanner==null else int(_scanner.snapshot().selected_actor_id)
		if target_id>=0:
			var targets: Array=[] if _encounter==null else _encounter.combat_snapshot().actors
			if not targets.any(func(actor):return actor.actor_id==target_id and actor.active and actor.vitals.hull>0 and not actor.get("contract_debris",false)):target_id=-1
		var route: RefCounted=_world_route if _route==null else _route
		if not crew.issue_order(command,target_id,route if command==2 else null):reject(crew.error);return null
	var next:=fork_for_frame();next._wingmen=crew
	return next

func secondary_feedback() -> Dictionary:
	return {} if _encounter==null else _encounter.secondary_feedback()

func cycle_secondary(paused:=false) -> RefCounted:
	if not secondary_available():reject("This flight has no secondary selection");return null
	return select_secondary(_encounter.next_secondary_id(),paused)

func select_secondary(item_id: int,paused:=false) -> RefCounted:
	error=""
	if paused or not secondary_available() or dialogue_visible() or death_active() or cinematic_input_blocked() or local_departing() or not _briefing.snapshot().entry_released or not _station_packet.is_empty() or not _unsupported_boundary.is_empty() or contract_result_pending():reject("Secondary selection is unavailable in this flight phase");return null
	var selected: RefCounted=_encounter.select_secondary(item_id)
	if selected==null:reject(_encounter.error);return null
	var next:=fork_for_frame();next._encounter=selected
	return next

## Ginoya's radiation for this flight: the orbit's rate for the story cursor,
## cut by the best fitted gamma shield (subtype 38, percent in property 52).
func _radiation(bindings: RefCounted,catalogues: RefCounted,entry: Dictionary,equipment: RefCounted) -> float:
	if catalogues==null or not load("res://src/content/valkyrie_campaign_definitions.gd").available(bindings):return 0.0
	var rate: float=Worlds.gamma_rate(int(entry.get("location",{}).get("station_id",-1)),int(entry.get("campaign_cursor",-1)))
	if rate<=0.0:return rate
	var cut:=0
	for id in entry.get("departure",{}).get("loadout",{}).get("equipment_ids",[]):
		if int(id)<0 or int(id)>=catalogues.tables.items.size():continue
		var properties: Dictionary=catalogues.tables.items[int(id)].properties
		if int(properties.get(2,-1))==int(Worlds.GAMMA_SHIELD_SORT):cut=maxi(cut,int(properties.get(int(Worlds.GAMMA_SHIELD_ATTRIBUTE),0)))
	return rate*maxf(0.0,1.0-float(cut)/100.0)

## People-moving flights (Supernova kind 184): who can dock where, how many
## are aboard and the story status that counts people delivered down to 0.
## Boarding stops at the ship's passenger berths.
func _story_people(catalogues: RefCounted,entry: Dictionary) -> Dictionary:
	if _mission_context==null or _mission_context.recipe().get("docks",{}).is_empty():return {}
	var docks: Dictionary=_mission_context.recipe().docks
	var status:=maxi(0,load("res://src/content/valkyrie_campaign_definitions.gd").story_status(int(entry.get("campaign_cursor",-1))))
	var boards:=docks.values().any(func(row):return row.mode=="board")
	var berths:=_passenger_berths(catalogues,entry.get("departure",{}).get("loadout",{}))
	var shuttles: Dictionary=_mission_context.recipe().get("shuttles",{}).duplicate(true)
	if not shuttles.is_empty():shuttles.visits={}
	# With only drop-off docks the ship arrives with the people it can carry
	# (92: the ten from Valpatro; 102: the rest wait at the station).
	return {"actors":docks.duplicate(true),"docked":-1,"elapsed":0,"last_ms":0,"aboard":0 if boards else mini(status,berths),"status":status,"berths":berths,"shuttles":shuttles}

## Docked = within reach of a visible, dockable docking point. While docked
## the ship is held until that point's transfer is over; one person moves
## every 1.5 s once its transfer is on.
static func _passenger_berths(catalogues: RefCounted,loadout: Dictionary) -> int:
	if catalogues==null or not loadout.get("slots") is Array:return 0
	var sessions:=load("res://src/simulation/contract_session.gd")
	return sessions.passenger_capacity(sessions.cabin_catalogue(catalogues,load("res://src/content/early_contract_definitions.gd").MAC_ACCEPTANCE),loadout)

func _advance_story_dock(elapsed: int) -> bool:
	if _story_dock.is_empty():return true
	var step:=maxi(0,elapsed-int(_story_dock.last_ms));_story_dock.last_ms=elapsed
	var actors: Array=_encounter.combat_snapshot().actors
	var docked:=-1
	for id in _story_dock.actors:
		var row: Dictionary=_story_dock.actors[id]
		if not row.dockable or id>=actors.size() or int(actors[id].vitals.hull)<=0 or not actors[id].get("model_draw_enabled",true):continue
		var pose: Variant=actors[id].get("pose",actors[id].get("body_pose"))
		var reach: float=STORY_DOCK_RANGE+load("res://src/content/static_object_definitions.gd").reach(int(actors[id].get("static_model",-1)))
		if pose is Transform3D and _pose.origin.distance_to(pose.origin)<=reach:docked=int(id)
	if docked!=int(_story_dock.docked):_story_dock.docked=docked;_story_dock.elapsed=0;_story_hack=null
	_advance_story_shuttles(elapsed,actors)
	# A hack point opens the puzzle (difficulty 1 at cursor 91, else 4); a
	# win closes the point and counts for condition 50. Leaving drops it.
	if docked>=0 and _story_dock.actors[docked].mode=="hack":
		if _story_hack==null:
			_story_hack=load("res://src/simulation/hacking_game.gd").new()
			if not _story_hack.configure(1 if int(_entry.get("campaign_cursor",-1))==91 else 4,absi(hash([docked,elapsed]))):return reject(_story_hack.error)
		_story_hack.advance(step)
		if _story_hack.won():
			_story_dock.actors[docked].dockable=false;_story_dock.hacks=int(_story_dock.get("hacks",0))+1;_story_dock.last_hacked=docked
			_story_hack=null;_story_dock.docked=-1
		return true
	if docked<0 or not _story_dock.actors[docked].transfer:return true
	# A delivery point (kind 174, 135's Mining Plant): one unit of the good
	# leaves the hold each second and the story status rises by one.
	if _story_dock.actors[docked].mode=="deliver":
		var good:=int(_mission_context.recipe().get("deliver_item",_mission_context.recipe().get("asteroid_ore",-1)))
		_story_dock.elapsed=int(_story_dock.elapsed)+step
		while int(_story_dock.elapsed)>=STORY_DELIVER_MS and good>=0 and _cargo!=null and _cargo.quantity(good)>0:
			_story_dock.elapsed=int(_story_dock.elapsed)-STORY_DELIVER_MS
			if not _cargo.consume(good,1):return reject(_cargo.error)
			_story_dock.status=int(_story_dock.status)+1
		return true
	_story_dock.elapsed=int(_story_dock.elapsed)+step
	while int(_story_dock.elapsed)>=STORY_TRANSFER_MS and not _story_transfer_done(docked):
		_story_dock.elapsed=int(_story_dock.elapsed)-STORY_TRANSFER_MS
		if _story_dock.actors[docked].mode=="board":_story_dock.aboard=int(_story_dock.aboard)+1
		else:_story_dock.aboard=int(_story_dock.aboard)-1;_story_dock.status=maxi(0,int(_story_dock.status)-1)
	return true

## The recipe's route toward the sun: `toward_sun` metres along the station's
## sun direction, flattened to x/z (assumption: the flight starts at the
## player's arrival point).
func _player_route(catalogues: RefCounted,entry: Dictionary) -> Dictionary:
	if _mission_context==null or _mission_context.recipe().get("player_route",{}).is_empty() or catalogues==null:return {}
	var plan: Dictionary=_mission_context.recipe().player_route
	var station_id:=int(entry.get("location",{}).get("station_id",-1))
	var station: Variant=catalogues.tables.stations.get(station_id) if catalogues.tables.stations is Dictionary else (catalogues.tables.stations[station_id] if station_id>=0 and station_id<catalogues.tables.stations.size() else null)
	if station==null:return {}
	var sun: Dictionary=load("res://src/simulation/sun_placement.gd").new().for_station(station_id,int(station.get("planet_type",0)))
	if sun.is_empty():return {}
	var flat:=Vector3(sun.direction_to_sun.x,0,sun.direction_to_sun.z).normalized()
	return {"direction":flat,"distance":float(plan.toward_sun),"reach":float(plan.get("reach_radius",10000)),"point":null}

func story_route_point() -> Variant:return _story_route.get("point")

func _volatile_carried() -> bool:
	if _cargo==null:return false
	return Worlds.VOLATILE_GOODS.items.any(func(id):return _cargo.quantity(int(id))>0)

func instability() -> float:return _instability

func _story_course() -> bool:
	if _mission_context==null or _mission_context.contract_context().is_empty():return false
	var recipe: Dictionary=_mission_context.recipe()
	return not recipe.get("player_route",{}).is_empty() or recipe.get("radio_actions",[]).any(func(action):return action.action=="route")

## Where story ships appear: ahead of the player, round a random living ship
## of near_actors (or by player_chance the player), round the player, or at
## a fixed centre; the ring radius is drawn from radius [min,max].
func _story_spot(action: Dictionary,index: int,elapsed: int) -> Array:
	var roll:=absi(hash([index,elapsed]))
	var radius_row: Array=action.get("radius",[3000,3000])
	var radius:=maxf(1000.0,float(radius_row[0])+float(roll%maxi(1,int(radius_row[1])-int(radius_row[0]))))
	if action.has("ahead_of_player"):return [_pose.origin-_pose.basis.z.normalized()*float(action.ahead_of_player),radius]
	if action.has("near_actors"):
		var actors: Array=_encounter.combat_snapshot().actors
		var living: Array=range(int(action.near_actors[0]),int(action.near_actors[1])).filter(func(id):return int(actors[id].vitals.hull)>0)
		if living.is_empty() or float(roll%1000)<1000.0*float(action.get("player_chance",0.0)):return [_pose.origin,radius]
		return [actors[living[(roll/1000)%living.size()]].pose.origin,radius]
	if action.has("center") and not action.center is String:return [Vector3(action.center),radius]
	return [_pose.origin,radius]

## Condition 35 for story actions: [35,[line, ms, 0 started / 1 finished]].
func _story_line_passed(condition: Array,elapsed: int) -> bool:
	if condition.size()!=2 or int(condition[0])!=35:return false
	var values: Array=condition[1]
	var mark: Variant=_line_marks["finished" if int(values[2])==1 else "started"].get(int(values[0]))
	return mark!=null and elapsed-int(mark)>=int(values[1])

## Stealth fighters (verified behaviour): every 8 s a 30% chance to cloak,
## or 50% straight away after being hit; a cloak lasts 9-14 s, fading 2 s
## each way, and the ship cannot be targeted meanwhile. Rolls come from a
## hash of the ship and roll number, so a replayed frame rolls the same.
func _advance_story_cloaks(elapsed: int) -> bool:
	var ids: Array=_mission_context.recipe().get("cloakers",[])
	if ids.is_empty():return true
	var actors: Array=_encounter.combat_snapshot().actors
	for id in ids:
		if id>=actors.size():continue
		var actor: Dictionary=actors[id]
		var pool:=float(actor.vitals.hull)+float(actor.vitals.get("armor",0))+float(actor.vitals.get("shield",0))
		var mark: Dictionary=_story_cloaks.get(id,{"next_ms":elapsed+8000,"until_ms":-1,"pool":pool,"rolls":0})
		var awake: bool=actor.active and int(actor.get("actor_mode",0))!=5 and float(actor.vitals.hull)>0
		var cloak:=false
		if int(mark.until_ms)>=0:
			cloak=awake and elapsed<int(mark.until_ms)
			if not cloak:mark.until_ms=-1;mark.next_ms=elapsed+8000
		elif awake:
			var hit:=pool<float(mark.pool)
			if hit or elapsed>=int(mark.next_ms):
				mark.rolls=int(mark.rolls)+1
				var roll:=absi(hash([id,int(mark.rolls)]))%100
				if roll<(50 if hit else 30):
					cloak=true;mark.until_ms=elapsed+2000+9000+absi(hash([id,int(mark.rolls),1]))%5001+2000
				if not hit or cloak:mark.next_ms=elapsed+8000
		else:mark.next_ms=elapsed+8000
		mark.pool=pool;_story_cloaks[id]=mark
		if not _encounter.set_story_cloak(id,cloak):return reject(_encounter.error)
	return true

## Story shuttles (94's Midorian fighters): each arrival at the drop-off
## point delivers one person per 1.5 s for the visit (12 s); with
## hold_at_berths they stop once the people left fit the player's berths.
func _advance_story_shuttles(elapsed: int,actors: Array) -> void:
	var plan: Dictionary=_story_dock.get("shuttles",{})
	if plan.is_empty():return
	var dock: int=int(plan.dock)
	if dock>=actors.size() or int(actors[dock].vitals.hull)<=0:return
	var target: Vector3=actors[dock].get("pose",actors[dock].get("body_pose",Transform3D())).origin
	var reach: float=STORY_DOCK_RANGE+load("res://src/content/static_object_definitions.gd").reach(int(actors[dock].get("static_model",-1)))
	for id in range(int(plan.first_actor),mini(int(plan.end_actor),actors.size())):
		var visit: Dictionary=plan.visits.get(id,{"start":-1,"given":0,"away":true})
		var near: bool=int(actors[id].vitals.hull)>0 and actors[id].get("pose",Transform3D()).origin.distance_to(target)<=reach
		if near and visit.away and int(visit.start)<0:visit={"start":elapsed,"given":0,"away":false}
		if not near:visit.away=true
		if int(visit.start)>=0:
			var rate:=int(plan.get("transfer_ms",STORY_TRANSFER_MS))
			var due:=mini(int(plan.visit_ms)/rate,(elapsed-int(visit.start))/rate)
			while int(visit.given)<due:
				visit.given=int(visit.given)+1
				var floor_left:=int(_story_dock.berths) if plan.get("hold_at_berths",false) else 0
				if int(_story_dock.status)>floor_left:_story_dock.status=int(_story_dock.status)-1
			if elapsed-int(visit.start)>=int(plan.visit_ms):visit.start=-1
		plan.visits[id]=visit

func _story_transfer_done(id: int) -> bool:
	if _story_dock.actors[id].mode=="board":return int(_story_dock.aboard)>=(int(_story_dock.status) if _story_dock.actors[id].get("ignore_berths",false) else mini(int(_story_dock.berths),int(_story_dock.status)))
	return int(_story_dock.aboard)<=0

func story_dock_held() -> bool:
	if _story_hack!=null:return true
	return not _story_dock.is_empty() and int(_story_dock.docked)>=0 and _story_dock.actors[int(_story_dock.docked)].mode not in ["hack","deliver"] and not _story_transfer_done(int(_story_dock.docked))

## The open hacking puzzle for the panel, or {}.
func story_hack_state() -> Dictionary:
	if _story_hack==null:return {}
	var state: Dictionary=_story_hack.snapshot();state.highlighted=_story_hack.highlighted()
	return state

## A hacking button ("left"/"right"); false when no puzzle takes it.
func story_hack_press(button: String) -> bool:
	return _story_hack!=null and _story_hack.press(button)

func cinematic_input_blocked() -> bool:
	return _story_locked or story_dock_held() or convoy_input_blocked() or (_alioth!=null and _alioth.snapshot().input_blocked) or (_sahi!=null and _sahi.snapshot().input_blocked) or (_probe!=null and _probe.snapshot().input_blocked) or gate_modal() or gate_coasting() or gate_departing() or drive_departing()

func void_environment_owner() -> RefCounted:return null if _void_environment==null else _void_environment.fork()
func ordinary_void_source_owner() -> RefCounted:return null if _ordinary_void_source==null else _ordinary_void_source.fork()
func void_portal_owner() -> RefCounted:return null if _void_portal==null else _void_portal.fork_for_frame()

func void_return_required() -> bool:
	return _void_portal!=null and not death_active() and _void_portal.transition_ready(int(_player.snapshot().vitals.hull))

func _apply_portal_contact(portal: RefCounted) -> bool:
	var observation:={"player_pose":_pose,"environment_contact_enabled":_collision_enabled,"mining_active":_mining!=null and _mining.has_active_drill()}
	if _probe!=null:
		var objective: Dictionary=_objective.snapshot()
		var retired: bool=objective.phase=="portal_search" and objective.combat_objective_acknowledged
		observation.story_selection={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,
			"campaign_cursor":objective.campaign_cursor,"mission_kind":-1 if retired else 4,"mission_story":not retired,
			"mission_completed":objective.mission_completed,"mission_failed":false,"current_station_id":-1,"return_station_id":91}
	if not portal.observe_contact(observation):return reject(portal.error)
	var contact: Dictionary=portal.snapshot().contact
	if not contact.is_empty() and contact.pull_distance>0:
		_pose.origin=Vectors.added(_pose.origin,Vectors.scaled(Vectors.normalized(-contact.player_offset),float(contact.pull_distance)))
		_statistics_pose=_pose*Transform3D(_model_basis,Vector3.ZERO)
		if _autopilot!=null and not _autopilot.observe_scripted_pose(_pose):return reject(_autopilot.error)
	return true

func sahi_arrival_required() -> bool:
	return _sahi!=null and not death_active() and _sahi.transition_ready(int(_player.snapshot().vitals.hull))

## Construct a prospective world from this frame's actual living-player contact.
## No accepted owner is changed until the enclosing application adopts the result.
func construct_sahi_arrival(bindings: RefCounted,catalogues: RefCounted,environment_seconds: Variant,unix_seconds: Variant,large_display:=true,body_resources: RefCounted=null,effect_resources: RefCounted=null) -> RefCounted:
	error=""
	if not sahi_arrival_required():reject("Enter the Sahi portal alive before preparing its next world");return null
	return _construct_portal_arrival(bindings,catalogues,25,environment_seconds,unix_seconds,large_display,body_resources,effect_resources)

func construct_void_return(bindings: RefCounted,catalogues: RefCounted,environment_seconds: Variant,unix_seconds: Variant,large_display:=true,body_resources: RefCounted=null,effect_resources: RefCounted=null) -> RefCounted:
	error=""
	if not void_return_required():reject("Enter the Void portal alive before preparing its return world");return null
	if _ordinary_void_source!=null:return _construct_ordinary_portal_arrival(bindings,catalogues,environment_seconds,unix_seconds,large_display,body_resources,effect_resources)
	var cursor:=29 if _entry.campaign_cursor==28 else 30 if _entry.campaign_cursor==29 else 26
	return _construct_portal_arrival(bindings,catalogues,cursor,environment_seconds,unix_seconds,large_display,body_resources,effect_resources)

## Prepare a detached world after real portal contact. No story cursor changes;
## the source flight's ledger is retired once in the prospective career only.
func _construct_ordinary_portal_arrival(bindings: RefCounted,catalogues: RefCounted,environment_seconds: Variant,unix_seconds: Variant,large_display: bool,body_resources: RefCounted,effect_resources: RefCounted) -> RefCounted:
	if bindings==null or catalogues==null or bindings.base_content_id!=_entry.base_content_id or bindings.binding_id!=_entry.binding_id or catalogues.content_id!=bindings.base_content_id:reject("The ordinary portal belongs to another content identity");return null
	var portal: Dictionary=_void_portal.snapshot()
	var entering: bool=portal.ordinary_mode=="source_entry"
	if Context.ordinary_void_route(bindings,_ordinary_void_source).is_empty() or portal.ordinary_mode not in ["source_entry","void_return"]:reject("The portal has no ordinary route");return null
	return _construct_void_trip(bindings,catalogues,_ordinary_void_source,entering,environment_seconds,unix_seconds,large_display,body_resources,effect_resources)

func _construct_void_trip(bindings: RefCounted,catalogues: RefCounted,route: RefCounted,entering: bool,environment_seconds: Variant,unix_seconds: Variant,large_display: bool,body_resources: RefCounted,effect_resources: RefCounted,location_settings: Dictionary={},location_library: RefCounted=null) -> RefCounted:
	var current:=snapshot()
	var contracts: RefCounted
	if entering:
		if not _objective is ContractObjective:reject("The source portal lost its ordinary flight ledger");return null
		contracts=_objective.retained_for_arrival(_encounter)
	else:
		contracts=_convoy_career.fork() if _convoy_career!=null else null
	if contracts==null:reject("The ordinary portal lost its retained career");return null
	var equipment: RefCounted=_equipment.fork()
	var source: Dictionary=equipment.snapshot().loadout
	var exit: Dictionary={} if entering else load("res://src/content/valkyrie_flight_definitions.gd").void_exit(int(Context.ordinary_void_route(bindings,route).get("campaign_cursor",-1)))
	if not exit.is_empty():
		if not contracts.leave_void_for_story(bindings,current.progress,route,int(exit.campaign_cursor),int(exit.station_id)):reject(contracts.error);return null
		if location_library==null or not contracts.select_location(bindings,catalogues,location_library,int(exit.station_id),location_settings,_random,unix_seconds):reject("The story's way out lost its destination: "+contracts.error);return null
		route=route.rebased_void_story(int(exit.campaign_cursor),int(exit.station_id),int(catalogues.tables.stations[int(exit.station_id)].system_id))
	if not equipment.retain_flight_cargo(current.cargo) or not equipment.relocate_ordinary_void(bindings,route,entering):reject(equipment.error);return null
	# A story that moved on during this flight (78 -> 79) is the trip's cursor.
	var pilot_state: Dictionary=current.player
	var trip_cursor: int=int(Context.ordinary_void_route(bindings,route).get("campaign_cursor",-1))
	if pilot_state.get("campaign_cursor")!=trip_cursor and contracts.snapshot().get("campaign_cursor")==trip_cursor:
		pilot_state=pilot_state.duplicate(true);pilot_state.campaign_cursor=trip_cursor
	var cache: Dictionary=load("res://src/simulation/flight_player_cache.gd").capture_ordinary_void(bindings,route,source,equipment.snapshot().loadout,pilot_state,entering)
	if cache.is_empty():reject("The ordinary portal lost the surviving ship pools");return null
	if exit.is_empty() and not contracts.transfer_ordinary_void(bindings,current.progress,route,entering):reject(contracts.error);return null
	var candidate:=Construction.new()
	var prepared: bool
	if entering:
		prepared=candidate.prepare_ordinary_void_selected(bindings,catalogues,equipment,route,cache,current.progress,_station_response_flags,contracts.snapshot().difficulty,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,contracts)
	else:
		prepared=candidate.prepare_portal_return(bindings,catalogues,equipment,contracts,_station_response_flags,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,cache,route)
	if not prepared:reject(candidate.error);return null
	return candidate

func _construct_portal_arrival(bindings: RefCounted,catalogues: RefCounted,cursor: int,environment_seconds: Variant,unix_seconds: Variant,large_display: bool,body_resources: RefCounted,effect_resources: RefCounted) -> RefCounted:
	if not load("res://src/content/post_sahi_definitions.gd").available(bindings):reject("This content pack does not declare the world beyond Sahi");return null
	if bindings.base_content_id!=_entry.base_content_id or bindings.binding_id!=_entry.binding_id or catalogues==null or catalogues.content_id!=bindings.base_content_id:reject("The Sahi arrival belongs to another content identity");return null
	var current:=snapshot()
	var equipment: RefCounted=_equipment.fork()
	var source: Dictionary=equipment.snapshot().loadout
	if not equipment.retain_flight_cargo(current.cargo):reject(equipment.error);return null
	if cursor==25 and not equipment.protect_sahi_cargo(bindings):reject(equipment.error);return null
	if not equipment.relocate_post_sahi(bindings,cursor):reject(equipment.error);return null
	var cache: Dictionary=load("res://src/simulation/flight_player_cache.gd").capture_post_sahi(bindings.mido_travel,source,equipment.snapshot().loadout,current.player,cursor)
	if cache.is_empty():reject("The Sahi arrival lost its actual ship pools or equipment");return null
	var progress: Dictionary=current.progress.duplicate(true)
	var contracts: RefCounted=_convoy_career.fork() if _convoy_career!=null else null
	if contracts!=null:
		var retained: bool=contracts.advance_sahi_story(bindings,progress,cursor) if cursor in [25,29] else contracts.return_from_void(bindings,progress,cursor)
		if not retained:reject(contracts.error);return null
		progress=contracts.snapshot().progress
	elif cursor in [25,29]:
		var earned: Dictionary=load("res://src/simulation/opening_handoff.gd").calculate_progress(bindings.opening_handoff,cursor,progress.player_kills,progress.pirate_kills,progress.other_score)
		if earned.is_empty():reject("The Sahi arrival exceeds the supported career range");return null
		progress.merge(earned,true)
	var context: Dictionary=_entry.sahi_context.duplicate(true)
	var location: Dictionary=load("res://src/content/post_sahi_definitions.gd").location(cursor)
	var mission: Dictionary=load("res://src/content/post_sahi_definitions.gd").mission(bindings,cursor)
	context.merge({"campaign_cursor":cursor,"station_id":location.station_id,"system_id":location.system_id,"mission_kind":int(mission.kind),"mission_completed":false,"mission_failed":false,"rank":progress.rank},true)
	var candidate:=Construction.new()
	if cursor==30:
		if not candidate.prepare_portal_return(bindings,catalogues,equipment,contracts,_station_response_flags,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,cache):reject(candidate.error);return null
		return candidate
	if not candidate.prepare_post_sahi_selected(bindings,catalogues,equipment,context,progress,_station_response_flags,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,cache,contracts,_selected_locations):reject(candidate.error);return null
	return candidate

func _advance_probe_sequence(delta_ms: int) -> bool:
	if not _probe.advance_clock(delta_ms):return reject(_probe.error)
	var clock: Dictionary=_probe.snapshot()
	var lock: Dictionary=_void_targeting.snapshot()
	_radio_events=_radio.step_probe(int(_briefing.snapshot().world_elapsed_ms),{
		"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":29,
		"stage_elapsed_ms":clock.stage_elapsed_ms,"mother_ship_locked":lock.mother_ship_locked})
	if not _radio.error.is_empty():return reject(_radio.error)
	if not _probe.observe_radio(_radio,_pose,_camera.snapshot().pose):return reject(_probe.error)
	var stage: Dictionary=_probe.snapshot()
	var refresh:=false
	for cue in stage.frame.cues:
		match cue.kind:
			"player_damage":
				if not _player.set_permissions(_player.snapshot().active,bool(cue.enabled)):return reject(_player.error)
			"camera_eye":
				_shot={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"mode":"fixed_eye","target":"probe","eye":cue.position,"inherit_target_up":true}
				refresh=true
			"camera_scripted":
				_camera_follow_enabled=not bool(cue.enabled)
				if not cue.enabled:_shot={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"mode":"follow","target":"player"}
	# Native primary input has no retained trigger latch. The stage input flag
	# cancels this frame's request at the shared fire owner below.
	if stage.scripted_camera:
		var scene:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,
			"player_pose":_pose,"probe_pose":_probe.probe_snapshot().pose}
		if not _camera.update(_camera_ms,_shot,scene,_shot if refresh else {}):return reject(_camera.error)
	return true

func _advance_sahi(delta_ms: int) -> bool:
	if not _sahi.advance_stage(delta_ms,_radio.snapshot(),_pose,_camera.snapshot().pose):return reject(_sahi.error)
	var state: Dictionary=_sahi.snapshot()
	var refresh:=false;var shake:={}
	for cue in state.frame.cues:
		match cue.kind:
			"clear_npc_weapon_targets":
				if not _encounter.apply_sahi_view(_sahi):return reject(_encounter.error)
			"player_damage":
				if not _player.set_permissions(_player.snapshot().active,bool(cue.enabled)):return reject(_player.error)
			"player_physical_pose":
				_pose=cue.pose
				_statistics_pose=_pose*Transform3D(_model_basis,Vector3.ZERO)
				if _autopilot!=null and not _autopilot.observe_scripted_pose(_pose):return reject(_autopilot.error)
			"camera_eye":
				_shot={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"mode":"fixed_eye","target":"player","eye":cue.position,"inherit_target_up":true}
				refresh=true;_camera_follow_enabled=false
			"camera_shake":shake=cue
			"player_visual_rotation":
				_model_basis=(_model_basis*Basis.from_euler(cue.delta)).orthonormalized()
				_statistics_pose=_pose*Transform3D(_model_basis,Vector3.ZERO)
				if _approach!=null and _approach.snapshot().phase!="idle" and not _approach.accept_model_basis(_model_basis):return reject(_approach.error)
			"rebase_starfield":_reference=_camera.snapshot().eye
	if not state.input_blocked:return true
	var random: RefCounted=load("res://src/simulation/seeded_random.gd").new()
	if not random.restore(_random):return reject(random.error)
	var scene:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"player_pose":_pose}
	for pass_index in _camera_passes:
		var jitter:=Vector3.ZERO
		if _camera_ms>0 and not shake.is_empty():
			for axis in 3:jitter[axis]=float(random.next_int(2*int(shake.shake_kind))-int(shake.shake_kind))*float(shake.amount)
		if not _camera.update(_camera_ms,_shot,scene,_shot if refresh and pass_index==0 else {},null,jitter):return reject(_camera.error)
	_random=random.snapshot()
	return true

func _advance_alioth(delta_ms: int) -> bool:
	var actors: Dictionary=_encounter.combat_owner().alioth_actor_context()
	if not _alioth.advance(delta_ms,_radio.snapshot(),actors,_pose,_portal.snapshot().pose,_random):return reject(_alioth.error)
	if not _encounter.apply_alioth_sequence(_alioth,_random) or not _portal.apply_sequence(_alioth):return reject(_encounter.error+_portal.error)
	var state: Dictionary=_alioth.snapshot();var frame: Dictionary=state.frame
	_random=frame.random_state.duplicate(true)
	# The source disables special body/drive actions and late input. It retains
	# existing mining and guidance owners; the ordinary player phase gates them.
	for op in frame.camera_operations:
		match op.action:
			"follow_player":
				_shot={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"mode":"follow","target":"player"}
				_alioth_camera={};_camera_follow_enabled=true
			"follow_actor":_alioth_camera={"target":"actor","actor_id":int(op.actor_id)}
			"follow_environment":_alioth_camera={"target":"environment","slot":int(op.slot)}
			"set_eye":_alioth_camera.eye=op.position
			"offset":_alioth_camera.eye=Vectors.added(_alioth_camera.eye,op.delta)
	if not _alioth_camera.is_empty():
		_shot={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"mode":"fixed_eye","target":_alioth_camera.target,"eye":_alioth_camera.eye,"inherit_target_up":true}
		if _alioth_camera.target=="actor":_shot.actor_id=_alioth_camera.actor_id
		else:_shot.slot=_alioth_camera.slot
		var scene:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"player_pose":_pose,
			"actors":_encounter.combat_snapshot().actors.map(func(actor):return {"actor_id":actor.actor_id,"pose":actor.body_pose}),
			"environment":{int(_portal.snapshot().slot):_portal.snapshot().pose}}
		for pass_index in _camera_passes:
			if not _camera.update(_camera_ms,_shot,scene,_shot if pass_index==0 else {}):return reject(_camera.error)
	return true

func convoy_input_blocked() -> bool:return _convoy!=null and _convoy.snapshot().input_blocked
func convoy_arrival_required() -> bool:return _convoy!=null and not death_active() and _convoy.snapshot().phase==Capture.Stage.ARRIVAL_REQUIRED

func _advance_convoy(delta_ms: int) -> bool:
	var actors: Array=_encounter.combat_snapshot().actors
	if not _convoy.advance(delta_ms,_radio.snapshot(),_pose,actors[6].body_pose):return reject(_convoy.error)
	if not _encounter.apply_convoy_capture(_convoy):return reject(_encounter.error)
	if _particles!=null and _particles.has_convoy_emp() and not _particles.apply_convoy_capture(_convoy):return reject(_particles.error)
	var state: Dictionary=_convoy.snapshot();var frame: Dictionary=state.frame
	if not state.input_blocked:return true
	if frame.disable_player:
		if not _player.set_permissions(false,_player.snapshot().damage_allowed):return reject(_player.error)
		_throttle=0.0;_preceding_commands=Vector2.ZERO
		_pilot.angular_units=Vector2.ZERO
		_model_basis=(_model_basis*Basis(Vector3.UP,frame.model_rotation_delta.y)).orthonormalized()
		_statistics_pose=_pose*Transform3D(_model_basis,Vector3.ZERO)
		if _approach!=null and _approach.snapshot().phase!="idle" and not _approach.accept_model_basis(_model_basis):return reject(_approach.error)
	if not _apply_convoy_engine_cue(frame):return false
	for operation in frame.camera_operations:
		if operation.action in ["follow_player","follow_actor"]:
			_convoy_camera={"target":("player" if operation.action=="follow_player" else "actor"),"actor_id":int(operation.get("actor_id",-1)),"offset":Vector3.ZERO}
		elif operation.action=="offset":_convoy_camera.offset+=operation.delta
	if _convoy_camera.is_empty():return reject("Disabled convoy lost its source camera")
	var target: Transform3D=_pose if _convoy_camera.target=="player" else actors[_convoy_camera.actor_id].body_pose
	_shot={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"mode":"fixed_eye","target":_convoy_camera.target,"eye":target.origin+_convoy_camera.offset,"inherit_target_up":true}
	if _convoy_camera.target=="actor":_shot.actor_id=_convoy_camera.actor_id
	var scene:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"player_pose":_pose,"actors":actors.map(func(actor):return {"actor_id":actor.actor_id,"pose":actor.body_pose})}
	for pass_index in _camera_passes:
		if not _camera.update(_camera_ms,_shot,scene,_shot if pass_index==0 else {}):return reject(_camera.error)
	return _objective.observe_combat(_encounter)

func _apply_convoy_engine_cue(frame: Dictionary) -> bool:
	if frame.get("stop_nozzle_emitters",false) and _engine_particles!=null:
		# The source passes NPC0's retained [-1,0,1] handles to the nozzle
		# manager. The unassigned handle is ignored; nozzles2/3 keep emitting.
		for index in [0,1]:
			if not _engine_particles.set_nozzle_emitting(index,false):return reject(_engine_particles.error)
	return true

func _observe_radio() -> bool:
	if _radio==null:return true
	if _probe!=null:return true # Its ordered radio/stage pass precedes mission polling.
	if _radio is LocalRadio:
		var reaction: Dictionary=_encounter.career_snapshot().get("provocation",{})
		if reaction.is_empty():return true
		var result: Dictionary=_radio.evaluate(int(_briefing.snapshot().world_elapsed_ms),reaction,_random)
		if result.is_empty():return reject(_radio.error)
		_radio=result.radio;_radio_events=result.events;_random=result.random_state
		return true
	if _mission_context!=null and (_mission_context.advances_campaign() or not _mission_context.contract_context().is_empty()):
		var elapsed: int=int(_briefing.snapshot().world_elapsed_ms)
		# When each recipe line started and finished (condition 35).
		var lines: Dictionary=_radio.snapshot()
		for kind in ["started","finished"]:
			var seen: Array=lines.get(kind,[])
			for index in seen.size():
				if seen[index]==true and not _line_marks[kind].has(index):_line_marks[kind][index]=elapsed
		if not _radio.bind_context(_mission_context.radio_observation(elapsed,_story_radio_facts())):return reject(_radio.error)
		_radio_events=_radio.step_context(elapsed)
		var turn: Dictionary=_mission_context.recipe().get("turn_hostile",{})
		if not turn.is_empty() and _radio.error.is_empty() and _radio.snapshot().finished[int(turn.radio_index)] and not _encounter.story_hostility_applied():
			if not _encounter.apply_story_hostility(int(turn.get("reputation_axis",-1)),int(turn.get("reputation_value",0))):return reject(_encounter.error)
		# Recipe actions cued by a radio line starting (e.g. pirates give up at "Fall back!").
		if not _advance_story_dock(elapsed):return false
		if not _advance_story_cloaks(elapsed):return false
		# Sleeping ships wake when the player comes within range; then every
		# sleeper of the group within all_range wakes too (114).
		for wake in _mission_context.recipe().get("proximity_wakes",[]):
			var actors: Array=_encounter.combat_snapshot().actors
			var ids: Array=range(int(wake.first_actor),int(wake.end_actor))
			var asleep: Callable=func(id):return not actors[id].get("active",false) and int(actors[id].get("actor_mode",-1))==5 and int(actors[id].vitals.hull)>0
			if ids.any(func(id):return asleep.call(id) and actors[id].pose.origin.distance_to(_pose.origin)<=float(wake.range)):
				for id in ids.filter(func(id):return asleep.call(id) and actors[id].pose.origin.distance_to(_pose.origin)<=float(wake.all_range)):
					if not _encounter.wake_story_actors(id,id+1):return reject(_encounter.error)
		if not _story_route.is_empty() and _story_route.point==null:_story_route.point=_pose.origin+_story_route.direction*float(_story_route.distance)
		var radio_actions: Array=_mission_context.recipe().get("radio_actions",[])
		var radio_lock:=false;var radio_invulnerable:=false
		for index in radio_actions.size():
			var action: Dictionary=radio_actions[index]
			# Cued when the line starts, or with on:"finished" when it is over.
			var started: Array=_radio.snapshot().get("finished" if action.get("on","")=="finished" else "started",[])
			if int(action.radio_index)>=started.size() or started[int(action.radio_index)]!=true:continue
			# when:"undocked" waits for the player to leave the docking point;
			# delay_ms counts from the moment the cue (and its when) first held.
			if not _action_marks.has(index):
				if action.get("when","")=="undocked" and int(_story_dock.get("docked",-1))>=0:continue
				_action_marks[index]=elapsed
			if elapsed<int(_action_marks[index])+int(action.get("delay_ms",0)):continue
			if action.action=="lock_player":
				# No steering for the scene; "invulnerable" also keeps the ship unharmed.
				# "until" holds it until a line has started/finished that long ago
				# (condition 35) instead of for a duration.
				var held: bool=not _story_line_passed(action.until,elapsed) if action.has("until") else elapsed<int(_action_marks[index])+int(action.get("delay_ms",0))+int(action.duration_ms)
				if held:
					radio_lock=true;radio_invulnerable=radio_invulnerable or action.get("invulnerable",false)
			elif action.action in ["dockable","transfer"]:
				# target "last_hacked": the point of the latest won hack (139).
				if action.get("target","")=="last_hacked" and _action_marks.has("applied%d"%index):continue
				var ids: Array=[int(_story_dock.get("last_hacked",-1))] if action.get("target","")=="last_hacked" else range(int(action.first_actor),int(action.end_actor))
				for id in ids:
					if not _story_dock.get("actors",{}).has(id):continue
					_story_dock.actors[id][action.action]=action.get("enabled",true)
					# 139: the hacked battleship becomes a boarding point, count from 0.
					# Its count is goods, not passengers: cabins don't limit it.
					if action.has("mode"):_story_dock.actors[id].mode=action.mode;_story_dock.actors[id].dockable=true;_story_dock.actors[id].ignore_berths=true
					if action.get("reset",false):_story_dock.aboard=0
				_action_marks["applied%d"%index]=true
			elif action.action=="respawn":
				# Every every_ms the range's dead ships come back, until line
				# until_radio starts (102, 105, 135).
				var until:=int(action.get("until_radio",-1))
				var begun: Array=_radio.snapshot().get("started",[])
				if until>=0 and until<begun.size() and begun[until]==true:continue
				var last:=int(_action_marks.get("respawn%d"%index,int(_action_marks[index])))
				if elapsed-last<int(action.every_ms):continue
				_action_marks["respawn%d"%index]=elapsed
				var count:=0
				if action.has("offset"):
					for id in range(int(action.first_actor),int(action.end_actor)):
						var at:=_pose.origin+Vector3(action.offset)+Vector3(action.get("step",Vector3.ZERO))*float(id-int(action.first_actor))
						var back: int=_encounter.respawn_story_actors(id,id+1,at,1.0)
						if back<0:return reject(_encounter.error)
						count+=back
				else:
					var spot:=_story_spot(action,index,elapsed)
					count=_encounter.respawn_story_actors(int(action.first_actor),int(action.end_actor),spot[0],spot[1])
					if count<0:return reject(_encounter.error)
				if count>0:_action_marks["respawned"]=elapsed
			elif action.action=="route":
				# A course for the player to a fixed point (125: the black box site).
				if _story_route.get("point")==null:_story_route={"direction":Vector3.ZERO,"distance":0.0,"reach":float(action.get("reach",STORY_ROUTE_REACH)),"point":Vector3(action.points[0])}
			elif action.action=="show" and action.get("center","")=="player":
				# Parked ships appear once on a ring round the player.
				if _action_marks.has("placed%d"%index):continue
				if action.has("offset"):
					# 135: each ship at the player + offset + step x its index.
					for id in range(int(action.first_actor),int(action.end_actor)):
						var at:=_pose.origin+Vector3(action.offset)+Vector3(action.get("step",Vector3.ZERO))*float(id-int(action.first_actor))
						if _encounter.respawn_story_actors(id,id+1,at,1.0)<0 or not _encounter.place_story_actors(id,id+1,at,1.0,true):return reject(_encounter.error)
				else:
					var radius:=float(action.radius[0])+float(absi(hash([index,elapsed]))%maxi(1,int(action.radius[1])-int(action.radius[0])))
					if not _encounter.place_story_actors(int(action.first_actor),int(action.end_actor),_pose.origin,radius):return reject(_encounter.error)
				_action_marks["placed%d"%index]=true
				if action.get("wake",false) and not _encounter.wake_story_actors(int(action.first_actor),int(action.end_actor)):return reject(_encounter.error)
			elif action.action=="show" and action.has("ahead_of_player"):
				# Parked ships appear once, ahead of the player.
				if _action_marks.has("placed%d"%index):continue
				var ahead:=_pose.origin-_pose.basis.z.normalized()*float(action.ahead_of_player)
				if not _encounter.place_story_actors(int(action.first_actor),int(action.end_actor),ahead,maxf(1000.0,float(action.radius[1]))):return reject(_encounter.error)
				_action_marks["placed%d"%index]=true
			elif action.action=="show" and action.has("near_actors"):
				# Parked ships appear once, on a ring round a random living ship
				# of near_actors (or, by player_chance, round the player).
				if _action_marks.has("placed%d"%index):continue
				var actors: Array=_encounter.combat_snapshot().actors
				var living: Array=range(int(action.near_actors[0]),int(action.near_actors[1])).filter(func(id):return int(actors[id].vitals.hull)>0)
				var roll:=absi(hash([index,elapsed]))
				var center: Vector3=_pose.origin if living.is_empty() or float(roll%1000)<1000.0*float(action.get("player_chance",0.0)) else actors[living[(roll/1000)%living.size()]].pose.origin
				var radius:=float(action.radius[0])+float(roll%maxi(1,int(action.radius[1])-int(action.radius[0])))
				if not _encounter.place_story_actors(int(action.first_actor),int(action.end_actor),center,radius):return reject(_encounter.error)
				_action_marks["placed%d"%index]=true
			elif action.action in ["show","destroy"]:
				var actors: Array=_encounter.combat_snapshot().actors
				var pending: bool=range(int(action.first_actor),int(action.end_actor)).any(func(id):return int(actors[id].vitals.hull)>0 and (action.action=="destroy" or not actors[id].get("model_draw_enabled",true)))
				if pending and not _encounter.story_actor_action(int(action.first_actor),int(action.end_actor),action.action):return reject(_encounter.error)
			elif action.action=="hostile":
				# The cast turns on the player (W1: the criminal is found or hit).
				if not _encounter.story_hostility_applied() and not _encounter.apply_story_hostility(-1,0):return reject(_encounter.error)
			elif action.action=="stand_down":
				# Once: the ships give up, neither hostile nor firing (W1 surrender).
				if not _action_marks.has("stood%d"%index):
					if not _encounter.stand_down_story_actors(int(action.first_actor),int(action.end_actor)):return reject(_encounter.error)
					_action_marks["stood%d"%index]=true
			elif action.action=="disarm":
				var actors: Array=_encounter.combat_snapshot().actors
				if range(int(action.first_actor),int(action.end_actor)).any(func(id):return actors[id].get("firing_allowed",false) and int(actors[id].vitals.hull)>0):
					if not _encounter.disarm_story_actors(int(action.first_actor),int(action.end_actor)):return reject(_encounter.error)
			elif action.action=="place":
				# Parked (asleep, far away) reserve ships arrive once per action.
				if _action_marks.has("placed%d"%index):continue
				var actors: Array=_encounter.combat_snapshot().actors
				# centre "player": a ring around the player; wake: they attack at once.
				var center:=_pose.origin if action.center is String and action.center=="player" else Vector3(action.center)
				if actors[int(action.first_actor)].get("active",false)!=true and int(actors[int(action.first_actor)].vitals.hull)>0 and (action.center is String or actors[int(action.first_actor)].pose.origin.distance_to(center)>2.0*float(action.radius)):
					if not _encounter.place_story_actors(int(action.first_actor),int(action.end_actor),center,float(action.radius)):return reject(_encounter.error)
					_action_marks["placed%d"%index]=true
					if action.get("wake",false) and not _encounter.wake_story_actors(int(action.first_actor),int(action.end_actor)):return reject(_encounter.error)
			elif action.action=="wake":
				# Once per action: sleeping ships start to fight.
				if not _action_marks.has("woken%d"%index):
					if not _encounter.wake_story_actors(int(action.first_actor),int(action.end_actor)):return reject(_encounter.error)
					_action_marks["woken%d"%index]=true
			elif action.action=="retire":
				# The ship or object leaves the scene (80: the Valkyrie jumps away).
				var actors: Array=_encounter.combat_snapshot().actors
				var parked: Variant=actors[int(action.first_actor)].get("pose",actors[int(action.first_actor)].get("body_pose"))
				var gone: bool=not actors[int(action.first_actor)].get("model_draw_enabled",true) if actors[int(action.first_actor)].get("static_object",false) else not actors[int(action.first_actor)].get("active",false) and parked is Transform3D and parked.origin.distance_to(RETIRE_POINT)<=100000.0
				# Once per action: a later "place" may bring the same ships back.
				if not gone and not _action_marks.has("retired%d"%index):
					if not _encounter.retire_story_actors(int(action.first_actor),int(action.end_actor),RETIRE_POINT):return reject(_encounter.error)
					_action_marks["retired%d"%index]=true
		if radio_actions.any(func(action):return action.action=="lock_player") and radio_lock!=_story_locked:
			_story_locked=radio_lock
			if (radio_invulnerable or not radio_lock) and not _player.set_permissions(bool(_player.snapshot().active),not radio_lock):return reject(_player.error)
		# Recipe actions at a flight time (78: the station leaves, the pirates wake).
		for action in _mission_context.recipe().get("timed_actions",[]):
			if elapsed<int(action.after_ms):continue
			# A cutaway (kind 170 scenes): the player is held and unharmable for
			# the whole flight. Assumption: the camera stays on the ship.
			# It ends once the story has moved on, so the story's jump can go.
			if action.action=="cutaway":
				var held: bool=int(_objective.snapshot().campaign_cursor)==int(_entry.get("campaign_cursor",-1))
				if held!=_story_locked:
					_story_locked=held
					if not _player.set_permissions(bool(_player.snapshot().active),not held):return reject(_player.error)
			elif action.action=="hide_station" and not _station_hidden:
				_station_hidden=true;_return_rules={}
			elif action.action=="lock_player":
				# No steering for the scene; "invulnerable" also keeps the ship unharmed.
				var locked: bool=not _story_line_passed(action.until,elapsed) if action.has("until") else elapsed<int(action.after_ms)+int(action.duration_ms)
				if locked!=_story_locked:
					_story_locked=locked
					if action.get("invulnerable",false) and not _player.set_permissions(bool(_player.snapshot().active),not locked):return reject(_player.error)
			elif action.action in ["show","destroy"]:
				var actors: Array=_encounter.combat_snapshot().actors
				var pending: bool=range(int(action.first_actor),int(action.end_actor)).any(func(id):return int(actors[id].vitals.hull)>0 and (action.action=="destroy" or not actors[id].get("model_draw_enabled",true)))
				if pending and not _encounter.story_actor_action(int(action.first_actor),int(action.end_actor),action.action):return reject(_encounter.error)
			elif action.action=="hide":
				var actors: Array=_encounter.combat_snapshot().actors
				if range(int(action.first_actor),int(action.end_actor)).any(func(id):return actors[id].get("model_draw_enabled",true) and actors[id].get("static_object",false)):
					if not _encounter.retire_story_actors(int(action.first_actor),int(action.end_actor),RETIRE_POINT):return reject(_encounter.error)
			elif action.action=="wake":
				var actors: Array=_encounter.combat_snapshot().actors
				if range(int(action.first_actor),int(action.end_actor)).any(func(id):return actors[id].get("active",false)!=true and int(actors[id].get("actor_mode",-1))==5 and int(actors[id].vitals.hull)>0):
					if not _encounter.wake_story_actors(int(action.first_actor),int(action.end_actor)):return reject(_encounter.error)
	elif _void_environment!=null or _entry.campaign_cursor==28:
		_radio_events=_radio.step(int(_briefing.snapshot().world_elapsed_ms),{},0)
		# 81: the story's way out of the alien world starts once its lines are over.
		if _void_environment!=null and _drive!=null and _drive.snapshot().get("phase","")=="ready" and load("res://src/content/valkyrie_flight_definitions.gd").void_exit(int(_entry.campaign_cursor)).get("auto",false):
			var heard: Array=_radio.snapshot().get("finished",[])
			if not heard.is_empty() and heard.all(func(done):return done==true):_story_jump=0
	elif _sahi!=null:
		var context:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":_entry.campaign_cursor,"recovery":_encounter.recovery_totals()}
		_radio_events=_radio.step_sahi(int(_briefing.snapshot().world_elapsed_ms),context)
	elif _rescue!=null:
		var context: Dictionary=_encounter.kappa_radio_context(_route)
		if context.is_empty():return reject(_encounter.error)
		_radio_events=_radio.step_kappa_rescue(int(_briefing.snapshot().world_elapsed_ms),context)
	elif _alioth!=null:
		_radio_events=_radio.step_alioth_attack(int(_briefing.snapshot().world_elapsed_ms),_encounter.combat_owner().alioth_actor_context())
	elif _convoy!=null:
		var targets:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":14,"player_targets":_encounter.combat_snapshot().actors.map(func(actor):return {"scenery":false,"current_hull":int(actor.vitals.hull)})}
		_radio_events=_radio.step_convoy(int(_briefing.snapshot().world_elapsed_ms),targets)
	else:_radio_events=_radio.step_combat_training(int(_briefing.snapshot().world_elapsed_ms),_encounter.combat_owner())
	return true if _radio.error.is_empty() else reject(_radio.error)

## Story radio reads the live cast the way the original's radio conditions do:
## an awake non-friendly ship, ships destroyed so far, and the player's armour.
func _story_radio_facts() -> Dictionary:
	if _mission_context.contract_context().is_empty() or _mission_context.recipe().get("radio",[]).is_empty():return {}
	var hostile_active:=false;var defeated:=0;var hulls:={};var distances:={};var emp:={};var maximum:={}
	var actors: Array=_encounter.combat_snapshot().actors
	for id in actors.size():
		var actor: Dictionary=actors[id]
		if actor.get("scenery",false):continue
		hostile_active=hostile_active or (actor.get("active",false)==true and actor.get("friendly",false)!=true)
		if int(actor.vitals.hull)<=0:defeated+=1
		hulls[id]=int(actor.vitals.hull)
		if int(actor.get("max_hull",0))>0:maximum[id]=int(actor.max_hull)
		if actor.get("pose") is Transform3D:distances[id]=_pose.origin.distance_to(actor.pose.origin)
		emp[id]=[int(actor.get("systems_hit_serial",0))>0,actor.get("systems_disabled",false)==true]
	var facts:={"hostile_active":hostile_active,"defeated_targets":defeated,"player_armor_depleted":int(_player.snapshot().vitals.armor)<1,"hulls":hulls,"player_distances":distances,"emp":emp}
	facts.radio_marks=_line_marks.duplicate(true)
	facts.maximum_hulls=maximum
	if _scanner!=null:facts.player_target=int(_scanner.snapshot().get("selected_actor_id",-1))
	if _action_marks.has("respawned"):facts.story_respawned_ms=int(_action_marks.respawned)
	if not _story_route.is_empty() and _story_route.point is Vector3:facts.player_route_reached=_pose.origin.distance_to(_story_route.point)<=float(_story_route.reach)
	if not _story_dock.is_empty():
		# When the status first reached each value (condition 34's hold time).
		var marks: Dictionary=_story_dock.get("status_marks",{})
		if not marks.has(int(_story_dock.status)):marks[int(_story_dock.status)]=int(_briefing.snapshot().world_elapsed_ms)
		_story_dock.status_marks=marks
		facts.merge({"story_hacks":int(_story_dock.get("hacks",0)),"story_docked":int(_story_dock.docked),"story_aboard":int(_story_dock.aboard),"story_status":int(_story_dock.status),"story_status_marks":marks.duplicate()})
	return facts

func _advance_world(milliseconds: int, preceding_reference: Vector3) -> bool:
	if _wingmen!=null:
		var crew: Dictionary=_wingmen.advance_targeting(milliseconds,_pose,_player.snapshot(),[] if _encounter==null else _encounter.combat_snapshot().actors,_random)
		if crew.is_empty():return reject(_wingmen.error)
		_random=crew.random_state
		# A casualty is recorded once in this departure's career, independently
		# of hostile kill/reward accounting and the later wreck presentation.
		for casualty in _wingmen.casualty_bodies():
			if not _objective.record_wingman_loss(casualty):return reject(_objective.error)
	if _encounter!=null:
		var before: Dictionary={} if _particles==null else _encounter.combat_snapshot()
		var actors: Dictionary=_encounter.evaluate_world(_player,_pose,milliseconds,_random,_wingmen)
		if actors.is_empty():return reject(_encounter.error)
		if _particles!=null:
			if not _particles.finish_npc_pass(before,actors.encounter.combat_snapshot(),actors.encounter.actor_events(),milliseconds,1.0):return reject(_particles.error)
		_encounter=actors.encounter;_random=actors.random_state
		if not _objective.observe_combat(_encounter):return reject(_objective.error)
		if not _audio_frame.is_empty():_audio_frame.actors=_encounter.actor_events()
	if not _scenery.update(milliseconds,preceding_reference,1.0,null,_random):return reject(_scenery.error)
	if _objective!=null and not _objective.observe_scenery(_scenery):return reject(_objective.error)
	if _portal!=null and not _portal.advance(milliseconds,_camera.snapshot().pose):return reject(_portal.error)
	if _sahi!=null and not _sahi.advance_portal(milliseconds,_camera.snapshot().pose):return reject(_sahi.error)
	_random=_scenery.random_state()
	if _void_portal!=null:
		var random: RefCounted=VoidPortal.Random.new()
		if not random.restore(_random) or not _void_portal.advance(milliseconds,_camera.snapshot().pose,random):return reject(random.error+_void_portal.error)
		_random=random.snapshot()
		if _void_portal.snapshot().frame.get("cancel_autopilot",false) and _autopilot!=null and not _autopilot.clear_target():return reject(_autopilot.error)
	_world_elapsed_ms+=milliseconds
	return true

func start_mining(paused:=false) -> RefCounted:
	error=""
	if cinematic_input_blocked():reject("The capture sequence owns flight controls");return null
	if local_departing():reject("Planet departure owns flight actions");return null
	if game_over_waiting():reject("A completed game-over screen owns flight actions");return null
	if not _unsupported_boundary.is_empty():reject("This flight requires its player-death transition");return null
	if not _station_packet.is_empty():reject("This flight has reached the station");return null
	if _approach==null or _targeting==null or paused:reject("This active flight has no supported mining approach");return null
	if _autopilot!=null and _autopilot.snapshot().active:reject("Cancel station autopilot before selecting a mining approach");return null
	var cues: Dictionary=_briefing.snapshot()
	if not cues.entry_released or dialogue_visible():reject("Mining requires released flight input");return null
	var next:=fork_for_frame()
	if not next._approach.start(next._scenery,next._targeting,_pose,_model_basis,_throttle):reject(next._approach.error);return null
	if _cargo.snapshot().free_space<=0:
		if _notices==null:reject("The cargo hold has no space for mining");return null
		next=fork_for_frame()
		if not next._notices.enqueue(27):reject(next._notices.error);return null
	elif next._notices!=null and not next._notices.enqueue(11):reject(next._notices.error);return null
	return next

func start_station_autopilot(paused:=false) -> RefCounted:
	error=""
	if cinematic_input_blocked():reject("The capture sequence owns flight controls");return null
	if local_departing():reject("Planet departure owns flight actions");return null
	if game_over_waiting():reject("A completed game-over screen owns flight actions");return null
	if not _unsupported_boundary.is_empty():reject("This flight requires its player-death transition");return null
	if not _station_packet.is_empty():reject("This flight has reached the station");return null
	if _autopilot==null or paused or dialogue_visible() or not _briefing.snapshot().entry_released:reject("Station autopilot requires released flight input");return null
	if _approach!=null and _approach.snapshot().phase!="idle":reject("Finish or cancel mining before selecting the station");return null
	var next:=fork_for_frame()
	if next._autopilot.snapshot().active and not next._autopilot.clear_target():reject(next._autopilot.error);return null
	if not next._autopilot.start(_pose):reject(next._autopilot.error);return null
	next._throttle=next._autopilot.snapshot().throttle
	if not next._queue_notice_events(next._autopilot.snapshot().events):reject(next.error);return null
	return next

func start_field_autopilot(paused:=false) -> RefCounted:
	error=""
	if paused or _autopilot==null or cinematic_input_blocked() or death_active() or local_departing() or dialogue_visible() or not _briefing.snapshot().entry_released:reject("Asteroid autopilot requires released flight input");return null
	if _approach!=null and _approach.snapshot().phase!="idle":reject("Finish or cancel mining before selecting the field");return null
	var next:=fork_for_frame()
	if not next._autopilot.start_field(_scenery.read_snapshot().center,_pose):reject(next._autopilot.error);return null
	next._throttle=next._autopilot.snapshot().throttle
	return next

func cancel_station_autopilot(paused:=false) -> RefCounted:
	error=""
	if cinematic_input_blocked():reject("The cinematic owns flight controls");return null
	if local_departing():reject("Planet departure owns flight actions");return null
	if game_over_waiting():reject("A completed game-over screen owns flight actions");return null
	if not _unsupported_boundary.is_empty():reject("This flight requires its player-death transition");return null
	if not _station_packet.is_empty():reject("This flight has reached the station");return null
	if _autopilot==null or paused or dialogue_visible():reject("No active station autopilot can be cancelled");return null
	var next:=fork_for_frame()
	if not next._autopilot.cancel():reject(next._autopilot.error);return null
	if not next._queue_notice_events(next._autopilot.snapshot().events):reject(next.error);return null
	return next

func select_planet(station_id: int, paused:=false) -> RefCounted:
	error=""
	if cinematic_input_blocked() or local_departing():reject("Finish the current departure before selecting another planet");return null
	if _local_travel==null or paused or death_active() or dialogue_visible() or not _briefing.snapshot().entry_released:reject("Planet selection requires released local flight input");return null
	if _approach!=null and _approach.snapshot().phase!="idle":reject("Finish or cancel mining before selecting a planet");return null
	var destination: Variant=_local_travel.target_position(station_id)
	if destination==null:reject(_local_travel.error);return null
	var next:=fork_for_frame()
	if not next._autopilot.start_planet(station_id,destination,_pose):reject(next._autopilot.error);return null
	next._pending_destination=station_id;next._navigation_applied=true
	next._throttle=next._autopilot.snapshot().throttle
	return next

func launch_planet(paused:=false) -> RefCounted:
	error=""
	if cinematic_input_blocked():reject("The cinematic owns flight controls");return null
	if _local_travel==null or paused or death_active() or dialogue_visible() or not _briefing.snapshot().entry_released:reject("Planet departure requires released local flight input");return null
	if _approach!=null and _approach.snapshot().phase!="idle":reject("Finish or cancel mining before departing");return null
	var next:=fork_for_frame()
	if not next._local_travel.launch_acquired():reject(next._local_travel.error);return null
	if not next._begin_local_departure():reject(next.error);return null
	return next

func _begin_local_departure() -> bool:
	if not _booster.cancel():return reject(_booster.error)
	# Source launch fixes the camera eye, but the next positive camera update
	# still looks at the moving ship. Acquisition runs after this frame's camera;
	# changing the shot must not recompute or move the already accepted view.
	_shot.merge({"mode":"fixed_eye","eye":_camera.snapshot().eye,"inherit_target_up":true},true)
	_collision_enabled=false
	# Reset the installed primary timers, preserving live projectiles and their
	# handles. The source category reset does not destroy bullets already fired.
	if not _encounter.reset_primary_fire_intervals():return reject(_encounter.error)
	return true

func local_departing() -> bool:
	return _local_travel!=null and _local_travel.snapshot().phase!="flight"

func gate_coasting() -> bool:
	return _gate_transit!=null and _gate_transit.snapshot().phase=="flight" and _gate_transit.snapshot().coasting

func gate_modal() -> bool:
	return _gate_transit!=null and _gate_transit.snapshot().phase in ["confirmation","map"]

func gate_departing() -> bool:
	return _gate_transit!=null and _gate_transit.snapshot().phase in ["departing","ready"]

func control_throttle() -> float:return _throttle

func gate_animation_owner() -> RefCounted:
	return _gate_transit.animation() if _gate_transit!=null else (_gate_animation.fork_for_frame() if _gate_animation!=null else null)

func _gate_input_available(paused: bool) -> bool:
	if _gate_transit==null or paused or death_active() or dialogue_visible() or not _briefing.snapshot().entry_released or local_departing():return reject("Gate selection requires released ordinary flight")
	if not _station_packet.is_empty() or not _unsupported_boundary.is_empty():return reject("Finish the current flight transition before selecting the gate")
	if _approach!=null and _approach.snapshot().phase!="idle":return reject("Finish or cancel mining before selecting the gate")
	return true

func start_gate_autopilot(paused:=false) -> RefCounted:
	error=""
	if not _gate_input_available(paused):return null
	if cinematic_input_blocked():reject("The cinematic owns flight controls");return null
	var next:=fork_for_frame()
	if not next._autopilot.start_gate(_pose):reject(next._autopilot.error);return null
	next._throttle=next._autopilot.snapshot().throttle
	return next

func select_gate_destination(station_id: int,paused:=false) -> RefCounted:
	error=""
	if not _gate_input_available(paused):return null
	if cinematic_input_blocked():reject("The cinematic owns flight controls");return null
	if not _gate_destinations.has(station_id):reject("This destination does not yet have a supported ordinary world");return null
	var next:=start_gate_autopilot(paused)
	if next==null:return null
	if not next._gate_transit.set_course(station_id):reject(next._gate_transit.error);return null
	next._pending_destination=station_id;next._navigation_applied=true
	return next

func select_map_destination(station_id: int,paused:=false) -> RefCounted:
	error=""
	if _system_navigation==null:return select_planet(station_id,paused)
	if not _navigation_destinations.has(station_id):reject("This destination has no admitted flight");return null
	var course: Dictionary=_system_navigation.course(int(_entry.location.station_id),station_id)
	if course.is_empty() or int(course.jump_count)>1:reject("Choose a location in this system or a directly linked system");return null
	var next: RefCounted
	match course.guidance.kind:
		"planet":next=select_planet(int(course.guidance.station_id),paused)
		"gate":next=select_gate_destination(station_id,paused)
		_:reject("The ship is already at this destination");return null
	if next==null:return null
	next._pending_destination=station_id;next._navigation_applied=true
	return next

func queue_map_destination(station_id: int,drive:=false) -> RefCounted:
	if entry_released():reject("Queue a departure course before flight input is released");return null
	if _system_navigation!=null and not _navigation_destinations.has(station_id):reject("The departure course has no admitted destination");return null
	var next:=fork_for_frame();next._pending_destination=station_id;next._navigation_applied=false;next._queued_drive=drive
	return next

func choose_gate_confirmation(result: int,paused:=false) -> RefCounted:
	error=""
	if not _gate_input_available(paused):return null
	var next:=fork_for_frame()
	if not next._gate_transit.choose_confirmation(result):reject(next._gate_transit.error);return null
	if next.gate_departing() and not next._begin_gate_departure():reject(next.error);return null
	return next

func close_gate_map(accepted: bool,destination: int=-1,paused:=false) -> RefCounted:
	error=""
	if not _gate_input_available(paused) or _gate_transit.snapshot().phase!="map":reject("No gate map awaits a choice");return null
	var next:=fork_for_frame()
	if accepted:
		if not _gate_destinations.has(destination):reject("This destination does not yet have a supported ordinary world");return null
		if not next._gate_transit.set_course(destination):reject(next._gate_transit.error);return null
		next._pending_destination=destination;next._navigation_applied=true
	if not next._gate_transit.close_map(accepted):reject(next._gate_transit.error);return null
	if accepted:
		if not next._begin_gate_departure():reject(next.error);return null
	else:
		next._pose=next._gate_transit.snapshot().player_pose;next._statistics_pose=next._pose*Transform3D(next._model_basis,Vector3.ZERO)
		next._throttle=next._gate_transit.snapshot().speed/next._gate_cruise_speed
		if not next._autopilot.clear_target():reject(next._autopilot.error);return null
	return next

func _begin_gate_departure() -> bool:
	var gate: Dictionary=_gate_transit.snapshot()
	if not gate_departing() or not gate.has("departure_permissions"):return reject("Gate departure requires its original player permissions")
	if not _booster.cancel():return reject(_booster.error)
	if not _autopilot.clear_target() or not _player.set_permissions(true,gate.departure_permissions.damage_allowed):return reject(_autopilot.error+_player.error)
	if gate.reset_primary_fire_intervals and not _encounter.reset_primary_fire_intervals():return reject(_encounter.error)
	_pose=gate.player_pose;_statistics_pose=_pose;_model_basis=Basis.IDENTITY;_throttle=gate.speed/_gate_cruise_speed
	_collision_enabled=gate.departure_permissions.collision_enabled;_camera_follow_enabled=true
	_shot.merge({"mode":"fixed_eye","eye":gate.camera_position,"inherit_target_up":false},true)
	return true

func prepare_gate_arrival() -> Dictionary:
	return {} if _gate_transit==null or death_active() else _gate_transit.arrival_request()

func prepare_local_arrival() -> Dictionary:
	if _local_travel==null or death_active():return {}
	return _local_travel.prepare_arrival()

func construct_local_arrival(bindings: RefCounted, catalogues: RefCounted, environment_seconds: Variant, unix_seconds: Variant, large_display:=true, body_resources: RefCounted=null, effect_resources: RefCounted=null,location_settings: Dictionary={},location_library: RefCounted=null) -> RefCounted:
	error=""
	if prepare_local_arrival().is_empty() or _objective==null or _equipment==null:reject("Complete the surviving local flight before constructing arrival");return null
	return _construct_arrival(bindings,catalogues,prepare_local_arrival(),environment_seconds,unix_seconds,large_display,body_resources,effect_resources,location_settings,location_library,false)

func construct_gate_arrival(bindings: RefCounted,catalogues: RefCounted,environment_seconds: Variant,unix_seconds: Variant,large_display:=true,body_resources: RefCounted=null,effect_resources: RefCounted=null,location_settings: Dictionary={},location_library: RefCounted=null) -> RefCounted:
	error=""
	if not _objective is ContractObjective or _equipment==null:reject("Complete the surviving gate flight before constructing arrival");return null
	var packet:=GateArrival.packet(bindings,catalogues,prepare_gate_arrival(),int(_objective.snapshot().campaign_cursor))
	if packet.is_empty():reject("Complete the surviving gate flight before constructing arrival");return null
	return _construct_arrival(bindings,catalogues,packet,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,location_settings,location_library,true)

func _construct_arrival(bindings: RefCounted,catalogues: RefCounted,packet: Dictionary,environment_seconds: Variant,unix_seconds: Variant,large_display: bool,body_resources: RefCounted,effect_resources: RefCounted,location_settings: Dictionary,location_library: RefCounted,gate: bool,drive_arrival: RefCounted=null) -> RefCounted:
	var result:=Construction.new()
	if not result.prepare_arrival_viewport(_viewport):reject(result.error);return null
	var objective: Dictionary=_objective.snapshot()
	objective.station_response_flags=station_response_flags()
	var contracts: RefCounted
	if _objective is ContractObjective:
		contracts=_objective.retained_for_arrival(_encounter)
		if contracts==null:reject(_objective.error);return null
	elif _entry.campaign_cursor==26 and objective.campaign_cursor==27:
		contracts=_retained_sahi_return_career(objective.progress)
		if contracts==null:return null
	if contracts!=null:
		if not location_settings.is_empty() and not contracts.select_location(bindings,catalogues,location_library,int(packet.station_id),location_settings,_random,unix_seconds):reject(contracts.error);return null
		objective.progress=contracts.snapshot().progress
	var prepared: bool=result.prepare_drive_arrival(bindings,catalogues,drive_arrival,_player,_equipment,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,objective,contracts,location_library) if drive_arrival!=null else result.prepare_gate_arrival(bindings,catalogues,_gate_transit,_player,_equipment,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,objective,contracts,location_library) if gate else result.prepare_local_arrival(bindings,catalogues,_local_travel,_player,_equipment,environment_seconds,unix_seconds,large_display,body_resources,effect_resources,objective,contracts,location_library)
	if not prepared:reject(result.error);return null
	if _pending_destination>=0 and _pending_destination!=int(packet.station_id) and not result.retain_navigation_destination(_pending_destination):reject(result.error);return null
	return result.selected40_builder() if result.selected40_builder()!=null else result

func station_response_flags() -> Dictionary:
	var flags:=_station_response_flags.duplicate()
	if _encounter!=null and (_entry.campaign_cursor in [10,11,12] or _objective is ContractObjective):
		var reaction: Dictionary=_encounter.career_snapshot().get("provocation",{})
		if not reaction.is_empty():flags[int(reaction.station_id)]=bool(reaction.station_response_flag)
	return flags

func local_travel_owner() -> RefCounted:return null if _local_travel==null else _local_travel.fork()

func cancel_mining(paused:=false) -> RefCounted:
	error=""
	if cinematic_input_blocked():reject("Capture owns flight actions");return null
	if local_departing():reject("Planet departure owns flight actions");return null
	if game_over_waiting():reject("A completed game-over screen owns flight actions");return null
	if not _unsupported_boundary.is_empty():reject("This flight requires its player-death transition");return null
	if _approach==null or paused or dialogue_visible():reject("No active mining approach can be cancelled");return null
	if _mining!=null and _mining.has_active_drill():reject("Use the mining stop action to finish an active drill");return null
	var next:=fork_for_frame()
	if not next._release_mining_approach():reject(next.error);return null
	if next._notices!=null and not next._notices.enqueue(6):reject(next._notices.error);return null
	return next

func stop_mining(paused:=false) -> RefCounted:
	error=""
	if cinematic_input_blocked():reject("Capture owns flight actions");return null
	if local_departing():reject("Planet departure owns flight actions");return null
	if game_over_waiting():reject("A completed game-over screen owns flight actions");return null
	if not _unsupported_boundary.is_empty():reject("This flight requires its player-death transition");return null
	if _mining==null or paused or dialogue_visible():reject("No active drilling input is available");return null
	var next:=fork_for_frame()
	next._begin_mining_audio_batch()
	var operation: Dictionary=next._mining.stop(next._scenery,next._cargo,next._random)
	if operation.is_empty():reject(next._mining.error);return null
	next._mining=operation.session;next._scenery=operation.scenery;next._cargo=operation.cargo;next._random=operation.random_state
	next._queue_mining_audio(next._mining.snapshot().events)
	if next._equipment!=null and not next._equipment.retain_flight_cargo(next._cargo.snapshot()):reject(next._equipment.error);return null
	if operation.get("release_approach",false) and not next._retain_mining_extraction(next._mining.snapshot().extraction):reject(next.error);return null
	if not next._release_mining_approach():reject(next.error);return null
	return next

## Retain one detached acknowledged station at the actual departure boundary.
## Frames share it read-only; docking obtains a fork and updates live pools/cargo.
func retain_departure_station(station: RefCounted,bindings: RefCounted,catalogues: RefCounted) -> bool:
	if _entry.get("campaign_cursor") not in [10,11,12]:return true
	var trip:=Travel.journey(bindings.mido_travel,int(_entry.campaign_cursor))
	if trip.is_empty() or _entry.location.station_id!=int(trip.from_station_id):return true
	if not is_instance_of(station,load("res://src/simulation/station_entry.gd")) or station.prepare_departure(bindings,catalogues)!=_entry.departure:return reject("Return docking requires this flight's acknowledged departure station")
	var rules:=OrdinaryFlight.departure_docking(bindings,int(_entry.campaign_cursor))
	if rules.is_empty():return reject("This departure has no supported return docking")
	_departure_station=station.fork();_return_rules=rules
	return true

func departure_station_owner() -> RefCounted:return null if _departure_station==null else _departure_station.fork()

func _evaluate_station_return() -> bool:
	var volume:=int(_station.point_volume(_pose.origin))
	var autopilot: Dictionary=_autopilot.snapshot()
	var selected: bool=autopilot.active and autopilot.target_kind=="station"
	var objective: Dictionary=_objective.snapshot()
	var local_visit: bool=_return_rules.get("local_visit",false)
	var contract_station: bool=_return_rules.get("contract_station",false)
	if not local_visit and objective.campaign_cursor==int(_return_rules.departing_cursor):
		if selected and volume>=0 and not _notices.enqueue(int(_return_rules.restricted_notice)):return reject(_notices.error)
		return true
	if not selected or (volume<0 and not _station_contact):return true
	if objective.has("campaign_visit") and not objective.campaign_visit.acknowledged:
		if not _notices.enqueue(int(_return_rules.restricted_notice)):return reject(_notices.error)
		return true
	if _return_rules.get("sahi_return",false):
		# Until final result Next, the selected kind4 mission forbids contact.
		if not _notices.enqueue(int(_return_rules.restricted_notice)):return reject(_notices.error)
		return true
	if objective.campaign_cursor!=int(_return_rules.campaign_cursor) or objective.dialogue.visible:return reject("Station arrival changed its current mission")
	if not local_visit and (not objective.get("combat_objective_acknowledged",objective.cargo_objective_acknowledged) or not objective.station_return_required):return reject("Station return requires its acknowledged cargo instructions")
	var contracts: RefCounted
	if contract_station:
		if _objective is ContractObjective:
			if contract_result_pending():return reject("The station requires its acknowledged contract result")
			contracts=_objective.retained_for_arrival(_encounter)
			if contracts==null:return reject(_objective.error)
			objective.progress=contracts.snapshot().progress
		elif _entry.campaign_cursor==26 and objective.campaign_cursor==27:
			if not _objective.observe_combat(_encounter):return reject(_objective.error)
			objective=_objective.snapshot()
			if _convoy_career!=null:
				contracts=_retained_sahi_return_career(objective.progress)
				if contracts==null:return false
		else:return reject("The station requires the retained contract flight")
	elif _mission_context!=null and _mission_context.advances_campaign():
		if not _mission_context.matches_source(_story_bindings,_entry.departure) or not _mission_context.accepts_result(objective.campaign_cursor,objective.mission,_entry.location.station_id) or not objective.get("combat_objective_acknowledged",false):return reject("Mission docking lost its acknowledged source result")
		contracts=contract_owner()
		if contracts==null:return reject("Dekato docking lost its retained native career")
	elif _return_rules.get("departure_return",false):
		if _departure_station==null or objective.mission!=_entry.departure.mission:return reject("Return docking lost its unfinished local journey")
	elif _return_rules.get("alioth_return",false) or _return_rules.get("bakka_return",false):
		if _convoy_career==null or _story_bindings==null:return reject("Story docking lost its retained career")
		contracts=_convoy_career.fork()
		var retained: bool=contracts.retain_bakka_return_progress(_story_bindings,objective.progress) if _return_rules.get("bakka_return",false) else contracts.retain_alioth_return_progress(_story_bindings,objective.progress)
		if not retained:return reject(contracts.error)
		if objective.mission!={"kind":int(_return_rules.mission_kind),"station_id":int(_return_rules.station_id),"reward":0,"bonus":0,"source_parameter":0}:return reject("Story docking lost its acknowledged return mission")
	else:
		var mission:={"kind":int(_return_rules.mission_kind),"station_id":int(_return_rules.station_id),"reward":0,"bonus":0}
		if local_visit or _return_rules.get("alioth_return",false):mission.source_parameter=0
		if objective.mission!=mission:return reject("Station return mission does not match the current station")
	var held: Dictionary=_cargo.snapshot()
	if held.used<int(_return_rules.minimum_delivered_cargo) or _cargo.field_identity()!=_scenery.presentation_identity() or not _cargo.matches_mined_field(_scenery.mining_snapshot()):return reject("Station return cargo disagrees with its mining field")
	var player: Dictionary=_player.snapshot()
	# Flight may have consumed installed secondary ammunition. The retained
	# inventory is authoritative for arrival; the entry seed describes launch.
	var seed: Dictionary=_entry.departure.loadout if _equipment==null else _equipment.snapshot().loadout
	var cached:=Cache.station_arrival_cache(_return_rules,seed,player)
	if cached.is_empty():return reject("Station arrival cannot preserve the current player pools")
	_station_packet={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,
		"campaign_cursor":int(_return_rules.campaign_cursor),"source_state":int(_return_rules.source_state),
		"loadout":seed.duplicate(true),"player":player,"player_cache":cached,"cargo":held,
		"progress":objective.progress.duplicate(true),"mission":objective.mission.duplicate(true),
		"source_ship_configuration":_entry.departure.source_ship_configuration,
		"world_elapsed_ms":_briefing.snapshot().world_elapsed_ms,
		"docking":{"station_id":int(_return_rules.station_id),"pre_motion_contact":_station_contact,"post_motion_volume_index":volume,"position":_pose.origin}}
	if _return_rules.get("departure_return",false):_station_packet.departure_return=true
	if _equipment!=null:_station_packet.equipment=_equipment.snapshot()
	if local_visit or contract_station or _return_rules.get("bakka_return",false):_station_packet.station_response_flags=station_response_flags()
	if contracts!=null:_station_packet.contracts=contracts.snapshot()
	if _return_rules.get("dekato_return",false):
		_station_packet.dekato_source_receipt=_entry.departure.dekato_source_receipt.duplicate(true)
		_convoy_career=contracts
	if _return_rules.get("alioth_return",false) or _return_rules.get("bakka_return",false) or (_entry.campaign_cursor==26 and objective.campaign_cursor==27):_convoy_career=contracts
	return true

func prepare_station() -> Dictionary:
	error=""
	if _return_rules.is_empty() or _station_packet.is_empty():reject("Reach the station with the acknowledged return mission before preparing entry");return {}
	return _station_packet.duplicate(true)

func prepare_convoy_station() -> Dictionary:
	error=""
	if not convoy_arrival_required() or _convoy_career==null or _equipment==null or _objective==null:return _reject_convoy_station("Finish the surviving capture before entering Alioth")
	var held: Dictionary=_cargo.snapshot()
	if not _cargo.matches_mined_field(_scenery.mining_snapshot()) or held!=_equipment.snapshot().cargo:return _reject_convoy_station("The capture lost its actual mining cargo")
	var state:=snapshot()
	return {"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":14,
		"arrival":_convoy.snapshot().arrival.duplicate(true),"loadout":_equipment.snapshot().loadout,
		"equipment":_equipment.snapshot(),"cargo":held,"player":_player.snapshot(),
		"player_cache":_player.cache_snapshot(),"progress":state.progress.duplicate(true),
		"contracts":_convoy_career.snapshot(),"world_elapsed_ms":state.world_elapsed_ms,
		"source_ship_configuration":_entry.departure.source_ship_configuration}

func _reject_convoy_station(message: String) -> Dictionary:
	reject(message);return {}

func convoy_career_owner() -> RefCounted:
	return null if _convoy_career==null else _convoy_career.fork()

func _release_mining_approach() -> bool:
	var index: int=_approach.snapshot().object_index
	if not _approach.cancel():return reject(_approach.error)
	if _engine_particles!=null and not _engine_particles.set_engine_enabled(true):return reject(_engine_particles.error)
	_camera_follow_enabled=true
	if death_active() and not _death.sample_camera(_camera.snapshot().pose,true):return reject(_death.error)
	if not _scenery.set_spin_enabled(index,true):return reject(_scenery.error)
	_targeting.clear_selection()
	return true

func _queue_notice_events(events: Array) -> bool:
	if _notices==null:return true
	for event in events:
		if event.get("kind")=="notification" and not _notices.enqueue(event.get("source_id")):return reject(_notices.error)
	return true

func _begin_mining_audio_batch() -> void:
	if not _mining_audio.is_empty():_mining_audio.events=[]

func _queue_mining_audio(events: Array) -> void:
	# Native mining owners emit only their accepted source cues. Keep one
	# ordered batch per operation; a manual stop has no simulation-time delta.
	for event in events:
		var kind: String=event.get("kind","")
		if kind not in ["sound","audio_event","stop_audio_event"]:continue
		if _mining_audio.events.is_empty():_mining_audio.serial+=1
		_mining_audio.events.append({"action":"stop" if kind=="stop_audio_event" else "start","source_id":int(event.source_id)})

func _retain_mining_hint(seen: bool) -> void:
	if not seen and not _briefing.snapshot().progress.has("mining_failure_hint_seen"):return
	_briefing.retain_mining_hint(seen)
	if _objective!=null:_objective.retain_mining_hint(seen)
	if _convoy_career!=null:
		_convoy_career=_convoy_career.fork()
		_convoy_career.retain_mining_hint(seen)

func _retain_mining_extraction(receipt: Dictionary) -> bool:
	if not _briefing.retain_mining_extraction(receipt):return reject(_briefing.error)
	if _objective!=null and not _objective.retain_mining_extraction(receipt):return reject(_objective.error)
	if _convoy_career!=null:
		var candidate: RefCounted=_convoy_career.fork()
		if not MiningExtraction.retain_contract_owner(candidate,receipt):return reject("Mining lifetime progress belongs to another retained career")
		_convoy_career=candidate
	return true

func equipment_owner() -> RefCounted:return null if _equipment==null else _equipment.fork()

func contract_owner() -> RefCounted:
	if _ordinary_void_source!=null and _entry.location.station_id<0:return null if _convoy_career==null else _convoy_career.fork()
	if _objective is ContractObjective:return _objective.retained_for_arrival(_encounter) if not _station_packet.is_empty() else _objective.contract_owner()
	# Final mission Next already committed the complete career. The frozen
	# pending station frame must not re-admit it through an older convoy stage.
	if mission_station_return_required():return null if _convoy_career==null else _convoy_career.fork()
	if _mission_context!=null and _mission_context.advances_campaign() and _convoy_career!=null:
		var career: RefCounted=_convoy_career.fork()
		if not career.retain_dekato_progress(_story_bindings,_objective.snapshot().progress):reject(career.error);return null
		return career
	if _entry.has("bakka_context") and _convoy_career!=null:return _convoy_career.fork()
	if _entry.campaign_cursor!=26 or _convoy_career==null:return null
	var objective: Dictionary=_objective.snapshot()
	return _retained_sahi_return_career(objective.progress) if objective.campaign_cursor==27 else null

func _retained_sahi_return_career(progress: Dictionary) -> RefCounted:
	if _convoy_career==null:reject("The Sahi return lost its retained career");return null
	var contracts: RefCounted=_convoy_career.fork()
	if not contracts.retain_sahi_return_progress(_story_bindings,progress):reject(contracts.error);return null
	return contracts

## The frame publishes acknowledgement, result retirement and the retained
## career together. A failure or rejected ledger leaves its prior frame intact.
func _finish_bakka_navigation(previous: Dictionary) -> bool:
	var result: Dictionary=_objective.snapshot()
	if result.has("campaign_failure"):
		var receipt: Dictionary=result.campaign_failure
		_game_over_packet={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":result.campaign_cursor,"source_state":receipt.source_state,"campaign_failure":receipt.duplicate(true)}
	elif result.campaign_cursor!=previous.campaign_cursor:
		if previous.campaign_cursor!=36 or result.campaign_cursor!=37 or not result.combat_objective_acknowledged or _convoy_career==null:return reject("B'akka acknowledgement lost its retained campaign career")
		var career: RefCounted=_convoy_career.fork()
		if not career.advance_bakka_story(_story_bindings,previous.progress):return reject(career.error)
		if career.snapshot().progress!=result.progress:return reject("B'akka acknowledgement changed its earned combat progress")
		var rules:=OrdinaryFlight.docking(_story_bindings,result.campaign_cursor)
		if rules.is_empty() or _autopilot==null or _notices==null:return reject("B'akka acknowledgement lost its physical return support")
		if not _encounter.acknowledge_bakka_result():return reject(_encounter.error)
		_convoy_career=career;_return_rules=rules
	return true

func contract_result_pending() -> bool:
	return _objective is ContractObjective and _objective.result_pending()

## A selected native flight can retire its result and select the original next
## mission. Public admission and an earned career/save remain separate owners.
func _finish_mission_navigation(previous: Dictionary) -> bool:
	var result: Dictionary=_objective.snapshot()
	if result.has("campaign_failure"):
		var receipt: Dictionary=result.campaign_failure
		_game_over_packet={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":result.campaign_cursor,"source_state":receipt.source_state,"campaign_failure":receipt.duplicate(true)}
	elif result.campaign_cursor!=previous.campaign_cursor:
		var recipe: Dictionary=_mission_context.recipe()
		if recipe.is_empty() or result.campaign_cursor!=recipe.next_cursor or not result.combat_objective_acknowledged:return reject("Mission acknowledgement lost its native result")
		if not _mission_context.matches_source(_story_bindings,_entry.departure):return reject("Mission acknowledgement changed its explicit source provenance")
		if _entry.departure.has("contracts") and _convoy_career==null:return reject("Dekato acknowledgement lost its retained career")
		var career: RefCounted=null
		if _convoy_career!=null:
			career=_convoy_career.fork()
			if not career.advance_mission_story(_story_bindings,_mission_context,previous.progress):return reject(career.error)
			if career.snapshot().progress!=result.progress:return reject("Dekato acknowledgement changed its earned combat progress")
		var docking: Dictionary=recipe.docking.duplicate(true)
		if not docking.is_empty() and (career==null or _autopilot==null or _station==null):return reject("Mission acknowledgement lost its retained physical return")
		var station_return:={}
		if recipe.get("continuation",{}).get("kind")=="station":
			if career==null or recipe.next_mission.station_id!=recipe.continuation.station_id:return reject("Mission acknowledgement lost its automatic station destination")
			station_return={"source_cursor":recipe.cursor,"campaign_cursor":recipe.next_cursor,"station_id":recipe.continuation.station_id}
		if not _encounter.acknowledge_mission_result():return reject(_encounter.error)
		_convoy_career=career;_return_rules=docking
		_mission_station_return=station_return
		if not station_return.is_empty():_mission_station_identity=RefCounted.new()
	return true

func acknowledge_contract_result(serial: int,paused:=false) -> RefCounted:
	error=""
	if paused or not contract_result_pending() or not _station_packet.is_empty():reject("No active contract result awaits acknowledgement");return null
	var next:=fork_for_frame()
	var result: Dictionary=next._objective.acknowledge(next._encounter,serial)
	if result.is_empty():reject(next._objective.error);return null
	if result.clear_player_control:
		next._route=null
	if result.clear_world_path:
		# Contract routes are copied into each actor at construction. Clearing
		# the shared path does not destroy their retained individual routes.
		next._world_path=[]
		next._world_route=null
	return next

func drill_owner() -> RefCounted:return null if _mining==null else _mining.drill_owner()
func entry_released() -> bool:return _briefing!=null and _briefing.snapshot().entry_released
func can_skip_entry() -> bool:
	return _mission_context!=null and _briefing!=null and not entry_released() and _briefing.snapshot().entry_elapsed_ms>0 and not dialogue_visible() and not death_active() and not local_departing() and not cinematic_input_blocked() and _unsupported_boundary.is_empty()

func skip_entry(paused:=false) -> RefCounted:
	if paused or not can_skip_entry():reject("The arrival introduction is not awaiting skip");return null
	var next:=fork_for_frame()
	if not next._briefing.skip_entry():reject(next._briefing.error);return null
	var frame: RefCounted=next.evaluate(0)
	if frame==null:reject(next.error)
	return frame
func has_local_travel() -> bool:return _local_travel!=null
func station_owner() -> RefCounted:return null if _station==null else _station.fork_for_frame()
func mission_context_owner() -> RefCounted:return _mission_context
func mission_station_return_required() -> bool:return not _mission_station_return.is_empty()
func mission_station_return_identity() -> RefCounted:return _mission_station_identity
func encounter_owner() -> RefCounted:return null if _encounter==null else _encounter.fork_for_frame()
func wingman_owner() -> RefCounted:return null if _wingmen==null else _wingmen.fork_for_frame()
func tractor_owner() -> RefCounted:return null if _tractor==null else _tractor.fork_for_frame()
func destruction_owner() -> RefCounted:return null if _death==null else _death.fork_for_frame()
func damage_particle_owner() -> RefCounted:return null if _particles==null else _particles.fork_for_frame()
## Read-only during presentation of this accepted frame.
func scenery_presentation_owner() -> RefCounted:return _scenery

func turret_state() -> Dictionary:return {} if _encounter==null else _encounter.turret_state()
func toggle_turret() -> RefCounted:
	error=""
	if not turret_state().get("ready",false) or not entry_released() or dialogue_visible() or death_active() or local_departing() or cinematic_input_blocked() or _approach.snapshot().phase!="idle" or (_autopilot!=null and _autopilot.snapshot().active):reject("The turret is unavailable during this operation");return null
	var next:=fork_for_frame()
	next._encounter=_encounter.set_turret_active(not _encounter.turret_active())
	next._pilot.angular_units=Vector2.ZERO;next._pilot.lateral_units_per_millisecond=0.0
	return next

## Ships with an automatic turret switch its fire off and on (original HUD button).
func toggle_auto_turret() -> RefCounted:
	error=""
	var turret:=turret_state()
	if not turret.get("auto",false) or not entry_released() or dialogue_visible() or death_active():reject("The auto turret is unavailable now");return null
	var enabled: bool=not turret.get("auto_enabled",true)
	var next:=fork_for_frame()
	next._encounter=_encounter.set_auto_turret_enabled(enabled)
	if next._notices!=null:
		if not next._notices.enqueue_auto_turret(enabled):reject(next._notices.error);return null
	return next

## Systems the story opened in flight join the map and the drive at once.
func _refresh_story_navigation(story_state: Dictionary) -> bool:
	var career: Dictionary=contract_owner().snapshot()
	var navigation:=SystemNavigation.new()
	if not navigation.configure(_story_bindings,_story_catalogues,career.get("lounges",{}).get("system_availability")):return reject(navigation.error)
	var observation:=_entry.duplicate();observation.contracts=career;observation.mission=story_state.mission;observation.campaign_cursor=story_state.campaign_cursor
	var destinations:=Context.navigation_destinations(_story_bindings,_story_catalogues,observation)
	if _drive!=null:
		var drive: RefCounted=_drive.with_navigation(_story_catalogues,navigation,destinations)
		if drive==null:return reject(_drive.error)
		_drive=drive
	_system_navigation=navigation;_navigation_destinations=destinations
	return true

func drive_state() -> Dictionary:return {} if _drive==null else _drive.snapshot()
func drive_departing() -> bool:return _drive!=null and _drive.departing()
func drive_fitted() -> bool:return _drive!=null and _drive.available()
func drive_available() -> bool:return _drive!=null and _drive.ready()
func drive_quote(station_id: int) -> Dictionary:return {} if _drive==null else _drive.quote(station_id,_cargo.quantity(Drive.Definitions.ENERGY_ITEM))
func drive_permits_mission() -> bool:
	if _objective==null:return false
	if story_drive_rule().get("allow",false):return true
	if _ordinary_void_source!=null and _entry.location.station_id<0:return true
	var current: Dictionary=_objective.snapshot()
	var job: Dictionary=current.get("contracts",{}).get("mission",{})
	if not job.is_empty():return Drive.permits_mission(job)
	var context: Dictionary=_entry.departure.get("free_context",{})
	if not context.get("mission_story",false):return true
	return Drive.permits_mission({"kind":context.get("mission_kind",-1),"completed":context.get("mission_completed",false)})

## The story's drive rule for this flight (see valkyrie_flight_definitions.DRIVE).
func story_drive_rule() -> Dictionary:
	var flights=load("res://src/content/valkyrie_flight_definitions.gd")
	if _story_bindings==null or not flights.Campaign.saved_story(_story_bindings,_entry.get("campaign_cursor")):return {}
	return flights.drive_rule(int(_entry.campaign_cursor))

func drive_selection() -> RefCounted:
	if not drive_available():reject("Khador Drive is not ready");return null
	var next:=fork_for_frame()
	if not drive_permits_mission() and not next._notices.enqueue(21):reject(next._notices.error);return null
	return next

func drive_map_observation() -> Dictionary:
	var result:=snapshot();var quotes:={}
	for station_id in _navigation_destinations:
		if station_id==result.location.station_id:continue
		var quote:=drive_quote(station_id)
		if not quote.is_empty():quotes[station_id]=quote
	result.drive_mode=true;result.drive_quotes=quotes;result.drive_void_quote=drive_quote(-1);result.drive_void_prompt=true
	return result

func start_drive(station_id: int,story_jump:=false) -> RefCounted:
	error=""
	if not drive_available() or not entry_released() or death_active() or dialogue_visible() or cinematic_input_blocked() or local_departing():reject("Khador Drive is unavailable during this operation");return null
	var next:=fork_for_frame()
	if not story_jump and not drive_permits_mission():
		if not next._notices.enqueue(21):reject(next._notices.error);return null
		return next
	# A story mission may need passenger berths before its target can be set.
	var loadout: Dictionary=next._equipment.snapshot().loadout;var fitted: Array=Array(loadout.get("equipment_ids",[]))
	var sorts: Array=[] if _story_catalogues==null else fitted.map(func(id):return int(_story_catalogues.tables.items[int(id)].properties.get(2,-1)))
	var refusal: int=load("res://src/content/valkyrie_campaign_definitions.gd").entry_refusal(int(_entry.campaign_cursor),station_id,_passenger_berths(_story_catalogues,loadout),fitted,sorts,int(loadout.get("ship_id",-1)))
	if not story_jump and refusal>=0:
		if not next._notices.enqueue(refusal):reject(next._notices.error);return null
		return next
	# Volatile cargo aboard: the Khador Drive refuses to jump (text 601).
	if not story_jump and next._volatile_carried():
		if not next._notices.enqueue(load("res://src/content/valkyrie_campaign_definitions.gd").ENTRY_NOTICE_BASE+int(Worlds.VOLATILE_GOODS.drive_text_id)):reject(next._notices.error);return null
		return next
	var operation: Dictionary=next._drive.evaluate_request(station_id,next._cargo,story_jump)
	if operation.is_empty() or not operation.started:reject(next._drive.error if operation.is_empty() else "Not enough energy cells for this jump");return null
	next._equipment=next._equipment.fork()
	if not next._equipment.retain_flight_cargo(operation.cargo.snapshot()):reject(next._equipment.error);return null
	var capability:=Context.new()
	if operation.quote.mode=="void_entry":
		if not capability.admit_drive_void(_story_bindings,_story_catalogues,next._equipment.snapshot().loadout,contract_owner()):reject(capability.error);return null
	elif operation.quote.mode=="void_exit":capability=_ordinary_void_source
	elif not capability.admit_drive_arrival(_story_bindings,_story_catalogues,next._equipment.snapshot().loadout,contract_owner(),station_id):reject(capability.error);return null
	if int(operation.quote.cost)>0 and not next._notices.enqueue_energy_spent(int(operation.quote.cost)):reject(next._notices.error);return null
	next._drive=operation.drive;next._cargo=operation.cargo;next._drive_arrival=capability
	next._pending_destination=-1;next._navigation_applied=true
	if not next._autopilot.clear_target():reject(next._autopilot.error);return null
	return next

func _advance_drive(milliseconds: int) -> bool:
	var departing:=drive_departing()
	if not _drive.advance(milliseconds,_pose):return reject(_drive.error)
	if not drive_departing():return true
	if not departing:
		if not _booster.cancel() or not _autopilot.clear_target() or not _player.set_permissions(true,false):return reject(_booster.error+_autopilot.error+_player.error)
		if _encounter.turret_active():_encounter=_encounter.set_turret_active(false)
		_collision_enabled=false
		_shot.merge({"mode":"fixed_eye","inherit_target_up":false},true)
	_shot.eye=_drive.snapshot().camera_position
	return true

func prepare_drive_arrival() -> Dictionary:return {} if _drive==null or death_active() else _drive.arrival_request()
func construct_drive_arrival(bindings: RefCounted,cat: RefCounted,environment_seconds: Variant,unix_seconds: Variant,large_display:=true,bodies: RefCounted=null,effects: RefCounted=null,settings: Dictionary={},library: RefCounted=null) -> RefCounted:
	if prepare_drive_arrival().is_empty() or _drive_arrival==null:reject("Finish the Khador transit before arriving");return null
	var trip:=prepare_drive_arrival()
	if trip.mode in ["void_entry","void_exit"]:return _construct_void_trip(bindings,cat,_drive_arrival,trip.mode=="void_entry",environment_seconds,unix_seconds,large_display,bodies,effects,settings,library)
	return _construct_arrival(bindings,cat,_drive_arrival.arrival_packet(),environment_seconds,unix_seconds,large_display,bodies,effects,settings,library,false,_drive_arrival)

func cloak_state() -> Dictionary:return {} if _player==null else _player.cloak_state()
func booster_state() -> Dictionary:return {} if _booster==null else _booster.snapshot()
func cloak_input_permitted() -> bool:
	return _equipment!=null and entry_released() and not death_active() and _player.snapshot().vitals.hull>0 and not dialogue_visible() and not cinematic_input_blocked() and not local_departing() and not gate_departing()

func booster_input_permitted() -> bool:
	return _booster!=null and entry_released() and not death_active() and _player.snapshot().vitals.hull>0 and not dialogue_visible() and not cinematic_input_blocked() and not local_departing() and not gate_departing() and drill_owner()==null and (_approach==null or _approach.snapshot().phase in ["idle","approach"])

func engine_particle_owner() -> RefCounted:return null if _engine_particles==null else _engine_particles.fork_for_frame()
func death_active() -> bool:return _death!=null and _death.snapshot().phase!="ready"
func game_over_waiting() -> bool:return death_active() and not _death.player_updates_enabled()

func request_game_over_exit(paused:=false) -> RefCounted:
	error=""
	if paused or not death_active() or not _game_over_packet.is_empty():reject("No active game-over acknowledgement is available");return null
	var next:=fork_for_frame()
	var packet: Dictionary=next._death.request_exit()
	if packet.is_empty():reject(next._death.error);return null
	next._game_over_packet=packet
	return next

func prepare_game_over() -> Dictionary:return _game_over_packet.duplicate(true)

func dialogue_visible() -> bool:
	return contract_result_pending() or (_briefing!=null and _briefing.snapshot().dialogue.visible) or (_objective.dialogue_visible() if _objective is ContractObjective else (_objective!=null and _objective.snapshot().dialogue.visible))

func navigate(action: String, paused:=false) -> RefCounted:
	error=""
	if game_over_waiting() or not _game_over_packet.is_empty():reject("A completed game-over screen owns flight actions");return null
	if not _unsupported_boundary.is_empty():reject("This flight requires its player-death transition");return null
	if not _station_packet.is_empty():reject("This flight has reached the station");return null
	if _briefing==null or paused:reject("Mining briefing navigation requires the active flight");return null
	var next:=fork_for_frame()
	if _briefing.snapshot().phase=="mining_instruction":
		if not next._briefing.navigate(action):reject(next._briefing.error);return null
	elif _objective!=null and _objective.snapshot().dialogue.visible:
		if next._objective is ContractObjective:
			if not next._objective.navigate(action,next._encounter):reject(next._objective.error);return null
			var state: Dictionary=next._objective.snapshot()
			if state.has("campaign_failure"):
				var receipt: Dictionary=state.campaign_failure
				next._game_over_packet={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":state.campaign_cursor,"source_state":receipt.source_state,"campaign_failure":receipt.duplicate(true)}
			elif state.campaign_cursor!=_objective.snapshot().campaign_cursor and next._rescue==null:
				if next._local_travel==null or not next._local_travel.rebase_campaign(_story_bindings,state.campaign_cursor,state.mission):reject("Campaign navigation: "+str(next._local_travel.error if next._local_travel!=null else "missing travel"));return null
				var guidance: Dictionary=next._autopilot.snapshot()
				if guidance.active and guidance.target_kind=="planet" and not next._local_travel.supports_destination(guidance.station_id):
					if not next._autopilot.clear_target():reject(next._autopilot.error);return null
				next._return_rules=FreeFlight.docking(_story_bindings,int(_entry.location.station_id),state.campaign_cursor)
		elif not next._objective.navigate(action):reject(next._objective.error);return null
		if _entry.has("bakka_context") and not next._finish_bakka_navigation(_objective.snapshot()):reject(next.error);return null
		if _mission_context!=null and _mission_context.advances_campaign() and not next._finish_mission_navigation(_objective.snapshot()):reject(next.error);return null
		if _entry.campaign_cursor==7 and _equipment!=null and next._objective.snapshot().combat_objective_acknowledged and not _objective.snapshot().combat_objective_acknowledged:
			if not next._equipment.complete_training(next._cargo.snapshot()):reject(next._equipment.error);return null
			if not _navigation.is_empty() and _navigation.clear_on_completion_acknowledgement:next._route=null
		if _alioth!=null and _story_bindings!=null and next._objective.snapshot().combat_objective_acknowledged and not _objective.snapshot().combat_objective_acknowledged:
			if _convoy_career==null:reject("Alioth completion lost its retained career");return null
			next._convoy_career=_convoy_career.fork()
			if not next._convoy_career.advance_alioth_story(_story_bindings,_objective.snapshot().progress,int(next._objective.snapshot().campaign_cursor)):reject(next._convoy_career.error);return null
			if next._convoy_career.snapshot().progress!=next._objective.snapshot().progress:reject("Alioth completion changed the earned career");return null
		if _entry.campaign_cursor in [25,26,29]:
			var previous: Dictionary=_objective.snapshot()
			var result: Dictionary=next._objective.snapshot()
			if result.campaign_cursor==previous.campaign_cursor:return next
			if _convoy_career!=null:
				next._convoy_career=_convoy_career.fork()
				if not next._convoy_career.advance_sahi_story(_story_bindings,previous.progress,result.campaign_cursor):reject(next._convoy_career.error);return null
			if result.campaign_cursor==27:
				var cache: Dictionary=_player.cache_snapshot()
				cache.campaign_cursor=27
				var entry:={"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"campaign_cursor":27,
					"departure":{"mission":result.mission,"player_cache":cache}}
				next._local_travel=LocalTravel.new()
				if not next._local_travel.configure_flight(_story_bindings,_story_catalogues,next._equipment,entry) or not next._local_travel.sample_frame(next._camera.snapshot().pose,next._aim.snapshot(),0,-1,false):reject(next._local_travel.error);return null
				if not next._autopilot.refresh_local_navigation(_story_bindings,27):reject(next._autopilot.error);return null
				next._return_rules=FreeFlight.docking(_story_bindings,int(_entry.location.station_id),27)
	elif not next._briefing.navigate(action):reject(next._briefing.error);return null
	return next

func snapshot(shared_scenery:=false) -> Dictionary:
	if _briefing==null:return {}
	var state: Dictionary=_briefing.snapshot()
	var held: Dictionary=_cargo.snapshot()
	state.cargo_used=held.used
	state.booster=booster_state();state.cloak=cloak_state();state.turret=turret_state();state.khador=drive_state()
	state.player_engine=_engine_audio.snapshot()
	if _wingmen!=null:state.wingman_actors=_wingmen.snapshot()
	state.merge({"world_type":_entry.world_type,"location":_entry.location.duplicate(true),"activated":true,
		"player_pose":_pose,"control_throttle":_throttle,"player":_player.snapshot(),"gamma_rate":_gamma_rate,"volatile":_volatile_carried(),"instability":_instability,"player_cache":_player.cache_snapshot(),"angular_units":_pilot.angular_units,
		"camera_shot":_shot.duplicate(true),"camera_view":_camera.snapshot(),"scenery":_scenery.read_snapshot() if shared_scenery else _scenery.snapshot(),
		"ship_detail":_detail.snapshot(),"detail_reference":_reference,"actors":[],"random_state":_random.duplicate(true),
		"cargo":held,"arrival_from_station_id":int(_entry.departure.get("from_station_id",-1)),
		"navigation_destination_id":_pending_destination,
		"scenery_collision_enabled":_collision_enabled,"scenery_collision_supported":_physical_contacts!=null})
	if _entry.has("environment_object"):state.environment_object=_entry.environment_object.duplicate(true)
	if _entry.departure.has("dekato_source_receipt"):state.dekato_source_receipt=_entry.departure.dekato_source_receipt.duplicate(true)
	if _entry.has("pending_station_id"):
		state.pending_station_id=_entry.pending_station_id;state.pending_system_id=_entry.pending_system_id
	if _void_environment!=null:state.void_environment=_void_environment.snapshot()
	if _void_portal!=null:
		state.void_portal=_void_portal.portal_snapshot();state.void_portal_contact=_void_portal.snapshot()
		if void_return_required():state.boundary="void_return_transition_required"
	if _probe!=null:
		state.void_probe_stage=_probe.snapshot();state.void_probe=_probe.probe_snapshot()
		state.void_station_targeting=_void_targeting.snapshot()
	state.world_phase_elapsed_ms=_world_elapsed_ms
	if mission_station_return_required():
		state.boundary="mission_station_return_required"
		state.mission_station_return=_mission_station_return.duplicate(true)
	if _music!=null:state.flight_music=_flight_music.duplicate(true)
	state.player_statistics_pose=_statistics_pose
	state.camera_follow_enabled=_camera_follow_enabled
	if _fast_forward!=null:
		state.fast_forward=fast_forward_state()
		state.fast_forward.camera_ms=_camera_ms;state.fast_forward.camera_passes=_camera_passes
		state.fast_forward.camera_response=_camera.response_snapshot()
	if _entry.has("gate_environment"):state.gate_environment=_entry.gate_environment.duplicate(true)
	var gate_animation: RefCounted=gate_animation_owner()
	if gate_animation!=null:state.gate_animation=gate_animation.snapshot()
	if _gate_transit!=null:
		state.gate_transit=_gate_transit.snapshot();state.gate_destinations=_gate_destinations.duplicate()
		if gate_modal():state.boundary="gate_confirmation_required" if state.gate_transit.phase=="confirmation" else "gate_map_required"
		elif not prepare_gate_arrival().is_empty():state.boundary="gate_arrival_transition_required"
	if not prepare_drive_arrival().is_empty():state.boundary="drive_arrival_transition_required"
	if _alioth!=null:
		state.alioth_attack=_alioth.snapshot();state.alioth_portal=_portal.snapshot();state.alioth_camera=_alioth_camera.duplicate(true)
	if _sahi!=null:
		state.sahi_stage=_sahi.snapshot();state.sahi_portal=_sahi.portal_snapshot()
		if sahi_arrival_required():state.boundary="sahi_arrival_transition_required"
	if _convoy!=null:
		state.convoy_capture=_convoy.snapshot()
		state.convoy_camera=_convoy_camera.duplicate(true)
		if convoy_arrival_required():state.boundary="convoy_arrival_transition_required"
	if _death!=null:state.player_destruction=_death.snapshot()
	if _particles!=null:state.damage_particles=_particles.snapshot(shared_scenery)
	if _engine_particles!=null:state.engine_particles=_engine_particles.snapshot(shared_scenery)
	if _radio!=null:state.radio=_radio.snapshot();state.radio_events=_radio_events.duplicate(true)
	if _scanner!=null:state.npc_scanner=_scanner.snapshot();state.npc_scanner_events=_scanner_events.duplicate(true)
	if _tractor!=null:state.tractor=_tractor.snapshot();state.tractor_frame=_tractor_frame.duplicate(true)
	if _local_travel!=null:
		state.local_travel=_local_travel.snapshot()
		if state.local_travel.phase=="arrival_required" and not death_active():state.boundary="local_arrival_transition_required"
	if not _navigation.is_empty() or _rescue!=null:state.player_route={} if _route==null else _route.snapshot()
	elif _story_course():
		# A story course (105 toward the sun, 125 the black box site).
		state.player_route={} if not _story_route.get("point") is Vector3 else {"base_content_id":_entry.base_content_id,"binding_id":_entry.binding_id,"owner":"player","story":true,"point":_story_route.point}
	if _rescue!=null:state.kappa_rescue=_rescue.snapshot()
	if _objective is ContractObjective:state.world_path=_world_path.duplicate(true)
	if not _audio_frame.is_empty():state.flight_audio=_audio_frame.duplicate(true)
	if _encounter!=null:
		state.encounter=_encounter.snapshot();state.actors=state.encounter.combat.actors.duplicate(true)
		state.mission_readout=state.encounter.controller.get("mission_readout",{})
		state.station_return_supported=not _return_rules.is_empty()
	if _entry.campaign_cursor in [10,11,12,26,36] or _entry.has("dekato_context") or _objective is ContractObjective:state.station_response_flags=station_response_flags()
	if _station!=null:
		state.station_exterior=_station.snapshot()
		state.station_hidden=_station_hidden
		state.station_volume_index=_station.point_volume(_pose.origin)
	if _autopilot!=null:state.station_autopilot=_autopilot.snapshot()
	if not _return_rules.is_empty():
		state.station_arrival={"pre_motion_contact":_station_contact,"ready":not _station_packet.is_empty()}
		if not _station_packet.is_empty():state.boundary="station_transition_required"
	if not _unsupported_boundary.is_empty():state.boundary=_unsupported_boundary
	if not _game_over_packet.is_empty():state.boundary="game_over_transition_required"
	if _aim!=null:state.player_aim=_aim.snapshot()
	if _targeting!=null:state.mining_targeting=_targeting.snapshot()
	if _station_targeting!=null:state.station_targeting=_station_targeting.snapshot()
	if _approach!=null:
		state.mining_approach=_approach.snapshot()
		state.mining_boundary="drill_required" if _mining==null and state.mining_approach.phase=="drill_required" else ""
	if _approach!=null or _autopilot!=null:state.player_model_basis=_model_basis
	if _mining!=null:state.mining_session=_mining.snapshot()
	if not _mining_audio.is_empty():state.mining_audio=_mining_audio.duplicate(true)
	if _notices!=null:state.flight_notices=_notices.snapshot()
	if _objective!=null:
		state.mining_objective=_objective.snapshot()
		var instruction_visible: bool=state.phase=="mining_instruction"
		if _objective is ContractObjective:
			state.contracts=state.mining_objective.contracts;state.contract_result=state.mining_objective.contract_result
			state.campaign_cursor=state.mining_objective.campaign_cursor;state.mission=state.mining_objective.mission.duplicate(true)
		if _equipment!=null:
			state.progress=state.mining_objective.progress
			state.combat_objective_satisfied=state.mining_objective.combat_objective_satisfied
			state.combat_objective_acknowledged=state.mining_objective.combat_objective_acknowledged
			state.equipment=_equipment.snapshot()
		if _convoy_career!=null:
			state.contracts=_convoy_career.snapshot()
			state.contracts.progress=state.mining_objective.progress
			state.contracts.campaign_cursor=state.mining_objective.campaign_cursor
			state.contracts.rank=state.mining_objective.progress.rank
			state.contracts.reputation=state.mining_objective.progress.reputation
		if state.mining_objective.phase!="collecting":
			for key in ["campaign_cursor","progress","mission","dialogue","phase"]:
				if not instruction_visible or key not in ["dialogue","phase"]:state[key]=state.mining_objective[key]
		state.cargo_objective_satisfied=state.mining_objective.cargo_objective_satisfied
		state.cargo_objective_acknowledged=state.mining_objective.cargo_objective_acknowledged
		state.station_return_required=state.mining_objective.station_return_required
	return state

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._mission_context=_mission_context
	copy._mission_station_return=_mission_station_return.duplicate(true)
	copy._mission_station_identity=_mission_station_identity
	copy._entry=_entry;copy._pose=_pose;copy._shot=_shot.duplicate(true);copy._random=_random.duplicate(true);copy._reference=_reference
	copy._station_response_flags=_station_response_flags.duplicate(true)
	if _alioth!=null:copy._alioth=_alioth.fork_for_frame();copy._portal=_portal.fork_for_frame()
	if _sahi!=null:copy._sahi=_sahi.fork_for_frame()
	if _void_portal!=null:copy._void_portal=_void_portal.fork_for_frame()
	if _probe!=null:copy._probe=_probe.fork_for_frame()
	if _void_targeting!=null:copy._void_targeting=_void_targeting.fork_for_frame()
	copy._void_environment=_void_environment # Immutable generated layout; public access forks it.
	copy._drive=_drive.fork_for_frame() if _drive!=null else null;copy._drive_arrival=_drive_arrival
	copy._ordinary_void_source=_ordinary_void_source # Entry-owned immutable route; public access forks it.
	copy._alioth_camera=_alioth_camera.duplicate(true)
	if _convoy!=null:copy._convoy=_convoy.fork_for_frame()
	copy._convoy_camera=_convoy_camera.duplicate(true)
	copy._convoy_career=_convoy_career # immutable departure owner; public access forks it
	copy._selected_locations=_selected_locations # Retained history is unchanged in Void.
	copy._story_bindings=_story_bindings
	copy._story_catalogues=_story_catalogues
	if _gate_animation!=null:copy._gate_animation=_gate_animation.fork_for_frame()
	if _gate_transit!=null:copy._gate_transit=_gate_transit.fork_for_frame()
	copy._gate_destinations=_gate_destinations.duplicate();copy._gate_cruise_speed=_gate_cruise_speed
	copy._system_navigation=_system_navigation;copy._navigation_destinations=_navigation_destinations
	copy._pending_destination=_pending_destination;copy._navigation_applied=_navigation_applied;copy._queued_drive=_queued_drive;copy._story_jump=_story_jump;copy._story_locked=_story_locked;copy._story_dock=_story_dock.duplicate(true);copy._action_marks=_action_marks.duplicate();copy._line_marks=_line_marks.duplicate(true);copy._gamma_rate=_gamma_rate;copy._instability=_instability;copy._volatile_steer=_volatile_steer;copy._story_cloaks=_story_cloaks.duplicate(true);copy._story_hack=_story_hack;copy._story_route=_story_route.duplicate()
	copy._briefing=_briefing.fork();copy._player=_player.fork_for_frame();copy._scenery=_scenery.fork_for_frame()
	copy._camera=_camera.fork_for_frame();copy._pilot=_pilot.fork_for_frame();copy._detail=_detail.fork_for_frame()
	copy._collision_enabled=_collision_enabled
	copy._cargo=_cargo.fork_for_frame()
	if _tractor!=null:copy._tractor=_tractor.fork_for_frame()
	copy._tractor_frame=_tractor_frame.duplicate(true)
	copy._viewport=_viewport
	if _aim!=null:copy._aim=_aim.fork_for_frame()
	if _targeting!=null:copy._targeting=_targeting.fork_for_frame()
	if _approach!=null:copy._approach=_approach.fork_for_frame()
	if _mining!=null:copy._mining=_mining.fork_for_frame()
	copy._mining_audio=_mining_audio.duplicate(true)
	if _physical_contacts!=null:copy._physical_contacts=_physical_contacts.fork_for_frame()
	copy._music=_music;copy._music_context=_music_context;copy._music_faction=_music_faction;copy._flight_music=_flight_music.duplicate(true)
	if _notices!=null:copy._notices=_notices.fork_for_frame()
	if _objective!=null:copy._objective=_objective.fork_for_frame()
	if _wingmen!=null:copy._wingmen=_wingmen.fork_for_frame()
	if _station!=null:copy._station=_station.fork_for_frame()
	if _station_targeting!=null:copy._station_targeting=_station_targeting.fork_for_frame()
	if _autopilot!=null:copy._autopilot=_autopilot.fork_for_frame()
	copy._preceding_commands=_preceding_commands
	copy._departure_station=_departure_station
	copy._return_rules=_return_rules;copy._station_contact=_station_contact;copy._station_hidden=_station_hidden;copy._station_packet=_station_packet.duplicate(true)
	copy._model_basis=_model_basis;copy._throttle=_throttle
	if _encounter!=null:copy._encounter=_encounter.fork_for_frame()
	copy._world_elapsed_ms=_world_elapsed_ms
	copy._unsupported_boundary=_unsupported_boundary
	copy._statistics_pose=_statistics_pose;copy._camera_follow_enabled=_camera_follow_enabled
	copy._game_over_packet=_game_over_packet.duplicate(true)
	if _death!=null:copy._death=_death.fork_for_frame()
	if _particles!=null:copy._particles=_particles.fork_for_frame()
	if _engine_particles!=null:copy._engine_particles=_engine_particles.fork_for_frame()
	if _engine_audio!=null:copy._engine_audio=_engine_audio.fork_for_frame()
	if _booster!=null:copy._booster=_booster.fork_for_frame()
	if _equipment!=null:copy._equipment=_equipment.fork()
	if _radio!=null:copy._radio=_radio.fork_for_frame()
	copy._radio_events=_radio_events.duplicate(true)
	if _scanner!=null:copy._scanner=_scanner.fork_for_frame()
	copy._scanner_events=_scanner_events.duplicate(true)
	if _route!=null:copy._route=_route.fork_for_frame()
	if _rescue!=null:copy._rescue=_rescue.fork()
	copy._navigation=_navigation
	copy._world_path=_world_path.duplicate(true)
	copy._world_route=_world_route # Immutable shared path; commands fork per pilot.
	copy._audio_frame=_audio_frame.duplicate(true)
	if _local_travel!=null:copy._local_travel=_local_travel.fork()
	if _fast_forward!=null:copy._fast_forward=_fast_forward.fork_for_frame()
	copy._near_target=_near_target;copy._camera_ms=_camera_ms;copy._camera_passes=_camera_passes
	return copy

func clear() -> void:
	error="";_entry={};_pose=Transform3D.IDENTITY;_shot={};_random={};_reference=Vector3.ZERO
	_alioth=null;_portal=null;_alioth_camera={}
	_convoy=null;_convoy_camera={};_convoy_career=null;_selected_locations=null
	_story_bindings=null
	_story_catalogues=null
	_gate_animation=null;_gate_transit=null;_gate_destinations=[];_gate_cruise_speed=0.0
	_system_navigation=null;_navigation_destinations=[];_pending_destination=-1;_navigation_applied=false
	_drive=null;_drive_arrival=null;_queued_drive=false;_story_jump=-2
	_briefing=null;_player=null;_scenery=null;_camera=null;_pilot=null;_detail=null;_collision_enabled=false
	_cargo=null;_tractor=null;_tractor_frame={}
	_aim=null;_targeting=null;_viewport=Vector2i(1280,720)
	_approach=null;_model_basis=Basis.IDENTITY;_throttle=1.0
	_mining=null;_mining_audio={};_notices=null;_objective=null
	_wingmen=null
	_physical_contacts=null
	_music=null;_music_context={};_music_faction=-1;_flight_music={}
	_station=null
	_autopilot=null;_station_targeting=null;_preceding_commands=Vector2.ZERO
	_return_rules={};_departure_station=null;_station_contact=false;_station_packet={}
	_encounter=null;_world_elapsed_ms=0
	_unsupported_boundary=""
	_death=null;_statistics_pose=Transform3D.IDENTITY;_camera_follow_enabled=true;_game_over_packet={}
	_particles=null;_audio_frame={};_equipment=null;_radio=null;_radio_events=[]
	_engine_particles=null;_booster=null
	_engine_audio=null
	_route=null;_navigation={};_world_path=[];_world_route=null;_rescue=null;_sahi=null;_void_environment=null;_void_portal=null;_ordinary_void_source=null
	_probe=null;_void_targeting=null
	_scanner=null;_scanner_events=[]
	_local_travel=null;_station_response_flags={}
	_fast_forward=null;_near_target=false;_camera_ms=0;_camera_passes=1
func reject(message: String) -> bool:error=message;return false
