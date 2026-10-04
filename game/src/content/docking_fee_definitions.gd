extends RefCounted
## Docking where the player is unwelcome (original station entry): an enemy of
## the system's race, or a pilot who attacked this station's forces, is asked
## for a fee before the hangar opens. Yes pays it (and forgives the attack); No,
## or too few credits (192, missing amount), sends the ship back out.
##  - enemy (194): |standing| / 100 * 2800 + a draw of -100..99 credits
##  - attack (195): rank * 150 + 1000 credits
## Both are ten times as much on the hardest difficulty. No fee at the black
## market system (25), stations 100/101/108, during mission 48, at a story
## station's own talk, or where a pirate outpost stands, nor when a save is
## loaded at a station. Assumption: a docking that opens with a story
## conversation is not charged either.
## Assumption: Supernova-struck systems (also exempt in the original) are not
## exempted; the remake has no such system state.

const SPEAKER:=16
const ENEMY_TEXT:=194
const ATTACK_TEXT:=195
const SHORT_TEXT:=192
const ENEMY_SCALE:=2800.0
const ATTACK_BASE:=1000
const ATTACK_PER_RANK:=150
const HARDEST_DIFFICULTY:=1.5
const HARDEST_SCALE:=10
const EXEMPT_STATIONS:=[100,101,108]
const EXEMPT_SYSTEM:=25
const EXEMPT_CURSOR:=48
## Story arrivals that open their own talk: station -> cursor.
const EXEMPT_STORY:={126:120,78:141}
const SYSTEM_RACE_FIELD:=2

## Race 0/2 are enemies below -70 on their axis, race 1/3 above +70.
static func enemy(standing: Dictionary,race: int) -> bool:
	if race<0 or race>3 or not standing.get("axes") is Array or standing.axes.size()!=2:return false
	var value:=int(standing.axes[0 if race<2 else 1])
	return value < -70 if race in [0,2] else value > 70

## {} when docking is free, else {"text_id","amount"}. roll is 0..199.
static func quote(station_id: int,system_id: int,race: int,cursor: int,career: Dictionary,attacked: bool,roll: int) -> Dictionary:
	if station_id in EXEMPT_STATIONS or system_id==EXEMPT_SYSTEM or cursor==EXEMPT_CURSOR or EXEMPT_STORY.get(station_id,-1)==cursor:return {}
	var standing: Dictionary=career.get("reputation",{})
	var result:={}
	if enemy(standing,race):
		var value:=absi(int(standing.axes[0 if race<2 else 1]))
		result={"text_id":ENEMY_TEXT,"amount":int(float(value)/100.0*ENEMY_SCALE)+roll-100}
	elif attacked:
		result={"text_id":ATTACK_TEXT,"amount":int(career.get("rank",0))*ATTACK_PER_RANK+ATTACK_BASE}
	else:return {}
	if float(career.get("difficulty",0.5))>=HARDEST_DIFFICULTY:result.amount*=HARDEST_SCALE
	return result
