extends "res://tests/ordinary_contracts.gd"
## Explicit component branches use an earned accepted career. Application
## acceptance separately flies a genuine Escort offer with player input.

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_escort(args)
	else:check(false,"Expected content, bindings and visual paths")
	print("Escort cast: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_escort(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var file=load("res://src/simulation/station_save_file.gd").new()
	var archive=load("res://src/simulation/station_archive.gd").new()
	var document: Dictionary=file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library)
	if document.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot()
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	for faction in [0,1,2,3,4]:
		var contracts: RefCounted=station.contract_owner().fork()
		contracts._state.mission.kind=9;contracts._state.mission.station_id=int(original.loadout.station_id)
		contracts._state.accepted_contact.offer.mission=contracts._state.mission.duplicate(true)
		contracts._state.accepted_contact.offer.context.client_faction=faction
		var construction:=Construction.new()
		if not construction._prepare_free_owned(bindings,cat,station.equipment_owner(),contracts,original.mission,{},4096,1789103000,false,bodies,effects):check(false,construction.error);return
		var frame=load("res://src/simulation/first_flight_frame.gd").new()
		if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
		verify_cast_frame(frame,faction)
		if failures:return
	check(station.snapshot()==original,"Escort branches changed the earned source station")

func verify_cast_frame(frame: RefCounted,faction: int) -> void:
	var original: Dictionary=frame.snapshot()
	var actors: Array=original.encounter.combat.actors
	var split:=int(frame.mission_context_owner().recipe().result.success.end_actor)
	check(actors.size()==split+5,"Escort omitted a freighter from its convoy")
	var policy: Dictionary=frame._encounter._control._rules
	for id in actors.size():
		var row: Dictionary=actors[id];var freight: bool=id>=split
		check(row.active and row.actor_mode==0 and row.friendly==freight and row.hostile!=freight,"Escort changed its initial friendship or activation")
		if freight:
			check(row.subtype==1 and row.population_group=="freighter" and not row.point_boxes.is_empty() and row.vitals.hull==row.max_hull,"The convoy lacks a healthy large-ship body or collision boxes")
			check(row.actor_kind==(faction if faction<4 else 0),"The convoy has another client's faction")
			check(policy.npc_weapons[id].get("unarmed",false),"The cargo freighter gained a fighter weapon")
			check(frame._encounter.freighter_assembly(id).size()>0,"The convoy lost its original modular ship")
		else:
			check(row.actor_kind==(int([1,0,3,2][faction]) if faction<4 else 8),"Attackers ignored the client's opposing faction")
			check(policy.target_memberships[id].back()==-1 and policy.target_memberships[id].slice(0,-1)==range(split,actors.size()),"Attackers did not prioritize the convoy")
	var stepped: RefCounted=frame.evaluate(100)
	if stepped==null:check(false,frame.error);return
	for id in range(split,actors.size()):
		check(stepped.snapshot().encounter.combat.actors[id].position==actors[id].position+Vector3(0,0,100),"A cruising freighter did not advance along its original forward axis")
	check(frame.snapshot()==original,"Convoy movement changed the retained parent frame")
	if faction!=0:return
	var runner: RefCounted=frame._encounter._control._mission_runner.fork()
	var observed: Array=actors.duplicate(true)
	for id in range(split,actors.size()-1):observed[id].actor_mode=4;observed[id].vitals.hull=0
	check(not runner.observe(observed).failed,"Losing only some freighters failed the mission")
	observed.back().vitals.hull=0;observed.back().actor_mode=3
	check(not runner.observe(observed).failed,"An unfinished freighter explosion ended the mission")
	observed.back().actor_mode=4
	check(runner.sample_clock(5001,5001) and runner.poll(observed,true,true).mode==2,"The lost convoy did not fail during radio")
	for won in [true,false]:
		var branch: RefCounted=frame.fork_for_frame()
		var combat: RefCounted=branch._encounter._combat.fork_for_frame();branch._encounter._combat=combat
		if not combat.begin_contact_pass(original.random_state,true):check(false,combat.error);return
		for id in (range(split) if won else range(split,actors.size())):
			if combat.normal_hit(id,actors[id].vitals.hull,false).is_empty():check(false,combat.error);return
		for tick in 200:
			var next: RefCounted=branch.evaluate(100)
			if next==null:check(false,branch.error);return
			branch=next
			if branch.contract_result_pending():break
		var pending: Dictionary=branch.snapshot()
		check(branch.contract_result_pending() and pending.contracts.pending_result.get("completed")==won,"The retired cast did not produce the expected Escort result")
		if failures:return
		var serial:=int(pending.contracts.pending_result.serial)
		var paid: RefCounted=branch.acknowledge_contract_result(serial)
		if paid==null:check(false,branch.error);return
		var job: Dictionary=original.contracts.mission
		check(paid.snapshot().contracts.credits==original.contracts.credits+(int(job.reward)+int(job.bonus) if won else 0) and paid.snapshot().campaign_cursor==original.campaign_cursor,"Escort settlement changed the campaign or payment")
		check(paid.acknowledge_contract_result(serial)==null,"Escort paid more than once")
	check(frame.snapshot()==original,"Escort loss or success corrupted the retained parent frame")
