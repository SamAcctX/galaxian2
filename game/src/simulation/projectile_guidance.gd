extends RefCounted
## Acquired-target steering follows ordinary movement and preserves shot speed.
const Vectors=preload("res://src/simulation/source_vectors.gd")

static func velocity(position: Vector3, current: Vector3, target: Vector3) -> Vector3:
	var aim:=Vectors.normalized(Vectors.added(target,-position))
	if aim==Vector3.ZERO:return current
	var forward:=Vectors.normalized(current)
	var bent:=Vectors.added(forward,Vectors.scaled(Vectors.added(aim,-forward),1.0/6.0))
	return Vectors.scaled(Vectors.normalized(bent),current.length())
