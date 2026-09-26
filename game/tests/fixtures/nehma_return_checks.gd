extends RefCounted
## Actual sealed39 career guards plus explicitly detached station-dialogue inputs.
## No result from a component is committed to a career or written as a save.
const Bindings=preload("res://src/content/resource_bindings.gd")
const Rules=preload("res://src/content/nehma_return_definitions.gd")
const Extension=preload("res://src/content/nehma_source_extension.gd")
const Campaign=preload("res://src/content/free_campaign_definitions.gd")
const Navigation=preload("res://src/content/free_navigation_definitions.gd")
const Visit=preload("res://src/simulation/campaign_visit.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const MISSION39={"kind":11,"station_id":30,"reward":0,"bonus":0,"source_parameter":0}
const MISSION40={"kind":161,"station_id":-1,"reward":0,"bonus":0,"source_parameter":0}
var checks:=0
var failures:=0
var completed:=false

func verify(bindings: RefCounted,library: RefCounted,cat: RefCounted,document: Dictionary,base_directory: String,source_directory: String) -> void:
	var archive:=Archive.new()
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var before: Dictionary=station.snapshot()
	check(document.version==9 and before.campaign_cursor==39 and before.loadout.station_id==22 and before.arrival_player.campaign_cursor==38 and before.mission==MISSION39,"Use the genuine landed Dekato39/world38 career")
	var original_identity:=[bindings.base_content_id,bindings.binding_id,JSON.stringify(bindings.mido_travel).sha256_text(),bindings.dekato_source_receipt().duplicate(true)]
	check(not Rules.available(bindings) and bindings.nehma_source_receipt().is_empty() and Campaign.dialogue_rules(bindings,39,MISSION39,true).is_empty(),"Néhma dialogue attached itself while restoring a v9 save")
	check(not Campaign.supported(bindings,39) and station.prepare_departure(bindings,cat).is_empty(),"A missing onward source permitted departure from the earned station")
	var plain:=Bindings.new()
	if not plain.open(base_directory,library.manifest):check(false,plain.error);return
	check(not plain.attach_nehma_source(source_directory,library.manifest) and plain.nehma_source_receipt().is_empty() and plain.dekato_source_receipt().is_empty(),"The new source bypassed explicit Dekato attachment")
	check(not plain.attach_dekato_source(source_directory,library.manifest),"An additive204 source replaced the exact203 save provenance")
	if not bindings.attach_nehma_source(source_directory,library.manifest):check(false,bindings.error);return
	check(Rules.available(bindings) and not bindings.nehma_source_receipt().is_empty(),"Explicit Néhma attachment lost its station declarations")
	check(original_identity==[bindings.base_content_id,bindings.binding_id,JSON.stringify(bindings.mido_travel).sha256_text(),bindings.dekato_source_receipt()],"Néhma attachment rewrote preceding raw data, identity or the sealed9 receipt")
	check(bindings.nehma_source_receipt().binding_id==bindings.dekato_source_receipt().source_binding_id,"The new declaration receipt skipped the actual203 predecessor")
	var retained_receipt: Dictionary=bindings.nehma_source_receipt()
	check(retained_receipt.is_read_only() and Rules.declarations(bindings).is_read_only(),"Attached source declarations are mutable")
	check(not bindings.attach_nehma_source(source_directory,library.manifest) and bindings.nehma_source_receipt()==retained_receipt,"A repeated attachment changed the retained source")
	var candidate:=Bindings.new()
	if not candidate.open(source_directory,library.manifest):check(false,candidate.error);return
	check(Rules.available(candidate) and archive.restore(candidate,cat,library,document)==null,"An independently identified204 pack was accepted as the original202 career")
	verify_source_identity(bindings,candidate,source_directory)
	check(Campaign.dialogue_rules(bindings,39,MISSION39).is_empty(),"Station-only Néhma dialogue opened in flight")
	for cursor in [39.0,40,38]:
		check(Rules.conversation(bindings,cursor,MISSION39).is_empty(),"A different or mistyped cursor selected Néhma39")
	for key in MISSION39:
		var wrong:=MISSION39.duplicate();wrong[key]+=1
		check(Rules.conversation(bindings,39,wrong).is_empty(),"A modified mission selected Néhma39: "+key)
	var extra:=MISSION39.duplicate();extra.extra=true
	check(Rules.conversation(bindings,39,extra).is_empty(),"Extra mission fields selected Néhma39")
	for language in library.manifest.languages:
		if not library.select_language(language):check(false,library.error);continue
		verify_dialogue(bindings,library,cat)
	if not library.select_language("gb"):check(false,library.error);return
	check(station.snapshot()==before and not station.begin_campaign_conversation(bindings,cat,library) and station.snapshot()==before,"The remote Néhma result altered the actual Dekato station")
	check(archive.capture(station,bindings)==document,"Optional station declarations changed the exact sealed9 document")
	check(not Campaign.supported(bindings.mido_travel,39) and not Campaign.supported(candidate.mido_travel,39) and not Campaign.supported(candidate.mido_travel,40),"Declarations opened incomplete onward flight or kind161")
	check(Campaign.supported(bindings,39) and Navigation.destination_supported(bindings,39,MISSION39,30) and not station.prepare_departure(bindings,cat).is_empty(),"The sourced retained39 station could not prepare onward travel")
	check(not Campaign.supported(bindings,39.0) and not Campaign.supported(bindings,40) and not Campaign.supported(plain,39) and not Campaign.supported(candidate,39),"A mistyped, unsourced or special successor cursor gained free flight")
	var flight: RefCounted=load("res://src/simulation/first_flight_construction.gd").new()
	if not flight.prepare_free(bindings,cat,station,4096,1789104672):check(false,flight.error);return
	var actual: Dictionary=flight.snapshot()
	check(actual.campaign_cursor==39 and actual.location.station_id==22 and actual.departure.player.campaign_cursor==39 and actual.departure.mission==MISSION39,"The real retained station did not construct its native39 departure")
	check(actual.departure.equipment.loadout==before.loadout and actual.departure.contracts.mission==before.contracts.mission and actual.departure.contracts.passengers==before.contracts.passengers,"Onward construction replaced the earned ship or independent passenger job")
	var restored: RefCounted=archive.restore(bindings,cat,library,document)
	check(restored!=null and restored.snapshot()==before and station.snapshot()==before,"Source validation mutated native career, equipment, passengers, pools or progress")
	completed=failures==0

func verify_source_identity(bindings: RefCounted,candidate: RefCounted,directory: String) -> void:
	var previous: Dictionary=bindings._nehma_parent_identity
	var current: Dictionary=candidate._nehma_identity
	check(Extension.receipt(previous,current)==bindings.nehma_source_receipt(),"The explicit source receipt differs from normal imported identities")
	for key in ["reader","base_content_id","source_executable_sha256","source_executable_bytes","architecture","preceding_payload_sha256"]:
		var wrong:=current.duplicate(true)
		wrong[key]="foreign" if wrong[key] is String else -1
		check(Extension.receipt(previous,wrong).is_empty(),"A foreign source identity was accepted: "+key)
	var wrong:=current.duplicate(true);wrong.binding_id=previous.binding_id
	check(Extension.receipt(previous,wrong).is_empty(),"The same binding pretended to be a new source")
	var header: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("bindings.json")))
	var body: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("registrations.json")))
	var changed:=body.duplicate(true);changed.mido_travel.free_flight.extra=true
	check(Extension.receipt(previous,Extension.describe(header,changed)).is_empty(),"Projection ignored an unrelated earlier declaration change")
	changed=body.duplicate(true);changed.mido_travel.provenance.erase(Rules.SPANS.keys()[0])
	check(Extension.receipt(previous,Extension.describe(header,changed)).is_empty(),"Projection accepted a missing new source extent")
	check(Extension.receipt({},current).is_empty() and Extension.receipt(previous,{}).is_empty(),"Missing source identities were accepted")

func verify_dialogue(bindings: RefCounted,library: RefCounted,cat: RefCounted) -> void:
	var rules:=Rules.conversation(bindings,39,MISSION39)
	var visit:=Visit.new()
	if not visit.configure_station(bindings,library,cat,39,MISSION39):check(false,visit.error);return
	# These are dialogue polling inputs only: no station/equipment/career owner
	# is moved to30 and no archive can be produced from this component.
	var context:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"station_id":22}
	check(visit.poll_station(context,true) and visit.snapshot().phase=="waiting","The Néhma result opened at actual Dekato22")
	context.station_id=30
	check(visit.poll_station(context,false) and visit.snapshot().phase=="waiting","The result opened before docking")
	check(visit.poll_station(context,true,true) and visit.snapshot().phase=="waiting","A blocked poll opened the result")
	check(visit.poll_station(context,true) and visit.snapshot().dialogue.count==10,"The landed dialogue component lost its ten original pages")
	check(not visit.navigate("previous") and visit.transition().is_empty(),"Opening the first page already completed the visit")
	for index in 10:
		var current: Dictionary=visit.snapshot()
		var line: Dictionary=current.dialogue
		check(current.campaign_cursor==39 and line.visible and line.index==index and line.text_id==int(rules.events[index].text_id) and line.speaker_id==int(rules.events[index].speaker_id) and line.voice_event_id==401+index and not line.text.is_empty(),"Wrong Néhma page/portrait/voice in "+library.active_language)
		check(visit.transition().is_empty(),"An intermediate page advanced the pending story")
		if index==1:
			check(visit.navigate("previous") and visit.snapshot().dialogue.index==0 and visit.navigate("next") and visit.snapshot()==current,"Previous/Next changed the pending result")
			var fork: RefCounted=visit.fork()
			check(fork.navigate("next") and visit.snapshot()==current,"Dialogue navigation mutated its retained parent")
		if not visit.navigate("next"):check(false,visit.error);return
	var receipt:=visit.transition()
	check(receipt.get("from_cursor")==39 and receipt.get("campaign_cursor")==40 and receipt.get("station_id")==30 and receipt.get("mission")==MISSION40 and receipt.get("reward_credits")==0,"Final Next lost the prospective original kind161 successor")
	check(not receipt.has("unlock_system_ids") and not receipt.has("next_course") and not rules.has("cargo_requirement"),"The station result invented access, a forced course or inventory transfer")
	var settled: Dictionary=visit.snapshot()
	check(not visit.navigate("next") and not visit.navigate("previous") and visit.snapshot()==settled,"The acknowledged component repeated its result")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
