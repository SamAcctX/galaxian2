extends "res://tests/mission_arrival_input.gd"
## Isolate the real failure-page Host exit. Earlier entry and lethal hit are
## explicitly detached; the separate input driver proves ordinary gunfire.

func verify_component(world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var app: Control=await make_host(frame)
	if app==null:return
	await verify_exit(app,frame,context)
	app.free();await process_frame

func verify_exit(app: Control,frame: RefCounted,context: RefCounted) -> void:
	var initial: Dictionary=frame.snapshot();var session: Node3D=app.session
	await key(KEY_ENTER)
	for page in 3:
		check(session.snapshot().dialogue.get("text_id")==2038+page,"Failure exit fixture skipped a briefing page")
		await key(KEY_ENTER)
	if failures:return
	var parent: RefCounted=session.flight_owner();var before: Dictionary=parent.snapshot()
	var active: RefCounted=parent.fork_for_frame()
	active._encounter._combat=active._encounter._combat.fork_for_frame()
	if active._encounter._combat._writable(0).normal_hit(2147483647,true).is_empty():check(false,active._encounter._combat.error);return
	session._accepted_world(active)
	check(session.rebase_time(now_us),"Could not start the detached failure-exit clock")
	for tick in 120:
		now_us+=100000
		if not session.step(now_us,Vector2.ZERO,false,false,0.0,true):check(false,session.error);return
		if session.snapshot().dialogue.visible:break
	var failed: Dictionary=session.snapshot()
	check(failed.dialogue.visible and failed.player.vitals.hull>0 and failed.encounter.combat.actors[0].actor_mode==4 and failed.runner.mode==int(context.recipe().result.policy.failure_result_mode),"Host exit fixture did not reach actual freighter failure")
	check(parent.snapshot()==before and frame.snapshot()==initial,"Failure exit fixture mutated a retained incoming frame")
	var unacknowledged: RefCounted=session.flight_owner()
	var unacknowledged_state: Dictionary=unacknowledged.snapshot()
	check(unacknowledged.prepare_campaign_failure_exit().is_empty() and frame.prepare_campaign_failure_exit().is_empty(),"Unacknowledged failure or initial flight issued a menu exit")
	if failures:return
	await capture(app,"mission-failure-host-before-next")
	await key(KEY_ENTER)
	check(session.status=="game_over_transition_required","Root Enter did not acknowledge the actual mission failure")
	if failures:return
	print("Acknowledged native failure boundary ",session.snapshot().boundary," packet ",session.prepare_game_over())
	verify_receipt(session.flight_owner())
	check(unacknowledged.snapshot()==unacknowledged_state and parent.snapshot()==before,"Receipt adaptation changed its unacknowledged parent")
	if failures:return
	now_us+=100000;app._selected40_tick(now_us)
	check(not app._transition_failed and app.session==null,"Host rejected the native failure exit: "+app.status.text)
	if failures:return
	var result: Dictionary=app.game_over_result()
	check(result.transition.campaign_cursor==41 and result.transition.campaign_failure.outcome=="failed" and result.transition.campaign_failure.reward_credits==0,"Host exit advanced or rewarded a failed mission")
	check(result.flight.player.vitals.hull>0 and result.flight.career==failed.career and result.flight.equipment==failed.equipment,"Host exit substituted player death or changed fitting/career")
	await capture(app,"mission-failure-host-exited")
	await key(KEY_ENTER)
	check(app.session==null and not app._transition_failed and app.game_over_result()==result,"Repeated root Enter replaced or rejected the accepted failure")
	check(parent.snapshot()==before and frame.snapshot()==initial,"Host acknowledgement changed an incoming parent")
	print("Native freighter failure -> root Enter -> actual Host exit; unchanged career/fitting, no earned journey or Resume claim")

func verify_receipt(owner: RefCounted) -> void:
	var before: Dictionary=owner.snapshot();var raw: Dictionary=owner.prepare_game_over()
	var receipt: Dictionary=owner.prepare_campaign_failure_exit()
	check(not receipt.is_empty() and receipt.base_content_id==bindings.base_content_id and receipt.binding_id==bindings.binding_id and receipt.campaign_cursor==before.campaign_cursor and receipt.source_state==1 and receipt.campaign_failure.reward_credits==0,"Acknowledged native failure did not prepare a source menu receipt")
	if failures:return
	var copied: Dictionary=owner.prepare_campaign_failure_exit();copied.campaign_failure.reward_credits=1
	check(owner.prepare_campaign_failure_exit()==receipt and owner.prepare_game_over()==raw and owner.snapshot()==before,"Menu receipt adaptation or its returned copy mutated the native transition")
	for change in [{"from_cursor":42},{"base_content_id":"wrong"},{"binding_id":"wrong"},{"previous_mission":{}},{"outcome":"success"},{"reward_credits":1},{"source_state":2}]:
		var poisoned: RefCounted=owner.fork_for_frame();poisoned._game_over=raw.duplicate(true)
		poisoned._game_over.merge(change,true)
		check(poisoned.prepare_campaign_failure_exit().is_empty(),"Mismatched native failure issued a menu exit: "+str(change))
	for boundary in ["","game_over_transition_required"]:
		var wrong_boundary: RefCounted=owner.fork_for_frame();wrong_boundary._state.boundary=boundary
		check(wrong_boundary.prepare_campaign_failure_exit().is_empty(),"A different native boundary issued a campaign failure exit")
	var wrong_mode: RefCounted=owner.fork_for_frame();wrong_mode._runner._state.mode=0
	check(wrong_mode.prepare_campaign_failure_exit().is_empty() and owner.snapshot()==before,"Receipt admitted an inactive runner or negative probes mutated their parent")
