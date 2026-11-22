extends Control

signal chosen(action: String, value: Variant)
signal dismissed

const PAGES := ["River", "Jobs", "Build", "Workshop", "Crew"]
const CREAM := Color("#f5ead7")
const MIST := Color("#b3cbc4")
const GOLD := Color("#dfb784")

var active_page := "River"
var body: VBoxContainer
var tabs: VBoxContainer
var location_line: Label
var inventory_line: Label
var message_line: Label
var scroller: ScrollContainer
var crew_name: LineEdit
var address: LineEdit
var page_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#101b20ab")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box(Color("#18272df8"), Color("#526660"), 16))
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 63
	frame.offset_right = -63
	frame.offset_top = 48
	frame.offset_bottom = -47
	var space := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		space.add_theme_constant_override("margin_" + side, 25)
	frame.add_child(space)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	space.add_child(column)
	var mast := HBoxContainer.new()
	column.add_child(mast)
	var headings := VBoxContainer.new()
	headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headings.add_theme_constant_override("separation", 2)
	mast.add_child(headings)
	headings.add_child(make_label("OTTAWA RIVER", 15, GOLD))
	location_line = make_label("", 30, CREAM)
	headings.add_child(location_line)
	var close := button("Back to game   Esc", false)
	close.pressed.connect(func(): dismissed.emit())
	mast.add_child(close)
	inventory_line = make_label("", 17, MIST)
	column.add_child(inventory_line)
	var line := HSeparator.new()
	column.add_child(line)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 26)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	tabs = VBoxContainer.new()
	tabs.custom_minimum_size.x = 168
	tabs.add_theme_constant_override("separation", 9)
	middle.add_child(tabs)
	for title: String in PAGES:
		var tab := button(title, false)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.toggle_mode = true
		tab.pressed.connect(select_page.bind(title))
		page_buttons[title] = tab
		tabs.add_child(tab)
	scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(scroller)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroller.add_child(body)
	message_line = make_label("", 15, GOLD)
	message_line.custom_minimum_size.y = 24
	column.add_child(message_line)
	hide()


func select_page(page: String) -> void:
	active_page = page
	scroller.scroll_vertical = 0
	chosen.emit("page", page)


func show_data(data: Dictionary) -> void:
	for title: String in page_buttons:
		page_buttons[title].set_pressed_no_signal(title == active_page)
	location_line.text = str(data.heading)
	inventory_line.text = str(data.inventory)
	message_line.text = str(data.get("message", ""))
	for item in body.get_children():
		body.remove_child(item)
		item.queue_free()
	body.add_child(make_label(data.title, 24, CREAM))
	var detail := make_label(data.detail, 16, MIST)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail)
	if active_page == "Crew" and data.get("join_fields", false):
		add_connection_fields(data)
	for row: Dictionary in data.rows:
		add_row(row)


func add_connection_fields(data: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	crew_name = LineEdit.new()
	crew_name.placeholder_text = "Display name"
	crew_name.max_length = 18
	crew_name.text = str(data.get("local_name", ""))
	crew_name.custom_minimum_size = Vector2(141, 40)
	row.add_child(crew_name)
	address = LineEdit.new()
	address.placeholder_text = "Host IP (LAN)"
	address.text = str(data.get("address", ""))
	address.max_length = 64
	address.custom_minimum_size = Vector2(163, 40)
	row.add_child(address)
	var host := button("Host", true)
	host.pressed.connect(func(): chosen.emit("host", crew_name.text))
	row.add_child(host)
	var join := button("Join", false)
	join.pressed.connect(func(): chosen.emit("join", [crew_name.text, address.text]))
	row.add_child(join)


func set_message(message: String) -> void:
	message_line.text = message


func add_row(data: Dictionary) -> void:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", box(Color("#26383d"), Color("#3b5353"), 8))
	body.add_child(tile)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 9)
	tile.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(make_label(data.name, 17, CREAM))
	if not str(data.detail).is_empty():
		var desc := make_label(data.detail, 14, MIST)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
	if str(data.get("button", "")).is_empty():
		return
	var action := button(data.button, bool(data.get("primary", false)))
	action.custom_minimum_size.x = 138
	action.disabled = bool(data.get("disabled", false))
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.pressed.connect(func(): chosen.emit(data.action, data.get("value", null)))
	row.add_child(action)


func button(text: String, primary: bool) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(0, 39)
	control.add_theme_font_size_override("font_size", 15)
	control.add_theme_stylebox_override("normal", box(Color("#e5bd87") if primary else Color("#344c4d"), Color("#697d73"), 7))
	control.add_theme_stylebox_override("hover", box(Color("#f7d49e") if primary else Color("#476561"), Color("#a3b5a3"), 7))
	control.add_theme_stylebox_override("pressed", box(Color("#b6d1bc"), Color("#8fae9b"), 7))
	control.add_theme_stylebox_override("disabled", box(Color("#273438"), Color("#37484b"), 7))
	control.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, Color("#e7cfab"), 7))
	control.add_theme_color_override("font_color", Color("#222d30") if primary else CREAM)
	control.add_theme_color_override("font_hover_color", Color("#1c292a") if primary else CREAM)
	control.add_theme_color_override("font_pressed_color", Color("#1c292a"))
	control.add_theme_color_override("font_disabled_color", Color("#9aadaa"))
	return control


func box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 13
	style.content_margin_right = 13
	return style


func make_label(text: String, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	return label
