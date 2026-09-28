extends SceneTree
## Every admitted base-game destination must build its actual world resources.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Worlds=preload("res://src/content/ordinary_world_definitions.gd")
const Flight=preload("res://src/content/free_flight_definitions.gd")
const Planets=preload("res://src/simulation/opening_planet_layout.gd")
const Exterior=preload("res://src/content/station_exterior_resources.gd")
const Factory=preload("res://src/simulation/opening_npc_construction.gd")
const Travel=preload("res://src/content/mido_travel_definitions.gd")
const Scenery=preload("res://src/simulation/scenery_population.gd")
const Cache=preload("res://src/simulation/flight_player_cache.gd")
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected content, bindings and visuals");finish();return
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	check(lib.open(args[0]),lib.error)
	check(bindings.open(args[1],lib.manifest,lib),bindings.error)
	check(cat.open(lib) and lib.select_language("gb"),cat.error+lib.error)
	check(visuals.open(args[2],lib.manifest),visuals.error)
	if failures:finish();return
	var scenery:=Scenery.new();check(scenery.configure(bindings),scenery.error)
	var systems:={}
	for station in range(int(bindings.early_contracts.base_station_stock.last_station_id)+1):
		var world:=Worlds.catalogue_location(bindings,cat,station)
		check(not world.is_empty(),"Missing base-game destination "+str(station))
		if world.is_empty():continue
		check(Flight.flight(bindings,station).get("system_id")==world.system_id and not Flight.docking(bindings,station).is_empty(),"Destination has no flight or docking: "+str(station))
		check(Flight.docking_parameters(Flight.docking(bindings,station)),"Docking rejected an admitted destination: "+str(station))
		check(Travel.navigation_stations(bindings,18,station)==world.station_ids,"Local map lost base-game destinations: "+str(station))
		check(not scenery.for_departure(station,{"companions_empty":true,"location_match":false,"special_placement":false},18).is_empty(),str(station)+": "+scenery.error)
		var linked: PackedInt32Array=cat.tables.systems[world.system_id].linked_system_ids
		if not linked.is_empty():
			var origin_system: int=linked[0]
			var origin: int=cat.tables.systems[origin_system].fields[int(bindings.mido_travel.free_navigation.gate_station_field)]
			var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":0,"station_id":origin,"system_id":origin_system,"equipment_ids":[81,86]}
			var destination:=seed.duplicate(true);destination.station_id=station;destination.system_id=world.system_id
			var player:=seed.duplicate(true);player.merge({"campaign_cursor":18,"vitals":{"hull":150,"armor":80,"shield":50.5},"gamma":20.5})
			var retained:=Cache.capture_gate_arrival(bindings,seed,destination,player)
			check(retained.get("station_id")==station and retained.get("values")=={"hull":150,"armor":80,"shield":50,"gamma":20},"Gate arrival lost the destination or surviving pools: "+str(station))
		var layout:=Planets.new();check(not layout.for_lounge(bindings,cat,station,18).is_empty(),str(station)+": "+layout.error)
		var exterior:=Exterior.new();check(exterior.configure_ordinary_location(lib,bindings,cat,station),str(station)+": "+exterior.error)
		check(not bindings.resolve_hangar(station,cat).is_empty(),"Missing destination hangar: "+str(station))
		if systems.has(world.system_id):continue
		systems[world.system_id]=true
		var context:={"system_id":world.system_id,"station_id":station,"campaign_cursor":18,"difficulty":0.5,"rank":0,"mission_kind":-1,"mission_completed":true,"mission_story":false,"companions_empty":true,"side_missions_empty":true,"station_response":false,"special_arrival":false,"void_encounter":false}
		var factory:=Factory.new()
		check(factory.configure_free_factory(bindings,cat,0,[81,86],context,1),str(station)+": "+factory.error)
	check(Worlds.location(bindings,120).is_empty(),"Base-world expansion admitted DLC")
	finish()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func finish():print("Base worlds: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
