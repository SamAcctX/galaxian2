extends SceneTree
## Dialogue contexts are detached component inputs, not earned career fixtures.
## The application test separately earns travel, docking and the saved result.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Campaign=preload("res://src/content/free_campaign_definitions.gd")
const Navigation=preload("res://src/content/free_navigation_definitions.gd")
const Visit=preload("res://src/simulation/campaign_visit.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const SaveCompare=preload("res://tests/fixtures/save_compare.gd")
const MISSION34={"kind":11,"station_id":30,"reward":0,"bonus":0,"source_parameter":0}
const MISSION35={"kind":11,"station_id":29,"reward":0,"bonus":0,"source_parameter":0}
const VOICES=[364,365,371,372,373,374,375,376,377,378,366,367,368,369,370]
var checks:=0
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected imported content, bindings and visuals")
	else:verify(args)
	print("Nehma visit components: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var travel: Dictionary=bindings.mido_travel
	check(Campaign.nehma_available(travel),"The selected pack lacks the complete Nehma continuation")
	check(Campaign.mission(travel,34)==MISSION34 and Campaign.mission(travel,35)==MISSION35,"Nehma changed the source mission or its prospective result")
	check(Navigation.destination_supported(bindings,34,MISSION34,30) and Navigation.ordinary_departure_at(bindings,35,MISSION35,30),"Nehma cannot arrive or retain ordinary departure after its visit")
	check(not Navigation.destination_supported(bindings,35,MISSION35,29) and not Campaign.ordinary_story_at(travel,35,29),"The unimplemented Gakkrr35 story world was exposed")
	check(not Campaign.supported(travel,34.0) and not Campaign.supported(travel,35.0) and not Campaign.supported(travel,36),"A mistyped or later cursor was admitted")
	var context:={"campaign_cursor":34,"station_id":30,"system_id":2,"mission_story":true,"mission_completed":false,"mission_kind":11}
	check(Campaign.empty_story(travel,context),"Nehma did not select its original empty cast")
	for field in {"station_id":10,"system_id":6,"mission_story":false,"mission_completed":true,"mission_kind":8}:
		var wrong: Dictionary=context.duplicate()
		wrong[field]={"station_id":10,"system_id":6,"mission_story":false,"mission_completed":true,"mission_kind":8}[field]
		check(not Campaign.empty_story(travel,wrong),"Nehma accepted a foreign story context: "+field)
	for capability in ["nehma_visit","void_crystals","void_access","post_probe_visits"]:
		var missing: Dictionary=travel.duplicate(true);missing.erase(capability)
		check(not Campaign.nehma_available(missing) and not Campaign.ordinary_story_at(missing,34,30) and not Campaign.supported(missing,35),"Missing capability admitted Nehma: "+capability)
		missing[capability]={}
		check(not Campaign.nehma_available(missing),"Malformed capability admitted Nehma: "+capability)
	for field in {"kind":8,"station_id":10,"reward":1,"bonus":1,"source_parameter":1}:
		var wrong: Dictionary=MISSION34.duplicate()
		wrong[field]={"kind":8,"station_id":10,"reward":1,"bonus":1,"source_parameter":1}[field]
		check(Campaign.dialogue_rules(bindings,34,wrong,true).is_empty() and not Navigation.destination_supported(bindings,34,wrong,30),"An altered mission entered Nehma: "+field)
	if failures:return
	for language in library.manifest.languages:
		if not library.select_language(language):check(false,library.error);continue
		verify_dialogue(bindings,library,cat)
	if not library.select_language("gb"):check(false,library.error);return
	var input:=OS.get_environment("GOF2_SOURCE_SAVE")
	var hash_before:=FileAccess.get_sha256(input)
	var file:=SaveFile.new();var archive:=Archive.new()
	var record: Dictionary=file.load_document(input,bindings,cat,library)
	if record.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,record)
	if station==null:check(false,archive.error);return
	var before: Dictionary=station.snapshot()
	check(before.campaign_cursor==34 and before.loadout.station_id==10 and before.mission==MISSION34,"Use the genuine delivered-crystal Thynome34 save")
	check(not station.begin_campaign_conversation(bindings,cat,library) and station.snapshot()==before,"The remote Nehma result opened at Thynome")
	# Saves now carry newer fields (medals, blueprint stations, visits) the older file predates.
	check(SaveCompare.matches_older(archive.capture(station,bindings),record),"The existing crystal return lost its archive")
	check(not station.prepare_departure(bindings,cat).is_empty(),"The existing crystal return lost its departure")
	check(not hash_before.is_empty() and FileAccess.get_sha256(input)==hash_before,"Component checks changed the earned input")

func verify_dialogue(bindings: RefCounted,library: RefCounted,cat: RefCounted) -> void:
	var rules: Dictionary=Campaign.dialogue_rules(bindings,34,MISSION34,true)
	var visit:=Visit.new()
	if not visit.configure_station(bindings,library,cat,34,MISSION34):check(false,visit.error);return
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":10}
	check(visit.poll_station(context,true) and visit.snapshot().phase=="waiting","The result opened at the wrong station")
	context.station_id=30
	check(visit.poll_station(context,false) and visit.snapshot().phase=="waiting","The result opened before docking")
	check(visit.poll_station(context,true,true) and visit.snapshot().phase=="waiting","A blocked poll opened the result")
	check(visit.poll_station(context,true) and visit.snapshot().mission_completed and visit.snapshot().dialogue.count==15,"Landed Nehma did not offer its fifteen result lines")
	check(visit.transition().is_empty() and not visit.navigate("previous"),"Opening the result advanced progress or allowed a previous first line")
	for index in 15:
		var current: Dictionary=visit.snapshot()
		check(current.campaign_cursor==34 and current.dialogue.visible and current.dialogue.index==index and current.dialogue.speaker_id==int(rules.events[index].speaker_id) and current.dialogue.text_id==int(rules.events[index].text_id) and current.dialogue.voice_event_id==VOICES[index],"Nehma lost original dialogue order in "+library.active_language)
		check(visit.transition().is_empty(),"An intermediate result line committed the visit")
		if index==1:
			check(visit.navigate("previous") and visit.snapshot().dialogue.index==0 and visit.navigate("next") and visit.snapshot()==current,"Previous/Next changed the pending result")
		if not visit.navigate("next"):check(false,visit.error);return
	var receipt: Dictionary=visit.transition()
	check(receipt.get("campaign_cursor")==35 and receipt.get("from_cursor")==34 and receipt.get("station_id")==30 and receipt.get("mission")==MISSION35 and receipt.get("reward_credits")==0,"Final Next changed the original zero-reward continuation")
	check(not receipt.has("unlock_system_ids") and not receipt.has("next_course") and not rules.has("cargo_requirement"),"Nehma invented a system unlock, course or inventory transaction")
	var after: Dictionary=visit.snapshot()
	check(not visit.navigate("next") and not visit.navigate("previous") and visit.snapshot()==after and visit.transition()==receipt,"An acknowledged result navigated or changed its receipt")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
