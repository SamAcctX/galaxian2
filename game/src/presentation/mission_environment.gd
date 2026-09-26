extends Node3D
## Compose the world features selected by the admitted mission. Simulation owns
## portal visibility/contact and camera time; this view only samples them.
const Context=preload("res://src/simulation/mission_context.gd")
const Ordinary=preload("res://src/presentation/selected40_environment.gd")
const VoidView=preload("res://src/presentation/void_environment_geometry.gd")
const PortalView=preload("res://src/presentation/portal_geometry.gd")
var error:=""
var lights: Node3D
var _ordinary: Node3D
var _void: Node3D
var _portal: Node3D
var _generation: RefCounted
var _elapsed_ms:=0

func configure(library: RefCounted,visuals: RefCounted,bindings: RefCounted,catalogues: RefCounted,world: RefCounted) -> bool:
	if _generation!=null:return reject("Register a mission environment once")
	var context:=Context.from_owner(world)
	if context==null:
		_ordinary=Ordinary.new();add_child(_ordinary)
		if not _ordinary.configure(library,visuals,bindings,catalogues,world):return reject(_ordinary.error)
		lights=_ordinary.lights
	elif context.has_feature("void_environment"):
		_void=VoidView.new();add_child(_void)
		if not _void.build(library,visuals,bindings,world.void_environment_owner()):return reject(_void.error)
		var owner: RefCounted=world.portal_owner()
		if owner!=null:
			var portal: Dictionary=owner.portal_snapshot()
			var identity:={}
			for key in ["base_content_id","binding_id","model_id","slot"]:identity[key]=portal[key]
			_portal=PortalView.new();add_child(_portal)
			if not _portal._build_portal(library,visuals,bindings,identity):return reject(_portal.error)
	else:return reject("No environment renderer was prepared for the admitted world features")
	_generation=world.presentation_identity()
	return true

func present(world: RefCounted,viewport: Vector2i) -> bool:
	if _generation==null or world.presentation_identity()!=_generation:return reject("Environment belongs to another flight generation")
	if _ordinary!=null:
		if not _ordinary.present(world,viewport):return reject(_ordinary.error)
		return true
	var state: Dictionary=world.frame_context()
	if state.elapsed_ms<_elapsed_ms:return reject("Environment animation cannot move backwards")
	var portal:={}
	if _portal!=null:
		portal=_portal.prepare_state(world.portal_owner().portal_snapshot())
		if portal.is_empty():return reject(_portal.error)
	if not _void.advance(int(state.elapsed_ms)-_elapsed_ms,state.encounter.view.camera):return reject(_void.error)
	if not portal.is_empty():_portal.commit_state(portal)
	_elapsed_ms=int(state.elapsed_ms)
	return true

func snapshot() -> Dictionary:
	return _ordinary.snapshot() if _ordinary!=null else {"void_environment":_void!=null,"elapsed_ms":_elapsed_ms}
func reject(message: String) -> bool:error=message;return false
