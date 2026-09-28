extends "res://tests/ordinary_contracts.gd"
## Detached component branches cover each generated convoy size and faction.
## The application pilot separately accepts and flies a genuine lounge offer.

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_intercept(args)
	else:check(false,"Expected content, bindings and visual paths")
	print("Intercept cast: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify_intercept(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var file=load("res://src/simulation/station_save_file.gd").new();var archive=load("res://src/simulation/station_archive.gd").new()
	var station: RefCounted=archive.restore(bindings,cat,library,file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library))
	if station==null:check(false,file.error+archive.error);return
	var original: Dictionary=station.snapshot()
	var bodies=load("res://src/content/scenery_body_resources.gd").new();var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	var retained_cargo:=false
	for variant in 10:
		var faction:=variant%5;var seen:=[]
		var contracts: RefCounted=station.contract_owner().fork()
		contracts._state.difficulty=0.5 if variant<5 else 1.0
		contracts._state.mission.kind=10;contracts._state.mission.station_id=int(original.loadout.station_id)
		contracts._state.accepted_contact.offer.mission=contracts._state.mission.duplicate(true)
		contracts._state.accepted_contact.offer.context.client_faction=faction
		for sample in 20:
			var construction:=Construction.new()
			if not construction._prepare_free_owned(bindings,cat,station.equipment_owner(),contracts,original.mission,{},4096,1789103500+sample,false,bodies,effects):check(false,construction.error);return
			var frame=load("res://src/simulation/first_flight_frame.gd").new()
			if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
			var split:=int(frame.mission_context_owner().recipe().result.success.end_actor)
			if split in seen:continue
			seen.append(split)
			verify_cast(frame,faction)
			retained_cargo=retained_cargo or frame._encounter._control._initial_actors.slice(0,split).any(func(actor):return not actor.cargo.is_empty())
			if faction==0:verify_objective(frame)
			if failures:return
			if seen.size()==2:break
		check(2 in seen and 3 in seen,"The generated population never produced both convoy sizes")
	check(retained_cargo,"All generated freighters discarded their recoverable goods")
	check(station.snapshot()==original,"Intercept branches changed their earned source station")

func verify_cast(frame: RefCounted,client_faction: int) -> void:
	var original: Dictionary=frame.snapshot();var actors: Array=original.encounter.combat.actors
	var split:=int(frame.mission_context_owner().recipe().result.success.end_actor)
	var policy: Dictionary=frame._encounter._control._rules
	var faction:=int([1,0,3,2][client_faction]) if client_faction<4 else 0
	check(split in [2,3] and actors.size()>split,"The Intercept cast lost its freighters or guards")
	for id in actors.size():
		var actor: Dictionary=actors[id]
		check(actor.active and actor.hostile and not actor.friendly and actor.actor_kind==faction and policy.target_memberships[id]==[-1],"The Intercept force is inactive, targets itself or uses another faction")
		if id<split:
			check(actor.subtype==1 and actor.population_group=="freighter" and actor.vitals.hull==actor.max_hull and not actor.point_boxes.is_empty(),"An Intercept freighter lacks its full hull or collision geometry")
			check(policy.npc_weapons[id].get("unarmed",false) and frame._encounter.freighter_assembly(id).size()>0,"The freighter lost its assembled model or gained a fighter weapon")
			check(actor.position.x>=-12500 and actor.position.x<12500 and actor.position.y>=-12500 and actor.position.y<12500 and actor.position.z>=110000 and actor.position.z<160000,"A freighter was placed outside the rear convoy region")
			check(frame._encounter._control._initial_actors[id].cargo.all(func(row):return row.quantity>=8),"Freighter goods kept small-fighter quantities")
		else:check(actor.subtype==0 and actor.population_group=="patrol" and not policy.npc_weapons[id].get("unarmed",false),"A guard was replaced by another freighter or lost its gun")
	var stepped: RefCounted=frame.evaluate(100)
	if stepped==null:check(false,frame.error);return
	for id in split:check(stepped.snapshot().encounter.combat.actors[id].position==actors[id].position,"A stationary Intercept freighter cruised away")
	check(frame.snapshot()==original,"Advancing the Intercept cast changed its retained parent")

func verify_objective(frame: RefCounted) -> void:
	var original: Dictionary=frame.snapshot();var actors: Array=original.encounter.combat.actors
	var split:=int(frame.mission_context_owner().recipe().result.success.end_actor)
	var guards: RefCounted=damage_branch(frame,range(split,actors.size()))
	if guards==null:return
	guards=retire_branch(guards)
	if guards==null:return
	check(not guards.contract_result_pending() and guards.snapshot().encounter.combat.actors.slice(split).all(func(actor):return actor.actor_mode==4),"Defeating only the guards completed Intercept")
	var partial: RefCounted=damage_branch(frame,range(split-1))
	if partial==null:return
	partial=retire_branch(partial)
	if partial==null:return
	check(not partial.contract_result_pending(),"A surviving freighter did not keep the objective open")
	var branch: RefCounted=damage_branch(partial,[split-1])
	if branch==null:return
	check(not branch.contract_result_pending(),"The last hit paid before the freighter's explosion")
	branch=retire_branch(branch)
	if branch==null:return
	var pending: Dictionary=branch.snapshot()
	check(branch.contract_result_pending() and pending.contracts.pending_result.completed and pending.encounter.combat.actors.slice(split).all(func(actor):return actor.vitals.hull>0),"Destroying the convoy still required its surviving guards")
	if failures:return
	var serial:=int(pending.contracts.pending_result.serial)
	var paid: RefCounted=branch.acknowledge_contract_result(serial)
	if paid==null:check(false,branch.error);return
	check(paid.snapshot().contracts.credits==original.contracts.credits+original.contracts.mission.reward+original.contracts.mission.bonus and paid.snapshot().campaign_cursor==original.campaign_cursor,"Intercept paid the wrong amount or changed the campaign")
	check(paid.acknowledge_contract_result(serial)==null and frame.snapshot()==original,"Repeated Intercept acknowledgement paid again or changed its parent")

func damage_branch(frame: RefCounted,targets: Array) -> RefCounted:
	var branch: RefCounted=frame.fork_for_frame();var state: Dictionary=branch.snapshot()
	var combat: RefCounted=branch._encounter._combat.fork_for_frame();branch._encounter._combat=combat
	if not combat.begin_contact_pass(state.random_state,true):check(false,combat.error);return null
	for id in targets:
		if combat.normal_hit(id,state.encounter.combat.actors[id].vitals.hull,false).is_empty():check(false,combat.error);return null
	return branch

func retire_branch(frame: RefCounted) -> RefCounted:
	var branch: RefCounted=frame
	for tick in 180:
		var next: RefCounted=branch.evaluate(100)
		if next==null:check(false,branch.error);return null
		branch=next
		if branch.contract_result_pending():break
	return branch
