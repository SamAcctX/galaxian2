extends "res://tests/purchase_contract.gd"
## Detached station transactions; the application covers generated offers,
## physical travel, purchased files and the saved return to the client.

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected matching content, bindings and visuals")
	print("Stolen Goods: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library=load("res://src/content/library.gd").new();var bindings=load("res://src/content/resource_bindings.gd").new();var cat=load("res://src/content/catalogues.gd").new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not cat.open(library) or not library.select_language("gb"):check(false,library.error+bindings.error+cat.error);return
	var file=load("res://src/simulation/station_save_file.gd").new();var archive=load("res://src/simulation/station_archive.gd").new()
	var station: RefCounted=archive.restore(bindings,cat,library,file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library))
	if station==null:check(false,file.error+archive.error);return
	var source: Dictionary=station.snapshot();var contracts: RefCounted=station.contract_owner().fork()
	var context: Dictionary=contracts.snapshot().accepted_contact.offer.context.duplicate(true)
	context.station_id=source.loadout.station_id;context.campaign_cursor=source.campaign_cursor
	context.rank=source.contracts.rank;context.reputation=source.contracts.reputation
	var offer=load("res://src/simulation/contract_offer.gd").new()
	if not offer.configure(bindings,cat,context,{"kind":14,"difficulty_index":7,"parameter_index":0,"quantity_index":0,"destination_station_id":39}):check(false,offer.error);return
	var quote: Dictionary=offer.snapshot()
	contracts._state.offers[0]={"consumed":false,"offer":quote}
	var equipment: RefCounted=contracts.accept(0,station.equipment_owner(),true,bindings)
	if equipment==null:check(false,contracts.error);return
	var accepted: Dictionary=contracts.snapshot();var inventory: Dictionary=equipment.snapshot()
	check(accepted.mission==quote.mission and inventory.cargo==source.cargo and accepted.credits==source.contracts.credits,"Acceptance supplied a file or changed money")
	check(contracts.active_mission_for(39,bindings).is_empty(),"The shop search selected a combat cast")
	check(contracts.poll_station(equipment,bindings) and contracts.snapshot()==accepted,"A missing file completed the job")
	var ready:=cargo_fixture(equipment,115,[3,2])
	var elsewhere: RefCounted=ready.fork();elsewhere._state.loadout.station_id=39
	check(contracts.poll_station(elsewhere,bindings) and contracts.snapshot()==accepted,"The file paid at its shop instead of the client's station")
	var branch: RefCounted=contracts.fork()
	check(branch.poll_station(ready,bindings),branch.error)
	var pending: Dictionary=branch.snapshot()
	check(pending.pending_result.get("completed",false) and pending.credits==accepted.credits and pending.completed_side_missions==accepted.completed_side_missions,"The return failed or paid before Close")
	check(branch.poll_station(ready,bindings) and branch.snapshot()==pending,"Repeated result polling changed standing twice")
	var paid_inventory: RefCounted=branch.acknowledge_delivery_result(ready,bindings)
	if paid_inventory==null:check(false,branch.error);return
	var paid: Dictionary=branch.snapshot()
	check(paid.credits==accepted.credits+quote.mission.reward+quote.mission.bonus and paid.completed_side_missions==accepted.completed_side_missions+1,"The file returned the wrong reward or job count")
	check(paid_inventory.snapshot().cargo.entries==inventory.cargo.entries+[{"item_id":115,"quantity":2}] and paid_inventory.cargo_cache_valid(),"Hand-in failed to remove only the entire first file stack")
	check(paid.delivery_statistics==accepted.delivery_statistics and paid.campaign_cursor==source.campaign_cursor,"The return changed delivery statistics or the campaign")
	check(paid.mission.is_empty() and paid.accepted_contact.is_empty() and branch.acknowledge_delivery_result(paid_inventory,bindings)==null,"The completed job paid twice")
	check(contracts.snapshot()==accepted and ready.snapshot().cargo.entries.size()==inventory.cargo.entries.size()+2,"Settlement mutated its parent")
	var replaced: RefCounted=contracts.fork()
	replaced._state.offers[3]={"consumed":false,"offer":quoted_fixture(bindings,cat,contracts,118)}
	var replaced_inventory: RefCounted=replaced.accept(3,ready,true,bindings)
	check(replaced_inventory!=null and replaced_inventory.snapshot().cargo==ready.snapshot().cargo and replaced.snapshot().credits==accepted.credits,"Replacement deleted owned files or paid the abandoned job")
	verify_stock(contracts,equipment,source,bindings,cat,library)
	verify_markers(accepted,source,ready.snapshot().cargo,bindings,cat,library)
	check(station.snapshot()==source,"Detached checks changed the earned station")

func verify_stock(contracts: RefCounted,equipment: RefCounted,source: Dictionary,bindings: RefCounted,cat: RefCounted,library: RefCounted) -> void:
	var parent: Dictionary=contracts.snapshot();var search: RefCounted=contracts.fork()
	check(search.apply_station_entry(bindings,cat,equipment,source.mission) and search.snapshot()==parent,"The client station gained the search file")
	var settings=load("res://src/presentation/opening_preview.gd").BASE_STOCK_SETTINGS.duplicate(true)
	settings.difficulty=parent.difficulty;settings.ship_price_percent=0
	if not search.select_location(bindings,cat,library,39,settings,parent.lounges.random,1789104016):check(false,search.error);return
	var arrived: RefCounted=equipment.fork();arrived._state.loadout.station_id=39
	if not search.rebase_station(arrived,bindings):check(false,search.error);return
	var before: Dictionary=search.snapshot();var before_cache: RefCounted=search.location_owner()
	var stock: Array=before_cache.item_stock(39)
	check(not stock.any(func(row):return row.item_id==115),"The stock fixture already contains the file")
	if not search.apply_station_entry(bindings,cat,arrived,source.mission):check(false,search.error);return
	var supplied: Array=search.location_owner().item_stock(39)
	check(supplied.size()==stock.size()+1 and supplied.back().item_id==115 and supplied.back().quantity==1 and supplied.back().unit_price>0,"The destination shop did not receive one priced file")
	check(supplied.slice(0,-1)==stock and search.snapshot().population==before.population and search.snapshot().offers==before.offers,"File insertion rerolled stock or contacts")
	check(before_cache.item_stock(39)==stock and contracts.snapshot()==parent,"Stock insertion changed a parent cache or career")
	var retained: Dictionary=search.snapshot()
	check(search.apply_station_entry(bindings,cat,arrived,source.mission) and search.snapshot()==retained,"Existing file stock was duplicated or repriced")
	var shopping: RefCounted=search.open_shopping(bindings,cat,arrived,[1789104016,1789104016,1789104016],library)
	if shopping==null:check(false,search.error);return
	var row: Dictionary=shopping.snapshot().market_rows.filter(func(entry):return entry.item_id==115)[0]
	var credits:=int(search.snapshot().credits)
	var bought: RefCounted=search.transact_shopping(bindings,cat,shopping,"buy",115)
	if bought==null:check(false,search.error);return
	check(bought.snapshot().cargo.entries.any(func(entry):return entry.item_id==115 and entry.quantity==1) and search.snapshot().credits==credits-row.unit_price,"Buying the file did not exchange its displayed price and cargo")
	check(not search.location_owner().item_stock(39).any(func(entry):return entry.item_id==115),"The purchased file remained in stock")
	check(search.poll_station(bought,bindings) and search.snapshot().pending_result.is_empty(),"Buying the file completed before returning to the client")
	var closed: RefCounted=bought.fork()
	if not closed.close_ordinary_shopping():check(false,closed.error);return
	var reopened: RefCounted=search.open_shopping(bindings,cat,closed,[1789104017,1789104017,1789104017],library)
	if reopened==null:check(false,search.error);return
	check(reopened.snapshot().market_rows.filter(func(entry):return entry.item_id==115)[0].stock==0,"Reopening the shop replenished a purchased file")
	closed=reopened.fork()
	if not closed.close_ordinary_shopping():check(false,closed.error);return
	check(search.apply_station_entry(bindings,cat,closed,source.mission) and search.location_owner().item_stock(39).filter(func(entry):return entry.item_id==115)[0].quantity==1,"A later station entry did not replenish an absent file")

func verify_markers(accepted: Dictionary,source: Dictionary,cargo: Dictionary,bindings: RefCounted,cat: RefCounted,library: RefCounted) -> void:
	var recipe=load("res://src/content/mission_recipe.gd")
	var outward: Dictionary=recipe.objective_markers(bindings.early_contracts,accepted.mission,accepted.accepted_contact,source.cargo)
	var home: Dictionary=recipe.objective_markers(bindings.early_contracts,accepted.mission,accepted.accepted_contact,cargo)
	check(outward.station_id==accepted.accepted_contact.station_id and outward.system_station_id==accepted.mission.station_id,"Map disclosed the search station or lost its system")
	check(home.station_id==accepted.accepted_contact.station_id and home.system_station_id==accepted.accepted_contact.station_id,"The owned file did not direct the system marker home")
	var panel=load("res://src/presentation/lounge_panel.gd").new();panel._library=library;panel._bindings=bindings;panel._catalogues=cat
	var brief: String=panel.format_job(library.strings[accepted.mission.briefing_text_id],accepted.mission)
	check(brief.contains(cat.tables.systems[accepted.mission.system_id].name) and not brief.contains(cat.tables.stations[accepted.mission.station_id].name) and not brief.contains("#"),"The search briefing disclosed its exact station or left placeholders")
	panel.free()
	var state:=source.duplicate(true);state.contracts=accepted;state.station_map=true
	state.location={"station_id":source.loadout.station_id,"system_id":source.loadout.system_id}
	var map=load("res://src/simulation/local_map.gd").new()
	if not map.configure(library,bindings,cat,state):check(false,map.error);return
	check(map.snapshot().rows.filter(func(row):return row.mission_target).map(func(row):return row.station_id)==[accepted.accepted_contact.station_id],"The local map did not display the return client")
	var row: Dictionary=map.snapshot().rows.filter(func(entry):return entry.station_id==accepted.accepted_contact.station_id)[0]
	check(row.contract_target and not row.story_target,"The side job used a campaign objective marker")
