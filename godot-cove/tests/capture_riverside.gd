extends SceneTree

const Cycle = preload("res://river_day_cycle.gd")
const Weather = preload("res://river_weather.gd")

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var output := "user://riverside-captures"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var game = load("res://game_world.tscn").instantiate()
	if OS.get_cmdline_user_args().has("--check-only"):
		print("RIVERSIDE_PARSE_OK")
		game.free()
		quit()
		return
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.waterfront.park_grass == null:
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.eye.current = true
	game.hud.hide()
	# The user's saved fullscreen preference overrides Godot's startup resolution.
	if OS.get_cmdline_user_args().has("--capture-resolution=720"):
		game.pause_menu.set_fullscreen(false, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		for frame in 4:
			await process_frame
	elif OS.get_cmdline_user_args().has("--capture-resolution=1080"):
		game.pause_menu.set_fullscreen(false, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		for frame in 4:
			await process_frame
	game.graphics.level = 0 if OS.get_cmdline_user_args().has("--preset=performance") else (2 if OS.get_cmdline_user_args().has("--preset=scenic") else 1)
	game.graphics.apply(game.river, game.eye)
	if OS.get_cmdline_user_args().has("--riverside-grass-prototype") or OS.get_cmdline_user_args().has("--capture-clear-weather"):
		var minute: float = game.campaign.ledger.state.work_minutes
		var weather_state: Dictionary = game.campaign.ledger.state.weather
		var clear: Vector4 = Weather.CONDITIONS[Weather.CLEAR]
		weather_state.merge({"kind": Weather.CLEAR, "from": [clear.x, clear.y, clear.z, clear.w],
			"start": minute, "end": minute, "advance": minute + 1000.0,
			"wet": 0.0, "strength": 1.0, "wind": -1.0}, true)
		game.weather_fx.update(game, weather_state, minute, .2)
	print("RENDER_PROFILE opt_in=", game.river.riverside_enabled, " preset=", game.graphics.description())
	if game.river.world_grass != null:
		verify_world_surfaces(game)
	var pavilion: Array = game.river.meta.marina.pavilion
	var x := float(pavilion[0])
	var z := float(pavilion[1])
	var meadow_y: float = game.river.ground_height(x - 42.0, z + 12.0)
	var ridge_y: float = game.river.ground_height(x - 122.0, z + 88.0)
	var views := [
		["public_wharf", Vector3(x + 83.0, 2.2, z + 15.0), Vector3(x + 17.0, 1.5, z + 125.0), Cycle.MIDDAY],
		["marina_park", Vector3(x + 9.0, 2.1, z + 8.0), Vector3(x - 28.0, 2.8, z - 14.0), Cycle.MIDDAY],
		["wide_meadow", Vector3(x - 42.0, meadow_y + 2.2, z + 12.0), Vector3(x - 112.0,
			game.river.ground_height(x - 112.0, z + 78.0) + 1.4, z + 78.0), Cycle.MIDDAY],
		["grass_patch_close", Vector3(x - 42.0, meadow_y + 1.65, z + 12.0),
			Vector3(x - 53.0, game.river.ground_height(x - 53.0, z + 23.0) + .6, z + 23.0), Cycle.MIDDAY],
		["grass_patch_overview", Vector3(x - 58.0, game.river.ground_height(x - 58.0, z + 5.0) + 5.0, z + 5.0),
			Vector3(x - 42.0, meadow_y, z + 12.0), Cycle.MIDDAY],
		["inland_ridge", Vector3(x - 122.0, ridge_y + 2.2, z + 88.0), Vector3(x - 24.0,
			game.river.ground_height(x - 24.0, z + 34.0) + 1.4, z + 34.0), Cycle.MIDDAY],
		["elevated_marina", Vector3(x + 15.0, 34.0, z - 70.0), Vector3(x - 65.0, 2.0, z + 2.0), Cycle.MIDDAY],
		["from_boat", Vector3(x + 46.0, 2.0, z + 91.0), Vector3(x + 19.0, 2.7, z + 2.0), Cycle.MIDDAY],
		["golden_hour", Vector3(x + 83.0, 2.2, z + 15.0), Vector3(x - 45.0, 2.1, z + 140.0), Cycle.GOLDEN_HOUR],
		["night_marina", Vector3(x + 83.0, 2.2, z + 15.0), Vector3(x + 17.0, 1.5, z + 125.0), Cycle.NIGHT],
	]
	if game.river.world_grass != null:
		views.append(land_view(game, "residential", Vector2(18515, 13829), Vector2(18508, 13836)))
		views.append(land_view(game, "downtown", Vector2(17957, 13320), Vector2(17991, 13330)))
		views.append(land_view(game, "roadside", Vector2(17620, 13138), Vector2(17620, 13126)))
		views.append(land_view(game, "lamure_beach", Vector2(18700, 13190), Vector2(18680, 13210)))
		views.append(land_view(game, "riverbank", Vector2(18240, 13170), Vector2(18227, 13155)))
		var forest: Array = game.river.meta.brockhouse.walkways[1]
		views.append(land_view(game, "forest_trail", Vector2(forest[4][0], forest[4][1]),
			Vector2(forest[7][0], forest[7][1])))
		var routes: Array[Dictionary] = game.river.world_grass_surface.driveways.accepted
		if not routes.is_empty():
			var drive: Dictionary = routes[0]
			for route: Dictionary in routes:
				if route.entry.distance_to(route.end) > 12.0 and route.style.r > .6:
					drive = route
					break
			var approach: Vector2 = (drive.end - drive.entry).normalized()
			views.append(land_view(game, "gravel_driveway", drive.entry - approach * 4.0, drive.end))
	var selected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--view="):
			selected = argument.trim_prefix("--view=")
	for view in views:
		if selected != "" and not selected.split(",").has(view[0]):
			continue
		game.river.update_day_cycle(view[3])
		game.eye.global_position = view[1]
		game.eye.look_at(view[2], Vector3.UP)
		game.river.update_water(view[1], 120.0)
		if game.river.world_grass != null:
			game.river.world_grass.build_budget_usec = 20000
			var first_near := -1
			for frame in 3600:
				game.river.update_grass(view[1], game.graphics.level)
				await process_frame
				if first_near == -1 and game.river.world_grass.ready_near():
					first_near = frame + 1
				if game.river.world_grass.ready_all():
					break
				if frame > 0 and frame % 600 == 0:
					print("WORLD_GRASS_LOADING ", view[0], " frame=", frame,
						" active=", game.river.world_grass.active.size(),
						" target=", game.river.world_grass.desired.size())
			game.river.world_grass.build_budget_usec = game.river.world_grass.BUILD_BUDGET_USEC
			print("WORLD_GRASS_CAPTURE ", view[0], " chunks=", game.river.world_grass.active.size(),
				" near_ready=", game.river.world_grass.ready_near(),
				" all_ready=", game.river.world_grass.ready_all(),
				" first_near_frame=", first_near)
			verify_instanced_grass(game, view[0])
		for frame in 8:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path(output.path_join(view[0] + ".png"))
		print("CAPTURE ", path, " ", image.get_width(), "x", image.get_height(), " ", image.save_png(path))
		if OS.get_cmdline_user_args().has("--stream-benchmark") and game.river.world_grass != null:
			await benchmark_streaming(game, view, output)
		if OS.get_cmdline_user_args().has("--benchmark"):
			var frames: Array[float] = []
			for sample in 300:
				var started := Time.get_ticks_usec()
				await process_frame
				frames.append(float(Time.get_ticks_usec() - started) / 1000.0)
			frames.sort()
			print("FRAME_TIME ", view[0], " median_ms=", frames[150], " p95_ms=", frames[285],
				" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if game.river.riverside_enabled:
		var grass_count: int = game.river.waterfront.grass_transforms.size()
		print("CHECK mowing index count ", grass_count == game.mower.grass.multimesh.instance_count)
		var tuft_index: int = game.river.waterfront.riverside_tufts.keys()[0]
		var tuft: Array = game.river.waterfront.riverside_tufts[tuft_index]
		var batch := tuft[0] as MultiMeshInstance3D
		var original: Transform3D = batch.multimesh.get_instance_transform(tuft[1])
		game.mower.grass_trimmed.emit(tuft_index)
		var cut: Transform3D = batch.multimesh.get_instance_transform(tuft[1])
		print("CHECK mowing cover cut ", cut.basis.y.length() < original.basis.y.length() * .3)
		game.mower.grass_cut[tuft_index] = 1
		game.mower.regrow_grass([tuft_index])
		var grown: Transform3D = batch.multimesh.get_instance_transform(tuft[1])
		print("CHECK mowing cover regrow ", grown.basis.y.is_equal_approx(original.basis.y))
		game.river.update_water(Vector3(x + 450.0, 2.0, z + 450.0), 160.0)
		print("CHECK profile outside marina ", not game.river.riverside_near)
	quit()


func land_view(game: Node3D, label: String, at: Vector2, look: Vector2) -> Array:
	return [label, Vector3(at.x, game.river.ground_height(at.x, at.y) + 2.0, at.y),
		Vector3(look.x, game.river.ground_height(look.x, look.y) + 1.0, look.y), Cycle.MIDDAY]


func verify_world_surfaces(game: Node3D) -> void:
	var surface = game.river.world_grass_surface
	var road_checked := 0
	var road_clear := 0
	var seen_roads := {}
	for bucket: Array in surface.roads.values():
		for span in bucket:
			var key := Vector4(span.start.x, span.start.y, span.end.x, span.end.y)
			if seen_roads.has(key):
				continue
			seen_roads[key] = true
			var at: Vector2 = span.start.lerp(span.end, .5)
			road_checked += 1
			road_clear += int(not is_finite(surface.grass_height(at, surface.masks)))
			if road_checked == 64:
				break
		if road_checked == 64:
			break
	var drive_checked := 0
	var drive_clear := 0
	for route: Dictionary in surface.driveways.accepted:
		var at: Vector2 = route.entry.lerp(route.end, .5)
		drive_checked += 1
		drive_clear += int(not is_finite(surface.grass_height(at, surface.masks)))
		if drive_checked == 64:
			break
	print("WORLD_GRASS_SURFACE road_centers=", road_clear, "/", road_checked,
		" driveway_centers=", drive_clear, "/", drive_checked)
	if road_checked == 0 or drive_checked == 0 or road_clear != road_checked or drive_clear != drive_checked:
		push_error("World grass surface placement failed a road or driveway sample")
	for at: Vector2 in [Vector2(18235, 13174), Vector2(18238, 13170), Vector2(18240, 13167)]:
		print("WORLD_GRASS_RIVERBANK_PROBE ", at, " road=", surface.road_or_walk(at),
			" trail=", surface.park.near_trail(at, 2.6),
			" eligible=", is_finite(surface.grass_height(at, surface.masks)))
	for at: Vector2 in [Vector2(17620, 13063), Vector2(17612, 13070), Vector2(17628, 13070),
			Vector2(17620, 13085)]:
		print("WORLD_GRASS_DRIVE_PROBE ", at, " road=", surface.road_or_walk(at),
			" paved=", surface.paved(at, surface.masks), " occupied=", surface.occupied(at),
			" height=", surface.world.ground_height(at.x, at.y),
			" eligible=", is_finite(surface.grass_height(at, surface.masks)))


func verify_instanced_grass(game: Node3D, label: String) -> void:
	var surface = game.river.world_grass_surface
	var checked := 0
	var invalid := 0
	for item: Dictionary in game.river.world_grass.active.values():
		if item.batch == null:
			continue
		var group: MultiMesh = item.batch.multimesh
		var stride := 1 if OS.get_cmdline_user_args().has("--verify-all-grass") else \
			maxi(1, ceili(float(group.instance_count) / 8.0))
		for i in range(0, group.instance_count, stride):
			var origin := group.get_instance_transform(i).origin
			checked += 1
			if not is_finite(surface.grass_height(Vector2(origin.x, origin.z), surface.masks)):
				invalid += 1
	print("WORLD_GRASS_INSTANCE_CHECK ", label, " valid=", checked - invalid, "/", checked)
	if invalid > 0:
		push_error("World grass instances overlap excluded surfaces")


func benchmark_streaming(game: Node3D, view: Array, output: String) -> void:
	var direction := Vector2(view[2].x - view[1].x, view[2].z - view[1].z).normalized()
	var extended := OS.get_cmdline_user_args().has("--phase2-extended")
	for pace in ([2.0, 5.0, 15.0, 25.0, -25.0] if extended else [2.0, 15.0]):
		var speed: float = absf(pace)
		var start := Vector2(view[1].x, view[1].z)
		var course := road_course(game.river.world_grass_surface, start) if speed >= 15.0 and view[0] != "from_boat" else {}
		if not course.is_empty():
			start = course.start
			direction = course.direction
		if view[0] == "from_boat":
			direction = Vector2(1.0, 0.0)
		if pace < 0.0:
			start += direction * speed * 5.0
			direction = -direction
		if speed >= 15.0:
			print("WORLD_GRASS_COURSE ", view[0], " road_span=", not course.is_empty(),
				" start=", start, " direction=", direction)
		var update_ms: Array[float] = []
		var frame_ms: Array[float] = []
		var fast_frames := 0
		var previous := Time.get_ticks_usec()
		for sample in 300:
			var at: Vector2 = start + direction * speed * float(sample) / 60.0
			var pose := Vector3(at.x, game.river.ground_height(at.x, at.y) + 2.0, at.y)
			game.eye.global_position = pose
			game.eye.look_at(pose + Vector3(direction.x * 20.0, -.7, direction.y * 20.0), Vector3.UP)
			var started := Time.get_ticks_usec()
			game.river.update_grass(pose, game.graphics.level)
			fast_frames += int(game.river.world_grass.moving_fast)
			update_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
			await process_frame
			var now := Time.get_ticks_usec()
			frame_ms.append(float(now - previous) / 1000.0)
			previous = now
		update_ms.sort()
		frame_ms.sort()
		var near_total := 0
		var near_missing := 0
		var near_fallback := 0
		for cell: Vector2i in game.river.world_grass.desired:
			if game.river.world_grass.desired[cell] == 0:
				near_total += 1
				if not game.river.world_grass.active.has(cell) or game.river.world_grass.active[cell].lod != 0:
					near_missing += 1
					near_fallback += int(game.river.world_grass.active.has(cell) and
						game.river.world_grass.active[cell].batch != null)
		print("WORLD_GRASS_MOVE ", view[0], " speed_mps=", pace,
			" update_median_ms=", update_ms[150], " update_p95_ms=", update_ms[285],
			" frame_median_ms=", frame_ms[150], " frame_p95_ms=", frame_ms[285],
			" chunks=", game.river.world_grass.active.size(),
			" cached=", game.river.world_grass.cached.size(),
			" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			" vram_mb=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			" near_ready=", game.river.world_grass.ready_near(),
			" near_missing=", near_missing, "/", near_total,
			" near_fallback=", near_fallback,
			" fast_frames=", fast_frames,
			" end_on_road=", game.river.world_grass_surface.road_or_walk(
				Vector2(game.eye.global_position.x, game.eye.global_position.z)),
			" end_ground_eligible=", is_finite(game.river.world_grass_surface.grass_height(
				Vector2(game.eye.global_position.x, game.eye.global_position.z),
				game.river.world_grass_surface.masks)))
		print("WORLD_GRASS_QUEUE ", view[0], " speed_mps=", pace,
			" waiting=", game.river.world_grass.waiting.size(),
			" current=", game.river.world_grass.current.get("cell", Vector2i.ZERO),
			" current_lod=", game.river.world_grass.current.get("lod", -1),
			" current_index=", game.river.world_grass.current.get("index", -1))
		if pace == 15.0 or (extended and pace == 25.0):
			if OS.get_cmdline_user_args().has("--verify-all-grass"):
				verify_instanced_grass(game, view[0] + "_drive_end")
			var suffix := "_highspeed_end.png" if pace == 25.0 else "_drive_end.png"
			var path := ProjectSettings.globalize_path(output.path_join(view[0] + suffix))
			var frame := root.get_viewport().get_texture().get_image()
			print("CAPTURE ", path, " ", frame.get_width(), "x", frame.get_height(), " ", frame.save_png(path))
	if extended:
		var teleported := Vector2(18240.0, 13170.0)
		var first_near := -1
		var started := Time.get_ticks_usec()
		for frame in 120:
			var pose := Vector3(teleported.x, game.river.ground_height(teleported.x, teleported.y) + 2.0,
				teleported.y)
			game.eye.global_position = pose
			game.river.update_grass(pose, game.graphics.level)
			await process_frame
			if first_near == -1 and game.river.world_grass.ready_near():
				first_near = frame + 1
		print("WORLD_GRASS_TELEPORT ", view[0], " near_ready_frame=", first_near,
			" chunks=", game.river.world_grass.active.size(),
			" cached=", game.river.world_grass.cached.size(),
			" wall_ms=", float(Time.get_ticks_usec() - started) / 1000.0)


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
