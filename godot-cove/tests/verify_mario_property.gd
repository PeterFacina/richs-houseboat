extends SceneTree

const DeepRiverMap = preload("res://deep_river_map.gd")
const MarioProperty = preload("res://mario_property.gd")

var failed := false


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, detail: String) -> void:
	if not ok:
		push_error(detail)
		failed = true


func run_checks() -> void:
	var map := DeepRiverMap.new()
	root.add_child(map)
	await map.build()
	var site := map.find_child("MarioProperty16Silvie", true, false) as Node3D
	check(site != null, "16 Silvie property was not built")
	if site == null:
		quit(1)
		return
	check(MarioProperty.replaces("ms-374") and not MarioProperty.replaces("ms-843"),
		"The wrong mapped house was replaced")
	check(site.position.distance_to(Vector3(18345.5865, site.position.y, 13866.1102)) < .05,
		"House center moved off the mapped duplex footprint")
	check(site.has_node("StorageGarageG") and site.has_node("WorkshopS")
		and site.has_node("GreenhouseGH"), "Rear building is missing")
	var garage := site.get_node("StorageGarageG") as Node3D
	var workshop := site.get_node("WorkshopS") as Node3D
	var greenhouse := site.get_node("GreenhouseGH") as Node3D
	check(garage.position.x < workshop.position.x and garage.position.z < greenhouse.position.z,
		"Rear buildings are mirrored or greenhouse is behind the garage")
	check(absf((greenhouse.position.z - 1.9) - (garage.position.z + 4.0)) >= .5
		and absf((greenhouse.position.z - 1.9) - (garage.position.z + 4.0)) <= 1.0,
		"Greenhouse/garage clearance is outside the 0.5–1 m target")
	var road: Array = map.meta.streets[63]
	var drive_end := site.to_global(Vector3(11.1, 0, 24.8))
	var walk_end := site.to_global(Vector3(8.35, 0, 24.8))
	var road_a := Vector2(road[0][0], road[0][1])
	var road_b := Vector2(road[1][0], road[1][1])
	for endpoint in [drive_end, walk_end]:
		var p := Vector2(endpoint.x, endpoint.z)
		check(p.distance_to(Geometry2D.get_closest_point_to_segment(p, road_a, road_b)) < 3.4,
			"Driveway or walkway does not reach Silvie Street")
	await physics_frame
	# A standing-height ray must have a clear route from street to the house,
	# around the covered side porch, across the lawn, and between G and S.
	for segment in [
		[Vector2(11.1, 24.6), Vector2(11.1, 7.5)],
		[Vector2(8.35, 24.6), Vector2(8.35, 8.2)],
		[Vector2(10.1, 5.8), Vector2(10.1, -7.7)],
		[Vector2(10.1, -8.5), Vector2(10.1, -15.0)],
		[Vector2(10.1, -15.0), Vector2(7.7, -28.9)],
		[Vector2(7.7, -28.9), Vector2(7.7, -36.0)],
	]:
		var start: Vector2 = segment[0]
		var end: Vector2 = segment[1]
		var a := site.to_global(Vector3(start.x, 0, start.y))
		var b := site.to_global(Vector3(end.x, 0, end.y))
		a.y = map.ground_height(a.x, a.z) + 1.1
		b.y = map.ground_height(b.x, b.z) + 1.1
		var hit := site.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(a, b))
		check(hit.is_empty(), "Standing-height path blocked: %s to %s by %s" % [start, end, hit.get("collider", "none")])
	print("Mario property geometry and route checks: ", "FAIL" if failed else "PASS")
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture-dir":
		await capture_views(site, args[1])
	quit(1 if failed else 0)


func capture_views(site: Node3D, folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 65.0
	camera.far = 350.0
	camera.current = true
	for view in [
		["aerial", Vector3(8, 74, -11), Vector3(8, 0, -11)],
		["front", Vector3(6, 2.8, 34), Vector3(3, 3, 0)],
		["side", Vector3(13, 2.6, 9), Vector3(9.5, 1.3, -8)],
		["backyard", Vector3(8, 2.5, -12), Vector3(8, 2, -35)],
	]:
		camera.global_position = site.to_global(view[1])
		camera.look_at(site.to_global(view[2]), Vector3.UP)
		await process_frame
		await process_frame
		await process_frame
		var path := folder.path_join("mario-property-%s.png" % view[0])
		check(root.get_texture().get_image().save_png(path) == OK, "Screenshot failed: " + path)
		print("Captured ", path)
