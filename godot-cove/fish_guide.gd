extends Control

signal closed

const Species = preload("res://fish_species.gd")
const Fish = preload("res://river_fish.gd")
const TEXT := Color("#edf1e5")
const MUTED := Color("#a8beb8")
const ACCENT := Color("#e1b37b")

var viewport: SubViewport
var specimen: Fish
var heading: Label
var latin: Label
var details: Label
var entries: ItemList
var ordered: Array[int] = []
var selected := 0
var clock := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color("#091217db")
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#13252b")
	frame.border_color = Color("#506f6a")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(12)
	frame.content_margin_left = 26
	frame.content_margin_right = 26
	frame.content_margin_top = 23
	frame.content_margin_bottom = 23
	panel.add_theme_stylebox_override("panel", frame)
	var margins := MarginContainer.new()
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 64)
	for side in ["top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 48)
	margins.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var title := caption("Ottawa River fish guide", 28, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "Close  [J]"
	close.custom_minimum_size.x = 113
	close.pressed.connect(func() -> void: closed.emit())
	top.add_child(close)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 23)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(pages)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 297
	sidebar.add_theme_constant_override("separation", 11)
	pages.add_child(sidebar)
	var search := LineEdit.new()
	search.placeholder_text = "Find a species"
	search.text_changed.connect(fill_list)
	sidebar.add_child(search)
	entries = ItemList.new()
	entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("v_separation", 8)
	entries.add_theme_color_override("font_color", TEXT)
	entries.item_selected.connect(func(index: int) -> void: show_fish(entries.get_item_metadata(index)))
	sidebar.add_child(entries)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(content)
	heading = caption("", 30, TEXT)
	latin = caption("", 17, MUTED)
	content.add_child(heading)
	content.add_child(latin)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(250, 236)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(image)
	create_specimen()
	image.texture = viewport.get_texture()
	details = caption("", 17, ACCENT)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details)
	for index in Species.all().size():
		ordered.append(index)
	ordered.sort_custom(func(a: int, b: int) -> bool: return Species.profile(a).name.naturalnocasecmp_to(Species.profile(b).name) < 0)
	fill_list("")
	show_fish(0)
	visibility_changed.connect(update_preview)
	update_preview()


func caption(text: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	return item


func create_specimen() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(675, 324)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#0d2027")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#c8deeb")
	environment.environment.ambient_light_energy = .48
	scene.add_child(environment)
	var daylight := DirectionalLight3D.new()
	daylight.light_energy = .91
	daylight.light_color = Color("#fff0d8")
	daylight.rotation_degrees = Vector3(-36, 48, -18)
	scene.add_child(daylight)
	var fill := DirectionalLight3D.new()
	fill.light_energy = .28
	fill.light_color = Color("#9bced1")
	fill.rotation_degrees = Vector3(-26, -108, 15)
	scene.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .65
	scene.add_child(camera)
	camera.position = Vector3(1.9, .18, -.031)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	specimen = Fish.new()
	scene.add_child(specimen)


func fill_list(query: String) -> void:
	entries.clear()
	var term := query.strip_edges().to_lower()
	for index in ordered:
		var row := Species.profile(index)
		if term.is_empty() or term in row.name.to_lower() or term in row.scientific.to_lower():
			var slot := entries.add_item(row.name)
			entries.set_item_metadata(slot, index)
			if index == selected:
				entries.select(slot)
	if entries.is_anything_selected():
		entries.ensure_current_is_visible()


func show_fish(index: int) -> void:
	selected = index
	var row := Species.profile(index)
	heading.text = row.name
	latin.text = row.scientific
	var status := "Recorded elsewhere on the Ottawa River"
	if row.record == "historical":
		status = "Historical record for Upper Allumette"
	elif row.record == "upper_allumette":
		status = "Upper Allumette • Observe only" if row.rig == "watch" else "Upper Allumette • " + Species.RIG_LABELS[Species.RIGS.find(row.rig)]
	details.text = "%s\n%d–%d cm in this game" % [status, int(row.length_cm[0]), int(row.length_cm[1])]
	specimen.select_species(index, 100)


func update_preview() -> void:
	var open := is_visible_in_tree()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open else SubViewport.UPDATE_DISABLED
	set_process(open)


func _process(delta: float) -> void:
	clock += delta
	var heading_angle := sin(clock * .61) * .23
	var course := Vector3.FORWARD.rotated(Vector3.UP, heading_angle)
	specimen.pose(course * .49, course, sin(clock * .68) * .07, .036, clock * 5.0)
