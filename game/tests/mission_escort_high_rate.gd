extends "res://tests/mission_escort_flight.gd"
## Full native ambush at 144 samples/second with a paid alternate gun.
## Earlier arrival/portal is detached; no earned Host or render-FPS claim.
const PaidLoadout=preload("res://tests/fixtures/mission_paid_loadout.gd")
var purchase:=PaidLoadout.new()
var steps:={}
var phase_times:={}

func verify(args: Array) -> void:
	# The earned fixture predates per-blueprint station/completed fields and the
	# retained base medals. Loading it migrates those, so re-save it once with
	# the current archive; the inherited "unchanged save" check then compares
	# against what the game itself would write for this career.
	var source:=OS.get_environment("GOF2_SOURCE_SAVE")
	var lib=load("res://src/content/library.gd").new();var bind=load("res://src/content/resource_bindings.gd").new();var cat=load("res://src/content/catalogues.gd").new()
	if not lib.open(args[0]) or not lib.select_language("gb") or not bind.open(args[1],lib.manifest) or not cat.open(lib):check(false,lib.error+bind.error+cat.error);return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array or supplement.size()!=3:check(false,"Missing explicit "+key);return
		var accepted: bool=bind.attach_dekato_source(supplement[1],lib.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bind.attach_nehma_source(supplement[1],lib.manifest)
		if not accepted:check(false,bind.error);return
	var file=load("res://src/simulation/station_save_file.gd").new()
	var document: Dictionary=file.load_document(source,bind,cat,lib)
	if document.is_empty():check(false,file.error);return
	var restored: RefCounted=load("res://src/simulation/station_archive.gd").new().restore(bind,cat,lib,document)
	if restored==null:check(false,"The earned fixture save could not be restored");return
	var current:=OS.get_user_data_dir().path_join("escort-high-rate/current.gof2save")
	if not file.save(current,restored,bind,cat,lib):check(false,file.error);return
	OS.set_environment("GOF2_SOURCE_SAVE",current)
	await super.verify(args)
	OS.set_environment("GOF2_SOURCE_SAVE",source)

func component_station(station: RefCounted) -> RefCounted:
	var fitted: RefCounted=purchase.prepare(bindings,catalogues,library,station,check)
	if fitted==null:check(false,purchase.error)
	return fitted

func frame_delta_ms(index: int) -> int:
	# Integer native frames partition the same accumulated 144Hz clock used
	# by the accepted Host. Do not round each 6.944ms sample independently.
	var delta: int=(index+1)*1000/144-index*1000/144
	steps[delta]=true
	return delta

func observe_phase(frame: RefCounted,phase: int) -> void:
	phase_times[phase]=frame.frame_context().elapsed_ms

func finish_component(frame: RefCounted,frames: int) -> void:
	var result: Dictionary=frame.snapshot()
	check(result.elapsed_ms==frames*1000/144 and steps.has(6) and steps.has(7) and steps.size()==2,"Full high-rate fight lost its accumulated clock or native6/7ms partition")
	check(phase_times[3]-phase_times[2]>15000 and phase_times[5]-phase_times[4]>15000,"High-rate fight skipped a separately timed cinematic")
	check(result.career.credits==purchase.receipt.credits_after,"High-rate battle refunded the legal primary purchase")
	var guns: Array=result.encounter.primaries.guns
	check(guns.size()==1 and guns[0].equipment.item_id==purchase.receipt.new_item,"High-rate battle replaced the purchased primary")
	var next: RefCounted=frame
	for page in 5:
		check(next.dialogue().get("text_id")==2047+page,"High-rate battle lost a result41 page")
		var acknowledged: RefCounted=next.navigate("next")
		if acknowledged==null:check(false,next.error);return
		next=acknowledged
	var continued: Dictionary=next.snapshot()
	check(continued.campaign_cursor==42 and not continued.dialogue.visible,"High-rate result did not release the living mission42 continuation")
	check(continued.player==result.player and continued.player_pose==result.player_pose and continued.equipment==result.equipment and continued.encounter.combat==result.encounter.combat,"High-rate acknowledgement rebuilt or repaired the retained flight")
	check(next.initialized_world_owner()==frame.initialized_world_owner() and next.presentation_identity()==frame.presentation_identity(),"High-rate acknowledgement replaced the admitted world or scene identity")
	check(continued.career.credits==result.career.credits and frame.snapshot()==result,"High-rate acknowledgement paid a reward or mutated its result parent")
	check(next.navigate("next")==null and next.snapshot()==continued,"High-rate repeated final Next advanced the campaign twice")
	var living: RefCounted=next.evaluate(7,Vector2.ZERO,1.0,false,false,Vector2i(1280,720),0.0,false,-1,true)
	if living==null:check(false,next.error);return
	check(living.snapshot().campaign_cursor==42 and living.snapshot().player.vitals.hull>0,"High-rate continuation did not survive its first native42 frame")
	print("Full high-rate paid-loadout result: ",frames," frames / ",result.elapsed_ms,"ms; phases ",phase_times,"; item ",purchase.receipt.new_item," credits ",continued.career.credits,"; native living42, not an earned route or successor save")
