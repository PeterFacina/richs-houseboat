extends RefCounted

const Kit = preload("res://scenery.gd")

# Approximate placement from the owner's street references: the east end of Silvie Street,
# adjacent to Hillcrest Avenue. Interior dimensions are not known from the supplied photos.
const SITE := Vector2(18455.0, 13792.0)
const HOUSE_SIZE := Vector2(13.6, 9.4)


static func build(parent: Node3D, elevation: Callable, concrete_scan: Texture2D, wood_scan: Texture2D) -> Node3D:
	var site := Node3D.new()
	site.name = "MarioHome16Silvie"
	parent.add_child(site)
	site.position = Vector3(SITE.x, float(elevation.call(SITE.x, SITE.y)), SITE.y)
	site.rotation.y = 1.16
	var siding := Kit.paint(Color("#d8d2c5"), .82)
	var roof := Kit.paint(Color("#444a4b"), .92)
	var shutter := Kit.paint(Color("#536273"), .78)
	var window := Kit.paint(Color("#70878b"), .25, .42)
	var trim := Kit.paint(Color("#eee9dc"), .82)
	var door := Kit.paint(Color("#42687b"), .66)
	var lawn := Kit.paint(Color("#647951"), .98)
	var concrete := Kit.paint(Color("#a8a49b"), .94)
	var wood := Kit.paint(Color("#735743"), .94)
	var wood_scan_material := Kit.paint(Color("#80664d"), .91)
	if wood_scan != null:
		wood_scan_material.albedo_texture = wood_scan
		wood_scan_material.uv1_triplanar = true
	var asphalt := Kit.paint(Color("#292e31"), .95)
	if concrete_scan != null:
		concrete.albedo_texture = concrete_scan
		concrete.uv1_triplanar = true
	var world := StaticBody3D.new()
	world.name = "PropertyCollision"
	site.add_child(world)
	# A graded lawn and walkable hard surfaces give the property clear, usable boundaries.
	Kit.box_at(site, Vector3(0, -.10, 0), Vector3(30, .16, 36), lawn)
	Kit.collider(world, Vector3(0, -.20, 0), Vector3(30, .20, 36))
	var house := Vector2(-4.1, -4.2)
	build_duplex(site, world, house, siding, roof, shutter, window, trim, door, concrete)
	build_walk(site, world, house, concrete)
	build_driveway(site, world, Vector2(3.5, -2.6), asphalt)
	build_yard(site, world, wood_scan_material, wood, concrete)
	build_garage(site, world, Vector2(8.2, 6.0), wood_scan_material, door, roof, window)
	build_shed(site, world, Vector2(-8.9, 5.8), wood, roof)
	return site


static func build_duplex(root: Node3D, body: StaticBody3D, at: Vector2, wall: Material, roof: Material,
		shutter: Material, glass: Material, trim: Material, blue_door: Material, stone: Material) -> void:
	var size := HOUSE_SIZE
	var base := Vector3(at.x, 0, at.y)
	Kit.box_at(root, base + Vector3(0, .12, 0), Vector3(size.x + .30, .24, size.y + .30), stone)
	var wall_height := 5.55
	Kit.box_at(root, base + Vector3(0, wall_height * .5 + .24, 0), Vector3(size.x, wall_height, size.y), wall)
	Kit.collider(body, base + Vector3(0, wall_height * .5 + .24, 0), Vector3(size.x, wall_height, size.y))
	# A shallow gable and grey shingle planes keep the recognizable two-storey silhouette.
	var roof_ridge := base + Vector3(0, 6.14, 0)
	Kit.box_at(root, roof_ridge, Vector3(.20, .24, size.y + 1.15), roof)
	for side in [-1.0, 1.0]:
		var plane := Kit.box_at(root, roof_ridge + Vector3(side * 3.48, -.18, 0), Vector3(7.15, .20, size.y + .95), roof)
		plane.rotation.z = -side * .24
	for floor in 2:
		var y := 1.34 + floor * 2.65
		for i in 4:
			var x := at.x - 4.45 + i * 2.88
			Kit.box_at(root, Vector3(x, y, at.y + size.y * .5 + .018), Vector3(.98, 1.10, .065), trim)
			Kit.box_at(root, Vector3(x, y, at.y + size.y * .5 + .060), Vector3(.78, .84, .018), glass)
			for side in [-1.0, 1.0]:
				Kit.box_at(root, Vector3(x + side * .62, y, at.y + size.y * .5 + .072), Vector3(.18, 1.18, .11), shutter)
		Kit.box_at(root, Vector3(at.x + 2.48, y, at.y + size.y * .5 + .035), Vector3(1.12, 1.18, .09), trim)
		Kit.box_at(root, Vector3(at.x + 2.48, y, at.y + size.y * .5 + .092), Vector3(.89, .94, .018), glass)
		for side in [-1.0, 1.0]:
			Kit.box_at(root, Vector3(at.x + 2.48 + side * .69, y, at.y + size.y * .5 + .105), Vector3(.18, 1.23, .11), shutter)
	# Front door, small porch cover, concrete landing and steps.
	var porch := Vector3(at.x + 4.65, .95, at.y + size.y * .5 + .85)
	Kit.box_at(root, porch + Vector3(0, .94, 0), Vector3(2.7, .12, 1.9), roof)
	for x in [-1.10, 1.10]:
		Kit.box_at(root, porch + Vector3(x, .43, .63), Vector3(.13, .86, .13), trim)
	Kit.box_at(root, Vector3(at.x + 4.65, 1.12, at.y + size.y * .5 + .08), Vector3(1.1, 2.16, .13), blue_door)
	Kit.box_at(root, Vector3(at.x + 4.65, .45, at.y + size.y * .5 + 1.0), Vector3(2.8, .14, 2.2), stone)
	for step in 3:
		Kit.box_at(root, Vector3(at.x + 4.65, .12 + step * .19, at.y + size.y * .5 + 1.48 + step * .29),
			Vector3(1.65, .18, .58), stone)
	# An implied shared-wall seam keeps the duplex clear while neighboring half stays sealed.
	Kit.box_at(root, Vector3(at.x - .75, 3.0, at.y + size.y * .5 + .056), Vector3(.045, 5.8, .028), trim)


static func build_walk(root: Node3D, body: StaticBody3D, house: Vector2, stone: Material) -> void:
	for i in 11:
		var pos := Vector3(house.x + 4.65, .02, house.y + 6.7 + i * .73)
		Kit.box_at(root, pos, Vector3(1.65, .08, .65), stone)
		Kit.collider(body, pos + Vector3(0, -.04, 0), Vector3(1.65, .08, .65))


static func build_driveway(root: Node3D, body: StaticBody3D, at: Vector2, asphalt: Material) -> void:
	Kit.box_at(root, Vector3(at.x, .035, at.y + 5.2), Vector3(6.4, .07, 16), asphalt)
	Kit.collider(body, Vector3(at.x, -.012, at.y + 5.2), Vector3(6.4, .05, 16))


static func build_yard(root: Node3D, body: StaticBody3D, fence: Material, firebrick: Material, stone: Material) -> void:
	# Privacy fence encloses the rear and sides without taking the street frontage.
	for x in range(-14, 15, 2):
		Kit.box_at(root, Vector3(x, 1.05, 17.7), Vector3(1.8, 2.1, .12), fence)
	for z in range(2, 18, 2):
		for side in [-1.0, 1.0]:
			Kit.box_at(root, Vector3(side * 14.0, 1.05, z), Vector3(.12, 2.1, 1.8), fence)
	var pit := Vector3(0, .05, 9.0)
	for side in range(4):
		var block := Kit.box_at(root, pit + Vector3((side % 2) * .82 - .41, .22, (side / 2) * .82 - .41), Vector3(.88, .42, .18), firebrick)
		block.rotation.y = PI * .5 * (side % 2)
	for i in 3:
		Kit.box_at(root, Vector3(-2.5, .16 + i * .12, 7.7), Vector3(2.0, .19, .40), stone)
	# Side cover and lumber racks suggest the source photos while keeping circulation clear.
	for x in [-12.2, -8.8]:
		Kit.box_at(root, Vector3(x, 2.1, 8.0), Vector3(.13, 4.2, .13), fence)
	Kit.box_at(root, Vector3(-10.5, 4.15, 8.0), Vector3(3.6, .16, 4.3), fence)
	for i in 4:
		Kit.box_at(root, Vector3(6.2 + i * .42, .72, 10.1), Vector3(.35, .10, 3.5), fence)


static func build_garage(root: Node3D, body: StaticBody3D, at: Vector2, wall: Material,
		blue: Material, roof: Material, glass: Material) -> void:
	var size := Vector2(8.5, 9.0)
	var center := Vector3(at.x, 0, at.y)
	var height := 5.15
	Kit.box_at(root, center + Vector3(0, .11, 0), Vector3(size.x + .24, .22, size.y + .24), Kit.paint(Color("#888c8d"), .94))
	Kit.collider(body, center + Vector3(0, .11, 0), Vector3(size.x + .24, .22, size.y + .24))
	for side in [-1.0, 1.0]:
		var x: float = side * size.x * .5
		Kit.box_at(root, center + Vector3(x, height * .5 + .22, 0), Vector3(.18, height, size.y), wall)
		Kit.collider(body, center + Vector3(x, height * .5 + .22, 0), Vector3(.18, height, size.y))
	Kit.box_at(root, center + Vector3(0, height + .13, 0), Vector3(size.x + .35, .20, size.y + .35), roof)
	# Two blue doors face the house and yard.
	for x in [-2.1, 2.1]:
		Kit.box_at(root, center + Vector3(x, 1.65, size.y * .5 + .07), Vector3(3.4, 3.05, .13), blue)
		for y in [.48, .96, 1.44, 1.92, 2.40, 2.82]:
			Kit.box_at(root, center + Vector3(x, y, size.y * .5 + .15), Vector3(3.34, .045, .025), Kit.paint(Color("#244a61"), .8))
	# Woodworking bench, saw table, drill press and cabinets are usable visual set dressing.
	Kit.box_at(root, center + Vector3(-2.4, .94, -2.1), Vector3(4.0, .18, 1.0), Kit.paint(Color("#75533a"), .9))
	Kit.box_at(root, center + Vector3(-2.4, .48, -2.1), Vector3(.15, .9, .82), Kit.paint(Color("#48504c"), .8))
	Kit.box_at(root, center + Vector3(2.0, .80, -2.4), Vector3(1.1, 1.6, .9), Kit.paint(Color("#48545a"), .8))
	Kit.box_at(root, center + Vector3(3.0, 1.1, 0), Vector3(.45, 2.2, .55), Kit.paint(Color("#536269"), .8))
	for i in 4:
		Kit.box_at(root, center + Vector3(-3.6 + i * .46, .85, -4.65), Vector3(.30, 1.5, .12), glass)


static func build_shed(root: Node3D, body: StaticBody3D, at: Vector2, wall: Material, roof: Material) -> void:
	var center := Vector3(at.x, 0, at.y)
	Kit.box_at(root, center + Vector3(0, 1.35, 0), Vector3(3.8, 2.7, 4.6), wall)
	Kit.collider(body, center + Vector3(0, 1.35, 0), Vector3(3.8, 2.7, 4.6))
	Kit.box_at(root, center + Vector3(0, 2.82, 0), Vector3(4.2, .18, 5.0), roof)
	Kit.box_at(root, center + Vector3(0, .76, 2.35), Vector3(1.5, 1.55, .12), roof)
