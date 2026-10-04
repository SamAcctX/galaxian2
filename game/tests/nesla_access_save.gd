extends "res://tests/campaign_visit_save.gd"
## Reuse actual earned access checkpoints. No journey is replayed or synthesized.
const CANONICAL_SHA="d48230d070bd6c99b997487bfc2785beb1726f14cb5bfd11443205fdc0ec74ec"
const ORIGINAL_BINDING="3c3d6c0153e6b2444ab0f3edeefcfa99b33385a1e3b2aa59668c28331c302639"
const PREFIX={25:[5,0],15:[3,1],40:[8,2],30:[2,3],85:[17,4],20:[4,5]}

func verify_cursor38(bindings: RefCounted,cat: RefCounted,library: RefCounted,current: Dictionary) -> void:
	var source:=OS.get_environment("GOF2_SOURCE_SAVE")
	var expected:=OS.get_environment("GOF2_SOURCE_SAVE_SHA")
	var canonical:=OS.get_environment("GOF2_CANONICAL_SOURCE_SAVE")
	check(expected.length()==64 and FileAccess.get_sha256(source)==expected,"Use the retained producer's exact source file, not an invented access checkpoint")
	check(FileAccess.get_sha256(canonical)==CANONICAL_SHA and bindings.binding_id==ORIGINAL_BINDING,"Nesla verification changed the canonical save or original source identity")
	if failures:return
	var file:=SaveFile.new();var archive:=Archive.new()
	var document:=file.load_document(canonical,bindings,cat,library)
	var station:=archive.restore(bindings,cat,library,document)
	if station==null:check(false,file.error+archive.error);return
	var before: Dictionary=station.snapshot()
	var id: int=current.loadout.station_id
	check(PREFIX.has(id),"The actual access save is not on the source-defined prefix")
	if failures:return
	check(current.loadout.system_id==PREFIX[id][0] and current.campaign_cursor==38 and current.mission==before.mission and current.reward_credits==0,"Access travel changed the pending original assignment")
	check(current.binding_id==before.binding_id and current.base_content_id==before.base_content_id,"Access travel rebound the career")
	check(current.contracts.travel_statistics.jumpgates_used==before.contracts.travel_statistics.jumpgates_used+PREFIX[id][1],"The saved prefix omitted or invented a completed gate transit")
	for field in ["mission","passengers","accepted_contact","blueprints"]:
		check(current.contracts[field]==before.contracts[field],"Travel changed the independent retained contract or blueprint record: "+field)
	check(current.contracts.lounges.system_availability==before.contracts.lounges.system_availability,"Access travel granted an unrelated or expansion system")
	check(current.contracts.credits>=0 and current.contracts.credits<=before.contracts.credits and current.cargo.entries==before.cargo.entries,"The access trip granted money or cargo")
	var navigation=load("res://src/simulation/system_navigation.gd").new()
	if not navigation.configure(bindings,cat,current.contracts.lounges.system_availability):check(false,navigation.error);return
	var course: Dictionary=navigation.course(id,22)
	check(not course.is_empty() and course.system_path[-1]==4 and course.jump_count==5-int(PREFIX[id][1]),"The remaining source Eanya course changed")
	check(not load("res://src/content/free_navigation_definitions.gd").destination_supported(bindings,38,current.mission,22),"Saving an access prefix opened the incomplete Dekato story")
	var predecessor:=OS.get_environment("GOF2_PREDECESSOR_SOURCE_SAVE")
	if not predecessor.is_empty():
		var predecessor_sha:=OS.get_environment("GOF2_PREDECESSOR_SOURCE_SHA")
		check(predecessor_sha.length()==64 and FileAccess.get_sha256(predecessor)==predecessor_sha,"The final hop lost its original predecessor")
		if failures:return
		var prior_document:=file.load_document(predecessor,bindings,cat,library)
		var prior:=archive.restore(bindings,cat,library,prior_document)
		if prior==null:check(false,file.error+archive.error);return
		var start: Dictionary=prior.snapshot()
		check(start.loadout.station_id==85 and current.loadout.station_id==20 and current.contracts.credits==start.contracts.credits and current.cargo==start.cargo,"The final source-defined hop changed the saved wallet or cargo")
		check(current.contracts.travel_statistics.jumpgates_used==start.contracts.travel_statistics.jumpgates_used+1,"The retained last leg did not earn exactly one gate transit")
		for field in ["mission","passengers","accepted_contact","blueprints"]:check(current.contracts[field]==start.contracts[field],"The retained last leg changed "+field)
		check(FileAccess.get_sha256(predecessor)==predecessor_sha,"Archive verification changed the Genoh predecessor")
	check(SaveCompare.matches_older(archive.capture(station,bindings),document) and FileAccess.get_sha256(source)==expected and FileAccess.get_sha256(canonical)==CANONICAL_SHA,"Read-only comparison changed either retained checkpoint")
	print("Verified original202 access save ",expected," station ",id," completed gates ",PREFIX[id][1]," credits ",current.contracts.credits," remaining original course ",course.system_path)
