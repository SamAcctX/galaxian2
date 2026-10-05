extends "res://tests/desktop_controller_resume.gd"
func verify_feedback_preferences() -> void:
	check(app.preferences.values.flight_hud_scale==4 and app.preferences.values.flight_hud_filter=="nearest" and app.preferences.values.antialiasing=="msaa4","Fresh Resume lost the flight HUD or antialiasing choices")
