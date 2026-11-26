extends SceneTree

const Cycle = preload("res://river_day_cycle.gd")

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
	game.graphics.level = 0 if OS.get_cmdline_user_args().has("--preset=performance") else (2 if OS.get_cmdline_user_args().has("--preset=scenic") else 1)
	game.graphics.apply(game.river, game.eye)
	print("RENDER_PROFILE opt_in=", game.river.riverside_enabled, " preset=", game.graphics.description())
	var pavilion: Array = game.river.meta.marina.pavilion
	var x := float(pavilion[0])
	var z := float(pavilion[1])
	var views := [
		["public_wharf", Vector3(x + 83.0, 2.2, z + 15.0), Vector3(x + 17.0, 1.5, z + 125.0), Cycle.MIDDAY],
		["marina_park", Vector3(x + 9.0, 2.1, z + 8.0), Vector3(x - 28.0, 2.8, z - 14.0), Cycle.MIDDAY],
		["from_boat", Vector3(x + 46.0, 2.0, z + 91.0), Vector3(x + 19.0, 2.7, z + 2.0), Cycle.MIDDAY],
		["golden_hour", Vector3(x + 83.0, 2.2, z + 15.0), Vector3(x - 45.0, 2.1, z + 140.0), Cycle.GOLDEN_HOUR],
		["night_marina", Vector3(x + 83.0, 2.2, z + 15.0), Vector3(x + 17.0, 1.5, z + 125.0), Cycle.NIGHT],
	]
	for view in views:
		game.river.update_day_cycle(view[3])
		game.eye.global_position = view[1]
		game.eye.look_at(view[2], Vector3.UP)
		game.river.update_water(view[1], 120.0)
		for frame in 8:
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path(output.path_join(view[0] + ".png"))
		print("CAPTURE ", path, " ", image.get_width(), "x", image.get_height(), " ", image.save_png(path))
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
