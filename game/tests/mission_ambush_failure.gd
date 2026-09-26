extends "res://tests/mission_escape_sequence.gd"
## Focused loss component, not an input-earned battle. The initial lethal hit
## is detached; native destruction must retire the existing freighter before
## the real mission runner opens failure. The earned station remains untouched.
const Runner=preload("res://src/simulation/mission_runner.gd")

func verify_component(world: RefCounted) -> void:
	var context:=Context.new()
	var entry: RefCounted=world.entry_owner()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var origin:=NPC.new()
	if not origin.prepare(bindings,catalogues,library,world):check(false,origin.error);return
	var original: Dictionary=origin.snapshot()
	var runner:=Runner.new()
	if not runner.configure(context) or not runner.prepare_conversations(bindings,library):check(false,runner.error);return
	var active: RefCounted=origin.fork_for_frame()
	# Use the owning damage operation on a writable actor, never a changed save,
	# a forced retired flag, or a replacement cast.
	if active._combat._writable(0).normal_hit(2147483647,true).is_empty():check(false,active._combat.error);return
	var damaged: Dictionary=active.snapshot().combat.actors[0]
	check(damaged.vitals.hull<=0 and damaged.actor_mode!=4,"Lethal damage skipped the freighter's native breakup")
	var observation: Dictionary=active.result_observation()
	var pending: Dictionary=runner.poll(observation.actors,true,false,true,observation.sequences)
	check(not pending.is_empty() and pending.mode==0 and not runner.dialogue().visible,"Hull zero alone prematurely failed the ambush")
	var retirement_ms:=-1
	for tick in 200:
		var next: RefCounted=active.evaluate(100,original.player_pose)
		if next==null:check(false,active.error);return
		active=next
		observation=active.result_observation()
		if observation.actors[0].actor_mode==4:
			retirement_ms=(tick+1)*100
			break
	check(retirement_ms>0,"The destroyed freighter never completed native retirement")
	if failures:return
	check(not observation.sequences.sequence_complete,"Freighter loss completed the success cinematic")
	check(active.snapshot().player.vitals.hull>0,"Freighter loss was masked by player destruction")
	# Failure is independent of the success polling interval and radio idle gate.
	var loss: Dictionary=runner.poll(observation.actors,true,false,true,observation.sequences)
	check(not loss.is_empty() and loss.mode==int(context.recipe().result.policy.failure_result_mode),"Native freighter retirement did not fail mission 41 while radio was active")
	if failures:return
	check(runner.open_result() and runner.dialogue().visible,"Freighter loss did not open its actual failure page")
	var failed_before: Dictionary=runner.snapshot()
	check(not runner.acknowledge() and runner.snapshot()==failed_before and not runner.snapshot().retired,"Failure was accepted as a successful career advancement")
	check(active.snapshot().combat.actors.size()==original.combat.actors.size(),"Freighter retirement replaced the encounter's cast")
	check(origin.snapshot()==original,"Failure component mutated its living parent encounter")
	print("Native freighter retirement at ",retirement_ms,"ms opens failure, not hull-zero success; source career remains unchanged")
