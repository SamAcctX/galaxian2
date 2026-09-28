extends SceneTree
## Synthetic observations test a read-only condition, not earned flight progress.
const Condition=preload("res://src/simulation/pirate_defeat_condition.gd")
const Definitions=preload("res://src/content/contract_ship_lifecycle_definitions.gd")
const Bakka=preload("res://src/content/bakka_contest_definitions.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	verify()
	print("Pirate defeat condition: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	for edition in [Bakka.VALUES,Bakka.MAC_VALUES]:
		check(Bakka.parameters(edition),"A supported contest declaration was rejected")
		check(edition.objectives==Definitions.VALUES.objectives,"The campaign duplicated different contest rules")
		var altered: Dictionary=edition.duplicate(true)
		altered.objectives.challenge_first_actor=0
		check(not Bakka.parameters(altered),"A changed contest range was accepted")
	var rules: Dictionary=Definitions.VALUES.objectives.duplicate(true)
	var actors:=[actor(1,0),actor(8,1),actor(8,1),actor(8,1)]
	var totals:={"world_player_kills":2,"world_other_kills":1}
	var status:=Condition.evaluate(actors,totals,rules,true)
	check(status=={"kind":20,"failure_kind":21,"defeated":0,"required":3,"satisfied":false,"failed":false},"A fresh contest resolved")
	for id in range(1,actors.size()):actors[id].vitals.hull=0
	check(Condition.evaluate(actors,totals,rules,true)==status,"Zero hull bypassed destruction retirement")
	for id in range(1,actors.size()):
		actors[id].actor_mode=4
		status=Condition.evaluate(actors,totals,rules,true)
		check(status.defeated==id and status.satisfied==(id==3) and not status.failed,"Partial retirement resolved the contest")
	# The opponent is outside the counted range, including its own destruction.
	for mode in range(6):
		actors[0].actor_mode=mode
		check(Condition.evaluate(actors,totals,rules,true).satisfied,"Opponent mode changed pirate victory")
	# Scores are the retained WORLD counters, not a reconstructed distribution of
	# just this cast. Every equal score loses; neither branch fires prematurely.
	for player in range(9):
		for other in range(9):
			totals={"world_player_kills":player,"world_other_kills":other}
			status=Condition.evaluate(actors,totals,rules,true)
			check(status.satisfied==(player>other) and status.failed==(player<=other),"Strict world-kill majority changed")
			actors[2].actor_mode=3
			status=Condition.evaluate(actors,totals,rules,true)
			check(not status.satisfied and not status.failed,"Score resolved a tumbling pirate")
			actors[2].actor_mode=4
	actors[2].actor_kind=2
	status=Condition.evaluate(actors,totals,rules,true)
	check(status.defeated==2 and not status.satisfied and not status.failed,"Another faction substituted for a pirate")
	actors[2].actor_kind=8
	for mode in range(6):
		actors[1].actor_mode=mode
		status=Condition.evaluate(actors,totals,rules,true)
		check(status.failed==(mode==4) and not status.satisfied,"The retirement predicate accepted another mode")
	actors[1].actor_mode=4
	# Ordinary pirate jobs share the actor predicate, without contest scoring.
	actors[0]=actor(8,4)
	totals={"world_player_kills":0,"world_other_kills":4}
	status=Condition.evaluate(actors,totals,rules,false)
	check(status=={"kind":18,"failure_kind":-1,"defeated":4,"required":4,"satisfied":true,"failed":false},"A pirate job acquired the contest-majority requirement")
	actors[0].actor_mode=1
	check(not Condition.evaluate(actors,totals,rules,false).satisfied,"A pirate job skipped actor zero")
	var before:=actors.duplicate(true)
	var retained_totals:=totals.duplicate(true)
	var retained_rules:=rules.duplicate(true)
	for _repeat in range(8):Condition.evaluate(actors,totals,rules,true)
	check(actors==before and totals==retained_totals and rules==retained_rules,"Read-only condition mutated its inputs")
	check(not status.has("campaign_cursor") and not status.has("reward") and not status.has("acknowledged"),"A predicate acquired settlement authority")

func actor(kind: int,mode: int) -> Dictionary:
	return {"actor_kind":kind,"actor_mode":mode,"vitals":{"hull":100}}

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1;push_error(message)
