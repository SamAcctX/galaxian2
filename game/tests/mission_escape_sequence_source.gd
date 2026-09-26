extends RefCounted
## Small native setup for the escape component, independent of Host/renderers.
## Supplies a detached arrival packet and late source-portal phase/contact,
## following the existing mission_flight_source fixture's boundary stimulus.
## It never writes a save or claims this arrival/cinematic was player-earned.
var error:=""

func prepare(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted) -> RefCounted:
	var equipment: RefCounted=station.equipment_owner();var career: RefCounted=station.contract_owner()
	var before: Dictionary=station.snapshot();var seed: Dictionary=equipment.snapshot().loadout
	var departing: RefCounted=load("res://src/simulation/opening_player_state.gd").new()
	if not departing.configure_local_travel(bindings,cat,equipment,before.player_cache,40):return fail(departing.error)
	var packet: Dictionary=load("res://src/content/gate_arrival_definitions.gd").packet(bindings,cat,
		{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"from_station_id":seed.station_id,"destination_station_id":career.void_source_state().source_station_id},40)
	if packet.is_empty():return fail("Source fixture requires the retained adjacent gate destination")
	if not equipment.relocate_gate_arrival(bindings,cat,packet) or not career.rebase_gate_arrival(bindings,cat,equipment,packet):return fail(equipment.error+career.error)
	var settings: Dictionary=load("res://src/presentation/opening_preview.gd").BASE_STOCK_SETTINGS.duplicate(true)
	settings.difficulty=career.snapshot().difficulty;settings.ship_price_percent=0
	if not career.select_location(bindings,cat,library,packet.station_id,settings,{"state":42},1700000000):return fail(career.error)
	var cache: Dictionary=load("res://src/simulation/flight_player_cache.gd").capture_gate_arrival(bindings,seed,equipment.snapshot().loadout,departing.snapshot())
	if cache.is_empty():return fail("Detached arrival lost the real player's flight pools")
	var selected: RefCounted=career.selected40_entry_owner()
	if selected==null:return fail("Native arrival did not retain its selected source")
	var context: Dictionary=career.selected40_context(bindings,packet.station_id,packet.system_id)
	var bodies: RefCounted=load("res://src/content/scenery_body_resources.gd").new()
	var effects: RefCounted=load("res://src/content/scenery_effect_resources.gd").new()
	var scenery: RefCounted=load("res://src/simulation/opening_scenery.gd").new()
	if not bodies.configure(library,bindings) or not effects.configure(library,bindings):return fail(bodies.error+effects.error)
	if not scenery.configure_selected40(bindings,cat,equipment,context,selected,1700000001,true,bodies,effects):return fail(scenery.error)
	var player: RefCounted=load("res://src/simulation/opening_player_state.gd").new()
	if not player.configure_selected40(bindings,cat,equipment,scenery.world_initialization_owner().npc_construction_owner(),cache):return fail(player.error)
	var builder: RefCounted=load("res://src/simulation/selected40_flight_construction.gd").new()
	var pose: Transform3D=selected.player_pose(Transform3D.IDENTITY)
	if not builder.prepare(bindings,cat,library,player,scenery,equipment,career.snapshot().reputation,pose,0.5,Vector2i(1440,900),career):return fail(builder.error)
	var frame: RefCounted=builder.world_owner()
	frame._encounter._selected40_sequence=frame._encounter._selected40_sequence.fork_for_frame()
	frame._encounter._selected40_sequence._state.phase=4
	frame._pose=Transform3D(Basis.IDENTITY,frame.portal_owner().portal_snapshot().position+Vector3(900,0,0));frame._statistics_pose=frame._pose
	if not frame._portal.observe_contact({"player_pose":frame._pose,"environment_contact_enabled":true,"mining_active":false}) or not frame._resolve_portal_tail():return fail(frame.error+frame._portal.error)
	var entry: RefCounted=frame.prepare_successor41_entry(bindings)
	if entry==null:return fail(frame.error)
	var world: RefCounted=load("res://src/simulation/selected41_world_initialization.gd").new()
	if not world.prepare(bindings,cat,library,entry,1700000001,1700000002):return fail(world.error)
	return world

func fail(message: String) -> RefCounted:error=message;return null
