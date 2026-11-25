extends Control

signal spawn_requested(boat_id: String)

const Style = preload("res://game_menu_theme.gd")
const BOATS := {
	"princecraft": "Princecraft Holiday DLX",
	"classic": "Classic",
	"panorama": "Panorama",
}

var choices: Dictionary[String, Button] = {}
var spawn_button: Button
var status: Label
var selected := "classic"
var previous_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	name = "BoatsMenu"
	theme = Style.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .48, 1.0])
	gradient.colors = PackedColorArray([Color("#101d25fa"), Color("#101d25db"), Color("#101d2500")])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	var scrim := TextureRect.new()
	scrim.texture = shade
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	scrim.offset_right = 770

	var menu := VBoxContainer.new()
	menu.position = Vector2(Style.MARGIN, 64)
	menu.custom_minimum_size.x = 330
	menu.add_theme_constant_override("separation", 12)
	add_child(menu)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", -5)
	menu.add_child(heading)
	heading.add_child(Style.text("DEEP RIVER MARINA", 16, Style.CREAM, true))
	heading.add_child(Style.text("BOATS", 65, Style.GOLD, true))

	var group := ButtonGroup.new()
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", Style.GAP)
	menu.add_child(options)
	var chosen := Style.box(Color("#4e675f"), Style.GOLD, 7)
	chosen.set_border_width_all(2)
	var chosen_hover := chosen.duplicate() as StyleBoxFlat
	chosen_hover.bg_color = Color("#5b756a")
	for boat_id: String in BOATS:
		var option := Style.button(BOATS[boat_id], &"TitleAction")
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.toggle_mode = true
		option.button_group = group
		option.add_theme_stylebox_override("pressed", chosen)
		option.add_theme_stylebox_override("hover_pressed", chosen_hover)
		options.add_child(option)
		choices[boat_id] = option
		option.pressed.connect(select_boat.bind(boat_id))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", Style.GAP)
	menu.add_child(actions)
	spawn_button = Style.button("Spawn Boat", &"TitleStart", "play")
	spawn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_button.pressed.connect(submit)
	actions.add_child(spawn_button)
	var back := Style.button("Back", &"TitleAction", "back")
	back.pressed.connect(close)
	actions.add_child(back)
	status = Style.text("", 15, Style.CREAM)
	status.custom_minimum_size.x = 330
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(status)
	hide()


func open(boat_id: String) -> void:
	previous_mouse_mode = Input.mouse_mode
	select_boat(boat_id)
	spawn_button.disabled = false
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	choices[selected].grab_focus()


func close() -> void:
	if visible:
		hide()
		Input.mouse_mode = previous_mouse_mode


func select_boat(boat_id: String) -> void:
	selected = boat_id
	for id: String in choices:
		choices[id].set_pressed_no_signal(id == selected)
	status.hide()


func submit() -> void:
	if spawn_button.disabled:
		return
	spawn_button.disabled = true
	status.text = "Checking the berth…"
	status.show()
	spawn_requested.emit(selected)


func report(message: String, launched: bool) -> void:
	if launched:
		close()
	elif visible:
		spawn_button.disabled = false
		status.text = message
		status.show()
