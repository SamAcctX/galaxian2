extends "res://src/simulation/campaign_visit.gd"
## Adapts a station's inventory boundary to the shared recipe runner. Dialogue
## and completion use the same owners as flight missions; this adapter pays nothing.
const Context=preload("res://src/simulation/mission_station_context.gd")
const Runner=preload("res://src/simulation/mission_runner.gd")
var _runner: RefCounted
var _receipt:={}
var _elapsed_ms:=0

func prepare(bindings: RefCounted,library: RefCounted,catalogues: RefCounted,context: RefCounted,elapsed_ms: int) -> bool:
	if not _state.is_empty() or not context is Context or elapsed_ms<0 or catalogues.content_id!=bindings.base_content_id:return reject("Station result requires its admitted recipe and inventory")
	var recipe: Dictionary=context.recipe()
	if recipe.get("entry")!="station":return reject("No station recipe is available")
	_runner=Runner.new()
	if not _runner.configure(context) or not _runner.prepare_conversations(bindings,library):return reject(_runner.error)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"language":library.active_language,
		"campaign_cursor":recipe.cursor,"mission":recipe.mission.duplicate(true),"phase":"waiting","line_index":0,
		"acknowledged":false,"world_elapsed_ms":elapsed_ms,"reward_credits":0,"mission_completed":false}
	_station_only=true;_station_count=catalogues.tables.stations.size();_elapsed_ms=elapsed_ms
	return true

func poll_station(loadout: Variant,docked: Variant,poll_blocked:=false,_equipment: RefCounted=null) -> bool:
	if _runner==null or not loadout is Dictionary or not docked is bool:return reject("The station recipe lost its observation")
	var context: RefCounted=_runner.context_owner()
	var destination: Dictionary=context.snapshot()
	for key in ["base_content_id","binding_id","station_id","system_id"]:
		if loadout.get(key)!=destination[key]:return reject("The station recipe observed another inventory or location")
	if _state.phase!="waiting" or poll_blocked:return true
	if not _runner.sample_clock(_elapsed_ms,_elapsed_ms):return reject(_runner.error)
	var result: Dictionary=_runner.poll([],false,true,true,{}, {"docked":docked,"station_id":int(loadout.station_id)})
	if result.is_empty():return reject(_runner.error)
	if result.mode==0:return true
	if not _runner.open_result():return reject(_runner.error)
	_station_loadout=loadout.duplicate(true);_state.station_id=int(loadout.station_id)
	_state.phase="conversation";_state.mission_completed=true
	return true

func navigate(action: String) -> bool:
	if _runner==null or _state.phase!="conversation":return reject("No station recipe conversation awaits navigation")
	var result: Dictionary=_runner.navigate(action)
	if result.is_empty():return reject(_runner.error)
	if result.acknowledged:
		_receipt=result.transition.duplicate(true);_state.phase="acknowledged";_state.acknowledged=true
	else:_state.line_index=int(_runner.dialogue().index)
	return true

func transition() -> Dictionary:return _receipt.duplicate(true)

func snapshot() -> Dictionary:
	var result:=_state.duplicate(true)
	var dialogue: Dictionary={"visible":false} if _runner==null else _runner.dialogue()
	result.dialogue={"visible":false,"index":_state.get("line_index",0),"count":0,"previous_available":false}
	result.dialogue.merge(dialogue,true)
	return result

func fork() -> RefCounted:
	var copy: RefCounted=super.fork()
	copy._runner=null if _runner==null else _runner.fork();copy._receipt=_receipt.duplicate(true);copy._elapsed_ms=_elapsed_ms
	return copy
