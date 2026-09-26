extends "res://tests/mission_escape_flight.gd"
## Reach the genuine escape boundary using the existing component's native
## flight and visible input. Detached initial poses remain component stimuli;
## this is not the earned end-to-end campaign or an autosaved continuation.
const ReturnEntry=preload("res://src/simulation/mission_portal_return.gd")

func verify_retained_flight() -> void:
	var early: RefCounted=active
	var early_before: Dictionary=early.snapshot()
	var premature:=ReturnEntry.new()
	check(not premature.prepare(bindings,catalogues,early) and premature.snapshot().is_empty(),"Return accepted a living Void frame before departure")
	check(not ReturnEntry.new().prepare(bindings,catalogues,Frame.new()),"An uninitialized frame authorized a return")
	# Spend an installed EMP through native input before the escape. Returning
	# the constructor's original inventory would incorrectly refund this round.
	var choices: Array=active.encounter_owner().secondary_choices()
	var paid: Array=choices.filter(func(choice):return choice.item_id==42)
	if paid.is_empty():check(false,"The earned component lacks its installed EMP stack");return
	var selected: RefCounted=active.select_secondary(int(paid[0].item_id))
	if selected==null:check(false,active.error);return
	var fired: RefCounted=selected.evaluate(100,Vector2.ZERO,0.0,false,false,Vector2i.ZERO,0.0,true)
	if fired==null:check(false,selected.error);return
	active=fired
	var remaining: Array=active.encounter_owner().secondary_choices().filter(func(choice):return choice.item_id==42)
	var ammunition: int=0 if remaining.is_empty() else int(remaining[0].quantity)
	check(ammunition==int(paid[0].quantity)-1,"Native secondary input did not spend exactly one paid round")
	if not present():return
	if not advance_flight(false):return
	await super.verify_retained_flight()
	if failures:return
	var before: Dictionary=active.snapshot()
	var entry:=ReturnEntry.new()
	if not entry.prepare(bindings,catalogues,active):check(false,entry.error);return
	var result: Dictionary=entry.snapshot()
	var destination: Dictionary=entry.equipment_owner().snapshot()
	var career: Dictionary=entry.career_owner().snapshot()
	var retained: Dictionary=active.initialized_world_owner().entry_owner().snapshot()
	check(not retained.station_response_flags.is_empty() and result.station_response_flags==retained.station_response_flags,"Normal return lost the nonempty retained station responses")
	var inspected: Dictionary=active.station_response_flags();inspected.clear()
	check(active.station_response_flags()==retained.station_response_flags,"Inspecting the station history mutated the retained entry")
	check(result.return_station_id==retained.return_station_id and result.return_system_id==retained.return_system_id and result.return_station_id!=10,"Return skipped the retained location for Thynome")
	var expected: Dictionary=before.equipment.duplicate(true)
	expected.loadout.station_id=retained.return_station_id;expected.loadout.system_id=retained.return_system_id
	check(destination==expected,"Return changed equipped slots, paid ammunition, cargo or prices")
	var values: Dictionary=result.player_cache.values
	check(values.hull==before.player.vitals.hull and values.armor==before.player.vitals.armor and values.shield==int(before.player.vitals.shield) and values.gamma==int(before.player.gamma),"Return repaired or reset the surviving player pools")
	check(result.player_cache.campaign_cursor==before.campaign_cursor and result.player_cache.station_id==retained.return_station_id,"Return cache retained the old world cursor/location")
	check(career.progress==before.progress and result.progress==before.progress,"Return dropped final combat counters or counted them twice")
	check(career.campaign_cursor==before.campaign_cursor and career.station_id==retained.return_station_id,"Return advanced the story before its normal-space result")
	for key in ["mission","accepted_contact","passengers","credits","result_serial","completed_side_missions","void_source","blueprints","lounges"]:
		check(career.get(key)==before.career.get(key),"Return altered the independently retained career field: "+key)
	check(result.random_state==before.random_state and result.source_before==retained.source_before,"Return reseeded the live random stream or replaced source history")
	check(entry.matches_departure(active) and entry.matches_departure(active.fork_for_frame()),"Prepared transfer lost its exact native terminal generation")
	check(not entry.matches_departure(early),"Prepared transfer accepted a pre-departure world")
	var stale: RefCounted=active.fork_for_frame();stale._state.revision+=1
	check(not entry.matches_departure(stale),"Prepared transfer accepted a different source revision")
	var branch: RefCounted=active.fork_for_frame();branch._presentation_identity=RefCounted.new()
	check(not entry.matches_departure(branch),"Prepared transfer accepted a different scene generation")
	var terminal: RefCounted=active.fork_for_frame();terminal._return_identity=RefCounted.new()
	check(not entry.matches_departure(terminal),"Prepared transfer accepted a different completed escape")
	var rerolled: RefCounted=active.fork_for_frame();var random:=Random.new();random.seed_from(9876)
	rerolled._random=random.snapshot()
	check(not entry.matches_departure(rerolled),"Prepared transfer accepted a changed random stream")
	var failed: RefCounted=active.fork_for_frame();failed._career=active.career_owner()
	failed._career._state.pending_result={"serial":123}
	var failed_before: Dictionary=failed.snapshot();var rejected:=ReturnEntry.new()
	check(not rejected.prepare(bindings,catalogues,failed) and rejected.snapshot().is_empty() and rejected.equipment_owner()==null and rejected.career_owner()==null,"Failed career preparation leaked a partially relocated candidate")
	check(failed.snapshot()==failed_before,"Rejected preparation mutated the source career or inventory")
	check(rejected.prepare(bindings,catalogues,active),"Rejected preparation prevented a clean retry: "+rejected.error)
	var accepted: Dictionary=entry.snapshot()
	check(not entry.prepare(bindings,catalogues,active) and entry.snapshot()==accepted,"Repeated preparation changed an accepted transfer")
	result.player_cache.values.hull=1
	result.station_response_flags.clear()
	check(entry.snapshot()==accepted,"A returned snapshot mutated the prepared player cache")
	var forked: RefCounted=entry.fork()
	check(forked.snapshot()==accepted and forked.matches_departure(active) and forked.equipment_owner().snapshot()==destination and forked.career_owner().snapshot()==career,"Forking the prepared return changed its owners or terminal binding")
	check(active.snapshot()==before and early.snapshot()==early_before,"Return preparation mutated the original Void world")
	print("Prepared native return at station ",accepted.return_station_id,"/system ",accepted.return_system_id,"; campaign ",career.campaign_cursor,"; player pools ",accepted.player_cache.values,"; EMP ammunition ",ammunition,"; progress retained")

func capture(label: String) -> void:
	# One new visual check of the preserved final display, not five recaptures
	# of previously accepted explosion shots. The terminal frame itself is a
	# pending transition, so its last complete rendered frame is the fade.
	if label=="escape-fade":await super.capture("escape-return-preparation")
