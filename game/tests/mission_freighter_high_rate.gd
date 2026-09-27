extends "res://tests/mission_arrival_input.gd"
## Paid-loadout failure through the actual flight at native 144Hz cadence.
## Entry and one lethal owner hit are detached, not an earned combat defeat.
const PaidLoadout=preload("res://tests/fixtures/mission_paid_loadout.gd")
var purchase:=PaidLoadout.new()

func component_station(station: RefCounted) -> RefCounted:
	var fitted: RefCounted=purchase.prepare(bindings,catalogues,library,station,check)
	if fitted==null:check(false,purchase.error)
	return fitted

func verify_component(world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var initial: Dictionary=frame.snapshot()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var app: Control=await make_host(frame)
	if app==null:return
	await verify_loss(app,frame,initial,context)
	app.free();await process_frame

func verify_loss(app: Control,frame: RefCounted,initial: Dictionary,context: RefCounted) -> void:
	var session: Node3D=app.session
	await key(KEY_ENTER)
	for page in 3:
		check(session.snapshot().dialogue.get("text_id")==2038+page,"Paid failure fixture lost the ordinary briefing")
		await key(KEY_ENTER)
	check(session.can_control(),"Paid failure fixture did not release the living flight through Host input")
	if failures:return
	var briefed: RefCounted=session.flight_owner()
	var living: Dictionary=briefed.snapshot()
	var active: RefCounted=briefed.fork_for_frame()
	# Flight/encounter forks retain immutable combat until a writer owns it.
	active._encounter._combat=active._encounter._combat.fork_for_frame()
	if active._encounter._combat._writable(0).normal_hit(2147483647,true).is_empty():check(false,active._encounter._combat.error);return
	var damaged: Dictionary=active.snapshot()
	check(damaged.encounter.combat.actors[0].vitals.hull<=0 and damaged.encounter.combat.actors[0].actor_mode!=4,"Detached lethal hit bypassed native freighter breakup")
	check(not damaged.dialogue.visible and damaged.runner.mode==0 and briefed.snapshot()==living,"Hull zero prematurely failed the flight or mutated its living parent")
	if failures:return
	session._accepted_world(active)
	check(session.rebase_time(now_us),"Paid failure session could not start its native clock")
	var frames:=0;var retirement_ms:=-1;var steps:={}
	var start_us:=now_us
	while frames<2880:
		var delta: int=(frames+1)*1000/144-frames*1000/144
		steps[delta]=true
		now_us=start_us+(frames+1)*1000000/144
		if not session.step(now_us,Vector2.ZERO,false,false,0.0,true):check(false,session.error);return
		active=session.flight_owner();frames+=1
		var state: Dictionary=active.frame_context()
		var actors: Array=active.combat_owner().snapshot().actors
		check(state.elapsed_ms==frames*1000/144,"Paid freighter loss lost the accumulated high-rate clock")
		check(state.player.vitals.hull>0,"Player destruction masked the paid freighter failure")
		check(not state.input.primary_held and not state.input.secondary_requested,"No-fire freighter loss consumed player weapons")
		if actors[0].actor_mode==4 and retirement_ms<0:retirement_ms=state.elapsed_ms
		if state.dialogue.visible:
			check(retirement_ms>=0 and state.runner.mode==int(context.recipe().result.policy.failure_result_mode),"Paid flight opened a result without native freighter retirement")
			break
		check(state.runner.mode==0,"Paid failure runner changed mode without a visible result")
		if failures:return
		if frames%144==0:app.present_session();await process_frame
	var failed: Dictionary=active.snapshot()
	check(retirement_ms>0 and failed.dialogue.visible and steps.has(6) and steps.has(7) and steps.size()==2,"Paid high-rate flight did not reach its native freighter failure")
	check(failed.campaign_cursor==41 and not active.encounter_owner().result_observation().sequences.sequence_complete,"Freighter defeat completed or advanced the ambush")
	check(failed.career==living.career and failed.career.credits==purchase.receipt.credits_after and failed.equipment==living.equipment,"Freighter failure refunded or replaced the paid loadout/career")
	check(failed.encounter.primaries.guns[0].equipment.item_id==purchase.receipt.new_item,"Freighter failure substituted the purchased gun")
	check(failed.encounter.combat.actors.size()==living.encounter.combat.actors.size() and active.initialized_world_owner()==briefed.initialized_world_owner(),"Freighter loss replaced the retained cast/world")
	if failures:return
	var acknowledged: RefCounted=active.navigate("next")
	if acknowledged==null:check(false,active.error);return
	var after: Dictionary=acknowledged.snapshot()
	check(after.boundary=="campaign_failure_transition_required" and not after.game_over_packet.is_empty() and not after.dialogue.visible,"Failure acknowledgement did not request the native loss exit")
	check(after.campaign_cursor==41 and after.career==failed.career and after.equipment==failed.equipment and acknowledged.prepare_portal_transition().is_empty(),"Failure acknowledgement advanced, paid, refitted or escaped the campaign")
	check(acknowledged.navigate("next")==null and acknowledged.snapshot()==after,"Repeated loss acknowledgement issued another transition")
	check(active.snapshot()==failed and briefed.snapshot()==living and frame.snapshot()==initial,"Paid failure or acknowledgement mutated a retained parent")
	if failures:return
	check(app.session==session and app.session.snapshot().dialogue==failed.dialogue and not app.session.can_control(),"Host did not retain and present the actual native failure page")
	check(app.session.scene.feedback.dialogue._next.is_visible_in_tree(),"Rendered freighter failure omitted its acknowledgement action")
	await capture(app,"mission-paid-freighter-failure")
	print("Paid high-rate freighter loss: retirement ",retirement_ms,"ms; result ",failed.elapsed_ms,"ms / ",frames," frames; credits ",after.career.credits," item ",purchase.receipt.new_item,"; native failure exit, not earned combat or a saved successor")
