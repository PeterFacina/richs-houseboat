extends SceneTree

# Developer-only compact bake. Existing PR coverage is rewritten into the hybrid
# format, then exactly 500 additional eligible cells are selected around streets
# that pass residential lots. One full-detail record supplies every runtime LOD.
const MAX_BUNDLE_BYTES := 64 * 1024 * 1024
const ADDITIONAL_CELLS := 500
const PREVIOUS_CELLS := 571
const BATCH_SIZE := 8
const CHUNK := 8.0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	var startup_frames := 0
	while game.eye == null or game.river == null or game.river.world_grass == null:
		await process_frame
		startup_frames += 1
		if startup_frames % 600 == 0:
			print("GRASS_BAKE_STARTUP frames=", startup_frames, " eye=", game.eye != null,
				" river=", game.river != null, " world_grass=",
				game.river != null and game.river.world_grass != null)
		if startup_frames >= 7200:
			push_error("Grass bake world did not initialize within 7,200 frames")
			quit(1)
			return
	game.set_process(false)
	game.set_physics_process(false)
	var grass = game.river.world_grass
	grass.build_budget_usec = 100000
	var legacy_cells := find_legacy_cells(grass.disk_cache.bundled_directory)
	var bundle_cells := {}
	print("GRASS_BAKE_BASELINE cells=", legacy_cells.size())
	for offset in range(0, legacy_cells.size(), BATCH_SIZE):
		var batch: Array[Vector2i] = []
		for index in range(offset, mini(offset + BATCH_SIZE, legacy_cells.size())):
			batch.append(legacy_cells[index])
		await bake_batch(grass, batch)
		for cell: Vector2i in batch:
			bundle_cells[cell] = true
		if offset % 64 == 0:
			print("GRASS_BAKE_BASELINE_PROGRESS baked=", mini(offset + batch.size(), legacy_cells.size()))

	var candidates := residential_road_cells(legacy_cells)
	var added := maxi(0, legacy_cells.size() - PREVIOUS_CELLS)
	var attempted := 0
	while added < ADDITIONAL_CELLS and attempted < candidates.size():
		var batch: Array[Vector2i] = []
		for index in range(attempted, mini(attempted + BATCH_SIZE, candidates.size())):
			batch.append(candidates[index])
		attempted += batch.size()
		await bake_batch(grass, batch)
		for cell: Vector2i in batch:
			if added >= ADDITIONAL_CELLS:
				break
			var item: Dictionary = grass.active.get(cell, {})
			if not item.is_empty() and item.get("batch") != null \
					and int(item.batch.get_meta("riverside_count", 0)) > 0:
				bundle_cells[cell] = true
				added += 1
		if added % 50 < BATCH_SIZE:
			print("GRASS_BAKE_RESIDENTIAL eligible=", added, "/", ADDITIONAL_CELLS,
				" attempted=", attempted)
	if added != ADDITIONAL_CELLS:
		push_error("Only %d eligible residential-road cells found after %d candidates" % [added, attempted])
		quit(1)
		return

	var no_targets: Array[Vector2i] = []
	grass.set_bake_targets(no_targets)
	for frame in 1800:
		grass.update_around(Vector3.ZERO, 0)
		if grass.pending_saves.is_empty() and grass.disk_cache.idle():
			break
		await process_frame
	if not grass.pending_saves.is_empty() or not grass.disk_cache.idle():
		push_error("Grass cache did not finish writing")
		quit(1)
		return
	var result := copy_bundle(grass.disk_cache.directory, grass.disk_cache.bundled_directory, bundle_cells)
	print("GRASS_BAKE_BUNDLE version=", grass.disk_cache.bundled_directory.get_file(),
		" files=", result.files, " cells=", bundle_cells.size(), " additional=", added,
		" bytes=", result.bytes, " source=", grass.disk_cache.directory)
	quit()


func bake_batch(grass, cells: Array[Vector2i]) -> void:
	grass.set_bake_targets(cells)
	var center := Vector2(cells[0]) * CHUNK + Vector2.ONE * CHUNK * .5
	var pose := Vector3(center.x, 100.0, center.y)
	var started := Time.get_ticks_msec()
	for frame in 3600:
		grass.update_around(pose, 0)
		if grass.ready_all():
			return
		await process_frame
		if Time.get_ticks_msec() - started > 180000:
			break
	push_error("Timed out baking cells %s" % [cells])
	quit(1)


func find_legacy_cells(_current_bundle: String) -> Array[Vector2i]:
	var found := {}
	for folder: String in DirAccess.get_directories_at("res://deep_river/grass_baked"):
		var path := "res://deep_river/grass_baked".path_join(folder)
		for name: String in DirAccess.get_files_at(path):
			if not name.ends_with(".gzc"):
				continue
			var parts := name.get_basename().split("_")
			if parts.size() == 3:
				found[Vector2i(int(parts[0]), int(parts[1]))] = true
	var cells: Array[Vector2i] = []
	for cell: Vector2i in found:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


func residential_road_cells(excluded: Array[Vector2i]) -> Array[Vector2i]:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://deep_river/river.json"))
	var near_houses := {}
	for building: Dictionary in data.buildings:
		add_disk(near_houses, Vector2(building.center[0], building.center[1]), 48.0)
	var cells := {}
	for street: Array in data.streets:
		for index in street.size() - 1:
			var start := Vector2(float(street[index][0]), float(street[index][1]))
			var finish := Vector2(float(street[index + 1][0]), float(street[index + 1][1]))
			var length := start.distance_to(finish)
			for step in ceili(length / CHUNK) + 1:
				var point := start.lerp(finish, minf(1.0, step * CHUNK / maxf(length, 1.0)))
				var corridor := {}
				add_disk(corridor, point, 28.0)
				for cell: Vector2i in corridor:
					if near_houses.has(cell):
						cells[cell] = true
	for cell: Vector2i in excluded:
		cells.erase(cell)
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in cells:
		ordered.append(cell)
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ah := hash(a)
		var bh := hash(b)
		return ah < bh or (ah == bh and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	print("GRASS_BAKE_CANDIDATES residential_road=", ordered.size())
	return ordered


func add_disk(cells: Dictionary, point: Vector2, radius: float) -> void:
	var low := Vector2i(floori((point.x - radius) / CHUNK), floori((point.y - radius) / CHUNK))
	var high := Vector2i(floori((point.x + radius) / CHUNK), floori((point.y + radius) / CHUNK))
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, z)
			var middle := Vector2(cell) * CHUNK + Vector2.ONE * CHUNK * .5
			if middle.distance_to(point) <= radius:
				cells[cell] = true


func copy_bundle(source_dir: String, bundle_dir: String, cells: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bundle_dir))
	var copied := 0
	var bytes := 0
	for cell: Vector2i in cells:
		var name := "%d_%d_0.gzc" % [cell.x, cell.y]
		var source := source_dir.path_join(name)
		var target := bundle_dir.path_join(name)
		if not FileAccess.file_exists(source) and not FileAccess.file_exists(target):
			push_error("Missing compact grass record " + source)
			quit(1)
			return {}
		var data := FileAccess.get_file_as_bytes(source if FileAccess.file_exists(source) else target)
		if bytes + data.size() > MAX_BUNDLE_BYTES:
			push_error("Compact grass bundle exceeded byte budget")
			quit(1)
			return {}
		if FileAccess.file_exists(source):
			var dest := FileAccess.open(target, FileAccess.WRITE)
			if dest == null:
				push_error("Could not write bundled grass cache")
				quit(1)
				return {}
			dest.store_buffer(data)
			dest.close()
		copied += 1
		bytes += data.size()
	for name: String in DirAccess.get_files_at(bundle_dir):
		if not name.ends_with(".gzc"):
			continue
		var parts := name.get_basename().split("_")
		if parts.size() != 3 or not cells.has(Vector2i(int(parts[0]), int(parts[1]))):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bundle_dir.path_join(name)))
	return {"files": copied, "bytes": bytes}
