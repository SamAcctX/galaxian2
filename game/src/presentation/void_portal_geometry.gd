extends "res://src/presentation/portal_geometry.gd"
const Definitions=preload("res://src/content/void_portal_definitions.gd")
const NativePortal=preload("res://src/simulation/void_portal.gd")

## The actual selected40 native owner keeps its own story/source identity.
## Reuse the original animated geometry without relabelling it as cursor33.
func build_selected40(library: RefCounted,visuals: RefCounted,bindings: RefCounted,portal: RefCounted) -> bool:
	if not _identity.is_empty() or bindings==null or not portal is NativePortal or portal.selected40_construction_owner()==null:return reject("Selected40 rendering requires its fresh native portal owner")
	var state: Dictionary=portal.portal_snapshot()
	if state.get("scope")!="selected40_source_portal_component" or state.get("campaign_cursor")!=40 or state.get("mission_kind")!=161:return reject("Selected40 rendering lost its actual story selection")
	for key in ["base_content_id","binding_id"]:
		if state.get(key)!=bindings.get(key):return reject("Selected40 portal belongs to another source")
	var identity:={}
	for key in ["base_content_id","binding_id","campaign_cursor","system_id","station_id","mission_kind","model_id","slot","scope","source_station_id","source_system_id"]:identity[key]=state[key]
	return _build_portal(library,visuals,bindings,identity)

## The ordinary portal has already been admitted by its native contact owner.
## Keep its route immutable while sampling the shared original model clock.
func build_ordinary(library: RefCounted,visuals: RefCounted,bindings: RefCounted,portal: RefCounted) -> bool:
	if bindings==null or not portal is NativePortal:return reject("Ordinary portal rendering requires its native owner")
	var state: Dictionary=portal.portal_snapshot()
	if state.get("ordinary_mode") not in ["source_entry","void_return"]:return reject("Ordinary portal rendering requires its retained route")
	for key in ["base_content_id","binding_id"]:
		if state.get(key)!=bindings.get(key):return reject("Ordinary portal belongs to another source")
	var identity:={}
	for key in ["base_content_id","binding_id","campaign_cursor","system_id","station_id","mission_kind","model_id","slot","ordinary_mode","source_station_id","source_system_id"]:identity[key]=state[key]
	return _build_portal(library,visuals,bindings,identity)

func build(library: RefCounted,visuals: RefCounted,bindings: RefCounted,context: Dictionary) -> bool:
	if bindings==null or not Definitions.selected(bindings.mido_travel,context):return reject("This world has no returning Void portal")
	var rules: Dictionary=bindings.mido_travel.void_portal
	return _build_portal(library,visuals,bindings,{"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,
		"campaign_cursor":int(context.campaign_cursor),"system_id":int(context.system_id),"station_id":int(context.station_id),
		"mission_kind":int(context.mission_kind),"model_id":int(rules.portal.model_id),"slot":int(rules.portal.environment_slot)})
