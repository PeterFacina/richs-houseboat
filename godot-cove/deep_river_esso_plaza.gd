extends Node3D

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const Roads = preload("res://deep_river_roads.gd")
const SIGN_FONT = preload("res://deep_river/BarlowCondensed-SemiBold.ttf")

const REPLACED_FOOTPRINTS := ["1336267290", "378664819", "1336267295"]
# Local +Z faces Highway 17. +X runs along the storefronts from Pizza to Subway.
const ORIGIN := Roads.SIGNALS.JUNCTION
const ALONG := Vector2(-0.79388, -0.60807)
const FRONT := Vector2(0.60807, -0.79388)
const LOT := Rect2(-51, -51, 48, 43)
const ROAD_EDGE := -Roads.HIGHWAY_HALF_WIDTH
const PIZZA_LEFT := -47.0
const ASPHALT_LIFT := .075

var ground: Callable
var solid: StaticBody3D
var concrete: StandardMaterial3D
var cream := Kit.paint(Color("#b9ae98"))
var white := Kit.paint(Color("#ece9df"))
var red := Kit.paint(Color("#b72428"))
var dark := Kit.paint(Color("#393a38"))
var glazing := Kit.paint(Color("#4f5955"), .26)


static func clears_tree(point: Vector2) -> bool:
	var offset := point - ORIGIN
	return LOT.grow(1.6).has_point(Vector2(offset.dot(ALONG), offset.dot(FRONT)))


func build(elevation: Callable, asphalt: Texture2D, paving: Texture2D) -> void:
	name = "DeepRiverEssoPlaza"
	ground = elevation
	position = Vector3(ORIGIN.x, ground.call(ORIGIN.x, ORIGIN.y), ORIGIN.y)
	basis = Basis(Vector3(ALONG.x, 0, ALONG.y), Vector3.UP, Vector3(FRONT.x, 0, FRONT.y))
	solid = StaticBody3D.new()
	add_child(solid)
	concrete = Kit.paint(Color("#bcb5a5"))
	concrete.albedo_texture = paving

	build_forecourt(asphalt)
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


func build_forecourt(scan: Texture2D) -> void:
	var asphalt := ShaderMaterial.new()
	asphalt.shader = preload("res://deep_river_esso_asphalt.gdshader")
	asphalt.set_shader_parameter("asphalt_scan", scan)
	surface(LOT, ASPHALT_LIFT, ASPHALT_LIFT, asphalt, true)
	for opening in [Vector2(-45, -34), Vector2(-22, -12)]:
		surface(Rect2(opening.x, LOT.end.y, opening.y - opening.x, ROAD_EDGE - LOT.end.y),
			ASPHALT_LIFT, .045, asphalt, true)
	# Set the right entry back from the existing junction signal.
	for curb in [Vector2(-51, -45), Vector2(-34, -22), Vector2(-12, -3)]:
		surface(Rect2(curb.x, -8.85, curb.y - curb.x, .85), .20, .20, concrete)
		surface(Rect2(curb.x, -8, curb.y - curb.x, .42), .20, .02, concrete)
	surface(Rect2(-30, -35, 24, 2.6), .20, .20, concrete)
	surface(Rect2(PIZZA_LEFT, -39, 14, 2.4), .20, .20, concrete)


func surface(area: Rect2, back: float, front: float, material: Material, drivable := false) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := ceili(area.size.x)
	var rows := ceili(area.size.y)
	for row in rows + 1:
		for col in cols + 1:
			var p := area.position + area.size * Vector2(float(col) / cols, float(row) / rows)
			mesh.set_uv(p * .24)
			mesh.add_vertex(Vector3(p.x, grade(p.x, p.y) + lerpf(back, front, float(row) / rows), p.y))
	var stride := cols + 1
	for row in rows:
		for col in cols:
			var i := row * stride + col
			for vertex in [i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]:
				mesh.add_index(vertex)
	mesh.generate_normals()
	var item := Kit.mesh_at(self, mesh.commit(), Vector3.ZERO, material)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.create_trimesh_collision()
	if drivable:
		var body := item.get_child(0) as StaticBody3D
		body.collision_layer |= Roads.ROAD_LAYER


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
	block(Vector3(-18, floor_y + .1, -34.45), Vector3(24, .22, 1.1), concrete, true)
	storefront("B&R CONVENIENCE", -26.0, floor_y, z, 6.5, red)
	storefront("DEEP RIVER CANNABIS", -18.0, floor_y, z, 6.8, Kit.paint(Color("#214f3f")))
	var green := Kit.paint(Color("#14723c"))
	storefront("SUBWAY", -10.0, floor_y, z, 7.0, green)
	for at in [-44.0, -41.7, -39.4]:
		var pane := Vector3(-5.97, floor_y + 1.47, at)
		block(pane, Vector3(.115, 1.95, 2.14), white)
		block(pane + Vector3(.07, 0, 0), Vector3(.05, 1.80, 2.0), glazing)
	sign_panel("SUBWAY", Vector3(-5.96, floor_y + 3.02, -38.5), 3.3, .76, green, Color("#f4dd60"), PI * .5)


func storefront(title: String, x: float, base: float, z: float, width: float, sign: Material) -> void:
	for offset in [-width * .31, 0.0, width * .31]:
		var door := is_zero_approx(offset)
		var tall := 2.18 if door else 1.72
		var at := Vector3(x + offset, base + (1.22 if door else 1.39), z)
		var pane_width := 1.28 if door else width * .29
		block(at, Vector3(pane_width, tall, .13), white)
		block(at + Vector3(0, 0, .08), Vector3(pane_width - .12, tall - .12, .06), glazing)
		block(at + Vector3(0, -.25, .12), Vector3(pane_width, .045, .04), white)
	var ink := Color("#f4dd60") if title == "SUBWAY" else Color.WHITE
	sign_panel(title, Vector3(x, base + 3.01, z + .09), width - .35, .76, sign, ink)


func build_pizzeria(siding: Material) -> void:
	var shop := Node3D.new()
	shop.name = "FamousPizza"
	add_child(shop)
	var x := PIZZA_LEFT + 7.0
	var z := -39.0
	var base := grade(x, z) + .3
	var foundation := minf(grade(PIZZA_LEFT, -48.5), grade(x, z)) - .2
	block(Vector3(x, (foundation + base + 2.8) * .5, z - 4.75),
		Vector3(14, base + 2.8 - foundation, 9.5), siding, true)
	var roof := PrismMesh.new()
	roof.size = Vector3(9.9, 1.05, 14.45)
	Kit.mesh_at(shop, roof, Vector3(x, base + 3.32, z - 4.75), dark).rotation.y = PI * .5
	block(Vector3(x, base + 2.785, z - 4.75), Vector3(14.5, .14, 9.95), white)
	sign_panel("FAMOUS PIZZA", Vector3(x - 2.1, base + 1.95, z + .06), 4.9, .78, red, Color.WHITE)
	for offset in [2.1, 4.6]:
		block(Vector3(x + offset, base + 1.19, z + .04), Vector3(1.5, 2.10, .15), white)
		block(Vector3(x + offset, base + 1.27, z + .14), Vector3(1.3, 1.82, .075), glazing)
	block(Vector3(x + 3.3, base + .04, z + .44), Vector3(5.0, .25, .9), concrete, true)


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
	var y := grade(PIZZA_LEFT, z)
	block(Vector3(PIZZA_LEFT, y + .19, z), Vector3(2.75, .38, 1.4), concrete, true)
	for offset in [-1.05, 1.05]:
		block(Vector3(PIZZA_LEFT + offset, y + 2.66, z), Vector3(.13, 5.2, .17), white, true)
	var blue := Kit.paint(Color("#244777"))
	var green := Kit.paint(Color("#14723c"))
	for side: float in [-1.0, 1.0]:
		var angle := 0.0 if side > 0 else PI
		var face := z + side * .15
		sign_panel("Esso", Vector3(PIZZA_LEFT, y + 4.68, face), 2.16, 1.02, white, Color("#b72428"), angle)
		sign_panel("172.9", Vector3(PIZZA_LEFT, y + 3.86, face), 2.16, .58, blue, Color("#ff7359"), angle)
		sign_panel("Convenience", Vector3(PIZZA_LEFT, y + 3.31, face), 2.16, .47, blue, Color.WHITE, angle)
		sign_panel("SUBWAY", Vector3(PIZZA_LEFT, y + 2.78, face), 2.16, .53, green, Color("#f4dd60"), angle)


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
		ink: Color, angle := 0.0) -> void:
	var panel := Kit.box_at(self, at, Vector3(width, height, .12), finish)
	panel.rotation.y = angle
	var label := Label3D.new()
	label.text = title
	label.font = SIGN_FONT
	label.font_size = 56
	label.pixel_size = minf(height * .62 / label.font_size,
		width * .88 / label.font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x)
	label.outline_size = 0
	label.modulate = ink
	label.double_sided = false
	label.position.z = .066
	panel.add_child(label)
