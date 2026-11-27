extends SceneTree

func _initialize() -> void:
	call_deferred("profile")


func profile() -> void:
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.waterfront.park_grass == null:
		await process_frame
	for frame in 30:
		await process_frame
	game.pause_menu.set_fullscreen(false, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game.graphics.level = 0
	game.graphics.apply(game.river, game.eye)
	paused = false
	game.set_process(true)
	game.set_physics_process(true)
	var grass = game.river.world_grass
	var variant := "riverside" if grass != null else "original"
	print("PROFILE_SETUP variant=", variant, " viewport=", root.get_viewport().get_visible_rect().size,
		" vsync=", DisplayServer.window_get_vsync_mode(), " msaa=", root.get_viewport().msaa_3d,
		" camera_far=", game.eye.far, " shadow_range=", game.river.landscape_light.directional_shadow_max_distance)
	for frame in 120:
		await process_frame
	if OS.get_cmdline_user_args().has("--render-audit"):
		if grass != null:
			grass.surface.ready = false
			grass.hide()
		game.set_process(false)
		game.set_physics_process(false)
		await audit_render_groups(game)
		quit()
		return
	await sample(game, variant + "_live")
	if OS.get_cmdline_user_args().has("--profile-only-live"):
		quit()
		return
	if grass != null:
		grass.surface.ready = false
		for frame in 30:
			await process_frame
		await sample(game, variant + "_grass_static")
		grass.hide()
		for frame in 30:
			await process_frame
		await sample(game, variant + "_grass_off")
	quit()


func audit_render_groups(game: Node3D) -> void:
	await sample(game, "render_base")
	for test in [
		["buildings", ["building_shell", "building_detail"]],
		["trees", ["riverside_leaves", "riverside_tree", "tree_detail", "tree_silhouette",
			"tree_stem", "regional_crown", "regional_trunk"]]
	]:
		var hidden := []
		for kind: String in test[1]:
			for item: Node3D in root.get_tree().get_nodes_in_group("river_graphics_" + kind):
				if game.river.is_ancestor_of(item) and item.visible:
					item.hide()
					hidden.append(item)
		for frame in 30:
			await process_frame
		await sample(game, "render_no_" + test[0])
		for item: Node3D in hidden:
			item.show()
	game.river.near_surface.hide()
	for frame in 30:
		await process_frame
	await sample(game, "render_no_near_water")
	game.river.near_surface.show()
	var shadow_distance: float = game.river.landscape_light.directional_shadow_max_distance
	game.river.landscape_light.directional_shadow_max_distance = 0.0
	for frame in 30:
		await process_frame
	await sample(game, "render_no_directional_shadow")
	game.river.landscape_light.directional_shadow_max_distance = shadow_distance


func sample(game: Node3D, label: String) -> void:
	if game.river.world_grass != null:
		game.river.world_grass.reset_profile()
	var frame_ms: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var primitives: Array[float] = []
	var objects: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 300:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - previous) / 1000.0)
		previous = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	frame_ms.sort()
	process_ms.sort()
	physics_ms.sort()
	draw_calls.sort()
	primitives.sort()
	objects.sort()
	print("PROFILE_RESULT label=", label, " frame_median_ms=", frame_ms[150], " frame_p95_ms=", frame_ms[285],
		" fps_median=", 1000.0 / frame_ms[150], " process_median_ms=", process_ms[150],
		" physics_median_ms=", physics_ms[150], " draws_median=", draw_calls[150],
		" primitives_median=", primitives[150], " objects_median=", objects[150],
		" nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		" active_physics=", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		" vram_mb=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		" grass_chunks=", game.river.world_grass.active.size() if game.river.world_grass != null else 0)
	if game.river.world_grass != null and game.river.world_grass.profile_enabled:
		var grass = game.river.world_grass
		print("PROFILE_GRASS label=", label, " generate_ms=", float(grass.profile_generate_usec) / 1000.0,
			" tile_ms=", float(grass.profile_tile_usec) / 1000.0,
			" upload_ms=", float(grass.profile_upload_usec) / 1000.0,
			" rebuild_ms=", float(grass.profile_rebuild_usec) / 1000.0,
			" completed=", grass.profile_completed, " aborted=", grass.profile_aborted,
			" waiting=", grass.waiting.size())
