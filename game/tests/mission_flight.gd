extends SceneTree
## Focused headless component checks. Source navigation is real; the late portal
## and cinematic boundary stimuli are explicitly detached, not acceptance.
const Frame=preload("res://src/simulation/mission_flight_frame.gd")
const NPC=preload("res://src/simulation/selected41_npc_combat.gd")
const Context=preload("res://src/simulation/mission_context.gd")
const Source=preload("res://tests/fixtures/mission_flight_source.gd")
const Runner=preload("res://src/simulation/mission_runner.gd")
var checks:=0
var failures:=0
var captures:=""
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	check(args.size()==3,"Supply App Store content, bindings and visuals")
	if failures==0:await verify(args)
	print("Mission flight: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
func verify(args: Array) -> void:
	var frame:=Frame.new()
	check(not frame.configure(null,null,null,Context.new(),null) and frame.snapshot().is_empty(),"Unadmitted mission populated a flight")
	var library: RefCounted=load("res://src/content/library.gd").new()
	var bindings: RefCounted=load("res://src/content/resource_bindings.gd").new()
	var cat: RefCounted=load("res://src/content/catalogues.gd").new()
	if not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	for env in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var addon: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(env)))
		if not addon is Array or addon.size()!=3:check(false,"Missing explicit source supplement "+env);return
		var attached: bool=bindings.attach_dekato_source(addon[1],library.manifest) if env=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(addon[1],library.manifest)
		if not attached:check(false,bindings.error);return
	var save: RefCounted=load("res://src/simulation/station_save_file.gd").new()
	var archive: RefCounted=load("res://src/simulation/station_archive.gd").new()
	var document: Dictionary=save.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library)
	if document.is_empty():check(false,save.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot()
	var source:=Source.new();source.host=self;source.library=library;source.bindings=bindings;source.cat=cat
	await source.verify(station,args[2])
	if source.initialized!=null:
		verify_component(bindings,cat,library,source.initialized)
		check(source.retained_parent.snapshot()==source.parent_snapshot,"Flight component mutated original navigation")
	check(station.snapshot()==original and archive.capture(station,bindings)==document,"Mission component changed the earned station or save document")
	if is_instance_valid(source.app):source.app.free()
func verify_component(bindings: RefCounted,cat: RefCounted,library: RefCounted,world: RefCounted) -> void:
	var initial: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner()
	var context:=Context.new()
	if not context.admit(bindings,cat,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var npc:=NPC.new()
	if not npc.prepare(bindings,cat,library,world):check(false,npc.error);return
	var before: Dictionary=npc.snapshot();var pose: Transform3D=initial.player_pose
	var direct: RefCounted=npc.evaluate(100,pose)
	if direct==null:check(false,npc.error);return
	var composed: RefCounted=npc.compose(npc.player_owner(),npc.combat_owner(),npc.weapons_owner(),npc.random_state())
	if composed==null:check(false,npc.error);return
	var contacts: RefCounted=composed.evaluate_contacts(100,pose)
	if contacts==null:check(false,composed.error);return
	check(contacts.evaluate_motion()==null and contacts.evaluate_contacts(100,pose)==null,"Staged NPC admitted missing or repeated sequence")
	var sequence: RefCounted=contacts.evaluate_sequence()
	if sequence==null:check(false,contacts.error);return
	check(sequence.evaluate_sequence()==null,"Staged NPC repeated sequence actions")
	var motion: RefCounted=sequence.evaluate_motion()
	if motion==null:check(false,sequence.error);return
	check(motion.snapshot()==direct.snapshot() and npc.snapshot()==before,"Typed NPC composition changed accepted ordering or mutated parent")
	check(npc.compose(null,npc.combat_owner(),npc.weapons_owner(),npc.random_state())==null and npc.snapshot()==before,"Invalid composition mutated parent")
	var camera_composed: RefCounted=contacts.evaluate_sequence(npc.camera_owner())
	check(camera_composed!=null and camera_composed.snapshot()==sequence.snapshot(),"Composed native camera changed the established sequence")
	verify_result_order(npc,context,bindings,library)
	if OS.get_environment("GOF2_MISSION_FLIGHT_COMPONENT_ONLY")=="1":
		print("Component-only: full frame configuration deliberately not requested; shared-owner integration remains pending")
		return
	var frame:=Frame.new()
	if not frame.configure(bindings,cat,library,context,world):check(false,frame.error);return
	check(frame.player_owner().snapshot().vitals==initial.components.player.vitals,"Mission frame repaired the incoming injured player")
	check(frame.career_owner().snapshot()==entry.career_owner().snapshot(),"Mission frame changed independent passenger career")
	var start: Dictionary=frame.snapshot()
	check(frame.evaluate(-1)==null and frame.snapshot()==start,"Invalid flight frame changed parent")
	check(frame.evaluate(100,Vector2.ONE,1,true,true).snapshot()==start,"Paused mission advanced owners")
	var skipped: RefCounted=frame.skip_entry()
	if skipped==null:check(false,frame.error);return
	check(skipped.campaign_dialogue_visible() and skipped.frame_context().elapsed_ms==0 and skipped.frame_context().player_pose==start.player_pose,"Arrival skip simulated missing time or omitted briefing")
	for page in context.recipe().briefing.size():
		var next: RefCounted=skipped.navigate("next")
		if next==null:check(false,skipped.error);return
		skipped=next
	check(not skipped.campaign_dialogue_visible(),"Briefing did not release flight")
	var active: RefCounted=skipped.evaluate(100,Vector2(.3,-.2),1,true)
	if active==null:check(false,skipped.error);return
	check(active.frame_context().player_pose!=skipped.frame_context().player_pose and active.frame_context().input.enabled,"Released mission did not fly with native motion")
	check(frame.snapshot()==start and world.snapshot()==initial,"Accepted child flight changed portal/world/parent")
	var broken: RefCounted=active.fork_for_frame()
	broken._scenery._detail=broken._scenery._detail.fork_for_frame();broken._scenery._detail.clear();broken._scenery._read_snapshot={}
	var broken_before: Dictionary=broken.snapshot()
	check(broken.evaluate(100,Vector2.ONE,1,true)==null and broken.snapshot()==broken_before,"Late flight failure leaked player, contacts or weapons")

func verify_result_order(origin: RefCounted,context: RefCounted,bindings: RefCounted,library: RefCounted) -> void:
	var npc: RefCounted=origin.fork_for_frame();var original: Dictionary=origin.snapshot()
	# Detached radio START stimulus. Every subsequent cut, clock, permission,
	# actor write and result observation is performed by its native owner.
	npc._radio._started[4]=true
	var pose: Transform3D=original.player_pose
	for _cut in 2:
		var next: RefCounted=npc.evaluate(0,pose)
		if next==null:check(false,npc.error);return
		npc=next
	check(npc.snapshot().sequence.phase==2,"Radio START did not enter the native drift")
	for _tick in 151:
		var next: RefCounted=npc.evaluate(100,pose)
		if next==null:check(false,npc.error);return
		npc=next
	var placed: RefCounted=npc.evaluate(0,pose)
	if placed==null:check(false,npc.error);return
	npc=placed
	for _tick in 150:
		var next: RefCounted=npc.evaluate(100,pose)
		if next==null:check(false,npc.error);return
		npc=next
	check(npc.snapshot().sequence.phase==4 and not npc.result_observation().sequences.sequence_complete,"Pullback completed before its strict crossing")
	var runner:=Runner.new()
	if not runner.configure(context) or not runner.prepare_conversations(bindings,library) or not runner.sample_clock(30100,5001):check(false,runner.error);return
	var contacts: RefCounted=npc.evaluate_contacts(1,pose)
	if contacts==null:check(false,npc.error);return
	var observed: Dictionary=contacts.result_observation()
	var pending: Dictionary=runner.poll(observed.actors,false,true,true,observed.sequences)
	check(not pending.is_empty() and pending.mode==0,"Parent runner saw a future sequence completion")
	var sequence: RefCounted=contacts.evaluate_sequence(npc.camera_owner())
	if sequence==null:check(false,contacts.error);return
	var broken: RefCounted=sequence.fork_for_frame()
	broken._control._rules=broken._control._rules.duplicate(true);broken._control._rules.actor_count=9
	var rejected: Dictionary=broken.snapshot();var previous: Dictionary=npc.snapshot()
	check(broken.evaluate_motion()==null and broken.snapshot()==rejected and npc.snapshot()==previous,"Rejected late motion leaked release or native actor writes")
	var released: RefCounted=sequence.evaluate_motion()
	if released==null:check(false,sequence.error);return
	check(released.result_observation().sequences.sequence_complete and released.snapshot().player.damage_allowed,"Native late sequence did not expose completed release")
	check(released.snapshot().combat.actors[0].vitals.hull==100 and released.snapshot().combat.actors[0].actor_mode!=4,"Success destroyed or retired the protected freighter")
	check(not contacts.result_observation().sequences.sequence_complete and npc.snapshot()==previous,"Completion mutated its pre-poll/parent observation")
	var waiting: RefCounted=runner.fork();check(waiting.sample_clock(30101,5001),waiting.error)
	observed=released.result_observation()
	check(waiting.poll(observed.actors,true,true,true,observed.sequences).mode==0,"Radio-active result ignored the idle-radio gate")
	check(waiting.sample_clock(35102,5001),waiting.error)
	var success: Dictionary=waiting.poll(observed.actors,false,true,true,observed.sequences)
	check(success.mode==int(context.recipe().result.policy.success_result_mode),"Next eligible runner visit did not accept native sequence completion")
	check(waiting.open_result(),waiting.error)
	var result_before: Dictionary=waiting.snapshot();var result_page: Dictionary=waiting.dialogue()
	var next_runner: RefCounted=waiting.fork()
	for _page in context.recipe().result.lines.size():
		var step: Dictionary=next_runner.navigate("next")
		if step.is_empty():check(false,next_runner.error);return
	check(next_runner.snapshot().retired and next_runner.navigate("next").is_empty(),"Result acknowledgement was repeatable")
	check(waiting.snapshot()==result_before and waiting.dialogue()==result_page and origin.snapshot()==original,"Result/sequence candidate changed a retained parent")
