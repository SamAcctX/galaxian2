extends SceneTree
## Headless components over the earned source and native owner constructors.
## Detached arrival, radio, acknowledgement and portal-contact stimuli do not
## constitute an input-earned escape, rendered cinematic or saved continuation.
const Escape=preload("res://src/simulation/mission_escape_sequence.gd")
const Portal=preload("res://src/simulation/void_portal.gd")
const NPC=preload("res://src/simulation/selected41_npc_combat.gd")
const Context=preload("res://src/simulation/mission_context.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Source=preload("res://tests/mission_escape_sequence_source.gd")
var checks:=0
var failures:=0
var captures:=""
var bindings: RefCounted
var library: RefCounted
var catalogues: RefCounted
var player: RefCounted
var radio: RefCounted
var anchor:=Transform3D.IDENTITY
var far_pose:=Transform3D(Basis.IDENTITY,Vector3(-60000,40000,70000))

func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run() -> void:
	var args:=Array(OS.get_cmdline_user_args())
	if args.size()!=3:check(false,"Supply App Store content, bindings and visuals")
	else:await verify(args)
	print("Mission escape: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: Array) -> void:
	library=load("res://src/content/library.gd").new();bindings=load("res://src/content/resource_bindings.gd").new()
	catalogues=load("res://src/content/catalogues.gd").new()
	if not library.open(args[0]) or not library.select_language("gb") or not bindings.open(args[1],library.manifest) or not catalogues.open(library):check(false,library.error+bindings.error+catalogues.error);return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array or supplement.size()!=3:check(false,"Missing explicit "+key);return
		var accepted: bool=bindings.attach_dekato_source(supplement[1],library.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(supplement[1],library.manifest)
		if not accepted:check(false,bindings.error);return
	var save: RefCounted=load("res://src/simulation/station_save_file.gd").new()
	var archive: RefCounted=load("res://src/simulation/station_archive.gd").new()
	var document: Dictionary=save.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,catalogues,library)
	if document.is_empty():check(false,save.error);return
	var station: RefCounted=archive.restore(bindings,catalogues,library,document)
	if station==null:check(false,archive.error);return
	var before: Dictionary=station.snapshot()
	var source:=Source.new()
	var initialized: RefCounted=source.prepare(bindings,catalogues,library,station)
	if initialized==null:check(false,source.error)
	else:verify_component(initialized)
	check(station.snapshot()==before and archive.capture(station,bindings)==document,"Escape component changed the earned station/save")

func verify_component(world: RefCounted) -> void:
	var world_before: Dictionary=world.snapshot();var entry: RefCounted=world.entry_owner()
	var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var portal:=Portal.new()
	check(not portal.configure_admitted_world(bindings,Context.new(),world_before,library) and portal.snapshot().is_empty(),"Unadmitted world created a portal")
	if not portal.configure_admitted_world(bindings,context,world_before,library):check(false,portal.error);return
	check(portal.portal_snapshot().position==world_before.environment_object.position and portal.portal_snapshot().model_id==world_before.environment_object.resource_id,"Portal replaced the initialized world object")
	var original_portal: Dictionary=portal.portal_snapshot()
	check(not portal.configure_admitted_world(bindings,context,world_before,library) and portal.portal_snapshot()==original_portal,"Repeated admission rebuilt the portal")
	verify_portal(portal)
	var npc:=NPC.new()
	if not npc.prepare(bindings,catalogues,library,world):check(false,npc.error);return
	var original: Dictionary=npc.snapshot()
	check(not Escape.new().configure(bindings,context,npc,portal,world.camera_owner(),true),"Escape began before the final shot")
	# Only radio completion is accelerated: native sequence actions establish
	# the disabled freighter and phase5. All eight actors stay real and retained.
	var completed: RefCounted=complete_ambush(npc,world_before.player_pose)
	if completed==null:return
	var retained: Dictionary=completed.snapshot()
	player=completed.player_owner();radio=completed.radio_owner()
	anchor=world.environment_owner().object_state(0).pose
	check(retained.sequence.phase==5 and retained.combat.actors[0].vitals.hull==100,"Fixture failed to reach the native disabled-freighter boundary")
	check(not Escape.new().configure(bindings,context,completed,portal,completed.camera_owner(),false),"Unacknowledged result started escape")
	var dead_npc: RefCounted=completed.fork_for_frame()
	check(not dead_npc._player.normal_hit(2147483647).is_empty(),dead_npc._player.error)
	check(not Escape.new().configure(bindings,context,dead_npc,portal,completed.camera_owner(),true),"Dead player started escape")
	var sequence:=Escape.new()
	if not sequence.configure(bindings,context,completed,portal,completed.camera_owner(),true):check(false,sequence.error);return
	var configured: Dictionary=sequence.snapshot()
	check(not sequence.configure(bindings,context,completed,portal,completed.camera_owner(),true) and sequence.snapshot()==configured,"Repeated configuration replaced escape")
	var waiting:=frame(sequence,portal,100,far_pose)
	if waiting.is_empty():return
	check(waiting.sequence.snapshot().phase==5 and waiting.sequence.snapshot().frame.audio.is_empty(),"Incomplete inherited radio opened portal")
	# Real lethal damage satisfies radio6; then drive its existing scheduler.
	var combat: RefCounted=completed.combat_owner()
	if combat._writable(0).normal_hit(2147483647,true).is_empty():check(false,combat.error);return
	var now: int=radio._last_time+1
	if not drive_radio(combat,6,false,now):return
	now=radio._last_time+1
	var speaking:=frame(waiting.sequence,waiting.portal,100,far_pose)
	if speaking.is_empty():return
	check(speaking.sequence.snapshot().phase==5,"Freighter death or radio6 start opened portal")
	if not drive_radio(combat,6,true,now) or not drive_radio(combat,7,false,radio._last_time+1):return
	var unfinished:=frame(speaking.sequence,speaking.portal,100,far_pose)
	if unfinished.is_empty():return
	check(radio.event_state(7).condition_satisfied and not radio.event_state(7).playback_finished and unfinished.sequence.snapshot().phase==5,"Radio7 START bypassed FINISHED gate")
	if not drive_radio(combat,7,true,radio._last_time+1):return
	var opened:=frame(unfinished.sequence,unfinished.portal,100,far_pose)
	if opened.is_empty():return
	var opening: Dictionary=opened.sequence.snapshot()
	check(opening.phase==6 and opening.elapsed_ms==0 and opening.phase_elapsed_ms==0 and opening.frame.clear_world_conditions and opening.frame.reset_elapsed,"Radio7 completion failed ordered clock/condition reset")
	check(opening.frame.audio==[{"action":"play","sound_id":153}] and opened.portal.portal_snapshot().position==Vector3(25000,20000,-55000) and opened.portal.portal_snapshot().elapsed_ms==-3000,"Escape failed to open the retained portal/start rumble")
	check(not opening.input_blocked and opening.hud_visible and opening.player_damage_allowed,"Approach disabled living free flight")
	var approach:=frame(opened.sequence,opened.portal,100,far_pose)
	if approach.is_empty():return
	var approaching: Dictionary=approach.sequence.snapshot()
	check(approaching.frame.audio==[{"action":"update","sound_id":153,"position":far_pose.origin,"velocity":Vector3.ZERO,"parameters":{1:0.5}}],"Rumble did not follow player with its time parameter")
	var baseline: RefCounted=opened.sequence.camera_owner()
	check(baseline.update(100,opening.shot,{"base_content_id":opening.base_content_id,"binding_id":opening.binding_id,"player_pose":far_pose}),baseline.error)
	check(jitter_matches(approaching.camera.look-baseline.snapshot().look,0.5) and approaching.camera.eye==baseline.snapshot().eye,"Approach shake moved the eye or used a noninteger look perturbation")
	var contact_pose:=Transform3D(Basis.from_euler(Vector3(0.3,1.1,-0.2)),Vector3(25900,20000,-55000))
	var dead: RefCounted=player.fork_for_frame();check(not dead.normal_hit(2147483647).is_empty(),dead.error)
	var dead_contact:=frame(approach.sequence,approach.portal,1,contact_pose,dead)
	if dead_contact.is_empty():return
	check(dead_contact.portal.snapshot().portal_entered and dead_contact.sequence.snapshot().phase==6 and dead_contact.sequence.snapshot().frame.return_request.is_empty(),"Dead shared contact entered the protected cinematic")
	var entered:=frame(approach.sequence,approach.portal,1,contact_pose)
	if entered.is_empty():return
	verify_entry(entered,contact_pose)
	verify_invalid_and_forks(entered,contact_pose)
	verify_clocks(entered,contact_pose)
	var high_rate:=[]
	for index in 144:high_rate.append(int(floor((index+1)*1000.0/144.0))-int(floor(index*1000.0/144.0)))
	verify_rates(entered,contact_pose,high_rate,"144Hz")
	verify_rates(entered,contact_pose,[1,33,16,100,7,142],"variable frames")
	check(sequence.snapshot()==configured and completed.snapshot()==retained and npc.snapshot()==original and portal.portal_snapshot()==original_portal and world.snapshot()==world_before,"Escape changed retained parents/cast/player/career")

func complete_ambush(npc: RefCounted,pose: Transform3D) -> RefCounted:
	var active: RefCounted=npc.fork_for_frame()
	for index in 5:active._radio._started[index]=true;active._radio._finished[index]=true
	for _tick in 310:
		var next: RefCounted=active.evaluate(100,pose,false)
		if next==null:check(false,active.error);return null
		active=next
		if active.sequence_owner().snapshot().phase==5:return active
	check(false,"Native final shot did not complete");return null

func drive_radio(combat: RefCounted,index: int,finished: bool,start: int) -> bool:
	for tick in 1000:
		radio.step_selected41(start+tick*100,combat)
		if not radio.error.is_empty():check(false,radio.error);return false
		if radio.event_state(index).get("playback_finished" if finished else "condition_satisfied",false):return true
	check(false,"Retained radio failed event %d"%index);return false

## Tiny frame adapter applies ONLY this component's portal actions. Player,
## combat and career are deliberately not simulated by the escape hook.
func frame(sequence: RefCounted,portal: RefCounted,ms: int,pose: Transform3D,observed_player: RefCounted=null) -> Dictionary:
	var next: RefCounted=sequence.fork_for_frame();var gate: RefCounted=portal.fork_for_frame();var rng:=Random.new()
	if not rng.restore(sequence.snapshot().random_state) or not gate.advance(ms,sequence.camera_owner().snapshot().pose,rng):check(false,rng.error+gate.error);return {}
	if not gate.observe_contact({"player_pose":pose,"environment_contact_enabled":true,"mining_active":false}):check(false,gate.error);return {}
	if not next.advance(ms,radio,player if observed_player==null else observed_player,gate,pose,anchor,rng):check(false,next.error);return {}
	for action in next.snapshot().frame.portal_actions:
		var accepted: bool=gate.open_at(action.position,action.hold_open) if action.action=="open_at" else gate.begin_closing(action.age_ms)
		if not accepted:check(false,gate.error);return {}
	return {"sequence":next,"portal":gate}

func travel(value: Dictionary,ms: int,pose: Transform3D,pattern: Array=[100]) -> Dictionary:
	var active:=value;var index:=0
	while ms>0:
		var step:=mini(ms,pattern[index%pattern.size()]);index+=1
		active=frame(active.sequence,active.portal,step,pose)
		if active.is_empty():return {}
		ms-=step
	return active

func verify_entry(value: Dictionary,pose: Transform3D) -> void:
	var state: Dictionary=value.sequence.snapshot();var eye:=pose.origin+pose.origin.normalized()*5000
	check(state.phase==7 and state.phase_elapsed_ms==0 and state.explosion_elapsed_ms==0 and state.camera.eye.is_equal_approx(eye) and state.camera.look==anchor.origin,"Portal acceptance lost actual radial eye or mothership target")
	check(state.camera.pose.basis.is_equal_approx(Basis.looking_at(anchor.origin-eye,anchor.basis.y)),"Entry camera lost shared inherited up")
	check(state.input_blocked and not state.hud_visible and not state.player_damage_allowed and state.automatic_forward and not state.player_visible and not state.player_particles_visible,"Entry failed protection/automatic movement/visibility actions")
	check(state.frame.input_actions[0].action=="reset_cinematic" and state.frame.input_actions[1].action=="cancel_player_actions" and state.frame.camera_actions.has({"action":"set_projection_fov","radians":1.22}) and state.shake_strength==0,"Entry failed common held-control/FOV/shake reset")
	check(value.portal.portal_snapshot().elapsed_ms==59000 and value.portal.portal_snapshot().scale==1.0 and state.frame.audio.has({"action":"play","sound_id":154}),"Entry failed closing portal or explosion sound")
	check(state.mothership_visible and state.explosions_visible and state.frame.renderer_actions[0].model_ids==[14285,14286,14287],"Entry hid mothership early or omitted retained explosion models")
	verify_render_transforms(state)

func verify_render_transforms(state: Dictionary) -> void:
	var forward: Vector3=(state.camera.look-state.camera.eye).normalized()
	for action in state.frame.renderer_actions:
		if action.action=="face_explosion":check(action.model_ids==[14286,14287] and action.forward.is_equal_approx(forward) and action.up==Vector3.UP,"Explosion facing ignored current renderer-camera forward")
		if action.action=="place_explosion":check(action.model_id==14286 and action.position.is_equal_approx(forward*10000),"Explosion billboard added an eye/player origin or moved another model")

func verify_invalid_and_forks(value: Dictionary,pose: Transform3D) -> void:
	var sequence: RefCounted=value.sequence;var rng:=Random.new();rng.restore(sequence.snapshot().random_state)
	var original: Dictionary=sequence.snapshot();var stream: Dictionary=rng.snapshot();var gate: Dictionary=value.portal.portal_snapshot()
	for ms in [-1,1.5,2147483648]:
		check(not sequence.advance(ms,radio,player,value.portal,pose,anchor,rng) and sequence.snapshot()==original and rng.snapshot()==stream,"Invalid escape frame changed its parent/stream")
	check(not sequence.advance(1,radio,player,Portal.new(),pose,anchor,rng) and sequence.snapshot()==original,"Escape accepted an unconfigured contact owner")
	var next: RefCounted=sequence.fork_for_frame()
	check(not next.advance(1,radio,player,value.portal,pose,Transform3D(Basis.IDENTITY,Vector3(INF,0,0)),rng) and next.snapshot()==original,"Invalid anchor partially advanced cinematic")
	# Force a late common-camera rejection AFTER fade/animation/RNG preparation.
	var broken: RefCounted=sequence.fork_for_frame();broken._camera._binding="foreign"
	var broken_before: Dictionary=broken.snapshot()
	check(not broken.advance(100,radio,player,value.portal,pose,anchor,rng) and broken.snapshot()==broken_before and rng.snapshot()==stream,"Late camera failure leaked clocks/cues/random")
	check(next.advance(100,radio,player,value.portal,pose,anchor,rng),next.error)
	var replay: RefCounted=sequence.fork_for_frame();check(replay.advance(100,radio,player,value.portal,pose,anchor,rng),replay.error)
	check(next.snapshot()==replay.snapshot() and sequence.snapshot()==original and rng.snapshot()==stream and value.portal.portal_snapshot()==gate,"Sibling escape forks consumed a parent or changed replay")
	var snapshot: Dictionary=next.snapshot();snapshot.frame.renderer_actions.clear();snapshot.fade.active=false
	check(not next.snapshot().frame.renderer_actions.is_empty(),"Published escape snapshot aliases mutable state")

func verify_clocks(value: Dictionary,pose: Transform3D) -> void:
	var at_four:=travel(value,4000,pose)
	if at_four.is_empty():return
	var state: Dictionary=at_four.sequence.snapshot();var eye: Vector3=value.sequence.snapshot().camera.eye
	check(state.phase==7 and state.mothership_visible and state.camera.eye.is_equal_approx(eye+Vector3(0,0,-72000)),"Explosion moved camera in local axes or hid mothership at inclusive boundary")
	check(jitter_matches(state.camera.look-anchor.origin,100) and state.camera.pose.basis.is_equal_approx(Basis.looking_at(state.camera.look-state.camera.eye,anchor.basis.y)),"Explosion shake rolled/moved the eye instead of perturbing look")
	verify_render_transforms(state)
	var hidden:=frame(at_four.sequence,at_four.portal,1,pose)
	if hidden.is_empty():return
	check(not hidden.sequence.snapshot().mothership_visible and hidden.sequence.snapshot().frame.renderer_actions.has({"action":"set_environment_visible","slot":0,"visible":false}),"Mothership did not hide after animation passed four seconds")
	var fifteen:=travel(hidden,10999,pose)
	if fifteen.is_empty():return
	state=fifteen.sequence.snapshot()
	check(state.phase_elapsed_ms==15000 and state.explosions_visible and not state.fade_requested,"Explosion shot ended at inclusive fifteen-second boundary")
	var fading:=frame(fifteen.sequence,fifteen.portal,1,pose)
	if fading.is_empty():return
	state=fading.sequence.snapshot()
	check(state.phase==7 and state.phase_elapsed_ms==0 and state.fade.active and state.fade.alpha_byte==0 and not state.explosions_visible and not state.mothership_visible,"Fade did not immediately stop all explosion drawings")
	check(state.frame.renderer_actions.has({"action":"set_explosion_visible","model_ids":[14285,14286,14287],"visible":false}) and state.frame.fade_request.duration_ms==4000,"Fade transition lost renderer/fade directives")
	var half:=travel(fading,2000,pose)
	if half.is_empty():return
	state=half.sequence.snapshot()
	check(state.fade.alpha_byte==127 and state.frame.renderer_actions.is_empty() and state.frame.audio.is_empty() and state.camera.eye.is_equal_approx(eye+Vector3(0,0,-18*17001)),"Fade replayed explosions/audio, stopped retreat or was nonlinear")
	var black:=travel(half,2000,pose)
	if black.is_empty():return
	check(black.sequence.snapshot().fade.active and black.sequence.snapshot().fade.alpha_byte==255 and black.sequence.snapshot().boundary.is_empty(),"Inclusive fade endpoint returned early")
	var returned:=frame(black.sequence,black.portal,1,pose)
	if returned.is_empty():return
	state=returned.sequence.snapshot()
	check(not state.fade.active and state.fade.alpha_byte==255 and state.boundary=="normal_space_return_required" and not state.frame.return_request.is_empty(),"Strict fade completion failed the black return boundary")
	check(state.frame.return_request.cache_player and state.frame.return_request.portal_arrival and state.frame.return_request.special_placement and state.frame.return_request.clear_navigation_target,"Return omitted shared cache/arrival instructions")
	var after:=frame(returned.sequence,returned.portal,100,pose)
	if after.is_empty():return
	check(after.sequence.snapshot().frame.return_request.is_empty() and after.sequence.snapshot().elapsed_ms==state.elapsed_ms,"Terminal return replayed or kept advancing")
	# Shared fade-active fault stimulus: keep the fade clock from completing.
	var stuck:=fading
	for _tick in 100:
		stuck.sequence=stuck.sequence.fork_for_frame();stuck.sequence._fade.elapsed_ms=0
		stuck=frame(stuck.sequence,stuck.portal,100,pose)
		if stuck.is_empty():return
	check(stuck.sequence.snapshot().boundary.is_empty() and stuck.sequence.snapshot().phase_elapsed_ms==10000,"Fade fallback returned before its boundary")
	stuck=frame(stuck.sequence,stuck.portal,1,pose)
	if stuck.is_empty():return
	check(stuck.sequence.snapshot().boundary=="normal_space_return_required","Active fade defeated the 10001ms fallback")

func verify_rates(value: Dictionary,pose: Transform3D,pattern: Array,label: String) -> void:
	var active:=travel(value,15000,pose,pattern)
	if active.is_empty():return
	check(not active.sequence.snapshot().fade_requested,label+" changed the strict explosion clock")
	active=frame(active.sequence,active.portal,1,pose)
	if active.is_empty():return
	active=travel(active,4000,pose,pattern)
	if active.is_empty():return
	check(active.sequence.snapshot().boundary.is_empty(),label+" changed the strict fade clock")
	active=frame(active.sequence,active.portal,1,pose)
	if active.is_empty():return
	var state: Dictionary=active.sequence.snapshot()
	check(state.boundary=="normal_space_return_required" and state.camera.eye.is_equal_approx(value.sequence.snapshot().camera.eye+Vector3(0,0,-18*19002)),label+" changed observed retreat or return ordering")

func jitter_matches(offset: Vector3,strength: float) -> bool:
	for axis in 3:
		var sample:=offset[axis]/strength
		if not is_equal_approx(sample,roundf(sample)) or sample<-30 or sample>29:return false
	return true

func verify_portal(parent: RefCounted) -> void:
	var original: Dictionary=parent.portal_snapshot();var gate: RefCounted=parent.fork_for_frame();var rng:=Random.new();rng.seed_from(42)
	var camera:=Transform3D(Basis.IDENTITY,Vector3(0,2000,0));var centre:=Vector3(25000,20000,-55000)
	check(gate.open_at(centre) and gate.portal_snapshot().extent==0 and gate.portal_snapshot().animation==original.animation,"Explicit portal opening rebuilt its authored animation")
	for _tick in 10:
		if not gate.advance(150,camera,rng):check(false,gate.error);return
	check(gate.portal_snapshot().scale==0.5,"Portal failed the half-open observable scale")
	for _tick in 10:
		if not gate.advance(150,camera,rng):check(false,gate.error);return
	check(gate.portal_snapshot().scale==1.0 and gate.portal_snapshot().extent==4096,"Explicit opening never reached full extent")
	var stream: Dictionary=rng.snapshot()
	for _tick in 500:
		if not gate.advance(150,camera,rng):check(false,gate.error);return
	check(gate.portal_snapshot().elapsed_ms==60000 and gate.portal_snapshot().scale==1.0 and gate.portal_snapshot().position==centre and rng.snapshot()==stream,"Held portal timed out or relocated while approaching")
	var direction: Vector3=(camera.origin-centre).normalized();direction.x+=0.5
	check(gate.portal_snapshot().pose.basis.z.is_equal_approx(direction.normalized()),"Portal changed its shared facing offset")
	for probe in [{"offset":Vector3(40000,0,0),"mining":false,"contact":false},
		{"offset":Vector3(1000,0,0),"mining":false,"contact":true},
		{"offset":Vector3(999.9,0,0),"mining":true,"contact":false}]:
		check(gate.observe_contact({"player_pose":Transform3D(Basis.IDENTITY,centre+probe.offset),"environment_contact_enabled":true,"mining_active":probe.mining}),gate.error)
		check(not gate.snapshot().portal_entered and gate.snapshot().contact.is_empty()!=probe.contact,"Shared cube/mining/strict entry admission changed")
	check(gate.observe_contact({"player_pose":Transform3D(Basis.IDENTITY,centre+Vector3(999.9,0,0)),"environment_contact_enabled":true,"mining_active":false}),gate.error)
	check(gate.snapshot().contact.distance==999 and gate.snapshot().contact.pull_distance==152 and gate.transition_ready(1) and not gate.transition_ready(0),"Shared truncated contact/pull/living latch changed")
	check(gate.begin_closing() and gate.portal_snapshot().elapsed_ms==59000 and gate.portal_snapshot().scale==1.0,gate.error)
	for _tick in 10:
		if not gate.advance(100,camera,rng):check(false,gate.error);return
	check(gate.portal_snapshot().elapsed_ms==60000 and gate.portal_snapshot().scale==1.0,"Closing skipped its full-size second")
	check(gate.advance(1,camera,rng) and gate.observe_contact({"player_pose":Transform3D(Basis.IDENTITY,centre),"environment_contact_enabled":true,"mining_active":false}) and gate.snapshot().contact.is_empty(),"Closing portal admitted a new contact")
	for _tick in 20:
		if not gate.advance(150,camera,rng):check(false,gate.error);return
	check(gate.portal_snapshot().position!=centre and gate.portal_snapshot().visible,"Cinematic close permanently removed shared recurring portal")
	var hidden: RefCounted=gate.fork_for_frame();hidden._state.visible=false
	var animation_time: int=hidden.portal_snapshot().animation_elapsed_ms;var age: int=hidden.portal_snapshot().elapsed_ms
	check(hidden.advance(100,camera,rng) and hidden.portal_snapshot().animation_elapsed_ms==animation_time+100 and hidden.portal_snapshot().elapsed_ms==age,"Hidden portal stopped authored animation or advanced visible lifecycle")
	var before: Dictionary=gate.portal_snapshot()
	check(not gate.open_at(Vector3(INF,0,0)) and not gate.begin_closing(-1) and gate.portal_snapshot()==before,"Rejected portal control changed state")
	check(parent.portal_snapshot()==original,"Portal controls mutated the retained parent")
