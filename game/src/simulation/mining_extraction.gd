extends RefCounted
## Plans ore yield and prepares cargo/asteroid retirement as one candidate.
## The flight accepts both returned owners together. Planning alone mutates
## nothing; neither operation grants mission progress, credits or achievements.
const Drill=preload("res://src/simulation/mining_drill.gd")
const Definitions=preload("res://src/content/mining_drill_definitions.gd")
const Numbers=preload("res://src/content/opening_definitions.gd")
const Scenery=preload("res://src/simulation/opening_scenery.gd")
const Cargo=preload("res://src/simulation/flight_cargo.gd")
var error:=""

## Retain only quantities that the accepted extraction actually inserted. Missing
## fields stay missing until a successful extraction establishes lifetime history.
static func retained_lifetime(progress: Dictionary, receipt: Dictionary) -> Dictionary:
	var ore: Variant=receipt.get("ore_tons")
	var core_id: Variant=receipt.get("core_item_id")
	if not Numbers.integer(ore,0,2147483647) or not core_id is int or core_id < -1 or core_id > 2147483647:return {}
	var retained:=progress.duplicate(true)
	var current_ore: Variant=retained.get("mined_ore_tons",0)
	var current_cores: Variant=retained.get("mined_cores",0)
	if not Numbers.integer(current_ore,0,2147483647) or not Numbers.integer(current_cores,0,2147483647):return {}
	if int(ore)>2147483647-int(current_ore):return {}
	var core_delta:=1 if int(core_id)>=0 else 0
	if core_delta>2147483647-int(current_cores):return {}
	if int(ore)>0 or retained.has("mined_ore_tons"):retained.mined_ore_tons=int(current_ore)+int(ore)
	if core_delta>0 or retained.has("mined_cores"):retained.mined_cores=int(current_cores)+core_delta
	return retained

static func retain_contract_owner(owner: RefCounted,receipt: Dictionary) -> bool:
	if owner==null:return false
	var script: Script=owner.get_script()
	if script==null or script.resource_path!="res://src/simulation/contract_session.gd":return false
	var state: Variant=owner.get("_state")
	if not state is Dictionary or state.is_empty():return false
	for key in ["base_content_id","binding_id"]:
		if receipt.get(key)!=state.get(key):return false
	var retained:=retained_lifetime(state.get("progress",{}),receipt)
	if retained.is_empty():return false
	var next: Dictionary=state.duplicate(true);next.progress=retained
	owner.set("_state",next)
	return true

func evaluate(bindings: RefCounted, catalogues: RefCounted, drill: RefCounted, scenery: RefCounted, cargo: RefCounted, hard_difficulty: bool) -> Dictionary:
	error=""
	if drill==null or drill.get_script()!=Drill or scenery==null or scenery.get_script()!=Scenery or cargo==null or cargo.get_script()!=Cargo:return fail("Extraction requires its live drill, scenery and cargo owners")
	var identity: RefCounted=scenery.presentation_identity()
	if identity==null or drill.field_identity()!=identity or cargo.field_identity()!=identity:return fail("Extraction belongs to another live field")
	if not cargo.matches_mined_field(scenery.snapshot()):return fail("Cargo and scenery have different mining histories")
	var held: Dictionary=cargo.snapshot()
	var state: Dictionary=drill.snapshot()
	for key in ["base_content_id","binding_id"]:
		if held.get(key)!=state.get(key):return fail("Extraction cargo belongs to another content identity")
	var result:=plan(bindings,catalogues,drill,held.free_space,hard_difficulty)
	if result.is_empty():return {}
	var next_cargo: RefCounted=cargo.fork_for_frame()
	var next_scenery: RefCounted=scenery.fork_for_frame()
	if not next_cargo.add_entries(result.entries):return fail(next_cargo.error)
	if not next_scenery._consume_mined(state):return fail(next_scenery.error)
	if not next_cargo._record_mining(int(state.object_index)):return fail(next_cargo.error)
	# Only this complete candidate may replace the flight's accepted owners.
	# Replaying against that candidate fails because its asteroid is retired.
	return {"cargo":next_cargo,"scenery":next_scenery,"extraction":result}

func plan(bindings: RefCounted, catalogues: RefCounted, drill: RefCounted, free_space: Variant, hard_difficulty: bool) -> Dictionary:
	error=""
	if bindings==null or catalogues==null or drill==null or drill.get_script()!=Drill or not Definitions.parameters(bindings.mining_drill):return fail("Extraction requires a supported native drill")
	var state: Dictionary=drill.snapshot()
	if state.is_empty() or state.get("base_content_id")!=bindings.base_content_id or state.get("binding_id")!=bindings.binding_id or catalogues.content_id!=bindings.base_content_id:return fail("Extraction belongs to another content identity")
	if state.phase not in ["extracted","failed","stopped"]:return fail("Stop or finish drilling before extracting cargo")
	if not Numbers.integer(free_space,0,2147483647):return fail("Extraction requires the available cargo space")
	var rules: Dictionary=bindings.mining_drill
	var quantity:=int(state.ore_tons)
	if hard_difficulty and not state.all_layers:quantity=int(Drill.f32(float(quantity)*float(rules.hard_partial_multiplier)))
	quantity=mini(int(free_space),quantity)
	var remaining:=int(free_space)
	var entries:=[]
	var core_id:=int(rules.special_core_id) if state.item_id==int(rules.special_ore_id) else int(state.item_id)+int(rules.core_item_offset)
	var items: Array=catalogues.tables.get("items",[])
	if state.item_id<0 or state.item_id>=items.size() or state.core and (core_id<0 or core_id>=items.size()):return fail("Extracted ore or core is unavailable in this catalogue")
	if remaining>0 and state.core:
		entries.append({"item_id":core_id,"quantity":1});remaining-=1
	quantity=mini(remaining,quantity)
	if quantity>0:
		entries.append({"item_id":int(state.item_id),"quantity":quantity});remaining-=quantity
	return {"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"object_index":state.object_index,
		"phase":state.phase,"all_layers":state.all_layers,"ore_item_id":state.item_id,"ore_tons":quantity,
		"core_item_id":core_id if state.core and int(free_space)>0 else -1,"entries":entries,
		"free_space_before":int(free_space),"free_space_after":remaining,"cargo_added":int(free_space)-remaining,
		"consume_asteroid":bool(rules.consume_asteroid),"hard_difficulty":hard_difficulty}

func fail(message: String) -> Dictionary:error=message;return {}
