extends Node3D
## Audio side effects are committed only after the whole opening frame validates.
const Resources=preload("res://src/content/audio_resources.gd")
const Definitions=preload("res://src/content/audio_definitions.gd")
const Layered=preload("res://src/presentation/layered_audio.gd")
const ParameterLoop=preload("res://src/presentation/parameter_audio.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const Sequence=preload("res://src/simulation/audio_sequence.gd")
const Death=preload("res://src/content/npc_destruction_definitions.gd")
const WeaponAudio=preload("res://src/content/weapon_audio_definitions.gd")
const SecondaryAudio=preload("res://src/content/secondary_ownership_definitions.gd")
const Conventional=preload("res://src/content/conventional_secondary_definitions.gd")
const BombAudio=preload("res://src/content/emp_bombs_definitions.gd")
const MineAudio=preload("res://src/content/mine_definitions.gd")
const RadioVoice=preload("res://src/content/radio_audio_definitions.gd")
const Dialogue=preload("res://src/content/dialogue_definitions.gd")
const Story=preload("res://src/content/story_encounter_definitions.gd")
const VoidProbe=preload("res://src/content/void_probe_definitions.gd")
const EngineParameters=preload("res://src/simulation/engine_audio.gd")
const MiningFlight=preload("res://src/simulation/first_flight_frame.gd")
const Pirate=preload("res://src/content/full_hold_pirate_definitions.gd")
const PlayerDeath=preload("res://src/content/player_destruction_definitions.gd")
const Training=preload("res://src/content/combat_training_story_definitions.gd")
const TrainingControl=preload("res://src/content/combat_training_control_definitions.gd")
const OrdinaryFlight=preload("res://src/content/ordinary_flight_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const ContractWorld=preload("res://src/content/contract_world_definitions.gd")
const LocalRadio=preload("res://src/simulation/local_traffic_radio.gd")
const Booster=preload("res://src/content/booster_definitions.gd")
const PLAYER_ENGINE="player_engine"
var error := ""
var _resources: RefCounted
var _identity: RefCounted
var _revision := -1
var _booster_serial:=0
var _cloak_serial:=0
var _players := {}
var _retiring: Array[Dictionary]=[]
var _music := -1
var _engine := -1
var _paused := false
var _listener := Transform3D.IDENTITY
var _history: Array[Dictionary]=[]
var _unsupported := {}
var _elapsed_ms := 0
var _viewport: Viewport
var _previous_listener:=false
var _seed_value:=0
var _start_serial:=0
var _random:=RandomNumberGenerator.new()
var _last_samples:={}
var _death_audio:={}
var _freighter_audio:={}
var _freighter_actors:=[]
var _debris_actors:=[]
var _debris_sound:=-1
var _notification_sound:=-1
var _notified_result_serial:=0
var _content_identity:={}
var _weapon_audio:={}
var _secondary_audio:={}
var _npc_weapon_sound:=-1
var _npc_weapon_sounds:=[]
var _npc_scan_sound:=-1
var _radio_voice:={}
var _local_radio_rules:={}
var _radio_identity:={}
var _voice_displayed: Array=[]
var _voice_serial:=0
var _engine_ids: Array=[]
var _arrival_engine_id:=-1
var _engine_generation:=-1
var _initial_engine_id:=-1
var _npc_count:=3
var _player_death_rules:={}
var _flight_identity: RefCounted
var _flight_serial:=-1
var _travel_sounds: Array[int]=[]
var _tractor_sounds: Array[int]=[]
var _portal_sound:=-1
var _probe_sound:=-1
var _travel_attached:=false
var _travel_serial:=0
var _mining_only:=false
var _mining_attached:=false
var _mining_serial:=0
var _drill_rates: Array=[]
var _flight_music_attached:=false
var _selected40_identity: RefCounted
var _selected41_radio_world: RefCounted

func configure(library: RefCounted, bindings: RefCounted, audio_seed: int=0, campaign_cursor: int=0, local_combat: Dictionary={},mission_context: RefCounted=null) -> bool:
	if mission_context==null and campaign_cursor==40 and (not local_combat.has("free_context") or not OrdinaryFlight.combat_population(bindings,local_combat)):return reject("Selected40 audio requires its explicit native flight owner")
	clear()
	var dialogue: Dictionary=Dialogue.select(bindings,campaign_cursor) if bindings!=null else {}
	var contest: bool=OrdinaryFlight.BakkaCombat.combat_population(bindings,local_combat)
	var local_flight: bool=OrdinaryFlight.combat_population(bindings,local_combat,mission_context)
	var admitted_silent: bool=mission_context!=null and mission_context.recipe().radio.is_empty()
	if admitted_silent:dialogue={}
	var authored_radio: bool=Dialogue.valid_parameters(dialogue,campaign_cursor) and ((campaign_cursor in [28,29] and Story.combat_population(bindings,local_combat)) or OrdinaryFlight.Dekato.combat_population(bindings,local_combat))
	var story_radio: bool=(campaign_cursor==14 and local_combat.get("actors",[]).any(func(actor):return actor.get("convoy",false))) or campaign_cursor==16 or OrdinaryFlight.Kappa.combat_population(bindings,local_combat) or OrdinaryFlight.Authored.combat_population(bindings,local_combat) or authored_radio
	if admitted_silent:story_radio=mission_context.advances_campaign()
	if campaign_cursor==29 and not authored_radio and not admitted_silent:return reject("Authored radio requires its selected story cast")
	if campaign_cursor==2:
		_npc_count=0
		if PlayerDeath.parameters(bindings.player_destruction):_player_death_rules=bindings.player_destruction.duplicate(true)
	if campaign_cursor==4:
		if bindings==null or not Pirate.parameters(bindings.full_hold_pirate) or not PlayerDeath.parameters(bindings.player_destruction):return reject("Second-flight audio lacks its pirate and player destruction declarations")
		_npc_count=1;_player_death_rules=bindings.player_destruction.duplicate(true)
	if campaign_cursor==7:
		if bindings==null or not Training.parameters(bindings.combat_training_story) or not TrainingControl.parameters(bindings.combat_training_control) or not PlayerDeath.parameters(bindings.player_destruction):return reject("Training audio lacks its complete cast and player destruction declarations")
		_npc_count=4;_player_death_rules=bindings.player_destruction.duplicate(true)
		_npc_scan_sound=int(bindings.opening_staging.npc_scanner.acquisition_sound_id)
	if local_flight:
		if bindings==null or not Travel.parameters(bindings.mido_travel) or not PlayerDeath.parameters(bindings.player_destruction):return reject("Local flight audio lacks its patrol and player destruction declarations")
		var actors: Variant=local_combat.get("actors")
		var empty_delivery: bool=ContractWorld.supports(bindings,campaign_cursor) and actors is Array and actors.is_empty() and local_combat.get("contract_encounter",{}).get("kind")==0
		if not local_flight and not authored_radio and not empty_delivery:return reject("Local flight audio requires its generated population")
		for id in actors.size():
			if not actors[id] is Dictionary or actors[id].get("actor_id")!=id or (not actors[id].get("actor_kind") is int):return reject("Unsupported local sound owner")
		_npc_count=actors.size();_player_death_rules=bindings.player_destruction.duplicate(true)
		_npc_scan_sound=int(bindings.opening_staging.npc_scanner.acquisition_sound_id)
		_local_radio_rules={} if story_radio or contest else bindings.mido_travel.traffic_combat.radio.duplicate(true)
		_travel_sounds=[int(bindings.mido_travel.travel.acquisition_sound_id),int(bindings.mido_travel.travel.launch_sound_id)]
	if local_flight:
		_freighter_actors=local_combat.actors.filter(func(actor):return actor.get("population_group") in ["freighter","capital"]).map(func(actor):return int(actor.actor_id))
		if not _freighter_actors.is_empty():_freighter_audio=bindings.freighter_destruction.duplicate(true)
	if local_flight and (local_combat.has("free_context") or local_combat.has("contract_encounter")):
		_debris_actors=local_combat.actors.filter(func(actor):return actor.get("population_group")=="debris").map(func(actor):return int(actor.actor_id))
		_debris_sound=int(bindings.early_contracts.junk_lifecycle.sound_id)
		_notification_sound=int(bindings.early_contracts.delivery_results.notification_sound_id)
	_seed_value=audio_seed
	_random.seed=audio_seed
	_resources=Resources.new()
	if local_flight and not story_radio and not contest:
		if not _resources.configure_local_traffic(library,bindings):return reject(_resources.error)
	# Ordinary Void and the contest have combat but no timed radio. Resolve
	# their original clips through the base bank without inventing a radio scene.
	elif not _resources.configure(library,bindings,0 if admitted_silent or contest or campaign_cursor in [2,4,26,33] else campaign_cursor):return reject(_resources.error)
	for id in [_npc_scan_sound,_debris_sound,_notification_sound]:
		if id>=0 and _resources.prepare(id).is_empty():return reject(_resources.error)
	for id in _travel_sounds:
		var clip: Dictionary=_resources.prepare(id)
		if clip.is_empty() or clip.has("unsupported"):return reject("Local travel sound is unsupported: "+str(id)+" "+str(clip.get("unsupported",_resources.error)))
	_content_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	for id in bindings.vehicle_response.get("audio",{}).get("event_ids",[]):_engine_ids.append(int(id))
	_arrival_engine_id=int(bindings.opening_staging.get("escape",{}).get("arrival_engine_sound_id",-1))
	_radio_voice=dialogue.get("voice",{}) if campaign_cursor in [0,1,7] or story_radio else {}
	if not _radio_voice.is_empty():
		if not RadioVoice.parameters(_radio_voice,dialogue.events.size()):return reject("Invalid radio voice capability")
		_radio_voice=_radio_voice.duplicate(true)
		_radio_identity=_content_identity.duplicate();_radio_identity.language=library.active_language
		if campaign_cursor!=0:_radio_identity.campaign_cursor=campaign_cursor
		_voice_displayed.resize(_radio_voice.event_ids.size());_voice_displayed.fill(false)
		for id in _radio_voice.event_ids:
			if id>=0 and _resources.prepare(int(id)).is_empty():return reject(_resources.error)
	if not _local_radio_rules.is_empty():
		_radio_identity=_content_identity.duplicate();_radio_identity.language=library.active_language;_radio_identity.campaign_cursor=campaign_cursor
		_voice_displayed=[false,false]
		for id in _local_radio_rules.warning_voice_ids+_local_radio_rules.response_voice_ids:
			if _resources.prepare(int(id)).is_empty():return reject(_resources.error)
	_secondary_audio=SecondaryAudio.VALUES.duplicate(true) if SecondaryAudio.available(bindings) else {}
	_weapon_audio=bindings.weapon_parameters.get("audio",{}) if (local_flight or campaign_cursor in [0,4,7]) else {}
	if not _weapon_audio.is_empty():
		if not WeaponAudio.parameters(_weapon_audio):return reject("Invalid weapon audio capability")
		_weapon_audio=_weapon_audio.duplicate(true)
		var kind: int=int(bindings.opening_actors.get("npc_initialization",{}).get("primary_weapon",{}).get("actor_kind",-1))
		if campaign_cursor==4:kind=int(bindings.full_hold_pirate.actor_kind)
		if local_flight:kind=int(bindings.mido_travel.traffic_combat.actor_kind)
		if kind<0:return reject("Weapon audio requires its NPC owner")
		_npc_weapon_sound=int(_weapon_audio.npc_event_ids[kind]) if kind<_weapon_audio.npc_event_ids.size() else int(_weapon_audio.npc_default_event_id)
		for id in _npc_count:
			var actor_kind:=int(local_combat.actors[id].actor_kind) if local_flight else (int(bindings.combat_training_control.actor_kinds[id]) if campaign_cursor==7 else kind)
			if actor_kind<0:_npc_weapon_sounds.append(-1);continue
			var sound:=int(_weapon_audio.npc_event_ids[actor_kind]) if actor_kind<_weapon_audio.npc_event_ids.size() else int(_weapon_audio.npc_default_event_id)
			_npc_weapon_sounds.append(sound)
			if _resources.prepare(sound).is_empty():return reject(_resources.error)
	_death_audio=bindings.opening_actors.get("npc_initialization",{}).get("destruction_audio",{}) if (local_flight or campaign_cursor in [0,4,7]) else {}
	if not _death_audio.is_empty():
		if not Death.audio_parameters(_death_audio):return reject("Invalid NPC destruction audio capability")
		_death_audio=_death_audio.duplicate(true)
		_death_audio.initial_source_id=int(_death_audio.initial_source_id)
		_death_audio.breakup_source_ids=[int(_death_audio.breakup_source_ids[0]),int(_death_audio.breakup_source_ids[1])]
		for id in [_death_audio.initial_source_id]+_death_audio.breakup_source_ids:
			if _resources.prepare(int(id)).is_empty():return reject(_resources.error)
	var flight_sounds: Array=[]
	if not _player_death_rules.is_empty():
		flight_sounds=[int(_player_death_rules.breakup_sound_base),int(_player_death_rules.breakup_sound_base)+1,int(_player_death_rules.failure_sound)]
	if (local_flight or campaign_cursor in [4,7]):
		if _weapon_audio.is_empty() or _death_audio.is_empty():return reject("Second-flight combat audio is unavailable")
		flight_sounds.append_array([_npc_weapon_sound,int(_death_audio.initial_source_id)])
	for id in flight_sounds:
		var clip: Dictionary=_resources.prepare(id)
		if clip.is_empty() or clip.has("unsupported"):return reject("Unsupported flight sound: "+str(id)+" "+str(clip.get("unsupported",_resources.error)))
	_identity=RefCounted.new()
	_viewport=get_viewport()
	_previous_listener=_viewport.is_audio_listener_3d()
	_viewport.set_as_audio_listener_3d(true)
	var escape: Dictionary=bindings.opening_staging.get("escape",{}) if campaign_cursor==0 else {}
	if not escape.is_empty():
		var ids: Array=[escape.entry_music_id,escape.jump_music_id,escape.exit_sound_id,escape.arrival_sound_id,escape.arrival_engine_sound_id]
		ids.append_array(escape.drive_sound_ids)
		for id in ids:
			if _resources.prepare(int(id)).is_empty():return reject(_resources.error)
	return true

## Selected40 has a distinct native constructor, not an ordinary departure.
## Reuse this backend's source clip validation, language, cached playback and
## prepare/commit boundary. Environment music/engine selection is not invented.
## Radio-only consumer for the retained source41 native component. This does
## not grant its unfinished cinematic, music/combat audio or application swap.
func configure_selected41_radio(library: RefCounted,bindings: RefCounted,npc: RefCounted,audio_seed: int=0) -> bool:
	error=""
	if _identity!=null or not is_instance_of(npc,load("res://src/simulation/selected41_npc_combat.gd")):return reject("Prepare source41 radio audio once on its native component")
	var state: Dictionary=npc.frame_context()
	if state.is_empty() or state.revision!=0 or state.elapsed_ms!=0 or npc.world_owner()==null:return reject("Prepare source41 radio audio before its first native frame")
	var dialogue: Dictionary=Dialogue.select(bindings,41)
	if not Dialogue.valid_parameters(dialogue,41) or not RadioVoice.parameters(dialogue.get("voice",{}),8):return reject("Source41 radio audio lacks its eight original transmissions")
	for key in ["base_content_id","binding_id"]:
		if state.get(key)!=bindings.get(key):return reject("Source41 radio audio belongs to another content generation")
	var resources:=Resources.new()
	if not resources.configure(library,bindings,41):return reject(resources.error)
	for id in dialogue.voice.event_ids:
		var clip: Dictionary=resources.prepare(int(id))
		if clip.is_empty() or clip.has("unsupported"):return reject("Unsupported source41 speech: "+str(id)+" "+str(clip.get("unsupported",resources.error)))
	_resources=resources;_seed_value=audio_seed;_random.seed=audio_seed
	_radio_voice=dialogue.voice.duplicate(true)
	_radio_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"language":library.active_language,"campaign_cursor":41}
	_content_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_voice_displayed.resize(8);_voice_displayed.fill(false)
	_selected41_radio_world=npc.world_owner();_identity=RefCounted.new()
	# Speech is non-spatial: no listener is stolen from the retained world.
	return true

func prepare_selected41_radio(npc: RefCounted) -> Dictionary:
	error=""
	if not is_instance_of(npc,load("res://src/simulation/selected41_npc_combat.gd")) or _selected41_radio_world==null or npc.world_owner()!=_selected41_radio_world:return fail("Source41 speech rejected another initialized generation")
	var state: Dictionary=npc.snapshot()
	if not Definitions.integer(state.revision,maxi(0,_flight_serial),_flight_serial+1) or not Definitions.integer(state.elapsed_ms,_elapsed_ms,0x7fffffff):return fail("Source41 speech lost its next completed native revision")
	if state.revision==_flight_serial:
		if state.elapsed_ms!=_elapsed_ms:return fail("Repeated source41 speech changed its clock")
		return {"identity":_identity,"revision":_revision,"repeat":true}
	var frame:=prepare_frame(_revision+1,{"elapsed_ms":state.elapsed_ms,"radio":state.radio,"radio_changes":state.events.get("radio",[])})
	if frame.is_empty():return {}
	frame.flight_serial=state.revision
	return frame

func configure_selected40(library: RefCounted,bindings: RefCounted,world: RefCounted,audio_seed: int=0) -> bool:
	error=""
	if _identity!=null or not is_instance_of(world,load("res://src/simulation/selected40_flight_frame.gd")):return reject("Register selected40 audio once on its native flight")
	var state: Dictionary=world.audio_state()
	var death: RefCounted=world.destruction_owner()
	if state.is_empty() or state.revision!=0 or state.elapsed_ms!=0 or death==null or death.snapshot().phase!="ready":return reject("Register selected40 sound before the first native frame")
	var constructor: RefCounted=world.scenery_owner().world_initialization_owner().npc_construction_owner()
	if constructor==null or world.player_owner().selected40_construction_owner()!=constructor or death.snapshot().departure_cursor!=40:return reject("Selected40 audio lost its exact native generation")
	return _configure_retained_flight(library,bindings,world,constructor,40,audio_seed)

func configure_mission(library: RefCounted,bindings: RefCounted,world: RefCounted,audio_seed: int=0) -> bool:
	var context: RefCounted=load("res://src/simulation/mission_context.gd").from_owner(world)
	if _identity!=null or context==null:return reject("Register mission audio once on its admitted native flight")
	var initialized: RefCounted=world.initialized_world_owner()
	var constructor: RefCounted=initialized.construction_owner().npc_construction_owner()
	return _configure_retained_flight(library,bindings,world,constructor,int(context.identity().campaign_cursor),audio_seed)

func _configure_retained_flight(library: RefCounted,bindings: RefCounted,world: RefCounted,constructor: RefCounted,cursor: int,audio_seed: int) -> bool:
	var state: Dictionary=world.audio_state();var death: RefCounted=world.destruction_owner()
	if state.is_empty() or state.revision!=0 or state.elapsed_ms!=0 or death==null or death.snapshot().phase!="ready":return reject("Register retained flight sound before the first native frame")
	var dialogue: Dictionary=Dialogue.select(bindings,cursor)
	if not Dialogue.valid_parameters(dialogue,cursor) or not PlayerDeath.parameters(bindings.player_destruction) or not WeaponAudio.parameters(bindings.weapon_parameters.get("audio",{})) or not Death.audio_parameters(bindings.opening_actors.get("npc_initialization",{}).get("destruction_audio",{})):return reject("Selected40 sound lacks original radio, weapon or destruction declarations")
	var resources:=Resources.new()
	if not resources.configure(library,bindings,cursor):return reject(resources.error)
	var actors: Array=constructor.snapshot().actors
	var sounds: Array=[];var weapons: Array=[]
	var weapon_rules: Dictionary=bindings.weapon_parameters.audio
	for actor in actors:
		var kind: int=actor.actor_kind
		var id: int=-1 if actor.population_group!="fighter" else int(weapon_rules.npc_event_ids[kind]) if kind<weapon_rules.npc_event_ids.size() else int(weapon_rules.npc_default_event_id)
		weapons.append(id)
		if id>=0:sounds.append(id)
	var death_rules: Dictionary=bindings.player_destruction
	var npc_death: Dictionary=bindings.opening_actors.npc_initialization.destruction_audio
	var freighter: Dictionary=load("res://src/content/freighter_destruction_definitions.gd").for_faction(bindings,int(actors[0].actor_kind))
	if freighter.is_empty():return reject("Selected40 freighter sound lacks its original constructor")
	sounds.append_array([death_rules.breakup_sound_base,death_rules.breakup_sound_base+1,death_rules.failure_sound,npc_death.initial_source_id])
	sounds.append_array(npc_death.breakup_source_ids)
	sounds.append_array(dialogue.voice.event_ids)
	var scanner_id:=int(bindings.opening_staging.npc_scanner.acquisition_sound_id)
	sounds.append(scanner_id)
	var engine_state: Dictionary=state.combat.get(PLAYER_ENGINE,{})
	if engine_state.is_empty() or not state.has("flight_music"):return reject("Selected40 sound requires its retained engine and native music selector")
	sounds.append(engine_state.source_id)
	sounds.append_array([bindings.ordinary_music.portal_peace_id,bindings.ordinary_music.portal_battle_id])
	for id in sounds:
		if id<0:continue
		var clip: Dictionary=resources.prepare(int(id))
		if clip.is_empty() or clip.has("unsupported"):return reject("Unsupported selected40 source sound: "+str(id)+" "+str(clip.get("unsupported",resources.error)))
	_resources=resources;_seed_value=audio_seed;_random.seed=audio_seed
	_engine_ids=[int(engine_state.initial_source_id)];_arrival_engine_id=-1;_flight_music_attached=true
	_content_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id}
	_player_death_rules=death_rules.duplicate(true);_weapon_audio=weapon_rules.duplicate(true)
	_death_audio=npc_death.duplicate(true);_death_audio.initial_source_id=int(npc_death.initial_source_id)
	_death_audio.breakup_source_ids=Array(npc_death.breakup_source_ids).map(func(id):return int(id))
	_freighter_audio=freighter;_freighter_actors=[0];_npc_count=actors.size();_npc_weapon_sounds=weapons;_npc_scan_sound=scanner_id
	_secondary_audio=SecondaryAudio.VALUES.duplicate(true) if SecondaryAudio.available(bindings) else {}
	_radio_voice=dialogue.voice.duplicate(true)
	_radio_identity=_content_identity.duplicate();_radio_identity.language=library.active_language;_radio_identity.campaign_cursor=cursor
	_voice_displayed.resize(_radio_voice.event_ids.size());_voice_displayed.fill(false)
	_selected40_identity=world.presentation_identity();_flight_identity=death.presentation_identity()
	_identity=RefCounted.new();_viewport=get_viewport();_previous_listener=_viewport.is_audio_listener_3d();_viewport.set_as_audio_listener_3d(true)
	return true

func prepare_selected40(world: RefCounted) -> Dictionary:
	error=""
	if not is_instance_of(world,load("res://src/simulation/selected40_flight_frame.gd")) or _selected40_identity==null or world.presentation_identity()!=_selected40_identity or world.destruction_owner().presentation_identity()!=_flight_identity:return fail("Selected40 sound rejected another native flight")
	return _prepare_retained_flight(world)

func prepare_mission(world: RefCounted) -> Dictionary:
	var context: RefCounted=load("res://src/simulation/mission_context.gd").from_owner(world)
	if context==null or _selected40_identity==null or world.presentation_identity()!=_selected40_identity or world.destruction_owner().presentation_identity()!=_flight_identity:return fail("Mission sound rejected another native flight")
	return _prepare_retained_flight(world)

func _prepare_retained_flight(world: RefCounted) -> Dictionary:
	var state: Dictionary=world.audio_state()
	if state.is_empty() or not Definitions.integer(state.revision,maxi(0,_flight_serial),_flight_serial+1) or not Definitions.integer(state.elapsed_ms,_elapsed_ms,0x7fffffff):return fail("Selected40 sound lost its next completed native revision")
	if state.revision==_flight_serial:
		if state.elapsed_ms!=_elapsed_ms:return fail("Repeated selected40 sound changed its clock")
		return {"identity":_identity,"revision":_revision,"repeat":true}
	var commands: Array[Dictionary]=[]
	var events: Dictionary=state.death_events
	for phase in ["player_tail","player_poll"]:
		var prepared:=prepare_player_death({} if phase=="player_tail" and events.get("started",false) else events,phase)
		if prepared.is_empty():return {}
		commands.append_array(prepared.operations)
	for event in state.scanner_events:
		if not event is Dictionary or event.get("kind")!="sound" or event.get("source_id")!=_npc_scan_sound or not Definitions.integer(event.get("actor_id"),0,_npc_count-1):return fail("Selected40 acquisition sound lost its native scanner")
		commands.append({"action":"start","source_id":_npc_scan_sound})
	var view:={"booster":state.get("booster",{}),"cloak":state.get("cloak",{}),"elapsed_ms":state.elapsed_ms,"camera":{"view":state.camera_view},"escape":{"frame":{"audio":commands}},"radio":state.radio,"radio_changes":state.radio_events}
	var music:=prepare_flight_music(state)
	if music.is_empty():return {}
	var result:=prepare_frame(_revision+1,view,state.combat,music.operations)
	if result.is_empty():return {}
	result.flight_serial=state.revision
	return result

func configure_full_hold(library: RefCounted,bindings: RefCounted,world: RefCounted,audio_seed: int=0) -> bool:
	if not world is MiningFlight:return reject("Flight audio requires its native world")
	var state: Dictionary=world.snapshot()
	var death: RefCounted=world.destruction_owner()
	for key in ["base_content_id","binding_id"]:
		if bindings==null or state.get(key)!=bindings.get(key):return reject("Second-flight audio belongs to another content identity")
	if state.get("campaign_cursor")==2 and death==null:
		if not state.has("mining_session") or not state.has("mining_targeting") or not state.has("mining_approach") or not state.has("world_elapsed_ms"):
			return reject("First mining audio requires its accepted native owners")
		if not configure(library,bindings,audio_seed,2):return false
		_mining_only=true
		_flight_music_attached=state.has("flight_music")
		return configure_mining_audio(bindings,state)
	if death==null:return reject("Second-flight audio requires its native destruction owner")
	if not state.get("flight_audio") is Dictionary or state.flight_audio.get("serial")!=0:return reject("Register second-flight audio before advancing its world")
	var cursor: int=state.player_destruction.departure_cursor
	if state.campaign_cursor!=cursor:return reject("Register ordinary-flight sound in its initial mission")
	var combat: Dictionary=state.get("encounter",{}).get("combat",{})
	var mission_context: RefCounted=world.mission_context_owner()
	var local_flight:=OrdinaryFlight.combat_population(bindings,combat,mission_context)
	var travel: Variant=state.get("local_travel",{})
	if not travel is Dictionary or (not travel.is_empty() and (not local_flight or travel.get("event_serial")!=0 or travel.get("events")!=[])):return reject("Register local travel audio before its first event")
	if not configure(library,bindings,audio_seed,cursor,combat if local_flight else {},mission_context):return false
	if state.has("void_probe_stage")!=state.has("void_probe") or (cursor==29)!=state.has("void_probe_stage"):
		return reject("Probe sound requires its selected stage and model")
	if cursor==29:
		if not VoidProbe.parameters(bindings.mido_travel.get("void_probe",{})):return reject("Original probe sound declaration is unavailable")
		_probe_sound=int(bindings.mido_travel.void_probe.world29.probe.sound_event_id)
		var probe_clip: Dictionary=_resources.prepare(_probe_sound)
		if probe_clip.is_empty() or probe_clip.has("unsupported") or not probe_clip.get("spatial",false):return reject("Original probe sound is unavailable: "+str(_probe_sound))
	if world.tractor_owner()!=null:
		var pull: Dictionary=bindings.mido_travel.tractor_recovery.pull
		_tractor_sounds=[int(pull.loop_sound),int(pull.pickup_sound)]
		for id in _tractor_sounds:
			var clip: Dictionary=_resources.prepare(id)
			if clip.is_empty() or clip.has("unsupported"):return reject("Original tractor sound is unavailable: "+str(clip.get("unsupported",_resources.error)))
	if state.has("sahi_stage"):
		_portal_sound=int(bindings.mido_travel.sahi_stage.spin.sound_event_id)
		var clip: Dictionary=_resources.prepare(_portal_sound)
		if clip.is_empty() or clip.has("unsupported"):return reject("Original portal sound is unavailable: "+str(clip.get("unsupported",_resources.error)))
	_notified_result_serial=int(state.get("contracts",{}).get("last_result",{}).get("serial",0))
	_travel_attached=not travel.is_empty()
	_flight_identity=death.presentation_identity()
	_flight_music_attached=state.has("flight_music")
	if not configure_mining_audio(bindings,state):return false
	return true

func configure_mining_audio(bindings: RefCounted,state: Dictionary) -> bool:
	_mining_attached=state.has("mining_session")
	if not _mining_attached:return true
	var batch: Variant=state.get("mining_audio")
	if not batch is Dictionary or batch.get("serial")!=0 or batch.get("events")!=[]:
		return reject("Mining sound must attach before its first event")
	var rates: Variant=bindings.mining_drill.get("spin_rates")
	if not rates is Array or rates.size()!=7 or rates[0]!=5.0 or rates[-1]!=38.0:
		return reject("Mining sound lacks the original drill-speed thresholds")
	_drill_rates=rates.duplicate()
	for id in [1,2,3,26]:
		var clip: Dictionary=_resources.prepare(id)
		if clip.is_empty() or clip.has("unsupported"):
			return reject("Original mining sound is unavailable: "+str(id)+" "+str(clip.get("unsupported",_resources.error)))
	return true

func current_music_id() -> int:return _music

func prepare_full_hold(world: RefCounted, state: Dictionary={}) -> Dictionary:
	error=""
	if not world is MiningFlight or _identity==null:return fail("Flight audio follows one configured native world")
	if not _mining_only:
		var death: RefCounted=world.destruction_owner()
		if _flight_identity==null or death==null or death.presentation_identity()!=_flight_identity:return fail("Second-flight audio follows one configured native world")
	if state.is_empty():state=world.snapshot()
	for key in _content_identity:
		if state.get(key)!=_content_identity[key]:return fail("Second-flight audio frame changed content identity")
	var mining:=prepare_mining_audio(state)
	if mining.is_empty():return {}
	var flight_music:=prepare_flight_music(state)
	if flight_music.is_empty():return {}
	var booster:=prepare_booster(state.get("booster",{}))
	var cloak:=prepare_cloak(state.get("cloak",{}))
	if booster.is_empty() or cloak.is_empty():return {}
	if _mining_only:
		var mining_elapsed: Variant=state.get("world_elapsed_ms")
		if not Definitions.integer(mining_elapsed,_elapsed_ms,0x7fffffff) or state.get("campaign_cursor") not in [2,3]:return fail("First mining audio frame changed its mission or clock")
		if _revision>=0 and mining_elapsed==_elapsed_ms and mining.serial==_mining_serial and flight_music.operations.is_empty() and booster.serial==_booster_serial and cloak.serial==_cloak_serial:return {"identity":_identity,"revision":_revision,"repeat":true}
		var mining_view:={"booster":state.get("booster",{}),"cloak":state.get("cloak",{}),"elapsed_ms":int(mining_elapsed),"camera":{"view":state.camera_view},"escape":{"frame":{"audio":mining.operations+flight_music.operations}}}
		if mining.parameter!=null:mining_view.mining_drill_parameter=mining.parameter
		var mining_frame:=prepare_frame(_revision+1,mining_view)
		if mining_frame.is_empty():return {}
		mining_frame.mining_serial=mining.serial
		return mining_frame
	var cues: Variant=state.get("flight_audio")
	var elapsed: Variant=state.get("damage_particles",{}).get("elapsed_ms") if int(state.get("player_destruction",{}).get("departure_cursor",-1))==2 else state.get("encounter",{}).get("elapsed_ms")
	if not cues is Dictionary or cues.size()!=4 or not Definitions.integer(cues.get("serial"),maxi(0,_flight_serial),_flight_serial+1) or not Definitions.integer(elapsed,_elapsed_ms,0x7fffffff):return fail("Second-flight audio frame is out of sequence")
	var travel:=prepare_travel(state)
	if travel.is_empty():return {}
	var notification:=prepare_contract_notification(state)
	if notification.is_empty():return {}
	var repeated: bool=cues.serial==_flight_serial
	if repeated:
		if elapsed!=_elapsed_ms:return fail("Repeated second-flight sound frame changed its clock")
		if travel.operations.is_empty() and notification.serial==_notified_result_serial and travel.attached==_travel_attached and mining.serial==_mining_serial and flight_music.operations.is_empty() and booster.serial==_booster_serial and cloak.serial==_cloak_serial:return {"identity":_identity,"revision":_revision,"repeat":true}
		if not travel.operations.is_empty() and (travel.operations.size()!=1 or travel.operations[0].source_id!=_travel_sounds[1]):return fail("A manual travel action emitted a flight acquisition cue")
	var commands: Array[Dictionary]=[]
	if not repeated:
		for phase in ["player_tail","player_poll"]:
			var prepared:=prepare_player_death(cues.get(phase),phase)
			if prepared.is_empty():return {}
			commands.append_array(prepared.operations)
		var recovery:=prepare_tractor(state.get("tractor_frame",{}))
		if recovery.is_empty():return {}
		commands.append_array(recovery.operations)
		for cue in state.get("sahi_stage",{}).get("frame",{}).get("cues",[]):
			if cue.kind not in ["sound_start","sound_position"]:continue
			if _portal_sound<0 or cue.get("event_id")!=_portal_sound:return fail("Portal sound belongs to another scene")
			if cue.kind=="sound_start":commands.append({"action":"start","source_id":_portal_sound})
			else:
				if cue.get("velocity")!=Vector3.ZERO:return fail("Unsupported portal sound velocity")
				commands.append({"action":"position","source_id":_portal_sound,"position":cue.get("position")})
		if _probe_sound>=0:
			var stage: Variant=state.get("void_probe_stage")
			var probe_state: Variant=state.get("void_probe")
			if not stage is Dictionary or not probe_state is Dictionary or stage.get("campaign_cursor")!=29 or not stage.get("phase") is int or stage.phase not in [0,1,2] or not stage.get("frame") is Dictionary or not stage.frame.get("cues") is Array:
				return fail("Probe sound lost its native stage frame")
			for key in _content_identity:
				if stage.get(key)!=_content_identity[key]:return fail("Probe sound belongs to another content identity")
			var sound_count:=0
			for cue in stage.frame.cues:
				if not cue is Dictionary:return fail("Invalid probe stage sound cue")
				if cue.get("kind")!="sound_start":continue
				sound_count+=1
				if sound_count>1 or stage.phase!=1 or cue.get("event_id")!=_probe_sound or not cue.get("position") is Vector3 or not cue.position.is_finite() or probe_state.get("visible")!=true:
					return fail("Probe launch sound differs from its source cue")
				commands.append({"action":"start_spatial","source_id":_probe_sound,"position":cue.position})
		if state.has("convoy_capture"):
			var capture: Dictionary=state.convoy_capture
			if capture.get("campaign_cursor")!=14:return fail("Capture audio belongs to another scene")
			for cue in capture.get("frame",{}).get("audio",[]):
				if cue.get("source_id")!=15 or cue.get("action") not in ["start","start_spatial"]:return fail("Capture requested an unsupported sound")
				commands.append(cue.duplicate(true))
			if capture.get("frame",{}).get("disable_player",false):commands.append({"action":"stop_player_engine"})
		for event in state.get("npc_scanner_events",[]):
			if not event is Dictionary or event.get("kind")!="sound" or event.get("source_id")!=_npc_scan_sound or not Definitions.integer(event.get("actor_id"),0,_npc_count-1):return fail("Invalid training acquisition sound")
			commands.append({"action":"start","source_id":_npc_scan_sound})
	commands.append_array(mining.operations)
	commands.append_array(flight_music.operations)
	var view:={"booster":state.get("booster",{}),"cloak":state.get("cloak",{}),"elapsed_ms":int(elapsed),"camera":{"view":state.camera_view},"escape":{"frame":{"audio":commands}}}
	if mining.parameter!=null:view.mining_drill_parameter=mining.parameter
	if state.has("radio"):
		view.radio=state.radio;view.radio_changes=[] if repeated else state.radio_events
	var combat:={}
	if not repeated and state.has("encounter"):
		combat=_content_identity.duplicate()
		for key in ["primary_fire","primaries","secondaries","secondary_events"]:
			if state.encounter.has(key):combat[key]=state.encounter[key]
		combat.elapsed_ms=int(elapsed);combat.actor_events=cues.get("actors")
	var result:=prepare_frame(_revision+1,view,combat,travel.operations+notification.operations)
	if result.is_empty():return {}
	result.flight_serial=int(cues.serial)
	result.travel_serial=int(travel.serial)
	result.travel_attached=travel.attached
	result.contract_result_serial=int(notification.serial)
	result.mining_serial=int(mining.serial)
	return result

func prepare_mining_audio(state: Dictionary) -> Dictionary:
	var operations: Array[Dictionary]=[]
	if not _mining_attached:return {"serial":0,"operations":operations,"parameter":null}
	var batch: Variant=state.get("mining_audio")
	if not batch is Dictionary or batch.size()!=2 or not Definitions.integer(batch.get("serial"),_mining_serial,_mining_serial+1) or not batch.get("events") is Array or batch.events.size()>4:
		return fail("Mining sound batch is out of sequence")
	var active: Variant=state.get("mining_session",{}).get("drill",{})
	if not active is Dictionary:return fail("Mining sound lost its native drill state")
	var parameter: Variant=null
	if not active.is_empty():
		var layer: Variant=active.get("layer_index")
		if active.get("phase")!="drilling" or not Definitions.integer(layer,0,_drill_rates.size()-1):return fail("Mining sound has an invalid drill layer")
		var value:=Sequence.f32(float(_drill_rates[int(layer)])-5.0)
		value=Sequence.f32(value/33.0)
		parameter=Sequence.f32(value*3.0)
	for event in batch.events:
		if not event is Dictionary or event.size()!=2 or event.get("action") not in ["start","stop"] or not Definitions.integer(event.get("source_id"),0,26):return fail("Invalid mining sound transition")
		var id: int=int(event.source_id)
		if (event.action=="start" and id not in [1,2,26]) or (event.action=="stop" and id not in [1,3]):return fail("Mining sound requested another source event")
		if id==1 and event.action=="start" and parameter==null:return fail("Drill sound started without its accepted layer")
		if int(batch.serial)==_mining_serial:continue
		# Source acquisition26 is suppressed while its cached precursor0 plays.
		if id==26 and _players.has(0):continue
		var op:={"action":event.action,"source_id":id}
		if id==1 and event.action=="start":op.parameter=parameter
		operations.append(op)
	if int(batch.serial)==_mining_serial+1 and batch.events.is_empty():return fail("Mining sound serial advanced without a source event")
	return {"serial":int(batch.serial),"operations":operations,"parameter":parameter}

func prepare_flight_music(state: Dictionary) -> Dictionary:
	var operations: Array[Dictionary]=[]
	if not _flight_music_attached:return {"operations":operations}
	var batch: Variant=state.get("flight_music")
	if not batch is Dictionary or batch.size()!=1 or not batch.get("operations") is Array or batch.operations.size()>1:
		return fail("Ordinary music lost its accepted selection")
	for event in batch.operations:
		if not event is Dictionary or event.size()!=2 or event.get("action")!="replace_music" or event.get("source_id") not in [134,136,137,138,139,140,141,142,145,149,150,151,152]:
			return fail("Ordinary music requested an unsupported source event")
		if int(event.source_id)!=_music:operations.append(event.duplicate(true))
	return {"operations":operations}

func prepare_tractor(frame: Dictionary) -> Dictionary:
	var operations: Array[Dictionary]=[]
	for event in frame.get("events",[]):
		if event.get("kind") not in ["sound","stop_sound"]:continue
		if _tractor_sounds.is_empty() or event.get("source_id") not in _tractor_sounds:return fail("Unprepared tractor sound event")
		if event.kind=="stop_sound" and event.source_id!=_tractor_sounds[0]:return fail("Only the retained tractor loop can stop")
		operations.append({"action":"start" if event.kind=="sound" else "stop","source_id":int(event.source_id)})
	return {"operations":operations}

func prepare_contract_notification(state: Dictionary) -> Dictionary:
	var result: Dictionary=state.get("contracts",{}).get("last_result",{})
	var operations: Array[Dictionary]=[]
	var serial:=int(result.get("serial",0))
	if serial==_notified_result_serial:return {"serial":serial,"operations":operations}
	if _notification_sound<0 or serial!=_notified_result_serial+1 or result.get("acknowledgement_required",true):return fail("Contract payment sound lost its acknowledged result")
	var id:=int(result.get("notification_sound_id",-1))
	if id>=0:
		if id!=_notification_sound or not result.get("completed",false):return fail("Contract result requested another payment sound")
		operations.append({"action":"start","source_id":id,"contract_result_serial":serial})
	return {"serial":serial,"operations":operations}

func prepare_travel(state: Dictionary) -> Dictionary:
	var operations: Array[Dictionary]=[]
	var travel: Variant=state.get("local_travel",{})
	if not travel is Dictionary:return fail("Invalid local travel audio owner")
	if travel.is_empty():
		if _travel_attached:return fail("Local travel audio lost its configured world owner")
		return {"serial":0,"operations":operations,"attached":false}
	if not _travel_attached:
		# Final pursuit Next enables navigation without replacing this world.
		if state.get("encounter",{}).get("campaign_cursor")!=26 or state.get("campaign_cursor")!=27 or not state.get("mining_objective",{}).get("combat_objective_acknowledged",false) or travel.get("event_serial")!=0 or travel.get("events")!=[]:return fail("Local travel sound has no acknowledged continuation")
	for key in _content_identity:
		if travel.get(key)!=_content_identity[key]:return fail("Local travel sound changed its content identity")
	var serial: Variant=travel.get("event_serial");var events: Variant=travel.get("events")
	if _travel_sounds.size()!=2 or not Definitions.integer(serial,_travel_serial,_travel_serial+1) or not events is Array or events.size()>2:return fail("Local travel sound batch is out of sequence")
	var ids: Array[int]=[]
	for event in events:
		if not event is Dictionary or event.size()!=2 or event.get("kind")!="sound" or not Definitions.integer(event.get("source_id"),0,19999) or not _travel_sounds.has(int(event.source_id)):return fail("Invalid local travel sound event")
		ids.append(int(event.source_id))
	if ids.size()==2 and ids!=_travel_sounds:return fail("Local travel sounds changed their acquisition/launch order")
	if serial==_travel_serial:return {"serial":serial,"operations":operations,"attached":true}
	if ids.is_empty() or not Definitions.integer(travel.get("acquired_station_id"),0,2147483647):return fail("Local travel sound has no acquired destination")
	if travel.get("phase") not in ["flight","launch"] or (travel.phase=="launch" and ids.back()!=_travel_sounds[1]):return fail("Local travel sound is missing its departure transition")
	if ids.has(_travel_sounds[1]) and (travel.get("phase")!="launch" or travel.get("launch_ms")!=0 or travel.get("destination_station_id")!=travel.acquired_station_id):return fail("Local launch sound has no new departure")
	for id in ids:operations.append({"action":"start","source_id":id,"travel_serial":int(serial),"destination_station_id":int(travel.acquired_station_id)})
	return {"serial":int(serial),"operations":operations,"attached":true}

func prepare_player_death(events: Variant,phase: String) -> Dictionary:
	if not events is Dictionary:return fail("Invalid player destruction sound phase")
	var operations: Array[Dictionary]=[]
	if events.is_empty():return {"operations":operations}
	for flag in ["started","breakup","failed"]:
		if not events.get(flag) is bool:return fail("Invalid player destruction sound transition")
	if events.started and (phase!="player_poll" or events.breakup or events.failed):return fail("Player destruction started outside its poll")
	var ids: Variant=events.get("sound_events");var cues: Variant=events.get("audio_events")
	if not ids is Array or not cues is Array or ids.size()!=int(events.breakup)+int(events.failed) or cues.size()!=ids.size():return fail("Player sounds differ from their death transitions")
	for i in cues.size():
		var cue: Variant=cues[i]
		if not cue is Dictionary or cue.size()!=2 or not cue.has("position") or cue.get("source_id")!=ids[i]:return fail("Invalid player destruction sound cue")
		var breakup: bool=events.breakup and i==0
		if breakup:
			if not Definitions.integer(ids[i],int(_player_death_rules.breakup_sound_base),int(_player_death_rules.breakup_sound_base)+int(_player_death_rules.breakup_sound_bound)-1) or not cue.get("position") is Vector3 or not cue.position.is_finite():return fail("Invalid player breakup sound or position")
			if phase=="player_tail":operations.append({"action":"start_spatial","source_id":int(ids[i]),"position":cue.position,"actor_id":"player"})
		else:
			if ids[i]!=int(_player_death_rules.failure_sound) or cue.get("position")!=null:return fail("Invalid player failure sound")
			if phase=="player_poll":operations.append({"action":"start","source_id":int(ids[i]),"actor_id":"player"})
	if events.started:
		if events.get("stop_current_music")!=true or events.get("stop_current_engine_sound")!=true:return fail("Player death changed its current music/engine stops")
		var stops: Variant=events.get("stop_sound_ids")
		if not stops is Array or stops.size()!=_player_death_rules.stop_sound_ids.size():return fail("Player death changed its source sound stop extent")
		for i in stops.size():
			if not Definitions.integer(stops[i],int(_player_death_rules.stop_sound_ids[i]),int(_player_death_rules.stop_sound_ids[i])):return fail("Player death changed its source sound stop order")
		operations.append({"action":"stop_music"});operations.append({"action":"stop_player_engine"})
		for id in events.stop_sound_ids:operations.append({"action":"stop","source_id":int(id)})
	return {"operations":operations}

func prepare_frame(revision: int, state: Dictionary, world: Dictionary={}, following_audio: Array[Dictionary]=[]) -> Dictionary:
	error=""
	if _identity==null or revision<_revision or revision>_revision+1:return fail("Audio frame revision is out of sequence")
	if revision==_revision:return {"identity":_identity,"revision":revision,"repeat":true}
	var view: Variant=state.get("camera",{}).get("view",{}).get("pose",Transform3D.IDENTITY)
	if not view is Transform3D or not view.is_finite():return fail("Invalid audio listener pose")
	var elapsed: Variant=state.get("elapsed_ms")
	if not Definitions.integer(elapsed,_elapsed_ms,0x7fffffff):return fail("Invalid audio clock")
	var layer_frames: Array[Dictionary]=[]
	for record in _players.values()+_retiring:
		if record.node is Layered:
			var parameter: Variant=state.get("mining_drill_parameter") if record.clip.id==1 else null
			var frame: Dictionary=record.node.prepare_step(int(elapsed)-_elapsed_ms,parameter)
			if frame.is_empty():return fail(record.node.error)
			layer_frames.append({"node":record.node,"frame":frame})
	var commands: Variant=state.get("escape",{}).get("frame",{}).get("audio",[])
	if not commands is Array or commands.size()>32:return fail("Invalid opening audio commands")
	commands=commands.duplicate(true)
	var booster:=prepare_booster(state.get("booster",{}))
	var cloak:=prepare_cloak(state.get("cloak",{}))
	if booster.is_empty() or cloak.is_empty():return {}
	commands.append_array(booster.operations)
	commands.append_array(cloak.operations)
	var combat_begin: int=commands.size()
	if (not _death_audio.is_empty() or not _weapon_audio.is_empty()) and not world.is_empty():
		var combat_frame:=prepare_combat(world,int(elapsed))
		if combat_frame.is_empty():return {}
		commands.append_array(combat_frame.operations)
	var combat_end: int=commands.size()
	var radio_frame:=prepare_radio(state)
	if radio_frame.is_empty():return {}
	commands.append_array(radio_frame.operations)
	if following_audio.size()>2:return fail("Too many trailing flight sounds")
	commands.append_array(following_audio)
	var operations: Array[Dictionary]=[]
	for command_index in commands.size():
		var command: Variant=commands[command_index]
		if not command is Dictionary:return fail("Invalid opening audio operation")
		var action: Variant=command.get("action")
		if action not in ["replace_music","start","start_spatial","position","stop","stop_music","stop_player_engine","set_player_engine"]:return fail("Unsupported opening audio operation")
		var op: Dictionary=command.duplicate(true)
		if action not in ["stop_music","stop_player_engine"]:
			if not Definitions.integer(command.get("source_id"),0,19999):return fail("Invalid opening sound identifier")
			op.source_id=int(command.source_id)
		if action in ["start_spatial","position"]:
			if not command.get("position") is Vector3 or not command.position.is_finite():return fail("Invalid opening sound position")
		if command.has("pitch_raw") and (action!="start_spatial" or not Definitions.number(command.pitch_raw,0.0,1.0)):return fail("Invalid weapon sound pitch")
		if command.has("parameter") and (action!="start" or op.source_id!=1 or not Definitions.number(command.parameter,0.0,3.0)):return fail("Invalid drill sound parameter")
		if action=="start" and op.source_id==1 and not command.has("parameter"):return fail("Drill sound lacks its accepted parameter")
		if action in ["replace_music","start","start_spatial","set_player_engine"]:
			op.clip=_resources.prepare(op.source_id)
			if op.clip.is_empty():return fail(_resources.error)
			if op.clip.get("release_at_sample_end",false) and (command_index<combat_begin or command_index>=combat_end or action!="start_spatial" or not command.has("mount_id") or not command.has("item_id")):return fail("Continuous cannon sound lacks its verified primary owner")
			if op.clip.get("kind")=="parameter_loop" and not ParameterLoop.valid_context(op.get("position",Vector3.ZERO),view):return fail("Invalid engine sound spatial context")
		operations.append(op)
	for record in _players.values()+_retiring:
		if record.node is ParameterLoop and not ParameterLoop.valid_context(record.position,view):return fail("Invalid retained engine sound spatial context")
	var engine_frame:=prepare_engine(world,int(elapsed),view,operations)
	if engine_frame.is_empty():return {}
	return {"identity":_identity,"revision":revision,"repeat":false,"listener":view,"elapsed_ms":int(elapsed),"operations":operations,"layer_frames":layer_frames,"voice_displayed":radio_frame.displayed,"player_engine":engine_frame,"booster_serial":booster.serial,"cloak_serial":cloak.serial}

func prepare_cloak(state: Variant) -> Dictionary:
	if not state is Dictionary:return fail("Invalid cloak audio observation")
	if state.is_empty():return {"serial":_cloak_serial,"operations":[]}
	for key in _content_identity:
		if state.get(key)!=_content_identity[key]:return fail("Cloak sound belongs to another flight content")
	var serial: Variant=state.get("audio_serial")
	if not Definitions.integer(serial,_cloak_serial,_cloak_serial+1):return fail("Cloak sound lost its accepted lifecycle")
	if serial==_cloak_serial:return {"serial":serial,"operations":[]}
	var cues: Variant=state.get("audio")
	if not cues is Array or cues.size()!=1 or not cues[0] is Dictionary or cues[0].get("source_id")!=30 or cues[0].get("phase") not in ["active","cooldown"]:return fail("Cloak sound differs from its accepted cue")
	return {"serial":int(serial),"operations":[{"action":"start","source_id":30}]}

func prepare_booster(state: Variant) -> Dictionary:
	if not state is Dictionary:return fail("Invalid booster audio observation")
	if state.is_empty():return {"serial":_booster_serial,"operations":[]}
	for key in _content_identity:
		if state.get(key)!=_content_identity[key]:return fail("Booster sound belongs to another flight content")
	var serial: Variant=state.get("audio_serial")
	if not Definitions.integer(serial,_booster_serial,_booster_serial+2):return fail("Booster sound lost its accepted activation")
	if serial==_booster_serial:return {"serial":serial,"operations":[]}
	var id: Variant=state.get("item_id")
	var operations: Variant=state.get("audio")
	var count:=int(serial)-_booster_serial
	if not Booster.SOUND_IDS.has(id) or not operations is Array or operations.size()<count or operations.size()>2:return fail("Booster sound lost its fitted device")
	var pending: Array=operations.slice(operations.size()-count)
	for operation in pending:
		if not operation is Dictionary or operation.get("source_id")!=Booster.SOUND_IDS[id] or operation.get("action") not in ["start","stop"]:return fail("Booster sound differs from its device cue")
	return {"serial":int(serial),"operations":pending.duplicate(true)}

func prepare_engine(world: Dictionary,elapsed_ms: int,view: Transform3D,operations: Array) -> Dictionary:
	var state: Variant=world.get(PLAYER_ENGINE,{})
	if not state is Dictionary:return fail("Invalid retained player engine frame")
	if state.is_empty():
		if _engine_generation>=0:return fail("Retained player engine disappeared from its world")
		return {"present":false}
	for key in _content_identity:
		if state.get(key)!=_content_identity[key] or world.get(key)!=_content_identity[key]:return fail("Retained player engine belongs to another world")
	if world.get("elapsed_ms")!=elapsed_ms or state.get("elapsed_ms")!=elapsed_ms:return fail("Retained player engine clock differs from its world")
	if not Definitions.integer(state.get("initial_source_id"),0,19999) or state.initial_source_id not in _engine_ids:return fail("Invalid initial player engine selection")
	if not Definitions.integer(state.get("generation"),maxi(0,_engine_generation),mini(1,_engine_generation+1)) or not state.get("active") is bool:return fail("Invalid retained player engine lifetime")
	if _initial_engine_id>=0 and int(state.initial_source_id)!=_initial_engine_id:return fail("Initial player engine selection changed during flight")
	if not state.get("position") is Vector3 or not state.position.is_finite() or not state.get("source_commands") is Vector2 or not state.source_commands.is_finite():return fail("Invalid retained player engine position or controls")
	if absf(state.source_commands.x)>1 or absf(state.source_commands.y)>1:return fail("Retained player engine commands exceed normalized input")
	var expected: int=int(state.initial_source_id) if state.generation==0 else _arrival_engine_id
	if not Definitions.integer(state.get("source_id"),expected,expected) or expected<0:return fail("Player engine replacement differs from its source controller")
	if state.generation==0:
		if not EngineParameters.valid_parameters(state.get("parameters")):return fail("Invalid ordinary player engine parameters")
	elif not state.get("parameters") is Array or not state.parameters.is_empty():return fail("The arrival engine uses its own timed parameter")
	var replacements:=0
	for op in operations:
		if op.action=="set_player_engine":
			replacements+=1
			if state.generation!=1 or _engine_generation!=0 or op.source_id!=expected:return fail("Retained engine replacement lacks its controller transition")
		elif op.action in ["start","start_spatial","replace_music"] and op.source_id==expected:return fail("The player engine requires its retained instance")
	if replacements!=int(state.generation==1 and _engine_generation==0):return fail("Retained engine lifetime differs from its controller transition")
	var clip: Dictionary=_resources.prepare(expected)
	if clip.is_empty():return fail(_resources.error)
	if state.generation==0 and clip.get("kind")!="parameter_loop":return fail("The initial player engine has unsupported playback behavior")
	if state.generation==1 and clip.get("kind")!="layered":return fail("The arrival engine has unsupported playback behavior")
	if state.generation==0 and not ParameterLoop.valid_context(state.position,view):return fail("Invalid retained player engine listener")
	var result: Dictionary=state.duplicate(true);result.present=true;result.clip=clip
	return result

func prepare_radio(state: Dictionary) -> Dictionary:
	if not _local_radio_rules.is_empty():return prepare_local_radio(state)
	var displayed:=_voice_displayed.duplicate()
	var operations: Array[Dictionary]=[]
	if _radio_voice.is_empty() or (not state.has("radio") and not state.has("radio_changes")):return {"operations":operations,"displayed":displayed}
	var radio: Variant=state.get("radio")
	var changes: Variant=state.get("radio_changes")
	if not radio is Dictionary or not changes is Array or changes.size()>3:return fail("Invalid radio voice frame")
	for key in _radio_identity:
		if radio.get(key)!=_radio_identity[key]:return fail("Radio voice belongs to another content or text language")
	for key in ["started","finished"]:
		var rows: Variant=radio.get(key)
		if not rows is Array or rows.size()!=displayed.size():return fail("Invalid radio voice event extent")
		for value in rows:
			if not value is bool:return fail("Invalid radio voice event flag")
	if not Definitions.integer(radio.get("active_event"),-1,displayed.size()-1) or not radio.get("visible") is bool:return fail("Invalid active radio voice display")
	if radio.active_event>=0:
		if not radio.started[radio.active_event] or radio.get("text_id")!=_radio_voice.text_ids[radio.active_event]:return fail("Active radio voice differs from its text")
	elif radio.visible:return fail("Visible radio voice has no active event")
	var displayed_now:=-1
	for change in changes:
		if not change is Dictionary or change.get("kind") not in ["started","display","finished"] or not Definitions.integer(change.get("event"),0,displayed.size()-1):return fail("Invalid radio voice transition")
		if change.size()!=(3 if change.kind=="display" else 2):return fail("Invalid radio voice transition fields")
		if change.kind!="display":continue
		var event:=int(change.event)
		if displayed_now>=0 or displayed[event] or not radio.started[event] or change.get("text_id")!=_radio_voice.text_ids[event]:return fail("Radio voice repeated or differs from its text display")
		displayed_now=event;displayed[event]=true
		if _radio_voice.event_ids[event]>=0:
			operations.append({"action":"start","source_id":int(_radio_voice.event_ids[event]),"radio_event":event,"text_id":int(change.text_id)})
	if displayed_now>=0:
		var visible: bool=radio.get("visible")==true and radio.get("active_event")==displayed_now
		var finished: bool=radio.finished[displayed_now] and changes.any(func(change):return change.kind=="finished" and change.event==displayed_now)
		if not visible and not finished:return fail("Radio voice has no accepted display transition")
	return {"operations":operations,"displayed":displayed}

func prepare_local_radio(state: Dictionary) -> Dictionary:
	var radio: Variant=state.get("radio");var changes: Variant=state.get("radio_changes")
	if not radio is Dictionary or not changes is Array or changes.size()>3:return fail("Invalid local radio voice frame")
	for key in _radio_identity:
		if radio.get(key)!=_radio_identity[key]:return fail("Local voice belongs to another content or language")
	if not Definitions.integer(radio.get("last_serial"),0,2) or not Definitions.integer(radio.get("active_event"),-1,0) or not radio.get("visible") is bool:return fail("Invalid local voice lifetime")
	var message: Variant=radio.get("message")
	if not message is Dictionary:return fail("Local voice lost its message")
	if radio.active_event==0:
		if not LocalRadio.valid_payload(_local_radio_rules,message) or message.serial>radio.last_serial or radio.get("text_id")!=message.text_id or radio.get("speaker_id")!=message.speaker_id or radio.get("started")!=[true] or radio.get("finished")!=[false]:return fail("Local voice differs from its active text")
	elif radio.visible or not message.is_empty():return fail("Inactive local voice retained a visible message")
	var displayed:=_voice_displayed.duplicate();var operations: Array[Dictionary]=[]
	var displayed_now:=0;var transition_message:={};var previous_phase:=-1
	for change in changes:
		if not change is Dictionary or change.size()!=7 or change.get("event")!=0 or change.get("kind") not in ["started","display","finished"]:return fail("Invalid local voice transition")
		var phase: int=["started","display","finished"].find(change.kind)
		if phase<=previous_phase:return fail("Local voice transitions are out of order")
		previous_phase=phase
		var selected:={"serial":change.get("serial"),"kind":change.get("message_kind"),"speaker_id":change.get("speaker_id"),"text_id":change.get("text_id"),"voice_event_id":change.get("voice_event_id")}
		if not LocalRadio.valid_payload(_local_radio_rules,selected) or selected.serial>radio.last_serial:return fail("Local voice lost its source text and recording pair")
		if not transition_message.is_empty() and selected!=transition_message:return fail("Local voice changed message within one update")
		transition_message=selected
		if change.kind!="display":continue
		var index: int=selected.serial-1
		if displayed[index]:return fail("Local voice repeated an accepted display")
		displayed[index]=true;displayed_now=selected.serial
		operations.append({"action":"start","source_id":selected.voice_event_id,"radio_event":selected.serial,"text_id":selected.text_id})
	if not transition_message.is_empty():
		var finished: bool=changes[-1].kind=="finished"
		if finished:
			if radio.active_event!=-1 or not displayed[transition_message.serial-1]:return fail("Local voice finished without an accepted display")
		elif message!=transition_message:return fail("Local voice transition differs from the active transmission")
	if displayed_now>0 and radio.active_event==0 and not radio.visible:return fail("Local voice has no accepted text display")
	return {"operations":operations,"displayed":displayed}

## Secondary launch sounds use their own declared events. Detonation must not
## replay launch audio, and rejected frame preparation must remain silent.
func prepare_secondaries(world: Dictionary) -> Dictionary:
	var operations: Array[Dictionary]=[]
	var events: Variant=world.get("secondary_events",[])
	if not events is Array:return fail("Invalid secondary sound event list")
	if not world.has("secondaries"):
		return {"operations":operations} if events.is_empty() else fail("Secondary sound lost its launcher")
	var owner: Variant=world.secondaries
	if _secondary_audio.is_empty() or not owner is Dictionary or not owner.get("guns") is Array or not owner.get("loadout") is Dictionary:return fail("Secondary sound requires supported equipped ownership")
	for key in _content_identity:
		if owner.loadout.get(key)!=_content_identity[key]:return fail("Secondary sound belongs to another content identity")
	var guns: Array=owner.guns
	if guns.size()>255 or events.size()>65536:return fail("Secondary sound event extent exceeds the equipped launchers")
	var slots:={};var seen:={}
	for gun in guns:
		if not gun is Dictionary or not Definitions.integer(gun.get("slot_index"),0,1020) or slots.has(gun.slot_index) or not gun.get("equipment") is Dictionary:return fail("Secondary sound lost its installed launcher")
		if gun.has("bomb"):
			if not gun.bomb is Dictionary or not gun.equipment.get("item_id") is int or BombAudio.declaration(gun.equipment.item_id).is_empty():return fail("Unsupported bomb sound item")
		elif gun.has("mine"):
			if not gun.mine is Dictionary or not gun.equipment.get("item_id") is int or MineAudio.declaration(gun.equipment.item_id).is_empty():return fail("Unsupported mine sound item")
		elif not Conventional.resolved(gun.get("projectiles",{}).get("weapon",{})) or _weapon_audio.is_empty():return fail("Secondary sound lost its resolved conventional weapon")
		slots[gun.slot_index]=gun
	# Burst wrappers run in the early weapon pass, before late launch input.
	# Keep their forward creation order, not the reverse launcher traversal.
	var bursts:=prepare_secondary_detonations(owner)
	if bursts.is_empty():return {}
	operations.append_array(bursts.operations)
	for event in events:
		if not event is Dictionary or event.get("action") not in ["launched","detonated","impact"] or not slots.has(event.get("slot_index")) or not event.get("audio") is Dictionary:return fail("Invalid secondary sound transition")
		var gun: Dictionary=slots[event.slot_index]
		if event.get("item_id")!=gun.equipment.item_id:return fail("Secondary sound changed launcher identity")
		if event.action=="impact":
			if not gun.has("projectiles") or not event.audio.is_empty() or event.get("ammunition_consumed")!=0:return fail("Projectile impact replayed launch audio or spent ammunition")
			continue
		var key:=str(event.slot_index)+":"+str(event.action)
		if gun.has("mine") and event.action=="detonated":
			if not Definitions.integer(event.get("blast",{}).get("projectile_id"),1,2147483647):return fail("Mine blast lost its projectile sound identity")
			key+=":"+str(event.blast.projectile_id)
		if seen.has(key):return fail("Secondary sound repeated an event in one frame")
		seen[key]=true
		if event.action=="detonated":
			if not event.audio.is_empty() or event.get("ammunition_consumed")!=0:return fail("Detonation replayed launch audio or consumed ammunition")
			continue
		var id: int=int(BombAudio.declaration(event.item_id).launch_sound) if gun.has("bomb") else (int(MineAudio.declaration(event.item_id).launch_sound) if gun.has("mine") else int(_weapon_audio.player_event_ids[event.item_id]))
		var cue: Dictionary=event.audio
		if event.get("ammunition_consumed")!=1 or cue.size()!=3 or cue.get("source_id")!=id or cue.get("pitch_raw")!=_secondary_audio.launch_audio.pitch_raw or not cue.get("position") is Vector3 or not cue.position.is_finite():return fail("Secondary launch lost its declared sound, pitch or source position")
		operations.append({"action":"start_spatial","source_id":id,"position":cue.position,"pitch_raw":float(cue.pitch_raw),"item_id":int(event.item_id),"secondary_slot":int(event.slot_index)})
	return {"operations":operations,"detonation_count":bursts.operations.size()}

## Validate emitted wrapper cues, not a guessed sound inferred from a lingering
## effect. A same-frame relaunch can already have reset that wrapper's visuals.
func prepare_secondary_detonations(owner: Dictionary) -> Dictionary:
	var operations: Array[Dictionary]=[]
	var guns: Array=owner.guns
	var attached: bool=guns.any(func(gun):return gun.has("detonation") or gun.has("mine_bursts"))
	if not attached:
		return {"operations":operations} if not owner.has("detonation_audio") else fail("EMP sound has no retained burst wrappers")
	var cues: Variant=owner.get("detonation_audio")
	if not cues is Array or cues.size()>guns.size()*MineAudio.CAPACITY:return fail("Invalid area burst sound extent")
	var sources:={};var mines:={}
	for index in range(guns.size()-1,-1,-1):
		var gun: Dictionary=guns[index]
		if gun.has("mine"):
			var retained: Variant=gun.get("mine_bursts")
			if not retained is Dictionary or retained.get("weapon")!=gun.mine.weapon or not retained.get("bursts") is Array or retained.bursts.size()!=MineAudio.CAPACITY:return fail("Mine sound lost its retained bursts")
			mines[gun.slot_index]={"order":(guns.size()-1-index)*(MineAudio.CAPACITY+1),"slot_index":int(gun.slot_index),"item_id":int(gun.equipment.item_id),"bursts":retained.bursts}
			continue
		if not gun.has("bomb"):continue
		var burst: Variant=gun.get("detonation")
		if not burst is Dictionary or burst.get("item_id")!=gun.equipment.item_id:return fail("EMP sound lost its retained burst item")
		for key in _content_identity:
			if burst.get(key)!=_content_identity[key]:return fail("EMP burst sound changed content identity")
		var declaration:=BombAudio.declaration(gun.equipment.item_id)
		if declaration.is_empty():return fail("Burst sound lost its admitted bomb declaration")
		var id: int=declaration.burst_sound
		if sources.has(id):return fail("EMP sound repeated an equipped item")
		sources[id]={"order":(guns.size()-1-index)*(MineAudio.CAPACITY+1),"slot_index":int(gun.slot_index),"item_id":int(gun.equipment.item_id)}
	var previous:=-1
	for cue in cues:
		if not cue is Dictionary or cue.get("action")!="start_spatial" or not Definitions.integer(cue.get("source_id"),0,19999) or cue.get("pitch_raw")!=0.0 or not cue.get("position") is Vector3 or not cue.position.is_finite():return fail("Invalid original area burst sound cue")
		var source: Dictionary
		var order: int
		if cue.has("projectile_slot"):
			if cue.size()!=7 or not mines.has(cue.get("secondary_slot")) or not Definitions.integer(cue.projectile_slot,0,MineAudio.CAPACITY-1):return fail("Mine sound lost its projectile slot")
			source=mines[cue.secondary_slot]
			var burst: Dictionary=source.bursts[cue.projectile_slot]
			if cue.get("item_id")!=source.item_id or cue.source_id!=MineAudio.declaration(source.item_id).burst_sound or burst.get("item_id")!=source.item_id or burst.get("effect",{}).get("position")!=cue.position:return fail("Mine sound changed its original burst or accepted position")
			order=source.order+int(cue.projectile_slot)
		else:
			if cue.size()!=4 or not sources.has(cue.source_id):return fail("Area burst sound lost its source")
			source=sources[cue.source_id];order=source.order
		if order<=previous:return fail("Area burst sounds changed wrapper order or repeated a cue")
		previous=order
		var op: Dictionary=cue.duplicate(true)
		op.item_id=source.item_id;op.secondary_slot=source.slot_index
		operations.append(op)
	return {"operations":operations}

func prepare_combat(world: Dictionary, elapsed_ms: int) -> Dictionary:
	for key in _content_identity:
		if world.get(key)!=_content_identity[key]:return fail("NPC audio belongs to another content identity")
	if world.get("elapsed_ms")!=elapsed_ms:return fail("NPC audio clock differs from its world")
	var events: Variant=world.get("actor_events")
	if not events is Array or events.size()>_npc_count:return fail("Invalid NPC audio event extent")
	var operations: Array[Dictionary]=[]
	var secondary:=prepare_secondaries(world)
	if secondary.is_empty():return {}
	# Existing EMP wrappers update before late primary/secondary input. Split
	# the validated secondary cues so their sound ordering matches that pass.
	var burst_count: int=secondary.get("detonation_count",0)
	operations.append_array(secondary.operations.slice(0,burst_count))
	if not _weapon_audio.is_empty():
		var primary:=prepare_primaries(world)
		if primary.is_empty():return {}
		operations.append_array(primary.operations)
		# The continuous cannon handle remains active between successful shots
		# while the trigger is held. Releasing it finishes the current sample.
		if world.get("primary_fire",{}).is_empty():
			for id in _players:
				if _players[id].get("primary_weapon",false) and _players[id].clip.get("release_at_sample_end",false):operations.append({"action":"stop","source_id":id})
	operations.append_array(secondary.operations.slice(burst_count))
	var previous:=-1
	for event in events:
		if not event is Dictionary or not Definitions.integer(event.get("actor_id"),previous+1,_npc_count-1):return fail("Invalid NPC audio actor order")
		previous=int(event.actor_id)
		if not _weapon_audio.is_empty():
			var firing:=prepare_npc_weapon(event,previous)
			if firing.is_empty():return {}
			operations.append_array(firing.operations)
		var death: Variant=event.get("destruction",{})
		if not death is Dictionary:return fail("Invalid NPC audio death frame")
		if death.is_empty() or _death_audio.is_empty():continue
		if previous in _debris_actors:
			var debris:=prepare_debris_audio(death,previous)
			if debris.is_empty():return {}
			operations.append_array(debris.operations);continue
		if previous in _freighter_actors:
			var freight:=prepare_freighter_audio(death,previous)
			if freight.is_empty():return {}
			operations.append_array(freight.operations);continue
		var cues: Variant=death.get("audio_events")
		var ids: Variant=death.get("sound_events")
		if not cues is Array or not ids is Array or cues.size()!=ids.size() or cues.size()>2 or not death.get("started") is bool or not death.get("breakup") is bool:return fail("Invalid NPC destruction audio events")
		if cues.size()!=int(death.started)+int(death.breakup):return fail("NPC sound events differ from their death transitions")
		for i in cues.size():
			var cue: Variant=cues[i]
			if not cue is Dictionary or not cue.get("position") is Vector3 or not cue.position.is_finite() or not Definitions.integer(cue.get("source_id"),0,19999) or cue.source_id!=ids[i]:return fail("Invalid NPC destruction sound position or identifier")
			if death.started and i==0:
				if cue.source_id!=_death_audio.initial_source_id:return fail("Wrong NPC death initialization sound")
			elif cue.source_id not in _death_audio.breakup_source_ids:return fail("Wrong NPC breakup sound")
			operations.append({"action":"start_spatial","source_id":int(cue.source_id),"position":cue.position,"actor_id":previous})
	return {"operations":operations}

func prepare_debris_audio(death: Dictionary,actor_id: int) -> Dictionary:
	var cues: Variant=death.get("audio_events")
	if not death.get("started",false) or death.get("sound_events")!=[_debris_sound] or not cues is Array or cues.size()!=1:return fail("Debris sound lost its destruction transition")
	var cue: Variant=cues[0]
	if not cue is Dictionary or cue.get("source_id")!=_debris_sound or not cue.get("position") is Vector3 or not cue.position.is_finite():return fail("Debris sound lost its source or position")
	return {"operations":[{"action":"start_spatial","source_id":_debris_sound,"position":cue.position,"actor_id":actor_id}]}

func prepare_freighter_audio(death: Dictionary, actor_id: int) -> Dictionary:
	if _freighter_audio.is_empty() or not death.get("started") is bool or not death.get("breakup") is bool:return fail("Freighter sound requires its native death transitions")
	var cues: Variant=death.get("audio_events")
	if not cues is Array or cues.size()!=2*int(death.started)+int(death.breakup):return fail("Freighter lost its initial or final explosion sounds")
	var operations: Array[Dictionary]=[]
	for index in cues.size():
		var cue: Variant=cues[index]
		if not cue is Dictionary or not cue.get("source_id") is int or not cue.get("position") is Vector3 or not cue.position.is_finite():return fail("Invalid freighter sound position or source")
		if death.started and index==0:
			if cue.source_id!=int(_freighter_audio.initial_sound_id):return fail("Wrong freighter initial sound")
		elif cue.source_id<int(_freighter_audio.effect_sound_base) or cue.source_id>=int(_freighter_audio.effect_sound_base)+int(_freighter_audio.effect_sound_bound):return fail("Wrong freighter explosion sound")
		operations.append({"action":"start_spatial","source_id":int(cue.source_id),"position":cue.position,"actor_id":actor_id})
	return {"operations":operations}

func prepare_primaries(world: Dictionary) -> Dictionary:
	var fire: Variant=world.get("primary_fire",{})
	if not fire is Dictionary:return fail("Invalid primary audio firing frame")
	var operations: Array[Dictionary]=[]
	if fire.is_empty():return {"operations":operations}
	var events: Variant=fire.get("weapons")
	var owner: Variant=world.get("primaries")
	if not owner is Dictionary:return fail("Invalid primary sound owner")
	var guns: Variant=owner.get("guns")
	if not events is Array or not guns is Array or events.size()!=guns.size() or guns.size()>255:return fail("Invalid primary sound owner extent")
	for i in guns.size():
		var event: Variant=events[i]
		var gun: Variant=guns[i]
		if not event is Dictionary or not gun is Dictionary:return fail("Invalid primary sound owner")
		if not gun.get("equipment") is Dictionary or not event.get("result") is Dictionary:return fail("Invalid primary sound equipment or result")
		var item: Variant=event.get("item_id")
		if not Definitions.integer(item,0,_weapon_audio.player_event_ids.size()-1) or item!=gun.get("equipment",{}).get("item_id") or event.get("slot")!=gun.get("equipment",{}).get("slot") or event.get("mount_id")!=gun.get("mount_id"):return fail("Primary sound belongs to another weapon")
		var entry: Variant=gun.get("audio")
		if not entry is Dictionary or not entry.get("enabled") is bool or entry.get("source_id")!=_weapon_audio.player_event_ids[int(item)] or not Definitions.number(entry.get("pitch_raw"),0.0,1.0):return fail("Invalid primary sound selection")
		var fired: Variant=event.get("result",{}).get("fired")
		var cues:=prepare_weapon_cues(event.get("audio_events"),fired,entry)
		if cues.is_empty():return {}
		for op in cues.operations:
			op.mount_id=event.mount_id;op.item_id=int(item);operations.append(op)
	return {"operations":operations}

func prepare_npc_weapon(event: Dictionary, actor_id: int) -> Dictionary:
	var firing: Variant=event.get("firing",{})
	if not firing is Dictionary:return fail("Invalid NPC firing audio frame")
	if firing.is_empty():return {"operations":[]}
	var death: Variant=event.get("destruction",{})
	if not death is Dictionary or not death.is_empty():return fail("NPC fired during a destruction transition")
	var rows: Variant=firing.get("actors")
	if not rows is Array or rows.size()!=1 or not rows[0] is Dictionary or rows[0].get("actor_id")!=actor_id:return fail("NPC sound belongs to another firing actor")
	if not rows[0].get("outcome") is Dictionary:return fail("Invalid NPC firing result")
	if _npc_weapon_sounds[actor_id]<0:return fail("An unarmed debris actor emitted weapon audio")
	var entry:={"enabled":true,"source_id":_npc_weapon_sounds[actor_id],"pitch_raw":0.0}
	var frame:=prepare_weapon_cues(rows[0].get("audio_events"),rows[0].get("outcome",{}).get("fired"),entry)
	if frame.is_empty():return {}
	for op in frame.operations:op.actor_id=actor_id
	return frame

func prepare_weapon_cues(cues: Variant, fired: Variant, entry: Dictionary) -> Dictionary:
	if not fired is bool or not cues is Array:return fail("Weapon sound lacks its launch result")
	var expected: int=int(fired and entry.enabled and int(entry.source_id)>=0)
	if cues.size()!=expected:return fail("Weapon sound differs from its successful launch and selection")
	var operations: Array[Dictionary]=[]
	for cue in cues:
		if not cue is Dictionary or cue.size()!=3 or cue.get("source_id")!=entry.source_id or not Definitions.number(cue.get("pitch_raw"),0.0,1.0) or cue.pitch_raw!=entry.pitch_raw or not cue.get("position") is Vector3 or not cue.position.is_finite():return fail("Invalid weapon sound identifier, position or pitch")
		operations.append({"action":"start_spatial","source_id":int(cue.source_id),"position":cue.position,"pitch_raw":float(cue.pitch_raw)})
	return {"operations":operations}

func commit_frame(frame: Dictionary) -> void:
	if frame.get("identity")!=_identity or frame.get("revision")!=_revision+1 or frame.get("repeat",true):return
	var delta_ms: int=frame.elapsed_ms-_elapsed_ms
	_elapsed_ms=frame.elapsed_ms;_revision=frame.revision;_listener=frame.listener
	_booster_serial=int(frame.get("booster_serial",_booster_serial))
	_cloak_serial=int(frame.get("cloak_serial",_cloak_serial))
	if frame.has("flight_serial"):_flight_serial=int(frame.flight_serial)
	if frame.has("travel_serial"):_travel_serial=int(frame.travel_serial)
	if frame.has("travel_attached"):_travel_attached=frame.travel_attached
	if frame.has("contract_result_serial"):_notified_result_serial=int(frame.contract_result_serial)
	if frame.has("mining_serial"):_mining_serial=int(frame.mining_serial)
	_voice_displayed=frame.voice_displayed.duplicate()
	for record in _players.values():record.age_ms+=delta_ms
	for record in _retiring.duplicate():
		record.remaining_ms=maxi(0,record.remaining_ms-delta_ms)
		if record.remaining_ms==0:
			record.node.stop();record.node.queue_free();_retiring.erase(record)
	for item in frame.layer_frames:
		if is_instance_valid(item.node) and not item.node.is_queued_for_deletion():item.node.commit_step(item.frame)
	if frame.player_engine.present and (frame.player_engine.generation==0 or frame.player_engine.generation==_engine_generation):commit_engine(frame.player_engine)
	for op in frame.operations:
		match op.action:
			"replace_music":
				stop_event(_music);_music=op.source_id;start_event(op)
			"start","start_spatial":start_event(op)
			"position":
				if _players.has(op.source_id):_players[op.source_id].position=op.position
			"stop":stop_event(op.source_id)
			"stop_music":stop_event(_music)
			"stop_player_engine":
				stop_event(_engine)
				if not frame.player_engine.present:_engine=-1
			"set_player_engine":
				if frame.player_engine.present:commit_engine(frame.player_engine)
				else:stop_event(_engine);_engine=op.source_id;start_event(op)
		var entry: Dictionary=op.duplicate();entry.erase("clip");entry["revision"]=_revision;_history.append(entry)
		if _history.size()>256:_history.pop_front()
	refresh_levels()

func commit_engine(state: Dictionary) -> void:
	if int(state.generation)!=_engine_generation:stop_event(PLAYER_ENGINE)
	_engine_generation=int(state.generation);_initial_engine_id=int(state.initial_source_id);_engine=int(state.source_id)
	if not state.active:stop_event(PLAYER_ENGINE);return
	start_event({"source_id":_engine,"clip":state.clip,"position":state.position},PLAYER_ENGINE)
	var record: Dictionary=_players[PLAYER_ENGINE]
	if record.node is ParameterLoop:record.node.set_parameters(state.parameters)

func start_event(op: Dictionary,key: Variant=null) -> void:
	if key==null:key=op.source_id
	if op.clip.has("unsupported"):
		_unsupported[op.source_id]=op.clip.unsupported
		return
	# The original wrapper retains one handle per event. Starting an audible
	# cached instance updates its position without resetting its sample or RNG.
	if _players.has(key):
		var old: Dictionary=_players[key]
		if old.node.playing or old.pending_resume:
			if op.has("position"):old.position=op.position
			apply_pitch(old,float(op.get("pitch_raw",0.0)),true)
			return
		old.node.stop();old.node.queue_free();_players.erase(key)
	for old in _retiring.duplicate():
		if old.clip.id==op.source_id:
			if old.get("release_tail",false) and (old.node.playing or old.pending_resume):
				_retiring.erase(old);old.erase("release_tail");old.remaining_ms=0
				if op.has("position"):old.position=op.position
				apply_pitch(old,float(op.get("pitch_raw",0.0)),true)
				_players[key]=old
				return
			old.node.stop();old.node.queue_free();_retiring.erase(old)
	if op.clip.get("voice",false):reserve_voice()
	var node: Node
	var clip: Dictionary=op.clip
	var category: String="Music" if op.get("action")=="replace_music" else "Voice" if clip.get("voice",false) else "FX"
	if op.clip.get("kind")=="layered":
		node=Layered.new();node.category=category;node.configure(op.clip,_seed_value+_start_serial);_start_serial+=1
		if op.source_id==1:node.set_initial_parameter(float(op.parameter))
	elif op.clip.get("kind")=="parameter_loop":
		node=ParameterLoop.new();node.configure(op.clip)
	else:
		if clip.get("kind")=="playlist":
			var definition: Dictionary=clip.definition
			var last: int=_last_samples.get(op.source_id,-1) if definition.playlist_flags!=8 else -1
			var choice:=Sequence.sample(definition,_random,last)
			_last_samples[op.source_id]=choice.playlist_index
			clip=clip.duplicate();clip.merge(choice.sample);clip.gain*=choice.gain
			clip.pitch=choice.pitch;clip.playlist_index=choice.playlist_index
			node=Streams.player(clip.stream,clip.spatial,category);node.pitch_scale=choice.pitch
		else:node=Streams.player(clip.stream,clip.spatial,category)
	if clip.has("event_volume_random"):
		clip=clip.duplicate()
		clip.gain*=lerpf(1.0-float(clip.event_volume_random),1.0,_random.randf())
	var record:={"node":node,"clip":clip,"age_ms":0,"position":op.get("position",Vector3.ZERO),"remaining_ms":0,"stop_gain":1.0,"pending_resume":false,"resume_position":0.0,"primary_weapon":op.has("mount_id")}
	if clip.get("voice",false):record.voice_serial=_voice_serial;_voice_serial+=1
	apply_pitch(record,float(op.get("pitch_raw",0.0)))
	add_child(node)
	_players[key]=record
	apply_level(record,1.0)
	if _paused:record.pending_resume=true
	else:node.play()

func reserve_voice() -> void:
	var voices: Array=[]
	for record in _players.values()+_retiring:
		if record.clip.get("voice",false) and (record.node.playing or record.pending_resume):voices.append(record)
	if voices.size()<2:return
	voices.sort_custom(func(a,b):return a.voice_serial<b.voice_serial)
	# Category flags0 select the oldest started instance. The source uses an
	# immediate stop for category stealing, independent of its normal stop fade.
	var oldest: Dictionary=voices[0]
	oldest.node.stop();oldest.node.queue_free()
	_players.erase(int(oldest.clip.id));_retiring.erase(oldest)

func apply_pitch(record: Dictionary, raw: float, cached:=false) -> void:
	# FMOD Designer raw pitch has four octaves per unit. Playlist pitch is an
	# independent sample variation; repeated cached starts retain that choice.
	# Event variation is redrawn by each pitch setter on a live cached channel.
	if record.node is Layered:return
	var factor:=pow(2.0,4.0*raw)
	var deviation: float=record.clip.get("event_pitch_random",0.0)
	if deviation!=0.0:
		# A nonzero weapon override follows the source's initial zero-pitch setter.
		if cached and raw!=0.0:_random.randi()
		factor=Sequence.event_pitch(raw,deviation,_random.randi()&0x7fffffff)
	record.node.pitch_scale=float(record.clip.get("pitch",1.0))*factor
	record.pitch_raw=raw

func stop_event(id: Variant) -> void:
	if not _players.has(id):return
	var record: Dictionary=_players[id];_players.erase(id)
	var fade: int=record.clip.fade_out_ms
	if record.clip.get("release_at_sample_end",false) and (record.node.playing or record.pending_resume):
		var sample: Dictionary=record.clip.sample
		var end_seconds: float=float(sample.loop_end)/float(sample.rate)
		var cursor: float=record.node.get_playback_position() if record.node.playing else 0.0
		record.remaining_ms=maxi(1,ceili(1000.0*maxf(0.0,end_seconds-cursor)/maxf(0.001,record.node.pitch_scale)))
		record.stop_gain=1.0 if record.clip.fade_in_ms==0 else minf(1.0,float(record.age_ms)/record.clip.fade_in_ms)
		record.release_tail=true
		_retiring.append(record)
		return
	if fade==0:record.node.stop();record.node.queue_free();return
	record.remaining_ms=fade
	record.stop_gain=1.0 if record.clip.fade_in_ms==0 else minf(1.0,float(record.age_ms)/record.clip.fade_in_ms)
	_retiring.append(record)

func refresh_levels() -> void:
	for record in _players.values():
		var fade: float=1.0 if record.clip.fade_in_ms==0 else minf(1.0,float(record.age_ms)/record.clip.fade_in_ms)
		apply_level(record,fade)
	for record in _retiring:
		var fade: float=clampf(float(record.remaining_ms)/maxf(1.0,float(record.clip.fade_out_ms)),0.0,1.0) if record.get("release_tail",false) else float(record.remaining_ms)/record.clip.fade_out_ms
		apply_level(record,record.stop_gain*fade)

func apply_level(record: Dictionary, fade: float) -> void:
	var gain: float=record.clip.gain*fade
	if record.clip.spatial:
		if record.node is ParameterLoop:record.node.set_spatial(record.position,_listener)
		else:record.node.position=record.position
		var distance: float=_listener.origin.distance_to(record.position)
		gain*=clampf((record.clip.max_distance-distance)/(record.clip.max_distance-record.clip.min_distance),0.0,1.0)
	record.node.volume_db=linear_to_db(gain) if gain>0 else -80.0

func set_paused(value: bool) -> void:
	_paused=value
	for record in _players.values():pause_record(record,value)
	for record in _retiring:pause_record(record,value)

func pause_record(record: Dictionary, value: bool) -> void:
	Streams.pause(record,value)


func snapshot() -> Dictionary:
	var active:={}
	for id in _players:
		var row: Dictionary=_players[id]
		active[id]={"name":row.clip.name,"position":row.position,"gain_db":row.node.volume_db,"paused":row.node.stream_paused or row.pending_resume,"playing":row.node.playing,"looping":row.clip.looping,"source_bank":row.clip.get("source_bank",""),"source_index":row.clip.get("source_index",-1)}
		if row.clip.get("kind")=="playlist":active[id].pitch=row.clip.pitch;active[id].playlist_index=row.clip.playlist_index
		if row.has("pitch_raw"):active[id].pitch_raw=row.pitch_raw;active[id].playback_pitch=row.node.pitch_scale
		if row.node is Layered:active[id].layers=row.node.snapshot()
		if row.node is ParameterLoop:active[id].parameter_loop=row.node.snapshot()
		if row.clip.get("voice",false):active[id].voice=true;active[id].voice_serial=row.voice_serial
	return {"revision":_revision,"elapsed_ms":_elapsed_ms,"music_id":_music,"engine_id":_engine,"engine_generation":_engine_generation,"active":active,"retiring":_retiring.size(),"paused":_paused,"history":_history.duplicate(true),"unsupported":_unsupported.duplicate(),"random_state":_random.state,"voice_displayed":_voice_displayed.duplicate()}

func clear() -> void:
	for child in get_children():
		child.stop();child.free()
	restore_listener()
	_resources=null;_identity=null;_revision=-1;_elapsed_ms=0;_booster_serial=0;_cloak_serial=0;_players.clear();_retiring.clear();_history.clear();_unsupported.clear();_music=-1;_engine=-1;_paused=false;_start_serial=0;error=""
	_last_samples.clear();_random.seed=0
	_death_audio={};_freighter_audio={};_freighter_actors=[];_debris_actors=[];_debris_sound=-1;_notification_sound=-1;_notified_result_serial=0;_content_identity={};_weapon_audio={};_npc_weapon_sound=-1;_npc_weapon_sounds=[];_npc_scan_sound=-1
	_radio_voice={};_local_radio_rules={};_radio_identity={};_voice_displayed=[];_voice_serial=0
	_engine_ids=[];_arrival_engine_id=-1;_engine_generation=-1;_initial_engine_id=-1
	_npc_count=3;_player_death_rules={};_flight_identity=null;_flight_serial=-1
	_travel_sounds=[];_tractor_sounds=[];_portal_sound=-1;_probe_sound=-1;_travel_attached=false;_travel_serial=0;_secondary_audio={}
	_mining_only=false;_mining_attached=false;_mining_serial=0;_drill_rates=[];_flight_music_attached=false
	_selected40_identity=null
	_selected41_radio_world=null

func reject(message: String) -> bool:
	error=message
	return false

func fail(message: String) -> Dictionary:
	error=message
	return {}

func restore_listener() -> void:
	if is_instance_valid(_viewport):_viewport.set_as_audio_listener_3d(_previous_listener)
	_viewport=null

func take_listener_from(previous: Node3D) -> bool:
	# A prepared replacement shares its viewport with the old scene. Transfer
	# restoration responsibility so disposing the old scene cannot disable it.
	if previous==null or previous.get_script()!=get_script() or _identity==null or previous._identity==null or not is_instance_valid(_viewport) or previous._viewport!=_viewport:return reject("Audio handoff requires two prepared owners in the same viewport")
	_previous_listener=previous._previous_listener
	previous._viewport=null
	_viewport.set_as_audio_listener_3d(true)
	return true

func _exit_tree() -> void:
	for child in get_children():child.stop()
	restore_listener()
