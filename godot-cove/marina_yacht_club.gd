extends RefCounted

const Kit = preload("res://scenery.gd")
const Pines = preload("res://lamure_pines.gd")

# Traced from Geospatial Ontario imagery, with elevations and trim interpreted
# from Come Wander's DeepRiver_2 and Bob and Diana McElroy's concert photograph.
const ORIGIN := Vector2(17933.5, 12709.25)
const LANDSCAPE := Rect2(17913, 12689, 54, 51)
const HALL := [
	Vector2(-9.25, 1.05), Vector2(-8.25, -5.45), Vector2(-.60, -7.90),
	Vector2(7.45, -5.60), Vector2(8.60, 4.80), Vector2(1.75, 7.25),
]
const WING_NEAR := Vector2(7.35, 10.65)
const WING_AXIS := Vector2(.28, .96)
const WING_CROSS := Vector2(.96, -.28)
const HALL_EAVE := 3.16
const WING_EAVE := 2.58
const LINK_EAVE := 2.52
const RED := Color("#71382f")
const TIMBER := Color("#64332e")
const IVORY := Color("#dedcd1")
const HALL_SHINGLES := Color("#a5aaa5")
const WING_SHINGLES := Color("#605853")
const GLASS := Color("#7a8d89")

var club: Node3D
var ground: Callable
var shell := SurfaceTool.new()
var trim := SurfaceTool.new()
var glazing := SurfaceTool.new()
var roofing := SurfaceTool.new()


func build(parent: Node3D, elevation: Callable, windows: ShaderMaterial, aggregate: Texture2D) -> void:
	ground = elevation
	club = Node3D.new()
	club.name = "HexagonYachtClub"
	parent.add_child(club)
	club.position = at_ground(ORIGIN, ground)
	for surface: SurfaceTool in [shell, trim, glazing, roofing]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	build_hall()
	var near_left := WING_NEAR - WING_CROSS * 3.55
	var near_right := WING_NEAR + WING_CROSS * 3.55
	var far_left := near_left + WING_AXIS * 11.45
	var far_right := near_right + WING_AXIS * 11.45
	build_wing(near_left, near_right, far_right, far_left)
	build_link(Vector2(1.55, 6.78), Vector2(8.10, 4.55), near_right, near_left)

	var walls := Kit.mesh_at(club, shell.commit(), Vector3.ZERO, vertex_paint())
	walls.create_trimesh_collision()
	Kit.mesh_at(club, trim.commit(), Vector3.ZERO, vertex_paint())
	var panes := Kit.mesh_at(club, glazing.commit(), Vector3.ZERO, windows)
	panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shingles := ShaderMaterial.new()
	shingles.shader = preload("res://marina_yacht_roof.gdshader")
	shingles.set_shader_parameter("aggregate", aggregate)
	Kit.mesh_at(club, roofing.commit(), Vector3.ZERO, shingles)


func build_hall() -> void:
	var peak := point(Vector2(-.1, -.78), HALL_EAVE + 2.06)
	for index in HALL.size():
		var eave_a: Vector2 = HALL[(index + 1) % HALL.size()]
		var eave_b: Vector2 = HALL[index]
		var a := eave_a - eave_a.normalized() * .52
		var b := eave_b - eave_b.normalized() * .52
		wall(a, b, HALL_EAVE, HALL_EAVE)
		hall_windows(a, b, index == 3)
		var high_a := point(eave_a, HALL_EAVE + .13)
		var high_b := point(eave_b, HALL_EAVE + .13)
		roof_triangle(high_a, high_b, peak, HALL_SHINGLES)
		eave_trim(high_a, high_b, point(a, HALL_EAVE - .08), point(b, HALL_EAVE - .08))


func build_wing(near_left: Vector2, near_right: Vector2, far_right: Vector2, far_left: Vector2) -> void:
	var outline := [near_left, near_right, far_right, far_left]
	for index in outline.size():
		var a: Vector2 = outline[(index + 1) % outline.size()]
		var b: Vector2 = outline[index]
		wall(a, b, WING_EAVE, WING_EAVE, true)
		if index in [1, 3]:
			var along := (b - a).normalized()
			var face := frontage(a, along)
			for distance: float in [2.15, 5.72, 9.42]:
				window(face + horizontal(along) * distance + Vector3.UP * 1.09,
					along, 1.16, 1.04, IVORY)

	var eave_near := WING_NEAR - WING_AXIS * .32
	var eave_far := WING_NEAR + WING_AXIS * 11.77
	var ridge_a := point(eave_near, WING_EAVE + .53)
	var ridge_b := point(eave_far, WING_EAVE + .53)
	for side: float in [-1.0, 1.0]:
		var lip_a := point(eave_near + WING_CROSS * (3.84 * side), WING_EAVE + .10)
		var lip_b := point(eave_far + WING_CROSS * (3.84 * side), WING_EAVE + .10)
		roof_triangle(lip_a, lip_b, ridge_a, WING_SHINGLES)
		roof_triangle(lip_b, ridge_b, ridge_a, WING_SHINGLES, lip_a)
		var inner_a := point(WING_NEAR + WING_CROSS * (3.55 * side), WING_EAVE - .08)
		var inner_b := inner_a + horizontal(WING_AXIS) * 11.45
		eave_trim(lip_a, lip_b, inner_a, inner_b, horizontal(WING_CROSS) * side)

	for side: float in [-1.0, 1.0]:
		var end := WING_NEAR + WING_AXIS * (0.0 if side < 0.0 else 11.45)
		var outward := horizontal(WING_AXIS) * side
		var peak := point(end, WING_EAVE + .49)
		var left := point(end - WING_CROSS * 3.55, WING_EAVE)
		var right := point(end + WING_CROSS * 3.55, WING_EAVE)
		triangle(trim, left, right, peak, outward, RED)
		var roof_peak := peak + outward * .32 + Vector3.UP * .04
		for corner: Vector3 in [left, right]:
			var edge := corner + (corner - point(end, WING_EAVE)).normalized() * .29
			edge += outward * .32 + Vector3.UP * .10
			eave_trim(edge, roof_peak, corner - Vector3.UP * .08, peak, outward)

	var vent := point(WING_NEAR + WING_AXIS * 2.2 + WING_CROSS * .85, WING_EAVE + .89)
	var box := Kit.box_at(club, vent, Vector3(.91, 1.14, .91), Kit.paint(IVORY))
	box.basis = Basis(horizontal(WING_CROSS), Vector3.UP, horizontal(WING_AXIS))
	var cap := Kit.box_at(club, vent + Vector3.UP * .58, Vector3(1.05, .12, 1.05),
		Kit.paint(Color("#858783")))
	cap.basis = box.basis


func build_link(hall_left: Vector2, hall_right: Vector2, wing_right: Vector2, wing_left: Vector2) -> void:
	wall(hall_left, wing_left, LINK_EAVE, LINK_EAVE, true)
	wall(wing_right, hall_right, LINK_EAVE, LINK_EAVE, true)
	var pale := Color("#8f8e83")
	var a := point(hall_left + Vector2(-.15, 0), LINK_EAVE + .17)
	var b := point(hall_right + Vector2(.15, 0), LINK_EAVE + .17)
	var c := point(wing_right + Vector2(.15, 0), LINK_EAVE + .14)
	var d := point(wing_left + Vector2(-.15, 0), LINK_EAVE + .14)
	roof_triangle(a, b, c, pale)
	roof_triangle(a, c, d, pale)
	eave_trim(a, d, point(hall_left, LINK_EAVE - .02), point(wing_left, LINK_EAVE - .02))
	eave_trim(c, b, point(wing_right, LINK_EAVE - .02), point(hall_right, LINK_EAVE - .02))

	var along := (wing_left - hall_left).normalized()
	var out := normal_to(along)
	var face := frontage(hall_left, along)
	for distance: float in [.83, 2.22]:
		window(face + horizontal(along) * distance + Vector3.UP * .42, along, 1.23, 1.71, IVORY)
	var entry := face + horizontal(along) * 4.03
	panel(trim, entry - horizontal(along) * .64 + Vector3.UP * .07, along, 1.28, 2.13, IVORY)
	panel(glazing, entry - horizontal(along) * .30 + out * .019 + Vector3.UP * .72, along,
		.59, 1.18, GLASS)
	panel(trim, entry - horizontal(along) * .46 + out * .021 + Vector3.UP * .92, along,
		.045, .27, TIMBER)

	build_approach(Vector2(entry.x, entry.z), Vector2(out.x, out.z))


func hall_windows(a: Vector2, b: Vector2, river_door: bool) -> void:
	var width := a.distance_to(b)
	var along := (b - a) / width
	var axis := horizontal(along)
	var outward := normal_to(along)
	var face := frontage(a, along)
	var count := maxi(2, roundi(width / 1.46))
	var bay := (width - .32) / count
	panel(trim, face + axis * .10 + Vector3.UP * .26, along, width - .20, 2.80, TIMBER)
	for index in count:
		var edge := face + axis * (.16 + index * bay) + outward * .016
		var is_door := river_door and index == floori(count * .5)
		panel(glazing, edge + axis * .066 + Vector3.UP * (.68 if is_door else .43),
			along, bay - .132, 1.36 if is_door else 1.61, GLASS)
		panel(glazing, edge + axis * .066 + Vector3.UP * 2.13, along, bay - .132, .52, GLASS)
		panel(trim, edge + axis * .066 + Vector3.UP * 2.74, along, bay - .132, .265, IVORY)
		if is_door:
			panel(trim, edge + axis * .22 + outward * .012 + Vector3.UP * .95, along, .045, .26, IVORY)


func window(center: Vector3, along: Vector2, width: float, height: float, frame_color: Color) -> void:
	var axis := horizontal(along)
	var lower := center - axis * width * .5
	var outward := normal_to(along)
	panel(trim, lower, along, width, height, frame_color)
	var pane_height := (height - .225) * .5
	for level in 2:
		var glass_start := lower + axis * .075 + Vector3.UP * (.075 + level * (pane_height + .075))
		panel(glazing, glass_start + outward * .014, along, width - .15, pane_height, GLASS)


func wall(a: Vector2, b: Vector2, top_a: float, top_b: float, boards := false) -> void:
	var along := (b - a).normalized()
	var outward := normal_to(along)
	var foot_a := point(a, minf(.0, local_ground(a)) - .075)
	var foot_b := point(b, minf(.0, local_ground(b)) - .075)
	quad(shell, foot_a, point(a, top_a), foot_b, point(b, top_b), outward, RED)
	if boards:
		var count := ceili(a.distance_to(b) / .205)
		for index in range(1, count):
			var fraction := float(index) / count
			var place := a.lerp(b, fraction)
			var board_base := minf(.0, local_ground(place)) - .06
			var origin := point(place, board_base) + outward * .008
			panel(trim, origin, along, .021, lerpf(top_a, top_b, fraction) - board_base,
				RED.darkened(.18))


func build_approach(entrance: Vector2, outward: Vector2) -> void:
	var route := Curve2D.new()
	route.bake_interval = .35
	route.add_point(entrance, Vector2.ZERO, outward * 3.4)
	route.add_point(Vector2(-8.45, 15.60), Vector2(3.35, -2.80))
	var path := route.get_baked_points()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	surface.set_normal(Vector3.UP)
	for index in path.size():
		var forward := (path[mini(index + 1, path.size() - 1)] - path[maxi(index - 1, 0)]).normalized()
		var right := Vector2(forward.y, -forward.x)
		for side: float in [-1.0, 1.0]:
			var p := path[index] + right * side * (.72 if index == 0 else .62)
			surface.add_vertex(point(p, local_ground(p) + .032))
	var walk := Kit.mesh_at(club, surface.commit(), Vector3.ZERO, Kit.paint(Color("#8e8e83")))
	walk.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED


func roof_triangle(a: Vector3, b: Vector3, c: Vector3, color: Color,
		uv_origin := Vector3.INF) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var order := [a, b, c] if normal.y > 0.0 else [a, c, b]
	if normal.y < 0.0:
		normal = -normal
	var across := Vector3.UP.cross(normal).normalized() if normal.y < .9999 else Vector3.RIGHT
	var uphill := normal.cross(across)
	var start := a if uv_origin == Vector3.INF else uv_origin
	roofing.set_color(color)
	roofing.set_normal(normal)
	for p: Vector3 in order:
		var offset := p - start
		roofing.set_uv(Vector2(offset.dot(across), offset.dot(uphill)))
		roofing.add_vertex(p)


func eave_trim(a: Vector3, b: Vector3, inner_a: Vector3, inner_b: Vector3,
		outward := Vector3.ZERO) -> void:
	if outward == Vector3.ZERO:
		outward = (b - a).cross(Vector3.UP).normalized()
	var drop := Vector3.UP * .16
	quad(trim, a - drop, a, b - drop, b, outward, IVORY)
	quad(trim, inner_a, a - drop, inner_b, b - drop, Vector3.DOWN, IVORY.darkened(.11))


func frontage(a: Vector2, along: Vector2) -> Vector3:
	return point(a, 0) + normal_to(along) * .024


func local_ground(p: Vector2) -> float:
	return float(ground.call(ORIGIN.x + p.x, ORIGIN.y + p.y)) - club.position.y


static func horizontal(p: Vector2) -> Vector3:
	return Vector3(p.x, 0, p.y)


static func point(p: Vector2, height: float) -> Vector3:
	return Vector3(p.x, height, p.y)


static func normal_to(along: Vector2) -> Vector3:
	return horizontal(along).cross(Vector3.UP)


static func vertex_paint() -> StandardMaterial3D:
	var material := Kit.paint(Color.WHITE, .88)
	material.vertex_color_use_as_albedo = true
	return material


static func panel(surface: SurfaceTool, p: Vector3, along: Vector2, width: float, height: float,
		color: Color) -> void:
	var right := p + horizontal(along) * width
	quad(surface, p, p + Vector3.UP * height, right, right + Vector3.UP * height,
		normal_to(along), color)


static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, color: Color) -> void:
	var positions := [a, b, c, d]
	var uv := [Vector2.DOWN, Vector2.ZERO, Vector2.ONE, Vector2.RIGHT]
	var order := [0, 1, 2, 1, 3, 2]
	if (c - a).cross(b - a).dot(normal) < 0.0:
		order = [0, 2, 1, 1, 2, 3]
	surface.set_color(color)
	surface.set_normal(normal)
	for index: int in order:
		surface.set_uv(uv[index])
		surface.add_vertex(positions[index])


static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		normal: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.set_normal(normal)
	var order := [a, b, c] if (c - a).cross(b - a).dot(normal) > 0.0 else [a, c, b]
	for p: Vector3 in order:
		surface.add_vertex(p)


static func at_ground(p: Vector2, elevation: Callable) -> Vector3:
	return point(p, elevation.call(p.x, p.y))


static func build_landscape(parent: Node3D, elevation: Callable, render_foliage: Callable) -> void:
	var planting := Node3D.new()
	planting.name = "YachtClubPlanting"
	parent.add_child(planting)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1949
	var pines := Pines.new()
	# Keep the original contrast between the open court approach and the tall shore-side stand.
	for tree: Vector3 in [
		Vector3(-10, -12, 15.5), Vector3(4, -14.5, 12.0),
		Vector3(13.0, -3.2, 18.5), Vector3(20, -7.4, 15.4),
		Vector3(26, -12, 17.3), Vector3(27, 7.5, 15.4),
		Vector3(17.3, 20.1, 13.4), Vector3(22.3, 24.1, 15.2),
	]:
		pines.plant(at_ground(ORIGIN + Vector2(tree.x, tree.y), elevation), tree.z, rng)
	pines.build(planting)

	var crowns: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	for tree: Vector3 in [Vector3(.10, 8.16, 7.05), Vector3(1.32, 9.01, 5.55)]:
		var foot := at_ground(ORIGIN + Vector2(tree.x, tree.y), elevation)
		var tree_height := tree.z
		stems.append(Transform3D(Basis.from_scale(Vector3(.14, tree_height * .62, .14)),
			foot + Vector3.UP * tree_height * .31))
		for level in 7:
			var ratio := float(level) / 6.0
			var girth := lerpf(1.39, .53, ratio)
			var turn := Basis(Vector3.UP, rng.randf_range(0, TAU))
			var crown := turn.scaled_local(Vector3(girth, tree_height * .25, girth))
			crowns.append(Transform3D(crown, foot + Vector3.UP * tree_height * lerpf(.21, .89, ratio)))

	var shade := at_ground(ORIGIN + Vector2(15.5, 21.75), elevation)
	stems.append(Transform3D(Basis.from_scale(Vector3(.53, 6.35, .53)), shade + Vector3.UP * 3.17))
	crowns.append(Transform3D(Basis.from_scale(Vector3(5.65, 5.55, 5.18)), shade + Vector3.UP * 5.55))
	crowns.append(Transform3D(Basis.from_scale(Vector3(3.58, 3.47, 3.52)), shade + Vector3(1.32, 7.23, -.45)))

	for center: Vector2 in [Vector2(-.52, 7.95), Vector2(3.5, 14.4), Vector2(4.25, 17.5),
			Vector2(5.38, 20.6), Vector2(-6.7, 3.7), Vector2(6.2, 22.8)]:
		for cluster in 4:
			var offset := Vector2(rng.randf_range(-.50, .50), rng.randf_range(-.32, .32))
			var foot := at_ground(ORIGIN + center + offset, elevation)
			var turn := Basis(Vector3.UP, rng.randf_range(0, TAU))
			var crown := turn.scaled_local(Vector3(rng.randf_range(.65, 1.1), .55, .72))
			crowns.append(Transform3D(crown, foot + Vector3.UP * .29))
	render_foliage.call(planting, crowns, stems)
	build_hosta_bed(planting, elevation, rng)


static func build_hosta_bed(parent: Node3D, elevation: Callable, rng: RandomNumberGenerator) -> void:
	var bed := at_ground(ORIGIN + Vector2(-4.0, 4.54), elevation)
	var along := Vector2(.86, .51).normalized()
	var axis := Basis(horizontal(along), Vector3.UP, normal_to(along))
	var planter := Kit.box_at(parent, bed + Vector3.UP * .13, Vector3(4.20, .36, .62),
		Kit.paint(Color("#544039")))
	planter.basis = axis
	var soil := Kit.box_at(parent, bed + Vector3.UP * .31, Vector3(4.03, .025, .46),
		Kit.paint(Color("#423c30")))
	soil.basis = axis
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plant in 9:
		var start := bed + axis.x * (plant * .45 - 1.80) + Vector3.UP * .32
		for leaf in 8:
			var turn := float(leaf) * TAU / 8.0 + rng.randf_range(-.21, .21)
			var direction := Vector3(cos(turn), 0, sin(turn))
			var side := direction.cross(Vector3.UP)
			var length := rng.randf_range(.20, .41)
			var tip := start + direction * length + Vector3.UP * (.11 + length * .31)
			var mid := start.lerp(tip, .58) + Vector3.UP * .10
			var left := mid - side * length * .29 - Vector3.UP * .024
			var right := mid + side * length * .29 - Vector3.UP * .024
			var color := Color("#678c44").lerp(Color("#adc185"), rng.randf_range(0, .6))
			triangle(leaves, start, left, mid, Vector3.UP, color)
			triangle(leaves, start, mid, right, Vector3.UP, color.darkened(.20))
			triangle(leaves, mid, left, tip, Vector3.UP, color.lightened(.11))
			triangle(leaves, mid, tip, right, Vector3.UP, color)
	var material := vertex_paint()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	Kit.mesh_at(parent, leaves.commit(), Vector3.ZERO, material)
