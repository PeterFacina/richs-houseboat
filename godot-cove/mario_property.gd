extends RefCounted

const Kit = preload("res://scenery.gd")

# The address pin and the mapped ms-1022 duplex footprint agree within one parcel.
# Coordinates use the town's metre grid; this is the duplex center, not the lot center.
const SITE := Vector2(18518.041, 13824.852)
const SITE_ROTATION := -0.84
const HOUSE_SIZE := Vector2(13.6, 9.4)
const MAPPED_HOUSE := "ms-1022"


static func replaces(footprint: String) -> bool:
	return footprint == MAPPED_HOUSE


static func build(parent: Node3D, elevation: Callable, concrete_scan: Texture2D, wood_scan: Texture2D) -> Node3D:
	var site := Node3D.new()
	site.name = "MarioHome16Silvie"
	parent.add_child(site)
	site.position = Vector3(SITE.x, float(elevation.call(SITE.x, SITE.y)), SITE.y)
	site.rotation.y = SITE_ROTATION
	var siding := Kit.paint(Color("#d8d2c5"), .82)
	var roof := Kit.paint(Color("#444a4b"), .92)
	var metal_roof := Kit.paint(Color("#596267"), .80)
	var shutter := Kit.paint(Color("#536273"), .78)
	var window := Kit.paint(Color("#70878b"), .25, .42)
	var trim := Kit.paint(Color("#eee9dc"), .82)
	var door := Kit.paint(Color("#42687b"), .66)
	var lawn := Kit.paint(Color("#647951"), .98)
	var concrete := Kit.paint(Color("#a8a49b"), .94)
	var gravel := Kit.paint(Color("#77746c"), .96)
	var wood := Kit.paint(Color("#735743"), .94)
	var wood_scan_material := Kit.paint(Color("#80664d"), .91)
	if wood_scan != null:
		wood_scan_material.albedo_texture = wood_scan
		wood_scan_material.uv1_triplanar = true
	if concrete_scan != null:
		concrete.albedo_texture = concrete_scan
		concrete.uv1_triplanar = true
	var world := StaticBody3D.new()
	world.name = "PropertyCollision"
	site.add_child(world)
	# Mario's yard occupies the right-hand parcel behind the duplex; the other unit stays clear.
	Kit.box_at(site, Vector3(12.0, -.10, -30.0), Vector3(24.0, .16, 50.0), lawn)
	Kit.collider(world, Vector3(12.0, -.20, -30.0), Vector3(24.0, .20, 50.0))
	build_duplex(site, world, siding, roof, shutter, window, trim, door, concrete)
	build_front_walk(site, world, concrete)
	build_driveway(site, world, gravel)
	build_yard(site, world, wood_scan_material, wood, concrete)
	# The rear street sits across the back of the long residential lots. A clear approach
	# leads from it through the boat shed and into Mario's yard.
	Kit.box_at(site, Vector3(10.5, .035, -54.0), Vector3(5.2, .07, 12.0), gravel)
	Kit.collider(world, Vector3(10.5, -.01, -54.0), Vector3(5.2, .05, 12.0))
	build_shed(site, world, Vector2(10.5, -43.5), wood_scan_material, metal_roof)
	build_garage(site, world, Vector2(19.0, -43.5), wood_scan_material, door, metal_roof, window)
	return site


static func build_duplex(root: Node3D, body: StaticBody3D, wall: Material, roof: Material,
		shutter: Material, glass: Material, trim: Material, blue_door: Material, stone: Material) -> void:
	var half := HOUSE_SIZE * .5
	Kit.box_at(root, Vector3(0, .12, 0), Vector3(HOUSE_SIZE.x + .30, .24, HOUSE_SIZE.y + .30), stone)
	var wall_height := 5.55
	var wall_center := Vector3(0, wall_height * .5 + .24, 0)
	Kit.box_at(root, wall_center, Vector3(HOUSE_SIZE.x, wall_height, HOUSE_SIZE.y), wall)
	Kit.collider(body, wall_center, Vector3(HOUSE_SIZE.x, wall_height, HOUSE_SIZE.y))
	# The broad front faces Silvie Street; the right-hand unit is Mario's.
	var roof_ridge := Vector3(0, 6.14, 0)
	Kit.box_at(root, roof_ridge, Vector3(.20, .24, HOUSE_SIZE.y + 1.15), roof)
	for side in [-1.0, 1.0]:
		var plane := Kit.box_at(root, roof_ridge + Vector3(side * 3.48, -.18, 0), Vector3(7.15, .20, HOUSE_SIZE.y + .95), roof)
		plane.rotation.z = -side * .24
	for floor in 2:
		var y := 1.34 + floor * 2.65
		for i in 4:
			var x := -half.x + 1.72 + i * 2.88
			Kit.box_at(root, Vector3(x, y, half.y + .018), Vector3(.98, 1.10, .065), trim)
			Kit.box_at(root, Vector3(x, y, half.y + .060), Vector3(.78, .84, .018), glass)
			for side in [-1.0, 1.0]:
				Kit.box_at(root, Vector3(x + side * .62, y, half.y + .072), Vector3(.18, 1.18, .11), shutter)
		# Mario's entry is on the right half; the neighboring unit remains ordinary and sealed.
		var door_x := 4.65
		Kit.box_at(root, Vector3(door_x, y, half.y + .035), Vector3(1.12, 1.18, .09), trim)
		Kit.box_at(root, Vector3(door_x, y, half.y + .092), Vector3(.89, .94, .018), glass)
		for side in [-1.0, 1.0]:
			Kit.box_at(root, Vector3(door_x + side * .69, y, half.y + .105), Vector3(.18, 1.23, .11), shutter)
	# Separate entry porch and concrete stairs on Mario's side.
	var porch := Vector3(4.65, .95, half.y + .85)
	Kit.box_at(root, porch + Vector3(0, .94, 0), Vector3(2.7, .12, 1.9), roof)
	for x in [-1.10, 1.10]:
		Kit.box_at(root, porch + Vector3(x, .43, .63), Vector3(.13, .86, .13), trim)
	Kit.box_at(root, Vector3(4.65, 1.12, half.y + .08), Vector3(1.1, 2.16, .13), blue_door)
	Kit.box_at(root, Vector3(4.65, .45, half.y + 1.0), Vector3(2.8, .14, 2.2), stone)
	for step in 3:
		Kit.box_at(root, Vector3(4.65, .12 + step * .19, half.y + 1.48 + step * .29),
			Vector3(1.65, .18, .58), stone)
	Kit.box_at(root, Vector3(0, 3.0, half.y + .056), Vector3(.045, 5.8, .028), trim)


static func build_front_walk(root: Node3D, body: StaticBody3D, stone: Material) -> void:
	for i in 9:
		var pos := Vector3(4.65, .02, 5.9 + i * .78)
		Kit.box_at(root, pos, Vector3(1.65, .08, .68), stone)
		Kit.collider(body, pos + Vector3(0, -.04, 0), Vector3(1.65, .08, .68))


static func build_driveway(root: Node3D, body: StaticBody3D, gravel: Material) -> void:
	# A side drive follows Mario's side of the duplex to the woodworking garage.
	Kit.box_at(root, Vector3(18.3, .035, -12.0), Vector3(3.8, .07, 53.0), gravel)
	Kit.collider(body, Vector3(18.3, -.012, -12.0), Vector3(3.8, .05, 53.0))


static func build_yard(root: Node3D, body: StaticBody3D, fence: Material, firebrick: Material, stone: Material) -> void:
	# Fence lines define only Mario's backyard. The rear opening aligns with the storage shed.
	for z in range(-8, -54, -2):
		Kit.box_at(root, Vector3(.08, 1.05, z), Vector3(.12, 2.1, 1.8), fence)
		Kit.box_at(root, Vector3(23.92, 1.05, z), Vector3(.12, 2.1, 1.8), fence)
	for x in range(0, 25, 2):
		if x < 8.5 or x > 12.5:
			Kit.box_at(root, Vector3(x, 1.05, -54.9), Vector3(1.8, 2.1, .12), fence)
	# The fire pit sits near the center of Mario's rear yard, between house and outbuildings.
	var pit := Vector3(12.5, .05, -25.0)
	for side in range(4):
		var block := Kit.box_at(root, pit + Vector3((side % 2) * .90 - .45, .22, (side / 2) * .90 - .45), Vector3(.96, .42, .18), firebrick)
		block.rotation.y = PI * .5 * (side % 2)
	for i in 3:
		Kit.box_at(root, Vector3(12.5, .16 + i * .12, -28.0), Vector3(2.0, .19, .40), stone)
	# A covered lumber rack keeps the workshop materials in the backyard, by the garage side.
	for z in [-32.0, -36.0]:
		Kit.box_at(root, Vector3(17.3, 1.25, z), Vector3(.13, 2.5, .13), fence)
	Kit.box_at(root, Vector3(17.3, 2.55, -34.0), Vector3(2.8, .16, 4.3), fence)
	for i in 4:
		Kit.box_at(root, Vector3(16.4, .72, -35.3 + i * .42), Vector3(1.4, .10, .35), fence)


static func build_garage(root: Node3D, body: StaticBody3D, at: Vector2, wall: Material,
		blue: Material, roof: Material, glass: Material) -> void:
	var size := Vector2(8.4, 10.0)
	var center := Vector3(at.x, 0, at.y)
	var height := 4.8
	Kit.box_at(root, center + Vector3(0, .02, 0), Vector3(size.x + .24, .04, size.y + .24), Kit.paint(Color("#888c8d"), .94))
	Kit.collider(body, center + Vector3(0, .02, 0), Vector3(size.x + .24, .04, size.y + .24))
	# Side and rear walls leave a wide, walkable opening toward the backyard.
	for side in [-1.0, 1.0]:
		var x: float = side * size.x * .5
		Kit.box_at(root, center + Vector3(x, height * .5 + .22, 0), Vector3(.18, height, size.y), wall)
		Kit.collider(body, center + Vector3(x, height * .5 + .22, 0), Vector3(.18, height, size.y))
	Kit.box_at(root, center + Vector3(0, height * .5 + .22, -size.y * .5), Vector3(size.x, height, .18), wall)
	Kit.collider(body, center + Vector3(0, height * .5 + .22, -size.y * .5), Vector3(size.x, height, .18))
	# Blue doors stand open at the jambs; the wide center remains a real entrance.
	for side in [-1.0, 1.0]:
		var panel := Kit.box_at(root, center + Vector3(side * 3.35, 1.52, size.y * .5 + .12), Vector3(1.3, 2.85, .12), blue)
		panel.rotation.y = side * .72
	for side in [-1.0, 1.0]:
		var plane := Kit.box_at(root, center + Vector3(side * 2.55, height + .22, 0), Vector3(4.9, .20, size.y + .55), roof)
		plane.rotation.z = -side * .23
	Kit.box_at(root, center + Vector3(0, height + .49, 0), Vector3(.18, .20, size.y + .65), roof)
	# Woodworking bench, saw table, drill press and tool racks are inside the garage.
	Kit.box_at(root, center + Vector3(-2.45, .91, -1.7), Vector3(3.8, .18, 1.05), Kit.paint(Color("#75533a"), .9))
	Kit.box_at(root, center + Vector3(-2.45, .46, -1.7), Vector3(.13, .88, .82), Kit.paint(Color("#48504c"), .8))
	Kit.box_at(root, center + Vector3(2.35, .78, -1.7), Vector3(1.25, 1.52, .94), Kit.paint(Color("#48545a"), .8))
	Kit.box_at(root, center + Vector3(3.1, 1.03, 1.0), Vector3(.5, 2.05, .6), Kit.paint(Color("#536269"), .8))
	for i in 4:
		Kit.box_at(root, center + Vector3(-3.3 + i * .40, .85, -4.84), Vector3(.30, 1.5, .12), glass)


static func build_shed(root: Node3D, body: StaticBody3D, at: Vector2, wall: Material, roof: Material) -> void:
	var size := Vector2(8.2, 12.0)
	var center := Vector3(at.x, 0, at.y)
	var height := 4.35
	Kit.box_at(root, center + Vector3(0, .02, 0), Vector3(size.x + .24, .04, size.y + .24), Kit.paint(Color("#8c8171"), .94))
	Kit.collider(body, center + Vector3(0, .02, 0), Vector3(size.x + .24, .04, size.y + .24))
	for side in [-1.0, 1.0]:
		var x: float = side * size.x * .5
		Kit.box_at(root, center + Vector3(x, height * .5 + .22, 0), Vector3(.16, height, size.y), wall)
		Kit.collider(body, center + Vector3(x, height * .5 + .22, 0), Vector3(.16, height, size.y))
	# Both ends stay open: enter from the rear street and walk through to the backyard.
	for z_sign in [-1.0, 1.0]:
		var z: float = z_sign * size.y * .5
		for side in [-1.0, 1.0]:
			var x: float = side * (size.x * .5 - .55)
			Kit.box_at(root, center + Vector3(x, height * .5 + .22, z), Vector3(1.1, height, .16), wall)
			Kit.collider(body, center + Vector3(x, height * .5 + .22, z), Vector3(1.1, height, .16))
		Kit.box_at(root, center + Vector3(0, height - .18, z), Vector3(size.x, .36, .16), wall)
		# Wide sliding door leaves are visibly parked open beside the passage.
		for side in [-1.0, 1.0]:
			var door := Kit.box_at(root, center + Vector3(side * 3.15, 1.75, z + z_sign * .12), Vector3(1.25, 3.25, .10), roof)
			door.rotation.y = z_sign * side * .18
	# Metal gable roof, with the ridge running from the street side through the shed.
	Kit.box_at(root, center + Vector3(0, 4.95, 0), Vector3(.20, .20, size.y + .65), roof)
	for side in [-1.0, 1.0]:
		var plane := Kit.box_at(root, center + Vector3(side * 2.12, 4.70, 0), Vector3(4.45, .18, size.y + .60), roof)
		plane.rotation.z = -side * .24
	# Boat hulls, motors, timber and equipment are stacked in side bays, leaving a walk-through lane.
	var storage := Kit.paint(Color("#506d79"), .52, .28)
	Kit.box_at(root, center + Vector3(-2.55, 1.08, 0), Vector3(1.45, .62, 7.4), storage)
	Kit.box_at(root, center + Vector3(2.65, .72, -.2), Vector3(1.25, .32, 5.4), Kit.paint(Color("#926b47"), .9))
	for i in 4:
		Kit.box_at(root, center + Vector3(2.65, 1.18 + i * .22, -3.5), Vector3(1.35, .09, 2.4), wall)
	for i in 3:
		Kit.box_at(root, center + Vector3(-2.65, .35 + i * .42, -3.2), Vector3(1.3, .12, 1.35), storage)
