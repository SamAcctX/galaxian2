extends SceneTree
## Supernova Challenge rules a player sees: kill points, the combo and its
## voice lines, the cashed combo bonus, the end of the run, and the challenge
## recipe's respawn and survival rules.
const KillScore=preload("res://src/simulation/kill_score.gd")
const Rules=preload("res://src/content/supernova_challenge_definitions.gd")
var failures:=0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var score:=KillScore.new()
	check(score.configure(Rules.SCORE),score.error)
	# First kill: no running window, so 1000 points and no voice.
	check(score.kill()==-1 and score.readout().score==1000,"The first kill should score 1000 silently")
	# Half a window later: 1000 + half of 2000, combo 1 -> voice 2282.
	score.advance(3750)
	check(score.kill()==2282 and score.readout().score==3000,"A kill inside the window should score 2000 and say combo 1")
	# Straight away: full bonus, combo 2 -> voice 2283, "x 2" is shown.
	check(score.kill()==2283 and score.readout().score==6000 and score.readout().combo==2,"A quick kill should raise the combo to 2")
	check(score.readout().pending_bonus==2200,"Combo 2 should promise a 2200 bonus")
	# The window runs out: the 2200 bonus is cashed and the combo drops to 1.
	score.advance(7600)
	check(score.readout().score==8200 and score.readout().combo==0,"An expired combo should cash its bonus")
	check(score.snapshot().combo==1,"A cashed combo returns to 1")
	# Eleven quick kills: combo 1..9 lines, then the last line from 10 on.
	var voices:=[]
	for i in 11:voices.append(score.kill())
	check(voices==range(2282,2292)+[2291],"Combo voice lines run 2282..2290 then stay at 2291: "+str(voices))
	check(KillScore.combo_bonus(Rules.SCORE,5)==6250 and KillScore.combo_bonus(Rules.SCORE,9)==13050,"Combo bonus table changed")
	# The run ends at 151 s and cashes the running combo.
	var before: int=score.readout().score
	var combo: int=score.snapshot().combo
	var ended:=false
	for i in 200:ended=score.advance(1000) or ended
	check(ended and score.readout().finished and score.readout().remaining_ms==0,"The run should end at 151 s")
	check(score.readout().score==before+KillScore.combo_bonus(Rules.SCORE,combo),"The end should cash the running combo")
	check(score.kill()==-1 and score.readout().score==before+KillScore.combo_bonus(Rules.SCORE,combo),"No kill counts after the end")
	# A forked score is independent of its parent frame.
	var fresh:=KillScore.new();fresh.configure(Rules.SCORE)
	var copy:=fresh.fork();copy.kill()
	check(fresh.readout().score==0 and copy.readout().score==1000,"A forked score wrote into its parent")
	# Recipe: eight hostile 300-hull Voids, respawning every 7.5 s, player survives.
	var recipe:=Rules.recipe()
	check(recipe.actor_count==8 and recipe.ship_groups[0].ship_state.hull_override==300 and recipe.ship_groups[0].policy.initial_hostile,"Challenge cast changed")
	check(recipe.timed_actions[0].action=="respawn" and recipe.timed_actions[0].every_ms==7500 and recipe.player_survives and recipe.success.kind=="never","Challenge rules changed")
	check(Rules.job(152,111,{"supernova_challenge":true}).get("supernova_challenge",false) and Rules.job(152,111,{}).is_empty(),"Only a challenge career selects the challenge job")
	# The player's hull stops at 1.
	var player:=preload("res://src/simulation/opening_player_state.gd").new()
	player._state={"active":true,"damage_allowed":true,"vitals":{"hull":10,"armor":0,"shield":0.0},"gamma":100.0}
	player.set_hull_floor(1)
	var hit:=player.normal_hit(500);check(int(player._state.vitals.hull)==1,"A survivable ship lost its last hull point: "+player.error+str(hit)+str(player._state.vitals))
	player.destroy_hull();player.drain_gamma(200.0,20.0);check(int(player._state.vitals.hull)==1,"A survivable ship was destroyed")
	print("SUPERNOVA CHALLENGE SCORE ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(1 if failures else 0)

func check(condition: bool,message: String) -> void:
	if not condition:failures+=1;printerr(message)
