extends Control

signal equip_requested(gear: int)
signal open_requested
signal dismissed

const MenuTheme = preload("res://river_menu_theme.gd")
const NONE := -2
const FISTS := -1
const ROD := 0
const HOTBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const SLOT_WIDTH := 57
const HOTBAR_SECONDS := 2.7
const CREAM := Color("#f5ead7")
const MIST := Color("#b3cbc4")
const SUN := Color("#ffd878")
const SEAFOAM := Color("#8ce3cc")

var equipped := NONE
var selected := ROD
var shortcuts: Array[int] = [ROD, NONE, NONE, NONE, NONE, NONE, FISTS]
var hotbar: CenterContainer
var controls: PanelContainer
var waypoint: Label
var throttle_panel: PanelContainer
var throttle_name: Label
var throttle_segments: Array[PanelContainer] = []
var throttle_shown := -1
var hud_available := true
var hotbar_time := HOTBAR_SECONDS
var cursor_was_free := true
var inventory: Control
var cards: Array[PanelContainer] = []
var icons: Array[HotbarIcon] = []
var slot_labels: Array[Label] = []
var gear_buttons: Dictionary = {}
var gear_states: Dictionary = {}
var shortcut_buttons: Array[Button] = []
var backpack_button: Button
var equip_button: Button
var gear_detail: Label
var selected_card := MenuTheme.box(MenuTheme.MIST, MenuTheme.ORANGE, 7)
var selected_hover := MenuTheme.box(Color("#b8dce5"), MenuTheme.ORANGE, 7)
var occupied_slot := MenuTheme.box(MenuTheme.PAPER, MenuTheme.SAND, 7, 0)
var empty_slot := MenuTheme.box(MenuTheme.CREAM, MenuTheme.SAND, 7, 0)
var equipped_slot := MenuTheme.box(MenuTheme.MIST, MenuTheme.ORANGE, 7, 0)


func _ready() -> void:
	name = "Backpack"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_hotbar()
	build_controls()
	build_inventory()
	build_throttle()
	refresh()


func _process(delta: float) -> void:
	var cursor_free := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if cursor_was_free and not cursor_free:
		reveal_hotbar()
	cursor_was_free = cursor_free
	update_displays(delta, cursor_free, get_window().has_focus() and Input.is_physical_key_pressed(KEY_F1))


func reveal_hotbar() -> void:
	hotbar_time = HOTBAR_SECONDS


func flash_slot(slot: int) -> void:
	reveal_hotbar()
	var card := cards[slot]
	if card.has_meta("selection_tween"):
		var old: Tween = card.get_meta("selection_tween")
		old.kill()
	card.pivot_offset = card.size * .5
	card.scale = Vector2(.91, .91)
	var tween := card.create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, .14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	card.set_meta("selection_tween", tween)


func update_displays(delta: float, cursor_free: bool, help_held: bool) -> void:
	hotbar_time = maxf(0.0, hotbar_time - delta)
	if not hud_available or inventory.visible:
		hotbar.modulate.a = 0.0
		hotbar.hide()
		controls.modulate.a = 0.0
		controls.hide()
		return
	var show_hotbar := cursor_free or help_held or hotbar_time > 0.0
	hotbar.modulate.a = move_toward(hotbar.modulate.a, 1.0 if show_hotbar else 0.0, delta * (10.0 if show_hotbar else 3.5))
	hotbar.visible = hotbar.modulate.a > 0.0
	controls.modulate.a = move_toward(controls.modulate.a, 1.0 if help_held else 0.0, delta * 9.0)
	controls.visible = controls.modulate.a > 0.0


func build_throttle() -> void:
	throttle_panel = PanelContainer.new()
	throttle_panel.name = "MowerThrottle"
	throttle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(throttle_panel)
	throttle_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	throttle_panel.offset_left = -264
	throttle_panel.offset_right = -25
	throttle_panel.offset_top = -172
	throttle_panel.offset_bottom = -99
	throttle_panel.add_theme_stylebox_override("panel", surface(Color("#0e2936ed"), Color("#4a7484"), 13))
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	throttle_panel.add_child(stack)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header)
	var title := make_label("Mower throttle", 15, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	throttle_name = make_label("", 14, SEAFOAM)
	header.add_child(throttle_name)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	stack.add_child(row)
	for index in 4:
		var segment := PanelContainer.new()
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.custom_minimum_size.y = 9
		row.add_child(segment)
		throttle_segments.append(segment)
	throttle_panel.hide()


func update_throttle(level: int, name_text: String) -> void:
	throttle_panel.visible = level >= 0 and not inventory.visible
	if level < 0 or level == throttle_shown:
		return
	throttle_shown = level
	throttle_name.text = name_text
	for index in throttle_segments.size():
		var fill := Color("#204653")
		if index <= level:
			fill = SEAFOAM if index == level else Color("#4d9d94")
		var bar := surface(fill, fill, 0)
		bar.set_corner_radius_all(3)
		bar.content_margin_top = 0
		bar.content_margin_bottom = 0
		throttle_segments[index].add_theme_stylebox_override("panel", bar)


func build_hotbar() -> void:
	hotbar = CenterContainer.new()
	hotbar.theme = MenuTheme.get_theme()
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotbar)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hotbar.offset_left = 16
	hotbar.offset_right = -16
	hotbar.offset_top = -105
	hotbar.offset_bottom = -22
	equipped_slot.set_border_width_all(3)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail := MenuTheme.box(MenuTheme.CREAM, MenuTheme.BLUE, 12, MenuTheme.GAP)
	rail.set_content_margin_all(MenuTheme.GAP)
	rail.shadow_color = Color("#101d2570")
	rail.shadow_size = 6
	frame.add_theme_stylebox_override("panel", rail)
	hotbar.add_child(frame)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", MenuTheme.GAP)
	frame.add_child(row)
	for key in HOTBAR_KEYS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(SLOT_WIDTH, 59)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		cards.append(card)
		var face := Control.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
		var number := MenuTheme.text(OS.get_keycode_string(key), 13, MenuTheme.NAVY, true)
		number.position = Vector2(6, 2)
		face.add_child(number)
		var icon := HotbarIcon.new()
		face.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -12
		icon.offset_right = 12
		icon.offset_top = -13
		icon.offset_bottom = 7
		icons.append(icon)
		var caption := MenuTheme.text("", 12, MenuTheme.MUTED, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -20
		caption.offset_bottom = -2
		slot_labels.append(caption)
	backpack_button = MenuTheme.button("Backpack   I", &"MainAction", "pack", 59)
	backpack_button.name = "BackpackButton"
	backpack_button.tooltip_text = "Open backpack (I)"
	backpack_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	backpack_button.focus_mode = Control.FOCUS_NONE
	backpack_button.custom_minimum_size.x = 144
	backpack_button.add_theme_font_size_override("font_size", 15)
	backpack_button.pressed.connect(func(): open_requested.emit())
	row.add_child(backpack_button)


func build_controls() -> void:
	controls = PanelContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_theme_stylebox_override("panel", surface(Color("#102b38f5"), Color("#4a7484"), 15))
	add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -362
	controls.offset_right = -24
	controls.offset_top = 92
	controls.offset_bottom = 92
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	controls.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	var title := make_label("Controls", 21, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var hint := make_label("Release F1 to hide", 13, MIST)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(hint)
	for entry in [
		["WASD / Space", "Walk, swim / jump"],
		["1–7 / I", "Equip or stow / backpack"],
		["E / L", "Interact / dock or board"],
		["R/F · A/D", "Helm throttle · steer"],
		["X (hold)", "Center the wheel"],
		["E at dash key", "Hold to start · tap to stop"],
		["R / Left click", "Cast or reel / punch with fists"],
		["Tab / B", "Chart and teleport / notebook"],
		["F / J", "Sonar / Fish Index"],
		["E / X", "Mower: mount, blades"],
		["C / H", "Car: camera, headlights"],
		["F2 / F4", "Solo cheats / draw distance"],
		["Esc", "Release cursor"],
	]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		var keys := make_label(entry[0], 14, SEAFOAM)
		keys.custom_minimum_size.x = 117
		row.add_child(keys)
		row.add_child(make_label(entry[1], 14, CREAM))
	waypoint = make_label("", 14, SUN)
	column.add_child(waypoint)
	waypoint.hide()
	controls.modulate.a = 0.0
	controls.hide()


func build_inventory() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = MenuTheme.SCRIM
	inventory = Control.new()
	inventory.theme = MenuTheme.get_theme()
	add_child(inventory)
	inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	inventory.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MenuTheme.panel(center, MenuTheme.CREAM, MenuTheme.SAND, 15, 24)
	(margin.get_parent() as Control).custom_minimum_size.x = 800
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := MenuTheme.text("Backpack", 42, MenuTheme.NAVY, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := MenuTheme.button("Close  ·  I", &"QuietAction", "back", 37)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.tooltip_text = "Close backpack (I or Esc)"
	close.pressed.connect(func(): dismissed.emit())
	heading.add_child(close)
	column.add_child(HSeparator.new())
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", MenuTheme.GAP)
	column.add_child(gear_row)
	selected_card.set_border_width_all(2)
	selected_hover.set_border_width_all(2)
	add_gear(gear_row, ROD)
	add_gear(gear_row, FISTS)

	var detail_margin := MenuTheme.panel(column, MenuTheme.PAPER, MenuTheme.SAND, 9, 12)
	var details := HBoxContainer.new()
	detail_margin.add_child(details)
	gear_detail = MenuTheme.text("", 17, MenuTheme.NAVY, true)
	gear_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gear_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(gear_detail)
	equip_button = MenuTheme.button("Equip", &"MainAction", "", 40)
	equip_button.custom_minimum_size.x = 109
	equip_button.pressed.connect(func(): equip_requested.emit(NONE if selected == equipped else selected))
	details.add_child(equip_button)

	column.add_child(HSeparator.new())
	var hotbar_heading := HBoxContainer.new()
	hotbar_heading.add_theme_constant_override("separation", 12)
	column.add_child(hotbar_heading)
	hotbar_heading.add_child(MenuTheme.text("Hotbar", 20, MenuTheme.BLUE, true))
	var prompt := MenuTheme.text("Choose a slot to assign the selected gear.", 15, MenuTheme.MUTED)
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hotbar_heading.add_child(prompt)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", MenuTheme.GAP)
	column.add_child(slots)
	for slot in HOTBAR_KEYS.size():
		var shortcut := inventory_card(59)
		shortcut.add_theme_font_size_override("font_size", 15)
		shortcut.pressed.connect(assign_to.bind(slot))
		slots.add_child(shortcut)
		shortcut_buttons.append(shortcut)
	inventory.hide()
	inventory.visibility_changed.connect(func():
		if inventory.is_visible_in_tree():
			gear_buttons[selected].grab_focus())


func inventory_card(height: int) -> Button:
	var card := MenuTheme.button("", &"Button", "", height)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.toggle_mode = true
	card.add_theme_stylebox_override("pressed", selected_card)
	card.add_theme_stylebox_override("hover_pressed", selected_hover)
	return card


func add_gear(parent: HBoxContainer, gear: int) -> void:
	var option := inventory_card(82)
	parent.add_child(option)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 13)
	option.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 17
	row.offset_right = -17
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(44, 44)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)
	tile.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.MIST, MenuTheme.MIST, 7, 0))
	var icon := HotbarIcon.new()
	icon.update_icon(gear_name(gear).to_lower(), MenuTheme.BLUE)
	tile.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -12
	icon.offset_right = 12
	icon.offset_top = -10
	icon.offset_bottom = 10
	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	labels.add_theme_constant_override("separation", 1)
	row.add_child(labels)
	labels.add_child(MenuTheme.text(gear_name(gear), 19, MenuTheme.NAVY, true))
	var state := MenuTheme.text("", 14, MenuTheme.MUTED)
	labels.add_child(state)
	option.pressed.connect(select_gear.bind(gear))
	gear_buttons[gear] = option
	gear_states[gear] = state


func select_gear(gear: int) -> void:
	selected = gear
	refresh()


func set_equipped(gear: int) -> void:
	equipped = gear
	if gear != NONE:
		selected = gear
	refresh()


func assign_to(slot: int) -> void:
	var old_slot := shortcuts.find(selected)
	if old_slot != -1:
		shortcuts[old_slot] = shortcuts[slot]
	shortcuts[slot] = selected
	refresh()


func refresh() -> void:
	for slot in shortcuts.size():
		var gear := shortcuts[slot]
		var key := OS.get_keycode_string(HOTBAR_KEYS[slot])
		var active := gear != NONE and gear == equipped
		var style := equipped_slot if active else (empty_slot if gear == NONE else occupied_slot)
		cards[slot].add_theme_stylebox_override("panel", style)
		var caption := gear_name(gear)
		icons[slot].update_icon(caption.to_lower(), MenuTheme.MUTED if gear == NONE else MenuTheme.BLUE)
		slot_labels[slot].text = caption if gear != NONE else ""
		var shortcut := shortcut_buttons[slot]
		shortcut.text = "%s\n%s" % [key, caption]
		shortcut.set_pressed_no_signal(gear == selected)
		shortcut.tooltip_text = "Assign %s to slot %s" % [gear_name(selected).to_lower(), key]
	for gear: int in gear_buttons:
		var option: Button = gear_buttons[gear]
		var label: Label = gear_states[gear]
		label.text = "Equipped" if gear == equipped else "Stowed"
		label.add_theme_color_override("font_color", MenuTheme.BLUE if gear == equipped else MenuTheme.MUTED)
		option.accessibility_name = "%s, %s" % [gear_name(gear), label.text]
		option.set_pressed_no_signal(gear == selected)
	equip_button.text = "Stow" if selected == equipped else "Equip"
	gear_detail.text = "R  ·  Cast or reel" if selected == ROD else "Left click  ·  Punch"


func gear_name(gear: int) -> String:
	if gear == NONE:
		return "Empty"
	return "Fists" if gear == FISTS else "Rod"


func make_label(value: String, size: int, tint: Color) -> Label:
	var text := Label.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = value
	text.add_theme_font_size_override("font_size", size)
	text.add_theme_color_override("font_color", tint)
	return text


func surface(fill: Color, edge: Color, padding := 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding if padding > 9 else 3
	style.content_margin_bottom = style.content_margin_top
	return style


class HotbarIcon extends Control:
	var kind := ""
	var ink := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(24, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func update_icon(icon_kind: String, tint: Color) -> void:
		kind = icon_kind
		ink = tint
		queue_redraw()

	func _draw() -> void:
		match kind:
			"rod":
				draw_polyline(PackedVector2Array([Vector2(3, 17), Vector2(18, 3), Vector2(21, 4),
					Vector2(21, 12)]), ink, 1.7, true)
				draw_line(Vector2(3, 17), Vector2(8, 12), ink, 3.0, true)
				draw_circle(Vector2(9, 15), 2.5, ink, false, 1.4, true)
			"fists":
				draw_polyline(PackedVector2Array([Vector2(6, 18), Vector2(4, 12), Vector2(4, 8), Vector2(8, 8),
					Vector2(8, 4), Vector2(19, 4), Vector2(21, 7), Vector2(20, 12), Vector2(16, 18),
					Vector2(6, 18)]), ink, 1.7, true)
				for x in [11, 15, 18]:
					draw_line(Vector2(x, 5), Vector2(x, 9), ink, 1.2, true)
			"empty":
				draw_line(Vector2(8, 13), Vector2(16, 13), ink, 1.6, true)
