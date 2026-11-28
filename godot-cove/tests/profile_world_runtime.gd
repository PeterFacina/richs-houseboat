extends SceneTree

var render_pre_usec := 0
var render_post_usec := 0
var render_duration_usec := 0

func _initialize() -> void:
	call_deferred("profile")


func profile() -> void:
	RenderingServer.frame_pre_draw.connect(record_render_pre)
	RenderingServer.frame_post_draw.connect(record_render_post)
	var load_started := Time.get_ticks_usec()
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	while game.eye == null or game.river == null or game.river.waterfront.park_grass == null:
		await process_frame
	print("PROFILE_LOAD ready_ms=", float(Time.get_ticks_usec() - load_started) / 1000.0)
	for frame in 30:
		await process_frame
	game.pause_menu.set_fullscreen(false, false)
	var requested_window_mode := "windowed"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--window-mode="):
			requested_window_mode = argument.trim_prefix("--window-mode=")
	match requested_window_mode:
		"exclusive": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var benchmark_size := Vector2i(1280, 720)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--resolution="):
			var dimensions := argument.trim_prefix("--resolution=").split("x")
			if dimensions.size() == 2:
				benchmark_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	DisplayServer.window_set_size(benchmark_size)
	root.content_scale_size = benchmark_size
	game.graphics.level = 0
	game.graphics.apply(game.river, game.eye)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--camera-far="):
			game.eye.far = float(argument.trim_prefix("--camera-far="))
			print("PROFILE_CONTROL camera_far=", game.eye.far)
	if OS.get_cmdline_user_args().has("--static-sky"):
		game.river.landscape_environment.sky.process_mode = Sky.PROCESS_MODE_QUALITY
		print("PROFILE_CONTROL static_sky=true")
	if OS.get_cmdline_user_args().has("--no-shadows"):
		var disabled_lights := 0
		for node in game.find_children("*", "Light3D", true, false):
			var light := node as Light3D
			if light.shadow_enabled:
				light.shadow_enabled = false
				disabled_lights += 1
		print("PROFILE_CONTROL shadows=false lights=", disabled_lights)
	if OS.get_cmdline_user_args().has("--no-water"):
		var hidden_water := hide_water_geometry(game)
		print("PROFILE_CONTROL water=false geometry=", hidden_water)
	if OS.get_cmdline_user_args().has("--simple-materials"):
		var overridden_geometry := override_geometry_materials(game)
		print("PROFILE_CONTROL simple_materials=true geometry=", overridden_geometry)
	if OS.get_cmdline_user_args().has("--physics-step-cap-one"):
		Engine.max_physics_steps_per_frame = 1
	paused = false
	game.set_process(true)
	game.set_physics_process(true)
	if OS.get_cmdline_user_args().has("--disable-game-tree"):
		game.process_mode = Node.PROCESS_MODE_DISABLED
	if OS.get_cmdline_user_args().has("--disable-render-loop"):
		RenderingServer.render_loop_enabled = false
	var grass = game.river.world_grass
	var variant := "riverside" if grass != null else "original"
	print("PROFILE_SETUP variant=", variant, " viewport=", root.get_viewport().get_visible_rect().size,
		" vsync=", DisplayServer.window_get_vsync_mode(), " msaa=", root.get_viewport().msaa_3d,
		" window_mode=", requested_window_mode,
		" camera_far=", game.eye.far, " shadow_range=", game.river.landscape_light.directional_shadow_max_distance,
		" camera_mode=", game.camera_mode(), " riverside_enabled=", game.river.riverside_enabled,
		" world_grass_present=", grass != null)
	if OS.get_cmdline_user_args().has("--architecture-audit"):
		print_architecture_inventory(game)
	for frame in 120:
		await process_frame
	if OS.get_cmdline_user_args().has("--mesh-inventory-only"):
		print_mesh_inventory(game)
		quit()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			var capture_path := argument.trim_prefix("--capture=")
			var capture_error := root.get_viewport().get_texture().get_image().save_png(capture_path)
			print("PROFILE_CAPTURE path=", capture_path, " error=", capture_error)
	if OS.get_cmdline_user_args().has("--focused-performance"):
		await focused_performance(game, variant)
		quit()
		return
	if OS.get_cmdline_user_args().has("--tail-diagnostic"):
		await tail_diagnostic(game)
		quit()
		return
	if OS.get_cmdline_user_args().has("--trace-only"):
		await route_sample(game, "trace_live", Callable(), 360)
		quit()
		return
	if OS.get_cmdline_user_args().has("--resident-prewarm-ab"):
		await route_sample(game, "resident_lazy", Callable(), 360)
		prewarm_residents(game)
		for frame in 120:
			await process_frame
		await route_sample(game, "resident_prewarmed", Callable(), 360)
		quit()
		return
	if OS.get_cmdline_user_args().has("--routes-only"):
		await route_sample(game, "stationary_marina", Callable(), 360)
		await route_sample(game, "walking_marina", Callable(self, "walk_route").bind(game), 360)
		await route_sample(game, "driving_marina", Callable(self, "drive_route").bind(game), 360)
		await route_sample(game, "boating_marina", Callable(self, "boat_route").bind(game), 360)
		quit()
		return
	if OS.get_cmdline_user_args().has("--walking-only"):
		await route_sample(game, "walking_marina", Callable(self, "walk_route").bind(game), 360)
		quit()
		return
	if OS.get_cmdline_user_args().has("--render-audit"):
		if grass != null:
			grass.surface.ready = false
			grass.hide()
		game.set_process(false)
		game.set_physics_process(false)
		await audit_render_groups(game)
		quit()
		return
	await sample(game, variant + "_live")
	if OS.get_cmdline_user_args().has("--mesh-inventory"):
		print_mesh_inventory(game)
	if OS.get_cmdline_user_args().has("--regionalization-ab"):
		remove_outside_region(game)
		for frame in 60:
			await process_frame
		await sample(game, variant + "_deep_river_only")
	if OS.get_cmdline_user_args().has("--profile-only-live"):
		quit()
		return
	if grass != null:
		grass.surface.ready = false
		for frame in 30:
			await process_frame
		await sample(game, variant + "_grass_static")
		grass.hide()
		for frame in 30:
			await process_frame
		await sample(game, variant + "_grass_off")
	quit()


func hide_water_geometry(game: Node3D) -> int:
	var water_materials: Array[Material] = [game.river.near_water, game.river.far_water,
		game.river.headpond_water]
	var hidden := 0
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry_uses_material(geometry, water_materials):
			geometry.hide()
			hidden += 1
	return hidden


func geometry_uses_material(geometry: GeometryInstance3D, materials: Array[Material]) -> bool:
	if geometry.material_override in materials:
		return true
	var mesh: Mesh = null
	if geometry is MeshInstance3D:
		mesh = (geometry as MeshInstance3D).mesh
	elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null:
		mesh = (geometry as MultiMeshInstance3D).multimesh.mesh
	if mesh == null:
		return false
	for surface in mesh.get_surface_count():
		if mesh.surface_get_material(surface) in materials:
			return true
	return false


func override_geometry_materials(game: Node3D) -> int:
	var simple := StandardMaterial3D.new()
	simple.albedo_color = Color(0.55, 0.58, 0.52)
	simple.roughness = 1.0
	var overridden := 0
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.visible:
			continue
		geometry.material_override = simple
		overridden += 1
	return overridden


func print_mesh_inventory(game: Node3D) -> void:
	var mesh_use := {}
	var buckets := {}
	var enabled_geometry := 0
	var enabled_mesh_instances := 0
	var enabled_multimeshes := 0
	var referenced_surfaces := 0
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.visible or not geometry.is_visible_in_tree():
			continue
		enabled_geometry += 1
		var mesh: Mesh = null
		var multiplier := 1
		if geometry is MeshInstance3D:
			mesh = (geometry as MeshInstance3D).mesh
			enabled_mesh_instances += 1
		elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null:
			var multimesh := (geometry as MultiMeshInstance3D).multimesh
			mesh = multimesh.mesh
			multiplier = multimesh.visible_instance_count if multimesh.visible_instance_count >= 0 else multimesh.instance_count
			enabled_multimeshes += 1
		if mesh == null:
			continue
		var rid := mesh.get_rid()
		mesh_use[rid] = int(mesh_use.get(rid, 0)) + 1
		var bucket := mesh_inventory_bucket(game, geometry)
		if not buckets.has(bucket):
			buckets[bucket] = {"geometry": 0, "multimeshes": 0, "instances": 0, "meshes": {}}
		var entry: Dictionary = buckets[bucket]
		entry.geometry += 1
		entry.multimeshes += 1 if geometry is MultiMeshInstance3D else 0
		entry.instances += multiplier
		entry.meshes[rid] = true
		referenced_surfaces += mesh.get_surface_count()
	var single_use_meshes := 0
	for uses in mesh_use.values():
		if uses == 1:
			single_use_meshes += 1
	print("PROFILE_MESH_INVENTORY enabled_geometry=", enabled_geometry,
		" mesh_instances=", enabled_mesh_instances, " multimeshes=", enabled_multimeshes,
		" unique_mesh_resources=", mesh_use.size(), " single_use_mesh_resources=", single_use_meshes,
		" referenced_surfaces=", referenced_surfaces)
	var ranking: Array = []
	for bucket in buckets:
		var entry: Dictionary = buckets[bucket]
		ranking.append({"name": bucket, "geometry": entry.geometry, "multimeshes": entry.multimeshes,
			"instances": entry.instances, "unique_meshes": entry.meshes.size()})
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.unique_meshes > b.unique_meshes)
	for index in mini(20, ranking.size()):
		var entry: Dictionary = ranking[index]
		print("PROFILE_MESH_BUCKET rank=", index + 1, " name=", entry.name,
			" unique_meshes=", entry.unique_meshes, " geometry=", entry.geometry,
			" multimeshes=", entry.multimeshes, " instances=", entry.instances)


func mesh_inventory_bucket(game: Node3D, geometry: GeometryInstance3D) -> String:
	var current: Node = geometry
	var path: Array[String] = [current.name]
	while current.get_parent() != null and current.get_parent() != game and current.get_parent() != game.river:
		current = current.get_parent()
		path.push_front(current.name)
	var scope := "river" if current.get_parent() == game.river else "game"
	return scope + "/" + "/".join(path.slice(0, mini(2, path.size())))


func focused_performance(game: Node3D, variant: String) -> void:
	print("FOCUSED_BEGIN variant=", variant, " camera_mode=", game.camera_mode(),
		" riverside_enabled=", game.river.riverside_enabled)
	await route_sample(game, "stationary_marina", Callable(), 360)
	await route_sample(game, "walking_marina", Callable(self, "walk_route").bind(game), 360)
	await route_sample(game, "driving_marina", Callable(self, "drive_route").bind(game), 360)
	await route_sample(game, "boating_marina", Callable(self, "boat_route").bind(game), 360)
	reset_stationary(game)
	for frame in 120:
		await process_frame
	# Highest expected-impact local rendering experiments first. Each restores state.
	await group_ab(game, "no_town_crowns", ["tree_detail", "tree_silhouette", "regional_crown"])
	await group_ab(game, "no_tree_trunks", ["tree_stem", "regional_trunk"])
	await tree_shadow_ab(game)
	await shadow_distance_ab(game, 36.0, "shadow_36m")
	await shadow_distance_ab(game, 0.0, "shadow_off")
	await resolution_ab(game, Vector2i(960, 540), "540p")
	print("FOCUSED_END")


func tail_diagnostic(game: Node3D) -> void:
	await route_sample(game, "tail_live", Callable(), 360)
	game.hud.hide()
	await route_sample(game, "tail_hud_hidden", Callable(), 360)
	game.hud.show()
	game.set_process(false)
	await route_sample(game, "tail_process_off", Callable(), 360)
	game.set_process(true)
	game.set_physics_process(false)
	await route_sample(game, "tail_physics_off", Callable(), 360)
	game.set_process(false)
	await route_sample(game, "tail_all_game_loops_off", Callable(), 360)


func reset_stationary(game: Node3D) -> void:
	game.marina_cars.active = -1
	game.driving = false
	game.player.global_position = Vector3(17921.6, game.river.ground_height(17921.6, 12731.4) + .08, 12731.4)
	game.player.velocity = Vector3.ZERO
	game.yaw = 1.07
	game.pitch = -.27
	game.update_view()


func prewarm_residents(game: Node3D) -> void:
	var residents = game.town_residents.residents
	var eye: Vector3 = game.eye.global_position
	for index in residents.size():
		var resident = residents[index]
		if resident.avatar == null:
			var at: Vector3 = eye + Vector3(float(index % 5) * 1.5, -1.5, float(index / 5) * 1.5)
			game.town_residents.display(index, at, Vector3.ZERO, 0.0, eye, 0.016, game.clock)
			resident.avatar.hide()
			resident.avatar.established = false
	print("PROFILE_EVENT resident_avatars_prewarmed=", residents.size())


func route_sample(game: Node3D, label: String, route: Callable, frames: int) -> void:
	if OS.get_cmdline_user_args().has("--resident-profile"):
		game.town_residents.reset_profile()
	if OS.get_cmdline_user_args().has("--gameplay-profile"):
		game.reset_performance_probe()
	var monitorless := OS.get_cmdline_user_args().has("--monitorless")
	var frame_ms: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var objects: Array[float] = []
	var spike_rows: Array[String] = []
	var previous := Time.get_ticks_usec()
	var previous_physics_frame := Engine.get_physics_frames()
	var previous_draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var previous_objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	for frame in frames:
		if route.is_valid():
			route.call(frame, frames)
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - previous) / 1000.0
		previous = now
		var physics_frame := Engine.get_physics_frames()
		var physics_steps := physics_frame - previous_physics_frame
		previous_physics_frame = physics_frame
		var process := 0.0 if monitorless else Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var physics := 0.0 if monitorless else Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var draw := 0.0 if monitorless else Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var primitive := 0.0 if monitorless else Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var object_count := 0.0 if monitorless else Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		frame_ms.append(elapsed)
		process_ms.append(process)
		physics_ms.append(physics)
		draws.append(draw)
		primitives.append(primitive)
		objects.append(object_count)
		if elapsed >= 33.33:
			var since_render_post := float(now - render_post_usec) / 1000.0 if render_post_usec > 0 else -1.0
			spike_rows.append("frame=%d ms=%.3f physics_steps=%d render_stage_ms=%.3f post_to_process_ms=%.3f process=%.3f physics=%.3f draws=%.0f ddraws=%+.0f objects=%.0f dobjects=%+.0f primitives=%.0f camera=(%.1f,%.1f,%.1f) mode=%s" % [frame, elapsed, physics_steps, float(render_duration_usec) / 1000.0, since_render_post, process, physics, draw, draw - previous_draws, object_count, object_count - previous_objects, primitive, game.eye.global_position.x, game.eye.global_position.y, game.eye.global_position.z, game.camera_mode()])
		previous_draws = draw
		previous_objects = object_count
	print_sample_result(label, frame_ms, process_ms, physics_ms, draws, primitives, objects)
	if OS.get_cmdline_user_args().has("--resident-profile"):
		game.town_residents.print_profile(label)
	if OS.get_cmdline_user_args().has("--gameplay-profile"):
		game.print_performance_probe(label)
	for row in spike_rows:
		print("PROFILE_SPIKE label=", label, " ", row)


func record_render_pre() -> void:
	render_pre_usec = Time.get_ticks_usec()


func record_render_post() -> void:
	render_post_usec = Time.get_ticks_usec()
	render_duration_usec = render_post_usec - render_pre_usec


func print_sample_result(label: String, frame_ms: Array[float], process_ms: Array[float],
		physics_ms: Array[float], draws: Array[float], primitives: Array[float], objects: Array[float]) -> void:
	for values in [frame_ms, process_ms, physics_ms, draws, primitives, objects]:
		values.sort()
	var middle := frame_ms.size() / 2
	var p95 := mini(frame_ms.size() - 1, floori(frame_ms.size() * .95))
	var p99 := mini(frame_ms.size() - 1, floori(frame_ms.size() * .99))
	var tail := maxi(1, ceili(frame_ms.size() * .01))
	var tail_total := 0.0
	for index in range(frame_ms.size() - tail, frame_ms.size()):
		tail_total += frame_ms[index]
	print("PROFILE_ROUTE label=", label, " frames=", frame_ms.size(),
		" median_ms=", frame_ms[middle], " p95_ms=", frame_ms[p95], " p99_ms=", frame_ms[p99],
		" worst_ms=", frame_ms[-1], " fps_1pct_low=", 1000.0 / (tail_total / tail),
		" process_p95_ms=", process_ms[p95], " physics_p95_ms=", physics_ms[p95],
		" draws_median=", draws[middle], " primitives_median=", primitives[middle],
		" objects_median=", objects[middle])


func walk_route(frame: int, frames: int, game: Node3D) -> void:
	var t := float(frame) / maxf(1.0, frames - 1.0)
	var from := Vector3(17920.0, 0.0, 12670.0)
	var to := Vector3(18300.0, 0.0, 12920.0)
	var at := from.lerp(to, t)
	at.y = game.river.ground_height(at.x, at.z) + .08
	game.player.global_position = at
	game.player.velocity = (to - from).normalized() * 4.2
	game.yaw = atan2(-(to - from).x, -(to - from).z)
	game.update_view()


func drive_route(frame: int, frames: int, game: Node3D) -> void:
	var car = game.marina_cars.cars[0]
	if game.marina_cars.active != 0:
		game.marina_cars.enter(0)
	var t := float(frame) / maxf(1.0, frames - 1.0)
	var from := Vector3(18025.0, 0.0, 12638.0)
	var to := Vector3(18415.0, 0.0, 13010.0)
	var at := from.lerp(to, t)
	at.y = game.river.driving_height(at.x, at.z)
	car.heading = atan2(-(to - from).x, -(to - from).z)
	car.global_position = at
	car.speed = 15.0
	game.marina_cars.follow(1.0)


func boat_route(frame: int, frames: int, game: Node3D) -> void:
	if game.marina_cars.active >= 0:
		game.marina_cars.active = -1
	game.driving = true
	var t := float(frame) / maxf(1.0, frames - 1.0)
	var from := Vector3(17770.0, 0.0, 12370.0)
	var to := Vector3(18550.0, 0.0, 12160.0)
	var at := from.lerp(to, t)
	var heading := atan2(-(to - from).x, -(to - from).z)
	game.vessel.heading = heading
	game.vessel.speed = 6.0
	game.vessel.global_position = Vector3(at.x, game.river.wave_height(at, game.clock), at.z)
	game.player.global_position = game.vessel.to_global(Vector3(0.0, 1.5, 0.0))
	game.eye.global_position = game.vessel.to_global(Vector3(0.0, 2.25, 1.8))
	game.eye.global_basis = Basis(Vector3.UP, heading)


func group_ab(game: Node3D, label: String, kinds: Array[String]) -> void:
	var hidden: Array[Node3D] = []
	for kind in kinds:
		for item: Node3D in root.get_tree().get_nodes_in_group("river_graphics_" + kind):
			if game.river.is_ancestor_of(item) and item.visible:
				item.hide()
				hidden.append(item)
	for frame in 90:
		await process_frame
	await route_sample(game, label, Callable(), 360)
	for item in hidden:
		item.show()


func tree_shadow_ab(game: Node3D) -> void:
	var previous: Array = []
	for kind in ["tree_detail", "tree_silhouette", "tree_stem", "regional_crown", "regional_trunk"]:
		for item: GeometryInstance3D in root.get_tree().get_nodes_in_group("river_graphics_" + kind):
			if game.river.is_ancestor_of(item):
				previous.append([item, item.cast_shadow])
				item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for frame in 90:
		await process_frame
	await route_sample(game, "tree_shadows_off", Callable(), 360)
	for state in previous:
		state[0].cast_shadow = state[1]


func shadow_distance_ab(game: Node3D, distance: float, label: String) -> void:
	var previous: float = game.river.landscape_light.directional_shadow_max_distance
	game.river.landscape_light.directional_shadow_max_distance = distance
	for frame in 90:
		await process_frame
	await route_sample(game, label, Callable(), 360)
	game.river.landscape_light.directional_shadow_max_distance = previous


func resolution_ab(game: Node3D, size: Vector2i, label: String) -> void:
	var previous := DisplayServer.window_get_size()
	DisplayServer.window_set_size(size)
	for frame in 120:
		await process_frame
	await route_sample(game, label, Callable(), 360)
	DisplayServer.window_set_size(previous)


func audit_render_groups(game: Node3D) -> void:
	await sample(game, "render_base")
	for test in [
		["buildings", ["building_shell", "building_detail"]],
		["trees", ["riverside_leaves", "riverside_tree", "tree_detail", "tree_silhouette",
			"tree_stem", "regional_crown", "regional_trunk"]]
	]:
		var hidden := []
		for kind: String in test[1]:
			for item: Node3D in root.get_tree().get_nodes_in_group("river_graphics_" + kind):
				if game.river.is_ancestor_of(item) and item.visible:
					item.hide()
					hidden.append(item)
		for frame in 30:
			await process_frame
		await sample(game, "render_no_" + test[0])
		for item: Node3D in hidden:
			item.show()
	game.river.near_surface.hide()
	for frame in 30:
		await process_frame
	await sample(game, "render_no_near_water")
	game.river.near_surface.show()
	var shadow_distance: float = game.river.landscape_light.directional_shadow_max_distance
	game.river.landscape_light.directional_shadow_max_distance = 0.0
	for frame in 30:
		await process_frame
	await sample(game, "render_no_directional_shadow")
	game.river.landscape_light.directional_shadow_max_distance = shadow_distance


func sample(game: Node3D, label: String) -> void:
	if game.river.world_grass != null:
		game.river.world_grass.reset_profile()
	var frame_ms: Array[float] = []
	var stall_count := 0
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var primitives: Array[float] = []
	var objects: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 300:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - previous) / 1000.0)
		if frame_ms[-1] >= 33.33:
			stall_count += 1
		previous = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	frame_ms.sort()
	process_ms.sort()
	physics_ms.sort()
	draw_calls.sort()
	primitives.sort()
	objects.sort()
	var worst_one_percent_frames := maxi(1, ceili(frame_ms.size() * .01))
	var worst_one_percent_total := 0.0
	for index in range(frame_ms.size() - worst_one_percent_frames, frame_ms.size()):
		worst_one_percent_total += frame_ms[index]
	var one_percent_low_fps := 1000.0 / (worst_one_percent_total / worst_one_percent_frames)
	print("PROFILE_RESULT label=", label, " frame_median_ms=", frame_ms[150], " frame_p95_ms=", frame_ms[285],
		" frame_p99_ms=", frame_ms[297], " frame_worst_ms=", frame_ms[-1],
		" fps_1pct_low=", one_percent_low_fps,
		" stalls_33ms=", stall_count,
		" fps_median=", 1000.0 / frame_ms[150], " process_median_ms=", process_ms[150],
		" process_p95_ms=", process_ms[285], " process_p99_ms=", process_ms[297],
		" physics_median_ms=", physics_ms[150], " physics_p95_ms=", physics_ms[285],
		" physics_p99_ms=", physics_ms[297], " draws_median=", draw_calls[150],
		" primitives_median=", primitives[150], " objects_median=", objects[150],
		" nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		" active_physics=", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		" ram_mb=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		" vram_mb=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		" grass_chunks=", game.river.world_grass.active.size() if game.river.world_grass != null else 0)
	if game.river.world_grass != null and game.river.world_grass.profile_enabled:
		var grass = game.river.world_grass
		print("PROFILE_GRASS label=", label, " generate_ms=", float(grass.profile_generate_usec) / 1000.0,
			" tile_ms=", float(grass.profile_tile_usec) / 1000.0,
			" upload_ms=", float(grass.profile_upload_usec) / 1000.0,
			" rebuild_ms=", float(grass.profile_rebuild_usec) / 1000.0,
			" completed=", grass.profile_completed, " aborted=", grass.profile_aborted,
			" waiting=", grass.waiting.size())


func print_architecture_inventory(game: Node3D) -> void:
	# Source-derived envelope: all current Deep River town ground, marina, Lamure,
	# McAnulty access, and a generous Ottawa River boating buffer remain inside.
	var playable := Rect2(14500.0, 10000.0, 6000.0, 5800.0)
	var groups := ["building_shell", "building_detail", "tree_detail", "tree_silhouette",
		"tree_stem", "regional_crown", "regional_trunk"]
	for kind: String in groups:
		var counts := inventory_group(game.river, "river_graphics_" + kind, playable)
		print("ARCH_INVENTORY group=", kind, " inside_nodes=", counts.inside_nodes,
			" crossing_nodes=", counts.crossing_nodes, " outside_nodes=", counts.outside_nodes,
			" inside_instances=", counts.inside_instances, " crossing_instances=", counts.crossing_instances,
			" outside_instances=", counts.outside_instances)
	var terrain := {"inside": 0, "crossing": 0, "outside": 0, "triangles_inside": 0,
		"triangles_crossing": 0, "triangles_outside": 0}
	for body: Node in root.get_tree().get_nodes_in_group("ottawa_terrain"):
		if not game.river.is_ancestor_of(body) or not body.get_parent() is MeshInstance3D:
			continue
		var mesh := body.get_parent() as MeshInstance3D
		var world_box := mesh.global_transform * mesh.get_aabb()
		var footprint := Rect2(world_box.position.x, world_box.position.z, world_box.size.x, world_box.size.z)
		var bucket := classify_footprint(footprint, playable)
		terrain[bucket] += 1
		var faces := mesh.mesh.get_faces().size() / 3 if mesh.mesh != null else 0
		terrain["triangles_" + bucket] += faces
	print("ARCH_TERRAIN inside_tiles=", terrain.inside, " crossing_tiles=", terrain.crossing,
		" outside_tiles=", terrain.outside, " inside_triangles=", terrain.triangles_inside,
		" crossing_triangles=", terrain.triangles_crossing, " outside_triangles=", terrain.triangles_outside)


func inventory_group(owner: Node, group: String, playable: Rect2) -> Dictionary:
	var counts := {"inside_nodes": 0, "crossing_nodes": 0, "outside_nodes": 0,
		"inside_instances": 0, "crossing_instances": 0, "outside_instances": 0}
	for node: Node in root.get_tree().get_nodes_in_group(group):
		if not owner.is_ancestor_of(node) or not node is VisualInstance3D:
			continue
		var visual := node as VisualInstance3D
		var world_box := visual.global_transform * visual.get_aabb()
		var footprint := Rect2(world_box.position.x, world_box.position.z, world_box.size.x, world_box.size.z)
		var bucket := classify_footprint(footprint, playable)
		counts[bucket + "_nodes"] += 1
		var instances := 1
		if visual is MultiMeshInstance3D and visual.multimesh != null:
			instances = visual.multimesh.instance_count
		counts[bucket + "_instances"] += instances
	return counts


func classify_footprint(footprint: Rect2, playable: Rect2) -> String:
	if playable.encloses(footprint):
		return "inside"
	if playable.intersects(footprint):
		return "crossing"
	return "outside"


func remove_outside_region(game: Node3D) -> void:
	var playable := Rect2(14500.0, 10000.0, 6000.0, 5800.0)
	var removed_visuals := 0
	var removed_instances := 0
	for kind: String in ["regional_crown", "regional_trunk"]:
		for node: Node in root.get_tree().get_nodes_in_group("river_graphics_" + kind):
			if not game.river.is_ancestor_of(node) or not node is VisualInstance3D:
				continue
			var visual := node as VisualInstance3D
			var world_box := visual.global_transform * visual.get_aabb()
			var footprint := Rect2(world_box.position.x, world_box.position.z, world_box.size.x, world_box.size.z)
			if classify_footprint(footprint, playable) != "outside":
				continue
			removed_visuals += 1
			removed_instances += visual.multimesh.instance_count if visual is MultiMeshInstance3D and visual.multimesh != null else 1
			visual.queue_free()
	var removed_terrain := 0
	var removed_triangles := 0
	for body: Node in root.get_tree().get_nodes_in_group("ottawa_terrain"):
		if not game.river.is_ancestor_of(body) or not body.get_parent() is MeshInstance3D:
			continue
		var mesh := body.get_parent() as MeshInstance3D
		var world_box := mesh.global_transform * mesh.get_aabb()
		var footprint := Rect2(world_box.position.x, world_box.position.z, world_box.size.x, world_box.size.z)
		if classify_footprint(footprint, playable) != "outside":
			continue
		removed_terrain += 1
		removed_triangles += mesh.mesh.get_faces().size() / 3 if mesh.mesh != null else 0
		mesh.queue_free()
	print("ARCH_AB_REMOVED visuals=", removed_visuals, " instances=", removed_instances,
		" terrain_tiles=", removed_terrain, " terrain_triangles=", removed_triangles)
