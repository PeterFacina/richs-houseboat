extends RefCounted

const Kit = preload("res://scenery.gd")
const PublicWorks = preload("res://public_works.gd")
const CivicParking = preload("res://deep_river_civic_parking.gd")
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
const PARKING_LIMITS := Vector4(12.0, 21.0, 105.0, 115.0)
const STREET_HALF_WIDTH := 3.4
const PARKING_HALF_WIDTH := 8.7
const CHAMPLAIN_SIDEWALK_WIDTH := 1.65
const RIDGE := 49
const BROCKHOUSE := 76
const MARINA_APPROACH := 62
const PLAZA_FRONTAGE := Vector2(18025.0, 13243.0)

enum Marking { NONE, SOLID, BROKEN, HIGHWAY }

class Span:
	var street: int
	var order: int
	var start: Vector2
	var end: Vector2
	var left: Vector2
	var right: Vector2
	var length: float
	var station: float
	var total: float
	var width: float
	var start_width: float
	var end_width: float
	var shoulder: float
	var marking: Marking
	var fine: bool
	var bounds: Rect2
	var pavement_bounds: Rect2
	var outline: PackedVector2Array
	var neighbors: Array[Span] = []


var ground: Callable
var close_areas: Array[Rect2]
var downtown: Rect2
var marina_area: Rect2
var marina_apron: Image
var paved: ShaderMaterial
var gravel: ShaderMaterial
var spans: Array[Span] = []
var chunks: Dictionary = {}


func build(map: Node3D, data: Dictionary, elevation: Callable, parking_mask: Texture2D,
		detail_areas: Array[Rect2], asphalt: Texture2D, normal: Texture2D,
		stone: Texture2D, gravel_grain: Texture2D) -> void:
	ground = elevation
	close_areas = detail_areas
	var limits: Array = data.downtown_paving
	downtown = Rect2(limits[0], limits[1], limits[2] - limits[0], limits[3] - limits[1])
	paved = ShaderMaterial.new()
	paved.shader = preload("res://town_street.gdshader")
	paved.set_shader_parameter("road_scan", asphalt)
	paved.set_shader_parameter("road_normal", normal)
	paved.set_shader_parameter("asphalt_scan", gravel_grain)
	paved.set_shader_parameter("concrete_scan", stone)
	paved.set_shader_parameter("champlain_access", CIVIC_ACCESS)
	if parking_mask != null:
		marina_apron = parking_mask.get_image()
		marina_area = detail_areas[0]
		paved.set_shader_parameter("marina_paving", parking_mask)
		paved.set_shader_parameter("marina_paving_bounds", Vector4(marina_area.position.x, marina_area.position.y,
			marina_area.size.x, marina_area.size.y))
	gravel = ShaderMaterial.new()
	gravel.shader = preload("res://town_road_shoulder.gdshader")
	gravel.set_shader_parameter("asphalt_scan", asphalt)
	gravel.set_shader_parameter("concrete_scan", stone)

	# Through roads own the overlap with side streets. Draw and collide with
	# one surface in the overlap, with both approaches at the same grade.
	var streets: Array = data.streets
	add_street(HIGHWAY[0], highway_line(streets), HIGHWAY_HALF_WIDTH)
	var through := [RIDGE, DEEP_RIVER_ROAD, CHAMPLAIN, BROCKHOUSE, MARINA_APPROACH]
	for index: int in through:
		var line: Array = champlain_line(streets[index]) if index == CHAMPLAIN else streets[index]
		add_street(index, line, STREET_HALF_WIDTH)
	for index in streets.size():
		if not through.has(index) and index not in HIGHWAY:
			add_street(index, streets[index], 3.4)
	add_street(streets.size(), PublicWorks.CEDAR_ROAD, 3.4)
	add_street(streets.size() + 1, PublicWorks.YARD_DRIVE, 2.85)
	find_neighbors()
	for span: Span in spans:
		build_span(span)

	var network := Node3D.new()
	network.name = "DeepRiverRoads"
	map.add_child(network)
	var signals := SIGNALS.new()
	network.add_child(signals)
	signals.build(streets, ground)
	var sidewalk := Kit.paint(Color("#e0dacf"))
	sidewalk.albedo_texture = stone
	sidewalk.uv1_triplanar = true
	sidewalk.uv1_scale = Vector3.ONE * .55
	for cell: Vector2i in chunks:
		var batch: Dictionary = chunks[cell]
		var origin := Vector3(cell.x * CHUNK_SIZE, 0.0, cell.y * CHUNK_SIZE)
		install(network, batch.asphalt, origin, paved, "Asphalt", true)
		install(network, batch.shoulder, origin, gravel, "GravelShoulder", true)
		if batch.has("sidewalk"):
			install(network, batch.sidewalk, origin, sidewalk, "ChamplainSidewalk", true)
	var edges: Array[PackedVector2Array] = []
	for span: Span in spans:
		if CivicParking.BOUNDS.intersects(span.pavement_bounds):
			var outline := PackedVector2Array()
			for point in span.outline:
				outline.append(point - CivicParking.ORIGIN)
			edges.append(outline)
		span.neighbors.clear()
	CivicParking.new().build(network, ground, paved, edges, ROAD_LAYER)
	chunks.clear()
	spans.clear()


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
	for distance: float in [PARKING_LIMITS.x, PARKING_LIMITS.y, PARKING_LIMITS.z, PARKING_LIMITS.w]:
		var at := start + axis * distance
		points.append([at.x, at.y])
	points.append_array(line.slice(1))
	return points


static func clears_champlain_tree(point: Vector2, start: Vector2, axis: Vector2) -> bool:
	var delta := point - start
	var station := delta.dot(axis)
	return station >= PARKING_LIMITS.x and station <= PARKING_LIMITS.w and \
		absf(delta.dot(axis.orthogonal())) <= champlain_half_width(station) + CHAMPLAIN_SIDEWALK_WIDTH + .48


static func champlain_half_width(station: float) -> float:
	var taper_in := inverse_lerp(PARKING_LIMITS.x, PARKING_LIMITS.y, station)
	var taper_out := inverse_lerp(PARKING_LIMITS.w, PARKING_LIMITS.z, station)
	return lerpf(STREET_HALF_WIDTH, PARKING_HALF_WIDTH, clampf(minf(taper_in, taper_out), 0.0, 1.0))


func add_street(street: int, line: Array, width: float) -> void:
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
		span.order = spans.size()
		span.start = centers[i - 1]
		span.end = centers[i]
		span.left = edges[i - 1]
		span.right = edges[i]
		span.length = span.start.distance_to(span.end)
		span.station = stations[i - 1]
		span.total = stations[-1]
		span.start_width = champlain_half_width(span.station) if street == CHAMPLAIN else width
		span.end_width = champlain_half_width(stations[i]) if street == CHAMPLAIN else width
		span.width = maxf(span.start_width, span.end_width)
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
			span.start - span.left * span.start_width, span.start + span.left * span.start_width,
			span.end + span.right * span.end_width, span.end - span.right * span.end_width])
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


func build_span(span: Span) -> void:
	var spacing := .78 if span.fine else 4.6
	var divisions := maxi(1, ceili(span.length / spacing))
	var columns := PackedFloat32Array([-1.0, -.5, 0.0, .5, 1.0])
	if not span.fine:
		columns = PackedFloat32Array([-1.0, 0.0, 1.0])
	var first := 0.0
	for row in divisions:
		var last := float(row + 1) / divisions
		var start := span.start.lerp(span.end, first)
		var end := span.start.lerp(span.end, last)
		var middle := (start + end) * .5
		var cell := Vector2i((middle / CHUNK_SIZE).floor())
		if not chunks.has(cell):
			chunks[cell] = {"asphalt": new_surface(), "shoulder": new_surface()}
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
		if shoulder_width(span, middle) > .02:
			for side: float in [-1.0, 1.0]:
				var edge := span.width * side
				var lip := edge + side * .09
				var outer := edge + side * span.shoulder
				emit_strip(batch.shoulder, span, first, last, minf(edge, lip), maxf(edge, lip),
					nearby, origin, true)
				emit_strip(batch.shoulder, span, first, last, minf(lip, outer), maxf(lip, outer),
					nearby, origin, true)
		if span.street == CHAMPLAIN and is_equal_approx(span.start_width, PARKING_HALF_WIDTH) \
				and is_equal_approx(span.end_width, PARKING_HALF_WIDTH):
			if not batch.has("sidewalk"):
				batch.sidewalk = new_surface()
			emit_champlain_sidewalk(batch.sidewalk, span, first, last, origin)
		first = last


func emit_champlain_sidewalk(surface: SurfaceTool, span: Span, first: float, last: float, origin: Vector2) -> void:
	var middle := span.station + (first + last) * .5 * span.length
	for side: float in [-1.0, 1.0]:
		if side < 0.0 and absf(middle - CIVIC_ACCESS.x) < CIVIC_ACCESS.y:
			continue
		var profile := [Vector2(0, .049), Vector2(.16, .156), Vector2(CHAMPLAIN_SIDEWALK_WIDTH, .143)]
		for i in range(1, profile.size()):
			var left: Vector2 = profile[i - 1]
			var right: Vector2 = profile[i]
			if side < 0.0:
				left = profile[i]
				right = profile[i - 1]
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0),
					Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
				var edge := left if corner.y == 0 else right
				var fraction := first if corner.x == 0 else last
				var point := at(span, fraction, side * (PARKING_HALF_WIDTH + edge.x))
				var station := span.station + fraction * span.length
				var ramp := smoothstep(0.0, 1.4, minf(station - PARKING_LIMITS.y, PARKING_LIMITS.z - station))
				var lift := lerpf(.049, edge.y, ramp)
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
	var parts: Array[PackedVector2Array] = [corners]
	var bounds := Rect2(corners[0], Vector2.ZERO).expand(corners[1]).expand(corners[2]).expand(corners[3])
	for other: Span in nearby:
		if (not shoulder and other.order > span.order) or not other.pavement_bounds.intersects(bounds):
			continue
		if Geometry2D.intersect_polygons(corners, other.outline).is_empty():
			continue
		var remainder: Array[PackedVector2Array] = []
		for part: PackedVector2Array in parts:
			remainder.append_array(Geometry2D.clip_polygons(part, other.outline))
		parts = remainder
	for polygon: PackedVector2Array in parts:
		var local := PackedVector2Array()
		for point: Vector2 in polygon:
			local.append(point - polygon[0])
		var indices := Geometry2D.triangulate_polygon(local)
		for i in range(0, indices.size(), 3):
			for j in 3:
				var point := polygon[indices[i + j]]
				emit_vertex(surface, span, point, nearby, origin, shoulder)


func at(span: Span, fraction: float, lateral: float) -> Vector2:
	var width := lerpf(span.start_width, span.end_width, fraction)
	return span.start.lerp(span.end, fraction) + span.left.lerp(span.right, fraction) * lateral * (width / span.width)


func emit_vertex(surface: SurfaceTool, span: Span, point: Vector2, nearby: Array[Span],
		origin: Vector2, shoulder: bool) -> void:
	var axis := (span.end - span.start) / span.length
	var station := span.station + clampf((point - span.start).dot(axis), 0.0, span.length)
	var lateral := (point - span.start).dot(axis.orthogonal())
	var width := lerpf(span.start_width, span.end_width, (station - span.station) / span.length)
	var edge := clampf(absf(lateral) / width, 0.0, 1.0)
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
	surface.set_color(Color(style, edges, (1.0 - joins) * end_blend * (1.0 - apron),
		0.0 if span.street == CHAMPLAIN else 1.0))
	surface.set_uv(Vector2(lateral, station))
	surface.set_uv2(Vector2(shoulder_mix if shoulder else paint * end_blend, transverse))
	var height := ground.call(point.x, point.y) as float
	surface.add_vertex(Vector3(point.x - origin.x, height + lift, point.y - origin.y))


func apron_coverage(point: Vector2) -> float:
	if marina_apron == null or not marina_area.has_point(point):
		return 0.0
	var uv := (point - marina_area.position) / marina_area.size
	var pixel := Vector2i(uv * Vector2(marina_apron.get_size()))
	return marina_apron.get_pixelv(pixel.min(marina_apron.get_size() - Vector2i.ONE)).r


static func new_surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


static func install(parent: Node3D, surface: SurfaceTool, origin: Vector3,
		material: Material, label: String, collision: bool) -> void:
	if not surface.get_aabb().has_surface():
		return
	surface.index()
	surface.generate_normals()
	var mesh := Kit.mesh_at(parent, surface.commit(), origin, material)
	mesh.name = label
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collision:
		add_collision(mesh)


static func add_collision(mesh: MeshInstance3D) -> void:
	mesh.create_trimesh_collision()
	var body := mesh.get_child(0) as StaticBody3D
	body.collision_layer |= ROAD_LAYER
