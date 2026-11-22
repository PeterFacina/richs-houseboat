extends RefCounted

const Kit = preload("res://scenery.gd")
const Playground = preload("res://lamure_playground.gd")
const SHORE_AXIS := Vector3(.932, 0, -.362)

var swim_area := PackedVector2Array()
var swim_bounds := Rect2()
var raft: AnimatableBody3D
var raft_anchor := Vector3.ZERO


func build(parent: Node3D, layout: Dictionary, ground: Callable, marina: RefCounted) -> void:
	var beach := Node3D.new()
	beach.name = "LamureBeach"
	parent.add_child(beach)
	for coordinate: Array in layout.guard:
		build_guard_stand(beach, on_land(coordinate, ground), marina.timber)
	var shelter: Node3D = marina.build_pavilion(beach, on_land(layout.shelter, ground),
		Color("#829aa2"), Color("#a1b4bb"))
	shelter.name = "LamurePicnicShelter"
	shelter.rotation.y = .32
	build_volleyball(beach, on_land(layout.volleyball, ground))
	build_swings(beach, on_land(layout.swing, ground))
	if layout.has("slide"):
		Playground.build_slide(beach, on_land(layout.slide, ground), marina.timber)
		Playground.build_bin(beach, on_land(layout.bin, ground))
		Playground.build_mat(beach, layout.access_mat, ground)
	build_entry(beach, on_land(layout.entry, ground), marina.timber)
	build_bench(beach, on_land([18572.0, 13220.0], ground), marina.timber)
	build_backshore(beach, layout, ground, marina)
	build_float_line(beach, layout.swim_line)
	build_raft(beach, layout.raft, marina.timber)


func on_land(coordinate: Array, ground: Callable) -> Vector3:
	var point := Vector3(coordinate[0], 0, coordinate[1])
	point.y = ground.call(point.x, point.z)
	return point


func blocks_swim_area(point: Vector3) -> bool:
	var p := Vector2(point.x, point.z)
	return swim_bounds.has_point(p) and Geometry2D.is_point_in_polygon(p, swim_area)


func update_float(viewpoint: Vector3, clock: float, wave: Callable) -> void:
	if raft == null or raft_anchor.distance_squared_to(viewpoint) > 320.0 * 320.0:
		return
	var middle: float = wave.call(raft_anchor, clock)
	var east: float = wave.call(raft_anchor + Vector3.RIGHT * 1.65, clock)
	var south: float = wave.call(raft_anchor + Vector3.BACK * 1.15, clock)
	raft.position.y = raft_anchor.y + middle
	raft.rotation = Vector3(-(south - middle) / 1.15, .29, (east - middle) / 1.65)


func at_swim_ladder(feet: Vector3, eye: Camera3D) -> bool:
	if raft == null or feet.y >= raft.position.y:
		return false
	var rail := raft.to_global(Vector3(0, .27, 1.50))
	var offset := rail - eye.global_position
	return feet.distance_squared_to(rail) < 2.4 * 2.4 and offset.normalized().dot(-eye.global_basis.z) > .78


func climb_float(player: CharacterBody3D) -> void:
	player.global_position = raft.to_global(Vector3(0, .15, .45))
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func fixture(parent: Node3D, at: Vector3, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = at
	node.basis = Basis(SHORE_AXIS, Vector3.UP, SHORE_AXIS.cross(Vector3.UP)).orthonormalized()
	return node


func build_guard_stand(parent: Node3D, at: Vector3, timber: Material) -> void:
	var stand := fixture(parent, at, "LifeguardStand")
	var red := Kit.paint(Color("#a63736"), .66, .16)
	var cream := Kit.paint(Color("#ddd9cc"), .81)
	var shade := Kit.paint(Color("#344c45"), .82)
	for x: float in [-1.0, 1.0]:
		for side: float in [-1.0, 1.0]:
			Kit.beam(stand, Vector3(x * .78, -.16, side * .86), Vector3(x * .49, 2.04, side * .51), .082, red)
		Kit.beam(stand, Vector3(x * .65, .73, -.75), Vector3(x * .47, 1.91, .48), .055, red)
		Kit.beam(stand, Vector3(x * .36, .03, 1.10), Vector3(x * .36, 2.32, .56), .058, red)
	for rung in 7:
		var y := .30 + rung * .269
		Kit.beam(stand, Vector3(-.37, y, 1.08 - y * .229),
			Vector3(.37, y, 1.08 - y * .229), .043, cream)
	Kit.box_at(stand, Vector3(0, 2.04, 0), Vector3(1.28, .11, 1.31), timber)
	Kit.box_at(stand, Vector3(0, 2.42, -.24), Vector3(.88, .10, .46), cream)
	Kit.box_at(stand, Vector3(0, 2.68, .035), Vector3(.90, .47, .073), cream)
	for x: float in [-.56, .56]:
		Kit.beam(stand, Vector3(x, 2.08, .56), Vector3(x, 2.72, .56), .051, red)
		Kit.beam(stand, Vector3(x, 2.71, .56), Vector3(x, 2.71, -.54), .051, red)
	Kit.beam(stand, Vector3(.42, 2.06, .51), Vector3(.42, 3.61, .50), .057, red)
	var roof := Kit.box_at(stand, Vector3(0, 3.54, -.02), Vector3(2.08, .071, 1.58), shade)
	roof.rotation.x = -.22
	var life_ring := TorusMesh.new()
	life_ring.inner_radius = .185
	life_ring.outer_radius = .270
	life_ring.rings = 16
	life_ring.ring_segments = 9
	var ring := Kit.mesh_at(stand, life_ring, Vector3(-.61, 1.53, -.09), cream)
	ring.rotation.z = PI * .5
	var buoy_tag := Kit.paint(Color("#e07340"))
	for side: float in [-1.0, 1.0]:
		Kit.box_at(stand, Vector3(-.615, 1.53, side * .220), Vector3(.089, .096, .089), buoy_tag)


func build_entry(parent: Node3D, at: Vector3, timber: Material) -> void:
	var entry := fixture(parent, at, "LamureBeachSign")
	entry.rotate_y(-1.28)
	var post := Kit.paint(Color("#6e5a42"))
	for x: float in [-.83, .83]:
		Kit.box_at(entry, Vector3(x, .82, 0), Vector3(.118, 1.78, .115), post)
	Kit.box_at(entry, Vector3(0, 1.48, 0), Vector3(1.96, .40, .09), timber)
	var lettering := Label3D.new()
	entry.add_child(lettering)
	lettering.position = Vector3(0, 1.48, .052)
	lettering.text = "LAMURE BEACH"
	lettering.font_size = 44
	lettering.pixel_size = .0038
	lettering.modulate = Color("#263b37")
	lettering.outline_size = 0


static func build_bench(parent: Node3D, at: Vector3, timber: Material) -> Node3D:
	var bench := Node3D.new()
	bench.name = "BeachBench"
	parent.add_child(bench)
	bench.position = at
	var iron := Kit.paint(Color("#4c514c"), .72, .23)
	for x: float in [-.74, .74]:
		for z: float in [-.20, .20]:
			Kit.beam(bench, Vector3(x, -.13, z), Vector3(x, .53, z * .81), .054, iron)
		Kit.beam(bench, Vector3(x, .43, .14), Vector3(x, .98, .26), .057, iron)
	for z: float in [-.155, -.05, .055, .16]:
		Kit.box_at(bench, Vector3(0, .532, z), Vector3(1.89, .047, .096), timber)
	for y: float in [.72, .84, .96]:
		Kit.box_at(bench, Vector3(0, y, .21 + (y - .72) * .18), Vector3(1.89, .088, .044), timber)
	return bench


func build_backshore(parent: Node3D, layout: Dictionary, ground: Callable, marina: RefCounted) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 361270
	var grass: Array[Transform3D] = []
	var driftwood: Array[Transform3D] = []
	var edge: Array = layout.backshore
	var inland := SHORE_AXIS.cross(Vector3.UP)
	for index in range(1, edge.size()):
		var start := Vector3(edge[index - 1][0], 0, edge[index - 1][1])
		var finish := Vector3(edge[index][0], 0, edge[index][1])
		var count := ceili(start.distance_to(finish) * 1.4)
		for i in count:
			var point := start.lerp(finish, float(i) / count) + inland * random.randf_range(.34, 4.1)
			point.y = ground.call(point.x, point.z)
			if point.y < .3:
				continue
			var width := random.randf_range(.62, 1.38)
			var shape := Vector3(width, random.randf_range(.23, .67), width)
			grass.append(Transform3D(Basis(Vector3.UP, random.randf_range(0, TAU)).scaled_local(shape), point))
		var log_at := start.lerp(finish, .43) + inland * .22
		log_at.y = float(ground.call(log_at.x, log_at.z)) + .13
		var angle := Basis.from_euler(Vector3(0, random.randf_range(0, TAU), PI * .5))
		var size := Vector3(random.randf_range(.16, .29), random.randf_range(.90, 2.4), random.randf_range(.18, .28))
		driftwood.append(Transform3D(angle.scaled_local(size), log_at))
	var reeds := ShaderMaterial.new()
	reeds.shader = preload("res://river_reeds.gdshader")
	var edge_grass := Kit.new().scatter(parent, marina.reed_mesh(random), grass, reeds)
	edge_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = .35
	log_mesh.bottom_radius = .51
	log_mesh.height = 1.0
	log_mesh.radial_segments = 7
	Kit.new().scatter(parent, log_mesh, driftwood, Kit.paint(Color("#776452"), .95))


func build_volleyball(parent: Node3D, at: Vector3) -> void:
	var court := fixture(parent, at, "BeachVolleyball")
	var posts := Kit.paint(Color("#3a5667"), .63, .15)
	var tape := Kit.paint(Color("#e1dcc9"), .89)
	for z: float in [-4.32, 4.32]:
		Kit.beam(court, Vector3(0, -.26, z), Vector3(0, 2.49, z), .083, posts)
	Kit.beam(court, Vector3(0, 2.38, -4.24), Vector3(0, 2.38, 4.24), .047, tape)
	Kit.beam(court, Vector3(0, 1.42, -4.24), Vector3(0, 1.42, 4.24), .022, tape)
	var thread := Kit.paint(Color("#685f53"))
	thread.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES, thread)
	for row in range(1, 9):
		var height := 1.42 + .96 * row / 9.0
		grid.surface_add_vertex(Vector3(0, height, -4.20))
		grid.surface_add_vertex(Vector3(0, height, 4.20))
	for col in 75:
		var z := lerpf(-4.2, 4.2, col / 74.0)
		grid.surface_add_vertex(Vector3(0, 1.43, z))
		grid.surface_add_vertex(Vector3(0, 2.38, z))
	grid.surface_end()
	Kit.mesh_at(court, grid, Vector3.ZERO, thread).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_swings(parent: Node3D, at: Vector3) -> void:
	var swings := fixture(parent, at, "BeachSwings")
	var frame := Kit.paint(Color("#586e7a"), .57, .24)
	var chain := Kit.paint(Color("#777a76"), .53, .28)
	var seat := Kit.paint(Color("#315e87"), .65)
	Kit.beam(swings, Vector3(-2.62, 2.84, 0), Vector3(2.62, 2.84, 0), .087, frame)
	for x: float in [-2.56, 2.56]:
		for z: float in [-1.27, 1.27]:
			Kit.beam(swings, Vector3(x, -.14, z), Vector3(x, 2.84, 0), .082, frame)
	for x: float in [-1.14, 1.14]:
		for side: float in [-1.0, 1.0]:
			Kit.beam(swings, Vector3(x + side * .29, 2.81, 0),
				Vector3(x + side * .24, .56, .095), .016, chain)
		Kit.box_at(swings, Vector3(x, .553, .095), Vector3(.53, .075, .29), seat)
		for side: float in [-1.0, 1.0]:
			Kit.box_at(swings, Vector3(x + side * .229, .653, .10), Vector3(.067, .15, .30), seat)
		Kit.box_at(swings, Vector3(x, .672, .218), Vector3(.51, .181, .066), seat)


func build_float_line(parent: Node3D, trace: Array) -> void:
	var rope := Kit.paint(Color("#b5bfb2"))
	var white: Array[Transform3D] = []
	var yellow: Array[Transform3D] = []
	var index := 0
	for coordinates: Array in trace:
		var point := Vector2(coordinates[0], coordinates[1])
		swim_area.append(point)
		swim_bounds = Rect2(point, Vector2.ZERO) if swim_area.size() == 1 else swim_bounds.expand(point)
	for end in range(1, swim_area.size()):
		var first := swim_area[end - 1]
		var last := swim_area[end]
		var a := Vector3(first.x, .065, first.y)
		var b := Vector3(last.x, .065, last.y)
		Kit.beam(parent, a, b, .023, rope).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pieces := maxi(1, ceili(a.distance_to(b) / 4.55))
		for spot in pieces:
			var position := a.lerp(b, float(spot) / pieces) + Vector3.UP * .026
			var bead := Transform3D(Basis.IDENTITY, position)
			if index % 4 == 0:
				yellow.append(bead.scaled_local(Vector3.ONE * 1.48))
			else:
				white.append(bead)
			index += 1
	var buoy := SphereMesh.new()
	buoy.radius = .170
	buoy.height = .221
	buoy.radial_segments = 9
	buoy.rings = 5
	Kit.new().scatter(parent, buoy, white, Kit.paint(Color("#e6e2cf"), .62))
	Kit.new().scatter(parent, buoy, yellow, Kit.paint(Color("#ecbd4c"), .64))


func build_raft(parent: Node3D, coordinate: Array, timber: Material) -> void:
	raft_anchor = Vector3(coordinate[0], .31, coordinate[1])
	raft = AnimatableBody3D.new()
	raft.name = "LamureSwimFloat"
	raft.sync_to_physics = false
	parent.add_child(raft)
	raft.position = raft_anchor
	raft.rotation.y = .29
	var float_dark := Kit.paint(Color("#545857"))
	var ladder := Kit.paint(Color("#b5c4bd"), .43, .53)
	var yellow := Kit.paint(Color("#b7a052"), .76)
	for x: float in [-1.27, 1.27]:
		Kit.box_at(raft, Vector3(x, -.226, 0), Vector3(.51, .31, 2.24), float_dark)
	Kit.box_at(raft, Vector3.ZERO, Vector3(3.65, .22, 2.64), timber)
	Kit.collider(raft, Vector3.ZERO, Vector3(3.65, .22, 2.64))
	for x: float in [-1.76, 1.76]:
		Kit.box_at(raft, Vector3(x, .006, 0), Vector3(.11, .21, 2.73), yellow)
	for side: float in [-1.0, 1.0]:
		Kit.beam(raft, Vector3(side * .31, -.81, 1.49), Vector3(side * .31, .51, 1.48), .043, ladder)
		Kit.beam(raft, Vector3(side * .31, .51, 1.48), Vector3(side * .31, .12, 1.05), .043, ladder)
	for rung in 4:
		var height := -.72 + rung * .239
		Kit.beam(raft, Vector3(-.31, height, 1.485), Vector3(.31, height, 1.485), .046, ladder)
