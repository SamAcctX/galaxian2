extends "res://tests/conventional_secondary_geometry.gd"
## Detached fitted launchers and constructed targets exercise visible mine
## bodies, retained bursts, damage and audio. No career or purchase is earned.
const BurstResources=preload("res://src/content/emp_detonation_resources.gd")
const PlaybackAudio=preload("res://src/presentation/opening_audio.gd")
const Fitting=preload("res://src/simulation/equipment_fitting.gd")

func _initialize() -> void:call_deferred("run_mines")

func run_mines() -> void:
	var args:=OS.get_cmdline_user_args()
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new();var visuals:=Visuals.new()
	if args.size()!=3 or not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not mounts.open(lib,cat) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+mounts.error+visuals.error);finish_geometry();return
	var built:=construction(bindings,cat,0.5)
	if built==null:finish_geometry();return
	root.size=Vector2i(1280,720)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.near=1;camera.far=1000000
	var light:=DirectionalLight3D.new();light.rotation=Vector3(-0.65,-0.6,0);root.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();root.add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.02,0.025,0.035)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.5
	var fitting:=Fitting.new();var assets:=fitting.prepare_assets(bindings,cat,lib)
	if assets.is_empty():check(false,fitting.error);finish_geometry();return
	for item in [60,61,62]:
		var owner:=Ownership.new();var group:=active_group(bindings,cat,built,0)
		var initial:=equipped(bindings,cat,[{"item_id":item,"slot":0,"quantity":2}])
		if group==null or not owner.configure(bindings,cat,initial,mounts):check(false,owner.error);continue
		var support:=fitting.inspect(bindings,cat,initial,assets)
		check(not support.is_empty() and assets.items.get(item)=="", "Mine fitting rejected its supported original assets: "+fitting.error)
		var bursts:=BurstResources.new()
		if not bursts.configure(lib,bindings,Ownership.Mines.Definitions.effect_family(item)) or not owner.configure_detonations(bursts) or not owner.configure_projectile_visuals(lib,bindings):check(false,bursts.error+owner.error);continue
		var geometry:=Geometry.new();root.add_child(geometry)
		var audio:=PlaybackAudio.new();root.add_child(audio)
		if not geometry.build(owner,lib,visuals,bindings) or not audio.configure(lib,bindings,730):check(false,geometry.error+audio.error);geometry.free();audio.free();continue
		audio.set_paused(true)
		var cached_clip: Dictionary=audio._resources.prepare(6)
		if not cached_clip.get("stream") is AudioStream:check(false,"Existing EMP sample was not prepared");geometry.free();audio.free();continue
		var order:=[0,1,2,3];var center:=Vector3(100000,100000,100000)
		var mine: Dictionary=owner.snapshot().guns[0].mine
		var step:=owner.evaluate_advance(1,group,order,center)
		if step.is_empty():check(false,owner.error);geometry.free();audio.free();continue
		owner=step.owner
		var clock:=1
		for round in 2:
			var pose:=Transform3D(Basis.IDENTITY,center+Vector3(round*200,0,0)-Vector3(mine.weapon.muzzle_offset))
			var prior:=owner.snapshot()
			var fired:=owner.evaluate_trigger(pose,item,group,order)
			if fired.is_empty():check(false,owner.error);break
			check(owner.snapshot()==prior and fired.events.size()==1 and fired.events[0].action=="launched","Mine launch mutated its parent or omitted its accepted round")
			owner=fired.owner
			var world:=sound_world(bindings,owner,fired.events,clock)
			var frame:=audio.prepare_frame(round,{"elapsed_ms":clock},world)
			if frame.is_empty():check(false,audio.error);break
			audio.commit_frame(frame)
			check(audio.snapshot().unsupported.is_empty() and audio.snapshot().active.has(Ownership.Mines.Definitions.declaration(item).launch_sound),"Mine did not decode and play its original launch sound: "+str(audio.snapshot().unsupported))
			check(audio._resources._banks.size()<=4,"Loading a mine's sound bank removed the resident cache bound")
			if round==0:
				var delta: int=mine.weapon.interval_ms+1
				step=owner.evaluate_advance(delta,group,order,center);clock+=delta
				if step.is_empty():check(false,owner.error);break
				owner=step.owner
		var state:=owner.snapshot()
		check(state.guns[0].ammunition==0 and state.guns[0].mine.slots.filter(func(shot):return shot!=null).size()==2,"Spending the last mine erased deployed bodies")
		check(owner.selection_feedback(item).actions.is_empty() and owner.reconcile_loadout(initial).slots[state.guns[0].slot_index]==null,"Empty mine launcher offered remote detonation or restored spent ammunition")
		var renderer: Node3D=geometry._mines[0]
		var radius: float=maxf(renderer.bodies[0].source_bounds.size.length(),500.0)
		camera.look_at_from_position(center+Vector3(1.2,0.7,1.8)*radius,center)
		var frame:=geometry.prepare_world(owner,camera.transform)
		if frame.is_empty():check(false,geometry.error);geometry.free();audio.free();continue
		geometry.commit_world(frame)
		check(renderer.bodies.filter(func(body):return body.visible).size()==2 and renderer.attachments.filter(func(body):return body.visible).size()==2,"Mine body or additive attachment was missing")
		await capture_geometry("mine-%d-deployed"%item)
		var paused:=owner.snapshot();var paused_pose: Transform3D=renderer.bodies[0].transform
		for unused in 3:await process_frame
		check(owner.snapshot()==paused and renderer.bodies[0].transform==paused_pose,"Paused presentation advanced mine tumble or effects")
		# Move only this detached target through the real collision owner. The
		# application pilot must earn its own positioning through flight input.
		group=group.fork_for_frame()
		if not group.set_pose(0,Transform3D(Basis.IDENTITY,center)):check(false,group.error);geometry.free();audio.free();continue
		var before: Dictionary=group.snapshot()
		step=owner.evaluate_advance(100,group,order,center+Vector3(0,0,500));clock+=100
		if step.is_empty():check(false,owner.error);geometry.free();audio.free();continue
		check(group.snapshot()==before and owner.snapshot()==paused,"Preparing mine contact changed its parent combat or launcher")
		owner=step.owner;group=step.combat;state=owner.snapshot()
		check(step.events.size()==2 and step.self_hits.is_empty() and state.detonation_audio.size()==2,"Simultaneous mine contact lost a pulse, sound, or invented own-ship damage")
		if item==61:check(group.snapshot().actors[0].systems.disabled and group.snapshot().actors[0].vitals==before.actors[0].vitals and step.events.all(func(event):return event.normal_hits.is_empty()),"EMP mine did not disable the target without normal damage")
		else:check(group.snapshot().actors[0].vitals.hull<before.actors[0].vitals.hull,"Normal mine did not damage the constructed target")
		var mixed:=audio.prepare_frame(2,{"elapsed_ms":clock},sound_world(bindings,owner,step.events,clock))
		if mixed.is_empty():check(false,audio.error);geometry.free();audio.free();continue
		audio.commit_frame(mixed)
		check(audio.snapshot().unsupported.is_empty() and audio.snapshot().active.has(22),"Simultaneous mines failed to play their shared original detonation sound")
		check(audio._resources.prepare(6).get("stream")==cached_clip.stream and cached_clip.stream.get_length()>0,"Replacing a cold bank invalidated an earlier prepared clip")
		var bad:=sound_world(bindings,owner,step.events,clock)
		bad.secondaries.detonation_audio.append(bad.secondaries.detonation_audio[0].duplicate())
		var played:=audio.snapshot()
		check(audio.prepare_frame(3,{"elapsed_ms":clock+1},bad).is_empty() and audio.snapshot()==played,"Duplicated mine sound partly changed playback")
		camera.look_at_from_position(center+Vector3(3500,2500,5000),center)
		var stale:=frame;frame=geometry.prepare_world(owner,camera.transform)
		if frame.is_empty():check(false,geometry.error);geometry.free();audio.free();continue
		geometry.commit_world(frame)
		check(renderer.bodies.all(func(body):return not body.visible) and geometry.detonations.filter(func(effect):return effect.visible).size()==2,"Mine explosion erased another burst or retained its detonated body")
		await capture_geometry("mine-%d-bursts"%item)
		geometry.commit_world(stale)
		check(not geometry.error.is_empty() and renderer.bodies.all(func(body):return not body.visible),"A stale frame revived detonated mines")
		step=owner.evaluate_advance(100,group,order,center)
		if step.is_empty():check(false,owner.error);geometry.free();audio.free();continue
		owner=step.owner
		check(step.events.is_empty() and owner.snapshot().detonation_audio.is_empty() and owner.snapshot().guns[0].mine_bursts.camera.elapsed_ms==300,"Mine burst repeated damage/audio or lost its shared camera clock")
		var shake:=owner.evaluate_camera({"state":42})
		check(not shake.is_empty() and shake.offset.is_finite(),"Mine camera could not consume its accepted shared burst sample")
		var pool: RefCounted=owner._guns[0].mine_bursts.fork()
		var replacement: Dictionary={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"item_id":item,"slot":0,"projectile_id":100,"position":center+Vector3(5000,0,0)}
		var old_effect: Dictionary=pool.snapshot().bursts[0].effect
		var continuing: Dictionary=pool.advance([replacement],1,center)
		check(not continuing.is_empty() and continuing.audio.is_empty() and pool.snapshot().bursts[0].effect.position==old_effect.position,"Reused mine slot restarted an unfinished explosion")
		var retired: Dictionary=pool.advance([],int(old_effect.duration_ms)+1,center)
		check(not retired.is_empty() and pool.snapshot().bursts.all(func(burst):return not burst.effect.active) and pool.snapshot().camera.strength==0.0,"Mine burst pool did not retire its effects and camera")
		replacement.projectile_id=101
		var restarted: Dictionary=pool.advance([replacement],1,center)
		check(not restarted.is_empty() and restarted.audio.size()==1 and pool.snapshot().bursts[0].effect.position==replacement.position,"Retired burst slot could not display a later mine explosion")
		geometry.free();audio.free()
	print("Mine ownership and presentation: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

static func sound_world(bindings: RefCounted,owner: RefCounted,events: Array,clock: int) -> Dictionary:
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":clock,"actor_events":[],"secondaries":owner.snapshot(),"secondary_events":events}
