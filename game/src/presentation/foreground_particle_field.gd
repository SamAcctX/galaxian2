extends RefCounted
## Nearby dust persists in world space. A prospective view owns its own packed
## arrays and RNG state; displaying or rejecting it never changes its parent.
const Pose=preload("res://src/simulation/npc_flight.gd")
const COUNT:=500
const RADIUS:=10000.0
var error:=""
var _seed:=0
var _random_state:=0
var _elapsed_ms:=-1
var _camera:=Vector3.ZERO
var _positions:=PackedVector3Array()
var _velocities:=PackedVector3Array()
var _sizes:=PackedInt32Array()
var _weights:=PackedFloat32Array()
## MultiMesh rows kept between updates; sizes and colour never change.
var _buffer:=PackedFloat32Array()

func configure(placement_seed: int) -> void:
	_seed=placement_seed;_random_state=0;_elapsed_ms=-1;_camera=Vector3.ZERO
	_positions.clear();_velocities.clear();_sizes.clear();_weights.clear();_buffer.clear();error=""

func sample(camera_pose: Transform3D,elapsed_ms: int) -> RefCounted:
	error=""
	if not Pose.rigid_pose(camera_pose) or elapsed_ms<0 or elapsed_ms<_elapsed_ms:
		error="Nearby particles require a finite camera and forward world time";return null
	if _elapsed_ms==elapsed_ms and _camera==camera_pose.origin:return self
	var next: RefCounted=get_script().new()
	next._seed=_seed;next._elapsed_ms=elapsed_ms;next._camera=camera_pose.origin
	next._positions=_positions.duplicate();next._velocities=_velocities.duplicate()
	next._sizes=_sizes;next._weights.resize(COUNT);next._buffer=_buffer.duplicate()
	var random:=RandomNumberGenerator.new()
	if _elapsed_ms<0:
		random.seed=_seed
		for index in COUNT:
			next._positions.append(camera_pose.origin+Vector3(random.randi_range(-10000,9999),random.randi_range(-10000,9999),random.randi_range(-10000,9999)))
			next._velocities.append(camera_pose.basis.z*-30000.0+Vector3(random.randi_range(-5,4),random.randi_range(-5,4),random.randi_range(-5,4)))
			next._sizes.append(random.randi_range(20,59))
	else:
		random.state=_random_state
		var seconds:=float(elapsed_ms-_elapsed_ms)/1000.0
		for index in COUNT:
			var position: Vector3=next._positions[index]+next._velocities[index]*seconds
			var distance_squared:=position.distance_squared_to(camera_pose.origin)
			if not position.is_finite() or not is_finite(distance_squared):
				error="Nearby particle motion exceeded finite coordinates";return null
			# Distance fading is evaluated by the shader; this keeps only the
			# gate that hides startup and recycled particles for one update.
			next._weights[index]=1.0
			if distance_squared>RADIUS*RADIUS*1.01:
				var height:=random.randf_range(-1.0,1.0)
				var azimuth:=random.randf_range(0.0,TAU)
				var ring:=sqrt(maxf(0.0,1.0-height*height))
				position=camera_pose.origin+Vector3(ring*cos(azimuth),height,ring*sin(azimuth))*RADIUS
				next._velocities[index]=Vector3.ZERO
				next._weights[index]=0.0
			next._positions[index]=position
			var offset:=index*16
			next._buffer[offset+3]=position.x;next._buffer[offset+7]=position.y;next._buffer[offset+11]=position.z
			next._buffer[offset+15]=next._weights[index]
	next._random_state=random.state
	if _elapsed_ms<0:next._buffer=next._full_buffer()
	return next

static func opacity(distance_squared: float) -> float:
	var near_weight:=clampf(distance_squared/4000000.0,0.0,1.0)
	var far_weight:=clampf((RADIUS*RADIUS-distance_squared)/75000000.0,0.0,1.0)
	return minf(near_weight,far_weight)

## Displayed opacity: the recycle gate times the shader's distance fade.
func weights() -> PackedFloat32Array:
	var result:=_weights.duplicate()
	for index in result.size():
		if result[index]>0.0:result[index]=opacity(_positions[index].distance_squared_to(_camera))
	return result

func snapshot() -> Dictionary:
	return {"elapsed_ms":_elapsed_ms,"camera":_camera,"positions":_positions.duplicate(),
		"velocities":_velocities.duplicate(),"sizes":_sizes.duplicate(),"weights":weights()}

func instance_buffer() -> PackedFloat32Array:return _buffer

func _full_buffer() -> PackedFloat32Array:
	var buffer:=PackedFloat32Array();buffer.resize(COUNT*16)
	for index in COUNT:
		var offset:=index*16
		var half:=_sizes[index]>>1
		# MultiMesh stores three transform rows followed by instance RGBA.
		buffer[offset]=half;buffer[offset+3]=_positions[index].x
		buffer[offset+5]=half;buffer[offset+7]=_positions[index].y
		buffer[offset+10]=half;buffer[offset+11]=_positions[index].z
		buffer[offset+12]=1.0;buffer[offset+13]=1.0;buffer[offset+14]=1.0
		buffer[offset+15]=_weights[index]
	return buffer
