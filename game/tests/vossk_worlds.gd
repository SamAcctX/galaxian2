extends "res://tests/ordinary_worlds.gd"
## Original Vossk catalogue/scenery and detached factory inputs. These checks
## neither earn a journey nor unlock the pending contest at station27.
const HitGeometry=preload("res://src/simulation/ordinary_hit_geometry.gd")
var observed_world_factions:={}

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected explicit content, bindings and visuals")
	print("Vossk destination worlds: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not cat.open(lib) or not lib.select_language("gb"):check(false,lib.error+bindings.error+cat.error);return
	var available: bool=Worlds.vossk_available(bindings.mido_travel)
	for system_id in [3,5]:
		var expected: Dictionary=Worlds.SYSTEMS[system_id]
		var cache:=Cache.new();check(cache.configure(bindings),cache.error)
		for station in expected.station_ids:
			var world:=Worlds.catalogue_location(bindings,cat,station)
			if not available:
				check(world.is_empty() and FreeFlight.flight(bindings,station,18).is_empty(),"Incomplete Vossk resources opened a world")
				continue
			check(not world.is_empty() and world.system_id==system_id and world.faction==1 and world.security==(2 if system_id==3 else 1),"Vossk world differs from its exact source catalogue")
			if world.is_empty():return
			if not select(cache,bindings,cat,lib,station):
				printerr("Vossk world preflight stopped at station ",station)
				return
			var view:=station_view(bindings,cat,station)
			check(not view.is_empty() and view.hangar_row==1 and StationView.view_parameters(view),"Vossk station lacks its source hangar camera")
			if view.is_empty():return
			check(view.camera.position==[1787,1086,-1632] and view.camera.angles==[-0.30000001192092896,-3.75,-0.029999999329447746] and view.light.ambient==[0.25,0.550000011920929,0.25],"Vossk hangar borrowed another source camera or light")
			var hangar: Dictionary=bindings.resolve_hangar(station,cat)
			check(not hangar.is_empty() and hangar.row==1,"Imported hangar disagrees with its Vossk camera")
			var dock:=FreeFlight.docking(bindings,station,18)
			check(not dock.is_empty() and dock.system_id==system_id and FreeFlight.docking_parameters(dock),"Vossk docking lost its world context")
			var exterior: RefCounted=load("res://src/content/station_exterior_resources.gd").new()
			if not exterior.configure_ordinary_location(lib,bindings,cat,station):check(false,exterior.error);return
			var shapes: Dictionary=exterior.snapshot()
			check(shapes.station_id==station and shapes.system_id==system_id and shapes.faction==1 and shapes.layers.size()==3,"Vossk exterior lost original layers or faction")
			check(shapes.layers.map(func(layer):return layer.resource_id)==[16436,16439,16442] and shapes.collision.station_id==1000 and shapes.collision.source_offset>=0,"Vossk station lost its original shared assembly or collision record")
			for shape in shapes.collision.get("shapes",shapes.collision.boxes):check(exterior.point_volume(shape.center)>=0,"Vossk station missed an authored collision volume")
			var planets:=PlanetLayout.new();var planet_state:=planets.for_lounge(bindings,cat,station,18)
			if planet_state.is_empty():check(false,planets.error);return
			check(planet_state.system_id==system_id and planet_state.entries.size()==6,"Vossk planet membership changed")
			for planet in planet_state.entries:check(lib.manifest.files.has(planet.texture_path),"Missing original Vossk planet texture")
			var conditions:={"companions_empty":true,"location_match":false,"special_placement":false}
			var scenery:=Scenery.new();check(scenery.configure(bindings),scenery.error)
			var field:=scenery.for_departure(station,conditions,18)
			check(not field.is_empty() and field.station_id==station and field.count>0,"Vossk world lost its ordinary asteroid field")
			var retained:=cache.snapshot();var arrival:=ArrivalEnvironment.new()
			if not arrival.configure(bindings,cat,station,cache):check(false,arrival.error);return
			check(arrival.snapshot().system_id==system_id and cache.snapshot()==retained,"Vossk arrival changed its world or retained cache")
			if station==world.gate_station_id:check(arrival.snapshot().source=="gate","Vossk gate arrival used a cached planet")
			var context:=CONTEXT.duplicate();context.system_id=system_id;context.station_id=station
			for seed in [2,22,30]:
				verify_vossk_factory(bindings,cat,context,seed)
				context.special_arrival=true;context.player_position=arrival.snapshot().position
				verify_vossk_factory(bindings,cat,context,seed)
				context.special_arrival=false;context.erase("player_position")
			var location:=cache.location(station)
			check(not location.stock.is_empty() and not location.population.is_empty(),"Vossk location omitted stock or contacts")
			if station in [18,26]:
				var authored: Dictionary=location.population.contacts[0]
				check(authored.role==4 and authored.source_contact_id==(12 if station==18 else 13) and not authored.generated and authored.offer.is_empty(),"Vossk cache lost its original persistent service contact")
				check(authored.service=={"parameter":0 if station==18 else 1,"price":25000 if station==18 else 10000} and not location.offers.has(0),"Vossk service acquired invented terms or a contract")
				var prior:=cache.snapshot()
				check(not cache.consume(station,0) and cache.snapshot()==prior,"Unsupported service consumed a contract or mutated the cache")
			check(select(cache,bindings,cat,lib,station) and cache.location(station)==location,"Vossk revisit regenerated retained stock or contacts")
			if failures:return
	if available:
		for faction in [0,1,8]:check(observed_world_factions.has(faction),"Vossk factories omitted faction "+str(faction))

func verify_vossk_factory(bindings: RefCounted,cat: RefCounted,context: Dictionary,seed: int) -> void:
	var owner:=Factory.new()
	if not owner.configure_free_factory(bindings,cat,0,[81,86],context,seed):check(false,owner.error);return
	var packet: Dictionary=owner.generate({"state":98765})
	if packet.is_empty():check(false,owner.error);return
	check(packet.population.system_faction==1 and packet.actors.size()==packet.population.actor_count,"Vossk factory lost source faction or actor counts")
	check(not Traffic.population(bindings,packet,context.rank,context.difficulty).is_empty(),"Vossk factory does not satisfy ordinary flight")
	var lifecycle: Dictionary=Life.population(bindings,packet)
	check(not lifecycle.is_empty() and lifecycle.lifecycle.reactions.primary_faction==1 and lifecycle.lifecycle.reactions.eligible_factions==[1,0],"Vossk reactions use another world's faction")
	for row in packet.actors:
		observed_world_factions[row.actor_kind]=true
		if row.population_group!="freighter":continue
		check(row.actor_kind==1 and row.hull_catalogue_id==13,"Vossk factory substituted another faction's freighter")
		var actor:=Actor.new()
		if not actor.configure_ambient(bindings,cat,owner,row.actor_id,context.rank,context.difficulty):check(false,actor.error);return
		var shape: Dictionary=actor.collision_context()
		check(shape.path=="point_geometry" and shape.boxes.size()==5,"Vossk freighter lost its five source collision boxes")
		var geometry:=HitGeometry.new()
		for basis in [Basis.IDENTITY,Basis(Vector3.UP,PI/2)]:
			var pose:=Transform3D(basis,Vector3(100,200,300))
			check(actor.set_pose(pose,pose),actor.error)
			shape=actor.collision_context()
			var edge:=Vector3(1965,351,5827)
			# The original boxes translate in world axes, independently of body rotation.
			var face:=geometry.box_geometry(pose.origin+edge,pose.origin,shape.boxes)
			var outside:=geometry.box_geometry(pose.origin+edge+Vector3(0.5,0,0),pose.origin,shape.boxes)
			var inside:=geometry.box_geometry(pose.origin+edge-Vector3(0.5,0,0),pose.origin,shape.boxes)
			check(not face.is_empty() and not outside.is_empty() and not inside.is_empty(),geometry.error)
			if face.is_empty() or outside.is_empty() or inside.is_empty():return
			check(not face.hit and not outside.hit and inside.hit and inside.box_index==0,"Vossk box lost its strict world-axis boundary under rotation")
	check(owner.snapshot()==packet,"Detached Vossk actors changed the factory packet")
