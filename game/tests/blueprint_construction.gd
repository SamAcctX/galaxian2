extends "res://tests/ship_exchange.gd"
## Fabrication conserves materials across partial deliveries, saves and pickup.
const Blueprints=preload("res://src/simulation/blueprint_progress.gd")

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	for key in ["GOF2_DEKATO_SOURCE_ARGS","GOF2_NEHMA_SOURCE_ARGS"]:
		var extra: Array=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment(key)))
		var ready: bool=bindings.attach_dekato_source(extra[1],library.manifest) if key=="GOF2_DEKATO_SOURCE_ARGS" else bindings.attach_nehma_source(extra[1],library.manifest)
		if not ready:check(false,bindings.error);return
	var file:=File.new();var archive:=Archive.new()
	var document:=file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library)
	if document.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var untouched: Dictionary=station.snapshot()
	var source: RefCounted=station.fork()
	if not source.open_equipment(bindings,cat,library,[1789103558,1789103558,1789103558]):check(false,source.error);return
	var project:=Blueprints.new()
	if not project.restore(cat,bindings.binding_id,source.contract_owner().blueprint_state()):check(false,project.error);return
	check(project.entry(85).available and project.entry(85).station_id==10,"The earned prototype lost its construction site")
	var recipe:=project.recipe(85);var supplied: RefCounted=source.equipment_owner();var stock:=[]
	for i in recipe.material_ids.size():stock.append({"item_id":recipe.material_ids[i],"quantity":recipe.quantities[i]+1,"unit_price":100})
	if not supplied.close_ordinary_shopping() or supplied.open_ordinary_shopping(bindings,cat,stock,source.contract_owner().location_owner().snapshot().random,[1789103558,1789103558,1789103558],0,library).is_empty():check(false,supplied.error);return
	# These detached catalogue fixtures exercise the recipe; the application
	# pilot separately buys actual generated stock with the retained wallet.
	for index in recipe.material_ids.size():
		var id:=int(recipe.material_ids[index]);var amount:=int(project.entry(85).remaining[index])
		if amount<=0:continue
		var before:=project.snapshot();var cargo: Dictionary=supplied.snapshot()
		check(project.contribute(85,id,amount,supplied)==null and project.snapshot()==before and supplied.snapshot()==cargo,"Missing materials altered construction")
		for unit in amount:
			if not supplied.transact("buy",id,30000000):check(false,supplied.error);return
		var staged: RefCounted=project.fork_for_transaction()
		var inventory: RefCounted=staged.contribute(85,id,1,supplied)
		if inventory==null:check(false,staged.error);return
		check(project.snapshot()==before,"A blueprint fork changed the parent")
		check(inventory.snapshot().cargo.used==supplied.snapshot().cargo.used-1,"The first contribution did not debit cargo")
		var restored:=Blueprints.new()
		check(restored.restore(cat,bindings.binding_id,staged.snapshot()) and restored.snapshot()==staged.snapshot(),"Partial fabrication did not survive save restoration")
		project=restored;supplied=inventory
		if amount>1:
			inventory=project.contribute(85,id,amount-1,supplied)
			if inventory==null:check(false,project.error);return
			supplied=inventory
		var accepted:=project.snapshot();var remaining: int=project.entry(85).remaining[index]
		check(project.contribute(85,id,remaining+1,supplied)==null and project.snapshot()==accepted,"An excess/stale material request produced another item")
	check(project.entry(85).completed==1 and project.entry(85).station_id==-1,"Completion did not count and reset the build")
	check(not supplied.snapshot().cargo.entries.any(func(row):return row.item_id==85),"A remote completion teleported the product")
	check(project.snapshot().products==[{"item_id":85,"station_id":10,"quantity":1}],"The finished drive did not wait at its construction station")
	check(project.shipping_cost(85,97,2)==0,"A new build retained the previous shipping site")
	var arrived: RefCounted=supplied.fork()
	if not arrived.close_ordinary_shopping():check(false,arrived.error);return
	arrived._state.loadout.station_id=10;arrived._state.loadout.system_id=int(cat.tables.stations[10].system_id)
	var collected: RefCounted=project.collect(arrived)
	if collected==null:check(false,project.error);return
	check(collected.snapshot().cargo.entries.any(func(row):return row.item_id==85 and row.quantity==1) and project.snapshot().products.is_empty(),"Station pickup lost the product")
	var again: RefCounted=project.collect(collected)
	check(again!=null and again.snapshot()==collected.snapshot(),"Repeated station entry duplicated the product")
	var saved: Dictionary=collected.snapshot();saved.erase("requirements")
	check(archive._inventory(bindings,cat,saved)!=null,"The constructed product failed inventory restore: "+archive.error)
	var malformed:=project.snapshot();malformed.products=[{"item_id":85,"station_id":10,"quantity":1},{"item_id":85,"station_id":10,"quantity":1}]
	check(not Blueprints.new().restore(cat,bindings.binding_id,malformed),"A duplicate pending product was accepted")
	verify_production_station(bindings,cat,library,station,archive,project)
	check(station.snapshot()==untouched,"Fabrication checks mutated the earned save owner")
	print("Blueprint construction: ",checks," checks; ",failures," failures")

func verify_production_station(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted,archive: RefCounted,project: RefCounted) -> void:
	var medals=preload("res://src/simulation/base_medal_progress.gd")
	var counts: Dictionary=medals.blueprint_counts(project.snapshot())
	check(counts=={"blueprints_owned":1,"blueprints_constructed":1} and medals.all_base_gold(45,counts)==false,"A finished prototype granted all blueprint medals")
	check(medals.all_base_gold(45,{"blueprints_owned":13,"blueprints_constructed":13})==null,"Blueprint achievements guessed the other earned medals")
	var career: RefCounted=station.contract_owner();var locations: Dictionary=career.location_owner().snapshot()
	var settings:={"difficulty":career.snapshot().difficulty,"valkyrie_owned":false,"supernova_owned":false,"energy_availability_percent":0,"missile_availability_percent":0,"ship_price_percent":0}
	var context: RefCounted=station.mission_station_context_owner()
	if not career.select_location(bindings,cat,library,10,settings,locations.random,1789103569,context):check(false,career.error);return
	var selected: RefCounted=career.location_owner();var saved: Dictionary=selected.snapshot()
	check(selected.location(10).stock.context.all_base_medals_gold==false and selected.location(10).has("medal_progress"),"The earned ending could not retain ordinary Thynome stock")
	var restored: RefCounted=archive._locations(bindings,cat,library,saved,context)
	check(restored!=null and restored.snapshot()==saved,"The production station lost its sampled medal state on Resume: "+archive.error)
	check(station.contract_owner().location_owner().snapshot()==locations,"A new production station corrupted its parent career")
	var forged:=saved.duplicate(true)
	for row in forged.locations:
		if row.station_id==10:row.medal_progress.blueprints_constructed=-1
	check(archive._locations(bindings,cat,library,forged,context)==null,"Invalid retained blueprint medal progress survived loading")
