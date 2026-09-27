extends "res://tests/mission_continuation.gd"
## Short native visibility component, not an earned escort or escape. Only the
## preceding radio is detached; ordinary frames own player pose and poll time.
## Inspect actual hull visibility/projection separately from camera identity.
var observations: Array[Dictionary]=[]

func verify_component(world: RefCounted) -> void:
	var original: Dictionary=world.snapshot()
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	for relative_mouse in [false,true]:
		await verify_visibility_path(world,relative_mouse)
		if is_instance_valid(scene):scene.free()
		if failures:break
	check(world.snapshot()==original,"Visibility branches mutated their shared initialized world")
	if not capture_path.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_path)
		var report:=FileAccess.open(capture_path.path_join("result-visibility.json"),FileAccess.WRITE)
		check(report!=null,"Could not open the result visibility observations")
		if report!=null:report.store_string(JSON.stringify(observations,"\t"));report.close()

func verify_visibility_path(world: RefCounted,relative_mouse: bool) -> void:
	var label: String="mouse" if relative_mouse else "keyboard"
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	active=Frame.new()
	if not active.configure(bindings,catalogues,library,context,world,1.0,root.size):check(false,active.error);return
	var visuals: RefCounted=load("res://src/content/visual_library.gd").new()
	if not visuals.open(visual_path,library.manifest):check(false,visuals.error);return
	scene=Scene.new();root.add_child(scene)
	if not scene.configure(library,bindings,visuals,catalogues,active,root.size):check(false,scene.error);return
	scene.world_changed.connect(func(candidate):active=candidate)
	scene.feedback.set_active(true)
	var camera_node: Camera3D=scene.camera;var player_node: Node3D=scene.player
	var skipped: RefCounted=active.skip_entry()
	if skipped==null:check(false,active.error);return
	active=skipped
	if not present():return
	for page in context.recipe().briefing.size():
		if not acknowledge():return
	# Shift the next result poll through actual free flight, not a timer edit.
	# Both modes receive exactly the same ordinary pose/control history.
	for tick in 46:
		if not visibility_step(100,relative_mouse):return
	observe_visibility(label,"ordinary")
	active._encounter=active._encounter.fork_for_frame()
	active._encounter._hook=active._encounter._hook.fork_for_frame()
	for index in 5:
		active._encounter._hook._radio._started[index]=true
		active._encounter._hook._radio._finished[index]=true
	var release: RefCounted;var preceding: RefCounted
	for tick in 700:
		preceding=active
		if not visibility_step(100,relative_mouse):return
		var state: Dictionary=active.frame_context()
		if state.encounter.sequence.phase==5 and release==null:
			release=active
			observe_visibility(label,"release")
			await capture("visibility-"+label+"-release")
		if active.campaign_dialogue_visible():break
	check(release!=null and active.dialogue().get("text_id")==2047,label+": timed native shots did not open result41")
	if failures:return
	var before: Dictionary=preceding.snapshot();var result: Dictionary=active.snapshot()
	var released: Dictionary=release.snapshot()
	check(int(result.elapsed_ms)-int(released.elapsed_ms)>0 and int(result.elapsed_ms)-int(released.elapsed_ms)<=600,label+": component missed its short natural release-to-result interval")
	check(before.runner.clock_ms<=5000 and int(before.runner.clock_ms)+100>5000,label+": result no longer uses its strict shared poll")
	check(result.encounter.view.camera==before.encounter.view.camera and result.player_pose!=before.player_pose,label+": opening result lost early motion or advanced the late camera")
	check(active._camera.response_snapshot().relative_capture==relative_mouse,label+": flight selected the wrong ordinary camera response")
	observe_visibility(label,"result")
	await capture("visibility-"+label+"-result")
	var modal: RefCounted=active.evaluate(100,Vector2.ONE,1.0,true,false,root.size,1.0,false,-1,not relative_mouse)
	check(modal!=null and modal.snapshot()==result,label+": modal input moved the camera/player or changed response")
	check(scene.camera==camera_node and scene.player==player_node,label+": result recreated its presentation owners")
	for page in 5:
		if not acknowledge():return
	var continued: Dictionary=active.snapshot()
	check(continued.campaign_cursor==42 and continued.player_pose==result.player_pose and continued.encounter.view.camera==result.encounter.view.camera,label+": final Next moved the retained view or lost living42")
	check(continued.equipment==result.equipment and continued.career.credits==result.career.credits,label+": result altered inventory or money")
	if not visibility_step(100,relative_mouse):return
	observe_visibility(label,"resumed-first")
	await capture("visibility-"+label+"-resumed-first")
	for tick in 39:
		if not visibility_step(100,relative_mouse):return
	observe_visibility(label,"resumed-four-seconds")
	await capture("visibility-"+label+"-resumed-four-seconds")
	check(scene.camera==camera_node and scene.player==player_node and active.initialized_world_owner()==world,label+": returning follow rebuilt a retained owner")
	check(preceding.snapshot()==before and release.snapshot()==released,label+": result/continuation mutated retained native parents")

func visibility_step(ms: int,relative_mouse: bool) -> bool:
	var next: RefCounted=active.evaluate(ms,Vector2.ZERO,1.0,false,false,root.size,0.0,false,scene.feedback.audio.current_music_id(),relative_mouse)
	if next==null:check(false,active.error);return false
	active=next
	return present()

func observe_visibility(label: String,moment: String) -> void:
	var state: Dictionary=active.frame_context();var camera: Camera3D=scene.camera
	var body: Node3D=scene.player;var center: Vector3=body.global_position
	var local_center: Vector3=camera.to_local(center)
	var projected: Vector2=camera.unproject_position(center)
	var viewport:=Rect2(Vector2.ZERO,Vector2(root.size))
	var meshes:=0;var drawing:=0;var points:=PackedVector2Array()
	for level in body.levels:
		for child in level.find_children("*","MeshInstance3D",true,false):
			meshes+=1
			if not child.is_visible_in_tree() or child.mesh==null:continue
			drawing+=1
			check((child.layers&camera.cull_mask)!=0,label+": drawable hull is masked out by the camera")
			var bounds: AABB=child.mesh.get_aabb()
			for corner in 8:
				var point: Vector3=child.global_transform*bounds.get_endpoint(corner)
				if camera.is_position_behind(point):continue
				var pixel: Vector2=camera.unproject_position(point)
				if pixel.is_finite():points.append(pixel)
	var rect:=Rect2()
	if not points.is_empty():
		rect=Rect2(points[0],Vector2.ZERO)
		for pixel in points:rect=rect.expand(pixel)
	var selection: Dictionary=body.selection
	var suppressed: bool=state.encounter.view.player_render_suppressed
	var drawable: bool=body.is_visible_in_tree() and selection.visible and not suppressed
	var native_camera: Transform3D=state.encounter.view.camera.pose
	var basis_error: float=maxf((camera.global_basis.x-native_camera.basis.x).length(),maxf((camera.global_basis.y-native_camera.basis.y).length(),(camera.global_basis.z-native_camera.basis.z).length()))
	# Node3D can round the assigned basis when synchronizing its transform.
	# Translation and identity stay exact; bound rotation error explicitly.
	check(body.transform==state.player_pose and camera.global_position==native_camera.origin and basis_error<0.000001,label+": renderer replaced the native player/camera pose; basis error "+str(basis_error))
	check(meshes>0 and (drawing>0)==drawable,label+": actual hull draw flags disagree with native visibility/LOD")
	check(local_center.is_finite() and projected.is_finite(),label+": camera-relative player projection is not finite")
	var row:={"input":label,"moment":moment,"elapsed_ms":state.elapsed_ms,"poll_ms":active.runner_owner().snapshot().clock_ms,
		"phase":state.encounter.sequence.phase,"dialogue":active.dialogue().get("text_id",-1),
		"player_pose":body.global_transform,"camera_pose":camera.global_transform,"camera_basis_error":basis_error,"camera_relative":local_center,
		"distance":center.distance_to(camera.global_position),"center_pixel":projected,
		"center_on_screen":not camera.is_position_behind(center) and viewport.has_point(projected),
		"near":camera.near,"far":camera.far,"within_depth":-local_center.z>=camera.near and -local_center.z<=camera.far,
		"root_visible":body.is_visible_in_tree(),"suppressed":suppressed,"selection":selection,
		"mesh_count":meshes,"drawing_meshes":drawing,"projected_hull":rect,
		"hull_intersects_view":not points.is_empty() and viewport.intersects(rect),
		"response":active._camera.response_snapshot()}
	# A consistent but permanently culled ship must not pass this component.
	# Do not require visibility during the uncompleted return itself.
	if moment in ["ordinary","resumed-four-seconds"]:
		check(drawable and drawing>0 and row.center_on_screen and row.within_depth and row.hull_intersects_view,label+": ordinary follow failed to show the retained player hull at "+moment)
	observations.append(row)
	print("Result visibility ",JSON.stringify(row))
