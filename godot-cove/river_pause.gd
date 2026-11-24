extends Control

const SAVE := "user://river_preferences.cfg"
const MenuTheme = preload("res://river_menu_theme.gd")
const MIST := MenuTheme.MUTED
const TEAL := MenuTheme.BLUE
const Graphics = preload("res://river_graphics.gd")
var game: Node3D
var graphics: Graphics
var preferences := {"volume": .8, "sensitivity": 1.0, "fov": 78.0,
	"fullscreen": false, "vsync": true, "fps": false, "hand_motion": .65,
	"toggle_crouch": false, "aircraft_invert_pitch": false}
var name_field: LineEdit
var status: Label
var quit_dialog: ConfirmationDialog
var paused_solo := false
var graphics_option: OptionButton
var sliders: Dictionary = {}
var fullscreen_button: CheckButton
var aircraft_invert_pitch: CheckButton
var windowed_mode := DisplayServer.WINDOW_MODE_WINDOWED
var title: Label
var main_page: VBoxContainer
var settings_page: VBoxContainer
var vehicle_page: VBoxContainer
var crew_page: VBoxContainer
var back: Button
var resume_button: Button
var settings_button: Button
var vehicle_button: Button
var crew_button: Button
var leave_button: Button
var main_menu_button: Button


func setup(scene: Node3D = null) -> void:
	game = scene
	if game == null:
		graphics = Graphics.new()
		graphics.load_setting()
	else:
		graphics = game.graphics
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	var config := ConfigFile.new()
	if config.load(SAVE) == OK:
		for key: String in preferences:
			var value: Variant = config.get_value("settings", key, preferences[key])
			if typeof(value) == typeof(preferences[key]):
				preferences[key] = value
	apply_settings()
	if DisplayServer.get_name() != "headless":
		var window := get_window()
		window.unresizable = false
		window.maximize_disabled = false
		window.min_size = Vector2i(960, 540)
	theme = MenuTheme.get_theme()
	var shade := ColorRect.new()
	shade.color = MenuTheme.SCRIM
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MenuTheme.panel(self, MenuTheme.CREAM, MenuTheme.SAND, 15, 24)
	var frame := margin.get_parent() as PanelContainer
	frame.position = Vector2(MenuTheme.MARGIN, 59)
	frame.custom_minimum_size.x = 510 if game != null else 680
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(MenuTheme.text("RICH’S HOUSEBOAT", 14, MenuTheme.ORANGE, true))
	title = MenuTheme.text("Settings" if game == null else "Paused", 42, MenuTheme.NAVY, true)
	titles.add_child(title)
	back = button(header, "Back", func(): close() if game == null else show_main(), &"QuietAction", "back", 36)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_page = VBoxContainer.new()
	settings_page.add_theme_constant_override("separation", 12)
	column.add_child(settings_page)
	build_settings(settings_page)
	if game == null:
		back.tooltip_text = "Back · Esc"
	else:
		build_pause_pages(column)
		settings_page.hide()
		vehicle_page.hide()
		crew_page.hide()
		back.hide()
	hide()
	if DisplayServer.get_name() != "headless":
		if game != null:
			get_window().focus_exited.connect(release_cursor)
		set_fullscreen(bool(preferences.fullscreen), false)


func build_pause_pages(column: VBoxContainer) -> void:
	main_page = VBoxContainer.new()
	main_page.add_theme_constant_override("separation", 15)
	column.add_child(main_page)
	resume_button = button(main_page, "Resume", close, &"MainAction", "play", 55)
	resume_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	resume_button.add_theme_font_size_override("font_size", 21)
	resume_button.tooltip_text = "Resume · Esc"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", MenuTheme.GAP)
	grid.add_theme_constant_override("v_separation", MenuTheme.GAP)
	main_page.add_child(grid)
	settings_button = button(grid, "Settings", func(): show_page(settings_page, "Settings", sliders["volume"]), &"Button", "settings")
	vehicle_button = button(grid, "Vehicle Controls", func(): show_page(vehicle_page, "Vehicle Controls", aircraft_invert_pitch), &"Button", "tools")
	button(grid, "Save", save_world, &"Button", "save")
	button(grid, "Backpack", func(): navigate("pack"), &"Button", "pack").tooltip_text = "Backpack · I"
	button(grid, "River Chart", func(): navigate("chart"), &"Button", "chart").tooltip_text = "River Chart · Tab / M"
	button(grid, "Boat Notebook", func(): navigate("board"), &"Button", "journal").tooltip_text = "Boat Notebook · B"
	button(grid, "Fish Index", func(): navigate("guide"), &"Button", "fish").tooltip_text = "Fish Index · J"
	crew_button = button(grid, "Display Name", func(): show_page(crew_page, "Display Name", name_field), &"Button", "crew")
	leave_button = button(grid, "Leave session", return_to_main_menu, &"Button", "back")
	for action: Button in grid.get_children():
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main_page.add_child(HSeparator.new())
	main_menu_button = button(main_page, "Return to Main Menu", return_to_main_menu, &"Button", "back")
	main_menu_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", MenuTheme.GAP)
	main_page.add_child(footer)
	button(footer, "Unstuck", unstuck, &"QuietAction", "reset", 37).tooltip_text = "Release vehicles and return to a clear spot."
	button(footer, "Exit to Windows", confirm_exit, &"QuietAction", "exit", 37).tooltip_text = "Save and exit to desktop"
	for action: Button in footer.get_children():
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
	build_vehicle_controls(column)
	crew_page = VBoxContainer.new()
	crew_page.add_theme_constant_override("separation", 12)
	column.add_child(crew_page)
	text(crew_page, "Your display name", 20, MenuTheme.NAVY)
	text(crew_page, "Saves and ownership stay linked to your profile.", 15, MIST)
	name_field = LineEdit.new()
	name_field.max_length = 18
	name_field.placeholder_text = "Your name"
	name_field.custom_minimum_size.y = 44
	crew_page.add_child(name_field)
	name_field.text_submitted.connect(func(_value: String): rename_player())
	button(crew_page, "Apply name", rename_player, &"MainAction")
	status = text(column, "", 14, MIST)
	status.custom_minimum_size.y = 22
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "Leave the river?"
	quit_dialog.ok_button_text = "Save & exit"
	MenuTheme.style_confirmation(quit_dialog)
	quit_dialog.confirmed.connect(quit_game)
	add_child(quit_dialog)


func confirm_exit() -> void:
	var crew = game.campaign.crew
	quit_dialog.dialog_text = "Your trip and settings will be saved."
	if crew.on_server():
		quit_dialog.dialog_text = "Your crew world and settings will be saved. The session will end."
	elif crew.is_guest():
		quit_dialog.dialog_text = "You’ll leave the session and save your local settings."
	quit_dialog.popup_centered(Vector2i(460, 170))
	quit_dialog.get_cancel_button().grab_focus()


func show_page(page: VBoxContainer, caption: String, first: Control) -> void:
	main_page.visible = page == main_page
	settings_page.visible = page == settings_page
	vehicle_page.visible = page == vehicle_page
	crew_page.visible = page == crew_page
	back.visible = page != main_page
	title.text = caption
	if visible:
		first.grab_focus()


func show_main() -> void:
	var first := settings_button if settings_page.visible else vehicle_button if vehicle_page.visible else crew_button
	show_page(main_page, "Paused", first)


func build_vehicle_controls(column: VBoxContainer) -> void:
	vehicle_page = VBoxContainer.new()
	vehicle_page.add_theme_constant_override("separation", 12)
	column.add_child(vehicle_page)
	text(vehicle_page, "Helicopter", 22, MenuTheme.NAVY)
	var bindings := GridContainer.new()
	bindings.columns = 2
	bindings.add_theme_constant_override("h_separation", 18)
	bindings.add_theme_constant_override("v_separation", 6)
	vehicle_page.add_child(bindings)
	for binding: Array in [["Mouse", "Pitch and yaw"], ["A / D", "Bank left or right. Release to hold."],
			["Space / Ctrl", "Climb or descend"], ["H", "Level the craft and hover"]]:
		text(bindings, binding[0], 16, TEAL)
		text(bindings, binding[1], 16, MIST)
	vehicle_page.add_child(HSeparator.new())
	text(vehicle_page, "Aim at a door handle and press E to board or exit when the helicopter is landed and stopped.", 16, MIST)
	text(vehicle_page, "Aim at the dash key and hold E to start. Lift is ready at 100% RPM. After landing, aim at the key and tap E to shut down.", 16, MIST)
	aircraft_invert_pitch = CheckButton.new()
	aircraft_invert_pitch.text = "Invert Pitch"
	aircraft_invert_pitch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	aircraft_invert_pitch.button_pressed = preferences.aircraft_invert_pitch
	aircraft_invert_pitch.toggled.connect(func(enabled: bool):
		preferences.aircraft_invert_pitch = enabled
		apply_settings()
		persist())
	vehicle_page.add_child(aircraft_invert_pitch)


func build_settings(settings: VBoxContainer) -> void:
	slider(settings, "Master volume", "volume", 0, 1, .01)
	slider(settings, "Mouse sensitivity", "sensitivity", .25, 2.5, .05)
	slider(settings, "Field of view", "fov", 60, 100, 1)
	slider(settings, "Hand motion", "hand_motion", 0, 1, .05)
	var movement := HBoxContainer.new()
	settings.add_child(movement)
	text(movement, "Crouch mode", 16, MIST).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var crouch_mode := OptionButton.new()
	crouch_mode.add_item("Hold")
	crouch_mode.add_item("Toggle")
	crouch_mode.select(1 if preferences.toggle_crouch else 0)
	crouch_mode.item_selected.connect(func(index: int):
		preferences.toggle_crouch = index == 1
		persist())
	movement.add_child(crouch_mode)
	var row := HBoxContainer.new()
	settings.add_child(row)
	text(row, "Graphics quality / distance", 16, MIST).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_option = OptionButton.new()
	MenuTheme.animate_press(graphics_option)
	for title: String in Graphics.NAMES:
		graphics_option.add_item(title)
	graphics_option.select(graphics.level)
	graphics_option.item_selected.connect(func(index: int):
		while graphics.level != index:
			graphics.advance()
		if game != null:
			graphics.apply(game.river, game.eye))
	row.add_child(graphics_option)
	var checks := HBoxContainer.new()
	checks.add_theme_constant_override("separation", MenuTheme.GAP)
	settings.add_child(checks)
	for key: String in ["fullscreen", "vsync", "fps"]:
		var check := CheckButton.new()
		MenuTheme.animate_press(check)
		check.text = {"fullscreen": "Fullscreen", "vsync": "VSync", "fps": "Show FPS"}[key]
		check.button_pressed = preferences[key]
		if key == "fullscreen":
			fullscreen_button = check
		check.toggled.connect(func(enabled: bool):
			preferences[key] = enabled
			if key == "fullscreen":
				set_fullscreen(enabled, false)
			else:
				apply_settings()
			persist())
		checks.add_child(check)
	button(settings, "Maximize window", maximize_window)
	var cursor_tip := "   ·   F10: release mouse" if game != null else ""
	text(settings, "Alt+Enter / F11: fullscreen" + cursor_tip + "\nSettings are saved on this PC. Set Hand motion to 0 for steadier hands.", 14, MIST)


func text(parent: Node, words: String, size: int, color: Color) -> Label:
	var label := MenuTheme.text(words, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func button(parent: Node, words: String, action: Callable, style: StringName = &"Button", icon := "", height := MenuTheme.BUTTON_HEIGHT) -> Button:
	var result := MenuTheme.button(words, style, icon, height)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(action)
	parent.add_child(result)
	return result


func slider(parent: Node, title: String, key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := text(row, title, 16, MIST)
	label.custom_minimum_size.x = 210
	var control := HSlider.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.min_value = low
	control.max_value = high
	control.step = step
	control.value = preferences[key]
	row.add_child(control)
	var value := text(row, "%.2f" % control.value, 15, TEAL)
	value.custom_minimum_size.x = 60
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	control.value_changed.connect(func(amount: float):
		preferences[key] = amount
		value.text = "%.2f" % amount
		apply_settings()
		persist())
	sliders[key] = control


func apply_settings() -> void:
	preferences.volume = clampf(float(preferences.volume), 0, 1)
	preferences.sensitivity = clampf(float(preferences.sensitivity), .25, 2.5)
	preferences.fov = clampf(float(preferences.fov), 60, 100)
	preferences.hand_motion = clampf(float(preferences.hand_motion), 0, 1)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.0001, preferences.volume)))
	AudioServer.set_bus_mute(0, preferences.volume <= 0)
	if game != null:
		game.aircraft_steering.invert_pitch = preferences.aircraft_invert_pitch
		game.mouse_sensitivity = .0022 * preferences.sensitivity
		game.eye.fov = preferences.fov
		game.rig.motion_amount = preferences.hand_motion
		game.fps.visible = preferences.fps
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if preferences.vsync else DisplayServer.VSYNC_DISABLED)


func persist() -> void:
	var config := ConfigFile.new()
	for key: String in preferences:
		config.set_value("settings", key, preferences[key])
	config.save(SAVE)


func open() -> void:
	if game == null:
		show()
		sliders["volume"].grab_focus()
		return
	game.interact_pressed = false
	game.rod_pressed = false
	game.sonar_overlay.hide()
	name_field.text = game.campaign.crew.local_name
	leave_button.visible = game.campaign.crew.started
	var crew = game.campaign.crew
	leave_button.text = "Save & end session" if crew.on_server() else "Leave session"
	main_menu_button.tooltip_text = "Save your trip and return to the title screen."
	if crew.on_server():
		main_menu_button.tooltip_text = "Save the crew world and end the session."
	elif crew.is_guest():
		main_menu_button.tooltip_text = "Leave the crew and return to the title screen."
	graphics_option.select(game.graphics.level)
	status.text = "Solo trip paused" if game.campaign.crew.mode == "solo" else "Crew session stays live while this menu is open"
	show()
	show_page(main_page, "Paused", resume_button)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paused_solo = game.campaign.crew.mode == "solo"
	if paused_solo:
		get_tree().paused = true


func close() -> void:
	hide()
	if game == null:
		return
	quit_dialog.hide()
	if paused_solo:
		get_tree().paused = false
	paused_solo = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_F11 or (event.alt_pressed and key in [KEY_ENTER, KEY_KP_ENTER]):
			set_fullscreen(not bool(preferences.fullscreen))
			get_viewport().set_input_as_handled()
			return
		if key == KEY_F10:
			release_cursor()
			get_viewport().set_input_as_handled()
			return
	if visible and event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
		if quit_dialog != null and quit_dialog.visible:
			quit_dialog.hide()
		else:
			close()
		get_viewport().set_input_as_handled()


func set_fullscreen(enabled: bool, save := true) -> void:
	preferences.fullscreen = enabled
	if is_instance_valid(fullscreen_button):
		fullscreen_button.set_pressed_no_signal(enabled)
	if DisplayServer.get_name() != "headless":
		var previous_mouse := Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var current := DisplayServer.window_get_mode()
		if enabled:
			if current in [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED]:
				windowed_mode = current
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif current in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
			DisplayServer.window_set_mode(windowed_mode)
		if previous_mouse == Input.MOUSE_MODE_CAPTURED and not visible and get_window().has_focus():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if save:
		persist()


func maximize_window() -> void:
	set_fullscreen(false)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		windowed_mode = DisplayServer.WINDOW_MODE_MAXIMIZED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func release_cursor() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.campaign):
		return
	if not visible and not game.menu_blocks_play():
		open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func navigate(where: String) -> void:
	close()
	match where:
		"chart":
			game.open_chart()
		"board": game.campaign.open_board()
		"pack": game.open_backpack()
		"guide": game.open_fish_guide()


func unstuck() -> void:
	close()
	game.unstuck()


func rename_player() -> void:
	game.campaign.crew.set_display_name(name_field.text)
	name_field.text = game.campaign.crew.local_name
	status.text = "Name updated to " + name_field.text


func return_to_main_menu() -> void:
	var error: String = game.leave_trip()
	if not error.is_empty():
		status.text = error


func save_world() -> String:
	var error: String = game.save_trip()
	if game.campaign.crew.is_guest():
		status.text = "The host saves the shared world. Your name/settings are saved on this PC."
	else:
		status.text = "World saved" if error.is_empty() else error
	return error


func quit_game() -> void:
	var error := save_world()
	if not error.is_empty():
		quit_dialog.hide()
		status.text = error + " Exit cancelled so you can retry."
		return
	game.leaving_trip = true
	game.campaign.crew.stop()
	get_tree().paused = false
	get_tree().quit()
