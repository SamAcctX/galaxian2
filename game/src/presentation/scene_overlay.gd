extends CanvasLayer
## Scene-owned interface drawn after any optional world display effect.
var error:=""
var _view: Node

func _enter_tree() -> void:
	error=""
	var candidate: Node=get_viewport().get_parent()
	if candidate!=null and candidate.has_method("register_overlay"):
		if candidate.register_overlay(self):_view=candidate
		else:error=candidate.error

func _exit_tree() -> void:
	if is_instance_valid(_view):_view.unregister_overlay(self)
	_view=null
