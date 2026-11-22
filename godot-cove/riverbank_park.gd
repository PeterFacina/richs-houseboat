extends RefCounted

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
	return groves.any(func(polygon: PackedVector2Array) -> bool:
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
	var shelter := marina.build_pavilion(park, on_land(pair(layout.shelter)), Color("#455e53"), Color("#637368"))
	shelter.name = "RiverbankLookoutShelter"
	shelter.rotation.y = -.36
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
	build_terraces(park, stone)
	build_flag(park, on_land(pair(layout.flag)))
	build_sign(park, on_land(Vector2(18024.4, 12648.8)), Vector3(1, 0, -.15),
		"RIVERBANK PARK\nFootpath to Lamure Beach", timber)
	build_sign(park, on_land(Vector2(18202.0, 13123.8)), Vector3(.7, 0, -.7),
		"LAMURE BEACH\nFollow the gravel path", timber)
	build_sign(park, on_land(Vector2(18543.0, 13223.8)), Vector3(.96, 0, -.27),
		"RIVERBANK PARK\nFootpath to the marina", timber)

	var local := PackedFloat32Array()
	for i in range(0, survey.size(), 3):
		var foot := Vector3(survey[i], 0, survey[i + 1])
		if owns_tree(foot) and not near_trail(Vector2(foot.x, foot.z), 2.8):
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


func build_terraces(park: Node3D, stone: Material) -> void:
	var line := points(layout.terraces)
	var blocks: Array[Transform3D] = []
	for index in range(1, line.size()):
		var start := line[index - 1]
		var end := line[index]
		var forward := (end - start).normalized()
		var across := Vector2(forward.y, -forward.x)
		var count := maxi(1, roundi(start.distance_to(end) / 1.40))
		for i in count:
			for row in 2:
				var surface := start.lerp(end, (float(i) + .26 + .32 * row) / count)
				var foot := on_land(surface + across * row * 1.14)
				var height := random.randf_range(.49, .67)
				var at := foot + Vector3.UP * height * .08
				var angle := atan2(forward.x, forward.y) + random.randf_range(-.09, .09)
				var shape := Basis(Vector3.UP, angle).scaled_local(
					Vector3(random.randf_range(.71, .94), height, random.randf_range(1.20, 1.42)))
				blocks.append(Transform3D(shape, at))
	var steps := Kit.new().scatter(park, BoxMesh.new(), blocks, stone)
	steps.name = "RiverbankStoneTerraces"


func build_verge(park: Node3D, marina: Marina, clearance: Callable) -> void:
	var grass: Array[Transform3D] = []
	for trail in [trails[1], trails[2]]:
		for i in range(1, trail.size()):
			var a: Vector2 = trail[i - 1]
			var b: Vector2 = trail[i]
			var edge := (b - a).normalized().orthogonal()
			for _sample in ceili(a.distance_to(b) * 2.0):
				var location := a.lerp(b, random.randf()) + edge * random.randf_range(-6.5, 6.5)
				if near_trail(location, 1.86) or location.distance_to(pair(layout.shelter)) < 12.0:
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
	sign.position = foot
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
