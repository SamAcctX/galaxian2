extends RefCounted
## Detached galaxy observation: browsing never selects a career location or
## advances its random stream. The context owner admits destination worlds.
const Context=preload("res://src/simulation/mission_context.gd")
const Navigation=preload("res://src/simulation/system_navigation.gd")
const VoidSource=preload("res://src/simulation/ordinary_void_source.gd")
const Recipe=preload("res://src/content/mission_recipe.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
var error:=""
var _state:={}

func configure(library: RefCounted,bindings: RefCounted,cat: RefCounted,observation: Dictionary) -> bool:
	error=""
	if bindings==null or cat==null or library==null or library.manifest.get("content_id")!=bindings.base_content_id or cat.content_id!=bindings.base_content_id:return reject("Galaxy map requires matching imported content")
	for key in ["base_content_id","binding_id"]:
		if observation.get(key)!=bindings.get(key):return reject("Galaxy map belongs to another career")
	var rules: Dictionary=bindings.mido_travel.get("map",{})
	if rules.is_empty() or int(observation.get("campaign_cursor",-1))<int(rules.galaxy_cursor):return reject("Galaxy navigation is not unlocked")
	var location: Dictionary=observation.get("location",{})
	if not Numbers.integer(location.get("system_id"),0,cat.tables.systems.size()-1) or not Numbers.integer(location.get("station_id"),0,cat.tables.stations.size()-1) or cat.tables.stations[location.station_id].system_id!=location.system_id:return reject("Galaxy map lost the current location")
	var career: Dictionary=observation.get("contracts",{})
	var navigation:=Navigation.new()
	if not navigation.configure(bindings,cat,career.get("lounges",{}).get("system_availability")):return reject(navigation.error)
	var availability: Array=navigation.snapshot().system_availability
	var destinations:=Context.navigation_destinations(bindings,cat,observation)
	var markers:=Recipe.objective_markers(bindings.early_contracts,career.get("mission",{}),career.get("accepted_contact",{}),observation.get("cargo",{}))
	var target_system:=-1
	if markers.system_station_id>=0:target_system=int(cat.tables.stations[markers.system_station_id].system_id)
	var warning:={}
	if career.has("void_source"):
		var source:=VoidSource.new()
		if not source.configure(bindings,cat,availability,career.void_source):return reject(source.error)
		var retained:=source.snapshot();var limits: Dictionary=bindings.mido_travel.void_access.map_warning
		if int(observation.campaign_cursor)>=int(limits.first_cursor) and retained.source_system_id>=0:
			var station_id:=int(retained.source_station_id) if int(observation.campaign_cursor)>=int(limits.target_hint_first_cursor) else -1
			warning={"system_id":int(retained.source_system_id),"station_id":station_id,
				"system_name":cat.tables.systems[retained.source_system_id].name,"station_name":cat.tables.stations[station_id].name if station_id>=0 else ""}
	var rows:=[];var links:=[];var origin: Dictionary=cat.tables.systems[location.system_id]
	for system in cat.tables.systems:
		if not availability[system.id]:continue
		var position:=Vector3((100.0-system.fields[3])*140.0-10000.0,(100.0-system.fields[4])*130.0-9000.0,(100.0-system.fields[5])*60.0+1000.0)
		var faction:=int(system.fields[2])
		if not position.is_finite() or faction<0 or faction>=rules.ui.faction_image_ids.size():return reject("Galaxy system has invalid coordinates or faction")
		var supported: bool=Array(system.station_ids).any(func(id):return destinations.has(id))
		rows.append({"system_id":int(system.id),"name":system.name,"position":position,"model_id":18070+int(system.sky_index),
			"faction_image_id":int(rules.ui.faction_image_ids[faction]),"current":system.id==location.system_id,
			"story_target":system.station_ids.has(observation.get("mission",{}).get("station_id",-1)),"contract_target":system.id==target_system,
			"void_source":system.id==warning.get("system_id",-1),"supported":supported,
			"connected":system.id==location.system_id or origin.linked_system_ids.has(system.id)})
		for other in system.linked_system_ids:
			if availability[other] and system.id<other:links.append([int(system.id),int(other)])
	var route: Array=[]
	var mission_target:=target_system
	if mission_target<0:
		var story_station:=int(observation.get("mission",{}).get("station_id",-1))
		if story_station>=0 and story_station<cat.tables.stations.size():mission_target=int(cat.tables.stations[story_station].system_id)
	if mission_target>=0:route=navigation.route(int(location.system_id),mission_target)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"language":library.active_language,
		"campaign_cursor":int(observation.campaign_cursor),"station_id":int(location.station_id),"system_id":int(location.system_id),
		"rows":rows,"links":links,"mission_route":route,"void_warning":warning,"destinations":destinations,
		"selected_system_id":int(location.system_id),"selected_station_id":-1,"confirmation_visible":false,"diagnostic":"",
		"route_mode":"galaxy","ui":rules.ui.duplicate(true),"visuals":rules.visuals.duplicate(true),
		"labels":{"title":library.strings[176],"back":library.strings[169],"open":library.strings[177],"key":library.strings[389],"unconnected":library.strings[409]}}
	return true

func select_system(id: int) -> bool:
	error=""
	if not _state.get("rows",[]).any(func(row):return row.system_id==id):return reject("This system is not known to the retained career")
	_state.selected_system_id=id;_state.diagnostic=""
	return true

func move_selection(direction: Vector2) -> bool:
	if _state.is_empty() or not direction.is_finite() or direction.is_zero_approx():return reject("Galaxy selection needs a direction")
	var rows: Array=_state.rows;var selected: Dictionary={}
	for row in rows:
		if row.system_id==_state.selected_system_id:selected=row;break
	if selected.is_empty():return select_system(int(rows[0].system_id))
	var best:=-1;var score:=INF
	for row in rows:
		# Source +X faces screen-left; source +Y faces screen-up.
		var offset: Vector2=-Vector2(row.position.x-selected.position.x,row.position.y-selected.position.y)
		var forward:=offset.dot(direction.normalized())
		if forward<=0:continue
		var candidate:=offset.length_squared()/forward
		if candidate<score:score=candidate;best=int(row.system_id)
	return true if best<0 else select_system(best)

func open_selected() -> int:
	error=""
	for row in _state.get("rows",[]):
		if row.system_id!=_state.selected_system_id:continue
		if not row.connected:_state.diagnostic=_state.labels.unconnected;return -1
		if not row.supported:_state.diagnostic="This destination is not available in the current flight.";return -1
		return int(row.system_id)
	return -1

func snapshot() -> Dictionary:return _state.duplicate(true)
func reject(message: String) -> bool:error=message;return false
