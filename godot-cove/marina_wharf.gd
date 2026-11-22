extends RefCounted

const Kit = preload("res://scenery.gd")
const Cleat = preload("res://mooring_cleat.gd")
const Launch = preload("res://marina_launch.gd")
const DECK_HEIGHT := 1.02
const LAUNCH_WIDTH := 2.45

var deck: PackedVector2Array
var launch_dock: PackedVector2Array
var waterfront_bounds := Rect2()
var light_lens: StandardMaterial3D
var light_spill: OmniLight3D
var launch := Launch.new()


func build(parent: Node3D, layout: Dictionary, ground: Callable, concrete: Texture2D,
		walkway: Callable, float_height: float) -> void:
	deck = polygon(layout.deck)
	launch_dock = polygon(layout.launch_dock)
	waterfront_bounds = Rect2(deck[0], Vector2.ZERO)
	for path in [deck, launch_dock]:
		for p: Vector2 in path:
			waterfront_bounds = waterfront_bounds.expand(p)
	waterfront_bounds = waterfront_bounds.grow(LAUNCH_WIDTH * .5)

	var wharf := Node3D.new()
	wharf.name = "PublicWharf"
	parent.add_child(wharf)
	var cement := ShaderMaterial.new()
	cement.shader = preload("res://marina_wharf.gdshader")
	cement.set_shader_parameter("concrete", concrete)
	build_deck(wharf, cement)
	build_approach(wharf, polygon(layout.approach), ground, cement)
	if layout.has("launch_ramp"):
		launch.build(wharf, layout.launch_ramp, ground, concrete)
	for index in range(1, launch_dock.size()):
		var a := at(launch_dock[index - 1], float_height)
		var b := at(launch_dock[index], float_height)
		if index == 1:
			a.y = maxf(a.y, ground.call(a.x, a.z))
		var bend := (b - a).normalized() * .34
		walkway.call(wharf, a - (bend if index > 1 else Vector3.ZERO),
			b + (bend if index < launch_dock.size() - 1 else Vector3.ZERO), LAUNCH_WIDTH)
	var boarding_hardware: Array[Transform3D] = []
	add_cleats(boarding_hardware, at(launch_dock[-2], float_height + .09),
		at(launch_dock[-1], float_height + .09), .92, [.16, .39, .64, .87], .74)
	Cleat.place(wharf, boarding_hardware).name = "LaunchDockCleats"

	var white := Kit.paint(Color("#e3e5df"), .59, .16)
	var rails := Kit.paint(Color("#c4c9c1"), .52, .23)
	for run: Array in layout.railings:
		var points := polygon(run)
		for index in range(1, points.size()):
			build_railing(wharf, at(points[index - 1], DECK_HEIGHT), at(points[index], DECK_HEIGHT), rails)
	build_beacon(wharf, at(Vector2(layout.beacon[0], layout.beacon[1]), DECK_HEIGHT), white)
	build_lamppost(wharf, at(Vector2(layout.lamp[0], layout.lamp[1]), DECK_HEIGHT))
	build_shack(parent, layout, ground)


func blocks_water(point: Vector3) -> bool:
	var p := Vector2(point.x, point.z)
	if not waterfront_bounds.has_point(p):
		return false
	if Geometry2D.is_point_in_polygon(p, deck):
		return true
	for index in range(1, launch_dock.size()):
		var dock_edge := Geometry2D.get_closest_point_to_segment(p, launch_dock[index - 1], launch_dock[index])
		if dock_edge.distance_squared_to(p) < LAUNCH_WIDTH * LAUNCH_WIDTH * .25:
			return true
	return false


func update_light(clock: float, dusk: float) -> void:
	if light_lens == null:
		return
	var phase := fposmod(clock, 4.0)
	var flash := smoothstep(0.0, .065, phase) * (1.0 - smoothstep(.27, .42, phase))
	var night := clampf(dusk, 0.0, 1.0)
	light_lens.emission_energy_multiplier = .10 + flash * lerpf(1.18, 3.4, night)
	light_spill.light_energy = night * flash * .64
	light_spill.visible = light_spill.light_energy > .005


static func polygon(points: Array) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for p: Array in points:
		vertices.append(Vector2(p[0], p[1]))
	return vertices


static func at(p: Vector2, height: float) -> Vector3:
	return Vector3(p.x, height, p.y)


static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.set_normal((c - a).cross(b - a).normalized())
	for vertex: Vector3 in [a, b, c]:
		surface.add_vertex(vertex)


func build_deck(parent: Node3D, cement: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := Kit.paint(Color("#bcb6a8"), .90)
	var indices := Geometry2D.triangulate_polygon(deck)
	for index in range(0, indices.size(), 3):
		var a := at(deck[indices[index]], DECK_HEIGHT)
		var b := at(deck[indices[index + 1]], DECK_HEIGHT)
		var c := at(deck[indices[index + 2]], DECK_HEIGHT)
		if (c - a).cross(b - a).y > 0.0:
			triangle(surface, a, b, c)
		else:
			triangle(surface, a, c, b)
	for index in deck.size():
		var a := at(deck[index], DECK_HEIGHT)
		var b := at(deck[(index + 1) % deck.size()], DECK_HEIGHT)
		var low_a := Vector3(a.x, -2.2, a.z)
		var low_b := Vector3(b.x, -2.2, b.z)
		triangle(surface, a, low_a, b)
		triangle(surface, b, low_a, low_b)
		var rim_a := a.lerp(b, .013) - Vector3.UP * .058
		var rim_b := a.lerp(b, .987) - Vector3.UP * .058
		Kit.beam(parent, rim_a, rim_b, .104, edge)
	var pavement := Kit.mesh_at(parent, surface.commit(), Vector3.ZERO, cement)
	pavement.name = "ConcreteDeck"
	pavement.create_trimesh_collision()

	var wharf_hardware: Array[Transform3D] = []
	add_cleats(wharf_hardware, at(deck[6], DECK_HEIGHT), at(deck[7], DECK_HEIGHT),
		.48, [.12, .31, .57, .82], 1.25)
	add_cleats(wharf_hardware, at(deck[0], DECK_HEIGHT), at(deck[1], DECK_HEIGHT),
		.43, [.32, .69, .90], 1.12)
	add_cleats(wharf_hardware, at(deck[3], DECK_HEIGHT), at(deck[4], DECK_HEIGHT),
		.57, [.21, .61], 1.22)
	Cleat.place(parent, wharf_hardware).name = "WharfCleats"


func add_cleats(transforms: Array[Transform3D], a: Vector3, b: Vector3, setback: float,
		positions: Array, size: float) -> void:
	var along := (b - a).normalized()
	var across := along.cross(Vector3.UP)
	var facing := Basis(along, Vector3.UP, across).scaled_local(Vector3.ONE * size)
	for position: float in positions:
		transforms.append(Transform3D(facing, a.lerp(b, position) + across * setback))


func build_approach(parent: Node3D, corners: PackedVector2Array, ground: Callable, cement: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 10
	var rows := 18
	var samples := PackedVector3Array()
	for row in rows + 1:
		var across := float(row) / rows
		var shore := corners[0].lerp(corners[3], across)
		var quay := corners[1].lerp(corners[2], across)
		for column in columns + 1:
			var along := float(column) / columns
			var p := shore.lerp(quay, along)
			var height := lerpf(ground.call(p.x, p.y) + .025, DECK_HEIGHT, smoothstep(0.0, 1.0, along))
			samples.append(at(p, height))
	var stride := columns + 1
	for row in rows:
		for column in columns:
			var index := row * stride + column
			triangle(surface, samples[index], samples[index + 1], samples[index + stride])
			triangle(surface, samples[index + 1], samples[index + stride + 1], samples[index + stride])
	var ramp := Kit.mesh_at(parent, surface.commit(), Vector3.ZERO, cement)
	ramp.name = "WharfApproach"
	ramp.create_trimesh_collision()


func build_railing(parent: Node3D, a: Vector3, b: Vector3, paint: Material) -> void:
	var cap := Vector3.UP * 1.06
	Kit.beam(parent, a + cap, b + cap, .066, paint)
	Kit.beam(parent, a + cap * .54, b + cap * .54, .042, paint)
	var panels := maxi(1, ceili(a.distance_to(b) / 2.25))
	for index in panels + 1:
		var foot := a.lerp(b, float(index) / panels)
		Kit.beam(parent, foot, foot + cap, .061, paint)
	var guard := StaticBody3D.new()
	parent.add_child(guard)
	guard.position = (a + b + cap) * .5
	guard.basis = Basis.looking_at(b - a)
	Kit.collider(guard, Vector3.ZERO, Vector3(.075, cap.y, a.distance_to(b)))


func build_beacon(parent: Node3D, foot: Vector3, white: Material) -> void:
	var tower := StaticBody3D.new()
	tower.name = "DeepRiverHarbourLight"
	parent.add_child(tower)
	tower.position = foot
	var red := Kit.paint(Color("#aa242e"), .52, .23)
	var dark := Kit.paint(Color("#502d2e"), .58, .27)
	cylinder(tower, .55, .64, .19, .095, white)
	cylinder(tower, .37, .50, 4.31, 2.32, white)
	cylinder(tower, .56, .39, .18, 4.54, red)
	cylinder(tower, .49, .55, .52, 4.83, red)
	light_lens = Kit.paint(Color("#84252a"), .28, .08)
	light_lens.emission_enabled = true
	light_lens.emission = Color("#ff1714")
	light_lens.emission_energy_multiplier = .10
	cylinder(tower, .40, .40, .34, 5.26, light_lens)
	cylinder(tower, .28, .52, .18, 5.51, red)
	for index in 8:
		var angle := TAU * index / 8.0
		var bars := Vector3(cos(angle), 0, sin(angle)) * .402
		Kit.beam(tower, bars + Vector3.UP * 5.08, bars + Vector3.UP * 5.43, .035, dark)
	var hatch := Kit.box_at(tower, Vector3(-.46, .77, 0), Vector3(.06, 1.12, .42), white)
	Kit.box_at(tower, hatch.position + Vector3(-.045, -.05, .135), Vector3(.041, .092, .028), dark)
	Kit.collider(tower, Vector3.UP * 2.25, Vector3(.91, 4.5, .91))
	light_spill = OmniLight3D.new()
	light_spill.light_color = Color("#ff282c")
	light_spill.omni_range = 12.0
	light_spill.omni_attenuation = 1.3
	light_spill.hide()
	tower.add_child(light_spill)
	light_spill.position = Vector3.UP * 5.26


static func cylinder(parent: Node3D, top: float, bottom: float, length: float, center: float, paint: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = length
	mesh.radial_segments = 24
	mesh.rings = 1
	Kit.mesh_at(parent, mesh, Vector3.UP * center, paint)


func build_lamppost(parent: Node3D, foot: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "WharfLamppost"
	parent.add_child(lamp)
	lamp.position = foot
	var post := Kit.paint(Color("#707975"), .60, .36)
	var housing := Kit.paint(Color("#565e5b"), .57, .26)
	var lens := Kit.paint(Color("#e4ded2"), .48)
	cylinder(lamp, .14, .20, .30, .15, housing)
	cylinder(lamp, .050, .089, 5.5, 2.86, post)
	for side: float in [-1.0, 1.0]:
		var end := Vector3(side * .68, 5.67, 0)
		Kit.beam(lamp, Vector3.UP * 5.28, end, .050, post)
		Kit.box_at(lamp, end, Vector3(.29, .107, .19), housing)
		Kit.box_at(lamp, end - Vector3.UP * .052, Vector3(.247, .018, .15), lens)


func build_shack(parent: Node3D, layout: Dictionary, ground: Callable) -> void:
	var center := Vector2(layout.shack[0], layout.shack[1])
	var direction := (Vector2(layout.shack_ridge[0], layout.shack_ridge[1]) - center).normalized()
	var axis := Vector3(direction.x, 0, direction.y)
	var side := axis.cross(Vector3.UP)
	var yaw := Basis(axis, Vector3.UP, side)
	var width := 7.6
	var depth := 5.4
	var eave := 2.62
	var pitch := .16
	var floor_height := float(ground.call(center.x, center.y)) + .13
	var shack := StaticBody3D.new()
	shack.name = "MarinaShack"
	parent.add_child(shack)
	shack.position = at(center, floor_height)
	shack.basis = yaw
	var siding := ShaderMaterial.new()
	siding.shader = preload("res://marina_shack_siding.gdshader")
	var trim := Kit.paint(Color("#e6e9e2"), .73)
	var base := Kit.paint(Color("#7d8176"), .94)
	var roof := Kit.paint(Color("#839b9d"), .74, .16)
	var roof_seam := Kit.paint(Color("#778e90"), .70, .15)
	var glass := Kit.paint(Color("#405158"), .36, .16)
	var dark_trim := Kit.paint(Color("#657778"), .74)
	Kit.box_at(shack, Vector3(0, -.30, 0), Vector3(width + .04, .61, depth + .04), base)
	Kit.box_at(shack, Vector3.UP * eave * .5, Vector3(width, eave, depth), siding)
	Kit.collider(shack, Vector3.UP * eave * .39, Vector3(width, eave * 1.22, depth))
	var gables := SurfaceTool.new()
	gables.begin(Mesh.PRIMITIVE_TRIANGLES)
	for end: float in [-1.0, 1.0]:
		var x := end * width * .5
		var ridge := Vector3(x, eave + tan(pitch) * depth * .5, 0)
		var a := Vector3(x, eave, -end * depth * .5)
		var b := Vector3(x, eave, end * depth * .5)
		triangle(gables, b, ridge, a)
	Kit.mesh_at(shack, gables.commit(), Vector3.ZERO, siding)
	var roof_span := depth * .5 + .23
	var slope := roof_span / cos(pitch)
	for wall: float in [-1.0, 1.0]:
		var panel := Node3D.new()
		shack.add_child(panel)
		panel.position = Vector3(0, eave + tan(pitch) * (depth - roof_span) * .5, wall * roof_span * .5)
		panel.rotation.x = wall * pitch
		Kit.box_at(panel, Vector3.ZERO, Vector3(width + .64, .13, slope), roof)
		Kit.box_at(panel, Vector3(0, -.055, wall * slope * .5), Vector3(width + .66, .22, .053), trim)
		for rib in range(-8, 9):
			var seam := Kit.box_at(panel, Vector3(rib * .456, .074, 0), Vector3(.024, .024, slope), roof_seam)
			seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for x: float in [-width * .5, width * .5]:
			Kit.box_at(shack, Vector3(x, eave * .5, wall * depth * .5), Vector3(.105, eave, .10), trim)
	Kit.box_at(shack, Vector3(0, eave + tan(pitch) * depth * .5 + .072, 0),
		Vector3(width + .68, .058, .145), roof_seam)
	var front := -depth * .5
	var door := Vector3(2.45, 1.07, front)
	Kit.box_at(shack, door, Vector3(1.05, 2.16, .126), trim)
	Kit.box_at(shack, door + Vector3.FORWARD * .073, Vector3(.89, 2.03, .056), dark_trim)
	Kit.box_at(shack, door + Vector3(-.32, -.08, -.115), Vector3(.13, .040, .045), base)
	Kit.box_at(shack, door + Vector3(0, -.99, -.32), Vector3(1.46, .13, .68), base)
	service_window(shack, Vector3(-.75, 1.62, front), 2.85, trim, glass)
	service_window(shack, Vector3(.66, 1.58, -front), 1.63, trim, glass)


func service_window(parent: Node3D, center: Vector3, width: float, trim: Material, glass: Material) -> void:
	var face := signf(center.z)
	Kit.box_at(parent, center, Vector3(width + .14, 1.03, .13), trim)
	Kit.box_at(parent, center + Vector3.BACK * face * .083, Vector3(width, .89, .049), glass)
	Kit.box_at(parent, center + Vector3.BACK * face * .114, Vector3(.062, .94, .044), trim)
	Kit.box_at(parent, center + Vector3(0, -.49, face * .11), Vector3(width + .25, .069, .25), trim)
