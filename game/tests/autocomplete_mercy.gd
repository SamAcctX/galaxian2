extends SceneTree
## Android-only hangar and combat rules: blueprint shipping at 200 per unit,
## blueprint Autocomplete (BluePrint::getAutoCompletionPrice,
## HangarWindow::OnTouchEnd) and the mercy rule (MGame::gameOverCheck,
## Level::assignGuns). Detached from any journey; Mac content keeps 20 per
## unit and has neither autocomplete nor mercy.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Visuals=preload("res://src/content/visual_library.gd")
const Shopping=preload("res://src/content/ordinary_shopping_definitions.gd")
const Campaign=preload("res://src/content/free_campaign_definitions.gd")
const Blueprints=preload("res://src/simulation/blueprint_progress.gd")
const Equipment=preload("res://src/simulation/station_equipment.gd")
const Loadout=preload("res://src/simulation/opening_loadout.gd")
const Session=preload("res://src/simulation/contract_session.gd")
const Cache=preload("res://src/simulation/lounge_cache.gd")
const Random=preload("res://src/simulation/seeded_random.gd")
const HangarPanel=preload("res://src/presentation/station_equipment_panel.gd")
const Weapons=preload("res://src/simulation/opening_npc_weapons.gd")
const Shots=preload("res://src/simulation/ordinary_projectiles.gd")
const Player=preload("res://src/simulation/opening_player_state.gd")
const Combat=preload("res://src/simulation/opening_combat_group.gd")
const Wingmen=preload("res://src/simulation/wingman_actors.gd")
const Encounter=preload("res://src/simulation/full_hold_encounter.gd")
const Preview=preload("res://src/presentation/opening_preview.gd")
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const BLUEPRINTS={"shipping_unit_cost":200,"autocomplete":{"label":"Autocomplete","text_id":3392,"shortfall_text_id":192,"multiplier":1.25,"special_item_id":210,"special_add":2000000}}
const MERCY={"minimum_failures":3,"damage_factor":0.699999988079071}
## The imported catalogue (items.bin, equal on both editions): item -> [property 8, price].
const PRICES={33:[59,737],46:[3124,39050],85:[296082,370102],179:[7100,88750],232:[22000,275000]}
## FEATURES-4B 3a's vectors, applied to synthetic maximum prices: [type, property 8, price];
## 1573250 x 10 rounds in float32, 85313 x 10 x 1.25 truncates, 16777217 is not a float32.
const SYNTHETIC=[[1,101,1262],[1,4968,62100],[3,662923,828653],[1,85313,1066412],[1,1573250,19665624],[0,16777217,20971520]]
const SETTINGS={"difficulty":1.0,"valkyrie_owned":true,"supernova_owned":true,"energy_availability_percent":0,"missile_availability_percent":0,"ship_price_percent":0}
var checks:=0
var failures:=0
var emitted:=[]

class Body extends RefCounted:
	var hits:=[]
	func fork_for_frame() -> RefCounted:return self
	func read_snapshot() -> Dictionary:return {"actor_kind":8}
	func collision_context() -> Dictionary:return {"eligible":true}
	func normal_hit(amount: int,_nonplayer:=false) -> Dictionary:hits.append(amount);return {"destroyed_now":false}

class Group extends RefCounted:
	var actors:=[]
	func actor_snapshots() -> Array:return actors

class Flight extends RefCounted:
	var campaign:=false
	func encounter_owner() -> RefCounted:return self
	func campaign_mission() -> bool:return campaign

class Context extends RefCounted:
	var campaign:=false
	func advances_campaign() -> bool:return campaign

class Host extends Node3D:
	var flight: RefCounted
	func flight_owner() -> RefCounted:return flight

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Autocomplete, shipping and mercy: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func verify(args: PackedStringArray) -> void:
	var lib:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var visuals:=Visuals.new()
	if not lib.open(args[0]) or not bindings.open(args[1],lib.manifest) or not lib.select_language("gb") or not cat.open(lib) or not visuals.open(args[2],lib.manifest):check(false,lib.error+bindings.error+cat.error+visuals.error);return
	var android: bool=bindings.source_architecture=="android-armv7"
	check(Equal.equal_value(Shopping.blueprints(bindings),BLUEPRINTS if android else {}),"Hangar blueprint rules differ from the library's")
	check(Equal.equal_value(Weapons.mercy(bindings),MERCY if android else {}),"Mercy rules differ from the library's")
	check(Blueprints.shipping_unit(bindings)==(200 if android else 20),"Blueprint shipping unit cost differs from the library's")
	verify_prices(bindings,cat,android)
	verify_completion(bindings,cat,android)
	verify_session(bindings,cat,lib,android)
	verify_panel(bindings,cat,lib,visuals,android)
	verify_mercy(bindings,cat,lib,android)

## BluePrint::getAutoCompletionPrice: progress-free except for Chromo Plasma.
@warning_ignore("integer_division")
func verify_prices(bindings: RefCounted,cat: RefCounted,android: bool) -> void:
	var project:=Blueprints.new();check(project.configure(cat,bindings.binding_id),project.error)
	var shopping: Dictionary=bindings.mido_travel.ordinary_shopping;var items: Array=cat.tables.items
	if not android:
		for row in project.snapshot().entries:check(Blueprints.autocomplete_price(shopping,items,row)==-1,"A Mac blueprint has an autocompletion price")
		return
	for id in PRICES:
		check(int(items[id].properties.get(8))==PRICES[id][0],"Item %d changed its maximum price"%id)
		check(Blueprints.autocomplete_price(shopping,items,project.entry(id))==PRICES[id][1],"Item %d autocompletes for another price"%id)
	# float32: 15732500 x 1.25 rounds to 19665624; 853130 x 1.25 truncates 1066412.5.
	var synthetic: Array=items.duplicate()
	for row in SYNTHETIC:
		var item: Dictionary=items[232].duplicate(true);item.properties[1]=row[0];item.properties[8]=row[1];synthetic[232]=item
		check(Blueprints.autocomplete_price(shopping,synthetic,project.entry(232))==row[2],"Maximum price %d autocompletes for another price"%row[1])
	check(float(1573250*10)*1.25==19665625.0 and float(85313*10)*1.25==1066412.5,"The float32 rounding and truncation fixtures changed")
	var started:=project.entry(179);started.remaining[0]=0;started.station_id=4;started.material_value=99
	check(Blueprints.autocomplete_price(shopping,items,started)==PRICES[179][1],"Supplied materials changed an ordinary autocompletion price")
	var plasma:=project.entry(210);var recipe:=project.recipe(210);var index: int=recipe.material_ids.find(201)
	check(index>=0 and int(recipe.quantities[index])>=100,"Chromo Plasma lost its item-201 requirement")
	if index<0:return
	var single: int=int(items[201].properties[7])+(int(items[201].properties[8])-int(items[201].properties[7]))/2
	var fresh:=Blueprints.autocomplete_price(shopping,items,plasma)
	var value:=0
	for i in recipe.material_ids.size():value+=int(recipe.quantities[i])*(int(items[recipe.material_ids[i]].properties[7])+(int(items[recipe.material_ids[i]].properties[8])-int(items[recipe.material_ids[i]].properties[7]))/2)
	check(fresh==value+2000000 and fresh==2361298,"Fresh Chromo Plasma does not cost its ingredients plus 2000000")
	plasma.remaining[index]-=100
	check(Blueprints.autocomplete_price(shopping,items,plasma)==fresh-100*single,"Supplied Chromo Plasma ingredients kept their price")
	check(Blueprints.autocomplete_price({},items,project.entry(33))==-1 and Blueprints.autocomplete_price(shopping,items,{})==-1,"Autocomplete priced without its rule or blueprint")

## A detached open hangar at a station with nothing in the hold.
func hangar(bindings: RefCounted,cat: RefCounted,station_id: int,stock: Array=[]) -> RefCounted:
	var loadout:=Loadout.new()
	if not loadout.configure_station(bindings,cat,bindings.base_content_id):check(false,loadout.error);return null
	var seed: Dictionary=loadout.snapshot();seed.slots=seed.slots.map(func(_slot):return null)
	seed.station_id=station_id;seed.system_id=int(cat.tables.stations[station_id].system_id)
	var capacity:=int(cat.tables.ships[seed.ship_id].stats.cargo_capacity)
	var owned:=Equipment.new()
	owned._completion_prices=Equipment.prototype_prices(bindings,cat);owned._catalogue_size=cat.tables.items.size()
	owned._state={"loadout":seed,"cargo":{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"ship_id":seed.ship_id,"capacity":capacity,"entries":[],"used":0,"free_space":capacity},
		"cargo_cache_stale":false,"ordinary_shopping_open":true,"market_rows":stock.map(func(row):return {"item_id":row.item_id,"owned":0,"stock":row.quantity,"unit_price":row.unit_price,"mission":false}),
		"stock":stock.duplicate(true),"prices":{"cargo":[],"installed":[]},"credit_delta":0,"transactions":0,"training_inventory_released":true,"prototype_drill_replaced":true}
	return owned

func held(owner: RefCounted,item_id: int) -> int:
	var total:=0
	for row in owner.snapshot().cargo.entries:if row.item_id==item_id:total+=int(row.quantity)
	return total

## HangarWindow::OnTouchEnd and setSellMode: site, completion and the reset.
func verify_completion(bindings: RefCounted,cat: RefCounted,android: bool) -> void:
	var project:=Blueprints.new();check(project.configure(cat,bindings.binding_id),project.error)
	var here:=hangar(bindings,cat,10)
	if here==null:return
	var untouched: Dictionary=project.snapshot()
	check(project.autocomplete(33,here)==null and project.snapshot()==untouched,"A locked blueprint was autocompleted")
	check(project.unlock(33) and project.unlock(179),project.error)
	var closed: RefCounted=here.fork();closed._state.erase("ordinary_shopping_open")
	var before: Dictionary=project.snapshot()
	check(project.autocomplete(33,closed)==null and project.snapshot()==before,"Autocomplete ran with the hangar closed")
	# An empty blueprint is built here: ten secondaries in the hold.
	var staged: RefCounted=project.fork_for_transaction()
	var built: RefCounted=staged.autocomplete(33,here)
	check(built!=null and held(built,33)==10 and held(here,33)==0,"An empty blueprint did not deliver ten secondaries here: "+staged.error)
	check(project.snapshot()==before,"Autocomplete changed the parent blueprint state")
	var row: Dictionary=staged.entry(33)
	check(row.completed==1 and row.station_id==-1 and row.material_value==0 and row.remaining==project.recipe(33).quantities and staged.snapshot().products.is_empty(),"The built blueprint was not reset")
	# A blueprint started elsewhere waits there, unshipped.
	var saved: Dictionary=project.snapshot()
	for entry in saved.entries:
		if entry.item_id==179:entry.station_id=5;entry.material_value=400;entry.remaining[0]-=1
	var remote:=Blueprints.new();check(remote.restore(cat,bindings.binding_id,saved),remote.error)
	built=remote.autocomplete(179,here)
	check(built!=null and held(built,179)==0 and remote.snapshot().products==[{"item_id":179,"station_id":5,"quantity":10}] and remote.entry(179).completed==1 and remote.entry(179).station_id==-1,"A remote blueprint did not wait at its site")
	# A story grant sets a site without invested value; it is not empty (BluePrint::addItem).
	var granted: RefCounted=project.fork_for_transaction()
	check(granted.story_grant(85,164,50,10) and granted.entry(85).material_value==0,granted.error)
	built=granted.autocomplete(85,hangar(bindings,cat,5))
	check(built!=null and held(built,85)==0 and granted.snapshot().products==[{"item_id":85,"station_id":10,"quantity":1}],"A story-granted site moved to the current station")
	# The cursor-33 Khador Drive credit keeps working with autocomplete.
	var drive: RefCounted=project.fork_for_transaction()
	var credit:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"from_cursor":33,"to_cursor":34,"item_id":164,"quantity":50,"expected_entry":drive.entry(85)}
	check(drive.precredit_story33(credit),drive.error)
	var at_site: RefCounted=drive.fork_for_transaction()
	built=at_site.autocomplete(85,here)
	check(built!=null and held(built,85)==1 and at_site.entry(85).completed==1 and at_site.entry(85).remaining==project.recipe(85).quantities,"The credited Khador Drive was not built at Thynome")
	credit.expected_entry=at_site.entry(85)
	check(at_site.precredit_story33(credit) and at_site.entry(85).station_id==10,"A built Khador Drive blocked the story credit")

## contract_session: Yes pays the price or is refused (text 192 in the panel);
## shipping costs the import's unit cost.
func verify_session(bindings: RefCounted,cat: RefCounted,lib: RefCounted,android: bool) -> void:
	var cursor:=-1
	for value in [23,24,27,28,32,39,40,42,50]:
		if Campaign.supported(bindings,value):cursor=value;break
	check(cursor>=0,"No supported ordinary cursor for the hangar session")
	var cache:=Cache.new();check(cache.configure(bindings),cache.error)
	var random:=Random.new();random.seed_from(5)
	var career:={"campaign_cursor":cursor,"station_id":10,"rank":0,"reputation":{"axes":[0,0],"override":-1}}
	if cursor<0 or not cache.select_location(bindings,cat,lib,career,SETTINGS,random.snapshot(),1789100000):check(false,cache.error);return
	var project:=Blueprints.new();check(project.configure(cat,bindings.binding_id) and project.unlock(33),project.error)
	var shopping: Dictionary=bindings.mido_travel.ordinary_shopping
	var price: int=Blueprints.autocomplete_price(shopping,cat.tables.items,project.entry(33))
	var session:=Session.new();session._lounges=cache;session._blueprints=project
	session._state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":cursor,"progress":{"campaign_cursor":cursor},"station_id":10,"credits":maxi(0,price-1),"mission":{}}
	var stock: Array=cache.item_stock(10)
	var inventory:=hangar(bindings,cat,10,stock)
	if inventory==null:return
	var before: Dictionary=project.snapshot()
	check(session.transact_shopping(bindings,cat,inventory,"autocomplete_blueprint",33)==null and session._state.credits==maxi(0,price-1) and session.blueprint_state()==before,"Too few credits autocompleted a blueprint")
	if android:
		session._state.credits=price
		var bought: RefCounted=session.transact_shopping(bindings,cat,inventory,"autocomplete_blueprint",33)
		check(bought!=null and session._state.credits==0 and held(bought,33)==10 and session.blueprint_state().entries.filter(func(row):return row.item_id==33)[0].completed==1,"Autocomplete did not charge its price: "+session.error)
	else:
		session._state.credits=1000000000
		check(session.transact_shopping(bindings,cat,inventory,"autocomplete_blueprint",33)==null and session._state.credits==1000000000,"A Mac hangar autocompleted a blueprint")
	# Shipping two units to a blueprint started at Var Hastra (station 5).
	var saved: Dictionary=project.snapshot();var material: int=int(project.recipe(33).material_ids[0])
	for entry in saved.entries:
		if entry.item_id==33:entry.station_id=5;entry.material_value=1
	var started:=Blueprints.new();check(started.restore(cat,bindings.binding_id,saved),started.error)
	session._blueprints=started;session._state.credits=1000
	var owned:=hangar(bindings,cat,10,stock)
	var rows: Array=owned._state.market_rows.filter(func(row):return row.item_id==material)
	if rows.is_empty():owned._state.market_rows.append({"item_id":material,"owned":2,"stock":0,"unit_price":10,"mission":false})
	else:rows[0].owned=2
	owned._state.cargo.entries=[{"item_id":material,"quantity":2}];owned._state.cargo.used=2;owned._state.cargo.free_space-=2;owned._state.prices.cargo=[{"item_id":material,"unit_price":10}]
	var supplied: RefCounted=session.transact_shopping(bindings,cat,owned,"supply_blueprint",33,material,2)
	check(supplied!=null and session._state.credits==1000-2*(200 if android else 20),"Blueprint shipping charged another unit cost: "+session.error)
	check(Blueprints.quote_shipping({"station_id":5},10,3,Blueprints.shipping_unit(bindings))==3*(200 if android else 20) and Blueprints.quote_shipping({"station_id":10},10,3,200)==0 and Blueprints.quote_shipping({"station_id":5},10,3)==60,"Shipping quotes differ")

## The hangar's blueprint page: the Autocomplete row, its question and refusal.
func verify_panel(bindings: RefCounted,cat: RefCounted,lib: RefCounted,visuals: RefCounted,android: bool) -> void:
	var panel:=HangarPanel.new();root.add_child(panel);root.size=Vector2i(1280,720)
	if not panel.configure(lib,bindings,visuals):check(false,panel.error);panel.free();return
	panel.blueprint_action_requested.connect(func(action,item_id,material_id,quantity):emitted.append([action,item_id,material_id,quantity]))
	var project:=Blueprints.new();check(project.configure(cat,bindings.binding_id) and project.unlock(33),project.error)
	var saved: Dictionary=project.snapshot()
	for entry in saved.entries:
		if entry.item_id==33:entry.station_id=5;entry.material_value=1
	var inventory:=hangar(bindings,cat,10)
	var material: int=int(project.recipe(33).material_ids[0])
	inventory._state.market_rows=[{"item_id":material,"owned":3,"stock":0,"unit_price":10,"mission":false}]
	inventory._state.cargo.entries=[{"item_id":material,"quantity":3}];inventory._state.cargo.used=3;inventory._state.cargo.free_space-=3
	var price: int=PRICES[33][1]
	var state:={"hangar_open":true,"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"language":lib.active_language,
		"equipment":inventory.snapshot(),"contracts":{"credits":price-1,"blueprints":saved}}
	check(panel.present(state),panel.error)
	panel.select_tab("blueprints")
	var buttons: Array=panel._blueprint_list.find_children("*","Button",true,false).filter(func(button):return button.text=="Autocomplete")
	check(buttons.size()==(1 if android else 0),"The blueprint page shows Autocomplete on the wrong edition")
	# The supply question quotes the import's shipping fee.
	panel._supply_blueprint(33,material,3)
	check(panel._replacement.dialog_text==lib.strings[277].replace("#S",cat.tables.stations[5].name).replace("#C","%d$"%(3*(200 if android else 20))),"The shipping question quotes another fee")
	panel._pending_replace={};panel._refresh()
	if not android:panel.free();return
	buttons[0].pressed.emit()
	check(panel._replacement.dialog_text==lib.strings[3392].replace("#C","%d$"%price) and panel._pending_replace.get("price")==price,"Autocomplete asks another question")
	panel._confirm_replacement()
	check(emitted.is_empty() and panel._message.text==lib.strings[192].replace("#C","1$"),"Too few credits did not show the shortfall")
	state.contracts.credits=price;check(panel.present(state),panel.error)
	panel._autocomplete_blueprint(33);panel._confirm_replacement()
	check(emitted==[["autocomplete_blueprint",33,-1,1]],"Yes did not request the autocompletion")
	panel.free()

## MGame::gameOverCheck counts campaign deaths; Level::assignGuns weakens the
## enemy guns of a campaign mission at that cursor after three.
func verify_mercy(bindings: RefCounted,cat: RefCounted,lib: RefCounted,android: bool) -> void:
	Weapons.campaign_failures={"cursor":-1,"count":0}
	var counts:=[]
	for cursor in [12,12,13,13,13,12]:
		Weapons.record_campaign_failure(bindings,cursor);counts.append(Weapons.campaign_failures.duplicate())
	if android:check(counts.map(func(row):return [row.cursor,row.count])==[[12,1],[12,2],[13,1],[13,2],[13,3],[12,1]],"Campaign failures counted differently")
	else:check(Weapons.campaign_failures=={"cursor":-1,"count":0},"A Mac death counted for mercy")
	# The host counts acknowledged deaths of campaign missions only.
	var preview:=Preview.new();var host:=Host.new();host.flight=Flight.new();preview.bindings=bindings;preview.session=host
	var death:={"campaign_cursor":30,"player_destruction":{"phase":"game_over","exit_requested":true}}
	Weapons.campaign_failures={"cursor":-1,"count":0}
	preview._record_campaign_failure(death)
	host.flight.campaign=true
	for phase in [["game_over_fade",false],["game_over",false],["explosion",true]]:preview._record_campaign_failure({"campaign_cursor":30,"player_destruction":{"phase":phase[0],"exit_requested":phase[1]}})
	check(Weapons.campaign_failures=={"cursor":-1,"count":0},"A side flight or an unacknowledged death counted")
	preview._record_campaign_failure(death);preview._record_campaign_failure(death)
	check(Weapons.campaign_failures==({"cursor":30,"count":2} if android else {"cursor":-1,"count":0}),"A campaign death was not counted")
	host.free();preview.free()
	# The guns: the training rows plus a damage-20 copy (float32: 20 x 0.7f = 14, not 13).
	var rows: Array=bindings.combat_training_weapons.npc_weapons.duplicate(true)
	var extra: Dictionary=rows[3].duplicate(true);extra.actor_id=4;extra.damage=20;rows.append(extra)
	var guns:=Weapons.new()
	if not guns._configure_rows(bindings,cat,rows,7):check(false,guns.error);return
	var declared: Array=guns.snapshot().actors.map(func(row):return row.projectiles.weapon.damage)
	for failures_case in [{"cursor":7,"count":2},{"cursor":8,"count":3}]:
		Weapons.campaign_failures=failures_case
		var copy: RefCounted=guns.fork_for_frame()
		check(copy.apply_mercy(bindings,7,[0,1,2,3,4]) and not copy.snapshot().actors.any(func(row):return row.projectiles.weapon.has("mercy_damage")),"Mercy applied below three failures or at another cursor")
	Weapons.campaign_failures={"cursor":7,"count":3}
	var weak: RefCounted=guns.fork_for_frame()
	check(weak.apply_mercy(bindings,7,[0,3,4]),weak.error)
	var mercy: Array=weak.snapshot().actors.map(func(row):return row.projectiles.weapon.get("mercy_damage",-1))
	check(mercy==([0,-1,-1,2,14] if android else [-1,-1,-1,-1,-1]),"Enemy guns were weakened differently: "+str(mercy))
	check(weak.snapshot().actors.map(func(row):return row.projectiles.weapon.damage)==declared,"Mercy changed the declared damage")
	Weapons.campaign_failures={"cursor":7,"count":4}
	check(guns.fork_for_frame().apply_mercy(bindings,7,[4]),"More failures stopped the mercy rule")
	if not android:return
	for bad in [-1,21,1.5]:
		var forged: Dictionary=weak.snapshot().actors[4].projectiles.weapon;forged.mercy_damage=bad
		check(not Shots.new().configure(forged),"Invalid mercy damage configured a gun")
	verify_hits(bindings,weak.snapshot().actors[3].projectiles.weapon)
	verify_encounter(bindings,cat,lib,rows.slice(0,4))
	Weapons.campaign_failures={"cursor":-1,"count":0}

## Every owner hit by a weakened gun takes its mercy damage.
func verify_hits(bindings: RefCounted,shot: Dictionary) -> void:
	var player:=Player.new()
	player._state={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"vitals":{"hull":1000,"armor":0,"shield":0},"active":true,"damage_allowed":true}
	player._hit_policy=bindings.weapon_parameters.player_hit_policy
	player._npc_weapons=[{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"launch_mode":"ordinary","item_id":shot.item_id,"category":shot.category,"kind":shot.kind,"damage":shot.damage,"campaign_cursor":7,"nonplayer_source":true}]
	var full: Dictionary=shot.duplicate(true);full.erase("mercy_damage")
	check(shot.damage==3 and shot.mercy_damage==2,"The hit fixture is not the weakened Gunant gun")
	check(not player.weapon_hit(shot,true,true,false).is_empty() and player._state.vitals.hull==998,"The player took more than the mercy damage: "+player.error)
	check(not player.weapon_hit(full,true,true,false).is_empty() and player._state.vitals.hull==995,"An ordinary gun lost its damage")
	var group:=Combat.new();var body:=Body.new()
	group._identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id};group._hit_policy=bindings.weapon_parameters.ordinary_hit_policy
	group._training_weapons=bindings.combat_training_weapons;group._actors=[body]
	check(not group.weapon_hit(0,shot).is_empty() and not group.weapon_hit(0,full).is_empty() and body.hits==[2,3],"An NPC took other damage: "+group.error)
	var companions:=Wingmen.new();var pilot:=Body.new()
	companions._incoming_declarations=[shot,full];companions._actors=[pilot]
	check(not companions.weapon_hit(0,shot).is_empty() and not companions.weapon_hit(0,full).is_empty() and pilot.hits==[2,3],"A companion took other damage: "+companions.error)

## The encounter weakens a campaign mission's enemy guns and remembers it.
func verify_encounter(bindings: RefCounted,cat: RefCounted,lib: RefCounted,rows: Array) -> void:
	var combat:=Group.new();combat.actors=[{"actor_id":0,"hostile":false},{"actor_id":3,"hostile":true}]
	var identity:={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":7}
	for campaign in [false,true]:
		var guns:=Weapons.new()
		if not guns._configure_rows(bindings,cat,rows,7):check(false,guns.error);return
		var encounter:=Encounter.new()
		check(encounter._accept_configuration(bindings,lib,identity,null,combat,guns,null,null,null,null,false,campaign),encounter.error)
		check(encounter.campaign_mission()==campaign and encounter.fork_for_frame().campaign_mission()==campaign,"The encounter lost its campaign mission")
		var mercy: Array=encounter._weapons.snapshot().actors.map(func(row):return row.projectiles.weapon.get("mercy_damage",-1))
		check(mercy==([-1,-1,-1,2] if campaign else [-1,-1,-1,-1]),"The encounter weakened other guns: "+str(mercy))
	var job:=Context.new();var story:=Context.new();story.campaign=true
	check(not Encounter.campaign_cast({"ordinary_void":true},{}) and Encounter.campaign_cast({"actors":[]},{}) and Encounter.campaign_cast({"mission_context":story},{}) and not Encounter.campaign_cast({"mission_context":job},{}),"Story casts classified differently")
	check(Encounter.campaign_cast({},{"free_context":{"mission_story":true}}) and not Encounter.campaign_cast({},{"free_context":{"mission_story":false}}) and not Encounter.campaign_cast({},{}),"Ordinary traffic classified differently")
