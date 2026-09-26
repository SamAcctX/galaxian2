extends "res://tests/mission_escape_sequence.gd"
## Focused continuation component. The source portal/radio stimuli are detached;
## native choreography, visible result input and candidate ownership are real.
## This does not claim an input-earned battle, escape or station save.
const Frame=preload("res://src/simulation/mission_flight_frame.gd")
const Scene=preload("res://src/presentation/mission_scene.gd")
const Condition=preload("res://src/simulation/mission_result_condition.gd")
var active: RefCounted
var scene: Node3D
var visual_path:=""
var capture_path:=""

func verify(args: Array) -> void:
	visual_path=args[2]
	capture_path=OS.get_environment("GOF2_CAPTURE_DIR")
	await super.verify(args)

func verify_component(world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	active=Frame.new()
	if not active.configure(bindings,catalogues,library,context,world):check(false,active.error);return
	var original: Dictionary=active.snapshot();var world_before: Dictionary=world.snapshot()
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(visual_path,library.manifest):check(false,visuals.error);return
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i.ZERO
	if not prepare_scene(visuals):return
	scene.feedback.set_active(true)
	check(scene.sequence_audio!=null and scene.sequence_audio.snapshot().active.is_empty(),"Ambush sounds started before their cinematic cut")
	await capture("continuation-arrival")
	var skipped: RefCounted=active.skip_entry()
	if skipped==null:check(false,active.error);scene.free();return
	active=skipped
	if not present():scene.free();return
	for page in context.recipe().briefing.size():
		if not acknowledge():scene.free();return
	check(not active.campaign_dialogue_visible(),"Briefing did not release the component flight")
	# Detached completed preceding radio: the actual native hook still performs
	# the attack, drift, placement, pullback and timed eligibility itself.
	active._encounter=active._encounter.fork_for_frame()
	active._encounter._hook=active._encounter._hook.fork_for_frame()
	for index in 5:
		active._encounter._hook._radio._started[index]=true
		active._encounter._hook._radio._finished[index]=true
	var phases:={};var elapsed_pullback:=0
	for tick in 900:
		if active.campaign_dialogue_visible():break
		var next: RefCounted=active.evaluate(100)
		if next==null:check(false,active.error);scene.free();return
		active=next
		if not present():scene.free();return
		var phase: int=active.frame_context().encounter.sequence.phase
		if not phases.has(phase):
			phases[phase]=true
			verify_sequence_sound(phase)
			verify_freighter_engine(phase)
			await capture("continuation-shot-"+str(phase))
		if phase==4:
			elapsed_pullback+=100
			if elapsed_pullback==14000:await capture("continuation-pullback-late")
	check(active.campaign_dialogue_visible() and active.dialogue().get("text_id")==2047,"Native cinematic did not open result41")
	if failures:scene.free();return
	for page in 4:
		check(active.dialogue().text_id==2047+page,"Result41 changed its page order")
		if not acknowledge():scene.free();return
	await capture("continuation-final-result")
	var sound_before_result: Dictionary=scene.sequence_audio.snapshot()
	var parent: RefCounted=active;var before: Dictionary=parent.snapshot()
	var rejected_loadout: Dictionary=parent.equipment_owner().snapshot().loadout.duplicate(true)
	rejected_loadout.ship_id=-1
	check(context.retained_successor(bindings,rejected_loadout)==null,"Continuation accepted changed equipment")
	if not acknowledge():scene.free();return
	check(scene.sequence_audio.snapshot().history==sound_before_result.history,"Final Next replayed the retained cinematic sound cues")
	var after: Dictionary=active.snapshot()
	check(after.campaign_cursor==42 and after.boundary.is_empty() and not active.campaign_dialogue_visible(),"Final Next did not release living mission42")
	check(active.runner_owner().context_owner().identity().campaign_cursor==42 and active.mission_context_owner()==context,"Active objective replaced the admitted world capability")
	check(active.initialized_world_owner()==world and active.presentation_identity()==parent.presentation_identity(),"Continuation rebuilt the world or scene generation")
	check(active.encounter_owner().snapshot()==parent.encounter_owner().snapshot() and after.scenery==before.scenery and after.player==before.player and after.player_pose==before.player_pose,"Result acknowledgement changed cast, radio, player or scenery")
	check(after.equipment==before.equipment and after.career.mission==before.career.mission and after.career.credits==before.career.credits,"Result acknowledgement changed independent job, equipment or money")
	check(after.runner.mode==0 and not after.runner.retired and after.runner.clock_ms==0,"Successor inherited the old result or polling clock")
	check(parent.snapshot()==before and world.snapshot()==world_before,"Accepted successor mutated its parent/world")
	check(active.navigate("next")==null and active.snapshot()==after,"Repeated final Next advanced the career twice")
	await capture("continuation-live-cursor42")
	verify_successor_conditions(active)
	var next: RefCounted=active.evaluate(100,Vector2(.2,-.2),1,true)
	if next==null:check(false,active.error)
	else:
		active=next
		check(active.frame_context().input.enabled and active.frame_context().player_pose!=after.player_pose,"Mission42 did not resume player input/movement")
		check(active.frame_context().campaign_cursor==42 and not active.campaign_dialogue_visible(),"Retained ambush completion repeated its result")
		present()
	check(original.career.mission==after.career.mission,"Independent passenger job changed across the cinematic")
	if failures==0:await verify_retained_flight()
	if is_instance_valid(scene):scene.free()

func prepare_scene(visuals: RefCounted) -> bool:
	scene=Scene.new();root.add_child(scene)
	if not scene.configure(library,bindings,visuals,catalogues,active,root.size):check(false,scene.error);scene.free();return false
	scene.world_changed.connect(func(candidate):active=candidate)
	return true

func verify_retained_flight() -> void:pass

func verify_sequence_sound(phase: int) -> void:
	if scene.sequence_audio==null:check(false,"Admitted ambush has no sequence audio owner");return
	var sound: Dictionary=scene.sequence_audio.snapshot()
	var starts: Array=sound.history.filter(func(cue):return cue.action=="play" and cue.get("sound_id")==155)
	var stops: Array=sound.history.filter(func(cue):return cue.action=="stop" and cue.get("sound_id")==156)
	check(starts.size()==int(phase>=2),"Engine damage sound did not start exactly once at the drift cut")
	check(stops.size()==int(phase>=5),"Cinematic release lost or repeated its distinct stop cue")
	if phase==2:
		check(sound.active.has(155),"Damage sound has no actual prepared playback instance")
		if sound.active.has(155):
			check(scene.sequence_audio._players[155].nodes.any(func(node):return node.playing),"Damage sound instance is not playing")
		check(sound.directives==[{"action":"stop_actor_engine","actor_id":0}],"Engine stop lost its actor rather than reaching the shared directive boundary")
		check(present() and scene.sequence_audio.snapshot()==sound,"Repeated display replayed or advanced a cinematic sound")
		scene.set_paused(true)
		var paused: RefCounted=active.evaluate(100,Vector2.ZERO,1.0,false,true)
		check(paused!=null and scene.present(paused,root.size),"Paused cinematic could not display its unchanged frame")
		scene.set_paused(false)
		check(scene.sequence_audio.snapshot()==sound,"Pause/resume advanced, restarted or lost cinematic sound state")
	if phase==5:
		check(not sound.history.any(func(cue):return cue.action=="stop" and cue.get("sound_id")==155),"Release incorrectly replaced the distinct stop156 with stop155")

func verify_freighter_engine(phase: int) -> void:
	var body: Node3D=scene.encounter.actors[0].hull
	var engines: Array=body._actor_engine_parts
	check(engines.size()==1 and engines[0].get_meta("source_resource_id")==17038,"Actor draw control lost the original detailed Vossk engine child")
	if engines.size()!=1:return
	check(engines[0].visible==(phase<4),"Freighter engine visibility differs from the native final-placement cut")
	var lights: Array=body.levels[0].get_children().filter(func(node):return node.get_meta("source_resource_id",-1)==18713)
	check(lights.size()==1 and lights[0].visible,"Engine shutdown hid the independent freighter lights")
	if phase==4:
		var selection: Dictionary=body.selection.duplicate(true)
		for level in body.levels.size():
			check(body.apply_selection({"visible":true,"level":level}) and not engines[0].visible,"Changing hull detail revived a disabled freighter engine")
		check(body.apply_selection(selection) and body.visible,"Engine shutdown lost the retained freighter body")

func verify_successor_conditions(frame: RefCounted) -> void:
	var runner: RefCounted=frame.runner_owner();var recipe: Dictionary=runner.context_owner().recipe()
	var observed: Dictionary=frame.encounter_owner().result_observation()
	check(recipe.mission.kind==160 and recipe.next_mission.kind==11 and recipe.next_mission.station_id==10,"Successor recipe lost its original mission/Thynome target")
	check(recipe.result.lines.map(func(row):return row.text_id)==[2054,2055,2056,2057] and recipe.result.lines.map(func(row):return row.voice_event_id)==[421,422,423,424],"Successor result pages/voices changed")
	var actors: Array=observed.actors.duplicate(true)
	actors[0].actor_mode=4
	check(runner.sample_clock(60000,5001),runner.error)
	var waiting: Dictionary=runner.poll(actors,false,true,true,observed.sequences)
	check(not waiting.is_empty() and waiting.mode==0,"Freighter retirement inherited mission41 failure or completion")
	var facts:={"features":{"normal_space":true},"elapsed_ms":10000,"station_id":42}
	check(not Condition.evaluate(recipe.result.success,{"world":facts}).satisfied,"Return succeeded at the strict ten-second boundary")
	facts.elapsed_ms=10001
	check(Condition.evaluate(recipe.result.success,{"world":facts}).satisfied,"Return eligibility failed after ten seconds in normal space")
	facts.station_id=-1
	check(not Condition.evaluate(recipe.result.success,{"world":facts}).satisfied,"Return succeeded at the mission's excluded target")
	check(not Condition.evaluate(recipe.result.success,{"world":{"features":{"void_environment":true},"elapsed_ms":999999,"station_id":-1}}).satisfied,"Time in Void space completed the normal-space result")

func present() -> bool:
	if not scene.present(active,root.size):check(false,scene.error);return false
	return true

func acknowledge() -> bool:
	var previous: Dictionary=active.dialogue()
	var event:=InputEventKey.new();event.physical_keycode=KEY_ENTER;event.pressed=true
	var handled: bool=scene.handle_event(event)
	event.pressed=false;scene.handle_event(event)
	check(handled and active.dialogue()!=previous,"Visible Enter failed to acknowledge page "+str(previous.get("text_id"))+": "+scene.error+scene.feedback.error)
	return failures==0

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless" or capture_path.is_empty():return
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_path)
	check(root.get_texture().get_image().save_png(capture_path.path_join(label+".png"))==OK,"Could not write focused continuation capture")
