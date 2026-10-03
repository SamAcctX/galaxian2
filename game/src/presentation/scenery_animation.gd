extends RefCounted
## Stateful sampling and world transforms for supported scenery effect surfaces.
## Drawing, material selection and bounds/culling remain the renderer's owners.
const Keys = preload("res://src/content/scenery_animation_keys.gd")
const Resources = preload("res://src/content/scenery_effect_resources.gd")
const Rotation = preload("res://src/presentation/scenery_animation_rotation.gd")
const Readonly = preload("res://src/simulation/readonly_state.gd")
var error := ""
var _tables: Array = []
var _pivots: Array[Vector3] = []
var _state: Array = []
var _range := {}
var _sample_time:=-1
var _sample_parent:=Transform3D.IDENTITY
var _sample_result:={}

func configure(surfaces: Variant, allow_static:=false) -> bool:
	error="";_tables=[];_pivots=[];_state=[];_range={};_sample_time=-1;_sample_result={}
	var timing := Resources.playback_range(surfaces,allow_static)
	if timing.is_empty():error="Unsupported scenery animation channels or timing";return false
	for surface in surfaces:
		if not surface.get("pivot") is Vector3 or not surface.pivot.is_finite():
			error="Scenery animation requires finite source pivots";return false
	var compiler := Keys.new()
	var prepared := compiler.prepare(surfaces,allow_static)
	if prepared.is_empty():error=compiler.error;return false
	_tables=prepared.surfaces;_range=timing
	# Key rotations are fixed; convert each to its quaternion once.
	for table in _tables:
		var rotations:=[]
		for key in table.times.size():
			var components:=Rotation.from_angles(vector_at(table.values,key*Keys.WIDTH+3))
			if components.is_empty():error="Scenery rotation angles must be finite";_tables=[];_range={};return false
			rotations.append(components)
		table.rotations=rotations
	for surface in surfaces:
		_pivots.append(convert_axis(surface.pivot))
		_state.append({"basis":Basis.IDENTITY,"translation":Vector3.ZERO,"color_byte":255})
	# Source loading evaluates the configured start before instances are cloned.
	if sample(timing.start_ms,Transform3D.IDENTITY).is_empty():
		_tables=[];_pivots=[];_state=[];_range={};return false
	return true

func sample(time_ms: Variant, parent: Transform3D) -> Dictionary:
	error=""
	if _tables.is_empty():return reject("Scenery animation is not configured")
	if not time_ms is int or time_ms<0:return reject("Scenery animation time must be a nonnegative integer in milliseconds")
	if not parent.is_finite():return reject("Scenery animation parent must be finite")
	# Inactive effect slots keep the same retained time for many frames. Reuse
	# that exact sample, including its first-key/rewind state, until inputs change.
	if time_ms==_sample_time and parent==_sample_parent:return _sample_result
	# Rows are frozen and shared with forks; a sampled row is replaced, not edited.
	var next := _state.duplicate()
	var output := []
	for surface in _tables.size():
		var table: Dictionary=_tables[surface]
		if table.times.is_empty():
			output.append({"animated":false,"pose":parent});continue
		var times: PackedInt32Array=table.times
		var start: int=_range.start_ms if _range.start_ms<=times[-1] else 0
		var at := mini(maxi(time_ms,start),times[-1])
		var index := lower_bound(times,at)
		# The first-record branch changes only source UV state. It leaves the
		# geometry matrix and packed color intact, including after a rewind.
		if index>0:next[surface]=next[surface].duplicate()
		if index>0 and not update_row(next[surface],table,index,Keys.ratio(at-times[index-1],times[index]-times[index-1])):
			return {}
		var row: Dictionary=next[surface]
		# Many authored layers animate only color, or retain their pose between
		# keys. Reuse the already rounded matrix while still sampling color/time.
		if parent==_sample_parent and not _sample_result.is_empty() and row.basis==_state[surface].basis and row.translation==_state[surface].translation:
			output.append({"animated":true,"pose":_sample_result.surfaces[surface].pose,"color_byte":row.color_byte})
			continue
		# Parent, translation, then the layer basis about its pivot.
		var pivot: Vector3=_pivots[surface]
		var world := parent*Transform3D(row.basis,row.translation+pivot-row.basis*pivot)
		if not world.is_finite():return reject("Scenery animation world transform exceeds source precision")
		output.append({"animated":true,"pose":world,"color_byte":row.color_byte})
	_state=Readonly.freeze(next)
	# Samples are read-only; callers copy one before editing it.
	_sample_time=time_ms;_sample_parent=parent;_sample_result=Readonly.freeze({"surfaces":output})
	return _sample_result

func update_row(row: Dictionary, table: Dictionary, index: int, weight: float) -> bool:
	var values: PackedFloat32Array=table.values
	var a := (index-1)*Keys.WIDTH
	var b := index*Keys.WIDTH
	var mixed:=Rotation.blend(table.rotations[index-1],table.rotations[index],weight)
	if mixed.is_empty():error="Scenery rotation blend is singular or exceeds source precision";return false
	var rotation:=Rotation.to_basis(mixed)
	if rotation.has("error"):error=rotation.error;return false
	var basis: Basis=rotation.basis
	basis=Basis(convert_axis(basis.x),convert_axis(basis.z),-convert_axis(basis.y))
	var translation := Vector3.ZERO
	for axis in 3:
		var scale := Keys.blend(values[a+6+axis],values[b+6+axis],weight)
		# Scale the converted local columns. Basis.scaled() scales world axes.
		for component in 3:basis[axis][component]=Keys.single(basis[axis][component]*scale)
		translation[axis]=Keys.blend(values[a+axis],values[b+axis],weight)
	var scalar := Keys.blend(values[a+9],values[b+9],weight)
	var color := Keys.single(scalar*255.0)
	if not basis.is_finite() or not translation.is_finite() or not is_finite(color) or color<-2147483648.0 or color>=2147483648.0:
		error="Scenery animation values exceed source precision";return false
	row.basis=basis;row.translation=translation
	# All four source color channels use this byte. Material/parent modulation
	# is separate; do not clamp the authored scalar to an opacity range here.
	row.color_byte=int(color)&255
	return true

func time_range() -> Dictionary:return _range

func snapshot() -> Dictionary:
	return {} if _tables.is_empty() else {"range":_range.duplicate(),"surfaces":_state.duplicate(true)}

func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	# Compiled tables and pivots are private and immutable after configuration.
	copy._tables=_tables;copy._pivots=_pivots
	copy._state=_state;copy._range=_range.duplicate()
	copy._sample_time=_sample_time;copy._sample_parent=_sample_parent;copy._sample_result=_sample_result
	return copy

static func lower_bound(times: PackedInt32Array, value: int) -> int:
	var low := 0;var high := times.size()
	while low<high:
		var middle := int((low+high)/2)
		if times[middle]<value:low=middle+1
		else:high=middle
	return low

static func convert_axis(value: Vector3) -> Vector3:
	return Vector3(value.x,value.z,-value.y)

static func vector_at(values: PackedFloat32Array, start: int) -> Vector3:
	return Vector3(values[start],values[start+1],values[start+2])

static func multiply(left: Transform3D, right: Transform3D) -> Transform3D:
	# Native products; binary32 rounding of each step is not visible on screen.
	return left*right

func reject(message: String) -> Dictionary:
	error=message;return {}
