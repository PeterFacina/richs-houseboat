extends RefCounted

const Roads = preload("res://deep_river_roads.gd")
const Traffic = preload("res://deep_river_traffic_controls.gd")
const CELL := 12.0
const BLOCK_RECHECK := 8.0

var graph := AStar3D.new()
var points := PackedVector3Array()
var cells := {}
var visited := {}
var components := PackedInt32Array()
var districts: Array[PackedInt32Array] = []
var query := PhysicsShapeQueryParameters3D.new()
var crossing_count := 0
var blocked_edges: Dictionary[Vector2i, float] = {}
var block_clock := 0.0


func build(edges: PackedVector3Array, waterfront: PackedVector3Array) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = .27
	shape.height = 1.38
	query.shape = shape
	query.collision_mask = 1
	for runs in [edges, waterfront]:
		for index in range(0, runs.size(), 2):
			link(vertex(runs[index]), vertex(runs[index + 1]))
	visited.clear()


func vertex(position: Vector3) -> int:
	var flat := Vector2(position.x, position.z)
	var key := Vector2i((flat * 12.0).round())
	if visited.has(key):
		return visited[key]
	var id := points.size()
	points.append(position)
	graph.add_point(id, position)
	visited[key] = id
	var cell := Vector2i((flat / CELL).floor())
	if not cells.has(cell):
		cells[cell] = PackedInt32Array()
	cells[cell].append(id)
	return id


func link(a: int, b: int) -> void:
	if a != b and not graph.are_points_connected(a, b):
		graph.connect_points(a, b)


func near(position: Vector3, radius: float) -> PackedInt32Array:
	var center := Vector2(position.x, position.z)
	var padding := Vector2.ONE * radius
	var first := Vector2i(((center - padding) / CELL).floor())
	var last := Vector2i(((center + padding) / CELL).floor())
	var found := PackedInt32Array()
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			for id: int in cells.get(Vector2i(x, z), PackedInt32Array()):
				if points[id].distance_squared_to(position) <= radius * radius:
					found.append(id)
	return found


func connect_crossings(space: PhysicsDirectSpaceState3D, ground: Callable) -> void:
	# A marked crossing is usable only when there are paved approaches on both sides.
	for crossing in [Traffic.LAURIER_CROSSING, Traffic.DEEP_RIVER_CROSSING]:
		var center := Vector3(crossing.x, ground.call(crossing.x, crossing.y), crossing.y)
		var axis := Vector3(crossing.z, 0, crossing.w)
		var across := axis.cross(Vector3.UP)
		var ends := [-1, -1]
		var scores := [INF, INF]
		for id in near(center, 14.0):
			var offset := points[id] - center
			var lateral := offset.dot(across)
			var along := absf(offset.dot(axis))
			if absf(lateral) < 2.8 or along > 2.3:
				continue
			var side := int(lateral > 0.0)
			var score := absf(lateral) + along * 4.0
			if score < scores[side]:
				ends[side] = id
				scores[side] = score
		if ends[0] >= 0 and ends[1] >= 0:
			var a := points[ends[0]]
			var b := points[ends[1]]
			if safe_grade(a, b, ground) and clear(space, a, b):
				link(ends[0], ends[1])
				crossing_count += 1


func seal() -> void:
	components.resize(points.size())
	components.fill(-1)
	for point in points.size():
		if components[point] >= 0:
			continue
		var group := PackedInt32Array([point])
		components[point] = districts.size()
		var cursor := 0
		while cursor < group.size():
			for next in graph.get_point_connections(group[cursor]):
				if components[next] < 0:
					components[next] = districts.size()
					group.append(next)
			cursor += 1
		districts.append(group)


func home_link(entry: Dictionary, space: PhysicsDirectSpaceState3D, ground: Callable) -> int:
	var foot: Vector3 = entry.foot
	var outward: Vector3 = entry.out
	var candidates: Array[Vector2] = []
	for id in near(foot, 31.0):
		if districts[components[id]].size() < 28:
			continue
		var difference := points[id] - foot
		if (difference * Vector3(1, 0, 1)).normalized().dot(outward) < .48:
			continue
		candidates.append(Vector2(difference.length_squared(), id))
	if candidates.is_empty() or not clear(space, entry.door, entry.door) or not clear(space, entry.door, foot):
		return -1
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var tried := PackedVector3Array()
	for candidate in candidates:
		var id := int(candidate.y)
		var to := points[id]
		var duplicate := false
		for previous in tried:
			if to.distance_squared_to(previous) < 1.7 * 1.7:
				duplicate = true
				break
		if duplicate:
			continue
		tried.append(to)
		if tried.size() > 14:
			break
		# A front walk can cross its own lawn. Skip connections through traffic lanes.
		if safe_grade(foot, to, ground) and clear_of_road(space, foot, to) and clear(space, foot, to):
			return id
	return -1


func clear_of_road(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = Roads.ROAD_LAYER
	var steps := maxi(1, ceili(from.distance_to(to) / 2.0))
	for i in range(1, steps):
		var sample := from.lerp(to, float(i) / steps)
		ray.from = sample + Vector3.UP * 1.5
		ray.to = sample - Vector3.UP * 1.5
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			var surface: Node = hit.collider.get_parent()
			if str(surface.name).begins_with("Asphalt"):
				return false
	return true


func safe_grade(from: Vector3, to: Vector3, ground: Callable) -> bool:
	var run := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	var steps := maxi(1, ceili(run / .9))
	var previous := from.y
	for i in range(1, steps + 1):
		var position := from.lerp(to, float(i) / steps)
		var height: float = to.y if i == steps else ground.call(position.x, position.z)
		if absf(height - previous) > .48:
			return false
		previous = height
	return true


func clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, height := .88) -> bool:
	query.transform.origin = from + Vector3.UP * height
	query.motion = to - from
	var travel := space.cast_motion(query)
	query.transform.origin = to + Vector3.UP * height
	query.motion = Vector3.ZERO
	return travel[0] >= 1.0 and space.intersect_shape(query, 1).is_empty()


func block_link(a: int, b: int) -> void:
	if graph.are_points_connected(a, b):
		graph.disconnect_points(a, b)
		blocked_edges[Vector2i(mini(a, b), maxi(a, b))] = block_clock + BLOCK_RECHECK


func recheck_blocked_links(delta: float, space: PhysicsDirectSpaceState3D) -> void:
	block_clock += delta
	# Probe at most one due link per physics tick.
	var due := Vector2i(-1, -1)
	for edge in blocked_edges:
		if block_clock >= blocked_edges[edge]:
			due = edge
			break
	if due.x < 0:
		return
	var a := points[due.x]
	var b := points[due.y]
	if clear(space, a, b) and clear(space, b, a):
		graph.connect_points(due.x, due.y)
		blocked_edges.erase(due)
	else:
		blocked_edges[due] = block_clock + BLOCK_RECHECK
