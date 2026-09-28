extends RefCounted
## Catalogue rockets and missiles share travel, contacts and original exhaust.
const Fitting=preload("res://src/content/ordinary_fitting_definitions.gd")
const AEM=preload("res://src/content/aem.gd")
const Tracks=preload("res://src/content/animation_tracks.gd")
const Ranges=preload("res://src/content/scenery_effect_resources.gd")

static func declaration(item_id: int, kind: int) -> Dictionary:
	if not ((kind==4 and item_id>=31 and item_id<=35) or (kind==5 and item_id>=36 and item_id<=40)):return {}
	return {"guided":kind==5,"trail_id":39,"retention_ms":2000,"attached_model_id":14250,"scenery_damage":9999,"penetrates_scenery":true}

static func resolved(weapon: Dictionary) -> bool:
	var row:=declaration(int(weapon.get("item_id",-1)),int(weapon.get("kind",-1)))
	return not row.is_empty() and weapon.get("category")==1 and weapon.get("launch_mode")=="ordinary" and weapon.get("projectile_capacity")==5 and weapon.get("secondary_projectile")==row and not weapon.get("nonplayer_source",false) and not weapon.has("dispersion")

static func model(bindings: RefCounted, weapon: Dictionary) -> Dictionary:
	if not Fitting.available(bindings) or not resolved(weapon):return {}
	var id:=int(bindings.mido_travel.ordinary_fitting.primary.projectile_model_ids[weapon.item_id])
	var resource: String=bindings.resolve(id,"mesh")
	var attached: String=bindings.resolve(int(weapon.secondary_projectile.attached_model_id),"mesh")
	return {} if resource.is_empty() or attached.is_empty() else {"id":id,"resource":resource,"attached_resource":attached,"captured_up":true}

static func presentation(library: RefCounted,bindings: RefCounted,weapon: Dictionary) -> Dictionary:
	var mapping:=model(bindings,weapon)
	if mapping.is_empty() or library.manifest.get("content_id")!=bindings.base_content_id:return {}
	var reader:=AEM.new()
	var body:=reader.decode(library.read_resource(mapping.resource,AEM.MAX_BYTES))
	if body.is_empty() or not Tracks.has_identity_tracks(body.surfaces):return {}
	var attached:=reader.decode(library.read_resource(mapping.attached_resource,AEM.MAX_BYTES))
	if attached.is_empty() or bindings.material_for_mesh(mapping.attached_resource,"high").get("render_type")!=2:return {}
	var timing:=Ranges.playback_range(attached.surfaces,true)
	if timing.is_empty():return {}
	return {"model_id":mapping.id,"resource":mapping.resource,"rules":bindings.opening_staging.projectile_visuals.duplicate(true),
		"attachment":{"model_id":int(weapon.secondary_projectile.attached_model_id),"resource":mapping.attached_resource,
			"start_ms":timing.start_ms,"end_ms":timing.end_ms,"time_ms":timing.start_ms,"playing":true}}
