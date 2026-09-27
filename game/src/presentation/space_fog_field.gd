extends RefCounted
## Persistent world-space clouds. Sampling prepares a new field; a rejected
## camera view cannot consume placement randomness or move accepted clouds.
const COUNT:=15
const SIZE:=10000.0
const RADIUS:=10000.0
const PALETTE:=[0x00a020,0x8c1402,0x006d7b,0x2c9bd8,0x7a7a7a,0xce5a46,
	0x69a07d,0xa7a07e,0x7eb59f,0xcedee1,0x9274d4,0xdb6923,0xffffff,
	0x9ae4ff,0xaeb77d,0xdb6923,0x47665e,0x738d95,0xaba075]
var error:=""
var sky_index:=-1
var tint:=Color.WHITE
var _positions:=PackedVector3Array()
var _weights:=PackedFloat32Array()
var _camera:=Vector3.ZERO
var _seed:=0
var _random_state:=0

func configure(location_sky: int, placement_seed: int) -> bool:
	if location_sky<0 or location_sky>=PALETTE.size():
		error="Space clouds require a location palette";return false
	sky_index=location_sky;_seed=placement_seed;_random_state=0
	_positions.clear();_weights.clear();_camera=Vector3.ZERO
	var rgb: int=PALETTE[sky_index]
	tint=Color(float(int(((rgb>>16)&255)*0.6))/255.0,
		float(int(((rgb>>8)&255)*0.6))/255.0,float(int((rgb&255)*0.6))/255.0,187.0/255.0)
	error="";return true

func sample(camera_position: Vector3) -> RefCounted:
	error=""
	if sky_index<0 or not camera_position.is_finite():
		error="Space clouds require a configured finite camera";return null
	if not _positions.is_empty() and camera_position==_camera:return self
	var next=get_script().new()
	next.sky_index=sky_index;next.tint=tint;next._seed=_seed;next._camera=camera_position
	next._positions=_positions.duplicate();next._weights.resize(COUNT)
	var random:=RandomNumberGenerator.new()
	if _positions.is_empty():
		random.seed=_seed
		for index in COUNT:
			next._positions.append(camera_position+Vector3(random.randf_range(-RADIUS,RADIUS),random.randf_range(-RADIUS,RADIUS),random.randf_range(-RADIUS,RADIUS)))
	else:random.state=_random_state
	for index in COUNT:
		var distance_squared: float=camera_position.distance_squared_to(next._positions[index])
		if not is_finite(distance_squared):
			error="Space cloud distance exceeded finite coordinates";return null
		next._weights[index]=brightness(distance_squared)
		if distance_squared>RADIUS*RADIUS*1.01:
			# Recycle beyond the fully faded boundary. A fresh center starts dark
			# and becomes visible only as the viewer approaches it.
			var height:=random.randf_range(-1.0,1.0)
			var angle:=random.randf_range(0.0,TAU)
			var ring:=sqrt(maxf(0.0,1.0-height*height))
			next._positions[index]=camera_position+Vector3(ring*cos(angle),height,ring*sin(angle))*RADIUS
			next._weights[index]=0.0
	next._random_state=random.state
	return next

static func brightness(distance_squared: float) -> float:
	var near_fade:=clampf(distance_squared/(1000.0*1000.0),0.0,1.0)
	var far_fade:=clampf((RADIUS*RADIUS-distance_squared)/(RADIUS*RADIUS-5000.0*5000.0),0.0,1.0)
	return minf(near_fade,far_fade)

func snapshot() -> Dictionary:
	return {"sky_index":sky_index,"tint":tint,"camera":_camera,
		"positions":_positions.duplicate(),"weights":_weights.duplicate()}
