extends RefCounted
## Translate one observed-frame pilot sample into ordinary desktop events.
## The caller advances the Host once afterward, then observes the new frame.

static func key(viewport: Viewport,code: Key,down: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
	viewport.push_input(event,true)

static func press(viewport: Viewport,code: Key) -> void:
	key(viewport,code,true);key(viewport,code,false)

static func apply(app: Control,viewport: Viewport,input: Dictionary,delta_us: int) -> Dictionary:
	if app.session.can_control():
		# snapshot.throttle belongs to the last accepted flight frame. Re-reading
		# it between key presses cannot observe the pending control setting.
		var current: float=app.session.snapshot().throttle
		var count:=roundi(absf(current-float(input.throttle))*10.0)
		for adjustment in count:
			press(viewport,KEY_BRACKETRIGHT if current<float(input.throttle) else KEY_SLASH)
		var held: Dictionary=app._controls.snapshot()
		if held.held.fire!=bool(input.fire):key(viewport,KEY_SPACE,bool(input.fire))
		if (held.strafe<0)!=(input.strafe<0):key(viewport,KEY_A,input.strafe<0)
		if (held.strafe>0)!=(input.strafe>0):key(viewport,KEY_D,input.strafe>0)
		var motion:=InputEventMouseMotion.new()
		motion.screen_relative=Vector2(-input.commands.y,input.commands.x)*600.0*float(delta_us)/1000000.0/app._controls.mouse_sensitivity
		motion.relative=motion.screen_relative;viewport.push_input(motion,true)
	app._controls.advance_mouse(float(delta_us)/1000000.0)
	return app._controls.snapshot()
