extends RefCounted
## Parked ships in the station hangar (Level::createScene, verified). Each
## hangar row has fixed pads; a docking parks 0..pads ships (uniform), each on
## a free pad at the pad + its own hangar height, turned 0-3 rad about y,
## asleep with engines off. A ship is a fighter of the hangar's race, or (30%)
## of a random race 0-3, of which 30% become pirates. Station 100 parks ships
## 37, 38 or 40. An owned Kaamo Club (108) parks the player's stored ships
## instead, in storage order, up to its pads.
const Kaamo=preload("res://src/content/kaamo_club_definitions.gd")
const PADS:={0:[Vector3(0,0,2891),Vector3(0,0,5781)],
	1:[Vector3(-3715,0,661),Vector3(-6983,36,2548),Vector3(-9408,36,5438),Vector3(-9408,36,16301),Vector3(-6983,36,19191),
		Vector3(-3715,36,21078),Vector3(-9408,5359,16301),Vector3(-6983,5359,19191),Vector3(-3715,5359,21078)],
	2:[Vector3(4096,0,0),Vector3(4096,0,4096)],
	3:[Vector3(-4096,0,0),Vector3(0,0,4096),Vector3(-4096,0,4096)],
	7:[Vector3(-1961,0,8512),Vector3(-1961,0,5562),Vector3(-1961,0,2610)]}
## Fighters a race parks (Globals::getRandomEnemyFighter over ships 0-36).
const FIGHTERS:={0:[1,5,7,17,22,26,27,28,33,34,36],2:[4,12,16,18,21,31,35],3:[3,6,19,20,30],8:[2,11,23,24,25,29,32]}
## Vossk park ship 9; after Valkyrie is won (cursor 84+) 25% 41 and 15% 39.
const VOSSK:=9
const VOSSK_AFTER:=[[60,9],[85,41],[100,39]]
const VALKYRIE_WON_CURSOR:=84
const STATION_100:=[37,38,40]

## [{ship_id, position, rotation_y}] for this docking. roll(n) returns 0..n-1.
static func choose(row: int,station_id: int,cursor: int,progress: Dictionary,roll: Callable) -> Array:
	var pads: Array=PADS.get(row,[])
	if pads.is_empty():return []
	var stored: Array=[]
	if station_id==Kaamo.STATION_ID and Kaamo.state(progress)==Kaamo.OWNED:
		stored=progress.get("kaamo_storage",{}).get("ships",[]).map(func(entry):return int(entry.ship_id))
	var count: int=mini(stored.size(),pads.size()) if station_id==Kaamo.STATION_ID and Kaamo.state(progress)==Kaamo.OWNED else int(roll.call(pads.size()+1))
	var free:=range(pads.size());var result:=[]
	for index in count:
		var ship: int=int(stored[index]) if not stored.is_empty() else _fighter(row,station_id,cursor,roll)
		var pad: int=free.pop_at(int(roll.call(free.size())))
		result.append({"ship_id":ship,"position":pads[pad],"rotation_y":float(roll.call(300))/100.0})
	return result

static func _fighter(row: int,station_id: int,cursor: int,roll: Callable) -> int:
	var race:=row
	if int(roll.call(100))<30:
		race=int(roll.call(4))
		if int(roll.call(100))<30:race=8
	if station_id==100:return int(STATION_100[int(roll.call(3))])
	if race==1:
		if cursor<VALKYRIE_WON_CURSOR:return VOSSK
		var draw:=int(roll.call(100))
		for band in VOSSK_AFTER:
			if draw<int(band[0]):return int(band[1])
	var ships: Array=FIGHTERS.get(race if race in FIGHTERS else 8,[])
	return int(ships[int(roll.call(ships.size()))])
