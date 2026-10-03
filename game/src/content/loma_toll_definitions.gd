extends RefCounted
## Loma (system 25) pirate toll, Valkyrie black-market system.
## Career progress "loma_toll": 1 paid, 2 refused (absent: not asked yet).
## Paid or unasked: pirates hold fire. Unasked: a welcome line, then a paused
## question asks a share of the hold's value. Refusing, failing to pay or
## hitting a pirate makes every pirate hostile. Leaving Loma clears it.
const SYSTEM_ID:=25
const PIRATE_KIND:=8
const SPEAKER_ID:=9
const PROGRESS_KEY:="loma_toll"
const PAID:=1
const REFUSED:=2
const QUESTION_TEXT:=437
const YES_TEXT:=133
const NO_TEXT:=134
const SHORTFALL_TEXT:=192
const EMPTY_HOLD_VALUE:=100
## Radio pairs: either line of a pair may play.
const WELCOME:=[438,439]
const PAID_LINES:=[440,441]
const ATTACK:=[442,443]
const RETURN:=[444,445]
## Text id -> voice event id.
const LINES:={438:1436,439:1437,440:1442,441:1443,442:1438,443:1439,444:1440,445:1441}

static func active(system_id: int) -> bool:return system_id==SYSTEM_ID

static func status(progress: Dictionary) -> int:
	var value: Variant=progress.get(PROGRESS_KEY,0)
	return int(value) if value is int and value in [PAID,REFUSED] else 0

static func valid(value: Variant) -> bool:return value is int and value in [PAID,REFUSED]

## Percent of the hold's value by career difficulty.
static func percent(difficulty: float) -> int:
	if difficulty<=0.0:return 2
	if is_equal_approx(difficulty,0.5):return 5
	if is_equal_approx(difficulty,1.0):return 10
	return 20

## Hold value: quantity x unit price per entry; 100 when the hold is empty.
## Prices come from the retained purchase price, else the item's lowest price.
static func cargo_value(entries: Array,prices: Array,items: Array) -> int:
	var paid:={}
	for row in prices:
		if row is Dictionary and row.has("item_id"):paid[int(row.item_id)]=int(row.get("unit_price",0))
	var total:=0
	for entry in entries:
		var id:=int(entry.get("item_id",-1))
		var price:int=paid.get(id,-1)
		if price<0:price=int(items[id].properties.get(7,0)) if id>=0 and id<items.size() else 0
		total+=int(entry.get("quantity",0))*price
	return EMPTY_HOLD_VALUE if total<=0 else total

static func amount(value: int,difficulty: float) -> int:
	return value*percent(difficulty)/100

static func pick(lines: Array,serial: int) -> int:return int(lines[absi(serial)%lines.size()])

static func question_text(template: String,percent_value: int,toll: int) -> String:
	return template.replace("#P",str(percent_value)).replace("#C","%d$"%toll)

static func shortfall_text(template: String,missing: int) -> String:
	return template.replace("#C","%d$"%missing)
