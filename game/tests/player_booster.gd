extends SceneTree
const Booster=preload("res://src/simulation/player_booster.gd")
const Pilot=preload("res://src/simulation/pilot_motion.gd")
const Engines=preload("res://src/simulation/player_engine_particles.gd")
const Audio=preload("res://src/content/audio_resources.gd")
const Playback=preload("res://src/presentation/opening_audio.gd")
var library=preload("res://src/content/library.gd").new()
var bindings=preload("res://src/content/resource_bindings.gd").new()
var catalogues=preload("res://src/content/catalogues.gd").new()
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<2 or not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not catalogues.open(library):
		check(false,library.error+bindings.error+catalogues.error)
	else:
		verify_activation()
		verify_timing()
		verify_motion()
		verify_exhaust()
		verify_audio()
	print("Player boosters: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func configured(ids: Array=[71]) -> RefCounted:
	var owner:=Booster.new();check(owner.configure(bindings,catalogues,ids),owner.error)
	return owner

func verify_activation() -> void:
	var owner:=configured([]);var initial: Dictionary=owner.snapshot()
	check(owner.request_start() and owner.snapshot()==initial,"An empty slot activated a booster")
	owner=configured([57,71]);initial=owner.snapshot()
	check(owner.request_start(false) and owner.snapshot()==initial,"A blocked flight played boost or consumed readiness")
	check(owner.request_start() and owner.active() and not owner.ready(),"A ready fitted booster did not start")
	check(owner.snapshot().audio.size()==1 and owner.snapshot().activation==1,"Activation lost its single original sound cue")
	var accepted: Dictionary=owner.snapshot()
	check(owner.request_start() and owner.snapshot()==accepted,"Repeated input restarted an active boost")
	check(owner.advance(0) and owner.snapshot()==accepted,"A zero-time hold changed boost state")
	var candidate: RefCounted=owner.fork_for_frame()
	check(candidate.advance(500) and candidate.snapshot().envelope==1 and owner.snapshot()==accepted,"Candidate exhaust envelope mutated its accepted parent")
	check(candidate.cancel() and candidate.ready() and candidate.speed_multiplier()==1 and candidate.snapshot().audio[0].action=="stop","Cancellation retained acceleration, sample or a fabricated cooldown")
	accepted=candidate.snapshot()
	for value in [-1,1001,0.25,NAN,"100",true]:
		check(not candidate.advance(value) and candidate.snapshot()==accepted,"Bad frame time partially changed boost")
	check(not candidate.request_start(null) and candidate.snapshot()==accepted,"Invalid input permission changed boost")
	check(not candidate.configure(bindings,catalogues,[195]) and candidate.snapshot()==accepted,"Unsupported equipment replaced an accepted device")
	var identity: String=catalogues.content_id;catalogues.content_id="0".repeat(64)
	check(not candidate.configure(bindings,catalogues,[71]) and candidate.snapshot()==accepted,"Foreign content changed the fitted device")
	catalogues.content_id=identity

func verify_timing() -> void:
	for id in range(71,75):
		for cadence in [[100],[7],[5,11,16,33,100,6]]:
			var owner:=configured([id]);owner.request_start()
			var duration: int=owner.snapshot().duration_ms;var elapsed:=0;var tick:=0
			while elapsed<duration:
				var delta: int=mini(cadence[tick%cadence.size()],duration-elapsed)
				if not owner.advance(delta):check(false,owner.error);return
				elapsed+=delta;tick+=1
			check(owner.active() and not owner.ready(),"Boost expired before its inclusive duration at cadence "+str(cadence))
			check(owner.advance(1) and not owner.active() and owner.snapshot().remaining_ms==owner.snapshot().cooldown_ms,"Expiry did not start a full recharge interval")
			var accepted: Dictionary=owner.snapshot()
			check(owner.request_start() and owner.snapshot()==accepted,"Cooldown input restarted boost or its sample")
			while owner.snapshot().remaining_ms>300:
				if not owner.advance(100):check(false,owner.error);return
			check(not owner.ready() and owner.advance(100) and not owner.ready() and owner.snapshot().remaining_ms==200,"Booster became ready at the strict three-frame boundary")
			check(owner.advance(100) and owner.ready() and owner.snapshot().icon_alpha==1,"Booster missed near-boundary readiness or retained its dim icon")
			check(owner.request_start() and owner.snapshot().activation==2,"Recharged booster could not start again")

func verify_motion() -> void:
	var ordinary:=Pilot.new()
	check(ordinary.configure_vehicle(bindings,catalogues,bindings.base_content_id,0,[],[],1.0),ordinary.error)
	var straight:=Transform3D.IDENTITY
	for sample in [[71,300.0],[72,300.0],[73,500.0],[74,600.0]]:
		var device:=configured([sample[0]]);device.request_start()
		var pilot: RefCounted=ordinary.fork_for_frame()
		var moved: Transform3D=pilot.advance(straight,Vector2.ZERO,1.0,0.1,0.0,device.speed_multiplier())
		check(pilot.error.is_empty() and moved.origin.is_equal_approx(Vector3(0,0,sample[1])),"Fitted booster moved the player at the wrong speed")
		var half: Transform3D=pilot.advance(straight,Vector2.ZERO,0.5,0.1,0.0,device.speed_multiplier())
		check(half.origin.is_equal_approx(moved.origin*0.5),"Boost bypassed subsequent throttle input")
	var accelerated: RefCounted=ordinary.fork_for_frame()
	var normal_pose:=straight;var boosted_pose:=straight
	for frame in 10:
		normal_pose=ordinary.advance(normal_pose,Vector2(0.2,0.3),1.0,0.01,1.0)
		boosted_pose=accelerated.advance(boosted_pose,Vector2(0.2,0.3),1.0,0.01,1.0,3.0)
		check(normal_pose.basis.is_equal_approx(boosted_pose.basis) and ordinary.angular_units==accelerated.angular_units and ordinary.lateral_units_per_millisecond==accelerated.lateral_units_per_millisecond,"Forward boost accelerated steering or strafe")
	var angular: Vector2=accelerated.angular_units
	check(accelerated.advance(boosted_pose,Vector2.ONE,1,0.1,1,INF)==boosted_pose and not accelerated.error.is_empty() and accelerated.angular_units==angular,"Invalid speed partially committed pilot response")

func verify_exhaust() -> void:
	var mounts=preload("res://src/content/weapon_mounts.gd").new()
	check(mounts.open(library,catalogues),mounts.error)
	var engines:=Engines.new();check(engines.configure(bindings,mounts,0,73),engines.error)
	check(engines.advance(Transform3D.IDENTITY,1),engines.error)
	check(engines.advance(Transform3D(Basis.IDENTITY,Vector3(0,0,80)),40),engines.error)
	var accepted: Dictionary=engines.snapshot()
	var boost: RefCounted=engines.fork_for_frame()
	var pose:=Transform3D(Basis.IDENTITY,Vector3(0,0,160))
	check(boost.advance(pose,40,1.0) and engines.snapshot()==accepted,"Boost exhaust changed a retained frame")
	for key in accepted.owners:
		var before: Dictionary=accepted.owners[key].exhaust;var after: Dictionary=boost.snapshot().owners[key].exhaust
		check(before.preset==after.preset and after.birth_size==before.preset.size*1.5,"Boost altered static sprite resources or missed original size expansion")
		var newest: Dictionary=after.slots[(after.cursor+after.slots.size()-1)%after.slots.size()]
		check(newest.appearance.size==int(before.preset.size*1.5),"Newborn boost plume has the ordinary size")
	accepted=boost.snapshot()
	check(boost.advance(pose,0,0.0) and boost.snapshot()==accepted,"Paused exhaust reset its boost envelope")
	check(boost.advance(Transform3D(Basis.IDENTITY,Vector3(0,0,240)),40,0.0),boost.error)
	check(boost.snapshot().mode=="normal" and boost.snapshot().owners.player_nozzle0.exhaust.birth_size==125,"Boost expiry retained enlarged new particles")

func verify_audio() -> void:
	var resources:=Audio.new();check(resources.configure(library,bindings),resources.error)
	for id in range(71,75):
		var owner:=configured([id]);owner.request_start()
		var sound: Dictionary=resources.prepare(owner.snapshot().sound_id)
		check(not sound.is_empty() and not sound.has("unsupported"),"Original booster sound cannot play: "+str(sound.get("unsupported",resources.error)))
		if not sound.is_empty():print("Booster ",id," sample ",sound.get("name")," kind ",sound.get("kind")," looping ",sound.get("looping"))
	var playback:=Playback.new();root.add_child(playback)
	if not playback.configure(library,bindings):check(false,playback.error);playback.free();return
	var owner:=configured();owner.request_start()
	var frame: Dictionary=playback.prepare_frame(0,{"elapsed_ms":0,"booster":owner.snapshot()})
	if frame.is_empty():check(false,playback.error);playback.free();return
	playback.commit_frame(frame)
	check(playback.snapshot().history.filter(func(row):return row.action=="start" and row.source_id==38).size()==1,"A single boost omitted or repeated its sample")
	var repeated: Dictionary=playback.prepare_frame(1,{"elapsed_ms":0,"booster":owner.snapshot()})
	check(not repeated.is_empty() and repeated.operations.is_empty(),"Presenting an accepted boost replayed its sound")
	owner.cancel()
	var cancelled: Dictionary=playback.prepare_frame(1,{"elapsed_ms":0,"booster":owner.snapshot()})
	check(not cancelled.is_empty() and cancelled.operations.size()==1 and cancelled.operations[0].action=="stop","Same-clock departure lost its stop or replayed activation")
	if not cancelled.is_empty():playback.commit_frame(cancelled)
	owner.request_start();owner.cancel()
	var batch: Dictionary=playback.prepare_frame(2,{"elapsed_ms":0,"booster":owner.snapshot()})
	check(not batch.is_empty() and batch.operations.map(func(row):return row.action)==["start","stop"],"Activation and departure in one frame lost their ordered sample cues")
	var history: Dictionary=playback.snapshot()
	var invalid: Dictionary=owner.snapshot();invalid.binding_id="0".repeat(64)
	check(playback.prepare_frame(2,{"elapsed_ms":0,"booster":invalid}).is_empty() and playback.snapshot()==history,"Rejected booster audio changed accepted playback")
	if not batch.is_empty():playback.commit_frame(batch)
	playback.free()

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
