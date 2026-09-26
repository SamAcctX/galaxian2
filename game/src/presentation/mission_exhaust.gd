extends Node3D
## Passive adapter for the shared original four-nozzle sprite renderer. No
## procedural replacement, simulation tick, camera-dependent RNG or HUD gate.
const Context=preload("res://src/simulation/mission_context.gd")
const FlightFrame=preload("res://src/simulation/selected40_flight_frame.gd")
const Sprites=preload("res://src/presentation/opening_damage_geometry.gd")
var error:=""
var sprites: Node3D
var _generation: RefCounted
var _sample:={}

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,frame: RefCounted) -> bool:
	error=""
	if sprites!=null or not (frame is FlightFrame or Context.from_owner(frame)!=null) or frame.presentation_identity()==null or frame.exhaust_state().is_empty():return reject("Mission exhaust requires one complete native flight")
	var pending:=Sprites.new()
	if not pending.build(frame.engine_particles_owner(),library,visuals,bindings):
		var problem: String=pending.error;pending.free();return reject(problem)
	add_child(pending);sprites=pending;_generation=frame.presentation_identity()
	return true

func present(frame: RefCounted) -> bool:
	error=""
	if sprites==null or not (frame is FlightFrame or Context.from_owner(frame)!=null) or frame.presentation_identity()!=_generation:return reject("Mission exhaust cannot accept another native flight generation")
	var sample: Dictionary=frame.exhaust_state()
	if sample.is_empty():return reject("Mission exhaust requires an accepted frame, not a pending boundary")
	if not _sample.is_empty():
		if sample.revision<_sample.revision or sample.elapsed_ms<_sample.elapsed_ms:return reject("Mission exhaust rejected a regressed native frame")
		if sample.revision==_sample.revision:
			if sample!=_sample:return reject("Mission exhaust revision was reused with different state")
			return true
	var prepared: Dictionary=sprites.prepare_world(frame.engine_particles_owner(),sample,sample.camera_pose)
	if prepared.is_empty():return reject(sprites.error)
	# Every mesh is prepared before touching the displayed frame. A rejected
	# final nozzle cannot partially replace the preceding accepted plume.
	sprites.commit_world(prepared);_sample=sample
	return true

func snapshot() -> Dictionary:return _sample.duplicate(true)
func reject(message: String) -> bool:error=message;return false
