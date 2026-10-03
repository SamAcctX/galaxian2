extends "res://tests/gate_environment.gd"
## Valkyrie/Supernova guns and turrets sold in stations can be fitted and fire
## through the shared primary pipeline. Diagnostics grant no career progress.
const Fitting=preload("res://src/simulation/equipment_fitting.gd")
const Loadout=preload("res://src/simulation/opening_loadout.gd")
const Primary=preload("res://src/simulation/primary_weapons.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
const Visuals=preload("res://src/simulation/projectile_visual_state.gd")
const Impacts=preload("res://src/simulation/ordinary_impact_state.gd")
const Textures=preload("res://src/content/visual_library.gd")
const Trail=preload("res://src/presentation/projectile_trail_geometry.gd")
## Spread guns (type 25 = type 2), lasers, beam, thermal, auto turrets.
const GUNS:={176:"spread",177:"spread",178:"spread",183:"bolt",229:"bolt",228:"beam",193:"thermal",180:"turret",181:"turret",182:"turret"}
## Still refused: the Matador's four-part twin-barrel turret.
const REFUSED:=[224]

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected content, bindings and visuals")
	print("DLC primary weapons: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var mounts:=Mounts.new();var textures:=Textures.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library) or not mounts.open(library,cat) or not textures.open(args[2],library.manifest):check(false,library.error+bindings.error+cat.error+mounts.error+textures.error);return
	var fitting:=Fitting.new();var assets:=fitting.prepare_assets(bindings,cat,library)
	check(not assets.is_empty(),fitting.error)
	if assets.is_empty():return
	for id in GUNS:verify_gun(id,GUNS[id],bindings,cat,mounts,library,fitting,assets)
	for id in REFUSED:
		var seed:=loadout(bindings,cat,id)
		var report: Dictionary=fitting.inspect(bindings,cat,seed,assets)
		check(report.is_empty() or not report.support[id].is_empty(),"Unbuilt item %d was offered for fitting"%id)
	var trail:=Trail.new();root.add_child(trail)
	check(trail.build(28,library,textures,bindings),"SunFire ribbon: "+trail.error)
	trail.free()

## A ship with a free slot of the item's category, docked at the Valkyrie station.
func loadout(bindings: RefCounted,cat: RefCounted,id: int) -> Dictionary:
	var category: int=cat.tables.items[id].arrays[2][3]
	var ship:=int(bindings.station_departure.ship_id)
	if int(cat.tables.ships[ship].stats[Loadout.SLOT_PROPERTIES[category]])==0:
		for row in cat.tables.ships.size():
			if int(cat.tables.ships[row].stats[Loadout.SLOT_PROPERTIES[category]])>0:ship=row;break
	var seed:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":ship,"station_id":105,
		"system_id":int(cat.tables.stations[105].system_id),"campaign_cursor":135,"equipment_ids":[id],"slots":[]}
	var offset:=0;var extent:=0
	for i in Loadout.SLOT_PROPERTIES.size():
		var count:=int(cat.tables.ships[ship].stats[Loadout.SLOT_PROPERTIES[i]])
		if i<category:offset+=count
		extent+=count
	seed.slots.resize(extent)
	seed.slots[offset]={"item_id":id,"category":category,"slot":0,"quantity":1}
	return seed

func verify_gun(id: int,family: String,bindings: RefCounted,cat: RefCounted,mounts: RefCounted,library: RefCounted,fitting: RefCounted,assets: Dictionary) -> void:
	var seed:=loadout(bindings,cat,id)
	var report: Dictionary=fitting.inspect(bindings,cat,seed,assets)
	check(not report.is_empty() and report.support[id].is_empty(),"Item %d is not fittable: %s"%[id,fitting.error if report.is_empty() else report.support[id]])
	var primary:=Primary.new()
	if not primary.configure(bindings,cat,mounts,seed):check(false,"Primary %d: %s"%[id,primary.error]);return
	var gun: Dictionary=primary.snapshot().guns[0]
	var weapon: Dictionary=gun.projectiles.weapon
	check(not gun.audio.is_empty(),"Item %d has no firing sound"%id)
	match family:
		"spread":check(weapon.kind==2 and weapon.projectile_capacity==25 and weapon.has("dispersion"),"Item %d lost its scattered spread"%id)
		"beam":check(weapon.launch_mode=="beam" and weapon.beam.model_id==19090 and weapon.beam.muzzle_model_id==14501,"Raccoon lost its endpoint beam")
		"thermal":check(weapon.thermal.trail_id==28 and weapon.projectile_capacity==20,"SunFire lost its guided ribbon")
		"turret":check(weapon.get("manual_turret")==true and primary.turret_automatic(),"Item %d is not an automatic turret"%id)
	var world:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"elapsed_ms":0,"campaign_cursor":135,"primaries":primary.snapshot(),"weapons":{"actors":[]}}
	var visual:=Visuals.new();var impacts:=Impacts.new()
	check(visual.configure(bindings,library,world),"Projectile %d: %s"%[id,visual.error])
	check(impacts.configure(bindings,library,world),"Impact %d: %s"%[id,impacts.error])
	check(not primary.advance(int(weapon.interval_ms)+1).is_empty(),primary.error)
	var turret: bool=family=="turret"
	var fired: Dictionary=primary.fire(Transform3D.IDENTITY,true,{"state":1234},[],not turret,turret)
	check(not fired.is_empty() and fired.weapons[0].result.get("fired",false),"Item %d did not fire: %s"%[id,primary.error if fired.is_empty() else str(fired.weapons[0].result)])
	if not fired.is_empty():check(fired.weapons[0].get("audio_events",[]).size()==1,"Item %d fired silently"%id)
