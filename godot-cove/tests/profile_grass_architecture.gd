extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://game_world.tscn").instantiate()
	var prewarm := OS.get_cmdline_user_args().has("--prewarm")
	game.show_loading_screen = prewarm
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.waterfront.park_grass == null \
			or (prewarm and is_instance_valid(game.loading_layer)):
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.eye.current = true
	game.hud.hide()
	game.pause_menu.set_fullscreen(false, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game.graphics.level = 0
	game.graphics.apply(game.river, game.eye)
	var grass = game.river.world_grass
	var surface = game.river.world_grass_surface
	var court: Array = game.river.meta.marina.tennis
	var center := Vector2.ZERO
	for corner: Array in court:
		center += Vector2(corner[0], corner[1]) / float(court.size())
	var target := Vector2.ZERO
	for candidate: Vector2 in [Vector2(17940, 12775), Vector2(17935, 12780),
			Vector2(17905, 12780), Vector2(17875, 12780), Vector2(17815, 12745),
			Vector2(17875, 12700)]:
		var eligible: bool = is_finite(surface.grass_height(candidate, surface.masks))
		print("TENNIS_LAWN_PROBE ", candidate, " eligible=", eligible)
		if eligible and target == Vector2.ZERO:
			target = candidate
	if target == Vector2.ZERO:
		push_error("No verified grass lawn found beside the tennis court")
		quit()
		return
	print("TENNIS_SURFACE center=", center, " center_eligible=",
		is_finite(surface.grass_height(center, surface.masks)), " lawn=", target,
		" lawn_eligible=", is_finite(surface.grass_height(target, surface.masks)))
	var start := Vector2(18025.0, 12740.0)
	var initial_started := Time.get_ticks_msec()
	var initial_near_ms := -1
	for frame in 600:
		var initial_pose := Vector3(start.x, game.river.ground_height(start.x, start.y) + 2.0, start.y)
		game.eye.global_position = initial_pose
		grass.update_around(initial_pose, game.graphics.level)
		await process_frame
		if initial_near_ms < 0 and grass.ready_near():
			initial_near_ms = Time.get_ticks_msec() - initial_started
	print("ARCH_INITIAL near_ready_ms=", initial_near_ms, " elapsed_ms=",
		Time.get_ticks_msec() - initial_started, " active=", grass.active.size(),
		" waiting=", grass.waiting.size(), " cache_loaded=", grass.profile_cache_loaded,
		" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	grass.reset_profile()
	var output := "user://tennis-stream"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var update_ms: Array[float] = []
	var frame_ms: Array[float] = []
	var previous := Time.get_ticks_usec()
	for sample in 1800:
		var fraction := minf(1.0, float(sample) / 1200.0)
		var at := start.lerp(target, fraction)
		var pose := Vector3(at.x, game.river.ground_height(at.x, at.y) + 2.0, at.y)
		game.eye.global_position = pose
		game.eye.look_at(pose + Vector3(-10.0, -.5, 0.0), Vector3.UP)
		var began := Time.get_ticks_usec()
		grass.update_around(pose, game.graphics.level)
		update_ms.append(float(Time.get_ticks_usec() - began) / 1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - previous) / 1000.0)
		previous = now
		if sample % 240 == 0 or sample == 1199 or sample == 1799:
			var near_total := 0
			var near_full := 0
			var near_fallback := 0
			for cell: Vector2i in grass.desired:
				if grass.desired[cell] != 0:
					continue
				near_total += 1
				if grass.active.has(cell):
					if grass.active[cell].lod == 0:
						near_full += 1
					else:
						near_fallback += 1
			print("TENNIS_STREAM frame=", sample, " at=", at, " near_full=", near_full,
				" near_fallback=", near_fallback, " near_total=", near_total,
				" active=", grass.active.size(), " waiting=", grass.waiting.size(),
				" loading=", grass.loading.size(), " prefetched=", grass.prefetched.size(),
				" current_lod=", grass.current.get("lod", -1))
		if (sample == 1199 or sample == 1799) and DisplayServer.get_name() != "headless":
			var name := "arrival.png" if sample == 1199 else "settled.png"
			var image := root.get_viewport().get_texture().get_image()
			var path := ProjectSettings.globalize_path(output.path_join(name))
			print("TENNIS_CAPTURE ", path, " ", image.save_png(path))
	update_ms.sort()
	frame_ms.sort()
	print("TENNIS_TIMING update_median_ms=", update_ms[900], " update_p95_ms=", update_ms[1710],
		" frame_median_ms=", frame_ms[900], " frame_p95_ms=", frame_ms[1710])
	print("ARCH_GRASS generate_ms=", float(grass.profile_generate_usec) / 1000.0,
		" tile_ms=", float(grass.profile_tile_usec) / 1000.0,
		" rebuild_ms=", float(grass.profile_rebuild_usec) / 1000.0,
		" upload_ms=", float(grass.profile_upload_usec) / 1000.0,
		" completed=", grass.profile_completed, " cache_loaded=", grass.profile_cache_loaded,
		" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	for speed in [5.0, 15.0]:
		await road_run(game, grass, speed)
	quit()


func road_run(game: Node3D, grass, speed: float) -> void:
	var start := Vector2(17620.0, 13138.0)
	var course := road_course(grass.surface, start)
	if course.is_empty():
		push_error("No verified road course")
		return
	var direction: Vector2 = course.direction
	start = course.start
	var update_ms: Array[float] = []
	var frame_ms: Array[float] = []
	var previous := Time.get_ticks_usec()
	var fast_frames := 0
	grass.reset_profile()
	for sample in 300:
		var at: Vector2 = start + direction * speed * float(sample) / 60.0
		var pose := Vector3(at.x, game.river.ground_height(at.x, at.y) + 2.0, at.y)
		game.eye.global_position = pose
		game.eye.look_at(pose + Vector3(direction.x * 20.0, -.7, direction.y * 20.0), Vector3.UP)
		var began := Time.get_ticks_usec()
		grass.update_around(pose, game.graphics.level)
		fast_frames += int(grass.moving_fast)
		update_ms.append(float(Time.get_ticks_usec() - began) / 1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - previous) / 1000.0)
		previous = now
	var near_total := 0
	var near_full := 0
	var near_fallback := 0
	for cell: Vector2i in grass.desired:
		if grass.desired[cell] == 0:
			near_total += 1
			if grass.active.has(cell):
				if grass.active[cell].lod == 0:
					near_full += 1
				else:
					near_fallback += 1
	update_ms.sort()
	frame_ms.sort()
	print("ARCH_ROAD speed=", speed, " near_full=", near_full, " near_fallback=",
		near_fallback, " near_total=", near_total, " active=", grass.active.size(),
		" waiting=", grass.waiting.size(), " loading=", grass.loading.size(),
		" prefetched=", grass.prefetched.size(), " fast_frames=", fast_frames,
		" update_median_ms=", update_ms[150],
		" update_p95_ms=", update_ms[285], " frame_median_ms=", frame_ms[150],
		" frame_p95_ms=", frame_ms[285], " generate_ms=",
		float(grass.profile_generate_usec) / 1000.0, " rebuild_ms=",
		float(grass.profile_rebuild_usec) / 1000.0, " tile_ms=",
		float(grass.profile_tile_usec) / 1000.0, " upload_ms=",
		float(grass.profile_upload_usec) / 1000.0, " cache_loaded=", grass.profile_cache_loaded,
		" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)


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
