extends Node3D

const Kit = preload("res://scenery.gd")
const Bench = preload("res://lamure_beach.gd")
const FOOTPRINTS := ["384191400", "243198179", "243198178"]
const ORIGIN := Vector2(18003.882, 13356.1399)
const ANGLE := -.397
const WEST := [Vector2(-10.35, -9), Vector2(10.35, -9), Vector2(10.35, 9), Vector2(-10.35, 9)]
const CIVIC := [Vector2(10.35, -9), Vector2(19, -8.5), Vector2(36.8, -3), Vector2(31.3, 14.5), Vector2(10.35, 9)]
const POLICE := [Vector2(19, -8.5), Vector2(22.9, -21.2), Vector2(40.7, -15.8), Vector2(36.8, -3)]
const ATRIUM_X := 10.4
const ATRIUM_FRONT := 11.8
const ATRIUM_REAR := -8.7
const ATRIUM_HALF := 4.25
const EAVE := 8.3
const PEAK := 12.55
const POLICE_EAVE := 4.75
const PLAZA_CANOPY_Z := 21.55
const PLAZA_CANOPY_WIDTH := 33.0

var ground: Callable
var collision := StaticBody3D.new()
var boxes := {}
var masonry: Material
var sandstone: Material
var footing: Material
var roof: Material
var copper: Material
var copper_seam: Material
var mullion: Material
var dark: Material
var glass: ShaderMaterial
var glass_alt: ShaderMaterial
var concrete: Material
var steel: Material
var white: Material
var lamp_glass: StandardMaterial3D
var exterior_lights: Array[OmniLight3D] = []
var monument: Material
var rng := RandomNumberGenerator.new()
var crowns: Array[Transform3D] = []
var stems: Array[Transform3D] = []


func build(elevation: Callable, concrete_scan: Texture2D, canopy: Callable) -> void:
	name = "DeepRiverTownHall"
	ground = elevation
	position = Vector3(ORIGIN.x, ground.call(ORIGIN.x, ORIGIN.y) + .08, ORIGIN.y)
	rotation.y = ANGLE
	add_child(collision)
	rng.seed = 384191400
	make_materials(concrete_scan)
	block_roof(WEST, EAVE)
	block_roof(CIVIC, EAVE)
	block_roof(POLICE, POLICE_EAVE)

	# Champlain Street wraps around the civic front and the west return.
	ribbon_wall(Vector2(-10.35, 9), Vector2(10.35, 9), EAVE, true, true)
	ribbon_wall(Vector2(10.35, 9), Vector2(31.3, 14.5), EAVE, true, true)
	ribbon_wall(Vector2(-10.35, -9), Vector2(-10.35, 9), EAVE, true, false)
	ribbon_wall(WEST[1], WEST[0], EAVE, true, false)
	ribbon_wall(CIVIC[1], CIVIC[0], EAVE, false, false)
	close_roof_step(CIVIC[2], CIVIC[1])
	ribbon_wall(POLICE[0], POLICE[1], POLICE_EAVE, false, false)
	ribbon_wall(POLICE[2], POLICE[1], POLICE_EAVE, true, false)
	service_wall(Vector2(31.3, 14.5), Vector2(36.8, -3), true)
	service_wall(Vector2(36.8, -3), Vector2(40.7, -15.8), false)

	build_atrium()
	build_civic_plaza()
	for mount in [Vector3(-6.0, EAVE + .11, -4.3), Vector3(26.0, EAVE + .11, 1.7)]:
		roof_unit(mount)
	antenna(Vector3(-8.7, EAVE + .15, -5.3), 1.85)
	antenna(Vector3(31.3, EAVE + .15, 3.4), 2.45)
	canopy.call(self, crowns, stems)
	flush_boxes()


func make_materials(concrete_scan: Texture2D) -> void:
	masonry = brick(Color("#995f4e"), Color("#8d8070"))
	sandstone = brick(Color("#b09a80"), Color("#8e8170"))
	footing = Kit.paint(Color("#746b60"))
	roof = Kit.paint(Color("#47494a"))
	copper = Kit.paint(Color("#6d9b92"), .58, .32)
	copper_seam = Kit.paint(Color("#4d726e"), .56, .3)
	mullion = Kit.paint(Color("#3e494b"), .44, .42)
	dark = Kit.paint(Color("#262c30"))
	steel = Kit.paint(Color("#596264"), .55, .5)
	white = Kit.paint(Color("#f1efe4"), .66)
	concrete = Kit.paint(Color("#d9ccc0"))
	concrete.albedo_texture = concrete_scan
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3.ONE * .68
	monument = Kit.paint(Color("#b79f96"), .5)
	lamp_glass = Kit.paint(Color("#fff2cc"), .32)
	lamp_glass.emission_enabled = true
	lamp_glass.emission = Color("#f5d294")
	lamp_glass.emission_energy_multiplier = 0.0
	glass = ShaderMaterial.new()
	glass.shader = preload("res://deep_river_town_hall_glass.gdshader")
	glass_alt = glass.duplicate()
	glass_alt.set_shader_parameter("tone", .91)


func set_evening(amount: float) -> void:
	for material in [glass, glass_alt]:
		material.set_shader_parameter("evening", amount)
	lamp_glass.emission_energy_multiplier = .66 * amount
	for lamp in exterior_lights:
		lamp.visible = amount > .005
		lamp.light_energy = 1.15 * amount


func brick(tint: Color, mortar: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://deep_river_town_hall_brick.gdshader")
	mat.set_shader_parameter("brick", tint)
	mat.set_shader_parameter("mortar", mortar)
	return mat


func box(at: Vector3, size: Vector3, material: Material, frame := Transform3D.IDENTITY) -> void:
	if not boxes.has(material):
		boxes[material] = []
	boxes[material].append(frame * Transform3D(Basis.from_scale(size), at))


func flush_boxes() -> void:
	var cube := BoxMesh.new()
	for material: Material in boxes:
		var transforms: Array = boxes[material]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = cube
		batch.instance_count = transforms.size()
		for i in transforms.size():
			batch.set_instance_transform(i, transforms[i])
		var detail := MultiMeshInstance3D.new()
		detail.multimesh = batch
		detail.material_override = material
		add_child(detail)
	boxes.clear()


func wall_frame(a: Vector2, b: Vector2) -> Transform3D:
	var along := (b - a).normalized()
	var midpoint := (a + b) * .5
	return Transform3D(Basis(Vector3(along.x, 0, along.y), Vector3.UP, Vector3(-along.y, 0, along.x)),
		Vector3(midpoint.x, 0, midpoint.y))


func solid_wall(frame: Transform3D, width: float, height: float) -> void:
	var body := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height + 1.0, .36)
	body.shape = shape
	collision.add_child(body)
	body.transform = frame.translated_local(Vector3(0, height * .5 - .5, -.18))
	box(Vector3(0, height * .5 - .6, -.20), Vector3(width + .025, height + 1.2, .4), masonry, frame)
	box(Vector3(0, .18, -.18), Vector3(width + .065, .48, .46), footing, frame)
	box(Vector3(0, .63, -.18), Vector3(width + .045, .23, .45), sandstone, frame)
	box(Vector3(0, height - .23, -.18), Vector3(width + .065, .28, .47), sandstone, frame)
	box(Vector3(0, height - .052, -.17), Vector3(width + .11, .11, .54), roof, frame)


func ribbon_wall(a: Vector2, b: Vector2, height: float, windows: bool, civic: bool) -> void:
	var frame := wall_frame(a, b)
	var width := a.distance_to(b)
	solid_wall(frame, width, height)
	box(Vector3(0, 3.44, -.17), Vector3(width + .06, .26, .47), sandstone, frame)
	if not windows:
		for i in 2:
			louver(frame, (i - .5) * width * .5, height - 1.25, .68, .44)
		return
	window_strip(frame, .015, 1.82, width - 2.3, 1.48, 2.3)
	if height > 5.0:
		window_strip(frame, 0, 6.42 if civic else 5.80, width - (1.55 if civic else 2.6),
			3.18 if civic else 1.82, 2.15)
	for x in [-width * .5 + .47, width * .5 - .47]:
		box(Vector3(x, height * .5, -.043), Vector3(.32, height - .35, .12), masonry, frame)


func window_strip(frame: Transform3D, x: float, y: float, width: float, height: float, bay_size: float) -> void:
	box(Vector3(x, y, .047), Vector3(width + .14, height + .13, .09), mullion, frame)
	var count := maxi(1, roundi(width / bay_size))
	var bay := width / count
	for i in count:
		var center := x - width * .5 + (i + .5) * bay
		box(Vector3(center, y, .10), Vector3(bay - .075, height - .065, .028), glass if i % 3 != 1 else glass_alt, frame)
	var transom := y - height * .25
	box(Vector3(x, transom, .123), Vector3(width, .055, .046), mullion, frame)
	box(Vector3(x, y - height * .5 - .086, .070), Vector3(width + .2, .10, .20), sandstone, frame)


func block_roof(outline: Array, height: float) -> void:
	var boundary := PackedVector2Array(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in Geometry2D.triangulate_polygon(boundary):
		var p := boundary[i]
		surface.set_normal(Vector3.UP)
		surface.set_uv(p * .25)
		surface.add_vertex(Vector3(p.x, height - .105, p.y))
	Kit.mesh_at(self, surface.commit(), Vector3.ZERO, roof)


func close_roof_step(a: Vector2, b: Vector2) -> void:
	var frame := wall_frame(a, b)
	var width := a.distance_to(b)
	var height := EAVE - POLICE_EAVE + .23
	var center := Vector3(0, EAVE - height * .5, -.18)
	var size := Vector3(width + .06, height, .36)
	box(center, size, masonry, frame)
	var body := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	body.shape = shape
	collision.add_child(body)
	body.transform = frame.translated_local(center)
	box(Vector3(0, EAVE - .22, -.18), Vector3(width + .08, .28, .45), sandstone, frame)
	box(Vector3(0, EAVE - .04, -.18), Vector3(width + .13, .10, .53), roof, frame)
	for x in [-4.5, 4.5]:
		louver(frame, x, POLICE_EAVE + 1.33, .74, .45)


func service_wall(a: Vector2, b: Vector2, fire: bool) -> void:
	var frame := wall_frame(a, b)
	var width := a.distance_to(b)
	var height := EAVE if fire else POLICE_EAVE
	solid_wall(frame, width, height)
	if fire:
		box(Vector3(0, 4.42, -.17), Vector3(width, .30, .46), sandstone, frame)
		wordmark(frame, Vector3(.25, 6.56, .106), "TOWN OF DEEP RIVER\nEMERGENCY SERVICES", .84, Color("#e7e4db"))
		wordmark(frame, Vector3(-6.85, 3.82, .112), "FIRE DEPARTMENT", .32, Color("#dddcd2"))
		louver(frame, -7.0, 5.0, 1.1, .73)
		for x in [-2.25, 2.1, 6.45]:
			bay_door(frame, x, 3.55, 4.18, true)
		downspout(frame, 8.45, height)
	else:
		wordmark(frame, Vector3(4.55, 3.62, .11), "POLICE SERVICE", .39, Color("#deddd5"))
		window_strip(frame, 4.75, 1.75, 1.8, 1.48, 1.8)
		for x in [-3.85, -.10]:
			bay_door(frame, x, 3.14, 3.12, false)
		downspout(frame, -6.45, height)


func bay_door(frame: Transform3D, x: float, width: float, height: float, fire: bool) -> void:
	box(Vector3(x, height * .5, .057), Vector3(width + .16, height + .1, .10), dark, frame)
	for row in 7:
		var panel_y := (row + .5) * height / 7.0
		for col in (4 if fire else 3):
			var count := 4 if fire else 3
			var panel_x := x + (col + .5) * width / count - width * .5
			var mat: Material = dark if not fire or row == 0 or row == 6 else glass_alt
			box(Vector3(panel_x, panel_y, .118), Vector3(width / count - .046, height / 7.0 - .045, .045), mat, frame)
		box(Vector3(x, row * height / 7.0, .151), Vector3(width, .041, .048), steel, frame)
	if not fire:
		box(Vector3(x, height + .53, .12), Vector3(width + .12, .96, .18), footing, frame)
		for slat in 15:
			box(Vector3(x - width * .46 + slat * width * .065, height + .53, .222),
				Vector3(.025, .87, .028), roof, frame)
	wall_light(frame, x - width * .60, height - .08)


func louver(frame: Transform3D, x: float, y: float, width: float, height: float) -> void:
	box(Vector3(x, y, .055), Vector3(width, height, .105), dark, frame)
	for row in 6:
		box(Vector3(x, y + (row - 2.5) * height / 6.0, .12), Vector3(width - .13, .032, .054), steel, frame)


func wall_light(frame: Transform3D, x: float, y: float) -> void:
	box(Vector3(x, y + .055, .18), Vector3(.30, .23, .33), mullion, frame)
	box(Vector3(x, y - .058, .23), Vector3(.22, .035, .18), lamp_glass, frame)
	add_exterior_light(frame * Vector3(x, y - .15, .30), 4.5)


func downspout(frame: Transform3D, x: float, height: float) -> void:
	box(Vector3(x, height * .5, .1), Vector3(.085, height - .2, .095), steel, frame)
	box(Vector3(x, .16, .18), Vector3(.09, .085, .26), steel, frame)


func wordmark(frame: Transform3D, at: Vector3, text: String, cap_height: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 80
	label.pixel_size = cap_height / 60.0
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = false
	label.double_sided = false
	add_child(label)
	label.transform = frame.translated_local(at)


func build_atrium() -> void:
	var center := ATRIUM_X
	var width := ATRIUM_HALF * 2.0
	var bezel := Kit.paint(Color("#414b48"), .44, .4)
	var depth := ATRIUM_FRONT - ATRIUM_REAR
	var ridge := Vector3(center, PEAK, ATRIUM_FRONT + .38)
	for side in [-1.0, 1.0]:
		var eave := Vector3(center + side * ATRIUM_HALF, EAVE, ridge.z)
		var slope := (ridge - eave).length()
		var angle := atan2(ridge.y - eave.y, ridge.x - eave.x)
		var frame := Transform3D(Basis(Vector3.BACK, angle), (ridge + eave) * .5 - Vector3.BACK * (depth * .5))
		box(Vector3.ZERO, Vector3(slope + .21, .19, depth + .82), copper, frame)
		for sheet in 12:
			box(Vector3(0, .117, (sheet - 5.5) * depth / 11.4), Vector3(slope + .12, .035, .037), copper_seam, frame)
		box(Vector3(0, .01, depth * .5 + .43), Vector3(slope + .25, .26, .10), bezel, frame)
		var cheek := wall_frame(Vector2(eave.x, ATRIUM_FRONT), Vector2(eave.x, 8.5))
		if side < 0:
			cheek = wall_frame(Vector2(eave.x, 8.5), Vector2(eave.x, ATRIUM_FRONT))
		solid_wall(cheek, 3.3, EAVE)
		window_strip(cheek, 0, 5.58, 3.08, 4.8, 1.5)
		var pier_x: float = center + side * (ATRIUM_HALF + .40)
		box(Vector3(pier_x, EAVE * .5, ATRIUM_FRONT - .8), Vector3(.76, EAVE, 1.52), masonry)
	box(Vector3(center, PEAK + .085, (ATRIUM_FRONT + ATRIUM_REAR) * .5),
		Vector3(.22, .12, depth + .86), copper_seam)
	gable_glass()
	rear_gable()
	entry_canopy(center, ATRIUM_FRONT)
	var frame := wall_frame(Vector2(center - ATRIUM_HALF, ATRIUM_FRONT), Vector2(center + ATRIUM_HALF, ATRIUM_FRONT))
	var blocker := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, EAVE, .34)
	blocker.shape = shape
	collision.add_child(blocker)
	blocker.transform = frame.translated_local(Vector3(0, EAVE * .5, -.04))


func gable_glass() -> void:
	var frame := wall_frame(Vector2(ATRIUM_X - ATRIUM_HALF, ATRIUM_FRONT), Vector2(ATRIUM_X + ATRIUM_HALF, ATRIUM_FRONT))
	window_strip(frame, 0, 5.65, ATRIUM_HALF * 2.0, 5.26, 1.73)
	window_strip(frame, 0, 1.55, ATRIUM_HALF * 2.0, 2.92, 1.73)
	for x in [-.82, .82]:
		box(Vector3(x, 1.50, .18), Vector3(.055, 2.72, .07), steel, frame)
		box(Vector3(x * .31, 1.10, .26), Vector3(.062, .24, .10), steel, frame)
	var divisions := 6
	for i in divisions:
		var a := -ATRIUM_HALF + 2.0 * ATRIUM_HALF * i / divisions
		var b := a + 2.0 * ATRIUM_HALF / divisions
		var points := PackedVector2Array([Vector2(a, EAVE - .075), Vector2(b, EAVE - .075),
			Vector2(b, gable_y(b)), Vector2(a, gable_y(a))])
		draw_gable(points, frame, glass if i % 2 == 0 else glass_alt)
		var height := gable_y(a) - EAVE
		if height > .2:
			box(Vector3(a, EAVE + height * .5, .055), Vector3(.065, height, .10), mullion, frame)
	for y in [9.3, 10.55, 11.63]:
		var segment := (1.0 - (float(y) - EAVE) / (PEAK - EAVE)) * ATRIUM_HALF
		box(Vector3(0, y, .072), Vector3(segment * 2.0, .06, .11), mullion, frame)
	clock_face(frame, Vector3(0, 10.05, .23))


func gable_y(x: float) -> float:
	return lerpf(PEAK, EAVE, absf(x) / ATRIUM_HALF)


func draw_gable(points: PackedVector2Array, frame: Transform3D, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 2, 1, 0, 3, 2]:
		var p := points[i]
		surface.set_normal(frame.basis.z)
		surface.set_color(Color("#8c9ca2"))
		surface.set_uv(Vector2(0.21 + i % 2 * .57, (p.y - EAVE + .1) / 4.4))
		surface.add_vertex(frame * Vector3(p.x, p.y, .035))
	Kit.mesh_at(self, surface.commit(), Vector3.ZERO, material)


func rear_gable() -> void:
	var z := ATRIUM_REAR
	var frame := wall_frame(Vector2(ATRIUM_X + ATRIUM_HALF, z), Vector2(ATRIUM_X - ATRIUM_HALF, z))
	draw_gable(PackedVector2Array([Vector2(-ATRIUM_HALF, EAVE), Vector2(ATRIUM_HALF, EAVE),
		Vector2(0, PEAK), Vector2(-ATRIUM_HALF, EAVE)]), frame, copper)
	for i in 14:
		var x := (i - 6.5) * .59
		var height := gable_y(x) - EAVE
		box(Vector3(x, EAVE + height * .5, .060), Vector3(.035, height, .03), copper_seam, frame)


func clock_face(frame: Transform3D, at: Vector3) -> void:
	cylinder(frame * at, 1.02, 1.02, .15, steel, Basis(Vector3.RIGHT, PI * .5))
	cylinder(frame * (at + Vector3.BACK * .091), .91, .91, .047, white, Basis(Vector3.RIGHT, PI * .5))
	for tick in 12:
		var angle := TAU * tick / 12.0
		var mark := at + Vector3(sin(angle) * .744, cos(angle) * .744, .126)
		box(Vector3.ZERO, Vector3(.032, .13 if tick % 3 == 0 else .07, .024), dark,
			frame * Transform3D(Basis(Vector3.BACK, -angle), mark))
	for hand in [Vector2(PI / 3, .60), Vector2(-PI / 3, .46)]:
		var mark := at + Vector3(sin(hand.x) * hand.y * .42, cos(hand.x) * hand.y * .42, .15)
		box(Vector3.ZERO, Vector3(.054, hand.y, .037), dark,
			frame * Transform3D(Basis(Vector3.BACK, -hand.x), mark))
	cylinder(frame * (at + Vector3.BACK * .174), .068, .068, .032, dark, Basis(Vector3.RIGHT, PI * .5))


func entry_canopy(x: float, z: float) -> void:
	var front := z + 3.5
	var center_z := (z + front) * .5
	for side in [-1.0, 1.0]:
		var mount := Transform3D(Basis(Vector3.BACK, -side * .36), Vector3(x + side * 1.74, 3.78, center_z))
		box(Vector3.ZERO, Vector3(3.70, .15, 3.74), copper, mount)
		for seam in 8:
			box(Vector3((seam - 3.5) * .44, .09, 0), Vector3(.032, .028, 3.78), copper_seam, mount)
	box(Vector3(x, 3.12, center_z), Vector3(7.05, .23, 3.75), mullion)
	for px in [x - 3.28, x + 3.28]:
		cylinder(Vector3(px, 1.47, front - .18), .10, .115, 3.25, steel)
		wall_light(Transform3D.IDENTITY, px, 2.7)



func grade(x: float, z: float) -> float:
	var point := to_global(Vector3(x, 0, z))
	return float(ground.call(point.x, point.z)) - global_position.y


func build_civic_plaza() -> void:
	paving(Rect2(ATRIUM_X - 17.75, 18.85, 35.5, 6.7), concrete, .11)
	paving(Rect2(7.0, 13.1, 7.2, 27.4), concrete, .10)
	for z in [15.5, 18.5, 30.0, 35.2, 38.5]:
		box(Vector3(10.6, grade(10.6, z) + .112, z), Vector3(7.05, .009, .028), footing)

	build_plaza_canopy()
	civic_memorial()
	flagpole(-2.3, 17.9, false)
	flagpole(21.0, 19.2, true)
	for at in [Vector2(-8.4, 30.05), Vector2(16.4, 36.7), Vector2(29.1, 28.95)]:
		street_lamp(at)
	for at in [Vector2(-7.7, 28.9), Vector2(18.6, 31.5)]:
		var bench := Bench.build_bench(self, Vector3(at.x, grade(at.x, at.y), at.y), Kit.paint(Color("#8b7963")))
		bench.rotation.y = PI
	for at in [Vector2(-6.9, 12.8), Vector2(27.3, 18.3), Vector2(-2.9, 33.3)]:
		garden_tree(at)
	for bed in [Rect2(-8.4, 14.2, 10.1, 3.15), Rect2(14.55, 15.1, 9.8, 3.0)]:
		garden_bed(bed)
	for side in [-1.0, 1.0]:
		var angle: float = side * .34
		var center := Vector3(10.25 + side * 4.74, 0, 35.5)
		var frame := Transform3D(Basis(Vector3.UP, angle), center)
		garden_bed(Rect2(-.59, -3.3, 1.18, 6.6), frame)
		for i in 4:
			var point := frame * Vector3(side * .8, 0, -3.1 + i * .96)
			point.y = grade(point.x, point.z) + .43
			var proportions := Vector3(1.53, 1.08, 1.1) * rng.randf_range(.69, 1.11)
			crowns.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(proportions), point))


func build_plaza_canopy() -> void:
	var at := Vector3(ATRIUM_X, grade(ATRIUM_X, PLAZA_CANOPY_Z) + 3.42, PLAZA_CANOPY_Z)
	box(at, Vector3(PLAZA_CANOPY_WIDTH, .58, 4.25), concrete)
	box(at + Vector3(0, .33, 0), Vector3(PLAZA_CANOPY_WIDTH + .15, .10, 4.31), roof)
	box(at + Vector3(0, -.28, 2.08), Vector3(PLAZA_CANOPY_WIDTH - .05, .10, .12), sandstone)
	wordmark(Transform3D.IDENTITY, at + Vector3(0, .016, 2.162),
		"THE CORPORATION OF THE TOWN OF DEEP RIVER", .27, Color("#4a453b"))
	for offset: float in [-15.5, -11.5, -4.25, 4.25, 11.5, 15.5]:
		var x := at.x + offset
		for z: float in [at.z - 1.8, at.z + 1.69]:
			var base := grade(x, z) + .09
			var height := at.y - base
			var post := Vector3(x, base + height * .5, z)
			cylinder(post, .107, .124, height, mullion)
			Kit.collider(collision, post, Vector3(.24, height, .24))
			box(Vector3(x, base + .08, z), Vector3(.33, .16, .33), footing)
	for offset: float in [-13.5, -8.1, -2.7, 2.7, 8.1, 13.5]:
		box(at + Vector3(offset, -.312, -.07), Vector3(.86, .065, .21), lamp_glass)
		add_exterior_light(at + Vector3(offset, -.43, -.07), 5.0)


func civic_memorial() -> void:
	var at := Vector3(8.96, grade(8.96, 29.43), 29.43)
	for course in 3:
		box(at + Vector3(0, .093 + course * .14, 0), Vector3(4.36 - course * .46, .142, 2.5 - course * .36),
			footing if course == 1 else concrete)
	box(at + Vector3(-.82, 1.99, 0), Vector3(.63, 3.35, .73), monument)
	box(at + Vector3(-.82, 3.69, 0), Vector3(.65, .075, .75), monument)
	monument_plinth(at)
	box(at + Vector3(-.82, 2.79, .372), Vector3(.038, .34, .014), footing)
	box(at + Vector3(-.82, 2.82, .374), Vector3(.21, .034, .014), footing)
	wordmark(Transform3D.IDENTITY, at + Vector3(-.82, 2.17, .371), "IN\nREMEMBRANCE", .068, Color("#776759"))
	for side in [-1.0, 1.0]:
		cylinder(at + Vector3(side * 1.75, .50, .39), .23, .16, .36, masonry)
		garden_bed(Rect2(at.x + side * 2.15 - .48, at.z + .56, .96, .77))


func paving(area: Rect2, material: Material, lift: float, frame := Transform3D.IDENTITY) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := maxi(1, ceili(area.size.x / 2.0))
	var rows := maxi(1, ceili(area.size.y / 2.0))
	for row in rows + 1:
		for col in columns + 1:
			var point := area.position + area.size * Vector2(float(col) / columns, float(row) / rows)
			var p := frame * Vector3(point.x, 0, point.y)
			p.y = grade(p.x, p.z) + lift
			surface.set_uv(Vector2(p.x, p.z) * .3)
			surface.add_vertex(p)
	var stride := columns + 1
	for row in rows:
		for col in columns:
			var i := row * stride + col
			for vertex in [i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]:
				surface.add_index(vertex)
	surface.generate_normals()
	var apron := Kit.mesh_at(self, surface.commit(), Vector3.ZERO, material)
	apron.create_trimesh_collision()


func cylinder(at: Vector3, top: float, bottom: float, height: float, material: Material, basis := Basis.IDENTITY) -> void:
	var part := CylinderMesh.new()
	part.top_radius = top
	part.bottom_radius = bottom
	part.height = height
	part.radial_segments = 20 if maxf(top, bottom) > .6 else 10
	var mesh := Kit.mesh_at(self, part, at, material)
	mesh.basis = basis


func antenna(at: Vector3, height: float) -> void:
	cylinder(at + Vector3.UP * height * .5, .019, .027, height, steel)
	for i in 3:
		var angle := TAU * i / 3.0
		var leg := at + Vector3(cos(angle) * .52, 0, sin(angle) * .52)
		Kit.beam(self, leg, at + Vector3.UP * height * .72, .026, steel)
	Kit.beam(self, at + Vector3(-.33, height - .12, 0), at + Vector3(.33, height - .12, 0), .022, steel)


func roof_unit(at: Vector3) -> void:
	box(at + Vector3.UP * .26, Vector3(2.45, .52, 1.26), roof)
	box(at + Vector3.UP * .52, Vector3(2.57, .090, 1.34), steel)
	for row in 6:
		box(at + Vector3(0, .13 + row * .051, .641), Vector3(2.14, .021, .05), dark)


func street_lamp(at: Vector2) -> void:
	var foot := Vector3(at.x, grade(at.x, at.y), at.y)
	cylinder(foot + Vector3.UP * .22, .15, .23, .44, dark)
	cylinder(foot + Vector3.UP * 2.51, .046, .085, 4.68, dark)
	var previous := foot + Vector3.UP * 4.77
	for i in range(1, 13):
		var angle := PI - PI * i / 12.0
		var next := foot + Vector3(.40 + .40 * cos(angle), 4.77 + .43 * sin(angle), 0)
		Kit.beam(self, previous, next, .052, dark)
		previous = next
	cylinder(previous - Vector3.UP * .12, .065, .25, .26, dark)
	cylinder(previous - Vector3.UP * .263, .195, .17, .08, lamp_glass)
	add_exterior_light(previous - Vector3.UP * .38, 8.0)


func add_exterior_light(at: Vector3, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffdbac")
	lamp.omni_range = reach
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 85.0
	lamp.distance_fade_length = 35.0
	lamp.hide()
	add_child(lamp)
	lamp.position = at
	exterior_lights.append(lamp)


func flagpole(x: float, z: float, ontario: bool) -> void:
	var base := Vector3(x, grade(x, z), z)
	cylinder(base + Vector3.UP * .105, .25, .30, .21, concrete)
	cylinder(base + Vector3.UP * 4.58, .034, .063, 9.15, steel)
	cylinder(base + Vector3.UP * 9.17, .057, .068, .18, footing)
	var image := Image.new()
	var svg := canadian_flag() if not ontario else ontario_flag()
	if image.load_svg_from_string(svg) != OK:
		return
	image.generate_mipmaps()
	var material := Kit.paint(Color.WHITE)
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 15
	for row in 2:
		for i in columns + 1:
			var u := float(i) / columns
			surface.set_uv(Vector2(u, row))
			surface.add_vertex(base + Vector3(.04 + u * 2.55, 8.99 - row * 1.28 - u * .22,
				sin(u * 8.8) * .26 * u + u * .36))
	for i in columns:
		for vertex in [i, i + 1, i + columns + 1, i + 1, i + columns + 2, i + columns + 1]:
			surface.add_index(vertex)
	surface.generate_normals()
	Kit.mesh_at(self, surface.commit(), Vector3.ZERO, material)


func canadian_flag() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="128" viewBox="0 0 200 100">
	<path fill="#c82735" d="M0 0h200v100H0z"/><path fill="#fff" d="M50 0h100v100H50z"/>
	<path fill="#d32937" d="m100 15 7 16 7-4-3 21 12-11 2 6 13-3-4 12 5 4-24 19 3 7-16-2 1 11h-6l1-11-16 2 3-7-24-19 5-4-4-12 13 3 2-6 12 11-3-21 7 4z"/></svg>"""


func ontario_flag() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="128" viewBox="0 0 200 100">
	<path fill="#ad2530" d="M0 0h200v100H0z"/><path fill="#243657" d="M0 0h97v48H0z"/>
	<path stroke="#fff" stroke-width="9" d="M0 0l97 48m0-48L0 48"/><path stroke="#b7333e" stroke-width="3" d="M0 0l97 48m0-48L0 48"/>
	<path stroke="#fff" stroke-width="14" d="M0 24h97M48.5 0v48"/><path stroke="#b7333e" stroke-width="8" d="M0 24h97M48.5 0v48"/>
	<path fill="#236641" stroke="#e3ca98" stroke-width="2" d="M138 31h28v22q-1 11-14 18-13-7-14-18z"/>
	<path fill="#fff3d7" d="M139 32h26v13h-26z"/><path stroke="#b63237" stroke-width="3" d="M139 38h26m-13-6v13"/>
	<path stroke="#edc75c" stroke-width="2" d="m152 63-7-7m7 7v-13m0 13 7-7"/></svg>"""


func garden_tree(at: Vector2) -> void:
	var base := Vector3(at.x, grade(at.x, at.y), at.y)
	crowns.append(Transform3D(Basis.from_scale(Vector3(4.85, 4.06, 3.85)), base + Vector3.UP * 3.20))
	crowns.append(Transform3D(Basis(Vector3.UP, .6).scaled_local(Vector3(2.7, 2.55, 2.9)),
		base + Vector3(.76, 4.13, .37)))
	stems.append(Transform3D(Basis.from_scale(Vector3(.39, 3.60, .39)), base + Vector3.UP * 1.54))


func garden_bed(area: Rect2, mount := Transform3D.IDENTITY) -> void:
	var soil := Kit.paint(Color("#655746"))
	paving(area, soil, .046, mount)
	var leaf := Kit.paint(Color("#52743a"))
	var petal := [Kit.paint(Color("#c84744")), Kit.paint(Color("#e4933c")), Kit.paint(Color("#965b66"))]
	for i in maxi(6, roundi(area.get_area() * 2.0)):
		var point := mount * Vector3(rng.randf_range(area.position.x + .15, area.end.x - .15), 0,
			rng.randf_range(area.position.y + .13, area.end.y - .13))
		var x := point.x
		var z := point.z
		var stem := rng.randf_range(.18, .40)
		var y := grade(x, z) + .04
		box(Vector3(x, y + stem * .45, z), Vector3(.037, stem, .034), leaf)
		var angle := rng.randf_range(0, TAU)
		var frame := Transform3D(Basis(Vector3.UP, angle), Vector3(x, y, z))
		box(Vector3(.041, stem * .68, 0), Vector3(.15, .036, .075), leaf, frame)
		for axis in 3:
			var flower := frame.rotated_local(Vector3.UP, axis * PI / 3.0)
			box(Vector3(0, stem + .017, 0), Vector3(.15, .041, .056), petal[i % 3], flower)


func monument_plinth(at: Vector3) -> void:
	var points := PackedVector3Array([Vector3(-.47, .44, .33), Vector3(1.37, .44, .33),
		Vector3(.22, 1.35, .33), Vector3(-.47, .44, -.33), Vector3(1.37, .44, -.33), Vector3(.22, 1.35, -.33)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 2, 1, 3, 4, 5, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 4]:
		surface.add_vertex(at + points[i])
	surface.generate_normals()
	Kit.mesh_at(self, surface.commit(), Vector3.ZERO, monument)
