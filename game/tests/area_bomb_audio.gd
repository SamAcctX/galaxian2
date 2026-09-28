extends "res://tests/secondary_retention.gd"
## Actual bomb-owner transitions through the playback adapter. Detached
## equipment here exercises sound ordering, not a purchase or earned career.
const BombAudio=preload("res://src/presentation/opening_audio.gd")
const BurstResources=preload("res://src/content/emp_detonation_resources.gd")

func _initialize() -> void:call_deferred("run_bomb_audio")

func run_bomb_audio() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify_bomb_audio(args)
	else:check(false,"Expected content, bindings and visuals")
	await process_frame
	print("Area bomb playback: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_bomb_audio(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat):check(false,lib.error+bindings.error+cat.error+mounts.error);return
	var built:=construction(bindings,cat,0.5)
	if built==null:return
	for item in range(41,47):
		var owner:=Ownership.new();var burst:=BurstResources.new();var audio:=BombAudio.new();root.add_child(audio)
		var initial:=equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":2}])
		var declaration:=Ownership.Bomb.Definitions.declaration(item)
		if not owner.configure(bindings,cat,initial,mounts) or not burst.configure(lib,bindings,declaration.kind) or not owner.configure_detonations(burst) or not audio.configure(lib,bindings,730):
			check(false,owner.error+burst.error+audio.error);audio.free();continue
		audio.set_paused(true)
		var group:=active_group(bindings,cat,built,0)
		if group==null:audio.free();continue
		var pose:=Transform3D(Basis.IDENTITY,Vector3(100000,0,100000))
		var step:=owner.evaluate_advance(1,group,[0,1,2,3],pose.origin)
		if step.is_empty():check(false,owner.error);audio.free();continue
		owner=step.owner
		var launch:=owner.evaluate_trigger(pose,item,group,[0,1,2,3])
		if launch.is_empty():check(false,owner.error);audio.free();continue
		owner=launch.owner;group=launch.combat
		var world:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":1,"actor_events":[],"secondaries":owner.snapshot(),"secondary_events":launch.events}
		var before:=audio.snapshot();var frame:=audio.prepare_frame(0,{"elapsed_ms":1},world)
		check(not frame.is_empty() and audio.snapshot()==before,"Preparing a bomb launch played audio or rejected an admitted launcher")
		if frame.is_empty():check(false,audio.error);audio.free();continue
		audio.commit_frame(frame)
		var played:=audio.snapshot()
		check(played.unsupported.is_empty() and played.active.has(declaration.launch_sound) and played.active[declaration.launch_sound].position==pose.origin and played.active[declaration.launch_sound].paused,"Launch omitted its decoded original spatial recording")
		# Expiry is observed in the early pass. A new round and a primary can
		# fire later in that same frame, even after the old effect has retired.
		var interval:=int(owner.snapshot().guns[0].bomb.weapon.interval_ms)
		step=owner.evaluate_advance(interval+1,group,[0,1,2,3],pose.origin)
		if step.is_empty():check(false,owner.error);audio.free();continue
		owner=step.owner;group=step.combat
		launch=owner.evaluate_trigger(pose,item,group,[0,1,2,3])
		if launch.is_empty():check(false,owner.error);audio.free();continue
		owner=launch.owner
		var primary:=Primaries.new()
		if not primary.configure(bindings,cat,mounts,initial):check(false,primary.error);audio.free();continue
		primary.advance(interval+2)
		var primary_fire:=primary.fire(pose,true,{"state":1234})
		if primary_fire.is_empty():check(false,primary.error);audio.free();continue
		world.elapsed_ms=interval+2;world.secondaries=owner.snapshot();world.secondary_events=launch.events
		world.primaries=primary.snapshot();world.primary_fire=primary_fire
		var routed:=audio.prepare_combat(world,world.elapsed_ms)
		var primary_sound: int=world.primaries.guns[0].audio.source_id
		check(not routed.is_empty() and routed.operations.map(func(op):return op.source_id)==[declaration.burst_sound,primary_sound,declaration.launch_sound],"Same-frame bomb expiry, primary and relaunch played in the wrong order")
		frame=audio.prepare_frame(1,{"elapsed_ms":world.elapsed_ms},world)
		if frame.is_empty():check(false,audio.error);audio.free();continue
		audio.commit_frame(frame);played=audio.snapshot()
		check(played.unsupported.is_empty() and played.active.has(declaration.burst_sound),"Bomb explosion did not decode and play its original sound")
		audio.commit_frame(frame)
		check(audio.snapshot()==played,"Replaying an accepted bomb frame repeated its sounds")
		var bad:=world.duplicate(true);bad.secondaries.detonation_audio[0].source_id=19999
		check(audio.prepare_frame(2,{"elapsed_ms":world.elapsed_ms},bad).is_empty() and audio.snapshot()==played,"An invalid bomb cue partially changed playback")
		audio.clear();audio.free()
