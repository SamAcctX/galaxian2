extends RefCounted
## Shared complete-payload projection for explicit, additive declaration sources.
## Validated pack readers supply the only permitted field and source extents.
const Frozen=preload("res://src/simulation/readonly_state.gd")
const KEYS=["base_content_id","binding_id","source_executable_sha256","source_executable_bytes","architecture","records_sha256"]

static func describe(header: Dictionary,body: Dictionary,previous_reader: String,next_reader: String,field: String,spans: Dictionary,valid: bool) -> Dictionary:
	if header.get("reader") not in [previous_reader,next_reader]:return {}
	var result:={"reader":header.reader,"payload_sha256":JSON.stringify(body).sha256_text(),"preceding_payload_sha256":""}
	for key in KEYS:result[key]=header[key]
	if header.reader==next_reader and valid:
		var preceding:=body.duplicate(true)
		preceding.reader=previous_reader
		preceding.mido_travel.erase(field)
		for key in spans:
			if not preceding.mido_travel.provenance.has(key):return Frozen.freeze(result)
			preceding.mido_travel.provenance.erase(key)
		result.preceding_payload_sha256=JSON.stringify(preceding).sha256_text()
	return Frozen.freeze(result)

static func receipt(previous: Dictionary,current: Dictionary,previous_reader: String,next_reader: String,scope: String) -> Dictionary:
	if previous.get("reader")!=previous_reader or current.get("reader")!=next_reader:return {}
	if previous.get("payload_sha256","").is_empty() or previous.payload_sha256!=current.get("preceding_payload_sha256"):return {}
	for key in ["base_content_id","source_executable_sha256","source_executable_bytes","architecture"]:
		if previous.get(key)!=current.get(key):return {}
	if previous.get("binding_id")==current.get("binding_id"):return {}
	return Frozen.freeze({"scope":scope,"base_content_id":previous.base_content_id,
		"binding_id":previous.binding_id,"source_binding_id":current.binding_id,
		"source_executable_sha256":previous.source_executable_sha256,
		"base_records_sha256":previous.records_sha256,"source_records_sha256":current.records_sha256,
		"preceding_payload_sha256":previous.payload_sha256})
