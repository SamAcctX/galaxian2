extends RefCounted
## Read-only pirate/contest conditions over an already validated native cast.
## Damage and kill attribution belong to combat/death accounting. Presentation,
## acknowledgement and rewards belong to the enclosing contract or campaign.
## Calling this predicate alone never authorizes career progress.

static func evaluate(actors: Array,totals: Dictionary,rules: Dictionary,challenge: bool) -> Dictionary:
	var begin:=int(rules.challenge_first_actor) if challenge else 0
	var defeated:=0
	for id in range(begin,actors.size()):
		var actor: Dictionary=actors[id]
		# Exhausted hull is not retirement, and another faction does not satisfy
		# this pirate condition even when its destruction has finished.
		if actor.actor_kind==int(rules.challenge_actor_kind) and actor.actor_mode==int(rules.destroyed_mode):defeated+=1
	var required:=actors.size()-begin
	var all_retired: bool=defeated==required
	var player_wins: bool=totals.world_player_kills>totals.world_other_kills
	return {"kind":int(rules.challenge_success_kind if challenge else rules.pirate_kind),
		"failure_kind":int(rules.challenge_failure_kind) if challenge else -1,
		"defeated":defeated,"required":required,
		"satisfied":all_retired and (not challenge or player_wins),
		"failed":challenge and all_retired and not player_wins}
