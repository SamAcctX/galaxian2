extends SceneTree
## Valkyrie station-side story effects a player notices at the talk boundary:
## the Disruptor recipe and the returned Void Essence (71 -> 72), Kothar's
## shipyard (75, 77, the win), the Khador Drive taken (78), the Valkyrie
## workshop reset (78), the drive refused for sale at 77, and the win's hold
## goods. Starts from the earned save docked at Inari Onu after mission 68;
## the cursor is edited to reach each talk quickly.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const Valkyrie=preload("res://src/content/valkyrie_campaign_definitions.gd")
const DRIVE:=85
var checks:=0
var failures:=0
var lib;var bindings;var cat

func _initialize():call_deferred("run")

func run():
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:check(false,"Expected content, bindings and visuals");finish();return
	lib=Library.new();bindings=Bindings.new();cat=Catalogues.new()
	check(lib.open(args[0]) and bindings.open(args[1],lib.manifest,lib) and cat.open(lib) and lib.select_language("gb"),lib.error+bindings.error+cat.error)
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var extra: Array=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		check(bindings.attach_dekato_source(extra[1],lib.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(extra[1],lib.manifest),bindings.error)
	var source: Dictionary=SaveFile.new().read_document(OS.get_environment("GOF2_SOURCE_SAVE"))
	check(source.get("station",{}).get("campaign_cursor")==69 and source.station.loadout.station_id==66 and DRIVE in source.station.loadout.equipment_ids,"Expected the earned 69 save docked at Inari Onu with the Khador Drive fitted")
	if failures:finish();return
	netor_talk(source)
	protected_drive(source)
	kothar_and_valkyrie(source)
	finish()

## 71 -> 72 through the real station conversation, then autosave and Resume.
func netor_talk(source: Dictionary) -> void:
	var entry: RefCounted=restore_at(source,71)
	if entry==null:return
	var before: Dictionary=entry.contract_owner().snapshot()
	var essence:=hold(entry,175)
	check(entry.campaign_conversation_ready(bindings,cat,lib,0) and entry.begin_campaign_conversation(bindings,cat,lib,0),"Talk 71 did not start at Inari Onu: "+entry.error)
	for line in 40:
		if entry.snapshot().get("phase")!="conversation":break
		if not entry.acknowledge():check(false,"Talk 71 stopped: "+entry.error);return
	var career: RefCounted=entry.contract_owner()
	check(entry.snapshot().campaign_cursor==72 and career.snapshot().campaign_cursor==72,"Talk 71 did not move the story to 72")
	check(career.snapshot().credits==before.credits,"Talk 71 changed the credits")
	check(hold(entry,175)==essence+1,"Netor did not give the Void Essence back")
	var disruptor:=blueprint(career,183)
	check(disruptor.get("available")==true and disruptor.get("material_value")==0 and disruptor.get("remaining")==career._blueprints.recipe(183).quantities,"The Disruptor blueprint is not listed as a fresh recipe: "+str(disruptor))
	var resumed: RefCounted=resume(entry)
	if resumed==null:return
	check(hold(resumed,175)==essence+1 and blueprint(resumed.contract_owner(),183).get("available")==true and resumed.snapshot().campaign_cursor==72,"Resume lost the talk 71 grants")

## At 77 the fitted Khador Drive cannot be demounted or sold; at 76 it can.
func protected_drive(source: Dictionary) -> void:
	for cursor in [76,77]:
		var entry: RefCounted=restore_at(source,cursor)
		if entry==null:return
		var now:=int(Time.get_unix_time_from_system())
		if not entry.open_equipment(bindings,cat,lib,[now,now,now]):check(false,"Hangar did not open at %d: %s"%[cursor,entry.error]);return
		var removed: bool=entry.equipment_action("unmount",DRIVE,bindings,cat)
		if cursor==77:
			check(not removed and entry.error.contains("cannot be sold or demounted"),"The drive was demounted at 77: "+entry.error)
			check(DRIVE in entry.equipment_owner().snapshot().loadout.equipment_ids,"The refused demount changed the ship")
			check(entry.equipment_action("unmount",51,bindings,cat),"Other equipment is locked at 77: "+entry.error)
		else:
			check(removed,"The drive is locked outside cursor 77: "+entry.error)
			check(entry.equipment_action("sell",DRIVE,bindings,cat),"The drive cannot be sold at 76: "+entry.error)

## Kothar and Valkyrie talks, applied at the docked station with the real
## per-cursor rules (the save is docked at Inari Onu, which stands in for the
## talk's station), then saved and resumed.
func kothar_and_valkyrie(source: Dictionary) -> void:
	var entry: RefCounted=restore_at(source,72)
	if entry==null:return
	var station:=66
	var career: RefCounted=entry._contracts.fork();var inventory: RefCounted=entry._equipment.fork()
	var credits: int=career.snapshot().credits
	# Something built at the Valkyrie workshop before Alice leaves.
	career._blueprints=career._blueprints.fork_for_transaction()
	check(career._blueprints.story_grant(179,127,5,101),career._blueprints.error)
	var won: Dictionary=talk(career,inventory,83)
	var offers: Array=ships(career,station)
	check(offers.has(37) and offers.has(38) and offers.has(40),"The win did not add the built-in-drive ships: "+str(offers))
	check(price(career,station,38)>0 and price(career,station,38)==load("res://src/simulation/station_stock.gd").local_ship_price(bindings,cat,38,station,int(career._lounges.location(station).stock.context.get("ship_price_percent",0))),"The Typhon is not at its normal price")
	check(not won.is_empty() and hold_of(inventory,137)==1,"The win did not put the rum in the hold")
	talk(career,inventory,74)
	check(ships(career,station).is_empty(),"Entering 75 did not empty the shipyard")
	talk(career,inventory,76)
	check(ships(career,station)==[37] and price(career,station,37)==0,"Entering 77 did not offer the Cronus for free")
	var drives:=hold_of(inventory,DRIVE)
	check(drives==1,"Expected the win's spare drive in the hold before 78")
	talk(career,inventory,77)
	var owned: Dictionary=inventory.snapshot()
	check(not DRIVE in owned.loadout.equipment_ids and hold_of(inventory,DRIVE)==1,"Entering 78 did not take the fitted drive first")
	talk(career,inventory,77)
	check(hold_of(inventory,DRIVE)==0,"A second 78 entry did not take the drive from the hold")
	var liberator:=blueprint(career,179)
	check(liberator.get("station_id")==-1 and liberator.get("remaining")==career._blueprints.recipe(179).quantities,"The Valkyrie workshop was not reset: "+str(liberator))
	check(blueprint(career,85).get("station_id")==10,"The reset touched another station's blueprint")
	talk(career,inventory,83)
	check(price(career,station,37)==0 and ships(career,station).has(38) and ships(career,station).has(40),"The win replaced an offered ship or lost one")
	check(career.snapshot().credits==credits,"Station-side story changes changed the credits")
	entry._contracts=career;entry._retain_equipment(inventory)
	var resumed: RefCounted=resume(entry)
	if resumed==null:return
	var after: RefCounted=resumed.contract_owner()
	check(not DRIVE in resumed.equipment_owner().snapshot().loadout.equipment_ids and hold(resumed,137)==2 and ships(after,station).has(40) and price(after,station,37)==0,"Resume lost the station-side story changes")

func talk(career: RefCounted,inventory: RefCounted,cursor: int) -> Dictionary:
	var rules: Dictionary=Valkyrie.conversation(bindings,cursor,Valkyrie.mission(cursor))
	if rules.is_empty():check(false,"No talk rules for %d"%cursor);return {}
	if not career._apply_story_station_rules(bindings,inventory,rules):check(false,"Talk %d: %s"%[cursor,career.error]);return {}
	return rules

func restore_at(source: Dictionary,cursor: int) -> RefCounted:
	var doc:=source.duplicate(true);var mission:=Valkyrie.mission(cursor)
	doc.station.campaign_cursor=cursor;doc.station.progress.campaign_cursor=cursor;doc.station.player_cache.campaign_cursor=cursor
	doc.station.mission=mission
	doc.career.campaign_cursor=cursor
	var progress: Dictionary=doc.station.progress
	var earned: Dictionary=load("res://src/simulation/opening_handoff.gd").calculate_progress(bindings.opening_handoff,cursor,progress.player_kills,progress.pirate_kills,progress.other_score)
	doc.station.progress.merge(earned,true);doc.career.progress.merge(earned,true)
	if doc.career.has("rank"):doc.career.rank=earned.rank
	var archive:=Archive.new();var entry: RefCounted=archive.restore(bindings,cat,lib,doc)
	check(entry!=null,"Could not restore the save at %d: %s"%[cursor,archive.error])
	return entry

func resume(entry: RefCounted) -> RefCounted:
	var directory:=OS.get_environment("GOF2_SAVE_TEST_DIRECTORY")
	if directory.is_empty():check(false,"Set a private save directory");return null
	var file:=SaveFile.new();var path:=directory.path_join("story-talks.gof2save")
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	if not file.save(path,entry,bindings,cat,lib):check(false,"Autosave failed: "+file.error);return null
	var document:=file.load_document(path,bindings,cat,lib)
	var restored: RefCounted=Archive.new().restore(bindings,cat,lib,document) if not document.is_empty() else null
	check(restored!=null,"Resume failed: "+file.error)
	return restored

func hold(entry: RefCounted,item: int) -> int:return hold_of(entry.equipment_owner(),item)
func hold_of(inventory: RefCounted,item: int) -> int:
	var total:=0
	for row in inventory.snapshot().cargo.entries:
		if int(row.item_id)==item:total+=int(row.quantity)
	return total
func blueprint(career: RefCounted,item: int) -> Dictionary:
	for row in career.blueprint_state().get("entries",[]):
		if row.item_id==item:return row
	return {}
func ships(career: RefCounted,station: int) -> Array:return career._lounges.ship_stock(station).map(func(row):return int(row.ship_id))
func price(career: RefCounted,station: int,ship: int) -> int:
	for row in career._lounges.ship_stock(station):
		if int(row.ship_id)==ship:return int(row.unit_price)
	return -1

func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func finish():print("Valkyrie story talks: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
