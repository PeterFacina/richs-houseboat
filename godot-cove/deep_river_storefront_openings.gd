extends RefCounted

const Kit = preload("res://scenery.gd")
const SIGNS := "champlain_plaza_signs"
const ALUMINUM := Color("#bcbcb2")
const IVORY := Color("#c7c2b1")
const CONCRETE := Color("#918d80")
const DARK := Color("#3d3832")
const OPENING_TOP := 2.82
const STOCK_TINTS: Array[Color] = [Color("#969174"), Color("#786350"), Color("#8a8b83"), Color("#a9a295")]

# Each bay runs from the Deep River Road corner toward Forest Avenue.
# Pane widths are relative, so the brick piers can follow the surveyed footprint.
const SHOPS := [
	{
		"label": "THE OLIVE TREE", "weight": 1.06, "sign": "#334a3c", "ink": "#ede8d6",
		"door_right": true, "entry": 1.38, "depth": 0.57, "sidelight": 0.28,
		"panes": [1.0, 2.10, 0.64], "sill": 0.43, "head": 2.15, "upper": "header",
		"display": "shelves", "interior": "#73654f",
	},
	{
		"label": "EMPLOYMENT SERVICE", "weight": 0.89, "sign": "#833747", "ink": "#f0e7de",
		"door_right": false, "entry": 1.02, "depth": 0.27,
		"panes": [0.65, 1.95, 0.65], "sill": 0.52, "head": 2.19, "upper": "infill",
		"display": "frosted", "interior": "#c2bdb0",
	},
	{
		"label": "DEEP IN FASHION", "weight": 1.00, "sign": "#d9c7ae", "ink": "#54463e",
		"door_right": true, "entry": 1.54, "depth": 0.49, "sidelight": 0.46,
		"panes": [0.59, 1.95], "sill": 0.50, "head": 2.16, "upper": "header",
		"display": "plinth", "interior": "#8e7265",
	},
	{
		"label": "PET SHOP", "weight": 1.09, "sign": "#4e7454", "ink": "#f2efe2",
		"door_right": false, "entry": 1.38, "depth": 0.62, "sidelight": 0.27,
		"panes": [0.65, 2.55], "sill": 0.54, "head": 2.12, "upper": "clear",
		"display": "shelves", "interior": "#777458",
	},
	{
		"label": "GODFATHER'S PIZZA", "weight": 1.16, "sign": "#47312b", "ink": "#e5aa5d",
		"door_right": true, "entry": 1.07, "depth": 0.39, "opaque_head": true,
		"panes": [1.12, 1.26, 0.61], "sill": 0.49, "head": 2.16, "upper": "header",
		"display": "counter", "interior": "#836b52",
	},
	{
		"label": "PLAZA CONFECTIONERY", "weight": 0.97, "sign": "#e1dcc7", "ink": "#4a5f57",
		"door_right": false, "entry": 0.99, "depth": 0.29, "opaque_head": true,
		"panes": [0.67, 1.46, 1.22], "sill": 0.51, "head": 2.13, "upper": "boarded",
		"display": "boarded", "interior": "#9b7b61",
	},
]

var panes: SurfaceTool
var signboards: SurfaceTool
var landings: SurfaceTool
var walls: SurfaceTool
var frames: SurfaceTool
var town: Node3D
var barriers: StaticBody3D
var ground_height: Callable
var panel: Callable
var sign: Callable

var origin: Vector3
var axis: Basis
var wall_height: float
var wall_bottom: Vector2
var brick: Color


func setup(parent: Node3D, masonry: SurfaceTool, trim: SurfaceTool, ground: Callable,
		draw_panel: Callable, draw_sign: Callable) -> void:
	town = parent
	walls = masonry
	frames = trim
	ground_height = ground
	panel = draw_panel
	sign = draw_sign
	barriers = null
	panes = SurfaceTool.new()
	signboards = SurfaceTool.new()
	landings = SurfaceTool.new()
	for surface in [panes, signboards, landings]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)


static func bay_edges(width: float) -> PackedFloat32Array:
	var total := 0.0
	for shop: Dictionary in SHOPS:
		total += shop.weight
	var edges := PackedFloat32Array([0.0])
	for shop: Dictionary in SHOPS:
		edges.append(edges[-1] + width * float(shop.weight) / total)
	return edges


static func fascia_sections(kind: String, width: float) -> Array[Vector3]:
	if kind == "lcbo":
		return [Vector3(0.0, width, 0.0)]
	var edges := bay_edges(width)
	return [
		Vector3(0.0, edges[2], 0.0),
		Vector3(edges[2], edges[4], -0.11),
		Vector3(edges[4], width, -0.035),
	]


func build_front(kind: String, at: Vector3, basis: Basis, width: float, height: float,
		wall_color: Color, bottom_a: float, bottom_b: float) -> void:
	begin_facade(at, basis, height, wall_color, bottom_a, bottom_b)
	if kind == "lcbo":
		build_lcbo(width)
		return

	var edges := bay_edges(width)
	var previous := 0.0
	for i in SHOPS.size():
		var shop: Dictionary = SHOPS[i]
		var left := edges[i] + (0.10 if i == 0 else 0.24)
		var right := edges[i + 1] - (0.47 if i == SHOPS.size() - 1 else 0.24)
		wall_strip(previous, left, width)
		build_shop(shop, left, right, i)
		previous = right
	wall_strip(previous, width, width)


func begin_facade(at: Vector3, basis: Basis, height: float, wall_color: Color,
		bottom_a: float, bottom_b: float) -> void:
	origin = at
	axis = basis
	brick = wall_color
	wall_height = height
	wall_bottom = Vector2(bottom_a - origin.y, bottom_b - origin.y)


func build_lcbo(width: float) -> void:
	var display_left := width * 0.25
	var display_right := width * 0.61
	var entry_left := width * 0.675
	var entry_right := width - 0.33
	var grade := sidewalk((display_left + entry_right) * 0.5)
	var head := frontage_head(grade)
	wall_strip(0.0, display_left, width)
	display_window(display_left, display_right, {
		"panes": [1.0, 1.0, 1.0], "sill": 0.51, "head": 2.19, "upper": "clear",
		"display": "shelves", "interior": "#746b55",
	}, 0.14, grade, head)
	wall_strip(display_right, entry_left, width)
	entryway(entry_left, entry_right, 0.80, {"double": true, "sidelight": 0.65}, head)
	wall_strip(entry_right, width, width)
	fascia_sign(display_left - 0.38, entry_right + 0.08, 2.91, 0.45,
		"LCBO   WINE  SPIRITS  BEER", Color("#515933"), IVORY)


func build_shop(shop: Dictionary, left: float, right: float, index: int) -> void:
	var entry_width: float = shop.entry
	var frame_gap := 0.091
	var door_right: bool = shop.door_right
	var entry_left := right - entry_width if door_right else left
	var entry_right := entry_left + entry_width
	var display_left := left if door_right else entry_right + frame_gap
	var display_right := entry_left - frame_gap if door_right else right
	var bay_grade := sidewalk((left + right) * 0.5)
	var head := frontage_head(bay_grade)
	entryway(entry_left, entry_right, shop.depth, shop, head)
	display_window(display_left, display_right, shop, 0.18 if index in [0, 2] else 0.13, bay_grade, head)
	var joint := entry_left - frame_gap if door_right else entry_right
	var grade := sidewalk(joint)
	paint(frames, face_at(joint, grade - 0.10, -0.024), frame_gap, head - grade + 0.10, Color("#8f9085"))
	masonry(face_at(joint, head), face_at(joint + frame_gap, head), face_at(joint + frame_gap, wall_height),
		face_at(joint, wall_height), axis.z, brick)
	fascia_sign(left + 0.16, right - 0.16, 2.91, 0.39 if index in [2, 3] else 0.45,
		shop.label, Color(shop.sign), Color(shop.ink))


func frontage_head(grade: float) -> float:
	return minf(OPENING_TOP, grade + 2.78)


func wall_strip(left: float, right: float, width: float) -> void:
	var left_y := lerpf(wall_bottom.x, wall_bottom.y, left / width)
	var right_y := lerpf(wall_bottom.x, wall_bottom.y, right / width)
	masonry(face_at(left, left_y), face_at(right, right_y), face_at(right, wall_height),
		face_at(left, wall_height), axis.z, brick)


func fascia_sign(left: float, right: float, y: float, height: float, caption: String,
		background: Color, ink: Color) -> void:
	sign.call(face_at(left, y, 1.528), axis, right - left, height, caption, background, ink, true)


func entryway(left: float, right: float, depth: float, shop: Dictionary, top: float) -> void:
	var outer_left := sidewalk(left, 0.014)
	var outer_right := sidewalk(right, 0.014)
	var inner_grade := maxf(sidewalk(left, -depth), sidewalk(right, -depth))
	var floor_y := maxf((outer_left + outer_right) * 0.5, inner_grade) + 0.034
	var lip := maxf(outer_left, outer_right) + 0.008
	var jamb_color := brick.darkened(0.13)
	masonry(face_at(left, outer_left - 0.09), face_at(left, floor_y - 0.09, -depth),
		face_at(left, top, -depth), face_at(left, top), axis.x, jamb_color)
	masonry(face_at(right, floor_y - 0.09, -depth), face_at(right, outer_right - 0.09),
		face_at(right, top), face_at(right, top, -depth), -axis.x, jamb_color)
	lintel(left, right, top, depth)
	quad(landings, face_at(left, outer_left + 0.006, 0.014), face_at(right, outer_right + 0.006, 0.014),
		face_at(right, floor_y, -depth), face_at(left, floor_y, -depth), Vector3.UP, CONCRETE.darkened(0.13))
	paint(landings, face_at(left, lip - 0.025, 0.017), right - left, 0.04, CONCRETE)
	threshold(left, right, floor_y, depth)
	var across := right - left
	var door_top := floor_y + float(shop.get("door_height", 2.05))
	var frame_y := top - floor_y
	var trim := Color(shop.get("frame", ALUMINUM))
	var double_door: bool = shop.get("double", false)
	var sidelight: float = shop.get("sidelight", 0.0)
	var left_light: float = shop.get("left_sidelight", sidelight if double_door or shop.get("door_right", false) else 0.0)
	var right_light: float = shop.get("right_sidelight",
		0.32 if double_door and sidelight > 0.0 else (sidelight if left_light == 0.0 else 0.0))
	var mullions: Array = []
	var first_leaf := int(left_light > 0.0)
	if left_light > 0.0:
		mullions.append(left_light)
	if double_door:
		mullions.append((left_light + across - right_light) * 0.5)
	if right_light > 0.0:
		mullions.append(across - right_light)
	bars(left, right, floor_y, frame_y, depth, mullions, 0.064, trim)
	var door_parts := partitions(left, right, mullions)
	var transom_tint := Color("#6f7368")
	if shop.get("opaque_head", false):
		transom_tint = Color("#c5b9a3") if shop.get("door_right", true) else Color("#783f3a")
	for i in door_parts.size() - 1:
		var a := door_parts[i]
		var b := door_parts[i + 1]
		var midrail := floor_y + (0.93 if double_door else 1.02)
		var slab := 0.16 if double_door else 0.115
		var is_leaf := i == first_leaf or (double_door and i == first_leaf + 1)
		if not is_leaf:
			slab = 0.085
		var lower := Color("#515b55")
		var glazed_lower := is_leaf or not shop.has("lower_infill")
		if not glazed_lower:
			lower = Color(shop.lower_infill)
		infill(a, b, floor_y + slab, midrail - 0.035, depth, lower, glazed_lower)
		infill(a, b, midrail + 0.035, door_top - 0.04, depth, Color("#686f63"), true)
		infill(a, b, door_top + 0.036, top - 0.034, depth, transom_tint, not shop.get("opaque_head", false))
		rail(a, b, floor_y + slab * 0.5, depth, slab, trim)
		rail(a, b, midrail, depth, 0.078 if double_door else 0.052, trim)
		if is_leaf:
			var handle_x := b - 0.15 if not double_door or i == first_leaf else a + 0.15
			rail(handle_x - 0.094, handle_x + 0.094, midrail + 0.09, depth - 0.053, 0.033, DARK)
			rail(handle_x - 0.082, handle_x + 0.082, midrail + 0.097, depth - 0.065, 0.024, ALUMINUM)
	rail(left, right, door_top, depth, 0.080, trim)
	barrier(left, right, floor_y, top, depth + 0.065)
	var rear := -depth - 0.46
	paint(frames, face_at(left, floor_y - 0.02, rear), across, frame_y + 0.045, Color("#393b34"))
	quad(frames, face_at(left, floor_y, -depth), face_at(right, floor_y, -depth),
		face_at(right, floor_y, rear), face_at(left, floor_y, rear), Vector3.UP, DARK)
	quad(frames, face_at(left, floor_y, -depth), face_at(left, floor_y, rear),
		face_at(left, top, rear), face_at(left, top, -depth), axis.x, DARK)
	quad(frames, face_at(right, floor_y, rear), face_at(right, floor_y, -depth),
		face_at(right, top, -depth), face_at(right, top, rear), -axis.x, DARK)
	quad(frames, face_at(right, top, -depth), face_at(left, top, -depth),
		face_at(left, top, rear), face_at(right, top, rear), Vector3.DOWN, DARK)


func display_window(left: float, right: float, shop: Dictionary, depth: float,
		grade: float, top: float) -> void:
	var sill: float = grade + shop.sill
	var upper: String = shop.upper
	var trim := Color(shop.get("frame", ALUMINUM))
	var divider: float = top if upper == "none" else minf(grade + float(shop.head), top - 0.33)
	var base := minf(sidewalk(left), sidewalk(right)) - 0.22
	masonry(face_at(left, base), face_at(right, base), face_at(right, sill), face_at(left, sill), axis.z, brick)
	masonry(face_at(left, sill), face_at(left, sill, -depth), face_at(left, top, -depth),
		face_at(left, top), axis.x, brick.darkened(0.15))
	masonry(face_at(right, sill, -depth), face_at(right, sill), face_at(right, top),
		face_at(right, top, -depth), -axis.x, brick.darkened(0.15))
	lintel(left, right, top, depth)
	quad(frames, face_at(left, sill, 0.026), face_at(right, sill, 0.026),
		face_at(right, sill, -depth), face_at(left, sill, -depth), Vector3.UP, IVORY)
	paint(frames, face_at(left, sill - 0.045, 0.027), right - left, 0.045, ALUMINUM)
	var widths: Array = shop.panes
	var total := 0.0
	for weight: float in widths:
		total += weight
	var mullions: Array = []
	var offset := 0.0
	for i in widths.size() - 1:
		offset += (right - left) * float(widths[i]) / total
		mullions.append(offset)
	bars(left, right, sill, top - sill, depth, mullions, 0.051, trim)
	rail(left, right, sill + 0.016, depth, 0.055, trim)
	if upper != "none":
		rail(left, right, divider, depth, 0.062, trim)
	var span := partitions(left, right, mullions)
	var style: String = shop.display
	for i in span.size() - 1:
		var a := span[i]
		var b := span[i + 1]
		var display_tint := Color("#78847b").darkened(0.055 * (i % 3))
		infill(a, b, sill + 0.044, divider - 0.035, depth, display_tint, true)
		if upper == "clear":
			infill(a, b, divider + 0.035, top - 0.034, depth, Color("#626c62"), true)
		elif upper in ["infill", "boarded"]:
			var tint := Color("#baa890") if upper == "boarded" else Color("#d1c5b0")
			infill(a, b, divider + 0.035, top - 0.034, depth, tint.darkened(0.09 * (i % 3)), false)
	if upper == "header":
		# Opaque transom panel continues the storefront even when the tenant sign is hidden.
		paint(frames, face_at(left + 0.032, divider + 0.035, -depth + 0.012),
			right - left - 0.064, top - divider - 0.069, Color(shop.sign).darkened(0.15))
		sign.call(face_at(left + 0.12, divider + 0.11, -depth + 0.028), axis,
			right - left - 0.24, top - divider - 0.23, shop.label, Color(shop.sign), Color(shop.ink), true)
	build_display(left, right, sill, divider, top, depth, style, Color(shop.interior))
	barrier(left, right, sill, top, depth + 0.041)


func lintel(left: float, right: float, y: float, depth: float) -> void:
	masonry(face_at(left, y), face_at(right, y), face_at(right, wall_height),
		face_at(left, wall_height), axis.z, brick)
	quad(frames, face_at(right, y), face_at(left, y), face_at(left, y, -depth),
		face_at(right, y, -depth), Vector3.DOWN, IVORY.darkened(0.14))


func build_display(left: float, right: float, sill: float, mullion_y: float, top: float,
		depth: float, style: String, backing: Color) -> void:
	var width := right - left
	var has_blinds := style in ["frosted", "blinds", "boarded"]
	var show_depth := 0.09 if has_blinds else 0.47
	var rear := -depth - show_depth
	paint(frames, face_at(left - 0.012, sill, rear), width + 0.024, top - sill, backing.darkened(0.32))
	quad(frames, face_at(left, sill, -depth), face_at(right, sill, -depth),
		face_at(right, sill, rear), face_at(left, sill, rear), Vector3.UP, DARK)
	quad(frames, face_at(left, sill, -depth), face_at(left, sill, rear),
		face_at(left, top, rear), face_at(left, top, -depth), axis.x, DARK)
	quad(frames, face_at(right, sill, rear), face_at(right, sill, -depth),
		face_at(right, top, -depth), face_at(right, top, rear), -axis.x, DARK)
	quad(frames, face_at(right, top, -depth), face_at(left, top, -depth),
		face_at(left, top, rear), face_at(right, top, rear), Vector3.DOWN, DARK)
	if has_blinds:
		var inset := width / 3.0
		for i in 3:
			var color := backing.darkened(0.13 - 0.044 * i)
			paint(frames, face_at(left + i * inset + 0.026, sill + 0.032, rear + 0.011),
				inset - 0.052, mullion_y - sill - 0.056, color)
		if style == "frosted":
			paint(frames, face_at(left + width * 0.30, sill + 0.25, rear + 0.022), width * 0.40, 0.82, Color("#8f746c"))
	elif style == "shelves":
		for shelf: int in 3:
			var y := sill + 0.18 + 0.41 * shelf
			paint(frames, face_at(left + 0.11, y, rear + 0.15), width - 0.22, 0.065, backing.lightened(0.12))
			var items := clampi(roundi(width * 2.5), 2, 11)
			for i in items:
				var x := left + 0.15 + float(i) * (width - 0.35) / items
				var tint := STOCK_TINTS[(i + shelf * 2) % STOCK_TINTS.size()]
				paint(frames, face_at(x, y + 0.063, rear + 0.13), 0.11 + 0.024 * (i % 3),
					0.12 + 0.043 * ((i + shelf) % 3), tint)
	elif style in ["counter", "plinth"]:
		var counter_height := 0.65 if style == "counter" else 0.40
		var front := rear + 0.23
		paint(frames, face_at(left + 0.12, sill, front), width - 0.24, counter_height, backing)
		var counter_top := sill + counter_height
		quad(frames, face_at(left + 0.12, counter_top, front), face_at(right - 0.12, counter_top, front),
			face_at(right - 0.12, counter_top, rear), face_at(left + 0.12, counter_top, rear), Vector3.UP, IVORY.darkened(0.24))


func bars(left: float, right: float, bottom: float, height: float, depth: float,
		mullions: Array, width: float, trim: Color) -> void:
	for x: float in partitions(left, right, mullions):
		var center := face_at(clampf(x, left + width * 0.5, right - width * 0.5),
			bottom + height * 0.5, -depth + 0.017)
		box(center, Vector3(width, height, 0.058), trim)
	rail(left, right, bottom + height - 0.03, depth, 0.062, trim)


func rail(left: float, right: float, y: float, depth: float, height: float, color: Color) -> void:
	box(face_at((left + right) * 0.5, y, -depth + 0.018), Vector3(right - left, height, 0.055), color)


func threshold(left: float, right: float, floor_y: float, depth: float) -> void:
	box(face_at((left + right) * 0.5, floor_y + 0.009, -depth + 0.027),
		Vector3(right - left, 0.021, 0.14), ALUMINUM)


func partitions(left: float, right: float, offsets: Array) -> PackedFloat32Array:
	var positions := PackedFloat32Array([left])
	for x: float in offsets:
		positions.append(left + x)
	positions.append(right)
	return positions


func infill(left: float, right: float, y: float, top: float, depth: float,
		tint: Color, transparent: bool) -> void:
	var surface := panes if transparent else frames
	if transparent:
		tint.a = 0.29
	paint(surface, face_at(left + 0.024, y, -depth + 0.003), right - left - 0.048, top - y, tint)


func sign_board(at: Vector3, basis: Basis, width: float, height: float, background: Color) -> void:
	panel.call(signboards, at, basis.x, basis.z, width, height, IVORY)
	panel.call(signboards, at + basis.x * 0.025 + Vector3.UP * 0.025 + basis.z * 0.008,
		basis.x, basis.z, width - 0.05, height - 0.05, background)


func barrier(left: float, right: float, bottom: float, top: float, depth: float) -> void:
	if barriers == null:
		barriers = StaticBody3D.new()
		barriers.name = "ChamplainStorefrontGlazing"
		town.add_child(barriers)
	var at := face_at((left + right) * 0.5, (bottom + top) * 0.5, -depth)
	Kit.collider(barriers, at, Vector3(right - left, top - bottom, 0.055))
	var collider := barriers.get_child(-1) as CollisionShape3D
	collider.basis = axis


func sidewalk(x: float, depth := 0.0) -> float:
	var at := face_at(x, 0.0, depth)
	return float(ground_height.call(at.x, at.z)) - origin.y


func face_at(x: float, y: float, z := 0.0) -> Vector3:
	return origin + axis.x * x + Vector3.UP * y + axis.z * z


func paint(surface: SurfaceTool, at: Vector3, width: float, height: float, color: Color) -> void:
	panel.call(surface, at, axis.x, axis.z, width, height, color)


func box(center: Vector3, size: Vector3, color: Color) -> void:
	var a := axis.x * size.x * 0.5
	var b := axis.y * size.y * 0.5
	var c := axis.z * size.z * 0.5
	box_face(center + c, a, b, axis.z, color)
	box_face(center + a, -c, b, axis.x, color)
	box_face(center - a, c, b, -axis.x, color)
	box_face(center + b, a, -c, axis.y, color)
	box_face(center - b, a, c, -axis.y, color)


func box_face(center: Vector3, across: Vector3, up: Vector3, normal: Vector3, color: Color) -> void:
	quad(frames, center - across - up, center + across - up, center + across + up,
		center - across + up, normal, color)


func masonry(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var u := (b - a).slide(Vector3.UP).normalized()
	var offset := origin.dot(u)
	walls.set_normal(normal)
	walls.set_color(color)
	for point: Vector3 in [a, d, b, d, c, b]:
		var datum := origin.y - 0.35
		if color.a > 0.25 and color.a < 0.4:
			datum = ground_height.call(point.x, point.z)
		walls.set_uv(Vector2(point.dot(u) - offset, point.y - datum))
		walls.add_vertex(point)


func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, color: Color) -> void:
	surface.set_normal(normal)
	surface.set_color(color)
	surface.set_uv(Vector2.ZERO)
	var winding := [a, b, c, a, c, d] if (c - a).cross(b - a).dot(normal) > 0.0 else [a, c, b, a, d, c]
	for point: Vector3 in winding:
		surface.add_vertex(point)
