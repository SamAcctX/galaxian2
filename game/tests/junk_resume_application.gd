extends "res://tests/junk_unlocked_application.gd"
## Resume the actual accepted or settled Junk save in a fresh application.

func _initialize() -> void:call_deferred("run_resumed_job")
