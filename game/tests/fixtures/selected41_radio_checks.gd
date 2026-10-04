extends RefCounted
## Detached timing/contact fixtures over real initialized native41 owners.
## Synthetic clock/placement probes are NOT an input-earned cinematic or save.
const NPC=preload("res://src/simulation/selected41_npc_combat.gd")
const Radio=preload("res://src/simulation/radio_sequence.gd")
const Rules=preload("res://src/content/selected41_population_definitions.gd")
const Dialogue=preload("res://src/content/dialogue_definitions.gd")
const Text=preload("res://src/presentation/opening_radio_resources.gd")
const Audio=preload("res://src/presentation/opening_audio.gd")
const Clips=preload("res://src/content/audio_resources.gd")
const PanelView=preload("res://src/presentation/radio_panel.gd")

static func run(host: SceneTree,library: RefCounted,bindings: RefCounted,cat: RefCounted,visuals: RefCounted,world: RefCounted,other: RefCounted) -> void:
	var original: Dictionary=world.snapshot();var retained: Dictionary=world.entry_owner().snapshot()
	var npc:=NPC.new()
	if not npc.prepare(bindings,cat,library,world):host.check(false,npc.error);return
	var first: Dictionary=npc.snapshot();var combat: RefCounted=npc.combat_owner()
	var rules: Dictionary=Dialogue.select(bindings,41)
	host.check(Dialogue.valid_parameters(rules,41) and rules.events.size()==8 and rules.voice.event_ids.map(func(id):return int(id))==range(531,539),"Source41 lost its eight exact text/voice mappings")
	for field in ["condition","text_id","speaker_id","values"]:
		var malformed: Dictionary=rules.duplicate(true)
		if field=="values":malformed.events[4][field]=[-99999]
		else:malformed.events[4][field]+=1
		host.check(not Dialogue.valid_parameters(malformed,41),"Source41 accepted modified radio declaration "+field)
	var radio: RefCounted=npc.radio_owner();var untouched: Dictionary=radio.snapshot()
	host.check(radio.step(80000,{0:0},5).is_empty() and not radio.error.is_empty() and radio.snapshot()==untouched,"Generic radio input invented source41 transmission ownership")
	for invalid in [null,RefCounted.new(),load("res://src/simulation/opening_combat_group.gd").new()]:
		host.check(radio.step_selected41(80000,invalid).is_empty() and not radio.error.is_empty() and radio.snapshot()==untouched,"Uninitialized radio target consumed source41 time")
	var view_snapshots:=[];var time:=79999
	host.check(radio.step_selected41(time,combat).is_empty() and radio.snapshot().active_event==-1,"Source41 first transmission started before 80000ms")
	time+=1
	for event in 4:
		var started: Array=radio.step_selected41(time,combat)
		host.check(started==[{"kind":"started","event":event}] and not radio.snapshot().visible and radio.event_state(event)=={"condition_satisfied":true,"playback_finished":false},"Source41 event did not start in source list order")
		if event<3:host.check(radio.eligible(rules.events[event+1],time,{},0),"Condition6 waited for playback rather than the source started latch")
		var visible_at: int=time+int(rules.timing.display_delay_ms)
		host.check(radio.step_selected41(visible_at,combat).is_empty() and not radio.snapshot().visible,"Source41 display lost its strict delayed boundary")
		var displayed: Array=radio.step_selected41(visible_at+1,combat)
		host.check(displayed==[{"kind":"display","event":event,"text_id":int(rules.events[event].text_id)}] and radio.snapshot().visible,"Source41 failed to display after the exact delay")
		if event in [0,1]:view_snapshots.append(radio.snapshot())
		var finish: int=visible_at+int(rules.timing.base_duration_ms)+int(rules.timing.per_line_ms)*int(radio._lines[event])
		host.check(radio.step_selected41(finish,combat).is_empty() and not radio.event_state(event).playback_finished,"Source41 finish used >= instead of >")
		host.check(radio.step_selected41(finish+1,combat)==[{"kind":"finished","event":event}] and radio.snapshot().active_event==-1,"Source41 finish overlapped the next transmission")
		time=finish+1
	host.check(radio.step_selected41(time,combat).is_empty(),"Side-attack radio ignored its live first-target position")
	# One float32 step inside either edge is accepted; equality and positions
	# beyond either edge are rejected. Deliberately move STATISTICS separately
	# from the original geometry body to detect a wrong-coordinate substitution.
	for position in [-200000.0,-105000.0,-104999.9921875,-100000.0,-95000.0078125,-95000.0,0.0]:
		var branch: RefCounted=combat.fork_for_frame();var body: Dictionary=branch.actor_snapshot(0)
		var placed: Transform3D=body.pose;placed.origin.z=position
		host.check(branch.set_pose(0,placed,body.body_pose),branch.error)
		var probe: RefCounted=radio.fork_for_frame();var changes: Array=probe.step_selected41(time,branch)
		var eligible: bool=absf(position+100000.0)<5000.0
		host.check((changes==[{"kind":"started","event":4}])==eligible and probe.error.is_empty(),"Source41 condition26 changed its strict statistics-Z tolerance: "+str(position))
	var near: RefCounted=combat.fork_for_frame();var row: Dictionary=near.actor_snapshot(0)
	var placed: Transform3D=row.pose;placed.origin.z=-100000
	host.check(near.set_pose(0,placed,row.body_pose),near.error)
	var inactive: RefCounted=near.fork_for_frame();inactive._writable(0)._state.active=false
	var probe: RefCounted=radio.fork_for_frame()
	host.check(probe.step_selected41(time,inactive).is_empty(),"Inactive freighter triggered condition26")
	var dead: RefCounted=near.fork_for_frame();var death_hit: Dictionary=dead._writable(0).normal_hit(2147483647,true)
	host.check(not death_hit.is_empty() and dead.actor_snapshot(0).vitals.hull==0 and dead.actor_snapshot(0).actor_mode!=4,"Native hull-zero probe did not retain the distinct breakup phase")
	probe=radio.fork_for_frame()
	host.check(probe.step_selected41(time,dead)==[{"kind":"started","event":6}] and not probe.event_state(4).condition_satisfied,"Hull-zero radio became proximity radio or waited for completed wreck mode4")
	probe=radio.fork_for_frame()
	host.check(probe.step_selected41(time,near)==[{"kind":"started","event":4}] and probe.eligible(rules.events[5],time,{},0),"Source41 engine-damage message lost its preceding started latch")
	var stopped: Dictionary=probe.snapshot();var clock: int=probe._last_time
	host.check(probe.step_selected41(time-1,near).is_empty() and not probe.error.is_empty() and probe.snapshot()==stopped and probe._last_time==clock,"Rejected source41 clock mutated its existing transmission")
	# Exercise actual native frame/audio staging with an EXPLICIT detached clock
	# boundary stimulus. Only elapsed time is accelerated, never mission phase.
	var audio:=Audio.new();host.root.add_child(audio)
	if not audio.configure_selected41_radio(library,bindings,npc):host.check(false,audio.error);audio.free();return
	var listener_before: bool=host.root.is_audio_listener_3d()
	var prepared: Dictionary=audio.prepare_selected41_radio(npc)
	if prepared.is_empty():host.check(false,audio.error);audio.free();return
	audio.commit_frame(prepared)
	var playing: RefCounted=tick(host,npc,80000)
	if playing==null:audio.free();return
	prepared=audio.prepare_selected41_radio(playing)
	host.check(not prepared.is_empty() and prepared.get("operations",[]).is_empty(),"Source41 speech started before text became visible")
	audio.commit_frame(prepared)
	var boundary: int=80000+int(rules.timing.display_delay_ms)
	playing=tick(host,playing,boundary)
	if playing==null:audio.free();return
	prepared=audio.prepare_selected41_radio(playing);host.check(not prepared.is_empty() and prepared.get("operations",[]).is_empty(),audio.error);audio.commit_frame(prepared)
	var before_sound: Dictionary=audio.snapshot();var before_native: Dictionary=playing.snapshot()
	var broken: RefCounted=playing.fork_for_frame();broken._control._rules=broken._control._rules.duplicate(true);broken._control._rules.actor_count=9
	var broken_before: Dictionary=broken.snapshot()
	host.check(broken.evaluate(1,first.player_pose)==null and broken.snapshot()==broken_before and audio.snapshot()==before_sound and playing.snapshot()==before_native,"Late NPC rejection leaked a staged radio display, clock or audio cue")
	playing=tick(host,playing,boundary+1)
	if playing==null:audio.free();return
	prepared=audio.prepare_selected41_radio(playing)
	host.check(not prepared.is_empty() and prepared.get("operations",[]).size()==1 and prepared.operations[0].source_id==531 and audio.snapshot()==before_sound,"Source41 speech did not prepare exactly one original display cue without side effects")
	audio.commit_frame(prepared)
	host.check(audio.snapshot().history.size()==1 and audio.snapshot().voice_displayed[0] and audio.snapshot().active.has(531),"Source41 committed display failed to play original voice531")
	var sound_state: Dictionary=audio.snapshot();audio.commit_frame(prepared)
	host.check(audio.snapshot()==sound_state and audio.prepare_selected41_radio(playing).get("repeat",false),"Source41 repeated native audio revision replayed a voice")
	var foreign:=NPC.new();host.check(foreign.prepare(bindings,cat,library,other),foreign.error)
	host.check(audio.prepare_selected41_radio(foreign).is_empty() and audio.snapshot()==sound_state,"Equal-context foreign source41 generation entered radio playback")
	var finish: int=boundary+int(rules.timing.base_duration_ms)+int(rules.timing.per_line_ms)*int(playing._radio._lines[0])+1
	playing=tick(host,playing,finish)
	if playing==null:audio.free();return
	prepared=audio.prepare_selected41_radio(playing)
	host.check(not prepared.is_empty() and prepared.get("operations",[]).is_empty() and playing.snapshot().radio.finished[0],"Source41 text completion stopped or repeated original speech")
	audio.commit_frame(prepared)
	playing=tick(host,playing,finish)
	if playing==null:audio.free();return
	prepared=audio.prepare_selected41_radio(playing);host.check(not prepared.is_empty(),audio.error);audio.commit_frame(prepared)
	playing=tick(host,playing,finish+int(rules.timing.display_delay_ms)+1)
	if playing==null:audio.free();return
	prepared=audio.prepare_selected41_radio(playing)
	host.check(not prepared.is_empty() and prepared.get("operations",[]).size()==1 and prepared.operations[0].source_id==532,"Source41 second speaker did not resolve original voice532")
	audio.commit_frame(prepared)
	host.check(audio.snapshot().history.map(func(item):return item.source_id)==[531,532] and host.root.is_audio_listener_3d()==listener_before,"Source41 radio stole the retained 3D listener or replayed speech")
	var panel:=PanelView.new();host.root.add_child(panel);var text:=Text.new()
	# The passive panel trusts the mission entry owner for which cursor flies (one capability owner).
	host.check(text.prepare(library,bindings,visuals,41),text.error)
	host.check(panel.configure_selected41(library,bindings,world,text.speakers) and panel.configure_art(library,bindings,visuals),panel.error)
	for snapshot in view_snapshots:
		host.check(panel.present(snapshot) and panel.visible and panel._portrait.texture!=null and not panel._name.text.is_empty(),"Original source41 speaker/text/portrait was not rendered")
	panel.free()
	for language in ["gb","de","fr"]:
		host.check(library.select_language(language),library.error)
		var clips:=Clips.new();host.check(clips.configure(library,bindings,41),clips.error)
		for id in range(531,539):
			var clip: Dictionary=clips.prepare(id)
			host.check(not clip.is_empty() and not clip.has("unsupported") and clip.get("voice",false) and not clip.get("spatial",true) and not clip.get("looping",true) and clip.source_bank.ends_with("_deu.fsb" if language=="de" else "_eng.fsb") and clip.stream.get_length()>0,"Source41 original voice/fallback unavailable: "+language+"/"+str(id))
	host.check(library.select_language(first.radio.language),library.error)
	if DisplayServer.get_name()!="headless":await load("res://tests/fixtures/selected41_construction_checks.gd").render(host,library,bindings,visuals,world.construction_owner(),world,npc,view_snapshots)
	audio.free()
	host.check(npc.snapshot()==first and world.snapshot()==original and world.entry_owner().snapshot()==retained,"Source41 radio tests changed native initialization, retained career/inventory or RNG")
	print("Source41 native RADIO:8 source messages/voices; exact80000ms start, strict display/finish and5000Z bounds; live hull/activity vs mode4; staged original531/532 playback, all8gb/de/fr clips, native rollback, typed portraits; detached clock/position fixtures, no cinematic/Host/result grant")

static func tick(host: SceneTree,parent: RefCounted,elapsed: int) -> RefCounted:
	var branch: RefCounted=parent.fork_for_frame()
	# A boundary-only stimulus; no claim of elapsed input-earned live combat.
	branch._state.elapsed_ms=elapsed-1
	var result: RefCounted=branch.evaluate(1,parent.frame_context().player_pose,false)
	if result==null:host.check(false,branch.error)
	return result
