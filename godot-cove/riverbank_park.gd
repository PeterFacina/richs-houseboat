extends RefCounted

const GAZEBO_FOOTPRINT := "411204346"
const GAZEBO_SITE := Vector2(18219.3688, 13123.3505)
const AMPHITHEATRE := Vector2(18183.65, 13100)
const ALONG_ROAD := Vector2(.61675, .78716)
const TOWARD_WATER := Vector2(.78716, -.61675)
const FLAG_SITE := Vector2(18181.1, 13088.1)
const TIER_COUNT := 6
const HALF_WIDTH := 10.3
const SEATING_ARC := 1.49
const ROAD_SETBACK := 5.55
const WALK_SETBACK := 3.0
const AISLE_HALF_WIDTH := .85
const Kit = preload("res://scenery.gd")
const Beach = preload("res://lamure_beach.gd")
const Marina = preload("res://marina_art.gd")
const Pines = preload("res://lamure_pines.gd")

var bounds := Rect2()
var layout: Dictionary
var trails: Array[PackedVector2Array] = []
var groves: Array[PackedVector2Array] = []
var ground: Callable
var random := RandomNumberGenerator.new()


func prepare(definition: Dictionary) -> void:
	layout = definition
	var paint: Array = layout.paint_bounds
	bounds = Rect2(paint[0], paint[1], paint[2], paint[3])
	for key in ["pier_approach", "promenade", "beach_link"]:
		trails.append(points(layout[key]))
	trails.append(PackedVector2Array([Vector2(17982.2319, 12637.6974), Vector2(17977.6, 12643.6),
		Vector2(17976.0, 12653.8), Vector2(17979.0, 12659.0), Vector2(17985.0, 12661.0)]))
	trails.append(PackedVector2Array([Vector2(18215.1, 13120.4), Vector2(18217.9, 13119.7),
		Vector2(18221.3, 13120.2), Vector2(18222.5, 13122.0)]))
	for polygon: Array in layout.woodland:
		groves.append(points(polygon))


func near_trail(location: Vector2, clearance := 2.25) -> bool:
	if not bounds.has_point(location):
		return false
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
	return in_amphitheatre(location) or groves.any(func(polygon: PackedVector2Array) -> bool:
		return Geometry2D.is_point_in_polygon(location, polygon)) or near_trail(location)


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
	build_terraces(park, stone)
	build_waterfront_stones(park, stone, clearance)
	build_flag(park, on_land(FLAG_SITE))
	build_sign(park, on_land(Vector2(18024.4, 12648.8)), Vector3(1, 0, -.15),
		"RIVERBANK PARK\nFootpath to Lamure Beach", timber)
	build_sign(park, on_land(Vector2(18202.0, 13123.8)), Vector3(.7, 0, -.7),
		"LAMURE BEACH\nFollow the gravel path", timber)
	build_sign(park, on_land(Vector2(18543.0, 13223.8)), Vector3(.96, 0, -.27),
		"RIVERBANK PARK\nFootpath to the marina", timber)

	var local := PackedFloat32Array()
	for i in range(0, survey.size(), 3):
		var foot := Vector3(survey[i], 0, survey[i + 1])
		if owns_tree(foot) and not in_amphitheatre(Vector2(foot.x, foot.z)) and not near_trail(Vector2(foot.x, foot.z), 2.8) \
				and Vector2(foot.x, foot.z).distance_squared_to(GAZEBO_SITE) > 36.0:
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
	for trail in trails:
		var edges := PackedVector2Array()
		for i in trail.size():
			var a := (trail[i] - trail[maxi(0, i - 1)]).normalized().orthogonal()
			var b := (trail[mini(i + 1, trail.size() - 1)] - trail[i]).normalized().orthogonal()
			edges.append((a + b).normalized() * (1.34 / maxf(.72, absf((a + b).length() * .5))))
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
						path_mesh.set_uv(Vector2(across, along))
						path_mesh.add_vertex(foot + Vector3.UP * .041)
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://riverbank_walk.gdshader")
	finish.set_shader_parameter("grit", grit)
	finish.set_shader_parameter("concrete_scan", concrete)
	var walk := Kit.mesh_at(park, path_mesh.commit(), Vector3.ZERO, finish)
	walk.name = "GazeboRiverWalk"
	walk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	grass.set_shader_parameter("grass_scan", preload("res://ottawa/materials/grass.jpg"))
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
	limestone.albedo_texture = preload("res://ottawa/materials/concrete.jpg")
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
