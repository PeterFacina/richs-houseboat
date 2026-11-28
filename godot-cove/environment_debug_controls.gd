extends VBoxContainer

var game: Node3D
var condition: OptionButton
var intensity: SpinBox
var wind: SpinBox
var hours: SpinBox
var idle: OptionButton


func setup(world: Node3D) -> void:
	game = world
	condition = options(game.weather.NAMES)
	intensity = value_control("Weather intensity", 0.0, 1.5, 1.0)
	wind = value_control("Wind override (−1 = preset)", -1.0, 1.0, -1.0)
	action(self, "Force selected weather", force_weather)
	hours = value_control("Time of day (hour)", 0.0, 23.95, 12.0)
	var environment := HBoxContainer.new()
	add_child(environment)
	action(environment, "Advance clock", func():
		if allowed(): game.campaign.advance_to_minute(hours.value * 60.0))
	action(environment, "Trigger lightning", strike)
	idle = options(game.standing_idle.NAMES)
	action(self, "Preview idle on Big Rich", func():
		if allowed(): game.campaign.rich.preview_idle(idle.selected))
	var view := HBoxContainer.new()
	add_child(view)
	action(view, "Camera smoothing", func():
		if allowed(): game.camera_motion.smoothing = .55 if game.camera_motion.smoothing <= 0.0 else 0.0)
	action(view, "Head bob", func():
		if allowed(): game.camera_motion.bob_amount = .35 if game.camera_motion.bob_amount <= 0.0 else 0.0)
	action(view, "Reticle debug", func():
		if allowed(): game.reticle.debug = not game.reticle.debug)


func allowed() -> bool:
	return OS.is_debug_build() and not game.campaign.crew.is_guest()


func force_weather() -> void:
	if not allowed():
		return
	var state: Dictionary = game.campaign.ledger.state
	var transition: float = game.weather.transition_minutes
	game.weather.transition_minutes = 2.5
	game.weather.force(state.weather, condition.selected, float(state.work_minutes), intensity.value, wind.value)
	game.weather.transition_minutes = transition
	if game.campaign.crew.on_server():
		game.campaign.send_weather()


func strike() -> void:
	if not allowed():
		return
	var state: Dictionary = game.campaign.ledger.state
	game.weather.strike(state.weather, float(state.work_minutes), game.player.global_position)
	if game.campaign.crew.on_server():
		game.campaign.send_weather()


func options(names: Array) -> OptionButton:
	var list := OptionButton.new()
	for title: String in names:
		list.add_item(title)
	add_child(list)
	return list


func value_control(title: String, minimum: float, maximum: float, initial: float) -> SpinBox:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = title
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = .05
	field.value = initial
	row.add_child(field)
	add_child(row)
	return field


func action(parent: Control, title: String, run: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(run)
	parent.add_child(button)
