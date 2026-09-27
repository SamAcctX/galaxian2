extends "res://tests/void_ambush_high_rate_application.gd"
## Bounded integration of the actual earned driver's loop, not its earned route.
## Source portal and late radio dependencies are explicitly detached fixtures.
const LoopSource=preload("res://tests/mission_escape_sequence_source.gd")
const LoopContext=preload("res://src/simulation/mission_context.gd")
const LoopFrame=preload("res://src/simulation/mission_flight_frame.gd")
var loop_case: String
var measured_pilot: RefCounted
var measured_tactics: RefCounted
var extra_us:=0
var step_us:=0
var delivered_steps:=0
var planning_steps:=0
var report_expected_ms:=0
var expected_report_steps:=[]
var yielded_steps:=[]
var captures_at:=[]
var observing_yields:=false
var metrics:=[]

class MeasuredPilot extends "res://tests/fixtures/mission_escort_pilot.gd":
	var calls:=0
	var measured_us:=0
	func controls_at_time(state: Dictionary,elapsed_ms: float,preferred: Array=[],reacquire_nearer:=false) -> Dictionary:
		var started:=Time.get_ticks_usec()
		var result:=super.controls_at_time(state,elapsed_ms,preferred,reacquire_nearer)
		measured_us+=Time.get_ticks_usec()-started;calls+=1
		return result

class MeasuredTactics extends "res://tests/fixtures/mission_escort_tactics.gd":
	var calls:=0
	var measured_us:=0
	func apply(state: Dictionary,sample: Dictionary) -> Dictionary:
		var started:=Time.get_ticks_usec();var result:=super.apply(state,sample)
		measured_us+=Time.get_ticks_usec()-started;calls+=1
		return result

class PreparedWorld extends RefCounted:
	var world: RefCounted
	func world_owner() -> RefCounted:return world

func _initialize() -> void:call_deferred("run_cadence_integration")

func run_cadence_integration() -> void:
	process_frame.connect(record_yield)
	if open_application_content(OS.get_cmdline_user_args()):await verify_cadence_integration()
	if is_instance_valid(app):app.free()
	print("Actual cadence loop: ",checks," checks; ",failures," failures; ",metrics)
	var directory:=OS.get_environment("GOF2_CAPTURE_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file:=FileAccess.open(directory.path_join("cadence-loop-metrics.json"),FileAccess.WRITE)
		if file==null:check(false,"Could not write cadence loop measurements")
		else:file.store_string(JSON.stringify(metrics,"\t"));file.close()
	quit(1 if failures else 0)

func verify_cadence_integration() -> void:
	var save:=OnwardFile.new();var archive: RefCounted=load("res://src/simulation/station_archive.gd").new()
	var document: Dictionary=save.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),definitions,catalogue,source)
	if document.is_empty():check(false,save.error);return
	var station: RefCounted=archive.restore(definitions,catalogue,source,document)
	if station==null:check(false,archive.error);return
	var station_before: Dictionary=station.snapshot()
	var fixture:=LoopSource.new();var world:=fixture.prepare(definitions,catalogue,source,station)
	if world==null:check(false,fixture.error);return
	var world_before: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner()
	var context:=LoopContext.new()
	if not context.admit(definitions,catalogue,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=LoopFrame.new()
	if not frame.configure(definitions,catalogue,source,context,world):check(false,frame.error);return
	var retained: Dictionary=frame.snapshot()
	for kind in ["144hz","variable","attack"]:
		await verify_loop_case(frame,kind)
		if failures:return
	check(frame.snapshot()==retained and world.snapshot()==world_before,"Cadence loop changed its retained frame/world")
	check(station.snapshot()==station_before and archive.capture(station,definitions)==document,"Cadence integration changed the earned station/save document")

func verify_loop_case(frame: RefCounted,kind: String) -> void:
	loop_case=kind;now_us=1000123
	cadence_frames=0;cadence_elapsed_us=0;cadence_kinds={};native_steps={};clock_origin_us=-1;clock_origin_ms=0
	controlled_frames=0;firing_frames=0;emitted_primary_shots=0;primary_captured=false
	strafe_frames={-1:0,1:0};throttle_frames={}
	extra_us=0;step_us=0;delivered_steps=0;planning_steps=0;report_expected_ms=0
	expected_report_steps=[];yielded_steps=[];captures_at=[]
	measured_pilot=MeasuredPilot.new();measured_tactics=MeasuredTactics.new()
	app=Host.new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_context(source,definitions,visual);app.set_process(false);app._focused=true;app.set_player_mode(true)
	app._mouse_steering=true
	var prepared:=PreparedWorld.new();prepared.world=frame.fork_for_frame()
	if not app.enter_mission_prepared(prepared,now_us):check(false,app.status.text);return
	app.show();app.present_session();await process_frame;await process_frame
	for reason in ["hidden","focus","user"]:app.session.set_pause(reason,false,now_us)
	for page in 4:
		resume_application_focus();app.present_session();root_press(KEY_ENTER);await process_frame
	check(app.session.can_control() and app._mouse_captured,"Actual cadence integration did not release mouse flight")
	if failures:return
	var session: Node3D=app.session;var scene: Node3D=session.scene;var camera: Camera3D=session.camera
	var parent: RefCounted=session.flight_owner();var initial: Dictionary=parent.snapshot()
	if kind=="attack":
		# Only the already documented radio dependency is detached. Real Host
		# frames must select phases 1/2 and render their new cameras and effects.
		var stimulus: RefCounted=parent.fork_for_frame()
		stimulus._encounter=stimulus._encounter.fork_for_frame()
		stimulus._encounter._hook=stimulus._encounter._hook.fork_for_frame()
		for index in 5:
			stimulus._encounter._hook._radio._started[index]=true
			stimulus._encounter._hook._radio._finished[index]=true
		session._accepted_world(stimulus)
	session.rebase_time(now_us);resume_application_focus()
	var phases:={};var limit:=1450 if kind=="144hz" else (400 if kind=="variable" else 8)
	observing_yields=true;var started:=Time.get_ticks_usec()
	await fly_cadence_loop(session,measured_pilot,measured_tactics,phases,limit)
	var elapsed:=Time.get_ticks_usec()-started;observing_yields=false
	if failures:return
	var final: Dictionary=session.snapshot()
	check(cadence_frames==limit and delivered_steps==limit,"Actual loop omitted or duplicated a root/Host sample across yields")
	check(now_us-1000123==cadence_elapsed_us,"Actual loop changed its absolute clock across capture/report yields")
	check(app.session==session and session.scene==scene and session.camera==camera,"Actual loop rebuilt its retained Host presentation")
	check(parent.snapshot()==initial and final.equipment==initial.equipment,"Actual loop changed retained parent or paid equipment")
	for expected in expected_report_steps:check(expected in yielded_steps,"Report did not yield after its delivered sample: "+str(expected))
	check(captures_at.size()>0 and captures_at[0].step==0,"Initial phase capture consumed a root input sample")
	if kind=="attack":
		check(phases.has(0) and phases.has(1) and phases.has(2),"Actual loop did not cross both native attack cuts")
		check(not session.can_control(),"Attack capture released ordinary pilot control")
	else:
		check(measured_pilot.calls==planning_steps and planning_steps==limit,"Actual loop bypassed real EscortPilot planning")
		check(measured_tactics.calls==limit,"Actual loop bypassed real escort tactics")
		check(expected_report_steps.size()==2,"Bounded flight did not cross a real ten-second periodic report")
	if kind=="variable":check(cadence_kinds.size()==CADENCE_US.size(),"Actual variable loop omitted an interval")
	else:super.check_cadence_coverage()
	metrics.append({"case":kind,"frames":cadence_frames,"native_ms":final.elapsed_ms,"input_us":cadence_elapsed_us,
		"pilot_calls":measured_pilot.calls,"pilot_us":measured_pilot.measured_us,"tactics_us":measured_tactics.measured_us,
		"whole_loop_us":elapsed,"extra_verification_us":extra_us,"actual_step_us":step_us,
		"loop_less_extra_us_per_sample":float(elapsed-extra_us)/limit,"report_steps":expected_report_steps,
		"yield_steps":yielded_steps,"phase_captures":captures_at,"phases":phases,"primary_emissions":emitted_primary_shots})
	print("Bounded actual cadence ",kind,": ",metrics.back(),"; detached, not earned battle/FPS/budget acceptance")
	await capture_free_application("void41-cadence-integrated-flight")
	app.free();app=null;await process_frame

func cadence_delta_us(index: int) -> int:
	return CADENCE_US[index%CADENCE_US.size()] if loop_case=="variable" else super.cadence_delta_us(index)

func check_cadence_step(before_ms: int,after_ms: int,start_us: int,delta_us: int) -> void:
	if loop_case=="variable":check(after_ms-before_ms==delta_us/1000,"Actual variable loop lost native time")
	else:super.check_cadence_step(before_ms,after_ms,start_us,delta_us)

func cadence_host_step(input: Dictionary,observation: RefCounted=null) -> bool:
	var started:=Time.get_ticks_usec()
	check(observation!=null and observation.matches(app.session),"Actual loop delivered a missing or yielded observation")
	if failures:return false
	var before: Dictionary=observation.read(app.session)
	if app.session.can_control() and not EscortTargets.select_ids(before.encounter.combat.actors).is_empty():
		planning_steps+=1
		check(measured_pilot.previous_observed_ms==float(before.elapsed_ms),"Actual planner did not reobserve after capture/report")
	if before.elapsed_ms>=report_expected_ms:
		report_expected_ms=int(before.elapsed_ms)+10000;expected_report_steps.append(cadence_frames+1)
	extra_us+=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec();var accepted:=super.cadence_host_step(input,observation)
	step_us+=Time.get_ticks_usec()-started
	if not accepted:return false
	started=Time.get_ticks_usec();delivered_steps+=1
	check(not observation.matches(app.session),"Actual cadence reused a consumed receipt")
	var after: Dictionary=app.session.snapshot()
	check(app.session.scene._revision==after.revision and app.session.scene._elapsed_ms==after.elapsed_ms,"Actual cadence omitted scene presentation for a native frame")
	check(after.revision>before.revision and after.elapsed_ms>before.elapsed_ms,"Actual cadence repeated a native frame")
	extra_us+=Time.get_ticks_usec()-started
	return failures==0

func record_yield() -> void:
	if observing_yields:yielded_steps.append(cadence_frames)

func cadence_capture_label(label: String) -> String:
	return label.replace("void41-cadence-","cadence-loop-"+loop_case+"-")

func capture_free_application(label: String) -> void:
	var started:=Time.get_ticks_usec()
	var receipt:=PilotObservation.new(app.session);var frames_before:=cadence_frames;var clock_before:=now_us
	var calls_before: int=measured_pilot.calls
	if label.begins_with("void41-cadence-phase-"):
		captures_at.append({"label":label,"step":cadence_frames,"elapsed_ms":receipt.read(app.session).elapsed_ms})
	extra_us+=Time.get_ticks_usec()-started
	await super.capture_free_application(label)
	started=Time.get_ticks_usec()
	check(not receipt.matches(app.session),"Actual phase capture failed to cross an observation lifetime")
	check(cadence_frames==frames_before and now_us==clock_before and measured_pilot.calls==calls_before,"Capture planned input, consumed a sample or advanced the clock")
	extra_us+=Time.get_ticks_usec()-started
