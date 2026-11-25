extends RefCounted

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const COIL_SEGMENTS := 120
const COIL_SIDES := 8
const ROPE_RADIUS := .012

static var cached_coil: ArrayMesh


static func coil() -> ArrayMesh:
	if cached_coil != null:
		return cached_coil
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(COIL_SEGMENTS + 1):
		var fraction := float(step) / COIL_SEGMENTS
		var point := coil_point(fraction)
		var tangent := (coil_point(minf(1.0, fraction + .003)) - coil_point(maxf(0.0, fraction - .003))).normalized()
		var across := tangent.cross(Vector3.UP).normalized()
		var up := across.cross(tangent).normalized()
		for face in COIL_SIDES:
			var angle := TAU * face / COIL_SIDES
			var normal := up * cos(angle) + across * sin(angle)
			mesh.set_normal(normal)
			var strand := .88 + .12 * cos(TAU * fraction * 36.0 + angle * 2.0)
			mesh.set_color(Color(strand, strand, strand))
			mesh.add_vertex(point + normal * ROPE_RADIUS)
	for ring in COIL_SEGMENTS:
		for face in COIL_SIDES:
			var first := ring * COIL_SIDES + face
			var second := ring * COIL_SIDES + (face + 1) % COIL_SIDES
			for index: int in [first, first + COIL_SIDES, second, second, first + COIL_SIDES, second + COIL_SIDES]:
				mesh.add_index(index)
	for end in [0, COIL_SEGMENTS]:
		var ring := int(end) * COIL_SIDES
		for face in range(1, COIL_SIDES - 1):
			mesh.add_index(ring)
			mesh.add_index(ring + (face if end == 0 else face + 1))
			mesh.add_index(ring + (face + 1 if end == 0 else face))
	cached_coil = mesh.commit()
	return cached_coil


static func coil_point(fraction: float) -> Vector3:
	var angle := (fraction - 1.0) * TAU * 3.6
	var tail := smoothstep(.84, 1.0, fraction)
	var radius := .165 - .101 * fraction + .135 * tail + .007 * sin(angle * 2.0 + .6)
	var cross_over := smoothstep(.76, .89, fraction) - smoothstep(.93, 1.0, fraction)
	var height := ROPE_RADIUS + .002 + .008 * fraction + .026 * cross_over
	return Vector3(radius * cos(angle), height, radius * .93 * sin(angle))


static func coil_tray(parent: Node3D, at: Vector3, dark: Material) -> void:
	var pad := Kit.box_at(parent, at - Vector3.UP * .016, Vector3(.31, .031, .29), dark)
	pad.name = "SternCoilTray"
	for side: float in [-1.0, 1.0]:
		Kit.box_at(parent, at + Vector3(side * .075, -.033, 0), Vector3(.055, .038, .24), dark)


static func cleat(parent: Node3D, at: Vector3, steel: Material, dark: Material) -> void:
	Kit.box_at(parent, at - Vector3.UP * .081, Vector3(.125, .035, .24), dark)
	for z: float in [-.056, .056]:
		Tools.tube(parent, at + Vector3(0, -.070, z), at + Vector3(0, -.023, z), .025, .019, steel)
	Tools.tube(parent, at + Vector3(0, -.018, -.117), at + Vector3(0, -.018, .117), .017, .017, steel)


static func roller(parent: Node3D, at: Vector3, size: float, steel: Material, dark: Material) -> void:
	var bracket := Node3D.new()
	bracket.name = "AnchorRoller"
	parent.add_child(bracket)
	bracket.position = at
	bracket.scale = Vector3.ONE * size
	Kit.box_at(bracket, Vector3(-.096, -.116, 0), Vector3(.36, .056, .26), dark)
	for z: float in [-.108, .108]:
		Kit.beam(bracket, Vector3(-.232, -.112, z), Vector3(.063, -.039, z), .051, steel)
		for x: float in [-.21, -.095]:
			Tools.tube(bracket, Vector3(x, -.104, z), Vector3(x, -.076, z), .022, .018, steel)
	Tools.tube(bracket, Vector3(.061, -.045, -.106), Vector3(.061, -.045, .106), .040, .040, dark)
	Tools.tube(bracket, Vector3(.061, -.045, -.133), Vector3(.061, -.045, .133), .018, .018, steel)


static func anchor(parent: Node3D, steel: Material, dark: Material) -> Node3D:
	var model := Node3D.new()
	model.name = "MarineAnchor"
	parent.add_child(model)
	Tools.tube(model, Vector3(0, -.045, 0), Vector3(0, -.560, 0), .034, .046, steel)
	Tools.tube(model, Vector3(-.205, -.193, .012), Vector3(.205, -.193, .012), .030, .030, steel)
	Tools.tube(model, Vector3(0, -.185, 0), Vector3(0, -.231, 0), .052, .052, dark)
	for side: float in [-1.0, 1.0]:
		Tools.tube(model, Vector3(side * .176, -.193, .012), Vector3(side * .220, -.193, .012), .040, .038, steel)
		var elbow := Vector3(side * .127, -.551, 0)
		var tip := Vector3(side * .232, -.437, 0)
		Tools.tube(model, Vector3(0, -.570, 0), elbow, .044, .033, steel)
		Tools.tube(model, elbow, tip, .033, .022, steel)
		add_fluke(model, side, steel)
	for link in 4:
		var ring := TorusMesh.new()
		ring.inner_radius = .025 if link == 0 else .013
		ring.outer_radius = .044 if link == 0 else .024
		ring.rings = 12
		ring.ring_segments = 8
		var mesh := Kit.mesh_at(model, ring, Vector3.UP * (-.022 + link * .033), dark if link % 2 else steel)
		mesh.rotation.z = PI * .5 if link % 2 else 0.0
		mesh.rotation.x = 0.0 if link % 2 else PI * .5
		mesh.scale.y = 1.12
	return model


static func add_fluke(model: Node3D, side: float, steel: Material) -> void:
	var blade := PackedVector2Array([Vector2(side * .137, -.493), Vector2(side * .259, -.494),
		Vector2(side * .340, -.305), Vector2(side * .205, -.362)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := Geometry2D.triangulate_polygon(blade)
	for z: float in [-.033, .033]:
		for index in faces.size():
			var vertex := blade[faces[index if z < 0.0 else faces.size() - 1 - index]]
			surface.add_vertex(Vector3(vertex.x, vertex.y, z))
	for i in blade.size():
		var a := blade[i]
		var b := blade[(i + 1) % blade.size()]
		var edge := [Vector3(a.x, a.y, -.033), Vector3(b.x, b.y, -.033),
			Vector3(b.x, b.y, .033), Vector3(a.x, a.y, .033)]
		for index in ([0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]):
			surface.add_vertex(edge[index])
	surface.generate_normals()
	Kit.mesh_at(model, surface.commit(), Vector3.ZERO, steel)


static func rode() -> ArrayMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .012
	cylinder.bottom_radius = .012
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	cylinder.rings = 0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(cylinder, 0, Transform3D(Basis(Vector3.RIGHT, PI * .5), Vector3.ZERO))
	return surface.commit()
