extends CanvasLayer

const Atlas = preload("res://river_menu_theme.gd")
const XP = preload("res://progression.gd")
const COLORS := {"Fishing": Color.SKY_BLUE, "Lawn Care": Color.PALE_GREEN, "Boating": Color.TURQUOISE, "Driving": Color.ORANGE, "Business": Color.PLUM, "Exploration": Color.CORAL}
var game: Node
var meter := ProgressBar.new()
var heading := Label.new()
var toast := Label.new()
var panel := PanelContainer.new()
var graph := GraphEdit.new()
var details := Label.new()
var purchase := Button.new()
var summary := Label.new()
var tabs := HFlowContainer.new()
var banner := Label.new()
var promotion_tween: Tween
var category := "Fishing"
var selected := ""
var previous_mode := Input.MOUSE_MODE_VISIBLE
var last_xp := -1
var last_level := 1
var initialized := false
var last_points := -1
var session := ""
var fade: Tween

func setup(owner_game: Node) -> void:
	game = owner_game
	layer = 8
	var strip := VBoxContainer.new()
	game.backpack.add_child(strip)
	strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	strip.offset_left = -145
	strip.offset_right = 145
	strip.offset_bottom = game.backpack.hotbar.offset_top - 4
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [toast, heading]:
		strip.add_child(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(meter)
	meter.show_percentage = false
	meter.custom_minimum_size.y = 5
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_top = 85
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 24)
	banner.add_theme_color_override("font_color", Atlas.CREAM)
	banner.add_theme_stylebox_override("normal", Atlas.box(Color("#182f40dc"), Color("#dfb784bb"), 10, 18))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.hide()
	var surface := StyleBoxFlat.new()
	surface.bg_color = Atlas.CREAM
	surface.set_border_width_all(2)
	surface.border_color = Atlas.SAND
	surface.set_corner_radius_all(14)
	panel.theme = Atlas.get_theme()
	surface.content_margin_left = 20
	surface.content_margin_right = 20
	surface.content_margin_top = 16
	surface.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", surface)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 20
	panel.offset_bottom = -20
	panel.hide()
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	layout.add_child(Atlas.text("Crew skill journal", 30, Atlas.NAVY, true))
	layout.add_child(summary)
	layout.add_child(tabs)
	for branch: String in COLORS:
		var tab := Atlas.button(branch, &"QuietAction", {"Fishing":"fish", "Lawn Care":"tools", "Boating":"river", "Driving":"chart", "Business":"jobs", "Exploration":"journal"}[branch], 40)
		tab.toggle_mode = true
		tab.text = branch
		tabs.add_child(tab)
		tab.pressed.connect(show_branch.bind(branch))
	var close := Button.new()
	close.text = "Close"
	tabs.add_child(close)
	close.pressed.connect(toggle)
	var columns := HSplitContainer.new()
	layout.add_child(columns)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(graph)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sidebar := VBoxContainer.new()
	columns.add_child(sidebar)
	sidebar.custom_minimum_size.x = 280
	sidebar.add_child(Atlas.text("Skill details", 23, Atlas.BLUE, true))
	sidebar.add_theme_constant_override("separation", 15)
	purchase.theme_type_variation = &"MainAction"
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.minimap_enabled = false
	graph.zoom = .85
	graph.add_theme_stylebox_override("panel", Atlas.box(Atlas.MIST, Atlas.SAND, 10))
	graph.show_grid = true
	graph.add_theme_color_override("grid_minor", Color("#1c567315"))
	graph.add_theme_color_override("grid_major", Color("#1c567332"))
	graph.show_arrange_button = false
	graph.show_grid_buttons = false
	sidebar.add_child(details)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(purchase)
	purchase.pressed.connect(func():
		var rank := int(profile().get("ranks", {}).get(selected, 0))
		game.campaign.request("purchase_skill", [selected, rank]))

func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		previous_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show_branch(category)
		tabs.get_child(0).grab_focus()
	else:
		Input.mouse_mode = previous_mode

func show_branch(branch: String) -> void:
	category = branch
	for tab in tabs.get_children():
		if tab is Button and tab.toggle_mode:
			tab.set_pressed_no_signal(tab.text == branch)
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.queue_free()
	var depths := {}
	var catalog := XP.CATALOG.skills()
	var first := ""
	for id: String in catalog:
		var skill: Dictionary = catalog[id]
		if skill.category != category:
			continue
		if first.is_empty():
			first = id
		var depth := int(skill.column)
		depths[id] = depth
		var row := int(skill.row)
		var node := GraphNode.new()
		node.name = id
		node.title = skill.name
		var card := StyleBoxFlat.new()
		card.bg_color = Atlas.PAPER
		card.content_margin_left = 10
		card.content_margin_right = 10
		card.set_corner_radius_all(6)
		node.add_theme_stylebox_override("panel", card)
		var title_box := card.duplicate() as StyleBoxFlat
		title_box.bg_color = Atlas.BLUE
		node.get_titlebar_hbox().get_child(0).add_theme_color_override("font_color", Atlas.PAPER)
		node.add_theme_stylebox_override("titlebar", title_box)
		node.position_offset = Vector2(40 + depth * 214, 92 + row * 148 + (depth % 2) * 45)
		graph.add_child(node)
		var button := preload("res://skill_hex.gd").new()
		button.flat = true
		button.custom_minimum_size = Vector2(125, 40)
		node.add_child(button)
		var rank := int(profile().get("ranks", {}).get(id, 0))
		button.text = "%d / %d" % [rank, skill.cap]
		button.tint = Color.GOLD if rank >= int(skill.cap) else (Color.AQUAMARINE if rank > 0 else (COLORS[branch] if XP.can_buy(profile(), id) else Color.GRAY))
		button.pressed.connect(select_skill.bind(id))
		node.set_slot(0, true, 0, Atlas.BLUE, true, 0, Atlas.BLUE)
	for id: String in depths:
		for dep: String in catalog[id].requires:
			graph.connect_node(dep, 0, id, 0)
	select_skill(selected if depths.has(selected) else first)
	graph.set_deferred("scroll_offset", Vector2.ZERO)

func profile() -> Dictionary:
	return game.campaign.progression_for(game.campaign.crew.my_id())

func select_skill(id: String) -> void:
	selected = id
	for node in graph.get_children():
		if node is GraphNode:
			var hex = node.get_child(0)
			hex.chosen = str(node.name) == id
			hex.queue_redraw()
	var skill: Dictionary = XP.CATALOG.skills()[id]
	var available := XP.can_buy(profile(), id)
	var prerequisites := PackedStringArray()
	for dep: String in skill.requires:
		prerequisites.append("%s rank %d" % [XP.CATALOG.skills()[dep].name, skill.requires[dep]])
	details.text = "%s   •   %s\n%s" % [skill.name, skill.effect, "Requires " + ", ".join(prerequisites) if prerequisites.size() else "Entry skill"]
	details.text += "   •   Level %d   •   Rank %d/%d" % [skill.level, profile().get("ranks", {}).get(id, 0), skill.cap]
	purchase.text = "Purchase rank · 1 point" if skill.enabled else "Unavailable in this build"
	if skill.has("per_rank"):
		var rank := int(profile().get("ranks", {}).get(id, 0))
		var unit := " beam width" if id == "fish_finder" else "%"
		details.text += "\nCurrent bonus   %s%s" % [str(rank * float(skill.per_rank)), unit]
		if rank < skill.cap:
			details.text += "\nNext rank   %s%s" % [str((rank + 1) * float(skill.per_rank)), unit]
	if not skill.enabled:
		details.text += "\n" + str(skill.unavailable)
	purchase.disabled = not available

func _process(_delta: float) -> void:
	if game == null:
		return
	var p := profile()
	var stats := XP.stats(p)
	if game.campaign.crew.is_guest() and not p.has("version"):
		initialized = false
	var xp := int(p.get("xp", 0))
	var mode: String = game.campaign.crew.mode
	if mode != session:
		session = mode
		last_xp = -1
		initialized = false
	if xp == last_xp and stats.points == last_points and (initialized or not p.has("version")):
		return
	var target := float(stats.rest) / XP.threshold(stats.level) if stats.level < XP.CAP else 1.0
	meter.max_value = 1.0
	create_tween().tween_property(meter, "value", target, .3)
	heading.text = "Level %d   •   %d skill points   [K]" % [stats.level, stats.points]
	summary.text = "%s   •   %d / %d XP" % [heading.text, stats.rest, XP.threshold(stats.level)]
	if initialized and last_xp >= 0 and xp > last_xp:
		toast.text = "+%d XP   •   %s" % [xp - last_xp, str(p.get("reason", "")).capitalize()]
		if stats.level > last_level:
			banner.text = "LEVEL   %02d\n+%d skill points" % [stats.level, stats.level - last_level]
			banner.modulate.a = 0.0
			banner.show()
			if promotion_tween:
				promotion_tween.kill()
			banner.offset_top = 55
			banner.scale = Vector2(.92, .92)
			banner.pivot_offset = banner.size * .5
			promotion_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			promotion_tween.tween_property(banner, "modulate:a", 1.0, .32)
			promotion_tween.parallel().tween_property(banner, "offset_top", 90, .55)
			promotion_tween.parallel().tween_property(banner, "scale", Vector2.ONE, .55)
			promotion_tween.tween_interval(2.1)
			promotion_tween.tween_property(banner, "modulate:a", 0.0, .45)
			promotion_tween.parallel().tween_property(banner, "offset_top", 72, .45)
			promotion_tween.tween_callback(banner.hide)
		if fade:
			fade.kill()
		toast.modulate.a = 0
		fade = create_tween()
		fade.tween_property(toast, "modulate:a", 1.0, .18)
		fade.tween_interval(1.6)
		fade.tween_property(toast, "modulate:a", 0.0, .4)
	initialized = not game.campaign.crew.is_guest() or p.has("version")
	last_xp = xp
	last_level = stats.level
	last_points = stats.points
	if panel.visible:
		show_branch(category)
