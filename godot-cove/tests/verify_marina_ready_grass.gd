extends SceneTree

const Cache = preload("res://riverside_grass_cache.gd")


func _initialize() -> void:
	var cache = Cache.new()
	cache.start()
	var checked := 0
	var nonempty := 0
	var mismatches := 0
	for name: String in DirAccess.get_files_at(cache.ready_bundled_directory):
		if not name.ends_with(".gzr"):
			continue
		var parts := name.get_basename().split("_")
		if parts.size() != 3:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var lod := int(parts[2])
		var ready: Dictionary = cache._load_ready(cache.ready_bundled_directory.path_join(name), lod)
		var compact_path := cache._bundled_path(cell, 0)
		var compact: Dictionary = cache._load(compact_path, cell, lod)
		checked += 1
		if ready.is_empty() or compact.is_empty() or ready.buffer != compact.buffer:
			mismatches += 1
		elif not ready.buffer.is_empty():
			nonempty += 1
	cache.stop()
	print("MARINA_READY_VERIFY files=", checked, " nonempty=", nonempty,
		" mismatches=", mismatches)
	quit(1 if mismatches > 0 or checked == 0 else 0)
