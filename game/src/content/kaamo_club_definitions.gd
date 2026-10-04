extends RefCounted
## Kaamo Club (station 108, Shima). Career progress "kaamo_state":
## 0 under siege, 1 siege won (club open), 2 first talk heard (purchase
## offered at every later docking), 3 owned.
## First docking after the siege: Mkkt Bkkt's 18-page talk, then state 2.
## Docking at state 2: without 50 t Buskat in the hold and more than
## 30,000,000 credits, message 465; with both, the Yes/No offer 466. Yes pays
## both, state 3, his farewell talk (468-473) and message 474.
## Assumption: the farewell talk is reachable in the original only through a
## dead path; it is played after the purchase as the texts intend.

const STATION_ID:=108
const SIEGE:=0
const OPEN:=1
const OFFERED:=2
const OWNED:=3
const PRICE:=30000000
const BUSKAT:=109
const BUSKAT_TONS:=50
const NOT_READY_TEXT:=465
const OFFER_TEXT:=466
const OWNED_TEXT:=474
const YES_TEXT:=133
const NO_TEXT:=134
## [speaker, text, voice]: 4 Mkkt Bkkt, 0 Keith, 16 the info screen.
const FIRST_TALK:=[[4,448,1444],[0,449,1445],[4,450,1453],[0,451,1454],[4,452,1455],[0,453,1456],
	[4,454,1457],[0,455,1458],[4,456,1459],[0,457,1460],[4,458,1446],[0,459,1447],[4,460,1448],
	[0,461,1449],[4,462,1450],[0,463,1451],[4,464,1452],[16,465,-1]]
const FAREWELL_TALK:=[[4,468,1461],[0,469,1462],[4,470,1463],[0,471,1464],[4,472,1465],[0,473,1466]]

static func state(progress: Dictionary) -> int:return int(progress.get("kaamo_state",SIEGE))

static func buskat_tons(cargo: Array) -> int:
	var tons:=0
	for row in cargo:
		if row is Dictionary and int(row.get("item_id",-1))==BUSKAT:tons+=int(row.get("quantity",0))
	return tons

## The original's check is "credits >= 30,000,001".
static func can_buy(credits: int,cargo: Array) -> bool:return credits>PRICE and buskat_tons(cargo)>=BUSKAT_TONS

## What docking at the club shows: "talk" (first visit), "offer", "not_ready" or "".
static func docking_event(station_id: int,progress: Dictionary,credits: int,cargo: Array) -> String:
	if station_id!=STATION_ID:return ""
	match state(progress):
		OPEN:return "talk"
		OFFERED:return "offer" if can_buy(credits,cargo) else "not_ready"
	return ""
