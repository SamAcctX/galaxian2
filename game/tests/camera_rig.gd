extends SceneTree
const Definitions = preload("res://src/content/camera_follow_definitions.gd")
const Fixture = preload("res://tests/camera_follow_fixture.gd")
const Rig = preload("res://src/simulation/camera_rig.gd")
const Director = preload("res://src/simulation/opening_camera.gd")
const Staging = preload("res://src/simulation/opening_staging.gd")
const Radio = preload("res://src/simulation/radio_sequence.gd")
const Library = preload("res://src/content/library.gd")
const Bindings = preload("res://src/content/resource_bindings.gd")
const Catalogues = preload("res://src/content/catalogues.gd")
var failures := 0

func _initialize() -> void:
	for mac in [true, false]:
		var data: Dictionary = JSON.parse_string(JSON.stringify(Fixture.definition(mac)))
		var arch := "x86_64" if mac else "armv7"
		check(Definitions.validate(data, 65536, arch).is_empty(), "Valid follow declarations rejected")
		for bad in ["missing", "nan", "bool", "rate", "matrix", "row", "offset", "extent", "overlap"]:
			var copy := data.duplicate(true)
			match bad:
				"missing": copy.erase("eye_offset")
				"nan": copy.response_matrix[1][1] = NAN
				"bool": copy.look_rate = true
				"rate": copy.eye_rate = 0
				"matrix": copy.response_matrix.pop_back()
				"row": copy.response_matrix[0].append(0)
				"offset": copy.look_offset[0] = INF
				"extent": copy.provenance.curve.offset = 65536
				"overlap": copy.provenance.follow.offset = copy.provenance.curve.offset
			check(not Definitions.validate(copy, 65536, arch).is_empty(), "Invalid follow declaration accepted: " + bad)
	var bindings := Bindings.new()
	bindings.base_content_id = "a".repeat(64); bindings.binding_id = "b".repeat(64)
	bindings.camera_follow = Fixture.definition()
	bindings.frame_clock = {"max_frame_milliseconds": 150, "time_unit": "milliseconds"}
	verify_auxiliary(bindings)
	verify_orbit(bindings)
	var rig := Rig.new()
	check(rig.configure(bindings), rig.error)
	var shot := {"base_content_id": bindings.base_content_id, "binding_id": bindings.binding_id,
		"mode": "fixed_eye", "target": "player", "eye": Vector3(-120, 40, -300), "inherit_target_up": true}
	var scene := {"base_content_id": bindings.base_content_id, "binding_id": bindings.binding_id,
		"player_pose": Transform3D(Basis.from_euler(Vector3(0.2, 0.4, -0.3)), Vector3(400, -50, 700))}
	check(rig.update(0, shot, scene) and rig.snapshot().is_empty(), "Zero time created a view")
	check(rig.update(16, shot, scene), rig.error)
	var saved := rig.snapshot()
	check(saved.eye == shot.eye and saved.look == scene.player_pose.origin, "Fixed eye changed source coordinates")
	shot.mode = "follow"
	check(rig.update(0, shot, scene) and rig.snapshot() == saved, "Zero-time handoff changed the rendered view")
	check(rig.update(16, shot, scene), rig.error)
	near(rig.snapshot().eye, saved.eye.lerp(scene.player_pose * Vector3(-18, 45, -220), 0.5), "Eye did not follow rotated target offset")
	near(rig.snapshot().look, saved.look.lerp(scene.player_pose * Vector3(12, 30, 100), 0.25), "Look did not use its own response")
	for i in 128:
		var before := rig.snapshot()
		scene.player_pose = Transform3D(Basis.from_euler(Vector3(0.3 * sin(i), i * 0.01, 0.1 * cos(i))), Vector3(400 + i, i * 0.5, 700 + i * 3))
		check(rig.update(1 + i % 150, shot, scene), rig.error)
		var current := rig.snapshot()
		near(current.eye, before.eye.lerp(scene.player_pose * Vector3(-18, 45, -220), 0.5), "Moving eye response changed")
		near(current.look, before.look.lerp(scene.player_pose * Vector3(12, 30, 100), 0.25), "Moving look response changed")
		var centered: Vector3 = current.pose.affine_inverse() * current.look
		check(absf(centered.x) < 0.001 and absf(centered.y) < 0.001 and centered.z < 0, "Follow look is not centered")
	for bad in ["time", "cap", "fraction", "identity", "binding", "scene", "mode", "target", "missing", "scaled", "reflected", "nonfinite", "eye", "up"]:
		var copy := shot.duplicate(true); var world := scene.duplicate(true); var delta: Variant = 16
		match bad:
			"time": delta = -1
			"cap": delta = 151
			"fraction": delta = 0.5
			"identity": copy.base_content_id = "c".repeat(64)
			"binding": copy.binding_id = "c".repeat(64)
			"scene": world.binding_id = "c".repeat(64)
			"mode": copy.mode = "cockpit"
			"target": copy.target = "unknown"
			"missing": world.erase("player_pose")
			"scaled": world.player_pose.basis = Basis.IDENTITY.scaled(Vector3(2, 1, 1))
			"reflected": world.player_pose.basis = Basis.IDENTITY.scaled(Vector3(-1, 1, 1))
			"nonfinite": world.player_pose.origin.x = NAN
			"eye": copy.mode = "fixed_eye"; copy.eye = Vector3(INF, 0, 0)
			"up": copy.mode = "fixed_eye"; copy.inherit_target_up = 1
		saved = rig.snapshot()
		check(not rig.update(delta, copy, world) and rig.snapshot() == saved, "Invalid update changed view: " + bad)
		if delta == 16: check(not rig.update(0, copy, world) and rig.snapshot() == saved, "Zero-time invalid input accepted: " + bad)
	saved = rig.snapshot(); saved.eye.x = 12345
	check(rig.snapshot().eye.x != 12345, "Snapshot mutated rig")
	check(rig.configure(bindings) and not rig.update(16, shot, scene) and rig.snapshot().is_empty(), "Follow invented previous view")
	bindings.camera_follow = {}
	check(not rig.configure(bindings) and rig.snapshot().is_empty(), "Failed configuration retained view")
	var args := OS.get_cmdline_user_args()
	check(args.size() % 2 == 0, "Expected content/bindings pairs")
	for i in range(0, args.size() - 1, 2): verify_source(args[i], args[i + 1])
	print("Camera rig checks: %d failures" % failures)
	quit(1 if failures else 0)

func verify_source(content: String, pack: String) -> void:
	var library := Library.new(); var bindings := Bindings.new(); var catalogues := Catalogues.new()
	check(library.open(content) and library.select_language("gb"), library.error)
	check(bindings.open(pack, library.manifest), bindings.error)
	check(catalogues.open(library), catalogues.error)
	verify_auxiliary(bindings)
	verify_orbit(bindings)
	var rig := Rig.new(); var director := Director.new(); var staging := Staging.new(); var radio := Radio.new()
	check(staging.configure(bindings, catalogues, catalogues.content_id), staging.error)
	check(director.configure(bindings), director.error)
	check(rig.configure(bindings), rig.error)
	if rig.error != "" or director.snapshot().is_empty(): return
	var counts := []; counts.resize(23); counts.fill(1)
	check(radio.configure(bindings, library, counts), radio.error)
	var time := 1500
	for event in 9:
		for finishing in [false, true]:
			if finishing: time += 5501
			radio.step(time, {}, 0)
			check(staging.update(radio.snapshot()) and director.advance(16, radio.snapshot()), director.error)
			check(rig.update(16, director.snapshot(), staging.snapshot(), director.fixed_refresh(), director.view_translation()), rig.error)
	check(rig.snapshot().mode == "follow", "Radio handoff did not produce player-follow view")
	var world := staging.snapshot()
	var desired_eye: Vector3 = world.player_pose * Staging.vec(bindings.camera_follow.eye_offset)
	var desired_look: Vector3 = world.player_pose * Staging.vec(bindings.camera_follow.look_offset)
	# Check every permitted time against an independent sum-of-powers oracle,
	# then verify convergence and a moving/rotating player after the handoff.
	for rate in [bindings.camera_follow.eye_rate, bindings.camera_follow.look_rate]:
		var coefficients := Rig.coefficients(bindings.camera_follow.response_matrix, rate)
		for milliseconds in range(1, int(bindings.frame_clock.max_frame_milliseconds) + 1):
			var expected := 0.0
			for power in 5:
				var coefficient := 0.0
				for degree in 9: coefficient += float(bindings.camera_follow.response_matrix[power][degree]) * pow(rate, degree)
				expected += coefficient * pow(milliseconds, power)
			expected *= PackedFloat32Array([bindings.camera_follow.reciprocal_numerator / milliseconds])[0]
			var weight := Rig.weight(coefficients, milliseconds, bindings.camera_follow.reciprocal_numerator)
			check(absf(weight - expected) < 0.000001, "Imported response curve disagrees with independent evaluation")
	for i in 600: check(rig.update(16, director.snapshot(), world), rig.error)
	converged(rig.snapshot().eye, desired_eye, Rig.weight(Rig.coefficients(bindings.camera_follow.response_matrix, bindings.camera_follow.eye_rate), 16, bindings.camera_follow.reciprocal_numerator))
	converged(rig.snapshot().look, desired_look, Rig.weight(Rig.coefficients(bindings.camera_follow.response_matrix, bindings.camera_follow.look_rate), 16, bindings.camera_follow.reciprocal_numerator))
	world.player_pose = Transform3D(Basis.from_euler(Vector3(0.1, 0.6, -0.2)), world.player_pose.origin + Vector3(100, 10, 500))
	check(rig.update(33, director.snapshot(), world), rig.error)
	check(rig.snapshot().pose.basis.determinant() > 0.999, "Moving follow orientation invalid")
	print(library.manifest.profile.edition, ": radio/staging/camera handoff, response curve and moving follow verified")

func verify_auxiliary(bindings: RefCounted) -> void:
	var rig:=Rig.new()
	check(not rig.set_auxiliary_enabled(false) and rig.auxiliary_snapshot().is_empty(),"Unconfigured auxiliary camera accepted a reset")
	check(rig.configure(bindings),rig.error)
	check(not rig.set_auxiliary_enabled(true) and not rig.auxiliary_snapshot().enabled,"Auxiliary activation invented an anchor")
	var target:=Transform3D(Basis.from_euler(Vector3(0.2,0.4,-0.3)),Vector3(400,-50,700))
	var scene:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"player_pose":target}
	var shot:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye","target":"player","eye":Vector3(-120,40,-300),"inherit_target_up":true}
	check(rig.update(16,shot,scene),rig.error)
	var anchor:=Transform3D(Basis.from_euler(Vector3(-0.3,-0.7,0.2)),Vector3(-900,240,1100))
	check(rig.set_auxiliary_anchor(anchor) and rig.set_auxiliary_enabled(true),rig.error)
	var before:=rig.snapshot();var auxiliary:=rig.auxiliary_snapshot()
	check(not rig.update(16,shot,scene) and rig.snapshot()==before and rig.auxiliary_snapshot()==auxiliary,"A fixed shot bypassed auxiliary cancellation")
	shot.mode="follow"
	check(rig.update(0,shot,scene) and rig.snapshot()==before and rig.auxiliary_snapshot()==auxiliary,"Zero time advanced an auxiliary view")
	check(not rig.update(16,shot,scene,{},null,Vector3.ONE) and rig.snapshot()==before and rig.auxiliary_snapshot()==auxiliary,"Unprepared auxiliary shake mutated the view")
	var eye_weight:=Rig.weight(Rig.coefficients(bindings.camera_follow.response_matrix,bindings.camera_follow.eye_rate),16,bindings.camera_follow.reciprocal_numerator)
	var completed:=false;var ready:=false
	for tick in 128:
		# Disclosed moving-anchor mathematics, not equipment or career state.
		# A later large translation also exercises the finite transition end.
		if tick==4:
			anchor.origin+=Vector3(40000,12000,-30000)
			check(rig.set_auxiliary_anchor(anchor),rig.error)
		before=rig.snapshot();auxiliary=rig.auxiliary_snapshot()
		var desired:=anchor*Vector3(0,150,800)
		var terminal: bool=auxiliary.initial_distance>0 and auxiliary.travelled>=Rig.single(auxiliary.initial_distance*1.5)
		var expected: Vector3=desired if terminal else before.eye.lerp(desired,eye_weight)
		check(rig.update(16,shot,scene),rig.error)
		var state:=rig.snapshot();var current:=rig.auxiliary_snapshot()
		# Closed-form half-turn geometry is independent of the rig's matrix
		# composition. Float32 pi/large-coordinate rounding fits this bound.
		near(state.eye,expected,"Auxiliary camera ignored its own anchor/response",0.03)
		near(state.look,state.eye+anchor.basis.z,"Auxiliary view lost its reversed forward axis",0.01)
		check(current.initial_distance>=0 and current.travelled>=auxiliary.travelled and current.enabled,"Auxiliary progress regressed or disabled itself")
		check(current.transition_pending==(current.travelled>Rig.single(current.initial_distance*0.75)),"Auxiliary ready latch lost its strict distance threshold")
		completed=completed or terminal;ready=ready or current.transition_pending
	check(completed and ready,"Moving native anchor never reached the auxiliary transition boundary")
	var original:=rig.snapshot();var original_aux:=rig.auxiliary_snapshot();var response:=rig.response_snapshot()
	var restored: RefCounted=rig.fork_for_frame()
	check(restored.set_auxiliary_enabled(false),restored.error)
	var reset: Dictionary=restored.auxiliary_snapshot()
	check(restored.snapshot()==original and restored.response_snapshot()==response,"Auxiliary cancellation replaced view history or follow response")
	check(not reset.enabled and reset.travelled==0 and reset.initial_distance==0 and reset.offset==Vector3(0,150,-800) and reset.transition_pending==original_aux.transition_pending and reset.anchor==original_aux.anchor,"Auxiliary reset changed the wrong state fields")
	check(restored.update(0,shot,scene) and restored.snapshot()==original and restored.auxiliary_snapshot()==reset,"Zero-time return changed view or progress")
	var expected_eye: Vector3=original.eye.lerp(target*Staging.vec(bindings.camera_follow.eye_offset),eye_weight)
	var look_weight:=Rig.weight(Rig.coefficients(bindings.camera_follow.response_matrix,bindings.camera_follow.look_rate),16,bindings.camera_follow.reciprocal_numerator)
	var expected_look: Vector3=original.look.lerp(target*Staging.vec(bindings.camera_follow.look_offset),look_weight)
	check(restored.update(16,shot,scene),restored.error)
	near(restored.snapshot().eye,expected_eye,"Auxiliary reset replaced the ordinary eye offset",0.01)
	near(restored.snapshot().look,expected_look,"Auxiliary reset replaced the ordinary look offset",0.01)
	check(restored.auxiliary_snapshot().transition_pending==(restored.auxiliary_snapshot().travelled<800.0),"Ordinary return lost its independent 800-unit threshold")
	check(rig.snapshot()==original and rig.auxiliary_snapshot()==original_aux,"Forked auxiliary cancellation mutated its parent")
	# A terminal view at its desired eye is a genuine zero-distance transition,
	# not a hand-edited progress counter.
	check(rig.set_auxiliary_enabled(true) and rig.update(16,shot,scene),rig.error)
	check(rig.auxiliary_snapshot().initial_distance==0 and rig.auxiliary_snapshot().travelled==0 and not rig.auxiliary_snapshot().transition_pending,"Zero-distance auxiliary transition produced stale progress or NaN")
	for invalid in [true,1,null,Vector3.ZERO,Transform3D(Basis.IDENTITY.scaled(Vector3(2,1,1)),Vector3.ZERO),Transform3D(Basis.IDENTITY,Vector3(INF,0,0))]:
		before=rig.snapshot();auxiliary=rig.auxiliary_snapshot()
		check(not rig.set_auxiliary_anchor(invalid) and rig.snapshot()==before and rig.auxiliary_snapshot()==auxiliary,"Malformed auxiliary anchor changed retained state")
	for invalid in [1,0,null,"false"]:
		before=rig.snapshot();auxiliary=rig.auxiliary_snapshot()
		check(not rig.set_auxiliary_enabled(invalid) and rig.snapshot()==before and rig.auxiliary_snapshot()==auxiliary,"Non-boolean auxiliary mode changed retained state")
	var failed: RefCounted=rig.fork_for_frame()
	check(failed.set_auxiliary_anchor(Transform3D(Basis.IDENTITY,Vector3(3e38,3e38,3e38))) and failed.set_auxiliary_enabled(true),failed.error)
	before=failed.snapshot();auxiliary=failed.auxiliary_snapshot()
	check(not failed.update(16,shot,scene) and failed.snapshot()==before and failed.auxiliary_snapshot()==auxiliary,"Overflowing auxiliary frame partially committed view or progress")
	print("Auxiliary camera: live anchor, blend/ready/return, zero-distance, reset, rollback and fork isolation verified")

func verify_orbit(bindings: RefCounted) -> void:
	var rig:=Rig.new()
	check(not rig.set_orbit_enabled(true) and rig.orbit_snapshot().is_empty(),"Unconfigured orbit was admitted")
	check(rig.configure(bindings),rig.error)
	var target:=Transform3D(Basis.from_euler(Vector3(0.3,-0.7,0.2)),Vector3(400,-50,700))
	var scene:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"player_pose":target}
	var shot:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"mode":"fixed_eye","target":"player","eye":Vector3(-120,40,-300),"inherit_target_up":true}
	check(rig.update(0,shot,scene,shot),rig.error)
	var initial:=rig.snapshot();var initial_orbit:=rig.orbit_snapshot();var auxiliary:=rig.auxiliary_snapshot()
	var angles:=Vector3(-0.175,0.49,0)
	check(rig.set_orbit_parameters(angles,3800) and rig.set_orbit_enabled(true),rig.error)
	check(rig.snapshot()==initial and rig.auxiliary_snapshot()==auxiliary,"Orbit selection replaced history or enabled an auxiliary camera")
	shot.mode="follow"
	var selected:=rig.orbit_snapshot()
	check(rig.update(0,shot,scene) and rig.snapshot()==initial and rig.orbit_snapshot()==selected,"Zero-time orbit normalized its offset or changed the view")
	var eye_weight:=Rig.weight(Rig.coefficients(bindings.camera_follow.response_matrix,bindings.camera_follow.eye_rate),16,bindings.camera_follow.reciprocal_numerator)
	var look_weight:=Rig.weight(Rig.coefficients(bindings.camera_follow.response_matrix,bindings.camera_follow.look_rate),16,bindings.camera_follow.reciprocal_numerator)
	var base_eye: Vector3=initial_orbit.eye_offset.normalized()*3800
	var base_look:=Staging.vec(bindings.camera_follow.look_offset)
	for tick in 24:
		angles=Vector3(-0.175+tick*0.02,0.49-tick*0.035,tick*0.01)
		target.origin+=Vector3(2,-1,4);scene.player_pose=target
		check(rig.set_orbit_parameters(angles,3800),rig.error)
		var before:=rig.snapshot()
		# Independent sequential vector rotations: rightmost Z, then X, then Y.
		# The rig composes bases; this oracle never reads its rotated target.
		var desired_eye: Vector3=target*base_eye.rotated(Vector3.BACK,angles.z).rotated(Vector3.RIGHT,angles.x).rotated(Vector3.UP,angles.y)
		var desired_look: Vector3=target*base_look.rotated(Vector3.BACK,angles.z).rotated(Vector3.RIGHT,angles.x).rotated(Vector3.UP,angles.y)
		check(rig.update(16,shot,scene),rig.error)
		var current:=rig.snapshot()
		near(current.eye,before.eye.lerp(desired_eye,eye_weight),"Orbit changed local YXZ order, target composition or source eye response",0.02)
		near(current.look,before.look.lerp(desired_look,look_weight),"Orbit failed to rotate the source look offset",0.02)
		var backwards: Vector3=(current.eye-current.look).normalized()
		near(current.pose.basis.x,target.basis.y.cross(backwards).normalized(),"Orbit rotated inherited up with its offsets",0.00001)
		check(absf(rig.orbit_snapshot().eye_offset.length()-3800)<0.002 and not rig.auxiliary_snapshot().enabled,"Orbit lost its radius or enabled the auxiliary path")
	var parent:=rig.snapshot();var parent_orbit:=rig.orbit_snapshot()
	var copy: RefCounted=rig.fork_for_frame()
	check(copy.set_orbit_enabled(false) and copy.orbit_snapshot().eye_offset==parent_orbit.eye_offset,"Leaving orbit reset the retained normalized offset")
	check(copy.update(16,shot,scene),copy.error)
	near(copy.snapshot().eye,parent.eye.lerp(target*parent_orbit.eye_offset,eye_weight),"Returning to follow invented a new distance",0.02)
	check(rig.snapshot()==parent and rig.orbit_snapshot()==parent_orbit,"Forked return changed its parent")
	for invalid in [true,null,Vector2.ZERO,Vector3(INF,0,0)]:
		check(not rig.set_orbit_parameters(invalid,3800) and rig.orbit_snapshot()==parent_orbit,"Malformed orbit angles changed retained parameters")
	for invalid in [true,null,-1,0,INF,NAN,"3800"]:
		check(not rig.set_orbit_parameters(angles,invalid) and rig.orbit_snapshot()==parent_orbit,"Malformed orbit distance changed retained parameters")
	for invalid in [null,0,1,"true"]:
		check(not rig.set_orbit_enabled(invalid) and rig.orbit_snapshot()==parent_orbit,"Malformed orbit enable changed state")
	copy=rig.fork_for_frame();check(copy.set_orbit_parameters(angles,8000),copy.error)
	copy._eye_coefficients=PackedFloat64Array([NAN])
	var broken: Dictionary=copy.orbit_snapshot();var history: Dictionary=copy.snapshot()
	check(not copy.update(16,shot,scene) and copy.orbit_snapshot()==broken and copy.snapshot()==history,"Failed orbit frame partially committed radius normalization or view")
	check(rig.configure(bindings) and not rig.orbit_snapshot().enabled and rig.orbit_snapshot().eye_offset==initial_orbit.eye_offset,"Fresh configuration retained a previous orbit radius")
	print("Ordinary orbit: YXZ offsets, unrotated target up, source blend, persistent radius, zero-time, malformed input and rollback verified")

func near(actual: Vector3, expected: Vector3, message: String, tolerance := 0.001) -> void:
	check(actual.distance_to(expected) <= tolerance, message + ": " + str(actual) + " vs " + str(expected))

func converged(actual: Vector3, expected: Vector3, weight: float) -> void:
	# At the opening's ~40000-unit coordinates, float32 lerp settles when its
	# weighted increment rounds below half an ULP. Bound that error per axis.
	for axis in 3:
		var ulp := pow(2.0, floor(log(maxf(absf(expected[axis]), 1.0)) / log(2.0)) - 23)
		check(absf(actual[axis] - expected[axis]) <= ulp * (0.5 / weight + 1.0), "Imported follow did not converge within float32 rounding bounds")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
