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
	var canonical: Dictionary=archive.capture(station,bindings)
	if canonical.is_empty():check(false,archive.error);return
	var source:=Source.new();source.host=self;source.library=library;source.bindings=bindings;source.cat=cat
	await source.verify(station,args[2])
	if source.initialized!=null:
		verify_component(bindings,cat,library,source.initialized)
		check(source.retained_parent.snapshot()==source.parent_snapshot,"Flight component mutated original navigation")
	check(station.snapshot()==original,"Mission component changed the earned station parent")
	check(archive.capture(station,bindings)==canonical,"Mission component changed the canonical earned save document")
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
	verify_booster(skipped,bindings,cat)
	var active: RefCounted=skipped.evaluate(100,Vector2(.3,-.2),1,true)
	if active==null:check(false,skipped.error);return
	check(active.frame_context().player_pose!=skipped.frame_context().player_pose and active.frame_context().input.enabled,"Released mission did not fly with native motion")
	verify_blast_composition(active._encounter)
	check(frame.snapshot()==start and world.snapshot()==initial,"Accepted child flight changed portal/world/parent")
	var broken: RefCounted=active.fork_for_frame()
	broken._scenery._detail=broken._scenery._detail.fork_for_frame();broken._scenery._detail.clear();broken._scenery._read_snapshot={}
	var broken_before: Dictionary=broken.snapshot()
	check(broken.evaluate(100,Vector2.ONE,1,true)==null and broken.snapshot()==broken_before,"Late flight failure leaked player, contacts or weapons")

func verify_booster(origin: RefCounted,bindings: RefCounted,cat: RefCounted) -> void:
	# Detached equipment stimulus exercises the recipe world's shared owner.
	# It does not alter or claim an earned fitting of this mission's save.
	var before: Dictionary=origin.snapshot();var fitted: RefCounted=origin.fork_for_frame()
	if not fitted._booster.configure(bindings,cat,[71]):check(false,fitted._booster.error);return
	var ordinary: RefCounted=fitted.evaluate(100,Vector2.ZERO,0.4)
	var boosted: RefCounted=fitted.evaluate(100,Vector2.ZERO,0.4,false,false,Vector2i.ZERO,0.0,false,-1,false,true)
	if ordinary==null or boosted==null:check(false,fitted.error);return
	check(boosted.booster_state().active and boosted.control_throttle()==1.0,"Recipe flight omitted boost or full throttle")
	check(boosted.frame_context().player_pose==ordinary.frame_context().player_pose,"Late boost input accelerated the preceding motion pass")
	var advanced: RefCounted=boosted.evaluate(100,Vector2.ZERO,1.0)
	var normal: RefCounted=ordinary.evaluate(100,Vector2.ZERO,1.0)
	if advanced==null or normal==null:check(false,boosted.error+ordinary.error);return
	var boosted_distance: float=advanced.frame_context().player_pose.origin.distance_to(boosted.frame_context().player_pose.origin)
	var normal_distance: float=normal.frame_context().player_pose.origin.distance_to(ordinary.frame_context().player_pose.origin)
	check(absf(boosted_distance-normal_distance*1.5)<0.2,"Recipe motion ignored the equipped acceleration")
	var active: Dictionary=advanced.snapshot()
	check(advanced.evaluate(100,Vector2.ONE,1.0,false,true).snapshot()==active,"Paused recipe flight advanced boost")
	var broken: RefCounted=advanced.fork_for_frame()
	broken._scenery._detail=broken._scenery._detail.fork_for_frame();broken._scenery._detail.clear();broken._scenery._read_snapshot={}
	var rejected: Dictionary=broken.snapshot()
	check(broken.evaluate(100)==null and broken.snapshot()==rejected,"Rejected recipe frame leaked boost time or exhaust")
	var scripted: RefCounted=advanced.fork_for_frame()
	scripted._encounter._hook=scripted._encounter._hook.fork_for_frame()
	scripted._encounter._hook._radio=scripted._encounter._hook._radio.fork_for_frame()
	scripted._encounter._hook._radio._started[4]=true
	for cut in 3:
		var next: RefCounted=scripted.evaluate(0,Vector2.ZERO,1.0,false,false,Vector2i.ZERO,0.0,false,-1,false,true)
		if next==null:check(false,scripted.error);return
		scripted=next
		if scripted.frame_context().encounter.sequence.input_blocked:break
	check(scripted.frame_context().encounter.sequence.input_blocked and not scripted.booster_state().active and scripted.booster_state().remaining_ms==0,"New cinematic retained boost or imposed a cooldown")
	check(advanced.snapshot()==active and origin.snapshot()==before,"Recipe booster or cinematic mutated a retained parent")

func verify_blast_composition(origin: RefCounted) -> void:
	var original: Dictionary=origin.snapshot();var encounter: RefCounted=origin.fork_for_frame()
	encounter._hook=encounter._hook.fork_for_frame()
	var control: RefCounted=encounter._hook._control
	var actor_id:=-1
	for id in control._destruction.size():
		if control._destruction[id].get_script()==preload("res://src/simulation/npc_destruction.gd"):actor_id=id;break
	if actor_id<0:check(false,"Recipe fixture has no fighter wreck owner");return
	var death: RefCounted=control._destruction[actor_id].fork_for_frame()
	# Detached cargo and a completed breakup isolate the later blast handoff.
	# Neither is written to the earned campaign or the original encounter.
	death._state=death._state.duplicate(true) # forks share a frozen state
	death._state.cargo.entries=[{"item_id":0,"quantity":1}];death._state.cargo.eligible=true
	if not death.capture(Transform3D.IDENTITY,2.0):check(false,death.error);return
	var random: Dictionary=encounter._hook.random_state()
	for tick in 100:
		var breakup: Dictionary=death.advance(100,random)
		if breakup.is_empty():check(false,death.error);return
		random=breakup.random_state
		if breakup.state.phase=="explosion":break
	var wreck: Dictionary=death.snapshot()
	if wreck.phase!="explosion":check(false,"Recipe wreck never exposed its cargo");return
	control._destruction[actor_id]=death;encounter._control=encounter._hook.controller_owner()
	var before: Dictionary=encounter.snapshot();var candidate: RefCounted=encounter.fork_for_frame()
	var pulse:=[{"blast":{"hits":[{"actor_id":actor_id,"normal_damage":1,"motion_scalar":0.25}]}}]
	if not candidate._retain_blast_motion(pulse):check(false,candidate.error);return
	var hook: RefCounted=candidate._hook
	var composed: RefCounted=hook.compose(hook.player_owner(),candidate._combat,candidate._weapons,random)
	if composed==null:check(false,hook.error);return
	var retained: RefCounted=composed.controller_owner()._destruction[actor_id].fork_for_frame()
	var moved: Dictionary=retained.advance(7,random)
	if moved.is_empty():check(false,retained.error);return
	check(absf(moved.state.cargo.pose.origin.distance_to(wreck.cargo.pose.origin)-0.25)<0.001,"Recipe composition discarded the later blast's visible cargo speed")
	check(moved.state.drift_direction==wreck.drift_direction and moved.state.effect.position==wreck.effect.position and moved.state.cargo.entries==wreck.cargo.entries and moved.random_state==random,"Recipe blast restarted breakup, changed cargo/direction or consumed random draws")
	check(encounter.snapshot()==before and origin.snapshot()==original,"Recipe blast changed the previous mission frame")

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
