extends RefCounted

const Kit = preload("res://scenery.gd")
const BEND_STEPS := 62
const EXIT_STEPS := 7
const CHUTE_SIDES := 12
const TURNS := 1.25
const MAT_HALF_WIDTH := .79


static func build_slide(parent: Node3D, at: Vector3, timber: Material) -> void:
	var tower := Node3D.new()
	tower.name = "LamureSpiralSlide"
	parent.add_child(tower)
	tower.position = at
	tower.rotation.y = -.31
	var frame := Kit.paint(Color("#445d68"), .53, .15)
	var rails := Kit.paint(Color("#c5ab69"), .59, .11)
	var chute := Kit.paint(Color("#9d302f"), .49)
	chute.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x: float in [-.69, .69]:
		for z: float in [-.69, .69]:
			Kit.beam(tower, Vector3(x, -.21, z), Vector3(x, 3.06, z), .090, frame)
	Kit.box_at(tower, Vector3(0, 2.17, 0), Vector3(1.47, .119, 1.42), timber)
	for side: float in [-1.0, 1.0]:
		Kit.beam(tower, Vector3(-.68, 3.03, side * .68), Vector3(.68, 3.03, side * .68), .054, rails)
		for bar in range(-3, 4):
			var x := bar * .179
			Kit.beam(tower, Vector3(x, 2.22, side * .68), Vector3(x, 3.03, side * .68), .041, rails)
	for side: float in [-1.0, 1.0]:
		Kit.beam(tower, Vector3(.71, .04, side * .33), Vector3(.71, 2.18, side * .33), .065, frame)
	for rung in 8:
		var y := .23 + rung * .242
		Kit.beam(tower, Vector3(.73, y, -.33), Vector3(.73, y, .33), .054, frame)
	Kit.beam(tower, Vector3(-1.78, -.18, 0), Vector3(-1.78, 2.21, 0), .108, frame)
	var bridge := Kit.box_at(tower, Vector3(-.70, 2.17, 0), Vector3(.38, .12, .79), chute)
	bridge.rotation.z = -.065

	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in BEND_STEPS + EXIT_STEPS:
		for lane in CHUTE_SIDES:
			var a := slide_point(step, lane)
			var b := slide_point(step + 1, lane)
			var c := slide_point(step, lane + 1)
			var d := slide_point(step + 1, lane + 1)
			triangle(shape, a, c, b)
			triangle(shape, c, d, b)
			var shell := Vector3.DOWN * .053
			triangle(shape, a + shell, b + shell, c + shell)
			triangle(shape, c + shell, b + shell, d + shell)
		for lane: int in [0, CHUTE_SIDES]:
			var edge := slide_point(step, lane)
			var next := slide_point(step + 1, lane)
			triangle(shape, edge, next, edge - Vector3.UP * .053)
			triangle(shape, next, next - Vector3.UP * .053, edge - Vector3.UP * .053)
	Kit.mesh_at(tower, shape.commit(), Vector3.ZERO, chute)


static func slide_point(step: int, lane: int) -> Vector3:
	var progress := minf(1.0, float(step) / BEND_STEPS)
	var turn := progress * TAU * TURNS
	var tangent := Vector3(-sin(turn), 0, cos(turn))
	var outward := Vector3(cos(turn), 0, sin(turn))
	var trail := maxf(0.0, float(step - BEND_STEPS) / EXIT_STEPS)
	var bank := lerpf(1.0, .35, trail)
	var arc := lerpf(-1.48, 1.48, float(lane) / CHUTE_SIDES)
	var height := lerpf(2.20, .23, progress) - trail * .095
	return (Vector3(-1.77, height + .276 * (1.0 - cos(arc)) * bank, 0)
		+ outward * (1.00 + sin(arc) * .416) + tangent * trail * 1.04)


static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.set_normal((c - a).cross(b - a).normalized())
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


static func build_mat(parent: Node3D, trace: Array, ground: Callable) -> void:
	var tile := SurfaceTool.new()
	tile.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distances := [0.0]
	var axis := PackedVector2Array()
	for point: Array in trace:
		axis.append(Vector2(point[0], point[1]))
		if axis.size() > 1:
			distances.append(float(distances[-1]) + axis[-1].distance_to(axis[-2]))
	var cross_section := PackedVector2Array()
	for i in axis.size():
		var left := axis[i] - axis[maxi(0, i - 1)]
		var right := axis[mini(i + 1, axis.size() - 1)] - axis[i]
		cross_section.append((left.normalized() + right.normalized()).normalized().orthogonal())
	for index in range(1, axis.size()):
		var a := axis[index - 1]
		var b := axis[index]
		var distance := a.distance_to(b)
		var rows := maxi(1, ceili(distance / .48))
		for row in rows:
			var first := float(row) / rows
			var last := float(row + 1) / rows
			for col in 4:
				var low := lerpf(-MAT_HALF_WIDTH, MAT_HALF_WIDTH, col / 4.0)
				var high := lerpf(-MAT_HALF_WIDTH, MAT_HALF_WIDTH, (col + 1) / 4.0)
				for uv: Vector2 in [Vector2(low, first), Vector2(high, first), Vector2(low, last),
						Vector2(low, last), Vector2(high, first), Vector2(high, last)]:
					var across := cross_section[index - 1].lerp(cross_section[index], uv.y).normalized()
					var point := a.lerp(b, uv.y) + across * uv.x
					tile.set_normal(Vector3.UP)
					tile.set_uv(Vector2(uv.x, distances[index - 1] + distance * uv.y))
					tile.add_vertex(Vector3(point.x, float(ground.call(point.x, point.y)) + .035, point.y))
	var blue := ShaderMaterial.new()
	blue.shader = preload("res://lamure_access_mat.gdshader")
	var mat := Kit.mesh_at(parent, tile.commit(), Vector3.ZERO, blue)
	mat.name = "LamureAccessMat"
	mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func build_bin(parent: Node3D, at: Vector3) -> void:
	var bin := Node3D.new()
	bin.name = "BeachWasteBin"
	parent.add_child(bin)
	bin.position = at
	var iron := Kit.paint(Color("#343633"), .65, .13)
	var hole := Kit.paint(Color("#101410"), .99)
	var barrel := CylinderMesh.new()
	barrel.top_radius = .275
	barrel.bottom_radius = .282
	barrel.height = .75
	barrel.radial_segments = 20
	Kit.mesh_at(bin, barrel, Vector3.UP * .375, iron)
	var dome := SphereMesh.new()
	dome.radius = .283
	dome.height = .318
	dome.radial_segments = 16
	dome.rings = 7
	Kit.mesh_at(bin, dome, Vector3.UP * .739, iron)
	Kit.box_at(bin, Vector3(0, .744, .262), Vector3(.228, .118, .034), hole)
	var trim := Kit.paint(Color("#41463e"), .70, .13)
	for rib in 16:
		var angle := TAU * rib / 16
		var position := Vector3(cos(angle) * .276, .367, sin(angle) * .276)
		Kit.box_at(bin, position, Vector3(.031, .68, .029), trim)
