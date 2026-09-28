extends "res://tests/scenery_world.gd"
## Original field and lifecycle owners share physical drift while retaining
## statistics, drop accounting and frozen parent frames.
var checks:=0

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected content, bindings and visuals");quit(1);return
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	var bodies:=Bodies.new();var effects:=Effects.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not bodies.configure(lib,bindings) or not effects.configure(lib,bindings):
		check(false,lib.error+bindings.error+cat.error+bodies.error+effects.error);quit(1);return
	check_world(bindings,cat,bodies,effects)
	verify_drift(bindings,cat,bodies,effects)
	print("Scenery displacement: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_drift(bindings: RefCounted,cat: RefCounted,bodies: RefCounted,effects: RefCounted) -> void:
	var world:=World.new()
	if not world.configure(bindings,cat,1789100000,true,bodies,effects):check(false,world.error);return
	var initial: Dictionary=world.snapshot()
	var selected:=candidates(initial)
	if selected.size()<2:check(false,"Missing authored asteroid fixture");return
	var index: int=selected[0];var untouched: int=selected[1]
	var origin: Vector3=initial.objects[index].position
	check(world._bodies.record_blast(index,Vector3.RIGHT,0.5),world._bodies.error)
	check(world.update(100,Vector3.ZERO),world.error)
	var intact:=world.snapshot()
	check(intact.objects[index].position==origin and intact.bodies.objects[index].motion_scalar==0.5,"Intact asteroid drifted or lost its pending blast impulse")
	world._random_state={"state":25214903899}
	check(world._bodies.normal_hit(index,2147483647).destroyed_now,"Could not prepare breakup")
	check(world.update(100,Vector3.ZERO),world.error)
	var triggered:=world.snapshot()
	check(triggered.objects[index].position==origin and triggered.destruction[index].effect.pose.origin==origin,"Trigger frame displaced the asteroid before breakup")
	check(not triggered.destruction[index].lifecycle.cargo.is_empty(),"Independent successful drop fixture did not produce junk")
	var random: Dictionary=triggered.random_state
	world.take_events()
	var parent:=world.snapshot()
	var a: RefCounted=world.fork_for_frame();var b: RefCounted=world.fork_for_frame()
	check(a.update(7,Vector3.ZERO) and b.update(100,Vector3.ZERO),a.error+b.error)
	var fast: Dictionary=a.snapshot();var slow: Dictionary=b.snapshot()
	var moved: Vector3=fast.objects[index].position-origin
	# Half-strength blasts move between506 and508 source units for the
	# original scale range; equal update counts share drift despite elapsed time.
	check(moved.x>=506.0 and moved.x<=508.0 and moved.y==0 and moved.z==0,"Breakup did not move outward by the observed whole-unit displacement")
	check(fast.objects[index].position==slow.objects[index].position and fast.bodies.objects[index].motion_scalar==slow.bodies.objects[index].motion_scalar,"Blast drift was incorrectly multiplied by frame duration")
	check(fast.destruction[index].effect.elapsed_ms==7 and slow.destruction[index].effect.elapsed_ms==100,"Drift made animation clocks depend on update count")
	check(fast.bodies.objects[index].position==origin and a._bodies.collision_context(index).center==origin,"Physical drift moved statistics or contact bounds")
	check(fast.destruction[index].effect.pose.origin==fast.objects[index].position and fast.destruction[index].lifecycle.cargo.pose.origin==fast.objects[index].position,"Breakup layers or junk were left at the old origin")
	check(fast.objects[untouched].position==initial.objects[untouched].position and fast.random_state==random and a.take_events().is_empty(),"Drift moved another asteroid, repeated drop accounting or consumed RNG")
	check(world.snapshot()==parent,"Candidate displacement corrupted the accepted field")
	var pause: Dictionary=a.snapshot()
	check(a.update(0,Vector3.ZERO) and a.snapshot()==pause,"Paused world advanced blast displacement or decay")
	check(a._bodies.retain_motion_scalar(index,0.0501),a._bodies.error)
	check(a.update(7,Vector3.ZERO),a.error)
	var exhausted: Dictionary=a.snapshot()
	check(exhausted.bodies.objects[index].motion_scalar==0.0,"Weak impulse did not expire below the visible threshold")
	check(a.update(7,Vector3.ZERO) and a.snapshot().objects[index].position==exhausted.objects[index].position,"Exhausted impulse kept moving junk")
	var before: Dictionary=b.snapshot()
	check(not b._bodies.record_blast(index,Vector3.ZERO,0.5) and b.snapshot()==before,"Invalid blast partly changed the retained world")
	check(b._bodies.record_blast(index,Vector3.UP,1.0),b._bodies.error)
	var duration: int=b.snapshot().destruction[index].effect.duration_ms
	while b.snapshot().destruction[index].effect.active:
		if not b.update(mini(100,duration+1),Vector3.ZERO):check(false,b.error);return
	var ended: Dictionary=b.snapshot()
	check(ended.bodies.objects[index].motion_scalar==0.0 and ended.destruction[index].lifecycle.actor_state==4,"Expired breakup retained a displacement impulse")
	var final_position: Vector3=ended.objects[index].position
	check(b.update(100,Vector3.ZERO) and b.update(100,Vector3.ZERO),b.error)
	check(b.snapshot().objects[index].position==final_position and b.snapshot().destruction[index].lifecycle.cargo.pose.origin==final_position,"Retirement moved the retained junk again")

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)
