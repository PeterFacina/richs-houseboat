extends SceneTree

const Residents = preload("res://town_residents.gd")
const Crew = preload("res://multiplayer_session.gd")


var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	print("CHECK ", label, ": ", condition)
	if not condition:
		failures += 1


func run() -> void:
	if not "houseboat-144" in OS.get_user_data_dir().to_lower():
		push_error("Run with an isolated APPDATA directory containing houseboat-144.")
		quit(2)
		return

	var game = load("res://game_world.tscn").instantiate()
	var load_started := Time.get_ticks_msec()
	root.add_child(game)
	await physics_frame
	await physics_frame
	print("World fixture reached first physics frame in ", Time.get_ticks_msec() - load_started, " ms.")
	game.set_physics_process(false)
	game.set_process(false)
	var residents: Residents = game.town_residents
	var camera: Camera3D = game.eye
	var start_at := camera.global_position
	camera.global_position = Vector3(10000, 500, 10000)
	var empty: Array[Dictionary] = []
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state

	var prepare_worst := 0
	var prepare_started := Time.get_ticks_usec()
	for step in 128:
		if residents.initialized:
			break
		var frame_start := Time.get_ticks_usec()
		residents.tick(.10, 400, camera, float(step) * .10, empty, true, PackedVector3Array())
		prepare_worst = maxi(prepare_worst, Time.get_ticks_usec() - frame_start)
	print("Navigation setup us ", Time.get_ticks_usec() - prepare_started, " max batch us ", prepare_worst, " marked crossings ", residents.routes.crossing_count)
	check(residents.initialized and residents.routes.points.size() > 100, "loaded pedestrian graph built from the world")
	var ids := {}
	var cells := {}
	var coastal := 0
	for resident in residents.residents:
		if resident.home.is_empty():
			continue
		ids[resident.home.id] = true
		var where: Vector3 = resident.home.foot
		cells[Vector2i(floori(where.x / 160.0), floori(where.z / 160.0))] = true
		coastal += int(residents.waterfront_nodes.has(residents.routes.components[resident.home_node]))
	print("Homes=", ids.size(), " districts at 160m resolution=", cells.size(), " waterfront home connections=", coastal)
	check(ids.size() == Residents.NAMES.size(), "20 unique residential entrances")
	check(cells.size() >= 8 and coastal > 0, "homes spread across districts and waterfront paths")
	if residents.residents[0].home.is_empty():
		game.queue_free()
		await process_frame
		quit(1)
		return
	var first := residents.residents[0]
	camera.global_position = first.home.door + Vector3.UP * 1.5
	first.wait = 0
	residents.simulate(first, .1, 700, camera, empty, space)
	check(first.phase == Residents.Phase.HOME and not first.feet.is_finite(),
		"nearby observer prevents a doorway appearance")
	camera.global_position = Vector3(10000, 500, 10000)

	var start_times := {}
	var ranges := {}
	var noticed := {}
	var at_graph := {}
	var simulator_usec := 0
	for step in 1600:
		var started := Time.get_ticks_usec()
		residents.tick(.10, 700, camera, float(step) * .10, empty, true, PackedVector3Array())
		simulator_usec += Time.get_ticks_usec() - started
		for i in residents.residents.size():
			var resident := residents.residents[i]
			if not resident.feet.is_finite():
				continue
			if not noticed.has(i):
				noticed[i] = true
				start_times[step] = true
			if resident.node >= 0:
				at_graph[i] = true
			ranges[i] = maxf(ranges.get(i, 0.0), resident.feet.distance_to(resident.home.door))
	var walked := 0
	for i in residents.residents.size():
		walked += int(ranges.get(i, 0.0) >= 23.0)
		var resident := residents.residents[i]
		if ranges.get(i, 0.0) < 23.0:
			print("SHORT ", i, " phase=", resident.phase, " max=", ranges.get(i, 0.0), " blocked=", resident.blocked_for,
				" at=", resident.feet, " node=", resident.node, " link=", resident.home_node, " entry=", resident.home)
	print("Departures=", noticed.size(), " distinct spawn ticks=", start_times.size(), " reached graph=", at_graph.size(),
		" walked 23+ m=", walked, " mean far tick us=", float(simulator_usec) / 1600.0)
	check(noticed.size() == Residents.NAMES.size() and start_times.size() >= 10, "staggered doorway departures")
	check(at_graph.size() == Residents.NAMES.size() and walked == Residents.NAMES.size(), "all residents leave their properties and walk across town")

	var viewport_peer := Residents.new()
	game.add_child(viewport_peer)
	viewport_peer.setup(PackedVector3Array(), PackedVector3Array(), [], game.river.ground_height)
	var packet := residents.snapshot()
	camera.global_position = packet[0] + Vector3.UP * 1.6
	viewport_peer.tick(.10, 700, camera, 0, empty, false, packet)
	check(not viewport_peer.initialized and viewport_peer.residents[0].avatar != null
		and viewport_peer.residents[0].avatar.global_position.distance_to(packet[0]) < .1,
		"guest presentation follows server position without simulating residents")
	check(game.campaign.ship_packet().pedestrians == packet and game.campaign.initial_ship_packet().pedestrians == packet,
		"ship updates and reliable initial packet include current residents")
	camera.global_position = Vector3(10000, 500, 10000)
	await verify_recovery(residents, camera, game)
	await verify_network(game, residents)
	var repeat := Residents.new()
	game.add_child(repeat)
	repeat.setup(game.river.town_walkways.pedestrian_edges, game.river.waterfront_walk,
		game.river.pedestrian_entries, game.river.ground_height, residents.moving_bodies)
	for i in 128:
		if repeat.initialized:
			break
		repeat.tick(.1, 400, camera, 0, empty, true, PackedVector3Array())
	var same_homes := repeat.initialized
	for i in residents.residents.size():
		same_homes = same_homes and repeat.residents[i].home.get("id") == residents.residents[i].home.get("id")
	check(same_homes, "rebuilding the district assigns the same homes")
	repeat.queue_free()
	camera.global_position = start_at
	check(is_instance_valid(game.campaign.rich) and is_instance_valid(game.shannon_job), "existing characters initialize")
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)


func verify_recovery(residents: Residents, camera: Camera3D, game: Node3D) -> void:
	var resident := residents.residents[0]
	var graph := residents.routes
	var start := -1
	var blocked := -1
	var opposite := -1
	for id in graph.districts[graph.components[resident.home_node]]:
		var usable := PackedInt32Array()
		for linked in graph.graph.get_point_connections(id):
			if graph.points[id].distance_to(graph.points[linked]) >= .60:
				usable.append(linked)
		if usable.size() >= 2 and graph.points[usable[0]].distance_to(graph.points[usable[1]]) >= 1.0:
			start = id
			blocked = usable[0]
			opposite = usable[1]
			break
	check(start >= 0, "walking district has a two-way sidewalk stretch")
	if start < 0:
		return
	var origin := graph.points[start]
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .21
	collision.shape = shape
	blocker.position = graph.points[blocked] + Vector3.UP * .9
	blocker.add_child(collision)
	game.add_child(blocker)
	await physics_frame
	await physics_frame
	var space := game.get_world_3d().direct_space_state
	var empty: Array[Dictionary] = []
	var observed_hold := false
	resident.node = start
	resident.feet = origin
	resident.phase = Residents.Phase.ROAMING
	resident.wait = 0.0
	resident.path = PackedInt64Array([start, blocked])
	resident.avoid = Vector2i(-1, -1)
	resident.blocked_for = 0.0
	resident.next = 1
	for i in 45:
		residents.simulate(resident, .1, 700.0, camera, empty, space)
		if resident.avoid == Vector2i(start, blocked):
			observed_hold = true
			break
	print("Obstacle probe distance=", resident.feet.distance_to(graph.points[blocked]), " phase=", resident.phase, " avoid=", resident.avoid)
	check(observed_hold and resident.feet.distance_to(graph.points[blocked]) > .18,
		"blocked route stops before collision and marks the failed edge")
	for i in 20:
		if resident.phase != Residents.Phase.RETREATING:
			break
		residents.simulate(resident, .1, 700.0, camera, empty, space)
	check(resident.feet.distance_to(origin) < .01, "resident walks back to the previous sidewalk point")
	var detour := graph.path(start, opposite, Vector2i(start, blocked))
	resident.path = detour
	resident.next = 1
	resident.wait = 0.0
	for i in 30:
		if resident.node == opposite:
			break
		residents.simulate(resident, .1, 700.0, camera, empty, space)
	check(resident.node == opposite, "resident can take a different link while the original stays blocked")
	blocker.queue_free()
	await physics_frame


func endpoint(label: String, vessel: Node3D) -> Crew:
	var group := Node.new()
	group.name = label
	root.add_child(group)
	var api := SceneMultiplayer.new()
	api.root_path = group.get_path()
	set_multiplayer(api, group.get_path())
	var crew := Crew.new()
	crew.name = "Crew"
	crew.boat = vessel
	crew.local_profile = label.md5_text()
	crew.progression_secret = label.sha256_text().left(32)
	group.add_child(crew)
	return crew


func until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()


func verify_network(game: Node3D, residents: Residents) -> void:
	var host := endpoint("ResidentHost", game.vessel)
	var guest := endpoint("ResidentGuest", game.vessel)
	var incoming := {}
	var expected := residents.snapshot()
	host.requested.connect(func(peer: int, action: String, _value: Variant):
		if action == "connected":
			host.enter_river.rpc_id(peer, game.campaign.initial_ship_packet()))
	guest.ship_received.connect(func(data: Dictionary): incoming.merge(data, true))
	host.host("ResidentHost")
	host.start_session()
	guest.join("ResidentGuest", "127.0.0.1")
	check(await until(func() -> bool: return guest.started and incoming.get("pedestrians") == expected),
		"late-joining ENet guest receives all 20 resident positions")
	var first := residents.residents[0]
	first.yaw = wrapf(first.yaw + .65, -PI, PI)
	var updated := residents.snapshot()
	host.share_ship.rpc(game.campaign.ship_packet())
	check(await until(func() -> bool: return incoming.get("pedestrians") == updated and updated != expected),
		"ENet guest receives subsequent authoritative resident state")
	guest.stop()
	host.stop()
	guest.get_parent().queue_free()
	host.get_parent().queue_free()
	await process_frame
