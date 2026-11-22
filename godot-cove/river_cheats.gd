extends PanelContainer

signal dismissed

var flight: CheckButton
var speed: CheckButton
var speed_scale: HSlider


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#132f3b")
	style.border_color = Color("#8ce3cc")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)
	var heading := Label.new()
	heading.text = "Solo cheats"
	heading.add_theme_font_size_override("font_size", 24)
	rows.add_child(heading)
	flight = CheckButton.new()
	flight.text = "Flight"
	rows.add_child(flight)
	var hint := Label.new()
	hint.text = "WASD to fly  ·  Space up  ·  Ctrl/Shift down"
	rows.add_child(hint)
	speed = CheckButton.new()
	speed.text = "Enable movement speed multiplier"
	rows.add_child(speed)
	var speed_label := Label.new()
	speed_label.text = "Movement speed: 3.0×"
	rows.add_child(speed_label)
	speed_scale = HSlider.new()
	speed_scale.min_value = 1
	speed_scale.max_value = 20
	speed_scale.step = .5
	speed_scale.value = 3
	speed_scale.custom_minimum_size.x = 340
	speed_scale.value_changed.connect(func(value: float):
		speed_label.text = "Movement speed: %.1f×" % value
		speed.button_pressed = value > 1)
	rows.add_child(speed_scale)
	var close := Button.new()
	close.text = "Resume   F2"
	close.pressed.connect(func(): dismissed.emit())
	rows.add_child(close)
	hide()


func multiplier() -> float:
	return speed_scale.value if speed.button_pressed else 1.0
