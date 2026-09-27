extends "res://src/simulation/campaign_visit.gd"
## Immediate authored conversations reuse the campaign's page/navigation owner.
## The enclosing runner commits the result; opening a page never earns progress.
const Context=preload("res://src/simulation/mission_context.gd")
const StationContext=preload("res://src/simulation/mission_station_context.gd")

func prepare(bindings: RefCounted,library: RefCounted,context: RefCounted,kind: String) -> bool:
	if not _state.is_empty() or not (context is Context or context is StationContext) or kind not in ["briefing","success","failure"]:return reject("Conversation requires a fresh admitted mission")
	var recipe: Dictionary=context.recipe()
	var events: Array=recipe.briefing if kind=="briefing" else recipe.result.lines
	var rules:={"campaign_cursor":recipe.cursor,"mission":recipe.mission,"next_cursor":recipe.next_cursor,
		"next_mission":recipe.next_mission,"reward_credits":int(recipe.get("career",{}).get("reward_credits",recipe.mission.reward)),"events":events}
	if not _configure_lines(bindings,library,recipe.cursor,recipe.mission,rules):return false
	if kind=="failure":
		_lines=Campaign.Outcome.failure_lines(bindings,library)
		_failure_rules=bindings.mido_travel.kappa_outcome.failure.duplicate(true)
		_result_mode=true;_state.outcome="failed"
	if _lines.is_empty():return reject("The mission conversation has no authored pages")
	_state.phase="conversation"
	return true
