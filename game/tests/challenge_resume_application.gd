extends "res://tests/challenge_unlocked_application.gd"
## Resume the actual accepted or settled contest in a fresh application.

func _initialize() -> void:call_deferred("run_resumed_job")
