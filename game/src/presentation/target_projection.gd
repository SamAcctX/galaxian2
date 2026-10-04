extends RefCounted
## Target HUD geometry for an ordinary, already oriented flight viewport.
## Render visibility and marker placement are deliberately separate: the source
## uses the center frame ellipse for failed projections, including rear targets.
## This component neither chooses targets nor advances a scanner clock.
const Definitions = preload("res://src/content/flight_projection_definitions.gd")
const Vectors = preload("res://src/simulation/source_vectors.gd")
# Keep extreme offscreen displacements within both float32 and signed pixels.
# This limit is far outside every supported viewport and preserves direction.
const SCREEN_DELTA_LIMIT := 1073741824.0
const STABLE_ELLIPSE_DISTANCE := 1048576.0
# safe_pixel(value) is absf(value) < PIXEL_LIMIT: NaN and both infinities fail it.
const PIXEL_LIMIT := 2147483648.0
var error := ""
var _size := Vector2i.ZERO
var _center := Vector2i.ZERO
var _tangents := Vector2.ZERO
var _inverse_squared_radii := Vector2.ZERO
var _near := 0.0

var _valid_camera := Transform3D(Basis(),Vector3(NAN,NAN,NAN))
## The validated camera's rotated eye: the same for every target it projects.
var _eye := Vector3.ZERO
func configure(data: Dictionary, viewport_size: Vector2i, frame_radii := Vector2.ONE) -> bool:
	clear()
	if not Definitions.parameters(data): return reject("Target projection requires imported flight perspective")
	if viewport_size.x < 1 or viewport_size.y < 1 or viewport_size.x > 32767 or viewport_size.y > 32767:
		return reject("Target projection requires a positive supported viewport")
	if not frame_radii.is_finite() or frame_radii.x < 1 or frame_radii.y < 1 or frame_radii.x > 32767 or frame_radii.y > 32767:
		return reject("Target projection requires finite center-frame radii")
	# The source metrics retain single-precision sine/cosine and aspect products.
	var half_fov := single(single(float(data.vertical_fov_radians)) / 2.0)
	var vertical := single(single(sin(half_fov)) / single(cos(half_fov)))
	_tangents = Vector2(single(single(float(viewport_size.x) / viewport_size.y) * vertical),vertical)
	if not _tangents.is_finite() or _tangents.x <= 0 or _tangents.y <= 0:
		return reject("Target perspective exceeds supported precision")
	_inverse_squared_radii = Vector2(single(1.0 / single(frame_radii.x * frame_radii.x)),single(1.0 / single(frame_radii.y * frame_radii.y)))
	_size = viewport_size
	_center = Vector2i(viewport_size.x >> 1,viewport_size.y >> 1)
	_near = single(float(data.near))
	return true

## The last sample(): a scanner that projects a whole field each frame reads
## these members instead of receiving a dictionary per target.
var camera_position := Vector3.ZERO
var screen_position := Vector2.ZERO
var pixels := Vector2i.ZERO
var projected := false
var in_view := false
var ellipse_clamped := false

func project_point(camera: Transform3D, position: Vector3) -> Dictionary:
	if not sample(camera,position,false): return {"error":error}
	return {"camera_position":camera_position,"projected":projected,"in_view":in_view,"screen_position":screen_position}

func project(camera: Transform3D, position: Vector3) -> Dictionary:
	if not sample(camera,position): return {"error":error}
	return {"camera_position":camera_position,"projected":projected,"in_view":in_view,"screen_position":screen_position,"pixels":pixels,"ellipse_clamped":ellipse_clamped}

## project() without its dictionary: false with `error` set, or the members above.
## project_point() stops before the marker (pixels and ellipse_clamped).
func sample(camera: Transform3D, position: Vector3, marker := true) -> bool:
	error = ""
	if _size == Vector2i.ZERO: return reject("Configure target projection before projecting")
	if not position.is_finite():return reject("Target projection requires a finite proper camera and world position")
	# One camera projects many targets per frame; validate it once.
	if camera != _valid_camera:
		if not camera.is_finite() or not camera.basis.is_equal_approx(camera.basis.orthonormalized()) or camera.basis.determinant() <= 0:
			return reject("Target projection requires a finite proper camera and world position")
		_valid_camera = camera
		_eye = Vector3(Vectors.dot(camera.basis.x,camera.origin),Vectors.dot(camera.basis.y,camera.origin),Vectors.dot(camera.basis.z,camera.origin))
	# Evaluate the rigid inverse as rotated point plus rotated translation. This
	# preserves source precision for large translated worlds; subtracting the eye
	# first produces different cancellation at pixel and acquisition boundaries.
	# Vector construction rounds each component to binary32, as single() does.
	var axes := camera.basis
	var local := Vector3(Vectors.dot(axes.x,position)-_eye.x,Vectors.dot(axes.y,position)-_eye.y,Vectors.dot(axes.z,position)-_eye.z)
	if not local.is_finite(): return reject("Target camera coordinates exceed source precision")
	var x := float(local.x)
	var y := float(local.y)
	var behind := true
	# This is the recovered HUD predicate. Godot's near clip and behind-camera
	# helpers have different behavior: the source accepts Z equal to +near.
	var depth := Vector2(_tangents.x * local.z,_tangents.y * local.z)
	if local.z <= _near and depth.x != 0 and depth.y != 0:
		x = -float(_size.x) * (float(local.x) / 2.0 / depth.x) + _center.x
		y = float(_size.y) * (float(local.y) / 2.0 / depth.y) + _center.y
		behind = false
	# A finite target crossing the camera plane can have arbitrarily large
	# projected coordinates. Bound its displacement radially in double precision
	# before float32 storage/integer conversion; it stays offscreen and retains
	# the same ellipse intersection. Ordinary pixel positions remain unchanged.
	var dx := x - _center.x
	var dy := y - _center.y
	var magnitude := maxf(absf(dx),absf(dy))
	if magnitude > SCREEN_DELTA_LIMIT:
		var scale := SCREEN_DELTA_LIMIT / magnitude
		x = _center.x + dx * scale
		y = _center.y + dy * scale
	var screen := Vector2(x,y)
	if not screen.is_finite(): return reject("Target projection exceeds source precision")
	camera_position = local;screen_position = screen;projected = not behind
	in_view = projected and screen.x >= 0 and screen.y >= 0 and screen.x < _size.x and screen.y < _size.y
	if not marker: return true
	# safe_pixel() spelled out: this runs for every target of every scanner.
	if not (absf(screen.x) < PIXEL_LIMIT and absf(screen.y) < PIXEL_LIMIT): return reject("Target projection exceeds signed pixel coordinates")
	var point := Vector2i(int(screen.x),int(screen.y))
	var clamped := false
	if not in_view:
		# A failed early projection retains camera X/Y as the ellipse input and
		# camera X/-Y as its fallback. Do not turn every failure into an edge arrow.
		var fallback := Vector2(local.x,-local.y)
		var delta := Vector2(float(_center.x)-point.x,float(_center.y)-point.y)
		if not (absf(delta.x) < PIXEL_LIMIT and absf(delta.y) < PIXEL_LIMIT): return reject("Target ellipse displacement exceeds signed pixel coordinates")
		if maxf(absf(delta.x),absf(delta.y)) > STABLE_ELLIPSE_DISTANCE:
			# Adding nearly opposite large float32 values loses the small marker
			# offset. Normalize first, then add the viewport center instead.
			var distance := sqrt(float(delta.x)*delta.x*_inverse_squared_radii.x + float(delta.y)*delta.y*_inverse_squared_radii.y)
			fallback = Vector2(single(_center.x-float(delta.x)/distance),single(_center.y-float(delta.y)/distance))
			clamped = true
		else:
			# Each constructed vector is one binary32 rounding step of the source expression.
			var squares := Vector2(delta.x * delta.x,delta.y * delta.y)
			var terms := Vector2(squares.x * _inverse_squared_radii.x,squares.y * _inverse_squared_radii.y)
			var q := Vector2(terms.x + terms.y,0.0).x
			if is_finite(q) and q > 0:
				var weight := Vector2(Vector2(q - Vector2(sqrt(q),0.0).x,0.0).x / q,0.0).x
				if weight >= 0 and weight <= 1:
					var offset := Vector2(delta.x * weight,delta.y * weight)
					fallback = Vector2(float(point.x) + offset.x,float(point.y) + offset.y)
					clamped = true
		if not (absf(fallback.x) < PIXEL_LIMIT and absf(fallback.y) < PIXEL_LIMIT): return reject("Target marker exceeds signed pixel coordinates")
		point = Vector2i(int(fallback.x),int(fallback.y))
	pixels = point;ellipse_clamped = clamped
	return true

func clear() -> void:
	error = ""
	_size = Vector2i.ZERO
	_center = Vector2i.ZERO
	_tangents = Vector2.ZERO
	_inverse_squared_radii = Vector2.ZERO
	_near = 0.0

static func single(value: float) -> float:return Vector2(value,0.0).x

static func dot_single(axis: Vector3, point: Vector3) -> float:return Vectors.dot(axis,point)

static func safe_pixel(value: float) -> bool:
	# Values outside this range have architecture-dependent integer conversions.
	return is_finite(value) and value > -2147483648.0 and value < 2147483648.0

func reject(message: String) -> bool:
	error = message
	return false
