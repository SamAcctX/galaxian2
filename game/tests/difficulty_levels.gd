extends SceneTree
## The four New Game difficulty levels are accepted by every career owner:
## an Easy or Hard career survives a station save round trip, an opening
## station carries a non-Normal choice into contracts, and Easy works for
## station stock, the Loma toll, Khador fuel and the cloak.
## Args: content, bindings. GOF2_SOURCE_SAVE: an earned career save.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Difficulty=preload("res://src/content/difficulty_definitions.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const Save=preload("res://src/simulation/station_save_file.gd")
const Station=preload("res://src/simulation/station_entry.gd")
const Stock=preload("res://src/simulation/station_stock.gd")
const Toll=preload("res://src/content/loma_toll_definitions.gd")
const Khador=preload("res://src/content/khador_drive_definitions.gd")
const Cloak=preload("res://src/content/cloak_definitions.gd")
const SETTINGS={"difficulty":0.0,"valkyrie_owned":false,"supernova_owned":false,
	"energy_availability_percent":0,"missile_availability_percent":0}
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if args.size()<2 or not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not lib.select_language("gb") or not cat.open(lib):check(false,"Expected content and bindings: "+lib.error+bindings.error+cat.error)
	else:
		verify_levels(lib)
		verify_opening_station()
		verify_owners(bindings,cat)
		verify_career(bindings,cat,lib)
		verify_spawns(bindings,cat)
	print("Difficulty levels: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_levels(lib: RefCounted) -> void:
	for value in [0.0,0.5,1.0,1.5,0,1]:check(Difficulty.valid(value),"Rejected difficulty %s"%str(value))
	for value in [2.0,-0.5,0.25,"1.0",null,NAN]:check(not Difficulty.valid(value),"Accepted difficulty %s"%str(value))
	for id in [Difficulty.TITLE_TEXT,Difficulty.PROMPT_TEXT,Difficulty.EXTREME_WARNING_TEXT]+Difficulty.LABEL_TEXTS:
		check(id<lib.strings.size() and not str(lib.strings[id]).is_empty(),"Missing difficulty text %d"%id)

func verify_opening_station() -> void:
	var station:=Station.new();station._state={"phase":"conversation"}
	check(station.career_difficulty()==0.5,"An opening station without a choice is not Normal")
	check(station.retain_difficulty(0.0) and station._state.get("difficulty")==0.0 and station.career_difficulty()==0.0,"Easy was not retained before contracts")
	check(station.fork().career_difficulty()==0.0,"A forked opening station lost Easy")
	check(station.retain_difficulty(0.5) and not station._state.has("difficulty"),"Normal left a stored difficulty")
	check(not station.retain_difficulty(2.0),"An unsupported difficulty was retained")

func verify_owners(bindings: RefCounted,cat: RefCounted) -> void:
	check(Toll.percent(0.0)==2,"Easy Loma toll is not 2%")
	var loadout:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":0,"equipment_ids":[Khador.ITEM_ID]}
	var drive: Dictionary=Khador.resolve(bindings,cat,loadout,0.0)
	check(not drive.has("error") and drive.fuel_multiplier==1,"Khador Drive refused Easy: %s"%str(drive.get("error")))
	check(Khador.resolve(bindings,cat,loadout,1.5).get("fuel_multiplier")==2,"Extreme lost doubled Khador fuel")
	var cloak: Dictionary=Cloak.resolve(bindings,cat,[],44,0.0)
	check(not cloak.has("error") and cloak.cooldown_ms==7000,"Cloak refused Easy or changed its cooldown")
	for level in Difficulty.LEVELS:
		var context: Dictionary=SETTINGS.duplicate(true);context.difficulty=level;context.station_id=78;context.campaign_cursor=1
		var rng:=preload("res://src/simulation/seeded_random.gd").new();rng.seed_from(917)
		var stock:=Stock.new()
		check(stock.prepare(bindings,cat,context,rng.snapshot(),1789423200),"Station stock refused difficulty %s: %s"%[str(level),stock.error])

func verify_career(bindings: RefCounted,cat: RefCounted,lib: RefCounted) -> void:
	var path:=OS.get_environment("GOF2_SOURCE_SAVE")
	if path.is_empty():check(false,"Set GOF2_SOURCE_SAVE to an earned career save");return
	var file:=Save.new()
	var document:=file.load_document(path,bindings,cat,lib)
	if document.is_empty():check(false,file.error);return
	for level in [0.0,1.0]:
		var edited: Dictionary=document.duplicate(true);edited.career.difficulty=level
		var archive:=Archive.new()
		var station: RefCounted=archive.restore(bindings,cat,lib,edited)
		if station==null:check(false,"Career at %s did not restore: %s"%[str(level),archive.error]);continue
		check(station.career_difficulty()==level,"Restored career changed its difficulty")
		var target:=OS.get_environment("GOF2_TEST_DIRECTORY").path_join("difficulty-%s.gof2save"%str(level)) if not OS.get_environment("GOF2_TEST_DIRECTORY").is_empty() else "user://difficulty-%s.gof2save"%str(level)
		var saver:=Save.new()
		if not saver.save(target,station,bindings,cat,lib,station.contract_owner().location_owner()):check(false,saver.error);continue
		var reread:=Save.new();var loaded:=reread.load_document(target,bindings,cat,lib)
		var again: RefCounted=null if loaded.is_empty() else Archive.new().restore(bindings,cat,lib,loaded)
		check(again!=null and again.career_difficulty()==level and loaded.career.difficulty is float,"Save round trip lost difficulty %s"%str(level))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))

## Spawned enemies: ordinary space traffic draws more hostile ships at each
## harder level (same seeds, a dangerous system, rank 0).
func verify_spawns(bindings: RefCounted,_cat: RefCounted) -> void:
	var Traffic:=preload("res://src/simulation/traffic_population.gd")
	var previous:=-1
	for level in [0.0,0.5,1.0,1.5]:
		var ordinary: Dictionary=bindings.mido_travel.free_population.duplicate(true)
		var thresholds: Array=ordinary.hostile_chance_thresholds
		var risky:=thresholds.find(thresholds.max())
		ordinary.merge({"security":risky,"faction":0,"rank":0,"difficulty":level,"station_response":false,"empty_story":false},true)
		var hostiles:=0
		for seed in 200:
			var random:=preload("res://src/simulation/seeded_random.gd").new();random.seed_from(hash(seed*7919+1))
			var result: Dictionary=Traffic._sample(bindings.mido_travel.departure_traffic,bindings.ambient_population,1789423200+seed*3607,random,ordinary)
			hostiles+=int(result.get(&"groups",{}).get(&"hostile",0))
		print("SPAWN difficulty ",level," hostile ships over 200 departures: ",hostiles)
		check(hostiles>previous,"Difficulty %s did not raise hostile traffic (%d after %d)"%[str(level),hostiles,previous])
		previous=hostiles

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
