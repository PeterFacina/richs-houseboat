extends RefCounted

const Kit = preload("res://scenery.gd")
const SIDES := 8
# Each section gives its position along the cleat, centre height, and two radii.
const PROFILE := [
	Vector4(-.38, .199, .016, .029), Vector4(-.31, .176, .031, .043),
	Vector4(-.19, .151, .042, .055), Vector4(0, .145, .048, .063),
	Vector4(.19, .151, .042, .055), Vector4(.31, .176, .031, .043),
	Vector4(.38, .199, .016, .029),
]

static var cleat_mesh: ArrayMesh


static func mesh() -> ArrayMesh:
	if cleat_mesh != null:
		return cleat_mesh

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plate := BoxMesh.new()
	plate.size = Vector3(.51, .050, .228)
	surface.append_from(plate, 0, Transform3D(Basis.IDENTITY, Vector3.UP * .025))
	var post := CylinderMesh.new()
	post.top_radius = .050
	post.bottom_radius = .073
	post.height = .121
	post.radial_segments = 10
	for x: float in [-.12, .12]:
		surface.append_from(post, 0, Transform3D(Basis.IDENTITY, Vector3(x, .091, 0)))
	surface.deindex()
	for span in range(PROFILE.size() - 1):
		for side in SIDES:
			add_section(surface, PROFILE[span], side)
			add_section(surface, PROFILE[span + 1], side)
			add_section(surface, PROFILE[span], side + 1)
			add_section(surface, PROFILE[span], side + 1)
			add_section(surface, PROFILE[span + 1], side)
			add_section(surface, PROFILE[span + 1], side + 1)
	for side in SIDES:
		for tip: float in [-1.0, 1.0]:
			var section: Vector4 = PROFILE.front() if tip < 0 else PROFILE.back()
			surface.set_normal(Vector3(tip, 0, 0))
			surface.add_vertex(Vector3(section.x, section.y, 0))
			surface.add_vertex(section_point(section, side if tip < 0 else side + 1))
			surface.add_vertex(section_point(section, side + 1 if tip < 0 else side))
	cleat_mesh = surface.commit()
	cleat_mesh.surface_set_material(0, Kit.paint(Color("#454d4d"), .48, .31))

	var bolts := SurfaceTool.new()
	bolts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hex_head := CylinderMesh.new()
	hex_head.top_radius = .022
	hex_head.bottom_radius = .024
	hex_head.height = .017
	hex_head.radial_segments = 6
	for x: float in [-.20, .20]:
		for z: float in [-.072, .072]:
			bolts.append_from(hex_head, 0, Transform3D(Basis.IDENTITY, Vector3(x, .056, z)))
	bolts.commit(cleat_mesh)
	cleat_mesh.surface_set_material(1, Kit.paint(Color("#939c9a"), .45, .42))
	return cleat_mesh


static func section_point(section: Vector4, side: int) -> Vector3:
	var angle := TAU * side / SIDES
	return Vector3(section.x, section.y + cos(angle) * section.z, sin(angle) * section.w)


static func add_section(surface: SurfaceTool, section: Vector4, side: int) -> void:
	var vertex := section_point(section, side)
	surface.set_normal((vertex - Vector3(section.x, section.y, 0)).normalized())
	surface.add_vertex(vertex)


static func place(parent: Node3D, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var cleats := Kit.new().scatter(parent, mesh(), transforms, null)
	cleats.name = "MooringCleats"
	return cleats
