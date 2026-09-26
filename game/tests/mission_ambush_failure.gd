extends "res://tests/mission_escape_sequence.gd"
## Focused loss component, not an input-earned battle. The initial lethal hit
## is detached; native destruction must retire the existing freighter before
## the real mission runner opens failure. The earned station remains untouched.
const Runner=preload("res://src/simulation/mission_runner.gd")
const Flight=preload("res://src/simulation/mission_flight_frame.gd")

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
	if not failures:verify_premature_exit(world,context)

## Detached portal placement tests the forbidden-exit boundary, not a playable
## way to open the mission's initially hidden exit. Native contact and player
## destruction must enforce the recipe without acknowledging the ambush.
func verify_premature_exit(world: RefCounted,context: RefCounted) -> void:
	var frame:=Flight.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	var active: RefCounted=frame.skip_entry()
	if active==null:check(false,frame.error);return
	for page in context.recipe().briefing.size():
		var next: RefCounted=active.navigate("next")
		if next==null:check(false,active.error);return
		active=next
	var original: Dictionary=active.snapshot()
	var career: Dictionary=active.career_owner().snapshot()
	check(original.campaign_cursor==41 and not original.portal.visible and original.player.vitals.hull>0,"Premature-exit check did not start in the living unacknowledged ambush")
	var contact: RefCounted=active.fork_for_frame()
	# Place an already-open contact volume through its owning operations.
	# Do not force the entered latch, hit the player, or change career/save data.
	if not contact._portal.open_at(original.player_pose.origin) or not contact._portal.begin_closing(0):check(false,contact._portal.error);return
	var placed: Dictionary=contact.snapshot()
	# The control case overlaps the same volume; visibility alone differs.
	var hidden: RefCounted=contact.fork_for_frame()
	if not hidden._portal.set_visible(false):check(false,hidden._portal.error);return
	var hidden_before: Dictionary=hidden.snapshot()
	var closed: RefCounted=hidden.evaluate(100,Vector2.ZERO,0.0,false)
	if closed==null:check(false,hidden.error);return
	check(not closed.snapshot().portal_contact.portal_entered and closed.snapshot().player.vitals.hull>0 and closed.prepare_portal_transition().is_empty(),"The overlapping hidden exit killed or returned the player")
	check(hidden.snapshot()==hidden_before,"Hidden-portal contact mutated its parent")
	var rejected: RefCounted=contact.evaluate(100,Vector2.ZERO,0.0,false)
	if rejected==null:check(false,contact.error);return
	var after: Dictionary=rejected.snapshot()
	check(after.portal_contact.portal_entered and after.player.vitals.hull<=0,"Native portal contact before result41 did not destroy the player")
	check(after.campaign_cursor==41 and rejected.prepare_portal_transition().is_empty(),"Premature Void exit advanced or returned the campaign")
	check(rejected.career_owner().snapshot()==career,"Premature exit changed the independent career")
	check(contact.snapshot()==placed and active.snapshot()==original,"Premature-exit candidate mutated either living parent")
	print("Native portal contact before result41 destroys the player without a return or career advancement")
