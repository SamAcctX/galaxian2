extends "res://tests/protection_unlocked_application.gd"

func _initialize() -> void:call_deferred("run_resumed_job")
