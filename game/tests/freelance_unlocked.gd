extends "res://tests/ordinary_contracts.gd"
## Retained post-unlock offers, native inventory and checked save boundaries.
## The local relocation below is an explicit component fixture; application
## navigation and input-only combat are separate acceptance checks.

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_unlocked(args)
	else:check(false,"Expected original content, binding and visual paths")
	print("Unlocked freelance: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_unlocked(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var file=preload("res://src/simulation/station_save_file.gd").new()
	var archive=preload("res://src/simulation/station_archive.gd").new()
	var source: Dictionary=file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library)
	if source.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,source)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot()
	if original.contracts.mission.get("kind")!=4:check(false,"The retained save has no accepted Pirate job");return
	var accepted: Dictionary=station.snapshot()
	var path:="user://unlocked-freelance.gof2save"
	if not file.save(path,station,bindings,cat,library):check(false,file.error);return
	var document: Dictionary=file.load_document(path,bindings,cat,library)
	var restored: RefCounted=archive.restore(bindings,cat,library,document)
	if restored==null:check(false,archive.error);return
	check(restored.snapshot().contracts.accepted_contact==accepted.contracts.accepted_contact,"Resume rerolled the accepted client or job")
	# Explicit later-story boundary fixtures verify retention only. They do not
	# advance the saved campaign or claim an earned journey to those chapters.
	var retained_job: RefCounted=restored.contract_owner()
	for cursor in [40,41]:
		var later: RefCounted=retained_job.fork();later._state.campaign_cursor=cursor
		check(later._selected40_side_slot_valid(bindings) and later.snapshot().mission==accepted.contracts.mission,"A selected story discarded its independent accepted Pirate job")
		var invalid: RefCounted=later.fork();invalid._state.passengers=1
		check(not invalid._selected40_side_slot_valid(bindings),"A retained Pirate job acquired unowned passengers")
		invalid=later.fork();invalid._state.accepted_contact=invalid._state.accepted_contact.duplicate(true);invalid._state.accepted_contact.offer.mission={}
		check(not invalid._selected40_side_slot_valid(bindings) and later._selected40_side_slot_valid(bindings),"A changed accepted client reached a selected story or corrupted its parent")
	var departure:=Construction.new()
	if not departure.prepare_free(bindings,cat,restored,4096,1789100000):check(false,departure.error);return
	var equipment: RefCounted=restored.equipment_owner();var contracts: RefCounted=restored.contract_owner()
	var target: int=accepted.contracts.mission.station_id
	var route: Dictionary=preload("res://src/content/mido_travel_definitions.gd").route(bindings,int(accepted.campaign_cursor),int(accepted.loadout.station_id),target)
	if route.is_empty():check(false,"The selected job has no local route");return
	var arrival:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":int(accepted.campaign_cursor),"from_station_id":int(accepted.loadout.station_id),"station_id":target,"system_id":int(route.system_id),"source_state":int(bindings.mido_travel.travel.source_state),"world_type":int(bindings.mido_travel.travel.world_type),"audio_selector":int(bindings.mido_travel.travel.audio_selector)}
	if not equipment.relocate_local_arrival(bindings,cat,arrival) or not contracts.rebase_station(equipment,bindings):check(false,equipment.error+contracts.error);return
	var destination:=Construction.new()
	var bodies=preload("res://src/content/scenery_body_resources.gd").new()
	var effects=preload("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	if not destination._prepare_free_owned(bindings,cat,equipment,contracts,accepted.mission,{},4096,1789100000,true,bodies,effects):check(false,destination.error);return
	var context: RefCounted=destination.mission_context_owner()
	check(context!=null and not context.advances_campaign(),"Selected freelance flight acquired campaign advancement")
	var frame=preload("res://src/simulation/first_flight_frame.gd").new()
	if not frame.configure(bindings,cat,library,destination,"F",1.0):check(false,frame.error);return
	var world: Dictionary=frame.snapshot()
	check(world.contracts.mission==accepted.contracts.mission and world.campaign_cursor==accepted.campaign_cursor,"Entering the target discarded the job or advanced the campaign")
	check(not world.encounter.combat.actors.is_empty() and world.encounter.combat.actors.all(func(actor):return actor.actor_kind==8),"The selected job constructed ambient traffic instead of pirates")
	# An explicit contact fixture isolates retirement/payment from the pilot.
	# Fork before moving or damaging anything so the accepted world stays intact.
	var branch: RefCounted=frame.fork_for_frame()
	for actor in world.encounter.combat.actors:
		branch._pose.origin=actor.pose.origin+Vector3(0,0,20000)
		for tick in 2:
			var next: RefCounted=branch.evaluate(0)
			if next==null:check(false,branch.error);return
			branch=next
	var combat: RefCounted=branch._encounter._combat
	if not combat.begin_contact_pass(branch.snapshot().random_state,true):check(false,combat.error);return
	for actor in combat.snapshot().actors:
		var hit: Dictionary=combat.normal_hit(actor.actor_id,actor.vitals.hull,false)
		if hit.is_empty() or not hit.destroyed_now:check(false,combat.error);return
	for tick in 140:
		var next: RefCounted=branch.evaluate(100)
		if next==null:check(false,branch.error);return
		branch=next
		if branch.contract_result_pending():break
	var pending: Dictionary=branch.snapshot()
	check(branch.contract_result_pending() and pending.encounter.combat.actors.all(func(actor):return actor.actor_mode==4),"Retiring the admitted pirates did not finish the job")
	check(frame.snapshot()==world,"Freelance retirement mutated the parent frame")
	check(pending.progress.player_kills==world.progress.player_kills+world.encounter.combat.actors.size(),"Retirement lost actual player kill credit")
	check(pending.contracts.credits==world.contracts.credits,"Retirement paid before acknowledgement")
	if failures:return
	var paid: RefCounted=branch.acknowledge_contract_result(pending.contracts.pending_result.serial)
	if paid==null:check(false,branch.error);return
	check(paid.snapshot().contracts.credits==world.contracts.credits+accepted.contracts.mission.reward+accepted.contracts.mission.bonus and paid.snapshot().campaign_cursor==world.campaign_cursor,"Acknowledgement lost its reward or advanced the campaign")
	check(paid.acknowledge_contract_result(pending.contracts.pending_result.serial)==null,"Freelance acknowledgement paid twice")
	var approach: RefCounted=paid.start_station_autopilot()
	if approach==null:check(false,paid.error);return
	approach._pose.origin=approach._station.snapshot().pose.origin
	var landed: RefCounted=approach.evaluate(0)
	if landed==null:check(false,approach.error);return
	check(not landed.prepare_station().is_empty() and landed.prepare_station().contracts.credits==paid.snapshot().contracts.credits,"The acknowledged job could not return to its actual station")
