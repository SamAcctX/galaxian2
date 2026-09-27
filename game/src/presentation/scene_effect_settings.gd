extends RefCounted
## Presentation-scoped preferences shared by existing and newly created views.
signal changed(enabled: bool)
var bloom_enabled:=false

func apply(values: Dictionary) -> void:
	var enabled: bool=values.get("bloom",false)
	if enabled==bloom_enabled:return
	bloom_enabled=enabled;changed.emit(enabled)

func bind(view: Node) -> void:
	changed.connect(view.apply_bloom_preference)
	view.apply_bloom_preference(bloom_enabled)

static func for_view(view: Node) -> RefCounted:
	var ancestor:=view.get_parent()
	while ancestor!=null:
		if ancestor.has_method("scene_effect_settings"):return ancestor.scene_effect_settings()
		ancestor=ancestor.get_parent()
	return null
