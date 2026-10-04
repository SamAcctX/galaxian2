extends SceneTree
## Detached construction inputs, not earned campaign progress.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
const Bakka=preload("res://src/content/bakka_contest_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Navigation=preload("res://src/content/free_navigation_definitions.gd")
const FreeFlight=preload("res://src/content/free_flight_definitions.gd")
const PlayerEntry=preload("res://src/content/player_entry_definitions.gd")
const FlightCache=preload("res://src/simulation/flight_player_cache.gd")
const SceneryPopulation=preload("res://src/simulation/scenery_population.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const FlightConstruction=preload("res://src/simulation/first_flight_construction.gd")
const Incoming=preload("res://src/simulation/local_arrival_environment.gd")
const Bodies=preload("res://src/content/scenery_body_resources.gd")
const Effects=preload("res://src/content/scenery_effect_resources.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const FlightFrame=preload("res://src/simulation/first_flight_frame.gd")
const Equipment=preload("res://src/simulation/station_equipment.gd")
const ComponentEquipment=preload("res://tests/fixtures/bakka_equipment.gd")
const Categories=preload("res://src/simulation/opening_loadout.gd")
const Career=preload("res://src/simulation/opening_handoff.gd")
const Reputation=preload("res://src/simulation/faction_reputation.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Route=preload("res://src/simulation/npc_route.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const MISSION={"kind":12,"station_id":27,"reward":0,"bonus":0,"source_parameter":0}
var checks:=0
var failures:=0
var populations:=0
# Retained native fixture for the scene/session diagnostic; never an earned save.
var selected_construction: RefCounted
var selected_arrival_construction: RefCounted

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected content, bindings and visuals")
	else:verify(args)
	print("Bakka population: %d checks; %d failures; %d independent populations"%[checks,failures,populations])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var available:=Bakka.available(bindings)
	check(Navigation.destination_supported(bindings,36,MISSION,27)==(available and FreeFlight.Campaign.BakkaReturn.available(bindings)),"B'akka navigation ignored its complete encounter/return capability")
	verify_entry_admission(bindings,cat,library,available)
	if not available:
		check(FlightFrame.OrdinaryFlight.docking(bindings,37).is_empty(),"An earlier pack enabled B'akka return docking")
		check(not Factory.new().configure_bakka(bindings,cat,{},{},Vector3.ZERO),"An earlier pack enabled Bakka")
		check(not Route.new().configure_bakka_generated(bindings,0),"An earlier pack enabled story routes")
		return
	var source: Dictionary=bindings.mido_travel.duplicate(true)
	var header: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("bindings.json")))
	verify_definitions(bindings,source,header)
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":36,"station_id":27,"system_id":5,"mission_kind":12,"mission_story":true,"mission_completed":false,"rank":7,"difficulty":0.5}
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":27,"system_id":5,"ship_id":0,"equipment_ids":[90,81]}
	verify_refusals(bindings,cat,seed,context)
	var file:=FileAccess.open(OS.get_environment("GOF2_BAKKA_VECTORS"),FileAccess.READ)
	if file==null or file.get_length()>2*1024*1024:check(false,"Supply independent Bakka vectors");return
	var vectors: Variant=JSON.parse_string(file.get_as_text())
	if not vectors is Array or vectors.size()!=10:check(false,"Incomplete independent vectors");return
	for rank in [0,7,20]:
		for difficulty in [0.5,1.0]:
			context.rank=rank;context.difficulty=difficulty
			for vector in vectors:verify_vector(bindings,cat,seed,context,vector)
	check(bindings.mido_travel==source and seed.equipment_ids==[90,81],"Construction mutated source or retained inputs")
	check(populations==60,"The full rank/difficulty/seed matrix did not run")

func verify_entry_admission(bindings: RefCounted,cat: RefCounted,library: RefCounted,available: bool) -> void:
	var flight:=FreeFlight.flight(bindings,27,36)
	check((not flight.is_empty())==available,"B'akka target flight admission ignored its contest capability")
	if available:check(flight.station_id==27 and flight.system_id==5 and flight.campaign_cursor==36,"B'akka target flight changed its authored location")
	var entry:=PlayerEntry.new()
	var configured:=entry.configure(bindings,36,27,false,0)
	check(configured==available,"B'akka target player entry ignored its contest capability")
	var restored:=PlayerEntry.new()
	check(restored.configure(bindings,36,27,true,0)==available,"B'akka target restore entry ignored its contest capability")
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":27,"system_id":5,"ship_id":0,"equipment_ids":[90,81]}
	var cache:={}
	if configured:
		cache=entry.player_cache(bindings.opening_actors.player_initialization.flight_cache,seed,100,{"armor":100,"shield":100},true)
	check((not cache.is_empty())==available,"B'akka target cache ignored its admitted player entry")
	if available:check(FlightCache.matches(cache,seed,36),"B'akka target cache changed the retained ship identity")
	var scenery:=SceneryPopulation.new()
	if not scenery.configure(bindings):check(false,scenery.error);return
	var selected:=scenery.for_departure(27,{"companions_empty":true,"location_match":false,"special_placement":false},36)
	check((not selected.is_empty())==available,"B'akka target scenery ignored its contest capability")
	if available:
		check(selected.station_id==27 and selected.campaign_cursor==36 and selected.center is Vector3,"B'akka target scenery changed its ordinary source center")
		verify_composition(bindings,cat,library)

func composition_seed(bindings: RefCounted) -> Dictionary:
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":27,"system_id":5,"ship_id":0,"equipment_ids":[22,86,81,55]}

func verify_composition(bindings: RefCounted,cat: RefCounted,library: RefCounted) -> void:
	var context={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":36,"station_id":27,"system_id":5,"mission_kind":12,"mission_story":true,"mission_completed":false,"rank":0,"difficulty":0.5}
	var seed:=composition_seed(bindings)
	var equipment: RefCounted=component_owner(bindings,cat,seed)
	if equipment==null:return
	var held: Dictionary=equipment.snapshot();var loadout: Dictionary=held.loadout
	var entry:=PlayerEntry.new()
	if not entry.configure(bindings,36,27,false,int(loadout.ship_id)):check(false,entry.error);return
	var parameters: Dictionary=bindings.opening_actors.player_initialization
	var capacities: Dictionary=Player.resolve_capacities(cat.tables.items,loadout.equipment_ids,parameters)
	var repair: Dictionary=parameters.repair
	var hull:=Player.resolve_ship_hull(cat.tables.ships[int(loadout.ship_id)].fields[int(repair.base_hull_field)],repair.initial_upgrades,repair)
	var cache:=entry.player_cache(parameters.flight_cache,loadout,hull,capacities,false)
	if cache.is_empty():check(false,"Cannot build B'akka target cache");return
	var conditions={"companions_empty":true,"location_match":false,"special_placement":false}
	var scenery:=Scenery.new()
	if not scenery.configure_bakka(bindings,cat,equipment,context,Vector3(10,10,10000),conditions,123):check(false,scenery.error);return
	var field: Dictionary=scenery.snapshot();var population: RefCounted=scenery.world_initialization_owner().npc_construction_owner()
	check(field.world_initialization.bakka_context==context and field.departure_population.campaign_cursor==36,"B'akka scenery lost its selected contest world")
	var player:=Player.new()
	if not player.configure_bakka(bindings,cat,equipment,population,cache):check(false,player.error);return
	check(player.snapshot().bakka_context==context and player.cache_snapshot()==cache,"B'akka player lost its selected context or surviving cache")
	var progress: Dictionary=Career.calculate_progress(bindings.opening_handoff,36,0,0,0)
	if progress.is_empty():check(false,"Cannot build deterministic B'akka career progress");return
	progress.reputation=Reputation.initial(bindings);progress.debris_destroyed=0;progress.capital_ship_kills=0
	context.rank=progress.rank
	var bodies:=Bodies.new();var effects:=Effects.new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var prepared:=FlightConstruction.new()
	if not prepared.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},4096,123,true,bodies,effects,cache,29):check(false,prepared.error);return
	var world: Dictionary=prepared.snapshot()
	check(world.bakka_context==context and world.campaign_cursor==36 and world.station_id==27 and world.system_id==5,"Selected B'akka construction lost contest identity")
	check(world.departure.bakka_context==context and world.scenery.world_initialization.bakka_context==context,"Selected B'akka construction fell back to ordinary free traffic")
	check(prepared.player_owner().cache_snapshot()==cache and prepared.equipment_owner().snapshot()==held,"Selected B'akka construction changed retained player pools or inventory")
	var encounter:=Encounter.new()
	if not encounter.configure_bakka(bindings,cat,library,prepared):check(false,encounter.error);return
	var encounter_state: Dictionary=encounter.snapshot()
	check(encounter_state.campaign_cursor==36 and encounter_state.controller.support_state=="bakka_combat" and encounter_state.combat.actors.size()==8,"Live B'akka encounter did not retain its fixed contest population")
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,cat,library,prepared,"F",0.5,Vector2i(1280,720),false,false,"Q","Space","Tab"):check(false,frame.error);return
	var frame_state: Dictionary=frame.snapshot()
	check(frame_state.campaign_cursor==36 and frame_state.encounter.controller.support_state=="bakka_combat" and frame_state.actors.size()==8,"B'akka target construction did not enter the native live flight frame")
	check(frame_state.mining_objective.get("phase")== "collecting" and not frame_state.combat_objective_satisfied and frame.prepare_station().is_empty(),"Unfinished B'akka contest produced a station arrival")
	verify_retained_career(bindings,cat,library,prepared,bodies,effects)

func verify_retained_career(bindings: RefCounted,cat: RefCounted,library: RefCounted,prepared: RefCounted,bodies: RefCounted,effects: RefCounted) -> void:
	# These are explicit ledger component inputs, not an earned save or proof of
	# travel. Never relabel a saved career to supply the isolated contest pack.
	var world: Dictionary=prepared.snapshot();var equipment: RefCounted=prepared.equipment_owner()
	var context: Dictionary=world.bakka_context;var progress: Dictionary=world.departure.progress
	var cache: Dictionary=prepared.player_owner().cache_snapshot();var owned: Dictionary=equipment.snapshot()
	var source:=Contracts.new()
	source._rules=bindings.early_contracts;source._progress_rules=bindings.opening_handoff;source._catalogues=cat
	source._state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"campaign_cursor":36,"station_id":29,"rank":progress.rank,"reputation":progress.reputation.duplicate(true),
		"difficulty":context.difficulty,"progress":progress.duplicate(true),"credits":12345,"passengers":2,
		"mission":{"kind":11,"station_id":99,"reward":321,"bonus":0,"source_parameter":2},
		"active_offer_id":4,"accepted_contact":{"station_id":29,"contact_id":4},
		"offers":{4:{"consumed":true}},"population":{"station_id":29},
		"completed_side_missions":4,"delivery_statistics":{"cargo":1,"passengers":0},
		"travel_statistics":{"jumpgates_used":3},"pending_result":{},"result_serial":2}
	# Selected-world history is another component input. It is generated by
	# native location owners, not imported from or relabelled as an earned save.
	var history=load("res://tests/fixtures/sahi_location_history.gd").new()
	var locations: RefCounted=history.create(bindings,cat,library,[29,27],{"campaign_cursor":36,"rank":progress.rank,"reputation":progress.reputation})
	if locations==null:check(false,history.error);return
	source._lounges=locations
	var initial: Dictionary=source.snapshot()
	check(not source.advance_bakka_story(bindings,progress) and source.snapshot()==initial,"B'akka story advanced before target-world ownership")
	for mutation in [["base_content_id","foreign"],["binding_id","foreign"],["campaign_cursor",35],["station_id",30],["rank",20],["difficulty",1.0],["pending_result",{"retained":true}]]:
		var rejected: RefCounted=source.fork();rejected._state[mutation[0]]=mutation[1]
		var before: Dictionary=rejected.snapshot()
		check(not rejected.rebase_bakka_target(bindings,equipment,context,progress) and rejected.snapshot()==before,"B'akka transfer accepted or mutated invalid career: "+mutation[0])
	for field in ["_flight","_pending_flight"]:
		var rejected: RefCounted=source.fork();rejected.set(field,{"retained":true})
		var before: Dictionary=rejected.snapshot();var pending: Dictionary=rejected._pending_flight.duplicate(true)
		check(not rejected.rebase_bakka_target(bindings,equipment,context,progress) and rejected.snapshot()==before and rejected._pending_flight==pending,"B'akka transfer discarded unresolved flight ownership: "+field)
	for mutation in [["binding_id","foreign"],["station_id",29],["system_id",15]]:
		var wrong: RefCounted=equipment.fork();wrong._state.loadout[mutation[0]]=mutation[1]
		var rejected: RefCounted=source.fork()
		check(not rejected.rebase_bakka_target(bindings,wrong,context,progress) and rejected.snapshot()==initial,"B'akka transfer accepted another inventory: "+mutation[0])
	var changed_progress:=progress.duplicate(true);changed_progress.player_kills+=1
	check(not source.rebase_bakka_target(bindings,equipment,context,changed_progress) and source.snapshot()==initial,"B'akka target manufactured flight progress")
	var target:=FlightConstruction.new()
	check(not target.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},4096,123,true,bodies,effects,cache,29,RefCounted.new()) and target.snapshot().is_empty(),"B'akka construction accepted a nonnative career")
	check(not target.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},-1,123,true,bodies,effects,cache,29,source) and target.snapshot().is_empty() and source.snapshot()==initial,"Failed world preparation committed a staged career transfer")
	if not target.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},4096,123,true,bodies,effects,cache,29,source):check(false,target.error);return
	selected_construction=target
	var career: RefCounted=target.contract_owner();var expected:=initial.duplicate(true)
	expected.station_id=27;expected.offers={};expected.erase("population");expected.location_generation_pending=true
	check(career!=null and career.snapshot()==expected and target.snapshot().departure.contracts==expected,"B'akka world, departure packet and retained career disagree")
	check(equipment.snapshot()==owned and source.snapshot()==initial and prepared.snapshot()==world,"B'akka preparation mutated its retained inputs")
	verify_incoming_composition(bindings,cat,library,source,target,bodies,effects)
	if failures:return
	check(not career.rebase_bakka_target(bindings,equipment,context,progress) and career.snapshot()==expected,"B'akka target rebased twice")
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,cat,library,target,"F",0.5,Vector2i(1280,720),false,false,"Q","Space","Tab"):check(false,frame.error);return
	check(frame.snapshot().campaign_cursor==36 and frame.prepare_station().is_empty(),"Retained B'akka career exposed an unfinished station arrival")
	verify_result_transaction(bindings,frame,cat,library)
	var combat_progress:=progress.duplicate(true)
	combat_progress.merge(Career.calculate_progress(bindings.opening_handoff,36,4,4,0),true)
	var corrupted:=combat_progress.duplicate(true);corrupted.rank_score+=1
	check(not career.advance_bakka_story(bindings,corrupted) and career.snapshot()==expected,"B'akka success accepted inconsistent career counters")
	var unresolved: RefCounted=career.fork();unresolved._state.pending_result={"retained":true}
	var unresolved_before: Dictionary=unresolved.snapshot()
	check(not unresolved.advance_bakka_story(bindings,combat_progress) and unresolved.snapshot()==unresolved_before,"B'akka success discarded a pending side-job result")
	if not career.advance_bakka_story(bindings,combat_progress):check(false,career.error);return
	var completed:=expected.duplicate(true);completed.campaign_cursor=37
	completed.progress=combat_progress.duplicate(true)
	completed.progress.merge(Career.calculate_progress(bindings.opening_handoff,37,4,4,0),true)
	completed.rank=completed.progress.rank
	check(career.snapshot()==completed,"B'akka career step changed the wallet, independent job, statistics or earned counters")
	check(not career.advance_bakka_story(bindings,combat_progress) and career.snapshot()==completed,"B'akka success advanced the campaign twice")
	check(target.contract_owner().snapshot()==expected and source.snapshot()==initial,"Detached success changed the live flight or prerequisite career")

func verify_incoming_composition(bindings: RefCounted,cat: RefCounted,library: RefCounted,source: RefCounted,prepared: RefCounted,bodies: RefCounted,effects: RefCounted) -> void:
	# Generated native history supplies this component arrival, never an earned
	# journey or a caller-authored player position. Preserve the launch fixture.
	var original: Dictionary=prepared.snapshot();var initial: Dictionary=source.snapshot()
	var equipment: RefCounted=prepared.equipment_owner();var owned: Dictionary=equipment.snapshot()
	var context: Dictionary=original.bakka_context;var progress: Dictionary=original.departure.progress
	var cache: Dictionary=prepared.player_owner().cache_snapshot()
	var incoming:=Incoming.new()
	if not incoming.configure(bindings,cat,27,source.location_owner(),36):check(false,incoming.error);return
	var arrival: Dictionary=incoming.snapshot();var target:=FlightConstruction.new()
	check(not target.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},4096,123,true,bodies,effects,cache,29,source,RefCounted.new()) and target.snapshot().is_empty(),"Selected incoming world accepted a nonnative arrival")
	check(not target.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},4096,123,true,bodies,effects,cache,29,null,incoming) and target.snapshot().is_empty(),"Selected incoming world discarded the retained location owner")
	if not target.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},4096,123,true,bodies,effects,cache,29,source,incoming):check(false,target.error);return
	var state: Dictionary=target.snapshot();var expected_pose: Transform3D=incoming.player_pose(original.player_pose.basis)
	check(state.player_pose==expected_pose and state.player_pose.origin!=original.player_pose.origin,"Selected incoming world reused launch placement instead of native arrival")
	check(state.departure.arrival_environment==arrival and state.bakka_context.player_position==expected_pose.origin and state.departure.bakka_context==state.bakka_context,"Incoming packet, encounter and player placement disagree")
	var before_rival: Vector3=original.scenery.world_initialization.npc_construction.actors[0].body_pose.origin-original.player_pose.origin
	var after_rival: Vector3=state.scenery.world_initialization.npc_construction.actors[0].body_pose.origin-state.player_pose.origin
	check(after_rival.is_equal_approx(before_rival) and state.random_state==original.random_state,"Incoming placement changed the rival's source offset or random draws")
	check(target.player_owner().cache_snapshot()==cache and target.contract_owner().snapshot()==prepared.contract_owner().snapshot(),"Incoming placement changed the ship pools or career")
	for mutation in [["binding_id","foreign"],["campaign_cursor",35],["station_id",29],["system_id",15],["location_order",[27,29]]]:
		var wrong:=Incoming.new();wrong._state=arrival.duplicate(true);wrong._state[mutation[0]]=mutation[1]
		check(not target.prepare_bakka_selected(bindings,cat,equipment,context,progress,{},4096,123,true,bodies,effects,cache,29,source,wrong) and target.snapshot()==state,"Rejected incoming placement changed the prepared world: "+mutation[0])
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,cat,library,target,"F",0.5,Vector2i(1280,720),false,false,"Q","Space","Tab"):check(false,frame.error);return
	check(frame.snapshot().player_pose==expected_pose and frame.snapshot().actors.size()==8 and frame.prepare_station().is_empty(),"Incoming world lost its native frame or completed an unplayed contest")
	check(source.snapshot()==initial and equipment.snapshot()==owned and prepared.snapshot()==original and incoming.snapshot()==arrival,"Selected incoming construction mutated its retained inputs")
	selected_arrival_construction=target
	verify_dispatched_incoming(bindings,cat,library,source,prepared,bodies,effects,incoming)

func verify_dispatched_incoming(bindings: RefCounted,cat: RefCounted,library: RefCounted,source: RefCounted,prepared: RefCounted,bodies: RefCounted,effects: RefCounted,incoming: RefCounted) -> void:
	# A declared component delivery exercises the normal arrival ownership path.
	# This fixture is not an earned journey, and navigation must remain closed.
	var equipment: RefCounted=prepared.equipment_owner();var owned: Dictionary=equipment.snapshot()
	var career: RefCounted=source.fork()
	career._state.mission={"kind":11,"station_id":29,"reward":321,"bonus":0,"source_parameter":2,"story":false,"difficulty":1,"quantity":2}
	career._state.accepted_contact={"station_id":29,"contact_id":4,"offer_id":4,"offer":{"mission":career._state.mission.duplicate(true)}}
	if not career.rebase_station(equipment,bindings):check(false,career.error);return
	var before: Dictionary=career.snapshot();var cache: Dictionary=prepared.player_owner().cache_snapshot()
	var dispatched:=FlightConstruction.new()
	if not dispatched._prepare_free_owned(bindings,cat,equipment,career,MISSION,{},4096,123,true,bodies,effects,cache,incoming,29):check(false,"Ordinary B'akka incoming dispatch: "+dispatched.error);return
	var state: Dictionary=dispatched.snapshot()
	check(state.has("bakka_context") and not state.departure.has("free_context") and state.scenery.world_initialization.npc_construction.actors.size()==8,"Ordinary arrival replaced the contest with random traffic")
	check(dispatched.contract_owner().snapshot()==before and state.departure.contracts==before,"Ordinary arrival relocated twice or changed its wallet, passengers or independent job")
	check(dispatched.player_owner().cache_snapshot()==cache and state.player_pose==selected_arrival_construction.snapshot().player_pose,"Ordinary arrival changed the incoming pose or retained ship pools")
	check(career.snapshot()==before and equipment.snapshot()==owned,"Ordinary arrival mutated its retained input owners")
	check(Bakka.selected(bindings,36,MISSION,27) and not Bakka.selected(bindings,35,MISSION,27) and not Bakka.selected(bindings,36.0,MISSION,27) and not Bakka.selected(bindings,36,MISSION,29),"Contest selection admitted another chapter or location")
	for arrival_owner in [null,RefCounted.new()]:
		check(not dispatched._prepare_free_owned(bindings,cat,equipment,career,MISSION,{},4096,123,true,bodies,effects,cache,arrival_owner,29) and dispatched.snapshot()==state,"Rejected arrival changed the prepared world or admitted a station departure")
	for field in ["kind","station_id","reward","source_parameter"]:
		var changed:=MISSION.duplicate(true);changed[field]+=1
		check(not Bakka.selected(bindings,36,changed,27),"Contest selected a changed mission: "+field)
		check(not dispatched._prepare_free_owned(bindings,cat,equipment,career,changed,{},4096,123,true,bodies,effects,cache,incoming,29) and dispatched.snapshot()==state,"Changed mission replaced the prepared incoming world: "+field)
	for mutation in [["binding_id","foreign"],["campaign_cursor",35],["pending_result",{"serial":1}],["accepted_contact",{}]]:
		var wrong: RefCounted=career.fork();wrong._state[mutation[0]]=mutation[1]
		var wrong_before: Dictionary=wrong.snapshot()
		check(not dispatched._prepare_free_owned(bindings,cat,equipment,wrong,MISSION,{},4096,123,true,bodies,effects,cache,incoming,29) and dispatched.snapshot()==state and wrong.snapshot()==wrong_before,"Invalid arrival career was accepted or mutated: "+mutation[0])
	check(not dispatched._prepare_free_owned(bindings,cat,equipment,career,MISSION,{},-1,123,true,bodies,effects,cache,incoming,29) and dispatched.snapshot()==state and career.snapshot()==before,"Failed incoming construction committed a career or world")
	var ordinary=load("res://src/content/ordinary_flight_definitions.gd")
	var departure: Dictionary=ordinary.briefing(bindings,36,true,29)
	check(not departure.is_empty() and departure.get("mission_kind")==-1 and departure.get("events")==[],"Contest capability blocked ordinary Ga'kkrr departure or replayed target dialogue")
	var target_briefing: Dictionary=ordinary.briefing(bindings,36,false,27)
	check(target_briefing.get("mission_kind")==12 and target_briefing.get("events")==bindings.mido_travel.bakka_contest.mission.briefing_events,"Selected contest entry lost its original two-line briefing")
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,cat,library,dispatched,"F",0.5,Vector2i(1280,720),false,false,"Q","Space","Tab"):check(false,frame.error);return
	check(frame.snapshot().actors.size()==8 and frame.prepare_station().is_empty(),"Dispatched contest completed without combat")
	selected_arrival_construction=dispatched

func verify_result_transaction(bindings: RefCounted,initial: RefCounted,cat: RefCounted,library: RefCounted) -> void:
	verify_pre_victory_docking(initial)
	var before: Dictionary=initial.snapshot();var retained: Dictionary=initial.contract_owner().snapshot()
	var win: RefCounted=contest_outcome(initial,true)
	if win==null:return
	var state: Dictionary=win.snapshot();var event: Dictionary=bindings.mido_travel.bakka_contest.result_events[0]
	check(state.phase=="return_instructions" and state.dialogue.text_id==int(event.text_id) and state.dialogue.voice_event_id==int(event.voice_event_id) and state.dialogue.count==2,"B'akka did not open its authored two-line success")
	check(state.campaign_cursor==36 and state.mission==MISSION and state.combat_objective_satisfied and not state.combat_objective_acknowledged,"B'akka advanced before final acknowledgement")
	check(state.progress.player_kills==before.progress.player_kills+4 and state.progress.pirate_kills==before.progress.pirate_kills+4,"B'akka objective omitted or duplicated actual death accounting")
	check(win.contract_owner().snapshot()==retained and not win.contract_result_pending(),"B'akka success prematurely settled the independent job")
	check(state.encounter.controller.bakka_result.clock_ms>=5001,"Success ignored the strict scene-clock gate")
	var frozen: RefCounted=win.evaluate(150)
	if frozen==null:check(false,"B'akka modal frame: "+win.error);return
	check(frozen.snapshot().encounter.controller.bakka_result==state.encounter.controller.bakka_result and frozen.snapshot().encounter.world_elapsed_ms==state.encounter.world_elapsed_ms and frozen.snapshot().progress==state.progress,"Success modal advanced the clock, world or earned counters")
	check(win.navigate("next",true)==null and win.navigate("previous")==null and win.snapshot()==state,"Paused/invalid navigation changed pending success")
	var last: RefCounted=win.navigate("next")
	if last==null:check(false,win.error);return
	check(last.snapshot().dialogue.index==1 and last.snapshot().campaign_cursor==36 and last.contract_owner().snapshot()==retained,"First Next completed a two-line result")
	var back: RefCounted=last.navigate("previous")
	check(back!=null and back.snapshot().dialogue.index==0 and back.snapshot().progress==state.progress,"Previous changed earned progress")
	var missing: RefCounted=last.fork_for_frame();missing._convoy_career=null
	var missing_before: Dictionary=missing.snapshot()
	check(missing.navigate("next")==null and missing.snapshot()==missing_before,"Missing career partially acknowledged the result")
	var foreign: RefCounted=last.fork_for_frame();foreign._convoy_career=foreign._convoy_career.fork();foreign._convoy_career._state.binding_id="foreign"
	var foreign_before: Dictionary=foreign.snapshot()
	check(foreign.navigate("next")==null and foreign.snapshot()==foreign_before,"Foreign career partially acknowledged the result")
	var unearned: RefCounted=last.fork_for_frame();unearned._encounter=initial._encounter.fork_for_frame()
	var unearned_before: Dictionary=unearned.snapshot()
	check(unearned.navigate("next")==null and unearned.snapshot()==unearned_before,"A missing controller victory still advanced the campaign")
	var acknowledged: RefCounted=last.navigate("next")
	if acknowledged==null:check(false,"Final B'akka acknowledgement: "+last.error);return
	var completed: Dictionary=acknowledged.snapshot();var career: Dictionary=acknowledged.contract_owner().snapshot()
	check(completed.campaign_cursor==37 and completed.mission=={"kind":160,"station_id":27,"reward":0,"bonus":0,"source_parameter":0} and completed.combat_objective_acknowledged and not completed.dialogue.visible,"Final Next did not select the source return mission")
	check(completed.encounter.controller.bakka_result.retired and completed.encounter.controller.bakka_result.mode==0 and career.campaign_cursor==37 and career.progress==completed.progress,"Result retirement and retained career were not committed together")
	for key in ["credits","passengers","mission","active_offer_id","accepted_contact","completed_side_missions","delivery_statistics","travel_statistics","pending_result","result_serial"]:
		check(career[key]==retained[key],"B'akka acknowledgement changed independent career field: "+key)
	check(completed.progress.rank_score==state.progress.rank_score+int(bindings.opening_handoff.cursor_weight),"Final acknowledgement awarded the story score more than once")
	check(acknowledged.navigate("next")==null and acknowledged.snapshot()==completed,"A repeated acknowledgement advanced again")
	var resumed: RefCounted=acknowledged.evaluate(150)
	check(resumed!=null and resumed.snapshot().campaign_cursor==37 and resumed.snapshot().progress==completed.progress,"Acknowledged B'akka world cannot resume without duplicating combat progress")
	var loss: RefCounted=contest_outcome(initial,false)
	if loss==null:return
	var failed: Dictionary=loss.snapshot()
	check(failed.phase=="failure_instructions" and failed.dialogue.count==1 and failed.dialogue.speaker_id==16 and failed.dialogue.voice_event_id==-1 and failed.campaign_cursor==36 and not failed.combat_objective_satisfied,"B'akka loss offered victory or skipped the source failure modal")
	check(failed.encounter.controller.bakka_result.clock_ms<5001,"B'akka failure waited for the periodic success gate")
	var held_loss: RefCounted=loss.evaluate(150)
	check(held_loss!=null and held_loss.snapshot().encounter.controller.bakka_result==failed.encounter.controller.bakka_result,"Failure modal did not freeze its result clock")
	check(loss.navigate("next",true)==null and loss.navigate("previous")==null and loss.snapshot()==failed,"Paused/invalid failure navigation changed the result")
	var exited: RefCounted=loss.navigate("next")
	if exited==null:check(false,"Failure acknowledgement: "+loss.error);return
	check(exited._game_over_packet.source_state==1 and exited._game_over_packet.campaign_cursor==36 and exited.snapshot().mining_objective.campaign_failure.reward_credits==0 and exited.contract_owner().snapshot()==retained,"Failure acknowledgement advanced, paid, or consumed the saved career")
	check(exited.navigate("next")==null and exited.evaluate(150).snapshot()==exited.snapshot(),"Acknowledged failure allowed further flight")
	check(initial.snapshot()==before and initial.contract_owner().snapshot()==retained and win.snapshot()==state,"Detached win/loss attempts changed the retained starting world or sibling result")
	check(initial.prepare_station().is_empty() and win.prepare_station().is_empty() and completed.station_return_supported,"Physical arrival opened before victory acknowledgement")
	var arrived: RefCounted=verify_physical_return(bindings,acknowledged)
	if arrived!=null and FreeFlight.Campaign.BakkaReturn.available(bindings):verify_station_return(bindings,cat,library,arrived)

## Disclosed contact pose in a detached contest, not campaign progress. The
## ordinary frame earns input release; original volumes and notices own contact.
func verify_pre_victory_docking(initial: RefCounted) -> void:
	var before: Dictionary=initial.snapshot();var retained: Dictionary=initial.contract_owner().snapshot()
	var frame: RefCounted=initial.fork_for_frame()
	for step in 100:
		if frame.entry_released():break
		var next: RefCounted=frame.evaluate(150)
		if next==null:check(false,"Pre-victory input release: "+frame.error);return
		frame=next
	if not frame.entry_released():check(false,"Contest never released station targeting");return
	var station: Dictionary=frame._station.snapshot()
	# Reuse the shared station-return contact fixture, not the first solid
	# collision sphere's center (which collision response correctly ejects).
	frame._pose.origin=station.pose.origin+Vector3(100,100,100)
	check(frame._station.point_volume(frame._pose.origin)>=0,"Denial fixture missed the original station volume")
	var unselected: RefCounted=frame.evaluate(0)
	if unselected==null:check(false,"Unselected contest contact: "+frame.error);return
	check(unselected.prepare_station().is_empty() and not unselected._notices.snapshot().pending.any(func(row):return row.source_id==21),"Unselected contact docked or emitted a selected-station denial")
	check(frame.start_station_autopilot(true)==null,"Paused contest selected station guidance")
	var selected: RefCounted=frame.start_station_autopilot()
	if selected==null:check(false,"Pre-victory station selection: "+frame.error);return
	var denied: RefCounted=selected.evaluate(0)
	if denied==null:check(false,"Pre-victory selected contact: "+selected.error);return
	var notices: Dictionary=denied._notices.snapshot()
	check(denied.snapshot().station_volume_index>=0 and notices.pending.any(func(row):return row.source_id==21),"Unfinished B'akka selected volume omitted the original refusal notice")
	check(denied.prepare_station().is_empty() and denied.snapshot().campaign_cursor==36 and denied.snapshot().mission==MISSION and denied.contract_owner().snapshot()==retained,"Docking refusal changed the contest, independent job or wallet")
	var repeated: RefCounted=denied.evaluate(0)
	check(repeated!=null and repeated._notices.snapshot()==notices and repeated.prepare_station().is_empty(),"Repeated restricted contact duplicated or restarted the notice")
	var cancelled: RefCounted=denied.cancel_station_autopilot()
	check(cancelled!=null and not cancelled.snapshot().station_autopilot.active and cancelled.prepare_station().is_empty(),"Refused station guidance cannot be cancelled")
	check(initial.snapshot()==before and initial.contract_owner().snapshot()==retained,"Restricted contact mutated the retained starting contest")

## One disclosed close approach in the detached component world, not an earned
## campaign journey. Guidance, motion, contact, inventory and arrival are native;
## no mission state, counters, rewards, clocks or saved progress are injected.
func verify_physical_return(bindings: RefCounted,initial: RefCounted,consume_frame: Callable=Callable()) -> RefCounted:
	var before: Dictionary=initial.snapshot();var retained: Dictionary=initial.contract_owner().snapshot()
	var rules:=FlightFrame.OrdinaryFlight.docking(bindings,37)
	check(not rules.is_empty() and FlightFrame.OrdinaryFlight.docking_parameters(rules),"Acknowledged B'akka lost its source return rules")
	for field in ["station_id","system_id","campaign_cursor","mission_kind","source_state"]:
		var invalid:=rules.duplicate(true);invalid[field]+=1
		check(not FlightFrame.OrdinaryFlight.docking_parameters(invalid),"Changed return declaration accepted: "+field)
	check(FlightFrame.OrdinaryFlight.station_conversation(bindings,37).is_empty(),"Physical docking invented a station conversation")
	check(initial.prepare_station().is_empty() and initial.start_station_autopilot(true)==null and initial.snapshot()==before,"A paused or distant return created arrival state")
	var frame: RefCounted=initial.fork_for_frame()
	frame._pose=Transform3D(Basis.IDENTITY,frame._station.snapshot().pose.origin+Vector3(0,0,-18000))
	check(frame._station.point_volume(frame._pose.origin)<0,"The close-approach fixture starts inside the station")
	var sampled: RefCounted=frame.evaluate(150,Vector2.ZERO,0.0)
	if sampled==null:check(false,"Return response sample: "+frame.error);return null
	if consume_frame.is_valid() and not consume_frame.call(sampled):return null
	check(sampled.prepare_station().is_empty(),"Unselected station contact created an arrival")
	frame=sampled.start_station_autopilot()
	if frame==null:check(false,"Return guidance: "+sampled.error);return null
	if consume_frame.is_valid() and not consume_frame.call(frame):return null
	check(frame._autopilot.snapshot().active and frame._autopilot.snapshot().station_id==27,"Return guidance selected another station")
	var cancelled: RefCounted=frame.cancel_station_autopilot()
	check(cancelled!=null and not cancelled._autopilot.snapshot().active and frame._autopilot.snapshot().active,"Cancelling a detached return changed its active sibling")
	var arrived: RefCounted
	var final_parent: RefCounted
	for step in 500:
		var next: RefCounted=frame.evaluate(150,Vector2.ZERO,1.0)
		if next==null:check(false,"Physical return frame: "+frame.error);return null
		if consume_frame.is_valid() and not consume_frame.call(next):return null
		if not next.prepare_station().is_empty():arrived=next;final_parent=frame;break
		frame=next
	if arrived==null:check(false,"Native station guidance never reached contact");return null
	for corrupt in [false,true]:
		var rejected: RefCounted=final_parent.fork_for_frame()
		if corrupt:
			rejected._convoy_career=rejected._convoy_career.fork();rejected._convoy_career._state.binding_id="foreign"
		else:rejected._convoy_career=null
		var unchanged: Dictionary=rejected.snapshot()
		check(rejected.evaluate(150,Vector2.ZERO,1.0)==null and rejected.snapshot()==unchanged,"Rejected docking partially committed a missing or foreign career")
	var packet: Dictionary=arrived.prepare_station();var state: Dictionary=arrived.snapshot()
	check(packet.campaign_cursor==37 and packet.source_state==5 and packet.mission==before.mission and packet.docking.station_id==27,"Physical return changed its source destination or mission")
	check(packet.docking.pre_motion_contact or packet.docking.post_motion_volume_index>=0,"Return bypassed native station contact")
	check(packet.contracts==arrived.contract_owner().snapshot() and packet.progress==packet.contracts.progress and packet.progress==state.progress,"Arrival lost its retained flight career")
	check(packet.station_response_flags==state.station_response_flags and packet.station_response_flags==arrived.station_response_flags(),"Arrival lost its actual station-response history")
	for field in ["credits","passengers","mission","accepted_contact","active_offer_id","completed_side_missions","delivery_statistics","travel_statistics","pending_result","result_serial"]:
		check(packet.contracts[field]==retained[field],"Docking settled or changed the independent career field: "+field)
	check(packet.cargo==packet.equipment.cargo and packet.loadout==packet.equipment.loadout and packet.player_cache.campaign_cursor==37,"Docking lost the actual cargo, equipment or cache cursor")
	check(packet.player_cache.values.hull==packet.player.vitals.hull and packet.player_cache.values.armor==packet.player.vitals.armor and packet.player_cache.values.shield==int(packet.player.vitals.shield) and packet.player_cache.values.gamma==int(packet.player.gamma),"Docking restored or changed the live player pools")
	var again: RefCounted=arrived.evaluate(150)
	check(again!=null and again.snapshot()==state and again.prepare_station()==packet,"Pending station arrival advanced or paid twice")
	packet.progress.player_kills+=100
	check(arrived.prepare_station().progress==state.progress and initial.snapshot()==before and initial.contract_owner().snapshot()==retained,"Detached arrival data mutated the live flight or its parent")
	return arrived

## The actual docked frame enters the shared station owner. This remains a
## component test, not evidence of an earned campaign journey or save.
func verify_station_return(bindings: RefCounted,cat: RefCounted,library: RefCounted,arrived: RefCounted) -> RefCounted:
	var station=load("res://src/simulation/station_entry.gd").new()
	var packet: Dictionary=arrived.prepare_station();var flight_before: Dictionary=arrived.snapshot()
	if not station.configure_return(bindings,cat,library,arrived):check(false,"Post-contest station: "+station.error);return null
	var initial: Dictionary=station.snapshot();var career: Dictionary=station.contract_owner().snapshot();var equipment: Dictionary=station.equipment_owner().snapshot()
	check(initial.campaign_cursor==37 and initial.mission==packet.mission and initial.progress==packet.progress and initial.loadout==packet.loadout and initial.cargo==packet.cargo,"Station creation changed the accepted arrival")
	check(station.campaign_conversation_ready(bindings,cat,library) and station.prepare_departure(bindings,cat).is_empty(),"Station return omitted its conversation or departed before it")
	var archive=load("res://src/simulation/station_archive.gd").new()
	# A talk that has not begun is offered again after Resume, so saving here is allowed.
	if not station.begin_campaign_conversation(bindings,cat,library):check(false,"Brent conversation: "+station.error);return null
	var opened: Dictionary=station.snapshot()
	check(opened.phase=="conversation" and not opened.acknowledged and opened.campaign_cursor==37 and not station.previous(),"Return conversation advanced immediately or allowed Previous at its first line")
	var events: Array=bindings.mido_travel.bakka_return.mission.result_events
	for index in events.size():
		var state: Dictionary=station.snapshot()
		check(state.line_index==index and state.campaign_cursor==37 and state.progress==initial.progress and station.contract_owner().snapshot()==career,"A non-final dialogue line changed the campaign or career")
		if index==events.size()-1:break
		if not station.acknowledge():check(false,"Brent intermediate Next: "+station.error);return null
	var final_line: Dictionary=station.snapshot()
	var missing: RefCounted=station.fork();missing._contracts=null
	var unchanged: Dictionary=missing.snapshot()
	check(not missing.acknowledge() and missing.snapshot()==unchanged,"Missing career partially committed the station acknowledgement")
	var foreign: RefCounted=station.fork();foreign._contracts=foreign._contracts.fork();foreign._contracts._state.binding_id="foreign"
	unchanged=foreign.snapshot()
	check(not foreign.acknowledge() and foreign.snapshot()==unchanged,"Foreign career partially committed the station acknowledgement")
	var backwards: RefCounted=station.fork()
	check(backwards.previous() and backwards.snapshot().line_index==6 and backwards.contract_owner().snapshot()==career and station.snapshot()==final_line,"Previous mutated a sibling conversation or retained career")
	if not station.acknowledge():check(false,"Brent final Next: "+station.error);return null
	var completed: Dictionary=station.snapshot();var retained: Dictionary=station.contract_owner().snapshot()
	check(completed.phase=="free_play_required" and completed.acknowledged and completed.campaign_cursor==38 and completed.player_cache.campaign_cursor==38 and completed.mission==FreeFlight.Campaign.mission(bindings.mido_travel,38),"Final station Next lost the declared mission or live cache cursor")
	check(completed.progress==retained.progress and completed.progress.rank_score==initial.progress.rank_score+int(bindings.opening_handoff.cursor_weight),"Station acknowledgement applied its campaign score incorrectly")
	for key in ["credits","passengers","mission","active_offer_id","accepted_contact","completed_side_missions","delivery_statistics","travel_statistics","pending_result","result_serial"]:
		check(retained[key]==career[key],"Brent dialogue changed the independent career field: "+key)
	check(station.equipment_owner().snapshot()==equipment and completed.reward_credits==0,"Return dialogue changed cargo or paid an invented reward")
	check(not station.acknowledge() and not station.campaign_conversation_ready(bindings,cat,library) and station.snapshot()==completed,"Repeated final Next advanced or paid twice")
	var ordinary_return: Dictionary=FreeFlight.docking(bindings,27,38)
	check(not ordinary_return.is_empty() and FreeFlight.docking_parameters(ordinary_return) and Navigation.ordinary_departure_at(bindings,38,completed.mission,27),"The acknowledged B'akka station lost its ordinary return/departure rules")
	check(archive.can_capture(completed),"The acknowledged source38 station is not eligible for its durable archive")
	for field in ["hangar_open","lounge_open","acknowledged"]:
		var unresolved: Dictionary=completed.duplicate(true)
		unresolved[field]=37 if field=="campaign_cursor" else false if field=="acknowledged" else true
		check(not archive.can_capture(unresolved),"An unresolved B'akka station became save eligible: "+field)
	check(archive.capture(station,bindings).is_empty() and not archive.error.is_empty() and station.snapshot()==completed,"A detached contest without the earned Void career became a campaign save")
	check(not Navigation.destination_supported(bindings,38,completed.mission,22),"Dialogue components opened the unfinished next encounter")
	check(arrived.snapshot()==flight_before and arrived.prepare_station()==packet,"Station transaction mutated the accepted flight")
	return station

func contest_outcome(initial: RefCounted,player_wins: bool,consume_frame: Callable=Callable()) -> RefCounted:
	# Controlled lethal contacts in a detached component world. The normal
	# controller, destruction, accounting and complete flight frame do the rest;
	# no counters, result flags, mission clocks or saved progress are fabricated.
	var frame: RefCounted=initial.fork_for_frame()
	for id in range(1,8):
		var actor: Dictionary=frame._encounter.combat_owner().actor_snapshot(id)
		var target:=Transform3D(Basis.IDENTITY,actor.body_pose.origin+Vector3(0,0,20000))
		for visit in 2:
			var operation: Dictionary=frame._encounter.evaluate_world(frame._player,target,0,frame._random)
			if operation.is_empty():check(false,"Contest activation: "+frame._encounter.error);return null
			frame._encounter=operation.encounter;frame._random=operation.random_state
		var combat: RefCounted=frame._encounter.combat_owner()
		if not combat.begin_contact_pass(frame._random,true):check(false,combat.error);return null
		var hit: Dictionary=combat.normal_hit(id,9999999,id>(4 if player_wins else 3))
		if hit.is_empty() or not hit.destroyed_now:check(false,"Contest contact: "+combat.error);return null
		frame._encounter._combat=combat
	for step in 100:
		var next: RefCounted=frame.evaluate(150,Vector2.ZERO,0.0)
		if next==null:check(false,"Contest result frame: "+frame.error);return null
		frame=next
		if consume_frame.is_valid() and not consume_frame.call(frame):return null
		if frame._objective.snapshot().dialogue.visible:return frame
	check(false,"Contest never reached its native result modal")
	return null

func component_owner(bindings: RefCounted,cat: RefCounted,seed: Dictionary) -> RefCounted:
	var fixture:=ComponentEquipment.new()
	var equipment: RefCounted=fixture.create(bindings,cat,seed)
	if equipment==null:check(false,fixture.error)
	return equipment

func equipped_seed(bindings: RefCounted,cat: RefCounted,source: Dictionary) -> Dictionary:
	return ComponentEquipment.equipped_seed(bindings,cat,source)

func verify_definitions(bindings: RefCounted,source: Dictionary,header: Dictionary) -> void:
	check(validate(source,header,bindings).is_empty(),"The imported source capability failed validation")
	for key in Bakka.SPANS:
		var changed: Dictionary=source.duplicate(true)
		changed.provenance[key].offset+=1
		check(not validate(changed,header,bindings).is_empty(),"A changed proof was trusted: "+key)
	for field in ["actor_count","rival_hull_catalogue_id","rival_name_text_id","condition_end_actor"]:
		var changed: Dictionary=source.duplicate(true)
		changed.bakka_contest.population[field]+=1
		check(not Travel.parameters(changed),"Changed population accepted: "+field)
	var mixed: Dictionary=source.duplicate(true)
	# Imported JSON has float-valued numbers; strict dictionary equality is
	# not an edition discriminator. Select the opposing source text binding.
	mixed.bakka_contest=Bakka.MAC_VALUES.duplicate(true) if int(source.bakka_contest.population.rival_name_text_id)==1593 else Bakka.VALUES.duplicate(true)
	check(mixed.bakka_contest.population.rival_name_text_id!=source.bakka_contest.population.rival_name_text_id and not Travel.parameters(mixed),"Mixed source editions accepted")

func verify_refusals(bindings: RefCounted,cat: RefCounted,seed: Dictionary,context: Dictionary) -> void:
	var replacements:={"base_content_id":"other","binding_id":"other","campaign_cursor":35,"station_id":29,"system_id":15,"mission_kind":11,"mission_story":false,"mission_completed":true,"rank":21,"difficulty":2.0}
	for key in replacements:
		var invalid: Dictionary=context.duplicate();invalid[key]=replacements[key]
		var owner:=Factory.new()
		check(not owner.configure_bakka(bindings,cat,seed,invalid,Vector3.ZERO) and owner.snapshot().is_empty(),"Foreign story context accepted: "+key)
	var fractional: Dictionary=context.duplicate();fractional.campaign_cursor=36.0
	check(not Bakka.context_valid(bindings,fractional),"Mistyped campaign cursor accepted")
	replacements={"binding_id":"other","station_id":29,"ship_id":-1,"equipment_ids":[9999]}
	for key in replacements:
		var invalid: Dictionary=seed.duplicate(true);invalid[key]=replacements[key]
		check(not Factory.new().configure_bakka(bindings,cat,invalid,context,Vector3.ZERO),"Invalid retained equipment accepted: "+key)
	check(not Factory.new().configure_bakka(bindings,cat,seed,context,Vector3(INF,0,0)),"Nonfinite placement accepted")
	check(not Route.new().configure_bakka_generated(bindings,-1) and not Route.new().configure_bakka_generated(bindings,8),"Out-of-range route owner accepted")

func verify_vector(bindings: RefCounted,cat: RefCounted,seed: Dictionary,context: Dictionary,vector: Dictionary) -> void:
	var owner:=Factory.new()
	if not owner.configure_bakka(bindings,cat,seed,context,vec(vector.player)):check(false,owner.error);return
	check(owner.generate({"state":-1}).is_empty() and owner.snapshot().actors.is_empty(),"Invalid RNG partially generated actors")
	var random:=Random.new();random.seed_from(int(vector.seed))
	var state:=owner.generate(random.snapshot())
	if state.is_empty():check(false,owner.error);return
	check(state.campaign_cursor==36 and state.station_id==27 and state.system_id==5 and state.actors.size()==8,"Changed story identity or fixed population")
	check(not state.has("contract_encounter") and state.bakka_encounter.context.mission.story,"Story impersonated a lounge contract")
	check(state.random_state.state==int(vector.random_state),"Changed independent final RNG")
	check(state.bakka_encounter.path==vector.path.map(vec) and state.bakka_encounter.unused_enemy_faction==-1,"Consumed a generated lounge path or dispatch draw")
	for id in 8:
		var actor: Dictionary=state.actors[id];var expected: Dictionary=vector.actors[id]
		check(actor.actor_id==id and actor.subtype==0 and actor.hull_catalogue_id==int(expected.hull),"Changed source actor identity")
		check(actor.factory_position==vec(expected.factory_position) and actor.body_pose.origin==vec(expected.position) and actor.statistics_pose==actor.body_pose,"Factory placement differs from independent trace")
		check(actor.route.waypoints==expected.route.map(vec) and actor.fragments.size()==int(expected.fragments),"Route or fragment draws changed")
		check(actor.cargo==expected.cargo.map(cargo_row),"Cargo draws changed")
		var route: RefCounted=owner.route(id)
		check(route!=null and route.snapshot()==actor.route and actor.route.campaign_cursor==36,"Live route differs from constructed record")
		if id==0:
			check(actor.actor_kind==1 and actor.name_text_id==int(bindings.mido_travel.bakka_contest.population.rival_name_text_id) and actor.friendly and actor.current_hull_override==9999999 and actor.base_speed==3.0 and actor.speed==3.0,"Named rival lost its overrides")
			check(actor.discarded_route.waypoints==expected.discarded_route.map(vec) and actor.discarded_cargo==expected.discarded_cargo.map(cargo_row),"Replacement skipped discarded factory draws")
			check(not actor.route.loop and actor.route.index==0,"Rival did not start its authored nonlooping path")
			for point in actor.route.waypoints:check(not route.advance(point).is_empty(),route.error)
			check(route.snapshot().completed and owner.route(id).snapshot().index==0,"Detached route advanced retained construction")
		else:check(actor.actor_kind==8 and actor.mode==5 and not actor.active and actor.targeting_blocked and actor.route.loop,"Pirates activated before their trigger")
	check(owner.generate(random.snapshot()).is_empty() and owner.snapshot()==state,"Committed construction rerolled")
	state.bakka_encounter.path.clear();state.actors[0].cargo.append({"item_id":1,"quantity":999})
	check(owner.snapshot().bakka_encounter.path.size()==4 and owner.snapshot().actors[0].cargo.is_empty(),"Caller mutated retained construction")
	populations+=1

func validate(data: Dictionary,header: Dictionary,bindings: RefCounted) -> String:
	return Travel.validate(data,int(header.source_executable_bytes),header.architecture,bindings.arrival_staging,bindings.station_entry,bindings.combat_training,bindings.scenery_population,bindings.scenery_resources)

func vec(values: Array) -> Vector3:return Vector3(values[0],values[1],values[2])
func cargo_row(values: Array) -> Dictionary:return {"item_id":int(values[0]),"quantity":int(values[1])}
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
