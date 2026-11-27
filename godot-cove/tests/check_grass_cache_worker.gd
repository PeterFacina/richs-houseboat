extends SceneTree

const GrassCache = preload("res://riverside_grass_cache.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var cache = GrassCache.new()
	cache.start()
	if not cache.available():
		push_error("Grass cache version could not be established")
		quit(1)
		return
	var cell := Vector2i(-10000, -10000)
	var count := GrassCache.GRID
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	heights.fill(-INF)
	heights[0] = 3.25
	var path: String = cache._path(cell, 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not cache.request_save(cell, 0, heights, PackedFloat32Array()):
		push_error("Grass cache worker rejected the save")
		cache.stop()
		quit(1)
		return
	for frame in 600:
		if FileAccess.file_exists(path) and cache.idle():
			break
		await process_frame
	var passed := FileAccess.file_exists(path)
	var load_times: Array[int] = []
	for lod in GrassCache.LOD_STEPS.size():
		var started := Time.get_ticks_usec()
		passed = cache.request_load(cell, lod) and passed
		var result := {}
		for frame in 600:
			result = cache.poll()
			if not result.is_empty():
				break
			await process_frame
		load_times.append(Time.get_ticks_usec() - started)
		var restored: PackedFloat32Array = result.get("buffer", PackedFloat32Array())
		passed = passed and result.get("valid", false) and restored.size() == 12 \
			and is_equal_approx(restored[7], 3.25)
	print("GRASS_CACHE_HYBRID passed=", passed, " bytes=", FileAccess.get_size(path),
		" load_usec_lod0=", load_times[0], " load_usec_lod1=", load_times[1],
		" load_usec_lod2=", load_times[2])
	cache.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not passed:
		push_error("Compact full-detail record did not reconstruct all LODs")
	quit(0 if passed else 1)
