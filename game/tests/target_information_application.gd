extends "res://tests/recovery_application.gd"
## Input-only HUD check from a real accepted Recovery job. It stops after
## acquisition and layout checks; the complete delivery has its own pilot.

func fly_recovery_job(initial: Dictionary) -> bool:
	var carrier: int=initial.encounter.combat.actors.size()-1
	var started:=now_us;var next_yield:=now_us;var next_log:=now_us;var approach_seen:=false
	while now_us-started<180000000:
		var state: Dictionary=app.session.snapshot()
		var actor: Dictionary=state.encounter.combat.actors[carrier]
		if state.player.vitals.hull<=0:check(false,"The HUD acquisition pilot died");return false
		var distance: float=state.player_pose.origin.distance_to(actor.position)
		var input:={"commands":RecoverySteering.steering_toward(state.player_pose,actor.position),"throttle":1.0 if distance>25000.0 else 0.0,"fire":false,"strafe":0.0}
		var markers: Array=state.npc_scanner.markers.filter(func(row):return row.actor_id==carrier and row.in_view)
		if not markers.is_empty():
			var offset: Vector2=Vector2(markers[0].pixels-state.npc_scanner.aim_pixels)
			input.commands=Vector2(clampf(offset.y/300.0,-1.0,1.0),clampf(-offset.x/300.0,-1.0,1.0))
			if not approach_seen:await capture_free_application("target-approach");approach_seen=true
		if not pirate_step(input):return false
		var acquired: Dictionary=app.session.snapshot()
		if acquired.npc_scanner.get("selected_target",{}).get("actor_id",-1)==carrier:
			var overlay: Control=app.session.scene.npc_markers
			check(overlay.visible and overlay.information_snapshot().text==source.strings[1600],"The actual Hijacker lock did not show its localized name")
			check(acquired.npc_scanner.markers.any(func(row):return row.actor_id==carrier and row.in_view),"The capture did not reach a visible target")
			await capture_free_application("target-hijacker-desktop")
			overlay.set_mobile_layout(true)
			await capture_free_application("target-hijacker-touch")
			overlay.set_mobile_layout(false)
			var before: Dictionary=app.session.snapshot()
			for tick in 10:
				if not pirate_step({"commands":Vector2(1,0),"throttle":0.0,"fire":false,"strafe":0.0}):return false
			var after: Dictionary=app.session.snapshot()
			check(overlay.information_snapshot().text==source.strings[1600] and after.npc_scanner.selected_actor_id==carrier,"Looking away discarded the named lock")
			check(after.contracts.mission==before.contracts.mission and after.contracts.accepted_contact==before.contracts.accepted_contact and after.contracts.credits==before.contracts.credits and after.contracts.completed_side_missions==before.contracts.completed_side_missions,"Target acquisition changed the accepted job or career")
			await capture_free_application("target-retained-lock")
			return false
		if now_us>=next_yield:await process_frame;next_yield=now_us+1000000
		if now_us>=next_log:
			print("Target information pilot: ",{"distance":distance,"active":actor.active,"hull":state.player.vitals.hull,"equipment":acquired.npc_scanner.equipment_id,"visible":acquired.npc_scanner.visible,"aim":acquired.npc_scanner.aim_pixels,"marker":markers,"selected":acquired.npc_scanner.selected_actor_id,"candidate":acquired.npc_scanner.candidate_actor_id,"elapsed":acquired.npc_scanner.elapsed_ms})
			next_log=now_us+20000000
	await capture_free_application("target-acquisition-stopped")
	check(false,"The input pilot did not acquire the Hijacker")
	return false
