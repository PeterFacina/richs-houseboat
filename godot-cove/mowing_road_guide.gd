extends MeshInstance3D

const Works = preload("res://public_works.gd")
const CELL := 4.5
const STREET_STEP := 2.5
const ROUTE_COLOR := Color("#32e9bd")

var roads := AStar2D.new()
var buckets: Dictionary = {}
var river: Node3D


func setup(map: Node3D) -> void:
	river = map
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.vertex_color_use_as_albedo = true
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = paint
	hide()


func build_road_graph(works: Node3D) -> void:
	for line: Array in river.meta.streets:
		add_road(line)
	add_road(Works.CEDAR_ROAD)
	add_road(Works.YARD_DRIVE)
	var drive_end: Array = Works.YARD_DRIVE[-1]
	for bay: Vector2 in Works.PARKING:
		var stall := flat(works.at_ground(bay))
		var apron := flat(works.at_ground(Vector2(bay.x, 17.0)))
		add_road([[stall.x, stall.y], [apron.x, apron.y], drive_end])


func add_road(line: Array) -> void:
	var previous := -1
	for index in range(1, line.size()):
		var start := Vector2(line[index - 1][0], line[index - 1][1])
		var finish := Vector2(line[index][0], line[index][1])
		var steps := maxi(1, ceili(start.distance_to(finish) / STREET_STEP))
		for step in range(1 if previous >= 0 else 0, steps + 1):
			var point := start.lerp(finish, float(step) / steps)
			var cell := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
			var id := roads.get_available_point_id()
			roads.add_point(id, point)
			for z in range(cell.y - 1, cell.y + 2):
				for x in range(cell.x - 1, cell.x + 2):
					for other: int in buckets.get(Vector2i(x, z), []):
						if point.distance_squared_to(roads.get_point_position(other)) <= CELL * CELL:
							roads.connect_points(other, id)
			if previous >= 0 and not roads.are_points_connected(previous, id):
				roads.connect_points(previous, id)
			if not buckets.has(cell):
				buckets[cell] = []
			buckets[cell].append(id)
			previous = id


func flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func route(from: Vector3, to: Vector3, works: Node3D) -> PackedVector2Array:
	var start := flat(from)
	var finish := flat(to)
	if start.distance_to(finish) < 28.0 and start.distance_to(Vector2(18000, 12645)) < 65.0:
		return PackedVector2Array([start, finish])
	if roads.get_point_count() == 0:
		build_road_graph(works)
	var path := roads.get_point_path(roads.get_closest_point(start), roads.get_closest_point(finish))
	if path.is_empty():
		return path
	var result := PackedVector2Array([start])
	result.append_array(path)
	result.append(finish)
	return result


func draw_route(points: PackedVector2Array) -> void:
	if points.size() < 2:
		hide()
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance := 0.0
	var next_arrow := 2.0
	for index in range(1, points.size()):
		var start := points[index - 1]
		var finish := points[index]
		var length := start.distance_to(finish)
		if length < .02:
			continue
		var axis := (finish - start) / length
		var side := axis.orthogonal()
		var steps := ceili(length / 1.5)
		for step in steps:
			var a := start.lerp(finish, float(step) / steps)
			var b := start.lerp(finish, float(step + 1) / steps)
			polygon(surface, [a - side * .20, a + side * .20, b + side * .20,
				a - side * .20, b + side * .20, b - side * .20], Color(ROUTE_COLOR, .68), .17)
		while next_arrow <= distance + length:
			var tip := start + axis * (next_arrow - distance)
			var mid := tip - axis * .72
			polygon(surface, [tip, mid + side * .62, mid - side * .62], ROUTE_COLOR, .19)
			next_arrow += 5.0
		distance += length
	mesh = surface.commit()
	visible = mesh != null


func polygon(surface: SurfaceTool, points: Array, color: Color, lift: float) -> void:
	for point: Vector2 in points:
		surface.set_color(color)
		surface.add_vertex(Vector3(point.x, river.ground_height(point.x, point.y) + lift, point.y))
