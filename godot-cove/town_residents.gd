extends Node3D

const Avatar = preload("res://crew_avatar.gd")
const Calendar = preload("res://mowing_routes.gd")
const Idle = preload("res://character_idle.gd")
const Routes = preload("res://pedestrian_routes.gd")

const NAMES := ["Mara Chen", "Eli Mercer", "Nadia Roy", "Gus Bell", "Jo Baptiste",
	"Mae Walker", "Sam Patel", "Ruth Pelletier", "Owen Park", "Ana Silva", "Lee Martin",
	"Tess Fraser", "Noah Grant", "Jean Leblanc", "Kim Nguyen", "Rose Haddad", "Alex Shah",
	"Casey Brooks", "Ren Okafor", "June Kelly"]
const OUTFITS := ["#81523d", "#665b77", "#416f77", "#776a44", "#684447",
	"#38526e", "#566748", "#77604e", "#5d5351", "#596f75"]
const ACTIVE_RADIUS := 85.0
const SOLID_MASK := 1

enum Phase { HOME, DEPARTING, ROAMING, RETREATING, RETURNING, ENTERING }

class Resident:
	var avatar: Avatar
	var idle := Idle.new()
	var random := RandomNumberGenerator.new()
	var home: Dictionary = {}
	var home_node := -1
	var node := -1
	var path := PackedInt64Array()
	var next := 0
	var phase := Phase.HOME
	var feet := Vector3.INF
	var movement := Vector3.ZERO
	var yaw := 0.0
	var pace := 1.15
	var wait := 0.0
	var blocked_for := 0.0
	var failed_plans := 0
	var exterior_leg := false
	var was_walking := false
	var departure := 480.0
	var curfew := 1230.0

var routes := Routes.new()
var residents: Array[Resident] = []
var entrances: Array[Dictionary] = []
var candidates: Array[Dictionary] = []
var waterfront_nodes := {}
var building_index := 0
var initialized := false
var frame := 0
var ground: Callable
var park_edges := PackedVector3Array()
var town_edges := PackedVector3Array()
var moving_bodies: Array[RID] = []
var profile_enabled := OS.get_cmdline_user_args().has("--resident-profile")
var profile_ticks := 0
var profile_prepare_usec := 0
var profile_simulate_usec := 0
var profile_display_usec := 0
var profile_tick_max_usec := 0
var profile_simulate_max_usec := 0
var profile_near_simulations := 0
var profile_far_simulations := 0
var profile_planning_slots := 0


func reset_profile() -> void:
	profile_ticks = 0
	profile_prepare_usec = 0
	profile_simulate_usec = 0
	profile_display_usec = 0
	profile_tick_max_usec = 0
	profile_simulate_max_usec = 0
	profile_near_simulations = 0
	profile_far_simulations = 0
	profile_planning_slots = 0
	routes.reset_profile()


func print_profile(label: String) -> void:
	print("PROFILE_RESIDENT label=", label, " ticks=", profile_ticks,
		" tick_total_ms=", float(profile_prepare_usec + profile_simulate_usec + profile_display_usec) / 1000.0,
		" tick_max_ms=", float(profile_tick_max_usec) / 1000.0,
		" prepare_ms=", float(profile_prepare_usec) / 1000.0,
		" simulate_ms=", float(profile_simulate_usec) / 1000.0,
		" simulate_max_ms=", float(profile_simulate_max_usec) / 1000.0,
		" display_ms=", float(profile_display_usec) / 1000.0,
		" near_simulations=", profile_near_simulations, " far_simulations=", profile_far_simulations,
		" planning_slots=", profile_planning_slots, " clear_calls=", routes.profile_clear_calls,
		" clear_ms=", float(routes.profile_clear_usec) / 1000.0,
		" recheck_calls=", routes.profile_recheck_calls,
		" recheck_ms=", float(routes.profile_recheck_usec) / 1000.0)


func setup(edges: PackedVector3Array, waterfront: PackedVector3Array, homes: Array[Dictionary],
		height: Callable, movable: Array[RID] = []) -> void:
	ground = height
	moving_bodies = movable
	park_edges = waterfront
	town_edges = edges
	entrances = homes
	for i in NAMES.size():
		var resident := Resident.new()
		resident.random.seed = hash(NAMES[i])
		resident.pace = resident.random.randf_range(.94, 1.48)
		resident.departure = resident.random.randf_range(420.0, 555.0)
		resident.curfew = resident.random.randf_range(1170.0, 1300.0)
		resident.wait = resident.random.randf_range(1.5, 27.0)
		residents.append(resident)


func prepare(spatial: PhysicsDirectSpaceState3D) -> void:
	if routes.points.is_empty():
		routes.build(town_edges, park_edges)

		routes.query.exclude = moving_bodies
		routes.connect_crossings(spatial, ground)
		routes.query.exclude = []
		routes.seal()
		for i in range(0, park_edges.size(), 12):
			for vertex in routes.near(park_edges[i], .15):
				waterfront_nodes[routes.components[vertex]] = true
		return
	routes.query.exclude = moving_bodies
	var batch := mini(building_index + 32, entrances.size())
	while building_index < batch:
		var entry := entrances[building_index]
		building_index += 1
		var node := routes.home_link(entry, spatial, ground)
		if node >= 0:
			candidates.append({"entry": entry, "node": node, "order": hash("houseboat/" + entry.id)})
	routes.query.exclude = []
	if building_index < entrances.size():
		return

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var waterfront_a := waterfront_nodes.has(routes.components[a.node])
		var waterfront_b := waterfront_nodes.has(routes.components[b.node])
		if waterfront_a != waterfront_b:
			return waterfront_a
		return a.order < b.order if a.order != b.order else a.entry.id < b.entry.id)
	var by_cell := {}
	var chosen: Array[Dictionary] = []
	# Spread the household assignments across the available pedestrian districts.
	for candidate in candidates:
		var foot: Vector3 = candidate.entry.foot
		var cell := Vector2i(floori(foot.x / 160.0), floori(foot.z / 160.0))
		if not by_cell.has(cell):
			by_cell[cell] = []
		by_cell[cell].append(candidate)
	while chosen.size() < residents.size():
		var count := chosen.size()
		for cell in by_cell:
			var bucket: Array = by_cell[cell]
			if not bucket.is_empty() and chosen.size() < residents.size():
				chosen.append(bucket.pop_front())
		if count == chosen.size():
			break
	for index in chosen.size():
		var resident := residents[index]
		resident.home = chosen[index].entry
		resident.home_node = chosen[index].node
	initialized = true


func tick(delta: float, work_minutes: float, camera: Camera3D, clock: float, peers: Array[Dictionary],
		authoritative: bool, incoming: PackedVector3Array) -> void:
	var tick_started := Time.get_ticks_usec() if profile_enabled else 0
	if authoritative:
		var space := get_world_3d().direct_space_state
		if not initialized:
			var prepare_started := Time.get_ticks_usec() if profile_enabled else 0
			prepare(space)
			if profile_enabled:
				profile_prepare_usec += Time.get_ticks_usec() - prepare_started
		if initialized:
			routes.recheck_blocked_links(delta, space)
			frame = (frame + 1) % 4
			for i in residents.size():
				var resident := residents[i]
				var near_player := is_near_player(resident.feet, camera.global_position, peers)
				var can_plan := frame == i % 4
				if near_player or can_plan:
					var simulate_started := Time.get_ticks_usec() if profile_enabled else 0
					simulate(resident, delta if near_player else delta * 4.0, work_minutes, camera, peers, space, can_plan)
					if profile_enabled:
						var elapsed := Time.get_ticks_usec() - simulate_started
						profile_simulate_usec += elapsed
						profile_simulate_max_usec = maxi(profile_simulate_max_usec, elapsed)
						profile_near_simulations += int(near_player)
						profile_far_simulations += int(not near_player)
						profile_planning_slots += int(can_plan)
				var display_started := Time.get_ticks_usec() if profile_enabled else 0
				display(i, resident.feet, resident.movement, resident.yaw, camera.global_position, delta, clock)
				if profile_enabled:
					profile_display_usec += Time.get_ticks_usec() - display_started
		if profile_enabled:
			profile_ticks += 1
			profile_tick_max_usec = maxi(profile_tick_max_usec, Time.get_ticks_usec() - tick_started)
		return

	for i in residents.size():
		var feet := Vector3.INF
		var motion := Vector3.ZERO
		if incoming.size() == residents.size() * 2:
			feet = incoming[i * 2]
			motion = incoming[i * 2 + 1]
		display(i, feet, Vector3(motion.y, 0, motion.z), motion.x, camera.global_position, delta, clock)


func snapshot() -> PackedVector3Array:
	if not initialized:
		return PackedVector3Array()
	var result := PackedVector3Array()
	for resident in residents:
		result.append(resident.feet)
		result.append(Vector3(resident.yaw, resident.movement.x, resident.movement.z))
	return result


func is_near_player(at: Vector3, local_eye: Vector3, peers: Array[Dictionary]) -> bool:
	if local_eye.distance_squared_to(at) < ACTIVE_RADIUS * ACTIVE_RADIUS:
		return true
	for peer in peers:
		if Vector3(peer.at).distance_squared_to(at) < ACTIVE_RADIUS * ACTIVE_RADIUS:
			return true
	return false


func observed(at: Vector3, camera: Camera3D, peers: Array[Dictionary], space: PhysicsDirectSpaceState3D) -> bool:
	var point := at + Vector3.UP * .9
	var eye := camera.global_position
	if eye.distance_squared_to(point) < 12.0 * 12.0:
		return true
	if eye.distance_squared_to(point) < ACTIVE_RADIUS * ACTIVE_RADIUS and camera.is_position_in_frustum(point):
		var sight := PhysicsRayQueryParameters3D.create(eye, point, SOLID_MASK)
		if space.intersect_ray(sight).is_empty():
			return true
	for peer in peers:
		var other := Vector3(peer.at) + Vector3.UP * 1.55
		var offset := point - other
		if offset.length_squared() < 12.0 * 12.0:
			return true
		if offset.length_squared() < ACTIVE_RADIUS * ACTIVE_RADIUS:
			var horizontal := Vector3(offset.x, 0, offset.z).normalized()
			var facing := Vector3.FORWARD.rotated(Vector3.UP, peer.yaw)
			if horizontal.dot(facing) > .55:
				var sight := PhysicsRayQueryParameters3D.create(other, point, SOLID_MASK)
				if space.intersect_ray(sight).is_empty():
					return true
	return false


func simulate(resident: Resident, delta: float, work_minutes: float, camera: Camera3D,
		peers: Array[Dictionary], space: PhysicsDirectSpaceState3D, can_plan := true) -> void:
	resident.movement = Vector3.ZERO
	var today := floori(work_minutes / Calendar.MINUTES_PER_DAY)
	var time := fposmod(work_minutes, Calendar.MINUTES_PER_DAY)
	var late := resident.curfew + posmod(hash([resident.home_node, today]), 31) - 15
	resident.wait = maxf(0.0, resident.wait - delta)
	if resident.wait > 0.0:
		return

	match resident.phase:
		Phase.HOME:
			var weekend := 55.0 if posmod(today, Calendar.DAYS.size()) >= 5 else 0.0
			var start := resident.departure + weekend + posmod(hash([today, resident.home_node]), 29) - 14
			if resident.home.is_empty() or time < start or time >= late:
				return
			if observed(resident.home.door, camera, peers, space) or not routes.clear(space, resident.home.door, resident.home.door):
				resident.wait = .7
				return
			resident.feet = resident.home.door
			resident.yaw = atan2(-resident.home.out.x, -resident.home.out.z)
			resident.phase = Phase.DEPARTING
			resident.exterior_leg = false
		Phase.DEPARTING, Phase.ENTERING:
			walk_home(resident, delta, camera, peers, space)
		Phase.RETREATING:
			if advance(resident, routes.points[resident.node], delta, space):
				resident.phase = Phase.ROAMING
				resident.wait = resident.random.randf_range(.6, 2.4)
		Phase.ROAMING, Phase.RETURNING:
			walk_paths(resident, delta, time >= late or time < 240.0, space, can_plan)


func walk_home(resident: Resident, delta: float, camera: Camera3D, peers: Array[Dictionary],
		space: PhysicsDirectSpaceState3D) -> void:
	var departing := resident.phase == Phase.DEPARTING
	var step: Vector3 = resident.home.foot
	if resident.exterior_leg:
		step = routes.points[resident.home_node] if departing else Vector3(resident.home.door)

	if advance(resident, step, delta, space):
		if not resident.exterior_leg:
			resident.exterior_leg = true
		elif departing:
			resident.node = resident.home_node
			resident.phase = Phase.ROAMING
		elif not observed(step, camera, peers, space):
			resident.feet = Vector3.INF
			resident.phase = Phase.HOME
			resident.wait = resident.random.randf_range(3.0, 15.0)
	if departing and resident.blocked_for > 2.5 and resident.exterior_leg:
		resident.phase = Phase.ENTERING
		resident.exterior_leg = false
		resident.blocked_for = 0.0


func walk_paths(resident: Resident, delta: float, return_home: bool,
		space: PhysicsDirectSpaceState3D, can_plan: bool) -> void:
	if resident.next >= resident.path.size():
		if not can_plan:
			return
		if return_home and resident.node == resident.home_node:
			resident.phase = Phase.ENTERING
			resident.exterior_leg = false
			return
		var goal := resident.home_node if return_home else choose_destination(resident)
		resident.path = routes.graph.get_id_path(resident.node, goal) if goal >= 0 else PackedInt64Array()
		resident.next = 1
		resident.phase = Phase.RETURNING if return_home else Phase.ROAMING
		if resident.path.size() < 2:
			resident.failed_plans += 1
			resident.wait = resident.random.randf_range(.65, 1.45)
			return
		resident.failed_plans = 0
	var next_node := int(resident.path[resident.next])
	if not routes.graph.are_points_connected(resident.node, next_node):
		retreat(resident)
	elif advance(resident, routes.points[next_node], delta, space):
		resident.node = next_node
		resident.next += 1
		if return_home and resident.phase == Phase.ROAMING:
			# Finish the current edge before turning home from the next sidewalk point.
			resident.path.clear()
			resident.next = 0
		elif resident.next == resident.path.size() and not return_home:
			resident.wait = resident.random.randf_range(4.0, 15.0)
	elif resident.blocked_for > 2.2:
		routes.block_link(resident.node, next_node)
		retreat(resident)


func retreat(resident: Resident) -> void:
	resident.path.clear()
	resident.next = 0
	resident.phase = Phase.RETREATING
	resident.blocked_for = 0.0


func choose_destination(resident: Resident) -> int:
	var local := routes.districts[routes.components[resident.node]]
	var base := routes.points[resident.home_node if resident.home_node >= 0 else resident.node]
	var area := 330.0 if waterfront_nodes.has(routes.components[resident.node]) else 185.0
	var minimum := 7.0 if resident.failed_plans >= 2 else 21.0
	for attempt in 24:
		var node := local[resident.random.randi_range(0, local.size() - 1)]
		var goal := routes.points[node]
		if goal.distance_squared_to(base) > area * area or goal.distance_squared_to(resident.feet) < minimum * minimum:
			continue
		var busy := false
		for neighbour in residents:
			if neighbour == resident:
				continue
			if neighbour.feet.distance_squared_to(goal) < 9.0 or (
					neighbour.next < neighbour.path.size()
					and routes.points[neighbour.path[-1]].distance_squared_to(goal) < 9.0):
				busy = true
				break
		if not busy:
			return node
	return -1


func advance(resident: Resident, target: Vector3, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	var previous := resident.feet
	if previous.distance_squared_to(target) < .00003:
		resident.blocked_for = 0.0
		return true
	var next := previous.move_toward(target, resident.pace * delta)
	# Use authored sidewalk elevations, following terrain on private front approaches.
	if resident.phase in [Phase.DEPARTING, Phase.ENTERING] and next != target:
		next.y = maxf(next.y, float(ground.call(next.x, next.z)) + .04)
	if not routes.clear(space, previous, next):
		resident.blocked_for += delta
		return false
	resident.feet = next
	resident.blocked_for = 0.0
	resident.movement = (next - previous) / delta
	var planar := Vector2(resident.movement.x, resident.movement.z)
	if planar.length_squared() > .001:
		resident.yaw = atan2(-planar.x, -planar.y)
	return next == target


func display(index: int, feet: Vector3, movement: Vector3, yaw: float,
		eye: Vector3, delta: float, clock: float) -> void:
	var resident := residents[index]
	var radius := ACTIVE_RADIUS + 12.0 if resident.avatar != null and resident.avatar.visible else ACTIVE_RADIUS
	var available := feet.is_finite() and eye.distance_squared_to(feet) <= radius * radius
	if not available:
		if resident.avatar != null and resident.avatar.visible:
			resident.avatar.hide()
			resident.avatar.established = false
			resident.was_walking = false
		return
	if resident.avatar == null:
		resident.avatar = Avatar.new()
		resident.avatar.name = "Resident%d" % index
		add_child(resident.avatar)
		resident.avatar.setup(NAMES[index], index, Color(OUTFITS[index % OUTFITS.size()]), true)
	resident.avatar.show()
	var moving := movement.length_squared() > .015
	if resident.was_walking and not moving:
		resident.idle.start(Idle.LOOK)
	resident.was_walking = moving
	resident.idle.tick(delta, not moving, false)
	resident.avatar.apply_sample({"at": feet, "yaw": yaw, "onboard": false,
		"animation": {"move": movement, "idle": resident.idle.packet()}}, null, delta, clock, eye)
	resident.avatar.label.visible = eye.distance_squared_to(feet) < 25.0
