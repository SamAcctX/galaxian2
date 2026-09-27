extends "res://tests/mission_presentation.gd"
## The real earned station checkpoint exercises the recipe/save boundary.
## This component test does not substitute for the rendered player journey.
const Archive=preload("res://src/simulation/station_archive.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const StationVisit=preload("res://src/simulation/station_mission_visit.gd")
var cat: RefCounted

func _initialize() -> void:call_deferred("run_station")

func run_station() -> void:
	if not prepare_content(OS.get_cmdline_user_args()):finish();return
	cat=load("res://src/content/catalogues.gd").new()
	if not cat.open(library):check(false,cat.error);finish();return
	var path:=OS.get_environment("GOF2_ENDING_EARNED_SAVE")
	var bytes:=FileAccess.get_file_as_bytes(path)
	var file:=Save.new();var archive:=Archive.new()
	var original: Dictionary=file.load_document(path,bindings,cat,library)
	if original.is_empty():check(false,file.error);finish();return
	var station: RefCounted=archive.restore(bindings,cat,library,original)
	if station==null:check(false,archive.error);finish();return
	var before: Dictionary=station.snapshot();var career: Dictionary=before.contracts
	check(before.campaign_cursor==43 and before.loadout.station_id==10 and career.passengers==3,"Expected the earned Thynome return with its independent passengers")
	verify_poll(station)
	check(not station.campaign_conversation_ready(bindings,cat,library,1000) and station.campaign_conversation_ready(bindings,cat,library,1001),"Station result ignored its strict one-second readiness gate")
	var pending: RefCounted=station.fork()
	if not pending.begin_campaign_conversation(bindings,cat,library,1001):check(false,pending.error);finish();return
	check(pending.snapshot().dialogue.voice_event_id==425 and pending.acknowledge() and pending.snapshot().dialogue.voice_event_id==426,"The drink invitation lost its two authored speakers/voices")
	check(pending.acknowledge() and pending.snapshot().phase=="presentation_required","The invitation did not request its presentation")
	check(station.snapshot()==before and pending.snapshot().contracts==career and pending.snapshot().campaign_cursor==43,"Starting credits mutated the parent or paid/advanced the career")
	check(not pending.acknowledge() and archive.capture(pending,bindings).is_empty(),"Repeated input or saving bypassed the pending presentation")
	var sequence:=prepared()
	check(not pending.complete_presentation(sequence) and pending.snapshot().contracts==career,"An incomplete presentation advanced the career")
	while not sequence.snapshot().complete:
		if not sequence.advance(100):check(false,sequence.error);finish();return
	if not pending.complete_presentation(sequence):check(false,pending.error);finish();return
	var note: Dictionary=pending.snapshot()
	check(note.campaign_cursor==44 and note.contracts.credits==career.credits and note.arrival_player==before.arrival_player,"Finishing credits paid early or rewrote the arriving flight")
	check(note.mission_station_return.station_history==[43] and note.mission_station_return.source_cursor==42,"Finishing credits lost the original arrival receipt")
	check(not pending.complete_presentation(sequence) and pending.snapshot()==note,"A duplicate presentation completion changed the career")
	var checkpoint: Dictionary=archive.capture(pending,bindings)
	check(not checkpoint.is_empty(),archive.error)
	var resumed: RefCounted=archive.restore(bindings,cat,library,checkpoint)
	if resumed==null:check(false,archive.error);finish();return
	check(resumed.snapshot().contracts==note.contracts and resumed.presentation_request().is_empty(),"Resuming the note repeated the ending or changed the career")
	if not resumed.begin_campaign_conversation(bindings,cat,library,1001):check(false,resumed.error);finish();return
	var voices:=[]
	while resumed.snapshot().dialogue.visible:
		voices.append(resumed.snapshot().dialogue.voice_event_id)
		if not resumed.acknowledge():check(false,resumed.error);finish();return
	var paid: Dictionary=resumed.snapshot()
	check(voices==[427,428,429,430] and paid.campaign_cursor==45 and paid.mission.kind==-1,"The note lost its four lines or empty final mission")
	check(paid.contracts.credits==career.credits+40000 and paid.reward_credits==40000,"The final acknowledgement did not grant the promised payment once")
	for key in ["mission","passengers","accepted_contact","completed_side_missions","result_serial","blueprints","travel_statistics","delivery_statistics"]:
		check(paid.contracts[key]==career[key],"The ending changed independent career state: "+key)
	check(not resumed.acknowledge() and resumed.snapshot()==paid,"Duplicate final input repaid the ending")
	var paid_document: Dictionary=archive.capture(resumed,bindings)
	check(not paid_document.is_empty(),archive.error)
	var paid_resume: RefCounted=archive.restore(bindings,cat,library,paid_document)
	check(paid_resume!=null,archive.error)
	if paid_resume!=null:
		check(paid_resume.snapshot().contracts==paid.contracts and not paid_resume.campaign_conversation_ready(bindings,cat,library,100000),"Paid Resume replayed a station recipe or reward")
	verify_tampering(archive,paid_document)
	check(FileAccess.get_file_as_bytes(path)==bytes,"The component test changed its earned input file")
	print("Earned station recipes: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify_poll(station: RefCounted) -> void:
	var context: RefCounted=station.mission_station_context_owner()
	var seed: Dictionary=station.snapshot().loadout
	var visit:=StationVisit.new()
	check(visit.prepare(bindings,library,cat,context,1001) and visit.poll_station(seed,false) and not visit.snapshot().dialogue.visible,"An undocked observation completed a station recipe")
	check(visit.poll_station(seed,true,true) and not visit.snapshot().dialogue.visible,"A modal failed to block the station result")
	check(visit.poll_station(seed,true) and visit.snapshot().dialogue.visible,"The admitted station did not open its runner-owned result")
	var before: Dictionary=visit.snapshot();var branch: RefCounted=visit.fork()
	check(branch.navigate("next") and visit.snapshot()==before,"Candidate navigation changed the retained conversation")

func verify_tampering(archive: RefCounted,document: Dictionary) -> void:
	for history in [[44],[43,43],[43,44,44],[43.0,44]]:
		var changed:=document.duplicate(true);changed.station.mission_station_return.station_history=history
		check(archive.restore(bindings,cat,library,changed)==null,"A save skipped, duplicated or retyped a station acknowledgement")
	var changed:=document.duplicate(true);changed.station.reward_credits=0
	check(archive.restore(bindings,cat,library,changed)==null,"A paid save changed the acknowledged reward metadata")
	changed=document.duplicate(true);changed.station.arrival_player.campaign_cursor=44
	check(archive.restore(bindings,cat,library,changed)==null,"A station recipe rewrote its original arriving flight")
