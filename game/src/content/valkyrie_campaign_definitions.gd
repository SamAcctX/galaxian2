extends RefCounted
## Valkyrie expansion story: the mission each campaign cursor starts and the
## station conversations that finish talk missions. The story continues from a
## finished main career (cursor 45); Valkyrie is won once the cursor passes 83.
const Dialogue=preload("res://src/content/valkyrie_dialogue_definitions.gd")
const Epilogue=preload("res://src/content/campaign_epilogue_definitions.gd")
const FIRST_CURSOR:=45
const LAST_CURSOR:=83
## A won Valkyrie career rests here with an empty story mission (as 45 does
## after the main game).
const WON_CURSOR:=84
## Supernova continues a won Valkyrie career: the in-flight call at 84 plays
## cursor 85's lines and moves the story to 86. The story runs to the end of Supernova (162).
const STORY_END:=162
const TALK:=11
## Systems revealed when a conversation is acknowledged. The original reveals
## Herjaza and Skavac as missions 55 and 63 begin; Loma is visible to every
## expansion owner, so a continued career receives it with the first call.
const UNLOCKS:={45:[25],54:[23],62:[24],88:[27,28],116:[30],138:[31]}
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
const STATION_KINDS:=[8,11,163,166,171,172]
## Kind 8 (68) is a delivery: the goods are handed over ("consume").
## Assumption: one Void Essence (the amount the original takes is not recovered).
const DELIVERY_KIND:=8
const GOODS:={58:{"item_id":179,"quantity":10},68:{"item_id":175,"quantity":1,"consume":true},
	104:{"item_id":206,"quantity":1},112:{"item_id":146,"quantity":1},
	118:{"item_id":209,"quantity":1},121:{"item_id":209,"quantity":1},
143:{"item_id":210,"quantity":1,"consume":true},
}
## Bar talks (171) finish in the target station's lounge once its intro is
## over; 172 also needs GOODS in the hold (112: one Magnetar Juice).
const BAR_KINDS:=[171,172]
const BAR_GOODS_KIND:=172
## 116: the first lounge visit at each of these Pescal Inartu (18) stations
## shows its line once [speaker, text, voice]; the visits are kept as bits of
## story_status (Sobotnik 94 shares Maissa's bit 3). Maissa (93) ends the hunt.
const BAR_HUNT:={116:{"system_id":18,"stations":{90:[0,0,2705,1561],91:[1,57,2706,1562],92:[2,0,2707,1563],94:[3,58,2708,1564]}}}
## Blueprints handed over as the story enters a cursor: mission 58 grants item
## 179 with 5 of material 127 already supplied at the Valkyrie; 59 takes it back.
## 72: Netor hands over the Disruptor blueprint (183), recipe only.
const BLUEPRINTS:={58:{"item_id":179,"grant":true,"material_id":127,"quantity":5,"station_id":101},59:{"item_id":179,"grant":false},72:{"item_id":183,"grant":true},
	104:{"item_id":206,"grant":true,"material_id":163,"quantity":10,"station_id":10},
141:{"item_id":210,"grant":true,"materials":[[201,847],[202,834],[203,861],[204,892]],"station_id":112}}
## Talks paying extra per story-counter kill (60: 50000 x (Liberator kills + 1)).
## The counter and cleared-station mask end with that talk.
const COUNTER_REWARD:={60:50000}
## Station-side story changes, keyed by the cursor a talk enters and applied
## at the talk's station when it is acknowledged.
## Goods put in the hold [item, quantity]; the original ignores hold space.
## 72: Netor gives the Void Essence back (175). 84 (the win): one S'kloptorr
## Rum (137) and a Khador Drive (85).
## 102: Brent's Nirai SPP-C1 (207) for the Tadram evacuation.
const HOLD_GRANTS:={72:[[175,1]],84:[[137,1],[85,1]],94:[[205,1]],102:[[207,1]],
142:[[197,15],[196,1],[198,1]]}
## Shipyard changes: "clear" empties the shipyard first; each [ship, price] is
## then offered (price -1 = the normal local price, added only when missing).
## 75: Kothar's shipyard is emptied. 77: Khador's Cronus (37) for free. 84:
## the three built-in-drive ships 37 Cronus, 38 Typhon, 40 Nemesis.
const STATION_SHIPS:={75:{"clear":true,"ships":[]},77:{"ships":[[37,0]]},84:{"ships":[[37,-1],[38,-1],[40,-1]]}}
## Items that cannot be sold or demounted while the career is at the cursor
## (77: Alice is about to take the Khador Drive).
const PROTECTED_ITEMS:={77:[85],119:[209],120:[209],121:[209]}
## Items taken away (the fitted one, else the hold stack) and a station whose
## blueprint construction is reset as the story enters the cursor (78: Alice's
## men strip the drive; the Valkyrie workshop is gone).
const REMOVED_ITEMS:={78:[85]}
const BLUEPRINT_RESET:={78:101}
## Goods taken from the hold as the story enters the cursor [item, quantity]
## (89: ten Luxury, 104; assumption: fewer are simply all taken).
## 113: the Magnetar Juice handed over at Nepis (112).
const REMOVED_GOODS:={89:[[104,10]],113:[[146,1]],122:[[209,1]]}
## Stations whose visit is undone as the story enters the cursor (90: the 89
## cutscene's forced Naneroh visit; the visited-stations count drops by one).
const UNVISIT:={90:[109]}
## Kind 184 counts people down from this value (the mission's status value);
## it completes at 0. Kept in career progress as "story_status".
const STORY_STATUS:={91:10,92:10,94:83,102:1700,116:0,135:0,139:10}
## Required before the mission's target can be picked on the star map or
## docked at; otherwise text_id is shown and the course is refused.
const ENTRY_REQUIREMENTS:={91:{"passenger_berths":10,"text_id":3203},94:{"passenger_berths":1,"text_id":3203},
	105:{"fitted_item":206,"text_id":3206},
	135:{"fitted_sort":19,"text_id":3202},
	139:{"any":[{"ship_ids":[42]},{"ship_ids":[9,39,41,42,44,49,50,53,54,61,63],"fitted_item":190}],"text_id":3204},
142:{"fitted_sorts":[33,35],"fitted_items":[[197,15]],"text_id":3205,"free_cargo":1,"free_cargo_text_id":3207},
}
## Where the player is put as the story enters the cursor (from a talk's
## acknowledgement or a flight's advance): "gate" = arrive at the station's
## orbit through the gate in flight, "docked" = the station screen.
## keep_vitals: hull, shield, armour and gamma carry over.
const MOVE_ON_ENTRY:={89:{"station_id":109,"arrive":"gate"},90:{"station_id":10,"arrive":"docked"},
	92:{"station_id":113,"arrive":"gate","keep_vitals":true},95:{"station_id":10,"arrive":"gate","keep_vitals":true},
	96:{"station_id":98,"arrive":"gate","keep_vitals":true},99:{"station_id":10,"arrive":"gate"},100:{"station_id":120,"arrive":"docked"},
	106:{"station_id":111,"arrive":"gate","keep_vitals":true},108:{"station_id":10,"arrive":"gate","keep_vitals":true},
	109:{"station_id":114,"arrive":"gate"},110:{"station_id":10,"arrive":"docked"},
	119:{"station_id":10,"arrive":"gate"},120:{"station_id":126,"arrive":"docked"},
	126:{"station_id":120,"arrive":"launch","keep_vitals":true},
	127:{"station_id":98,"arrive":"gate","keep_vitals":true},133:{"station_id":120,"arrive":"gate"},
	134:{"station_id":112,"arrive":"docked"},
	144:{"station_id":112,"arrive":"launch"},145:{"station_id":112,"arrive":"launch","keep_vitals":true},
	155:{"station_id":-1,"arrive":"gate","keep_vitals":true},158:{"station_id":111,"arrive":"gate","keep_vitals":true},
	160:{"station_id":10,"arrive":"launch"},161:{"station_id":93,"arrive":"launch"},162:{"station_id":93,"arrive":"docked"},
}
## Terran Wanted boards (W1), open from 128's entry (127's talk): a one-time
## notice (text 590) at the next station. The first two wanted.bin entries are
## the story's criminals; each is listed from the cursor its entry names (Pal
## Tyyrt 128, Kehnor 130). Below a third of his hull he surrenders (no longer
## hostile, cannot be hurt); the story then plays that cursor's result in
## flight and moves on (128 -> 130, 130 -> 131).
const WANTED:={"from_cursor":128,"notice_text_id":590,"story_entries":{0:128,1:130},"surrender_hull_fraction":0.3333}
## The end of Supernova: an empty, invisible mission; the story is over and
## free play continues (docked at Maissa, MOVE_ON_ENTRY 162).
const SUPERNOVA_WON:=162
## A talk that plays another cursor's result rows (148: the Kalun Amir bar
## plays the penthouse talk 151; the story then moves 148 -> 152).
const TALK_DIALOGUE:={148:151}
## Bars that play a result once while the career is at the cursor, without
## moving the story (148: the three brokers with no suitable place):
## {cursor: {station: result cursor}}. Heard once each (progress "bar_heard").
const BAR_FLAVOR:={148:{55:148,66:149,9:150}}
## cursor: [kind, reward, station]; -1 station means any station.
const MISSIONS:={
	84:[-1,0,0],
	47:[11,0,74],48:[11,0,58],49:[156,0,58],50:[156,0,62],51:[156,0,25],52:[160,0,25],
	54:[11,200000,74],55:[11,0,101],56:[4,0,102],57:[11,150000,101],58:[166,0,101],59:[163,0,101],
	60:[11,50000,101],61:[164,0,101],62:[11,0,100],63:[4,0,103],64:[4,0,104],65:[11,0,100],
	66:[11,0,101],67:[4,0,104],68:[8,0,66],69:[6,0,66],70:[6,0,65],71:[11,0,66],
	72:[164,150000,101],73:[10,0,81],74:[11,0,100],75:[11,0,100],76:[11,0,100],77:[11,0,101],
	78:[4,0,101],79:[165,0,-1],80:[1,0,100],81:[4,0,-1],82:[11,0,100],83:[11,0,100],
	# Supernova. 85 (10 s in space) is skipped by the call at 84. 184 = people
	# moved (STORY_STATUS counts down); 95 is the next block's first cutaway.
	85:[164,0,0],86:[11,0,100],87:[4,0,10],88:[11,0,10],89:[4,0,109],90:[11,0,10],
	91:[184,0,110],92:[184,0,113],93:[11,0,114],94:[184,0,111],95:[170,0,10],
	# 170 = cutaway scene, 171/172 = bar talk. 107 does not exist: 106 moves
	# the story twice. 117 is the next block's first talk.
	96:[11,0,98],97:[4,0,85],98:[11,0,120],99:[170,0,10],100:[4,0,98],101:[11,0,98],102:[184,0,113],
	103:[11,0,10],104:[166,0,10],105:[4,0,109],106:[4,0,111],108:[11,0,10],109:[170,0,114],
	110:[171,0,10],111:[171,0,38],112:[172,0,38],113:[171,0,82],114:[4,0,83],115:[171,0,82],116:[171,0,93],
	117:[11,0,126],
	118:[8,0,126],119:[170,0,10],120:[4,0,40],121:[8,0,93],122:[11,0,10],123:[4,0,121],124:[11,0,121],125:[4,0,55],
	126:[170,0,120],127:[11,0,98],128:[-1,0,0],130:[-1,0,0],131:[4,0,112],132:[11,0,112],133:[170,0,120],
	134:[11,0,22],135:[174,0,103],136:[11,0,112],137:[4,0,58],138:[11,0,58],139:[168,0,131],140:[11,0,112],
	# 141-162. -1 with kinds 4/165 is the alien world (as 79/81). 171 = bar
	# talk; 148's target bar moves the story to 152 (next_cursor). 162 = won.
	141:[11,0,78],142:[4,0,79],143:[8,0,112],144:[170,0,112],145:[4,0,112],146:[11,0,112],
	147:[4,0,-1],148:[171,0,96],149:[171,0,96],150:[171,0,96],151:[171,0,96],152:[165,0,-1],
	153:[11,0,98],154:[4,0,-1],155:[164,0,0],156:[11,0,99],157:[4,0,112],158:[4,0,111],
	159:[11,0,10],160:[170,0,10],161:[170,0,93],162:[-1,0,0],
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
	if cursor==52:return 54
	if cursor==WON_CURSOR:return 86
	if cursor==148:return 152
	if cursor==128:return 130
	if cursor==106:return 108
	return cursor+1

## Station conversations. A finished main career takes the expansion's incoming
## call at whichever station it is docked in; talk missions play their authored
## result at the target station.
static func conversation(bindings: RefCounted,cursor: Variant,story_mission: Variant) -> Dictionary:
	if not cursor is int or not story_mission is Dictionary or not available(bindings):return {}
	if cursor==FIRST_CURSOR:
		if int(story_mission.get("kind",0))!=-1:return {}
		return _rules(cursor,story_mission,47,Dialogue.events(Dialogue.RESULT,46),false)
	var expected:=mission(cursor)
	if expected.is_empty() or int(expected.kind) not in [TALK,GOODS_KIND,DELIVERY_KIND]+BAR_KINDS or not _same(story_mission,expected):return {}
	var next:=next_cursor(cursor)
	if next>STORY_END:return {}
	var rules:=_rules(cursor,expected,next,Dialogue.events(Dialogue.RESULT,int(TALK_DIALOGUE.get(cursor,cursor))),true)
	if int(expected.kind) in BAR_KINDS and not rules.is_empty():rules.place="lounge"
	if int(expected.kind) in [GOODS_KIND,DELIVERY_KIND,BAR_GOODS_KIND] and not rules.is_empty():
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
	if HOLD_GRANTS.has(next):result.story_hold_grants=HOLD_GRANTS[next].duplicate(true)
	if STATION_SHIPS.has(next):result.story_station_ships=STATION_SHIPS[next].duplicate(true)
	if REMOVED_ITEMS.has(next):result.story_removed_items=REMOVED_ITEMS[next].duplicate()
	if BLUEPRINT_RESET.has(next):result.story_blueprint_reset=int(BLUEPRINT_RESET[next])
	if REMOVED_GOODS.has(next):result.story_removed_goods=REMOVED_GOODS[next].duplicate(true)
	if UNVISIT.has(next):result.story_unvisit=UNVISIT[next].duplicate()
	if STORY_STATUS.has(next):result.story_status=int(STORY_STATUS[next])
	if MOVE_ON_ENTRY.has(next):result.story_move=MOVE_ON_ENTRY[next].duplicate()
	return result

static func _same(a: Dictionary,b: Dictionary) -> bool:
	for key in ["kind","station_id","reward"]:
		if int(a.get(key,-2))!=int(b[key]):return false
	return true

## True for careers inside the expansion story, including the finished main
## career that is about to take its first call.
static func active(bindings: RefCounted,cursor: Variant) -> bool:
	return cursor is int and cursor>=FIRST_CURSOR and cursor<=STORY_END and available(bindings)

## Careers saved inside the expansion story after its first call.
static func saved_story(bindings: RefCounted,cursor: Variant) -> bool:
	return cursor is int and cursor>FIRST_CURSOR and cursor<=STORY_END and available(bindings)

static func saved_mission(cursor: Variant,value: Variant) -> bool:
	if not cursor is int or not value is Dictionary:return false
	var expected:=mission(cursor)
	if expected.is_empty():return false
	for key in ["kind","station_id","reward","bonus","source_parameter"]:
		if not value.get(key) is int or value[key]!=expected[key]:return false
	return value.size()==expected.size()

## Departure needs a given ship at this cursor (verified
## ModStation::leaveStation): 77 only in Khador's Cronus (37), else 315
## "Go to the hangar and board the ship that Khador provided for you."
const DEPARTURE_SHIPS:={77:{"ship_id":37,"text_id":315}}
static func departure_ship(bindings: RefCounted,cursor: Variant) -> Dictionary:
	if not saved_story(bindings,cursor):return {}
	return DEPARTURE_SHIPS.get(cursor,{}).duplicate()

## Items the career may not sell or demount at this cursor.
static func protected_items(bindings: RefCounted,cursor: Variant) -> Array:
	if not saved_story(bindings,cursor):return []
	return PROTECTED_ITEMS.get(cursor,[]).duplicate()

static func entry_requirement(cursor: int) -> Dictionary:return ENTRY_REQUIREMENTS.get(cursor,{}).duplicate()
## Flight notices for refused courses are keyed ENTRY_NOTICE_BASE + text id.
const ENTRY_NOTICE_BASE:=40000
## The notice to show when a course to `station_id` is refused at this cursor
## (too few passenger berths, or a required item not fitted), else -1.
## `sorts` are the fitted items' sorts (135: a mining drill, 19); "any"
## passes when one of its alternatives does (139: a Vossk ship).
## 142: every sort in fitted_sorts, fitted_items [[item, count]] (counts
## from `counts`, fitted ammunition per item), then free_cargo tonnes free
## with its own text.
static func entry_refusal(cursor: int,station_id: int,berths: int,fitted: Array=[],sorts: Array=[],ship_id:=-1,counts: Dictionary={},free_cargo:=-1) -> int:
	var need:=entry_requirement(cursor)
	if need.is_empty() or int(MISSIONS.get(cursor,[0,0,-2])[2])!=station_id:return -1
	if not _entry_met(need,berths,fitted,sorts,ship_id,counts):return ENTRY_NOTICE_BASE+int(need.text_id)
	if need.has("free_cargo") and free_cargo>=0 and free_cargo<int(need.free_cargo):return ENTRY_NOTICE_BASE+int(need.free_cargo_text_id)
	return -1
static func _entry_met(need: Dictionary,berths: int,fitted: Array,sorts: Array,ship_id: int,counts: Dictionary={}) -> bool:
	if need.has("any"):return need.any.any(func(option):return _entry_met(option,berths,fitted,sorts,ship_id,counts))
	if berths<int(need.get("passenger_berths",0)):return false
	if need.has("fitted_item") and not fitted.has(int(need.fitted_item)):return false
	if need.has("fitted_sort") and not sorts.has(int(need.fitted_sort)):return false
	if need.get("fitted_sorts",[]).any(func(sort):return not sorts.has(int(sort))):return false
	if need.get("fitted_items",[]).any(func(pair):return not fitted.has(int(pair[0])) or int(counts.get(int(pair[0]),0))<int(pair[1])):return false
	return not need.has("ship_ids") or ship_id in need.ship_ids
static func story_move(cursor: int) -> Dictionary:return MOVE_ON_ENTRY.get(cursor,{}).duplicate()
## The cursor a surrendering story criminal completes, or -1.
static func wanted_story_cursor(cursor: int,entry: int) -> int:
	return cursor if int(WANTED.story_entries.get(entry,-1))==cursor else -1
static func story_status(cursor: int) -> int:return int(STORY_STATUS.get(cursor,-1))

## The 116 bar-hunt line for a first lounge visit at station_id, or {} (not
## this cursor, not a hunt station, or its bit is already in status).
static func bar_hunt_line(cursor: int,station_id: int,status: int) -> Dictionary:
	var row: Array=BAR_HUNT.get(cursor,{}).get("stations",{}).get(station_id,[])
	if row.is_empty() or status & (1<<int(row[0])):return {}
	return {"status":status | (1<<int(row[0])),"speaker_id":int(row[1]),"text_id":int(row[2]),"voice_event_id":int(row[3])}

static func ship_equipment(ship: Dictionary) -> Array:
	return ship.get("equipment",[]).map(func(row):return {"item_id":int(row[0]),"slot":int(row[1]),"quantity":1})

static func talk_dialogue(cursor: int) -> int:return int(TALK_DIALOGUE.get(cursor,cursor))
static func bar_flavor(cursor: int,station_id: int) -> int:return int(BAR_FLAVOR.get(cursor,{}).get(station_id,-1))
