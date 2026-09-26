extends Node3D
## Passive composition of the native destruction owner and shared particles.
## A failure in either renderer leaves BOTH previously displayed frames intact.
const Context=preload("res://src/simulation/mission_context.gd")
const Frame=preload("res://src/simulation/selected40_flight_frame.gd")
const Sprites=preload("res://src/presentation/opening_damage_geometry.gd")
const Explosion=preload("res://src/presentation/npc_death_effect_geometry.gd")
var error:=""
var sprites: Node3D
var explosion: Node3D
var _generation: RefCounted
var _sample:={}

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,frame: RefCounted) -> bool:
	error=""
	if _generation!=null or not (frame is Frame or Context.from_owner(frame)!=null) or frame.presentation_identity()==null or frame.effects_state().is_empty():return reject("Mission effects require a fresh accepted native frame")
	var pending_sprites:=Sprites.new();var pending_explosion:=Explosion.new()
	if not pending_sprites.build(frame.damage_particles_owner(),library,visuals,bindings) or not pending_explosion.build(library,visuals,bindings,frame.destruction_owner()):
		var message: String=pending_sprites.error+pending_explosion.error
		pending_sprites.free();pending_explosion.free();return reject(message)
	sprites=pending_sprites;explosion=pending_explosion;add_child(sprites);add_child(explosion)
	_generation=frame.presentation_identity()
	return true

func present(frame: RefCounted) -> bool:
	error=""
	if _generation==null or not (frame is Frame or Context.from_owner(frame)!=null) or frame.presentation_identity()!=_generation:return reject("Mission effects cannot substitute another native flight")
	var sample: Dictionary=frame.effects_state()
	if sample.is_empty():return reject("Mission effects require complete matching native clocks")
	if not _sample.is_empty():
		if sample.revision<_sample.revision or sample.elapsed_ms<_sample.elapsed_ms or (sample.revision==_sample.revision and sample!=_sample):return reject("Mission effect revision regressed or changed")
		if sample==_sample:return true
	var particles: Dictionary=sprites.prepare_world(frame.damage_particles_owner(),sample,sample.camera_pose)
	if particles.is_empty():return reject(sprites.error)
	var effect: Dictionary=explosion.prepare_effect(frame.destruction_owner(),sample.camera_pose,PackedByteArray([255,255,255,255]),Vector4.ONE,1.0)
	if effect.is_empty():return reject(explosion.error)
	sprites.commit_world(particles);explosion.commit_effect(effect);_sample=sample
	return true

func snapshot() -> Dictionary:return _sample.duplicate(true)
func reject(message: String) -> bool:error=message;return false
