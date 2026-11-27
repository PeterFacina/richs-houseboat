extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://game_world.tscn").instantiate()
	game.show_loading_screen = true
	var started := Time.get_ticks_msec()
	root.add_child(game)
	for frame in 18000:
		await process_frame
		if game.river != null and game.river.world_grass != null and \
				game.loading_layer != null and not is_instance_valid(game.loading_layer):
			break
		if game.river != null and game.river.world_grass != null and \
				is_instance_valid(game.loading_layer) and not game.loading_layer.visible:
			break
	if game.river != null and game.river.world_grass != null:
		var grass = game.river.world_grass
		print("STARTUP_GRASS wall_ms=", Time.get_ticks_msec() - started,
			" ready_all=", grass.ready_all(), " ready_near=", grass.ready_near(),
			" active=", grass.active.size(), " target=", grass.desired.size(),
			" preset=", game.graphics.description())
		await sample_steady(game, "saved_preset")
		game.pause_menu.set_fullscreen(false, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		game.graphics.level = 0
		game.graphics.apply(game.river, game.eye)
		grass.build_budget_usec = 20000
		for frame in 1800:
			game.river.update_grass(game.eye.global_position, game.graphics.level)
			await process_frame
			if grass.ready_all():
				break
		grass.build_budget_usec = grass.BUILD_BUDGET_USEC
		await sample_steady(game, "performance_720")
	quit()


func sample_steady(game: Node3D, label: String) -> void:
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 300:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	samples.sort()
	print("STARTUP_STEADY label=", label, " median_ms=", samples[150],
		" p95_ms=", samples[285], " window=", DisplayServer.window_get_size(),
		" preset=", game.graphics.description(), " chunks=", game.river.world_grass.active.size(),
		" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
