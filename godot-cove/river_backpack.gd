extends Control

signal equip_requested(gear: int)
signal open_requested
signal dismissed

const NONE := -2
const FISTS := -1
const ROD := 0
const HOTBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const SLOT_WIDTH := 51
const SLOT_GAP := 6
const HOTBAR_SECONDS := 2.7
const CREAM := Color("#f5ead7")
const MIST := Color("#b3cbc4")
const GOLD := Color("#e6bd85")
const INK := Color("#143642")
const SUN := Color("#ffd878")
const CORAL := Color("#ffa58d")
const SEAFOAM := Color("#8ce3cc")
const SKY := Color("#82c6da")

var equipped := NONE
var selected := ROD
var shortcuts: Array[int] = [ROD, NONE, NONE, NONE, NONE, NONE, FISTS]
var hotbar: CenterContainer
var controls: PanelContainer
var waypoint: Label
var hud_available := true
var hotbar_time := HOTBAR_SECONDS
var cursor_was_free := true
var inventory: Control
var cards: Array[PanelContainer] = []
var icons: Array[HotbarIcon] = []
var gear_buttons: Dictionary = {}
var shortcut_buttons: Array[Button] = []
var backpack_button: Button
var equip_button: Button
var gear_detail: Label
var active_card := surface(Color("#364d4a"), GOLD)
var inactive_card := surface(Color("#17262de8"), Color("#62756d"))


func _ready() -> void:
	name = "Backpack"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_hotbar()
	build_throttle()
	build_controls()
	build_inventory()
	refresh()


func _process(delta: float) -> void:
	var cursor_free := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if cursor_was_free and not cursor_free:
		reveal_hotbar()
	cursor_was_free = cursor_free
	update_displays(delta, cursor_free, get_window().has_focus() and Input.is_physical_key_pressed(KEY_F1))


func reveal_hotbar() -> void:
	hotbar_time = HOTBAR_SECONDS


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


var throttle_panel: PanelContainer
var throttle_name: Label
var throttle_segments: Array[PanelContainer] = []
var throttle_shown := -1


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
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotbar)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hotbar.offset_left = 16
	hotbar.offset_right = -16
	hotbar.offset_top = -83
	hotbar.offset_bottom = -22
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", surface(Color("#0e2936e8"), Color("#4a7484"), 6))
	hotbar.add_child(frame)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", SLOT_GAP)
	frame.add_child(row)
	for key in HOTBAR_KEYS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(SLOT_WIDTH, 44)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		cards.append(card)
		var face := Control.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
		var number := make_label(OS.get_keycode_string(key), 12, CREAM)
		number.position = Vector2(-3, -1)
		number.add_theme_color_override("font_outline_color", INK)
		number.add_theme_constant_override("outline_size", 3)
		face.add_child(number)
		var icon := HotbarIcon.new()
		face.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -10
		icon.offset_right = 14
		icon.offset_top = -8
		icon.offset_bottom = 12
		icons.append(icon)
	backpack_button = Button.new()
	backpack_button.name = "BackpackButton"
	backpack_button.text = "Backpack   I"
	backpack_button.tooltip_text = "Open backpack (I)"
	backpack_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	backpack_button.focus_mode = Control.FOCUS_NONE
	backpack_button.custom_minimum_size = Vector2(122, 44)
	backpack_button.add_theme_font_size_override("font_size", 14)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		backpack_button.add_theme_color_override(state, INK)
	backpack_button.add_theme_stylebox_override("normal", backpack_surface(SEAFOAM))
	backpack_button.add_theme_stylebox_override("hover", backpack_surface(Color("#b6f2da")))
	backpack_button.add_theme_stylebox_override("pressed", backpack_surface(Color("#69c6b6")))
	backpack_button.pressed.connect(func(): open_requested.emit())
	row.add_child(backpack_button)
	var bag := HotbarIcon.new()
	bag.update_icon("backpack", INK)
	backpack_button.add_child(bag)
	bag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	bag.offset_left = 8
	bag.offset_right = 32
	bag.offset_top = -10
	bag.offset_bottom = 10


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
		["W/S · A/D", "At helm: throttle · steer"],
		["R / Left click", "Cast or reel / punch with fists"],
		["Tab / B", "Chart and teleport / notebook"],
		["F / J", "Sonar / fish guide"],
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


func backpack_surface(fill: Color) -> StyleBoxFlat:
	var style := surface(fill, Color("#b8f1dd"))
	style.content_margin_left = 34
	return style


func build_inventory() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#101b20ac")
	inventory = Control.new()
	add_child(inventory)
	inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	inventory.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 760
	panel.add_theme_stylebox_override("panel", surface(Color("#18272dfb"), Color("#647970"), 19))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := make_label("Backpack", 29, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := make_button("Close   Esc")
	close.pressed.connect(func(): dismissed.emit())
	heading.add_child(close)
	column.add_child(HSeparator.new())
	column.add_child(make_label("Gear", 16, SEAFOAM))
	var gear_grid := GridContainer.new()
	gear_grid.columns = 2
	gear_grid.add_theme_constant_override("h_separation", 12)
	column.add_child(gear_grid)
	add_gear(gear_grid, ROD)
	add_gear(gear_grid, FISTS)
	gear_detail = make_label("", 15, MIST)
	column.add_child(gear_detail)
	column.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	column.add_child(actions)
	var prompt := make_label("Hotbar  ·  Pick a slot to assign selected gear", 15, SEAFOAM)
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(prompt)
	equip_button = make_button("Equip")
	equip_button.pressed.connect(func(): equip_requested.emit(NONE if selected == equipped else selected))
	actions.add_child(equip_button)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", SLOT_GAP)
	column.add_child(slots)
	for slot in HOTBAR_KEYS.size():
		var shortcut := make_button("")
		shortcut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shortcut.pressed.connect(assign_to.bind(slot))
		slots.add_child(shortcut)
		shortcut_buttons.append(shortcut)
	inventory.hide()


func add_gear(grid: GridContainer, gear: int) -> void:
	var option := make_button("")
	option.custom_minimum_size.y = 100
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 18)
	var accent := SUN if gear == ROD else CORAL
	option.add_theme_stylebox_override("normal", surface(Color("#183949"), accent.darkened(.45)))
	option.add_theme_stylebox_override("pressed", surface(Color("#254b54"), accent))
	var icon := HotbarIcon.new()
	icon.update_icon(gear_name(gear).to_lower(), accent)
	option.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = 24
	icon.offset_top = -10
	option.toggle_mode = true
	option.pressed.connect(select_gear.bind(gear))
	grid.add_child(option)
	gear_buttons[gear] = option


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
		var accent := SUN if gear == ROD else (CORAL if gear == FISTS else SKY)
		var fill := accent if active else Color("#183949dd")
		var style := surface(fill, accent if gear != NONE else Color("#477886"), 7)
		style.set_border_width(SIDE_TOP, 2)
		cards[slot].add_theme_stylebox_override("panel", style)
		var caption := gear_name(gear)
		icons[slot].update_icon(caption.to_lower(), INK if active else accent)
		shortcut_buttons[slot].text = "%s  %s" % [key, caption]
	for gear: int in gear_buttons:
		var option: Button = gear_buttons[gear]
		var label := gear_name(gear)
		option.text = "%s  ·  Equipped" % label if gear == equipped else label
		option.set_pressed_no_signal(gear == selected)
	equip_button.text = "Stow" if selected == equipped else "Equip"
	gear_detail.text = "R  Cast or reel" if selected == ROD else "Left click  Punch"


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


func make_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_stylebox_override("normal", inactive_card)
	button.add_theme_stylebox_override("hover", surface(Color("#31474b"), MIST))
	button.add_theme_stylebox_override("pressed", active_card)
	button.add_theme_stylebox_override("focus", surface(Color.TRANSPARENT, GOLD))
	return button


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
			"backpack":
				draw_arc(Vector2(12, 6), 3.0, PI, TAU, 12, ink, 1.6, true)
				draw_polyline(PackedVector2Array([Vector2(5, 9), Vector2(7, 6), Vector2(17, 6), Vector2(19, 9),
					Vector2(19, 18), Vector2(5, 18), Vector2(5, 9)]), ink, 1.7, true)
				draw_rect(Rect2(8, 11, 8, 4), ink, false, 1.3)
