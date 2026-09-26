extends RefCounted
## Read-only overlay of separately imported, same-executable mesh declarations.
## Original bindings, base identity and saved identity are never modified.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
var error:=""
var base_content_id:=""
var binding_id:=""
var _bindings: RefCounted
var _extra:={}
var _receipt:={}

func configure(bindings: RefCounted,manifest: Dictionary,supplement_path:="") -> bool:
	if _bindings!=null:return reject("Sequence mesh resources are prepared only once")
	if not bindings is Bindings or bindings.base_content_id!=manifest.get("content_id") or manifest.get("profile",{}).get("edition")!="mac-full-hd":return reject("Sequence meshes require matching Mac content")
	var extra:={};var receipt:={}
	if not supplement_path.is_empty():
		var file:=FileAccess.open(supplement_path,FileAccess.READ)
		if file==null or file.get_length()>65536:return reject("Missing or oversized mesh resource supplement")
		var text:=file.get_as_text()
		var body: Variant=JSON.parse_string(text)
		if not body is Dictionary or body.get("schema")!=1 or body.get("reader")!="mac-mesh-registration-supplement-v1" or not body.get("binding_header") is Dictionary:return reject("Unsupported mesh resource supplement")
		var header: Dictionary=body.binding_header
		for key in ["base_content_id","binding_id","source_executable_sha256","records_sha256"]:
			if not Library.valid_hash(header.get(key)):return reject("Invalid supplemental mesh provenance")
		var identity:="gof2-bindings-v1\n%s\n%s\nx86_64\n%s\n"%[header.base_content_id,header.source_executable_sha256,header.records_sha256]
		if header.base_content_id!=bindings.base_content_id or header.binding_id!=bindings.binding_id or header.architecture!="x86_64" or identity.sha256_text()!=bindings.binding_id:return reject("Mesh supplement belongs to another binding source")
		if not Bindings.bounded_integer(header.get("source_executable_bytes"),28,64*1024*1024):return reject("Invalid supplemental mesh source extent")
		if not body.get("registrations") is Array or body.registrations.is_empty() or body.registrations.size()>32:return reject("Invalid supplemental mesh population")
		var paths:={}
		for row in body.registrations:
			if not row is Dictionary or not Bindings.bounded_integer(row.get("id"),0,65535) or not Bindings.bounded_integer(row.get("material_id"),0,65535) or not Bindings.bounded_integer(row.get("source_offset"),0,int(header.source_executable_bytes)-1):return reject("Invalid supplemental mesh declaration")
			var id:=int(row.id)
			if extra.has(id) or bindings.records.has(id) or bindings.materials.has(id) or row.get("kind")!="mesh" or row.get("registration_type")!=4 or row.get("mesh_flags")!=0:return reject("Duplicate, conflicting or unsupported supplemental mesh")
			var path: Variant=row.get("resource")
			if not path is String or paths.has(path) or manifest.files.get(path,{}).get("kind")!="mesh":return reject("Supplemental mesh is absent or duplicated in this content")
			for rows in bindings.records.values():
				for existing in rows:
					if existing.resource==path:return reject("Supplement cannot shadow an existing mesh path")
			if bindings.resolve_material(int(row.material_id)).is_empty():return reject(bindings.error)
			extra[id]=row.duplicate(true);paths[path]=true
		receipt={"supplement_sha256":text.sha256_text(),"source_executable_sha256":header.source_executable_sha256,"registrations":extra.values().duplicate(true)}
	_bindings=bindings;_extra=extra;_receipt=receipt
	base_content_id=bindings.base_content_id;binding_id=bindings.binding_id
	return true

func resolve(identifier: int,kind:="") -> String:
	if _extra.has(identifier):
		if kind not in ["","mesh"]:error="Supplemental resource is a mesh";return ""
		return _extra[identifier].resource
	var path: String=_bindings.resolve(identifier,kind);error=_bindings.error;return path

func material_for_mesh(path: String,quality:="high") -> Dictionary:
	for row in _extra.values():
		if row.resource==path:
			var result: Dictionary=_bindings.resolve_material(int(row.material_id),quality);error=_bindings.error;return result
	var result: Dictionary=_bindings.material_for_mesh(path,quality);error=_bindings.error;return result

func receipt() -> Dictionary:return _receipt.duplicate(true)
func reject(message: String) -> bool:error=message;return false
