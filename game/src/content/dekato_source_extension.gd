extends RefCounted
## Explicit203 declarations retain the exact original202 identity and v9 receipt.
const Rules=preload("res://src/content/dekato_convoy_definitions.gd")
const Identity=preload("res://src/content/source_extension_identity.gd")
const Frozen=Identity.Frozen

static func describe(header: Dictionary,body: Dictionary) -> Dictionary:
	return Identity.describe(header,body,"resource-registration-v202","resource-registration-v203","dekato_convoy",Rules.SPANS,Rules.parameters(body.get("mido_travel",{}).get("dekato_convoy")))

static func receipt(previous: Dictionary,current: Dictionary) -> Dictionary:
	return Identity.receipt(previous,current,"resource-registration-v202","resource-registration-v203","dekato_same_source_declaration_extension")
