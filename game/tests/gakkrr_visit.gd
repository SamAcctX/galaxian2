extends SceneTree
## Detached dialogue components use real imported text/source identities, not
## fabricated earned careers. Route, archive and application admission are separate.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Campaign=preload("res://src/content/free_campaign_definitions.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Navigation=preload("res://src/content/free_navigation_definitions.gd")
const Visit=preload("res://src/simulation/campaign_visit.gd")
const FreeFlight=preload("res://src/content/free_flight_definitions.gd")
const PlayerEntry=preload("res://src/content/player_entry_definitions.gd")
const StationView=preload("res://src/content/station_presentation_definitions.gd")
const PopulationVectors=preload("res://tests/free_population.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Traffic=preload("res://src/content/free_traffic_definitions.gd")
const Lifecycle=preload("res://src/content/free_lifecycle_definitions.gd")
const MISSION35={"kind":11,"station_id":29,"reward":0,"bonus":0,"source_parameter":0}
const MISSION36={"kind":12,"station_id":27,"reward":0,"bonus":0,"source_parameter":0}
var checks:=0
var failures:=0
var conversations:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected content, bindings and visuals")
	else:verify(args)
	print("Gakkrr visit declarations: %d checks; %d failures; %d localized conversations"%[checks,failures,conversations])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var original: Dictionary=bindings.mido_travel.duplicate(true)
	var has_gakkrr: bool=original.has("gakkrr_visit")
	var has_world:=Campaign.gakkrr_world_available(original)
	check(Navigation.destination_supported(bindings,35,MISSION35,29)==has_world and Campaign.ordinary_story_at(original,35,29)==has_world,"Gakkrr admission disagrees with its native world support")
	check(not has_world or has_gakkrr,"A native world bypassed missing Gakkrr declarations")
	check(Campaign.supported(original,36)==has_gakkrr and Campaign.mission(original,36)==(MISSION36 if has_gakkrr else {}),"The pending contest lost its capability-bound mission identity")
	var has_return: bool=has_gakkrr and original.has("bakka_return")
	var contest_ready: bool=has_return and Travel.Bakka.available(bindings)
	check(Navigation.destination_supported(bindings,36,MISSION36,27)==contest_ready and not Campaign.ordinary_story_at(original,36,27) and Campaign.dialogue_rules(bindings,36,MISSION36,true).is_empty(),"Contest navigation must require complete encounter/return support without becoming a station result")
	check(Navigation.ordinary_departure_at(bindings,36,MISSION36,29)==has_gakkrr,"The pending contest cannot retain ordinary departure from Gakkrr")
	check(not Navigation.ordinary_departure_at(bindings,36,MISSION36,27),"Navigation must not turn the unplayed contest into ordinary departure")
	for field in MISSION36:
		var changed_mission: Dictionary=MISSION36.duplicate();changed_mission[field]+=1
		check(not Navigation.destination_supported(bindings,36,changed_mission,27),"A changed contest mission entered B'akka: "+field)
	for cursor in [35,37,38]:
		check(not Navigation.destination_supported(bindings,cursor,MISSION36,27),"A stale contest mission entered B'akka")
	if contest_ready:
		for capability in ["bakka_contest","bakka_return"]:
			bindings.mido_travel=original.duplicate(true);bindings.mido_travel.erase(capability)
			check(not Navigation.destination_supported(bindings,36,MISSION36,27),"Incomplete contest support entered B'akka: "+capability)
		bindings.mido_travel=original
		check(not Navigation.destination_supported(bindings,38,Campaign.mission(original,38),22),"B'akka navigation admitted the unfinished next encounter")
	check(not Campaign.supported(original,35.0) and not Campaign.supported(original,36.0) and not Campaign.supported(original,37.0) and not Campaign.supported(original,38.0) and not Campaign.supported(original,39),"A mistyped or unsupported later campaign cursor was admitted")
	check(Campaign.supported(original,37)==has_return and Campaign.supported(original,38)==has_return,"Post-contest stages ignored the imported return capability")
	var without_return:=original.duplicate(true);without_return.erase("bakka_return")
	check(not Campaign.supported(without_return,37) and not Campaign.supported(without_return,38),"Missing return declarations admitted the post-contest stages")
	var header: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("bindings.json")))
	check(validate(original,header,bindings).is_empty(),"The imported declaration chain failed entry validation")
	if has_gakkrr:
		check(Travel.Gakkrr.parameters(original.gakkrr_visit),"Unknown Gakkrr source data")
		var context:={"campaign_cursor":35,"station_id":29,"system_id":5,"mission_story":true,"mission_completed":false,"mission_kind":11}
		check(Campaign.empty_story(original,context)==has_world,"Gakkrr selected an empty story without its native world")
		for field in {"station_id":27,"system_id":2,"mission_story":false,"mission_completed":true,"mission_kind":12}:
			var changed_context: Dictionary=context.duplicate()
			changed_context[field]={"station_id":27,"system_id":2,"mission_story":false,"mission_completed":true,"mission_kind":12}[field]
			check(not Campaign.empty_story(original,changed_context),"Gakkrr accepted a foreign story context: "+field)
		for capability in ["gakkrr_visit","nehma_visit","void_crystals","void_access","post_probe_visits"]:
			var missing: Dictionary=original.duplicate(true);missing.erase(capability)
			check(not Campaign.gakkrr_available(missing) and not Campaign.ordinary_story_at(missing,35,29) and not Campaign.supported(missing,36),"Missing capability admitted Gakkrr or its pending contest: "+capability)
			missing[capability]={}
			check(not Campaign.gakkrr_available(missing),"Malformed capability admitted Gakkrr: "+capability)
		for field in ["kind","station_id","reward","bonus","source_parameter"]:
			var wrong_mission: Dictionary=MISSION35.duplicate();wrong_mission[field]+=1
			check(not Navigation.destination_supported(bindings,35,wrong_mission,29),"A changed mission entered Gakkrr: "+field)
		for key in ["nehma_visit","void_crystals","void_access","post_probe_visits"]:
			var changed:=original.duplicate(true);changed.erase(key)
			check(not Travel.parameters(changed),"Gakkrr lost its prerequisite: "+key)
		var wrong:=original.duplicate(true)
		wrong.gakkrr_visit=Travel.Gakkrr.MAC_VALUES.duplicate(true) if Travel.Equal.equal_value(original.gakkrr_visit,Travel.Gakkrr.VALUES) else Travel.Gakkrr.VALUES.duplicate(true)
		check(not Travel.parameters(wrong),"Gakkrr accepted the other edition's dialogue")
		for key in Travel.Gakkrr.SPANS:
			var changed:=original.duplicate(true);changed.provenance[key].offset+=1
			check(not validate(changed,header,bindings).is_empty(),"An incorrect source offset passed: "+key)
			changed=original.duplicate(true);changed.provenance.erase(key)
			check(not validate(changed,header,bindings).is_empty(),"A missing source extent passed: "+key)
			changed=original.duplicate(true);changed.provenance[key].bytes+=1
			check(not validate(changed,header,bindings).is_empty(),"An incorrect source size passed: "+key)
		var changed:=original.duplicate(true);changed.gakkrr_visit.mission35.completion.ship_change=true
		check(not Travel.parameters(changed),"The conversation invented a ship reward")
	else:
		check(Campaign.dialogue_rules(bindings,35,MISSION35,true).is_empty(),"An older pack invented Gakkrr dialogue")
	verify_world_consumers(bindings,cat,has_world)
	var cases:=[]
	if Campaign.post_probe_available(original):cases.append_array([31,32])
	if Campaign.nehma_available(original):cases.append(34)
	if has_gakkrr:cases.append(35)
	for language in library.manifest.languages:
		if not library.select_language(language):check(false,library.error);continue
		for cursor in cases:verify_dialogue(bindings,library,cat,cursor)
	check(bindings.mido_travel==original,"Component checks mutated the loaded binding")

func verify_world_consumers(bindings: RefCounted,cat: RefCounted,available: bool) -> void:
	# Detached factory vectors exercise source scenery/actor consumers, not an
	# earned journey. Only the application path can supply a valid station save.
	if not available:
		for cursor in [35,36]:
			check(FreeFlight.flight(bindings,29,cursor).is_empty() and FreeFlight.docking(bindings,29,cursor).is_empty(),"An unfinished Gakkrr world admitted flight or docking")
			check(not PlayerEntry.new().configure(bindings,cursor,29,false,0),"An unfinished Gakkrr world admitted player entry")
		check(not Navigation.destination_supported(bindings,35,MISSION35,29),"Imported dialogue exposed the unfinished Gakkrr route")
		return
	for cursor in [35,36]:
		var flight:=FreeFlight.flight(bindings,29,cursor)
		var docking:=FreeFlight.docking(bindings,29,cursor)
		check(not flight.is_empty() and flight.campaign_cursor==cursor and flight.station_id==29 and flight.system_id==5,"Gakkrr lost its original ordinary flight location")
		check(not docking.is_empty() and FreeFlight.docking_parameters(docking),"Gakkrr flight and docking disagree on the supported career")
		check(not StationView.select(bindings,29,cursor).is_empty(),"Gakkrr lost its original station presentation")
		var entry:=PlayerEntry.new()
		check(entry.configure(bindings,cursor,29,false,0) and entry.is_departure and entry.uses_equipment,"Gakkrr cannot prepare its equipped player departure")
		check(entry.configure(bindings,cursor,29,true,0) and entry.restores_local and not entry.is_departure,"Gakkrr arrival lost its retained player entry")
		var context: Dictionary=PopulationVectors.CONTEXT.duplicate(true)
		context.campaign_cursor=cursor;context.system_id=5;context.station_id=29
		if cursor==35:context.mission_kind=11;context.mission_completed=false;context.mission_story=true
		var factory:=Factory.new()
		if not factory.configure_free_factory(bindings,cat,0,[81,86],context,1700000000):check(false,factory.error);continue
		var packet: Dictionary=factory.generate({"state":98765})
		if packet.is_empty():check(false,factory.error);continue
		check(packet.actors.size()==packet.population.actor_count,"The selected Gakkrr population lost an actor")
		if cursor==35:
			check(packet.actors.is_empty() and packet.population.groups.values().all(func(count):return count==0) and packet.population.mission_kind==11,"Gakkrr's selected story constructed an unearned cast")
		else:
			check(not packet.actors.is_empty() and not packet.population.has("mission_kind"),"The ordinary post-visit world retained its empty story scene")
		check(not Traffic.population(bindings,packet,context.rank,context.difficulty).is_empty() and not Lifecycle.population(bindings,packet).is_empty(),"The Gakkrr population was rejected by its flight lifecycle")

func verify_dialogue(bindings: RefCounted,library: RefCounted,cat: RefCounted,cursor: int) -> void:
	var travel: Dictionary=bindings.mido_travel
	var source: Dictionary=travel.post_probe_visits.missions[str(cursor)] if cursor in [31,32] else travel.nehma_visit.mission34 if cursor==34 else travel.gakkrr_visit.mission35
	var next_source: Dictionary=travel.post_probe_visits.missions["32"] if cursor==31 else travel.post_probe_visits.next_mission if cursor==32 else travel.nehma_visit.next_mission if cursor==34 else travel.gakkrr_visit.next_mission
	var mission: Dictionary=Campaign.PostProbe.mission_values(source)
	var rules: Dictionary=Campaign.dialogue_rules(bindings,cursor,mission,true)
	check(rules.get("events")==source.result_events and rules.get("next_cursor")==cursor+1,"The shared rule adapter changed an existing visit")
	check(Campaign.dialogue_rules(bindings,float(cursor),mission,true).is_empty(),"A noninteger cursor selected a result")
	for key in ["kind","station_id","reward","bonus","source_parameter"]:
		var wrong:=mission.duplicate();wrong[key]+=1
		check(Campaign.dialogue_rules(bindings,cursor,wrong,true).is_empty(),"A changed mission selected a result: "+key)
	if failures:return
	var visit:=Visit.new()
	if not visit.configure_station(bindings,library,cat,cursor,mission):check(false,visit.error);return
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":int(source.station_id)+1}
	check(visit.poll_station(context,true) and visit.snapshot().phase=="waiting","The result opened at another station")
	context.station_id=int(source.station_id)
	check(visit.poll_station(context,false) and visit.snapshot().phase=="waiting","The result opened before docking")
	check(visit.poll_station(context,true,true) and visit.snapshot().phase=="waiting","A blocked poll opened a modal result")
	check(visit.poll_station(context,true) and visit.snapshot().mission_completed,"Landed target did not open its result")
	check(visit.transition().is_empty() and not visit.navigate("previous"),"Opening the result advanced progress or moved before its first line")
	var count: int={31:10,32:11,34:15,35:10}[cursor]
	check(visit.snapshot().dialogue.count==count,"The source result line count changed")
	for index in count:
		var before: Dictionary=visit.snapshot()
		var event: Dictionary=source.result_events[index]
		check(before.campaign_cursor==cursor and before.dialogue.visible and before.dialogue.index==index and before.dialogue.speaker_id==int(event.speaker_id) and before.dialogue.text_id==int(event.text_id) and before.dialogue.voice_event_id==int(event.voice_event_id),"Original dialogue order changed: %d/%s/%d"%[cursor,library.active_language,index])
		if cursor==35:check(before.dialogue.voice_event_id==379+index,"Errkt's source voice order changed")
		check(visit.transition().is_empty(),"An intermediate acknowledgement advanced the campaign")
		if index==1:
			check(visit.navigate("previous") and visit.snapshot().dialogue.index==0 and visit.navigate("next") and visit.snapshot()==before,"Previous/Next changed pending state")
		if index==count-1:
			var fork: RefCounted=visit.fork()
			check(fork.navigate("next") and not fork.transition().is_empty() and visit.snapshot()==before,"A fork mutated the original pending result")
		if not visit.navigate("next"):check(false,visit.error);return
	var receipt: Dictionary=visit.transition()
	var next_mission: Dictionary=Campaign.PostProbe.mission_values(next_source)
	check(receipt.get("from_cursor")==cursor and receipt.get("campaign_cursor")==cursor+1 and receipt.get("mission")==next_mission and receipt.get("station_id")==int(source.station_id),"Final Next changed the next mission or relocated the player")
	check(receipt.get("reward_credits")== (30000 if cursor==31 else 0),"The shared result adapter changed payment")
	check(not receipt.has("unlock_system_ids") and not receipt.has("next_course") and not rules.has("cargo_requirement"),"A landed conversation invented a course, unlock or cargo transaction")
	if cursor==35:check(receipt.mission==MISSION36,"The contest became another visit or a freighter reward")
	var after: Dictionary=visit.snapshot()
	check(not visit.navigate("next") and not visit.navigate("previous") and visit.snapshot()==after and visit.transition()==receipt,"Acknowledged dialogue replayed or altered the receipt")
	receipt.mission.station_id=-1
	check(visit.transition().mission==next_mission,"A caller changed the retained prospective mission")
	conversations+=1

func validate(data: Dictionary,header: Dictionary,bindings: RefCounted) -> String:
	return Travel.validate(data,int(header.source_executable_bytes),header.architecture,bindings.arrival_staging,bindings.station_entry,bindings.combat_training,bindings.scenery_population,bindings.scenery_resources)

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
