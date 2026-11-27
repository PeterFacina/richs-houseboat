extends SceneTree

# Controlled marina experiment only. Every cell that the maximum grass preset can
# request from the marina spawn is baked at full density, then converted to exact
# ready-to-upload buffers for all three LODs. Empty cells are retained so runtime
# geographic classification is never used inside the experiment footprint.
const CHUNK := 8.0
const MARINA_RADIUS := 115.0 + 8.0 + CHUNK * .71
const BATCH_SIZE := 8


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game = load("res://game_world.tscn").instantiate()
	game.show_loading_screen = false
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.world_grass == null:
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var grass = game.river.world_grass
	grass.build_budget_usec = 100000
	var center := Vector2(game.eye.global_position.x, game.eye.global_position.z)
	var cells := marina_cells(center)
	print("MARINA_READY_BAKE_BEGIN center=", center, " radius=", MARINA_RADIUS,
		" cells=", cells.size(), " version=", grass.disk_cache.BUNDLE_VERSION)
	for offset in range(0, cells.size(), BATCH_SIZE):
		var batch: Array[Vector2i] = []
		for index in range(offset, mini(offset + BATCH_SIZE, cells.size())):
			batch.append(cells[index])
		await bake_batch(grass, batch)
		if offset % 64 == 0:
			print("MARINA_READY_BAKE_PROGRESS prepared=", mini(offset + batch.size(), cells.size()),
				"/", cells.size())
	var none: Array[Vector2i] = []
	grass.set_bake_targets(none)
	while not grass.pending_saves.is_empty() or not grass.disk_cache.idle():
		grass.update_around(Vector3(center.x, 100.0, center.y), 2)
		await process_frame

	var compact_bytes := 0
	var ready_bytes := 0
	var ready_files := 0
	var nonempty := 0
	for cell: Vector2i in cells:
		var compact_name := "%d_%d_0.gzc" % [cell.x, cell.y]
		var user_path: String = grass.disk_cache.directory.path_join(compact_name)
		var bundle_path: String = grass.disk_cache.bundled_directory.path_join(compact_name)
		if FileAccess.file_exists(user_path):
			copy_file(user_path, bundle_path)
		if not FileAccess.file_exists(bundle_path):
			push_error("Missing marina compact record " + compact_name)
			quit(1)
			return
		compact_bytes += FileAccess.get_size(bundle_path)
		for lod in 3:
			var record: Dictionary = grass.disk_cache._load(bundle_path, cell, lod)
			if record.is_empty() or not grass.disk_cache.save_ready(cell, lod, record.buffer):
				push_error("Could not create ready marina record %s lod %d" % [cell, lod])
				quit(1)
				return
			nonempty += int(not record.buffer.is_empty())
			var ready_path: String = grass.disk_cache._ready_path(cell, lod)
			ready_bytes += FileAccess.get_size(ready_path)
			ready_files += 1
	print("MARINA_READY_BAKE_COMPLETE center=", center, " cells=", cells.size(),
		" compact_bytes=", compact_bytes, " ready_files=", ready_files,
		" ready_nonempty=", nonempty, " ready_bytes=", ready_bytes)
	quit()


func marina_cells(center: Vector2) -> Array[Vector2i]:
	var low := Vector2i(floori((center.x - MARINA_RADIUS) / CHUNK),
		floori((center.y - MARINA_RADIUS) / CHUNK))
	var high := Vector2i(floori((center.x + MARINA_RADIUS) / CHUNK),
		floori((center.y + MARINA_RADIUS) / CHUNK))
	var cells: Array[Vector2i] = []
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, z)
			var middle := (Vector2(cell) + Vector2.ONE * .5) * CHUNK
			if center.distance_to(middle) <= MARINA_RADIUS:
				cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := center.distance_squared_to((Vector2(a) + Vector2.ONE * .5) * CHUNK)
		var db := center.distance_squared_to((Vector2(b) + Vector2.ONE * .5) * CHUNK)
		return da < db or (is_equal_approx(da, db) and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	return cells


func bake_batch(grass, cells: Array[Vector2i]) -> void:
	grass.set_bake_targets(cells)
	var center := (Vector2(cells[0]) + Vector2.ONE * .5) * CHUNK
	var pose := Vector3(center.x, 100.0, center.y)
	var started := Time.get_ticks_msec()
	while true:
		grass.update_around(pose, 2)
		if grass.ready_all():
			return
		await process_frame
		if Time.get_ticks_msec() - started > 180000:
			push_error("Timed out baking marina cells %s" % [cells])
			quit(1)
			return


func copy_file(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var data := FileAccess.get_file_as_bytes(source)
	var output := FileAccess.open(target, FileAccess.WRITE)
	if output != null:
		output.store_buffer(data)
		output.close()
