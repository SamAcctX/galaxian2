extends SceneTree
## The Kaamo Club option: owned from New Game or a one-way unlock, every edition.
const Kaamo=preload("res://src/content/kaamo_club_definitions.gd")
const Archive=preload("res://src/simulation/opening_station_archive.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
var failures:=0

func _initialize() -> void:
	for stored in [Kaamo.SIEGE,Kaamo.OPEN,Kaamo.OFFERED,Kaamo.OWNED]:
		var progress:={"kaamo_state":stored}
		check(Kaamo.state(progress)==stored,"Stored club state lost without the option")
		progress.kaamo_unlocked=true
		check(Kaamo.state(progress)==Kaamo.OWNED and Kaamo.unlocked(progress),"Unlocked club is not owned")
		check(Kaamo.docking_event(Kaamo.STATION_ID,progress,Kaamo.PRICE*2,[{"item_id":Kaamo.BUSKAT,"quantity":50}])=="","An owned club still offers itself")
	check(Kaamo.state({})==Kaamo.SIEGE and not Kaamo.unlocked({}),"A new career starts with the club unlocked")
	for value in [false,1,"true",null]:
		check(not Kaamo.unlocked({"kaamo_unlocked":value}),"Only true unlocks the club")
		check(not Archive.valid_lifetime("kaamo_unlocked",value),"A save accepts an invalid club option")
	check(Archive.valid_lifetime("kaamo_unlocked",true),"A save rejects the club option")
	check("kaamo_unlocked" in Archive.LIFETIME_KEYS and "kaamo_unlocked" in Archive.OPTIONAL_PROGRESS_KEYS,"The club option is not carried through flights and saves")
	var contracts:=Contracts.new()
	check(not contracts.unlock_kaamo(),"An empty contract session accepted the club option")
	print("Kaamo unlock checks: %d failures"%failures)
	quit(1 if failures else 0)

func check(condition: bool,message: String) -> void:
	if not condition:failures+=1;push_error(message)
