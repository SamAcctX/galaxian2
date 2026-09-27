extends "res://tests/freelance_unlocked.gd"
## Detached combat/hold fixtures use genuine generated offer terms. Earned
## application travel and input-only pickup have their own acceptance pilot.
const Recovery=preload("res://src/simulation/tractor_recovery.gd")
const Cargo=preload("res://src/simulation/flight_cargo.gd")
const Progress=preload("res://src/simulation/contract_progress.gd")

func requested_contract_kind() -> int:return 6
func verify_contract_frame(_bindings: RefCounted,_frame: RefCounted,_accepted: Dictionary) -> void:pass

func verify_unlocked(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var file=load("res://src/simulation/station_save_file.gd").new()
	var archive=load("res://src/simulation/station_archive.gd").new()
	var document: Dictionary=file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library)
	if document.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	verify_contract_boundaries(bindings,cat,library,station)

func verify_contract_boundaries(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted) -> void:
	var original: Dictionary=station.snapshot()
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):check(false,bodies.error+effects.error);return
	for kind in [3,5]:
		var contracts: RefCounted=station.contract_owner().fork()
		var quote=load("res://src/simulation/contract_offer.gd").new()
		var context: Dictionary=contracts.snapshot().accepted_contact.offer.context.duplicate(true)
		context.campaign_cursor=original.campaign_cursor;context.rank=original.contracts.rank;context.reputation=original.contracts.reputation
		if not quote.configure(bindings,cat,context,{"kind":kind,"difficulty_index":1,"parameter_index":0,"quantity_index":0,"destination_station_id":original.loadout.station_id}):check(false,quote.error);return
		contracts._state.mission=quote.snapshot().mission
		contracts._state.accepted_contact.offer=quote.snapshot()
		contracts._state.passengers=0
		var construction:=Construction.new()
		if not construction._prepare_free_owned(bindings,cat,station.equipment_owner(),contracts,original.mission,{},4096,1789101890,false,bodies,effects):check(false,construction.error);return
		var frame=load("res://src/simulation/first_flight_frame.gd").new()
		if not frame.configure(bindings,cat,library,construction,"F",1.0):check(false,frame.error);return
		var initial: Dictionary=frame.snapshot();var actors: Array=initial.encounter.combat.actors
		if kind==3:
			verify_outer_station_contact(frame)
			if failures:return
		var carrier:=actors.size()-1
		check(actors.size()==quote.snapshot().mission.quantity and actors.all(func(actor):return actor.actor_kind==8 and actor.actor_mode==5 and not actor.active),"Recovery lost its quoted distant pirate group")
		check(actors[carrier].name_text_id==1600 and actors[carrier].special_cargo and not actors[carrier].special_cargo_accepted and not actors[carrier].special_cargo_rejected,"The Hijacker lost its name or cargo objective flags")
		check(actors.slice(0,carrier).all(func(actor):return not actor.get("special_cargo",false)),"Another fighter became the mission carrier")
		var path: Array=initial.encounter.combat.contract_encounter.path
		check(path.size()==1 and path[0].y==0 and absf(path[0].x)>=40000 and absf(path[0].x)<120000 and absf(path[0].z)>=40000 and absf(path[0].z)<120000,"The recovery cast lost its distant spawn")
		var branch: RefCounted=frame.fork_for_frame()
		branch._pose.origin=actors[carrier].pose.origin+Vector3(0,0,20000)
		for tick in 2:
			var next: RefCounted=branch.evaluate(0)
			if next==null:check(false,branch.error);return
			branch=next
		var combat: RefCounted=branch._encounter._combat
		if not combat.begin_contact_pass(branch.snapshot().random_state,true) or combat.normal_hit(carrier,actors[carrier].vitals.hull,false).is_empty():check(false,combat.error);return
		for tick in 160:
			var next: RefCounted=branch.evaluate(100)
			if next==null:check(false,branch.error);return
			branch=next
			var death: RefCounted=branch._encounter.npc_destruction_owner(carrier)
			if death!=null and death.snapshot().cargo.model_exists:break
		check(not branch.contract_result_pending(),"Destroying the carrier paid before its cargo was recovered")
		var life: Dictionary=branch._encounter.npc_destruction_owner(carrier).snapshot()
		var expected_item:=117 if kind==3 else 116
		check(life.cargo.entries==[{"item_id":expected_item,"quantity":1}],"The Hijacker dropped unrelated cargo or the wrong recovery item")
		if failures:return
		verify_pickups(bindings,cat,library,station,branch,carrier,expected_item)
		if failures:return
		var abandoned: RefCounted=branch.fork_for_frame()
		# This expiry fixture leaves the battle, so player death cannot freeze
		# the world's container cleanup before its normal timeout.
		abandoned._pose.origin+=Vector3(0,1000000,0)
		for tick in 800:
			var next: RefCounted=abandoned.evaluate(100)
			if next==null:check(false,abandoned.error);return
			abandoned=next
			if abandoned.contract_result_pending():break
		check(abandoned.contract_result_pending() and abandoned.snapshot().contracts.pending_result.failed,"Uncollected mission cargo never expired into failure")
		check(frame.snapshot()==initial,"Cargo recovery or expiry changed the unplayed parent frame")
	check(station.snapshot()==original,"Recovery fixtures changed the earned station")

func verify_outer_station_contact(frame: RefCounted) -> void:
	# An outer wall lies beyond the proximity fallback. Its physical projection
	# must still permit docking, even though the final point is outside the box.
	var original: Dictionary=frame.snapshot()
	var flight: RefCounted=frame.fork_for_frame()
	for tick in 400:
		if flight._briefing.snapshot().entry_released:break
		var next: RefCounted=flight.evaluate(100)
		if next==null:check(false,flight.error);return
		flight=next
	var station: Dictionary=flight._station.snapshot()
	var position: Variant=null
	for shape in station.collision.get("shapes",station.collision.get("boxes",[])):
		if shape.get("kind",1)!=1:continue
		for x in [-0.9,0.9]:
			for y in [-0.9,0.9]:
				for z in [-0.9,0.9]:
					var point: Vector3=station.pose.origin+shape.center+shape.half_extents*Vector3(x,y,z)
					if point.length()<=float(flight._return_rules.contact_radius):continue
					var pose: Transform3D=flight._pose;pose.origin=point
					var plan: Dictionary=flight._physical_contacts.plan(flight._player.collision_context(pose),flight._scenery.read_snapshot().get("bodies",{}),true)
					if not plan.is_empty() and plan.center_after!=point and flight._station.point_volume(plan.center_after)<0:position=point
	check(position!=null,"The imported station has no outer wall for the docking regression")
	if position==null:return
	flight._pose.origin=position;flight._statistics_pose=flight._pose
	if not flight._autopilot.observe_scripted_pose(flight._pose):check(false,flight._autopilot.error);return
	var before: Dictionary=flight.snapshot()
	var manual: RefCounted=flight.evaluate(0,Vector2.ZERO,0.0)
	if manual==null:check(false,flight.error);return
	check(manual._station_packet.is_empty() and manual._pose.origin!=position,"Touching the hull without selecting docking entered the station or lost physical projection")
	var selected: RefCounted=flight.start_station_autopilot()
	if selected==null:check(false,flight.error);return
	var landed: RefCounted=selected.evaluate(0,Vector2.ZERO,0.0)
	if landed==null:check(false,selected.error);return
	var packet: Dictionary=landed.prepare_station()
	check(not packet.is_empty(),"Station projection discarded docking contact beyond the proximity fallback")
	if not packet.is_empty():
		check(packet.docking.post_motion_volume_index<0 and packet.docking.position.length()>float(flight._return_rules.contact_radius),"The wall regression did not exercise projection outside the docking query")
		check(packet.player.vitals==before.player.vitals and packet.contracts.credits==before.contracts.credits and packet.campaign_cursor==before.campaign_cursor,"Outer-wall docking damaged the ship, paid an unfinished job or advanced the story")
	check(flight.snapshot()==before and frame.snapshot()==original,"Station contact mutated its retained parent frame")

func verify_pickups(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted,branch: RefCounted,id: int,item: int) -> void:
	var encounter: RefCounted=branch._encounter
	var original: Dictionary=encounter.snapshot()
	var life: Dictionary=encounter.npc_destruction_owner(id).snapshot()
	var body: Dictionary=encounter.combat_snapshot().actors[id]
	var player:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"pose":Transform3D(Basis.IDENTITY,life.cargo.pose.origin-Vector3(0,0,300)),"autopilot":false}
	var observed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"actor_id":id,"actor_kind":body.actor_kind,"actor_mode":4,"hull":0,"active":true,
		"cargo_eligible":true,"cargo_model_exists":true,"retire_on_transfer":life.retire_on_transfer,"body_pose":life.pose,"cargo_pose":life.cargo.pose,"cargo_entries":life.cargo.entries,"collision_centers":[],
		"friendly":false,"statistics_exempt":false,"body_motion_blocked":false,"body_motion_detached":false,"special_cargo":true}
	for used in [0,25]:
		var tractor:=Recovery.new();var hold:=Cargo.new()
		if not tractor.configure(bindings,cat,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":0,"equipment_ids":[68,81]}):check(false,tractor.error);return
		hold._state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":0,"capacity":25,"used":used,"entries":[] if used==0 else [{"item_id":118,"quantity":used}]}
		hold._item_count=cat.tables.items.size();hold._recovery_cargo_ids=[116,117];hold._equipment_ids=[68,81]
		if not hold.bind_recovery(tractor) or not tractor.queue_acquired_wreck(observed):check(false,hold.error+tractor.error);return
		var started: Dictionary=encounter.evaluate_cargo_recovery(tractor,hold,0,player)
		if started.is_empty():check(false,encounter.error);return
		var picked: Dictionary=started.encounter.evaluate_cargo_recovery(started.tractor,started.cargo,0,player)
		if picked.is_empty():check(false,started.encounter.error);return
		var won: bool=used==0
		var carrier: Dictionary=picked.encounter.combat_snapshot().actors[id]
		check(carrier.special_cargo_accepted==won and carrier.special_cargo_rejected!=won,"The real transfer lost its accepted/full-hold cargo flags")
		check(picked.cargo.snapshot().entries==([{ "item_id":item,"quantity":1,"mission":true }] if won else hold.snapshot().entries),"Recovery failed to retain exactly one marked mission item")
		var control: RefCounted=picked.encounter._control
		if not control.sample_scene_clock(20000,5001):check(false,control.error);return
		var career: RefCounted=branch.contract_owner()
		var before: Dictionary=career.snapshot()
		var result: Dictionary=career.evaluate_flight(control)
		if result.is_empty():check(false,career.error);return
		check(result.opened and result.session.snapshot().credits==before.credits and result.session.snapshot().completed_side_missions==before.completed_side_missions,"Pickup paid or counted a job before the client delivery")
		var pending: Dictionary=result.session.snapshot().pending_result
		var resumed: Dictionary=result.session.acknowledge_flight_result(result.controller,pending.serial)
		if resumed.is_empty():check(false,result.session.error);return
		var after: Dictionary=resumed.session.snapshot()
		check(after.credits==before.credits and after.campaign_cursor==before.campaign_cursor,"Pickup acknowledgement paid or advanced the story")
		check(resumed.session.acknowledge_flight_result(resumed.controller,pending.serial).is_empty(),"Pickup could be acknowledged twice")
		if won:
			check(after.mission.kind==11 and after.mission.station_id==before.accepted_contact.station_id and after.mission.briefing_text_id==792 and after.passengers==0 and after.accepted_contact==before.accepted_contact,"The return leg changed its original client/terms or occupied passenger berths")
			check(pending.result_text_id==378 and pending.station_id==after.mission.station_id,"The intermediate result lost its client destination")
			var retained: RefCounted=resumed.session.finish_flight(resumed.controller,true)
			if retained==null:check(false,resumed.session.error);return
			var equipment: RefCounted=station.equipment_owner().fork()
			if not equipment.retain_flight_cargo(picked.cargo.snapshot()):check(false,equipment.error);return
			var checkpoint: RefCounted=station.fork()
			checkpoint._contracts=retained.fork();checkpoint._equipment=equipment.fork()
			checkpoint._state.cargo=equipment.snapshot().cargo
			checkpoint._state.progress=retained.snapshot().progress
			var archive=load("res://src/simulation/station_archive.gd").new()
			var document: Dictionary=archive.capture(checkpoint,bindings)
			if document.is_empty():check(false,archive.error);return
			var restored: RefCounted=archive.restore(bindings,cat,library,document)
			if restored==null:check(false,archive.error);return
			check(restored.snapshot().contracts.mission==after.mission and restored.snapshot().contracts.accepted_contact==before.accepted_contact and restored.snapshot().contracts.passengers==0,"Saving the return leg lost its objective or invented cabin passengers")
			var invalid: Dictionary=document.duplicate(true);invalid.career.contract_phase="unknown"
			check(archive.restore(bindings,cat,library,invalid)==null,"A save with an unearned continuation phase was accepted")
			invalid=document.duplicate(true);invalid.career.mission.reward+=1
			check(archive.restore(bindings,cat,library,invalid)==null,"A saved return job changed its generated reward")
			var arrival: Dictionary=equipment.snapshot().duplicate(true)
			arrival.loadout.station_id=after.mission.station_id
			if not retained._poll_station_results(arrival):check(false,retained.error);return
			var delivered: RefCounted=retained._acknowledge_delivery_inventory(equipment,arrival)
			if delivered==null:check(false,retained.error);return
			var paid: Dictionary=retained.snapshot()
			check(paid.mission.is_empty() and not paid.has("contract_phase") and paid.credits==before.credits+before.mission.reward+before.mission.bonus and paid.completed_side_missions==before.completed_side_missions+1,"Client delivery lost or duplicated the earned reward")
			check(delivered.snapshot().cargo.entries.is_empty() and paid.delivery_statistics.passengers==before.delivery_statistics.passengers+before.mission.quantity,"Return delivery kept mission cargo or lost the original career statistic")
			var malformed: Dictionary=after.duplicate(true);malformed.mission.station_id=before.mission.station_id
			check(Progress.matches(after,after.accepted_contact.offer,cat) and not Progress.matches(malformed,after.accepted_contact.offer,cat),"Continuation validation accepted a changed return destination")
		else:check(after.mission.is_empty() and after.accepted_contact.is_empty() and not after.has("contract_phase"),"A rejected pickup kept the failed contract")
		check(encounter.snapshot()==original and career.snapshot()==before,"Cargo/result transactions corrupted their retained parent")
