extends RefCounted
## Aim-window eligibility comes from the shared HUD projection, not scan lock.
const Definitions=preload("res://src/content/beam_primary_definitions.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")

static func launch(pose: Transform3D, targets: Array) -> Dictionary:
	var forward:=Vectors.normalized(pose.basis.z)
	var endpoint:=Vectors.added(pose.origin,Vectors.scaled(forward,Definitions.EMPTY_DISTANCE))
	var distance:=2147483647;var selected:=-1
	for target in targets:
		if not target is Dictionary or not Numbers.integer(target.get("actor_id"),0,2147483647) or not target.get("active") is bool or not target.get("pose") is Transform3D or not target.pose.is_finite() or not Numbers.integer(target.get("vitals",{}).get("hull"),0,2147483647):return {"error":"Invalid beam target observation"}
		if not target.active or target.vitals.hull==0:continue
		var length:=Vectors.added(target.pose.origin,-pose.origin).length()
		if not is_finite(length) or length>=2147483647:return {"error":"Beam target exceeds supported distance"}
		if int(length)<distance:
			distance=int(length);selected=target.actor_id;endpoint=target.pose.origin
	var direction:=forward if selected<0 else Vectors.normalized(Vectors.added(endpoint,-pose.origin))
	return {"position":endpoint,"velocity":forward,"direction":direction,"length":Definitions.EMPTY_DISTANCE if selected<0 else distance,"target_actor_id":selected}

static func basis(direction: Vector3) -> Basis:
	var right:=Vectors.normalized(Vectors.cross(Vector3.UP,direction))
	return Basis(right,Vectors.normalized(Vectors.cross(direction,right)),direction)

static func presentation(shot: Dictionary, muzzle: bool) -> Transform3D:
	var pose: Transform3D=shot.player_pose
	var offset: Vector3=shot.mount
	# The common mount setter adds 100Z; the beam wrapper removes it again.
	if not muzzle and offset==Vector3(0,0,-100):offset=Vector3.ZERO
	var root:=Transform3D(basis(Vectors.normalized(pose.basis.z) if muzzle else shot.direction),pose*offset)
	if not muzzle:root.basis.z=Vectors.scaled(root.basis.z,float(shot.length))
	return root
