extends "res://tests/ordinary_worlds.gd"
## Source-catalogue and detached native-world checks, not an earned journey.
## A source-specific fixture supplies records; the actual world owners are shared.
const GateRules=preload("res://src/content/gate_arrival_definitions.gd")
var observed_freighters:={}
var observed_hostiles:={}

func world_spec() -> Dictionary:
	return {"name":"Nesla","system":17,"ids":[85,86,87,88,89],"types":[13,9,8,7,16],"models":[10,8,3,2,5],"fields":[1,1,2,26,21,79,85,8],"arrays":[[14,0,0],[85,86,87,88,89],[2,4,9,26,29],[0,1,2]],"freighters":[0,2],"hostiles":[3,8],"gates":[[30,85],[45,85],[85,30],[85,45],[85,20]],"closed":[109,130]}

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Supply original content, bindings and visuals")
	print("%s destination worlds: %d checks; %d failures"%[world_spec().name,checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var spec:=world_spec()
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not lib.select_language("gb"):check(false,lib.error+bindings.error+cat.error);return
	var system: Dictionary=cat.tables.systems[spec.system]
	check(system.name==spec.name and Array(system.fields)==spec.fields and system.arrays.map(func(row):return Array(row))==spec.arrays,"Destination differs from both original Mac catalogue records")
	for index in spec.ids.size():check(Array(cat.tables.stations[spec.ids[index]].fields)==[spec.ids[index],spec.system,spec.models[index],spec.types[index]],"A station differs from the original catalogue")
	if not Worlds.Thynome.coherent(bindings.mido_travel):
		for id in spec.ids:check(Worlds.location(bindings.mido_travel,id).is_empty(),"Incomplete ordinary dependencies admitted a destination")
		return
	var cache:=Cache.new();check(cache.configure(bindings),cache.error)
	var pending_target:=int(FreeFlight.Campaign.mission(bindings.mido_travel,38).get("station_id",-1))
	for id in spec.ids:
		var world:=Worlds.catalogue_location(bindings,cat,id)
		check(not world.is_empty(),"Native world is absent at station%d"%id)
		if world.is_empty():return
		check(world.system_id==spec.system and world.faction==spec.fields[2] and world.security==spec.fields[0] and world.gate_station_id==spec.fields[6] and world.sky_index==spec.fields[7],"Destination borrowed another system's native environment")
		if id==pending_target:
			check(FreeFlight.flight(bindings,id,38).is_empty() and FreeFlight.docking(bindings,id,38).is_empty(),"Ordinary world support bypassed the pending authored arrival")
		else:
			check(FreeFlight.flight(bindings,id,38).get("system_id")==spec.system and FreeFlight.docking(bindings,id,38).get("system_id")==spec.system,"Retained cursor38 lost ordinary entry or docking")
		if not select(cache,bindings,cat,lib,id):return
		var view:=station_view(bindings,cat,id)
		check(not view.is_empty() and view.hangar_row==spec.fields[2] and bindings.resolve_hangar(id,cat).get("row")==spec.fields[2],"Destination lost its source hangar")
		check(StationView.view_parameters(view),"Source hangar view did not validate")
		var exterior: RefCounted=load("res://src/content/station_exterior_resources.gd").new()
		if not exterior.configure_ordinary_location(lib,bindings,cat,id):check(false,exterior.error);return
		var shapes: Dictionary=exterior.snapshot()
		check(shapes.station_id==id and shapes.system_id==spec.system and shapes.faction==spec.fields[2] and shapes.layers.size()==3,"Exterior lost a source layer or identity")
		for shape in shapes.collision.get("shapes",shapes.collision.boxes):
			var extent:=Vector3.ONE*float(shapes.bounds_half_extent)
			var volumes=load("res://src/content/station_collision_volumes.gd")
			var inside: bool=volumes.contains_point(shape.center,shapes.pose.origin,extent)
			check((exterior.point_volume(shape.center)>=0)==inside,"Station%d changed the source strict coarse bounds"%id)
			# Some source boxes extend beyond the coarse station box. Their center
			# must be rejected, but their overlapping interior still collides.
			var clipped: Vector3=shape.center.clamp(-extent+Vector3.ONE,extent-Vector3.ONE)
			var overlaps: bool=volumes.contains_sphere(clipped,shape.center,float(shape.radius)) if shape.get("kind",1)==0 else volumes.contains_point(clipped,shape.center,shape.half_extents)
			if overlaps:check(exterior.point_volume(clipped)>=0,"Station%d lost an authored volume inside its coarse bounds"%id)
		var planets:=PlanetLayout.new();var layout:=planets.for_lounge(bindings,cat,id,38)
		check(not layout.is_empty() and layout.system_id==spec.system and layout.entries.size()==spec.ids.size()+1,"Destination lost its member planets or star")
		if layout.is_empty():return
		for planet in layout.entries:check(lib.manifest.files.has(planet.texture_path),"Destination references an absent original planet texture")
		var scenery:=Scenery.new();check(scenery.configure(bindings),scenery.error)
		var field:=scenery.for_departure(id,{"companions_empty":true,"location_match":false,"special_placement":false},38)
		check(not field.is_empty() and field.station_id==id and field.count>0,"Destination omitted its ordinary asteroid field")
		var kept: Dictionary=cache.snapshot();var arrival:=ArrivalEnvironment.new()
		if not arrival.configure(bindings,cat,id,cache,38):check(false,arrival.error);return
		check(arrival.snapshot().system_id==spec.system and cache.snapshot()==kept,"Arrival changed the retained source cache")
		if id==spec.fields[6]:check(arrival.snapshot().source=="gate","Incoming gate ignored its source placement")
		var context:=CONTEXT.duplicate();context.station_id=id;context.system_id=spec.system
		for seed in [1,2,6,15,22,30]:
			verify_world_population(bindings,cat,context,seed)
			context.special_arrival=true;context.player_position=arrival.snapshot().position
			verify_world_population(bindings,cat,context,seed)
			context.special_arrival=false;context.erase("player_position")
		var location: Dictionary=cache.location(id)
		check(not location.stock.is_empty() and not location.population.is_empty(),"Destination omitted station stock or contacts")
		check(select(cache,bindings,cat,lib,id) and cache.location(id)==location,"Revisiting regenerated retained stock or contacts")
		if failures:return
	for faction in spec.freighters:check(observed_freighters.has(faction),"Population missed source freighter faction%d"%faction)
	for faction in spec.hostiles:check(observed_hostiles.has(faction),"Population missed source hostile faction%d"%faction)
	for pair in spec.gates:
		var request:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"from_station_id":pair[0],"destination_station_id":pair[1]}
		check(not GateRules.packet(bindings,cat,request,38).is_empty(),"A verified neighbor lost its source gate connection")
	for destination in spec.closed:
		check(GateRules.packet(bindings,cat,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"from_station_id":spec.fields[6],"destination_station_id":destination},38).is_empty(),"World admission opened an incomplete expansion world")
	verify_extra(bindings,cat)

func verify_world_population(bindings: RefCounted,cat: RefCounted,context: Dictionary,seed: int) -> void:
	var spec:=world_spec()
	var owner:=Factory.new()
	if not owner.configure_free_factory(bindings,cat,0,[81,86],context,seed):check(false,owner.error);return
	var packet:=owner.generate({"state":12345})
	if packet.is_empty():check(false,owner.error);return
	check(packet.free_context==context and packet.population.system_faction==spec.fields[2] and packet.population.security==spec.fields[0],"Population changed its native context")
	check(not Traffic.population(bindings,packet,context.rank,context.difficulty).is_empty(),"Traffic lacks native combat support")
	var life: Dictionary=Life.population(bindings,packet)
	check(not life.is_empty() and life.lifecycle.reactions.primary_faction==spec.fields[2] and life.lifecycle.reactions.eligible_factions==[spec.fields[2],spec.hostiles[0]],"Destination lost its source faction reactions")
	for row in packet.actors:
		if row.population_group=="freighter":
			observed_freighters[row.actor_kind]=true
			check(row.actor_kind in spec.freighters and row.hull_catalogue_id==Traffic.Population.freighter_hull(bindings,row.actor_kind),"Destination substituted a foreign freighter")
		if row.population_group=="hostile":observed_hostiles[row.actor_kind]=true
		var actor:=Actor.new()
		if not actor.configure_ambient(bindings,cat,owner,row.actor_id,context.rank,context.difficulty) or not actor.enable_local_combat() or not actor.refresh_hostility():check(false,actor.error);return
		check(actor.snapshot().vitals.hull>0,"Destination created a dead ordinary actor")
		verify_actor_extra(bindings,row,actor.snapshot())
	check(owner.snapshot()==packet,"Native actors changed the retained factory packet")

func verify_actor_extra(_bindings: RefCounted,_row: Dictionary,_actor: Dictionary) -> void:pass
func verify_extra(_bindings: RefCounted,_cat: RefCounted) -> void:pass
