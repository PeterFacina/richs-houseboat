extends StaticBody3D

const Kit = preload("res://scenery.gd")
const Door = preload("res://public_works_door.gd")
const SITE := Vector2(18835.7969, 13339.1946)
const HEADING := -.746
const REPLACED_FOOTPRINTS := ["379147344", "ms-180", "ms-405"]
const PARKING := [Vector2(-11.0, 2.8), Vector2(-4.6, 2.8)]
const SHANNON := Vector2(-24.94, 5.16)
const OFFICE_ENTRY := Vector2(-24.25, 9.24)
const CEDAR_ROAD := [
	[18578.0, 13397.0], [18592.0, 13384.0], [18617.0, 13376.0],
	[18648.0, 13359.0], [18688.0, 13335.0], [18725.0, 13308.0],
	[18758.0, 13288.0], [18778.0, 13279.0], [18813.0, 13279.0],
	[18835.0, 13282.0], [18845.0, 13276.0], [18847.0, 13258.0],
]
const YARD_DRIVE := [
	[18813.0, 13279.0], [18815.0, 13291.0], [18815.7, 13303.0],
	[18810.0, 13321.0], [18801.0, 13338.0], [18798.0, 13350.0],
]
const FRONT := 8.16
const TRUCK_PARKING := [Vector3(18858, -.70, 13373), Vector3(18869, -.62, 13379), Vector3(18878, 1.78, 13392)]
const PERIMETER := [
	Vector2(18823, 13305), Vector2(18870, 13300), Vector2(18887, 13321),
	Vector2(18912, 13344), Vector2(18938, 13374), Vector2(18925, 13398),
	Vector2(18877, 13408), Vector2(18831, 13397), Vector2(18790, 13391),
	Vector2(18782, 13367), Vector2(18791, 13339), Vector2(18800, 13319),
	Vector2(18808, 13301),
]

var river: Node3D
var doors: Array[Door] = []
var office_doors: Array[AnimatableBody3D] = []
var office_targets := PackedFloat32Array([0.0, 0.0])
var monitor_focus: Vector3
var office_floor := 0.0


func build(map: Node3D) -> void:
	river = map
	name = "PublicWorks"
	global_position = ground_point(SITE)
	rotation.y = HEADING
	var brick := ShaderMaterial.new()
	brick.shader = preload("res://public_works_masonry.gdshader")
	brick.set_shader_parameter("grit", river.concrete_scan)
	brick.set_shader_parameter("base_y", global_position.y)
	var concrete := Kit.paint(Color("#a7a49a"))
	concrete.albedo_texture = river.concrete_scan
	concrete.uv1_triplanar = true
	var metal := Kit.paint(Color("#444a48"), .61, .37)
	var green := Kit.paint(Color("#355853"), .72, .21)
	var trim := Kit.paint(Color("#707970"), .63, .26)
	build_gravel()
	var shop_floor := ShaderMaterial.new()
	shop_floor.shader = preload("res://public_works_floor.gdshader")
	shop_floor.set_shader_parameter("concrete_scan", river.concrete_scan)
	surface(Rect2(-20.5, -8.1, 41, 16), shop_floor)
	surface(Rect2(-20.5, 7.9, 41, 9), concrete)
	wall(Vector3(0, 3.4, -FRONT), Vector3(41, 8.2, .35), brick)
	for side: float in [-1, 1]:
		wall(Vector3(side * 20.5, 3.4, 0), Vector3(.36, 8.2, 16.3), brick)
		for stripe in 9:
			Kit.box_at(self, Vector3(side * 20.69, 1.7, (stripe - 4) * 1.77),
				Vector3(.028, .16, .85), concrete)
	wall(Vector3(0, 7.56, 0), Vector3(41.65, .23, 16.9), metal)
	wall(Vector3(0, 6.67, FRONT), Vector3(41, 1.55, .37), brick)
	Kit.box_at(self, Vector3(0, 5.98, FRONT + .23), Vector3(41, .15, .12), concrete)
	var left := -17.4
	for index in 5:
		var x := left + index * 6.4
		var floor := to_local(at_ground(Vector2(x, FRONT))).y
		var door := Door.new()
		add_child(door)
		door.position = Vector3(x, floor - .04, FRONT + .26)
		door.build(index + 1)
		doors.append(door)
		var header_bottom := door.position.y + Door.HEIGHT - .04
		var header_top := 5.91
		if header_bottom < header_top:
			Kit.box_at(self, Vector3(x, (header_bottom + header_top) * .5, FRONT + .36),
				Vector3(Door.WIDTH + .09, header_top - header_bottom, .115), metal)
		shop_sign(str(index + 1), Vector3(x, 6.42, FRONT + .211), .012)
		Kit.box_at(self, Vector3(x, 7.31, -2.4), Vector3(.28, .07, 3.6), concrete)
		Kit.box_at(self, Vector3(x, 7.31, 3.7), Vector3(.28, .07, 3.6), concrete)
		if index < 4:
			wall(Vector3(x + 3.2, 2.64, FRONT), Vector3(1.2, 6.56, .45), brick)
		for side: float in [-1, 1]:
			Kit.box_at(self, Vector3(x + side * (Door.WIDTH * .5 + .029), (header_top + floor) * .5 - .12, FRONT + .36),
				Vector3(.12, header_top - floor + .26, .095), metal)
			build_bollard(Vector2(x + side * 2.93, FRONT + .94))
	wall(Vector3(-20.23, 2.64, FRONT), Vector3(.53, 6.56, .45), brick)
	wall(Vector3(12.15, 2.64, FRONT), Vector3(2.71, 6.56, .45), brick)
	wall(Vector3(19.5, 2.64, FRONT), Vector3(2.0, 6.56, .45), brick)
	wall(Vector3(15.99, 4.48, FRONT), Vector3(4.99, 3.0, .38), brick)
	shop_sign("DEEP RIVER  /  PUBLIC WORKS", Vector3(16, 6.68, FRONT + .22), .0078)
	seal_wall_base(Vector2(-20.5, -FRONT), Vector2(20.5, -FRONT), brick)
	for side: float in [-1.0, 1.0]:
		seal_wall_base(Vector2(side * 20.5, -FRONT), Vector2(side * 20.5, FRONT), brick)
	build_office(brick, metal, concrete)
	build_workshop(metal)
	build_shed(Vector2(18799.7843, 13375.5242), Vector2(5.85, 4.35), .97, 6.1, green, trim)
	build_shed(Vector2(18819.5799, 13381.2013), Vector2(7.95, 12.1), .67, 6.6, green, trim)
	for index in range(PERIMETER.size() - 1):
		build_fence(PERIMETER[index], PERIMETER[index + 1], metal)
	build_fence(PERIMETER.front(), Vector2(18825, 13311), metal)
	build_fence(PERIMETER.back(), Vector2(18805, 13306), metal)
	build_dump_pile()
	for x: float in [20.0, 20.53]:
		var drum := CylinderMesh.new()
		drum.top_radius = .25
		drum.bottom_radius = .25
		drum.height = .84
		Kit.mesh_at(self, drum, to_local(at_ground(Vector2(x, FRONT + 1.3))) + Vector3.UP * .42,
			Kit.paint(Color("#296287"), .58, .12))


func seal_wall_base(start: Vector2, finish: Vector2, brick: Material) -> void:
	var along := finish - start
	var count := ceili(along.length() / 1.5)
	var span := along.length() / count
	for index in count:
		var a := start.lerp(finish, float(index) / count)
		var b := start.lerp(finish, float(index + 1) / count)
		var bottom := minf(to_local(at_ground(a)).y, to_local(at_ground(b)).y) - .21
		if bottom >= -.70:
			continue
		var middle := (a + b) * .5
		var width := Vector3(span + .03, -.59 - bottom, .33) if absf(along.x) > absf(along.y) \
			else Vector3(.34, -.59 - bottom, span + .03)
		wall(Vector3(middle.x, (bottom - .59) * .5, middle.y), width, brick)


func build_office(brick: Material, frame: Material, floor_paint: Material) -> void:
	office_floor = to_local(at_ground(OFFICE_ENTRY)).y
	var y := office_floor
	surface(Rect2(-27.7, 1.2, 8, 8), floor_paint)
	wall(Vector3(-20.60, y + 1.35, 8.62), Vector3(.36, 3.46, 1.54), brick)
	wall(Vector3(-27.7, y + 1.35, 5.2), Vector3(.28, 3.46, 8.0), brick)
	wall(Vector3(-24.1, y + 1.35, 1.25), Vector3(7.0, 3.46, .28), brick)
	wall(Vector3(-24.1, y + 3.05, 5.32), Vector3(7.45, .23, 8.45), frame)
	wall(Vector3(-24.1, y + 2.74, 9.24), Vector3(7.19, .59, .27), brick)
	wall(Vector3(-27.2, y + 1.1, 9.24), Vector3(.84, 2.66, .25), brick)
	wall(Vector3(-21.05, y + 1.1, 9.24), Vector3(1.16, 2.66, .25), brick)
	wall(Vector3(-26.73, y + 1.13, 9.24), Vector3(.21, 2.68, .23), brick)
	wall(Vector3(-21.76, y + 1.13, 9.24), Vector3(.27, 2.68, .23), brick)
	wall(Vector3(OFFICE_ENTRY.x, y + 2.37, OFFICE_ENTRY.y), Vector3(4.79, .20, .14), frame)
	var glass := Kit.paint(Color(.51, .74, .77, .23), .22, .24)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var metal := Kit.paint(Color("#92938d"), .39, .59)
	for side: float in [-1.0, 1.0]:
		var panel := AnimatableBody3D.new()
		panel.sync_to_physics = false
		add_child(panel)
		office_doors.append(panel)
		panel.position = Vector3(OFFICE_ENTRY.x + side * 1.14, y + 1.17, OFFICE_ENTRY.y + .06)
		var center := Vector3(-side * .57, 0, 0)
		Kit.box_at(panel, center, Vector3(1.10, 2.24, .066), glass)
		Kit.collider(panel, center, Vector3(1.13, 2.29, .08))
		for outline: float in [-1.0, 1.0]:
			Kit.box_at(panel, center + Vector3(outline * .552, 0, 0), Vector3(.053, 2.30, .093), frame)
			Kit.box_at(panel, center + Vector3(0, outline * 1.13, 0), Vector3(1.13, .055, .093), frame)
			Kit.box_at(panel, center + Vector3(-side * .41, -.04, outline * .083), Vector3(.028, .35, .08), metal)
		var sidelight := Vector3(OFFICE_ENTRY.x + side * 1.77, y + 1.17, OFFICE_ENTRY.y - .065)
		wall(sidelight, Vector3(1.22, 2.26, .072), glass)
		for outline: float in [-1.0, 1.0]:
			Kit.box_at(self, sidelight + Vector3(outline * .61, 0, 0), Vector3(.048, 2.31, .10), frame)
			Kit.box_at(self, sidelight + Vector3(0, outline * 1.15, 0), Vector3(1.25, .045, .10), frame)
	shop_sign("PUBLIC WORKS OFFICE", Vector3(OFFICE_ENTRY.x, y + 2.68, OFFICE_ENTRY.y + .15), .0065)
	build_corner_desk(frame, metal)
	lamp(Vector3(-24.4, y + 2.87, 5.48), 1.8, 6.4, 1.07)


func build_corner_desk(frame: Material, metal: Material) -> void:
	var y := office_floor
	var wood := Kit.paint(Color("#81634a"), .76)
	var dark := Kit.paint(Color("#27292b"), .8)
	wall(Vector3(-26.03, y + .76, 4.90), Vector3(.96, .10, 3.48), wood)
	wall(Vector3(-25.02, y + .76, 3.62), Vector3(1.12, .10, .92), wood)
	wall(Vector3(-26.05, y + .34, 3.64), Vector3(.71, .72, .84), frame)
	for at: Vector3 in [Vector3(-25.75, y + .37, 6.49), Vector3(-24.55, y + .37, 3.39)]:
		Kit.box_at(self, at, Vector3(.07, .74, .07), metal)
	var terminal := Node3D.new()
	add_child(terminal)
	terminal.position = Vector3(-25.82, y + .81, 5.50)
	terminal.rotation.y = 1.60
	Kit.box_at(terminal, Vector3(0, .025, 0), Vector3(.27, .047, .18), dark)
	Kit.box_at(terminal, Vector3(0, .16, -.045), Vector3(.066, .25, .043), frame)
	Kit.box_at(terminal, Vector3(0, .326, 0), Vector3(.66, .382, .061), dark)
	var listing := ShaderMaterial.new()
	listing.shader = preload("res://public_works_mower_screen.gdshader")
	var screen := QuadMesh.new()
	screen.size = Vector2(.625, .347)
	Kit.mesh_at(terminal, screen, Vector3(0, .326, .032), listing)
	var title := Label3D.new()
	terminal.add_child(title)
	title.position = Vector3(-.131, .456, .038)
	title.text = "ZERO-TURN MOWERS"
	title.pixel_size = .00058
	title.font_size = 22
	title.outline_size = 0
	title.modulate = Color("#f2f7f8")
	monitor_focus = terminal.to_global(Vector3(0, .33, .039))
	Kit.box_at(terminal, Vector3(0, .023, .26), Vector3(.32, .026, .112), dark)
	for row in 4:
		for key in 12:
			Kit.box_at(terminal, Vector3(-.142 + key * .026, .040, .218 + row * .024),
				Vector3(.018, .009, .015), frame)
	Kit.box_at(terminal, Vector3(.238, .019, .26), Vector3(.063, .033, .102), dark)
	var chair := Node3D.new()
	add_child(chair)
	chair.position = Vector3(SHANNON.x, y, SHANNON.y)
	chair.rotation.y = -.92
	Kit.box_at(chair, Vector3(0, .445, 0), Vector3(.48, .084, .45), dark)
	Kit.box_at(chair, Vector3(0, .75, -.22), Vector3(.47, .51, .081), dark).rotation.x = -.08
	for side: float in [-1.0, 1.0]:
		Kit.box_at(chair, Vector3(side * .21, .62, -.047), Vector3(.062, .047, .31), dark)
	Kit.box_at(chair, Vector3.UP * .23, Vector3(.086, .43, .086), metal)
	for angle in 5:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, angle * TAU / 5.0)
		Kit.beam(chair, Vector3.UP * .10, direction * .23 + Vector3.UP * .064, .036, metal)
		Kit.box_at(chair, direction * .23 + Vector3.UP * .034, Vector3(.059, .066, .053), dark)


func office_handle(eye: Camera3D) -> int:
	if eye.global_position.distance_squared_to(to_global(Vector3(OFFICE_ENTRY.x, office_floor + 1.1, OFFICE_ENTRY.y))) > 12.0:
		return -1
	var nearest := -1
	var best_alignment := .57
	for index in office_doors.size():
		var side := float(2 * index - 1)
		var offset := office_doors[index].to_global(Vector3(-side * 1.0, -.04, 0)) - eye.global_position
		var alignment := offset.normalized().dot(-eye.global_basis.z) if offset.length_squared() < 2.85 * 2.85 else 0.0
		if absf(office_doors[index].rotation.y) > .33:
			var jamb := office_doors[index].global_position - eye.global_position
			if jamb.length_squared() < 2.65 * 2.65:
				alignment = maxf(alignment, jamb.normalized().dot(-eye.global_basis.z) * .94)
		if alignment > best_alignment:
			best_alignment = alignment
			nearest = index
	return nearest


func office_prompt(index: int, eye: Camera3D) -> String:
	if is_zero_approx(office_targets[index]) and absf(office_doors[index].rotation.y) > .05:
		return "E  Reopen office door"
	return "E  %s office door" % ("Push" if office_pushes_away(index, eye) else "Pull")


func office_pushes_away(index: int, eye: Camera3D) -> bool:
	var outside := to_local(eye.global_position).z >= OFFICE_ENTRY.y
	var side := float(2 * index - 1)
	return is_zero_approx(office_targets[index]) or (office_targets[index] * side > 0.0) == outside


func toggle_office(index: int, eye: Camera3D) -> void:
	if not is_zero_approx(office_targets[index]):
		office_targets[index] = 0.0
		return
	var swing := -1.0 if to_local(eye.global_position).z >= OFFICE_ENTRY.y else 1.0
	office_targets[index] = swing * (2 * index - 1) * 1.57


func build_workshop(frame: Material) -> void:
	var oxide := Kit.paint(Color("#8a332b"), .65, .22)
	var steel := Kit.paint(Color("#8b9390"), .43, .46)
	var plywood := Kit.paint(Color("#795d43"), .90)
	var storage := Kit.paint(Color("#65746a"), .73)
	var tools := preload("res://crew_tools.gd")
	for bay in 5:
		var x := -17.4 + bay * 6.4
		lamp(Vector3(x, 7.35, 2.2), 3.0, 10.5, .85)
		var y := to_local(at_ground(Vector2(x, -6.55))).y
		wall(Vector3(x, y + .47, -6.55), Vector3(3.10, .94, .80), frame)
		Kit.box_at(self, Vector3(x, y + .99, -6.55), Vector3(3.23, .11, .94), plywood)
		Kit.box_at(self, Vector3(x, y + 1.64, -7.02), Vector3(3.14, 1.16, .10), storage)
		var drawer := x + 1.0
		for row in 4:
			var height := y + .18 + row * .197
			Kit.box_at(self, Vector3(drawer, height, -6.045), Vector3(.89, .174, .05), oxide)
			Kit.box_at(self, Vector3(drawer, height, -6.004), Vector3(.40, .029, .05), steel)
		for index in 6:
			var at := Vector3(x - 1.18 + index * .37, y + 1.66 + (index % 2) * .16, -6.943)
			var size := .27 + (index % 3) * .105
			var handle := plywood if index % 3 == 0 else steel
			tools.tube(self, at + Vector3.DOWN * size * .6, at + Vector3.UP * size * .34, .022, .016, handle)
			tools.shell(self, at + Vector3.UP * size * .40, Vector3(.11, .068, .035), steel)
	for x: float in [15.2, 18.2]:
		var y := to_local(at_ground(Vector2(x, -6.55))).y
		for p: float in [-.92, .92]:
			for depth: float in [-7.19, -5.96]:
				Kit.box_at(self, Vector3(x + p, y + 1.22, depth), Vector3(.07, 2.52, .073), steel)
		for level in 4:
			var shelf_y := y + .28 + level * .62
			Kit.box_at(self, Vector3(x, shelf_y, -6.57), Vector3(1.88, .061, 1.26), steel)
			for bin in 3:
				var at := Vector3(x + (bin - 1) * .56, shelf_y + .18, -6.56)
				Kit.box_at(self, at, Vector3(.43, .28, .75), plywood if (bin + level) % 3 == 0 else storage)
				Kit.box_at(self, at + Vector3(0, .07, .385), Vector3(.18, .065, .02), steel)
		Kit.collider(self, Vector3(x, y + 1.22, -6.57), Vector3(1.9, 2.5, 1.25))
	lamp(Vector3(16, 7.35, 2.2), 2.5, 10.5, .85)


func build_dump_pile() -> void:
	var pile := StaticBody3D.new()
	pile.name = "DumpPile"
	add_child(pile)
	pile.global_position = ground_point(Vector2(18840, 13391))
	var rock_paint := Kit.paint(Color("#60564a"))
	rock_paint.albedo_texture = river.riverbed
	rock_paint.uv1_triplanar = true
	rock_paint.uv1_scale = Vector3.ONE * .8
	var random := RandomNumberGenerator.new()
	random.seed = 412
	for i in 10:
		var stone := SphereMesh.new()
		stone.rings = 4
		stone.radial_segments = 9
		var angle := i * TAU / 10.0
		var at := Vector3(cos(angle) * random.randf_range(.1, 4.1), -.7, sin(angle) * random.randf_range(.1, 3.0))
		var item := Kit.mesh_at(pile, stone, at, rock_paint)
		item.scale = Vector3(random.randf_range(2.8, 5.4), random.randf_range(2.2, 4.4), random.randf_range(2.3, 4.5))
		item.rotation.y = angle
		var shape := CollisionShape3D.new()
		shape.shape = item.mesh.create_convex_shape()
		pile.add_child(shape)
		shape.transform = item.transform
	for i in 49:
		var at := Vector3(random.randf_range(-6.0, 6.0), 0, random.randf_range(-4.3, 4.3))
		if Vector2(at.x / 6.0, at.z / 4.3).length_squared() > 1.0:
			continue
		var world := pile.to_global(at)
		at.y = river.ground_height(world.x, world.z) - pile.global_position.y + .06
		var chip := Kit.box_at(pile, at, Vector3(random.randf_range(.13, .54), .17, random.randf_range(.10, .43)), rock_paint)
		chip.rotation.y = random.randf_range(0.0, TAU)


func lamp(at: Vector3, width: float, throw_distance: float, energy: float) -> void:
	var fixture := Kit.paint(Color("#eee7ce"), .45)
	fixture.emission_enabled = true
	fixture.emission = Color("#fff0d9")
	fixture.emission_energy_multiplier = .53
	Kit.box_at(self, at, Vector3(width, .064, .18), fixture)
	var light := OmniLight3D.new()
	light.light_color = Color("#fff1df")
	light.light_energy = energy
	light.omni_range = throw_distance
	add_child(light)
	light.position = at - Vector3.UP * .28


func build_gravel() -> void:
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://public_works_gravel.gdshader")
	paint.set_shader_parameter("concrete_scan", river.concrete_scan)
	paint.set_shader_parameter("grit_scan", river.riverbed)
	var yard := Node3D.new()
	yard.name = "PublicWorksGravel"
	river.add_child(yard)
	river.waterfront.drape(yard, [[18798, 13331], [18821, 13355],
		[18832, 13385], [18791, 13370]], paint, .039)
	river.waterfront.drape(yard, [[18813, 13349], [18857, 13365],
		[18846, 13393], [18799, 13375]], paint, .043)
	var apron: Array = []
	for corner: Vector2 in [Vector2(-21.6, 14.2), Vector2(22, 14.1), Vector2(24, 29), Vector2(-20.5, 30)]:
		var point := at_ground(corner)
		apron.append([point.x, point.z])
	river.waterfront.drape(yard, apron, paint, .040)
	river.waterfront.drape(yard, [[18840, 13358], [18910, 13361],
		[18916, 13401], [18844, 13399]], paint, .036)


static func cleared_for_construction(foot: Vector3) -> bool:
	var point := Vector2(foot.x, foot.z)
	var local := (point - SITE).rotated(HEADING)
	return road_clearance(point) or Rect2(-28.5, -9.0, 50, 25.9).has_point(local) \
		or point.distance_squared_to(Vector2(18799.7843, 13375.5242)) < 16.0 \
		or point.distance_squared_to(Vector2(18819.5799, 13381.2013)) < 53.0


static func road_clearance(point: Vector2) -> bool:
	if not Rect2(18568, 13248, 291, 164).has_point(point):
		return false
	for line in [CEDAR_ROAD, YARD_DRIVE]:
		for index in range(1, line.size()):
			var a := Vector2(line[index - 1][0], line[index - 1][1])
			var b := Vector2(line[index][0], line[index][1])
			if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, a, b)) < 33.64:
				return true
	return false


func ground_point(point: Vector2) -> Vector3:
	return Vector3(point.x, river.ground_height(point.x, point.y), point.y)


func at_ground(at: Vector2) -> Vector3:
	var world := to_global(Vector3(at.x, 0, at.y))
	return ground_point(Vector2(world.x, world.z))


func wall(at: Vector3, size: Vector3, paint: Material) -> void:
	Kit.box_at(self, at, size, paint)
	Kit.collider(self, at, size)


func shop_sign(title: String, at: Vector3, scale_per_pixel: float) -> void:
	var label := Label3D.new()
	label.text = title
	label.font_size = 48
	label.pixel_size = scale_per_pixel
	label.modulate = Color("#eee8d7")
	add_child(label)
	label.position = at


func build_bollard(at: Vector2) -> void:
	var foot := to_local(at_ground(at))
	var paint := Kit.paint(Color("#d7a32e"), .62)
	Kit.box_at(self, foot + Vector3.UP * .56, Vector3(.13, 1.12, .13), paint)


func build_shed(site: Vector2, span: Vector2, heading: float, height: float, siding: Material, trim: Material) -> void:
	var shed := StaticBody3D.new()
	add_child(shed)
	shed.global_position = ground_point(site)
	shed.global_rotation.y = heading
	var size := Vector3(span.x, height + .6, span.y)
	Kit.box_at(shed, Vector3.UP * (height * .5 - .3), size, siding)
	Kit.collider(shed, Vector3.UP * (height * .5 - .3), size)
	Kit.box_at(shed, Vector3(0, .42, span.y * .5 + .018), Vector3(span.x, 1.3, .06), trim)
	for side: float in [-1, 1]:
		var roof := Kit.box_at(shed, Vector3(side * span.x * .255, height + .40, 0),
			Vector3(span.x * .54, .14, span.y + .68), trim)
		roof.rotation.z = -.24 * side
	for index in ceili(span.x / .24):
		var x := -.5 * span.x + index * .24
		Kit.box_at(shed, Vector3(x, height * .57, span.y * .5 + .039), Vector3(.034, height * .85, .043), trim)
	Kit.box_at(shed, Vector3(0, 2.12, span.y * .5 + .075), Vector3(span.x * .70, 4.27, .07), Kit.paint(Color("#34413d")))


func build_fence(start: Vector2, finish: Vector2, material: Material) -> void:
	var mesh := ShaderMaterial.new()
	mesh.shader = preload("res://public_works_fence.gdshader")
	var sections := maxi(1, ceili(start.distance_to(finish) / 3.1))
	for index in sections:
		var a := to_local(ground_point(start.lerp(finish, float(index) / sections)))
		var b := to_local(ground_point(start.lerp(finish, float(index + 1) / sections)))
		var length := a.distance_to(b)
		var post := Kit.box_at(self, a + Vector3.UP * 1.12, Vector3(.082, 2.24, .082), material)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for height: float in [.17, 2.02]:
			Kit.beam(self, a + Vector3.UP * height, b + Vector3.UP * height, .049, material)
		var wire := SurfaceTool.new()
		wire.begin(Mesh.PRIMITIVE_TRIANGLES)
		for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
			wire.set_uv(Vector2(uv.x * length, uv.y * 1.85))
			wire.add_vertex(a.lerp(b, uv.x) + Vector3.UP * (.17 + uv.y * 1.85))
		wire.generate_normals()
		Kit.mesh_at(self, wire.commit(), Vector3.ZERO, mesh).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var collision := CollisionShape3D.new()
		var bar := BoxShape3D.new()
		bar.size = Vector3(.10, 2.04, length)
		collision.shape = bar
		add_child(collision)
		collision.position = (a + b) * .5 + Vector3.UP
		collision.basis = Basis.looking_at(b - a, Vector3.UP)
	var foot := to_local(ground_point(finish))
	Kit.box_at(self, foot + Vector3.UP * 1.12, Vector3(.082, 2.24, .082), material)


func surface(area: Rect2, paint: Material) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in int(area.size.y):
		for x in int(area.size.x):
			var corner := area.position + Vector2(x, z)
			for offset: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN,
					Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
				mesh.add_vertex(to_local(at_ground(corner + offset)) + Vector3.UP * .055)
	mesh.generate_normals()
	Kit.mesh_at(self, mesh.commit(), Vector3.ZERO, paint)


func nearby_door(eye: Camera3D) -> Door:
	if global_position.distance_squared_to(eye.global_position) > 28.0 * 28.0:
		return null
	var nearest: Door
	var best := 2.55 * 2.55
	for door in doors:
		var offset := door.to_global(door.chain) - eye.global_position
		var distance := offset.length_squared()
		if distance < best and offset.normalized().dot(-eye.global_basis.z) > .45:
			best = distance
			nearest = door
	return nearest


func advance(delta: float, player: Node3D, mower: Node3D, spare: Node3D) -> void:
	var occupants: Array[Node3D] = [player, mower, spare]
	for door in doors:
		door.advance(delta, occupants)
	var at := to_local(player.global_position)
	for index in office_doors.size():
		var leaf := office_doors[index]
		var target := office_targets[index]
		var current := leaf.rotation.y
		if is_equal_approx(current, target):
			continue
		var next := move_toward(current, target, delta * 2.75)
		var side := float(2 * index - 1)
		var hinge := Vector2(leaf.position.x, leaf.position.z)
		var foot := Vector2(at.x, at.z)
		var tip := hinge + Vector2(-side * 1.13, 0).rotated(-next)
		var old_tip := hinge + Vector2(-side * 1.13, 0).rotated(-current)
		var next_clearance := foot.distance_squared_to(Geometry2D.get_closest_point_to_segment(foot, hinge, tip))
		var old_clearance := foot.distance_squared_to(Geometry2D.get_closest_point_to_segment(foot, hinge, old_tip))
		if absf(at.y - office_floor) < 1.6 and next_clearance < .31 * .31 and next_clearance < old_clearance:
			continue
		leaf.rotation.y = next
