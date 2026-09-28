extends "res://tests/ordinary_contracts.gd"
## Real generated quotation; detached combat branches isolate collateral and
## deferred settlement. The application pilot separately supplies flight input.

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_informer(args)
	else:check(false,"Expected content, bindings and visual paths")
	print("Informer contract: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify_informer(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var file=load("res://src/simulation/station_save_file.gd").new();var archive=load("res://src/simulation/station_archive.gd").new()
	var station: RefCounted=archive.restore(bindings,cat,library,file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library))
	if station==null:check(false,file.error+archive.error);return
	var original: Dictionary=station.snapshot();var contracts: RefCounted=station.contract_owner().fork()
	var chosen: int=-1
	for id in contracts.snapshot().offers:
		var quote: Dictionary=contracts.snapshot().offers[id].offer
		if quote.mission.kind==13 and quote.mission.station_id==original.loadout.station_id:chosen=id;break
	if chosen<0:check(false,"The earned lounge has no local Informer quotation");return
	var equipment: RefCounted=contracts.accept(chosen,station.equipment_owner(),true,bindings)
	if equipment==null:check(false,contracts.error);return
	var accepted: Dictionary=contracts.snapshot()
	check(contracts.poll_station(equipment,bindings) and contracts.snapshot()==accepted,"The untouched Informer job settled without flying")
	var bodies=load("res://src/content/scenery_body_resources.gd").new();var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var construction:=Construction.new()
	if not construction._prepare_free_owned(bindings,cat,equipment,contracts,original.mission,{},4096,1789103300,false,bodies,effects):check(false,construction.error);return
	var frame=load("res://src/simulation/first_flight_frame.gd").new()
	if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
	var initial: Dictionary=frame.snapshot();var actors: Array=initial.encounter.combat.actors
	check(actors.size()==7 and actors[0].name_text_id==1652 and actors.slice(1).all(func(actor):return not actor.has("name_text_id")),"The security patrol lost its uniquely named spy")
	check(actors.all(func(actor):return actor.population_group=="patrol" and actor.active and actor.actor_mode==0 and actor.vitals.hull>0),"The security patrol cannot fly or take damage")
	var moving: RefCounted=frame
	for tick in 20:
		var next: RefCounted=moving.evaluate(100)
		if next==null:check(false,moving.error);return
		moving=next
	check(moving.snapshot().encounter.combat.actors.any(func(actor):return actor.position!=actors[actor.actor_id].position),"The security patrol remained frozen")
	var disabled: RefCounted=frame.fork_for_frame()
	var systems: RefCounted=disabled._encounter._combat.fork_for_frame();disabled._encounter._combat=systems
	if not systems.begin_contact_pass(initial.random_state,true) or systems.systems_hit(0,int(actors[0].systems.capacity),false).is_empty():check(false,systems.error);return
	disabled=disabled.evaluate(100)
	if disabled==null:check(false,"The disabled spy could not advance its frame");return
	check(disabled.snapshot().encounter.combat.actors[0].systems_disabled and disabled.snapshot().encounter.combat.actors[0].vitals.hull==actors[0].vitals.hull and not disabled.snapshot().contracts.has("station_outcome"),"An EMP killed the spy or incorrectly completed the objective")
	for targets in [[0],[1],[0,1],[1,0]]:
		var branch: RefCounted=frame.fork_for_frame()
		for target in targets:
			branch=hit_frame(branch,int(target),int(actors[target].vitals.hull))
			if branch==null:return
			check(not branch.contract_result_pending(),"A deferred objective froze flight or opened its result before docking")
			if target==0 and targets.front()==0:
				check(branch.snapshot().contracts.station_outcome==1,"The spy's destruction did not record a return objective")
		var won: bool=targets==[0]
		var career: RefCounted=branch.contract_owner()
		var retained: RefCounted=career.finish_flight(branch._encounter._control,true)
		if retained==null:check(false,career.error);return
		var arrived: Dictionary=retained.snapshot()
		check(arrived.station_outcome==(1 if won else 2) and arrived.credits==accepted.credits and arrived.completed_side_missions==accepted.completed_side_missions,"Flight paid early or lost collateral precedence")
		if won:
			var return_cast:=Construction.new()
			if not return_cast._prepare_free_owned(bindings,cat,equipment,retained,original.mission,{},4096,1789103301,false,bodies,effects):check(false,return_cast.error);return
			var returned=load("res://src/simulation/first_flight_frame.gd").new()
			if not returned.configure(bindings,cat,library,return_cast,"F",1.0):check(false,returned.error);return
			var survivors: Array=returned.snapshot().encounter.combat.actors
			check(survivors.size()==6 and survivors.all(func(actor):return not actor.has("name_text_id")),"Re-entering the system respawned the defeated spy")
			var collateral: RefCounted=hit_frame(returned,0,int(survivors[0].vitals.hull))
			if collateral==null:return
			check(collateral.snapshot().contracts.station_outcome==2,"Collateral after re-entry did not cancel the pending success")
		var checkpoint: RefCounted=station.fork();checkpoint._contracts=retained.fork();checkpoint._equipment=equipment.fork();checkpoint._state.progress=arrived.progress
		var document: Dictionary=archive.capture(checkpoint,bindings)
		if document.is_empty():check(false,archive.error);return
		var restored: RefCounted=archive.restore(bindings,cat,library,document)
		if restored==null:check(false,archive.error);return
		check(restored.snapshot().contracts.station_outcome==arrived.station_outcome,"The save lost the observed station result")
		var invalid: Dictionary=document.duplicate(true);invalid.career.station_outcome=3
		check(archive.restore(bindings,cat,library,invalid)==null,"An invalid station outcome entered the career")
		# Settlement accepts any station, so a detached arrival at another system
		# location must also open the retained result. Input travel is separate.
		var inventory: Dictionary=equipment.snapshot();inventory.loadout.station_id=38
		if not retained._poll_station_results(inventory,equipment):check(false,retained.error);return
		var pending: Dictionary=retained.snapshot()
		check(pending.pending_result.completed==won and pending.pending_result.station_id==38 and pending.credits==accepted.credits,"Docking failed to open the right result at another station")
		check(retained._poll_station_results(inventory,equipment) and retained.snapshot()==pending,"Repeated station polling repeated standing changes")
		var settled: RefCounted=retained._acknowledge_delivery_inventory(equipment,inventory)
		if settled==null:check(false,retained.error);return
		var paid: Dictionary=retained.snapshot()
		check(paid.credits==accepted.credits+(accepted.mission.reward+accepted.mission.bonus if won else 0) and paid.completed_side_missions==accepted.completed_side_missions+int(won),"The station paid the wrong outcome")
		check(paid.mission.is_empty() and not paid.has("station_outcome") and paid.campaign_cursor==original.campaign_cursor and paid.delivery_statistics==accepted.delivery_statistics and settled.snapshot().cargo==equipment.snapshot().cargo,"Station settlement changed story, cargo or delivery statistics")
		check(retained._acknowledge_delivery_inventory(equipment,inventory)==null,"The station result paid twice")
	var nonlethal: RefCounted=hit_frame(frame,1,1)
	if nonlethal==null:return
	check(not nonlethal.snapshot().contracts.has("station_outcome"),"A nonlethal hit failed the job")
	check(frame.snapshot()==initial and station.snapshot()==original,"A combat or settlement branch changed its parent")

func hit_frame(frame: RefCounted,id: int,damage: int) -> RefCounted:
	var branch: RefCounted=frame.fork_for_frame()
	var combat: RefCounted=branch._encounter._combat.fork_for_frame();branch._encounter._combat=combat
	if not combat.begin_contact_pass(branch.snapshot().random_state,true) or combat.normal_hit(id,damage,false).is_empty():check(false,combat.error);return null
	var next: RefCounted=branch.evaluate(100)
	if next==null:check(false,branch.error)
	return next
