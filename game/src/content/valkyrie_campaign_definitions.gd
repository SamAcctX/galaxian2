extends RefCounted
## Valkyrie expansion story: the mission each campaign cursor starts and the
## station conversations that finish talk missions. The story continues from a
## finished main career (cursor 45); Valkyrie is won once the cursor passes 83.
const Dialogue=preload("res://src/content/valkyrie_dialogue_definitions.gd")
const Epilogue=preload("res://src/content/campaign_epilogue_definitions.gd")
const FIRST_CURSOR:=45
const LAST_CURSOR:=83
const TALK:=11
## Systems revealed when a conversation is acknowledged. The original reveals
## Herjaza and Skavac as missions 55 and 63 begin; Loma is visible to every
## expansion owner, so a continued career receives it with the first call.
const UNLOCKS:={45:[25],54:[23],62:[24]}
## Ship changes applied as the story enters a cursor: a loaned hull with its
## fitted items [item, slot], or the owned ship handed back.
const SHIPS:={
	48:{"ship_id":9,"equipment":[[58,0],[83,1]],"store":true},
	49:{"ship_id":41,"equipment":[[177,0],[177,1],[177,2],[58,0],[83,1],[52,2]],"store":false},
	55:{"restore":true},
	56:{"ship_id":39,"equipment":[[181,0],[52,0],[58,1],[83,2]],"store":true},
	58:{"restore":true},
}
## Kind 166 finishes docked at its station with the goods in the hold (or the
## item fitted); the goods stay with the player (assumption: no removal found).
const GOODS_KIND:=166
## Kinds whose target is an ordinary station you dock at and leave: talks, goods,
## convoy hunts (finished elsewhere) and the 10 s flight (164).
const STATION_KINDS:=[11,163,164,166]
const GOODS:={58:{"item_id":179,"quantity":10}}
## Blueprints handed over as the story enters a cursor: mission 58 grants item
## 179 with 5 of material 127 already supplied at the Valkyrie; 59 takes it back.
const BLUEPRINTS:={58:{"item_id":179,"grant":true,"material_id":127,"quantity":5,"station_id":101},59:{"item_id":179,"grant":false}}
## Talks paying extra per story-counter kill (60: 50000 x (Liberator kills + 1)).
## The counter and cleared-station mask end with that talk.
const COUNTER_REWARD:={60:50000}
## cursor: [kind, reward, station]; -1 station means any station.
const MISSIONS:={
	47:[11,0,74],48:[11,0,58],49:[156,0,58],50:[156,0,62],51:[156,0,25],52:[160,0,25],
	54:[11,200000,74],55:[11,0,101],56:[4,0,102],57:[11,150000,101],58:[166,0,101],59:[163,0,101],
	60:[11,50000,101],61:[164,0,101],62:[11,0,100],63:[4,0,103],64:[4,0,104],65:[11,0,100],
	66:[11,0,101],67:[4,0,104],68:[8,0,66],69:[6,0,66],70:[6,0,65],71:[11,0,66],
	72:[164,150000,101],73:[10,0,81],74:[11,0,100],75:[11,0,100],76:[11,0,100],77:[11,0,101],
	78:[4,0,101],79:[165,0,-1],80:[1,0,100],81:[4,0,-1],82:[11,0,100],83:[11,0,100],
}

## The pack must carry the App Store campaign tables these rows were read from.
static func available(bindings: RefCounted) -> bool:
	return Epilogue.available(bindings)

static func mission(cursor: int) -> Dictionary:
	if cursor==53:cursor=54
	if not MISSIONS.has(cursor):return {}
	var row: Array=MISSIONS[cursor]
	return {"kind":row[0],"station_id":row[2],"reward":row[1],"bonus":0,"source_parameter":0}

static func next_cursor(cursor: int) -> int:
	return 54 if cursor==52 else cursor+1

## Station conversations. A finished main career takes the expansion's incoming
## call at whichever station it is docked in; talk missions play their authored
## result at the target station.
static func conversation(bindings: RefCounted,cursor: Variant,story_mission: Variant) -> Dictionary:
	if not cursor is int or not story_mission is Dictionary or not available(bindings):return {}
	if cursor==FIRST_CURSOR:
		if int(story_mission.get("kind",0))!=-1:return {}
		return _rules(cursor,story_mission,47,Dialogue.events(Dialogue.RESULT,46),false)
	var expected:=mission(cursor)
	if expected.is_empty() or int(expected.kind) not in [TALK,GOODS_KIND] or not _same(story_mission,expected):return {}
	var next:=next_cursor(cursor)
	if next>LAST_CURSOR:return {}
	var rules:=_rules(cursor,expected,next,Dialogue.events(Dialogue.RESULT,cursor),true)
	if int(expected.kind)==GOODS_KIND and not rules.is_empty():
		if not GOODS.has(cursor):return {}
		rules.goods_requirement=GOODS[cursor].duplicate()
	return rules

static func _rules(cursor: int,current: Dictionary,next: int,events: Array,target_required: bool) -> Dictionary:
	var next_mission:=mission(next)
	if next_mission.is_empty() or events.is_empty():return {}
	var result:={"campaign_cursor":cursor,"mission":current.duplicate(true),"next_cursor":next,"next_mission":next_mission,
		"reward_credits":int(current.get("reward",0)),"events":events,"target_station_required":target_required}
	if UNLOCKS.has(cursor):result.unlock_system_ids=UNLOCKS[cursor].duplicate()
	if COUNTER_REWARD.has(cursor):result.reward_per_story_counter=int(COUNTER_REWARD[cursor])
	if SHIPS.has(next):result.story_ship=SHIPS[next].duplicate(true)
	if BLUEPRINTS.has(next):result.story_blueprint=BLUEPRINTS[next].duplicate()
	return result

static func _same(a: Dictionary,b: Dictionary) -> bool:
	for key in ["kind","station_id","reward"]:
		if int(a.get(key,-2))!=int(b[key]):return false
	return true

## True for careers inside the expansion story, including the finished main
## career that is about to take its first call.
static func active(bindings: RefCounted,cursor: Variant) -> bool:
	return cursor is int and cursor>=FIRST_CURSOR and cursor<=LAST_CURSOR+1 and available(bindings)

## Careers saved inside the expansion story after its first call.
static func saved_story(bindings: RefCounted,cursor: Variant) -> bool:
	return cursor is int and cursor>FIRST_CURSOR and cursor<=LAST_CURSOR+1 and available(bindings)

static func saved_mission(cursor: Variant,value: Variant) -> bool:
	if not cursor is int or not value is Dictionary:return false
	var expected:=mission(cursor)
	if expected.is_empty():return false
	for key in ["kind","station_id","reward","bonus","source_parameter"]:
		if not value.get(key) is int or value[key]!=expected[key]:return false
	return value.size()==expected.size()

static func ship_equipment(ship: Dictionary) -> Array:
	return ship.get("equipment",[]).map(func(row):return {"item_id":int(row[0]),"slot":int(row[1]),"quantity":1})
