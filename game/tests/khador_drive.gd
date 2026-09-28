extends SceneTree
## Browsing starts from an earned career. Route/refusal branches use detached
## observations and must leave the restored station and its availability intact.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Galaxy=preload("res://src/simulation/galaxy_map.gd")
const Drive=preload("res://src/simulation/khador_drive.gd")
const Context=preload("res://src/simulation/mission_context.gd")
const Routing=preload("res://src/simulation/system_navigation.gd")
const Fitting=preload("res://src/simulation/equipment_fitting.gd")
const GalaxyPanel=preload("res://src/presentation/galaxy_map_panel.gd")
var checks:=0
var failures:=0
var opened:=[]
var closed:=0

func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<3:check(false,"Expected content, bindings and visuals");finish();return
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not lib.select_language("gb") or not cat.open(lib) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+visuals.error);finish();return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		if OS.get_environment(key).is_empty():continue
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array:check(false,"Missing retained campaign source");finish();return
		var accepted: bool=bindings.attach_dekato_source(supplement[1],lib.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(supplement[1],lib.manifest)
		if not accepted:check(false,bindings.error);finish();return
	var save:=Save.new();var archive:=Archive.new()
	var document:=save.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,lib)
	if document.is_empty():check(false,save.error);finish();return
	var station: RefCounted=archive.restore(bindings,cat,lib,document)
	if station==null:check(false,archive.error);finish();return
	var initial: Dictionary=station.snapshot();var loadout: Dictionary=initial.loadout.duplicate(true)
	# Detached quote/clock fixture; never installed or saved as an earned item.
	loadout.equipment_ids.append(85)
	var routing:=Routing.new();var drive:=Drive.new()
	var available: Array=initial.contracts.lounges.system_availability
	if not routing.configure(bindings,cat,available) or not drive.configure(bindings,cat,loadout,0.5,routing,Context.drive_destinations(bindings,cat,station.contract_owner())):check(false,routing.error+drive.error);finish();return
	var initial_drive:=drive.snapshot()
	check(drive.quote(36,0).gate_alternative and not drive.quote(36,0).affordable,"Adjacent empty-fuel trip omitted ordinary gate fallback")
	check(drive.quote(36,1).affordable and drive.quote(36,1).cost==1,"One paid cell cannot reach the adjacent system")
	var route: Array=routing.route(loadout.system_id,cat.tables.stations[95].system_id)
	check(route.size()>2 and drive.quote(95,100).cost==route.size()-1,"Drive discarded the available multi-hop distance")
	check(drive.quote(int(loadout.station_id),100).is_empty(),"Drive accepted the current planet")
	check(not drive.quote(-1,1).affordable and drive.quote(-1,2).cost==1 and drive.quote(-1,2).required==2,"Void fuel did not reserve the return cell")
	check(drive.snapshot()==initial_drive and station.snapshot()==initial,"Quoting a trip changed the source flight or earned station")
	var cargo=load("res://src/simulation/flight_cargo.gd").new()
	if not cargo.configure_equipment(bindings,cat,station.equipment_owner()):check(false,cargo.error);finish();return
	var hold: Dictionary=cargo.snapshot();var refused: Dictionary=drive.evaluate_request(36,cargo)
	check(not refused.is_empty() and not refused.started and refused.drive.snapshot()==initial_drive and refused.cargo.snapshot()==hold and cargo.snapshot()==hold,"Unaffordable activation debited cargo or changed its parent")
	var hard:=Drive.new()
	check(hard.configure(bindings,cat,loadout,1.5,routing,[36,95]) and hard.quote(36,2).cost==2 and hard.quote(-1,3).required==4,"Extreme difficulty lost doubled fuel or the Void reserve")
	var isolated: Array=available.duplicate();isolated.fill(false);isolated[loadout.system_id]=true;isolated[cat.tables.stations[95].system_id]=true
	var disconnected:=Routing.new();var distant:=Drive.new()
	check(disconnected.configure(bindings,cat,isolated) and distant.configure(bindings,cat,loadout,0.5,disconnected,[95]) and distant.quote(95,4).cost==4,"Disconnected known destination did not use four cells")
	var local_loadout:=loadout.duplicate(true);local_loadout.station_id=95;local_loadout.system_id=19
	var local:=Drive.new()
	check(local.configure(bindings,cat,local_loadout,0.5,routing,[95,98]) and local.quote(98,0).mode=="local" and local.quote(98,0).cost==0,"Current-system choice became a drive jump")
	check(Drive.permits_mission({}) and Drive.permits_mission({"kind":156,"completed":true}),"Completed flight cannot use the drive")
	check(Drive.permits_mission({"kind":11,"completed":false}) and not Drive.permits_mission({"kind":156,"completed":false}),"Drive ignored an unfinished combat mission")
	var fitting:=Fitting.new();var hulls:=0
	for ship in cat.tables.ships:
		if not Context.base_player_hull(bindings,int(ship.id)):continue
		hulls+=1
		check(fitting._item_reason(bindings,cat,null,85,[85],int(ship.id)).is_empty(),"Base hull refused the Khador device: "+str(ship.id))
	check(hulls==34,"The base hull capability omitted the earned reward ship")
	verify_emergency_cargo(bindings,cat,lib)
	finish()

func verify_emergency_cargo(bindings: RefCounted,cat: RefCounted,lib: RefCounted) -> void:
	# Detached population fixture, never awarded to the restored career.
	var factory=load("res://src/simulation/opening_npc_construction.gd").new()
	var context: Dictionary=load("res://tests/ordinary_worlds.gd").CONTEXT.duplicate(true)
	if not factory.configure_free_factory(bindings,cat,0,[81,85],context,1):check(false,factory.error);return
	var save:=Save.new();var archive:=Archive.new()
	var document:=save.load_document(OS.get_environment("GOF2_FUEL_SAVE"),bindings,cat,lib)
	if document.is_empty():check(false,save.error);return
	var supplier: RefCounted=archive.restore(bindings,cat,lib,document)
	if supplier==null:check(false,archive.error);return
	var owned: Dictionary=supplier.snapshot()
	check(factory.retain_player_cargo(supplier.equipment_owner()),factory.error)
	for seed in 40:
		var a=load("res://src/simulation/seeded_random.gd").new();var b=a.get_script().new()
		a.restore({"state":seed+1});b.restore({"state":seed+1})
		check(factory._sample_cargo(a)==factory._sample_cargo(b,1),"Generated world ignored the earned player's existing cells")
	check(supplier.snapshot()==owned,"Generating NPC fuel changed the supplier save")
	var rescued:=0;var unchanged:=0;var empty:=0
	for seed in 300:
		var normal=load("res://src/simulation/seeded_random.gd").new();var emergency=normal.get_script().new();var stocked=normal.get_script().new()
		for random in [normal,emergency,stocked]:random.restore({"state":seed+1})
		var ordinary: Array=factory._sample_cargo(normal,1);var fuel: Array=factory._sample_cargo(emergency,0)
		check(factory._sample_cargo(stocked,16)==ordinary,"Carrying more fuel changed ordinary NPC cargo")
		if fuel.is_empty():empty+=1;check(ordinary.is_empty(),"Fuel assistance invented a cargo hold");continue
		if fuel==ordinary:unchanged+=1;continue
		rescued+=1
		check(fuel.size()==ordinary.size() and fuel[0].item_id==122 and fuel[0].quantity==ordinary[0].quantity and fuel.slice(1)==ordinary.slice(1),"Emergency fuel changed unrelated cargo or its stack quantity")
	check(rescued>0 and unchanged>0 and empty>0,"Empty-fuel cargo did not cover rescue, ordinary and empty holds")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func finish() -> void:
	print("Khador Drive: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
