extends SceneTree
## Every Valkyrie destination builds its actual world resources.
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
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var extra: Array=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		check(bindings.attach_dekato_source(extra[1],lib.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(extra[1],lib.manifest),bindings.error)
	if failures:finish();return
	var scenery:=Scenery.new();check(scenery.configure(bindings),scenery.error)
	var systems:={}
	for station in [100,101,105,106,107,108]:
		var world:=Worlds.catalogue_location(bindings,cat,station)
		check(not world.is_empty(),"Missing Valkyrie destination "+str(station))
		if world.is_empty():continue
		check(Flight.flight(bindings,station).get("system_id")==world.system_id and not Flight.docking(bindings,station).is_empty(),"Destination has no flight or docking: "+str(station))
		check(Flight.docking_parameters(Flight.docking(bindings,station)),"Docking rejected an admitted destination: "+str(station))
		check(Travel.navigation_stations(bindings,47,station)==world.station_ids,"Local map lost base-game destinations: "+str(station))
		check(not scenery.for_departure(station,{"companions_empty":true,"location_match":false,"special_placement":false},47).is_empty(),str(station)+": "+scenery.error)
		var linked: PackedInt32Array=cat.tables.systems[world.system_id].linked_system_ids
		if not linked.is_empty():
			var origin_system: int=linked[0]
			var origin: int=cat.tables.systems[origin_system].fields[int(bindings.mido_travel.free_navigation.gate_station_field)]
			var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":0,"station_id":origin,"system_id":origin_system,"equipment_ids":[81,86]}
			var destination:=seed.duplicate(true);destination.station_id=station;destination.system_id=world.system_id
			var player:=seed.duplicate(true);player.merge({"campaign_cursor":47,"vitals":{"hull":150,"armor":80,"shield":50.5},"gamma":20.5})
			var retained:=Cache.capture_gate_arrival(bindings,seed,destination,player)
			check(retained.get("station_id")==station and retained.get("values")=={"hull":150,"armor":80,"shield":50,"gamma":20},"Gate arrival lost the destination or surviving pools: "+str(station))
		var layout:=Planets.new();check(not layout.for_lounge(bindings,cat,station,47).is_empty(),str(station)+": "+layout.error)
		var exterior:=Exterior.new();check(exterior.configure_ordinary_location(lib,bindings,cat,station),str(station)+": "+exterior.error)
		check(not bindings.resolve_hangar(station,cat).is_empty(),"Missing destination hangar: "+str(station))
		var random: RefCounted=load("res://src/simulation/seeded_random.gd").new();random.seed_from(station)
		var stock: RefCounted=load("res://src/simulation/station_stock.gd").new()
		var ok: bool=stock.prepare(bindings,cat,{"station_id":station,"campaign_cursor":47,"ship_price_percent":0,"valkyrie_owned":true,"supernova_owned":false,"difficulty":0.5,"energy_availability_percent":0,"missile_availability_percent":0},random.snapshot(),1789103558)
		check(ok,str(station)+" stock: "+stock.error)
		if ok:
			var market: Dictionary=stock.snapshot()
			print("STOCK ",station," items=",market.items.map(func(row):return row.item_id)," ships=",market.ships.map(func(row):return row.ship_id))
		if systems.has(world.system_id):continue
		systems[world.system_id]=true
		var context:={"system_id":world.system_id,"station_id":station,"campaign_cursor":47,"difficulty":0.5,"rank":0,"mission_kind":-1,"mission_completed":true,"mission_story":false,"companions_empty":true,"side_missions_empty":true,"station_response":false,"special_arrival":false,"void_encounter":false}
		var factory:=Factory.new()
		check(factory.configure_free_factory(bindings,cat,0,[81,86],context,1),str(station)+": "+factory.error)
	# Quineros adds each terminated board leader's ship (45-48) as a pirate build.
	var wanted_stock: RefCounted=load("res://src/simulation/station_stock.gd").new()
	var seeded: RefCounted=load("res://src/simulation/seeded_random.gd").new();seeded.seed_from(107)
	check(wanted_stock.prepare(bindings,cat,{"station_id":107,"campaign_cursor":140,"ship_price_percent":0,"valkyrie_owned":true,"supernova_owned":true,"difficulty":0.5,"energy_availability_percent":0,"missile_availability_percent":0,"wanted_ships":[45,48]},seeded.snapshot(),1789103558),"Quineros wanted stock: "+wanted_stock.error)
	var offered: Array=wanted_stock.snapshot().get("ships",[]).map(func(row):return int(row.ship_id))
	check(offered.has(45) and offered.has(48) and offered.has(60),"Quineros lacks the terminated pilots' ships: "+str(offered))
	var VW=load("res://src/content/valkyrie_world_definitions.gd")
	var table: Array=cat.tables.get("wanted",[])
	if table.size()==25:
		var wanted:={"entries":range(25).map(func(_i):return {"dead":false,"surrendered":false}),"bounties":[0,0,0,0]}
		wanted.entries[12].dead=true
		check(VW.wanted_ships({"wanted":wanted},table)==[46],"Only the dead board leader's ship goes on sale")
		var notice: Dictionary=VW.wanted_ship_notice({"wanted":wanted},table,{})
		check(notice.get("text_id")==3221 and notice.get("ship_text_id")==948 and VW.wanted_ship_notice({"wanted":wanted},table,{"wanted_12":true}).is_empty(),"The wanted-ship notice is wrong or repeats: "+str(notice))
	# New Most Wanted criminals at a docking: 3219 for one, 3220 (#N) for more.
	check(VW.wanted_news({"wanted":{"news":1}}).get("text_id")==3219 and VW.wanted_news({"wanted":{"news":3}}).get("text_id")==3220 and VW.wanted_news({"wanted":{"news":0}}).is_empty() and VW.wanted_news({}).is_empty(),"The new-criminals notice is wrong")
	# Docking medal notices: 638 all medals, 639 all gold, 640 + fireworks
	# blueprint with every add-on medal, 3222 after cursor 161; once per run.
	var Notices=preload("res://src/content/medal_notices_definitions.gd")
	var levels:=[];levels.resize(36);levels.fill(2)
	var career:={"campaign_cursor":140,"base_medals":{"version":1,"levels":levels.duplicate()},"blueprints":{"entries":[{"item_id":232,"available":false}]}}
	check(Notices.next(career,{}).get("text_id")==638 and Notices.next(career,{638:true}).is_empty(),"All base medals did not give 638 once")
	levels.fill(1);career.base_medals.levels=levels.duplicate()
	check(Notices.next(career,{638:true}).get("text_id")==639 and Notices.next(career,{638:true,639:true}).is_empty(),"All gold did not give 639 once (or 640 came without add-on medals)")
	career.elite_medals=range(36,45)
	var fireworks: Dictionary=Notices.next(career,{638:true,639:true})
	check(fireworks.get("text_id")==640 and fireworks.get("blueprint")==232,"All gold and add-on medals did not unlock the fireworks: "+str(fireworks))
	career.blueprints.entries[0].available=true
	check(Notices.next(career,{638:true,639:true}).is_empty(),"640 repeated after the fireworks were unlocked (or 3222 came before cursor 162)")
	career.campaign_cursor=162
	check(Notices.next(career,{638:true,639:true}).get("text_id")==3222 and Notices.next(career,{638:true,639:true,3222:true}).is_empty(),"The Specter notice 3222 did not come once after cursor 161")
	var hardcore:={"campaign_cursor":162,"difficulty":1.5,"base_medals":{"levels":[]}}
	check(Notices.next(hardcore,{}).get("text_id")==3222 and Notices.next(hardcore.merged({"difficulty":0.5},true),{}).is_empty(),"An Extreme career without medals did not get the Specter notice")
	# Valkyrie's Polytron Boost (195) and AB-4 Octopus tractor (194) can be fitted.
	var boost: Dictionary=load("res://src/content/booster_definitions.gd").resolve(bindings,cat,[195])
	check(boost.get("sound_id")==1102 and boost.get("item_id")==195,"The Polytron Boost is not fittable: "+str(boost))
	var tractor: RefCounted=load("res://src/simulation/tractor_recovery.gd").new()
	check(tractor.configure(bindings,cat,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":int(bindings.station_entry.ship_id),"equipment_ids":[194]},lib),"The AB-4 Octopus is not fittable: "+tractor.error)
	# Supernova's stations are expansion worlds too (Katashán, 120).
	check(not Worlds.location(bindings,120).is_empty(),"Supernova's Katashán is not an expansion world")
	finish()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func finish():print("Valkyrie worlds: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
