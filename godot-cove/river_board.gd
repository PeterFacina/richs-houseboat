extends Control

signal chosen(action: String, value: Variant)
signal dismissed

const MenuTheme = preload("res://game_menu_theme.gd")
const GROUPS := {
	"Trip": [["River", "river"], ["Jobs", "jobs"]],
	"Boat": [["Build", "build"], ["Workshop", "tools"]],
	"Fishing": [["Fish Index", "fish", "fish_guide"], ["Catch Journal", "journal", "catch_journal"]],
	"": [["Crew", "crew"]],
}

var active_page := "River"
var body: VBoxContainer
var location_line: Label
var inventory_line: Label
var message_line: Label
var scroller: ScrollContainer
var page_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuTheme.get_theme()
	var backdrop := ColorRect.new()
	backdrop.color = MenuTheme.SCRIM
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var space := MenuTheme.panel(self, MenuTheme.CREAM, MenuTheme.SAND, 15, 24)
	var frame := space.get_parent() as PanelContainer
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = MenuTheme.MARGIN
	frame.offset_right = -MenuTheme.MARGIN
	frame.offset_top = 48
	frame.offset_bottom = -48
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	space.add_child(column)
	var mast := HBoxContainer.new()
	column.add_child(mast)
	var headings := VBoxContainer.new()
	headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headings.add_theme_constant_override("separation", 2)
	mast.add_child(headings)
	headings.add_child(MenuTheme.text("BOAT NOTEBOOK", 14, MenuTheme.ORANGE, true))
	location_line = MenuTheme.text("", 39, MenuTheme.NAVY, true)
	headings.add_child(location_line)
	var close_button := MenuTheme.button("Close  ·  Esc", &"QuietAction", "back", 38)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(func(): dismissed.emit())
	# Enter the notebook on the current page, with Close last in the Tab order.
	inventory_line = MenuTheme.text("", 16, MenuTheme.BLUE)
	column.add_child(inventory_line)
	var line := HSeparator.new()
	column.add_child(line)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 20)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size.x = 190
	tabs.add_theme_constant_override("separation", 10)
	middle.add_child(tabs)
	for group: String in GROUPS:
		var entries := VBoxContainer.new()
		entries.add_theme_constant_override("separation", 5)
		tabs.add_child(entries)
		if not group.is_empty():
			entries.add_child(MenuTheme.text(group.to_upper(), 13, MenuTheme.MUTED, true))
		for entry: Array in GROUPS[group]:
			var tab := MenuTheme.button(entry[0], &"Button", entry[1], 39)
			tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
			entries.add_child(tab)
			if entry.size() == 3:
				tab.pressed.connect(func(): chosen.emit(entry[2], null))
			else:
				tab.toggle_mode = true
				tab.pressed.connect(select_page.bind(entry[0]))
				page_buttons[entry[0]] = tab
	var reading_area := MenuTheme.panel(middle, MenuTheme.PAPER, MenuTheme.SAND, 10, 15)
	(reading_area.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.follow_focus = true
	reading_area.add_child(scroller)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroller.add_child(body)
	message_line = MenuTheme.text("", 15, MenuTheme.ORANGE)
	message_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message_line)
	mast.add_child(close_button)
	var first: Button = page_buttons["River"]
	close_button.focus_next = close_button.get_path_to(first)
	first.focus_previous = first.get_path_to(close_button)
	hide()


func select_page(page: String) -> void:
	active_page = page
	scroller.scroll_vertical = 0
	chosen.emit("page", page)


func show_data(data: Dictionary) -> void:
	for title: String in page_buttons:
		var tab: Button = page_buttons[title]
		tab.set_pressed_no_signal(title == active_page)
		tab.theme_type_variation = &"MainAction" if title == active_page else &"Button"
	location_line.text = str(data.heading)
	inventory_line.text = str(data.inventory)
	set_message(str(data.get("message", "")))
	var focus := get_viewport().gui_get_focus_owner()
	var focus_path := body.get_path_to(focus) if focus != null and body.is_ancestor_of(focus) else NodePath()
	for item in body.get_children():
		body.remove_child(item)
		item.queue_free()
	body.add_child(MenuTheme.text(data.title, 26, MenuTheme.NAVY, true))
	var detail := MenuTheme.text(data.detail, 16, MenuTheme.MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail)
	for row: Dictionary in data.rows:
		add_row(row)
	if not focus_path.is_empty():
		var replacement := body.get_node_or_null(focus_path) as Control
		if replacement != null and (not replacement is BaseButton or not replacement.disabled):
			replacement.grab_focus()
		else:
			focus_page()


func focus_page() -> void:
	var tab: Button = page_buttons[active_page]
	tab.grab_focus()


func set_message(message: String) -> void:
	message_line.text = message
	message_line.visible = not message.is_empty()


func add_row(data: Dictionary) -> void:
	var margin := MenuTheme.panel(body, MenuTheme.CREAM, MenuTheme.SAND, 8, 12)
	margin.get_parent().name = "Row%d" % body.get_child_count()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var row := HBoxContainer.new()
	row.name = "Content"
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := MenuTheme.text(data.name, 17, MenuTheme.NAVY, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	if not str(data.detail).is_empty():
		var desc := MenuTheme.text(data.detail, 14, MenuTheme.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
	if str(data.get("button", "")).is_empty():
		return
	var action := MenuTheme.button(data.button, &"MainAction" if data.get("primary", false) else &"Button", "", 39)
	action.name = "Action"
	action.custom_minimum_size.x = 138
	action.disabled = bool(data.get("disabled", false))
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.pressed.connect(func(): chosen.emit(data.action, data.get("value", null)))
	row.add_child(action)
