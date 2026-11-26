extends RefCounted

const Kit = preload("res://scenery.gd")

# The 3GW8+JQ address pin converts to (18357.6, 13861.7) in the baked metre grid.
# It falls beside the right-hand entrance of this mapped duplex, not at ms-1022
# beyond the Silvie/Hillcrest junction. Dimensions are photo-based estimates.
const HOUSE_FOOTPRINT := "ms-374"
const SITE := Vector2(18345.5865, 13866.1102)
const YAW := 0.40
const HOUSE := Vector2(17.0, 9.4)
const YARD_RIGHT := 16.8
const YARD_REAR := -42.0


static func replaces(footprint: String) -> bool:
	return footprint == HOUSE_FOOTPRINT


static func clears_tree(point: Vector2) -> bool:
	var local := (point - SITE).rotated(YAW)
	return Rect2(Vector2(-9.5, YARD_REAR - 2.0), Vector2(28.0, 74.0)).has_point(local)


static func build(parent: Node3D, elevation: Callable, wood_scan: Texture2D) -> Node3D:
	var site := Node3D.new()
	site.name = "MarioProperty16Silvie"
	parent.add_child(site)
	site.position = Vector3(SITE.x, elevation.call(SITE.x, SITE.y), SITE.y)
	site.rotation.y = YAW
	var body := StaticBody3D.new()
	body.name = "PropertyCollision"
	site.add_child(body)
	var siding := Kit.paint(Color("#dddcd3"), .85)
	var roof := Kit.paint(Color("#414950"), .94)
	var shutters := Kit.paint(Color("#60758a"), .78)
	var glass := Kit.paint(Color("#65818a"), .22)
	var white := Kit.paint(Color("#eeeae2"), .79)
	var blue := Kit.paint(Color("#6d8492"), .75)
	var concrete := Kit.paint(Color("#99978f"), .94)
	var asphalt := Kit.paint(Color("#3e4141"), .98)
	var fence := Kit.paint(Color("#705944"), .93)
	fence.albedo_texture = wood_scan
	fence.uv1_triplanar = true
	var shed_wall := Kit.paint(Color("#747571"), .89)
	var shed_roof := Kit.paint(Color("#313b42"), .92)
	var translucent := Kit.paint(Color("#aec4bb", .68), .31)
	translucent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var firebrick := Kit.paint(Color("#777b78"), .96)
	build_house(site, body, siding, roof, shutters, glass, white, blue, concrete)
	build_approach(site, body, elevation, asphalt, concrete, white, roof)
	build_fence(site, body, elevation, fence)
	build_fire_pit(site, body, elevation, firebrick)
	build_rear_building(site, body, elevation, Vector2(4.0, -34.2), Vector2(6.2, 8.0),
		3.5, fence, shed_roof, false)
	build_rear_building(site, body, elevation, Vector2(11.2, -34.2), Vector2(5.6, 7.8),
		4.4, shed_wall, shed_roof, true)
	build_greenhouse(site, body, elevation, Vector2(4.0, -27.5), fence, translucent)
	return site


static func ground_y(site: Node3D, elevation: Callable, x: float, z: float) -> float:
	var at := site.to_global(Vector3(x, 0, z))
	return elevation.call(at.x, at.z) - site.global_position.y


static func box(root: Node3D, body: StaticBody3D, at: Vector3, size: Vector3,
		material: Material, solid := false) -> MeshInstance3D:
	var mesh := Kit.box_at(root, at, size, material)
	if solid:
		Kit.collider(body, at, size)
	return mesh


static func build_house(root: Node3D, body: StaticBody3D, siding: Material, roof: Material,
		shutters: Material, glass: Material, white: Material, blue: Material, concrete: Material) -> void:
	# The mapped footprint is replaced once. The neighboring half remains exterior context.
	box(root, body, Vector3(0, -.35, 0), Vector3(HOUSE.x + .2, .9, HOUSE.y + .2), concrete, true)
	box(root, body, Vector3(0, 2.9, 0), Vector3(HOUSE.x, 5.8, HOUSE.y), siding, true)
	for level in 2:
		var y := 1.6 + 2.7 * level
		for x in [-6.3, -3.5, 2.2, 6.0]:
			box(root, body, Vector3(x, y, HOUSE.y * .5 + .035), Vector3(1.32, 1.42, .09), white)
			box(root, body, Vector3(x, y, HOUSE.y * .5 + .095), Vector3(1.08, 1.13, .06), glass)
			for side in [-1.0, 1.0]:
				box(root, body, Vector3(x + side * .79, y, HOUSE.y * .5 + .10),
					Vector3(.28, 1.44, .10), shutters)
	# Narrow siding courses read as horizontal clapboard without adding interior geometry.
	for course in 18:
		var y := .30 + course * .30
		box(root, body, Vector3(0, y, HOUSE.y * .5 + .063), Vector3(HOUSE.x, .035, .035), white)
		for side in [-1.0, 1.0]:
			box(root, body, Vector3(side * (HOUSE.x * .5 + .063), y, 0),
				Vector3(.035, .035, HOUSE.y), white)
	for side in [-1.0, 1.0]:
		var plane := box(root, body, Vector3(0, 6.22, side * 2.45),
			Vector3(HOUSE.x + .9, .18, 5.35), roof)
		plane.rotation.x = side * .23
	box(root, body, Vector3(0, 6.78, 0), Vector3(HOUSE.x + .9, .16, .18), roof)
	# The right-hand front entry is offset from the driveway, as in the street photo.
	box(root, body, Vector3(4.1, 1.12, HOUSE.y * .5 + .09), Vector3(1.12, 2.24, .12), blue)
	box(root, body, Vector3(4.1, 2.73, 6.0), Vector3(2.65, .14, 2.6), roof)
	for x in [2.95, 5.25]:
		box(root, body, Vector3(x, 1.34, 7.05), Vector3(.12, 2.68, .12), white)
	box(root, body, Vector3(4.1, .48, 5.55), Vector3(2.5, .16, 1.8), concrete, true)
	for step in 3:
		box(root, body, Vector3(4.1, .10 + step * .14, 7.05 - step * .32),
			Vector3(1.9, .20 + step * .10, .60), concrete, true)


static func paving(root: Node3D, body: StaticBody3D, elevation: Callable, x: float, z: float,
		width: float, depth: float, material: Material) -> void:
	# Sample every corner so thin paving stays above the sloped terrain and street.
	# Terrain already supplies its walkable collision.
	var points := [Vector2(x - width * .5, z - depth * .5),
		Vector2(x + width * .5, z - depth * .5),
		Vector2(x + width * .5, z + depth * .5),
		Vector2(x - width * .5, z + depth * .5)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in points:
		surface.set_normal(Vector3.UP)
		surface.set_uv(point * .25)
		surface.add_vertex(Vector3(point.x, ground_y(root, elevation, point.x, point.y) + .11, point.y))
	for index in [0, 1, 2, 0, 2, 3]:
		surface.add_index(index)
	Kit.mesh_at(root, surface.commit(), Vector3.ZERO, material)


static func build_approach(root: Node3D, body: StaticBody3D, elevation: Callable,
		asphalt: Material, concrete: Material, white: Material, roof: Material) -> void:
	# Silvie Street is about 27 m in front of the mapped house. Mario's driveway
	# stays on the right, with a separate paved walk immediately to its left.
	for z in range(7, 24, 2):
		paving(root, body, elevation, 11.1, float(z), 3.5, 2.05, asphalt)
		paving(root, body, elevation, 8.35, float(z), 1.45, 2.05, concrete)
	paving(root, body, elevation, 11.1, 24.4, 3.5, .8, asphalt)
	paving(root, body, elevation, 8.35, 24.4, 1.45, .8, concrete)
	for x in [4.1, 5.5, 6.9, 8.3]:
		paving(root, body, elevation, x, 7.4, 1.35, 1.25, concrete)
	# Turn from the entrance toward the side porch, then stop at the lawn.
	for z in [5.8, 4.3, 2.8, 1.3, -.2, -1.7, -3.2, -4.7, -6.2, -7.7]:
		paving(root, body, elevation, 10.1, z, 1.45, 1.5, concrete)
	var porch_y := ground_y(root, elevation, 10.0, -2.0)
	box(root, body, Vector3(10.0, porch_y + 2.55, -1.8), Vector3(3.2, .16, 4.5), roof)
	for z in [-3.8, .2]:
		box(root, body, Vector3(11.4, porch_y + 1.25, z), Vector3(.12, 2.5, .12), white, true)


static func build_fence(root: Node3D, body: StaticBody3D, elevation: Callable, wood: Material) -> void:
	for x in [0.0, YARD_RIGHT]:
		for z in range(-8, -43, -2):
			var y := ground_y(root, elevation, x, float(z))
			box(root, body, Vector3(x, y + .83, z), Vector3(.11, 1.65, 2.02), wood, true)
			for offset in [-.5, .5]:
				box(root, body, Vector3(x + (.07 if x == 0.0 else -.07), y + .83, z + offset),
					Vector3(.035, 1.65, .035), wood)
	for x in range(0, 17, 2):
		var y := ground_y(root, elevation, float(x), YARD_REAR)
		box(root, body, Vector3(x, y + .83, YARD_REAR), Vector3(2.02, 1.65, .11), wood, true)


static func build_fire_pit(root: Node3D, body: StaticBody3D, elevation: Callable,
		stone: Material) -> void:
	var y := ground_y(root, elevation, 8.4, -18.5)
	var ash := Kit.paint(Color("#333835"), .98)
	var center := CylinderMesh.new()
	center.top_radius = .67
	center.bottom_radius = .67
	center.height = .035
	center.radial_segments = 24
	Kit.mesh_at(root, center, Vector3(8.4, y + .025, -18.5), ash)
	for ring in 2:
		for i in 16:
			var angle := TAU * (float(i) + .5 * ring) / 16.0
			var at := Vector3(8.4 + cos(angle) * .78, y + .115 + ring * .22,
				-18.5 + sin(angle) * .78)
			var brick := box(root, body, at, Vector3(.38, .21, .23), stone)
			brick.rotation.y = -angle + PI * .5
	var pit := CylinderShape3D.new()
	pit.radius = .92
	pit.height = .45
	var collision := CollisionShape3D.new()
	collision.shape = pit
	body.add_child(collision)
	collision.position = Vector3(8.4, y + .225, -18.5)


static func build_rear_building(root: Node3D, body: StaticBody3D, elevation: Callable,
		at: Vector2, size: Vector2, height: float, wall: Material, roof: Material,
		workshop: bool) -> void:
	var y := ground_y(root, elevation, at.x, at.y)
	var name := "WorkshopS" if workshop else "StorageGarageG"
	var marker := Node3D.new()
	marker.name = name
	root.add_child(marker)
	marker.position = Vector3(at.x, y, at.y)
	box(root, body, Vector3(at.x, y + .04, at.y), Vector3(size.x, .08, size.y), wall, true)
	for side in [-1.0, 1.0]:
		box(root, body, Vector3(at.x + side * size.x * .5, y + height * .5, at.y),
			Vector3(.15, height, size.y), wall, true)
	box(root, body, Vector3(at.x, y + height * .5, at.y - size.y * .5),
		Vector3(size.x, height, .15), wall, true)
	# G has a wide boat opening; S has a narrower workshop doorway.
	for side in [-1.0, 1.0]:
		box(root, body, Vector3(at.x + side * (size.x * .5 - .45), y + height * .5,
			at.y + size.y * .5), Vector3(.9, height, .15), wall, true)
	if workshop:
		for side in [-1.0, 1.0]:
			box(root, body, Vector3(at.x + side * 1.55, y + height * .5, at.y + size.y * .5),
				Vector3(1.85, height, .15), wall, true)
		box(root, body, Vector3(at.x, y + height - .2, at.y + size.y * .5),
			Vector3(1.25, .4, .15), wall, true)
		var door := box(root, body, Vector3(at.x - .70, y + 1.05, at.y + size.y * .5 + .35),
			Vector3(1.25, 2.1, .08), roof)
		door.rotation.y = -.9
		# The tall sloped roof and high window are the backyard photo's S silhouette.
		var plane := box(root, body, Vector3(at.x, y + height + .22, at.y),
			Vector3(size.x + .55, .18, size.y + .55), roof)
		plane.rotation.x = -.14
		box(root, body, Vector3(at.x + 1.65, y + height - .9, at.y + size.y * .5 + .09),
			Vector3(.9, .9, .08), Kit.paint(Color("#78939d"), .24))
	else:
		box(root, body, Vector3(at.x, y + height + .13, at.y),
			Vector3(size.x + .5, .2, size.y + .5), roof)


static func build_greenhouse(root: Node3D, body: StaticBody3D, elevation: Callable,
		at: Vector2, wood: Material, panel: Material) -> void:
	# The back edge is 0.8 m from G's front edge; either side has clearance.
	var size := Vector2(4.8, 3.8)
	var y := ground_y(root, elevation, at.x, at.y)
	var marker := Node3D.new()
	marker.name = "GreenhouseGH"
	root.add_child(marker)
	marker.position = Vector3(at.x, y, at.y)
	for x in [at.x - size.x * .5, at.x + size.x * .5]:
		box(root, body, Vector3(x, y + .45, at.y), Vector3(.11, .9, size.y), wood, true)
		box(root, body, Vector3(x, y + 1.48, at.y), Vector3(.06, 1.16, size.y), panel)
	for z in [at.y - size.y * .5, at.y + size.y * .5]:
		if z < at.y:
			box(root, body, Vector3(at.x, y + .45, z), Vector3(size.x, .9, .11), wood, true)
			box(root, body, Vector3(at.x, y + 1.48, z), Vector3(size.x, 1.16, .06), panel)
		else:
			# A door-width opening faces the lawn.
			for side in [-1.0, 1.0]:
				box(root, body, Vector3(at.x + side * 1.55, y + .45, z),
					Vector3(1.7, .9, .11), wood, true)
				box(root, body, Vector3(at.x + side * 1.55, y + 1.48, z),
					Vector3(1.7, 1.16, .06), panel)
	for x in [at.x - size.x * .5, at.x, at.x + size.x * .5]:
		for z in [at.y - size.y * .5, at.y + size.y * .5]:
			box(root, body, Vector3(x, y + 1.45, z), Vector3(.09, 2.9, .09), wood, true)
	var plane := box(root, body, Vector3(at.x, y + 2.8, at.y),
		Vector3(size.x + .25, .09, size.y + .25), panel)
	plane.rotation.x = -.18
