extends RefCounted
## The player's Graphics quality option (original Options row: Low 0, Medium
## 0.5, High 1.0). It scales the geometry detail input and, below 0.7, turns
## off the camera dust and space fog, as the original help text states.
static var level:=1.0

static func effects_enabled() -> bool:return level>0.7
