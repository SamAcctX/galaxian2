extends RefCounted
## Explicit204 declarations extend203, never original202 save identity or v9.
const Rules=preload("res://src/content/nehma_return_definitions.gd")
const Identity=preload("res://src/content/source_extension_identity.gd")
const Frozen=Identity.Frozen

static func describe(header: Dictionary,body: Dictionary) -> Dictionary:
	return Identity.describe(header,body,"resource-registration-v203","resource-registration-v204","nehma_return",Rules.SPANS,Rules.parameters(body.get("mido_travel",{}).get("nehma_return")))

static func receipt(previous: Dictionary,current: Dictionary) -> Dictionary:
	return Identity.receipt(previous,current,"resource-registration-v203","resource-registration-v204","nehma_same_source_declaration_extension")
