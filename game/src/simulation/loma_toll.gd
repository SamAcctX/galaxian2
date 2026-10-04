extends RefCounted
## One Loma flight's toll state (rules in loma_toll_definitions.gd). The flight
## frame applies the results: career write, pirate truce and radio lines.
const Toll=preload("res://src/content/loma_toll_definitions.gd")
var status:=0
var question:=false
var asked:=false
var percent:=0
var amount:=0
var shortfall:=0
var _serial:=0

## Entering Loma flight. Returns the radio line to play, or -1.
func start(career_status: int,seed: int) -> int:
	status=career_status if career_status in [Toll.PAID,Toll.REFUSED] else 0
	question=false;asked=status!=0;shortfall=0;_serial=seed
	if status==Toll.PAID:return -1
	return _line(Toll.RETURN if status==Toll.REFUSED else Toll.WELCOME)

func holds_fire() -> bool:return status!=Toll.REFUSED

## The welcome finished: ask once, with the toll computed now.
func observe_finished(text_id: int,cargo_value: int,difficulty: float) -> bool:
	if status!=0 or asked or text_id not in Toll.WELCOME:return false
	asked=true;question=true
	percent=Toll.percent(difficulty);amount=Toll.amount(cargo_value,difficulty)
	return true

## Returns {status, debit, shortfall, radio}.
func answer(yes: bool,credits: int) -> Dictionary:
	if not question:return {}
	question=false
	if yes and credits>=amount:
		status=Toll.PAID;shortfall=0
		return {"status":status,"debit":amount,"shortfall":0,"radio":_line(Toll.PAID_LINES)}
	status=Toll.REFUSED;shortfall=maxi(0,amount-credits) if yes else 0
	return {"status":status,"debit":0,"shortfall":shortfall,"radio":_line(Toll.ATTACK)}

## The player hit a pirate: every pirate turns hostile. True when it changed.
func provoke() -> bool:
	if status==Toll.REFUSED:return false
	status=Toll.REFUSED;asked=true;question=false
	return true

func _line(lines: Array) -> int:
	_serial+=1
	return Toll.pick(lines,_serial)

func snapshot() -> Dictionary:
	return {"status":status,"question":question,"percent":percent,"amount":amount,"shortfall":shortfall}

func fork() -> RefCounted:
	var copy: RefCounted=get_script().new()
	copy.status=status;copy.question=question;copy.asked=asked;copy.percent=percent
	copy.amount=amount;copy.shortfall=shortfall;copy._serial=_serial
	return copy
