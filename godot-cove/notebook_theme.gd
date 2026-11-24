extends RefCounted

const FONT = preload("res://fonts/notebook_mono.ttf")
const NAVY := Color("#18273d")
const INK := Color("#242e34")
const PAPER := Color("#f3e9ce")
const EDGE := Color("#b4a582")
const OLIVE := Color("#4c552e")
const YELLOW := Color("#edce71")
const SCRIM := Color("#151e2c86")

static var common: Theme


class Binding extends Control:
	func _init() -> void:
		custom_minimum_size.x = 28
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(4, 0, size.x - 8, size.y), Color("#b6a47f"))
		for number in 8:
			var y := size.y * float(number + 1) / 9.0
			draw_rect(Rect2(0, y - 5, size.x, 10), Color("#3d4140"))
			draw_rect(Rect2(2, y - 4, size.x - 4, 3), Color("#a89b7f"))


static func box(fill: Color, edge: Color, padding := 0, radius := 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func skin() -> Theme:
	if common != null:
		return common
	common = Theme.new()
	common.default_font = FONT
	common.default_font_size = 16
	common.set_color(&"font_color", &"Label", INK)
	common.set_color(&"font_color", &"LineEdit", INK)
	common.set_color(&"font_placeholder_color", &"LineEdit", OLIVE)
	common.set_color(&"caret_color", &"LineEdit", INK)
	common.set_stylebox(&"normal", &"LineEdit", box(Color("#fcf3d9"), EDGE, 8))
	common.set_stylebox(&"focus", &"LineEdit", box(Color("#fcf3d9"), OLIVE, 8))
	common.set_stylebox(&"panel", &"PanelContainer", box(PAPER, EDGE, 12))
	common.set_stylebox(&"panel", &"PopupMenu", box(PAPER, EDGE, 6))
	common.set_color(&"font_color", &"PopupMenu", INK)
	common.set_stylebox(&"hover", &"PopupMenu", box(YELLOW, EDGE, 6))
	var focus := box(Color.TRANSPARENT, OLIVE)
	focus.set_border_width_all(2)
	for kind in [&"Button", &"OptionButton"]:
		common.set_stylebox(&"normal", kind, box(Color("#e7d9b8"), EDGE, 8))
		common.set_stylebox(&"hover", kind, box(Color("#f7e3a5"), EDGE, 8))
		common.set_stylebox(&"pressed", kind, box(YELLOW, OLIVE, 8))
		common.set_stylebox(&"hover_pressed", kind, box(YELLOW, OLIVE, 8))
		common.set_stylebox(&"disabled", kind, box(Color("#e5dac2"), EDGE, 8))
		common.set_stylebox(&"focus", kind, focus)
		for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
			common.set_color(key, kind, INK)
		common.set_color(&"font_disabled_color", kind, Color("#696957"))
	var separator := box(EDGE, EDGE, 0, 0)
	separator.content_margin_bottom = 1
	common.set_stylebox(&"separator", &"HSeparator", separator)
	common.set_constant(&"separation", &"HSeparator", 1)
	common.set_stylebox(&"background", &"ProgressBar", box(Color("#ddceb0"), EDGE))
	common.set_stylebox(&"fill", &"ProgressBar", box(OLIVE, OLIVE))
	return common


static func label(value: String, height := 16, ink := INK) -> Label:
	var control := Label.new()
	control.text = value
	control.add_theme_font_override(&"font", FONT)
	control.add_theme_font_size_override(&"font_size", height)
	control.add_theme_color_override(&"font_color", ink)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


static func button(value: String, minimum := 42) -> Button:
	var control := Button.new()
	control.text = value
	control.custom_minimum_size.y = minimum
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return control


static func page(parent: Node, padding := 22) -> VBoxContainer:
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override(&"panel", box(PAPER, EDGE, 0))
	parent.add_child(paper)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	paper.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 11)
	margin.add_child(content)
	return content


static func restyle(root: Node) -> void:
	if root is Label:
		root.add_theme_font_override(&"font", FONT)
	elif root is Button:
		root.add_theme_font_override(&"font", FONT)
	elif root is PanelContainer:
		root.add_theme_stylebox_override(&"panel", box(PAPER, EDGE, 2))
	for child in root.get_children():
		restyle(child)
