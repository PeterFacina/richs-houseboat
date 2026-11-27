extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game = load("res://game_world.tscn").instantiate()
	game.show_loading_screen = true
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.world_grass == null \
			or is_instance_valid(game.loading_layer):
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var grass = game.river.world_grass
	var mode := "compact" if OS.get_cmdline_user_args().has("--grass-compact-control") else "ready"
	verify_raw_surface(game, grass, mode)
	verify_mowing(game, mode)
	var frame_ms: Array[float] = []
	var update_ms: Array[float] = []
	var previous := Time.get_ticks_usec()
	for sample in 600:
		var began := Time.get_ticks_usec()
		game.river.update_grass(game.eye.global_position, game.graphics.level)
		update_ms.append(float(Time.get_ticks_usec() - began) / 1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - previous) / 1000.0)
		previous = now
	frame_ms.sort()
	update_ms.sort()
	print("MARINA_GRASS_STEADY mode=", mode, " frame_median_ms=", frame_ms[300],
		" frame_p95_ms=", frame_ms[570], " fps_median=", 1000.0 / maxf(frame_ms[300], .001),
		" update_median_ms=", update_ms[300], " update_p95_ms=", update_ms[570],
		" active=", grass.active.size(), " desired=", grass.desired.size(),
		" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	quit()


func verify_raw_surface(game, grass, mode: String) -> void:
	var checked := 0
	var excluded := 0
	for item: Dictionary in grass.active.values():
		if item.batch == null:
			continue
		var buffer: PackedFloat32Array = item.batch.multimesh.buffer
		for at in range(0, buffer.size(), 12):
			checked += 1
			var point := Vector2(buffer[at + 3], buffer[at + 11])
			excluded += int(not is_finite(grass.surface.grass_height(point, grass.surface.masks)))
	print("MARINA_GRASS_SURFACE mode=", mode, " valid=", checked - excluded,
		" checked=", checked, " excluded=", excluded)


func verify_mowing(game, mode: String) -> void:
	var mowing_ok := false
	if not game.river.waterfront.riverside_tufts.is_empty():
		var tuft_index: int = game.river.waterfront.riverside_tufts.keys()[0]
		var tuft: Array = game.river.waterfront.riverside_tufts[tuft_index]
		var batch := tuft[0] as MultiMeshInstance3D
		var original: Transform3D = batch.multimesh.get_instance_transform(tuft[1])
		game.mower.grass_trimmed.emit(tuft_index)
		var cut: Transform3D = batch.multimesh.get_instance_transform(tuft[1])
		game.mower.grass_cut[tuft_index] = 1
		game.mower.regrow_grass([tuft_index])
		var grown: Transform3D = batch.multimesh.get_instance_transform(tuft[1])
		mowing_ok = cut.basis.y.length() < original.basis.y.length() * .3 \
			and grown.basis.y.is_equal_approx(original.basis.y)
	print("MARINA_GRASS_MOWING mode=", mode, " cut_and_regrow=", mowing_ok)
