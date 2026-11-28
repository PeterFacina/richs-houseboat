extends RefCounted

# The same surveyed geometry and paint masks used by the terrain and road builders.
const Roads = preload("res://deep_river_roads.gd")
const CivicParking = preload("res://deep_river_civic_parking.gd")
const PublicWorks = preload("res://public_works.gd")
const EssoPlaza = preload("res://deep_river_esso_plaza.gd")
const LamurePlayground = preload("res://lamure_playground.gd")
const CELL := 32.0
const CLEARANCE := .35
const OFFSETS := [Vector2.ZERO, Vector2(.35, 0), Vector2(-.35, 0), Vector2(0, .35),
	Vector2(0, -.35), Vector2(.2475, .2475), Vector2(-.2475, .2475),
	Vector2(.2475, -.2475), Vector2(-.2475, -.2475)]

var world
var park
var driveways
var roads := {}
var buildings := {}
var marina_reserved := []
var park_lookout := {}
var mowing := []
var paths := {}
var masks := []
var ready := false
var slope_cache := {}


func index_roads(spans: Array) -> void:
	for span in spans:
		index(roads, span.bounds, span)


func index_buildings(layout: Dictionary) -> void:
	for building: Dictionary in layout.buildings:
		var polygon := PackedVector2Array()
		for wall: Array in building.walls:
			polygon.append(Vector2(wall[0][0], wall[0][1]))
		if polygon.size() >= 3:
			var box: Array = building.box
			var bounds := Rect2(box[0], box[1], box[2] - box[0], box[3] - box[1]).grow(CLEARANCE * 2.0)
			index(buildings, bounds, {"bounds": bounds, "polygon": polygon})


func index(grid: Dictionary, bounds: Rect2, item: Variant) -> void:
	var first := Vector2i((bounds.position / CELL).floor())
	var last := Vector2i((bounds.end / CELL).floor())
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			var cell := Vector2i(x, z)
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(item)


func finish(map, riverbank_park) -> void:
	world = map
	park = riverbank_park
	var base := "res://deep_river/"
	var paving: Array = map.meta.downtown_paving
	add_mask(base + "deep_river_paving.png", Vector4(paving[0], paving[1], paving[2] - paving[0], paving[3] - paving[1]), .08, 0)
	add_mask(base + "marina_paving.png", map.patch_bounds(map.marina_patch), .08, 1)
	add_mask(base + "swisha_shoals.png", map.patch_bounds(map.swisha_patch), .08, 2)
	if map.meta.has("brockhouse"):
		var campus: Array = map.meta.brockhouse.bounds
		add_mask(base + "brockhouse_surface.png", Vector4(campus[0], campus[1], campus[2], campus[3]), .08, 3)
	if map.meta.has("riverbank"):
		var path := Image.load_from_file(base + "riverbank_surface.png")
		if path != null:
			park.clear_old_path_paint(path)
			masks.append([path, Vector4(park.bounds.position.x, park.bounds.position.y,
				park.bounds.size.x, park.bounds.size.y), .08, 3])
	if map.meta.has("lamure"):
		var paint: Array = map.meta.lamure.paint_bounds
		add_mask(base + "lamure_surface.png", Vector4(paint[0], paint[1], paint[2], paint[3]), .03, 0)
	var marina: Dictionary = map.meta.marina
	for area_name: String in ["buildings", "tennis", "boat_launch"]:
		if not marina.has(area_name):
			continue
		var outlines: Array = marina[area_name] if area_name == "buildings" else [marina[area_name]]
		for outline: Array in outlines:
			var polygon := PackedVector2Array()
			for corner: Array in outline:
				polygon.append(Vector2(corner[0], corner[1]))
			marina_reserved.append({"bounds": polygon_bounds(polygon).grow(CLEARANCE), "polygon": polygon})
	for route: Dictionary in map.waterfront.mowing_routes:
		for zone: PackedVector2Array in route.zones:
			mowing.append({"bounds": polygon_bounds(zone).grow(CLEARANCE), "polygon": zone})
	for line: Array in marina.get("dock_access", []):
		add_path(line, 2.0)
	for trail: PackedVector2Array in park.trails:
		add_path(trail, 2.6)
	park_lookout = {"bounds": polygon_bounds(park.lookout).grow(CLEARANCE),
		"polygon": park.lookout}
	if map.meta.has("brockhouse"):
		for line: Array in map.meta.brockhouse.walkways:
			add_path(line, 1.85)
	if map.meta.has("lamure"):
		add_path(map.meta.lamure.access_mat, LamurePlayground.MAT_HALF_WIDTH + CLEARANCE)
	var expected := 3 + int(map.meta.has("brockhouse")) + int(map.meta.has("riverbank")) + int(map.meta.has("lamure"))
	ready = masks.size() == expected and not roads.is_empty() and driveways != null
	if not ready:
		push_error("World grass disabled: geographic surface data is incomplete")


func add_mask(path: String, bounds: Vector4, cutoff: float, channel: int) -> void:
	var image := Image.load_from_file(path)
	if image == null:
		return
	masks.append([image, bounds, cutoff, channel])


func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for corner: Vector2 in polygon:
		bounds = bounds.expand(corner)
	return bounds


func polygon_blocks(point: Vector2, polygon: PackedVector2Array, extra := 0.0) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		if point.distance_squared_to(closest) < (CLEARANCE + extra) * (CLEARANCE + extra):
			return true
	return false


func add_path(line, radius: float) -> void:
	for i in range(1, line.size()):
		var a := Vector2(line[i - 1][0], line[i - 1][1])
		var b := Vector2(line[i][0], line[i][1])
		var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(radius + CLEARANCE)
		index(paths, bounds, {"bounds": bounds, "a": a, "b": b, "radius": radius})


func sample_mask(mask: Array, point: Vector2) -> float:
	var bounds: Vector4 = mask[1]
	var uv := (point - Vector2(bounds.x, bounds.y)) / Vector2(bounds.z, bounds.w)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return 0.0
	var image: Image = mask[0]
	var pixel := image.get_pixelv(Vector2i(uv * Vector2(image.get_size())).min(image.get_size() - Vector2i.ONE))
	match int(mask[3]):
		0: return maxf(pixel.r, pixel.g)
		1: return pixel.r
		2: return pixel.b
		_: return maxf(maxf(pixel.r, pixel.g), pixel.b)


func relevant_masks(area: Rect2) -> Array:
	var relevant := []
	for mask: Array in masks:
		var bounds: Vector4 = mask[1]
		var domain := Rect2(bounds.x, bounds.y, bounds.z, bounds.w)
		if not domain.intersects(area):
			continue
		var overlap := domain.intersection(area)
		var image: Image = mask[0]
		var first := Vector2i(((overlap.position - domain.position) / domain.size) * Vector2(image.get_size()))
		var last := Vector2i(((overlap.end - domain.position) / domain.size) * Vector2(image.get_size()))
		var found := false
		for y in range(maxi(0, first.y), mini(image.get_height(), last.y + 1)):
			for x in range(maxi(0, first.x), mini(image.get_width(), last.x + 1)):
				var pixel := image.get_pixel(x, y)
				var value := maxf(pixel.r, pixel.g) if mask[3] == 0 else (pixel.r if mask[3] == 1 else \
					(pixel.b if mask[3] == 2 else maxf(maxf(pixel.r, pixel.g), pixel.b)))
				if value > float(mask[2]):
					found = true
					break
			if found:
				break
		if found:
			relevant.append(mask)
	return relevant


func paved(point: Vector2, nearby_masks: Array, extra := 0.0) -> bool:
	for mask: Array in nearby_masks:
		for offset: Vector2 in OFFSETS:
			if sample_mask(mask, point + offset) > float(mask[2]) or (extra > 0.0 and \
					sample_mask(mask, point + offset * (1.0 + extra / CLEARANCE)) > float(mask[2])):
				return true
	return false


func road_or_walk(point: Vector2, extra := 0.0) -> bool:
	for span in roads.get(Vector2i((point / CELL).floor()), []):
		if not span.bounds.has_point(point):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(point, span.start, span.end)
		var station: float = span.station + span.start.distance_to(closest)
		var exclusion: float = span.width + span.shoulder + CLEARANCE + extra
		for section: Array in span.edge_profiles:
			if station >= float(section[0]) - CLEARANCE and station <= float(section[1]) + CLEARANCE:
				exclusion = maxf(exclusion, span.width + float(section[3]) + float(section[4]) + CLEARANCE + extra)
		if point.distance_squared_to(closest) <= exclusion * exclusion:
			return true
	return false


func occupied(point: Vector2, extra := 0.0) -> bool:
	for path: Dictionary in paths.get(Vector2i((point / CELL).floor()), []):
		if path.bounds.grow(extra).has_point(point) and point.distance_squared_to(
				Geometry2D.get_closest_point_to_segment(point, path.a, path.b)) < (path.radius + extra) * (path.radius + extra):
			return true
	if CivicParking.covers(point) or (extra > 0.0 and CivicParking.BOUNDS.grow(extra).has_point(point) \
			and (polygon_blocks(point, PackedVector2Array(CivicParking.LOT), extra) \
			or polygon_blocks(point, PackedVector2Array(CivicParking.APRON), extra))) \
			or PublicWorks.cleared_for_construction(Vector3(point.x, 0, point.y)) \
			or EssoPlaza.clears_tree(point):
		return true
	for route: Dictionary in driveways.near(driveways.occupied, point):
		var closest := Geometry2D.get_closest_point_to_segment(point, route.entry, route.end)
		if point.distance_squared_to(closest) < (2.35 + extra) * (2.35 + extra):
			return true
	for site: Dictionary in buildings.get(Vector2i((point / CELL).floor()), []):
		if site.bounds.grow(extra).has_point(point) and polygon_blocks(point, site.polygon, extra):
			return true
	if park.bounds.grow(3.0).has_point(point):
		if park.in_parking(point) or park.in_amphitheatre(point):
			return true
		if park_lookout.bounds.grow(extra).has_point(point) and polygon_blocks(point, park_lookout.polygon, extra):
			return true
	if world.marina_patch.area.grow(2.0 + extra).has_point(point):
		for site: Dictionary in marina_reserved:
			if site.bounds.grow(extra).has_point(point) and polygon_blocks(point, site.polygon, extra):
				return true
		for site: Dictionary in mowing:
			if site.bounds.grow(extra).has_point(point) and polygon_blocks(point, site.polygon, extra):
				return true
		var at := Vector3(point.x, world.ground_height(point.x, point.y), point.y)
		if world.waterfront.docks.bounds.grow(CLEARANCE + extra).has_point(point):
			for offset: Vector2 in OFFSETS:
				var scaled := offset * (1.0 + extra / CLEARANCE)
				if world.waterfront.docks.blocks(at + Vector3(scaled.x, 0, scaled.y)):
					return true
	return false


func grass_height(point: Vector2, nearby_masks: Array, extra := 0.0) -> float:
	if not ready or point.x < 1.0 or point.y < 1.0 or point.x > world.extent.x - 1.0 \
			or point.y > world.extent.y - 1.0:
		return -INF
	if road_or_walk(point, extra) or paved(point, nearby_masks, extra) or occupied(point, extra):
		return -INF
	var height: float = world.ground_height(point.x, point.y)
	var water_gap: float = world.wet_clearance(Vector3(point.x, height, point.y))
	if height < .28 or water_gap > 0.0:
		return -INF
	if water_gap > -CLEARANCE - extra:
		for offset: Vector2 in OFFSETS:
			var scaled := offset * (1.0 + extra / CLEARANCE)
			if world.wet_clearance(Vector3(point.x + scaled.x, height, point.y + scaled.y)) > 0.0:
				return -INF
	var cell := Vector2i(point.floor())
	var grade: int = slope_cache.get(cell, 0)
	if grade == 0:
		var center := Vector2(cell) + Vector2.ONE * .5
		var sx: float = world.ground_height(center.x + 1.0, center.y) - world.ground_height(center.x - 1.0, center.y)
		var sz: float = world.ground_height(center.x, center.y + 1.0) - world.ground_height(center.x, center.y - 1.0)
		var slope := sx * sx + sz * sz
		grade = 1 if slope < .35 else (2 if slope > 1.4 else 3)
		slope_cache[cell] = grade
	if grade == 1:
		return height
	if grade == 2:
		return -INF
	var dx: float = world.ground_height(point.x + .7, point.y) - world.ground_height(point.x - .7, point.y)
	var dz: float = world.ground_height(point.x, point.y + .7) - world.ground_height(point.x, point.y - .7)
	return height if dx * dx + dz * dz < 1.0 else -INF # Exposed rock and steep faces.
