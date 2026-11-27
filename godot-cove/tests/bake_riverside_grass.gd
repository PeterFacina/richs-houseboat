extends SceneTree

# Developer-only bake of the marina, tennis approach, and measured road course.
# The versioned bundle ships exact geographic results; other areas use the same
# bounded on-demand cache and streaming path.
const MAX_BUNDLE_BYTES := 64 * 1024 * 1024


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.world_grass == null:
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var grass = game.river.world_grass
	var original_budget: int = grass.build_budget_usec
	grass.build_budget_usec = 100000
	var surface = game.river.world_grass_surface
	var road := road_course(surface, Vector2(17620, 13138))
	if road.is_empty():
		push_error("Could not locate the measured road course")
		quit(1)
		return
	var viewpoints := [
		["spawn", Vector2(game.eye.global_position.x, game.eye.global_position.z)],
		["tennis_approach", Vector2(18025, 12740)],
		["tennis_lawn", Vector2(17940, 12775)],
	]
	for distance in [0.0, 25.0, 50.0, 75.0, 100.0]:
		viewpoints.append(["road_%d" % int(distance), road.start + road.direction * distance])
	var last_pose := Vector3.ZERO
	for view: Array in viewpoints:
		var at: Vector2 = view[1]
		last_pose = Vector3(at.x, game.river.ground_height(at.x, at.y) + 2.0, at.y)
		var started := Time.get_ticks_msec()
		for frame in 2400:
			grass.update_around(last_pose, 0)
			if grass.ready_all():
				break
			await process_frame
			if Time.get_ticks_msec() - started > 120000:
				break
		print("GRASS_BAKE_REGION ", view[0], " ready=", grass.ready_all(),
			" elapsed_ms=", Time.get_ticks_msec() - started,
			" active=", grass.active.size(), " waiting=", grass.waiting.size())
	for frame in 600:
		grass.update_around(last_pose, 0)
		if grass.pending_saves.is_empty() and grass.disk_cache.idle():
			break
		await process_frame
	grass.build_budget_usec = original_budget
	var source_dir: String = grass.disk_cache.directory
	var bundle_dir: String = grass.disk_cache.bundled_directory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bundle_dir))
	var copied := 0
	var bytes := 0
	for name: String in DirAccess.get_files_at(source_dir):
		if not name.ends_with(".gzc"):
			continue
		var source := source_dir.path_join(name)
		var size := FileAccess.get_size(source)
		if size < 0 or bytes + size > MAX_BUNDLE_BYTES:
			continue
		var data := FileAccess.get_file_as_bytes(source)
		var dest := FileAccess.open(bundle_dir.path_join(name), FileAccess.WRITE)
		if dest == null:
			push_error("Could not write bundled grass cache")
			quit(1)
			return
		dest.store_buffer(data)
		dest.close()
		copied += 1
		bytes += data.size()
	print("GRASS_BAKE_BUNDLE version=", bundle_dir.get_file(), " files=", copied,
		" bytes=", bytes, " source=", source_dir)
	quit()


func road_course(surface, near: Vector2) -> Dictionary:
	var best := INF
	var selected := {}
	for span in surface.roads.get(Vector2i((near / 32.0).floor()), []):
		var closest := Geometry2D.get_closest_point_to_segment(near, span.start, span.end)
		var reach := maxf(closest.distance_to(span.start), closest.distance_to(span.end))
		var distance := near.distance_to(closest)
		if reach < 76.0 or distance >= best:
			continue
		best = distance
		var toward: Vector2 = span.end if closest.distance_to(span.end) > closest.distance_to(span.start) else span.start
		selected = {"start": closest, "direction": (toward - closest).normalized()}
	return selected
