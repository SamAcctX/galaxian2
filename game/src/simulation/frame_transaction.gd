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
