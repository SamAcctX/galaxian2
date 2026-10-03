extends SceneTree
## Component transactions start from an actual saved inventory. Diagnostic
## quotes and wallets stay on detached owners and never enter the earned save.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const File=preload("res://src/simulation/station_save_file.gd")
const Context=preload("res://src/simulation/mission_context.gd")
const Ship=preload("res://src/simulation/ship_instance.gd")
const Stock=preload("res://src/simulation/station_stock.gd")
const Engines=preload("res://src/simulation/player_engine_particles.gd")
const Mounts=preload("res://src/content/weapon_mounts.gd")
var checks:=0
var failures:=0

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Ship exchange: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var supplement: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		if not supplement is Array:check(false,"Missing retained campaign source");return
		var accepted: bool=bindings.attach_dekato_source(supplement[1],library.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(supplement[1],library.manifest)
		if not accepted:check(false,bindings.error);return
	var file:=File.new();var archive:=Archive.new()
	var document:=file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library)
	if document.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var original: Dictionary=station.snapshot();var source: RefCounted=station.fork()
	if not source.open_equipment(bindings,cat,library,[1789103558,1789103558,1789103558]):check(false,source.error);return
	var quoted: Dictionary=source.snapshot();var inventory: RefCounted=source.equipment_owner()
	print("Earned ship market: ",{"station":quoted.loadout.station_id,"wallet":quoted.contracts.credits,"ships":quoted.equipment.market_ships,"mission":quoted.contracts.mission,"passengers":quoted.contracts.passengers})
	var mounts:=Mounts.new()
	if not mounts.open(library,cat):check(false,mounts.error);return
	var engine_audio:=preload("res://src/simulation/engine_audio.gd").new()
	var sounds:=preload("res://src/content/audio_resources.gd").new()
	if not engine_audio.configure(bindings,cat) or not sounds.configure(library,bindings):check(false,engine_audio.error+sounds.error);return
	for id in [293,318,325,192]:print("Ship UI ",id,": ",library.strings[id])
	if not quoted.equipment.market_ships.is_empty() and quoted.contracts.passengers>0:
		check(not source.equipment_action("buy_ship",0,bindings,cat) and source.snapshot()==quoted,"Passenger refusal changed the earned station")
	var owned:=quantities(quoted.equipment);var tested:=[]
	check(not Context.base_player_hull(bindings,-1),"A missing hull passed player entry")
	for hull in cat.tables.ships.size():
		if not Context.base_player_hull(bindings,hull) or hull==quoted.loadout.ship_id:continue
		# Expansion hulls (Valkyrie loans, Loma shipyard) belong to the DLC work, not this base-game exchange.
		if hull>=int(bindings.early_contracts.base_station_stock.ships.selection_draw_bound):continue
		var engine:=Engines.new()
		check(engine.configure(bindings,mounts,hull,1234) and engine.advance(Transform3D.IDENTITY,100),"Hull %d exhaust: %s"%[hull,engine.error])
		check(not bindings.resolve_player_engine_glow(hull).is_empty(),"Hull %d engine glow: %s"%[hull,bindings.error])
		var branch: RefCounted=inventory.fork()
		var price:=Stock.local_ship_price(bindings,cat,hull,int(quoted.loadout.station_id))
		var offer:={"ship_id":hull,"faction_id":int(bindings.early_contracts.base_station_stock.ships.affiliations[hull]),"unit_price":price}
		if not branch.open_ship_market(bindings,cat,[offer],0):check(false,branch.error);continue
		var before: Dictionary=branch.snapshot()
		check(not branch.purchase_ship(bindings,cat,0,30000000,1) and branch.snapshot()==before,"Occupied berths permitted exchange")
		if price>before.loadout.ship_instance.unit_price:check(not branch.purchase_ship(bindings,cat,0,0,0) and branch.snapshot()==before,"Unaffordable ship changed its inventory")
		if not branch.purchase_ship(bindings,cat,0,30000000,0):check(false,"Hull %d exchange: %s"%[hull,branch.error]);continue
		var after: Dictionary=branch.snapshot()
		check([68,69,70,94,95,96].all(func(id):return after.fitting_support.get(id,"missing").is_empty()),"A base hull refused its tractor or cloak")
		var tractor:=preload("res://src/simulation/tractor_recovery.gd").new()
		check(tractor.configure(bindings,cat,after.loadout,library),"Hull %d tractor: %s"%[hull,tractor.error])
		var selected:=engine_audio.select(hull,Ship.upgrades(after.loadout),after.loadout.equipment_ids)
		var sound: Dictionary={} if selected.is_empty() else sounds.prepare(int(selected.source_id))
		check(not sound.is_empty() and not sound.has("unsupported"),"Hull %d engine audio cannot enter flight: %s"%[hull,str(sound)])
		check(after.loadout.ship_id==hull and after.cargo.ship_id==hull and quantities(after)==owned,"Exchange lost cargo/equipment or retained the old hull")
		check(after.credit_delta==before.loadout.ship_instance.unit_price-price,"Ship exchange included equipment value or changed the offer quote")
		check(after.market_ships.size()==1 and after.market_ships[0].ship_id==before.loadout.ship_id and after.market_ships[0].upgrade_tags==[],"Exchange did not replace the selected offer with the stripped old hull")
		check(not branch.purchase_ship(bindings,cat,9,30000000,0) and branch.snapshot()==after,"Stale offer index altered ownership")
		check(branch.close_ordinary_shopping(),branch.error)
		var saved: Dictionary=branch.snapshot();saved.erase("requirements")
		check(archive._inventory(bindings,cat,saved)!=null,"Purchased inventory did not cross the save boundary: "+archive.error)
		check(archive._player_cache(bindings,cat,quoted.player_cache,after.loadout,int(quoted.campaign_cursor)),"Exchanging a hull invalidated the actual arrival cache")
		tested.append(hull)
	check(station.snapshot()==original and source.snapshot()==quoted,"Diagnostic purchases changed the earned career")
	check(tested.size()>25,"Base-game hull coverage was unexpectedly narrow")
	verify_transfer(bindings,cat,library,inventory,source)
	check(source.snapshot()==quoted,"Transfer diagnostics changed the source station")
	print("Purchased hulls: ",tested)

func verify_transfer(bindings: RefCounted,cat: RefCounted,library: RefCounted,inventory: RefCounted,station: RefCounted) -> void:
	var branch: RefCounted=inventory.fork()
	var rng: Dictionary=station.contract_owner().location_owner().snapshot().random
	var offer:={"ship_id":1,"faction_id":0,"unit_price":124146,"upgrade_tags":[0]}
	if not branch.open_ship_market(bindings,cat,[offer],0) or not branch.purchase_ship(bindings,cat,0,30000000,0) or not branch.close_ordinary_shopping():check(false,branch.error);return
	var stock:=[{"item_id":2,"quantity":3,"unit_price":1},{"item_id":36,"quantity":9,"unit_price":1},{"item_id":37,"quantity":9,"unit_price":1},{"item_id":116,"quantity":40,"unit_price":1}]
	if branch.open_ordinary_shopping(bindings,cat,stock,rng,[1789103558,1789103558,1789103558],0,library).is_empty():check(false,branch.error);return
	for ammunition in [36,37]:
		for i in 9:
			if not branch.transact("buy",ammunition,30000000):check(false,branch.error);return
		if not branch.fit(bindings,cat,"mount",ammunition):check(false,branch.error);return
	if not branch.transact("buy",2,30000000) or not branch.fit(bindings,cat,"mount",2):check(false,branch.error);return
	for i in 40:
		if not branch.transact("buy",116,30000000):check(false,branch.error);return
	if not branch.open_ship_market(bindings,cat,[{"ship_id":0,"faction_id":3,"unit_price":16200}],0):check(false,branch.error);return
	var before: Dictionary=branch.snapshot();var total:=quantities(before)
	if not branch.purchase_ship(bindings,cat,0,30000000,0):check(false,branch.error);return
	var after: Dictionary=branch.snapshot()
	check(quantities(after)==total and after.loadout.slots[0].item_id==before.loadout.slots[0].item_id,"A smaller ship lost stacks or reordered its retained gun")
	check(after.cargo.entries.any(func(row):return row.item_id==37 and row.quantity==9),"Ammunition that no longer fits was refilled or lost")
	var departure: RefCounted=station.fork();departure._retain_equipment(branch.fork())
	check(departure.close_equipment(),departure.error)
	check(after.cargo.used>after.cargo.capacity and departure.prepare_departure(bindings,cat).is_empty() and departure.error.contains("overfilled"),"An overfull exchange was refused or allowed to depart")
	check(after.loadout.ship_instance.upgrade_tags==[] and after.market_ships[0].upgrade_tags==[0],"A sold hull's upgrades moved to its replacement")
	check(branch.purchase_ship(bindings,cat,0,30000000,0),branch.error)
	check(branch.snapshot().loadout.ship_instance.upgrade_tags==[0] and branch.snapshot().fitting_stats.hull>after.fitting_stats.hull,"Buying back the actual upgraded hull lost its properties")

func quantities(state: Dictionary) -> Dictionary:
	var result:={}
	for row in state.cargo.entries:result[row.item_id]=int(result.get(row.item_id,0))+int(row.quantity)
	for slot in state.loadout.slots:
		if slot!=null:result[slot.item_id]=int(result.get(slot.item_id,0))+int(slot.quantity)
	return result

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
