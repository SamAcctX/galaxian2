extends RefCounted
## Read-only per-frame observations that owners cache until they change.
## Debug builds compare each cached read with a fresh build, so a missed
## invalidation fails a test instead of showing a stale value to the player.
## GOF2_FAST=1 skips that comparison when measuring the editor build.
static var verify:=OS.is_debug_build() and OS.get_environment("GOF2_FAST")!="1"

static func checked(cached: Dictionary,fresh: Callable,owner: String) -> Dictionary:
	if verify and cached!=fresh.call():push_error(owner+" served a stale cached observation")
	return cached
