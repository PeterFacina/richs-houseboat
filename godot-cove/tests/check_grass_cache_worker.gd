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
	var count := ceili(float(GrassCache.GRID) / float(GrassCache.LOD_STEPS[1]))
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	heights.fill(-INF)
	heights[0] = 3.25
	var buffer := PackedFloat32Array([1.0, 0.0, 0.0, -10000.0,
		0.0, 1.0, 0.0, 3.25, 0.0, 0.0, 1.0, -10000.0])
	var path: String = cache._path(cell, 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not cache.request_save(cell, 1, heights, buffer):
		push_error("Grass cache worker rejected the save")
		cache.stop()
		quit(1)
		return
	for frame in 600:
		if FileAccess.file_exists(path):
			break
		await process_frame
	if not FileAccess.file_exists(path) or not cache.request_load(cell, 1):
		push_error("Grass cache worker did not write or enqueue the record")
		cache.stop()
		quit(1)
		return
	var result := {}
	for frame in 600:
		result = cache.poll()
		if not result.is_empty():
			break
		await process_frame
	var passed: bool = result.get("valid", false) and result.get("buffer", PackedFloat32Array()) == buffer
	print("GRASS_CACHE_ROUNDTRIP passed=", passed, " bytes=", FileAccess.get_size(path))
	cache.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not passed:
		push_error("Grass cache changed the exact transform buffer")
	quit(0 if passed else 1)
