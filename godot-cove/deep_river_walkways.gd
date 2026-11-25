extends RefCounted

const EDGES = preload("res://ottawa/sidewalk_edges.json")
const Traffic = preload("res://deep_river_traffic_controls.gd")
const CURB_PROFILE := [Vector2(0.0, 0.0), Vector2(.035, .78),
	Vector2(.115, 1.0), Vector2(.265, 1.0)]
const CURB_GAP := .29
const ROW_SPACING := .78
const TREE_CELL := 12.0

var roads: RefCounted
var driveways: RefCounted
var walks: Dictionary
var curbs: Dictionary
var lawns: Dictionary
var tree_grid: Dictionary


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
	install_rows(layout, curbs, material, "Curb")
	install_rows(layout, lawns, terrain, "GrassVerge", true)
	walks.clear()
	curbs.clear()
	lawns.clear()
	roads = null
	driveways = null


func emit_section(span, section: Array, start: float, finish: float) -> void:
	var side: float = section[2]
	var inset := CURB_GAP + float(section[3])
	var width: float = section[4]
	var asphalt: bool = section[5] == "asphalt"
	var with_curb: bool = section[6]
	var divisions := maxi(1, ceili((finish - start) / ROW_SPACING))
	var previous_curb: Array[Vector3] = []
	var previous_walk: Array[Vector3] = []
	var previous_verge: Array[Vector3] = []
	var previous_bank: Array[Vector3] = []
	var previous_station := start
	for i in divisions + 1:
		var station := lerpf(start, finish, float(i) / divisions)
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
				for point: Vector2 in [inside, center, outside]:
					var native := height_at(point)
					var height := native + lerpf(.026, .045, drive)
					if with_curb:
						height = lerpf(height, maxf(native + .014, raised), ramp * drive)
					walk_row.append(at_level(point, height))
				if with_curb and drive > .55 and ramp > .08:
					var lawn_edge := outside + outward * .95
					if walk_region_clear(span, outside, lawn_edge):
						bank_row = [walk_row[-1], at_level(lawn_edge, height_at(lawn_edge) - .025)]
		var cell := Vector2i((edge / roads.CHUNK_SIZE).floor())
		if not previous_curb.is_empty() and not curb_row.is_empty():
			add_row(curbs, cell, previous_curb, curb_row, previous_station, station, side, Color.BLACK)
		if not previous_walk.is_empty() and not walk_row.is_empty():
			add_row(walks, cell, previous_walk, walk_row, previous_station, station, side,
				Color(0.0, 1.0, 0.0) if asphalt else Color.BLACK)
		var grass := Color("#45583e")
		if not previous_verge.is_empty() and not verge_row.is_empty():
			add_row(lawns, cell, previous_verge, verge_row, previous_station, station, side, grass, true)
		if not previous_bank.is_empty() and not bank_row.is_empty():
			add_row(lawns, cell, previous_bank, bank_row, previous_station, station, side, grass, true)
		previous_curb = curb_row
		previous_walk = walk_row
		previous_verge = verge_row
		previous_bank = bank_row
		previous_station = station


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
