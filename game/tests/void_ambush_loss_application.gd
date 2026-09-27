extends "res://tests/void_ambush_application.gd"
## Earned entry followed by undefended variable-step Host flight. Damage and
## failure come from the living encounter, never supplied test contacts.
const LOSS_STEPS_US=[4000,17000,31000,9000,67000]
const MAX_LOSS_US=600000000
var retry_station: Dictionary
var retry_path: String
var retry_bytes: PackedByteArray
var loss_frames:=0
var loss_elapsed_us:=0
var loss_delta_kinds:={}
var controlled_frames:=0
var steering_frames:=0
var braking_frames:=0

func depart_onward() -> bool:
	retry_station=app.session.station_owner().snapshot()
	if not app.save_station():check(false,app._save_notice.text);return false
	retry_path=app.station_save_path();retry_bytes=FileAccess.get_file_as_bytes(retry_path)
	check(not retry_bytes.is_empty(),"The earned-loss branch has no native retry checkpoint")
	return not failures and await super.depart_onward()

func verify_free_application() -> void:
	var original:=await enter_earned_ambush()
	if original.is_empty():return
	var session: Node3D=app.session;var scene: Node3D=session.scene
	var parent: RefCounted=session.flight_owner();var initial: Dictionary=parent.snapshot()
	var context: RefCounted=load("res://src/simulation/mission_context.gd").from_owner(parent)
	var failure_mode: int=context.recipe().result.policy.failure_result_mode
	app._mouse_steering=true;app.set_player_mode(true)
	resume_application_focus();app.present_session()
	root_key(KEY_ENTER,true);root_key(KEY_ENTER,false);await process_frame
	check(session.snapshot().entry_skipped and session.snapshot().dialogue.get("text_id")==2038,"Earned arrival skip did not retain the first briefing")
	if failures:return
	for page in 3:
		check(session.snapshot().dialogue.get("text_id")==2038+page,"The earned briefing skipped a page")
		if failures or not await acknowledge_page("Earned loss briefing"):return
	check(session.can_control() and app._mouse_captured,"The earned briefing did not release captured mouse flight")
	if failures:return
	var exposed:=false;var exposure_target:=-1;var reason:=""
	while loss_elapsed_us<MAX_LOSS_US:
		var state: Dictionary=session.snapshot()
		if state.player.vitals.hull<=0:reason="player destruction";break
		if state.runner.mode!=0:
			check(state.runner.mode==failure_mode and state.dialogue.visible,"Undefended flight reached success instead of a genuine loss")
			if failures:return
			reason="freighter defeat";break
		var targets: Array=state.encounter.combat.actors.filter(func(actor):return actor.actor_id>0 and actor.get("hostile",false) and actor.vitals.hull>0)
		targets.sort_custom(func(a,b):return a.position.distance_squared_to(state.player_pose.origin)<b.position.distance_squared_to(state.player_pose.origin))
		var commands:=Vector2.ZERO;var brake:=true
		if session.can_control() and not targets.is_empty():
			var target: Dictionary=targets[0]
			var distance: float=target.position.distance_to(state.player_pose.origin)
			if exposed and (target.actor_id!=exposure_target or distance>35000):exposed=false
			if not exposed and distance<6000:
				exposed=true;exposure_target=target.actor_id
				print("Earned loss exposure: actor ",exposure_target," distance ",int(distance)," at ",loss_elapsed_us/1000,"ms")
			if not exposed:
				commands=ExpeditionPilot.steering_toward(state.player_pose,target.position);brake=false
		if loss_frames%400==0:
			print("Earned loss frame ",loss_frames," time ",loss_elapsed_us/1000,"ms phase ",state.encounter.sequence.phase," pools ",state.player.vitals," exposed ",exposed)
			await process_frame
		if not loss_host_step(commands,brake):return
	check(not reason.is_empty(),"Undefended earned flight did not lose within its bounded simulation time")
	if failures:return
	var lost: Dictionary=session.snapshot()
	check(loss_frames>1 and controlled_frames>0 and loss_delta_kinds.size()==LOSS_STEPS_US.size(),"The loss did not exercise variable-step native flight input")
	check(lost.campaign_cursor==41 and app.session==session and session.scene==scene,"The loss advanced the campaign or rebuilt its scene")
	check(parent.snapshot()==initial,"Earned loss mutated its retained incoming frame")
	check(lost.career==initial.career and lost.progress.player_kills==initial.progress.player_kills,"No-fire loss changed the retained career or awarded player kills")
	check(lost.equipment==initial.equipment and lost.player.equipment_ids==initial.player.equipment_ids,"No-fire flight changed the earned inventory")
	check(steering_frames>0 and not lost.player_pose.is_equal_approx(initial.player_pose),"Root mouse input did not move the earned player")
	print("Earned native loss: ",reason," after ",loss_frames," Host frames / ",loss_elapsed_us/1000,"ms; steering/brake ",steering_frames,"/",braking_frames," pools ",lost.player.vitals," freighter ",lost.encounter.combat.actors[0].vitals," runner ",lost.runner)
	await capture_free_application("void41-loss-destruction")
	if failures:return
	if reason=="player destruction":
		check(initial.player.vitals.hull>0 and lost.player.vitals.hull<=0,"Player loss was not earned by real depletion")
		var deadline:=loss_elapsed_us+60000000
		while session.snapshot().player_destruction.phase!="game_over" and loss_elapsed_us<deadline:
			if not loss_host_step(Vector2.ZERO,true):return
			if loss_frames%100==0:await process_frame
		check(session.snapshot().player_destruction.phase=="game_over","Native player destruction did not finish its fade")
	else:
		check(lost.encounter.combat.actors[0].vitals.hull<=0 and lost.dialogue.voice_event_id==-1,"Freighter failure lacked actual destruction or invented speech")
	if failures:return
	await capture_free_application("void41-loss-confirmation")
	resume_application_focus();root_key(KEY_ENTER,true);root_key(KEY_ENTER,false);await process_frame
	check(session.status=="game_over_transition_required","Root Enter did not acknowledge the earned loss")
	if failures:return
	now_us+=17000;app._selected40_tick(now_us)
	check(not app._transition_failed and app.session==null and app.game_over_result().transition.campaign_cursor==41,"The Host did not consume the earned game-over boundary")
	check(FileAccess.get_file_as_bytes(retry_path)==retry_bytes,"Loss or acknowledgement overwrote the retry checkpoint")
	if failures:return
	if not app.load_station(now_us):check(false,app._save_notice.text);return
	check(app.session.station_owner().snapshot()==retry_station,"Resume changed the exact earned Néhma station")
	check(FileAccess.get_file_as_bytes(retry_path)==retry_bytes and FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==OS.get_environment("GOF2_SOURCE_SAVE_SHA256"),"Loss/Resume changed a checkpoint or original input")
	await capture_free_application("void41-loss-resumed-nehma")
	if not failures:print("Earned Néhma -> actual gate/mission40/portal -> variable-step mission41 ",reason," -> Host Game Over -> exact same-process Néhma Resume; no successor save")

func root_key(code: Key,down: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
	root.push_input(event,true)

func loss_host_step(commands: Vector2,brake: bool) -> bool:
	resume_application_focus()
	var delta_us: int=LOSS_STEPS_US[loss_frames%LOSS_STEPS_US.size()]
	var before: Dictionary=app.session.snapshot()
	var controlling: bool=app.session.can_control()
	if controlling:
		controlled_frames+=1
		if not commands.is_zero_approx():steering_frames+=1
		if brake:braking_frames+=1
		if app._controls.snapshot().held.brake!=brake:root_key(KEY_S,brake)
		var motion:=InputEventMouseMotion.new()
		motion.screen_relative=Vector2(-commands.y,commands.x)*600.0*float(delta_us)/1000000.0/app._controls.mouse_sensitivity
		motion.relative=motion.screen_relative;root.push_input(motion,true)
	app._controls.advance_mouse(float(delta_us)/1000000.0)
	if controlling:
		var input: Dictionary=app._controls.snapshot()
		check(input.command.is_equal_approx(commands) and input.held.brake==brake,"Root mouse/brake input did not reach the Host at its actual cadence")
		if failures:return false
	now_us+=delta_us;app._selected40_tick(now_us)
	if app._transition_failed:check(false,app.status.text);return false
	if app.session==null:check(false,"Game Over exited before explicit loss acknowledgement");return false
	var after: Dictionary=app.session.snapshot()
	check(not after.input.primary_held and not after.input.secondary_requested,"Undefended root input unexpectedly fired a weapon")
	check(after.elapsed_ms-before.elapsed_ms==delta_us/1000,"Variable Host flight dropped or accumulated simulation time")
	loss_frames+=1;loss_elapsed_us+=delta_us;loss_delta_kinds[delta_us]=true
	return failures==0

func capture_free_application(label: String) -> void:
	# Capture the new branch only, not unchanged mission40 reference frames.
	if label=="void41-arrival":await super.capture_free_application("void41-loss-earned-entry")
	elif label.begins_with("void41-loss-"):await super.capture_free_application(label)
