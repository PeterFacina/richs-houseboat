extends MeshInstance3D

const Works = preload("res://public_works.gd")
const CELL := 4.5
const STREET_STEP := 2.5
const PAINT = preload("res://mowing_chevrons.gdshader")
const CHEVRON_SPACING := 5.5
const RIGHT_LANE_OFFSET := 1.7
const OFF_ROUTE_DISTANCE := 7.0

var roads := AStar2D.new()
var buckets: Dictionary = {}
var river: Node3D
var paint := ShaderMaterial.new()
var points := PackedVector2Array()
var distances := PackedFloat32Array()
var destination := Vector3.INF
var last_search_origin := Vector2.INF
var segment := 1
var progress := 0.0
var chevron_profile := PackedVector2Array()


func setup(map: Node3D) -> void:
	river = map
	chevron_profile = rounded_chevron()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint.shader = PAINT
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


func reset() -> void:
	hide()
	destination = Vector3.INF


func navigate(origin: Vector3, target: Vector3, works: Node3D) -> void:
	var position_on_map := flat(origin)
	var changed := destination.distance_squared_to(target) >= 4.0
	var moved := last_search_origin.distance_squared_to(position_on_map) >= 16.0
	if not changed and (not moved or track(position_on_map) <= OFF_ROUTE_DISTANCE * OFF_ROUTE_DISTANCE):
		return
	destination = target
	last_search_origin = position_on_map
	draw_route(route(origin, target, works))
	update_paint(origin)


func track(origin: Vector2) -> float:
	var nearest := INF
	var best_segment := segment
	for index in range(maxi(1, segment - 8), mini(points.size(), segment + 17)):
		var start := points[index - 1]
		var finish := points[index]
		if start == finish:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(origin, start, finish)
		var distance := closest.distance_squared_to(origin)
		if distance < nearest:
			nearest = distance
			best_segment = index
			progress = distances[index - 1] + start.distance_to(closest)
	segment = best_segment
	return nearest


func update_paint(origin: Vector3) -> void:
	if visible:
		track(flat(origin))
		paint.set_shader_parameter("progress", progress)


func draw_route(path: PackedVector2Array) -> void:
	points = path
	distances.resize(path.size())
	if not distances.is_empty():
		distances[0] = 0.0
	segment = 1
	progress = 0.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance := 0.0
	var next_arrow := 3.0
	var has_arrows := false
	for index in range(1, path.size()):
		var start := path[index - 1]
		var finish := path[index]
		var length := start.distance_to(finish)
		distances[index] = distance + length
		if length > .001:
			var axis := (finish - start) / length
			var lane_offset := Vector2.ZERO
			# Only graph segments represent road centerlines, including on the return trip.
			if index > 1 and index < path.size() - 1:
				lane_offset = Vector2(-axis.y, axis.x) * RIGHT_LANE_OFFSET
			while next_arrow <= distance + length:
				var tip := start + axis * (next_arrow - distance)
				add_chevron(surface, tip + lane_offset, axis, next_arrow)
				has_arrows = true
				next_arrow += CHEVRON_SPACING
		distance += length
	mesh = surface.commit() if has_arrows else null
	visible = has_arrows


func rounded_chevron() -> PackedVector2Array:
	var outline := PackedVector2Array([
		Vector2.ZERO, Vector2(.62, -.39), Vector2(.53, -.76),
		Vector2(0, -.41), Vector2(-.53, -.76), Vector2(-.62, -.39),
	])
	var rounded := PackedVector2Array()
	for index in outline.size():
		var corner := outline[index]
		var before := corner.move_toward(outline[posmod(index - 1, outline.size())], .09)
		var after := corner.move_toward(outline[(index + 1) % outline.size()], .09)
		for step in range(5):
			var t := float(step) / 4.0
			rounded.append(before.lerp(corner, t).lerp(corner.lerp(after, t), t))
	var triangles := PackedVector2Array()
	for index in Geometry2D.triangulate_polygon(rounded):
		triangles.append(rounded[index])
	return triangles


func add_chevron(surface: SurfaceTool, tip: Vector2, axis: Vector2, at: float) -> void:
	var side := axis.orthogonal()
	for vertex in chevron_profile:
		var point := tip + side * vertex.x + axis * vertex.y
		surface.set_uv(Vector2(at, 0.0))
		surface.add_vertex(Vector3(point.x, river.ground_height(point.x, point.y) + .19, point.y))
