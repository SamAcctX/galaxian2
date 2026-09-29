extends SceneTree
## Detached counter fixtures exercise the ledger, not an earned reward purchase.
const Medals=preload("res://src/simulation/base_medal_progress.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
var checks:=0
var failures:=0

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func recipes(owned: int,built: int) -> Dictionary:
	var entries: Array=[]
	for index in owned:entries.append({"available":true,"completed":1 if index<built else 0})
	return {"entries":entries}

func career() -> Dictionary:
	return {"campaign_cursor":45,"progress":{"player_kills":49,"cargo_recovered":49},
		"delivery_statistics":{"cargo":25,"passengers":5},"travel_statistics":{"jumpgates_used":9},"pending_result":{}}

func _initialize() -> void:
	var native:=career();var before:=native.duplicate(true);var blueprints:=recipes(3,0)
	var first:=Medals.commit({},native,blueprints)
	check(Medals.valid_retained(first,native,blueprints),"Fresh cumulative observations must validate")
	check(first.levels[0]==1 and first.levels[30]==1,"Service and completed campaign medals have separate evidence")
	check(first.levels[13]==3 and first.levels[14]==0,"Owning three blueprints does not construct them")
	for id in [4,5,17,18,24]:check(first.levels[id]==0,"A below-threshold counter awarded medal %d"%id)
	for id in [1,2,3,6,7,8,9,10,11,12,15,16,19,20,21,22,23,25,26,27,28,29,31,32,33,34,35]:
		check(first.levels[id]==Medals.UNKNOWN,"Missing history was invented for medal %d"%id)
	check(native==before,"Observing medals mutated the career")
	native.progress.player_kills=50;native.progress.cargo_recovered=50
	native.delivery_statistics.cargo=26;native.delivery_statistics.passengers=6;native.travel_statistics.jumpgates_used=10
	var bronze:=Medals.commit(first,native,recipes(6,3))
	for id in [4,5,17,18,24]:check(bronze.levels[id]==3,"Actual threshold crossing did not award bronze %d"%id)
	check(first.levels[4]==0 and bronze.levels[13]==2 and bronze.levels[14]==3,"Promotion mutated retained history or confused blueprint counters")
	check(Medals.commit(bronze,native,recipes(6,3))==bronze,"Repeated station observations changed awards")
	for vector in [[99,3],[100,2],[249,2],[250,1]]:
		native.progress.player_kills=vector[0]
		check(Medals.observe(native).levels[4]==vector[1],"Kills use inclusive silver/gold boundaries")
	for vector in [[100,3],[101,2],[200,2],[201,1]]:
		native.delivery_statistics.cargo=vector[0]
		check(Medals.observe(native).levels[5]==vector[1],"Courier totals require strictly exceeding the threshold")
	var unavailable:=career();unavailable.progress.erase("cargo_recovered")
	check(Medals.observe(unavailable).levels[24]==Medals.UNKNOWN,"Absent legacy recovery is not zero")
	check(not Medals.valid_retained(bronze,unavailable,recipes(6,3)),"A retained award without its durable evidence was accepted")
	for bad in [-1,1.0,true,2147483648]:
		var malformed:=career();malformed.progress.player_kills=bad
		check(Medals.observe(malformed).is_empty(),"Invalid counter type/range was coerced")
	var forged:=bronze.duplicate(true);forged.levels[4]=1
	check(not Medals.valid_retained(forged,career(),recipes(6,3)),"A forged gold medal bypassed the native kill count")
	forged=bronze.duplicate(true);forged.levels[9]=1
	check(not Medals.valid_state(forged),"An unmapped history became an award")
	forged=bronze.duplicate(true);forged.levels.append(1)
	check(not Medals.valid_state(forged),"Additional medals entered the base aggregate")
	check(Medals.commit(bronze,career(),recipes(6,3)).is_empty() and bronze.levels[4]==3,"Regressed native evidence silently downgraded an award")
	check(Medals.all_base_gold(44)==false,"Incomplete campaign admitted the reward")
	check(Medals.all_base_gold(45,{"blueprints_owned":13,"blueprints_constructed":13})==null,"Legacy blueprint counts invented all-gold")
	var all_known:=career();all_known.progress={"player_kills":250,"cargo_recovered":500}
	all_known.delivery_statistics={"cargo":201,"passengers":51};all_known.travel_statistics.jumpgates_used=100
	all_known.base_medals=Medals.commit({},all_known,recipes(13,13))
	var receipt:=Medals.stock_progress(all_known,recipes(13,13))
	check(Medals.valid_counts(receipt) and Medals.all_base_gold(45,receipt)==null,"Known gold medals erased unknown eligibility")
	all_known.progress.player_kills=249;all_known.base_medals=Medals.commit({},all_known,recipes(13,13))
	check(Medals.all_base_gold(45,Medals.stock_progress(all_known,recipes(13,13)))==false,"Known silver did not prove ordinary stock")
	receipt.blueprints_owned=12;receipt.blueprints_constructed=12
	check(not Medals.valid_counts(receipt),"A stock receipt contradicted its blueprint award")
	var owner:=Contracts.new();owner._state=career()
	check(owner.settle_base_medals(),owner.error)
	var saved:=owner.snapshot();var copy:=owner.fork();copy._state.progress.player_kills=50
	check(copy.settle_base_medals() and copy.snapshot().base_medals.levels[4]==3,"Detached station did not bank the earned upgrade")
	check(owner.snapshot()==saved,"A detached medal upgrade mutated its parent")
	copy._flight={"active":true};var held: Dictionary=copy.snapshot()
	check(not copy.settle_base_medals() and copy.snapshot()==held,"Reading a living flight committed station medals")
	copy._flight={};copy._state.pending_result={"completed":true};held=copy.snapshot()
	check(not copy.settle_base_medals() and copy.snapshot()==held,"An unacknowledged result committed medals")
	print("Base medal progress: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
