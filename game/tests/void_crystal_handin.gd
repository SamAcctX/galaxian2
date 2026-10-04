extends SceneTree
## Cargo proposals below exercise a detached inventory owner from a genuine save.
## They are not mined cargo, earned mission33 progress, or saved gameplay fixtures.
const SaveCompare=preload("res://tests/fixtures/save_compare.gd")
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Campaign=preload("res://src/content/free_campaign_definitions.gd")
const Navigation=preload("res://src/content/free_navigation_definitions.gd")
const Crystals=preload("res://src/content/void_crystal_definitions.gd")
const Ordinary=preload("res://src/content/ordinary_flight_definitions.gd")
const Visit=preload("res://src/simulation/campaign_visit.gd")
const Equipment=preload("res://src/simulation/station_equipment.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const MISSION32={"kind":11,"station_id":10,"reward":0,"bonus":0,"source_parameter":0}
const MISSION33={"kind":8,"station_id":10,"reward":0,"bonus":0,"source_parameter":0,"item_id":164,"quantity":50}
const MISSION34={"kind":11,"station_id":30,"reward":0,"bonus":0,"source_parameter":0}
var checks:=0
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=4:check(false,"Expected imported content/binding/visuals and a genuine paid32 save")
	else:verify(args)
	print("Void crystal hand-in components: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var file:=SaveFile.new();var archive:=Archive.new()
	var document: Dictionary=file.read_document(args[3])
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	check(document.station.campaign_cursor==32 and document.inventory.loadout.station_id==98,"Use the actually earned paid Alioth32 fixture")
	var inventory: RefCounted=station.equipment_owner()
	var before: Dictionary=inventory.snapshot()
	verify_rows(inventory,before)
	verify_dialogue(bindings,cat,library,inventory,before.loadout)
	check(inventory.snapshot()==before and SaveCompare.matches_older(archive.capture(station,bindings),document),"Component proposals changed the earned parent inventory or career")
	check(file.read_document(args[3])==document,"The immutable earned input file changed")
	print("Earned input: ship%d, cargo capacity%d; proposals remain detached"%[before.loadout.ship_id,before.cargo.capacity])

func verify_rows(inventory: RefCounted,before: Dictionary) -> void:
	var cases:=[
		{"rows":[],"ready":false,"after":[]},
		{"rows":[{"item_id":164,"quantity":49}],"ready":false,"after":[]},
		{"rows":[{"item_id":164,"quantity":50}],"ready":true,"after":[]},
		{"rows":[{"item_id":164,"quantity":73}],"ready":true,"after":[{"item_id":164,"quantity":23}]},
		{"rows":[{"item_id":164,"quantity":30},{"item_id":164,"quantity":30}],"ready":false,"after":[]},
		{"rows":[{"item_id":158,"quantity":4},{"item_id":164,"quantity":20},{"item_id":164,"quantity":60}],"ready":true,"after":[{"item_id":158,"quantity":4},{"item_id":164,"quantity":60}]},
		{"rows":[{"item_id":164,"quantity":60},{"item_id":164,"quantity":20}],"ready":true,"after":[{"item_id":164,"quantity":10},{"item_id":164,"quantity":20}]}]
	for sample in cases:
		var staged: RefCounted=inventory.fork()
		var hold: Dictionary=before.cargo.duplicate(true)
		hold.entries=sample.rows.duplicate(true);hold.used=quantity(hold.entries);hold.free_space=hold.capacity-hold.used
		if not staged.retain_flight_cargo(hold):check(false,staged.error);continue
		var offered: Dictionary=staged.snapshot()
		var observation: Dictionary=staged.campaign_cargo(offered.loadout,164,50)
		check(not observation.is_empty() and observation.satisfied==sample.ready,"The cargo predicate changed its per-row threshold: "+str(sample.rows))
		check(staged.snapshot()==offered,"Polling the cargo requirement consumed cargo")
		check(staged.debit_campaign_cargo(164,50)==sample.ready,"The debit disagreed with the same inventory requirement")
		if sample.ready:
			var after: Dictionary=staged.snapshot()
			check(after.cargo.entries==sample.after,"The source debit changed first-row selection or surplus cargo")
			check(after.cargo.used==quantity(sample.after) and after.cargo.free_space==after.cargo.capacity-after.cargo.used and not after.cargo_cache_stale,"The debit did not refresh the cargo cache")
			check(after.prices.cargo.size()==sample.after.size() and after.loadout==offered.loadout and after.prices.installed==offered.prices.installed,"Cargo removal changed installed equipment or lost row prices")
			check(not staged.matches_cargo(observation.cargo),"A changed hold matched the earlier conversation observation")
		else:check(staged.snapshot()==offered,"A refused cargo debit changed inventory")
		check(inventory.snapshot()==before,"A detached cargo proposal changed its parent")
	for request in [[164,0],[164,-1],[164,2147483648],[-1,50],[9999,50]]:
		check(not inventory.debit_campaign_cargo(request[0],request[1]) and inventory.snapshot()==before,"An invalid cargo request changed inventory")
	var foreign: Dictionary=before.loadout.duplicate(true);foreign.station_id=10
	check(inventory.campaign_cargo(foreign,164,50).is_empty(),"A different station was accepted as this inventory")
	check(Equipment.new().campaign_cargo(before.loadout,164,50).is_empty(),"An unconfigured inventory supplied a cargo observation")

func verify_dialogue(bindings: RefCounted,cat: RefCounted,library: RefCounted,inventory: RefCounted,loadout: Dictionary) -> void:
	var rules32: Dictionary=Campaign.dialogue_rules(bindings,32,MISSION32,true)
	var rules33: Dictionary=Campaign.dialogue_rules(bindings,33,MISSION33,true)
	var briefing: Dictionary=Ordinary.briefing(bindings,32,true,10)
	var events: Array=briefing.get("events",[])
	# Imported JSON numbers can be floats. Compare the validated numeric fields,
	# not type-sensitive dictionaries against an integer-literal dictionary.
	check(events.size()==1 and events[0].speaker_id==0 and events[0].text_id==1959 and events[0].voice_event_id==181 and briefing.get("briefing_minimum_ms")==5001,"Thynome32 lost its selected flight briefing or HUD timing")
	check(Ordinary.briefing(bindings,32,true,98).get("events")==[],"The Thynome32 briefing opened at the paid Alioth departure")
	check(Ordinary.briefing_presentation(bindings,32,true)==briefing,"Arrival portrait/voice preparation missed the source briefing")
	check(rules32.get("next_mission")==MISSION33 and rules32.get("reward_credits")==0 and rules32.get("events",[]).size()==11,"Thynome32 lost its eleven lines or exact crystal requirement")
	check(rules33.get("next_mission")==MISSION34 and rules33.get("reward_credits")==0 and rules33.get("events",[]).size()==9 and rules33.get("cargo_requirement")=={"item_id":164,"quantity":50},"Crystal33 lost its nine lines, cargo threshold or Nehma34 result")
	check(Campaign.supported(bindings.mido_travel,33) and Campaign.mission(bindings.mido_travel,33)==MISSION33,"Selected ordinary Void support lost its exact crystal mission")
	verify_admission(bindings)
	check(Campaign.supported(bindings.mido_travel,34) and Campaign.mission(bindings.mido_travel,34)==MISSION34,"The crystal hand-in lost its declared pending Nehma mission")
	check(Navigation.destination_supported(bindings,34,MISSION34,10),"The acknowledged crystal hand-in cannot retain its actual Thynome station")
	var nehma: bool=Campaign.nehma_available(bindings.mido_travel)
	check(Navigation.destination_supported(bindings,34,MISSION34,30)==nehma and Campaign.ordinary_story_at(bindings.mido_travel,34,30)==nehma,"Nehma admission disagrees with its complete station continuation")
	check(Campaign.supported(bindings.mido_travel,35)==nehma and not Campaign.supported(bindings.mido_travel,34.0),"The hand-in admitted an unsupported or mistyped campaign stage")
	check(not Navigation.destination_supported(bindings,35,Campaign.mission(bindings.mido_travel,35),29),"Retaining Nehma's result exposed the unimplemented Gakkrr35 visit")
	var earlier: Dictionary=bindings.mido_travel.duplicate(true);earlier.erase("void_crystals")
	check(not Campaign.supported(earlier,34) and Campaign.mission(earlier,34).is_empty(),"Earlier content was granted an undeclared crystal result")
	var changed: Dictionary=MISSION33.duplicate();changed.quantity=49
	check(Crystals.conversation(bindings,33,changed).is_empty(),"An altered crystal mission matched the source result")
	for language in library.manifest.languages:
		if not library.select_language(language):check(false,library.error);continue
		for cursor in [32,33]:
			var visit:=Visit.new()
			check(visit.configure_station(bindings,library,cat,cursor,MISSION32 if cursor==32 else MISSION33),visit.error)
			check(visit.poll_station(loadout,true,false,inventory) and visit.snapshot().phase=="waiting" and visit.transition().is_empty(),"An Alioth inventory opened the remote Thynome result")
	# Dialogue-only poll context is deliberately not a career or an inventory.
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":10}
	var visit:=Visit.new()
	check(visit.configure_station(bindings,library,cat,32,MISSION32),visit.error)
	check(visit.poll_station(context,false) and visit.snapshot().phase=="waiting","Thynome result opened before docking")
	check(visit.poll_station(context,true,true) and visit.snapshot().phase=="waiting","A blocked result poll opened the conversation")
	check(visit.poll_station(context,true) and visit.snapshot().dialogue.count==11,"Thynome32 result did not open after the landed target poll")
	for index in 10:
		check(visit.navigate("next") and visit.transition().is_empty(),"An intermediate Thynome32 Next advanced the mission")
	check(visit.navigate("next") and visit.transition().mission==MISSION33 and visit.transition().campaign_cursor==33,"The final Thynome32 Next lost its prospective mission")
	var crystals:=Visit.new()
	check(crystals.configure_station(bindings,library,cat,33,MISSION33),crystals.error)
	check(not crystals.poll_station(context,true) and crystals.snapshot().phase=="waiting","A cargo dictionary bypassed the native inventory owner")
	check(not crystals.poll_station(context,true,false,inventory) and crystals.snapshot().phase=="waiting","A foreign station inventory opened the crystal result")

func verify_admission(bindings: RefCounted) -> void:
	var travel: Dictionary=bindings.mido_travel
	check(Navigation.destination_supported(bindings,32,MISSION32,10) and Campaign.ordinary_story_at(travel,32,10),"The supported crystal expedition cannot enter its original Thynome32 visit")
	check(not Campaign.ordinary_story_at(travel,32,35) and not Campaign.ordinary_story_at(travel,33,10),"Crystal admission selected a story cast at an ordinary station or hand-in")
	var context:={"campaign_cursor":32,"station_id":10,"system_id":6,"mission_story":true,"mission_completed":false,"mission_kind":11}
	check(Campaign.empty_story(travel,context),"Thynome32 did not select the sourced empty story cast")
	for field in {"system_id":7,"station_id":35,"mission_story":false,"mission_completed":true,"mission_kind":8}:
		var wrong: Dictionary=context.duplicate()
		wrong[field]={"system_id":7,"station_id":35,"mission_story":false,"mission_completed":true,"mission_kind":8}[field]
		check(not Campaign.empty_story(travel,wrong),"Thynome32 accepted a foreign story context: "+field)
	for field in {"kind":8,"station_id":35,"reward":1,"bonus":1,"source_parameter":1}:
		var wrong: Dictionary=MISSION32.duplicate()
		wrong[field]={"kind":8,"station_id":35,"reward":1,"bonus":1,"source_parameter":1}[field]
		check(not Navigation.destination_supported(bindings,32,wrong,10),"An altered mission entered Thynome32: "+field)
	# Capability fixtures stay detached from the loaded binding and earned career.
	for capability in ["post_probe_visits","void_crystals","void_access"]:
		var missing: Dictionary=travel.duplicate(true);missing.erase(capability)
		check(not Campaign.ordinary_story_at(missing,32,10),"Missing "+capability+" admitted the crystal expedition")
		var malformed: Dictionary=travel.duplicate(true);malformed[capability]={}
		check(not Campaign.ordinary_story_at(malformed,32,10),"Malformed "+capability+" admitted the crystal expedition")
	check(Campaign.ordinary_story_at(travel,31,98),"Crystal admission regressed the preceding Alioth result")

func quantity(rows: Array) -> int:
	var total:=0
	for row in rows:total+=row.quantity
	return total

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
