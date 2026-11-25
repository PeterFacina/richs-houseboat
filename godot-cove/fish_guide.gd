extends Control

signal closed

const Species = preload("res://fish_species.gd")
const Fish = preload("res://river_fish.gd")
const MenuTheme = preload("res://river_menu_theme.gd")
const NotebookStyle = preload("res://notebook_theme.gd")
var embedded := false

var image := TextureRect.new()
var viewport: SubViewport
var specimen: Fish
var heading: Label
var latin: Label
var discovery: Label
var details: Label
var tally: Label
var search: LineEdit
var entries: VBoxContainer
var buttons: Dictionary = {}
var ordered: Array[int] = []
var caught: Dictionary = {}
var selected := 0
var clock := 0.0


func _ready() -> void:
	theme = MenuTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = MenuTheme.SCRIM
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = not embedded
	var space := MenuTheme.panel(self, MenuTheme.CREAM, MenuTheme.SAND, 15, 24)
	var frame := space.get_parent() as PanelContainer
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = MenuTheme.MARGIN
	frame.offset_right = -MenuTheme.MARGIN
	frame.offset_top = 40
	frame.offset_bottom = -40
	if embedded:
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	space.add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	var title := MenuTheme.text("Fish Index", 42, MenuTheme.NAVY, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := MenuTheme.button("Close  ·  J", &"QuietAction", "back", 37)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): closed.emit())
	top.add_child(close)
	close.visible = not embedded
	layout.add_child(HSeparator.new())

	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 10 if embedded else 20)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(pages)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 334
	sidebar.add_theme_constant_override("separation", MenuTheme.GAP)
	pages.add_child(sidebar)
	tally = MenuTheme.text("", 15, MenuTheme.BLUE, true)
	sidebar.add_child(tally)
	search = LineEdit.new()
	search.placeholder_text = "Find a species"
	search.custom_minimum_size.y = 38
	search.text_changed.connect(fill_list)
	sidebar.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sidebar.add_child(scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", MenuTheme.GAP)
	scroll.add_child(entries)
	if embedded:
		pages.add_child(NotebookStyle.Binding.new())

	var reading_area := MenuTheme.panel(pages, MenuTheme.PAPER, MenuTheme.SAND, 12, 18)
	(reading_area.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	reading_area.add_child(content)
	discovery = MenuTheme.text("", 15, MenuTheme.BLUE, true)
	content.add_child(discovery)
	heading = MenuTheme.text("", 34, MenuTheme.NAVY, true)
	content.add_child(heading)
	latin = MenuTheme.text("", 17, MenuTheme.MUTED)
	content.add_child(latin)
	image.custom_minimum_size = Vector2(250, 182)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(image)
	create_specimen()
	image.texture = viewport.get_texture()
	details = MenuTheme.text("", 17, MenuTheme.NAVY)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details)

	for index in Species.all().size():
		ordered.append(index)
	ordered.sort_custom(func(a: int, b: int) -> bool:
		return Species.profile(a).name.naturalnocasecmp_to(Species.profile(b).name) < 0)
	selected = ordered[0]
	set_catches({})
	if embedded:
		title.add_theme_color_override(&"font_color", NotebookStyle.OLIVE)
	visibility_changed.connect(update_preview)
	update_preview()


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
	environment.environment.background_color = MenuTheme.NAVY
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


func set_catches(catches: Dictionary) -> void:
	caught = catches
	var count := 0
	for index in ordered:
		if caught.has(Species.profile(index).name):
			count += 1
	tally.text = "%d of %d species caught" % [count, ordered.size()]
	fill_list(search.text)
	show_fish(selected)


func fill_list(query: String) -> void:
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	buttons.clear()
	var term := query.strip_edges().to_lower()
	for index in ordered:
		var row := Species.profile(index)
		if term.is_empty() or (caught.has(row.name) and (term in row.name.to_lower() or term in row.scientific.to_lower())):
			add_card(index, row.name)
	if buttons.is_empty():
		entries.add_child(MenuTheme.text("No matching species", 16, MenuTheme.MUTED))
	elif not buttons.has(selected):
		show_fish(buttons.keys()[0])
	else:
		update_cards()


func add_card(index: int, species_name: String) -> void:
	var button := MenuTheme.button("", &"Button", "", 58)
	var caption := species_name if caught.has(species_name) else "Unidentified fish"
	button.accessibility_name = caption + ", " + discovery_text(species_name)
	button.toggle_mode = true
	button.pressed.connect(show_fish.bind(index))
	entries.add_child(button)
	buttons[index] = button
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 13
	row.offset_right = -10
	var icon := TextureRect.new()
	icon.texture = MenuTheme.icon("fish")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size.x = 26
	icon.self_modulate = MenuTheme.BLUE if caught.has(species_name) else MenuTheme.MUTED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	labels.add_theme_constant_override("separation", 1)
	row.add_child(labels)
	labels.add_child(MenuTheme.text(caption, 17, MenuTheme.NAVY, true))
	var tint := MenuTheme.BLUE if caught.has(species_name) else MenuTheme.MUTED
	labels.add_child(MenuTheme.text(discovery_text(species_name), 14, tint))


func discovery_text(species_name: String) -> String:
	return "Caught" if caught.has(species_name) else "Undiscovered"


func update_cards() -> void:
	for index: int in buttons:
		var button: Button = buttons[index]
		button.set_pressed_no_signal(index == selected)


func show_fish(index: int) -> void:
	selected = index
	var row := Species.profile(index)
	image.visible = caught.has(row.name)
	latin.visible = image.visible
	update_preview()
	if not image.visible:
		heading.text = "Unidentified fish"
		latin.text = ""
		discovery.text = "Undiscovered"
		details.text = "Land this species to add its illustration and field notes to your book."
		update_cards()
		return
	heading.text = row.name
	latin.text = row.scientific
	discovery.text = discovery_text(row.name)
	discovery.add_theme_color_override("font_color", MenuTheme.BLUE if caught.has(row.name) else MenuTheme.MUTED)
	var status := "Recorded elsewhere on the Ottawa River"
	if row.record == "historical":
		status = "Historical record for Upper Allumette"
	elif row.record == "upper_allumette":
		var rig: int = Species.RIGS.find(row.rig)
		status = "Upper Allumette  ·  " + (Species.RIG_LABELS[rig] if rig >= 0 else "Observe only")
	details.text = "%s\n%d–%d cm in this game" % [status, int(row.length_cm[0]), int(row.length_cm[1])]
	details.text += "\nHabitat depth: %s–%s m" % [row.bottom_m[0], row.bottom_m[1]]
	specimen.select_species(index, 100)
	update_cards()


func update_preview() -> void:
	var open := is_visible_in_tree() and image.visible
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open else SubViewport.UPDATE_DISABLED
	set_process(open)


func _process(delta: float) -> void:
	clock += delta
	var heading_angle := sin(clock * .61) * .23
	var course := Vector3.FORWARD.rotated(Vector3.UP, heading_angle)
	specimen.pose(course * .49, course, sin(clock * .68) * .07, .036, clock * 5.0)
