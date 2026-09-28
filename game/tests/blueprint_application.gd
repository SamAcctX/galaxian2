extends "res://tests/ship_purchase_application.gd"
## Buys actual generated materials and ships them to the earned prototype.
const BlueprintStock=preload("res://src/simulation/station_stock.gd")
var _visited_blueprint_suppliers:=[]
var _blueprint_refusal_seen:=false

func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor>=34

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	if OS.get_environment("GOF2_BLUEPRINT_NOTICE_REVIEW")=="1":
		var products: Array=original.cargo.entries.filter(func(row):return row.item_id==85)
		check(not products.is_empty(),"Notice review requires the already earned product")
		if failures or not app.session._prepare_blueprint_pickup(source,definitions,app.visuals,products):check(false,app.session.error);return
		app.session._blueprint_pickup.popup_centered(Vector2i(500,180))
		await capture_free_application("blueprint-collected-notice")
		await activate_ship_control(app.session._blueprint_pickup.get_ok_button(),true)
		check(not app.session._blueprint_pickup.visible and app.session.station_owner().snapshot()==original,"The styled notice changed inventory or failed keyboard acknowledgement")
		return
	if original.cargo.entries.any(func(row):return row.item_id==85):
		check(original.contracts.blueprints.entries.filter(func(row):return row.item_id==85)[0].completed>0,"Resume has a drive without its completed project")
		if is_instance_valid(app.session._blueprint_pickup) and app.session._blueprint_pickup.visible:await activate_ship_control(app.session._blueprint_pickup.get_ok_button())
		if not app.equipment_action("open"):check(false,app.session.error);return
		app.equipment_panel.select_tab("blueprints");await capture_free_application("blueprint-resumed")
		if not app.equipment_action("close"):check(false,app.session.error);return
		if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()):check(false,app.status.text);return
		if not await release_application_flight():return
		await capture_free_application("blueprint-product-carried")
		if not await dock_application():return
		check(app.session.station_owner().snapshot().cargo==original.cargo,"Fresh Resume flight lost or duplicated the constructed drive")
		retain_recovery_save("returned");return
	for visit in 20:
		if not await supply_current_hangar():return
		var state: Dictionary=app.session.station_owner().snapshot()
		var project: Dictionary=state.contracts.blueprints.entries.filter(func(row):return row.item_id==85)[0]
		if int(project.completed)>0:break
		if OS.get_environment("GOF2_BLUEPRINT_PARTIAL")=="1":
			if not retain_recovery_save("partial"):return
			return
		var destination:=next_blueprint_supplier(state,project)
		if destination<0:check(false,"No generated supplier can provide the remaining materials");return
		print("Blueprint supplier route: ",state.loadout.station_id," -> ",destination," remaining ",project.remaining)
		if not await visit_tractor_supplier(destination):return
		if not retain_recovery_save("supplier-"+str(destination)):return
	var completed: Dictionary=app.session.station_owner().snapshot()
	var project: Dictionary=completed.contracts.blueprints.entries.filter(func(row):return row.item_id==85)[0]
	check(project.completed==1,"The bought materials did not finish the prototype")
	if failures or not retain_recovery_save("finished"):return
	if not completed.cargo.entries.any(func(row):return row.item_id==85):
		var product: Dictionary=completed.contracts.blueprints.products.filter(func(row):return row.item_id==85)[0]
		if not await visit_tractor_supplier(int(product.station_id)):return
		check(is_instance_valid(app.session._blueprint_pickup) and app.session._blueprint_pickup.visible,"Collection did not show its original product notice")
		await capture_free_application("blueprint-collected-notice")
		if is_instance_valid(app.session._blueprint_pickup) and app.session._blueprint_pickup.visible:await activate_ship_control(app.session._blueprint_pickup.get_ok_button(),true)
	var collected: Dictionary=app.session.station_owner().snapshot()
	check(collected.cargo.entries.any(func(row):return row.item_id==85 and row.quantity==1) and collected.contracts.blueprints.products.is_empty(),"The actual dock did not collect exactly one finished drive")
	check(collected.campaign_cursor==original.campaign_cursor,"Construction altered the earned campaign")
	if not retain_recovery_save("returned"):return
	if not app.equipment_action("open"):check(false,app.session.error);return
	app.equipment_panel.select_tab("cargo");await capture_free_application("blueprint-constructed-cargo")
	if not app.equipment_action("close"):check(false,app.session.error);return
	print("Constructed drive saved: ",{"station":collected.loadout.station_id,"credits":collected.contracts.credits,"cargo":collected.cargo,"project":project,"timing":_pilot_deltas})

func supply_current_hangar() -> bool:
	if not app.equipment_action("open"):check(false,app.session.error);return false
	var before: Dictionary=app.session.station_owner().snapshot()
	_visited_blueprint_suppliers.append(int(before.loadout.station_id))
	if before.contracts.credits<40000:
		for id in [64,9]:
			var state: Dictionary=app.session.station_owner().snapshot()
			if state.loadout.equipment_ids.has(id) and not app.equipment_action("unmount",id):check(false,app.session.error);return false
			if app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==id):
				if not app.equipment_action("sell",id):check(false,app.session.error);return false
		if not app.session.station_owner().snapshot().loadout.equipment_ids.has(2) and app.session.station_owner().snapshot().cargo.entries.any(func(row):return row.item_id==2):
			if not app.equipment_action("mount",2):check(false,app.session.error);return false
	var recipe: Array=Array(catalogue.tables.items[85].arrays[0])
	for index in recipe.size():
		var state: Dictionary=app.session.station_owner().snapshot()
		var project: Dictionary=state.contracts.blueprints.entries.filter(func(row):return row.item_id==85)[0]
		if int(project.completed)>0:break
		var id:=int(recipe[index]);var need:=int(project.remaining[index])
		if need<=0:continue
		if not _blueprint_refusal_seen:
			check(not app.equipment_action("supply_blueprint",85,id,need+1) and app.session.station_owner().snapshot()==state,"Invalid material supply altered the station")
			_blueprint_refusal_seen=true
		var rows: Array=state.equipment.market_rows.filter(func(row):return row.item_id==id)
		if rows.is_empty():continue
		var offer: Dictionary=rows[0];var amount:=mini(need,int(offer.owned)+int(offer.stock))
		if amount<=0:continue
		for unit in maxi(0,amount-int(offer.owned)):
			if not app.equipment_action("buy",id):check(false,app.session.error);return false
		state=app.session.station_owner().snapshot()
		var fee:=amount*20 if int(project.station_id)!=int(state.loadout.station_id) else 0
		app.equipment_panel.select_tab("blueprints")
		var material: Dictionary=app.equipment_panel._blueprint_materials[id]
		material.quantity.value=amount
		app.equipment_panel._scroll.ensure_control_visible(material.button)
		await activate_ship_control(material.button,index%2==0)
		if app.equipment_panel._replacement.visible:
			if visit_capture_needed():await capture_free_application("blueprint-shipping-confirmation")
			await activate_ship_control(app.equipment_panel._replacement.get_ok_button(),index%2!=0)
		var after: Dictionary=app.session.station_owner().snapshot()
		check(after.contracts.credits==state.contracts.credits-fee and after.cargo.used==state.cargo.used-amount,"The material control lost its cargo debit or shipping payment")
		if failures:return false
		print("Supplied blueprint material: ",{"station":after.loadout.station_id,"item":id,"quantity":amount,"fee":fee,"wallet":after.contracts.credits})
		if visit_capture_needed():await capture_free_application("blueprint-materials-supplied")
	if not app.equipment_action("close"):check(false,app.session.error);return false
	return retain_recovery_save("materials-"+str(before.loadout.station_id))

func visit_capture_needed() -> bool:return _visited_blueprint_suppliers.size()==1

func next_blueprint_supplier(state: Dictionary,project: Dictionary) -> int:
	var locations: RefCounted=app.session.contract_owner().location_owner()
	var saved: Dictionary=locations.snapshot();var template: Dictionary=saved.locations[-1].stock.context
	var navigation:=Navigation.new()
	if not navigation.configure(definitions,catalogue,saved.system_availability):check(false,navigation.error);return -1
	var materials: Array=Array(catalogue.tables.items[85].arrays[0]);var chosen:=-1;var best:=0.0
	for id in range(int(definitions.early_contracts.base_station_stock.last_station_id)+1):
		if id in _visited_blueprint_suppliers:continue
		var system: int=catalogue.tables.stations[id].system_id
		if not saved.system_availability[system]:continue
		var route:=navigation.route(int(state.loadout.system_id),system)
		if route.is_empty():continue
		var stock: Array=locations.item_stock(id)
		if locations.location(id).is_empty():
			var context:=template.duplicate(true);context.station_id=id
			var preview:=BlueprintStock.new()
			if not preview.prepare(definitions,catalogue,context,saved.random,flight_world_seconds()):continue
			stock=preview.snapshot().items
		var coverage:=0
		for offer in stock:
			var index: int=materials.find(int(offer.item_id))
			if index>=0:coverage+=mini(int(project.remaining[index]),int(offer.quantity))
		var score:=float(coverage)/float(route.size()+1)
		if score>best:chosen=id;best=score
	return chosen
