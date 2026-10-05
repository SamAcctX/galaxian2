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
## Particles still flying from their startup burst; the rest never move.
var _drifting:=0
## MultiMesh rows kept between updates; sizes and colour never change.
var _buffer:=PackedFloat32Array()

func configure(placement_seed: int) -> void:
	_seed=placement_seed;_random_state=0;_elapsed_ms=-1;_camera=Vector3.ZERO
	_positions=PackedVector3Array();_velocities=PackedVector3Array();_sizes=PackedInt32Array();_weights=PackedFloat32Array();_buffer=PackedFloat32Array();_drifting=0;error=""

func sample(camera_pose: Transform3D,elapsed_ms: int) -> RefCounted:
	error=""
	if not Pose.rigid_pose(camera_pose) or elapsed_ms<0 or elapsed_ms<_elapsed_ms:
		error="Nearby particles require a finite camera and forward world time";return null
	if _elapsed_ms==elapsed_ms and _camera==camera_pose.origin:return self
	var next: RefCounted=get_script().new()
	next._seed=_seed;next._elapsed_ms=elapsed_ms;next._camera=camera_pose.origin;next._sizes=_sizes
	var random:=RandomNumberGenerator.new()
	if _elapsed_ms<0:
		random.seed=_seed
		next._weights.resize(COUNT)
		for index in COUNT:
			next._positions.append(camera_pose.origin+Vector3(random.randi_range(-10000,9999),random.randi_range(-10000,9999),random.randi_range(-10000,9999)))
			next._velocities.append(camera_pose.basis.z*-30000.0+Vector3(random.randi_range(-5,4),random.randi_range(-5,4),random.randi_range(-5,4)))
			next._sizes.append(random.randi_range(20,59))
			if next._velocities[index]!=Vector3.ZERO:next._drifting+=1
		next._random_state=random.state;next._buffer=next._full_buffer()
		return next
	random.state=_random_state
	var seconds:=float(elapsed_ms-_elapsed_ms)/1000.0
	var origin:=camera_pose.origin;var limit:=RADIUS*RADIUS*1.01
	# Dust at rest inside the radius keeps its row: the arrays stay shared with
	# the parent view until the first particle moves, recycles or reappears.
	var positions:=_positions;var velocities:=_velocities;var weights:=_weights;var buffer:=_buffer
	var drifting:=_drifting;var owned:=false
	for index in COUNT:
		var position: Vector3=positions[index]
		var velocity:=Vector3.ZERO
		if drifting>0:
			velocity=velocities[index]
			if velocity!=Vector3.ZERO:position+=velocity*seconds
		var distance_squared:=position.distance_squared_to(origin)
		# Distance fading is evaluated by the shader; this keeps only the
		# gate that hides startup and recycled particles for one update.
		var weight:=1.0
		if not distance_squared<=limit:
			if not position.is_finite() or not is_finite(distance_squared):
				error="Nearby particle motion exceeded finite coordinates";return null
			var height:=random.randf_range(-1.0,1.0)
			var azimuth:=random.randf_range(0.0,TAU)
			var ring:=sqrt(maxf(0.0,1.0-height*height))
			position=origin+Vector3(ring*cos(azimuth),height,ring*sin(azimuth))*RADIUS
			weight=0.0
		elif velocity==Vector3.ZERO and weights[index]==1.0:continue
		if not owned:
			positions=positions.duplicate();velocities=velocities.duplicate();weights=weights.duplicate();buffer=buffer.duplicate();owned=true
		if weight==0.0 and velocity!=Vector3.ZERO:velocities[index]=Vector3.ZERO;drifting-=1
		positions[index]=position;weights[index]=weight
		var offset:=index*16
		buffer[offset+3]=position.x;buffer[offset+7]=position.y;buffer[offset+11]=position.z
		buffer[offset+15]=weight
	next._positions=positions;next._velocities=velocities;next._weights=weights;next._buffer=buffer
	next._drifting=drifting;next._random_state=random.state
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
