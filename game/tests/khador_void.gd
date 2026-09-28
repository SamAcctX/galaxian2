extends "res://tests/khador_drive.gd"
## Prepare the admitted Void composition from a detached earned inventory. The
## application pilot separately owns charge, world transit, docking and saves.
func verify_emergency_cargo(bindings: RefCounted,cat: RefCounted,lib: RefCounted) -> void:
	var save:=Save.new();var archive:=Archive.new()
	var document:=save.load_document(OS.get_environment("GOF2_FUEL_SAVE"),bindings,cat,lib)
	if document.is_empty():check(false,save.error);return
	var station: RefCounted=archive.restore(bindings,cat,lib,document)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot()
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(lib,bindings) or not effects.configure(lib,bindings):check(false,bodies.error+effects.error);return
	var construction=load("res://src/simulation/first_flight_construction.gd").new()
	if not construction.prepare_free(bindings,cat,station,4096,1789103569,true,bodies,effects):check(false,construction.error);return
	var player: RefCounted=construction.player_owner();var equipment: RefCounted=station.equipment_owner().fork()
	var route:=Context.new();var career: RefCounted=station.contract_owner().fork()
	var from: Dictionary=equipment.snapshot().loadout
	if not route.admit_drive_void(bindings,cat,from,career):check(false,route.error);return
	if not equipment.relocate_ordinary_void(bindings,route,true):check(false,equipment.error);return
	var cache: Dictionary=load("res://src/simulation/flight_player_cache.gd").capture_ordinary_void(bindings,route,from,equipment.snapshot().loadout,player.snapshot(),true)
	check(not cache.is_empty(),"Void admission lost actual surviving pools")
	if failures:return
	if not career.transfer_ordinary_void(bindings,original.contracts.progress,route,true):check(false,career.error);return
	var visit=construction.get_script().new()
	if not visit.prepare_ordinary_void_selected(bindings,cat,equipment,route,cache,original.contracts.progress,construction.snapshot().departure.station_response_flags,original.contracts.difficulty,4096,1789103569,true,bodies,effects,career):check(false,visit.error);return
	check(visit.snapshot().campaign_cursor==original.campaign_cursor and visit.snapshot().location.station_id==-1,"Void constructor substituted a campaign or ordinary location")
	var frame=load("res://src/simulation/first_flight_frame.gd").new()
	if not frame.configure(bindings,cat,lib,visit,"F",0.5):check(false,frame.error);return
	for tick in 45:
		var next: RefCounted=frame.evaluate(100)
		if next==null:check(false,frame.error);return
		frame=next
	check(frame.drive_available() and frame.drive_quote(-1).cost==1 and frame.drive_quote(-1).station_id==original.loadout.station_id,"Live Void drive lost its direct return")
	check(station.snapshot()==original,"Preparing the Void composition mutated its earned parent")
