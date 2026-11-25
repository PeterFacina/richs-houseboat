extends RefCounted

const Menu = preload("res://river_menu_theme.gd")
const NAVY := Menu.NAVY
const INK := Menu.NAVY
const PAPER := Menu.PAPER
const EDGE := Menu.SAND
const OLIVE := Menu.MUTED
const SCRIM := Menu.SCRIM


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
	var style := Menu.box(fill, edge, radius, padding)
	style.set_content_margin_all(padding)
	return style


static func label(value: String, height := 16, ink := INK) -> Label:
	var control := Menu.text(value, height, ink)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control


static func button(value: String, minimum := 42) -> Button:
	return Menu.button(value, &"Button", "", minimum)


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
