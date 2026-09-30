extends RefCounted
## Most Wanted boards (Supernova): criminals from the imported list, their
## travel between stations, and the board rules. The career keeps the state
## in progress "wanted" = {entries: [{active, dead, surrendered, at, to, from,
## stats}], bounties: [per board]}. Stations are catalogue station ids.
##
## - A board (race 0 Terran .. 3 Midorian) is open at stations of that race
##   once the cursor reaches one of its entries' required mission.
## - Docking there activates each entry of the board whose required mission
##   is reached (story entries 0 and 1: exactly at it) and whose tier is
##   unlocked (that board's kills >= its required bounties). It is placed on
##   a route between two stations of known systems; the route's length in
##   systems is bounded per entry.
## - Each departure moves every active criminal one system along his route
##   (arriving at the destination's gate station, then the station itself);
##   at the destination he picks a new one.
## - Flying at his current station meets him. Story entries surrender below a
##   third of their hull; others are killed for the bounty.
const Random=preload("res://src/simulation/seeded_random.gd")
## Systems never on a criminal's route (Wolf-Reiser and the expansion's
## Loma, Shima, Ginoya and Talidor).
const EXCLUDED_SYSTEMS:=[6,25,26,27,28]
## No board at this station.
const CLOSED_STATION:=108
const STORY_ENTRIES:=2
const PLACE_ATTEMPTS:=200
const RANK_HULL:=15
const RANK_HULL_CAP:=300
const CURSOR_HULL:=4
const WON_HULL:=180
const SURRENDER_DIVISOR:=3

static func fresh(table: Array) -> Dictionary:
	var entries:=[]
	for row in table:entries.append({"active":false,"dead":false,"surrendered":false,"at":-1,"to":-1,"from":-1})
	return {"entries":entries,"bounties":[0,0,0,0]}

static func valid(state: Variant,table: Array) -> bool:
	return state is Dictionary and state.get("entries") is Array and state.entries.size()==table.size() and state.get("bounties") is Array and state.bounties.size()==4

static func system_of(cat: RefCounted,station_id: int) -> int:
	if station_id<0 or station_id>=cat.tables.stations.size():return -1
	return int(cat.tables.stations[station_id].system_id)

static func race_of(cat: RefCounted,station_id: int) -> int:
	var system:=system_of(cat,station_id)
	return -1 if system<0 else int(cat.tables.systems[system].fields[2])

## True when this station shows a board: its race has an entry whose
## required mission the cursor has reached.
static func accessible(table: Array,cat: RefCounted,cursor: int,station_id: int) -> bool:
	if station_id<0 or station_id==CLOSED_STATION:return false
	var race:=race_of(cat,station_id)
	return table.any(func(row):return int(row.board)==race and cursor>=int(row.required_mission))

## Entry indices listed on this station's board.
static func listed(table: Array,cat: RefCounted,station_id: int) -> Array:
	var race:=race_of(cat,station_id)
	return range(table.size()).filter(func(index):return int(table[index].board)==race)

## Activate the entries this docking unlocks. Returns the new state and the
## newly activated indices.
static func activate(state: Dictionary,table: Array,cat: RefCounted,cursor: int,station_id: int,known: Array,seed_value: int) -> Dictionary:
	var next: Dictionary=state.duplicate(true);var activated:=[]
	if station_id==CLOSED_STATION:return {"state":next,"activated":activated}
	var race:=race_of(cat,station_id)
	var random:=Random.new();random.seed_from(seed_value)
	for index in table.size():
		var row: Dictionary=table[index];var entry: Dictionary=next.entries[index]
		if int(row.board)!=race or entry.active or entry.dead or entry.surrendered:continue
		if (cursor!=int(row.required_mission) if index<STORY_ENTRIES else cursor<int(row.required_mission)):continue
		if int(next.bounties[int(row.board)])<int(row.required_bounties):continue
		var placed:=_place(cat,known,index,random)
		if placed.is_empty():continue
		entry.merge(placed,true);entry.active=true
		entry.stats={"name":row.name,"ship":int(row.ship),"race":int(row.race),"weapon":int(row.weapon),"hull":int(row.hull),
			"loot":[int(row.loot_item),int(row.loot_amount)],"reward":int(row.reward),"wingmen":int(row.wingmen),"board":int(row.board),"tier":int(row.required_bounties)}
		activated.append(index)
	return {"state":next,"activated":activated}

## One departure: every active criminal moves one step (not while he sits
## at the player's station).
static func travel(state: Dictionary,cat: RefCounted,player_station: int,known: Array,seed_value: int) -> Dictionary:
	var next: Dictionary=state.duplicate(true)
	var random:=Random.new();random.seed_from(seed_value)
	for index in next.entries.size():
		var entry: Dictionary=next.entries[index]
		if not entry.active or entry.dead or int(entry.at)<0 or int(entry.at)==player_station:continue
		if int(entry.at)==int(entry.to):
			var route:=_route_from(cat,known,index,int(entry.at),random)
			if not route.is_empty():entry.from=int(entry.at);entry.to=int(route.to)
			continue
		var here:=system_of(cat,int(entry.at));var there:=system_of(cat,int(entry.to))
		if here==there:entry.at=int(entry.to);continue
		var path:=_path(cat,known,here,there)
		if path.size()<2:entry.at=int(entry.to);continue
		var gate:=int(cat.tables.systems[path[1]].fields[6])
		entry.at=gate if gate>=0 else int(cat.tables.systems[path[1]].station_ids[0])
	return next

## The active criminal at this station (the lowest tier first), or -1.
static func criminal_at(state: Variant,station_id: int) -> int:
	if not state is Dictionary or not state.get("entries") is Array:return -1
	var found:=-1
	for index in state.entries.size():
		var entry: Dictionary=state.entries[index]
		if entry.active and not entry.dead and int(entry.at)==station_id:
			if found<0 or int(entry.stats.get("tier",0))<int(state.entries[found].stats.get("tier",0)):found=index
	return found

## His hull: rank, file hull and story progress, times the difficulty scale.
static func spawn_hull(stats: Dictionary,rank: int,cursor: int,won: bool,difficulty: float) -> int:
	return int(float(mini(rank*RANK_HULL,RANK_HULL_CAP)+int(stats.hull)+(WON_HULL if won else cursor*CURSOR_HULL))*(difficulty+0.5))

static func killed(state: Dictionary,index: int) -> Dictionary:
	var next: Dictionary=state.duplicate(true);var entry: Dictionary=next.entries[index]
	if entry.dead:return next
	entry.dead=true;entry.active=false
	var board:=int(entry.get("stats",{}).get("board",0))
	next.bounties[board]=int(next.bounties[board])+1
	return next

static func surrendered(state: Dictionary,index: int) -> Dictionary:
	var next: Dictionary=state.duplicate(true);var entry: Dictionary=next.entries[index]
	entry.surrendered=true;entry.active=false
	return next

## Route length bounds (systems on the path, both ends counted).
static func _bounds(index: int) -> Vector2i:
	if index<STORY_ENTRIES:return Vector2i(2,4)
	@warning_ignore("integer_division")
	var k:=(index-1)%6
	@warning_ignore("integer_division")
	return Vector2i(k/3+2,k/2+4)

static func _allowed(cat: RefCounted,known: Array,system: int) -> bool:
	return system>=0 and system<known.size() and known[system]==true and not EXCLUDED_SYSTEMS.has(system) and not cat.tables.systems[system].linked_system_ids.is_empty()

static func _stations(cat: RefCounted,system: int) -> Array:
	return Array(cat.tables.systems[system].station_ids).filter(func(id):return int(id)!=CLOSED_STATION)

static func _place(cat: RefCounted,known: Array,index: int,random: RefCounted) -> Dictionary:
	var systems: Array=range(cat.tables.systems.size()).filter(func(id):return _allowed(cat,known,id) and not _stations(cat,id).is_empty())
	if systems.size()<2:return {}
	for attempt in PLACE_ATTEMPTS:
		var a: int=systems[random.next_int(systems.size())]
		var from_stations:=_stations(cat,a)
		var start: int=from_stations[random.next_int(from_stations.size())]
		var route:=_route_from(cat,known,index,start,random)
		if route.is_empty():continue
		var path: Array=route.path;var stop: int=path[random.next_int(path.size())]
		var stops:=_stations(cat,stop)
		return {"from":start,"to":int(route.to),"at":int(stops[random.next_int(stops.size())])}
	return {}

## A destination station in another allowed system whose path length fits.
static func _route_from(cat: RefCounted,known: Array,index: int,start: int,random: RefCounted) -> Dictionary:
	var bounds:=_bounds(index);var origin:=system_of(cat,start)
	var systems: Array=range(cat.tables.systems.size()).filter(func(id):return id!=origin and _allowed(cat,known,id) and not _stations(cat,id).is_empty())
	for attempt in PLACE_ATTEMPTS:
		if systems.is_empty():return {}
		var b: int=systems[random.next_int(systems.size())]
		var path:=_path(cat,known,origin,b)
		if path.size()<bounds.x or path.size()>bounds.y:continue
		var stations:=_stations(cat,b)
		return {"to":int(stations[random.next_int(stations.size())]),"path":path}
	return {}

## Breadth-first system path through allowed systems, both ends included.
static func _path(cat: RefCounted,known: Array,from_system: int,to_system: int) -> Array:
	if from_system==to_system:return [from_system]
	var previous:={from_system:-1};var frontier:=[from_system]
	while not frontier.is_empty():
		var next:=[]
		for system in frontier:
			for link in cat.tables.systems[system].linked_system_ids:
				var id:=int(link)
				if previous.has(id) or not (_allowed(cat,known,id) or id==to_system):continue
				previous[id]=system
				if id==to_system:
					var path:=[id]
					while int(previous[path[0]])>=0:path.push_front(int(previous[path[0]]))
					return path
				next.append(id)
		frontier=next
	return []
