extends RefCounted
## Original area-bomb burst metadata. Geometry and audio remain local
## imported content; this provider never creates equipment or mission progress.
const Library = preload("res://src/content/library.gd")
const Bindings = preload("res://src/content/resource_bindings.gd")
const Bombs = preload("res://src/content/emp_bombs_definitions.gd")
const Ownership = preload("res://src/content/secondary_ownership_definitions.gd")
const AEM = preload("res://src/content/aem.gd")
const Timing = preload("res://src/content/scenery_effect_resources.gd")
const TypeZero = preload("res://src/content/npc_destruction_resources.gd")
const MODEL_ID := 16805
const MODEL_PATH := "resources/data/assets/main/3d/meshes/fx/explosion_emp_anim_lookat_add.aem"
const ITEM_IDS := [41, 42, 43]
const SOUND_IDS := [15, 16, 17]
const CAMERA_RANGE := 30000.0
const CAMERA_DECAY_MS := 2000
const CAMERA_SPREAD := 50
var error := ""
var _state := {}

func configure(library: RefCounted, bindings: RefCounted, kind:=6) -> bool:
	_state = {}; error = ""
	if not library is Library or not bindings is Bindings or not Ownership.available(bindings):
		return reject("EMP detonation requires supported secondary content")
	if not Library.valid_hash(bindings.base_content_id) or not Library.valid_hash(bindings.binding_id) or library.manifest.get("content_id") != bindings.base_content_id:
		return reject("EMP detonation resources belong to another content identity")
	# Antimatter (7) and Ion Lambda (34) share the type-0 burst.
	if kind==7 or kind==int(Bombs.ION_LAMBDA.kind):
		var resources:=TypeZero.new()
		if not resources.configure(library,bindings):return reject(resources.error)
		_state=resources.snapshot();_state.kind=kind;_state.effect_type=0
		return true
	if kind==int(Bombs.SHOCK.kind):return _configure_shock(library,bindings)
	if kind==int(Bombs.FIREWORKS.family):return _configure_glow(library,bindings,kind,int(Bombs.FIREWORKS.burst_model_id),float(Bombs.FIREWORKS.burst_scale))
	if kind!=6:return reject("Unsupported area-bomb effect family")
	if bindings.resolve(MODEL_ID, "mesh") != MODEL_PATH or bindings.material_for_mesh(MODEL_PATH, "high").get("render_type") != 2:
		return reject("EMP detonation lost its original additive model mapping")
	var bytes: PackedByteArray = library.read_resource(MODEL_PATH, AEM.MAX_BYTES)
	if bytes.is_empty(): return reject(library.error)
	var reader := AEM.new()
	var mesh: Dictionary = reader.decode(bytes)
	if mesh.is_empty(): return reject(reader.error)
	if mesh.get("version") != 4: return reject("Unsupported EMP detonation mesh version")
	var timing := Timing.playback_range(mesh.surfaces)
	if timing.is_empty(): return reject("Unsupported EMP detonation animation timing")
	_state = {"base_content_id": bindings.base_content_id, "binding_id": bindings.binding_id,
		"kind":6,"effect_type": 7, "models": [{"model_id": MODEL_ID, "resource": MODEL_PATH,
		"start_ms": timing.start_ms, "end_ms": timing.end_ms}], "duration_ms": timing.end_ms}
	return true

## Shock Blast burst: its look-at glow and the shock sphere (explosion type
## 11), played once at 50000x around the ship. The sphere is optional.
func _configure_shock(library: RefCounted, bindings: RefCounted) -> bool:
	if not _configure_glow(library,bindings,int(Bombs.SHOCK.kind),int(Bombs.SHOCK.glow_model_id),float(Bombs.SHOCK.glow_scale)):return false
	var id:=int(Bombs.SHOCK.sphere_model_id)
	var path: String=bindings.resolve(id,"mesh")
	var mesh: Dictionary={} if path.is_empty() else AEM.new().decode(library.read_resource(path,AEM.MAX_BYTES))
	var timing: Dictionary={} if mesh.is_empty() else Timing.playback_range(mesh.surfaces)
	if not timing.is_empty():_state.sphere={"model_id":id,"resource":path,"start_ms":timing.start_ms,"end_ms":timing.end_ms}
	bindings.error=""
	return true

## A burst that plays one look-at model once at a scale (Shock Blast, Fireworks).
func _configure_glow(library: RefCounted, bindings: RefCounted, family: int, id: int, scale: float) -> bool:
	var path: String=bindings.resolve(id,"mesh")
	if path.is_empty():return reject("The bomb's burst model is unavailable")
	var mesh: Dictionary=AEM.new().decode(library.read_resource(path,AEM.MAX_BYTES))
	if mesh.is_empty():return reject("The bomb's burst model could not be read")
	var timing := Timing.playback_range(mesh.surfaces)
	if timing.is_empty(): return reject("Unsupported bomb burst animation timing")
	_state = {"base_content_id": bindings.base_content_id, "binding_id": bindings.binding_id,
		"kind":family,"effect_type":7,"scale":scale,"models":[{"model_id":id,"resource":path,
		"start_ms": timing.start_ms, "end_ms": timing.end_ms}], "duration_ms": timing.end_ms}
	return true

func snapshot() -> Dictionary: return _state.duplicate(true)
func reject(message: String) -> bool: error = message; return false
