extends RefCounted

# Exact per-candidate eligibility and elevation, before deterministic transforms.
# This worker never reads the world, scene tree, Image, Mesh, or rendering server.
const ROOT := "user://riverside-grass-cache"
const BUNDLED := "res://deep_river/grass_baked"
const MAGIC := 0x47524331
const FORMAT := 2
const GRID := 113
const CHUNK := 8.0
const LOD_STEPS := [1, 2, 4]
const MAX_JOBS := 4
const MAX_DISK_BYTES := 256 * 1024 * 1024
const MAX_FILES := 4096

var directory := ""
var bundled_directory := ""
var thread := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var jobs: Array[Dictionary] = []
var results: Array[Dictionary] = []
var busy := 0
var stopping := false
var writes := 0
var invalid_paths := {}


func start() -> void:
	var source := "grass-cache-%d-%s" % [FORMAT, Engine.get_version_info().string]
	var files := PackedStringArray()
	for name: String in DirAccess.get_files_at("res://"):
		if name.ends_with(".gd") or name.ends_with(".tscn") or name == "project.godot":
			files.append("res://" + name)
	for name: String in DirAccess.get_files_at("res://deep_river"):
		if name.ends_with(".json") or name.ends_with(".bin") or name.ends_with(".png"):
			files.append("res://deep_river/" + name)
	files.sort()
	for path: String in files:
		var digest := FileAccess.get_sha256(path)
		if digest.is_empty():
			return # Do not reuse unverifiable geographic data.
		source += digest
	var version := source.sha256_text().substr(0, 24)
	directory = ROOT.path_join(version)
	bundled_directory = BUNDLED.path_join(version)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	thread.start(Callable(self, "_work"))


func available() -> bool:
	return not directory.is_empty()


func has(cell: Vector2i, lod: int) -> bool:
	return available() and ((FileAccess.file_exists(_path(cell, lod)) and not _is_bad(_path(cell, lod))) \
		or (FileAccess.file_exists(_bundled_path(cell, lod)) and not _is_bad(_bundled_path(cell, lod))))


func request_load(cell: Vector2i, lod: int) -> bool:
	var path := _path(cell, lod)
	if not FileAccess.file_exists(path) or _is_bad(path):
		path = _bundled_path(cell, lod)
	if not FileAccess.file_exists(path) or _is_bad(path):
		return false
	return _enqueue({"kind": "load", "cell": cell, "lod": lod, "path": path})


func request_save(cell: Vector2i, lod: int, heights: PackedFloat32Array,
		buffer: PackedFloat32Array) -> bool:
	return _enqueue({"kind": "save", "cell": cell, "lod": lod, "path": _path(cell, lod),
		"heights": heights, "buffer": buffer})


func cancel_load(cell: Vector2i, lod: int) -> bool:
	mutex.lock()
	for index in jobs.size():
		if jobs[index].kind == "load" and jobs[index].cell == cell and jobs[index].lod == lod:
			jobs.remove_at(index)
			mutex.unlock()
			return true
	mutex.unlock()
	return false


func poll() -> Dictionary:
	mutex.lock()
	var result: Dictionary = results.pop_front() if not results.is_empty() else {}
	mutex.unlock()
	return result


func idle() -> bool:
	mutex.lock()
	var quiet := jobs.is_empty() and busy == 0
	mutex.unlock()
	return quiet


func stop() -> void:
	if not thread.is_started():
		return
	mutex.lock()
	stopping = true
	mutex.unlock()
	wake.post()
	thread.wait_to_finish()


func _path(cell: Vector2i, lod: int) -> String:
	return directory.path_join("%d_%d_%d.gzc" % [cell.x, cell.y, lod])


func _bundled_path(cell: Vector2i, lod: int) -> String:
	return bundled_directory.path_join("%d_%d_%d.gzc" % [cell.x, cell.y, lod])


func _is_bad(path: String) -> bool:
	mutex.lock()
	var bad := invalid_paths.has(path)
	mutex.unlock()
	return bad


func _enqueue(job: Dictionary) -> bool:
	if not available():
		return false
	mutex.lock()
	var accepted := not stopping and jobs.size() + results.size() + busy < MAX_JOBS
	if accepted:
		jobs.append(job)
	mutex.unlock()
	if accepted:
		wake.post()
	return accepted


func _work() -> void:
	_trim_disk()
	while true:
		wake.wait()
		mutex.lock()
		if stopping and jobs.is_empty():
			mutex.unlock()
			return
		if jobs.is_empty():
			mutex.unlock()
			continue
		var job: Dictionary = jobs.pop_front()
		busy = 1
		mutex.unlock()
		var result := {}
		if job.kind == "load":
			var buffer := _load(job.path, job.lod)
			if buffer.is_empty():
				mutex.lock()
				invalid_paths[job.path] = true
				mutex.unlock()
				if job.path.begins_with(ROOT):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(job.path))
			result = {"cell": job.cell, "lod": job.lod,
				"buffer": buffer.get("buffer", PackedFloat32Array()),
				"valid": not buffer.is_empty()}
		else:
			_save(job.path, job.lod, job.heights, job.buffer)
			mutex.lock()
			invalid_paths.erase(job.path)
			mutex.unlock()
			writes += 1
			if writes % 16 == 0:
				_trim_disk()
		mutex.lock()
		busy = 0
		if not result.is_empty():
			results.append(result)
		mutex.unlock()


func _load(path: String, lod: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open_compressed(path, FileAccess.READ)
	if file == null:
		return {}
	var count := ceili(float(GRID) / float(LOD_STEPS[lod]))
	if file.get_32() != MAGIC or file.get_32() != FORMAT or file.get_32() != lod \
			or file.get_32() != count * count:
		return {}
	var buffer_count := file.get_32()
	if buffer_count > count * count * 12 or buffer_count % 12 != 0:
		return {}
	var expected_digest := file.get_buffer(32)
	var heights_bytes := file.get_buffer(count * count * 4)
	var buffer_bytes := file.get_buffer(buffer_count * 4)
	if expected_digest.size() != 32 or heights_bytes.size() != count * count * 4 \
			or buffer_bytes.size() != buffer_count * 4:
		return {}
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(heights_bytes)
	if not buffer_bytes.is_empty():
		digest.update(buffer_bytes)
	if digest.finish() != expected_digest:
		return {}
	return {"buffer": buffer_bytes.to_float32_array()}


func _save(path: String, lod: int, heights: PackedFloat32Array,
		buffer: PackedFloat32Array) -> void:
	var heights_bytes := heights.to_byte_array()
	var buffer_bytes := buffer.to_byte_array()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(heights_bytes)
	if not buffer_bytes.is_empty():
		digest.update(buffer_bytes)
	var temp := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open_compressed(temp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return
	file.store_32(MAGIC)
	file.store_32(FORMAT)
	file.store_32(lod)
	file.store_32(heights.size())
	file.store_32(buffer.size())
	file.store_buffer(digest.finish())
	file.store_buffer(heights_bytes)
	file.store_buffer(buffer_bytes)
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),
			ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))


func _trim_disk() -> void:
	var entries := []
	var total := 0
	for folder: String in DirAccess.get_directories_at(ROOT):
		var path := ROOT.path_join(folder)
		for name: String in DirAccess.get_files_at(path):
			if not name.ends_with(".gzc"):
				continue
			var file := path.path_join(name)
			var size := FileAccess.get_size(file)
			if size < 0:
				continue
			total += size
			entries.append({"path": file, "bytes": size, "time": FileAccess.get_modified_time(file)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	var index := 0
	while (total > MAX_DISK_BYTES or entries.size() - index > MAX_FILES) and index < entries.size():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(entries[index].path))
		total -= entries[index].bytes
		index += 1
