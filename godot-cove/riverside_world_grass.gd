extends Node3D

const Art = preload("res://riverside_art.gd")
const Surface = preload("res://riverside_grass_surface.gd")
const Graphics = preload("res://river_graphics.gd")
const CHUNK := 8.0
const TILE := 1.0
const GRID := 113 # 199.5 candidates/m2, matching the approved 200-blade prototype.
const LOD_STEPS := [1, 2, 4] # Nested deterministic subsets: 200, 50, 12.5 blades/m2.
const RADII := [[18.0, 32.0, 52.0], [22.0, 42.0, 69.0], [28.0, 50.0, 115.0]]
const BUILD_BUDGET_USEC := 3500

var surface
var mesh: Mesh
var material: ShaderMaterial
var active := {}
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


func setup(eligibility) -> void:
	surface = eligibility
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


func update_around(viewpoint: Vector3, preset: int) -> void:
	if surface == null or not surface.ready:
		return
	preset = clampi(preset, 0, 2)
	var position := Vector2(viewpoint.x, viewpoint.z)
	var now := Time.get_ticks_usec()
	if has_view:
		var delta := position - last_view
		var seconds := maxf(float(now - last_tick) / 1000000.0, .001)
		var speed := delta.length() / seconds
		var fast := (speed > 7.0 or (moving_fast and speed > 2.0)) and delta.length_squared() < 4.0
		if fast != moving_fast:
			moving_fast = fast
			view_cell = Vector2i(-999999, -999999)
		if delta.length_squared() > .0001 and delta.length_squared() < 4.0:
			travel = delta.normalized() * (20.0 if moving_fast else 0.0)
		elif delta.length_squared() >= 4.0:
			travel = Vector2.ZERO
	last_view = position
	last_tick = now
	has_view = true
	var center := Vector2i(floori(viewpoint.x / CHUNK), floori(viewpoint.z / CHUNK))
	if center != view_cell or preset != quality:
		view_cell = center
		quality = preset
		rebuild_targets(position)
	var deadline := Time.get_ticks_usec() + maxi(build_budget_usec, 5500 if moving_fast else 0)
	while Time.get_ticks_usec() < deadline:
		if current.is_empty():
			if waiting.is_empty():
				break
			current = waiting.pop_front()
			current["index"] = 0
			current["transforms"] = []
			current["tiles"] = {}
			var block: Vector2i = current.cell
			current["masks"] = surface.relevant_masks(Rect2(Vector2(block) * CHUNK,
				Vector2.ONE * CHUNK).grow(Surface.CLEARANCE))
		var cell: Vector2i = current.cell
		if not desired.has(cell):
			abort_current()
			continue
		if current.has("batch"):
			var batch: MultiMeshInstance3D = current.batch
			for task in 128:
				if current.upload >= current.transforms.size():
					break
				batch.multimesh.set_instance_transform(current.upload, current.transforms[current.upload])
				current.upload += 1
			if current.upload >= current.transforms.size():
				install_current()
			continue
		var step: int = LOD_STEPS[current.lod]
		var count := ceili(float(GRID) / float(step))
		var total := count * count
		for task in 24:
			if current.index >= total:
				break
			var local_x: int = (current.index % count) * step
			var local_z: int = floori(float(current.index) / float(count)) * step
			var tile := Vector2i(floori((float(local_x) + .5) * CHUNK / GRID / TILE),
				floori((float(local_z) + .5) * CHUNK / GRID / TILE))
			if not current.tiles.has(tile):
				current.tiles[tile] = classify_tile(cell, tile, current.masks)
			var tile_data: Dictionary = current.tiles[tile]
			if tile_data.state == -1:
				current["index"] += 1
				continue
			var seed := hash(Vector3i(cell.x, cell.y, local_z * GRID + local_x))
			var jitter_x := (float(seed & 1023) / 1023.0 - .5) * CHUNK / GRID * .68
			var jitter_z := (float((seed >> 10) & 1023) / 1023.0 - .5) * CHUNK / GRID * .68
			var point := Vector2((float(cell.x) + (float(local_x) + .5) / GRID) * CHUNK + jitter_x,
				(float(cell.y) + (float(local_z) + .5) / GRID) * CHUNK + jitter_z)
			var height: float = surface.grass_height(point, current.masks) if tile_data.state == 0 else \
				tile_height(point, cell, tile, tile_data.heights)
			if is_finite(height):
				var angle := float((seed >> 20) & 1023) / 1023.0 * TAU
				current.transforms.append(Transform3D(Basis(Vector3.UP, angle), Vector3(point.x, height, point.y)))
			current["index"] += 1
		if current.index >= total:
			start_upload()
		if Time.get_ticks_usec() >= deadline:
			break


func classify_tile(cell: Vector2i, tile: Vector2i, nearby_masks: Array) -> Dictionary:
	var origin := Vector2(cell) * CHUNK + Vector2(tile) * TILE
	var heights := []
	var valid := 0
	for z in 3:
		for x in 3:
			var height: float = surface.grass_height(origin + Vector2(x, z) * TILE * .5, nearby_masks)
			heights.append(height)
			valid += int(is_finite(height))
	if valid == 0:
		return {"state": -1}
	if valid == 9:
		var safe := true
		for z in 3:
			for x in 3:
				if not is_finite(surface.grass_height(origin + Vector2(x, z) * TILE * .5,
						nearby_masks, .35)):
					safe = false
					break
			if not safe:
				break
		if safe:
			return {"state": 1, "heights": [heights[0], heights[2], heights[6], heights[8]]}
	return {"state": 0}


func tile_height(point: Vector2, cell: Vector2i, tile: Vector2i, heights: Array) -> float:
	var within := point - (Vector2(cell) * CHUNK + Vector2(tile) * TILE)
	return lerpf(lerpf(heights[0], heights[1], within.x),
		lerpf(heights[2], heights[3], within.x), within.y)


func rebuild_targets(center: Vector2) -> void:
	surface.slope_cache.clear()
	var radii: Array = RADII[quality]
	if moving_fast:
		radii = radii.duplicate()
		radii[0] = 12.0
	var reach := ceili(float(radii[2]) / CHUNK) + 1
	desired.clear()
	var pending := []
	for z in range(view_cell.y - reach, view_cell.y + reach + 1):
		for x in range(view_cell.x - reach, view_cell.x + reach + 1):
			var cell := Vector2i(x, z)
			var middle := (Vector2(cell) + Vector2.ONE * .5) * CHUNK
			var distance := center.distance_to(middle)
			if distance > float(radii[2]) + CHUNK * .7:
				continue
			var lod := 0 if distance < float(radii[0]) else (1 if distance < float(radii[1]) else 2)
			desired[cell] = lod
			if not active.has(cell) or active[cell].lod != lod:
				var build_lod := 1 if moving_fast and lod == 0 and not active.has(cell) else lod
				if current.is_empty() or current.cell != cell or current.lod != build_lod:
					var ahead := (middle - (center + travel)).length() + 8.0
					var priority := 0 if lod == 0 and not active.has(cell) else (1 if lod == 0 else lod + 1)
					pending.append({"cell": cell, "lod": build_lod, "distance": minf(distance, ahead),
						"priority": priority})
	for cell: Vector2i in active.keys():
		if not desired.has(cell):
			if active[cell].batch != null:
				(active[cell].batch as Node).queue_free()
			active.erase(cell)
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


func start_upload() -> void:
	if current.transforms.is_empty():
		install_current()
		return
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.mesh = mesh
	group.instance_count = current.transforms.size()
	group.visible_instance_count = 0
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = group
	batch.material_override = material
	batch.name = "Grass_%d_%d_%d" % [current.cell.x, current.cell.y, current.lod]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.visibility_range_end = Graphics.RANGES["riverside_grass"][quality]
	batch.visibility_range_end_margin = 14.0
	batch.set_meta("riverside_count", current.transforms.size())
	add_child(batch)
	current["batch"] = batch
	current["upload"] = 0


func install_current() -> void:
	var cell: Vector2i = current.cell
	if active.has(cell):
		if active[cell].batch != null:
			(active[cell].batch as Node).queue_free()
		active.erase(cell)
	active[cell] = {"lod": current.lod, "batch": null}
	if current.has("batch"):
		var batch: MultiMeshInstance3D = current.batch
		batch.multimesh.visible_instance_count = batch.multimesh.instance_count
		Graphics.batch(batch, "riverside_grass")
		active[cell] = {"lod": current.lod, "batch": batch}
	current.clear()


func abort_current() -> void:
	if current.has("batch"):
		(current.batch as Node).queue_free()
	current.clear()


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
		if not active.has(cell) or active[cell].lod != desired[cell]:
			return false
	return true
