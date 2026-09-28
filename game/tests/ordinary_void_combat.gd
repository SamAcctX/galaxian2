extends SceneTree
## Detached combat observation from an immutable earned paid32 station. The
## selected Void world is generated, never saved or admitted as earned cursor33.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Source=preload("res://src/simulation/ordinary_void_source.gd")
const Field=preload("res://src/simulation/scenery_field.gd")
const World=preload("res://src/simulation/opening_world_initialization.gd")
const Population=preload("res://src/simulation/traffic_population.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Story=preload("res://src/content/story_encounter_definitions.gd")
const NativeControl=preload("res://src/simulation/combat_training_control.gd")
const Resources=preload("res://src/content/npc_destruction_resources.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const WeaponLoadout=preload("res://src/simulation/weapon_loadout.gd")
const ProjectileVisuals=preload("res://src/simulation/projectile_visual_state.gd")
const Reputation=preload("res://src/simulation/faction_reputation.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const Scanner=preload("res://src/simulation/opening_npc_scanner.gd")
const Frame=preload("res://src/presentation/flight_target_frame.gd")
const Markers=preload("res://src/presentation/flight_npc_markers.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
const FlightConstruction=preload("res://src/simulation/first_flight_construction.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const ENTRY={"companions_empty":true,"location_match":true,"special_placement":false}
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")

func test_label() -> String:return "Ordinary Void combat"

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=4 and args.size()!=5:check(false,"Expected content, bindings, visuals, immutable earned v8 paid32 save and optional capture directory");finish();return
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library) or not library.select_language("gb"):check(false,library.error+bindings.error+cat.error);finish();return
	var file:=Save.new();var archive:=Archive.new();var document: Dictionary=file.read_document(args[3])
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);finish();return
	var equipment: RefCounted=station.equipment_owner();var career: Dictionary=station.contract_owner().snapshot()
	var loadout: Dictionary=equipment.snapshot().loadout
	check(document.version==8 and document.station.campaign_cursor==32 and career.rank==4 and career.difficulty==0.5 and loadout.ship_id==0 and loadout.equipment_ids==[2,41,81,91,55],"Use the unchanged paid32 ship, equipment and rank")
	var source:=Source.new()
	if not source.configure(bindings,cat,career.lounges.system_availability,career.void_source):check(false,source.error);finish();return
	check(source.snapshot().source_system_id==18 and source.snapshot().source_station_id==91 and loadout.station_id==98,"Detached fixture pretended it had earned source-station travel")
	var retained: Dictionary=archive.capture(station,bindings)
	for seed in [1789100000,1789100001]:await verify_branch(library,bindings,cat,equipment,source,career,int(career.rank),seed)
	# This is an explicit maximum-rank component context. The saved career stays
	# rank4; it does not claim that the player has earned rank20 or Void travel.
	var maximum_rank: int=bindings.opening_handoff.rank_thresholds.size()-1
	var maximum_count: int=Population.maximum_void_actor_count_for_rank(bindings,maximum_rank)
	check(maximum_rank==20 and maximum_rank>career.rank and maximum_count==10,"The source-supported rank or fighter-count ceiling changed")
	var maximum_kinds:=[];maximum_kinds.resize(maximum_count);maximum_kinds.fill(9)
	var maximum_history:=Reputation.new()
	check(maximum_history.configure(bindings,33,maximum_kinds,career.difficulty,false,int(source.snapshot().source_system_id),maximum_rank) and maximum_history.snapshot().system_id==source.snapshot().source_system_id,"Source reputation rejected the declared maximum fighter count")
	maximum_kinds.append(9)
	check(not Reputation.new().configure(bindings,33,maximum_kinds,career.difficulty,false,int(source.snapshot().source_system_id),maximum_rank),"Source reputation exceeded its maximum fighter count")
	await verify_branch(library,bindings,cat,equipment,source,career,maximum_rank,1789100000)
	await verify_player_encounter(library,bindings,cat,station,source)
	check(archive.capture(station,bindings)==retained and file.read_document(args[3])==document,"Combat observation changed the paid save or parent career")
	print("%s: %d checks; %d failures"%[test_label(),checks,failures])
	finish()

func verify_branch(library: RefCounted,bindings: RefCounted,cat: RefCounted,equipment: RefCounted,source: RefCounted,career: Dictionary,rank: int,seed: int) -> void:
	var context:={"campaign_cursor":33,"selected_system_id":-1,"selected_station_id":-1,"retained_system_id":-1,"retained_station_id":-1,
		"selected_mission_kind":-1,"selected_mission_story":false,"location_match":true,"rank":rank}
	var field:=Field.new()
	if not field.configure(bindings,cat,-1,true,false,33):check(false,field.error);return
	var random:=Random.new();random.seed_from(seed)
	var scenery: Dictionary=field.generate(Vector3(-30000,0,30000),random.snapshot())
	if scenery.is_empty():check(false,field.error);return
	var world:=World.new();var loadout: Dictionary=equipment.snapshot().loadout
	if not world.configure_void_factory(bindings,cat,int(loadout.ship_id),loadout.equipment_ids,context,ENTRY):check(false,world.error);return
	var generated: Dictionary=world.generate(scenery.random_state)
	if generated.is_empty():check(false,world.error);return
	var original_world: Dictionary=world.snapshot();var original_equipment: Dictionary=equipment.snapshot()
	var data: Dictionary=Story.compose_void(bindings,cat,world,equipment,source,career.difficulty)
	if data.is_empty():check(false,"Generated cursor33 did not compose source-bound combat");return
	var count: int=generated.npc_construction.actors.size()
	if rank>career.rank:check(count>2 and generated.npc_construction.population.groups.void==count,"Maximum-rank component did not retain its larger generated fighter group")
	check(data.ordinary_void and data.mission_kind==-1 and not data.mission_story and data.mission_completed and data.context_key=="void_context" and data.source_system_id==18 and data.source_station_id==91 and data.equipment_station_id==98,"Detached Void composition lost source and nonstory identities")
	check(data.actor_count==count and data.player_weapon_targets==range(count) and data.target_memberships.all(func(ids):return ids==[-1]) and data.actor_rows.all(func(row):return row.population_group=="fighter"),"Void targets included another NPC or lost generated fighters")
	check(data.npc_weapons.all(func(row):return row.item_id==5 and row.actor_kind==9 and row.nonplayer_source) and data.lifecycle.reactions.primary_faction==int(cat.tables.systems[18].fields[int(bindings.mido_travel.free_population.faction_field)]),"Void weapons or source-system faction changed")
	var expected_damage:=2 if rank==4 else 14
	check(data.npc_weapons.all(func(row):return row.damage==expected_damage and row.interval_ms==534 and row.projectile_capacity==4 and row.lifetime_ms==3000 and row.speed_units_per_millisecond==16.0),"Void item5 no longer uses rank-sensitive shared source scaling and 0.8 damage")
	var control:=NativeControl.new();var construction: RefCounted=world.npc_construction_owner()
	if not control._configure_story(bindings,cat,construction,equipment,career.reputation,data):check(false,control.error);return
	var resources:=Resources.new()
	if not resources._configure_story(library,bindings,construction,data) or not control.set_destruction(bindings,resources):check(false,resources.error+control.error);return
	var weapons:=Weapons.new()
	if not weapons._configure_encounter_weapons(bindings,cat,data):check(false,weapons.error);return
	var original_shot: Dictionary=bindings.mido_travel.sahi_encounter.weapons["void"]
	for id in count:
		var fired: Dictionary=weapons.snapshot().actors[id].projectiles.weapon
		var mapped: Dictionary=ProjectileVisuals.model_mapping(bindings,fired,"npc:%d"%id,false)
		var impact: Dictionary=ProjectileVisuals.model_mapping(bindings,fired,"npc:%d"%id,true)
		check(mapped.get("id")==int(original_shot.model_resource_id) and impact.get("id")==int(original_shot.impact_model_id),"Void fighter lost its original item5 projectile or impact art")
	var resolver:=WeaponLoadout.new()
	if not resolver.configure(bindings,cat,bindings.base_content_id):check(false,resolver.error);return
	for slot in equipment.snapshot().loadout.slots:
		if slot==null or slot.category!=0:continue
		var primary: Dictionary=resolver.resolve(int(slot.item_id),loadout.equipment_ids)
		primary.campaign_cursor=33
		check(not ProjectileVisuals.model_mapping(bindings,primary,"player:0",false).is_empty() and not ProjectileVisuals.model_mapping(bindings,primary,"player:0",true).is_empty(),"Earned equipped primary lost its source projectile mapping")
	var initial: Dictionary=control.snapshot();var actor: Dictionary=initial.combat.actors[0]
	check(actor.actor_mode==int(data.initial_actor_mode) and actor.active==bool(data.initial_active) and actor.hostile and not actor.friendly and actor.forced_hostile and actor.script_hostile,"Raw source setter did not become immediate persistent hostility with normal factory mode")
	check(initial.combat.provocation.forced_hostile.size()==count and initial.combat.provocation.forced_hostile.all(func(value):return value) and initial.combat.provocation.permanent_hostile.all(func(value):return value),"Void reaction ledger did not start persistently hostile")
	check(initial.combat.reputation.system_id==source.snapshot().source_system_id and initial.combat.reputation.actor_kinds.size()==count and initial.combat.reputation.actor_kinds.all(func(kind):return kind==9),"Void standing used the selected sentinel instead of the retained source system")
	check(initial.destruction.size()==count and initial.destruction[0].cargo.entries==generated.npc_construction.actors[0].cargo and initial.accounting.events.is_empty(),"Void destruction regenerated cargo or precredited a kill")
	var pose:=Transform3D(Basis.IDENTITY,Vector3(-100000,0,100000))
	var target:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"pose":pose,"ship_id":0,"active":true,"hull":95,"special_flight":false,"targeting_blocked":false,"alternate_position":null}
	var first: Dictionary=control.advance(100,target,null,generated.random_state)
	if first.is_empty():check(false,control.error);return
	var after: Dictionary=control.snapshot()
	check(after.combat.actors[0].actor_mode==1 and after.combat.actors[0].hostile and after.combat.actors[0].script_hostile and after.flight[0].root_pose==initial.flight[0].root_pose,"Void first pass changed source movement or lost hostility")
	check(control.advance(-1,target,null,first.random_state).is_empty() and control.snapshot()==after,"Rejected Void frame changed live combat")
	var lethal: RefCounted=control.combat_owner()
	if not lethal.begin_contact_pass(first.random_state,true) or not lethal.refresh_hostility(0) or lethal.normal_hit(0,100000,false).is_empty():check(false,lethal.error);return
	var hit: Dictionary=control.advance(100,target,lethal,lethal.contact_random_state())
	if hit.is_empty():check(false,control.error);return
	var death: Dictionary=control.snapshot()
	check(death.accounting.events.size()==1 and death.accounting.counter_deltas.player_kills==1 and death.accounting.counter_deltas.pirate_kills==0 and death.destruction[0].cargo.entries==generated.npc_construction.actors[0].cargo,"Void hit duplicated cargo or miscredited the kind9 kill")
	check(death.combat.reputation.events.size()==1 and death.combat.reputation.events[0].change==int(bindings.mido_travel.alioth_lifecycle.void_reputation_change),"Void hit lost its original kind9 source-system reputation change")
	await verify_scanner(library,bindings,cat,equipment,source,initial.combat,after.combat,death.combat,"rank%d-seed%d"%[rank,seed])
	check(world.snapshot()==original_world and equipment.snapshot()==original_equipment and source.snapshot()==career.void_source,"Detached combat mutated its construction, equipment or source")
	check(not Encounter.new().configure_ordinary_void(bindings,cat,library,null,null,equipment,career.reputation,source,career.difficulty),"Unprepared player/scenery entered live Void combat")
	var foreign:=Source.new();var wrong: Dictionary=career.void_source.duplicate(true);wrong.binding_id="foreign"
	check(not foreign.configure(bindings,cat,career.lounges.system_availability,wrong) and Story.compose_void(bindings,cat,world,equipment,foreign,career.difficulty).is_empty(),"Foreign source entered Void combat")

func prepare_player_station(_library: RefCounted,_bindings: RefCounted,_cat: RefCounted,station: RefCounted) -> RefCounted:return station

func verify_player_encounter(library: RefCounted,bindings: RefCounted,cat: RefCounted,station: RefCounted,source: RefCounted) -> void:
	station=prepare_player_station(library,bindings,cat,station)
	if station==null:return
	var departure:=FlightConstruction.new()
	if not departure.prepare_free(bindings,cat,station,1789100000,1789100000):check(false,departure.error);return
	var equipment: RefCounted=departure.equipment_owner();var original: Dictionary=equipment.snapshot()
	var carrier: RefCounted=departure.player_owner()
	if not carrier.set_permissions(true,true) or carrier.normal_hit(17).is_empty():check(false,carrier.error);return
	var damaged: Dictionary=carrier.snapshot()
	check(damaged.vitals.hull==95 and damaged.vitals.armor<40,"The retained ship did not take the component's native pre-entry damage")
	# Explicit unsaved portal alternative: the parent remains paid32 at Alioth98
	# with its real source Dima91. Only this component observation selects 33.
	var route: RefCounted=source.fork();var selected: Dictionary=route.snapshot()
	selected.source_station_id=original.loadout.station_id;selected.source_system_id=original.loadout.system_id
	if not route.restore(selected):check(false,route.error);return
	var owned: RefCounted=equipment.fork()
	if not owned.relocate_ordinary_void(bindings,route,true):check(false,owned.error);return
	var crossing: Dictionary=damaged.duplicate(true);crossing.campaign_cursor=33
	var cache: Dictionary=Cache.capture_ordinary_void(bindings,route,original.loadout,owned.snapshot().loadout,crossing,true)
	if cache.is_empty():check(false,"The native portal cache rejected the retained ship");return
	var career: Dictionary=station.contract_owner().snapshot()
	var context:={"campaign_cursor":33,"selected_system_id":-1,"selected_station_id":-1,"retained_system_id":-1,"retained_station_id":-1,
		"selected_mission_kind":-1,"selected_mission_story":false,"location_match":true,"rank":int(career.rank)}
	var bodies: RefCounted=load("res://src/content/scenery_body_resources.gd").new()
	var effects: RefCounted=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var scenery:=Scenery.new()
	if not scenery.configure_ordinary_void(bindings,cat,owned,context,ENTRY,1789100000,true,bodies,effects):check(false,scenery.error);return
	var world: RefCounted=scenery.world_initialization_owner();var player:=Player.new()
	for rejected in [null,{},carrier.cache_snapshot()]:
		check(not Player.new().configure_ordinary_void(bindings,cat,owned,world,route,career.difficulty,rejected),"Void entry admitted a missing or previous-mission cache")
	check(not Player.new().configure_ordinary_void(bindings,cat,equipment,world,route,career.difficulty,cache),"Void entry skipped equipment relocation")
	check(not Player.new().configure_ordinary_void(bindings,cat,owned,world,Source.new(),career.difficulty,cache),"Void entry admitted an unconfigured source")
	var wrong: Dictionary=cache.duplicate(true);wrong.binding_id="foreign"
	check(not Player.new().configure_ordinary_void(bindings,cat,owned,world,route,career.difficulty,wrong),"Void entry admitted a foreign player cache")
	wrong=cache.duplicate(true);wrong.values.hull=0
	check(not Player.new().configure_ordinary_void(bindings,cat,owned,world,route,career.difficulty,wrong),"Void entry revived a destroyed player")
	if not player.configure_ordinary_void(bindings,cat,owned,world,route,career.difficulty,cache):check(false,player.error);return
	# cache_snapshot retains the shared capacity/identity template, not live
	# damage. The next portal captures current pools from the player itself.
	check(player.snapshot().vitals==damaged.vitals and player.snapshot().gamma==cache.values.gamma and Cache.matches(player.cache_snapshot(),owned.snapshot().loadout,33) and player.snapshot().void_context==context,"Void entry reset surviving pools, cache identity or generated context")
	check(player.loadout().station_id==-1 and player.loadout().system_id==-1 and player.loadout().equipment_ids==original.loadout.equipment_ids,"Void entry changed the retained loadout")
	var initial_player: Dictionary=player.snapshot();var initial_scenery: Dictionary=scenery.snapshot()
	var encounter:=Encounter.new()
	if not encounter.configure_ordinary_void(bindings,cat,library,player,scenery,owned,career.reputation,route,career.difficulty):check(false,encounter.error);return
	var initial: Dictionary=encounter.snapshot()
	check(initial.combat.actors.size()==world.snapshot().npc_construction.actors.size() and initial.has("primaries") and encounter.has_secondaries(),"The real Void encounter lost generated fighters or equipped weapons")
	var pose:=Transform3D(Basis.IDENTITY,Vector3(-100000,0,100000))
	var weapons: Dictionary=encounter.evaluate_weapons(player,pose,100,scenery,initial_scenery.random_state)
	if weapons.is_empty():check(false,encounter.error);return
	check(encounter.snapshot()==initial and player.snapshot()==initial_player and scenery.snapshot()==initial_scenery,"Prospective Void weapons mutated accepted owners")
	var fired: Dictionary=weapons.encounter.evaluate_primary_fire(weapons.player,pose,true,true,weapons.random_state)
	if fired.is_empty():check(false,weapons.encounter.error);return
	var moved: Dictionary=fired.encounter.evaluate_world(weapons.player,pose,100,fired.random_state)
	if moved.is_empty():check(false,fired.encounter.error);return
	check(moved.encounter.snapshot().elapsed_ms==100 and moved.encounter.snapshot().world_elapsed_ms==100 and not moved.encounter.snapshot().primary_fire.is_empty(),"The real Void weapon/NPC phases did not advance")
	var accepted: Dictionary=moved.encounter.snapshot()
	check(moved.encounter.evaluate_weapons(weapons.player,pose,-1,weapons.scenery,moved.random_state).is_empty() and moved.encounter.snapshot()==accepted,"Rejected Void weapon time changed the live encounter")
	var returning: RefCounted=owned.fork()
	if not returning.relocate_ordinary_void(bindings,route,false):check(false,returning.error);return
	var back: Dictionary=Cache.capture_ordinary_void(bindings,route,owned.snapshot().loadout,returning.snapshot().loadout,player.snapshot(),false)
	check(not back.is_empty() and back.values==cache.values and back.station_id==original.loadout.station_id and back.system_id==original.loadout.system_id,"The Void return cache lost surviving pools or its recorded source")
	await verify_constructed_void(library,bindings,cat,departure,owned,route,cache,career,bodies,effects)
	check(equipment.snapshot()==original and carrier.snapshot()==damaged and source.snapshot()==career.void_source,"The detached player/encounter changed its parent ship or source")

func verify_constructed_void(library: RefCounted,bindings: RefCounted,cat: RefCounted,departure: RefCounted,equipment: RefCounted,source: RefCounted,cache: Dictionary,career: Dictionary,bodies: RefCounted,effects: RefCounted) -> void:
	# A selected component proposal, not an earned advancement or a saved career.
	var progress: Dictionary=career.progress.duplicate(true)
	progress.merge(load("res://src/simulation/opening_handoff.gd").calculate_progress(bindings.opening_handoff,33,progress.player_kills,progress.pirate_kills,progress.other_score),true)
	var flags: Dictionary=departure.snapshot().departure.station_response_flags
	var construction:=FlightConstruction.new()
	var contracts: RefCounted=selected_void_career(bindings,cat,departure,source)
	if not construction.prepare_ordinary_void_selected(bindings,cat,equipment,source,cache,progress,flags,career.difficulty,1789100000,1789100000,true,bodies,effects,contracts):check(false,construction.error);return
	var entry: Dictionary=construction.snapshot();var place: Dictionary=entry.location
	check(Story.prepared_ordinary_void(bindings,entry) and not load("res://src/content/ordinary_flight_definitions.gd").for_departure(bindings,entry).is_empty(),"The generated Void was not admitted as its explicit prepared world")
	check(place.station_id==-1 and place.system_id==-1 and place.void_location and place.current_planet_texture_id==-1 and place.return_station_id==source.snapshot().source_station_id,"Void construction used an ordinary station or lost its actual return")
	check(entry.player_pose.origin==construction.void_environment_owner().snapshot().player_position and entry.player_yaw_units==32768 and entry.before_yaw_random_state==entry.yaw_random_state,"Void construction lost its incoming gate pose or consumed a launch yaw draw")
	check(entry.entry_conditions==ENTRY and entry.departure.progress==progress and entry.departure.cargo==equipment.snapshot().cargo and entry.mission_kind==-1 and not entry.mission_story and entry.departure.mission.kind==8,"Void construction changed the career, cargo or sentinel/story distinction")
	check(entry.player.vitals.hull==cache.values.hull and entry.player.vitals.armor==cache.values.armor and construction.ordinary_void_source_owner().snapshot()==source.snapshot(),"Void construction reset live pools or changed its source owner")
	var cargo: RefCounted=load("res://src/simulation/flight_cargo.gd").new()
	var briefing: RefCounted=load("res://src/simulation/mining_briefing.gd").new()
	var objective: RefCounted=load("res://src/simulation/mining_objective.gd").new()
	var mining: RefCounted=load("res://src/simulation/mining_session.gd").new()
	var approach: RefCounted=load("res://src/simulation/mining_approach.gd").new()
	if not cargo.configure_departure(bindings,cat,construction) or not briefing.configure(bindings,library,construction,"E") or not objective.configure(bindings,library,construction,"P","E") or not mining.configure(bindings,cat,construction,false) or not approach.configure(bindings,cat,construction):check(false,cargo.error+briefing.error+objective.error+mining.error+approach.error);return
	var field: RefCounted=construction.scenery_owner();var encounter:=Encounter.new()
	if not encounter.configure_ordinary_void(bindings,cat,library,construction.player_owner(),field,equipment,progress.reputation,source,career.difficulty):check(false,encounter.error);return
	for _tick in 60:
		if not briefing.advance(150):check(false,briefing.error);return
	if not objective.poll(cargo,field,true,encounter):check(false,objective.error);return
	check(briefing.snapshot().phase=="flight" and not briefing.snapshot().briefing_started and objective.snapshot().phase=="collecting" and objective.snapshot().campaign_cursor==33 and objective.snapshot().reward_credits==0,"Ordinary Void entry invented a briefing, completion or reward")
	check(cargo.snapshot().entries==equipment.snapshot().cargo.entries and cargo.field_identity()==field.presentation_identity(),"The shared mining hold lost its retained rows or crystal field identity")
	check(not construction.prepare_ordinary_void_selected(bindings,cat,equipment,source,{},progress,flags,career.difficulty,1789100000,1789100000,true,bodies,effects) and construction.snapshot()==entry,"Rejected Void preparation replaced the accepted construction")
	await verify_live_void_frame(library,bindings,cat,construction)

func selected_void_career(_bindings: RefCounted,_cat: RefCounted,_departure: RefCounted,_source: RefCounted) -> RefCounted:return null

func verify_live_void_frame(library: RefCounted,bindings: RefCounted,cat: RefCounted,construction: RefCounted) -> void:
	var frame: RefCounted=load("res://src/simulation/first_flight_frame.gd").new()
	var prepared: Dictionary=construction.snapshot()
	if not frame.configure(bindings,cat,library,construction,"E",1.0,Vector2i(1280,720),false,prepared.departure.difficulty==1.0,"P"):check(false,frame.error);return
	var initial: Dictionary=frame.snapshot()
	check(initial.campaign_cursor==33 and initial.void_portal_contact.ordinary_mode=="void_return" and initial.void_portal_contact.return_station_id==prepared.return_station_id,"The live Void frame selected a story portal or another return station")
	check(initial.actors.size()==prepared.scenery.world_initialization.npc_construction.actors.size() and frame.secondary_available(),"The live Void frame omitted generated fighters or equipped secondaries")
	check(initial.player.vitals==prepared.player.vitals and initial.cargo.entries==prepared.departure.cargo.entries,"Frame initialization changed the retained ship or hold")
	for _tick in 60:
		var next: RefCounted=frame.evaluate(150,Vector2(0.2,-0.1),1.0)
		if next==null:check(false,frame.error);return
		frame=next
	var flying: Dictionary=frame.snapshot()
	check(flying.phase=="flight" and flying.entry_released and flying.world_phase_elapsed_ms==9000 and flying.player_pose!=initial.player_pose,"The live Void flight did not release steering and update its world")
	check(flying.campaign_cursor==33 and flying.mission==prepared.departure.mission and not frame.dialogue_visible() and flying.cargo.entries==initial.cargo.entries,"Live Void flight invented mission advancement, dialogue or cargo")
	var paused: RefCounted=frame.evaluate(150,Vector2.ZERO,1.0,true)
	check(paused!=null and paused.snapshot()==flying and frame.evaluate(-1)==null and frame.snapshot()==flying,"Paused or rejected live Void frames changed the accepted world")
	var firing: RefCounted=frame.evaluate(150,Vector2.ZERO,1.0,false,Vector2i.ZERO,Vector2.ZERO,true,true)
	if firing==null:check(false,frame.error);return
	check(frame.snapshot()==flying and firing.snapshot().world_phase_elapsed_ms==9150 and firing.ordinary_void_source_owner().snapshot()==construction.ordinary_void_source_owner().snapshot(),"The Void weapon frame changed its accepted parent or lost its route")
	await verify_live_void_scene(library,bindings,cat,firing)
	check(construction.snapshot()==prepared,"Live Void evaluation mutated its prepared construction")

func verify_live_void_scene(library: RefCounted,bindings: RefCounted,cat: RefCounted,frame: RefCounted) -> void:
	var visuals:=Visuals.new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest):check(false,visuals.error);return
	var scene: Node3D=load("res://src/presentation/first_flight_scene.gd").new()
	root.size=Vector2i(1280,720);root.add_child(scene)
	var retained: Dictionary=frame.snapshot()
	if not scene.build(library,bindings,visuals,cat,frame):check(false,scene.error);scene.free();return
	check(scene.portal!=null and scene.void_environment!=null and scene.encounter!=null and scene.station==null and scene.planets==null and scene.npc_markers!=null,"The live Void scene substituted ordinary space or omitted its portal, fighters or HUD")
	for mobile in [false,true]:
		scene.set_mobile_layout(mobile);scene.set_display_active(true)
		check(scene.present(frame),scene.error)
		if DisplayServer.get_name()!="headless":
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			var args:=OS.get_cmdline_user_args()
			var directory: String=args[4] if args.size()==5 else OS.get_environment("GOF2_CAPTURE_DIR")
			if not directory.is_empty():check(root.get_texture().get_image().save_png(directory.path_join("void-flight-live-%s.png"%["phone" if mobile else "desktop"]))==OK,"Live Void scene capture failed")
	check(frame.snapshot()==retained,"Rendering changed the accepted live Void world")
	scene.free()

func verify_scanner(library: RefCounted,bindings: RefCounted,cat: RefCounted,equipment: RefCounted,source: RefCounted,initial: Dictionary,moving: Dictionary,destroyed: Dictionary,label: String) -> void:
	var geometry:=Frame.source_geometry(library,bindings);var animation:=Markers.source_geometry(library,bindings)
	if geometry.has("error") or animation.has("error"):check(false,"Void HUD lost the original scanner geometry");return
	var radii: Vector2=Frame.logical_radii(geometry.quarter_size,false)
	check(not Scanner.new().configure(bindings,cat,radii,animation.frames,equipment,initial),"Station equipment entered the selected Void scanner without relocation")
	# Explicit unsaved component alternative: choose the parent's current station
	# as the source, then exercise the real relocation owner on a detached ship.
	# The actual paid32 career retains Dima91 and never earns this alternative.
	var route: RefCounted=source.fork();var selected: Dictionary=route.snapshot()
	var owned: RefCounted=equipment.fork();var loadout: Dictionary=owned.snapshot().loadout
	selected.source_station_id=loadout.station_id;selected.source_system_id=loadout.system_id
	if not route.restore(selected) or not owned.relocate_ordinary_void(bindings,route,true):check(false,route.error+owned.error);return
	check(owned.snapshot().cargo==equipment.snapshot().cargo and source.snapshot().source_station_id==91,"HUD preparation changed cargo or the actual return source")
	check(Story.combat_population(bindings,initial),"The shared HUD rejected its native generated population")
	for change in [{"campaign_cursor":33.0},{"campaign_cursor":34},{"binding_id":"foreign"},{"actors":[]},{"actors":[null]},{"actors":7}]:
		var bad: Dictionary=initial.duplicate(true);bad.merge(change,true)
		check(not Scanner.new().configure(bindings,cat,radii,animation.frames,owned,bad),"Malformed Void population entered the scanner: "+str(change))
	for change in [{"rank":-1},{"rank":21},{"rank":float(initial.actors[0].rank)},{"actor_id":1},{"actor_kind":8},{"hull_catalogue_id":9},{"subtype":1},{"station_id":91},{"population_group":"freighter"},{"binding_id":"foreign"}]:
		var bad: Dictionary=initial.duplicate(true);bad.actors[0].merge(change,true)
		check(not Scanner.new().configure(bindings,cat,radii,animation.frames,owned,bad),"An unsupported Void fighter entered the scanner: "+str(change))
	var crowded: Dictionary=initial.duplicate(true)
	var ceiling: int=Population.maximum_void_actor_count_for_rank(bindings,int(initial.actors[0].rank))
	while crowded.actors.size()<=ceiling:
		var extra: Dictionary=initial.actors[0].duplicate(true);extra.actor_id=crowded.actors.size();crowded.actors.append(extra)
	check(not Scanner.new().configure(bindings,cat,radii,animation.frames,owned,crowded),"The scanner admitted more fighters than the generated rank permits")
	if initial.actors.size()>1:
		var mixed: Dictionary=initial.duplicate(true);mixed.actors[1].rank=0 if initial.actors[0].rank!=0 else 1
		check(not Scanner.new().configure(bindings,cat,radii,animation.frames,owned,mixed),"Mixed-rank fighters entered one generated Void encounter")
	var scanner:=Scanner.new()
	if not scanner.configure(bindings,cat,radii,animation.frames,owned,initial):check(false,scanner.error);return
	var camera:=Transform3D(Basis.IDENTITY,initial.actors[0].pose.origin+Vector3(0,0,1000))
	var aim:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"point":Vector3(640,360,-1000),"viewport_size":Vector2i(1280,720)}
	check(scanner.advance(initial,camera,camera,aim,0,true),scanner.error)
	var first: Dictionary=scanner.snapshot()
	check(first.equipment_id==81 and first.duration_ms==4000 and first.markers.size()==initial.actors.size() and first.markers.all(func(marker):return marker.hostile) and first.candidate_actor_id==0,"Generated mode-zero Void fighters lost source scanner properties or hostile markers")
	check(scanner.advance(moving,camera,camera,aim,4000,true),scanner.error)
	check(scanner.snapshot().selected_actor_id==-1 and scanner.snapshot().elapsed_ms==4000 and scanner.snapshot().animation_frame==animation.frames-1,"Void lock completed at equality or lost its final animation frame")
	var before: Dictionary=scanner.snapshot();var locked: RefCounted=scanner.fork_for_frame()
	check(locked.advance(moving,camera,camera,aim,1,true),locked.error)
	check(locked.snapshot().selected_actor_id==0 and locked.snapshot().events==[{"kind":"sound","source_id":int(bindings.opening_staging.npc_scanner.acquisition_sound_id),"actor_id":0}] and scanner.snapshot()==before,"Void acquisition lost its single sound or changed a retained scanner")
	scanner=locked
	check(scanner.advance(moving,camera,camera,aim,1,true) and scanner.snapshot().markers[0].selected and scanner.snapshot().events.is_empty(),"Void selection repeated its acquisition event")
	var visuals:=Visuals.new();var hud:=Markers.new()
	if not visuals.open(OS.get_cmdline_user_args()[2],library.manifest) or not hud.prepare(library,bindings,visuals):check(false,visuals.error+hud.error);hud.free();return
	root.add_child(hud);root.size=Vector2i(1280,720);hud.size=Vector2(1280,720)
	check(hud.present(scanner.snapshot()) and hud.source().animation.frames==25 and hud.source().regions.size()==15,"The original HUD could not present the selected Void fighters")
	await capture_markers(hud,scanner.snapshot(),label)
	var accepted: Dictionary=scanner.snapshot()
	for change in [{"campaign_cursor":29},{"binding_id":"foreign"}]:
		var bad: Dictionary=moving.duplicate(true);bad.merge(change,true)
		check(not scanner.advance(bad,camera,camera,aim,100,true) and scanner.snapshot()==accepted,"Foreign Void HUD sample changed the accepted target")
	var wrong: Dictionary=moving.duplicate(true);wrong.actors[0].actor_kind=8
	check(not scanner.advance(wrong,camera,camera,aim,100,true) and scanner.snapshot()==accepted,"Another faction replaced an accepted Void target")
	check(scanner.advance(moving,camera,camera,aim,100,false) and scanner.snapshot().selected_actor_id==0 and scanner.snapshot().elapsed_ms==accepted.elapsed_ms and not scanner.snapshot().visible,"Hidden Void HUD advanced or discarded target acquisition")
	check(scanner.advance(destroyed,camera,camera,aim,0,true),scanner.error)
	check(scanner.snapshot().selected_actor_id==-1 and scanner.snapshot().markers.size()==initial.actors.size()-1 and scanner.snapshot().markers.all(func(marker):return marker.actor_id!=0),"The destroyed Void fighter retained its target lock or marker")
	check(hud.present(scanner.snapshot()),hud.error)
	hud.set_mobile_layout(true)
	check(hud.present(scanner.snapshot()),hud.error)
	hud.free()

func capture_markers(hud: Control,sample: Dictionary,label: String) -> void:
	for mobile in [false,true]:
		hud.set_mobile_layout(mobile)
		check(hud.present(sample) and hud.visible and hud.mouse_filter==Control.MOUSE_FILTER_IGNORE,"The generated Void markers hid or intercepted flight input")
		if DisplayServer.get_name()!="headless":
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			var args:=OS.get_cmdline_user_args()
			var directory: String=args[4] if args.size()==5 else OS.get_environment("GOF2_CAPTURE_DIR")
			if not directory.is_empty():
				check(root.get_texture().get_image().save_png(directory.path_join("void-markers-%s-%s.png"%[label,"phone" if mobile else "desktop"]))==OK,"Void marker capture failed")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)

func finish() -> void:quit(1 if failures else 0)
