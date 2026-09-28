extends RefCounted
## The real Void station and its fallback incoming gate. The normal-sector seed
## is restored before these position draws; no second ordinary destination exists.
const Definitions=preload("res://src/content/post_sahi_definitions.gd")
const Generator=preload("res://src/simulation/seeded_random.gd")
const Orientation=preload("res://src/simulation/scenery_orientation.gd")
const VoidSource=preload("res://src/simulation/ordinary_void_source.gd")
const Crystals=preload("res://src/content/void_crystal_definitions.gd")
var error:=""
var _state:={}

func configure(bindings: RefCounted,random_state: Dictionary,cursor:=25) -> bool:
	error=""
	if not Definitions.available(bindings) or cursor not in [25,29] or not Definitions.portal_available(bindings.mido_travel,cursor):return reject("The source Void environment is unavailable")
	var rules: Dictionary=bindings.mido_travel.post_sahi["void"]
	return _configure(bindings,random_state,cursor,91 if cursor==29 else int(rules.return_station_id),18 if cursor==29 else int(rules.return_system_id),rules.field)

func configure_ordinary(bindings: RefCounted,random_state: Dictionary,source: RefCounted) -> bool:
	error=""
	if not Definitions.available(bindings) or load("res://src/simulation/mission_context.gd").ordinary_void_route(bindings,source).is_empty() or not Crystals.parameters(bindings.mido_travel.get("void_crystals")):return reject("The ordinary Void environment requires its retained source")
	var retained: Dictionary=load("res://src/simulation/mission_context.gd").ordinary_void_route(bindings,source)
	if retained.get("base_content_id")!=bindings.base_content_id or retained.get("binding_id")!=bindings.binding_id:return reject("The Void source belongs to another content identity")
	return _configure(bindings,random_state,int(retained.campaign_cursor),int(retained.source_station_id),int(retained.source_system_id),bindings.mido_travel.void_crystals.field)

## The real late portal selects the same Void station and incoming gate. The
## mission's later cast placement overrides the player, not these gate draws.
func configure_selected41(bindings: RefCounted,random_state: Dictionary,entry: RefCounted) -> bool:
	error=""
	if not _state.is_empty():return reject("Prepare the source41 environment exactly once")
	if not Definitions.available(bindings) or not is_instance_of(entry,load("res://src/simulation/selected41_portal_entry.gd")):return reject("Source41 environment requires the actual native portal entry")
	var retained: Dictionary=entry.snapshot()
	if retained.is_empty() or not load("res://src/content/selected41_population_definitions.gd").context_valid(bindings,retained.context):return reject("Source41 environment lost its native selected location")
	return _configure(bindings,random_state,41,int(retained.return_station_id),int(retained.return_system_id),bindings.mido_travel.post_sahi["void"].field)

func _configure(bindings: RefCounted,random_state: Dictionary,cursor: int,return_station: int,return_system: int,field: Dictionary) -> bool:
	var random:=Generator.new()
	if not random.restore(random_state):return reject(random.error)
	var rules: Dictionary=bindings.mido_travel.post_sahi["void"]
	var positions:=Vector3(0,int(rules.gate.position_offsets[1])+random.next_int(int(rules.gate.position_bounds[1])),int(rules.gate.position_offsets[2])+random.next_int(int(rules.gate.position_bounds[2])))
	var objects:=[]
	for source in [rules.station,rules.gate]:
		var resources:={}
		for id in source.model_ids:
			var path: String=bindings.resolve(int(id),"mesh")
			if path.is_empty():return reject(bindings.error)
			resources[int(id)]=path
		var gate: bool=source.environment_slot==2
		# The station faces back along its asset axes; all of its attached
		# models share that pose. The incoming gate has its own facing below.
		var pose:=Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)
		if gate:pose=Transform3D(Basis.looking_at(-positions,Vector3.UP,true),positions)
		objects.append({"index":int(source.environment_slot),"pose":pose,"models":resources,
			"model_ids":source.model_ids.map(func(id):return int(id)),"kind":"gate" if gate else "station"})
	var orientation:=Orientation.new().for_station(-1)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"campaign_cursor":cursor,"station_id":-1,"system_id":-1,"return_station_id":return_station,"return_system_id":return_system,
		"objects":objects,"player_position":positions,"initial_random":random_state.duplicate(true),"random_state":random.snapshot(),
		"sky":rules.sky.duplicate(true),"sky_orientation":orientation,"field":field.duplicate(true),"docking_available":false}
	return true

func object_state(index: int) -> Dictionary:
	for row in _state.get("objects",[]):
		if row.index==index:return row.duplicate(true)
	return {}

func snapshot() -> Dictionary:return _state.duplicate(true)
func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy._state=_state.duplicate(true)
	return copy
func reject(message: String) -> bool:error=message;return false
