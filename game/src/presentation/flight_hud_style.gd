extends RefCounted
## Flight artwork has its own scale, independent of menu layout and gameplay.
static var multiplier:=1.0
static var nearest:=true

static func apply(values: Dictionary) -> void:
	multiplier=float(values.get("flight_hud_scale",1))
	nearest=values.get("flight_hud_filter","nearest")=="nearest"

static func art(mobile: bool) -> float:return (1.0 if mobile else 0.5)*multiplier
static func font_size(original: int) -> int:return roundi(original*multiplier)
static func filtering() -> int:return CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
