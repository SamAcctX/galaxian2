extends RefCounted
## Source-declared empty child references. Real missing meshes remain errors.
const Equal=preload("res://src/content/opening_escape_definitions.gd")
const VALUES={"scope":"vossk_empty_lod_children","hull_catalogue_id":13,"resource_ids":[17040,17041]}
const SPANS={"vossk_traffic_lod_registry_main":[-648475,308015],"vossk_traffic_lod_registry_audio":[-340460,51233],"vossk_traffic_lod_registry_quality":[-289227,44631],"vossk_traffic_lod_child_loader":[-722330,268],"vossk_traffic_lod_lookup":[1149162,78],"vossk_traffic_lod_attach":[1162442,108],"vossk_traffic_lod_append":[1132218,42]}
const MAC_SPANS={"vossk_traffic_lod_registry_main":[-653836,311889],"vossk_traffic_lod_registry_audio":[-341947,51233],"vossk_traffic_lod_registry_quality":[-290714,44630],"vossk_traffic_lod_child_loader":[-728226,268],"vossk_traffic_lod_lookup":[1147074,78],"vossk_traffic_lod_attach":[1159762,108],"vossk_traffic_lod_append":[1131410,42]}

static func parameters(data: Variant) -> bool:
	return Equal.equal_value(data,VALUES)
