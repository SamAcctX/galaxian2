extends RefCounted
## Validate one coherent set of imported proof extents against its source anchor.
const Fonts = preload("res://src/content/font_definitions.gd")
const Numbers = preload("res://src/content/opening_definitions.gd")

static func matches(provenance: Variant, origin: int, executable_bytes: int, layouts: Array) -> bool:
	if not provenance is Dictionary or provenance.is_empty():return false
	var accepted:=0
	for layout in layouts:
		if provenance.size()!=layout.size():continue
		var valid:=true
		for key in layout:
			var rule: Array=layout[key]
			var span: Variant=provenance.get(key)
			if not Fonts.extent(span,"offset","bytes",[rule[1]],executable_bytes) or int(span.offset)!=origin+int(rule[0]):
				valid=false;break
		if valid:accepted+=1
	return accepted==1

## Android proofs sit inside named functions: each span is checked against its
## own function's file offset (`anchor`), never against other spans.
static func anchored(provenance: Variant, executable_bytes: int, spans: Dictionary) -> bool:
	if not provenance is Dictionary or provenance.is_empty() or provenance.size()!=spans.size():return false
	for key in spans:
		var rule: Array=spans[key]
		var span: Variant=provenance.get(key)
		if not Fonts.extent(span,"offset","bytes",[rule[1]],executable_bytes) or not Numbers.integer(span.get("anchor"),0,executable_bytes-1) or int(span.offset)!=int(span.anchor)+int(rule[0]):return false
	return true
