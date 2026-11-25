extends Control

signal inspected(id: String)
const XP = preload("res://progression.gd")
const Atlas = preload("res://game_menu_theme.gd")
const MARKS = preload("res://sounding_marks.svg")
const WATER = preload("res://sounding_water.svg")
const FISH := ["steady_hands", "experienced_angler", "quick_reel", "fish_finder", "lucky_catch", "trophy_hunter", "master_angler"]
const SYMBOL := {"Lawn Care":"tools", "Boating":"river", "Driving":"chart", "Business":"jobs", "Exploration":"journal"}
const INK := Color("#edf2e2")
const MINT := Color("#9ed4c7")
const GOLD := Color("#ffc36e")
const SEA := Color("#092f3e")
const TILE := Vector2(202, 101)
var buttons := {}
var ranks := {}
var level := 1
var selected := ""
var pan := Vector2.ZERO
var dragging := false
var columns := 1
var rows := 1

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	resized.connect(layout_nodes)

func populate(branch: String, profile: Dictionary, reset: bool) -> void:
	if reset:
		pan = Vector2.ZERO
	for button: Button in buttons.values():
		remove_child(button)
		button.queue_free()
	buttons.clear()
	level = XP.stats(profile).level
	ranks = profile.get("ranks", {})
	columns = 1
	rows = 1
	for id: String in XP.CATALOG.skills():
		var skill: Dictionary = XP.CATALOG.skills()[id]
		if skill.category != branch:
			continue
		columns = maxi(columns, int(skill.column) + 1)
		rows = maxi(rows, int(skill.row) + 1)
		var button := Button.new()
		button.flat = true
		button.accessibility_name = skill.name
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.size = TILE
		add_child(button)
		buttons[id] = button
		button.draw.connect(draw_buoy.bind(button, id, skill))
		button.pressed.connect(func(): inspected.emit(id))
		button.focus_entered.connect(reveal.bind(button))
	layout_nodes()

func spacing() -> Vector2:
	return Vector2(maxf(205, (size.x - TILE.x - 52) / maxi(columns - 1, 1)), maxf(106, (size.y - TILE.y - 52) / maxi(rows - 1, 1)))

func layout_nodes() -> void:
	var step := spacing()
	var extent := TILE + Vector2(columns - 1, rows - 1) * step + Vector2(52, 52)
	# Leave a little travel beyond fitted charts, while keeping an edge in reach.
	pan = pan.clamp((size - extent).min(Vector2.ZERO) - Vector2(70, 46), Vector2(70, 46))
	for id: String in buttons:
		var skill: Dictionary = XP.CATALOG.skills()[id]
		buttons[id].position = (Vector2(26, 26) + pan + Vector2(skill.column, skill.row) * step).round()
	queue_redraw()

func reveal(button: Button) -> void:
	if size.x < TILE.x or size.y < TILE.y:
		return
	var pos := button.position
	pan += Vector2(maxf(0, -pos.x) - maxf(0, pos.x + TILE.x - size.x), maxf(0, -pos.y) - maxf(0, pos.y + TILE.y - size.y))
	layout_nodes()
	button.queue_redraw()

func accessible(skill: Dictionary) -> bool:
	if not skill.enabled or level < int(skill.level):
		return false
	for dep: String in skill.requires:
		if int(ranks.get(dep, 0)) < int(skill.requires[dep]):
			return false
	return true

func highlight(id: String) -> void:
	selected = id
	for button: Button in buttons.values():
		button.queue_redraw()

func draw_buoy(button: Button, id: String, skill: Dictionary) -> void:
	var center := Vector2(TILE.x / 2, 34)
	var rank := int(ranks.get(id, 0))
	var locked := not accessible(skill)
	var tint := GOLD if selected == id else (Color("#afc5c6") if locked else MINT)
	button.draw_circle(center, 26, SEA, true, -1, true)
	if locked:
		for i in 18:
			button.draw_arc(center, 26, i * TAU / 18, (i + .58) * TAU / 18, 5, tint, 2, true)
	else:
		button.draw_arc(center, 26, 0, TAU, 60, tint, 2, true)
	if selected == id or button.has_focus() or button.is_hovered():
		button.draw_arc(center, 32, 0, TAU, 60, GOLD if selected == id else INK, 2, true)
	if button.has_focus():
		button.draw_line(center + Vector2(-8, -34), center + Vector2(8, -34), INK, 3)
	var target := Rect2(center - Vector2(15, 15), Vector2(30, 30))
	if id in FISH:
		button.draw_texture_rect_region(MARKS, target, Rect2(FISH.find(id) * 48, 0, 48, 48), tint)
	else:
		button.draw_texture_rect(Atlas.icon(SYMBOL[skill.category]), target, false, tint)
	var font := ThemeDB.fallback_font
	button.draw_string(font, Vector2(0, 80), skill.name, HORIZONTAL_ALIGNMENT_CENTER, TILE.x, 17, GOLD if selected == id else INK)
	var caption := "Unavailable" if not skill.enabled else ("Locked" if locked else "Rank %d / %d" % [rank, skill.cap])
	button.draw_string(font, Vector2(0, 99), caption, HORIZONTAL_ALIGNMENT_CENTER, TILE.x, 14, tint)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	for x in range(int(fposmod(pan.x, 32)), int(size.x), 32):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#17434d"))
	for y in range(int(fposmod(pan.y, 32)), int(size.y), 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#17434d"))
	draw_texture_rect(WATER, Rect2(Vector2.ZERO, size), false)
	for id: String in buttons:
		var skill: Dictionary = XP.CATALOG.skills()[id]
		for dep: String in skill.requires:
			var offset := Vector2(TILE.x / 2, 34)
			var start: Vector2 = buttons[dep].position + offset
			var end: Vector2 = buttons[id].position + offset
			if skill.enabled and int(ranks.get(dep, 0)) >= int(skill.requires[dep]):
				draw_line(start, end, MINT, 2, true)
			else:
				draw_dashed_line(start, end, Color("#81999d"), 2, 7, true, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pan += event.relative
			layout_nodes()
			accept_event()
		else:
			dragging = false
