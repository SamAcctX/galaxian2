extends RefCounted
## Prospective location/placement component, NOT departure or travel authority.
## The eventual enclosing flight must also own scenery, player, equipment,
## targeting, radio and results before committing any of this proposal.
const Rules=preload("res://src/content/selected40_population_definitions.gd")
const VoidSource=preload("res://src/simulation/ordinary_void_source.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
var error:=""
var _state:={}

func prepare(bindings: RefCounted,cat: RefCounted,source: RefCounted,context: Dictionary,chosen_station: Variant,entry_event: String,random: RefCounted) -> bool:
	error=""
	if not Rules.context_valid(bindings,context) or not cat is Catalogues or cat.content_id!=bindings.base_content_id:
		return reject("Selected40 entry requires its explicit source, content and retained career")
	if not source is VoidSource:return reject("Selected40 entry requires the native retained Void source")
	var retained: Dictionary=source.snapshot()
	if retained.is_empty() or retained.get("base_content_id")!=bindings.base_content_id or retained.get("binding_id")!=bindings.binding_id or retained.get("source_station_id",-1)<0:
		return reject("Selected40 entry lost its active source or content identity")
	if not chosen_station is int or chosen_station<0 or chosen_station>=cat.tables.stations.size():
		return reject("A pending -1 mission target is not an ordinary world location")
	if entry_event not in ["station_departure","travel_arrival"]:
		return reject("Selected40 entry requires an explicit launch or completed-travel event")
	if entry_event=="station_departure" and chosen_station!=context.origin_station_id:
		return reject("A station departure cannot relocate the retained player")
	# The source selector observes its OLD source before any qualifying reroll.
	# At that station the call is skipped, so selecting kind161 never rerolls it.
	# Its authored target remains -1, not the selected physical location.
	var selected: bool=chosen_station==retained.source_station_id
	var plan: Dictionary=source.select(context.campaign_cursor,chosen_station,Rules.ENTRY_VALUES.pending_target_station_id,false,random)
	if plan.is_empty():return reject(source.error)
	_state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":context.campaign_cursor,
		"scope":"selected40_world_entry_component","world_type":Rules.ENTRY_VALUES.world_type,
		"station_id":chosen_station,"system_id":int(cat.tables.stations[chosen_station].system_id),
		"pending_mission_kind":context.mission_kind,"pending_target_station_id":Rules.ENTRY_VALUES.pending_target_station_id,
		"mission_kind":context.mission_kind if selected else -1,"mission_story":selected,"selected40":selected,
		"entry_event":entry_event,"special_placement":entry_event=="travel_arrival",
		"source_before":retained,"source_after":plan.source,"source_event":plan.event,"random_state":plan.random_state}
	return true

## Called after the shared environment has produced its ordinary heading. The
## special authored tail replaces it only for a selected incoming encounter;
## it does not consume another random value or apply to a station launch.
func player_pose(ordinary: Transform3D) -> Variant:
	error=""
	if _state.is_empty() or not _valid_pose(ordinary):reject("Selected40 player placement requires a proper native pose");return null
	if not _state.selected40 or not _state.special_placement:return ordinary
	var position: Array=Rules.ENTRY_VALUES.arrival_player_position
	return Transform3D(Basis(Vector3.UP,float(Rules.ENTRY_VALUES.arrival_player_yaw)),Vector3(position[0],position[1],position[2]))

## The selected cast relocates portal slot3 on BOTH entry branches. This must
## not be accidentally nested beneath the conditional player-placement flag.
func portal_pose(ordinary: Transform3D) -> Variant:
	error=""
	if _state.is_empty() or not _valid_pose(ordinary):reject("Selected40 portal placement requires a proper native pose");return null
	if not _state.selected40:return ordinary
	var result:=ordinary
	var position: Array=Rules.ENTRY_VALUES.portal_position
	result.origin=Vector3(position[0],position[1],position[2])
	return result

static func _valid_pose(value: Transform3D) -> bool:
	return value.is_finite() and absf(value.basis.determinant()-1.0)<0.0001 and value.basis.is_equal_approx(value.basis.orthonormalized())

func snapshot() -> Dictionary:return _state.duplicate(true)
func fork() -> RefCounted:
	var result: RefCounted=get_script().new();result._state=_state.duplicate(true);return result
func reject(message: String) -> bool:error=message;return false
