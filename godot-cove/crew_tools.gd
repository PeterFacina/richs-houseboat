extends RefCounted

const Kit = preload("res://scenery.gd")


static func shell(parent: Node3D, at: Vector3, size: Vector3, paint: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	var item := Kit.mesh_at(parent, mesh, at, paint)
	item.scale = size
	return item


static func tube(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, paint: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = a.distance_to(b)
	mesh.bottom_radius = r0
	mesh.top_radius = r1
	mesh.radial_segments = 10
	var segment := Kit.mesh_at(parent, mesh, (a + b) * .5, paint)
	segment.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return segment


static func build_net(parent: Node3D) -> Node3D:
	var net := Node3D.new()
	parent.add_child(net)
	var alloy := Kit.paint(Color("#a79c80"), .37, .35)
	var rubber := Kit.paint(Color("#292f2e"))
	var cord := Kit.paint(Color("#645542"), .92)
	cord.cull_mode = BaseMaterial3D.CULL_DISABLED
	tube(net, Vector3(0, 0, .18), Vector3(0, -.02, -.68), .022, .016, alloy)
	tube(net, Vector3(0, 0, .23), Vector3(0, -.003, -.113), .027, .026, rubber)
	for index in 6:
		var at := .18 - index * .045
		tube(net, Vector3(0, 0, at), Vector3(0, 0, at + .012), .028, .028, rubber)
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var web := SurfaceTool.new()
	web.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 34
	for index in SIDES:
		var angle := TAU * float(index) / SIDES
		var next := TAU * float(index + 1) / SIDES
		strip(rim, knot(angle, 0), knot(next, 0), .011)
		for row in 4:
			var top := row * .25
			var shift := .17 * top
			var bottom := top + .25
			strip(web, knot(angle + shift, top), knot(next + shift, top), .00215)
			strip(web, knot(angle + shift, top), knot(angle + .17 * bottom, bottom), .00205)
		strip(web, knot(angle + .17, 1), Vector3(0, -.35, -1.03), .0020)
	rim.generate_normals()
	web.generate_normals()
	Kit.mesh_at(net, rim.commit(), Vector3.ZERO, alloy)
	Kit.mesh_at(net, web.commit(), Vector3.ZERO, cord).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return net


static func knot(angle: float, fill: float) -> Vector3:
	var ring := lerpf(1.0, .17, fill * fill)
	return Vector3(cos(angle) * .323 * ring, -.312 * sin(fill * 1.48), -1.03 + sin(angle) * .392 * ring)


static func strip(surface: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	var across := (b - a).cross(Vector3.UP).normalized() * width
	if across.length_squared() < .0000001:
		across = Vector3.RIGHT * width
	for point: Vector3 in [a - across, a + across, b - across, b - across, a + across, b + across]:
		surface.add_vertex(point)


static func build_cooler(parent: Node3D) -> Node3D:
	var cooler := Node3D.new()
	parent.add_child(cooler)
	var blue := Kit.paint(Color("#506c71"), .60)
	var lid := Kit.paint(Color("#d9ddcf"), .63)
	var gasket := Kit.paint(Color("#3c4849"), .79)
	var alloy := Kit.paint(Color("#a4b1ab"), .38, .32)
	Kit.box_at(cooler, Vector3(0, .157, 0), Vector3(.631, .310, .374), blue)
	Kit.box_at(cooler, Vector3(0, .065, 0), Vector3(.651, .085, .386), gasket)
	Kit.box_at(cooler, Vector3(0, .308, 0), Vector3(.66, .032, .40), gasket)
	var hinge := Node3D.new()
	hinge.name = "LidHinge"
	cooler.add_child(hinge)
	hinge.position = Vector3(0, .316, .20)
	Kit.box_at(hinge, Vector3(0, .032, -.20), Vector3(.675, .064, .416), lid)
	Kit.box_at(hinge, Vector3(0, .075, -.20), Vector3(.583, .034, .351), lid)
	for side in [-1.0, 1.0]:
		Kit.box_at(cooler, Vector3(side * .333, .183, 0), Vector3(.046, .103, .15), gasket)
		Kit.box_at(cooler, Vector3(side * .363, .208, 0), Vector3(.082, .046, .117), alloy)
		Kit.box_at(cooler, Vector3(side * .183, .275, -.193), Vector3(.054, .107, .027), alloy)
		Kit.box_at(cooler, Vector3(side * .207, .241, .193), Vector3(.109, .081, .027), blue)
	for groove in 6:
		Kit.box_at(hinge, Vector3((groove - 2.5) * .088, .092, -.20), Vector3(.036, .008, .309), lid)
	return cooler
