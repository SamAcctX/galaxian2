extends RefCounted
## Buy a different primary class from the retained station's actual market.
## No grants, stock replacement, save edits or manufactured flight equipment.
var error:=""
var receipt:={}

func prepare(bindings: RefCounted,cat: RefCounted,library: RefCounted,station: RefCounted,check: Callable) -> RefCounted:
	var before: Dictionary=station.snapshot()
	var fitted: RefCounted=station.fork()
	if not fitted.open_equipment(bindings,cat,library,[1789100000,1789100000,1789100000]):return fail(fitted.error)
	var opened: Dictionary=fitted.snapshot()
	var primary:=-1
	for index in opened.loadout.slots.size():
		var slot: Variant=opened.loadout.slots[index]
		if slot!=null and slot.category==0:primary=index;break
	if primary<0:return fail("The restored station has no mounted primary to exchange")
	var old_id: int=opened.loadout.slots[primary].item_id
	var old_type: int=cat.tables.items[old_id].arrays[2][5]
	var offers: Array=opened.equipment.market_rows.filter(func(row):
		return row.stock>0 and not row.mission and row.item_id!=old_id and row.unit_price>0 and row.unit_price<=opened.contracts.credits and cat.tables.items[row.item_id].arrays[2][3]==0 and cat.tables.items[row.item_id].arrays[2][5]!=old_type and opened.equipment.fitting_support.get(row.item_id,"unsupported").is_empty())
	offers.sort_custom(func(a,b):return a.item_id<b.item_id)
	if offers.is_empty():return fail("No affordable, supported alternate primary class in the retained station stock: "+str(opened.equipment.market_rows))
	var offer: Dictionary=offers[0]
	var new_id: int=offer.item_id
	# Never mount an unowned purchase or silently substitute the original gun.
	if not fitted.equipment_action("buy",new_id,bindings,cat):return fail(fitted.error)
	var bought: Dictionary=fitted.snapshot()
	check.call(bought.contracts.credits==opened.contracts.credits-offer.unit_price,"Alternate primary purchase did not debit its actual station quote")
	var quoted: Array=bought.equipment.market_rows.filter(func(row):return row.item_id==new_id)
	check.call(quoted.size()==1 and quoted[0].stock==offer.stock-1 and quoted[0].owned==offer.owned+1,"Paid primary did not move one real stock unit into owned cargo")
	if not fitted.equipment_action("unmount",old_id,bindings,cat,primary) or not fitted.equipment_action("mount",new_id,bindings,cat):return fail(fitted.error)
	var mounted: Dictionary=fitted.snapshot()
	check.call(mounted.loadout.slots[primary]!=null and mounted.loadout.slots[primary].item_id==new_id,"The paid alternate primary did not occupy the old gun's slot")
	for index in opened.loadout.slots.size():
		if index!=primary:check.call(mounted.loadout.slots[index]==opened.loadout.slots[index],"Primary exchange changed unrelated installed equipment")
	var old_cargo: int=0
	for row in opened.cargo.entries:
		if row.item_id==old_id:old_cargo+=row.quantity
	var kept_cargo: int=0
	for row in mounted.cargo.entries:
		if row.item_id==old_id:kept_cargo+=row.quantity
	check.call(kept_cargo==old_cargo+1,"Primary exchange lost the paid-for original gun instead of keeping it in cargo")
	for key in ["mission","passengers","progress","reputation"]:
		check.call(mounted.contracts.get(key)==before.contracts.get(key),"Paid fitting changed the independent career field "+key)
	check.call(mounted.station_response_flags==before.station_response_flags and mounted.campaign_cursor==before.campaign_cursor,"Paid fitting changed earned station history or campaign progress")
	if not fitted.close_equipment():return fail(fitted.error)
	var final: Dictionary=fitted.snapshot()
	check.call(final.contracts.credits==before.contracts.credits-offer.unit_price and station.snapshot()==before,"Closing paid fitting changed money or its immutable station parent")
	receipt={"station_id":before.loadout.station_id,"old_item":old_id,"new_item":new_id,"old_type":old_type,"new_type":cat.tables.items[new_id].arrays[2][5],"slot":primary,"price":offer.unit_price,"credits_before":before.contracts.credits,"credits_after":final.contracts.credits,"stock_before":offer.stock,"stock_after":quoted[0].stock,"original_in_cargo":kept_cargo}
	print("Legal alternate primary receipt ",JSON.stringify(receipt))
	return fitted

func fail(message: String) -> RefCounted:
	error=message
	return null
