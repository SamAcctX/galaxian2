extends "res://tests/nehma_visit_application.gd"
## Follow only the retained, source-defined available systems to Ga'kkrr.
const VisitRoute=preload("res://src/simulation/system_navigation.gd")

func visit_spec(original: Dictionary) -> Dictionary:
	if not PostProbeCampaign.gakkrr_world_available(definitions.mido_travel) or original.campaign_cursor!=35:
		check(false,"Resume earned mission35 only after its Gakkrr declarations and native world are implemented");return {}
	var navigation:=VisitRoute.new()
	if not navigation.configure(definitions,catalogue,original.contracts.lounges.system_availability):check(false,navigation.error);return {}
	var path: Array=navigation.route(int(original.loadout.system_id),5)
	if path.is_empty():check(false,navigation.error);return {}
	var route: Array=[[int(original.loadout.system_id),int(original.loadout.station_id)]]
	var gate_field:=int(definitions.mido_travel.free_navigation.gate_station_field)
	for index in range(1,path.size()):
		var system_id: int=path[index]
		var station_id:=29 if index==path.size()-1 else int(catalogue.tables.systems[system_id].fields[gate_field])
		if station_id<0:check(false,"The source route has no ordinary gate station");return {}
		route.append([system_id,station_id])
	if path.size()==1:route.append([5,29])
	return {"cursor":35,"name":"gakkrr","route":route}
