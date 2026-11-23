extends CanvasLayer

const Atlas = preload("res://river_menu_theme.gd")
const XP = preload("res://progression.gd")
const COLORS := {"Fishing": Color.SKY_BLUE, "Lawn Care": Color.PALE_GREEN, "Boating": Color.TURQUOISE, "Driving": Color.ORANGE, "Business": Color.PLUM, "Exploration": Color.CORAL}
var game: Node
var meter := ProgressBar.new()
var heading := Label.new()
var toast := Label.new()
var panel := PanelContainer.new()
var graph := preload("res://sounding_chart.gd").new()
var title := Label.new()
var skill_title := Label.new()
var bonus := Label.new()
var mouse_before := Input.MOUSE_MODE_CAPTURED
var details := Label.new()
var purchase := Button.new()
var summary := Label.new()
var tabs := HFlowContainer.new()
var banner := Label.new()
var promotion_tween: Tween
var category := "Fishing"
var selected := ""
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
	panel.name = "SoundingChart"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface := Atlas.box(Color("#0b252d"), Color("#0b252d"), 0, 24)
	surface.content_margin_top = 16
	surface.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", surface)
	panel.hide()
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	layout.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(names)
	names.add_child(Atlas.text("SKILLS   /   SOUNDING CHART", 15, graph.MINT, true))
	names.add_child(title)
	title.add_theme_font_size_override("font_size", 36)
	header.add_child(summary)
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close := Atlas.button("Close  [K]", &"Button", "", 38)
	header.add_child(close)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(toggle)
	layout.add_child(tabs)
	for branch: String in COLORS:
		var tab := Button.new()
		tab.text = branch
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(124, 38)
		tab.add_theme_stylebox_override("normal", Atlas.box(Color("#173c46"), Color("#28525a"), 5))
		tab.add_theme_stylebox_override("pressed", Atlas.box(Color("#684f2e"), graph.GOLD, 5))
		tabs.add_child(tab)
		tab.pressed.connect(show_branch.bind(branch))
	layout.add_child(graph)
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.inspected.connect(select_skill)
	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", Atlas.box(Color("#163d46"), Color("#315663"), 8, 20))
	layout.add_child(detail_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	detail_panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(Atlas.text("SELECTED SKILL", 13, graph.GOLD, true))
	info.add_child(skill_title)
	skill_title.add_theme_font_size_override("font_size", 25)
	info.add_child(details)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(bonus)
	bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bonus.add_theme_font_size_override("font_size", 24)
	bonus.add_theme_color_override("font_color", graph.GOLD)
	row.add_child(purchase)
	purchase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	purchase.custom_minimum_size = Vector2(210, 48)
	for state in ["normal", "pressed", "hover"]:
		purchase.add_theme_stylebox_override(state, Atlas.box(graph.GOLD.lightened(.12) if state == "hover" else graph.GOLD, graph.GOLD, 5))
		purchase.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", graph.SEA)
	purchase.pressed.connect(func():
		var rank := int(profile().get("ranks", {}).get(selected, 0))
		game.campaign.request("purchase_skill", [selected, rank]))
	layout.add_child(Atlas.text("Drag chart to pan     ·     Tab to focus     ·     Enter to select", 15, graph.MINT))

func toggle() -> void:
	if panel.visible:
		panel.hide()
		graph.dragging = false
		Input.mouse_mode = mouse_before
		return
	mouse_before = Input.mouse_mode
	game.release_line()
	game.sonar_overlay.hide()
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_branch(category)
	graph.buttons[selected].grab_focus()

func show_branch(branch: String, preserve_view := false) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var restore_focus := focused != null and graph.is_ancestor_of(focused)
	category = branch
	title.text = branch
	for tab: Button in tabs.get_children():
		tab.set_pressed_no_signal(tab.text == branch)
	graph.populate(branch, profile(), not preserve_view)
	select_skill(selected if graph.buttons.has(selected) else graph.buttons.keys()[0])
	if restore_focus:
		graph.buttons[selected].grab_focus()

func profile() -> Dictionary:
	return game.campaign.progression_for(game.campaign.crew.my_id())

func select_skill(id: String) -> void:
	selected = id
	graph.highlight(id)
	var skill: Dictionary = XP.CATALOG.skills()[id]
	var available := XP.can_buy(profile(), id)
	var prerequisites := PackedStringArray()
	for dep: String in skill.requires:
		prerequisites.append("%s rank %d" % [XP.CATALOG.skills()[dep].name, skill.requires[dep]])
	var rank := int(profile().get("ranks", {}).get(id, 0))
	skill_title.text = "%s   ·   %d/%d" % [skill.name, rank, skill.cap]
	details.text = str(skill.effect) + "\nRequires level %d" % skill.level
	if not prerequisites.is_empty():
		details.text += " and " + ", ".join(prerequisites)
	bonus.text = ""
	if skill.has("per_rank"):
		var unit := " beam" if id == "fish_finder" else (" pp" if id == "precision_cutting" else "%")
		var step := float(skill.per_rank)
		if str(skill.effect).contains("-"):
			step = -absf(step)
		bonus.text = "%s%s" % [str(rank * step).trim_suffix(".0"), unit]
		if rank < skill.cap:
			bonus.text += " → %s%s" % [str((rank + 1) * step).trim_suffix(".0"), unit]
	purchase.text = "Upgrade · 1 point" if rank > 0 else "Unlock · 1 point"
	if not skill.enabled:
		purchase.text = "Unavailable"
		details.text += "\n" + str(skill.unavailable)
	elif rank >= skill.cap:
		purchase.text = "Fully ranked"
	elif not graph.accessible(skill):
		purchase.text = "Requirements unmet"
	elif not available:
		purchase.text = "1 point needed"
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
	summary.text = "Level %d   ·   %d skill points" % [stats.level, stats.points]
	if stats.level < XP.CAP:
		summary.text += "   ·   %d XP to next level" % (XP.threshold(stats.level) - int(stats.rest))
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
		show_branch(category, true)
