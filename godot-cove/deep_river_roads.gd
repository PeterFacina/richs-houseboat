extends RefCounted

const Kit = preload("res://scenery.gd")
const PublicWorks = preload("res://public_works.gd")
const CivicParking = preload("res://deep_river_civic_parking.gd")
const Furniture = preload("res://deep_river_champlain_furniture.gd")
const StreetSigns = preload("res://deep_river_street_signs.gd")
const TrafficControls = preload("res://deep_river_traffic_controls.gd")
const Walkways = preload("res://deep_river_walkways.gd")
const ROAD_DETAILS = preload("res://ottawa/deep_river_road_details.json")
const MCANULTY_FEEDERS := [0, 2]
const ROAD_LAYER := 1 << 18
const CHUNK_SIZE := 256.0
const JUNCTION_LIFT := .043

# Indexes refer to the surveyed polylines in ottawa/river.json.
const HIGHWAY := [13, 15, 44, 2, 8, 7, 3]
const HIGHWAY_HALF_WIDTH := 5.65
const SIGNALS = preload("res://deep_river_signals.gd")
const CHAMPLAIN := 6
const DEEP_RIVER_ROAD := 11
const CIVIC_ACCESS := Vector2(99.3, 4.5)
const STREET_HALF_WIDTH := 3.4
const PARKING_HALF_WIDTH := 8.7
const CHAMPLAIN_SIDEWALK_WIDTH := 2.25
const CHAMPLAIN_WALK_START := 6.0
const CHAMPLAIN_WALK_END := Vector2(159.98, 174.2)
# Each station gives the pavement width on the east and west sides respectively.
const CHAMPLAIN_PROFILE := [
	Vector3(8.0, 3.4, 3.4), Vector3(12.0, 4.75, 4.75), Vector3(18.0, 8.7, 8.7),
	Vector3(106.0, 8.7, 8.7), Vector3(124.0, 5.15, 8.7), Vector3(148.0, 5.15, 8.7),
	Vector3(155.0, 3.4, 8.7), Vector3(162.5, 3.4, 8.7), Vector3(169.0, 3.4, 5.8),
	Vector3(173.0, 3.4, 3.4),
]
const RIDGE := 49
const BROCKHOUSE := 76
const MARINA_APPROACH := 62
const PLAZA_FRONTAGE := Vector2(18025.0, 13243.0)

enum Marking { NONE, SOLID, BROKEN, HIGHWAY }
# Packed into vertex alpha for town_street.gdshader. Standard meshes use alpha 1.
enum RoadSurface { CHAMPLAIN, BROCKHOUSE, CEDAR, YARD_DRIVE, STANDARD }

class Junction:
	var center: Vector2
	var inner: float
	var grade: float
	var slope: Vector2
	var gravel: float


class Span:
	var street: int
	var road_surface: RoadSurface
	var gravel_ranges: Array
	var unpaved := false
	var edge_profiles: Array
	var order: int
	var start: Vector2
	var end: Vector2
	var left: Vector2
	var right: Vector2
	var length: float
	var station: float
	var total: float
	var width: float
	var start_width: Vector2
	var end_width: Vector2
	var shoulder: float
	var marking: Marking
	var fine: bool
	var bounds: Rect2
	var pavement_bounds: Rect2
	var outline: PackedVector2Array
	var neighbors: Array[Span] = []
	var junctions: Array[Junction] = []


var ground: Callable
var close_areas: Array[Rect2]
var downtown: Rect2
var marina_area: Rect2
var marina_apron: Image
var paved: ShaderMaterial
var gravel: ShaderMaterial
var spans: Array[Span] = []
var chunks: Dictionary = {}
var town_paving: Image
var road_root: Node3D


func build(map: Node3D, data: Dictionary, elevation: Callable, parking_mask: Texture2D,
		detail_areas: Array[Rect2], asphalt: Texture2D, normal: Texture2D,
		stone: Texture2D, asphalt_grain: Texture2D, gravel_color: Texture2D, gravel_normal: Texture2D,
		paving_texture: Texture2D) -> void:
	ground = elevation
	close_areas = detail_areas
	var limits: Array = data.downtown_paving
	downtown = Rect2(limits[0], limits[1], limits[2] - limits[0], limits[3] - limits[1])
	town_paving = paving_texture.get_image()
	paved = ShaderMaterial.new()
	paved.shader = preload("res://town_street.gdshader")
	paved.set_shader_parameter("road_scan", asphalt)
	paved.set_shader_parameter("road_normal", normal)
	paved.set_shader_parameter("asphalt_scan", asphalt_grain)
	paved.set_shader_parameter("concrete_scan", stone)
	paved.set_shader_parameter("gravel_scan", gravel_color)
	paved.set_shader_parameter("gravel_normal", gravel_normal)
	paved.set_shader_parameter("champlain_access", CIVIC_ACCESS)
	paved.set_shader_parameter("champlain_bays", Vector4(Furniture.BAY_START, Furniture.BAY_PITCH,
		Furniture.BAY_SLOPE, Furniture.BAY_LANE_EDGE))
	paved.set_shader_parameter("laurier_crossing", TrafficControls.LAURIER_CROSSING)
	paved.set_shader_parameter("deep_river_crossing", TrafficControls.DEEP_RIVER_CROSSING)
	if parking_mask != null:
		marina_apron = parking_mask.get_image()
		marina_area = detail_areas[0]
		paved.set_shader_parameter("marina_paving", parking_mask)
		paved.set_shader_parameter("marina_paving_bounds", Vector4(marina_area.position.x, marina_area.position.y,
			marina_area.size.x, marina_area.size.y))
	gravel = ShaderMaterial.new()
	gravel.shader = preload("res://town_road_shoulder.gdshader")
	gravel.set_shader_parameter("gravel_scan", gravel_color)
	gravel.set_shader_parameter("town_paving", paving_texture)
	gravel.set_shader_parameter("paving_bounds", Vector4(downtown.position.x, downtown.position.y,
		downtown.size.x, downtown.size.y))

	# Through roads own the overlap with side streets. Draw and collide with
	# one surface in the overlap, with both approaches at the same grade.
	var streets: Array = data.streets
	add_street(HIGHWAY[0], highway_line(streets), HIGHWAY_HALF_WIDTH)
	var through := [RIDGE, DEEP_RIVER_ROAD, CHAMPLAIN, BROCKHOUSE, MARINA_APPROACH]
	var road_surfaces := {CHAMPLAIN: RoadSurface.CHAMPLAIN, BROCKHOUSE: RoadSurface.BROCKHOUSE}
	for index: int in through:
		var line: Array = champlain_line(streets[index]) if index == CHAMPLAIN else streets[index]
		add_street(index, line, STREET_HALF_WIDTH, road_surfaces.get(index, RoadSurface.STANDARD))
	for index in streets.size():
		if not through.has(index) and index not in HIGHWAY:
			add_street(index, streets[index], 3.4)
	add_street(streets.size(), PublicWorks.CEDAR_ROAD, 3.4, RoadSurface.CEDAR)
	add_street(streets.size() + 1, PublicWorks.YARD_DRIVE, 2.85, RoadSurface.YARD_DRIVE)
	# The middle regional segment follows the surveyed atlas road. Join only its two extensions.
	for index: int in MCANULTY_FEEDERS:
		add_street(streets.size() + 2 + index, map.regional_streets[index], 3.2, RoadSurface.STANDARD, true)
	find_neighbors()
	build_junction_grades()
	for span: Span in spans:
		build_span(span)

	var network := Node3D.new()
	network.name = "DeepRiverRoads"
	map.add_child(network)
	road_root = network
	var signals := SIGNALS.new()
	network.add_child(signals)
	signals.build(streets, ground)
	var sidewalk := ShaderMaterial.new()
	sidewalk.shader = preload("res://champlain_sidewalk.gdshader")
	sidewalk.set_shader_parameter("concrete_scan", stone)
	for cell: Vector2i in chunks:
		var batch: Dictionary = chunks[cell]
		var origin := Vector3(cell.x * CHUNK_SIZE, 0.0, cell.y * CHUNK_SIZE)
		install(network, batch.asphalt, origin, paved, "Asphalt", true)
		install(network, batch.shoulder, origin, gravel, "GravelShoulder", true)
		if batch.has("verge"):
			install(network, batch.verge, origin, gravel, "DowntownVerge", false)
		if batch.has("sidewalk"):
			install(network, batch.sidewalk, origin, sidewalk, "ChamplainSidewalk", true)
	var edges: Array[PackedVector2Array] = []
	for span: Span in spans:
		if CivicParking.BOUNDS.intersects(span.pavement_bounds):
			var outline := PackedVector2Array()
			for point in span.outline:
				outline.append(point - CivicParking.ORIGIN)
			edges.append(outline)
	CivicParking.new().build(network, ground, paved, edges, ROAD_LAYER)
	Furniture.new().build(network, streets[CHAMPLAIN], ground, champlain_half_width)
	StreetSigns.new().build(network, map, ROAD_DETAILS.data.junctions)
	TrafficControls.new().build(network, map)
	chunks.clear()


func build_walkways(driveways: RefCounted, concrete: Texture2D, asphalt: Texture2D, terrain: Material) -> Walkways:
	var walks := Walkways.new()
	walks.build(road_root, self, driveways, concrete, asphalt, terrain)
	for span: Span in spans:
		span.neighbors.clear()
	spans.clear()
	return walks


static func highway_line(streets: Array) -> Array:
	var highway: Array = []
	for index: int in HIGHWAY:
		highway.append_array(streets[index])
	return highway


static func champlain_line(line: Array) -> Array:
	var start := Vector2(line[0][0], line[0][1])
	var end := Vector2(line[1][0], line[1][1])
	var axis := (end - start).normalized()
	var points: Array = [line[0]]
	var breaks: Array[float] = [CHAMPLAIN_WALK_START, CHAMPLAIN_WALK_END.x, CHAMPLAIN_WALK_END.y,
		CIVIC_ACCESS.x - CIVIC_ACCESS.y, CIVIC_ACCESS.x + CIVIC_ACCESS.y]
	for section: Vector3 in CHAMPLAIN_PROFILE:
		breaks.append(section.x)
	breaks.sort()
	for distance in breaks:
		var at := start + axis * distance
		points.append([at.x, at.y])
	points.append_array(line.slice(1))
	return points


static func clears_champlain_tree(point: Vector2, start: Vector2, axis: Vector2) -> bool:
	var delta := point - start
	var station := delta.dot(axis)
	var offset := delta.dot(axis.orthogonal())
	var side := signf(offset)
	return station >= CHAMPLAIN_WALK_START and station <= CHAMPLAIN_WALK_END.y and \
		absf(offset) <= champlain_half_width(station, side) + champlain_walk_width(station, side) + .48


static func champlain_half_width(station: float, side: float) -> float:
	var previous: Vector3 = CHAMPLAIN_PROFILE[0]
	for next: Vector3 in CHAMPLAIN_PROFILE:
		if station <= next.x:
			var from := previous.y if side < 0.0 else previous.z
			var to := next.y if side < 0.0 else next.z
			return lerpf(from, to, clampf((station - previous.x) / maxf(.01, next.x - previous.x), 0.0, 1.0))
		previous = next
	return STREET_HALF_WIDTH


static func champlain_walk_width(station: float, side: float) -> float:
	if side >= 0.0:
		return CHAMPLAIN_SIDEWALK_WIDTH
	var width := lerpf(CHAMPLAIN_SIDEWALK_WIDTH, 1.92, smoothstep(116.0, 124.0, station))
	return lerpf(width, 3.48, smoothstep(154.0, CHAMPLAIN_WALK_END.x, station))


static func champlain_walk_end(side: float) -> float:
	return CHAMPLAIN_WALK_END.x if side < 0.0 else CHAMPLAIN_WALK_END.y


func add_street(street: int, line: Array, width: float, road_surface := RoadSurface.STANDARD, unpaved := false) -> void:
	var centers := PackedVector2Array()
	for pair: Array in line:
		var point := Vector2(pair[0], pair[1])
		if centers.is_empty() or point.distance_squared_to(centers[-1]) > .01:
			centers.append(point)
	if centers.size() < 2:
		return
	var edges := PackedVector2Array()
	var stations := PackedFloat32Array([0.0])
	for i in centers.size():
		var before := (centers[i] - centers[maxi(i - 1, 0)]).orthogonal().normalized()
		var after := (centers[mini(i + 1, centers.size() - 1)] - centers[i]).orthogonal().normalized()
		var bisector := (before + after).normalized()
		var alignment := maxf(.72, bisector.dot(after if i == 0 else before))
		edges.append(bisector / alignment)
		if i > 0:
			stations.append(stations[-1] + centers[i - 1].distance_to(centers[i]))
	for i in range(1, centers.size()):
		var span := Span.new()
		span.street = street
		span.road_surface = road_surface
		span.unpaved = unpaved
		span.gravel_ranges = ROAD_DETAILS.data.gravel.get(str(street), [])
		span.edge_profiles = Walkways.edges_for(street)
		span.order = spans.size()
		span.start = centers[i - 1]
		span.end = centers[i]
		span.left = edges[i - 1]
		span.right = edges[i]
		span.length = span.start.distance_to(span.end)
		span.station = stations[i - 1]
		span.total = stations[-1]
		span.start_width = Vector2(champlain_half_width(span.station, -1), champlain_half_width(span.station, 1)) \
			if street == CHAMPLAIN else Vector2.ONE * width
		span.end_width = Vector2(champlain_half_width(stations[i], -1), champlain_half_width(stations[i], 1)) \
			if street == CHAMPLAIN else Vector2.ONE * width
		span.width = maxf(maxf(span.start_width.x, span.start_width.y), maxf(span.end_width.x, span.end_width.y))
		span.bounds = Rect2(span.start, Vector2.ZERO).expand(span.end).grow(span.width * 1.4 + 4.5)
		span.fine = downtown.intersects(span.bounds) or close_areas.any(
			func(area: Rect2) -> bool: return area.intersects(span.bounds))
		span.shoulder = .92 if street in [RIDGE, BROCKHOUSE, MARINA_APPROACH] else .63
		span.marking = Marking.SOLID if street == RIDGE else Marking.NONE
		if street == BROCKHOUSE or street == CHAMPLAIN:
			span.marking = Marking.BROKEN
		if street in HIGHWAY:
			span.shoulder = 1.55
			span.marking = Marking.HIGHWAY
			span.fine = span.bounds.grow(30.0).has_point(SIGNALS.JUNCTION)
		span.outline = PackedVector2Array([
			span.start - span.left * span.start_width.x, span.start + span.left * span.start_width.y,
			span.end + span.right * span.end_width.y, span.end - span.right * span.end_width.x])
		span.pavement_bounds = Rect2(span.outline[0], Vector2.ZERO)
		for point: Vector2 in span.outline:
			span.pavement_bounds = span.pavement_bounds.expand(point)
		spans.append(span)


func find_neighbors() -> void:
	for i in spans.size():
		var a := spans[i]
		for j in range(i + 1, spans.size()):
			var b := spans[j]
			if a.street == b.street and j == i + 1:
				continue
			if a.bounds.intersects(b.bounds):
				a.neighbors.append(b)
				b.neighbors.append(a)


func build_junction_grades() -> void:
	var junctions: Array[Junction] = []
	for a: Span in spans:
		for b: Span in a.neighbors:
			if a.order >= b.order or a.street == b.street or not a.pavement_bounds.intersects(b.pavement_bounds):
				continue
			var overlap := Geometry2D.intersect_polygons(a.outline, b.outline)
			if overlap.is_empty():
				continue
			var position: Variant = Geometry2D.segment_intersects_segment(a.start, a.end, b.start, b.end)
			if position == null:
				# Some T approaches stop at the edge of the through road.
				for tip: Vector2 in [a.start, a.end, b.start, b.end]:
					var other := b if tip in [a.start, a.end] else a
					var projected := Geometry2D.get_closest_point_to_segment(tip, other.start, other.end)
					if tip.distance_to(projected) < other.width + .35:
						position = tip.lerp(projected, .5)
						break
			if position == null:
				continue
			var center: Vector2 = position
			var inner := 5.0
			for polygon: PackedVector2Array in overlap:
				for point: Vector2 in polygon:
					inner = maxf(inner, center.distance_to(point) + .65)
			var unpaved := minf(gravel_at(a, center), gravel_at(b, center))
			var existing := junctions.find_custom(func(site: Junction) -> bool:
				return site.center.distance_squared_to(center) < 4.0 * 4.0)
			if existing >= 0:
				var previous := junctions[existing]
				previous.inner = maxf(previous.inner, minf(inner + previous.center.distance_to(center), 15.0))
				previous.gravel = minf(previous.gravel, unpaved)
				continue
			var site := Junction.new()
			site.center = center
			site.inner = minf(inner, 15.0)
			site.gravel = unpaved
			site.grade = ground.call(center.x, center.y)
			site.slope = Vector2(
				ground.call(center.x + 3.0, center.y) - ground.call(center.x - 3.0, center.y),
				ground.call(center.x, center.y + 3.0) - ground.call(center.x, center.y - 3.0)) / 6.0
			junctions.append(site)
	for span: Span in spans:
		for site: Junction in junctions:
			if span.pavement_bounds.grow(site.inner + 7.0).has_point(site.center):
				span.junctions.append(site)


func junction_grade(span: Span, point: Vector2) -> Vector3:
	var weight := 0.0
	var sum := 0.0
	var grade := 0.0
	var surface := 0.0
	for site: Junction in span.junctions:
		var offset := point - site.center
		var share := 1.0 - smoothstep(site.inner, site.inner + 7.0, offset.length())
		weight = maxf(weight, share)
		sum += share
		grade += (site.grade + site.slope.dot(offset)) * share
		surface += site.gravel * share
	return Vector3(weight, grade / maxf(.0001, sum), surface / maxf(.0001, sum))


func gravel_at(span: Span, point: Vector2) -> float:
	if span.unpaved:
		return 1.0
	var axis := (span.end - span.start) / span.length
	var station := span.station + clampf((point - span.start).dot(axis), 0.0, span.length)
	var surface := 0.0
	for section: Array in span.gravel_ranges:
		surface = maxf(surface, smoothstep(section[0] - 7.0, section[0] + 7.0, station)
			* (1.0 - smoothstep(section[1] - 7.0, section[1] + 7.0, station)))
	return surface


func build_span(span: Span) -> void:
	var spacing := .78 if span.fine else 4.6
	var divisions := maxi(1, ceili(span.length / spacing))
	var columns := PackedFloat32Array([-1.0, -.5, 0.0, .5, 1.0])
	if not span.fine:
		columns = PackedFloat32Array([-1.0, 0.0, 1.0])
	var rows := PackedFloat32Array([0.0])
	for row in divisions:
		var start := float(row) / divisions
		var finish := float(row + 1) / divisions
		var bounds := Rect2(span.start.lerp(span.end, start), Vector2.ZERO).expand(span.start.lerp(span.end, finish))
		var close := span.junctions.any(func(site: Junction) -> bool:
			return bounds.grow(site.inner + span.width + 7.0).has_point(site.center))
		var subdivisions := maxi(1, ceili(span.length / divisions / 1.15)) if close else 1
		for sub in range(1, subdivisions + 1):
			rows.append(lerpf(start, finish, float(sub) / subdivisions))
	for row in range(1, rows.size()):
		var first := rows[row - 1]
		var last := rows[row]
		var start := span.start.lerp(span.end, first)
		var end := span.start.lerp(span.end, last)
		var middle := (start + end) * .5
		var cell := Vector2i((middle / CHUNK_SIZE).floor())
		if not chunks.has(cell):
			chunks[cell] = {"asphalt": new_surface(true), "shoulder": new_surface()}
		var batch: Dictionary = chunks[cell]
		var origin := Vector2(cell) * CHUNK_SIZE
		var nearby: Array[Span] = []
		var row_bounds := Rect2(start, Vector2.ZERO).expand(end).grow(span.width + span.shoulder + 1.5)
		for other: Span in span.neighbors:
			if other.bounds.intersects(row_bounds):
				nearby.append(other)

		for col in range(1, columns.size()):
			var left := columns[col - 1] * span.width
			var right := columns[col] * span.width
			emit_strip(batch.asphalt, span, first, last, left, right, nearby, origin, false)
		var has_shoulder := shoulder_width(span, middle) > .02
		if has_shoulder or span.street != CHAMPLAIN:
			# Downtown strips are visual at the unpaved edges of the mask.
			var shoulder_key := "shoulder" if has_shoulder else "verge"
			if not batch.has(shoulder_key):
				batch[shoulder_key] = new_surface()
			var verge: SurfaceTool = batch[shoulder_key]
			for side: float in [-1.0, 1.0]:
				var edge := span.width * side
				var lip := edge + side * .09
				var outer := edge + side * span.shoulder
				emit_strip(verge, span, first, last, minf(edge, lip), maxf(edge, lip),
					nearby, origin, true)
				emit_strip(verge, span, first, last, minf(lip, outer), maxf(lip, outer),
					nearby, origin, true)
		var station := span.station + (first + last) * .5 * span.length
		if span.street == CHAMPLAIN and station >= CHAMPLAIN_WALK_START and station <= CHAMPLAIN_WALK_END.y:
			if not batch.has("sidewalk"):
				batch.sidewalk = new_surface()
			emit_champlain_sidewalk(batch.sidewalk, span, first, last, origin)


func emit_champlain_sidewalk(surface: SurfaceTool, span: Span, first: float, last: float, origin: Vector2) -> void:
	var middle := span.station + (first + last) * .5 * span.length
	for side: float in [-1.0, 1.0]:
		var end := champlain_walk_end(side)
		if middle >= end or (side < 0.0 and absf(middle - CIVIC_ACCESS.x) < CIVIC_ACCESS.y):
			continue
		for strip in 4:
			surface.set_color(Color(1, 0, 0) if strip == 1 else Color.BLACK)
			var left := strip
			var right := strip + 1
			if side < 0.0:
				left = strip + 1
				right = strip
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0),
					Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
				var edge := left if corner.y == 0 else right
				var fraction := first if corner.x == 0 else last
				var station := span.station + fraction * span.length
				var walk_width := champlain_walk_width(station, side)
				var profile := [Vector2(0, .051), Vector2(.17, .162), Vector2(.66, .158),
					Vector2(walk_width - .09, .132), Vector2(walk_width, .053)]
				var step_out: Vector2 = profile[edge]
				var street_edge := at(span, fraction, span.width * side)
				var point := street_edge + span.left.lerp(span.right, fraction) * side * step_out.x
				var ramp := smoothstep(0.0, 1.75, minf(station - CHAMPLAIN_WALK_START, end - station))
				if side < 0.0:
					var driveway := absf(station - CIVIC_ACCESS.x) - CIVIC_ACCESS.y
					var crossing := absf(station - 54.2) - .92
					ramp *= smoothstep(0.0, 1.3, minf(driveway, crossing))
				var lift := lerpf(.051, step_out.y, ramp)
				surface.set_uv(Vector2(step_out.x, station))
				surface.add_vertex(Vector3(point.x - origin.x, ground.call(point.x, point.y) + lift, point.y - origin.y))


func shoulder_width(span: Span, point: Vector2) -> float:
	# The existing downtown paving mask supplies the sidewalks and forecourts.
	# Keep the gravel off those curbed blocks.
	var curbed := downtown.has_point(point) and span.street in [CHAMPLAIN, RIDGE, 4, 11, 67]
	return 0.0 if curbed else span.shoulder


func emit_strip(surface: SurfaceTool, span: Span, first: float, last: float, left: float,
		right: float, nearby: Array[Span], origin: Vector2, shoulder: bool) -> void:
	var corners := PackedVector2Array([
		at(span, first, left), at(span, first, right),
		at(span, last, right), at(span, last, left)])
	var bounds := Rect2(corners[0], Vector2.ZERO).expand(corners[1]).expand(corners[2]).expand(corners[3])
	# Polygon operations run in the same local coordinates as the mesh.
	var to_chunk := Transform2D(0.0, -origin)
	var local_corners := to_chunk * corners
	var parts: Array[PackedVector2Array] = [local_corners]
	for other: Span in nearby:
		if (not shoulder and other.order > span.order) or not other.pavement_bounds.intersects(bounds):
			continue
		var outline := to_chunk * other.outline
		if Geometry2D.intersect_polygons(local_corners, outline).is_empty():
			continue
		var remainder: Array[PackedVector2Array] = []
		for part: PackedVector2Array in parts:
			remainder.append_array(Geometry2D.clip_polygons(part, outline))
		parts = remainder
		if parts.is_empty():
			break
	for polygon: PackedVector2Array in parts:
		for index: int in Geometry2D.triangulate_polygon(polygon):
			emit_vertex(surface, span, polygon[index] + origin, nearby, origin, shoulder)


func at(span: Span, fraction: float, lateral: float) -> Vector2:
	# Follow the same straight polygon edges used to cut intersecting spans.
	var offset := lateral / span.width
	var first := span.start + span.left * (offset * span_width_at(span, 0.0, lateral))
	var last := span.end + span.right * (offset * span_width_at(span, 1.0, lateral))
	return first.lerp(last, fraction)


func span_width_at(span: Span, fraction: float, lateral: float) -> float:
	var widths := span.start_width.lerp(span.end_width, fraction)
	return widths.x if lateral < 0.0 else widths.y


func emit_vertex(surface: SurfaceTool, span: Span, point: Vector2, nearby: Array[Span],
		origin: Vector2, shoulder: bool) -> void:
	var axis := (span.end - span.start) / span.length
	var station := span.station + clampf((point - span.start).dot(axis), 0.0, span.length)
	var lateral := (point - span.start).dot(axis.orthogonal())
	var width := span_width_at(span, (station - span.station) / span.length, lateral)
	var edge := clampf(absf(lateral) / width, 0.0, 1.0)
	var junction := junction_grade(span, point)
	var joins := 0.0
	var paint := 1.0
	for other: Span in nearby:
		var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, other.start, other.end))
		joins = maxf(joins, 1.0 - smoothstep(other.width + .22, other.width + 4.0, distance))
		paint = minf(paint, smoothstep(other.width + 1.0, other.width + 3.0, distance))
	var end_blend := smoothstep(0.0, 4.0, minf(station, span.total - station))
	# Keep the open parking frontage flush with the existing plaza apron.
	var plaza := 1.0 - smoothstep(18.0, 25.0, point.distance_to(PLAZA_FRONTAGE))
	var lift := lerpf(.116 - .061 * edge, JUNCTION_LIFT, joins)
	lift = lerpf(.018 + end_blend * (lift - .018), JUNCTION_LIFT, joins)
	lift = lerpf(lift, .026, plaza)
	var apron := apron_coverage(point)
	lift = lerpf(lift, .010, apron)
	var shoulder_mix := clampf((absf(lateral) - span.width) / span.shoulder, 0.0, 1.0)
	if shoulder:
		var drop := smoothstep(0.0, .09, absf(lateral) - span.width) * .035 * (1.0 - joins)
		lift = lerpf(lift - drop, .006, shoulder_mix)
	var transverse := 1000.0
	if span.street == CHAMPLAIN and is_equal_approx(span.station + span.length, span.total):
		# The crossing belongs at the Ridge Road end of this block.
		transverse = span.total - station
	if span.street == RIDGE:
		paint *= smoothstep(26.0, 40.0, point.distance_to(PLAZA_FRONTAGE))
	var style := float(span.marking) / 3.0
	var edges := 1.0 if span.street in HIGHWAY or (span.street == BROCKHOUSE and not downtown.has_point(point)) else 0.0
	var curb := Walkways.curb_strength(span.edge_profiles, station, signf(lateral))
	# Blue is gravel coverage on pavement and opacity on the separate shoulder mesh.
	var surface_gravel := 0.0
	if shoulder:
		surface_gravel = (1.0 - joins) * end_blend * (1.0 - apron) * (1.0 - curb)
	else:
		surface_gravel = lerpf(gravel_at(span, point), junction.z, junction.x)
		# Match the shoulder material at the asphalt lip where a soft verge exists.
		var verge := (1.0 - joins) * end_blend * (1.0 - apron) * (1.0 - curb)
		if downtown.has_point(point):
			var outside := point + axis.orthogonal() * (signf(lateral) * .4)
			verge *= 0.0 if span.street == CHAMPLAIN else unpaved_ground(outside)
		var street_wear := fposmod(float(span.street + 19) * .618034, 1.0)
		surface.set_custom(0, Color(width, verge * (1.0 - junction.x), street_wear, junction.x))
	surface.set_color(Color(style, edges, surface_gravel,
		float(span.road_surface) / float(RoadSurface.STANDARD)))
	surface.set_uv(Vector2(lateral, station))
	surface.set_uv2(Vector2(shoulder_mix if shoulder else paint * end_blend, transverse))
	var height := ground.call(point.x, point.y) as float
	var road_height := height + lift
	if not shoulder and junction.x > 0.0:
		# The shared grade follows the terrain and stays above the rendered ground.
		var shared_height := maxf(height + .041, lerpf(height, junction.y, .38) + JUNCTION_LIFT)
		road_height = lerpf(road_height, shared_height, junction.x * (1.0 - maxf(plaza, apron)))
	surface.add_vertex(Vector3(point.x - origin.x, road_height, point.y - origin.y))


func apron_coverage(point: Vector2) -> float:
	if marina_apron == null or not marina_area.has_point(point):
		return 0.0
	var uv := (point - marina_area.position) / marina_area.size
	var pixel := Vector2i(uv * Vector2(marina_apron.get_size()))
	return marina_apron.get_pixelv(pixel.min(marina_apron.get_size() - Vector2i.ONE)).r


func unpaved_ground(point: Vector2) -> float:
	if not downtown.has_point(point):
		return 1.0
	var uv := (point - downtown.position) / downtown.size
	var pixel := Vector2i(uv * Vector2(town_paving.get_size()))
	var paint := town_paving.get_pixelv(pixel)
	return 1.0 - smoothstep(.08, .65, maxf(paint.r, paint.g))


static func new_surface(pavement := false) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if pavement:
		surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	return surface


static func install(parent: Node3D, surface: SurfaceTool, origin: Vector3,
		material: Material, label: String, collision: bool, road_contact := true) -> void:
	if not surface.get_aabb().has_surface():
		return
	surface.index()
	surface.generate_normals()
	var mesh := Kit.mesh_at(parent, surface.commit(), origin, material)
	mesh.name = label
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collision:
		if road_contact:
			add_collision(mesh)
		else:
			mesh.create_trimesh_collision()


static func add_collision(mesh: MeshInstance3D) -> void:
	mesh.create_trimesh_collision()
	var body := mesh.get_child(0) as StaticBody3D
	body.collision_layer |= ROAD_LAYER
