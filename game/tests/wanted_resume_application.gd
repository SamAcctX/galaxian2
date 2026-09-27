extends "res://tests/wanted_unlocked_application.gd"
## Resume the actual accepted or paid bounty in a fresh application.

func _initialize() -> void:call_deferred("run_resumed_job")
