extends PanelContainer

signal dismissed
signal test_cash_requested

var flight: CheckButton
var speed: CheckButton
var speed_scale: HSlider
var solo_rows: VBoxContainer
var rows: VBoxContainer
var environment_toggle: CheckButton
var environment: VBoxContainer


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
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)
	var heading := Label.new()
	heading.text = "Testing controls"
	heading.add_theme_font_size_override("font_size", 24)
	rows.add_child(heading)
	solo_rows = VBoxContainer.new()
	rows.add_child(solo_rows)
	flight = CheckButton.new()
	flight.text = "Flight"
	solo_rows.add_child(flight)
	var hint := Label.new()
	hint.text = "WASD to fly  ·  Space up  ·  Ctrl/Shift down"
	solo_rows.add_child(hint)
	speed = CheckButton.new()
	speed.text = "Enable movement speed multiplier"
	solo_rows.add_child(speed)
	var speed_label := Label.new()
	speed_label.text = "Movement speed: 3.0×"
	solo_rows.add_child(speed_label)
	speed_scale = HSlider.new()
	speed_scale.min_value = 1
	speed_scale.max_value = 20
	speed_scale.step = .5
	speed_scale.value = 3
	speed_scale.custom_minimum_size.x = 340
	speed_scale.value_changed.connect(func(value: float):
		speed_label.text = "Movement speed: %.1f×" % value
		speed.button_pressed = value > 1)
	solo_rows.add_child(speed_scale)
	var test_cash := Button.new()
	test_cash.text = "Add Test Cash"
	test_cash.pressed.connect(func(): test_cash_requested.emit())
	solo_rows.add_child(test_cash)
	var close := Button.new()
	close.text = "Resume   F2"
	close.pressed.connect(func(): dismissed.emit())
	rows.add_child(close)
	hide()


func setup_environment(game: Node3D) -> void:
	environment = preload("res://environment_debug_controls.gd").new()
	environment_toggle = CheckButton.new()
	environment_toggle.text = "Environment and camera"
	rows.add_child(environment_toggle)
	rows.move_child(environment_toggle, 2)
	rows.add_child(environment)
	rows.move_child(environment, 3)
	environment.setup(game)
	environment.hide()
	environment_toggle.toggled.connect(func(show_environment: bool):
		environment.visible = show_environment
		solo_rows.visible = not show_environment and game.campaign.crew.mode == "solo")


func configure_for_mode(solo: bool) -> void:
	if environment != null:
		environment_toggle.button_pressed = not solo
	solo_rows.visible = solo and (environment == null or not environment.visible)


func multiplier() -> float:
	return speed_scale.value if speed.button_pressed else 1.0
