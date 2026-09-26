extends SceneTree
## Detached construction from the exact earned station40. Never a successor save.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Rules=preload("res://src/content/selected40_population_definitions.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const World=preload("res://src/simulation/opening_world_initialization.gd")
const Route=preload("res://src/simulation/npc_route.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Geometry=preload("res://src/presentation/ship_geometry.gd")
const Body=preload("res://src/simulation/opening_combat_actor.gd")
const Systems=preload("res://src/content/npc_systems_definitions.gd")
const Entry=preload("res://src/simulation/selected40_world_entry.gd")
const VoidSource=preload("res://src/simulation/ordinary_void_source.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const PlayerEntry=preload("res://src/content/player_entry_definitions.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
const Secondary=preload("res://src/simulation/secondary_weapons.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const SceneryPopulation=preload("res://src/simulation/scenery_population.gd")
const SceneryField=preload("res://src/simulation/scenery_field.gd")
const SceneryMotion=preload("res://src/simulation/scenery_motion.gd")
const SceneryBodyResources=preload("res://src/content/scenery_body_resources.gd")
const SceneryEffectResources=preload("res://src/content/scenery_effect_resources.gd")
const SceneryGeometry=preload("res://src/presentation/scenery_geometry.gd")
const SceneryDetail=preload("res://src/presentation/scenery_detail_group.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const NpcWeapons=preload("res://src/simulation/opening_npc_weapons.gd")
const Guidance=preload("res://src/simulation/opening_npc_guidance.gd")
const NpcControl=preload("res://src/simulation/combat_training_control.gd")
const ProjectileVisuals=preload("res://src/simulation/projectile_visual_state.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const CapturePath=preload("res://tests/fixtures/free_play_station_scenario.gd")
var checks:=0
var failures:=0
var captures:=""

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()==4:captures=args.pop_back()
	if captures.is_empty():captures=OS.get_environment("GOF2_CAPTURE_DIR")
	if not captures.is_empty():check(CapturePath.private_path(captures.path_join("capture.png")),"Keep model captures in a private directory")
	check(args.size()==3,"Supply original202 content, binding and visuals")
	if not failures:await verify(args)
	print("Selected40 population: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: Array) -> void:
	var path:=OS.get_environment("GOF2_SOURCE_SAVE");var sha:=OS.get_environment("GOF2_SOURCE_SAVE_SHA256")
	check(sha.length()==64 and FileAccess.get_sha256(path)==sha,"Use only the exact earned Néhma40 input")
	if failures:return
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	check(not Rules.available(bindings),"Raw202 invented a selected40 source attachment")
	check(not PlayerEntry.new().configure(bindings,40,30,true,0),"Raw202 admitted optional navigation40 player entry")
	var raw_scenery:=SceneryPopulation.new()
	check(raw_scenery.configure(bindings) and raw_scenery.for_departure(30,{"companions_empty":true,"location_match":false,"special_placement":false},40).is_empty(),"Raw202 admitted optional navigation40 scenery")
	check(not Body.new().configure_selected40(bindings,cat,Factory.new(),0),"Unconstructed raw202 admitted a selected40 body")
	check(not Player.new().configure_selected40(bindings,cat,null,Factory.new(),{}),"Unconstructed raw202 admitted a selected40 player")
	check(not Scenery.new().configure_selected40(bindings,cat,null,{},Entry.new(),123),"Unconstructed raw202 admitted selected40 scenery")
	check(not Combat.new().configure_selected40(bindings,cat,World.new()),"Unconstructed raw202 admitted selected40 NPC actors")
	check(not NpcWeapons.new().configure_selected40(bindings,cat,World.new(),Combat.new()),"Unconstructed raw202 admitted selected40 guns")
	for env in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var addon: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(env)))
		if not addon is Array or addon.size()!=3:check(false,"Explicit source arguments required");return
		var attached: bool=bindings.attach_dekato_source(str(addon[1]),library.manifest) if env=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(str(addon[1]),library.manifest)
		if not attached:check(false,bindings.error);return
		if env=="GOF2_DEKATO_SOURCE_ARGS":check(not Rules.available(bindings),"203 alone invented the Néhma40 continuation")
	var file:=Save.new();var archive:=Archive.new()
	var document: Dictionary=file.load_document(path,bindings,cat,library)
	if document.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot()
	if OS.get_environment("GOF2_SELECTED40_NAVIGATION_PROBE")=="1":
		await load("res://tests/fixtures/selected40_navigation_checks.gd").run(self,library,bindings,cat,station,args[2])
		check(station.snapshot()==original and archive.capture(station,bindings)==document and FileAccess.get_sha256(path)==sha,"Native navigation altered its immutable earned input")
		return
	check(original.campaign_cursor==40 and original.arrival_player.campaign_cursor==39 and original.mission.kind==161 and original.mission.station_id==-1,"Keep career40 separate from the retained world39")
	var seed: Dictionary=document.inventory.loadout.duplicate(true)
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":40,
		"origin_station_id":seed.station_id,"origin_system_id":seed.system_id,"mission_kind":original.mission.kind,
		"mission_story":true,"mission_completed":false,"mission_failed":false,"rank":int(original.contracts.rank),"difficulty":float(original.contracts.difficulty)}
	check(Rules.context_valid(bindings,context),"The original source and earned origin must resolve the component")
	if failures:return
	var entry_preview:=verify_entry(bindings,cat,station,context)
	entry_preview.ship_id=int(seed.ship_id)
	entry_preview.player=verify_player(bindings,cat,station,context,entry_preview)
	entry_preview.primaries=verify_primaries(library,bindings,cat,station,context,entry_preview)
	entry_preview.scenery=await verify_scenery(library,bindings,cat,station,context)
	if OS.get_environment("GOF2_SELECTED40_APPLICATION_PROBE")=="1":
		check(station.snapshot()==original and archive.capture(station,bindings)==document and FileAccess.get_sha256(path)==sha,"Application component altered the canonical earned save or independent job")
		print("Focused selected40 application component only; generic departure/results remain closed")
		return
	if OS.get_environment("GOF2_SELECTED40_PORTAL_PROBE")=="1":
		print("Focused selected40 portal component only; complete population/flight acceptance not run")
		return
	var invalid:={"base_content_id":"foreign","binding_id":"foreign","campaign_cursor":39,"origin_station_id":-1,"origin_system_id":-1,"mission_kind":11,"mission_story":false,"mission_completed":true,"mission_failed":true,"rank":21,"difficulty":0.75}
	for key in invalid:
		var bad:=context.duplicate(true);bad[key]=invalid[key]
		check(not Factory.new().configure_selected40(bindings,cat,seed,bad),"Invalid construction context accepted: "+key)
	for key in ["base_content_id","binding_id","station_id","system_id","ship_id","equipment_ids"]:
		var bad:=seed.duplicate(true);bad[key]={"base_content_id":"foreign","binding_id":"foreign","station_id":-1,"system_id":-1,"ship_id":-1,"equipment_ids":[-1]}[key]
		check(not Factory.new().configure_selected40(bindings,cat,bad,context),"Invalid retained loadout accepted: "+key)
	for id in range(-1,15):check(Route.new().configure_selected40_generated(bindings,id)==(id>=1 and id<=12),"Generated route scope changed: "+str(id))
	var shown:={};var cargo_rows:=0
	for number in [1,42,4096,2147483647]:
		var factory:=Factory.new()
		if not factory.configure_selected40(bindings,cat,seed,context):check(false,factory.error);return
		var configured:=factory.snapshot()
		check(factory.generate({"state":-1}).is_empty() and factory.snapshot()==configured,"Invalid RNG partially committed the cast")
		var state:=factory.generate({"state":number})
		if state.is_empty():check(false,factory.error);return
		var oracle:=ordered_factory(bindings,cat,seed,context,number)
		check(state.actors.size()==13 and not state.has("station_id") and not state.has("system_id"),"Population construction manufactured a special world or wrong cast")
		check(state.selected40_context==context and state.player_equipment_ids==seed.equipment_ids,"Construction lost the retained context or equipment")
		check(not oracle.is_empty() and oracle.random_state==state.random_state,"Selected40 changed the shared-factory random order")
		if oracle.is_empty():return
		for id in 13:
			var row: Dictionary=state.actors[id];var expected: Dictionary=oracle.actors[id]
			for key in ["factory_position","cargo","fragments","route","hull_catalogue_id","body_pose"]:check(row[key]==expected[key],"Actor %d changed %s"%[id,key])
			check(row.actor_id==id and row.actor_kind==(0 if id<5 else 9) and row.subtype==(1 if id==0 else 0),"The original thirteen-actor order changed")
			check(row.friendly==(id<5) and row.script_hostile==(id>=5),"Actor allegiance changed")
			check(row.active==(id>0 and id<9) and row.targeting_blocked==(id==0 or id>=9) and row.mode==(5 if id==0 or id>=9 else 0),"Parked and active actors were conflated")
			check(row.model_draw_enabled==(id!=0),"Hidden freighter or reserve model visibility changed")
			check(row.body_pose==row.statistics_pose and row.model_local_pose==Transform3D.IDENTITY,"Actor pose spaces diverged")
			check(row.has("name_text_id")== (id in [0,2]),"Scripted names were assigned to unrelated actors")
			if id in [0,2]:check(row.name_text_id=={0:1593,2:1594}[id],"The retained AppStore actor name selected another edition's text")
			cargo_rows+=row.cargo.size()
			if id==0:
				check(row.hull_catalogue_id==13 and row.hull_override==1800+5*context.rank and row.route.is_empty() and row.fragments.is_empty(),"Authored freighter hull override or no-patrol factory changed")
			elif id<5:
				check(row.route.waypoints==[Vector3(-20000,-3000,35000),Vector3(-20000,-3000,200000)] and not row.route.loop and row.route.index==0 and not row.discarded_route.is_empty(),"Escort patrol did not replace its generated route")
				var patrol: RefCounted=factory.route(id)
				check(patrol.advance(row.route.waypoints[0]).index==1 and patrol.advance(row.route.waypoints[1]).completed,"Authored patrol did not exhaust exactly two points")
				check(factory.route(id).snapshot()==row.route,"A route fork mutated the retained construction")
			else:check(not factory.route(id).replace_with_selected40_patrol(),"A Void actor accepted the friendly authored patrol")
		check(factory.generate({"state":number}).is_empty() and factory.snapshot()==state,"The cast generated twice")
		var detached:=factory.snapshot();detached.actors[1].route.waypoints.clear()
		check(factory.snapshot()==state,"A detached snapshot mutated the retained cast")
		var world:=World.new()
		if not world.configure_selected40(bindings,cat,seed,context):check(false,world.error);return
		var complete:=world.generate({"state":number})
		check(not complete.is_empty() and complete.npc_construction==state and complete.weapon_effects.size()==13,"World allocation changed its selected cast")
		if complete.is_empty():return
		var random:=Random.new();random.restore(state.random_state)
		var shared: Dictionary=bindings.opening_actors.npc_initialization.world_initialization
		for id in 13:
			var effects: Dictionary=complete.weapon_effects[id]
			if id==0:check(effects=={"actor_id":0,"unarmed":true},"Hidden freighter allocated a weapon pool");continue
			check(effects.discarded_default.item_id==0 and effects.primary.item_id==(0 if id<5 else int(bindings.mido_travel.alioth_attack.weapons["void"].item_id)),"Terran or Void weapon selection changed")
			for key in ["discarded_default","primary"]:
				var flips:=[]
				for slot in int(shared.weapon_effect_capacity):flips.append(random.next_int(int(shared.weapon_effect_random_bound))==0)
				check(effects[key].flipped==flips,"Weapon pools consumed random draws before the full cast")
		check(complete.random_state==random.snapshot(),"The post-cast weapon RNG diverged")
		check(world.generate({"state":number}).is_empty() and world.snapshot()==complete,"World allocation committed twice")
		if number==42:shown=state
	check(cargo_rows>0,"Cargo checks did not exercise retained generated cargo")
	# Detached statistics parameter tests do not modify the earned career.
	# Include the high-rank case where the authored maximum is LOWER than the
	# ordinary freighter factory maximum, not merely a capacity-raising setter.
	shown.native_bodies=verify_bodies(bindings,cat,seed,context)
	for rank in [0,20]:
		for difficulty in [0.5,1.0]:
			var component_context:=context.duplicate(true)
			component_context.rank=rank;component_context.difficulty=difficulty
			verify_bodies(bindings,cat,seed,component_context)
	var held: Array=bindings.records[17065];bindings.records.erase(17065)
	check(not Factory.new().configure_selected40(bindings,cat,seed,context),"Missing original Terran freighter body was accepted")
	bindings.records[17065]=held
	var ordinary_departure: Dictionary=station.prepare_departure(bindings,cat)
	check(not ordinary_departure.is_empty() and ordinary_departure.campaign_cursor==40 and ordinary_departure.mission==original.mission and station.snapshot()==original,"Preparing ordinary navigation selected or altered the canonical pending story")
	check(archive.capture(station,bindings)==document and FileAccess.get_sha256(path)==sha,"Component testing modified the original saved career or bytes")
	check(not bindings.mido_travel.has("dekato_convoy") and not bindings.mido_travel.has("nehma_return"),"Component construction rewrote raw202")
	if DisplayServer.get_name()!="headless" and not shown.is_empty():
		await render_cast(library,bindings,args[2],shown)
		await render_entry(library,bindings,args[2],entry_preview)
		await render_primaries(library,bindings,args[2],entry_preview.get("primaries",{}))
		await render_npc_weapons(library,bindings,args[2],entry_preview.get("scenery",{}).get("npc",{}))
		await render_consequences(library,bindings,args[2],entry_preview.get("scenery",{}).get("consequences",{}))
		await render_contacts(library,bindings,args[2],entry_preview.get("scenery",{}).get("contacts",{}))
		await load("res://tests/fixtures/selected40_sequence_checks.gd").render(self,library,bindings,args[2],entry_preview.get("scenery",{}).get("sequence",{}),captures)
		await load("res://tests/fixtures/selected40_sequence_checks.gd").render(self,library,bindings,args[2],entry_preview.get("scenery",{}).get("flight",{}),captures)
		await render_scenery(library,bindings,args[2],entry_preview.get("scenery",{}))

## Real origin, real source selection, detached field. No completed trip or
## source42 inventory/cache is synthesized to make the component construct.
func verify_scenery(library: RefCounted,bindings: RefCounted,cat: RefCounted,station: RefCounted,context: Dictionary) -> Dictionary:
	var original: Dictionary=station.snapshot();var equipment: RefCounted=station.equipment_owner()
	var owned: Dictionary=equipment.snapshot();var seed: Dictionary=owned.loadout
	var source: RefCounted=station.contract_owner().void_source_owner();var retained: Dictionary=source.snapshot()
	var random:=Random.new();check(random.restore({"state":42}),random.error)
	var incoming:=Entry.new();var departure:=Entry.new()
	if not incoming.prepare(bindings,cat,source,context,retained.source_station_id,"travel_arrival",random) or not departure.prepare(bindings,cat,source,context,30,"station_departure",random):check(false,incoming.error+departure.error);return {}
	var selection:=incoming.snapshot();var population:=SceneryPopulation.new()
	if not population.configure(bindings):check(false,population.error);return {}
	var chosen:=population.for_selected40(bindings,incoming)
	if chosen.is_empty():check(false,population.error);return {}
	check(chosen.selected40_entry==selection and chosen.scope=="selected40_scenery_component","Scenery lost its prospective native entry boundary")
	var ordinary:={"companions_empty":true,"location_match":false,"special_placement":false}
	var unselected: Dictionary=population.for_departure(selection.station_id,ordinary,40)
	check(not unselected.is_empty() and not unselected.has("selected40_entry"),"Ordinary navigation scenery selected the special cast without its entry owner")
	for invalid in [null,RefCounted.new(),Entry.new(),departure]:
		check(population.for_selected40(bindings,invalid).is_empty(),"An unselected or unprepared entry acquired selected40 scenery")
		var candidate:=Scenery.new()
		check(not candidate.configure_selected40(bindings,cat,equipment,context,invalid,123) and candidate.snapshot().is_empty(),"Scenery admitted an unselected entry or retained a partial field")
	var foreign: RefCounted=incoming.fork();foreign._state.binding_id="foreign"
	check(population.for_selected40(bindings,foreign).is_empty() and not Scenery.new().configure_selected40(bindings,cat,equipment,context,foreign,123),"Scenery accepted another source identity")
	for seconds in [-1,2147483648,123.0,true,null]:
		var candidate:=Scenery.new()
		check(not candidate.configure_selected40(bindings,cat,equipment,context,incoming,seconds) and candidate.snapshot().is_empty(),"Invalid scenery seed partially committed native owners")
	for key in ["binding_id","campaign_cursor","origin_station_id","mission_kind"]:
		var invalid:=context.duplicate(true);invalid[key]={"binding_id":"foreign","campaign_cursor":39,"origin_station_id":selection.station_id,"mission_kind":11}[key]
		var candidate:=Scenery.new()
		check(not candidate.configure_selected40(bindings,cat,equipment,invalid,incoming,123) and candidate.snapshot().is_empty(),"Scenery accepted an altered retained context: "+key)
	var bodies:=SceneryBodyResources.new();var effects:=SceneryEffectResources.new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return {}
	for pair in [[RefCounted.new(),effects],[null,effects],[bodies,RefCounted.new()]]:
		var candidate:=Scenery.new()
		check(not candidate.configure_selected40(bindings,cat,equipment,context,incoming,123,true,pair[0],pair[1]) and candidate.snapshot().is_empty(),"Invalid body/effect resources left a partial field")
	# Independent station-count/center stream; actual placement starts over at
	# the explicit Unix seed, then the whole cast and weapon pools follow it.
	var count_random:=Random.new();check(count_random.seed_from(selection.station_id),count_random.error)
	var count: int=int(bindings.scenery_population.count_base)+count_random.next_int(int(bindings.scenery_population.count_bound))
	var count_state:=count_random.snapshot();var center:=Vector3.ZERO
	for axis in 3:center[axis]=int(bindings.arrival_world_initialization.center_offsets[axis])+count_random.next_int(int(bindings.arrival_world_initialization.center_random_bound))
	check(chosen.count==count and chosen.center==center and chosen.count_random_state==count_state and chosen.random_state==count_random.snapshot(),"Scenery used the placement/player stream for its station count or center")
	var field:=SceneryField.new();var construction_random:=Random.new()
	check(construction_random.seed_from(123),construction_random.error)
	if not field.configure(bindings,cat,selection.station_id,false,false,40):check(false,field.error);return {}
	var expected:=field.generate(center,construction_random.snapshot())
	if expected.is_empty():check(false,field.error);return {}
	var world:=World.new()
	if not world.configure_selected40(bindings,cat,seed,context):check(false,world.error);return {}
	var expected_world:=world.generate(expected.random_state)
	if expected_world.is_empty():check(false,world.error);return {}
	var scenery:=Scenery.new()
	if not scenery.configure_selected40(bindings,cat,equipment,context,incoming,123,true,bodies,effects):check(false,scenery.error);return {}
	var initial:=scenery.snapshot()
	for key in ["station_id","system_id","center","objects","large_count","ore_cursor"]:check(initial[key]==expected[key],"Selected40 changed shared field "+key)
	check(initial.world_initialization==expected_world and scenery.random_state()==expected_world.random_state and initial.random_state==expected_world.random_state,"Cast or weapon allocation restarted/borrowed the wrong random stream")
	check(initial.world_initialization.input_random_state==expected.random_state and initial.world_initialization.npc_construction.actors.size()==13,"Field did not hand its final stream to all thirteen actors")
	check(initial.departure_population==chosen and scenery.seed_seconds()==123,"Scenery lost its seed or separate selection provenance")
	check(initial.bodies.objects.size()==count and initial.destruction.size()==count and initial.detail.selections.size()==count,"Native scenery omitted bodies, lifecycle owners or LOD members")
	check(initial.remaining_count==count and initial.destroyed_count==0 and initial.mined_count==0 and not scenery.has_pending_destruction() and scenery.take_events().is_empty(),"Fresh scenery manufactured damage, drops or accounting")
	for index in count:
		var row: Dictionary=initial.objects[index];var body: Dictionary=initial.bodies.objects[index]
		check(row.model_variant==(2 if selection.system_id==22 else 0) and row.item_id!=int(bindings.scenery_resources.fallback_item_id),"A normal-space warning source became a Void crystal field")
		check(body.position==row.position and body.model_id==row.model_id and body.vitals.hull==body.initial_hull and body.initial_hull>0 and body.half_extent>0,"Scenery body does not match its generated original model")
		check(body.active and body.collision_enabled and body.damage_allowed and not body.destruction_pending,"Initial scenery lost native body permissions")
	var cast: RefCounted=scenery.world_initialization_owner().npc_construction_owner();var player:=Player.new()
	if not player.configure_selected40(bindings,cat,equipment,cast,original.player_cache):check(false,player.error);return {}
	if OS.get_environment("GOF2_SELECTED40_APPLICATION_PROBE")=="1":
		return await load("res://tests/fixtures/selected40_application_checks.gd").run(self,library,bindings,cat,scenery,equipment,original.contracts.reputation,player,incoming.player_pose(Transform3D.IDENTITY),station.contract_owner())
	var flight: Dictionary=await load("res://tests/fixtures/selected40_flight_checks.gd").run(self,library,bindings,cat,scenery,equipment,original.contracts.reputation,player,incoming.player_pose(Transform3D.IDENTITY),station.contract_owner())
	if OS.get_environment("GOF2_SELECTED40_PORTAL_PROBE")=="1":return flight
	var sequence: Dictionary=load("res://tests/fixtures/selected40_sequence_checks.gd").run(self,library,bindings,cat,scenery,equipment,original.contracts.reputation,player,incoming.player_pose(Transform3D.IDENTITY))
	var npc:=verify_npc_weapons(library,bindings,cat,scenery,player,incoming.player_pose(Transform3D.IDENTITY))
	var consequences:=verify_consequences(library,bindings,cat,scenery,equipment,original.contracts.reputation,player,incoming.player_pose(Transform3D.IDENTITY))
	var contacts:=verify_contacts(library,bindings,cat,scenery,equipment,original.contracts.reputation,player,incoming.player_pose(Transform3D.IDENTITY))
	check(player.cache_snapshot()==original.player_cache and player.loadout().station_id==30 and player.loadout().system_id==2,"Scenery composition fabricated a target-world player cache")
	check(not scenery.configure_selected40(bindings,cat,equipment,context,incoming,456,true,bodies,effects) and scenery.snapshot()==initial,"Reconfiguration replaced a live field")
	var read:=scenery.read_snapshot();var detached:=scenery.snapshot()
	detached.objects[0].position=Vector3.INF;detached.bodies.objects[0].vitals.hull=0
	detached.departure_population.selected40_entry.source_after.eligible_selection_count=0
	check(scenery.snapshot()==initial and read==initial,"Returned scenery observations alias native owners")
	var moved: RefCounted=scenery.fork_for_frame();var motion:=SceneryMotion.new()
	check(motion.configure(bindings,expected),motion.error)
	for frame in 30:
		check(moved.update(100,center,1.0,center),moved.error)
		check(motion.update(100),motion.error)
	var advanced: Dictionary=moved.snapshot()
	check(advanced.objects==motion.snapshot().objects and advanced.objects!=initial.objects,"Field rotation bypassed the shared native motion owner")
	check(advanced.bodies==initial.bodies and advanced.random_state==initial.random_state and advanced.world_initialization==initial.world_initialization,"Intact rotation changed body state, the cast or the shared random stream")
	check(scenery.snapshot()==initial and read==initial and moved.presentation_identity()==scenery.presentation_identity(),"A scenery frame mutated its parent or replaced presentation identity")
	for delta in [-1,0.5,true]:check(not moved.update(delta,center) and moved.snapshot()==advanced,"Invalid scenery frame partially committed")
	check(not moved.update(16,center,1.0,null,{"state":-1}) and moved.snapshot()==advanced,"Invalid shared RNG partially committed scenery")
	var later:=Scenery.new()
	if not later.configure_selected40(bindings,cat,equipment,context,incoming,456,true,bodies,effects):check(false,later.error);return {}
	var changed:=later.snapshot()
	check(changed.center==initial.center and changed.objects.size()==count and changed.objects!=initial.objects,"Unix reseeding changed the station center/count or failed to change placement")
	# Explicit source-location parameter case, not an edited earned source.
	# Arrival and launch at the SAME selected place must share field construction.
	var local_source: RefCounted=source.fork();var parameter:=retained.duplicate(true)
	parameter.source_station_id=30;parameter.source_system_id=2
	check(local_source.restore(parameter),local_source.error)
	var local_arrival:=Entry.new();var local_launch:=Entry.new()
	check(local_arrival.prepare(bindings,cat,local_source,context,30,"travel_arrival",random),local_arrival.error)
	check(local_launch.prepare(bindings,cat,local_source,context,30,"station_departure",random),local_launch.error)
	var arrival_center:=population.for_selected40(bindings,local_arrival);var launch_center:=population.for_selected40(bindings,local_launch)
	check(not arrival_center.is_empty() and not launch_center.is_empty() and arrival_center.center==launch_center.center and arrival_center.random_state==launch_center.random_state,"Incoming player placement changed scenery center selection")
	var local_field:=Scenery.new()
	if not local_field.configure_selected40(bindings,cat,equipment,context,local_launch,123,true,bodies,effects):check(false,local_field.error);return {}
	check(local_field.snapshot().station_id==30 and local_field.snapshot().system_id==2 and local_field.snapshot().center==launch_center.center,"Scenery hardcoded the observed source42")
	var local_history: RefCounted=load("res://src/simulation/faction_reputation.gd").new()
	check(local_history.configure_selected40(bindings,cat,local_field,equipment) and local_history.snapshot().system_id==2,"Consequence reputation hardcoded the observed source8")
	check(station.snapshot()==original and equipment.snapshot()==owned and source.snapshot()==retained and random.snapshot()=={"state":42},"Scenery testing changed the actual earned career, source or caller RNG")
	print("Selected40 native asteroid field: %d original bodies at system %d/station %d; center %s; field -> 13 actors -> weapons; prospective only"%[count,selection.system_id,selection.station_id,str(center)])
	return {"initial":initial,"advanced":advanced,"player":player.snapshot(),"entry":selection,"npc":npc,"consequences":consequences,"contacts":contacts,"sequence":sequence,"flight":flight}

## Actual projectiles, native target geometry and automatic NPC firing. Pilot
## firing/contact poses are explicit component inputs, not an earned arrival.
func verify_contacts(library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted,pose: Transform3D) -> Dictionary:
	var parent_player: Dictionary=player.snapshot();var parent_field: Dictionary=scenery.snapshot();var owned: Dictionary=equipment.snapshot()
	var pilot: RefCounted=player.fork_for_frame();check(pilot.set_permissions(true,true),pilot.error)
	var encounter:=Encounter.new()
	if not encounter.configure_selected40(bindings,cat,library,pilot,scenery,equipment,reputation):check(false,encounter.error);return {}
	var initial: Dictionary=encounter.snapshot();var random: Dictionary=scenery.random_state()
	check(initial.scope=="selected40_mixed_contact_component" and initial.combat.actors.size()==13 and initial.controller.destruction.size()==13,"Mixed contact entry omitted native bodies or consequences")
	check(initial.controller.random_state==random and initial.weapons.selected40.random_state==random,"Contact entry reset the post-field/cast/weapon stream")
	var membership: Dictionary=encounter._inventory.snapshot()
	check(membership.npc_ids==range(13) and membership.scenery_indices==range(parent_field.objects.size()),"Primary membership omitted parked actors or source scenery")
	check(membership.station_id==30 and membership.system_id==2 and membership.target_station_id==42 and membership.target_system_id==8 and pilot.loadout().station_id==30,"Target construction relocated the origin equipment")
	check(not encounter.configure_selected40(bindings,cat,library,pilot,scenery,equipment,reputation) and encounter.snapshot()==initial,"Repeated contact setup discarded live owners")
	check(encounter.evaluate_weapons(pilot,Transform3D(Basis.IDENTITY,Vector3(NAN,0,0)),1,scenery,random).is_empty(),"Nonfinite contact pose was admitted")
	check(encounter.evaluate_weapons(pilot,pose,1,Scenery.new(),random).is_empty(),"Unrelated scenery entered mixed contacts")
	check(encounter.evaluate_weapons(pilot,pose,1,scenery,{"state":-1}).is_empty(),"Invalid contact stream partially committed")
	var alien: RefCounted=pilot.fork_for_frame();alien._selected40_construction=Factory.new()
	check(encounter.evaluate_weapons(alien,pose,1,scenery,random).is_empty() and not Encounter.new().configure_selected40(bindings,cat,library,alien,scenery,equipment,reputation),"Same-shaped player replaced the actual constructor generation")
	var world: RefCounted=scenery.world_initialization_owner();var regenerated:=World.new()
	check(regenerated.configure_selected40(bindings,cat,owned.loadout,world.snapshot().selected40_context),regenerated.error)
	check(regenerated.generate(world.snapshot().input_random_state)==world.snapshot(),"Independent native generation did not reproduce the identity fixture")
	var same_shaped:=Player.new()
	check(same_shaped.configure_selected40(bindings,cat,equipment,regenerated.npc_construction_owner(),pilot.cache_snapshot()),same_shaped.error)
	check(not Encounter.new().configure_selected40(bindings,cat,library,same_shaped,scenery,equipment,reputation),"Dictionary-equal regenerated player replaced the actual constructor")
	var missing:=Encounter.new();var held: Array=bindings.records[14602];bindings.records.erase(14602)
	check(not missing.configure_selected40(bindings,cat,library,pilot,scenery,equipment,reputation) and missing.snapshot().is_empty(),"Late missing impact resource committed a partial native encounter")
	bindings.records[14602]=held
	check(encounter.snapshot()==initial and player.snapshot()==parent_player and scenery.snapshot()==parent_field and equipment.snapshot()==owned,"Rejected setup or contact mutated retained parents")
	# Let the shared early and late phases warm the actual intervals and AI.
	var active: RefCounted=encounter;var field: RefCounted=scenery;var current: RefCounted=pilot
	for frame in 6:
		var early: Dictionary=active.evaluate_weapons(current,pose,100,field,random)
		if early.is_empty():check(false,active.error);return {}
		check(not early.encounter.primary_contacts().is_empty() and not early.encounter.primary_npc_contact(),"An empty mounted-weapon record became an NPC hit")
		var late: Dictionary=early.encounter.evaluate_world(early.player,pose,100,early.random_state)
		if late.is_empty():check(false,early.encounter.error);return {}
		active=late.encounter;field=early.scenery;current=early.player;random=late.random_state
	var enemy: Dictionary=active.combat_owner().actor_snapshot(5)
	var mount: Dictionary=active.snapshot().primaries.guns[0].mount
	var aim:=Transform3D(Basis.IDENTITY,enemy.position-mount.position-Vector3(0,0,100))
	var launch: Dictionary=active.evaluate_primary_fire(current,aim,true,true,random)
	if launch.is_empty():check(false,active.error);return {}
	check(launch.encounter.snapshot().primary_fire.weapons[0].result.fired,"Native installed primary did not allocate its shot")
	var fired: RefCounted=launch.encounter;var before: Dictionary=fired.snapshot()
	var primary: Dictionary=fired.evaluate_weapons(current,pose,0,field,launch.random_state)
	if primary.is_empty():check(false,fired.error);return {}
	var hits: Array=primary.encounter.primary_contacts()[0].contacts
	check(primary.encounter.primary_npc_contact(),"Real mounted primary contact failed to set NPC aim feedback")
	check(hits.any(func(row):return row.target=={"group":"npc","index":5}),"Real primary failed to contact the original Void body")
	check(primary.encounter.combat_owner().actor_snapshot(5).vitals.hull<enemy.vitals.hull,"Real primary contact did not apply declared damage")
	check(primary.encounter.snapshot().impact_visuals.hits.any(func(row):return row.key=="player:0"),"Real primary did not retain its original impact slot")
	check(fired.snapshot()==before and field.snapshot()==scenery.snapshot(),"Preparing a primary contact mutated its parent")
	# The impact stage runs AFTER both damage passes. Break only a detached
	# impact observation to prove late rejection rolls back already staged hits.
	var broken: RefCounted=fired.fork_for_frame();broken._impacts=fired._impacts.fork_for_frame()
	broken._impacts._state.weapons[0].item_id=-1
	var broken_before: Dictionary=broken.snapshot();var prior_current: Dictionary=current.snapshot();var prior_field: Dictionary=field.snapshot()
	check(broken.evaluate_weapons(current,pose,0,field,launch.random_state).is_empty() and broken.error.contains("Impact"),"Malformed late impact state failed to reject the prepared frame")
	check(broken.snapshot()==broken_before and current.snapshot()==prior_current and field.snapshot()==prior_field and fired.snapshot()==before,"Late impact rejection leaked damage, cleanup or clocks into parents")
	# An independent real mounted shot visits all NPCs then the actual field.
	var rock: Dictionary=field.snapshot().bodies.objects[0]
	# Use the incoming face of the original collision bounds, not the hidden
	# center. Source sampling is center-position+velocity (not a swept ray),
	# with strict inequalities, so retain the real gun's one-velocity offset.
	var actual_weapon: Dictionary=active.snapshot().primaries.guns[0].projectiles.weapon
	var extent:=int(rock.half_extent if actual_weapon.collision_bounds.mode=="target" else actual_weapon.collision_bounds.half_extent)
	var speed:=float(actual_weapon.speed_units_per_millisecond)
	var rock_point: Vector3=rock.position+Vector3(0,0,-float(extent)+speed+1.0)
	var geometry: RefCounted=load("res://src/simulation/ordinary_hit_geometry.gd").new()
	check(geometry.bounds(rock_point,Vector3(0,0,speed),rock.position,extent).get("hit")==true,"Boundary fixture lost the source velocity offset or strict bounds")
	var rock_aim:=Transform3D(Basis.IDENTITY,rock_point-mount.position-Vector3(0,0,100))
	var rock_launch: Dictionary=active.evaluate_primary_fire(current,rock_aim,true,true,random)
	if rock_launch.is_empty():check(false,active.error);return {}
	var rock_hit: Dictionary=rock_launch.encounter.evaluate_weapons(current,pose,0,field,rock_launch.random_state)
	if rock_hit.is_empty():check(false,rock_launch.encounter.error);return {}
	check(rock_hit.encounter.primary_contacts()[0].contacts.any(func(row):return row.target=={"group":"scenery","index":0}),"Real primary skipped the source asteroid target")
	check(not rock_hit.encounter.primary_npc_contact(),"A real asteroid hit incorrectly enabled NPC aim feedback")
	check(rock_hit.scenery.snapshot().bodies.objects[0].vitals.hull<rock.vitals.hull and field.snapshot()==prior_field,"Scenery damage was missing or mutated its parent")
	# Fire the real mounted gun repeatedly at a disclosed component pose. No
	# synthetic damage or vitals changes: the following actor phase must account
	# for the projectile-killed Void fighter exactly once, not complete a mission.
	var lethal: Dictionary=primary;var killed_shots:=1
	for frame in 220:
		if lethal.encounter.combat_owner().actor_snapshot(5).vitals.hull==0:break
		var clocked: Dictionary=lethal.encounter.evaluate_weapons(lethal.player,pose,100,lethal.scenery,lethal.random_state)
		if clocked.is_empty():check(false,lethal.encounter.error);return {}
		var shot: Dictionary=clocked.encounter.evaluate_primary_fire(clocked.player,aim,true,true,clocked.random_state)
		if shot.is_empty():check(false,clocked.encounter.error);return {}
		if shot.encounter.snapshot().primary_fire.weapons[0].result.fired:killed_shots+=1
		lethal=shot.encounter.evaluate_weapons(clocked.player,pose,0,clocked.scenery,shot.random_state)
		if lethal.is_empty():check(false,shot.encounter.error);return {}
	check(lethal.encounter.combat_owner().actor_snapshot(5).vitals.hull==0 and killed_shots==ceili(float(enemy.vitals.hull)/6.0),"Declared primary shots failed to exhaust the original Void hull")
	check(lethal.encounter.snapshot().controller.accounting.events.is_empty(),"Projectile contact bypassed the late native death accounting phase")
	var death: Dictionary=lethal.encounter.evaluate_world(lethal.player,pose,100,lethal.random_state)
	if death.is_empty():check(false,lethal.encounter.error);return {}
	var counted: Dictionary=death.encounter.snapshot().controller
	check(counted.accounting.events.size()==1 and counted.accounting.counter_deltas.player_kills==1 and counted.accounting.counter_deltas.pirate_kills==0,"Projectile-killed Void acquired duplicate or pirate credit")
	check(counted.defeat_status.is_empty() and not counted.has("contract_result") and counted.combat.actors.slice(9).all(func(row):return not row.active),"Mixed contacts opened reserve choreography or mission completion")
	var death_again: Dictionary=death.encounter.evaluate_world(lethal.player,pose,100,death.random_state)
	check(not death_again.is_empty() and death_again.encounter.snapshot().controller.accounting==counted.accounting,"A second native frame duplicated projectile-death credit")
	# Do not move NPCs or force their requests. Find a genuine AI shot that
	# travels into an escort, then repeat that precise pass with a pilot at its
	# real shot position to exercise the source player-FIRST mixed list.
	var mixed:={};var automatic_ms:=600;var automatic_shots:=0
	for frame in 1200:
		var previous: Dictionary=active.snapshot()
		var previous_field: Dictionary=field.snapshot();var previous_player: Dictionary=current.snapshot()
		var early: Dictionary=active.evaluate_weapons(current,pose,100,field,random)
		if early.is_empty():check(false,active.error);return {}
		var selected: Array=early.encounter.snapshot().weapon_events.filter(func(row):return row.actor_id>=5 and not row.npc_contacts.is_empty())
		if not selected.is_empty():
			var event: Dictionary=selected[0];var contact: Dictionary=event.npc_contacts[0]
			var shot: Dictionary=previous.weapons.actors[event.actor_id].projectiles.slots[contact.slot]
			var overlap:=Transform3D(Basis.IDENTITY,shot.position)
			mixed=active.evaluate_weapons(current,overlap,100,field,random)
			if mixed.is_empty():check(false,active.error);return {}
			var repeated: Dictionary=active.evaluate_weapons(current,overlap,100,field,random)
			check(not repeated.is_empty() and repeated.encounter.snapshot()==mixed.encounter.snapshot() and repeated.player.snapshot()==mixed.player.snapshot() and repeated.random_state==mixed.random_state,"Repeated native contacts changed damage, effects or RNG")
			var observed: Array=mixed.encounter.snapshot().weapon_events.filter(func(row):return row.actor_id==event.actor_id)
			check(observed.size()==1 and observed[0].contacts.any(func(row):return row.projectile_id==shot.id) and observed[0].npc_contacts.any(func(row):return row.projectile_id==shot.id and row.actor_id==contact.actor_id),"A real AI projectile failed to visit player then the original NPC")
			check(observed[0].last_contact_actor=={"group":"npc","index":observed[0].npc_contacts.back().actor_id} and shot.id in observed[0].motion.cleared,"Cleanup happened before the complete mixed target list")
			check(mixed.player.snapshot().vitals!=current.snapshot().vitals and mixed.encounter.combat_owner().actor_snapshot(contact.actor_id).vitals.hull<previous.combat.actors[contact.actor_id].vitals.hull,"Shared real shot failed to damage both native targets")
			check(active.snapshot()==previous and field.snapshot()==previous_field and current.snapshot()==previous_player and player.snapshot()==parent_player,"Natural contact sibling mutated parent state")
			mixed.actor_id=contact.actor_id;mixed.shot=shot;mixed.shooter_id=event.actor_id;mixed.pose=overlap
			break
		var late: Dictionary=early.encounter.evaluate_world(early.player,pose,100,early.random_state)
		if late.is_empty():check(false,early.encounter.error);return {}
		for event in late.encounter.actor_events():
			for fire in event.get("firing",{}).get("actors",[]):
				if fire.outcome.fired:
					automatic_shots+=1
					check(fire.outcome.projectile.position==previous.combat.actors[fire.actor_id].pose.origin,"Native NPC fired from its moved rather than pre-motion pose")
		active=late.encounter;field=early.scenery;current=early.player;random=late.random_state;automatic_ms+=100
	check(not mixed.is_empty(),"No naturally fired Void shot reached an original escort through the complete shared contact path")
	check(player.snapshot()==parent_player and scenery.snapshot()==parent_field and equipment.snapshot()==owned,"Real mixed contact tests changed the earned origin owners")
	print("Selected40 real mixed contacts: native primary -> Void/asteroid; %d mounted shots -> one native Void kill; %d ms automatic flight, %d source AI shots; player-first then NPC; late-impact rollback; no departure/result"%[killed_shots,automatic_ms,automatic_shots])
	return {"primary":primary,"mixed":mixed,"asteroid":rock_hit,"enemy_id":5}

func render_contacts(library: RefCounted,bindings: RefCounted,art: String,proof: Dictionary) -> void:
	if proof.is_empty():return
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	for name in ["primary","mixed","asteroid"]:
		var contact: Dictionary=proof.get(name,{})
		if contact.is_empty():check(false,"Missing actual mixed-contact render case");continue
		var remote:=Transform3D(Basis.IDENTITY,Vector3(-105000,0,80000))
		var sampled: Dictionary=contact.encounter.evaluate_weapons(contact.player,remote,100,contact.scenery,contact.random_state)
		if sampled.is_empty():check(false,contact.encounter.error);continue
		var owner: RefCounted=sampled.encounter.impact_visual_owner();var scene: Dictionary=sampled.encounter.presentation_snapshot()
		var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=1;camera.far=500000
		var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
		var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
		var focus:=Vector3.ZERO;var radius:=1500.0
		if name=="asteroid":
			var field: Dictionary=sampled.scenery.snapshot();var body: Dictionary=field.bodies.objects[0]
			focus=body.position;radius=maxf(1500.0,body.model_radius*body.scale)
			var geometry:=SceneryGeometry.new();viewport.add_child(geometry)
			if not geometry.build(field,library,visuals,bindings,"high",true) or not geometry.apply_state(field) or not geometry.apply_activity(field.bodies):check(false,geometry.error);viewport.free();continue
		else:
			var actor: Dictionary=scene.combat.actors[int(contact.actor_id) if name=="mixed" else int(proof.enemy_id)]
			focus=actor.pose.origin
			var ship:=Geometry.new();viewport.add_child(ship)
			if not ship.build(int(actor.hull_catalogue_id),library,visuals,bindings):check(false,ship.error);viewport.free();continue
			ship.transform=actor.pose;check(ship.apply_selection({"visible":true,"level":0}),ship.error)
		camera.look_at_from_position(focus+Vector3(1.2,0.8,-1.8)*radius,focus)
		var impacts: Node3D=load("res://src/presentation/ordinary_impact_geometry.gd").new();viewport.add_child(impacts)
		if not impacts.build(owner,library,visuals,bindings):check(false,impacts.error);viewport.free();continue
		var drawn: Dictionary=impacts.prepare_world(owner,scene,camera.global_transform)
		if drawn.is_empty():check(false,impacts.error);viewport.free();continue
		impacts.commit_world(drawn)
		check(impacts.guns.any(func(gun):return gun.slots.any(func(slot):return slot.visible)),"Actual projectile impact was not rendered")
		var label:=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",22);viewport.add_child(label)
		label.text="SELECTED 40 | REAL PROJECTILE CONTACT: %s\nOriginal models and slot-local impact animation, sampled 100 ms after collision.\n%s\nNative component test, not admitted travel, mission completion or a successor save."%[name.to_upper(),"Automatically fired Void shot hit player then escort; only the pilot contact pose is controlled." if name=="mixed" else "Actual installed primary, source muzzle, real target geometry and native damage; controlled firing pose."]
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image();check(image!=null and not image.is_empty(),"Native contact did not render")
		if not captures.is_empty() and image!=null:check(image.save_png(captures.path_join("selected40-contacts-%s.png"%name))==OK,"Could not retain native contact capture")
		viewport.free()

## Disclosed component hits exercise shared native consequences, not pilot
## contact evidence, reserve activation, mission credit or a successor save.
func verify_consequences(library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,equipment: RefCounted,reputation: Dictionary,player: RefCounted,pose: Transform3D) -> Dictionary:
	var world: RefCounted=scenery.world_initialization_owner();var generated: Dictionary=world.snapshot()
	var packet: Dictionary=world.npc_construction_owner().snapshot();var field: Dictionary=scenery.snapshot()
	var inventory: Dictionary=equipment.snapshot();var prior_player: Dictionary=player.snapshot()
	var data:=Rules.consequence_profile(bindings,cat,scenery,equipment)
	check(not data.is_empty(),"Selected40 consequences did not resolve the actual source field")
	if data.is_empty():return {}
	check(data.station_id==42 and data.system_id==8 and data.equipment_station_id==30 and data.context.origin_system_id==2,"Consequences conflated the selected encounter with origin inventory")
	var primary:=int(cat.tables.systems[8].fields[int(bindings.mido_travel.free_population.faction_field)])
	check(data.lifecycle.reactions.primary_faction==primary and data.lifecycle.reactions.eligible_factions==[primary,int(bindings.mido_travel.free_population.enemy_factions[primary])],"Reaction factions do not belong to the selected source system")
	check(data.actors.map(func(row):return row.cargo_model_id)==[16992,16992,16992,16992,16992,16916,16916,16916,16916,16916,16916,16916,16916],"Terran/Void retained cargo model selection changed")
	var control:=NpcControl.new()
	if not control.configure_selected40(bindings,cat,world):check(false,control.error);return {}
	var unprepared:=control.snapshot();var identity: RefCounted=control.flight_identity()
	for invalid in [null,RefCounted.new(),Scenery.new()]:
		check(not control.prepare_selected40_consequences(library,bindings,cat,invalid,equipment,reputation) and control.snapshot()==unprepared,"Invalid scenery partially prepared consequences")
	check(not control.prepare_selected40_consequences(library,bindings,cat,scenery,null,reputation) and control.snapshot()==unprepared,"Missing native inventory partially prepared consequences")
	check(not control.prepare_selected40_consequences(library,bindings,cat,scenery,equipment,{"axes":[0.5,0],"override":-1}) and control.snapshot()==unprepared,"Invalid reputation partially committed reactions")
	check(Rules.consequence_profile(bindings,cat,scenery,equipment)==data,"Rejected preparation changed the consequence profile")
	check(is_same(control._selected40_world,world),"Rejected preparation replaced the retained native world")
	var duplicate:=World.new();check(duplicate.configure_selected40(bindings,cat,inventory.loadout,generated.selected40_context),duplicate.error)
	check(not duplicate.generate(generated.input_random_state).is_empty(),duplicate.error)
	var foreign:=NpcControl.new();check(foreign.configure_selected40(bindings,cat,duplicate),foreign.error)
	check(not foreign.prepare_selected40_consequences(library,bindings,cat,scenery,equipment,reputation),"Same-shaped construction replaced the actual world identity")
	# Resource failure happens AFTER a staged reaction/ledger exists. Neither
	# the parent controller nor its live actors may retain that partial setup.
	var held: Array=bindings.records[16992];bindings.records.erase(16992)
	check(not control.prepare_selected40_consequences(library,bindings,cat,scenery,equipment,reputation) and control.snapshot()==unprepared,"Missing original cargo resource partially committed consequences")
	bindings.records[16992]=held
	check(Rules.consequence_profile(bindings,cat,scenery,equipment)==data,"Resource rollback changed the source/inventory consequence profile")
	check(is_same(control._selected40_world,world) and Rules.matches_world(scenery,world),"Resource rollback replaced the retained native world generation")
	if not control.prepare_selected40_consequences(library,bindings,cat,scenery,equipment,reputation):check(false,control.error);return {}
	var initial:=control.snapshot();var guns:=NpcWeapons.new()
	if not guns.configure_selected40(bindings,cat,world,control.combat_owner()):check(false,guns.error);return {}
	check(initial.support_state=="selected40_consequence_component" and initial.random_state==generated.random_state and control.flight_identity()==identity,"Consequence setup reset motion identity or post-weapon RNG")
	check(initial.combat.actors==unprepared.combat.actors and initial.destruction.size()==13 and initial.accounting.events.is_empty(),"Preparation altered bodies or omitted lifecycle owners")
	check(initial.combat.reputation.system_id==8 and initial.combat.reputation.actor_kinds==[0,0,0,0,0,9,9,9,9,9,9,9,9] and not initial.combat.reputation.has("spawn_generations"),"Fixed selected40 cast became ordinary recycled traffic")
	check(initial.combat.provocation.station_id==42 and initial.combat.provocation.active_mission_kind==161 and initial.combat.provocation.initial_reputation==reputation,"Reaction owner lost selected location, mission or earned reputation")
	check(initial.combat.provocation.permanent_hostile==[false,false,false,false,false,true,true,true,true,true,true,true,true],"Provocation lost authored permanent force flags")
	for id in 13:
		check(initial.destruction[id].phase=="ready" and initial.destruction[id].cargo.entries==packet.actors[id].cargo,"Lifecycle regenerated cargo or started a death during preparation: "+str(id))
		check(initial.destruction[id].fragments==packet.actors[id].fragments,"Lifecycle resampled factory debris: "+str(id))
	check(initial.destruction[0].hull_catalogue_id==13 and initial.destruction[0].actor_kind==0 and initial.destruction[0].fragments.is_empty(),"Parked freighter inherited the wrong hull or sampled delayed debris early")
	check(not control.prepare_selected40_consequences(library,bindings,cat,scenery,equipment,reputation) and control.snapshot()==initial,"Reconfiguration replaced live consequences")
	check(control.combat_owner().supports_weapon_hit(guns.snapshot().actors[1].projectiles.weapon),"Prepared consequences rejected their declared NPC weapon")
	var target:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":player.loadout().ship_id,
		"pose":pose,"active":prior_player.active,"hull":prior_player.vitals.hull,"targeting_blocked":false,"special_flight":false,"alternate_position":null}
	check(control.advance(100,target,foreign.combat_owner()).is_empty() and control.snapshot()==initial,"Wrong native world partially advanced consequences")
	var incomplete:=Combat.new();check(incomplete.configure_selected40(bindings,cat,world),incomplete.error)
	check(control.advance(100,target,incomplete).is_empty() and control.snapshot()==initial,"Actor update discarded prepared consequence ownership")
	var branch: RefCounted=control.fork_for_frame();var hit: RefCounted=branch.combat_owner()
	check(hit.begin_contact_pass(generated.random_state,true),hit.error)
	var accepted: Dictionary=hit.normal_hit(1,80,false)
	if accepted.is_empty():check(false,hit.error);return {}
	check(hit.refresh_hostility(1),hit.error)
	var normal: Dictionary=hit.snapshot()
	check(normal.actors[1].vitals.hull==initial.combat.actors[1].vitals.hull-80 and normal.actors[1].friendly and not normal.actors[1].hostile,"Normal damage erased persistent Terran friendship")
	check(normal.provocation.requested_damage[1]==(80 if 0 in data.lifecycle.reactions.eligible_factions else 0),"Requested damage used origin-world or wrong-faction reactions")
	check(accepted.reactions.is_empty() and normal.provocation.radio_serial==0 and hit.contact_random_state()==generated.random_state,"Active kind161 warning consumed radio RNG or invented generic speech")
	check(not hit.normal_hit(2,20,true).is_empty() and hit.snapshot().provocation.requested_damage[2]==0,"NPC-origin hit acquired player provocation")
	check(not hit.normal_hit(5,20,false).is_empty() and hit.snapshot().provocation.requested_damage[5]==0,"Permanent Void hostility acquired player provocation")
	for id in [0,9,10,11,12]:
		var parked: Dictionary=hit.actor_snapshot(id)
		check(not hit.normal_hit(id,1000000,false).is_empty() and hit.actor_snapshot(id).vitals==parked.vitals and not hit.actor_snapshot(id).active,"Parked actor received damage or activation: "+str(id))
	for invalid in [-1,0.5,true]:
		var before: Dictionary=hit.snapshot()
		check(hit.normal_hit(1,invalid,false).is_empty() and hit.snapshot()==before,"Invalid damage partially committed reactions/history")
		check(hit.systems_hit(1,invalid,false).is_empty() and hit.snapshot()==before,"Invalid EMP partially committed systems/history")
	check(control.snapshot()==initial,"A consequence fork mutated its parent")
	# Systems damage has independent attribution and counters. This is a
	# component stimulus, not an EMP launch; paid origin ammunition stays intact.
	for nonplayer in [false,true]:
		var emp: RefCounted=control.fork_for_frame();var contact: RefCounted=emp.combat_owner()
		check(contact.begin_contact_pass(generated.random_state,true),contact.error)
		var capacity: int=contact.actor_snapshot(1).systems.capacity
		var effect: Dictionary=contact.systems_hit(1,capacity,nonplayer)
		if effect.is_empty():check(false,contact.error);return {}
		var disabled: Dictionary=contact.snapshot()
		check(disabled.actors[1].systems.integrity==0 and disabled.actors[1].vitals==initial.combat.actors[1].vitals,"EMP changed hull or failed to deplete native systems")
		check(disabled.provocation.requested_damage[1]==0 and disabled.reputation.events.size()==(0 if nonplayer else 1),"Systems damage leaked into hull provocation or lost attribution")
		check(contact.systems_hit(1,capacity,nonplayer).get("accepted")==false and contact.snapshot()==disabled,"Repeated disabled hit duplicated systems history")
		var stepped: Dictionary=emp.advance(0,target,contact,contact.contact_random_state())
		if stepped.is_empty():check(false,emp.error);return {}
		check(emp.snapshot().combat.actors[1].friendly and not emp.snapshot().combat.actors[1].hostile and emp.snapshot().accounting.events.is_empty(),"Native EMP recovery frame erased friendship or recorded a death")
	# Three distinct lethal stimuli: friendly Terran, player-killed Void and
	# NPC-killed Void. Account only in the ensuing native actor/death pass.
	var lethal: RefCounted=control.combat_owner().fork_for_frame()
	check(lethal.begin_contact_pass(generated.random_state,true),lethal.error)
	for id in [1,5,6]:
		if lethal.normal_hit(id,1000000,id==6).is_empty():check(false,lethal.error);return {}
	check(lethal.snapshot().reputation.events.map(func(row):return row.change)==[-5,0,0],"Terran/Void lethal reputation or NPC attribution changed")
	var running: RefCounted=control.fork_for_frame();var repeat: RefCounted=control.fork_for_frame()
	var first: Dictionary=running.advance(100,target,lethal,lethal.contact_random_state())
	var again: Dictionary=repeat.advance(100,target,lethal,lethal.contact_random_state())
	if first.is_empty() or again.is_empty():check(false,running.error+repeat.error);return {}
	check(running.snapshot()==repeat.snapshot() and first.random_state==again.random_state,"Native destruction did not deterministically consume retained world RNG")
	var started: Dictionary=running.snapshot();var counters: Dictionary=started.accounting.counter_deltas
	check(started.accounting.events.size()==3 and counters.hostile_deaths==2 and counters.hostile_remaining==-2 and counters.nonhostile_remaining==-1,"Hostile/friendly death accounting skipped native actor semantics")
	check(counters.player_kills==1 and counters.world_player_kills==1 and counters.world_other_kills==1 and counters.pirate_kills==0,"Void deaths were counted as pirates, friendly kills or wrong attribution")
	check(started.defeat_status.is_empty() and not started.has("contract_result"),"Native death fabricated selected40 mission completion")
	var shown:={"tumble":{"death":running.destruction_owner(5),"actor":started.combat.actors[5]}}
	var stream: Dictionary=first.random_state;var finished:=false;var elapsed:=100
	for tick in 900:
		var frame: Dictionary=running.advance(100,target,null,stream)
		if frame.is_empty():check(false,running.error);return {}
		stream=frame.random_state;elapsed+=100
		var current: Dictionary=running.snapshot()
		check(current.accounting.events==started.accounting.events and current.combat.reputation.events==started.combat.reputation.events,"Destruction clocks duplicated accounting or lethal reputation")
		for id in [1,5,6]:check(current.destruction[id].cargo.entries==packet.actors[id].cargo,"Destruction discarded or regenerated retained cargo")
		var death: Dictionary=current.destruction[5]
		if not shown.has("explosion") and death.phase=="explosion" and death.effect.active and death.effect.elapsed_ms>=100:
			shown.explosion={"death":running.destruction_owner(5),"actor":current.combat.actors[5]}
		if [1,5,6].all(func(id):return current.destruction[id].phase=="retired"):
			finished=true;break
	check(finished and shown.has("explosion"),"Native tumble/explosion/cargo cleanup did not retire all exhausted fighters")
	check(running.snapshot().combat.actors.slice(9).all(func(row):return not row.active and row.actor_mode==5),"Death handling activated untouched reserves")
	check(not running.prepare_selected40_consequences(library,bindings,cat,scenery,equipment,reputation),"A started controller reconfigured consequence ownership")
	check(control.snapshot()==initial and scenery.snapshot()==field and world.snapshot()==generated and equipment.snapshot()==inventory and player.snapshot()==prior_player,"Consequence testing changed an earned input or retained parent owner")
	print("Selected40 native consequences: 13 lifecycle owners, source %d/%d, origin30, primary faction%d; three deaths/one player kill/one NPC kill/no pirate kills; %d ms native cleanup; direct component stimuli"%[data.system_id,data.station_id,primary,elapsed])
	return shown

func render_consequences(library: RefCounted,bindings: RefCounted,art: String,proof: Dictionary) -> void:
	if proof.is_empty():return
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	for phase in proof:
		var owner: RefCounted=proof[phase].death;var state: Dictionary=owner.snapshot();var body: Dictionary=proof[phase].actor
		var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=1;camera.far=30000
		camera.look_at_from_position(state.pose.origin+Vector3(1500,1100,-2100),state.pose.origin)
		var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
		var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
		var effect: Node3D=load("res://src/presentation/npc_death_effect_geometry.gd").new();viewport.add_child(effect)
		if not effect.build(library,visuals,bindings,owner) or not effect.apply_effect(owner,camera.global_transform,PackedByteArray([255,255,255,255]),Vector4(1,1,1,1),1.0):check(false,effect.error);viewport.free();continue
		var ship:=Geometry.new();viewport.add_child(ship)
		if not ship.build(int(body.hull_catalogue_id),library,visuals,bindings):check(false,ship.error);viewport.free();continue
		ship.transform=body.pose;check(ship.apply_selection({"visible":effect.body_visible,"level":0}),ship.error)
		var label:=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",22);viewport.add_child(label)
		label.text="SELECTED 40 | NATIVE CONSEQUENCE COMPONENT\nOriginal Void actor5: %s, retained debris and animation clocks.\nExplicit component lethal input; native accounting and destruction.\nNot a mixed contact, earned mission victory or successor save."%phase
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image();check(image!=null and not image.is_empty(),"Native destruction did not render")
		if not captures.is_empty() and image!=null:check(image.save_png(captures.path_join("selected40-death-%s.png"%phase))==OK,"Could not retain native destruction capture")
		viewport.free()

## Native components from the ACTUAL field continuation. Controlled fire
## requests below test gun mechanics, not an input-earned combat or contact.
func verify_npc_weapons(library: RefCounted,bindings: RefCounted,cat: RefCounted,scenery: RefCounted,player: RefCounted,player_pose: Transform3D) -> Dictionary:
	var world: RefCounted=scenery.world_initialization_owner();var initialized: Dictionary=world.snapshot()
	var factory: RefCounted=world.npc_construction_owner();var original_player: Dictionary=player.snapshot()
	var combat:=Combat.new();var weapons:=NpcWeapons.new()
	if not combat.configure_selected40(bindings,cat,world):check(false,combat.error);return {}
	if not weapons.configure_selected40(bindings,cat,world,combat):check(false,weapons.error);return {}
	var initial:=weapons.snapshot();var bodies:=combat.snapshot();var rules:=Rules.weapon_profile(bindings,factory.snapshot())
	check(initial.selected40.weapon_effects==initialized.weapon_effects and initial.selected40.random_state==initialized.random_state and initial.selected40.input_random_state==initialized.input_random_state,"NPC owner restarted or replaced actual field/cast/effect RNG")
	check(initial.actors.size()==13 and initial.actors[0].projectiles.is_empty() and initial.actors[0].definition.unarmed,"Hidden freighter received a gun or population lost a member")
	check(not weapons.configure_selected40(bindings,cat,world,combat) and weapons.snapshot()==initial,"Reconfiguration replaced live NPC weapon pools")
	check(not combat.configure_selected40(bindings,cat,world) and combat.snapshot()==bodies,"Reconfiguration replaced live NPC bodies")
	var other:=World.new()
	check(other.configure_selected40(bindings,cat,player.loadout(),initialized.selected40_context),other.error)
	check(not other.generate(initialized.input_random_state).is_empty(),other.error)
	var other_combat:=Combat.new();check(other_combat.configure_selected40(bindings,cat,other),other_combat.error)
	check(not NpcWeapons.new().configure_selected40(bindings,cat,world,other_combat),"Same-shaped actors from another initialized world were accepted")
	check(not Guidance.new().configure_selected40(bindings,cat,factory,0),"Parked freighter inherited fighter guidance")
	var target:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":player.loadout().ship_id,
		"pose":player_pose,"active":original_player.active,"hull":original_player.vitals.hull,"targeting_blocked":false,"special_flight":false,"alternate_position":null}
	var stream: Dictionary=initialized.random_state.duplicate();var selectors:=[];var decisions:=[]
	for id in range(1,13):
		var gun: Dictionary=initial.actors[id].projectiles.weapon
		check(gun.item_id==(0 if id<5 else 5) and gun.damage==(4 if id<5 else 3) and gun.interval_ms==520 and gun.lifetime_ms==3000 and gun.speed_units_per_millisecond==16.0 and gun.projectile_capacity==4 and gun.nonplayer_source,"Wrong native rank5/difficulty0.5 NPC weapon: "+str(id))
		check(initial.actors[id].projectiles.elapsed_ms==520 and not initial.actors[id].projectiles.time_ready and initial.actors[id].projectiles.available_slots==4,"Fresh NPC gun bypassed strict interval or capacity")
		var expected: Array=[-1]+(range(5,13) if id<5 else range(0,5))
		check(initial.target_memberships[id]==expected,"Selected40 inherited an earlier Void player-last exception")
		check(combat.refresh_hostility(id),combat.error)
		var guidance:=Guidance.new()
		if not guidance.configure_selected40(bindings,cat,factory,id):check(false,guidance.error);return {}
		var current:=combat.actor_snapshot(id);var before:=guidance.snapshot()
		var targets:=guidance.training_targets(target,combat.actor_snapshots())
		check(targets.map(func(row):return row.actor_id)==expected,"Native targeting changed retained membership order")
		var bad:=target.duplicate(true);bad.binding_id="foreign"
		check(guidance.update(100,current,current.pose,bad,stream,combat.actor_snapshots()).is_empty() and guidance.snapshot()==before,"Invalid target partially committed native selection")
		var decision:=guidance.update(100,current,current.pose,target,stream,combat.actor_snapshots())
		if decision.is_empty():check(false,guidance.error);return {}
		stream=decision.random_state
		check(not decision.fire_requested and decision.activation.is_empty(),"Initial or parked native actor fired or activated reserves")
		check(combat.apply_selected40_guidance(decision),combat.error)
		check(combat.actor_snapshot(id).actor_mode==(1 if id<9 else 5) and combat.actor_snapshot(id).active==(id<9),"Targeting conflated initial fighters and parked reserves")
		if id<5:check(decision.target_kind=="route" and not guidance.snapshot().fire_desired,"Out-of-range initial escort skipped its original patrol")
		selectors.append(guidance);decisions.append(decision)
	check(stream==initialized.random_state,"Initial selection invented draws before its refresh clock")
	# Detached spatial input cases exercise the actual shared selector and aim
	# calculation; neither the earned player nor the real population is moved.
	var trial: RefCounted=combat.fork_for_frame();var escort: Dictionary=trial.actor_snapshot(1)
	var near_enemy: Transform3D=trial.actor_snapshot(5).pose;near_enemy.origin=escort.pose.origin+escort.pose.basis.z*4000
	check(trial.set_pose(5,near_enemy),trial.error)
	var nearby:=target.duplicate(true);nearby.pose=Transform3D(Basis.IDENTITY,escort.pose.origin+escort.pose.basis.z*3000)
	var aim: RefCounted=selectors[0].fork_for_frame()
	var acquired: Dictionary=aim.update(100,escort,escort.pose,nearby,stream,trial.actor_snapshots())
	check(not acquired.is_empty() and acquired.target_kind=="npc" and acquired.target_actor_id==5 and acquired.fire_requested,"Friendly escort did not acquire and aim at its live opposed target")
	var void_actor:=combat.actor_snapshot(5);nearby.pose=Transform3D(Basis.IDENTITY,void_actor.pose.origin+void_actor.pose.basis.z*4000)
	var attack: RefCounted=selectors[4].fork_for_frame()
	var selected: Dictionary=attack.update(100,void_actor,void_actor.pose,nearby,stream,combat.actor_snapshots())
	check(not selected.is_empty() and selected.target_kind=="player" and selected.target_actor_id==-1 and selected.fire_requested,"Hostile Void did not retain player-first acquisition and alignment")
	nearby.targeting_blocked=true
	var suppressed: Dictionary=attack.update(100,void_actor,void_actor.pose,nearby,selected.random_state,combat.actor_snapshots())
	check(not suppressed.is_empty() and not suppressed.fire_requested,"Native targeting suppression did not cancel firing")
	var period:=int(bindings.opening_actors.npc_initialization.guidance.selection_period_ms)
	for tick in int(ceil(float(period)/100.0)):
		for id in range(1,13):
			var actor:=combat.actor_snapshot(id);var guide: RefCounted=selectors[id-1]
			var decision: Dictionary=guide.update(100,actor,actor.pose,target,stream,combat.actor_snapshots())
			if decision.is_empty():check(false,guide.error);return {}
			stream=decision.random_state;check(combat.apply_selected40_guidance(decision),combat.error)
	check(stream!=initialized.random_state,"Timed targeting failed to continue the actual post-allocation RNG")
	var ready:=combat.snapshot()
	var requests: Array=[{"actor_id":5,"target_actor_id":-1,"pose":combat.actor_snapshot(5).pose},{"actor_id":1,"target_actor_id":5,"pose":combat.actor_snapshot(1).pose}]
	check(weapons.fire(combat,[1,5]).is_empty() and weapons.fire_combat_training(combat,requests).is_empty(),"Generic requests bypassed selected40 target ownership")
	check(weapons.fire_selected40(other_combat,player,requests).is_empty() and weapons.snapshot()==initial,"Another native world consumed weapon slots")
	for bad in [{"actor_id":1,"target_actor_id":-1,"pose":requests[1].pose},{"actor_id":1,"target_actor_id":2,"pose":requests[1].pose},{"actor_id":1,"target_actor_id":9,"pose":requests[1].pose},{"actor_id":5,"target_actor_id":0,"pose":requests[0].pose},{"actor_id":0,"target_actor_id":5,"pose":bodies.actors[0].pose},{"actor_id":5,"target_actor_id":-1,"pose":Transform3D.IDENTITY}]:
		check(weapons.fire_selected40(combat,player,[requests[0],bad]).is_empty() and weapons.snapshot()==initial,"Invalid late NPC request partially committed firing")
	var waiting:=weapons.fire_selected40(combat,player,requests)
	check(not waiting.is_empty() and waiting.actors.all(func(row):return not row.outcome.fired and row.outcome.reason=="interval"),"NPC fresh fire did not require strictly more than its interval")
	var visual:=ProjectileVisuals.new()
	var view:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":40,"elapsed_ms":0,"weapons":initial}
	if not visual.configure(bindings,library,view):check(false,visual.error);return {}
	check(visual.snapshot().models.size()==12,"Native NPC projectile visuals omitted armed reserves or added freighter")
	for model in visual.snapshot().models:
		check(model.model_id==(6754 if int(model.key.substr(4))<5 else 6762),"NPC projectile used another faction model")
		var weapon: Dictionary=initial.actors[int(model.key.substr(4))].projectiles.weapon
		check(ProjectileVisuals.model_mapping(bindings,weapon,model.key,true).get("id")== (14602 if int(model.key.substr(4))>=5 else 14600),"NPC impact model differs from its original weapon mapping")
	check(not weapons.advance(1).is_empty(),weapons.error)
	var shot:=weapons.fire_selected40(combat,player,requests)
	if shot.is_empty():check(false,weapons.error);return {}
	check(shot.actors.map(func(row):return row.actor_id)==[1,5] and shot.actors.all(func(row):return row.outcome.fired),"Firing did not use native actor order and real gun allocation")
	for row in shot.actors:check(row.audio_events.size()==1,"Native gun lost its original faction audio cue")
	var parked:=weapons.fire_selected40(combat,player,[{"actor_id":9,"target_actor_id":-1,"pose":combat.actor_snapshot(9).pose}])
	check(not parked.is_empty() and not parked.actors[0].outcome.fired and parked.actors[0].outcome.reason=="permission","Parked reserve launched a projectile")
	check(not weapons.advance(60).is_empty() and visual.advance(61),weapons.error+visual.error)
	var shown:=weapons.snapshot()
	for id in [1,5]:
		var slot: Dictionary=shown.actors[id].projectiles.slots[0]
		check(slot.get("remaining_ms")==2940,"NPC projectile did not advance its native lifetime")
	var fork: RefCounted=weapons.fork_for_frame();check(not fork.advance(100).is_empty() and weapons.snapshot()==shown,"Weapon frame mutated its parent")
	for delta in [-1,0.5,true]:check(weapons.advance(delta).is_empty() and weapons.snapshot()==shown,"Invalid NPC time partially advanced all guns")
	for index in 3:
		check(not weapons.advance(521).is_empty(),weapons.error)
		var fired:=weapons.fire_selected40(combat,player,requests)
		check(not fired.is_empty() and fired.actors.all(func(row):return row.outcome.fired),"Native four-slot pool failed before capacity")
	check(not weapons.advance(521).is_empty(),weapons.error)
	var full:=weapons.fire_selected40(combat,player,requests)
	check(not full.is_empty() and full.actors.all(func(row):return not row.outcome.fired and row.outcome.reason=="capacity"),"NPC gun exceeded its original four-slot pool")
	check(not weapons.advance(3001).is_empty(),weapons.error)
	check(weapons.snapshot().actors[1].projectiles.available_slots==4 and weapons.snapshot().actors[5].projectiles.available_slots==4,"Expired NPC projectiles were not retired")
	check(not combat.begin_contact_pass(stream,true) and combat.normal_hit(5,1).is_empty() and combat.systems_hit(5,1).is_empty(),"Partial group admitted unowned contact consequences")
	check(weapons.evaluate_combat_training_update(player,player_pose,combat,false,1).is_empty() and not combat.supports_weapon_hit(shown.actors[1].projectiles.weapon),"NPC component opened unfinished mixed contacts")
	check(combat.snapshot()==ready and world.snapshot()==initialized and player.snapshot()==original_player,"Gun tests mutated actor pools, initialized world or earned player")
	var fork_combat: RefCounted=combat.fork_for_frame();var changed: Transform3D=ready.actors[1].pose;changed.origin.x+=100
	check(fork_combat.set_pose(1,changed) and combat.snapshot()==ready,"Native actor COW fork modified the parent")
	print("Selected40 NPCs: 12 native guns, player-first targets, actual field/cast/effect RNG; controlled fire requests only; contacts closed")
	var automatic:=verify_automatic_npc(library,bindings,cat,world,player,player_pose)
	return {"weapons":shown,"visual":visual,"combat":ready,"decisions":decisions,"automatic":automatic}

func verify_automatic_npc(library: RefCounted,bindings: RefCounted,cat: RefCounted,world: RefCounted,player: RefCounted,pose: Transform3D) -> Dictionary:
	var control:=NpcControl.new();var guns:=NpcWeapons.new()
	if not control.configure_selected40(bindings,cat,world):check(false,control.error);return {}
	if not guns.configure_selected40(bindings,cat,world,control.combat_owner()):check(false,guns.error);return {}
	var baseline:=control.snapshot();var initial:=guns.snapshot();var original_player: Dictionary=player.snapshot()
	check(baseline.support_state=="selected40_targeting_component" and baseline.random_state==world.snapshot().random_state,"Native actor phase reseeded before targeting")
	check(not control.configure_selected40(bindings,cat,world) and control.snapshot()==baseline,"Reconfiguration replaced live targeting/flight")
	for invalid in [-1,preload("res://src/simulation/frame_clock.gd").simulation_limit(bindings)+1,0.5,true]:
		check(control.evaluate_selected40(guns,invalid,player,pose).is_empty() and control.snapshot()==baseline and guns.snapshot()==initial,"Invalid NPC phase partially committed actors, timers or shots: "+str(invalid))
	check(control.evaluate_selected40(guns,100,Player.new(),pose).is_empty() and control.snapshot()==baseline,"Unconfigured player partially committed targeting")
	check(control.evaluate_selected40(guns,100,player,Transform3D(Basis.from_scale(Vector3(2,1,1)),pose.origin)).is_empty() and control.snapshot()==baseline,"Invalid player transform partially committed targeting")
	var first:=control.evaluate_selected40(guns,100,player,pose);var repeat:=control.evaluate_selected40(guns,100,player,pose)
	if first.is_empty() or repeat.is_empty():check(false,control.error);return {}
	check(first.controller.snapshot()==repeat.controller.snapshot() and first.weapons.snapshot()==repeat.weapons.snapshot(),"The native actor phase is not deterministic from actual initialized RNG")
	check(control.snapshot()==baseline and guns.snapshot()==initial,"A staged automatic frame mutated parent owners")
	check(first.decisions.size()==13 and first.firing.actors.is_empty() and first.random_state==baseline.random_state,"Initial native actor pass fired or drew before its source clocks")
	var animation:=ProjectileVisuals.new()
	if not animation.configure(bindings,library,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":40,"elapsed_ms":0,"weapons":initial}):check(false,animation.error);return {}
	var running: RefCounted=control;var weapons: RefCounted=guns;var elapsed:=0;var pending:={};var captures_by_kind:={};var fired_count:=0
	for frame in 1200:
		var before: Dictionary=running.snapshot();var before_guns: Dictionary=weapons.snapshot()
		var step: Dictionary=running.evaluate_selected40(weapons,100,player,pose)
		if step.is_empty():check(false,running.error);return {}
		check(running.snapshot()==before and weapons.snapshot()==before_guns,"Automatic flight/gun evaluation violated parent isolation")
		running=step.controller;weapons=step.weapons;elapsed+=100
		check(animation.advance(100),animation.error)
		for kind in pending.keys():
			captures_by_kind[kind]={"actor_id":pending[kind],"kind":kind,"combat":step.combat.snapshot(),"weapons":weapons.snapshot(),"visual":animation.fork_for_frame(),"elapsed_ms":elapsed}
			pending.erase(kind)
		for shot in step.firing.actors:
			if not shot.outcome.fired:continue
			fired_count+=1
			var id: int=shot.actor_id;var kind: String="Terran escort" if id<5 else "Void attacker"
			check(step.decisions[id].fire_requested and step.decisions[id].target_actor_id in initial.target_memberships[id],"NPC shot bypassed its actual guidance decision")
			check(id>0 and id<9,"Hidden or parked NPC fired in the automatic phase")
			if not captures_by_kind.has(kind) and not pending.has(kind):pending[kind]=id
		if captures_by_kind.size()==2:break
	check(captures_by_kind.size()==2 and fired_count>=2,"Native source poses, targets and flight did not produce both factions' automatic shots")
	var result: Dictionary=running.snapshot()
	check(result.combat.actors[1].body_pose!=baseline.combat.actors[1].body_pose and result.combat.actors[5].body_pose!=baseline.combat.actors[5].body_pose,"Native fighter motion was not connected to targeting")
	for id in [0,9,10,11,12]:
		check(not result.combat.actors[id].active and result.combat.actors[id].actor_mode==5 and result.combat.actors[id].body_pose==baseline.combat.actors[id].body_pose,"Automatic targeting moved or activated a parked script actor")
	check(player.snapshot()==original_player and control.snapshot()==baseline and guns.snapshot()==initial,"Automatic firing changed the earned player or initial frame owners")
	check(not result.has("defeat_status") and not result.has("contract_result"),"NPC phase invented a completed mission result")
	print("Selected40 automatic targeting/flight: %d ms; %d real NPC shots; %d faction captures; no contacts or mission result"%[elapsed,fired_count,captures_by_kind.size()])
	return captures_by_kind

func render_npc_weapons(library: RefCounted,bindings: RefCounted,art: String,preview: Dictionary) -> void:
	if preview.is_empty():return
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=1;camera.far=30000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
	var label:=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",22);viewport.add_child(label)
	var geometry: Node3D=load("res://src/presentation/projectile_geometry.gd").new();viewport.add_child(geometry)
	var automatic: Array=preview.automatic.values()
	if automatic.is_empty():check(false,"Automatic NPC firing produced no native render cases");viewport.free();return
	if not geometry.build(automatic[0].visual,library,visuals,bindings):check(false,geometry.error);viewport.free();return
	for shot_case in automatic:
		var id: int=shot_case.actor_id
		var actor: Dictionary=shot_case.combat.actors[id];var pose: Transform3D=actor.pose
		var ship:=Geometry.new();viewport.add_child(ship)
		if not ship.build(int(actor.hull_catalogue_id),library,visuals,bindings):check(false,ship.error);ship.free();continue
		ship.transform=pose;check(ship.apply_selection({"visible":true,"level":0}),ship.error)
		camera.look_at_from_position(pose.origin+pose.basis*Vector3(1800,1200,-1600),pose.origin+pose.basis.z*750)
		var scene:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":40,"elapsed_ms":shot_case.elapsed_ms,"weapons":shot_case.weapons,"projectile_visuals":shot_case.visual.snapshot()}
		var draw: Dictionary=geometry.prepare_world(shot_case.visual,scene,camera.global_transform)
		if draw.is_empty():check(false,geometry.error);ship.free();continue
		geometry.commit_world(draw)
		check(geometry.guns[id-1].slots[0].visible,"Native NPC projectile was not drawn")
		label.text="SELECTED 40  |  AUTOMATIC NATIVE NPC FIRING\n%s actor %d, original hull %d and projectile; 100 ms after launch.\nActual field -> cast -> weapon RNG -> targeting -> flight -> firing.\nNative AI decision, not a forced fire request. This targeting-only capture is not mission admission."%[shot_case.kind,id,actor.hull_catalogue_id]
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		check(image!=null and not image.is_empty(),"NPC component did not render")
		if not captures.is_empty() and image!=null:check(image.save_png(captures.path_join("selected40-npc-%d.png"%id))==OK,"Could not retain native NPC capture")
		ship.free()
	viewport.free()

func render_scenery(library: RefCounted,bindings: RefCounted,art: String,proof: Dictionary) -> void:
	if proof.is_empty():return
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=10;camera.far=500000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
	var geometry:=SceneryGeometry.new();viewport.add_child(geometry)
	if not geometry.build(proof.initial,library,visuals,bindings,"high",true):check(false,geometry.error);viewport.free();return
	check(geometry.objects.size()==proof.initial.objects.size(),"GPU scenery dropped original asteroids")
	var title:=Label.new();title.position=Vector2(24,20);title.add_theme_font_size_override("font_size",22);viewport.add_child(title)
	for closeup in [false,true]:
		var field: Dictionary=proof.advanced if closeup else proof.initial
		check(geometry.apply_state(field) and geometry.apply_activity(field.bodies),geometry.error)
		var center: Vector3=field.center
		if closeup:
			var body: Dictionary=field.bodies.objects[0];var radius: float=body.model_radius*body.scale
			camera.look_at_from_position(body.position+Vector3(2.0,1.3,-3.0)*radius,body.position)
		else:camera.look_at_from_position(center+Vector3(55000,30000,-80000),center)
		# Native source LOD follows the inspection camera without changing a body.
		var detail:=SceneryDetail.new()
		check(detail.configure(bindings,field,true) and detail.refresh(camera.position,1.0),detail.error)
		check(geometry.apply_detail(detail.snapshot()),geometry.error)
		title.text="SELECTED 40  |  NATIVE ASTEROID SCENERY\n%d original models, bodies and lifecycle owners  |  system %d / station %d\n%s\nProspective component only; saved player remains at Néhma. No admitted mission flight."%[field.objects.size(),field.system_id,field.station_id,"Shared rotation after 3 seconds; original mesh close-up." if closeup else "Station-seeded count/center, independent placement stream, then all 13 actors."]
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		check(image!=null and not image.is_empty(),"The native asteroid field did not render")
		if not captures.is_empty() and image!=null:
			DirAccess.make_dir_recursive_absolute(captures)
			check(image.save_png(captures.path_join("selected40-scenery-%s.png"%("close" if closeup else "field")))==OK,"Could not retain native scenery capture")
	viewport.free()

func verify_bodies(bindings: RefCounted,cat: RefCounted,seed: Dictionary,context: Dictionary) -> Array:
	var factory:=Factory.new()
	if not factory.configure_selected40(bindings,cat,seed,context):check(false,factory.error);return []
	var packet:=factory.generate({"state":42})
	if packet.is_empty():check(false,factory.error);return []
	for id in [-1,13,1.5]:check(not Body.new().configure_selected40(bindings,cat,factory,id),"Invalid body ID accepted")
	var result:=[]
	var control: Dictionary=bindings.combat_training_control
	var standing: Dictionary=bindings.mido_travel.free_lifecycle.standing
	for id in 13:
		var body:=Body.new()
		if not body.configure_selected40(bindings,cat,factory,id):check(false,body.error);return []
		var before:=body.snapshot();var row: Dictionary=packet.actors[id]
		var active: bool=id>0 and id<9
		var base: int=int(control.rank_base)+int(control.rank_multiplier)*context.rank+int(control.cursor_multiplier)*40
		if id==0:base*=int(bindings.mido_travel.alioth_attack.population.freighter_combat.hull_multiplier)
		var ordinary:=int(float(base)*(1.0+float(context.difficulty)+float(control.difficulty_offset)))
		var expected: int=1800+5*context.rank if id==0 else ordinary
		check(before.vitals=={"hull":expected,"armor":0,"shield":0.0} and before.max_hull==expected and before.factory_hull==ordinary and before.hull_percent==100,"Current/maximum/factory hull diverged for actor "+str(id))
		check(before.campaign_cursor==40 and before.origin_station_id==30 and before.origin_system_id==2 and not before.has("station_id") and not before.has("system_id"),"Body invented a selected world location")
		check(before.active==active and before.actor_mode==(0 if active else 5) and before.targeting_blocked==not active,"Shared initialization erased authored parked states")
		check(before.body_pose==row.body_pose and before.pose==row.statistics_pose and before.model_draw_enabled==(id!=0),"Native body pose/visibility differs from the retained construction")
		check(before.friendly==(id<5) and before.permanent_friendly==(id<5) and before.hostile==(id>=5) and before.script_hostile==(id>=5),"Native systems initialization erased authored allegiance")
		check(before.has("name_text_id")== (id in [0,2]),"Native body lost source names")
		if id in [0,2]:check(before.name_text_id==row.name_text_id,"Native name selected another edition")
		var systems:=Systems.systems(bindings,context.rank,1 if id==0 else 0)
		check(before.systems.capacity==systems.capacity and before.systems.recovery_ms==systems.recovery_ms and before.systems.integrity==systems.capacity,"Body lost rank/subtype systems statistics")
		var collision:=body.collision_context()
		check(collision.eligible==active and collision.path==("point_geometry" if id==0 else "bounds"),"Inactive hidden/reserve actor became a projectile contact")
		if id==0:check(before.point_boxes==[
			{"offset":Vector3(0,-73,123),"half_extents":Vector3(1500,1430,5215)},
			{"offset":Vector3(0,-280,-4257),"half_extents":Vector3(1735,907.5,1100)},
			{"offset":Vector3(0,-770,-4279),"half_extents":Vector3(2610,340,1135)}] and before.point_box_index==0,"Terran body borrowed another freighter's collision boxes")
		for axis in [-100,100]:
			for forced in [false,true]:
				check(body.apply_free_hostility({"axes":[axis,axis],"override":-1},forced,standing),body.error)
				check(body.snapshot().hostile==(id>=5) and body.snapshot().friendly==(id<5),"Faction projection erased authored friendship/hostility")
		before=body.snapshot()
		check(body.normal_hit(-1).is_empty() and body.snapshot()==before,"Rejected hull damage partially mutated the body")
		check(body.systems_hit(-1).is_empty() and body.snapshot()==before,"Rejected systems damage partially mutated the body")
		var branch: RefCounted=body.fork_for_frame()
		var hit: Dictionary=branch.normal_hit(17)
		check(not hit.is_empty() and hit.accepted==active and branch.snapshot().vitals.hull==expected-(17 if active else 0),"Shared normal-hit owner changed selected40 activity gates")
		var emp: Dictionary=branch.systems_hit(systems.capacity)
		check(not emp.is_empty() and emp.accepted==active and branch.snapshot().systems_hit_serial==(1 if active else 0),"Shared EMP owner changed selected40 activity gates")
		if active:
			check(not branch.snapshot().systems_disabled and branch.advance_systems(1) and branch.snapshot().systems_disabled,"EMP fabricated an early radio projection or failed to project during the actor pass")
			check(branch.advance_systems(systems.recovery_ms-1) and branch.snapshot().systems.integrity==systems.capacity and branch.snapshot().systems_disabled,"Exactly full integrity cleared the source's delayed disabled flag")
			var recovery_step:=int(ceilf(float(systems.recovery_ms)/float(systems.capacity)))+1
			check(branch.advance_systems(recovery_step) and not branch.snapshot().systems_disabled,"Native integer-threshold systems recovery did not restore the fighter")
		check(body.snapshot()==before and factory.snapshot()==packet,"A body fork changed its parent or retained construction")
		result.append(before)
	return result

## Independent mission-level sequencing over already-verified shared samplers.
func ordered_factory(bindings: RefCounted,cat: RefCounted,seed: Dictionary,context: Dictionary,value: int) -> Dictionary:
	var factory:=Factory.new()
	if not factory.configure_selected40(bindings,cat,seed,context):check(false,factory.error);return {}
	var random:=Random.new();random.restore({"state":value})
	var rows:=[]
	for id in 13:
		var hull: int=13 if id==0 else Factory._select_hull(random,0,bindings.early_contracts.encounter_construction.hulls) if id<5 else 8
		var origin:=Vector3(-20000,-3000,200000) if id>=5 and id<9 else Vector3.ZERO
		var sample:=factory._sample_actor(id,origin,random,id==0)
		if sample.is_empty():check(false,factory.error);return {}
		var row: Dictionary=sample.actor;var at: Vector3=row.factory_position
		if id==0:
			for cargo in row.discarded_cargo:cargo.quantity=maxi(int(cargo.quantity)*(2+random.next_int(4)),8+random.next_int(5))
			at=Vector3(-9999999,-9999999,-9999999)
		elif id<5:
			row.route=row.route.duplicate(true);row.route.waypoints=[Vector3(-20000,-3000,35000),Vector3(-20000,-3000,200000)]
			row.route.candidate_indices=[];row.route.index=0;row.route.loop=false;row.route.completed=false
		elif id>=9:at=Vector3(-500000,-500000,-500000)
		row.cargo=row.discarded_cargo;row.hull_catalogue_id=hull;row.body_pose=Transform3D(Basis.IDENTITY,at)
		rows.append(row)
	return {"actors":rows,"random_state":random.snapshot()}

func render_cast(library: RefCounted,bindings: RefCounted,art: String,state: Dictionary) -> void:
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=10;camera.far=500000
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
	var title:=Label.new();title.position=Vector2(24,20);title.add_theme_font_size_override("font_size",22);viewport.add_child(title)
	for id in [1,5,0]:
		var row: Dictionary=state.actors[id];var ship:=Geometry.new();viewport.add_child(ship)
		var ready: bool=ship.build_population_assembly(row.assembly,library,visuals,bindings) if id==0 else ship.build(int(row.hull_catalogue_id),library,visuals,bindings)
		check(ready,ship.error)
		if not ready:ship.free();continue
		var native: Dictionary=state.native_bodies[id]
		ship.transform=native.body_pose;check(ship.apply_selection({"visible":true,"level":0}),ship.error)
		var at: Vector3=row.body_pose.origin
		camera.size=10000 if id==0 else 2000
		camera.look_at_from_position(at+Vector3(14000,10000,-18000),at)
		title.text="SELECTED 40  |  NATIVE BODY / ORIGINAL MODEL CHECK\n"+({0:"Hidden freighter inspected in isolation; gameplay remains hidden.",1:"Friendly escort; original generated hull and source patrol.",5:"Active Void attacker; four further attackers remain parked."}[id])+"\nHull %d/%d  |  Systems %d  |  Active: %s\nThis is not an admitted flight or successor save."%[native.vitals.hull,native.max_hull,native.systems.capacity,str(native.active)]
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		check(image!=null and not image.is_empty(),"The selected40 model did not render")
		if not captures.is_empty() and image!=null:
			DirAccess.make_dir_recursive_absolute(captures)
			check(image.save_png(captures.path_join("selected40-model-%d.png"%id))==OK,"Could not retain selected40 model capture")
		ship.free()
	viewport.free()

func verify_entry(bindings: RefCounted,cat: RefCounted,station: RefCounted,context: Dictionary) -> Dictionary:
	var career: RefCounted=station.contract_owner()
	var source: RefCounted=career.void_source_owner()
	if source==null:check(false,"The real station archive lost its Void source");return {}
	var retained: Dictionary=source.snapshot();var before: Dictionary=station.snapshot()
	var random:=Random.new();check(random.restore({"state":42}),random.error)
	var rng_before:=random.snapshot();var entry:=Entry.new()
	var ordinary:=Transform3D(Basis(Vector3.UP,0.4),Vector3(10,10,10000))
	var portal:=Transform3D(Basis(Vector3.UP,-0.3),Vector3(15000,24000,33000))
	check(entry.player_pose(ordinary)==null and entry.portal_pose(portal)==null,"An unprepared component applied placement")
	if not entry.prepare(bindings,cat,source,context,context.origin_station_id,"station_departure",random):check(false,entry.error);return {}
	var departure:=entry.snapshot()
	check(departure.selected40==(retained.source_station_id==context.origin_station_id) and not departure.special_placement and entry.player_pose(ordinary)==ordinary,"Néhma departure invented an incoming special placement")
	var incoming:=Entry.new()
	if not incoming.prepare(bindings,cat,source,context,retained.source_station_id,"travel_arrival",random):check(false,incoming.error);return {}
	var selected:=incoming.snapshot()
	check(selected.selected40 and selected.world_type==3 and selected.mission_kind==161 and selected.mission_story,"The real Void source did not select the authored world")
	check(selected.station_id==retained.source_station_id and selected.system_id==retained.source_system_id and selected.station_id>=0 and selected.pending_target_station_id==-1,"Selected world location was confused with the pending mission sentinel")
	check(selected.source_before==retained and selected.source_after==retained and selected.source_event=="skipped" and selected.random_state==rng_before,"Special source selection rerolled its own source or consumed RNG")
	var pose: Transform3D=incoming.player_pose(ordinary)
	check(pose.origin==Vector3(-105000,0,80000) and pose.basis.z.is_equal_approx(Vector3.RIGHT),"Incoming player did not receive the original position and quarter-turn heading")
	var portal_pose: Transform3D=incoming.portal_pose(portal)
	check(portal_pose.origin==Vector3(-20000,-3000,200000) and portal_pose.basis==portal.basis,"Authored portal placement changed its retained orientation")
	for row in cat.tables.stations:
		var id: int=int(row.id)
		check(entry.prepare(bindings,cat,source,context,id,"travel_arrival",random),entry.error)
		var observation:=entry.snapshot();var is_source: bool=id==retained.source_station_id
		check(observation.selected40==is_source and observation.mission_story==is_source and observation.mission_kind==(161 if is_source else -1),"Special selection leaked to ordinary location "+str(id))
		check(observation.station_id==id and observation.system_id==int(row.system_id) and observation.world_type==3 and observation.pending_target_station_id==-1,"World selection lost the actual catalogue location")
		check(is_source or entry.player_pose(ordinary)==ordinary and entry.portal_pose(portal)==portal,"A nonselected world received selected40 placement")
		check(source.snapshot()==retained and random.snapshot()==rng_before,"Prospective selection mutated the retained source or RNG")
	var stable:=entry.snapshot()
	check(not entry.prepare(bindings,cat,source,context,retained.source_station_id,"station_departure",random) and entry.snapshot()==stable,"A Néhma station departure relocated the player to the distant source")
	for id in [-1,-10,cat.tables.stations.size(),30.0,true]:
		check(not entry.prepare(bindings,cat,source,context,id,"travel_arrival",random) and entry.snapshot()==stable,"Invalid/sentinel location partially committed entry")
	for event in ["", "acknowledgement", "portal_contact"]:
		check(not entry.prepare(bindings,cat,source,context,retained.source_station_id,event,random) and entry.snapshot()==stable,"An unsupported event fabricated the placement transition")
	check(not entry.prepare(bindings,cat,VoidSource.new(),context,30,"station_departure",random) and entry.snapshot()==stable,"An unconfigured source replaced the prepared entry")
	check(not entry.prepare(bindings,cat,source,context,30,"station_departure",Random.new()) and entry.snapshot()==stable,"An unseeded selection partially committed entry")
	var bad_context:=context.duplicate(true);bad_context.binding_id="foreign"
	check(not entry.prepare(bindings,cat,source,bad_context,30,"station_departure",random) and entry.snapshot()==stable,"Entry accepted foreign content identity")
	for malformed in [Transform3D(Basis.from_scale(Vector3(2,1,1)),Vector3.ZERO),Transform3D(Basis.IDENTITY,Vector3(NAN,0,0))]:
		check(entry.player_pose(malformed)==null and entry.portal_pose(malformed)==null and entry.snapshot()==stable,"Malformed placement mutated the prepared selection")
	var detached: RefCounted=incoming.fork();var detached_state: Dictionary=detached.snapshot()
	detached_state.source_after.eligible_selection_count=10
	check(detached.snapshot()==selected and incoming.snapshot()==selected,"Returned placement/source observations alias live state")
	# Detached source-location parameter case, not a changed career or save.
	var launch_source: RefCounted=source.fork();var parameters:=retained.duplicate(true)
	parameters.source_station_id=context.origin_station_id;parameters.source_system_id=context.origin_system_id
	check(launch_source.restore(parameters),launch_source.error)
	check(detached.prepare(bindings,cat,launch_source,context,30,"station_departure",random),detached.error)
	check(detached.snapshot().selected40 and detached.player_pose(ordinary)==ordinary and detached.portal_pose(portal).origin==Vector3(-20000,-3000,200000),"Portal relocation was incorrectly gated by incoming player placement")
	# Separately labelled counter-threshold parameter case. A reroll may move
	# the warning source to the newly chosen station, but selection used the OLD
	# source. Never retroactively substitute the story cast into that arrival.
	var threshold_source: RefCounted=source.fork();var threshold:=retained.duplicate(true)
	threshold.eligible_selection_count=int(bindings.mido_travel.void_access.source.reroll.threshold)-1
	check(threshold_source.restore(threshold),threshold_source.error)
	var witnessed:=false
	for number in range(1,65):
		var stream:=Random.new();check(stream.restore({"state":number}),stream.error)
		var proposal: Dictionary=threshold_source.select(40,context.origin_station_id,-1,false,stream)
		if proposal.is_empty():check(false,threshold_source.error);break
		var chosen: int=proposal.source.source_station_id
		if chosen==retained.source_station_id:continue
		var probe:=Entry.new()
		check(probe.prepare(bindings,cat,threshold_source,context,chosen,"travel_arrival",stream),probe.error)
		var observation:=probe.snapshot()
		check(not observation.selected40 and not observation.mission_story and observation.mission_kind==-1,"Reroll retroactively selected a story mission")
		check(observation.source_event=="rerolled" and observation.source_after==proposal.source and observation.source_after.source_station_id==chosen and observation.source_after.eligible_selection_count==0,"Threshold selection did not retain the generated source proposal")
		check(observation.random_state==proposal.random_state and observation.random_state!=stream.snapshot() and stream.snapshot()=={"state":number},"Reroll committed or discarded the caller's random stream")
		check(threshold_source.snapshot()==threshold and probe.player_pose(ordinary)==ordinary and probe.portal_pose(portal)==portal,"A newly rerolled source inherited the current encounter's special transforms")
		witnessed=true;break
	check(witnessed,"No source-reroll ordering boundary was exercised")
	check(station.snapshot()==before and source.snapshot()==retained and random.snapshot()==rng_before,"Entry tests changed the actual acknowledged career")
	print("Selected40 actual retained source: system %d, station %d, counter %d; Néhma selects40=%s; proposals only"%[retained.source_system_id,retained.source_station_id,retained.eligible_selection_count,str(departure.selected40)])
	return {"source":retained,"departure_pose":ordinary,"arrival_pose":pose,"selection":selected}

## These are retained-origin player components and detached damage/cache cases,
## not a completed journey, an activated encounter or a new saved career.
func verify_player(bindings: RefCounted,cat: RefCounted,station: RefCounted,context: Dictionary,preview: Dictionary) -> Dictionary:
	var original: Dictionary=station.snapshot();var equipment: RefCounted=station.equipment_owner()
	if equipment==null:check(false,"The exact station lost its native equipment owner");return {}
	var owned: Dictionary=equipment.snapshot();var seed: Dictionary=owned.loadout
	var cache: Dictionary=original.player_cache.duplicate(true)
	var factory:=Factory.new()
	if not factory.configure_selected40(bindings,cat,seed,context):check(false,factory.error);return {}
	var packet:=factory.generate({"state":42})
	if packet.is_empty():check(false,factory.error);return {}
	var entry:=PlayerEntry.new()
	check(entry.configure(bindings,40,30,true,int(seed.ship_id)) and entry.equipped_entry.station_id==30 and entry.equipped_entry.system_id==2,"Native ordinary40 player entry moved the canonical origin")
	check(not entry.configure_selected40(bindings,{},int(seed.ship_id)),"Selected player entry accepted a missing source context")
	if not entry.configure_selected40(bindings,context,int(seed.ship_id)):check(false,entry.error);return {}
	check(entry.uses_equipment and entry.restores_local and not entry.is_departure and not entry.is_arrival,"Retained pools became a fresh launch or tutorial arrival")
	check(entry.equipped_entry.station_id==30 and entry.equipped_entry.system_id==2 and entry.equipped_entry.campaign_cursor==40,"Pool entry relabelled the actual origin")
	var player:=Player.new()
	check(not player.configure_selected40(bindings,cat,equipment,Factory.new(),cache) and player.snapshot().is_empty(),"An ungenerated population initialized a player")
	if not player.configure_selected40(bindings,cat,equipment,factory,cache):check(false,player.error);return {}
	var before:=player.snapshot();var loadout:=player.loadout();var expected:=seed.duplicate(true);expected.campaign_cursor=40
	check(loadout==expected and loadout.slots==seed.slots and loadout.equipment_ids==[2,42,57,91,64],"Player replaced installed equipment, slots or quantities")
	check(before.scope=="selected40_retained_player_component" and before.selected40_context==context and before.campaign_cursor==40,"Player lost the explicit component boundary")
	check(not before.has("station_id") and not before.has("system_id") and not before.has("mission"),"Player statistics fabricated a selected world or mission result")
	check(before.vitals=={"hull":95,"armor":38,"shield":0.0} and before.gamma==100.0,"The actual earned player was repaired or replaced")
	check(player.cache_snapshot()==cache and Cache.matches(player.cache_snapshot(),loadout,40),"Initial player cache reported full capacities instead of restored pools")
	check(before.capacities==Player.resolve_capacities(cat.tables.items,seed.equipment_ids,bindings.opening_actors.player_initialization),"Player capacities differ from actual catalogue equipment")
	check(before.active and before.damage_allowed and before.is_player,"Common player initialization lost native permission defaults")
	check(not player.configure_selected40(bindings,cat,equipment,factory,cache) and player.snapshot()==before and player.cache_snapshot()==cache,"Reconfiguration discarded existing live player state")
	var detached:=player.snapshot();detached.vitals.hull=1;detached.selected40_context.rank=20
	var detached_loadout:=player.loadout();detached_loadout.slots.clear()
	var detached_cache:=player.cache_snapshot();detached_cache.values.hull=1
	check(player.snapshot()==before and player.loadout()==loadout and player.cache_snapshot()==cache,"Returned player observations alias retained owners")
	for mutation in [["base_content_id","foreign"],["binding_id","foreign"],["campaign_cursor",39],["campaign_cursor",40.0],["station_id",preview.source.source_station_id],["station_id",-1],["system_id",-1],["ship_id",1],["equipment_ids",[]],["extra",true]]:
		var invalid:=cache.duplicate(true);invalid[mutation[0]]=mutation[1]
		var candidate:=Player.new()
		check(not candidate.configure_selected40(bindings,cat,equipment,factory,invalid) and candidate.snapshot().is_empty(),"Player accepted or partially committed an altered origin cache: "+str(mutation[0]))
	for missing in ["values","equipment_ids","campaign_cursor"]:
		var invalid:=cache.duplicate(true);invalid.erase(missing)
		check(not Player.new().configure_selected40(bindings,cat,equipment,factory,invalid),"Player accepted missing cache "+missing)
	for key in Cache.POOL_KEYS:
		var invalid:=cache.duplicate(true);invalid.values[key]=float(invalid.values[key])
		check(not Player.new().configure_selected40(bindings,cat,equipment,factory,invalid),"Player accepted a non-native cached "+key)
	for hull in [0,-1]:
		var invalid:=cache.duplicate(true);invalid.values.hull=hull
		check(not Player.new().configure_selected40(bindings,cat,equipment,factory,invalid),"Player resurrected dead or reset origin hull")
	for key in ["ship_id","station_id","system_id","equipment_ids"]:
		var wrong:=seed.duplicate(true);wrong[key]={"ship_id":1,"station_id":-1,"system_id":-1,"equipment_ids":[]}[key]
		check(Rules.retained_player_context(bindings,packet,wrong).is_empty(),"Construction accepted mismatched retained "+key)
	for key in ["training_inventory_released","prototype_drill_replaced","cargo_cache_stale"]:
		var corrupt: RefCounted=equipment.fork();corrupt._state[key]=key=="cargo_cache_stale"
		check(not Player.new().configure_selected40(bindings,cat,corrupt,factory,cache),"Player accepted invalid inventory lifecycle "+key)
	var corrupt_slots: RefCounted=equipment.fork();corrupt_slots._state.loadout.slots[0].item_id=22
	check(not Player.new().configure_selected40(bindings,cat,corrupt_slots,factory,cache),"Player accepted slots inconsistent with installed item order")
	# Native hit/recharge/repair transactions on forks. No hit is attributed to
	# a selected40 NPC until the full weapon/targeting owner is implemented.
	var damaged: Dictionary={}
	for amount in [0,17,38,55,133,1000]:
		var branch: RefCounted=player.fork_for_frame();var pools:=Vitals.new()
		check(pools.configure(95,38,0),pools.error)
		var expected_hit:=pools.normal_hit(amount,true);var actual: Dictionary=branch.normal_hit(amount)
		check(actual==expected_hit and branch.snapshot().vitals==pools.snapshot(),"Selected player diverged from native normal-hit accounting")
		check(branch.loadout()==loadout and branch.snapshot().max_hull==before.max_hull,"Player damage changed inventory or hull capacity")
		var position: Transform3D=preview.arrival_pose
		var contact: Dictionary=branch.collision_context(position)
		check(not contact.is_empty() and contact.eligible==(branch.snapshot().vitals.hull>0) and contact.center==position.origin,"Player bounds lost the explicit pose or live/dead gate")
		if amount==55:damaged=branch.snapshot()
		check(player.snapshot()==before and player.cache_snapshot()==cache,"A damage fork changed its retained parent")
	var branch: RefCounted=player.fork_for_frame()
	for value in [-1,1.0,NAN]:
		check(branch.normal_hit(value).is_empty() and branch.snapshot()==before,"Malformed normal damage partially changed player pools")
		check(branch.advance_recharge(value).is_empty() and branch.snapshot()==before,"Malformed recharge partially changed player state")
		check(branch.advance_repair(value).is_empty() and branch.snapshot()==before,"Malformed repair partially changed player state")
	check(branch.set_permissions(true,false) and not branch.normal_hit(1000).accepted and branch.snapshot().vitals==before.vitals,"Damage permission was ignored")
	check(branch.set_permissions(false,true) and not branch.normal_hit(1000).accepted and not branch.collision_context(preview.arrival_pose).eligible,"Inactive player received damage or remained a target")
	check(branch.set_permissions(true,true),branch.error)
	check(not branch.advance_recharge(1000).is_empty() and not branch.advance_repair(1000).is_empty(),branch.error)
	check(branch.snapshot().vitals==before.vitals and branch.loadout()==loadout,"Unequipped shield/repair device regenerated resources")
	check(not branch.supports_weapon_hit({"item_id":0}) and branch.snapshot().vitals==before.vitals,"Player component invented unfinished NPC weapon/contact authority")
	# Shared restoration edge cases, explicitly NOT changes to the actual save.
	var capacities: Dictionary=before.capacities
	var parameter_cache:=cache.duplicate(true)
	parameter_cache.values={"hull":before.max_hull+100,"armor":capacities.armor+50,"shield":capacities.shield+50,"gamma":37}
	var parameter_player:=Player.new()
	if not parameter_player.configure_selected40(bindings,cat,equipment,factory,parameter_cache):check(false,parameter_player.error);return {}
	var parameter_state:=parameter_player.snapshot();var refreshed:=parameter_player.cache_snapshot()
	check(parameter_state.vitals.hull==parameter_cache.values.hull and parameter_state.max_hull==parameter_cache.values.hull,"Cached hull did not raise current and maximum together")
	check(parameter_state.vitals.armor==capacities.armor and parameter_state.vitals.shield==capacities.shield and parameter_state.gamma==100.0,"Shared armor/shield clamping or normal-space gamma reset changed")
	check(refreshed.values=={"hull":parameter_state.vitals.hull,"armor":capacities.armor,"shield":capacities.shield,"gamma":100},"Restored cache retained unclamped or stale player values")
	var secondary:=Secondary.new()
	if not secondary.configure(bindings,cat,loadout):check(false,secondary.error);return {}
	var ammo:=secondary.snapshot()
	check(ammo.guns.size()==1 and ammo.guns[0].equipment.item_id==42 and ammo.guns[0].ammunition==3 and ammo.launches==0,"EMP ownership replaced the three remaining paid rounds")
	check(ammo.loadout==loadout and ammo.initial_loadout==loadout and secondary.reconcile_loadout(loadout)==loadout,"Secondary construction reconstructed unrelated equipment")
	check(branch.retain_secondary_ammunition(secondary) and branch.loadout()==loadout and branch.snapshot().vitals==before.vitals,"Unspent native ammunition retention altered surviving pools")
	check(not branch.retain_secondary_ammunition(Secondary.new()) and branch.loadout()==loadout,"An unconfigured secondary owner changed player ammunition")
	var ammo_view: Dictionary=secondary.snapshot();ammo_view.guns[0].ammunition=99;ammo_view.loadout.slots.clear()
	check(secondary.snapshot()==ammo,"Returned secondary observations changed the actual ammo owner")
	check(equipment.snapshot()==owned and factory.snapshot()==packet and station.snapshot()==original,"Player/equipment component changed the saved career, job or cast")
	check(original.arrival_player.campaign_cursor==39 and original.player_cache.campaign_cursor==40 and original.contracts.passengers==3,"Player initialization conflated live39 with cache40 or consumed the passenger job")
	print("Selected40 retained player: ",JSON.stringify({"origin":loadout.station_id,"cursor":before.campaign_cursor,"living_saved_cursor":original.arrival_player.campaign_cursor,"vitals":before.vitals,"gamma":before.gamma,"equipment":loadout.slots,"emp_rounds":ammo.guns[0].ammunition,"scope":before.scope}))
	return {"initial":before,"damaged":damaged,"ammunition":int(ammo.guns[0].ammunition)}

## Real mounted firing on a detached native owner, not an enemy hit, an earned
## flight or a career transition. The complete target/contact path stays closed.
func verify_primaries(library: RefCounted,bindings: RefCounted,cat: RefCounted,station: RefCounted,context: Dictionary,preview: Dictionary) -> Dictionary:
	var primaries_type: Script=load("res://src/simulation/primary_weapons.gd")
	var mounts: RefCounted=load("res://src/content/weapon_mounts.gd").new()
	if not mounts.open(library,cat):check(false,mounts.error);return {}
	var saved: Dictionary=station.snapshot();var equipment: RefCounted=station.equipment_owner()
	var owned: Dictionary=equipment.snapshot();var factory:=Factory.new()
	if not factory.configure_selected40(bindings,cat,owned.loadout,context):check(false,factory.error);return {}
	var packet:=factory.generate({"state":42})
	if packet.is_empty():check(false,factory.error);return {}
	var player:=Player.new()
	if not player.configure_selected40(bindings,cat,equipment,factory,saved.player_cache):check(false,player.error);return {}
	var retained:=player.snapshot();var loadout:=player.loadout()
	var guns: RefCounted=primaries_type.new()
	var ordinary_guns: RefCounted=primaries_type.new()
	check(ordinary_guns.configure(bindings,cat,mounts,loadout),ordinary_guns.error)
	var ordinary_equipment: Dictionary=ordinary_guns.snapshot().get("loadout",{})
	for key in ["base_content_id","binding_id","ship_id","slots","equipment_ids","campaign_cursor"]:
		check(ordinary_equipment.get(key)==loadout[key],"Ordinary40 primaries changed the retained equipment field "+key)
	# Ordinary navigation is now implemented. Keep the selected-native owner
	# fresh so malformed selected constructors cannot hide behind prior guns.
	for invalid in [null,Player.new(),Factory.new()]:
		check(not guns.configure_selected40(bindings,cat,mounts,invalid,factory) and guns.snapshot().is_empty(),"Primaries accepted a missing or non-player owner")
	check(not guns.configure_selected40(bindings,cat,mounts,player,Factory.new()),"Primaries accepted an ungenerated cast")
	for invalid in [null,RefCounted.new()]:
		check(not guns.configure_selected40(invalid,cat,mounts,player,factory) and guns.snapshot().is_empty(),"Primaries accepted a missing or non-native binding owner")
		check(not guns.configure_selected40(bindings,invalid,mounts,player,factory) and guns.snapshot().is_empty(),"Primaries accepted a missing or non-native catalogue owner")
	check(not guns.configure_selected40(bindings,cat,RefCounted.new(),player,factory),"Primaries accepted a non-native attachment owner")
	var mismatched:=Factory.new();var other_context:=context.duplicate(true);other_context.rank=(other_context.rank+1)%21
	if mismatched.configure_selected40(bindings,cat,owned.loadout,other_context):
		check(not mismatched.generate({"state":42}).is_empty(),mismatched.error)
		check(not guns.configure_selected40(bindings,cat,mounts,player,mismatched),"Primaries accepted a cast from another retained rank context")
	else:check(false,mismatched.error)
	check(not guns.configure_selected40(bindings,cat,load("res://src/content/weapon_mounts.gd").new(),player,factory),"Primaries accepted unopened mount data")
	if not guns.configure_selected40(bindings,cat,mounts,player,factory):check(false,guns.error);return {}
	var initial: Dictionary=guns.snapshot()
	check(initial.scope=="selected40_retained_primary_component" and initial.selected40_context==context,"Primaries lost their bounded origin context")
	check(initial.guns.size()==1 and initial.guns[0].equipment.item_id==2 and initial.guns[0].equipment.quantity==1,"Primaries replaced the actual installed gun")
	check(initial.loadout.equipment_ids==loadout.equipment_ids and initial.loadout.slots==loadout.slots and initial.loadout.campaign_cursor==40,"Primary construction changed equipment order or cursor")
	check(not initial.has("station_id") and not initial.has("system_id") and not initial.has("mission"),"Primary construction invented a physical world or mission")
	var gun: Dictionary=initial.guns[0];var weapon: Dictionary=gun.projectiles.weapon
	var resolver: RefCounted=load("res://src/simulation/weapon_loadout.gd").new()
	if not resolver.configure(bindings,cat,bindings.base_content_id):check(false,resolver.error);return {}
	var resolved: Dictionary=resolver.resolve(2,loadout.equipment_ids)
	for key in ["item_id","category","kind","damage","interval_ms","lifetime_ms","projectile_capacity","speed_units_per_millisecond","ordinary_hit_policy","collision_bounds"]:
		check(weapon.get(key)==resolved.get(key),"Primary changed source-resolved "+key)
	check(gun.mount==mounts.resolve(loadout.ship_id,0,gun.equipment.slot),"Primary used an item ID instead of its catalogue mount slot")
	check(not gun.contact_pass_evaluated and gun.last_contact_target==null,"A gun was initialized with a fabricated hit")
	check(not guns.configure_selected40(bindings,cat,mounts,player,factory) and guns.snapshot()==initial,"Repeated setup discarded live gun state")
	var pose: Transform3D=preview.arrival_pose
	var random:={"state":42}
	var first: Dictionary=guns.fire(pose,true,random)
	check(not first.is_empty() and not first.weapons[0].result.fired and first.weapons[0].result.reason=="interval" and guns.snapshot()==initial,"Initial equality bypassed the source strict interval")
	if guns.advance(1).is_empty():check(false,guns.error);return {}
	var ready: Dictionary=guns.snapshot()
	var refused: Dictionary=guns.fire(pose,false,random)
	check(not refused.is_empty() and not refused.weapons[0].result.fired and refused.weapons[0].result.reason=="permission" and guns.snapshot()==ready,"Rejected permission advanced a gun or emitted a shot")
	for bad_pose in [null,Vector3.ZERO,Transform3D(Basis.IDENTITY,Vector3(NAN,0,0))]:
		check(guns.fire(bad_pose,true,random).is_empty() and guns.snapshot()==ready,"Invalid firing pose partially committed primaries")
	check(guns.fire(pose,1,random).is_empty() and guns.snapshot()==ready,"Non-boolean firing permission was accepted")
	check(guns.fire(pose,true,{}).is_empty() and guns.snapshot()==ready,"Invalid shared random state advanced a gun")
	var fired: Dictionary=guns.fire(pose,true,random)
	if fired.is_empty():check(false,guns.error);return {}
	check(fired.weapons[0].result.fired and fired.random_state==random,"The actual gun failed to fire or consumed unrelated random draws")
	var shot: Dictionary=fired.weapons[0].result.projectile
	var muzzle: Vector3=pose*(gun.mount.position+Vector3(0,0,100))
	check(shot.position.is_equal_approx(muzzle) and shot.previous_position==shot.position,"Shot did not start at the transformed source muzzle")
	check(shot.velocity.is_equal_approx(pose.basis.z.normalized()*float(weapon.speed_units_per_millisecond)),"Shot used camera-negative Z or changed source speed")
	check(shot.get("up")==pose.basis.y,"Primary did not retain its firing up axis")
	check(shot.remaining_ms==weapon.lifetime_ms and shot.slot==0 and shot.id>0,"Primary lifetime, slot or native handle was replaced")
	check(fired.weapons[0].get("audio_events",[]).size()==1 and not gun.audio.is_empty(),"A successful shot omitted its configured source audio cue")
	var active: Dictionary=guns.snapshot();var branch: RefCounted=guns.fork_state()
	for bad_time in [-1,1.0,NAN]:
		check(branch.advance(bad_time).is_empty() and branch.snapshot()==active,"Invalid time partially changed the live projectile")
	var motion: Dictionary=branch.advance(40)
	if motion.is_empty():check(false,branch.error);return {}
	var moved: Dictionary=branch.snapshot().guns[0].projectiles.slots[0]
	check(moved.previous_position==shot.position and moved.position.is_equal_approx(shot.position+shot.velocity*40.0) and moved.remaining_ms==shot.remaining_ms-40,"Native projectile motion or lifetime diverged")
	check(moved.get("up")==shot.get("up") and guns.snapshot()==active,"Motion lost the firing basis or changed the parent branch")
	check(branch.evaluate_npc_update(null,range(13),40).is_empty() and branch.snapshot().guns[0].projectiles.slots[0]==moved,"Player gun admitted unfinished NPC targeting")
	check(branch.evaluate_opening_update(null,null,null,40).is_empty(),"Player gun admitted unfinished mixed scenery contacts")
	var secondary:=Secondary.new()
	if not secondary.configure(bindings,cat,loadout):check(false,secondary.error);return {}
	var before_ammo: Dictionary=branch.snapshot()
	check(branch.retain_secondary_ammunition(secondary) and branch.snapshot()==before_ammo,"Unspent EMP retention reset primary clocks, handles or context")
	check(secondary.snapshot().guns[0].ammunition==3 and secondary.snapshot().launches==0,"Primary fire consumed paid EMP ammunition")
	check(not branch.retain_secondary_ammunition(Secondary.new()) and branch.snapshot()==before_ammo,"Invalid secondary ownership modified live primaries")
	var expired: RefCounted=guns.fork_state()
	check(not expired.advance(int(weapon.lifetime_ms)).is_empty(),expired.error)
	var end: Dictionary=expired.snapshot().guns[0].projectiles
	check(end.slots[0]!=null and end.slots[0].remaining_ms==0 and end.available_slots==weapon.projectile_capacity,"Lifetime expiry skipped the retained final frame")
	check(not expired.advance(0).is_empty() and expired.snapshot().guns[0].projectiles.slots[0]==null,"Next zero-time update did not clear the expired projectile")
	check(not expired.retire(gun.mount_id,shot.id),"A cleared projectile handle remained valid")
	var interval: RefCounted=guns.fork_state()
	check(not interval.advance(int(weapon.interval_ms)).is_empty(),interval.error)
	check(not interval.fire(pose,true).weapons[0].result.fired,"Equal firing interval was treated as ready")
	check(not interval.advance(1).is_empty(),interval.error)
	var again: Dictionary=interval.fire(pose,true)
	check(not again.is_empty() and again.weapons[0].result.fired and again.weapons[0].result.projectile.id>shot.id,"Strictly elapsed interval did not create the next native handle")
	var reset: RefCounted=guns.fork_state()
	check(reset.reset_fire_intervals() and reset.snapshot().guns[0].projectiles.elapsed_ms==0 and reset.snapshot().guns[0].projectiles.slots==active.guns[0].projectiles.slots,"Interval reset discarded in-flight projectiles")
	reset.discard_flying()
	check(reset.snapshot().guns[0].projectiles.slots.all(func(slot):return slot==null) and guns.snapshot()==active,"Discard crossed the fork boundary")
	var detached: Dictionary=guns.snapshot();detached.guns[0].projectiles.slots.clear();detached.selected40_context.rank=20
	check(guns.snapshot()==active,"Returned gun observations alias live state")
	var visual: RefCounted=load("res://src/simulation/projectile_visual_state.gd").new()
	var envelope:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":0,"primaries":initial,"scope":initial.scope}
	if not visual.configure(bindings,library,envelope):check(false,visual.error);return {}
	check(visual.snapshot().models.size()==1 and visual.snapshot().models[0].captured_up,"Selected primary presentation lost its native launch basis")
	check(visual.snapshot().models[0].model_id==6756,"Primary presentation substituted another weapon's projectile")
	check(load("res://src/simulation/projectile_visual_state.gd").model_mapping(bindings,weapon,"npc:5",false).is_empty(),"Player visual work admitted unfinished NPC projectile models")
	var mapping: Script=load("res://src/simulation/projectile_visual_state.gd")
	check(mapping.model_mapping(bindings,weapon,"player:0",true).get("id")==14600,"Primary impact did not resolve its original source model")
	for key in ["player:invalid","player:-1","npc:0"]:
		check(mapping.model_mapping(bindings,weapon,key,false).is_empty(),"Selected primary visual accepted malformed or foreign handle "+key)
	for mutation in [["campaign_cursor",40.0],["nonplayer_source",true]]:
		var foreign:=weapon.duplicate(true);foreign[mutation[0]]=mutation[1]
		check(mapping.model_mapping(bindings,foreign,"player:0",false).is_empty(),"Selected primary visual accepted an invalid source field "+mutation[0])
	var replacement: RefCounted=guns.fork_state();replacement.clear()
	check(replacement.configure_selected40(bindings,cat,mounts,player,factory),replacement.error)
	check(replacement.snapshot().guns[0].mount_id>gun.mount_id and not replacement.retire(gun.mount_id,shot.id),"Explicit reset reused a live primary mount handle")
	check(equipment.snapshot()==owned and factory.snapshot()==packet and player.snapshot()==retained and station.snapshot()==saved,"Weapon component modified the cast, player, job or earned station")
	print("Selected40 live primary: ",JSON.stringify({"item":weapon.item_id,"damage":weapon.damage,"interval_ms":weapon.interval_ms,"lifetime_ms":weapon.lifetime_ms,"speed":weapon.speed_units_per_millisecond,"mount":gun.mount.position,"shots":1,"emp_rounds":3,"contact_scope":"closed","saved_origin":loadout.station_id}))
	var prepared: RefCounted=primaries_type.new()
	if not prepared.configure_selected40(bindings,cat,mounts,player,factory):check(false,prepared.error);return {}
	return {"owner":prepared,"pose":pose,"player":retained,"visual":visual,"ship_id":loadout.ship_id}

func render_primaries(library: RefCounted,bindings: RefCounted,art: String,preview: Dictionary) -> void:
	if preview.is_empty():return
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=1;camera.far=20000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
	var label:=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",22);viewport.add_child(label)
	var ship:=Geometry.new();viewport.add_child(ship)
	if not ship.build(int(preview.ship_id),library,visuals,bindings):check(false,ship.error);viewport.free();return
	check(ship.apply_selection({"visible":true,"level":0}),ship.error)
	for rolled in [false,true]:
		var owner: RefCounted=preview.owner.fork_state();var animation: RefCounted=preview.visual.fork_for_frame()
		var pose: Transform3D=preview.pose
		if rolled:pose.basis=pose.basis*Basis(Vector3.FORWARD,0.7)
		ship.transform=pose
		camera.look_at_from_position(pose.origin+pose.basis*Vector3(2200,1400,-1800),pose.origin+pose.basis.z*800)
		var geometry: Node3D=load("res://src/presentation/projectile_geometry.gd").new();viewport.add_child(geometry)
		if not geometry.build(animation,library,visuals,bindings):check(false,geometry.error);geometry.free();continue
		check(not owner.advance(1).is_empty() and animation.advance(1),owner.error+animation.error)
		var fired: Dictionary=owner.fire(pose,true,{"state":42})
		if fired.is_empty() or not fired.weapons[0].result.fired:check(false,owner.error);geometry.free();continue
		for age in [0,60]:
			if age>0:check(not owner.advance(age).is_empty() and animation.advance(age),owner.error+animation.error)
			var scene:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":animation.snapshot().elapsed_ms,"primaries":owner.snapshot(),"projectile_visuals":animation.snapshot(),"scope":"selected40_retained_primary_component"}
			var draw: Dictionary=geometry.prepare_world(animation,scene,camera.global_transform)
			if draw.is_empty():check(false,geometry.error);continue
			geometry.commit_world(draw)
			check(geometry.guns[0].slots[0].visible,"A real native primary shot was not drawn")
			label.text="SELECTED 40  |  NATIVE PRIMARY FIRING COMPONENT\nActual ship and installed primary 2; original animated projectile model.\nLive shot age %d ms; rolled firing basis: %s; retained hull95 / armor38 / EMP42 x3.\nNo enemy hit, completed journey or selected40 mission admission is claimed."%[age,str(rolled)]
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			check(image!=null and not image.is_empty(),"Native primary component did not render")
			if not captures.is_empty() and image!=null:check(image.save_png(captures.path_join("selected40-primary-%s-%d.png"%["rolled" if rolled else "level",age]))==OK,"Could not retain native primary capture")
		geometry.free()
	viewport.free()

func render_entry(library: RefCounted,bindings: RefCounted,art: String,preview: Dictionary) -> void:
	if not preview.has("selection"):return
	var visuals:=Visuals.new()
	if not visuals.open(art,library.manifest):check(false,visuals.error);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.near=1;camera.far=100000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);viewport.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.7;viewport.add_child(environment)
	var title:=Label.new();title.position=Vector2(24,20);title.add_theme_font_size_override("font_size",22);viewport.add_child(title)
	var ship:=Geometry.new();viewport.add_child(ship)
	check(ship.build(int(preview.ship_id),library,visuals,bindings),ship.error)
	for kind in ["departure","arrival"]:
		var pose: Transform3D=preview[kind+"_pose"]
		ship.transform=pose;check(ship.apply_selection({"visible":true,"level":0}),ship.error)
		camera.look_at_from_position(pose.origin+Vector3(900,650,-1100),pose.origin)
		title.text="SELECTED 40  |  NATIVE ENTRY PLACEMENT COMPONENT\nRetained player ship %d; proposed %s pose %s\nVoid source: system %d / station %d; pending mission target: -1\nOriginal model and native transform; NOT an earned arrival or admitted flight."%[preview.ship_id,kind,str(pose.origin),preview.source.source_system_id,preview.source.source_station_id]
		if not preview.get("player",{}).is_empty():
			var native: Dictionary=preview.player.initial
			title.text+="\nActual origin pools: hull %d / armor %d / shield %d / gamma %d; EMP42 x%d\nEquipment stays at Néhma30; saved living world39 and career/cache40 remain separate."%[native.vitals.hull,native.vitals.armor,native.vitals.shield,native.gamma,preview.player.ammunition]
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		check(image!=null and not image.is_empty(),"The entry component did not render")
		if not captures.is_empty() and image!=null:check(image.save_png(captures.path_join("selected40-entry-"+kind+".png"))==OK,"Could not retain entry placement capture")
	if not preview.get("player",{}).get("damaged",{}).is_empty():
		var native: Dictionary=preview.player.damaged
		title.text="SELECTED 40  |  NATIVE PLAYER DAMAGE COMPONENT\nDetached 55-point normal-hit test: hull %d / armor %d / shield %d\nOriginal ship and installed equipment; three paid EMP rounds remain unchanged.\nParent stays hull95 / armor38 / world39 / cache40 at Néhma30.\nNo NPC shot, journey, mission result or successor save is claimed."%[native.vitals.hull,native.vitals.armor,native.vitals.shield]
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		check(image!=null and not image.is_empty(),"The player damage component did not render")
		if not captures.is_empty() and image!=null:check(image.save_png(captures.path_join("selected40-player-damage.png"))==OK,"Could not retain player damage capture")
	viewport.free()

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
