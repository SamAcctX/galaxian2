extends RefCounted
## A flight frame is built on a private fork and discarded whole if any step
## fails. Owners forked while that frame is being built belong only to it, so
## their own all-or-nothing updates may change them in place instead of forking
## again. Outside a frame, or for owners shared with the accepted frame, `owns`
## is false and callers keep their private fork.
static var current:=0
static var _serial:=0

static func begin() -> int:
	_serial+=1;current=_serial
	return current

static func end(token: int) -> void:
	if current==token:current=0

static func owns(token: int) -> bool:return current!=0 and token==current

## GOF2_FRAME_SELFCHECK=1 (read once at startup) builds every flight frame
## twice, on forks alone and then inside the transaction, and refuses a frame
## whose two builds differ or that changed the frame it was built from. It
## proves that the owners updated in place leave the same state as copies.
static var selfcheck: bool=OS.get_environment("GOF2_FRAME_SELFCHECK")=="1"

static func check(before: Dictionary,after: Dictionary,forked: RefCounted,forked_error: String,result: RefCounted,result_error: String) -> String:
	var found:=difference(before,after)
	if not found.is_empty():return "Frame self-check: building the frame changed the accepted frame at "+found
	if (forked==null)!=(result==null) or forked_error!=result_error:return "Frame self-check: the forked and in-place builds fail differently: "+forked_error+" / "+result_error
	if result!=null:
		found=difference(forked.snapshot(),result.snapshot())
		if not found.is_empty():return "Frame self-check: the forked and in-place builds differ at "+found
		if forked.get("_random")!=result.get("_random"):return "Frame self-check: the forked and in-place builds differ in their random state"
	return ""

## The first key path at which two snapshots differ, or "".
static func difference(a: Variant,b: Variant,path:="") -> String:
	if typeof(a)!=typeof(b):return path+" (type)"
	if a is Dictionary:
		for key in a:
			if not b.has(key):return path+"/"+str(key)+" (missing)"
			var found:=difference(a[key],b[key],path+"/"+str(key))
			if not found.is_empty():return found
		for key in b:
			if not a.has(key):return path+"/"+str(key)+" (extra)"
		return ""
	if a is Array:
		if a.size()!=b.size():return path+" (size)"
		for i in a.size():
			var found:=difference(a[i],b[i],path+"/"+str(i))
			if not found.is_empty():return found
		return ""
	if a is float and is_nan(a) and is_nan(b):return ""
	return "" if a==b else path
