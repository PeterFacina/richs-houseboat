extends RefCounted

var invert_pitch := false
var aim := Vector2.ZERO


func mouse_motion(relative: Vector2, sensitivity: float, heading: float, lead_limit: float,
		pitch_limit: float, cockpit_look: bool) -> void:
	var yaw_gain := 1.0 if cockpit_look else 1.65
	var turn := Vector2(-relative.x * yaw_gain, -relative.y) * sensitivity
	aim.x = wrapf(aim.x + turn.x, -PI, PI)
	if not is_zero_approx(turn.x):
		var lead := wrapf(aim.x - heading, -PI, PI)
		aim.x = wrapf(heading + clampf(lead, -lead_limit, lead_limit), -PI, PI)
	var pitch_change := -turn.y if invert_pitch and not cockpit_look else turn.y
	aim.y = clampf(aim.y + pitch_change, -pitch_limit, pitch_limit)
