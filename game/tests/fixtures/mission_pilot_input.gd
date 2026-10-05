extends RefCounted
## Translate one observed-frame pilot sample into ordinary desktop events.
## The caller advances the Host once afterward, then observes the new frame.

static func key(viewport: Viewport,code: Key,down: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
	viewport.push_input(event,true)

static func press(viewport: Viewport,code: Key) -> void:
	key(viewport,code,true);key(viewport,code,false)

static func apply(app: Control,viewport: Viewport,input: Dictionary,delta_us: int,observation: RefCounted=null) -> Dictionary:
	# Never silently re-observe while retaining controls planned from stale data.
	if observation!=null and not observation.matches(app.session):
		return {"error":"Expired pilot observation: re-observe and plan before delivering input"}
	if app.session.can_control():
		# This scripted sample owns its relative-motion interval. Consume mouse
		# events queued while the harness yielded, before its new root event.
		# Do not clear held keys/actions or change production event accumulation.
		app._controls.advance_mouse(0)
		# snapshot.throttle belongs to the last accepted flight frame. Re-reading
		# it between key presses cannot observe the pending control setting.
		var accepted: Dictionary=app.session.snapshot() if observation==null else observation.read(app.session)
		var current: float=accepted.throttle
		var count:=roundi(absf(current-float(input.throttle))*10.0)
		for adjustment in count:
			press(viewport,KEY_BRACKETRIGHT if current<float(input.throttle) else KEY_SLASH)
		var held: Dictionary=app._controls.snapshot()
		if held.held.fire!=bool(input.fire):key(viewport,KEY_SPACE,bool(input.fire))
		if (held.strafe<0)!=(input.strafe<0):key(viewport,KEY_A,input.strafe<0)
		if (held.strafe>0)!=(input.strafe>0):key(viewport,KEY_D,input.strafe>0)
		# Captured mouse steering keeps a cursor offset: move it from the
		# current command to the requested one (screen x turns, y pitches).
		var have: Vector2=app._controls.snapshot().command
		var change:=Vector2(input.commands.x-have.x,have.y-input.commands.y)
		var motion:=InputEventMouseMotion.new()
		motion.screen_relative=Vector2(change.y,change.x)*Vector2(app.viewport.size)*app._controls.AIM_HALF_AREA/app._controls.mouse_sensitivity
		motion.relative=motion.screen_relative;viewport.push_input(motion,true)
	app._controls.advance_mouse(float(delta_us)/1000000.0,Vector2(app.viewport.size))
	if observation!=null:observation.invalidate()
	return app._controls.snapshot()
