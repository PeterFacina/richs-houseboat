extends Node3D

const Art = preload("res://riverside_art.gd")
const Surface = preload("res://riverside_grass_surface.gd")
const GrassCache = preload("res://riverside_grass_cache.gd")
const Graphics = preload("res://river_graphics.gd")
const CHUNK := 8.0
const TILE := 1.0
const GRID := 113 # 199.5 candidates/m2, matching the approved 200-blade prototype.
const LOD_STEPS := [1, 2, 4] # Nested deterministic subsets: 200, 50, 12.5 blades/m2.
const RADII := [[18.0, 32.0, 52.0], [22.0, 42.0, 69.0], [28.0, 50.0, 115.0]]
const BUILD_BUDGET_USEC := 1500
const FALLBACK_LOD := 1
const CACHE_LIMIT := 64
const LOAD_MARGIN := 8.0
const UNLOAD_MARGIN := 12.0
const AHEAD_RADIUS := 28.0
const MAX_LOOKAHEAD := 48.0
const PREFETCH_LIMIT := 32

var surface
var mesh: Mesh
var material: ShaderMaterial
var active := {}
var cached := {}
var cache_order := []
var tile_cache := {}
var desired := {}
var waiting := []
var current := {}
var view_cell := Vector2i(-999999, -999999)
var quality := -1
var build_budget_usec := BUILD_BUDGET_USEC
var last_view := Vector2.ZERO
var has_view := false
var travel := Vector2.ZERO
var last_tick := 0
var moving_fast := false
var disk_cache
var loading := {}
var prefetched := {}
var prefetch_order := []
var pending_saves: Array[Dictionary] = []
var profile_cache_loaded := 0
var profile_height_cache_hits := 0
var profile_enabled := OS.get_cmdline_user_args().has("--profile-grass")
var profile_generate_usec := 0
var profile_tile_usec := 0
var profile_upload_usec := 0
var profile_activation_usec := 0
var profile_disk_usec := 0
var profile_decompress_usec := 0
var profile_reconstruct_usec := 0
var profile_queue_usec := 0
var profile_result_wait_usec := 0
var profile_queue_max_usec := 0
var profile_result_wait_max_usec := 0
var profile_rebuild_usec := 0
var profile_completed := 0
var profile_aborted := 0
var profile_ready_loaded := 0
var profile_compact_loaded := 0
var profile_bundled_loaded := 0
var bake_targets: Array[Vector2i] = []


func setup(eligibility) -> void:
	surface = eligibility
	disk_cache = GrassCache.new()
	disk_cache.start()
	mesh = Art.godotgrass_blade()
	material = ShaderMaterial.new()
	material.shader = preload("res://riverside_godotgrass.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .0275
	var wind := NoiseTexture2D.new()
	wind.width = 256
	wind.height = 256
	wind.seamless = true
	wind.noise = noise
	material.set_shader_parameter("wind_noise", wind)
	name = "RiversideWorldGrass"


func _exit_tree() -> void:
	if disk_cache != null:
		disk_cache.stop()


func update_around(viewpoint: Vector3, preset: int) -> void:
	if surface == null or not surface.ready:
		return
	while not pending_saves.is_empty() and disk_cache.request_save(pending_saves[0].cell,
			pending_saves[0].lod, pending_saves[0].heights, pending_saves[0].buffer):
		pending_saves.pop_front()
	while true:
		var loaded: Dictionary = disk_cache.poll()
		if loaded.is_empty():
			break
		if profile_enabled:
			profile_disk_usec += int(loaded.get("disk_usec", 0))
			profile_decompress_usec += int(loaded.get("decompress_usec", 0))
			profile_reconstruct_usec += int(loaded.get("reconstruct_usec", 0))
			var queue_usec := int(loaded.get("queue_usec", 0))
			var result_wait_usec := maxi(0, Time.get_ticks_usec() - \
				int(loaded.get("worker_done_usec", Time.get_ticks_usec())))
			profile_queue_usec += queue_usec
			profile_result_wait_usec += result_wait_usec
			profile_queue_max_usec = maxi(profile_queue_max_usec, queue_usec)
			profile_result_wait_max_usec = maxi(profile_result_wait_max_usec, result_wait_usec)
			profile_ready_loaded += int(loaded.get("ready", false))
			profile_compact_loaded += int(not loaded.get("ready", false))
			profile_bundled_loaded += int(loaded.get("bundled", false))
		loading.erase(loaded.cell)
		if loaded.valid and desired.has(loaded.cell) and (not active.has(loaded.cell) \
				or active[loaded.cell].lod > loaded.lod):
			var upload_started := Time.get_ticks_usec() if profile_enabled else 0
			if loaded.lod == 0 and active.has(loaded.cell) \
					and (desired[loaded.cell] > 0 or moving_fast):
				_store_prefetch(loaded.cell, _batch_from_buffer(loaded.cell, 0, loaded.buffer))
			else:
				var interrupted := current
				current = {"cell": loaded.cell, "lod": loaded.lod, "buffer": loaded.buffer}
				start_upload()
				if profile_enabled:
					profile_upload_usec += Time.get_ticks_usec() - upload_started
				var activation_started := Time.get_ticks_usec() if profile_enabled else 0
				install_current()
				if profile_enabled:
					profile_activation_usec += Time.get_ticks_usec() - activation_started
				current = interrupted
			if profile_enabled and loaded.lod == 0 and active.has(loaded.cell) \
					and (desired[loaded.cell] > 0 or moving_fast):
				profile_upload_usec += Time.get_ticks_usec() - upload_started
			profile_cache_loaded += 1
		elif not loaded.valid and desired.has(loaded.cell):
			waiting.push_front({"cell": loaded.cell, "lod": loaded.lod, "distance": 0.0,
				"priority": 0})
	preset = clampi(preset, 0, 2)
	var position := Vector2(viewpoint.x, viewpoint.z)
	var now := Time.get_ticks_usec()
	if has_view:
		var delta := position - last_view
		var seconds := maxf(float(now - last_tick) / 1000000.0, .001)
		var speed := delta.length() / seconds
		var fast := (speed > 7.0 or (moving_fast and speed > 2.0)) and delta.length_squared() < 4.0
		if fast != moving_fast:
			# A partial full-detail chunk can otherwise consume the travel budget while
			# newly approached cells still have no grass. Its tile samples stay cached.
			if fast and current.get("lod", -1) == 0:
				abort_current()
			moving_fast = fast
			view_cell = Vector2i(-999999, -999999)
		var was_travelling := travel.length_squared() > 0.0
		if delta.length_squared() > .0001 and delta.length_squared() < 4.0 and speed > .8:
			travel = delta.normalized() * minf(MAX_LOOKAHEAD, maxf(20.0, speed * 2.0))
		else:
			travel = Vector2.ZERO
		if was_travelling and travel == Vector2.ZERO:
			view_cell = Vector2i(-999999, -999999)
	last_view = position
	last_tick = now
	has_view = true
	var center := Vector2i(floori(viewpoint.x / CHUNK), floori(viewpoint.z / CHUNK))
	if center != view_cell or preset != quality:
		view_cell = center
		quality = preset
		var rebuild_started := Time.get_ticks_usec() if profile_enabled else 0
		rebuild_targets(position)
		if profile_enabled:
			profile_rebuild_usec += Time.get_ticks_usec() - rebuild_started
	var deadline := Time.get_ticks_usec() + maxi(build_budget_usec, 2500 if moving_fast else 0)
	while Time.get_ticks_usec() < deadline:
		if current.is_empty():
			if waiting.is_empty():
				break
			current = waiting.pop_front()
			var next_cell: Vector2i = current.cell
			if disk_cache.has(next_cell, current.lod):
				if disk_cache.request_load(next_cell, current.lod):
					loading[next_cell] = current.lod
					current.clear()
					continue
				waiting.push_front(current)
				current = {}
				break
			current["index"] = 0
			current["written"] = 0
			var block: Vector2i = current.cell
			var count := ceili(float(GRID) / float(LOD_STEPS[current.lod]))
			var buffer := PackedFloat32Array()
			buffer.resize(count * count * 12)
			current["buffer"] = buffer
			var heights := PackedFloat32Array()
			heights.resize(count * count)
			heights.fill(-INF)
			current["heights"] = heights
			if not tile_cache.has(block):
				tile_cache[block] = [{}, {}, {}, [{}, {}]]
			current["tiles"] = tile_cache[block][0 if current.lod == 0 else 1]
			current["edge_cache"] = tile_cache[block][2]
			current["tile_samples"] = tile_cache[block][3]
			current["masks"] = surface.relevant_masks(Rect2(Vector2(block) * CHUNK,
				Vector2.ONE * CHUNK).grow(Surface.CLEARANCE))
		var cell: Vector2i = current.cell
		if not desired.has(cell):
			abort_current()
			continue
		var generate_started := Time.get_ticks_usec() if profile_enabled else 0
		var step: int = LOD_STEPS[current.lod]
		var count := ceili(float(GRID) / float(step))
		var total := count * count
		var candidate_heights: PackedFloat32Array = current.heights
		var transforms: PackedFloat32Array = current.buffer
		var index: int = current.index
		var written: int = current.written
		var tiles: Dictionary = current.tiles
		var edge_cache: Dictionary = current.edge_cache
		var tile_samples: Array = current.tile_samples
		var masks: Array = current.masks
		for task in 24:
			if index >= total:
				break
			var local_x: int = (index % count) * step
			var local_z: int = index / count * step
			var seed := hash(Vector3i(cell.x, cell.y, local_z * GRID + local_x))
			var jitter_x := (float(seed & 1023) / 1023.0 - .5) * CHUNK / GRID * .68
			var jitter_z := (float((seed >> 10) & 1023) / 1023.0 - .5) * CHUNK / GRID * .68
			var point := Vector2((float(cell.x) + (float(local_x) + .5) / GRID) * CHUNK + jitter_x,
				(float(cell.y) + (float(local_z) + .5) / GRID) * CHUNK + jitter_z)
			var tile := Vector2i(floori((float(local_x) + .5) * CHUNK / GRID / TILE),
				floori((float(local_z) + .5) * CHUNK / GRID / TILE))
			if not tiles.has(tile):
				var tile_started := Time.get_ticks_usec() if profile_enabled else 0
				tiles[tile] = classify_tile(cell, tile, masks, current.lod == 0, tile_samples)
				if profile_enabled:
					profile_tile_usec += Time.get_ticks_usec() - tile_started
			var tile_data: Dictionary = tiles[tile]
			if tile_data.state == -1:
				index += 1
				continue
			var height: float
			if tile_data.state == 0:
				var key := local_z * GRID + local_x
				if edge_cache.has(key):
					height = edge_cache[key]
					if profile_enabled:
						profile_height_cache_hits += 1
				else:
					height = surface.grass_height(point, masks)
					edge_cache[key] = height
			else:
				height = tile_height(point, cell, tile, tile_data.heights)
			candidate_heights[index] = height
			if is_finite(height):
				var angle := float((seed >> 20) & 1023) / 1023.0 * TAU
				var sine := sin(angle)
				var cosine := cos(angle)
				var at := written * 12
				transforms[at] = cosine
				transforms[at + 1] = 0.0
				transforms[at + 2] = sine
				transforms[at + 3] = point.x
				transforms[at + 4] = 0.0
				transforms[at + 5] = 1.0
				transforms[at + 6] = 0.0
				transforms[at + 7] = height
				transforms[at + 8] = -sine
				transforms[at + 9] = 0.0
				transforms[at + 10] = cosine
				transforms[at + 11] = point.y
				written += 1
			index += 1
		current["index"] = index
		current["written"] = written
		current["heights"] = candidate_heights
		current["buffer"] = transforms
		if index >= total:
			transforms.resize(written * 12)
			current["buffer"] = transforms
			if disk_cache.available() and not disk_cache.has(cell, current.lod):
				var save := {"cell": cell, "lod": current.lod, "heights": current.heights,
					"buffer": current.buffer}
				if not disk_cache.request_save(cell, current.lod, current.heights, current.buffer):
					pending_saves.append(save)
			var upload_started := Time.get_ticks_usec() if profile_enabled else 0
			start_upload()
			install_current()
			if profile_enabled:
				profile_upload_usec += Time.get_ticks_usec() - upload_started
		if profile_enabled:
			profile_generate_usec += Time.get_ticks_usec() - generate_started
		if Time.get_ticks_usec() >= deadline:
			break


func tile_sample(cell: Vector2i, tile: Vector2i, x: int, z: int, nearby_masks: Array,
		strict: bool, samples: Array) -> float:
	var key := Vector2i(tile.x * 2 + x, tile.y * 2 + z)
	var cache: Dictionary = samples[0 if strict else 1]
	if cache.has(key):
		return cache[key]
	var point := Vector2(cell) * CHUNK + Vector2(tile) * TILE + Vector2(x, z) * TILE * .5
	var height: float = surface.grass_height(point, nearby_masks, .35 if strict else 0.0)
	cache[key] = height
	return height


func classify_tile(cell: Vector2i, tile: Vector2i, nearby_masks: Array, full_detail: bool,
		samples: Array) -> Dictionary:
	var heights := []
	var valid := 0
	if full_detail:
		for z in 3:
			for x in 3:
				var height: float = tile_sample(cell, tile, x, z, nearby_masks, true, samples)
				heights.append(height)
				valid += int(is_finite(height))
		if valid == 9:
			return {"state": 1, "heights": [heights[0], heights[2], heights[6], heights[8]]}
		valid = 0
		for z in 3:
			for x in 3:
				valid += int(is_finite(tile_sample(cell, tile, x, z, nearby_masks, false, samples)))
		if valid == 0:
			return {"state": -1}
		return {"state": 0}
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(2, 0), Vector2i(0, 2),
			Vector2i(2, 2), Vector2i.ONE]:
		var height: float = tile_sample(cell, tile, offset.x, offset.y, nearby_masks, true, samples)
		heights.append(height)
		valid += int(is_finite(height))
	if valid == 0:
		return {"state": -1}
	if valid == 5:
		return {"state": 1, "heights": heights}
	return {"state": 0}


func tile_height(point: Vector2, cell: Vector2i, tile: Vector2i, heights: Array) -> float:
	var within := point - (Vector2(cell) * CHUNK + Vector2(tile) * TILE)
	return lerpf(lerpf(heights[0], heights[1], within.x),
		lerpf(heights[2], heights[3], within.x), within.y)


func rebuild_targets(center: Vector2) -> void:
	surface.slope_cache.clear()
	if not bake_targets.is_empty():
		rebuild_bake_targets()
		return
	var radii: Array = RADII[quality]
	if moving_fast:
		radii = radii.duplicate()
		radii[0] = 12.0
	var load_radius := float(radii[2]) + LOAD_MARGIN
	var unload_radius := load_radius + UNLOAD_MARGIN
	var reach := ceili(unload_radius / CHUNK) + 1
	desired.clear()
	var pending := []
	var upcoming := []
	for z in range(view_cell.y - reach, view_cell.y + reach + 1):
		for x in range(view_cell.x - reach, view_cell.x + reach + 1):
			var cell := Vector2i(x, z)
			var middle := (Vector2(cell) + Vector2.ONE * .5) * CHUNK
			var distance := center.distance_to(middle)
			if distance > load_radius + CHUNK * .7:
				if active.has(cell) and distance <= unload_radius + CHUNK * .7:
					desired[cell] = active[cell].lod
				continue
			var lod := 0 if distance < float(radii[0]) else (1 if distance < float(radii[1]) else 2)
			var ahead := (middle - (center + travel)).length()
			var approaching := travel.dot(middle - center) > 0.0 and ahead < AHEAD_RADIUS
			if approaching and moving_fast:
				lod = mini(lod, 1)
			desired[cell] = lod
			if lod == 0 and not moving_fast and prefetched.has(cell):
				var prepared: MultiMeshInstance3D = prefetched[cell]
				prefetched.erase(cell)
				prefetch_order.erase(cell)
				if prepared != null:
					prepared.show()
				var interrupted := current
				current = {"cell": cell, "lod": 0}
				if prepared != null:
					current["batch"] = prepared
				install_current()
				current = interrupted
			if not active.has(cell) and cached.has(cell):
				var restored: Dictionary = cached[cell]
				cached.erase(cell)
				cache_order.erase(cell)
				if restored.batch != null:
					restored.batch.visible = true
				active[cell] = restored
			if approaching and lod > 0 and active.has(cell) and active[cell].lod > 0 \
					and not loading.has(cell) and not prefetched.has(cell) and disk_cache.has(cell, 0):
				upcoming.append({"cell": cell, "distance": ahead})
			var build_lod := FALLBACK_LOD if moving_fast and lod == 0 else lod
			if not active.has(cell) and lod == 0:
				build_lod = FALLBACK_LOD
			if (not active.has(cell) or active[cell].lod > build_lod) and not loading.has(cell):
				if current.is_empty() or current.cell != cell or current.lod != build_lod:
					var priority := 0 if lod == 0 and not active.has(cell) else \
						(1 if approaching and not active.has(cell) else \
						(1 if lod == 0 and (travel == Vector2.ZERO or disk_cache.has(cell, 0)) else \
						(2 if not active.has(cell) else lod + 3)))
					pending.append({"cell": cell, "lod": build_lod,
						"distance": ahead if approaching else distance,
						"priority": priority})
	for cell: Vector2i in active.keys():
		if not desired.has(cell):
			if active[cell].batch != null:
				(active[cell].batch as Node3D).visible = false
				cached[cell] = active[cell]
				cache_order.append(cell)
			else:
				tile_cache.erase(cell)
			active.erase(cell)
	for cell: Vector2i in loading.keys():
		if not desired.has(cell) and disk_cache.cancel_load(cell, loading[cell]):
			loading.erase(cell)
	for cell: Vector2i in prefetched.keys():
		if not desired.has(cell):
			if prefetched[cell] != null:
				(prefetched[cell] as Node).queue_free()
			prefetched.erase(cell)
			prefetch_order.erase(cell)
	upcoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	for candidate: Dictionary in upcoming:
		if disk_cache.request_load(candidate.cell, 0):
			loading[candidate.cell] = 0
		else:
			break
	while cache_order.size() > CACHE_LIMIT:
		var oldest: Vector2i = cache_order.pop_front()
		if cached.has(oldest):
			if cached[oldest].batch != null:
				(cached[oldest].batch as Node).queue_free()
			cached.erase(oldest)
			tile_cache.erase(oldest)
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		return a.distance < b.distance)
	waiting = pending
	if not current.is_empty() and not desired.has(current.cell):
		abort_current()
	var cutoff: float = Graphics.RANGES["riverside_grass"][quality]
	material.set_shader_parameter("fade_start", cutoff - 24.0)
	material.set_shader_parameter("fade_end", cutoff - 4.0)
	for item: Dictionary in active.values():
		if item.batch != null:
			(item.batch as GeometryInstance3D).visibility_range_end = cutoff


func set_bake_targets(cells: Array[Vector2i]) -> void:
	# Developer bake mode uses the production generator/cache path but restricts
	# work to explicit cells, avoiding a large and approximate viewpoint sweep.
	bake_targets = cells.duplicate()
	view_cell = Vector2i(-999999, -999999)


func rebuild_bake_targets() -> void:
	desired.clear()
	var pending := []
	for cell: Vector2i in bake_targets:
		desired[cell] = 0
		if (not active.has(cell) or active[cell].lod > 0) and not loading.has(cell):
			pending.append({"cell": cell, "lod": 0, "distance": 0.0, "priority": 0})
	for cell: Vector2i in active.keys():
		if not desired.has(cell):
			if active[cell].batch != null:
				(active[cell].batch as Node).queue_free()
			active.erase(cell)
			tile_cache.erase(cell)
	for cell: Vector2i in loading.keys():
		if not desired.has(cell) and disk_cache.cancel_load(cell, loading[cell]):
			loading.erase(cell)
	waiting = pending
	if not current.is_empty() and not desired.has(current.cell):
		abort_current()


func _batch_from_buffer(cell: Vector2i, lod: int, buffer: PackedFloat32Array) -> MultiMeshInstance3D:
	if buffer.is_empty():
		return null
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.mesh = mesh
	group.instance_count = buffer.size() / 12
	group.buffer = buffer
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = group
	batch.material_override = material
	batch.name = "Grass_%d_%d_%d" % [cell.x, cell.y, lod]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.visibility_range_end = Graphics.RANGES["riverside_grass"][quality]
	batch.visibility_range_end_margin = 14.0
	batch.set_meta("riverside_count", group.instance_count)
	add_child(batch)
	return batch


func start_upload() -> void:
	var batch := _batch_from_buffer(current.cell, current.lod, current.buffer)
	if batch != null:
		current["batch"] = batch


func _store_prefetch(cell: Vector2i, batch: MultiMeshInstance3D) -> void:
	if batch != null:
		batch.hide()
	while prefetch_order.size() >= PREFETCH_LIMIT:
		var oldest: Vector2i = prefetch_order.pop_front()
		if prefetched[oldest] != null:
			(prefetched[oldest] as Node).queue_free()
		prefetched.erase(oldest)
	prefetched[cell] = batch
	prefetch_order.append(cell)


func install_current() -> void:
	if profile_enabled:
		profile_completed += 1
	var cell: Vector2i = current.cell
	if active.has(cell):
		if active[cell].batch != null:
			(active[cell].batch as Node).queue_free()
		active.erase(cell)
	active[cell] = {"lod": current.lod, "batch": null}
	if current.has("batch"):
		var batch: MultiMeshInstance3D = current.batch
		Graphics.batch(batch, "riverside_grass")
		active[cell] = {"lod": current.lod, "batch": batch}
	if desired.has(cell) and current.lod > desired[cell] and not moving_fast:
		var upgrade := {"cell": cell, "lod": desired[cell], "distance": 0.0,
			"priority": 1 if desired[cell] == 0 and (travel == Vector2.ZERO or disk_cache.has(cell, 0)) \
				else desired[cell] + 2}
		if travel != Vector2.ZERO and not disk_cache.has(cell, 0):
			waiting.append(upgrade)
		else:
			var insert_at := 0
			while insert_at < waiting.size() and waiting[insert_at].priority < upgrade.priority:
				insert_at += 1
			waiting.insert(insert_at, upgrade)
	current.clear()


func abort_current() -> void:
	if profile_enabled:
		profile_aborted += 1
	if current.has("batch"):
		(current.batch as Node).queue_free()
	current.clear()


func reset_profile() -> void:
	profile_generate_usec = 0
	profile_tile_usec = 0
	profile_upload_usec = 0
	profile_activation_usec = 0
	profile_disk_usec = 0
	profile_decompress_usec = 0
	profile_reconstruct_usec = 0
	profile_queue_usec = 0
	profile_result_wait_usec = 0
	profile_queue_max_usec = 0
	profile_result_wait_max_usec = 0
	profile_rebuild_usec = 0
	profile_completed = 0
	profile_aborted = 0
	profile_ready_loaded = 0
	profile_compact_loaded = 0
	profile_bundled_loaded = 0
	profile_cache_loaded = 0
	profile_height_cache_hits = 0


func ready_near() -> bool:
	if desired.is_empty():
		return false
	for cell: Vector2i in desired:
		if desired[cell] == 0 and (not active.has(cell) or active[cell].lod != 0):
			return false
	return true


func ready_all() -> bool:
	if desired.is_empty():
		return false
	for cell: Vector2i in desired:
		if not active.has(cell) or active[cell].lod > desired[cell]:
			return false
	return true
