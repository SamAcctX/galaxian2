extends RefCounted
## Retained escape choreography. Flight applies the declarative actions after
## accepting its candidate frame; this owner never moves/damages a player,
## resolves contacts, rebuilds a cast, acknowledges results or writes a career.
const Context=preload("res://src/simulation/mission_context.gd")
const Ambush=preload("res://src/simulation/selected41_npc_combat.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Radio=preload("res://src/simulation/radio_sequence.gd")
const Portal=preload("res://src/simulation/void_portal.gd")
const Camera=preload("res://src/simulation/camera_rig.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const Flight=preload("res://src/simulation/npc_flight.gd")
const Frames=preload("res://src/simulation/frame_clock.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Fade=preload("res://src/simulation/black_fade.gd")
const Vectors=preload("res://src/simulation/source_vectors.gd")
const EXPLOSIONS=[14285,14286,14287]
var error:=""
var _context: RefCounted
var _world: RefCounted
var _generation: RefCounted
var _portal_identity: RefCounted
var _camera: RefCounted
var _state:={}
var _shot:={}
var _fade:={}
var _random:={}
var _radio_state:={}
var _max_ms:=0

func configure(bindings: RefCounted,context: RefCounted,retained_npc: RefCounted,portal: RefCounted,camera: RefCounted,result_acknowledged: bool) -> bool:
	error=""
	if not _state.is_empty() or bindings==null or not context is Context or not retained_npc is Ambush or not result_acknowledged:
		return reject("Escape requires the acknowledged retained ambush")
	var sequence: RefCounted=retained_npc.sequence_owner();var world: RefCounted=retained_npc.world_owner()
	if sequence==null or world==null or retained_npc.composition_stage()!="ready":return reject("Escape requires a completed retained frame")
	var prior: Dictionary=sequence.snapshot()
	if prior.get("phase")!=5 or prior.get("sequence_complete")!=true or prior.get("view_revision")!=prior.get("revision"):
		return reject("Escape starts only after the completed final shot")
	if not portal is Portal or portal.mission_context_owner()!=context or portal.portal_snapshot().is_empty() or not context.has_feature("void_environment"):
		return reject("Escape requires its admitted retained Void portal")
	if not camera is Camera or not Flight.rigid_pose(camera.snapshot().get("pose")):return reject("Escape requires the current retained camera")
	var identity: Dictionary=context.identity()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if prior.get(key)!=identity.get(key) or portal.snapshot().get(key)!=identity.get(key):return reject("Escape changed the admitted world identity")
	for key in ["base_content_id","binding_id"]:
		if identity.get(key)!=bindings.get(key) or camera.snapshot().get(key)!=identity.get(key):return reject("Escape content identity changed")
	var player: RefCounted=retained_npc.player_owner();var radio: RefCounted=retained_npc.radio_owner()
	var combat: RefCounted=retained_npc.combat_owner()
	if player==null or combat==null or combat.selected41_world_owner()!=world or combat.actor_snapshot(0).is_empty():return reject("Escape lost its retained player or freighter")
	var generation: RefCounted=world.construction_owner().npc_construction_owner()
	if player.selected41_construction_owner()!=generation or player.snapshot().vitals.hull<=0:return reject("A dead or replaced player cannot start the escape")
	if not _valid_radio(radio,identity):return reject("Escape lost the inherited radio queue")
	if not Frames.valid_parameters(bindings.frame_clock):return reject("Escape requires the native frame clock")
	_context=context;_world=world;_generation=generation;_camera=camera.fork_for_frame()
	_portal_identity=portal.retained_identity();_radio_state=radio.snapshot()
	_max_ms=Frames.simulation_limit(bindings);_random=retained_npc.random_state()
	_state=identity.duplicate()
	_state.merge({"phase":5,"revision":0,"elapsed_ms":int(prior.elapsed_ms),"phase_elapsed_ms":0,
		"input_blocked":false,"hud_visible":true,"player_damage_allowed":true,"automatic_forward":false,
		"player_visible":true,"player_particles_visible":true,"cinematic":false,"absolute_eye":false,
		"shake_strength":0.0,"shake_range":30,"explosions_visible":false,"explosion_elapsed_ms":0,
		"mothership_visible":true,"fade_requested":false,"boundary":"","frame":empty_frame()})
	_shot={"base_content_id":identity.base_content_id,"binding_id":identity.binding_id,"mode":"follow","target":"player"}
	_fade={"active":false,"elapsed_ms":0,"duration_ms":4000,"source_direction":1,"black_plate":false}
	return true

## Call after the caller's ordinary movement, contact and radio updates, using
## the actual environment0 MODEL anchor. Camera and random changes are staged;
## supplied owners (including random) are read-only even on success.
func advance(milliseconds: Variant,radio: RefCounted,player: RefCounted,portal: RefCounted,player_pose: Transform3D,mothership_anchor: Transform3D,random: RefCounted,preceding_camera: RefCounted=null) -> bool:
	error=""
	if _state.is_empty() or not Numbers.integer(milliseconds,0,_max_ms) or not Flight.rigid_pose(player_pose) or not Flight.rigid_pose(mothership_anchor):return reject("Invalid escape time or physical camera anchor")
	if not player is Player or player.selected41_construction_owner()!=_generation or not portal is Portal or portal.mission_context_owner()!=_context or portal.retained_identity()!=_portal_identity:return reject("Escape cannot replace retained player/portal owners")
	if not _valid_radio(radio,_state) or not random is Random or random.snapshot().is_empty():return reject("Escape requires its inherited radio and seeded world stream")
	var speech: Dictionary=radio.snapshot()
	for index in _radio_state.started.size():
		if (_radio_state.started[index] and not speech.started[index]) or (_radio_state.finished[index] and not speech.finished[index]):return reject("Escape cannot restart the inherited radio queue")
	if preceding_camera!=null:
		if not preceding_camera is Camera or not Flight.rigid_pose(preceding_camera.snapshot().get("pose")):return reject("Escape requires a native preceding camera")
		for key in ["base_content_id","binding_id"]:
			if preceding_camera.snapshot().get(key)!=_state[key]:return reject("Escape preceding camera changed content")
	if _state.elapsed_ms>2147483647-milliseconds or _state.phase_elapsed_ms>2147483647-milliseconds:return reject("Escape clock overflow")
	var next:=_state.duplicate(true);next.frame=empty_frame()
	if not next.boundary.is_empty():_state=next;return true
	var shot:=_shot.duplicate(true);var fade:=_fade.duplicate(true)
	var camera: RefCounted=preceding_camera.fork_for_frame() if preceding_camera!=null and _state.phase<7 else _camera.fork_for_frame()
	var rng: RefCounted=random.fork()
	var scene:={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,
		"player_pose":player_pose,"environment":{0:mothership_anchor}}
	next.revision+=1;next.elapsed_ms+=milliseconds
	# Advance an already requested fade before the sequence can request one.
	var remaining: int=milliseconds
	while remaining>0:
		var step:=mini(remaining,150)
		if not Fade.advance(fade,step):return reject("Invalid retained escape fade")
		remaining-=step
	var entered:=false;var animate_explosions:=false
	if _state.phase==5:
		if radio.event_state(7).playback_finished:
			next.phase=6;next.elapsed_ms=0;next.phase_elapsed_ms=0
			next.frame.clear_world_conditions=true;next.frame.reset_elapsed=true
			next.frame.portal_actions=[{"action":"open_at","position":Vector3(25000,20000,-55000),"hold_open":true}]
			next.frame.audio=[{"action":"play","sound_id":153}]
	elif _state.phase==6:
		next.phase_elapsed_ms+=milliseconds;next.shake_strength=0.5
		next.frame.audio=[{"action":"update","sound_id":153,"position":player_pose.origin,"velocity":Vector3.ZERO,
			"parameters":{1:0.5}}]
		if portal.transition_ready(player.snapshot().vitals.hull):
			entered=true;next.phase=7;next.phase_elapsed_ms=0;next.explosion_elapsed_ms=0
			next.input_blocked=true;next.hud_visible=false;next.player_damage_allowed=false
			next.automatic_forward=true;next.player_visible=false;next.player_particles_visible=false
			next.cinematic=true;next.absolute_eye=true;next.shake_strength=0.0;next.explosions_visible=true
			shot={"base_content_id":_state.base_content_id,"binding_id":_state.binding_id,
				"mode":"fixed_eye","target":"environment","slot":0,"inherit_target_up":true,
				"eye":player_pose.origin+Vectors.scaled(Vectors.normalized(player_pose.origin),5000.0)}
			next.frame.input_actions=[{"action":"reset_cinematic"},{"action":"cancel_player_actions"},
				{"action":"set_player_control","enabled":false},{"action":"set_hud_visible","enabled":false},
				{"action":"set_automatic_forward","enabled":true},{"action":"set_player_visible","enabled":false},
				{"action":"set_player_particles_visible","enabled":false},{"action":"set_player_damage","enabled":false}]
			next.frame.camera_actions=[{"action":"set_cinematic","enabled":true},{"action":"set_absolute_eye","enabled":true},
				{"action":"set_projection_fov","radians":1.22},{"action":"select_shot","shot":shot.duplicate(true)}]
			next.frame.portal_actions=[{"action":"begin_closing","age_ms":59000}]
			next.frame.renderer_actions=[{"action":"set_explosion_visible","model_ids":EXPLOSIONS.duplicate(),"visible":true}]
			next.frame.audio.append({"action":"play","sound_id":154})
			if not camera.set_auxiliary_enabled(false) or not camera.set_orbit_enabled(false):return reject(camera.error)
	elif _state.phase==7:
		next.phase_elapsed_ms+=milliseconds;next.shake_strength=100.0
		shot.eye+=Vector3(0,0,-18.0*milliseconds)
		if next.explosions_visible:
			animate_explosions=true;next.explosion_elapsed_ms+=milliseconds
			next.frame.renderer_actions.append({"action":"advance_explosion","model_ids":EXPLOSIONS.duplicate(),"milliseconds":milliseconds,"recursive":false})
			if next.explosion_elapsed_ms>4000 and next.mothership_visible:
				next.mothership_visible=false
				next.frame.renderer_actions.append({"action":"set_environment_visible","slot":0,"visible":false})
		if not next.fade_requested and next.phase_elapsed_ms>15000:
			next.explosions_visible=false;next.fade_requested=true;next.phase_elapsed_ms=0
			next.frame.renderer_actions.append({"action":"set_explosion_visible","model_ids":EXPLOSIONS.duplicate(),"visible":false})
			next.frame.fade_request={"duration_ms":4000,"source_direction":1,"source_color_argument":255}
			fade.active=true;fade.elapsed_ms=0
		elif next.fade_requested and (not fade.active or next.phase_elapsed_ms>=10001):
			fade.black_plate=true;next.boundary="normal_space_return_required"
			next.frame.return_request={"action":"portal_return","cache_player":true,"clear_navigation_target":true,
				"portal_arrival":true,"special_placement":true}
	var jitter:=Vector3.ZERO
	# Auxiliary look perturbation is not supported by the common rig; its source
	# branch also skips this jitter. Cinematic entry explicitly clears it first.
	if milliseconds>0 and next.shake_strength>0 and not camera.auxiliary_snapshot().enabled:
		for axis in 3:jitter[axis]=next.shake_strength*(rng.next_int(60)-30)
	var refresh: Dictionary=shot if entered or next.phase==7 else {}
	if not camera.update(milliseconds,shot,scene,refresh,null,jitter):return reject(camera.error)
	if entered or animate_explosions:
		var forward: Vector3=-camera.snapshot().pose.basis.z
		next.frame.renderer_actions.append({"action":"face_explosion","model_ids":[14286,14287],"forward":forward,"up":Vector3.UP})
		next.frame.renderer_actions.append({"action":"place_explosion","model_id":14286,"position":forward*10000.0})
	next.frame.camera_actions.append({"action":"set_look_shake","strength":next.shake_strength,"range":30})
	if next.phase!=_state.phase:next.frame.phase_changed={"from":_state.phase,"to":next.phase}
	_state=next;_shot=shot;_camera=camera;_fade=fade;_random=rng.snapshot();_radio_state=speech
	return true

static func _valid_radio(radio: RefCounted,identity: Dictionary) -> bool:
	if not radio is Radio or radio.event_state(7).is_empty():return false
	var speech: Dictionary=radio.snapshot()
	for key in ["base_content_id","binding_id","campaign_cursor"]:
		if speech.get(key)!=identity.get(key):return false
	return true

static func empty_frame() -> Dictionary:
	return {"portal_actions":[],"input_actions":[],"camera_actions":[],"renderer_actions":[],"audio":[],
		"clear_world_conditions":false,"reset_elapsed":false,"fade_request":{},"return_request":{}}

func snapshot() -> Dictionary:
	if _state.is_empty():return {}
	var result:=_state.duplicate(true);result.camera=_camera.snapshot();result.shot=_shot.duplicate(true)
	result.fade=_fade.duplicate(true);result.fade.alpha_byte=Fade.alpha(_fade);result.random_state=_random.duplicate(true)
	return result
func camera_owner() -> RefCounted:return null if _camera==null else _camera.fork_for_frame()
func world_owner() -> RefCounted:return _world
func fork_for_frame() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._context=_context;copy._world=_world;copy._generation=_generation;copy._max_ms=_max_ms;copy._portal_identity=_portal_identity
	copy._state=_state.duplicate(true);copy._shot=_shot.duplicate(true);copy._fade=_fade.duplicate(true);copy._random=_random.duplicate(true)
	copy._camera=null if _camera==null else _camera.fork_for_frame()
	copy._radio_state=_radio_state.duplicate(true)
	return copy
func reject(message: String) -> bool:error=message;return false
