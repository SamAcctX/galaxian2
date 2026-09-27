extends "res://tests/freelance_unlocked_application.gd"
## A fresh application opens the native checkpoint through its Resume input.

func _initialize() -> void:call_deferred("run_resumed_job")
