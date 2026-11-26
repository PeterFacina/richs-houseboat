extends Node3D

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const Roads = preload("res://deep_river_roads.gd")
const SIGN_FONT = preload("res://deep_river/BarlowCondensed-SemiBold.ttf")

const REPLACED_FOOTPRINTS := ["1336267290", "378664819", "1336267295", "243973052"]
# Local +Z faces Highway 17. +X runs along the storefronts from Pizza to Subway.
const ORIGIN := Roads.SIGNALS.JUNCTION
const ALONG := Vector2(-0.79388, -0.60807)
const FRONT := Vector2(0.60807, -0.79388)
const LOT := Rect2(-51, -51, 48, 43)
const RESTAURANT_LOT := Rect2(5.5, -74, 33.5, 65)
const CONNECTOR := Rect2(LOT.end.x, RESTAURANT_LOT.position.y,
	RESTAURANT_LOT.position.x - LOT.end.x, LOT.end.y - RESTAURANT_LOT.position.y)
const ENTRY_TOP := .75
const ENTRY_LOWER := .70
const ENTRY_APRON := 1.25
const SHOP_ENTRY := Rect2(-30, -35, 24, ENTRY_TOP + ENTRY_LOWER + ENTRY_APRON)
const PIZZA_ENTRY := Rect2(-47, -39, 14, ENTRY_TOP + ENTRY_LOWER + ENTRY_APRON)
const RESTAURANT_WALL := Rect2(9.35, -64.24, 12.39, 28.86)
const RESTAURANT_DINING_START := -47.1
const ROAD_EDGE := -Roads.HIGHWAY_HALF_WIDTH
const PIZZA_LEFT := -47.0
const ASPHALT_LIFT := .075
const PAVEMENT_LAYERS := Roads.ROAD_LAYER | 1

var ground: Callable
var solid: StaticBody3D
var concrete: StandardMaterial3D
var cream := Kit.paint(Color("#b9ae98"))
var white := Kit.paint(Color("#ece9df"))
var red := Kit.paint(Color("#b72428"))
var dark := Kit.paint(Color("#393a38"))
var glazing := ShaderMaterial.new()
var storefront_trim := Kit.paint(Color("#afa99d"), .35, .24)
var door_hardware := Kit.paint(Color("#bbb9ad"), .27, .48)


static func clears_tree(point: Vector2) -> bool:
	var offset := point - ORIGIN
	var local := Vector2(offset.dot(ALONG), offset.dot(FRONT))
	return LOT.grow(1.6).has_point(local) or RESTAURANT_LOT.grow(1.6).has_point(local) \
		or CONNECTOR.grow(1.6).has_point(local)


func build(elevation: Callable, asphalt: Texture2D, paving: Texture2D, brick: Texture2D) -> void:
	name = "DeepRiverEssoPlaza"
	ground = elevation
	position = Vector3(ORIGIN.x, ground.call(ORIGIN.x, ORIGIN.y), ORIGIN.y)
	basis = Basis(Vector3(ALONG.x, 0, ALONG.y), Vector3.UP, Vector3(FRONT.x, 0, FRONT.y))
	solid = StaticBody3D.new()
	add_child(solid)
	concrete = Kit.paint(Color("#bcb5a5"))
	concrete.albedo_texture = paving
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3.ONE * .5
	glazing.shader = preload("res://deep_river_town_hall_glass.gdshader")
	glazing.set_shader_parameter("tone", .78)
	glazing.set_shader_parameter("reflection_strength", .43)

	var pavement := ShaderMaterial.new()
	pavement.shader = preload("res://deep_river_esso_asphalt.gdshader")
	pavement.set_shader_parameter("asphalt_scan", asphalt)
	build_forecourt(pavement)
	# Split the rear run at Esso's back edge to share the same pavement seam.
	surface(Rect2(CONNECTOR.position, Vector2(CONNECTOR.size.x, LOT.position.y - CONNECTOR.position.y)),
		ASPHALT_LIFT, ASPHALT_LIFT, pavement, PAVEMENT_LAYERS)
	surface(Rect2(CONNECTOR.position.x, LOT.position.y, CONNECTOR.size.x, LOT.size.y),
		ASPHALT_LIFT, ASPHALT_LIFT, pavement, PAVEMENT_LAYERS)
	build_restaurant_lot(pavement, brick)
	var siding := siding_material()
	build_shops(siding)
	build_pizzeria(siding)
	build_canopy()
	build_price_sign()
	build_utilities()
	for mesh: Node in find_children("*", "MeshInstance3D", true, false):
		Graphics.batch(mesh, "building_shell")


func grade(x: float, z: float) -> float:
	var at := ORIGIN + ALONG * x + FRONT * z
	return float(ground.call(at.x, at.y)) - position.y


func block(at: Vector3, size: Vector3, material: Material, collides := false) -> void:
	Kit.box_at(self, at, size, material)
	if collides:
		Kit.collider(solid, at, size)


func build_forecourt(asphalt: Material) -> void:
	# The concrete steps and approach own their entire footprint.
	for strip: Vector2 in [Vector2(LOT.position.x, PIZZA_ENTRY.position.x),
			Vector2(PIZZA_ENTRY.end.x, SHOP_ENTRY.position.x), Vector2(SHOP_ENTRY.end.x, LOT.end.x)]:
		surface(Rect2(strip.x, LOT.position.y, strip.y - strip.x, LOT.size.y),
			ASPHALT_LIFT, ASPHALT_LIFT, asphalt, PAVEMENT_LAYERS)
	for entry: Rect2 in [PIZZA_ENTRY, SHOP_ENTRY]:
		surface(Rect2(entry.position.x, LOT.position.y, entry.size.x, entry.position.y - LOT.position.y),
			ASPHALT_LIFT, ASPHALT_LIFT, asphalt, PAVEMENT_LAYERS)
		surface(Rect2(entry.position.x, entry.end.y, entry.size.x, LOT.end.y - entry.end.y),
			ASPHALT_LIFT, ASPHALT_LIFT, asphalt, PAVEMENT_LAYERS)

	# One apron ties the Esso opening, the new driveway mouth and the Burger King opening to Highway 17.
	surface(Rect2(-45, LOT.end.y, 69, ROAD_EDGE - LOT.end.y),
		ASPHALT_LIFT, .045, asphalt, PAVEMENT_LAYERS)
	for curb in [Vector2(-51, -45), Vector2(-12, -3)]:
		surface(Rect2(curb.x, -8.85, curb.y - curb.x, .85), .20, .20, concrete)
		surface(Rect2(curb.x, -8, curb.y - curb.x, .42), .20, .02, concrete)

func surface(area: Rect2, back: float, front: float, material: Material, collision_layer := 1,
		level_back := false) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := ceili(area.size.x)
	var rows := ceili(area.size.y)
	for row in rows + 1:
		for col in cols + 1:
			var p := area.position + area.size * Vector2(float(col) / cols, float(row) / rows)
			mesh.set_uv(p * .24)
			var terrain_y := grade(p.x, p.y)
			var back_y := back if level_back else terrain_y + back
			var height := lerpf(back_y, terrain_y + front, float(row) / rows)
			if level_back:
				height = maxf(height, terrain_y + .035)
			mesh.add_vertex(Vector3(p.x, height, p.y))
	var stride := cols + 1
	for row in rows:
		for col in cols:
			var i := row * stride + col
			for vertex in [i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]:
				mesh.add_index(vertex)
	mesh.generate_normals()
	var item := Kit.mesh_at(self, mesh.commit(), Vector3.ZERO, material)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collision_layer != 0:
		item.create_trimesh_collision()
		var body := item.get_child(0) as StaticBody3D
		body.collision_layer = collision_layer


func entry_steps(area: Rect2, threshold: float) -> void:
	# Both closed risers fit the player's step-up limit.
	const RISER := .135
	var apron_z := area.position.y + ENTRY_TOP + ENTRY_LOWER
	for tread: Vector2 in [Vector2(ENTRY_TOP, threshold), Vector2(ENTRY_TOP + ENTRY_LOWER, threshold - RISER)]:
		var center := Vector3(area.get_center().x, tread.y - .29, area.position.y + tread.x * .5)
		block(center, Vector3(area.size.x, .58, tread.x), concrete, true)
	surface(Rect2(area.position.x, apron_z, area.size.x, ENTRY_APRON),
		threshold - RISER * 2.0, ASPHALT_LIFT, concrete, 1, true)


func siding_material() -> StandardMaterial3D:
	var image := Image.create(4, 128, true, Image.FORMAT_RGB8)
	for y in 128:
		var seam := y % 4
		var tint := 0.83 if seam == 0 else 1.0
		for x in 4:
			image.set_pixel(x, y, cream.albedo_color * tint)
	image.generate_mipmaps()
	var siding := Kit.paint(Color.WHITE)
	siding.albedo_texture = ImageTexture.create_from_image(image)
	return siding


func build_shops(siding: Material) -> void:
	var z := -35.0
	var floor_y := maxf(grade(-30, z), grade(-6, z)) + .25
	var base := minf(grade(-30, -46), grade(-6, -46)) - .25
	block(Vector3(-18, (base + floor_y + 3.65) * .5, -41), Vector3(24, floor_y + 3.65 - base, 12), siding, true)
	block(Vector3(-18, floor_y + 3.65, -41), Vector3(24.35, .21, 12.35), white)
	entry_steps(SHOP_ENTRY, floor_y)
	storefront("B&R CONVENIENCE", -26.0, floor_y, z, 6.5, red)
	storefront("DEEP RIVER CANNABIS", -18.0, floor_y, z, 6.8, Kit.paint(Color("#214f3f")))
	var green := Kit.paint(Color("#14723c"))
	storefront("SUBWAY", -10.0, floor_y, z, 7.0, green)
	for at in [-44.0, -41.7, -39.4]:
		glazed_opening(Vector3(-5.97, floor_y + 1.47, at), 2.14, 1.92, PI * .5)
	sign_panel("SUBWAY", Vector3(-5.96, floor_y + 3.02, -38.5), 3.3, .76, green, Color("#f4dd60"), PI * .5)


func storefront(title: String, x: float, base: float, z: float, width: float, sign: Material) -> void:
	for offset in [-width * .31, 0.0, width * .31]:
		var door := is_zero_approx(offset)
		var tall := 2.18 if door else 1.72
		var at := Vector3(x + offset, base + (tall * .5 + .018 if door else 1.47), z)
		var pane_width := 1.28 if door else width * .29
		glazed_opening(at, pane_width, tall, 0.0, door)
	var ink := Color("#f4dd60") if title == "SUBWAY" else Color.WHITE
	sign_panel(title, Vector3(x, base + 3.01, z + .09), width - .35, .76, sign, ink)


func build_pizzeria(siding: Material) -> void:
	var shop := Node3D.new()
	shop.name = "FamousPizza"
	add_child(shop)
	var x := PIZZA_LEFT + 7.0
	var z := -39.0
	var base := maxf(grade(PIZZA_LEFT, z), grade(PIZZA_LEFT + 14, z)) + .22
	var foundation := minf(grade(PIZZA_LEFT, -48.5), grade(x, z)) - .2
	block(Vector3(x, (foundation + base + 2.8) * .5, z - 4.75),
		Vector3(14, base + 2.8 - foundation, 9.5), siding, true)
	var roof := PrismMesh.new()
	roof.size = Vector3(9.9, 1.05, 14.45)
	Kit.mesh_at(shop, roof, Vector3(x, base + 3.32, z - 4.75), dark).rotation.y = PI * .5
	block(Vector3(x, base + 2.785, z - 4.75), Vector3(14.5, .14, 9.95), white)
	sign_panel("FAMOUS PIZZA", Vector3(x - 2.1, base + 1.95, z + .06), 4.9, .78, red, Color.WHITE)
	glazed_opening(Vector3(x + 2.1, base + 1.38, z), 1.50, 1.72)
	glazed_opening(Vector3(x + 4.6, base + 1.08, z), 1.50, 2.12, 0.0, true)
	entry_steps(PIZZA_ENTRY, base)


func build_canopy() -> void:
	var x := -15.5
	var z := -19.0
	var top := grade(x, z) + 4.75
	block(Vector3(x, top, z), Vector3(17.0, .69, 8.6), white, true)
	block(Vector3(x, top + .06, z), Vector3(17.05, .29, 8.65), red)
	sign_panel("ESSO", Vector3(x - 6.1, top + .05, z + 4.34), 3.2, .46, white, Color("#b72428"))
	sign_panel("ESSO", Vector3(x + 8.54, top + .05, z), 2.65, .46, white, Color("#b72428"), PI * .5)
	var yellow := Kit.paint(Color("#d5a12e"))
	for light_x: float in [-6.0, 0.0, 6.0]:
		block(Vector3(x + light_x, top - .36, z), Vector3(1.12, .05, .51), white)
	for offset: float in [-4.9, 4.9]:
		var island := x + offset
		var y := grade(island, z)
		block(Vector3(island, y + .11, z), Vector3(2.25, .27, 5.8), concrete, true)
		block(Vector3(island, (y + top) * .5, z), Vector3(.42, top - y, .62), white, true)
		for side: float in [-1.0, 1.0]:
			var pz := z + side * 1.60
			block(Vector3(island, y + .98, pz), Vector3(.95, 1.48, .62), white, true)
			block(Vector3(island, y + 1.52, pz), Vector3(.99, .23, .66), red)
			block(Vector3(island, y + 1.18, pz + side * .33), Vector3(.71, .34, .04), dark)
			block(Vector3(island + .32, y + .86, pz + side * .36), Vector3(.08, .39, .07), dark)
			var handle := Vector3(island + .32, y + .84, pz + side * .37)
			var lowest := Vector3(island + .48, y + .51, pz + side * .39)
			Kit.beam(self, handle, lowest, .038, dark)
			Kit.beam(self, lowest, Vector3(island + .49, y + 1.21, pz + side * .17), .038, dark)
			block(Vector3(island, y + .51, pz + side * 1.13), Vector3(.15, .75, .15), yellow, true)


func build_price_sign() -> void:
	var z := -12.0
	var sign := StaticBody3D.new()
	sign.name = "EssoPriceSign"
	add_child(sign)
	sign.position = Vector3(PIZZA_LEFT, grade(PIZZA_LEFT, z), z)
	sign.rotation.y = PI * .5
	var footing := Vector3(0, .19, 0)
	var footing_size := Vector3(2.75, .38, 1.4)
	Kit.box_at(sign, footing, footing_size, concrete)
	Kit.collider(sign, footing, footing_size)
	for offset in [-1.05, 1.05]:
		var post := Vector3(offset, 2.66, 0)
		var post_size := Vector3(.13, 5.2, .17)
		Kit.box_at(sign, post, post_size, white)
		Kit.collider(sign, post, post_size)
	var blue := Kit.paint(Color("#244777"))
	var green := Kit.paint(Color("#14723c"))
	for side: float in [-1.0, 1.0]:
		var angle := 0.0 if side > 0 else PI
		var face := side * .15
		sign_panel("Esso", Vector3(0, 4.68, face), 2.16, 1.02, white, Color("#b72428"), angle, sign)
		sign_panel("172.9", Vector3(0, 3.86, face), 2.16, .58, blue, Color("#ff7359"), angle, sign)
		sign_panel("Convenience", Vector3(0, 3.31, face), 2.16, .47, blue, Color.WHITE, angle, sign)
		sign_panel("SUBWAY", Vector3(0, 2.78, face), 2.16, .53, green, Color("#f4dd60"), angle, sign)

func build_restaurant_lot(asphalt: Material, brick_scan: Texture2D) -> void:
	surface(RESTAURANT_LOT, ASPHALT_LIFT, ASPHALT_LIFT, asphalt, PAVEMENT_LAYERS)
	surface(Rect2(RESTAURANT_LOT.position.x, RESTAURANT_LOT.end.y,
		24 - RESTAURANT_LOT.position.x, LOT.end.y - RESTAURANT_LOT.end.y),
		ASPHALT_LIFT, ASPHALT_LIFT, asphalt, PAVEMENT_LAYERS)
	var parking_paint := Kit.paint(Color("#c6c1ad"))
	for space in 9:
		var z := -62.5 + float(space) * 2.65
		surface(Rect2(32.8, z, 5.1, .09), .087, .087, parking_paint, 0)
	surface(Rect2(37.85, -62.5, .09, 21.2), .087, .087, parking_paint, 0)
	for space in 4:
		var x := 29.0 + float(space) * 2.9
		surface(Rect2(x, -73.3, .09, 5.1), .087, .087, parking_paint, 0)
	surface(Rect2(29, -73.3, 8.7, .09), .087, .087, parking_paint, 0)
	parking_island(Vector2(33.8, -39.0), Vector2(6.1, 1.6))
	parking_island(Vector2(33.9, -64.8), Vector2(6.3, 1.35))
	parking_island(Vector2(27.8, -13.2), Vector2(5.2, 1.85))

	# Keep the surveyed footprint. The dining-room awning ends at the brick service wing.
	var front_z := RESTAURANT_WALL.end.y
	var back_z := RESTAURANT_WALL.position.y
	var x := RESTAURANT_WALL.get_center().x
	var center_z := RESTAURANT_WALL.get_center().y
	var right_wall := RESTAURANT_WALL.end.x
	var left_wall := RESTAURANT_WALL.position.x
	var floor_y := maxf(grade(left_wall, front_z), grade(right_wall, front_z)) + .20
	var foundation := minf(grade(left_wall, back_z), grade(right_wall, back_z)) - .3
	var eave := floor_y + 3.0
	var brick := Kit.paint(Color("#c4a284"))
	brick.albedo_texture = brick_scan
	brick.uv1_triplanar = true
	brick.uv1_scale = Vector3.ONE * .75
	var base_brick := brick.duplicate() as StandardMaterial3D
	base_brick.albedo_color = Color("#9f7565")
	block(Vector3(x, (foundation + eave) * .5, center_z),
		Vector3(RESTAURANT_WALL.size.x, eave - foundation, RESTAURANT_WALL.size.y), brick, true)
	block(Vector3(x, (foundation + floor_y + .32) * .5, center_z),
		Vector3(RESTAURANT_WALL.size.x + .035, floor_y + .32 - foundation, RESTAURANT_WALL.size.y + .035), base_brick)
	block(Vector3(x, floor_y - .08, front_z + .65), Vector3(12.65, .16, 1.3), concrete, true)
	surface(Rect2(right_wall, -49.4, 1.55, 14.02), .16, .16, concrete)

	var blue := Kit.paint(Color("#294982"))
	var fascia := Kit.paint(Color("#a6262c"))
	var roof_depth := front_z - RESTAURANT_DINING_START
	var roof_center := Vector3(x, eave, (front_z + RESTAURANT_DINING_START) * .5)
	build_restaurant_eaves(roof_center, blue, roof_depth)
	block(roof_center + Vector3.UP * 1.23, Vector3(11.45, .25, roof_depth - .96), fascia)
	block(roof_center + Vector3.UP * 1.40, Vector3(11.32, .14, roof_depth - 1.02), dark)
	var service_depth := RESTAURANT_DINING_START - back_z
	block(Vector3(x, eave + .44, (back_z + RESTAURANT_DINING_START) * .5),
		Vector3(12.44, .88, service_depth), brick)
	block(Vector3(x, eave + .90, (back_z + RESTAURANT_DINING_START) * .5),
		Vector3(12.55, .12, service_depth + .10), dark)

	for offset: float in [-4.5, -2.25, 0.0, 2.25, 4.5]:
		glazed_opening(Vector3(x + offset, floor_y + 1.47, front_z), 2.04, 1.70)
	var side_door_z := -45.8
	for z: float in [-37.3, -39.55, -41.8, -44.05]:
		glazed_opening(Vector3(right_wall, floor_y + 1.46, z), 2.02, 1.69, PI * .5)
	var door_base := grade(right_wall, side_door_z) + .16
	glazed_opening(Vector3(right_wall, door_base + 1.08, side_door_z), 1.36, 2.16, PI * .5, true)
	glazed_opening(Vector3(left_wall, floor_y + 1.49, -51.0), 1.35, .93, -PI * .5)
	block(Vector3(left_wall - .15, floor_y + .99, -51.0), Vector3(.32, .07, 1.47), dark)
	for z: float in [-50.0, -60.0]:
		block(Vector3(right_wall + .07, eave - .25, z), Vector3(.18, .16, .37), dark)
		block(Vector3(right_wall + .09, eave - .34, z), Vector3(.14, .036, .28), white)

	sign_panel("BURGER KING", Vector3(x, eave + .54, front_z + .69), 4.9, .67, blue, Color("#fff0d2"))
	build_restaurant_sign(fascia, blue)
	build_drive_through(parking_paint, blue)


func parking_island(at: Vector2, size: Vector2) -> void:
	var curb := CylinderMesh.new()
	curb.top_radius = .94
	curb.bottom_radius = 1.0
	curb.height = .27
	curb.radial_segments = 20
	var y := grade(at.x, at.y) + ASPHALT_LIFT
	var island := Kit.mesh_at(self, curb, Vector3(at.x, y + .04, at.y), concrete)
	island.scale = Vector3(size.x * .5, 1, size.y * .5)
	island.create_trimesh_collision()
	var infill := CylinderMesh.new()
	infill.top_radius = .86
	infill.bottom_radius = .86
	infill.height = .035
	infill.radial_segments = 20
	var grass := Kit.mesh_at(self, infill, Vector3(at.x, y + .17, at.y), Kit.paint(Color("#677747")))
	grass.scale = island.scale


func build_drive_through(marking: Material, blue: Material) -> void:
	var guide := Vector3(24.0, grade(24.0, -65.3) + ASPHALT_LIFT, -65.3)
	block(guide + Vector3.UP * .55, Vector3(.10, 1.1, .12), blue, true)
	sign_panel("DRIVE THRU  ›", guide + Vector3.UP * 1.12, 1.35, .41, blue, Color.WHITE, PI * .5)

	var curb_path := PackedVector2Array([
		Vector2(6.1, -68.4), Vector2(8.0, -68.5), Vector2(10.0, -68.55),
		Vector2(12.0, -68.55), Vector2(14.0, -68.55), Vector2(16.0, -68.55),
		Vector2(18.0, -68.5), Vector2(20.0, -68.27), Vector2(22.0, -67.84),
		Vector2(23.65, -67.3), Vector2(25.15, -66.55),
	])
	build_drive_through_curb(curb_path)
	build_drive_through_menu(Vector2(11.5, -65.65))

	for z: float in [-58.0, -54.0, -48.0, -42.0]:
		surface(Rect2(8.78, z, .075, 1.5), .087, .087, marking, 0)


func build_drive_through_curb(path: PackedVector2Array) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [Vector2(-.20, -.07), Vector2(-.14, .15), Vector2(.14, .15), Vector2(.20, -.07)]
	for i in path.size():
		var direction := path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]
		var across := direction.normalized().orthogonal()
		for edge: Vector2 in profile:
			var at := path[i] + across * edge.x
			mesh.add_vertex(Vector3(at.x, grade(at.x, at.y) + ASPHALT_LIFT + edge.y, at.y))
	for i in range(path.size() - 1):
		var start := i * profile.size()
		var next := start + profile.size()
		for side in range(profile.size() - 1):
			var a := start + side
			var b := next + side
			for corner: int in [a, a + 1, b, a + 1, b + 1, b]:
				mesh.add_index(corner)
	var last := (path.size() - 1) * profile.size()
	for corner: int in [0, 2, 1, 0, 3, 2, last, last + 1, last + 2, last, last + 2, last + 3]:
		mesh.add_index(corner)
	mesh.generate_normals()
	var curb := Kit.mesh_at(self, mesh.commit(), Vector3.ZERO, concrete)
	curb.name = "BurgerKingDriveThroughCurb"
	curb.create_trimesh_collision()


func build_drive_through_menu(at: Vector2) -> void:
	var y := grade(at.x, at.y) + ASPHALT_LIFT
	var cabinet := Kit.paint(Color("#292725"), .56)
	var paper := Kit.paint(Color("#eee1c7"), .69)
	var header := Kit.paint(Color("#9d2e22"))
	var ink := Color("#352019")
	var board := StaticBody3D.new()
	board.name = "BurgerKingDriveThroughMenu"
	add_child(board)
	board.position = Vector3(at.x, y, at.y)
	board.rotation.y = PI
	for x: float in [-.85, .85]:
		Kit.box_at(board, Vector3(x, .63, 0), Vector3(.15, 1.30, .19), cabinet)
		Kit.collider(board, Vector3(x, .63, 0), Vector3(.15, 1.30, .19))
	var case_center := Vector3(0, 1.51, 0)
	Kit.box_at(board, case_center, Vector3(2.52, 1.04, .19), cabinet)
	Kit.collider(board, case_center, Vector3(2.52, 1.04, .19))
	sign_panel("BURGER KING  •  MENU", Vector3(0, 1.87, .095), 2.35, .23, header, Color("#fff1d8"), 0.0, board)
	var panels := ["FLAME GRILLED\nWhopper\nDouble Whopper",
		"CHICKEN\nOriginal Chicken\nChicken Fries", "SIDES & DRINKS\nFrench Fries\nSoft Drinks"]
	for i in panels.size():
		sign_panel(panels[i], Vector3((i - 1) * .79, 1.42, .095), .75, .62, paper, ink, 0.0, board)


func build_restaurant_eaves(center: Vector3, material: Material, depth: float) -> void:
	var lower_depth := depth * .5 + .69
	var upper_depth := depth * .5 - .48
	var lower := [Vector2(-6.97, -lower_depth), Vector2(6.97, -lower_depth), Vector2(6.97, lower_depth), Vector2(-6.97, lower_depth)]
	var upper := [Vector2(-5.72, -upper_depth), Vector2(5.72, -upper_depth), Vector2(5.72, upper_depth), Vector2(-5.72, upper_depth)]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var j := (i + 1) % 4
		var a := Vector3(lower[i].x, 0, lower[i].y)
		var b := Vector3(lower[j].x, 0, lower[j].y)
		var c := Vector3(upper[i].x, 1.18, upper[i].y)
		var d := Vector3(upper[j].x, 1.18, upper[j].y)
		for p in [a, b, c, b, d, c]:
			mesh.add_vertex(p)
	mesh.generate_normals()
	Kit.mesh_at(self, mesh.commit(), center, material)
	block(center - Vector3.UP * .08, Vector3(13.94, .16, lower_depth * 2.0), material)


func glazed_opening(at: Vector3, width: float, height: float, heading := 0.0, door := false) -> void:
	var trim := Kit.box_at(self, at, Vector3(width, height, .12), storefront_trim)
	trim.rotation.y = heading
	# Opaque tinted glass masks the building shell. A recessed face catches daylight
	# and the aluminum rails stay slightly proud of the pane.
	var kick := .21 if door else .075
	Kit.box_at(trim, Vector3(0, kick * .5 - .035, .061),
		Vector3(width - .124, height - kick - .085, .025), glazing)
	Kit.box_at(trim, Vector3(0, -.21 if door else -.38, .071),
		Vector3(width - .112, .048, .033), storefront_trim)
	if door:
		var pull_x := width * .31
		for y: float in [-.24, .05]:
			Kit.box_at(trim, Vector3(pull_x, y, .105), Vector3(.05, .048, .092), door_hardware)
		Kit.box_at(trim, Vector3(pull_x, -.095, .147), Vector3(.038, .34, .037), door_hardware)

func build_restaurant_sign(fascia: Material, blue: Material) -> void:
	var x := 27.8
	var z := -13.2
	var y := grade(x, z)
	block(Vector3(x, y + 2.55, z), Vector3(.22, 5.1, .28), blue, true)
	var cream_face := Kit.paint(Color("#f6eddb"))
	var orange := Kit.paint(Color("#eaa153"))
	var at := Vector3(x, y + 5.0, z)
	block(at, Vector3(.23, 2.37, 2.22), cream_face)
	for side: float in [-1.0, 1.0]:
		var angle := PI * .5 * side
		restaurant_sign_disc(at + Vector3.RIGHT * side * .13, .98, .034, blue)
		restaurant_sign_disc(at + Vector3.RIGHT * side * .152, .86, .022, cream_face)
		restaurant_sign_disc(at + Vector3.RIGHT * side * .171, .74, .018, orange)
		var logo := sign_label("BURGER\nKING", 1.47, 1.31, Color("#b12028"))
		add_child(logo)
		logo.position = at + Vector3.RIGHT * side * .187
		logo.rotation.y = angle
		sign_panel("DRIVE THRU", Vector3(x + side * .15, y + 3.56, z), 2.63, .38, fascia, Color.WHITE, angle)
		sign_panel("WHOPPER\nWEDNESDAY", Vector3(x + side * .15, y + 2.89, z), 2.21, .81, cream_face, Color("#352e29"), angle)

func restaurant_sign_disc(at: Vector3, radius: float, depth: float, material: Material) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = depth
	disc.radial_segments = 24
	var face := Kit.mesh_at(self, disc, at, material)
	face.rotation.z = PI * .5

func build_utilities() -> void:
	var timber := Kit.paint(Color("#645b4f"))
	var wire := Kit.paint(Color("#302e2b"))
	var tops: Array[Vector3] = []
	for x in [-54.0, -30.5, -2.0]:
		var z := -10.0
		var y := grade(x, z)
		block(Vector3(x, y + 4.45, z), Vector3(.26, 8.9, .26), timber, true)
		block(Vector3(x, y + 8.46, z), Vector3(.19, .13, 1.48), timber)
		tops.append(Vector3(x, y + 8.58, z))
	for i in range(1, tops.size()):
		for shift in [-.59, 0.0, .59]:
			var a := tops[i - 1] + Vector3(0, 0, shift)
			var b := tops[i] + Vector3(0, 0, shift)
			var previous := a
			for step in range(1, 9):
				var t := float(step) / 8.0
				var next := a.lerp(b, t) - Vector3.UP * (2.1 * t * (1.0 - t))
				Kit.beam(self, previous, next, .026, wire)
				previous = next


func sign_panel(title: String, at: Vector3, width: float, height: float, finish: Material,
		ink: Color, angle := 0.0, parent: Node3D = null) -> void:
	var panel := Kit.box_at(self if parent == null else parent, at, Vector3(width, height, .12), finish)
	panel.rotation.y = angle
	var label := sign_label(title, width, height, ink)
	label.position.z = .066
	panel.add_child(label)


func sign_label(title: String, width: float, height: float, ink: Color) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.font = SIGN_FONT
	label.font_size = 56
	var line_height := label.font.get_height(label.font_size) * (title.count("\n") + 1)
	label.pixel_size = minf(height * .83 / line_height,
		width * .88 / label.font.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, label.font_size).x)
	label.outline_size = 0
	label.modulate = ink
	label.double_sided = false
	return label
