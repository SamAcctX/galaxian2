extends RefCounted
## Ten retained bursts with one launcher camera clock. A reused projectile slot
## does not cancel or restart an explosion that is still playing there.
const Burst=preload("res://src/simulation/emp_detonation.gd")
const Definitions=preload("res://src/content/mine_definitions.gd")
const Vitals=preload("res://src/simulation/combat_vitals.gd")
var error:=""
var _bursts: Array[RefCounted]=[]
var _weapon:={}
var _elapsed_ms:=0
var _camera:={"initial_strength":0.0,"elapsed_ms":0,"strength":0.0,"spread":0,"projectile_id":0,"projectile_slot":0}

func configure(resources: RefCounted,weapon: Dictionary) -> bool:
	error=""
	if weapon.get("kind")!=11 or not weapon.get("item_id") is int:return reject("Mine bursts require a configured mine launcher")
	var bursts: Array[RefCounted]=[]
	for unused in Definitions.CAPACITY:
		var burst:=Burst.new()
		if not burst.configure(resources,weapon.item_id):return reject(burst.error)
		for key in ["base_content_id","binding_id"]:
			if burst.snapshot()[key]!=weapon.get(key):return reject("Mine bursts belong to another weapon identity")
		bursts.append(burst)
	_bursts=bursts;_weapon=weapon.duplicate(true);_elapsed_ms=0
	_camera={"initial_strength":0.0,"elapsed_ms":0,"strength":0.0,"spread":0,"projectile_id":0,"projectile_slot":0}
	return true

func advance(blasts: Array,delta_ms: Variant,observer: Variant) -> Dictionary:
	error=""
	if _weapon.is_empty() or not Vitals.integer(delta_ms) or _elapsed_ms>Vitals.MAX_INTEGER-delta_ms:return fail("Invalid mine burst frame")
	var by_slot:={}
	for blast in blasts:
		if not blast is Dictionary or not Vitals.integer(blast.get("slot")) or blast.slot>=Definitions.CAPACITY or by_slot.has(blast.slot):return fail("Mine pulse lost its unique projectile slot")
		for key in ["base_content_id","binding_id","item_id"]:
			if blast.get(key)!=_weapon[key]:return fail("Mine pulse changed weapon identity")
		if not Vitals.integer(blast.get("projectile_id")) or blast.projectile_id<1 or not blast.get("position") is Vector3 or not blast.position.is_finite():return fail("Mine pulse lacks finite accepted geometry")
		by_slot[blast.slot]=blast
	var next: Array[RefCounted]=[];var audio: Array[Dictionary]=[];var camera: Dictionary=_camera.duplicate();var wrote:=false
	for index in _bursts.size():
		var burst: RefCounted=_bursts[index].fork()
		var before:={"weapon":_weapon,"shot":{},"elapsed_ms":_elapsed_ms}
		var after:={"weapon":_weapon,"shot":{},"elapsed_ms":_elapsed_ms+delta_ms}
		if by_slot.has(index) and not burst.snapshot().effect.active:
			var blast: Dictionary=by_slot[index]
			var shot:={"id":blast.projectile_id,"phase":"flying","position":blast.position,"velocity":Vector3.ZERO}
			if not burst.begin_projectile(shot):return fail(burst.error)
			before.shot=shot;after.shot=shot.duplicate();after.shot.phase="detonated"
		var event: Dictionary=burst.advance(before,after,delta_ms,observer)
		if event.is_empty():return fail(burst.error)
		for cue in event.audio:
			cue.projectile_slot=index;audio.append(cue)
		var state: Dictionary=burst.snapshot()
		if event.started:
			camera.initial_strength=state.camera.initial_strength;camera.elapsed_ms=0
		if state.effect.active or event.retired:
			camera.projectile_id=state.projectile_id;camera.projectile_slot=index;wrote=true
			camera.elapsed_ms=mini(Burst.Resources.CAMERA_DECAY_MS,camera.elapsed_ms+int(delta_ms))
			camera.strength=Vitals.single(float(camera.initial_strength)*(1.0-float(camera.elapsed_ms)/Burst.Resources.CAMERA_DECAY_MS))
			camera.spread=Burst.Resources.CAMERA_SPREAD
			if event.retired:camera.elapsed_ms=0;camera.strength=0.0;camera.spread=0
		next.append(burst)
	_bursts=next;_camera=camera;_elapsed_ms+=delta_ms
	return {"audio":audio,"camera":camera.duplicate() if wrote else {}}

func burst_owner(index: int) -> RefCounted:return _bursts[index] if index>=0 and index<_bursts.size() else null
func snapshot() -> Dictionary:return {"weapon":_weapon.duplicate(true),"bursts":_bursts.map(func(burst):return burst.snapshot()),"camera":_camera.duplicate(),"elapsed_ms":_elapsed_ms}
func fork() -> RefCounted:
	var next: RefCounted=get_script().new()
	next._weapon=_weapon.duplicate(true);next._elapsed_ms=_elapsed_ms;next._camera=_camera.duplicate()
	for burst in _bursts:next._bursts.append(burst.fork())
	return next
func reject(message: String) -> bool:error=message;return false
func fail(message: String) -> Dictionary:error=message;return {}
