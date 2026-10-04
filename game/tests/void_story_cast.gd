extends SceneTree
## 154 in the alien world: a story flight whose station is -1 is built by the
## drive's Void flight. From an edited earned save at 154 the Void carries the
## recipe cast, its lines, the countdown and its failure.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Context=preload("res://src/simulation/mission_context.gd")
var checks:=0
var _bodies: RefCounted
var _effects: RefCounted
var failures:=0

func _initialize() -> void:call_deferred("verify")
func verify() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()<3:check(false,"Expected content, bindings and visuals");finish();return
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not lib.select_language("gb") or not cat.open(lib):check(false,lib.error+bindings.error+cat.error);finish();return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		if OS.get_environment(key).is_empty():continue
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array:check(false,"Missing retained campaign source");finish();return
		var accepted: bool=bindings.attach_dekato_source(supplement[1],lib.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(supplement[1],lib.manifest)
		if not accepted:check(false,bindings.error);finish();return
	# A save written with a newer extraction needs it attached first, as the game does on launch.
	var update:=OS.get_environment("GOF2_IMPORT_UPDATE")
	if not update.is_empty() and not bindings.attach_import_update(update,lib.manifest,lib):check(false,"Import update: "+bindings.error);finish();return
	var save:=Save.new();var archive:=Archive.new()
	var document:=save.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,lib)
	if document.is_empty():check(false,save.error);finish();return
	var station: RefCounted=_at_cursor(bindings,cat,lib,document,154)
	if station==null:finish();return
	var frame: RefCounted=_enter_void(bindings,cat,lib,station)
	if frame==null:finish();return
	var actors: Array=frame._encounter.combat_snapshot().actors
	print("VOID 154 actors ",actors.map(func(row):return [row.get("actor_kind"),row.get("hull_catalogue_id"),row.get("population_group"),row.get("friendly",false)]))
	check(actors.size()==22 and actors[1].get("static_object",false) and range(2,22).all(func(id):return int(actors[id].actor_kind)==9),"The Void at 154 did not carry the freighter, Valkyrie and twenty Void fighters")
	check(range(2,22).all(func(id):return not actors[id].get("active",false)),"The Void fighters were awake before Alice's order")
	# The lines play, the fighters attack and Keith's 91 s countdown starts.
	var heard:=[]
	frame=_fly(frame,heard,func(next):return int(next._countdown_end)>=0,1800)
	if frame==null:finish();return
	actors=frame._encounter.combat_snapshot().actors
	print("VOID 154 before the countdown ",heard)
	check([3028,3034,3035,3036].all(func(id):return id in heard),"The ambush lines did not play before the countdown")
	check(range(2,22).filter(func(id):return actors[id].get("active",false)).size()>=10,"Alice's order did not wake the Void fighters")
	check(frame.snapshot().get("mission_readout",{}).get("kind","")=="countdown","The countdown is not on the HUD")
	# Failure: the countdown runs out with the ship never docked.
	var lost: RefCounted=_fly(frame,[],func(next):return next._objective.result_pending() or not next._objective.snapshot().contract_result.is_empty(),1200)
	if lost!=null:
		var result: Dictionary=lost._objective.snapshot()
		print("VOID 154 failure ",result.contract_result," cursor ",result.campaign_cursor)
		check(result.campaign_cursor==154 and not result.contract_result.is_empty(),"The countdown ran out without the failure result")
	# Success: docked at Valkyrie and the hack won (the hack itself is the
	# shared puzzle; the application playtest solves it).
	var won: RefCounted=_fly(frame,heard,func(next):return int(next._story_dock.get("docked",-1))==1 or next._story_dock.actors.get(1,{}).get("dockable",false),600)
	if won==null:finish();return
	won._story_dock.actors[1].dockable=false;won._story_dock.hacks=1;won._story_dock.last_hacked=1
	var aboard: RefCounted=won
	won=_fly(won,heard,func(next):return next._objective.snapshot().campaign_cursor!=154,1800)
	if won==null:print("VOID 154 heard ",heard," result ",aboard._objective.snapshot().contract_result);finish();return
	print("VOID 154 success ",heard," cursor ",won._objective.snapshot().campaign_cursor," jump ",won._story_jump)
	check(3039 in heard and 3055 in heard and won._objective.snapshot().campaign_cursor==155,"Winning the hack did not play the arrest and move the story to 155")
	won=_fly(won,[],func(next):return not next.prepare_drive_arrival().is_empty(),600)
	if won==null:finish();return
	# Out through the drive: back at the planet the pilot left, the story at 155.
	var home: RefCounted=won.construct_drive_arrival(bindings,cat,4096,1789103569,true,_bodies,_effects,{},lib)
	if home==null:check(false,"Leaving the Void after 154 failed: "+won.error);finish();return
	print("VOID 154 out at ",home.snapshot().location.station_id," cursor ",home.snapshot().campaign_cursor)
	check(home.snapshot().location.station_id==station.snapshot().loadout.station_id and home.snapshot().campaign_cursor==155,"The way out of the Void did not return to the source planet at 155")
	finish()

## Step the flight (the test pilot cannot be hurt) until `done`, keeping the lines heard.
func _fly(frame: RefCounted,heard: Array,done: Callable,ticks: int) -> RefCounted:
	for tick in ticks:
		if done.call(frame):return frame
		frame._player.set_permissions(bool(frame._player.snapshot().active),false)
		var radio: Dictionary=frame._radio.snapshot() if frame._radio!=null else {}
		if radio.get("visible",false) and int(radio.get("text_id",-1)) not in heard:heard.append(int(radio.text_id))
		var next: RefCounted=frame.evaluate(100)
		if next==null:check(false,"Flight step failed: "+frame.error);return null
		frame=next
	if done.call(frame):return frame
	check(false,"The flight did not reach its state in %d steps"%ticks)
	return null

## An edited copy of the earned save moved on to `cursor` (test fixture only).
func _at_cursor(bindings: RefCounted,cat: RefCounted,lib: RefCounted,source: Dictionary,cursor: int) -> RefCounted:
	var document: Dictionary=source.duplicate(true)
	var mission: Dictionary=load("res://src/content/free_campaign_definitions.gd").mission(bindings,cursor)
	var progress: Dictionary=document.career.progress
	var ranked: Dictionary=load("res://src/simulation/opening_handoff.gd").calculate_progress(bindings.opening_handoff,cursor,progress.player_kills,progress.pirate_kills,progress.other_score)
	for owner in [document.station.progress,document.career.progress]:owner.merge(ranked,true)
	for owner in [document.station,document.station.player_cache,document.career]:owner.campaign_cursor=cursor
	for owner in [document.station,document.career]:
		if owner.has("rank"):owner.rank=ranked.rank
	document.station.mission=mission.duplicate(true)
	# The Khador Drive in the last equipment slot (the drive takes the pilot into the Void).
	for loadout in [document.inventory.loadout,document.station.loadout]:
		var slots: Array=loadout.slots
		slots[slots.size()-1].item_id=85
		loadout.equipment_ids=slots.filter(func(slot):return slot!=null).map(func(slot):return int(slot.item_id))
	var installed: Array=document.inventory.prices.installed
	for index in installed.size():
		if installed[index] is Dictionary and index==installed.size()-1:installed[index].item_id=85
	var station: RefCounted=Archive.new().restore(bindings,cat,lib,document)
	if station==null:
		var archive:=Archive.new();archive.restore(bindings,cat,lib,document);check(false,"The edited save did not restore: "+archive.error)
	return station

## Into the Void with the drive the way the live frame does it (khador_void.gd).
func _enter_void(bindings: RefCounted,cat: RefCounted,lib: RefCounted,station: RefCounted) -> RefCounted:
	var original: Dictionary=station.snapshot()
	var bodies=load("res://src/content/scenery_body_resources.gd").new()
	var effects=load("res://src/content/scenery_effect_resources.gd").new()
	if not bodies.configure(lib,bindings) or not effects.configure(lib,bindings):check(false,bodies.error+effects.error);return null
	_bodies=bodies;_effects=effects
	var construction=load("res://src/simulation/first_flight_construction.gd").new()
	if not construction.prepare_free(bindings,cat,station,4096,1789103569,true,bodies,effects):check(false,construction.error);return null
	var player: RefCounted=construction.player_owner();var equipment: RefCounted=station.equipment_owner().fork()
	var route:=Context.new();var career: RefCounted=station.contract_owner().fork()
	var from: Dictionary=equipment.snapshot().loadout
	if not route.admit_drive_void(bindings,cat,from,career):check(false,route.error);return null
	check(route.has_contract_actors() and route.recipe().cursor==154,"The 154 Void visit was not admitted with its story cast")
	if not equipment.relocate_ordinary_void(bindings,route,true):check(false,equipment.error);return null
	var cache: Dictionary=load("res://src/simulation/flight_player_cache.gd").capture_ordinary_void(bindings,route,from,equipment.snapshot().loadout,player.snapshot(),true)
	if cache.is_empty():check(false,"Void admission lost actual surviving pools");return null
	if not career.transfer_ordinary_void(bindings,original.contracts.progress,route,true):check(false,career.error);return null
	var visit=construction.get_script().new()
	if not visit.prepare_ordinary_void_selected(bindings,cat,equipment,route,cache,original.contracts.progress,construction.snapshot().departure.station_response_flags,original.contracts.difficulty,4096,1789103569,true,bodies,effects,career):check(false,visit.error);return null
	var frame=load("res://src/simulation/first_flight_frame.gd").new()
	if not frame.configure(bindings,cat,lib,visit,"F",0.5):check(false,frame.error);return null
	return frame

func _print_cursors(value: Variant,path: String) -> void:
	if value is Dictionary:
		for key in value:
			if str(key) in ["campaign_cursor","mission","station_id"]:print(path+"/"+str(key)," = ",value[key])
			_print_cursors(value[key],path+"/"+str(key))
	elif value is Array:
		for index in mini(value.size(),3):_print_cursors(value[index],path+"[%d]"%index)

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func finish() -> void:
	print("Void story cast: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
