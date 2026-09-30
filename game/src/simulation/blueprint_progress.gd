extends RefCounted
## Career blueprint quantities are independent of player cargo and equipment.
## The caller stages the story acknowledgement and cargo debit as one transaction.
const MAX_I32 := 2147483647
const MIN_I32 := -2147483648
const STORY_BLUEPRINT_ID := 85
const STORY_MATERIAL_ID := 164
const STORY_MATERIAL_QUANTITY := 50
const SHIPPING_UNIT_COST := 20
const Catalogues = preload("res://src/content/catalogues.gd")
const Library = preload("res://src/content/library.gd")
var error := ""
var _recipes: Dictionary = {}
var _material_unit_value := 0
var _state: Dictionary = {}
var _station_count := 0


func configure(catalogues: RefCounted, binding_id: String) -> bool:
	error = ""
	var definitions := _read_catalogue(catalogues, binding_id)
	if definitions.is_empty(): return false
	var entries := []
	for item_id in definitions.ids:
		entries.append({"item_id": item_id, "available": false,
			"remaining": definitions.recipes[item_id].quantities.duplicate(), "material_value": 0,
			"station_id": -1, "completed": 0})
	_recipes = definitions.recipes
	_material_unit_value = definitions.material_unit_value
	_station_count=catalogues.tables.stations.size()
	_state = {"base_content_id": catalogues.content_id, "binding_id": binding_id, "entries": entries,"products":[]}
	return true


func restore(catalogues: RefCounted, binding_id: String, saved: Dictionary) -> bool:
	error = ""
	var definitions := _read_catalogue(catalogues, binding_id)
	if definitions.is_empty(): return false
	if saved.size() not in [3,4] or (saved.size()==4 and not saved.has("products")) or saved.get("base_content_id") != catalogues.content_id or saved.get("binding_id") != binding_id or not saved.get("entries") is Array:
		return reject("Blueprint progress has another content identity or an incomplete state")
	var entries: Array = saved.entries
	if entries.size() != definitions.ids.size():
		return reject("Blueprint progress lost a source recipe entry")
	for index in entries.size():
		var row: Variant = entries[index]
		var item_id: int = definitions.ids[index]
		if not row is Dictionary or row.size() not in [4,6] or not row.get("item_id") is int or row.item_id != item_id or not row.get("available") is bool or not row.get("material_value") is int or row.material_value < 0 or row.material_value > MAX_I32 or not row.get("remaining") is Array:
			return reject("Blueprint progress contains an invalid entry")
		if row.size()==6 and (not row.get("station_id") is int or row.station_id < -1 or row.station_id>=catalogues.tables.stations.size() or not row.get("completed") is int or row.completed<0 or row.completed>MAX_I32):return reject("Blueprint progress contains an invalid construction site")
		var remaining: Array = row.remaining
		if remaining.size() != definitions.recipes[item_id].quantities.size():
			return reject("Blueprint progress changed its source recipe extent")
		for amount in remaining:
			if not amount is int or amount < MIN_I32 or amount > MAX_I32:
				return reject("Blueprint progress contains an invalid material count")
	var products: Variant=saved.get("products",[])
	if not products is Array or products.size()>definitions.ids.size()*catalogues.tables.stations.size():return reject("Invalid retained blueprint products")
	var seen:={}
	for product in products:
		if not product is Dictionary or product.size()!=3 or not product.get("item_id") is int or not definitions.recipes.has(product.item_id) or not product.get("station_id") is int or product.station_id<0 or product.station_id>=catalogues.tables.stations.size() or not product.get("quantity") is int or product.quantity<1 or product.quantity>MAX_I32:return reject("Invalid retained blueprint product")
		var key:=str(product.item_id)+":"+str(product.station_id)
		if seen.has(key):return reject("Duplicate retained blueprint product")
		seen[key]=true
	_recipes = definitions.recipes
	_material_unit_value = definitions.material_unit_value
	_state = saved.duplicate(true)
	_station_count=catalogues.tables.stations.size()
	_state.products=products.duplicate(true)
	for row in _state.entries:
		if not row.has("station_id"):
			# Earlier native saves only allowed the story's partial prototype.
			row.station_id=10 if row.item_id==STORY_BLUEPRINT_ID and row.available and row.material_value>0 else -1
			row.completed=0
	return true


func snapshot() -> Dictionary:
	return _state.duplicate(true)


func entry(item_id: int) -> Dictionary:
	for row in _state.get("entries", []):
		if row.item_id == item_id: return row.duplicate(true)
	return {}


func fork_for_transaction() -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy._recipes = _recipes
	copy._material_unit_value = _material_unit_value
	copy._state = _state.duplicate(true)
	copy._station_count=_station_count
	return copy

func unlock(item_id: int) -> bool:
	error=""
	var before:=entry(item_id)
	if before.is_empty() or before.available:return reject("This blueprint is unknown or already owned")
	# Acquisition grants the recipe only, never materials or a finished product.
	for row in _state.entries:
		if row.item_id==item_id:
			row.available=true
			return true
	return reject("This blueprint has no retained recipe")

## A story mission hands over a recipe with some material already supplied at
## its station, and a later one takes the recipe back (progress is kept).
func story_grant(item_id: int,material_id: int,quantity: int,station_id: int) -> bool:
	error=""
	var index: int=_recipes.get(item_id,{}).get("material_ids",[]).find(material_id)
	if entry(item_id).is_empty() or index<0 or quantity<1 or station_id<0 or station_id>=_station_count:return reject("This story blueprint has no matching recipe")
	for row in _state.entries:
		if row.item_id!=item_id:continue
		row.available=true
		row.remaining[index]=maxi(0,int(row.remaining[index])-quantity)
		if row.station_id<0:row.station_id=station_id
	return true

## A story hands over a recipe only; no material is supplied.
func story_unlock(item_id: int) -> bool:
	error=""
	for row in _state.entries:
		if row.item_id==item_id:row.available=true;return true
	return reject("This story blueprint has no retained recipe")

## The story closes a construction site: blueprints being built at this
## station lose their supplied materials; the recipes stay owned.
func story_reset_station(station_id: int) -> bool:
	error=""
	if station_id<0 or station_id>=_station_count:return reject("The blueprint reset has no station")
	for row in _state.entries:
		if int(row.get("station_id",-1))!=station_id:continue
		row.remaining=_recipes[row.item_id].quantities.duplicate();row.material_value=0;row.station_id=-1
	return true

func story_lock(item_id: int) -> bool:
	error=""
	for row in _state.entries:
		if row.item_id==item_id:row.available=false;return true
	return reject("This story blueprint has no retained recipe")

func recipe(item_id: int) -> Dictionary:return _recipes.get(item_id,{}).duplicate(true)

func shipping_cost(item_id: int,station_id: int,quantity: int) -> int:
	return quote_shipping(entry(item_id),station_id,quantity)

static func quote_shipping(row: Dictionary,station_id: int,quantity: int) -> int:
	if row.is_empty() or quantity<1 or quantity>MAX_I32/SHIPPING_UNIT_COST:return -1
	var site: int=row.get("station_id",-1)
	return quantity*SHIPPING_UNIT_COST if site>=0 and site!=station_id else 0

## Inventory owns the debit and product insertion. Commit this owner and the
## returned inventory together, after the career has accepted the shipping fee.
func contribute(item_id: int,material_id: int,quantity: int,inventory: RefCounted) -> RefCounted:
	error=""
	if not is_instance_of(inventory,load("res://src/simulation/station_equipment.gd")):reject("Supply materials from the current Hangar inventory");return null
	var before:=entry(item_id);var owned: Dictionary=inventory.snapshot()
	if before.is_empty() or not before.available or quantity<1 or not owned.get("ordinary_shopping_open",false):reject("This blueprint is unavailable");return null
	for key in ["base_content_id","binding_id"]:
		if owned.loadout.get(key)!=_state.get(key):reject("Blueprint materials belong to another content source");return null
	var station: int=owned.loadout.station_id
	if station<0 or station>=_station_count:reject("Blueprint construction lost its station");return null
	var index: int=_recipes[item_id].material_ids.find(material_id)
	if index<0 or quantity>before.remaining[index]:reject("This quantity exceeds the blueprint's remaining requirement");return null
	var staged: RefCounted=inventory.fork()
	var value: int=staged.supply_blueprint_material(material_id,quantity)
	if value<0:reject(staged.error);return null
	if before.material_value>MAX_I32-value:reject("Blueprint material value exceeds its supported range");return null
	var next:=_state.duplicate(true)
	var row: Dictionary=next.entries.filter(func(candidate):return candidate.item_id==item_id)[0]
	row.remaining[index]-=quantity;row.material_value+=value
	if row.station_id<0:row.station_id=station
	if row.remaining.all(func(amount):return amount<=0):
		if row.completed==MAX_I32:reject("Blueprint completion count exceeds its supported range");return null
		var amount: int=_recipes[item_id].output_quantity
		if row.station_id==station:
			if not staged.receive_blueprint_product(item_id,amount):reject(staged.error);return null
		else:
			var pending: Array=next.products.filter(func(product):return product.item_id==item_id and product.station_id==row.station_id)
			if pending.is_empty():next.products.append({"item_id":item_id,"station_id":row.station_id,"quantity":amount})
			elif pending[0].quantity>MAX_I32-amount:reject("Blueprint output exceeds its supported range");return null
			else:pending[0].quantity+=amount
		row.completed+=1;row.station_id=-1;row.material_value=0;row.remaining=_recipes[item_id].quantities.duplicate()
	_state=next
	return staged

func collect(inventory: RefCounted) -> RefCounted:
	error=""
	if not is_instance_of(inventory,load("res://src/simulation/station_equipment.gd")):reject("Blueprint collection requires its inventory");return null
	var owned: Dictionary=inventory.snapshot()
	for key in ["base_content_id","binding_id"]:
		if owned.loadout.get(key)!=_state.get(key):reject("Blueprint collection belongs to another content source");return null
	var staged: RefCounted=inventory.fork();var kept:=[]
	for product in _state.products:
		if product.station_id!=owned.loadout.station_id:kept.append(product.duplicate(true));continue
		if not staged.receive_blueprint_product(product.item_id,product.quantity):reject(staged.error);return null
	_state=_state.duplicate(true);_state.products=kept
	return staged


## Invoke on a fork after staging the source's 50-crystal removal request.
## Inventory owns row selection; blueprint credit uses the requested quantity.
## expected_entry binds the proposal to the observed blueprint state; repeating
## the same proposal after this change is stale. Career owns once-only cursor33.
func precredit_story33(transaction: Dictionary) -> bool:
	error = ""
	if _state.is_empty() or transaction.size() != 7 or transaction.get("base_content_id") != _state.base_content_id or transaction.get("binding_id") != _state.binding_id or not transaction.get("from_cursor") is int or transaction.from_cursor != 33 or not transaction.get("to_cursor") is int or transaction.to_cursor != 34 or not transaction.get("item_id") is int or transaction.item_id != STORY_MATERIAL_ID or transaction.get("quantity") is not int or not transaction.get("expected_entry") is Dictionary:
		return reject("Blueprint credit requires the validated story33 final-Next transaction")
	if transaction.quantity != STORY_MATERIAL_QUANTITY:
		return reject("Blueprint credit requires the staged 50-crystal debit")
	var before := entry(STORY_BLUEPRINT_ID)
	if transaction.expected_entry != before:
		return reject("Blueprint credit proposal is stale")
	# The source's item85 branch is conditional. Valid native careers contain all
	# source recipes, but retain its harmless missing-entry behavior here.
	if before.is_empty(): return true
	var index: int = _recipes[STORY_BLUEPRINT_ID].material_ids.find(STORY_MATERIAL_ID)
	if index < 0: return reject("The source crystal recipe is unavailable")
	var material_value: int = STORY_MATERIAL_QUANTITY * _material_unit_value
	if before.remaining[index] < MIN_I32 + STORY_MATERIAL_QUANTITY or before.material_value > MAX_I32 - material_value:
		return reject("Blueprint material credit exceeds the source integer range")
	for row in _state.entries:
		if row.item_id == STORY_BLUEPRINT_ID:
			row.available = true
			row.remaining[index] -= STORY_MATERIAL_QUANTITY
			row.material_value += material_value
			if row.station_id<0:row.station_id=10
			return true
	return reject("Blueprint entry disappeared during the transaction")


func _read_catalogue(catalogues: RefCounted, binding_id: String) -> Dictionary:
	if not catalogues is Catalogues or not Library.valid_hash(catalogues.content_id) or not Library.valid_hash(binding_id):
		reject("Blueprint progress requires an imported item catalogue and binding identity")
		return {}
	var items: Variant = catalogues.tables.get("items")
	if not items is Array or items.size() <= STORY_MATERIAL_ID:
		reject("Blueprint progress requires the complete source item catalogue")
		return {}
	var ids := []
	var recipes := {}
	for item_id in items.size():
		var item: Variant = items[item_id]
		if not item is Dictionary or item.get("id") != item_id or not item.get("arrays") is Array or item.arrays.size() < 2 or not item.arrays[0] is PackedInt32Array or not item.arrays[1] is PackedInt32Array:
			reject("Blueprint progress received an invalid source item row")
			return {}
		var material_ids: Array = Array(item.arrays[0])
		if material_ids.is_empty(): continue
		var quantities: Array = Array(item.arrays[1])
		if material_ids.size() != quantities.size() or material_ids.size() > 64:
			reject("Blueprint progress received an invalid source recipe")
			return {}
		var seen := {}
		for index in material_ids.size():
			var material: Variant = material_ids[index]
			var quantity: Variant = quantities[index]
			if not material is int or material < 0 or material >= items.size() or seen.has(material) or not quantity is int or quantity < 1 or quantity > MAX_I32:
				reject("Blueprint progress received an invalid source material")
				return {}
			seen[material] = true
		ids.append(item_id)
		recipes[item_id] = {"material_ids": material_ids.duplicate(), "quantities": quantities.duplicate(),"output_quantity":10 if item.properties.get(1)==1 else 1}
	if not recipes.has(STORY_BLUEPRINT_ID):
		reject("The Khador Drive source recipe is missing")
		return {}
	var drive: Dictionary = recipes[STORY_BLUEPRINT_ID]
	if drive.material_ids.is_empty() or drive.material_ids[0] != STORY_MATERIAL_ID or drive.quantities[0] != STORY_MATERIAL_QUANTITY:
		reject("The Khador Drive crystal requirement changed")
		return {}
	var crystal: Dictionary = items[STORY_MATERIAL_ID]
	var properties: Variant = crystal.get("properties")
	if not properties is Dictionary or properties.get(7) != 400 or properties.get(8) != 400:
		reject("The source crystal material value changed")
		return {}
	return {"ids": ids, "recipes": recipes, "material_unit_value": 400}


func reject(message: String) -> bool:
	error = message
	return false
