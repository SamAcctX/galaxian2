extends RefCounted
## One flight-frame step for the Emergency System and Shield Injector
## (emergency_system.gd, shield_injector.gd, held by the player state). Runs
## after the frame's damage and before its death check. The injector's Blue
## Plasma leaves the frame's hold and the retained inventory.

const Injector=preload("res://src/simulation/shield_injector.gd")

## Returns {cargo, equipment, events} with the (possibly new) cargo and
## equipment owners, or {error} when the hold could not be updated.
static func advance(player: RefCounted,cargo: RefCounted,equipment: RefCounted,notices: RefCounted,delta_ms: int) -> Dictionary:
	var result:={"cargo":cargo,"equipment":equipment,"events":{}}
	if player==null or not player.has_method("advance_devices"):return result
	var plasma: int=maxi(0,cargo.quantity(Injector.PLASMA_ITEM)) if cargo!=null else 0
	var events: Dictionary=player.advance_devices(delta_ms,plasma)
	result.events=events
	var used:=int(events.get("plasma_used",0))
	if used>0 and cargo!=null:
		var hold: RefCounted=cargo.fork_for_frame()
		if not hold.consume(Injector.PLASMA_ITEM,used):return {"error":hold.error}
		result.cargo=hold
		if equipment!=null:
			var inventory: RefCounted=equipment.fork()
			if not inventory.retain_flight_cargo(hold.snapshot()):return {"error":inventory.error}
			result.equipment=inventory
		# HUD line "-30t <text 1465>", like the fuel notice.
		if notices!=null and notices.has_method("enqueue_plasma_injected"):notices.enqueue_plasma_injected(used)
	return result
