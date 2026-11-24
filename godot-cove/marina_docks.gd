extends RefCounted

const Kit = preload("res://scenery.gd")
const Cleat = preload("res://mooring_cleat.gd")
const DECK := .55
const SPINE_WIDTH := 2.45
const FINGER_WIDTH := 1.20

var root: Node3D
var ground: Callable
var timber: Material
var frame := Kit.paint(Color("#675446"), .87)
var float_shell := Kit.paint(Color("#303b3d"), .88)
var alloy := Kit.paint(Color("#9caeab"), .54, .32)
var boards: Array[Transform3D] = []
var floats: Array[Transform3D] = []
var bumpers: Array[Transform3D] = []
var cleats: Array[Transform3D] = []
var ladders: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var bounds := Rect2()


func build(parent: Node3D, layout: Dictionary, ground_at: Callable, wood: Material) -> Array[Dictionary]:
	root = Node3D.new()
	root.name = "FloatingDocks"
	parent.add_child(root)
	ground = ground_at
	timber = wood
	var berths: Array[Dictionary] = []
	var hut := point([18042.73, 12665.85])
	var hut_bank := point([18036.6, 12656.2])
	gangway("HutGangway", bank(hut_bank), hut, 1.87)
	var inner: Array = layout.dock_main[0]
	build_row("HutSlips", point(inner[0]), hut, 6, 5.7, [1.0], berths)
	var visitor := point([18073.15, 12659.75])
	build_row("VisitorDock", hut, visitor, 3, 4.35, [1.0], berths)

	var basin_entry := point(layout.dock_access[1][0])
	gangway("BasinGangway", bank(point([17984.7, 12712.0])), basin_entry, SPINE_WIDTH)
	var previous := basin_entry
	for index in range(1, layout.dock_main.size()):
		var run: Array = layout.dock_main[index]
		var a := point(run[0])
		var b := point(run[1])
		span("BasinBoardwalk", previous, a, SPINE_WIDTH, true)
		build_row("BasinDock%d" % index, a, b, [10, 9, 6][index - 1],
			6.25 if index == 3 else 8.1, [-1.0, 1.0], berths)
		previous = a
	return berths


static func point(pair: Array) -> Vector3:
	return Vector3(pair[0], DECK, pair[1])


func bank(at: Vector3) -> Vector3:
	return Vector3(at.x, float(ground.call(at.x, at.z)) + .04, at.z)


func build_row(title: String, a: Vector3, b: Vector3, count: int, reach: float, sides: Array,
		berths: Array[Dictionary]) -> void:
	span(title, a - (b - a).normalized() * .58, b + (b - a).normalized() * .58, SPINE_WIDTH, true)
	var forward := (b - a).normalized()
	var lateral := forward.cross(Vector3.UP)
	for side: float in sides:
		var outward := lateral * side
		for index in count:
			var joint := a.lerp(b, float(index) / (count - 1))
			var tip := joint + outward * reach
			span("SlipFinger", joint + outward * (SPINE_WIDTH * .5 - .045), tip, FINGER_WIDTH, true)
			# The cleat model's long axis is X, parallel to the finger edge.
			var basis := Basis(outward, Vector3.UP, outward.cross(Vector3.UP))
			for edge: float in [-1.0, 1.0]:
				var inset := forward * edge * (FINGER_WIDTH * .5 - .17)
				cleats.append(Transform3D(basis.scaled_local(Vector3.ONE * .65), tip - outward * .40 + inset))
				cleats.append(Transform3D(basis.scaled_local(Vector3.ONE * .55), joint + outward * 1.66 + inset))
			if index < count - 1:
				var next := a.lerp(b, float(index + 1) / (count - 1))
				berths.append({"row": title, "slot": index, "side": side, "edge": (joint + next) * .5,
					"outward": outward, "along": forward, "width": joint.distance_to(next) - FINGER_WIDTH})
	ladder(b - forward * 1.15, forward, SPINE_WIDTH, 1.0)


func gangway(title: String, a: Vector3, b: Vector3, width: float) -> void:
	var bridge := span(title, a, b, width, false)
	var length := a.distance_to(b)
	for side: float in [-1.0, 1.0]:
		var x := side * (width * .5 - .055)
		Kit.box_at(bridge, Vector3(x, .79, 0), Vector3(.055, .055, length), alloy)
		for t: float in [-.45, -.16, .16, .45]:
			Kit.box_at(bridge, Vector3(x, .39, t * length), Vector3(.060, .80, .060), alloy)


func span(title: String, a: Vector3, b: Vector3, width: float, floating: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	root.add_child(body, true)
	body.position = (a + b) * .5
	body.basis = Basis.looking_at(b - a)
	body.collision_mask = 0
	var length := a.distance_to(b)
	var thickness := .37 if floating else .15
	Kit.collider(body, Vector3.DOWN * thickness * .5, Vector3(width, thickness, length))
	Kit.box_at(body, Vector3.DOWN * .122, Vector3(width, .146, length), frame)
	var plank_count := maxi(1, roundi(length / .205))
	var step := length / plank_count
	for i in plank_count:
		add_box(boards, body, Vector3(0, -.025, (i + .5) * step - length * .5),
			Vector3(width, .05, step - .009))
	if floating:
		var bay_count := maxi(1, ceili(length / 3.6))
		var bay := length / bay_count
		for i in bay_count:
			add_box(floats, body, Vector3(0, -.42, (i + .5) * bay - length * .5),
				Vector3(width * .83, .53, bay * .87))
		for side: float in [-1.0, 1.0]:
			add_box(bumpers, body, Vector3(side * width * .5, -.17, 0),
				Vector3(.12, .16, length))
		add_obstacle(a, b, width + .12)
	else:
		add_obstacle(a, b, width)
	return body


func ladder(at: Vector3, forward: Vector3, width: float, side: float) -> void:
	var outward := forward.cross(Vector3.UP) * side
	var edge := at + outward * (width * .5 + .07)
	ladders.append({"edge": edge, "outward": outward, "top": edge - outward * .72 + Vector3.UP * .10})
	for offset: float in [-.23, .23]:
		var foot := edge + forward * offset
		Kit.beam(root, foot - Vector3.UP * 1.23, foot + Vector3.UP * .47, .045, alloy)
		Kit.beam(root, foot + Vector3.UP * .47, foot - outward * .21 + Vector3.UP * .39, .045, alloy)
	for step in 5:
		var rung := edge - Vector3.UP * (.09 + step * .25)
		Kit.beam(root, rung - forward * .23, rung + forward * .23, .035, alloy)


func aimed_ladder(feet: Vector3, eye: Camera3D) -> Dictionary:
	if not bounds.grow(3.0).has_point(Vector2(feet.x, feet.z)):
		return {}
	for entry in ladders:
		var edge: Vector3 = entry.edge
		var outward: Vector3 = entry.outward
		var look := edge + Vector3.UP * .12 - eye.global_position
		if feet.y < edge.y and (feet - edge).dot(outward) > -.12 \
				and feet.distance_squared_to(edge) < 2.35 * 2.35 and look.normalized().dot(-eye.global_basis.z) > .72:
			return entry
	return {}


func finish() -> void:
	var kit := Kit.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	kit.scatter(root, box, boards, timber).name = "TimberDecking"
	kit.scatter(root, box, floats, float_shell).name = "FlotationBlocks"
	kit.scatter(root, box, bumpers, float_shell).name = "RubberBumpers"
	Cleat.place(root, cleats).name = "DockCleats"


static func add_box(batch: Array[Transform3D], body: Node3D, at: Vector3, size: Vector3) -> void:
	batch.append(Transform3D(body.basis.scaled_local(size), body.position + body.basis * at))


func add_obstacle(a: Vector3, b: Vector3, width: float) -> void:
	var axis := Vector2(b.x - a.x, b.z - a.z).normalized()
	var side := Vector2(-axis.y, axis.x) * width * .5
	var start := Vector2(a.x, a.z)
	var end := Vector2(b.x, b.z)
	add_polygon(PackedVector2Array([start - side, end - side, end + side, start + side]))


func add_polygon(polygon: PackedVector2Array) -> void:
	var area := polygon_bounds(polygon)
	bounds = area if obstacles.is_empty() else bounds.merge(area)
	obstacles.append({"area": area, "polygon": polygon})


func blocks(point_at: Vector3) -> bool:
	var p := Vector2(point_at.x, point_at.z)
	if not bounds.has_point(p):
		return false
	for obstacle: Dictionary in obstacles:
		if obstacle.area.has_point(p) and Geometry2D.is_point_in_polygon(p, obstacle.polygon):
			return true
	return false


func overlaps(hull: PackedVector2Array) -> bool:
	var area := polygon_bounds(hull)
	if not bounds.intersects(area):
		return false
	for obstacle: Dictionary in obstacles:
		if area.intersects(obstacle.area) and not Geometry2D.intersect_polygons(hull, obstacle.polygon).is_empty():
			return true
	return false


static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var area := Rect2(polygon[0], Vector2.ZERO)
	for i in range(1, polygon.size()):
		area = area.expand(polygon[i])
	return area
