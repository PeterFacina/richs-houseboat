extends SpotLight3D


func _init() -> void:
	name = "PlayerFlashlight"
	light_color = Color("#fff3d9")
	light_energy = 1.65
	spot_range = 24.0
	spot_attenuation = 1.15
	spot_angle = 26.0
	distance_fade_enabled = true
	distance_fade_begin = 38.0
	distance_fade_length = 12.0
	hide()
