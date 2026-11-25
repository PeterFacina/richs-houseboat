extends RefCounted

const Kit = preload("res://scenery.gd")
const CONTROLS = preload("res://deep_river/municipal_traffic_controls.json")
const SCHOOL_SIGN = preload("res://deep_river/school_crossing_wc2.svg")
const STOP_SIGN = preload("res://deep_river/stop_ra1.svg")
const SIGN_FONT = preload("res://deep_river/BarlowCondensed-SemiBold.ttf")
# May 2025 imagery places these crosswalks across Laurier and the east leg of Deep River Rd.
const LAURIER_CROSSING := Vector4(17653.77, 12928.52, -.0906, .9959)
const DEEP_RIVER_CROSSING := Vector4(18143.57, 13325.72, .9996, -.0295)
const SIGN_SPAN := .49
const FACE_HEIGHT := 2.12
const DRAW_RANGE := 165.0

var post: BoxMesh
var octagon: ArrayMesh
var triangle: ArrayMesh
var steel: StandardMaterial3D
var white: StandardMaterial3D
var red: StandardMaterial3D
var fluorescent: StandardMaterial3D
var ink: StandardMaterial3D
var school: StandardMaterial3D
var stop: StandardMaterial3D
var occupied: Array[Vector2]


func build(parent: Node3D, map: Node3D) -> void:
	var signs := Node3D.new()
	signs.name = "MunicipalTrafficControls"
	parent.add_child(signs)
	steel = Kit.paint(Color("#8c969a"), .68, .3)
	white = Kit.paint(Color("#efece4"), .76)
	red = Kit.paint(Color("#b62527"), .64)
	fluorescent = Kit.paint(Color("#e8df46"), .75)
	ink = Kit.paint(Color("#20211b"), .82)
	school = Kit.paint(Color.WHITE, .8)
	school.albedo_texture = SCHOOL_SIGN
	school.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	stop = Kit.paint(Color.WHITE, .8)
	stop.albedo_texture = STOP_SIGN
	stop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	post = BoxMesh.new()
	post.size = Vector3(.06, 2.46, .06)
	octagon = polygon_face(8, PI / 8.0, .39)
	triangle = polygon_face(3, PI, .47)
	for node: Node3D in map.get_tree().get_nodes_in_group(&"deep_river_street_names"):
		var at := node.global_position
		occupied.append(Vector2(at.x, at.z))
	for row: Array in CONTROLS.data:
		var anchor := Vector2(row[3][0], row[3][1])
		var outward := Vector2(row[4][0], row[4][1]).normalized()
		var board := place_post(signs, map, anchor, outward, row[0], row[1], row[2])
		if board != null:
			add_regulatory_face(board, row[0])
	add_crossing(signs, map, LAURIER_CROSSING, "school", "Laurier Ave", "Brockhouse Way")
	add_crossing(signs, map, DEEP_RIVER_CROSSING, "crossover", "Deep River Rd", "Hillcrest Ave")


func add_crossing(parent: Node3D, map: Node3D, crossing: Vector4, kind: String,
		street: String, junction: String) -> void:
	var center := Vector2(crossing.x, crossing.y)
	var axis := Vector2(crossing.z, crossing.w).normalized()
	for outward: Vector2 in [axis, -axis]:
		var board := place_post(parent, map, center + outward * 1.24, outward, kind, street, junction)
		if board == null:
			continue
		if kind == "school":
			var panel := QuadMesh.new()
			panel.size = Vector2(.58, .87)
			panel_at(board, Vector3(0.0, FACE_HEIGHT, .058), Vector3(.60, .89, .040), steel)
			set_range(Kit.mesh_at(board, panel, Vector3(0.0, FACE_HEIGHT, .080), school))
		else:
			panel_at(board, Vector3(0.0, FACE_HEIGHT, .067), Vector3(.60, .79, .044), ink)
			panel_at(board, Vector3(0.0, FACE_HEIGHT, .083), Vector3(.558, .744, .035), fluorescent)
			for angle: float in [-PI / 4.0, PI / 4.0]:
				var bar := panel_at(board, Vector3(0.0, FACE_HEIGHT, .108), Vector3(.065, .46, .016), ink)
				bar.rotation.z = angle
			label_at(board, "PEDESTRIAN", Vector3(0.0, FACE_HEIGHT + .285, .12), .00127, Color("#20211b"))
			label_at(board, "CROSSOVER", Vector3(0.0, FACE_HEIGHT - .285, .12), .00127, Color("#20211b"))


func place_post(parent: Node3D, map: Node3D, anchor: Vector2, outward: Vector2,
		kind: String, street: String, junction: String) -> Node3D:
	var right := Vector2(outward.y, -outward.x)
	for offset: float in [0.0, 1.5, 3.0, 5.0]:
		for setback: float in [4.05, 4.65, 5.35, 6.25, 7.1]:
			var at := anchor + right * setback + outward * offset
			if occupied.any(func(point: Vector2) -> bool: return point.distance_squared_to(at) < 1.2):
				continue
			if (not map.roadside_safe(at) or not map.road_at_sign(at, SIGN_SPAN).is_empty()
					or in_building(map.meta.buildings, at)):
				continue
			var board := Node3D.new()
			parent.add_child(board)
			board.global_position = Vector3(at.x, map.ground_height(at.x, at.y), at.y)
			board.rotation.y = atan2(outward.x, outward.y)
			board.set_meta(&"sign_span", SIGN_SPAN)
			board.set_meta(&"kind", kind)
			board.set_meta(&"street", street)
			board.set_meta(&"junction", junction)
			board.add_to_group(&"town_roadside_signs")
			board.add_to_group(&"deep_river_traffic_controls")
			set_range(Kit.mesh_at(board, post, Vector3.UP * 1.23, steel))
			occupied.append(at)
			return board
	return null


static func in_building(buildings: Array, point: Vector2) -> bool:
	for building: Dictionary in buildings:
		var box: Array = building.box
		var footprint := Rect2(box[0], box[1], box[2] - box[0], box[3] - box[1])
		if footprint.grow(.42).has_point(point):
			return true
	return false


func add_regulatory_face(board: Node3D, kind: String) -> void:
	var shape := triangle if kind == "yield" else octagon
	plate(board, shape, .047, 1.015, steel, true)
	if kind == "yield":
		plate(board, shape, .063, 1.0, red)
		plate(board, shape, .067, .80, white)
		label_at(board, "YIELD", Vector3(0.0, FACE_HEIGHT + .06, .083), .0019, Color("#9c2125"))
	else:
		plate(board, shape, .063, 1.0, stop)
		if kind == "all_way":
			panel_at(board, Vector3(0.0, 1.62, .046), Vector3(.41, .16, .033), red)
			panel_at(board, Vector3(0.0, 1.62, .064), Vector3(.384, .134, .010), white)
			label_at(board, "ALL-WAY", Vector3(0.0, 1.62, .071), .0020, Color("#9c2125"))


func plate(board: Node3D, mesh: Mesh, depth: float, size: float,
		material: Material, reversed := false) -> void:
	var face := Kit.mesh_at(board, mesh, Vector3(0.0, FACE_HEIGHT, depth), material)
	face.scale = Vector3(size, size, 1.0)
	if reversed:
		face.rotation.y = PI
	set_range(face)


func panel_at(board: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var panel := Kit.box_at(board, at, size, material)
	set_range(panel)
	return panel


static func label_at(board: Node3D, title: String, at: Vector3, pixels: float, ink_color: Color) -> void:
	var label := Label3D.new()
	board.add_child(label)
	label.position = at
	label.text = title
	label.font = SIGN_FONT
	label.font_size = 48
	label.pixel_size = pixels
	label.outline_size = 0
	label.double_sided = false
	label.modulate = ink_color
	set_range(label)


static func polygon_face(sides: int, phase: float, radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extent := cos(phase) if sides == 8 else 1.0
	for i in sides:
		var a := phase + TAU * i / sides
		var b := phase + TAU * (i + 1) / sides
		for v: Vector3 in [Vector3.ZERO, Vector3(sin(a), cos(a), 0.0), Vector3(sin(b), cos(b), 0.0)]:
			surface.set_normal(Vector3.BACK)
			surface.set_uv(Vector2(.5 + v.x / (2.0 * extent), .5 - v.y / (2.0 * extent)))
			surface.add_vertex(v * radius)
	return surface.commit()


static func set_range(item: GeometryInstance3D) -> void:
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.visibility_range_end = DRAW_RANGE
	item.visibility_range_end_margin = 12.0
