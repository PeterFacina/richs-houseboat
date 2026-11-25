extends RefCounted

const GAZEBO_FOOTPRINT := "411204346"
const GAZEBO_SITE := Vector2(18219.3688, 13123.3505)
const ALONG_ROAD := Vector2(.61675, .78716)
const TOWARD_WATER := Vector2(.78716, -.61675)
const PARKING_ORIGIN := Vector2(18220.8982, 13147.5428)
const AMPHITHEATRE := PARKING_ORIGIN - ALONG_ROAD * 81.1
const TIER_COUNT := 6
const HALF_WIDTH := 10.3
const SEATING_ARC := 1.49
const ROAD_SETBACK := 9.2
const WALK_SETBACK := 3.0
const AISLE_HALF_WIDTH := .85
# Survey metres from the Brockhouse bend, increasing toward the amphitheatre.
# The gazebo footprint fixes the position and scale of the aerial measurements.
const PARKING_START := 34.0
const PARKING_END := 72.5
const PARKING_DEPTH := 8.65
const PARKING_AISLE := Vector2(50.2, 52.9)
const PARKING_TAPERS := Vector2(26.5, 79.5)
const STREET_HALF_WIDTH := 3.4
const PARKING_ROWS := [38.2, 42.4, 46.5, PARKING_AISLE.x, PARKING_AISLE.y, 56.3, 59.6, 63.0, 66.3]
const LOOKOUT_EDGE := [
	Vector2(16, 11.7), Vector2(20, 10.3), Vector2(25.8, 9.5), Vector2(30.4, 6.05),
	Vector2(35.4, 8.32), Vector2(41, 9.35), Vector2(49.9, 8.52), Vector2(53.2, 8.52),
	Vector2(58, 9.58), Vector2(65.9, 9.55), Vector2(71.3, 10.3), Vector2(73.1, 11.8),
	Vector2(70.2, 14.7), Vector2(62.5, 16.1), Vector2(50, 15.7), Vector2(39, 16.5),
	Vector2(28.2, 17.45), Vector2(21.0, 18.3), Vector2(16.3, 17.2), Vector2(14.7, 14.4),
]
const AMPHITHEATRE_ACCESS := [
	Vector2(97.0, 4.3), Vector2(97.0, 7.2), Vector2(96.2, 10.8),
	Vector2(94.25, 15.0), Vector2(94.0, 20.4), Vector2(92, 27.5),
]
const Kit = preload("res://scenery.gd")
const Beach = preload("res://lamure_beach.gd")
const Marina = preload("res://marina_art.gd")
const Pines = preload("res://lamure_pines.gd")

var bounds := Rect2()
var layout: Dictionary
var trails: Array[PackedVector2Array] = []
var groves: Array[PackedVector2Array] = []
var lookout := PackedVector2Array()
var ground: Callable
var random := RandomNumberGenerator.new()


func prepare(definition: Dictionary) -> void:
	layout = definition
	var paint: Array = layout.paint_bounds
	bounds = Rect2(paint[0], paint[1], paint[2], paint[3])
	trails.append(points(layout.pier_approach))
	var lower_walk := points(layout.promenade).slice(0, 12)
	lower_walk.append_array(survey_points([Vector2(108, 26), Vector2(92, 27.5), Vector2(79, 29.4),
		Vector2(62, 29.6), Vector2(46, 27.7), Vector2(32, 24.25), Vector2(22, 21.0), Vector2(17, 17.25)]))
	trails.append(lower_walk)
	var beach_walk := survey_points([Vector2(16.4, 14.6), Vector2(12.4, 10.6), Vector2(8.0, 8.15)])
	beach_walk.append_array(points(layout.beach_link).slice(6))
	trails.append(beach_walk)
	trails.append(PackedVector2Array([Vector2(17982.2319, 12637.6974), Vector2(17977.6, 12643.6),
		Vector2(17976.0, 12653.8)]))
	trails.append(survey_points(AMPHITHEATRE_ACCESS))
	lookout = survey_points(LOOKOUT_EDGE)
	for polygon: Array in layout.woodland:
		groves.append(points(polygon))


func near_trail(location: Vector2, clearance := 2.25) -> bool:
	if not bounds.has_point(location):
		return false
	if Geometry2D.is_point_in_polygon(location, lookout):
		return true
	for trail in trails:
		for index in range(1, trail.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(location, trail[index - 1], trail[index])
			if nearest.distance_squared_to(location) < clearance * clearance:
				return true
	return false


func owns_tree(foot: Vector3) -> bool:
	var location := Vector2(foot.x, foot.z)
	if not bounds.has_point(location):
		return false
	return in_amphitheatre(location) or in_parking(location) or groves.any(func(polygon: PackedVector2Array) -> bool:
		return Geometry2D.is_point_in_polygon(location, polygon)) or near_trail(location)


func grade_parking(source: PackedFloat32Array, grid: Vector2i, origin: Vector2,
		spacing: float, sample_height: Callable) -> PackedFloat32Array:
	var stations := PackedFloat32Array()
	for station in range(0, 106, 2):
		var at := parking_point(float(station), 0.0)
		stations.append(sample_height.call(at.x, at.y))
	var area := Rect2(parking_point(21.0, 0.0), Vector2.ZERO)
	for corner: Vector2 in [parking_point(21, 16), parking_point(86, 0), parking_point(86, 16)]:
		area = area.expand(corner)
	var first := Vector2i(((area.position - origin) / spacing).floor()).max(Vector2i.ZERO)
	var last := Vector2i(((area.end - origin) / spacing).ceil()).min(grid - Vector2i.ONE)
	for row in range(first.y, last.y + 1):
		for col in range(first.x, last.x + 1):
			var point := origin + Vector2(col, row) * spacing
			var site := survey_at(point)
			var station := clampf(site.x, 0.0, 102.0) / 2.0
			var i := floori(station)
			var road_level := lerpf(stations[i], stations[i + 1], station - i)
			var width := shelf_width(site.x)
			var along := smoothstep(21.0, PARKING_TAPERS.x, site.x) * (1.0 - smoothstep(PARKING_TAPERS.y, 86.0, site.x))
			var across := smoothstep(.5, 2.8, site.y) * (1.0 - smoothstep(width + 1.75, width + 4.6, site.y))
			# Keep the shelf at the road's longitudinal grade with a light drainage crossfall.
			var level := road_level - site.y * .012
			var index := row * grid.x + col
			source[index] = lerpf(source[index], level, along * across)
	return source


func clear_old_path_paint(surface: Image) -> void:
	var area := Rect2(parking_point(8.0, 3.0), Vector2.ZERO)
	for corner: Vector2 in [parking_point(8, 26), parking_point(100, 3), parking_point(100, 26)]:
		area = area.expand(corner)
	var pixels := Vector2(surface.get_size())
	var pixel_size := bounds.size / pixels
	var first := Vector2i(((area.position - bounds.position) / pixel_size).floor()).max(Vector2i.ZERO)
	var last := Vector2i(((area.end - bounds.position) / pixel_size).ceil()).min(surface.get_size() - Vector2i.ONE)
	for row in range(first.y, last.y + 1):
		for col in range(first.x, last.x + 1):
			var point := bounds.position + (Vector2(col, row) + Vector2(.5, .5)) * pixel_size
			var site := survey_at(point)
			var keep := 1.0 - smoothstep(8.0, 11.0, site.x) * (1.0 - smoothstep(96.0, 100.0, site.x))
			keep = maxf(keep, 1.0 - smoothstep(3.0, 4.4, site.y) * (1.0 - smoothstep(23.5, 26.0, site.y)))
			if keep < 1.0:
				surface.set_pixel(col, row, surface.get_pixel(col, row).lerp(Color.BLACK, 1.0 - keep))


func build(parent: Node3D, survey: PackedFloat32Array, marina: Marina, pines: Pines,
		elevation: Callable, clearance: Callable, stone_scan: Texture2D) -> void:
	ground = elevation
	random.seed = 81619
	var park := Node3D.new()
	park.name = "RiverbankPark"
	parent.add_child(park)
	var timber := marina.weathered_wood(Color("#79634f"), false)
	var stone := Kit.paint(Color("#988f83"), .91)
	stone.albedo_texture = stone_scan
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE * .77
	var shelter := marina.build_pavilion(park, on_land(GAZEBO_SITE), Color("#455e53"), Color("#637368"))
	shelter.name = "RiverbankLookoutShelter"
	shelter.rotation.y = -.042
	shelter.scale = Vector3(.79, .84, .76)
	for x: float in [-3.54, 0.0, 3.54]:
		for z: float in [-2.21, 2.21]:
			var cap := shelter.to_global(Vector3(x, .035, z))
			var bottom := ground.call(cap.x, cap.z) as float
			var height := cap.y - bottom + .16
			if height > .19:
				var footing := Kit.box_at(park, cap - Vector3.UP * height * .5,
					Vector3(.52, height, .54), stone)
				footing.rotation.y = shelter.rotation.y
	var floor_body := StaticBody3D.new()
	shelter.add_child(floor_body)
	Kit.collider(floor_body, Vector3(0, .09, 0), Vector3(8.64, .24, 5.76))
	for index in layout.seats.size():
		var seat := Beach.build_bench(park, on_land(pair(layout.seats[index])), timber)
		seat.name = "RiverbankBench%d" % (index + 1)
		seat.rotation.y = -.66 if index < 4 else -.16
	build_river_walk(park, stone_scan, parent.concrete_scan)
	build_waterfront_parking(park)
	build_terraces(park, stone)
	build_waterfront_stones(park, stone, clearance)
	build_flag(park, on_land(parking_point(32.25, 17.45)))
	build_flag(park, on_land(parking_point(34.0, 17.60)))
	build_sign(park, on_land(Vector2(18024.4, 12648.8)), Vector3(1, 0, -.15),
		"RIVERBANK PARK\nFootpath to Lamure Beach", timber)
	build_sign(park, on_land(Vector2(18202.0, 13123.8)), Vector3(.7, 0, -.7),
		"LAMURE BEACH\nFollow the gravel path", timber)
	build_sign(park, on_land(Vector2(18543.0, 13223.8)), Vector3(.96, 0, -.27),
		"RIVERBANK PARK\nFootpath to the marina", timber)

	var local := PackedFloat32Array()
	for i in range(0, survey.size(), 3):
		var foot := Vector3(survey[i], 0, survey[i + 1])
		var location := Vector2(foot.x, foot.z)
		if (owns_tree(foot) and not in_amphitheatre(location) and not in_parking(location)
				and not near_trail(location, 2.8) and location.distance_squared_to(GAZEBO_SITE) > 36.0):
			local.append(foot.x)
			local.append(foot.z)
			local.append(survey[i + 2])
	marina.build_canopy(park, local, Rect2(), clearance,
		func(foot: Vector3, height: float) -> bool:
			if height < 8.0 or random.randf() > .53:
				return false
			pines.plant(foot, height, random)
			return true)
	build_verge(park, marina, clearance)


static func in_amphitheatre(at: Vector2) -> bool:
	var offset := at - AMPHITHEATRE
	var depth := offset.dot(TOWARD_WATER)
	return depth > ROAD_SETBACK and depth < 27.0 and absf(offset.dot(ALONG_ROAD)) < HALF_WIDTH + 1.0


func build_river_walk(park: Node3D, grit: Texture2D, concrete: Texture2D) -> void:
	var path_mesh := SurfaceTool.new()
	path_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	path_mesh.set_normal(Vector3.UP)
	for trail_index in trails.size():
		var trail := trails[trail_index]
		var pavers := 1.0 if trail_index == trails.size() - 1 else 0.0
		var half_width := .90 if pavers > .0 else 1.34
		var edges := PackedVector2Array()
		for i in trail.size():
			var a := (trail[i] - trail[maxi(0, i - 1)]).normalized().orthogonal()
			var b := (trail[mini(i + 1, trail.size() - 1)] - trail[i]).normalized().orthogonal()
			edges.append((a + b).normalized() * (half_width / maxf(.72, absf((a + b).length() * .5))))
		for i in range(1, trail.size()):
			var count := maxi(2, ceili(trail[i - 1].distance_to(trail[i]) / .74))
			for j in count:
				for u in 4:
					for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
						var along := (j + uv.y) / count
						var across := (u + uv.x) / 4
						var center := trail[i - 1].lerp(trail[i], along)
						var edge := edges[i - 1].lerp(edges[i], along)
						var foot := on_land(center + edge * (across * 2.0 - 1.0))
						path_mesh.set_color(Color(pavers, 0.0, 0.0))
						path_mesh.set_uv(Vector2(across, along))
						path_mesh.add_vertex(foot + Vector3.UP * .041)
	build_lookout_paving(path_mesh)
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://riverbank_walk.gdshader")
	finish.set_shader_parameter("grit", grit)
	finish.set_shader_parameter("concrete_scan", concrete)
	finish.set_shader_parameter("parking_origin", PARKING_ORIGIN)
	finish.set_shader_parameter("parking_axis", ALONG_ROAD)
	finish.set_shader_parameter("parking_extent", Vector4(PARKING_TAPERS.x, PARKING_START, PARKING_END, PARKING_TAPERS.y))
	finish.set_shader_parameter("parking_depth", PARKING_DEPTH)
	var walk := Kit.mesh_at(park, path_mesh.commit(), Vector3.ZERO, finish)
	walk.name = "GazeboRiverWalk"
	walk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_lookout_paving(surface: SurfaceTool) -> void:
	var outline := PackedVector2Array(LOOKOUT_EDGE)
	var area := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline:
		area = area.expand(point)
	var spacing := .75
	var size := Vector2i((area.size / spacing).ceil())
	for row in size.y:
		for col in size.x:
			var a := area.position + Vector2(col, row) * spacing
			var cell := PackedVector2Array([a, a + Vector2(spacing, 0), a + Vector2.ONE * spacing, a + Vector2(0, spacing)])
			for section: PackedVector2Array in Geometry2D.intersect_polygons(outline, cell):
				for vertex in Geometry2D.triangulate_polygon(section):
					var p := section[vertex]
					surface.set_color(Color(1.0, 0.0, 0.0))
					surface.set_uv(Vector2(.5, 0.0))
					surface.add_vertex(on_land(parking_point(p.x, p.y)) + Vector3.UP * .059)


static func parking_point(station: float, depth: float) -> Vector2:
	return PARKING_ORIGIN - ALONG_ROAD * station + TOWARD_WATER * depth


static func survey_at(point: Vector2) -> Vector2:
	var offset := point - PARKING_ORIGIN
	return Vector2(-offset.dot(ALONG_ROAD), offset.dot(TOWARD_WATER))


static func survey_points(local: Array) -> PackedVector2Array:
	var world := PackedVector2Array()
	for point: Vector2 in local:
		world.append(parking_point(point.x, point.y))
	return world


static func parking_road(line: Array) -> Array:
	var result := line.slice(0, 2)
	for station: float in [PARKING_TAPERS.x, PARKING_START, PARKING_END, PARKING_TAPERS.y]:
		var point := parking_point(station, 0.0)
		result.append([point.x, point.y])
	result.append_array(line.slice(2))
	return result


static func parking_half_width(point: Vector2, street_width: float) -> float:
	var site := survey_at(point)
	if absf(site.y) > .15:
		return street_width
	return shelf_width(site.x, street_width)


static func shelf_width(station: float, street_width := STREET_HALF_WIDTH) -> float:
	var extent := clampf(minf((station - PARKING_TAPERS.x) / (PARKING_START - PARKING_TAPERS.x),
		(PARKING_TAPERS.y - station) / (PARKING_TAPERS.y - PARKING_END)), 0.0, 1.0)
	return lerpf(street_width, PARKING_DEPTH, extent)


static func in_parking(point: Vector2) -> bool:
	var site := survey_at(point)
	return site.x > PARKING_TAPERS.x and site.x < 98.0 and site.y > 2.5 and site.y < shelf_width(site.x) + 2.8


func build_waterfront_parking(park: Node3D) -> void:
	# Bays and the gate follow the May 2025 Brockhouse Way waterfront reference.
	var markings := SurfaceTool.new()
	markings.begin(Mesh.PRIMITIVE_TRIANGLES)
	markings.set_normal(Vector3.UP)
	for station: float in PARKING_ROWS:
		parking_stripe(markings, Vector2(station, 3.62), Vector2(station, 8.44))
	parking_hatch(markings, [Vector2(28.2, 3.62), Vector2(33.9, 8.42),
		Vector2(38.2, 8.42), Vector2(38.2, 3.62)])
	parking_hatch(markings, [Vector2(PARKING_AISLE.x, 3.62), Vector2(PARKING_AISLE.x, 8.43),
		Vector2(PARKING_AISLE.y, 8.43), Vector2(PARKING_AISLE.y, 3.62)])
	parking_hatch(markings, [Vector2(66.3, 3.62), Vector2(66.3, 8.42),
		Vector2(72.3, 8.42), Vector2(77.5, 3.62)])
	var access := Vector2(48.3, 6.0)
	var wheel := access + Vector2(-.14, -.06)
	# Accessible bay marking, oriented to be readable from the travel lane.
	for i in 22:
		var a := .22 + float(i) * 4.9 / 22.0
		var b := .22 + float(i + 1) * 4.9 / 22.0
		parking_stripe(markings, wheel + Vector2.from_angle(a) * .29,
			wheel + Vector2.from_angle(b) * .29, .075)
	for stroke: Vector4 in [Vector4(.055, .42, .025, .02), Vector4(.055, .22, -.23, .22),
			Vector4(.025, .02, .30, .02), Vector4(.30, .02, .44, -.26), Vector4(.44, -.26, .58, -.22)]:
		parking_stripe(markings, access + Vector2(stroke.x, stroke.y),
			access + Vector2(stroke.z, stroke.w), .078)
	parking_stripe(markings, access + Vector2(.055, .56), access + Vector2(.055, .62), .14)
	var paint := Kit.paint(Color("#e4dfd3"), .93)
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var striping := Kit.mesh_at(park, markings.commit(), Vector3.ZERO, paint)
	striping.name = "WaterfrontParkingStriping"
	striping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var iron := Kit.paint(Color("#2d3030"), .59, .63)
	build_railing(park, "WaterfrontParkingRailing", survey_points([
		Vector2(33.9, 8.89), Vector2(38, 8.89), Vector2(43, 8.89), Vector2(50.12, 8.89),
	]), iron, true)
	build_railing(park, "AmphitheatreRoadRailing", survey_points([
		Vector2(53.02, 8.89), Vector2(64.5, 8.89), Vector2(71, 8.89), Vector2(75.7, 6.74),
		Vector2(81.4, 5.55), Vector2(87.7, 5.13), Vector2(92.4, 5.46), Vector2(92.7, 7.18),
	]), iron, true)
	for side: float in [-1.0, 1.0]:
		var rail: Array[Vector2] = []
		for step: Vector2 in AMPHITHEATRE_ACCESS.slice(0, 5):
			rail.append(step + Vector2(side * .98, 0.0))
		var label := "AmphitheatrePathHandrailGazeboSide" if side < 0.0 else "AmphitheatrePathHandrailMarinaSide"
		build_railing(park, label, survey_points(rail), iron, false)


func parking_hatch(surface: SurfaceTool, outline: Array) -> void:
	var start := float(outline[0].x)
	var finish := start
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		start = minf(start, a.x)
		finish = maxf(finish, a.x)
		parking_stripe(surface, a, b, .10)
	for i in ceili((finish - start + 2.1) / .81):
		var station := start - 1.7 + float(i) * .81
		var a := Vector2(station, 3.1)
		var b := a + Vector2(2.2, 6.0)
		var hits: Array[Vector2] = []
		for j in outline.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, outline[j], outline[(j + 1) % outline.size()])
			if hit is Vector2:
				hits.append(hit)
		if hits.size() == 2 and hits[0].distance_to(hits[1]) > .16:
			parking_stripe(surface, hits[0], hits[1], .093)


func parking_stripe(surface: SurfaceTool, a: Vector2, b: Vector2, width := .10) -> void:
	var segments := maxi(1, ceili(a.distance_to(b) / .36))
	var side := (b - a).orthogonal().normalized() * width * .5
	for i in segments:
		var start := a.lerp(b, float(i) / segments)
		var finish := a.lerp(b, float(i + 1) / segments)
		for p: Vector2 in [start - side, start + side, finish - side,
				finish - side, start + side, finish + side]:
			var lift := lerpf(.116, .055, p.y / shelf_width(p.x))
			surface.add_vertex(on_land(parking_point(p.x, p.y)) + Vector3.UP * (lift + .020))


func build_railing(park: Node3D, label: String, path: PackedVector2Array, iron: Material, pickets: bool) -> void:
	var fence := StaticBody3D.new()
	fence.name = label
	park.add_child(fence)
	var bars: Array[Transform3D] = []
	for index in range(1, path.size()):
		var panels := maxi(1, ceili(path[index - 1].distance_to(path[index]) / 2.1))
		var start := on_land(path[index - 1])
		if index == 1:
			bars.append(rail_post(start))
		for panel in range(1, panels + 1):
			var finish := on_land(path[index - 1].lerp(path[index], float(panel) / panels))
			bars.append(rail_post(finish))
			for height: float in [.18 if pickets else .55, 1.01]:
				Kit.beam(fence, start + Vector3.UP * height, finish + Vector3.UP * height, .041, iron)
			if pickets:
				var steps := maxi(1, ceili(start.distance_to(finish) / .165))
				for bar in range(1, steps):
					var at := start.lerp(finish, float(bar) / steps) + Vector3.UP * .594
					bars.append(Transform3D(Basis.from_scale(Vector3(.024, .833, .024)), at))
			var shape := BoxShape3D.new()
			shape.size = Vector3(.075, 1.04 if pickets else .63, start.distance_to(finish))
			var collision := CollisionShape3D.new()
			collision.shape = shape
			fence.add_child(collision)
			collision.position = start.lerp(finish, .5) + Vector3.UP * (.53 if pickets else .71)
			collision.look_at_from_position(collision.position, finish + Vector3.UP * (.53 if pickets else .71))
			start = finish
	Kit.new().scatter(fence, BoxMesh.new(), bars, iron)


static func rail_post(foot: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(.065, 1.08, .065)), foot + Vector3.UP * .54)


func tier_line(lane: float) -> Vector2:
	var along := AMPHITHEATRE + ALONG_ROAD * lane
	var path := trails[1]
	for index in range(1, path.size()):
		var crossing: Variant = Geometry2D.segment_intersects_segment(along, along + TOWARD_WATER * 42.0,
			path[index - 1], path[index])
		if crossing is Vector2:
			return crossing
	return along + TOWARD_WATER * 26.0


func tier_point(lane: float, run: float) -> Vector2:
	var angle := lane / HALF_WIDTH * SEATING_ARC
	var radius := lerpf(1.0, .21, run)
	var cross := HALF_WIDTH * sin(angle) * radius
	var shoulder := AMPHITHEATRE + ALONG_ROAD * cross
	var trail_depth := (tier_line(cross) - shoulder).dot(TOWARD_WATER) - WALK_SETBACK
	var depth := lerpf(trail_depth, ROAD_SETBACK + .33, cos(angle) * radius)
	return shoulder + TOWARD_WATER * depth


func tier_top(row: int, lane: float) -> float:
	var front := tier_point(lane, (row + 1.0) / TIER_COUNT)
	var rear := tier_point(lane, (row + .25) / TIER_COUNT)
	return maxf(on_land(front).y + .13, on_land(rear).y + .045)


func build_terraces(park: Node3D, stone: Material) -> void:
	var amphitheatre := StaticBody3D.new()
	amphitheatre.name = "RiverbankAmphitheatre"
	park.add_child(amphitheatre)
	var blocks: Array[Transform3D] = []
	var turf := SurfaceTool.new()
	turf.begin(Mesh.PRIMITIVE_TRIANGLES)
	turf.set_normal(Vector3.UP)
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://riverbank_grass.gdshader")
	grass.set_shader_parameter("grass_scan", ImageTexture.create_from_image(Image.load_from_file("res://ottawa/materials/grass.jpg")))
	for row in TIER_COUNT:
		for side: float in [-1.0, 1.0]:
			for column in 7:
				var left := lerpf(AISLE_HALF_WIDTH, HALF_WIDTH, column / 7.0) * side
				var right := lerpf(AISLE_HALF_WIDTH, HALF_WIDTH, (column + 1) / 7.0) * side
				var lane_a := minf(left, right)
				var lane_b := maxf(left, right)
				var lane := (lane_a + lane_b) * .5
				var end := (row + 1.0) / TIER_COUNT
				var a := tier_point(lane_a, end)
				var b := tier_point(lane_b, end)
				var middle := (a + b) * .5
				var tangent := (b - a).normalized()
				var facing := atan2(tangent.x, tangent.y)
				var top := tier_top(row, lane)
				var bottom := minf(on_land(a).y, on_land(b).y) - .17
				var size := Vector3(.51, top - bottom, a.distance_to(b) * .967)
				var at := Vector3(middle.x, (top + bottom) * .5, middle.y)
				var orientation := Basis(Vector3.UP, facing)
				blocks.append(Transform3D(orientation.scaled_local(size), at))
				var collision := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = size
				collision.shape = shape
				amphitheatre.add_child(collision)
				collision.transform = Transform3D(orientation, at)
				for band in 4:
					for uv: Vector2 in [Vector2.ZERO, Vector2.DOWN, Vector2.RIGHT, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
						var across := lerpf(lane_a, lane_b, uv.x)
						var run := (band + uv.y) / 4.0
						var point := tier_point(across, (row + lerpf(.04, .935, run)) / TIER_COUNT)
						var natural := on_land(point).y
						var edge := minf(HALF_WIDTH - absf(across), absf(across) - AISLE_HALF_WIDTH)
						var blend := smoothstep(0.0, .76, edge) * smoothstep(0.0, .43, run)
						var height := lerpf(natural + .042, maxf(natural + .042, tier_top(row, across) - .035), blend)
						turf.add_vertex(Vector3(point.x, height, point.y))
	var limestone := stone.duplicate() as StandardMaterial3D
	limestone.albedo_color = Color("#c7c4b9")
	limestone.albedo_texture = ImageTexture.create_from_image(Image.load_from_file("res://ottawa/materials/concrete.jpg"))
	Kit.new().scatter(amphitheatre, BoxMesh.new(), blocks, limestone).name = "StoneSeating"
	var floor := Kit.mesh_at(amphitheatre, turf.commit(), Vector3.ZERO, grass)
	floor.name = "GrassyTiers"
	floor.create_trimesh_collision()




func build_waterfront_stones(park: Node3D, stone: Material, clearance: Callable) -> void:
	var shapes: Array[Transform3D] = []
	for sample in 450:
		var point := Vector2(random.randf_range(18155, 18250), random.randf_range(13061, 13139))
		var foot := on_land(point)
		if foot.y < -.13 or foot.y > 1.78 or clearance.call(foot) > .3 or near_trail(point, 1.15):
			continue
		var width := random.randf_range(.33, 1.13)
		var shape := Basis(Vector3.UP, random.randf_range(0, TAU)).scaled_local(Vector3(width, width * .48, width * .81))
		shapes.append(Transform3D(shape, foot + Vector3.UP * .045))
	if not shapes.is_empty():
		var rock := SphereMesh.new()
		rock.radial_segments = 8
		rock.rings = 4
		Kit.new().scatter(park, rock, shapes, stone).name = "LookoutShoreStones"



func build_verge(park: Node3D, marina: Marina, clearance: Callable) -> void:
	var grass: Array[Transform3D] = []
	for trail in [trails[1], trails[2]]:
		for i in range(1, trail.size()):
			var a: Vector2 = trail[i - 1]
			var b: Vector2 = trail[i]
			var edge := (b - a).normalized().orthogonal()
			for _sample in ceili(a.distance_to(b) * 2.0):
				var location := a.lerp(b, random.randf()) + edge * random.randf_range(-6.5, 6.5)
				if near_trail(location, 1.86) or in_amphitheatre(location) or location.distance_to(GAZEBO_SITE) < 12.0:
					continue
				var foot := on_land(location)
				if foot.y < .52 or clearance.call(foot) > .05:
					continue
				var scale := Vector3(random.randf_range(.51, .85), random.randf_range(.19, .43), .65)
				grass.append(Transform3D(Basis(Vector3.UP, random.randf_range(0, TAU)).scaled_local(scale), foot))
	var reeds := ShaderMaterial.new()
	reeds.shader = preload("res://river_reeds.gdshader")
	Kit.new().scatter(park, marina.reed_mesh(random), grass, reeds)


func build_flag(park: Node3D, foot: Vector3) -> void:
	var pole := CylinderMesh.new()
	pole.height = 7.4
	pole.top_radius = .044
	pole.bottom_radius = .069
	pole.radial_segments = 10
	Kit.mesh_at(park, pole, foot + Vector3.UP * 3.65, Kit.paint(Color("#bbbebc"), .45, .38))
	var pennant := QuadMesh.new()
	pennant.size = Vector2(1.64, .82)
	var fabric := Kit.paint(Color.WHITE, .85)
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	fabric.albedo_texture = canada_flag()
	var flag := Kit.mesh_at(park, pennant, foot + Vector3(.87, 6.64, 0), fabric)
	flag.name = "RiverbankCanadaFlag"


func build_sign(park: Node3D, foot: Vector3, towards: Vector3, message: String, timber: Material) -> void:
	var sign := Node3D.new()
	sign.name = "RiverbankTrailSign"
	park.add_child(sign)
	sign.global_position = park.get_parent().roadside_sign_foot(foot, .82)
	sign.add_to_group(&"town_roadside_signs")
	sign.set_meta(&"sign_span", .82)
	sign.basis = Basis.looking_at(towards, Vector3.UP, true)
	for x: float in [-.61, .61]:
		Kit.box_at(sign, Vector3(x, .65, 0), Vector3(.105, 1.56, .105), timber)
	Kit.box_at(sign, Vector3(0, 1.29, .044), Vector3(1.50, .40, .071), Kit.paint(Color("#294943")))
	var caption := Label3D.new()
	sign.add_child(caption)
	caption.position = Vector3(0, 1.30, .083)
	caption.text = message
	caption.font_size = 32
	caption.pixel_size = .0031
	caption.outline_size = 0
	caption.modulate = Color("#f5ead0")


func on_land(location: Vector2) -> Vector3:
	return Vector3(location.x, ground.call(location.x, location.y), location.y)


static func points(values: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for value: Array in values:
		polygon.append(pair(value))
	return polygon


static func pair(value: Array) -> Vector2:
	return Vector2(value[0], value[1])


static func canada_flag() -> ImageTexture:
	var image := Image.create_empty(128, 64, false, Image.FORMAT_RGB8)
	var red := Color("#cc2737")
	image.fill(red)
	image.fill_rect(Rect2i(32, 0, 64, 64), Color("#f5eee0"))
	var leaf := PackedVector2Array([Vector2(64, 8), Vector2(70, 22), Vector2(76, 19), Vector2(74, 34),
		Vector2(81, 27), Vector2(90, 27), Vector2(87, 37), Vector2(91, 39), Vector2(75, 48),
		Vector2(76, 52), Vector2(66, 50), Vector2(66, 56), Vector2(62, 56), Vector2(62, 50),
		Vector2(52, 52), Vector2(53, 48), Vector2(37, 39), Vector2(41, 37), Vector2(38, 27),
		Vector2(47, 27), Vector2(54, 34), Vector2(52, 19), Vector2(58, 22)])
	for y in range(8, 57):
		for x in range(37, 92):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), leaf):
				image.set_pixel(x, y, red)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
