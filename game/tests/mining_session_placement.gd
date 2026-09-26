extends RefCounted
## Isolate an actual asteroid approach without changing the field, combat,
## inventory or drill. This is component placement, not earned travel.
const Aim=preload("res://src/simulation/opening_aim.gd")

static func place(flight: RefCounted,asteroid: Dictionary,bindings: RefCounted) -> void:
	var stand_off:=float(int(asteroid.scale*2500))
	place_pose(flight,Transform3D(Basis(Vector3.UP,PI),asteroid.position+Vector3(0,0,stand_off-.5)),bindings)
	flight._targeting._selected=int(asteroid.index)

## A contact fixture establishes one pose, never a traveled distance or event.
static func place_pose(flight: RefCounted,pose: Transform3D,bindings: RefCounted) -> void:
	flight._pose=pose;flight._pilot.angular_units=Vector2.ZERO
	if flight._autopilot!=null:flight._autopilot.observe_manual(flight._pose,Vector2.ZERO)
	# This explicit placement is not a frame of flown movement. Establish its
	# statistics/exhaust sample before approach retains it through drilling.
	flight._statistics_pose=flight._pose*Transform3D(flight._model_basis,Vector3.ZERO)
	if flight._engine_particles!=null:
		for emitter in flight._engine_particles._emitters:emitter.reset()
	var follow: Dictionary=bindings.camera_follow
	var eye: Vector3=flight._pose*Vector3(follow.eye_offset[0],follow.eye_offset[1],follow.eye_offset[2])
	var look: Vector3=flight._pose*Vector3(follow.look_offset[0],follow.look_offset[1],follow.look_offset[2])
	flight._camera._state.eye=eye;flight._camera._state.look=look;flight._camera._state.pose=Transform3D.IDENTITY.looking_at(look-eye,Vector3.UP);flight._camera._state.pose.origin=eye
	flight._aim=Aim.new();flight._aim.configure(bindings)
