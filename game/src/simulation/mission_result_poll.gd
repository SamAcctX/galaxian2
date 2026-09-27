extends RefCounted
## Shared result precedence and cadence. Callers supply observed conditions;
## dialogue, reputation, rewards and acknowledgement keep their own owners.

static func evaluate(policy: Dictionary,state: Dictionary,status: Dictionary,radio_active: bool,periodic_allowed: bool,reset_while_blocked:=true) -> Dictionary:
	var next:=state.duplicate(true)
	if state.retired or state.mode!=0:return next
	var due: bool=state.clock_ms>=int(policy.success_poll_milliseconds)
	var eligible:=due and periodic_allowed
	if eligible and not radio_active and status.satisfied:
		next.mode=int(policy.success_result_mode)
	elif status.get("failed",false):
		next.mode=int(policy.failure_result_mode)
	elif eligible and status.get("periodic_failure",false):
		next.mode=int(policy.failure_result_mode);next.clock_ms=0
	elif due and (periodic_allowed or reset_while_blocked):
		# A cinematic gates success without banking an overdue result check.
		next.clock_ms=0
	return next
