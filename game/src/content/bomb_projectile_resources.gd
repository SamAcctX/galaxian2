extends RefCounted
## Original animated AMR body and its attached additive model.
const Bombs=preload("res://src/content/emp_bombs_definitions.gd")
const AEM=preload("res://src/content/aem.gd")
const Ranges=preload("res://src/content/scenery_effect_resources.gd")
const Surface=preload("res://src/presentation/animated_additive_model.gd")

static func prepare(library: RefCounted,bindings: RefCounted,weapon: Dictionary) -> Dictionary:
	var declaration:=Bombs.declaration(int(weapon.get("item_id",-1)))
	if declaration.is_empty() or declaration.kind!=7 or weapon.get("kind")!=7:return {}
	if library==null or bindings==null or library.manifest.get("content_id")!=weapon.get("base_content_id") or bindings.base_content_id!=weapon.base_content_id or bindings.binding_id!=weapon.get("binding_id"):return {}
	var models:=[]
	for id in [declaration.model_id,declaration.attachment_id]:
		var path: String=bindings.resolve(id,"mesh")
		if path.is_empty() or bindings.material_for_mesh(path,"high").get("render_type")!=(28 if models.is_empty() else 2):return {}
		var reader:=AEM.new()
		var data:=reader.decode(library.read_resource(path,AEM.MAX_BYTES))
		if data.is_empty() or not data.surfaces.all(func(surface):return Surface.supported_surface(surface)):return {}
		if models.is_empty() and not data.surfaces.all(func(surface):return opaque_color_is_white(surface)):return {}
		var timing:=Ranges.playback_range(data.surfaces,true)
		if timing.is_empty():return {}
		models.append({"model_id":id,"resource":path,"start_ms":timing.start_ms,"end_ms":timing.end_ms,"time_ms":timing.start_ms,"playing":true,"loop":not models.is_empty()})
	return {"models":models}

static func opaque_color_is_white(surface: Dictionary) -> bool:
	# Some authored deployment surfaces contain constant-white export tracks,
	# with tiny interpolation noise. They do not fade the opaque body.
	for track in surface.tracks.get("scalar",[]):
		if track.dimensions!=1:return false
		for index in range(1,track.keys.size(),2):
			if not is_equal_approx(float(track.keys[index]),100.0):return false
	return true
