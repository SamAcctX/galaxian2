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
var actor_engine_node: Node
var retained_music_node: Node

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
	verify_attached_particles(0)
	verify_actor_engine_audio(0)
	await capture("continuation-arrival")
	var skipped: RefCounted=active.skip_entry()
	if skipped==null:check(false,active.error);scene.free();return
	active=skipped
	if not present():scene.free();return
	for page in context.recipe().briefing.size():
		if not acknowledge():scene.free();return
	check(not active.campaign_dialogue_visible(),"Briefing did not release the component flight")
	if not verify_mission_music():scene.free();return
	# Detached completed preceding radio: the actual native hook still performs
	# the attack, drift, placement, pullback and timed eligibility itself.
	active._encounter=active._encounter.fork_for_frame()
	active._encounter._hook=active._encounter._hook.fork_for_frame()
	for index in 5:
		active._encounter._hook._radio._started[index]=true
		active._encounter._hook._radio._finished[index]=true
	var phases:={};var elapsed_pullback:=0;var elapsed_drift:=0
	for tick in 900:
		if active.campaign_dialogue_visible():break
		var next: RefCounted=active.evaluate(100,Vector2.ZERO,1.0,false,false,root.size,0.0,false,scene.feedback.audio.current_music_id())
		if next==null:check(false,active.error);scene.free();return
		active=next
		if not present():scene.free();return
		var phase: int=active.frame_context().encounter.sequence.phase
		if not phases.has(phase):
			phases[phase]=true
			verify_sequence_sound(phase)
			verify_freighter_engine(phase)
			verify_actor_engine_audio(phase)
			check(scene.feedback.audio.current_music_id()==145 and scene.feedback.audio._players.get(145,{}).get("node")==retained_music_node,"Cinematic or continuation restarted retained flight music")
			verify_attached_particles(phase)
			await capture("continuation-shot-"+str(phase))
		if phase==2:
			elapsed_drift+=100
			if elapsed_drift==3000:
				verify_attached_particles(phase,true)
				await capture("continuation-burning-drift")
		if phase==4:
			elapsed_pullback+=100
			if elapsed_pullback==14000:
				verify_attached_particles(phase,true)
				await capture("continuation-pullback-late")
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
	check(scene.sequence_audio.snapshot().actor_engines.is_empty(),"Retained mission42 restarted the crippled freighter's engine")
	check(active.snapshot().music_context.campaign_cursor==42 and active.audio_state().flight_music.operations.is_empty(),"Result continuation retained the old music cursor or replayed a music command")
	var after: Dictionary=active.snapshot()
	check(after.campaign_cursor==42 and after.boundary.is_empty() and not active.campaign_dialogue_visible(),"Final Next did not release living mission42")
	check(active.runner_owner().context_owner().identity().campaign_cursor==42 and active.mission_context_owner()==context,"Active objective replaced the admitted world capability")
	check(active.initialized_world_owner()==world and active.presentation_identity()==parent.presentation_identity(),"Continuation rebuilt the world or scene generation")
	check(active.encounter_owner().snapshot()==parent.encounter_owner().snapshot() and after.scenery==before.scenery and after.player==before.player and after.player_pose==before.player_pose,"Result acknowledgement changed cast, radio, player or scenery")
	check(after.equipment==before.equipment and after.career.mission==before.career.mission and after.career.credits==before.career.credits,"Result acknowledgement changed independent job, equipment or money")
	check(after.damage_particles==before.damage_particles,"Retained mission continuation restarted or lost the attached burning wreck")
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
	verify_void_surfaces()
	scene.world_changed.connect(func(candidate):active=candidate)
	return true

func verify_void_surfaces() -> void:
	var light_node: Node3D=scene.environment.lights
	check(light_node!=null,"The admitted Void scene omitted its light owner")
	if light_node==null:return
	var colors: Dictionary=bindings.environment_colors
	var key: Array=colors.sun_rgb[10]
	var expected_ambient:=Vector3(key[0],key[1],key[2])*0.15
	var expected_fill:=Vector3(colors.planet_rgb[7][2],colors.planet_rgb[8][0],colors.planet_rgb[8][1])*1.5
	var state: Dictionary=light_node.state
	check(state.system_id==-1 and state.station_id==-1 and state.sun.is_empty(),"Void lighting invented an ordinary station or sun placement")
	check(state.global_ambient.is_equal_approx(expected_ambient) and state.lights.size()==2,"Void palette or shared light count changed")
	check(state.lights[0].direction_to_light==Vector3(0,0,-1) and state.lights[1].direction_to_light==Vector3(0,0,-1),"Fallback light directions changed")
	check(state.lights[0].diffuse==Vector3.ONE*2 and state.lights[1].diffuse.is_equal_approx(expected_fill),"Void key/fill palette response changed")
	check(light_node.environment!=null and light_node.lights.size()==2 and light_node.environment.environment.ambient_light_energy>0,"Native light state has no actual Godot lights")
	check(scene.environment.reflection.texture!=null and scene.environment.reflection.selection.texture_id==12040 and scene.environment.reflection.selection.system_id==-1,"Void reflection substituted the return-system cube")
	check(scene.scenery.destruction!=null,"Void scenery omitted its shared surface/destruction owner")
	var imported:=load("res://src/presentation/imported_model.gd")
	var old_shader:=load("res://src/presentation/imported_material.gdshader")
	var source_shader:=load("res://src/presentation/surface_response.gdshader")
	for branch in [scene.player,scene.encounter,scene.scenery]+scene.environment.surface_roots():
		var source_surfaces:=0;var pbr_surfaces:=0
		for child in branch.find_children("*","",true,false):
			if child.get_script()!=imported:continue
			for index in child.materials.size():
				var material: ShaderMaterial=child.materials[index]
				if material.shader==old_shader:pbr_surfaces+=1
				if material.shader!=source_shader:continue
				source_surfaces+=1
				check(child.instances[index].material_override==material,"Geometry retained its old opaque material after replacement")
				check(material.get_shader_parameter("ambient_colors")[0].is_equal_approx(expected_ambient),"Actual hull material lost the Void ambient palette")
				check(material.get_shader_parameter("reflection_texture")==scene.environment.reflection.texture,"Actual hull material lost the prepared Void reflection")
		check(source_surfaces>0 and pbr_surfaces==0,"A Void body branch retained unlit/default PBR surfaces")

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

func verify_mission_music() -> bool:
	var before: Dictionary=active.snapshot()
	check(not before.radar.scanner_present and before.radar.battle_count==0,"Mission radar lost actual unequipped scanner state")
	var candidate: RefCounted=active.evaluate(0,Vector2.ZERO,1.0,false,false,root.size,0.0,false,scene.feedback.audio.current_music_id())
	if candidate==null:check(false,active.error);return false
	check(candidate.audio_state().flight_music.operations==[{"action":"replace_music","source_id":145}],"Visible no-scanner radar did not select native portal peace music")
	check(active.snapshot()==before,"Music/radar candidate mutated its parent flight")
	active=candidate
	if not present():return false
	check(scene.feedback.audio.current_music_id()==145 and scene.feedback.audio._players.has(145),"Shared mission music did not reach actual playback")
	if not scene.feedback.audio._players.has(145):return false
	retained_music_node=scene.feedback.audio._players[145].node
	check(retained_music_node.playing,"Selected mission music has no running audio channel")
	before=active.snapshot()
	candidate=active.evaluate(0,Vector2.ZERO,1.0,false,false,root.size,0.0,false,145)
	if candidate==null:check(false,active.error);return false
	check(candidate.audio_state().flight_music.operations.is_empty() and candidate.snapshot().radar.battle_count==0,"Existing portal peace music was replaced or enemies invented a scanner count")
	check(active.snapshot()==before,"Retained music sample changed its parent radar")
	active=candidate
	return present()

func verify_actor_engine_audio(phase: int) -> void:
	var owner: Node3D=scene.sequence_audio
	var sound: Dictionary=owner.snapshot()
	var engines: Dictionary=sound.actor_engines
	var native: Dictionary=active.audio_state().actor_engines[0]
	check(native.enabled==(phase<2),"Freighter sound lost its native automatic-motion gate")
	if phase>=3:
		check(engines.is_empty(),"Crippled freighter engine survived its stop fade or restarted")
		check(not is_instance_valid(actor_engine_node) or not actor_engine_node.playing,"Stopped freighter left a live playback channel")
		return
	check(engines.has(0),"Freighter has no separately owned engine playback")
	if not engines.has(0):return
	var engine: Dictionary=engines[0];var record: Dictionary=owner._players[owner.actor_key(0)]
	check(engine.sound_id==47 and record.clip.looping and record.nodes.size()==1,"Freighter substituted a player loop or lost its source event")
	check(engine.position==native.position and record.nodes[0].position==native.position,"Freighter engine does not follow its physical root")
	check(record.nodes[0] is AudioStreamPlayer3D and record.nodes[0].playing,"Freighter engine has no actual playing spatial channel")
	if phase==0:
		check(active.audio_state().flight_music.operations.is_empty(),"Hidden arrival published a flight music command")
		actor_engine_node=record.nodes[0]
		check(record.clip.fade_in_ms==800 and record.clip.fade_out_ms==200,"Actor loop lost imported event fades")
		check(record.clip.min_distance==1 and record.clip.max_distance==10000,"Actor loop lost imported distance attenuation")
		var event_pitch: float=record.nodes[0].pitch_scale/float(record.clip.get("pitch",1.0))
		check(event_pitch>=pow(2.0,-.1) and event_pitch<=pow(2.0,.1),"Actor engine pitch exceeded its imported variation")
		check(engine.gains_db[0]==-80.0,"Distant arrival engine bypassed source attenuation")
		var adapter: RefCounted=load("res://src/content/sequence_audio_resources.gd").new()
		var resources: RefCounted=load("res://src/content/audio_resources.gd").new()
		check(resources.configure(library,bindings,41),resources.error)
		check(adapter.prepare_actor_loop(resources,47,4).is_empty(),"Actor loop admitted more handles than its source maximum")
		verify_actor_stop_consumer(resources,native)
	else:check(record.nodes[0]==actor_engine_node,"Ordinary motion recreated the retained actor engine")
	check(engine.stopping==(phase==2),"Damage cut did not stop the actor-owned instance")
	if phase==2:
		check(engine.remaining_ms==200,"Engine stop skipped or restarted its source fade")
		var player_loop: Dictionary=scene.feedback.audio._players.get(scene.feedback.audio.PLAYER_ENGINE,{})
		check(not player_loop.is_empty() and player_loop.node.playing and player_loop.node!=actor_engine_node,"Freighter stop silenced the independent player engine")
	if phase==1:
		var flight_before: Dictionary=active.snapshot()
		var hidden: RefCounted=active.evaluate(0,Vector2.ZERO,1.0,false,false,root.size,0.0,false,-1)
		check(hidden!=null and hidden.audio_state().flight_music.operations.is_empty(),"Hidden cinematic selected music without a radar publication")
		check(active.snapshot()==flight_before,"Hidden music observation mutated the retained flight")
		var before: Dictionary=owner.snapshot()
		var candidate: Dictionary=before.state.duplicate(true)
		candidate.revision+=1;candidate.delta_ms=0
		candidate.cues=[{"action":"stop_actor_engine","actor_id":0},{"action":"stop_actor_engine","actor_id":999}]
		check(owner.prepare_frame(active.mission_context_owner(),candidate,scene.camera.transform).is_empty() and owner.snapshot()==before and actor_engine_node.playing,"Final invalid actor cue partly stopped a valid engine")
		candidate.cues=[];candidate.actor_engines[0].position=Vector3(NAN,0,0)
		check(owner.prepare_frame(active.mission_context_owner(),candidate,scene.camera.transform).is_empty() and owner.snapshot()==before,"Malformed physical sound position mutated playback")
		scene.set_paused(true)
		check(owner.snapshot().paused and (actor_engine_node.stream_paused or owner._players[owner.actor_key(0)].pause_records[0].pending_resume),"Pause did not reach the actual freighter channel")
		scene.set_paused(false)
		check(owner.snapshot()==before and record.nodes[0]==actor_engine_node,"Pause resumed a new engine instance or advanced its fade")

## Isolate cue consumption from the coincident cruise-off state. This is a
## playback component witness, not an input-earned world or campaign result.
func verify_actor_stop_consumer(resources: RefCounted,native: Dictionary) -> void:
	var owner: Node3D=scene.sequence_audio.get_script().new();root.add_child(owner)
	var context: RefCounted=active.mission_context_owner()
	if not owner.configure(context,resources,bindings,[155,156]):check(false,owner.error);owner.free();return
	var frame:={"revision":0,"delta_ms":0,"cues":[],"actor_engines":{0:native.duplicate(true)}}
	var listener:=Transform3D(Basis.IDENTITY,native.position+Vector3(0,0,2))
	var prepared: Dictionary=owner.prepare_frame(context,frame,listener)
	if prepared.is_empty():check(false,owner.error);owner.free();return
	check(owner.commit_frame(prepared),"Actor witness could not start its native loop")
	var key: String=owner.actor_key(0);var channel: Node=owner._players[key].nodes[0]
	check(channel.playing,"Actor witness has no actual playing channel")
	frame.revision=1;frame.delta_ms=1000;frame.cues=[{"action":"stop_actor_engine","actor_id":0}]
	prepared=owner.prepare_frame(context,frame,listener)
	if prepared.is_empty():check(false,owner.error);owner.free();return
	check(owner.commit_frame(prepared),"Actor stop consumer rejected its own prepared frame")
	check(frame.actor_engines[0].enabled and owner.snapshot().actor_engines[0].stopping and channel.playing,"Stop directive only logged or relied on an unrelated motion change")
	var stop_gain: float=db_to_linear(channel.volume_db)
	frame.revision=2;frame.delta_ms=100;frame.cues=[];frame.actor_engines[0].enabled=false
	prepared=owner.prepare_frame(context,frame,listener)
	check(not prepared.is_empty() and owner.commit_frame(prepared),"Actor stop fade did not accept its continuation")
	check(is_equal_approx(db_to_linear(channel.volume_db),stop_gain*.5),"Actor engine fade did not reach its actual channel gain")
	frame.revision=3
	prepared=owner.prepare_frame(context,frame,listener)
	check(not prepared.is_empty() and owner.commit_frame(prepared),"Actor stop fade did not finish")
	check(owner.snapshot().actor_engines.is_empty() and not channel.playing,"Completed actor fade left live audio")
	frame.revision=4;frame.delta_ms=0;frame.actor_engines[0].enabled=true
	prepared=owner.prepare_frame(context,frame,listener)
	check(not prepared.is_empty() and owner.commit_frame(prepared),"Independent actor loop could not reacquire its source event")
	channel=owner._players[key].nodes[0]
	owner.free()
	check(not is_instance_valid(channel),"Scene teardown retained an actor playback node")

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

func verify_attached_particles(phase: int,require_visible:=false) -> void:
	var owner: RefCounted=active.damage_particles_owner();var particles: Dictionary=owner.snapshot()
	var actors: Array=active.encounter_owner().combat_snapshot().actors
	for effect in [40,41]:
		var key:="attached0_%d"%effect
		check(particles.owners.has(key),"Native ambush did not register an attached sprite owner")
		if not particles.owners.has(key):continue
		var record: Dictionary=particles.owners[key];var emitter: Dictionary=record.fire
		check(record.actor_id==0 and record.root==actors[0].body_pose,"Attached particles lost the current physical freighter pose")
		check(emitter.enabled==(phase>=2),"Freighter particles ignored their native damage-cut enablement")
		check(emitter.preset.preset_id==effect and emitter.preset.material_id==20099 and emitter.get("fade_in_rgb",false),"Attached particles lost the general-manager material or RGB fade")
		check(emitter.slots.size()==(30 if effect==40 else 1000),"Attached particle population changed")
		var live: Array=emitter.slots.filter(func(slot):return slot.appearance.age_ms>=0)
		if phase<2:check(live.is_empty(),"Freighter burned before the source damage cut")
		var rendered: Array=scene.effects.sprites.items.filter(func(item):return item.key==key and item.kind=="fire")
		check(rendered.size()==1,"Attached particles have no shared sprite renderer")
		if require_visible:
			check(not live.is_empty(),"Enabled attached emitter produced no live particles")
			check(rendered.size()==1 and rendered[0].node.visible and rendered[0].node.mesh!=null,"Live attached particles were not actually drawn")
	if phase==2 and not require_visible:
		var display_before: Dictionary=scene.effects.snapshot()
		check(present() and active.damage_particles_owner().snapshot()==particles and scene.effects.snapshot()==display_before,"Repeated display advanced or reset attached particles")
		var invalid: Array=[{"action":"set_enabled","actor_id":0,"effect_type":40,"enabled":false},
			{"action":"set_enabled","actor_id":0,"effect_type":39,"enabled":false}]
		check(not owner.apply_sequence(invalid,actors) and owner.snapshot()==particles,"Rejected final directive partially disabled the first attached emitter")
		var extra: Dictionary=invalid[0].duplicate();extra.unexpected=true
		check(not owner.apply_sequence([extra],actors) and owner.snapshot()==particles,"Attached sprites accepted an unsupported cue field")
		var invalid_actors: Array=actors.duplicate(true);invalid_actors[0].body_pose=Transform3D(Basis.IDENTITY,Vector3(NAN,0,0))
		check(not owner.apply_sequence([],invalid_actors) and owner.snapshot()==particles,"Invalid root partially changed attached particle state")
		var candidate: RefCounted=owner.fork_for_frame()
		check(candidate.apply_sequence([invalid[0]],actors),candidate.error)
		check(not candidate.snapshot().owners.attached0_40.fire.enabled and candidate.snapshot().owners.attached0_41.fire.enabled and owner.snapshot()==particles,"Disabling one declared emitter modified its sibling or parent")

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
