extends SceneTree
## Detached counter fixtures exercise the ledger, not an earned reward purchase.
const Medals=preload("res://src/simulation/base_medal_progress.gd")
const Contracts=preload("res://src/simulation/contract_session.gd")
const ContractObjective=preload("res://src/simulation/contract_flight_objective.gd")
var checks:=0
var failures:=0

class MasonScenery extends "res://src/simulation/opening_scenery.gd":
	var mason_identity:=RefCounted.new()
	var mason_destroyed:=0
	func presentation_identity() -> RefCounted:return mason_identity
	func read_snapshot() -> Dictionary:return {"destroyed_count":mason_destroyed}

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)

func recipes(owned: int,built: int) -> Dictionary:
	var entries: Array=[]
	for index in owned:entries.append({"available":true,"completed":1 if index<built else 0})
	return {"entries":entries}

func career() -> Dictionary:
	return {"campaign_cursor":45,"progress":{"player_kills":49,"cargo_recovered":49,"debris_destroyed":30,"asteroids_destroyed":50},
		"completed_side_missions":5,"delivery_statistics":{"cargo":25,"passengers":5},
		"travel_statistics":{"jumpgates_used":9},"conversations":20,"rejected_jobs":50,"pending_result":{}}

func _initialize() -> void:
	var native:=career();var before:=native.duplicate(true);var blueprints:=recipes(3,0)
	var first:=Medals.commit({},native,blueprints)
	check(Medals.valid_retained(first,native,blueprints),"Fresh cumulative observations must validate")
	check(first.levels[0]==1 and first.levels[30]==1,"Service and completed campaign medals have separate evidence")
	check(first.levels[13]==3 and first.levels[14]==0,"Owning three blueprints does not construct them")
	for id in [4,5,10,16,17,18,24,26,29,32]:check(first.levels[id]==0,"A below-threshold counter awarded medal %d"%id)
	for id in [1,2,3,6,7,8,9,11,12,15,19,20,21,22,23,25,27,28,31,33,34,35]:
		check(first.levels[id]==Medals.UNKNOWN,"Missing history was invented for medal %d"%id)
	check(native==before,"Observing medals mutated the career")
	native.progress.player_kills=50;native.progress.cargo_recovered=50
	native.progress.debris_destroyed=31;native.progress.asteroids_destroyed=51;native.completed_side_missions=6
	native.delivery_statistics.cargo=26;native.delivery_statistics.passengers=6;native.travel_statistics.jumpgates_used=10;native.conversations=21
	var bronze:=Medals.commit(first,native,recipes(6,3))
	for id in [4,5,10,16,17,18,24,26,29]:check(bronze.levels[id]==3,"Actual threshold crossing did not award bronze %d"%id)
	check(first.levels[4]==0 and bronze.levels[13]==2 and bronze.levels[14]==3,"Promotion mutated retained history or confused blueprint counters")
	check(Medals.commit(bronze,native,recipes(6,3))==bronze,"Repeated station observations changed awards")
	for vector in [[99,3],[100,2],[249,2],[250,1]]:
		native.progress.player_kills=vector[0]
		check(Medals.observe(native).levels[4]==vector[1],"Kills use inclusive silver/gold boundaries")
	for vector in [[100,3],[101,2],[200,2],[201,1]]:
		native.delivery_statistics.cargo=vector[0]
		check(Medals.observe(native).levels[5]==vector[1],"Courier totals require strictly exceeding the threshold")
	for vector in [[30,0],[31,3],[100,3],[101,2],[150,2],[151,1]]:
		native.progress.debris_destroyed=vector[0]
		check(Medals.observe(native).levels[10]==vector[1],"Garbage Man requires strictly exceeding destroyed-junk thresholds")
	for vector in [[5,0],[6,3],[25,3],[26,2],[50,2],[51,1]]:
		native.completed_side_missions=vector[0]
		check(Medals.observe(native).levels[16]==vector[1],"Workaholic requires strictly exceeding completed-job thresholds")
	for vector in [[20,0],[21,3],[50,3],[51,2],[100,2],[101,1]]:
		native.conversations=vector[0]
		check(Medals.observe(native).levels[26]==vector[1],"Chatterbox requires strictly exceeding successful-conversation thresholds")
	for vector in [[50,0],[51,3],[150,3],[151,2],[250,2],[251,1]]:
		native.progress.asteroids_destroyed=vector[0]
		check(Medals.observe(native).levels[29]==vector[1],"Mason requires strictly exceeding destroyed-asteroid thresholds")
	for vector in [[50,0],[51,1]]:
		native.rejected_jobs=vector[0]
		check(Medals.observe(native).levels[32]==vector[1],"Naysayer requires more than fifty explicit job refusals")
	var champion: Array=[];champion.resize(Medals.BASE_COUNT);champion.fill(3);champion[0]=1;champion[30]=1
	check(Medals._champion_level(champion)==1,"Thirty-five earned base medals did not grant Champion gold")
	champion[12]=0;check(Medals._champion_level(champion)==0,"An unearned base medal still granted Champion")
	champion[12]=Medals.UNKNOWN;check(Medals._champion_level(champion)==Medals.UNKNOWN,"Missing base history invented Champion progress")
	champion[5]=Medals.UNKNOWN;champion[34]=0;check(Medals._champion_level(champion)==Medals.UNKNOWN,"Incomplete retained history invented a Champion verdict")
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
	var all_known:=career();all_known.progress={"player_kills":250,"cargo_recovered":500,"debris_destroyed":151,"asteroids_destroyed":251};all_known.completed_side_missions=51;all_known.conversations=101;all_known.rejected_jobs=51
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
	var mason:=Contracts.new();mason._state=career();mason._state.progress.erase("asteroids_destroyed");mason._flight={"active":true}
	check(mason.retain_asteroid_destruction_total(51) and mason.snapshot().progress.asteroids_destroyed==51,"A living flight did not retain Mason destruction progress")
	var mason_held:=mason.snapshot();check(not mason.retain_asteroid_destruction_total(50) and mason.snapshot()==mason_held,"Mason destruction progress regressed inside one retained flight")
	var objective_owner:=Contracts.new();objective_owner._state=career();objective_owner._flight={"active":true}
	var mason_scenery:=MasonScenery.new();var mason_objective:=ContractObjective.new()
	mason_objective._contracts=objective_owner;mason_objective._field_identity=mason_scenery.presentation_identity();mason_objective._initial_asteroids_destroyed=50
	mason_scenery.mason_destroyed=1
	check(mason_objective.observe_scenery(mason_scenery) and mason_objective.contract_owner().snapshot().progress.asteroids_destroyed==51,"Contract scenery did not publish one Mason destruction")
	check(mason_objective.observe_scenery(mason_scenery) and mason_objective.contract_owner().snapshot().progress.asteroids_destroyed==51,"Repeated contract scenery observation duplicated Mason progress")
	var objective_held: Dictionary=mason_objective.contract_owner().snapshot();mason_scenery.mason_destroyed=0
	check(not mason_objective.observe_scenery(mason_scenery) and mason_objective.contract_owner().snapshot()==objective_held,"Contract Mason scenery history regressed without rejection")
	var saved:=owner.snapshot();var copy:=owner.fork();copy._state.progress.player_kills=50
	check(copy.settle_base_medals() and copy.snapshot().base_medals.levels[4]==3,"Detached station did not bank the earned upgrade")
	check(owner.snapshot()==saved,"A detached medal upgrade mutated its parent")
	copy._flight={"active":true};var held: Dictionary=copy.snapshot()
	check(not copy.settle_base_medals() and copy.snapshot()==held,"Reading a living flight committed station medals")
	copy._flight={};copy._state.pending_result={"completed":true};held=copy.snapshot()
	check(not copy.settle_base_medals() and copy.snapshot()==held,"An unacknowledged result committed medals")
	var refusal:=Contracts.new();refusal._state=career();refusal._state.offers={7:{"offer":{"mission":{}},"consumed":false}}
	check(refusal.decline(7),refusal.error)
	check(refusal.snapshot().rejected_jobs==51 and refusal.snapshot().base_medals.levels[32]==1,"A real explicit refusal did not bank Naysayer gold")
	held=refusal.snapshot();check(not refusal.decline(8) and refusal.snapshot()==held,"An unavailable job changed the refusal history")
	print("Base medal progress: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)
