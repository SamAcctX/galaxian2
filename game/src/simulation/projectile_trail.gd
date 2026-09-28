extends RefCounted
## A bounded ribbon history. The moving end stays fresh until a section closes;
## old sections age independently after the projectile has stopped emitting.
const Definitions=preload("res://src/content/thermal_primary_definitions.gd")
var error:=""
var _preset:={}
var _sections:=[]
var _head:=Transform3D.IDENTITY
var _emitting:=false
var _section_ms:=0

func start(preset_id: int, pose: Transform3D) -> bool:
	var preset:=Definitions.trail(preset_id)
	if preset.is_empty() or not pose.is_finite():return reject("Unsupported projectile trail or nonfinite launch pose")
	_preset=preset;_head=pose;_sections=[];_section_ms=0;_emitting=true
	var edge:=_edge(pose)
	_sections.append({"from":edge,"to":edge,"age_ms":0})
	return true

func advance(delta_ms: int, pose: Variant=null) -> bool:
	error=""
	if _preset.is_empty() or delta_ms<0 or delta_ms>60000 or (pose!=null and (not pose is Transform3D or not pose.is_finite())):return reject("Invalid projectile trail update")
	var sections:=_sections.duplicate(true)
	var emitting: bool=pose!=null
	for index in sections.size():
		if _emitting and emitting and index==sections.size()-1:continue
		sections[index].age_ms+=delta_ms
	sections=sections.filter(func(section):return section.age_ms<=_preset.lifetime_ms)
	var elapsed:=_section_ms
	if emitting:
		var edge:=_edge(pose)
		if not _emitting or sections.is_empty():
			sections.append({"from":edge,"to":edge,"age_ms":0});elapsed=0
		else:
			var current: Dictionary=sections[-1]
			current.to=edge
			elapsed=mini(60001,elapsed+delta_ms)
			if elapsed>_preset.section_interval_ms and current.from.origin.distance_squared_to(edge.origin)>_preset.minimum_squared_distance:
				current.age_ms=0
				sections.append({"from":edge,"to":edge,"age_ms":0});elapsed=0
		while sections.size()>_preset.capacity:sections.pop_front()
		_head=pose
	_sections=sections;_emitting=emitting;_section_ms=elapsed
	return true

func _edge(pose: Transform3D) -> Transform3D:
	return Transform3D(pose.basis,pose.origin-pose.basis.z*float(_preset.cap_length))

func snapshot() -> Dictionary:
	return {"preset":_preset.duplicate(true),"sections":_sections.duplicate(true),"head":_head,"emitting":_emitting,"section_ms":_section_ms}

func fork_for_frame() -> RefCounted:
	var next: RefCounted=get_script().new()
	next._preset=_preset;next._sections=_sections.duplicate(true);next._head=_head;next._emitting=_emitting;next._section_ms=_section_ms
	return next

func reject(message: String) -> bool:error=message;return false
