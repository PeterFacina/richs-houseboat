extends Control

signal travel_requested(destination: int)
signal close_requested
signal guide_requested
signal map_resized

const MenuTheme = preload("res://river_menu_theme.gd")

class PinPulse extends Control:
	var tint: Color
	var progress := 1.0:
		set(value):
			progress = value
			queue_redraw()

	func _draw() -> void:
		if progress < 1.0:
			draw_arc(Vector2.ZERO, lerpf(7.0, 22.0, progress), 0, TAU, 32,
				Color(tint, 1.0 - progress), 2.5, true)

var extent: Vector2
var atlas: Texture2D
var bounds: Rect2
var sections: Array[Rect2] = []
var section_picker: OptionButton
var map_frame: AspectRatioContainer
var section := 0
var return_available := false
var map: TextureRect
var routes: Node2D
var leaders: Node2D
var pins: Control
var pulse: PinPulse
var pulse_tween: Tween
var boat_marker: Label
var scale_bar: Control
var scale_frame: PanelContainer
var destinations: VBoxContainer
var journal_view: VBoxContainer
var journal_label: Label
var ways_tab: Button
var journal_tab: Button
var guide_button: Button
var close_button: Button
var detail: PanelContainer
var detail_title: Label
var detail_text: Label
var travel_button: Button
var status: Label
var no_selection: Label
var waypoints: Dictionary = {}
var highway_layer: Node2D
var highway_paths: Array[Line2D] = []
var highway_points: Array = []
var highway_label: Label
var selected := -1
var boat_id := -1


func setup(texture: Texture2D, world_extent: Vector2) -> void:
	extent = world_extent
	atlas = texture
	bounds = Rect2(Vector2.ZERO, extent)
	theme = MenuTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = MenuTheme.SCRIM
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := MenuTheme.panel(self, MenuTheme.CREAM, MenuTheme.SAND, 15, 16)
	var frame := inset.get_parent() as PanelContainer
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = MenuTheme.MARGIN
	frame.offset_right = -MenuTheme.MARGIN
	frame.offset_top = 23
	frame.offset_bottom = -23
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	inset.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", MenuTheme.GAP)
	stack.add_child(header)
	var heading := MenuTheme.text("Ottawa River Chart", 39, MenuTheme.NAVY, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	section_picker = OptionButton.new()
	section_picker.custom_minimum_size.x = 170
	section_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	section_picker.tooltip_text = "Choose the entire river or an 18 × 18 km regional chart."
	section_picker.item_selected.connect(select_section)
	header.add_child(section_picker)
	guide_button = header_button(header, "Fish Index  ·  J", "fish", func(): guide_requested.emit())
	close_button = header_button(header, "Close  ·  Tab", "back", func(): close_requested.emit())

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(content)
	var map_column := VBoxContainer.new()
	map_column.add_theme_constant_override("separation", 6)
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(map_column)
	make_map(map_column, texture)
	var credits := HBoxContainer.new()
	map_column.add_child(credits)
	var sources := MenuTheme.text("© OpenStreetMap contributors  ·  Elevation: Natural Resources Canada", 12, MenuTheme.MUTED)
	sources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.add_child(sources)
	credits.add_child(MenuTheme.text("◆  Your boat", 12, MenuTheme.BLUE, true))
	make_sidebar(content)
	hide()


func header_button(parent: Node, caption: String, icon: String, action: Callable) -> Button:
	var button := MenuTheme.button(caption, &"QuietAction", icon, 37)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func make_map(parent: VBoxContainer, texture: Texture2D) -> void:
	map_frame = AspectRatioContainer.new()
	map_frame.ratio = extent.x / extent.y
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(map_frame)
	map = TextureRect.new()
	map.texture = texture
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.clip_contents = true
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://river_chart_palette.gdshader")
	map.material = palette
	map_frame.add_child(map)
	map.resized.connect(layout_map)
	highway_layer = Node2D.new()
	map.add_child(highway_layer)
	routes = Node2D.new()
	routes.name = "SupplyRoutes"
	map.add_child(routes)
	leaders = Node2D.new()
	map.add_child(leaders)
	boat_marker = MenuTheme.text("◆", 20, MenuTheme.NAVY, true)
	boat_marker.add_theme_color_override("font_outline_color", MenuTheme.PAPER)
	boat_marker.add_theme_constant_override("outline_size", 5)
	map.add_child(boat_marker)
	pins = Control.new()
	pins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(pins)
	pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pulse = PinPulse.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(pulse)
	var scale_margin := MenuTheme.panel(map, MenuTheme.PAPER, MenuTheme.SAND, 7, 8)
	scale_frame = scale_margin.get_parent() as PanelContainer
	scale_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scale_stack := VBoxContainer.new()
	scale_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale_stack.add_theme_constant_override("separation", 2)
	scale_margin.add_child(scale_stack)
	scale_stack.add_child(MenuTheme.text("5 km", 12, MenuTheme.NAVY, true))
	scale_bar = ColorRect.new()
	scale_bar.color = MenuTheme.BLUE
	scale_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale_stack.add_child(scale_bar)


func make_sidebar(parent: HBoxContainer) -> void:
	var margin := MenuTheme.panel(parent, MenuTheme.PAPER, MenuTheme.SAND, 10, 12)
	var frame := margin.get_parent() as Control
	frame.custom_minimum_size.x = 282
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 10)
	margin.add_child(sidebar)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", MenuTheme.GAP)
	sidebar.add_child(tabs)
	ways_tab = header_button(tabs, "Waypoints", "chart", func(): show_journal(false))
	journal_tab = header_button(tabs, "Catch Journal", "journal", func(): show_journal(true))
	for tab in [ways_tab, journal_tab]:
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 14)
		tab.toggle_mode = true

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sidebar.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	destinations = VBoxContainer.new()
	destinations.add_theme_constant_override("separation", 5)
	pages.add_child(destinations)
	no_selection = MenuTheme.text("Choose a waypoint to see travel details.", 14, MenuTheme.MUTED)
	no_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail_margin := MenuTheme.panel(destinations, MenuTheme.CREAM, MenuTheme.SAND, 8, 10)
	detail = detail_margin.get_parent() as PanelContainer
	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 5)
	detail_margin.add_child(detail_content)
	detail_title = MenuTheme.text("", 17, MenuTheme.NAVY, true)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(detail_title)
	detail_text = MenuTheme.text("", 14, MenuTheme.MUTED)
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(detail_text)
	travel_button = MenuTheme.button("Travel", &"MainAction", "play", 36)
	travel_button.pressed.connect(func(): travel_requested.emit(selected))
	detail_content.add_child(travel_button)
	status = MenuTheme.text("", 14, MenuTheme.ORANGE)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(status)
	set_status("")
	destinations.add_child(no_selection)
	detail.hide()

	journal_view = VBoxContainer.new()
	pages.add_child(journal_view)
	journal_view.add_child(MenuTheme.text("Recent catches", 21, MenuTheme.NAVY, true))
	journal_label = MenuTheme.text("", 15, MenuTheme.MUTED)
	journal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_view.add_child(journal_label)
	sidebar.add_child(MenuTheme.text("↑ ↓ Browse   ·   → Travel   ·   Enter Select", 12, MenuTheme.MUTED))


func add_waypoint(id: int, caption: String, pin_text: String, title: String, description: String,
		world_position: Vector3, offset: Vector2, tint: Color, is_boat := false, region := 1) -> void:
	var icon := MenuTheme.dot_texture(tint, 13)
	var list_button := waypoint_button(caption, tint, icon, 34)
	destinations.add_child(list_button)
	destinations.move_child(list_button, destinations.get_child_count() - 3)
	var pin := waypoint_button(pin_text, tint, icon, 29)
	pin.add_theme_font_size_override("font_size", 13)
	pin.tooltip_text = title
	pins.add_child(pin)
	var leader := Line2D.new()
	leader.width = 1.8
	leader.antialiased = true
	leaders.add_child(leader)
	var dot := waypoint_dot(tint)
	leader.add_child(dot)
	waypoints[id] = {"list": list_button, "pin": pin, "leader": leader, "dot": dot, "tint": tint,
		"world": world_position, "offset": offset, "title": title, "description": description,
		"region": region}
	if is_boat:
		boat_id = id
		set_return_available(false)
	for button in [list_button, pin]:
		button.pressed.connect(select_waypoint.bind(id))


func waypoint_button(caption: String, tint: Color, icon: Texture2D, height: int) -> Button:
	var button := MenuTheme.button(caption, &"Button", "", height)
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_constant_override("h_separation", 6)
	button.icon = icon
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_color_override("icon_%s_color" % state, Color.WHITE)
	var fill := MenuTheme.PAPER.lerp(tint, .16)
	var selected_fill := MenuTheme.PAPER.lerp(tint, .30)
	button.add_theme_stylebox_override("normal", MenuTheme.box(fill, fill.lerp(tint, .35), 7, 9))
	button.add_theme_stylebox_override("hover", MenuTheme.box(fill.lerp(tint, .14), tint, 7, 9))
	for state in ["pressed", "hover_pressed"]:
		var style := MenuTheme.box(selected_fill, tint, 7, 9)
		style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
	return button


func waypoint_dot(tint: Color) -> Polygon2D:
	var dot := Polygon2D.new()
	dot.polygon = PackedVector2Array([Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)])
	dot.color = tint
	return dot


func map_point(world: Vector3) -> Vector2:
	return (Vector2(world.x, world.z) - bounds.position) / bounds.size * map.size


func setup_sections(names: Array, areas: Array[Rect2]) -> void:
	sections = areas
	for title: String in names:
		section_picker.add_item(title)
	select_section(0)


func select_section(index: int) -> void:
	section = index
	bounds = sections[index]
	section_picker.select(index)
	if index == 0:
		map.texture = atlas
	else:
		var crop := AtlasTexture.new()
		crop.atlas = atlas
		var scale := atlas.get_size() / extent
		crop.region = Rect2(bounds.position * scale, bounds.size * scale)
		map.texture = crop
	map_frame.ratio = bounds.size.x / bounds.size.y
	selected = -1
	pulse.progress = 1.0
	for id: int in waypoints:
		update_waypoint_visibility(id)
	if boat_id >= 0:
		update_boat(waypoints[boat_id].world)
	update_selection()
	set_status("")
	layout_map()
	connect_focus()


func update_waypoint_visibility(id: int) -> void:
	var waypoint: Dictionary = waypoints[id]
	var world: Vector3 = waypoint.world
	waypoint.list.visible = return_available if id == boat_id else section == 0 or waypoint.region == section
	var on_map := bounds.has_point(Vector2(world.x, world.z))
	waypoint.pin.visible = waypoint.list.visible and on_map
	waypoint.leader.visible = waypoint.pin.visible


func set_highway(streets: Array) -> void:
	for index: int in preload("res://deep_river_roads.gd").HIGHWAY:
		var ribbon := Line2D.new()
		ribbon.default_color = Color("#d79e48")
		ribbon.antialiased = true
		highway_layer.add_child(ribbon)
		highway_paths.append(ribbon)
		highway_points.append(streets[index])
	highway_label = MenuTheme.text("HIGHWAY 17", 13, MenuTheme.NAVY, true)
	highway_label.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.PAPER, Color("#d79e48"), 4, 5))
	highway_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highway_layer.add_child(highway_label)
	layout_map()


func layout_map() -> void:
	if scale_bar == null:
		return
	scale_bar.custom_minimum_size = Vector2(5000.0 / bounds.size.x * map.size.x, 2)
	scale_frame.position = Vector2(12, map.size.y - 52)
	for id: int in waypoints:
		place_pin(id)
	for i in highway_paths.size():
		var points := PackedVector2Array()
		for p: Array in highway_points[i]:
			points.append(map_point(Vector3(p[0], 0, p[1])))
		highway_paths[i].points = points
		highway_paths[i].width = 3.0 if section == 0 else 4.0
	if highway_label != null:
		var anchor := Vector2(17030, 13565)
		highway_label.visible = bounds.has_point(anchor)
		highway_label.position = map_point(Vector3(anchor.x, 0, anchor.y)) + Vector2(-54, 13)
	map_resized.emit()


func place_pin(id: int) -> void:
	var waypoint: Dictionary = waypoints[id]
	var pin: Button = waypoint.pin
	var origin := map_point(waypoint.world)
	var inset := Vector2(7, 7)
	pin.size = pin.get_combined_minimum_size()
	var maximum := (map.size - pin.size - inset).max(inset)
	pin.position = (origin + Vector2(waypoint.offset)).clamp(inset, maximum)
	if id == boat_id:
		# The boat moves. Choose another side if its label lands over a shore waypoint.
		for offset in [Vector2(18, -73), Vector2(18, 17), Vector2(-108, -73), Vector2(-108, 17)]:
			pin.position = (origin + offset).clamp(inset, maximum)
			var overlaps := false
			for other: int in waypoints:
				if other != boat_id and waypoints[other].pin.visible \
						and pin.get_rect().grow(4).intersects(waypoints[other].pin.get_rect()):
					overlaps = true
					break
			if not overlaps:
				break
	var endpoint := origin.clamp(pin.position, pin.position + pin.size)
	waypoint.leader.points = PackedVector2Array([origin, endpoint])
	waypoint.dot.position = origin
	waypoint.leader.default_color = Color(waypoint.tint, 1.0 if id == selected else .78)
	waypoint.leader.width = 2.6 if id == selected else 1.6
	if id == selected:
		pulse.position = pin.position + Vector2(15, pin.size.y / 2.0)


func update_boat(world: Vector3) -> void:
	if boat_id < 0:
		return
	boat_marker.visible = bounds.has_point(Vector2(world.x, world.z))
	boat_marker.position = map_point(world) - boat_marker.size * .5
	waypoints[boat_id].world = world
	update_waypoint_visibility(boat_id)
	if waypoints[boat_id].pin.visible:
		place_pin(boat_id)


func set_return_available(available: bool) -> void:
	return_available = available
	update_waypoint_visibility(boat_id)


func open(show_catches: bool) -> void:
	selected = -1
	update_selection()
	show()
	show_journal(show_catches)
	layout_map()
	if not show_catches:
		for waypoint: Dictionary in waypoints.values():
			if waypoint.list.visible:
				waypoint.list.grab_focus()
				break


func show_journal(enabled: bool) -> void:
	destinations.visible = not enabled
	journal_view.visible = enabled
	ways_tab.theme_type_variation = &"MainAction" if not enabled else &"QuietAction"
	journal_tab.theme_type_variation = &"MainAction" if enabled else &"QuietAction"
	ways_tab.set_pressed_no_signal(not enabled)
	journal_tab.set_pressed_no_signal(enabled)
	var tab := journal_tab if enabled else ways_tab
	tab.grab_focus()
	connect_focus()


func select_waypoint(id: int) -> void:
	var pin: Button = waypoints[id].pin
	if journal_view.visible:
		show_journal(false)
		pin.grab_focus()
	selected = id
	set_status("")
	update_selection()
	if pulse_tween != null:
		pulse_tween.kill()
	pulse.tint = waypoints[id].tint
	pulse.progress = 0.0
	pulse_tween = create_tween()
	pulse_tween.tween_property(pulse, "progress", 1.0, .55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	connect_focus()


func update_selection() -> void:
	for id: int in waypoints:
		waypoints[id].list.set_pressed_no_signal(id == selected)
		waypoints[id].pin.set_pressed_no_signal(id == selected)
		place_pin(id)
	detail.visible = selected >= 0
	no_selection.visible = selected < 0
	if selected >= 0:
		var waypoint: Dictionary = waypoints[selected]
		detail_title.text = waypoint.title
		detail_text.text = waypoint.description
		travel_button.text = "Return to boat" if selected == boat_id else "Travel"


func set_status(message: String) -> void:
	status.text = message
	status.visible = not message.is_empty()


func connect_focus() -> void:
	var order: Array[Control] = [section_picker, ways_tab, journal_tab]
	var map_order: Array[Control] = []
	for id: int in waypoints:
		var waypoint: Dictionary = waypoints[id]
		if waypoint.list.is_visible_in_tree():
			order.append(waypoint.list)
			set_neighbor(waypoint.list, SIDE_LEFT, waypoint.pin if waypoint.pin.visible else section_picker)
			set_neighbor(waypoint.pin, SIDE_RIGHT, travel_button if id == selected else waypoint.list)
			set_neighbor(waypoint.list, SIDE_RIGHT, travel_button if id == selected else journal_tab)
		if waypoint.pin.is_visible_in_tree():
			map_order.append(waypoint.pin)
	if destinations.visible and selected >= 0:
		order.append(travel_button)
		set_neighbor(travel_button, SIDE_LEFT, waypoints[selected].list)
	order.append(guide_button)
	order.append(close_button)
	for i in order.size():
		set_neighbor(order[i], SIDE_TOP, order[posmod(i - 1, order.size())])
		set_neighbor(order[i], SIDE_BOTTOM, order[(i + 1) % order.size()])
	for i in map_order.size():
		set_neighbor(map_order[i], SIDE_TOP, map_order[posmod(i - 1, map_order.size())])
		set_neighbor(map_order[i], SIDE_BOTTOM, map_order[(i + 1) % map_order.size()])
		if journal_view.visible:
			set_neighbor(map_order[i], SIDE_RIGHT, journal_tab)
	if not map_order.is_empty():
		set_neighbor(ways_tab, SIDE_LEFT, map_order[0])
		set_neighbor(journal_tab, SIDE_LEFT, ways_tab)
	set_neighbor(ways_tab, SIDE_RIGHT, journal_tab)
	set_neighbor(section_picker, SIDE_RIGHT, guide_button)
	set_neighbor(guide_button, SIDE_LEFT, section_picker)
	set_neighbor(guide_button, SIDE_RIGHT, close_button)
	set_neighbor(close_button, SIDE_LEFT, guide_button)


func set_neighbor(control: Control, side: Side, neighbor: Control) -> void:
	control.set_focus_neighbor(side, control.get_path_to(neighbor))
