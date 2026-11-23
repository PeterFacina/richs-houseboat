extends RefCounted

const CELL := 48.0
const MAX_LENGTH := 44.0
const HALF_WIDTH := 1.49
const MAX_CROSS_GRADE := .38
const RoadNetwork = preload("res://deep_river_roads.gd")
const Graphics = preload("res://river_graphics.gd")
const MATERIALS := [Color("#646560"), Color("#b7b3a5"), Color("#77756d")]

var ground: Callable
var roads := {}
var buildings := {}
var occupied := {}
var surfaces := {}
var vertex_counts := {}
var accepted: Array[Dictionary] = []


func setup(streets: Array, regional: Array, footprints: Array, elevation: Callable) -> void:
	ground = elevation
	for i in streets.size():
		if i == RoadNetwork.CHAMPLAIN:
			index_street(RoadNetwork.champlain_line(streets[i]), RoadNetwork.STREET_HALF_WIDTH, true)
		elif i not in RoadNetwork.HIGHWAY:
			index_street(streets[i], RoadNetwork.STREET_HALF_WIDTH)
	index_street(RoadNetwork.highway_line(streets), RoadNetwork.HIGHWAY_HALF_WIDTH)
	for street: Array in regional:
		index_street(street, 3.2)
	for building: Dictionary in footprints:
		var polygon := PackedVector2Array()
		for edge: Array in building.walls:
			polygon.append(Vector2(edge[0][0], edge[0][1]))
		if polygon.size() < 3:
			continue
		var bounds := Rect2(building.box[0], building.box[1], building.box[2] - building.box[0], building.box[3] - building.box[1])
		index(buildings, bounds.grow(.4), {"bounds": bounds, "polygon": polygon})


func index_street(street: Array, half_width: float, champlain := false) -> void:
	var station := 0.0
	for i in range(1, street.size()):
		var a := Vector2(street[i - 1][0], street[i - 1][1])
		var b := Vector2(street[i][0], street[i][1])
		if a.distance_squared_to(b) < .03:
			continue
		var axis := (b - a).normalized()
		var start_width := RoadNetwork.champlain_half_width(station) if champlain else half_width
		station += a.distance_to(b)
		var end_width := RoadNetwork.champlain_half_width(station) if champlain else half_width
		var span := {"a": a, "b": b, "normal": Vector2(-axis.y, axis.x),
			"start_width": start_width, "end_width": end_width, "sidewalk": champlain
				and is_equal_approx(start_width, RoadNetwork.PARKING_HALF_WIDTH)
				and is_equal_approx(end_width, RoadNetwork.PARKING_HALF_WIDTH)}
		index(roads, Rect2(a, Vector2.ZERO).expand(b).grow(maxf(start_width, end_width) + 2.0), span)


func road_width(span: Dictionary, at: Vector2) -> float:
	var a: Vector2 = span.a
	var b: Vector2 = span.b
	return lerpf(span.start_width, span.end_width, a.distance_to(at) / a.distance_to(b))


func index(grid: Dictionary, area: Rect2, item: Dictionary) -> void:
	var first := Vector2i((area.position / CELL).floor())
	var last := Vector2i((area.end / CELL).floor())
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			var key := Vector2i(x, z)
			if not grid.has(key):
				grid[key] = []
			grid[key].append(item)


func near(grid: Dictionary, point: Vector2) -> Array:
	return grid.get(Vector2i((point / CELL).floor()), [])


func plan(footprint: Dictionary, front: int, garage: bool, seed: int, entrance_fraction: float) -> void:
	var edge: Array = footprint.walls[front]
	var a := Vector2(edge[0][0], edge[0][1])
	var b := Vector2(edge[1][0], edge[1][1])
	var width := a.distance_to(b)
	if width < 2.55 or (garage and width < 3.0):
		return
	var along := (b - a) / width
	var outward := Vector2(-along.y, along.x)
	var forward := (a + b) * .5
	var door := a.lerp(b, entrance_fraction)
	var ends: Array[Vector2] = []
	if garage:
		ends.append(forward + outward * .72)
	else:
		for side in [1.0, -1.0] if seed % 2 == 0 else [-1.0, 1.0]:
			var end: Vector2 = forward + along * side * (width * .5 + HALF_WIDTH + .62) - outward * .85
			ends.append(end)
		# Tight lots can use a shorter front parking pad away from the entrance.
		var parking_side := .19 if entrance_fraction > .5 else .81
		ends.append(a.lerp(b, parking_side) + outward * 2.55)
	for end in ends:
		var route := find_approach(end, outward, door, garage)
		if route.is_empty():
			continue
		var style: Color = MATERIALS[seed % MATERIALS.size()]
		route.end = end
		route.style = style
		accepted.append(route)
		index(occupied, Rect2(route.entry, Vector2.ZERO).expand(end).grow(3.4), route)
		return


func find_approach(end: Vector2, outward: Vector2, door: Vector2, garage: bool) -> Dictionary:
	var best := INF
	var found := {}
	var seen := {}
	var tile := Vector2i((end / CELL).floor())
	for x in range(tile.x - 1, tile.x + 2):
		for z in range(tile.y - 1, tile.y + 2):
			for span: Dictionary in roads.get(Vector2i(x, z), []):
				if seen.has(span.a) and span.b in seen[span.a]:
					continue
				if not seen.has(span.a):
					seen[span.a] = []
				seen[span.a].append(span.b)
				var projected := Geometry2D.get_closest_point_to_segment(end, span.a, span.b)
				var length_to_road := projected.distance_to(end)
				if length_to_road < 8.5 or length_to_road > minf(best, MAX_LENGTH):
					continue
				if projected.distance_to(span.a) < 3.4 or projected.distance_to(span.b) < 3.4:
					continue
				var direction := (projected - end) / length_to_road
				if direction.dot(outward) < .47:
					continue
				var side: Vector2 = span.normal
				side *= signf((end - projected).dot(side))
				if -direction.dot(side) < .56:
					continue
				if span.sidewalk:
					continue
				var entry := projected + side * (road_width(span, projected) - .24)
				if entry.distance_squared_to(RoadNetwork.SIGNALS.JUNCTION) < 19.0 * 19.0:
					continue
				if entry.distance_squared_to(end) < 5.5 * 5.5:
					continue
				if not garage:
					var entry_walk := door + outward * 1.85
					var closest := Geometry2D.get_closest_point_to_segment(entry_walk, entry, end)
					if closest.distance_squared_to(entry_walk) < 2.24 * 2.24:
						continue
				var across := direction.orthogonal()
				if not clear_route(entry, end, across, side, span):
					continue
				best = length_to_road
				found = {"entry": entry, "road_normal": side, "across": across, "road": span}
	return found


func clear_route(entry: Vector2, end: Vector2, across: Vector2, normal: Vector2, target: Dictionary) -> bool:
	var length := entry.distance_to(end)
	var divisions := maxi(1, ceili(length / .7))
	var previous := float(ground.call(entry.x, entry.y))
	for i in divisions + 1:
		var t := float(i) / divisions
		var center := entry.lerp(end, t)
		var grade := float(ground.call(center.x, center.y))
		if grade < .33 or (i > 0 and absf(grade - previous) > (length / divisions) * .32):
			return false
		previous = grade
		for lateral in [-1.0, -.5, 0.0, .5, 1.0]:
			var point := center + edge_offset(across, normal, t) * float(lateral)
			if absf(float(ground.call(point.x, point.y)) - grade) > MAX_CROSS_GRADE:
				return false
			for building: Dictionary in near(buildings, point):
				if building.bounds.grow(.26).has_point(point) and polygon_conflict(point, building.polygon):
					return false
			for route: Dictionary in near(occupied, point):
				var offset := Geometry2D.get_closest_point_to_segment(point, route.entry, route.end)
				if point.distance_squared_to(offset) < 2.16 * 2.16:
					return false
			for road: Dictionary in near(roads, point):
				if road.a == target.a and road.b == target.b:
					continue
				var road_center := Geometry2D.get_closest_point_to_segment(point, road.a, road.b)
				var road_margin := road_width(road, road_center) + (RoadNetwork.CHAMPLAIN_SIDEWALK_WIDTH + .10 if road.sidewalk else .6)
				if point.distance_squared_to(road_center) < road_margin * road_margin:
					return false
	return true


func clears_tree(point: Vector2) -> bool:
	for route: Dictionary in near(occupied, point):
		var approach := Geometry2D.get_closest_point_to_segment(point, route.entry, route.end)
		if point.distance_squared_to(approach) < 2.1 * 2.1:
			return true
	return false


func edge_offset(across: Vector2, road_normal: Vector2, t: float) -> Vector2:
	var flare := (1.0 - smoothstep(0.0, .23, t)) * .43
	var rounding := 1.0 - smoothstep(.89, 1.0, t) * .155
	var offset := across * (HALF_WIDTH + flare) * rounding
	# At the curb every vertex lies on the surveyed road-edge line.
	return offset - road_normal * road_normal.dot(offset) * (1.0 - smoothstep(0.0, .21, t))


func polygon_conflict(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for i in polygon.size():
		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, polygon[i],
				polygon[(i + 1) % polygon.size()])) < .27 * .27:
			return true
	return false


func build(parent: Node3D, asphalt_scan: Texture2D, concrete_scan: Texture2D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://deep_river_driveway.gdshader")
	mat.set_shader_parameter("asphalt_scan", asphalt_scan)
	mat.set_shader_parameter("concrete_scan", concrete_scan)
	for route in accepted:
		emit_drive(route)
	var layout := Node3D.new()
	layout.name = "ResidentialDriveways"
	parent.add_child(layout)
	for chunk: Vector2i in surfaces:
		var surface: SurfaceTool = surfaces[chunk]
		var piece := MeshInstance3D.new()
		piece.mesh = surface.commit()
		piece.material_override = mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layout.add_child(piece)
		piece.position = Vector3(chunk.x * CELL * 4.0, 0, chunk.y * CELL * 4.0)
		Graphics.batch(piece, "building_detail")
	surfaces.clear()
	vertex_counts.clear()


func emit_drive(route: Dictionary) -> void:
	var start: Vector2 = route.entry
	var end: Vector2 = route.end
	var across: Vector2 = route.across
	var normal: Vector2 = route.road_normal
	var chunk := Vector2i(((start + end) * .5 / (CELL * 4.0)).floor())
	if not surfaces.has(chunk):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[chunk] = surface
	var batch: SurfaceTool = surfaces[chunk]
	var origin := Vector2(chunk) * CELL * 4.0
	var length := start.distance_to(end)
	var rows := maxi(1, ceili(length / .55))
	var columns := 4
	var offset := int(vertex_counts.get(batch, 0))
	for row in rows + 1:
		var t := float(row) / rows
		var center := start.lerp(end, t)
		var offset_across := edge_offset(across, normal, t)
		for col in columns + 1:
			var side := float(col) / columns * 2.0 - 1.0
			var point := center + offset_across * side
			var grade := float(ground.call(point.x, point.y))
			var metres := t * length
			var apron := smoothstep(.03, .40, metres) * (1.0 - smoothstep(.65, 2.4, metres))
			var lift := .034 + .014 * apron + .009 * smoothstep(.2, 1.4, metres)
			batch.set_normal(Vector3.UP)
			batch.set_uv(Vector2(side, t * length))
			batch.set_color(route.style)
			batch.add_vertex(Vector3(point.x - origin.x, grade + lift, point.y - origin.y))
	var stride := columns + 1
	var flip := (end - start).cross(across) > 0.0
	for row in rows:
		for col in columns:
			var i := offset + row * stride + col
			var order := [i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]
			if flip:
				order = [i, i + stride, i + 1, i + 1, i + stride, i + stride + 1]
			for vertex in order:
				batch.add_index(vertex)
	vertex_counts[batch] = offset + (rows + 1) * stride
