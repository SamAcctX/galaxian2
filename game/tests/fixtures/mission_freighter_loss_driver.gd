extends RefCounted
## Input-only failure path shared by detached and earned-entry application checks.
## The native flight owns every projectile, hit, breakup, result and exit.
const Pilot=preload("res://tests/fixtures/bakka_flight_pilot.gd")
const Desktop=preload("res://tests/fixtures/mission_pilot_input.gd")
var error:=""
var now_us:=0
var frames:=0
var shots:=0
var contacts:=0
var depleted_ms:=-1
var retired_ms:=-1
var _check: Callable

func require(value: bool,message: String) -> bool:
	_check.call(value,message)
	if not value:error=message
	return value

func focus(app: Control) -> void:
	app._focused=true
	for reason in ["hidden","focus","user"]:app.session.set_pause(reason,false,now_us)
	app.present_session()

func run(app: Control,viewport: Viewport,start_us: int,verify: Callable,capture: Callable) -> bool:
	_check=verify;now_us=start_us
	var tree: SceneTree=app.get_tree()
	var session: Node3D=app.session;var scene: Node3D=session.scene
	var parent: RefCounted=session.flight_owner();var initial: Dictionary=parent.snapshot()
	var world: RefCounted=parent.initialized_world_owner()
	var context: RefCounted=load("res://src/simulation/mission_context.gd").from_owner(parent)
	app._mouse_steering=true;app.set_player_mode(true);focus(app)
	Desktop.press(viewport,KEY_ENTER);await tree.process_frame
	for page in 3:
		if not require(session.snapshot().dialogue.get("text_id")==2038+page,"Freighter-loss input skipped an ordinary briefing page"):return false
		focus(app);Desktop.press(viewport,KEY_ENTER);await tree.process_frame
	if not require(session.can_control() and app._mouse_captured,"Freighter-loss briefing did not release captured mouse flight"):return false
	var pilot:=Pilot.new();var first_contact:=false
	while session.snapshot().elapsed_ms<180000:
		var before: Dictionary=session.snapshot()
		if before.dialogue.visible:break
		if not require(before.player.vitals.hull>0 and session.status=="running","Player loss or another boundary masked freighter failure"):return false
		if not require(before.encounter.sequence.phase==0,"Freighter-loss pilot reached the scripted attack instead of an early defeat"):return false
		var input:={"commands":Vector2(.2,.2),"fire":false,"throttle":1.0,"strafe":Pilot.evasion_at(float(before.elapsed_ms))}
		if before.encounter.combat.actors[0].vitals.hull>0:input=pilot.controls_at_time(before,float(before.elapsed_ms),[0])
		focus(app)
		var delivered: Dictionary=Desktop.apply(app,viewport,input,100000)
		if not require(delivered.command.is_equal_approx(input.commands) and delivered.held.fire==input.fire and delivered.strafe==input.strafe,"Freighter-loss root controls did not reach the Host"):return false
		now_us+=100000;app._selected40_tick(now_us);frames+=1
		if not require(not app._transition_failed and app.session==session,"Freighter flight failed or exited before acknowledgement: "+app.status.text):return false
		var after: Dictionary=session.snapshot();var actor: Dictionary=after.encounter.combat.actors[0]
		if not require(after.elapsed_ms==before.elapsed_ms+100 and not after.input.secondary_requested,"Freighter loss changed its native cadence or fired a secondary"):return false
		for shot in after.encounter.get("primary_fire",{}).get("weapons",[]):
			if not shot.result.get("fired",false):continue
			if not require(input.fire and delivered.held.fire and after.input.primary_held,"Freighter shot bypassed ordinary held input"):return false
			var mounts: Array=after.encounter.primaries.guns.filter(func(gun):return gun.mount_id==shot.mount_id)
			if not require(mounts.size()==1 and mounts[0].projectiles.slots.any(func(slot):return slot!=null),"Freighter shot lacked an actual mounted projectile"):return false
			shots+=1
		for weapon in session.flight_owner().encounter_owner().primary_contacts():
			for contact in weapon.contacts:
				if contact.get("target")=={"group":"npc","index":0}:contacts+=1
		if contacts>0 and not first_contact:
			first_contact=true
			print("Actual freighter primary contact at ",after.elapsed_ms,"ms; shots ",shots," hull ",actor.vitals.hull)
			await capture.call("freighter-input-first-hit")
		if actor.vitals.hull<=0 and depleted_ms<0:
			depleted_ms=after.elapsed_ms
			if not require(actor.actor_mode!=4 and after.runner.mode==0 and not after.dialogue.visible,"Hull depletion bypassed native breakup before failure"):return false
			await capture.call("freighter-input-breakup")
		if actor.actor_mode==4 and retired_ms<0:retired_ms=after.elapsed_ms
		if frames%100==0:
			print("Freighter input ",after.elapsed_ms,"ms hull ",actor.vitals.hull," player ",after.player.vitals," range ",input.get("distance",-1)," shots/contacts ",shots,"/",contacts)
			await tree.process_frame
	var failed: Dictionary=session.snapshot()
	if not require(shots>0 and contacts>0 and depleted_ms>0 and retired_ms>depleted_ms,"Input flight did not produce real projectiles, freighter hits and native retirement"):return false
	if not require(failed.player.vitals.hull>0 and failed.dialogue.visible and failed.runner.mode==int(context.recipe().result.policy.failure_result_mode) and failed.elapsed_ms>retired_ms,"Freighter retirement did not open its failure with a living player"):return false
	if not require(failed.campaign_cursor==41 and failed.equipment==initial.equipment and failed.career.credits==initial.career.credits and failed.career.mission==initial.career.mission,"Failure advanced, refitted, paid or replaced the independent job"):return false
	if not require(session.scene==scene and session.flight_owner().initialized_world_owner()==world and parent.snapshot()==initial,"Input-driven failure replaced its world or changed the retained incoming frame"):return false
	if not require(not session.can_control() and scene.feedback.dialogue._next.is_visible_in_tree(),"Freighter failure omitted its real acknowledgement action"):return false
	await capture.call("freighter-input-failure")
	print("Input-driven freighter failure: ",frames," frames, ",shots," shots, ",contacts," contacts; depletion/retirement/result ",depleted_ms,"/",retired_ms,"/",failed.elapsed_ms,"ms; player ",failed.player.vitals)
	focus(app);Desktop.press(viewport,KEY_ENTER);await tree.process_frame
	if not require(session.status=="game_over_transition_required","Root Enter did not acknowledge the native freighter failure"):return false
	now_us+=100000;app._selected40_tick(now_us)
	if not require(not app._transition_failed and app.session==null,"Host rejected the acknowledged freighter failure: "+app.status.text):return false
	var result: Dictionary=app.game_over_result()
	if not require(result.transition.campaign_cursor==41 and result.transition.campaign_failure.outcome=="failed" and result.transition.campaign_failure.reward_credits==0,"Host exit did not retain its failed career without reward"):return false
	return require(result.flight.player.vitals.hull>0 and parent.snapshot()==initial,"Host exit substituted player death or mutated its incoming frame")
