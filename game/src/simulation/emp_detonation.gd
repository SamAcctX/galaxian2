extends RefCounted
## Retained native area-bomb burst. The weapon owner supplies its accepted
## before/after physics samples, so late manual pulses are observed next update.
## This component does not apply damage, change ammunition or move a camera.
const Resources = preload("res://src/content/emp_detonation_resources.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")
const Playback = preload("res://src/simulation/model_playback.gd")
const Vitals = preload("res://src/simulation/combat_vitals.gd")
const Vectors = preload("res://src/simulation/source_vectors.gd")
const Bomb = preload("res://src/simulation/emp_bombs.gd")
const TypeZero = preload("res://src/simulation/type_zero_explosion.gd")
const Mines=preload("res://src/content/mine_definitions.gd")
var error := ""
var _state := {}
var _identity: RefCounted

func configure(resources: RefCounted, item_id: int) -> bool:
	error = ""
	var declaration:=declaration_for(item_id)
	if not resources is Resources or declaration.is_empty():
		return reject("EMP burst requires its prepared original resources and item")
	var data: Dictionary = resources.snapshot()
	var family: int=Mines.effect_family(item_id) if declaration.kind==11 else int(declaration.get("family",declaration.kind))
	if data.is_empty() or data.kind!=family: return reject("Bomb burst resources are not prepared for this family")
	var effect: Dictionary
	if data.effect_type==0:effect=TypeZero.create(data,[],-1)
	else:effect={"active":false,"elapsed_ms":0,"duration_ms":data.duration_ms,"position":Vector3.ZERO,"models":[TypeZero.model_clock(data.models[0])]}
	if effect.is_empty():return reject("Bomb burst has unsupported animation clocks")
	effect.position=Vector3.ZERO
	if data.has("scale"):effect.scale=float(data.scale)
	_state = {"base_content_id": data.base_content_id, "binding_id": data.binding_id,
		"item_id": item_id,"kind":declaration.kind,"effect_type":data.effect_type, "projectile_id": 0, "cached_position": Vector3.ZERO, "triggered": false,
		"camera": {"initial_strength": 0.0, "elapsed_ms": 0, "strength": 0.0, "spread": 0},
		"effect":effect}
	_identity = RefCounted.new()
	return true

func begin_projectile(shot: Dictionary) -> bool:
	error = ""
	if _state.is_empty() or not valid_shot(shot) or shot.get("phase") != "flying" or shot.id <= _state.projectile_id:
		return reject("EMP burst reset requires a newly launched projectile")
	_state.projectile_id = shot.id; _state.cached_position = shot.position; _state.triggered = false
	_state.effect.active = false; _state.effect.elapsed_ms = 0; _state.effect.position = Vector3.ZERO
	_state.camera = {"initial_strength": 0.0, "elapsed_ms": 0, "strength": 0.0, "spread": 0}
	Playback.restart(_state.effect.models)
	return true

func advance(before: Dictionary, after: Dictionary, delta_ms: Variant, observer_position: Variant = null) -> Dictionary:
	error = ""
	if _state.is_empty() or not Numbers.integer(delta_ms, 0, 2147483647) or not valid_sample(before) or not valid_sample(after):
		return failed("EMP burst requires finite matching weapon samples and an integer frame")
	if observer_position != null and (not observer_position is Vector3 or not observer_position.is_finite()):
		return failed("EMP camera observation requires a finite player position")
	if before.weapon != after.weapon or after.elapsed_ms != before.elapsed_ms + delta_ms:
		return failed("EMP burst samples do not describe one weapon update")
	var previous: Dictionary = before.shot
	var current: Dictionary = after.shot
	if previous.is_empty():
		if not current.is_empty(): return failed("EMP burst cannot infer a launch from physics")
	elif previous.id != _state.projectile_id:
		return failed("EMP burst lost its retained projectile generation")
	elif previous.phase == "flying":
		if current.is_empty() or current.id != previous.id or _state.triggered:
			return failed("EMP burst lost its flying projectile transition")
	elif not current.is_empty():
		return failed("EMP burst requires the consumed detonation flag to clear")
	var next := _state.duplicate(true)
	# The wrapper saves the position before movement, not the damage pulse's
	# newer hit position. A previously flagged manual pulse keeps that cache.
	if previous.get("phase") == "flying": next.cached_position = previous.position
	var started: bool = not next.triggered and (previous.get("phase") == "detonated" or current.get("phase") == "detonated")
	var audio: Array[Dictionary] = []
	var own_hit:={}
	if started:
		if observer_position == null: return failed("A newly observed EMP burst requires the current player position")
		var difference: Vector3 = next.cached_position - observer_position
		var distance := Vitals.single(sqrt(Vectors.dot(difference, difference)))
		if not is_finite(distance): return failed("EMP camera distance exceeds finite world coordinates")
		var attenuation := Vitals.single(1.0 - Vitals.single(minf(distance, Resources.CAMERA_RANGE) / Resources.CAMERA_RANGE))
		next.camera = {"initial_strength": attenuation, "elapsed_ms": 0, "strength": attenuation, "spread": Resources.CAMERA_SPREAD}
		next.triggered = true; next.effect.active = true; next.effect.position = next.cached_position
		if next.kind!=11:
			own_hit=Bomb.self_hit(before.weapon,next.cached_position,observer_position)
			if own_hit.is_empty():return failed("Bomb self-damage observation exceeds finite world coordinates")
		if int(declaration_for(next.item_id).burst_sound)>=0:
			audio.append({"action": "start_spatial", "source_id": declaration_for(next.item_id).burst_sound,
				"position": next.cached_position, "pitch_raw": 0.0})
	var retired := false
	var camera := {}
	if next.effect.active:
		if next.effect.elapsed_ms > 2147483647 - delta_ms: return failed("EMP burst clock exceeded its integer range")
		Playback.advance(next.effect.models, delta_ms)
		next.effect.elapsed_ms += delta_ms
		# Capture distance once at the wrapper trigger, then decay on its own
		# bounded clock. Moving the player later does not resample attenuation.
		next.camera.elapsed_ms = mini(Resources.CAMERA_DECAY_MS, int(next.camera.elapsed_ms) + int(delta_ms))
		var decay := Vitals.single(1.0 + Vitals.single(float(next.camera.elapsed_ms) / -float(Resources.CAMERA_DECAY_MS)))
		next.camera.strength = Vitals.single(decay * float(next.camera.initial_strength))
		if next.effect.elapsed_ms > next.effect.duration_ms:
			Playback.restart(next.effect.models)
			next.effect.active = false; next.effect.elapsed_ms = 0; retired = true
			next.camera.elapsed_ms = 0; next.camera.strength = 0.0; next.camera.spread = 0
		camera = {"strength": next.camera.strength, "spread": next.camera.spread, "projectile_id": next.projectile_id}
	_state = next
	return {"started": started, "retired": retired, "audio": audio, "camera": camera,"self_hit":own_hit}

func valid_sample(sample: Dictionary) -> bool:
	var weapon: Variant = sample.get("weapon")
	if not weapon is Dictionary or not sample.get("shot") is Dictionary or not Numbers.integer(sample.get("elapsed_ms"), 0, 2147483647): return false
	for key in ["base_content_id", "binding_id", "item_id"]:
		if weapon.get(key) != _state[key]: return false
	return weapon.get("kind") == _state.kind and valid_shot(sample.shot)

static func valid_shot(shot: Dictionary) -> bool:
	if shot.is_empty(): return true
	return Numbers.integer(shot.get("id"), 1, 2147483647) and shot.get("phase") in ["flying", "detonated"] and shot.get("position") is Vector3 and shot.position.is_finite() and shot.get("velocity") is Vector3 and shot.velocity.is_finite()

static func declaration_for(item_id: int) -> Dictionary:
	var declaration:=Bomb.Definitions.declaration(item_id)
	return Mines.declaration(item_id) if declaration.is_empty() else declaration

func presentation_identity() -> RefCounted: return _identity
func snapshot() -> Dictionary: return _state.duplicate(true)
func fork() -> RefCounted:
	var next: RefCounted = get_script().new()
	next._state = _state.duplicate(true); next._identity = _identity
	return next
func reject(message: String) -> bool: error = message; return false
func failed(message: String) -> Dictionary: error = message; return {}
