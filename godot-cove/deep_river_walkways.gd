extends RefCounted

const EDGES = preload("res://deep_river/sidewalk_edges.json")
const Traffic = preload("res://deep_river_traffic_controls.gd")
const CURB_PROFILE := [Vector2(0.0, 0.0), Vector2(.035, .78),
	Vector2(.115, 1.0), Vector2(.265, 1.0)]
const CURB_GAP := .29
const ROW_SPACING := .78
const TREE_CELL := 12.0
const GLENDALE_CORNER := Vector2(17974.9162, 13428.5562)

var roads: RefCounted
var driveways: RefCounted
var walks: Dictionary
var corner_walks: Dictionary
var curbs: Dictionary
var lawns: Dictionary
var tree_grid: Dictionary
var walk_cuts: Dictionary
var landing_cuts: Dictionary


static func edges_for(road: int) -> Array:
	return EDGES.data.get(str(road), {}).get("edges", [])


static func curb_strength(edges: Array, station: float, side: float) -> float:
	var raised := 0.0
	for edge: Array in edges:
		if edge[6] and edge[2] == side:
			raised = maxf(raised, smoothstep(-.85, .50, minf(station - edge[0], edge[1] - station)))
	return raised


func build(parent: Node3D, network: RefCounted, drives: RefCounted,
		concrete_scan: Texture2D, asphalt_scan: Texture2D, terrain: Material) -> void:
	roads = network
	driveways = drives
	connect_corners()
	var material := ShaderMaterial.new()
	material.shader = preload("res://champlain_sidewalk.gdshader")
	material.set_shader_parameter("concrete_scan", concrete_scan)
	material.set_shader_parameter("asphalt_scan", asphalt_scan)
	var layout := Node3D.new()
	layout.name = "MappedSidewalks"
	parent.add_child(layout)
	for span in roads.spans:
		for section: Array in span.edge_profiles:
			var start := maxf(span.station, section[0])
			var finish := minf(span.station + span.length, section[1])
			if finish - start > .05:
				emit_section(span, section, start, finish)
	install_rows(layout, walks, material, "Sidewalk")
	install_rows(layout, corner_walks, material, "SidewalkCorner")
	install_rows(layout, curbs, material, "Curb")
	install_rows(layout, lawns, terrain, "GrassVerge", true)
	walks.clear()
	corner_walks.clear()
	curbs.clear()
	lawns.clear()
	walk_cuts.clear()
	landing_cuts.clear()
	roads = null
	driveways = null


func emit_section(span, section: Array, start: float, finish: float) -> void:
	var side: float = section[2]
	var inset := CURB_GAP + float(section[3])
	var width: float = section[4]
	var asphalt: bool = section[5] == "asphalt"
	var with_curb: bool = section[6]
	var stations := PackedFloat32Array([start, finish])
	var divisions := maxi(1, ceili((finish - start) / ROW_SPACING))
	for i in range(1, divisions):
		stations.append(lerpf(start, finish, float(i) / divisions))
	var key := Vector2i(span.street, int(side))
	var cuts: Array = walk_cuts.get(key, [])
	var landings: Array = landing_cuts.get(key, [])
	for cut: Vector2 in cuts:
		for station: float in [cut.x, cut.y]:
			if station > start and station < finish:
				stations.append(station)
	stations.sort()
	var previous_curb: Array[Vector3] = []
	var previous_walk: Array[Vector3] = []
	var previous_verge: Array[Vector3] = []
	var previous_bank: Array[Vector3] = []
	var previous_station := start
	for station: float in stations:
		if station == previous_station and not previous_walk.is_empty():
			continue
		var fraction: float = (station - span.station) / span.length
		var edge: Vector2 = roads.at(span, fraction, span.width * side)
		# Unit miter coordinates agree on shared span ends.
		var outward: Vector2 = span.left.lerp(span.right, fraction) * side
		var ramp := edge_ramp(section, span, edge, station)
		var inside := edge + outward * inset
		var outside := edge + outward * (inset + width)
		var center := inside.lerp(outside, .5)
		var foot := height_at(edge) + .040
		var raised := foot + .12
		if with_curb:
			var nearby_land := maxf(maxf(height_at(edge + outward * .265), height_at(inside)),
				maxf(height_at(center), height_at(outside)))
			raised = clampf(nearby_land + .028, raised, foot + .25)
		var level := lerpf(foot, raised, ramp)
		var curb_row: Array[Vector3] = []
		var walk_row: Array[Vector3] = []
		var verge_row: Array[Vector3] = []
		var bank_row: Array[Vector3] = []
		if with_curb and clearance(span, edge + outward * .14) > .06:
			for profile: Vector2 in CURB_PROFILE:
				var point := edge + outward * profile.x
				curb_row.append(at_level(point, lerpf(foot, level, profile.y)))
			var back := edge + outward * .265
			var verge_end := inside if width > .0 else edge + outward * .98
			var mid := back.lerp(verge_end, .55)
			if clearance(span, mid) > .25 and driveway_ramp(mid) > .55 and ramp > .08:
				var end_level := level if width > .0 else height_at(verge_end) - .025
				verge_row = [at_level(back, level), at_level(mid, level), at_level(verge_end, end_level)]
		if width > .0:
			if walk_region_clear(span, inside, outside):
				remember_tree_clearance(center)
				var drive := driveway_ramp(center)
				walk_row = walk_heights(inside, outside, drive, raised, ramp if with_curb else 0.0)
				if with_curb and drive > .55 and ramp > .08:
					var lawn_edge := outside + outward * .95
					if walk_region_clear(span, outside, lawn_edge):
						bank_row = [walk_row[-1], at_level(lawn_edge, height_at(lawn_edge) - .025)]
		var cell := Vector2i((edge / roads.CHUNK_SIZE).floor())
		if not previous_curb.is_empty() and not curb_row.is_empty():
			add_row(curbs, cell, previous_curb, curb_row, previous_station, station, side, Color.BLACK)
		var middle := (previous_station + station) * .5
		if not previous_walk.is_empty() and not walk_row.is_empty() and not is_cut(cuts, middle):
			add_row(walks, cell, previous_walk, walk_row, previous_station, station, side,
				Color(0.0, 1.0, 0.0) if asphalt else Color.BLACK)
		var grass := Color("#45583e")
		if not previous_verge.is_empty() and not verge_row.is_empty() and not is_cut(landings, middle):
			add_row(lawns, cell, previous_verge, verge_row, previous_station, station, side, grass, true)
		if not previous_bank.is_empty() and not bank_row.is_empty() and not is_cut(landings, middle):
			add_row(lawns, cell, previous_bank, bank_row, previous_station, station, side, grass, true)
		previous_curb = curb_row
		previous_walk = walk_row
		previous_verge = verge_row
		previous_bank = bank_row
		previous_station = station


func connect_corners() -> void:
	var joined: Dictionary = {}
	for a in roads.spans:
		if a.edge_profiles.is_empty():
			continue
		for b in a.neighbors:
			if a.street >= b.street or b.edge_profiles.is_empty():
				continue
			var axis_a: Vector2 = (a.end - a.start).normalized()
			var axis_b: Vector2 = (b.end - b.start).normalized()
			if absf(axis_a.cross(axis_b)) < .38:
				continue
			var crossing: Variant = Geometry2D.line_intersects_line(Vector2.ZERO, axis_a, b.start - a.start, axis_b)
			if not crossing is Vector2:
				continue
			var touch: Vector2 = a.start + crossing
			if ((touch - Geometry2D.get_closest_point_to_segment(touch, a.start, a.end)).length() > .55
					or (touch - Geometry2D.get_closest_point_to_segment(touch, b.start, b.end)).length() > .55):
				continue
			for left: Array in a.edge_profiles:
				for right: Array in b.edge_profiles:
					if left[4] <= 0.0 or right[4] <= 0.0:
						continue
					var key := Vector4i(a.street, b.street, left[2], right[2])
					var corners: Array = joined.get(key, [])
					if not corners.any(func(point: Vector2) -> bool: return point.distance_squared_to(touch) < 9.0):
						if connect_corner(a, b, left, right, touch):
							corners.append(touch)
							joined[key] = corners


func walk_edges(span, section: Array, fraction: float) -> PackedVector2Array:
	var outward: Vector2 = span.left.lerp(span.right, fraction) * float(section[2])
	var edge: Vector2 = roads.at(span, fraction, span.width * float(section[2]))
	var inside := edge + outward * (CURB_GAP + float(section[3]))
	return PackedVector2Array([edge, inside, inside + outward * float(section[4])])


func connect_corner(a, b, left: Array, right: Array, junction: Vector2) -> bool:
	var center_a := walk_edges(a, left, 0.0)
	var end_a := walk_edges(a, left, 1.0)
	var center_b := walk_edges(b, right, 0.0)
	var end_b := walk_edges(b, right, 1.0)
	var from_a := center_a[1].lerp(center_a[2], .5)
	var from_b := center_b[1].lerp(center_b[2], .5)
	var along_a := end_a[1].lerp(end_a[2], .5) - from_a
	var along_b := end_b[1].lerp(end_b[2], .5) - from_b
	var bend: Variant = Geometry2D.line_intersects_line(Vector2.ZERO, along_a.normalized(),
		from_b - from_a, along_b.normalized())
	if not bend is Vector2:
		return false
	var pivot := from_a + (bend as Vector2)
	var radius := junction.distance_to(pivot)
	if radius < 4.0 or radius > 14.0:
		return false
	var fresh := junction.distance_squared_to(GLENDALE_CORNER) < 1.5
	var run := 2.8 if fresh else 1.8
	var leg_a := corner_leg(a, left, from_a, along_a, junction, pivot, run)
	var leg_b := corner_leg(b, right, from_b, along_b, junction, pivot, run)
	if leg_a.is_empty() or leg_b.is_empty():
		return false
	var first: Array[Vector3] = leg_a.row
	var last: Array[Vector3] = leg_b.row
	var inside := corner_control(first[0], last[0], along_a, along_b, pivot)
	var outside := corner_control(first[2], last[2], along_a, along_b, pivot)
	var rows: Array = [first]
	for i in range(1, 12):
		var t := float(i) / 12.0
		var inner := corner_point(first[0], last[0], inside, t)
		var outer := corner_point(first[2], last[2], outside, t)
		if fresh:
			# Bring the concrete up to the curb at the bend and taper into each detached walk.
			var limit := 1.0
			var safe := 0.0
			for step in 8:
				var fraction := (safe + limit) * .5
				var nearer := inner.lerp(junction, fraction)
				if walk_region_clear(a, nearer, outer) and walk_region_clear(b, nearer, outer):
					safe = fraction
				else:
					limit = fraction
			inner = inner.lerp(junction, safe * sin(PI * t))
		if not walk_region_clear(a, inner, outer) or not walk_region_clear(b, inner, outer):
			return false
		var center := inner.lerp(outer, .5)
		var row: Array[Vector3] = []
		var index := 0
		for point: Vector2 in [inner, center, outer]:
			var level := lerpf(first[index].y, last[index].y, t)
			row.append(at_level(point, maxf(height_at(point) + .048, level)))
			index += 1
		rows.append(row)
	rows.append(last)
	var key_a := Vector2i(a.street, int(left[2]))
	var key_b := Vector2i(b.street, int(right[2]))
	cut_walk(walk_cuts, key_a, leg_a.cut)
	cut_walk(walk_cuts, key_b, leg_b.cut)
	if fresh:
		cut_walk(landing_cuts, key_a, leg_a.cut)
		cut_walk(landing_cuts, key_b, leg_b.cut)
	var cell := Vector2i((pivot / roads.CHUNK_SIZE).floor())
	var tangent := Vector2(last[1].x - first[1].x, last[1].z - first[1].z)
	var outward := Vector2(first[2].x - first[0].x, first[2].z - first[0].z)
	var side := 1.0 if tangent.cross(outward) < 0.0 else -1.0
	for i in range(1, rows.size()):
		var previous: Array[Vector3] = rows[i - 1]
		var row: Array[Vector3] = rows[i]
		remember_tree_clearance(Vector2(row[1].x, row[1].z))
		var finish := float(i) * .31
		var asphalt: bool = (left[5] if i <= 6 else right[5]) == "asphalt"
		add_row(corner_walks, cell, previous, row, finish - .31, finish, side,
			Color(0.0, float(asphalt), float(fresh)))
	return true


func corner_leg(span, section: Array, first: Vector2, axis: Vector2,
		junction: Vector2, pivot: Vector2, run: float) -> Dictionary:
	var direction := signf((pivot - junction).dot(axis))
	var fraction := ((pivot - first).dot(axis) + run * direction * axis.length()) / axis.length_squared()
	var station: float = span.station + fraction * span.length
	if fraction < 0.0 or fraction > 1.0 or station < section[0] or station > section[1]:
		return {}
	var edges := walk_edges(span, section, fraction)
	if not walk_region_clear(span, edges[1], edges[2]):
		return {}
	var foot := height_at(edges[0]) + .040
	var center := edges[1].lerp(edges[2], .5)
	var nearby := maxf(height_at(edges[0].lerp(edges[1], .265 / (CURB_GAP + float(section[3])))),
		maxf(height_at(edges[1]), maxf(height_at(center), height_at(edges[2]))))
	var raised := clampf(nearby + .028, foot + .12, foot + .25)
	var ramp := edge_ramp(section, span, edges[0], station) if section[6] else 0.0
	var junction_station: float = span.station + (junction - span.start).dot(span.end - span.start) / span.length
	var limit := junction_station - direction
	return {"row": walk_heights(edges[1], edges[2], driveway_ramp(center), raised, ramp),
		"cut": Vector2(minf(limit, station), maxf(limit, station))}


static func corner_control(a: Vector3, b: Vector3, axis_a: Vector2, axis_b: Vector2, fallback: Vector2) -> Vector2:
	var start := Vector2(a.x, a.z)
	var hit: Variant = Geometry2D.line_intersects_line(Vector2.ZERO, axis_a.normalized(),
		Vector2(b.x, b.z) - start, axis_b.normalized())
	return start + (hit as Vector2) if hit is Vector2 else fallback


static func corner_point(a: Vector3, b: Vector3, control: Vector2, t: float) -> Vector2:
	return Vector2(a.x, a.z).lerp(control, t).lerp(control.lerp(Vector2(b.x, b.z), t), t)


static func cut_walk(cuts: Dictionary, key: Vector2i, range_to_cut: Vector2) -> void:
	if not cuts.has(key):
		cuts[key] = []
	cuts[key].append(range_to_cut)


static func is_cut(cuts: Array, station: float) -> bool:
	for cut: Vector2 in cuts:
		if station > cut.x and station < cut.y:
			return true
	return false


func walk_heights(inside: Vector2, outside: Vector2, drive: float, raised: float, ramp: float) -> Array[Vector3]:
	var row: Array[Vector3] = []
	for point: Vector2 in [inside, inside.lerp(outside, .5), outside]:
		var native := height_at(point)
		var height := native + lerpf(.026, .045, drive)
		row.append(at_level(point, lerpf(height, maxf(native + .014, raised), ramp * drive)))
	return row


func edge_ramp(section: Array, span, edge: Vector2, station: float) -> float:
	var end_fade := smoothstep(0.0, 1.25, minf(station - section[0], section[1] - station))
	var corner := smoothstep(.10, 1.52, clearance(span, edge))
	var crosswalk := 1.0
	for crossing: Vector4 in [Traffic.LAURIER_CROSSING, Traffic.DEEP_RIVER_CROSSING]:
		var offset := edge - Vector2(crossing.x, crossing.y)
		if offset.length_squared() < 4.1 * 4.1:
			var along := absf(offset.dot(Vector2(crossing.z, crossing.w)))
			crosswalk = minf(crosswalk, smoothstep(1.14, 2.15, along))
	return end_fade * corner * crosswalk * driveway_ramp(edge)


func driveway_ramp(point: Vector2) -> float:
	var free := 1.0
	for route: Dictionary in driveways.near(driveways.occupied, point):
		var closest := Geometry2D.get_closest_point_to_segment(point, route.entry, route.end)
		free = minf(free, smoothstep(1.54, 2.38, point.distance_to(closest)))
	return free


func walk_region_clear(span, inside: Vector2, outside: Vector2) -> bool:
	for point: Vector2 in [inside, inside.lerp(outside, .5), outside]:
		if clearance(span, point) < .25:
			return false
		for building: Dictionary in driveways.near(driveways.buildings, point):
			if (building.bounds.grow(.1).has_point(point)
					and driveways.polygon_conflict(point, building.polygon)):
				return false
	return true


static func clearance(span, point: Vector2) -> float:
	var free := 12.0
	for other in span.neighbors:
		if not other.pavement_bounds.grow(2.7).has_point(point):
			continue
		if Geometry2D.is_point_in_polygon(point, other.outline):
			return -1.0
		for i in other.outline.size():
			var closest := Geometry2D.get_closest_point_to_segment(point, other.outline[i],
				other.outline[(i + 1) % other.outline.size()])
			free = minf(free, point.distance_to(closest))
	return free


func height_at(at: Vector2) -> float:
	return roads.ground.call(at.x, at.y)


static func at_level(at: Vector2, height: float) -> Vector3:
	return Vector3(at.x, height, at.y)


func add_row(chunks: Dictionary, cell: Vector2i, first: Array[Vector3], last: Array[Vector3],
		start: float, finish: float, side: float, color: Color, terrain := false) -> void:
	if not chunks.has(cell):
		chunks[cell] = roads.new_surface()
	var surface: SurfaceTool = chunks[cell]
	var origin := Vector3.ZERO if terrain else Vector3(cell.x * roads.CHUNK_SIZE, 0, cell.y * roads.CHUNK_SIZE)
	for i in range(1, first.size()):
		var left := i - 1 if side > 0 else i
		var right := i if side > 0 else i - 1
		var points := [first[left], first[right], last[left], first[right], last[right], last[left]]
		var stations := [start, start, finish, start, finish, finish]
		for j in points.size():
			surface.set_color(color)
			surface.set_uv(Vector2(float(left if j in [0, 2, 5] else right) * .24, stations[j]))
			surface.add_vertex(points[j] - origin)


func install_rows(parent: Node3D, meshes: Dictionary, material: Material, label: String, terrain := false) -> void:
	for cell: Vector2i in meshes:
		var origin := Vector3.ZERO if terrain else Vector3(cell.x * roads.CHUNK_SIZE, 0, cell.y * roads.CHUNK_SIZE)
		roads.install(parent, meshes[cell], origin, material, label, true, not terrain)


func remember_tree_clearance(point: Vector2) -> void:
	var cell := Vector2i((point / TREE_CELL).floor())
	if not tree_grid.has(cell):
		tree_grid[cell] = []
	tree_grid[cell].append(point)


func clears_tree(point: Vector2) -> bool:
	var cell := Vector2i((point / TREE_CELL).floor())
	for x in range(cell.x - 1, cell.x + 2):
		for z in range(cell.y - 1, cell.y + 2):
			for center: Vector2 in tree_grid.get(Vector2i(x, z), []):
				if center.distance_squared_to(point) < 1.02:
					return true
	return false
