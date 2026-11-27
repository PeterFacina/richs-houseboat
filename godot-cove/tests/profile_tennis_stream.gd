extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.waterfront.park_grass == null:
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
				" current_lod=", grass.current.get("lod", -1))
		if sample == 1199 or sample == 1799:
			var name := "arrival.png" if sample == 1199 else "settled.png"
			var image := root.get_viewport().get_texture().get_image()
			var path := ProjectSettings.globalize_path(output.path_join(name))
			print("TENNIS_CAPTURE ", path, " ", image.save_png(path))
	update_ms.sort()
	frame_ms.sort()
	print("TENNIS_TIMING update_median_ms=", update_ms[900], " update_p95_ms=", update_ms[1710],
		" frame_median_ms=", frame_ms[900], " frame_p95_ms=", frame_ms[1710])
	quit()
