extends AnimatableBody3D

signal grass_trimmed(index: int)

const Kit = preload("res://scenery.gd")
const PARKING_OFFSET := Vector2(14, 9.6)
const TRACK := .51
const HALF_WHEELBASE := .69
const WHEEL_POINTS := [
	Vector3(-TRACK, 0, -HALF_WHEELBASE), Vector3(TRACK, 0, -HALF_WHEELBASE),
	Vector3(-TRACK, 0, HALF_WHEELBASE), Vector3(TRACK, 0, HALF_WHEELBASE),
]
const WHEEL_RADII := [.153, .153, .29, .29]
const SEATED_FEET := Vector3(0, .11, .25)
const BODY_CENTER := Vector3(0, .69, .06)
const BODY_SIZE := Vector3(1.47, .88, 1.96)
const CUT_DECK := Vector3(0, .22, -.21)
const CUT_HEIGHT := .22
const DRIVE_SPEEDS := [2.4, 4.35, 5.8, 7.2]
const THROTTLE_NAMES := ["Low", "Normal", "High", "Transport"]
const REVERSE_SPEED := 2.05
const TURN_SPEED := 2.35

var river: Node3D
var rider: CharacterBody3D
var body_shape: Shape3D
var exit_shape := CapsuleShape3D.new()
var motor: AudioStreamPlayer3D
var wheels: Array[Node3D] = []
var casters: Array[Node3D] = []
var levers: Array[Node3D] = []
var chase_view := false
var rider_camera: Camera3D
var throttle_lever := Node3D.new()
var throttle_index := 1
var speed := 0.0
var yaw := 0.0
var blades := false
var grass: MultiMeshInstance3D
var grass_cells: Dictionary = {}
var grass_cut := PackedByteArray()
var grass_heights := PackedVector3Array()
var last_cut := Vector3.INF


func setup(map: Node3D) -> void:
	river = map
	name = "ZeroTurnMower"
	sync_to_physics = false
	build_model()
	Kit.collider(self, BODY_CENTER, BODY_SIZE)
	var collider := get_child(get_child_count() - 1) as CollisionShape3D
	body_shape = collider.shape
	exit_shape.radius = .26
	exit_shape.height = 1.62
	var park: Array = river.meta.marina.pavilion
	var parking := Vector3(park[0] + PARKING_OFFSET.x, 0, park[1] + PARKING_OFFSET.y)
	global_transform = ground_pose(parking, yaw)
	update_wheels(0.0, 0.0, 0.0)
	motor = AudioStreamPlayer3D.new()
	motor.stream = engine_loop()
	motor.position = Vector3(0, .57, .79)
	motor.unit_size = 2.2
	motor.max_distance = 35.0
	motor.volume_db = -20.0
	add_child(motor)
	grass = river.waterfront.park_grass
	index_grass()


func build_model() -> void:
	var orange := Kit.paint(Color("#b95324"), .58, .19)
	var dark := Kit.paint(Color("#292d2c"), .76)
	var steel := Kit.paint(Color("#91958a"), .45, .5)
	var rubber := Kit.paint(Color("#242321"), .96)
	var tread := Kit.paint(Color("#363430"), .91)
	Kit.box_at(self, Vector3(0, .43, .16), Vector3(.86, .22, 1.60), dark)
	Kit.box_at(self, Vector3(0, .36, -.61), Vector3(.91, .11, .49), steel)
	Kit.box_at(self, CUT_DECK, Vector3(1.39, .17, .71), orange)
	Kit.box_at(self, CUT_DECK + Vector3(.69, -.032, .08), Vector3(.25, .095, .33), dark)
	Kit.box_at(self, Vector3(0, .62, .78), Vector3(.80, .42, .47), orange)
	for vent in 5:
		Kit.box_at(self, Vector3((vent - 2) * .102, .74, 1.019), Vector3(.058, .085, .014), dark)
	Kit.box_at(self, Vector3(0, .75, .23), Vector3(.45, .14, .43), rubber)
	var backrest := Kit.box_at(self, Vector3(0, .96, .424), Vector3(.45, .38, .113), rubber)
	backrest.rotation.x = .14
	for side: float in [-1.0, 1.0]:
		Kit.box_at(self, Vector3(side * .53, .636, .58), Vector3(.30, .12, .48), orange)
		var lever := Node3D.new()
		add_child(lever)
		lever.position = Vector3(side * .39, .57, .06)
		Kit.beam(lever, Vector3.ZERO, Vector3(0, .47, -.10), .038, steel)
		Kit.beam(lever, Vector3(0, .47, -.10), Vector3(-side * .22, .47, -.10), .062, rubber)
		levers.append(lever)
	add_child(throttle_lever)
	throttle_lever.position = Vector3(.56, .71, .32)
	Kit.box_at(self, Vector3(.56, .707, .32), Vector3(.085, .045, .21), dark)
	Kit.beam(throttle_lever, Vector3.ZERO, Vector3(0, .13, 0), .027, steel)
	Kit.box_at(throttle_lever, Vector3(0, .13, 0), Vector3(.07, .044, .041), Kit.paint(Color("#e9c74e")))
	update_throttle_lever()
	for index in WHEEL_POINTS.size():
		var caster := Node3D.new()
		add_child(caster)
		caster.position = WHEEL_POINTS[index]
		casters.append(caster)
		if index < 2:
			Kit.box_at(caster, Vector3(0, .17, 0), Vector3(.24, .055, .10), steel)
			for side: float in [-1.0, 1.0]:
				Kit.box_at(caster, Vector3(side * .084, .085, 0), Vector3(.035, .17, .075), steel)
		var wheel := Node3D.new()
		caster.add_child(wheel)
		wheels.append(wheel)
		var radius: float = WHEEL_RADII[index]
		var width := .12 if index < 2 else .25
		add_wheel_mesh(wheel, radius, width, rubber)
		add_wheel_mesh(wheel, radius * .52, width + .018, steel)
		for lug in 14:
			var angle := lug * TAU / 14.0
			var block := Kit.box_at(wheel, Vector3(0, cos(angle), sin(angle)) * (radius - .004),
				Vector3(width * .88, .019, radius * .20), tread)
			block.rotation.x = angle


func add_wheel_mesh(parent: Node3D, radius: float, width: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 20
	Kit.mesh_at(parent, mesh, Vector3.ZERO, material).rotation.z = PI * .5


func ground_pose(at: Vector3, heading: float) -> Transform3D:
	var flat := Basis(Vector3.UP, heading)
	var contacts := PackedVector3Array()
	for wheel: Vector3 in WHEEL_POINTS:
		var point := at + flat * wheel
		point.y = river.ground_height(point.x, point.z)
		if point.y < .14 or river.wet_clearance(point) > .26:
			return Transform3D(Basis.IDENTITY, Vector3.INF)
		contacts.append(point)
	var forward := (contacts[0] + contacts[1] - contacts[2] - contacts[3]) * .5
	var right := (contacts[1] + contacts[3] - contacts[0] - contacts[2]) * .5
	var up := right.cross(forward).normalized()
	if up.y < .91:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	return Transform3D(Basis.looking_at(forward, up), (contacts[0] + contacts[1] + contacts[2] + contacts[3]) * .25)


func clear_at(shape: Shape3D, pose: Transform3D, ignored: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.collision_mask = 1
	query.exclude = ignored
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func near(player: CharacterBody3D, eye: Camera3D) -> bool:
	var target := to_global(Vector3(0, .92, .12))
	if player.global_position.distance_squared_to(target) > 2.45 * 2.45:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye.global_position, target, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.rid == get_rid()


func mount(player: CharacterBody3D) -> void:
	rider = player
	rider.add_collision_exception_with(self)
	position_rider()
	rider.reset_physics_interpolation()
	motor.play()


func dismount() -> bool:
	for offset: Vector3 in [Vector3(1.05, 0, .18), Vector3(-1.05, 0, .18),
			Vector3(0, 0, 1.43), Vector3(0, 0, -1.37), Vector3(1.45, 0, -.72), Vector3(-1.45, 0, -.72)]:
		var point := global_position + Basis(Vector3.UP, yaw) * offset
		point.y = river.ground_height(point.x, point.z) + .065
		if point.y < .16 or absf(point.y - global_position.y) > .65 or river.wet_clearance(point) > .26:
			continue
		var pose := Transform3D(Basis.IDENTITY, point + Vector3.UP * .84)
		if not clear_at(exit_shape, pose, [rider.get_rid()]):
			continue
		rider.global_position = point
		leave_seat()
		return true
	return false


func leave_for_flight() -> void:
	if dismount():
		return
	rider.global_position = to_global(Vector3(0, BODY_CENTER.y + BODY_SIZE.y * .5 + .08, 0))
	leave_seat()


func leave_seat() -> void:
	rider.reset_physics_interpolation()
	rider.remove_collision_exception_with(self)
	if is_instance_valid(rider_camera):
		rider_camera.position = Vector3.UP * 1.58
		rider_camera.rotation = Vector3.ZERO
	rider_camera = null
	chase_view = false
	rider = null
	speed = 0.0
	blades = false
	motor.stop()
	for lever in levers:
		lever.rotation.x = 0.0


func shift_throttle(change: int) -> void:
	throttle_index = clampi(throttle_index + change, 0, DRIVE_SPEEDS.size() - 1)
	update_throttle_lever()


func update_throttle_lever() -> void:
	throttle_lever.rotation.x = lerpf(.49, -.54, float(throttle_index) / (DRIVE_SPEEDS.size() - 1))


func throttle_label() -> String:
	return THROTTLE_NAMES[throttle_index]


func update_rider_camera(camera: Camera3D) -> void:
	rider_camera = camera
	if not chase_view:
		camera.position = Vector3.UP * 1.58
		camera.rotation = Vector3(camera.rotation.x, 0, 0)
		return
	var target := to_global(Vector3(0, 1.26, -.09))
	var behind := to_global(Vector3(0, 2.69, 4.0))
	var ray := PhysicsRayQueryParameters3D.create(target, behind, 1, [get_rid(), rider.get_rid()])
	var blocked := get_world_3d().direct_space_state.intersect_ray(ray)
	camera.global_position = blocked.position + (target - behind).normalized() * .18 if not blocked.is_empty() else behind
	camera.look_at(target)


func position_rider() -> void:
	rider.global_position = to_global(SEATED_FEET)
	rider.velocity = Vector3.ZERO


func drive(delta: float, throttle: float, steering: float) -> float:
	var start_yaw := yaw
	var top_speed: float = DRIVE_SPEEDS[throttle_index]
	var desired := throttle * (top_speed if throttle >= 0.0 else REVERSE_SPEED)
	var acceleration := 3.15 if absf(desired) > absf(speed) and desired * speed >= 0.0 else 6.8
	speed = move_toward(speed, desired, delta * acceleration)
	var turn := steering * TURN_SPEED * lerpf(1.0, .58, clampf(absf(speed) / top_speed, 0.0, 1.0)) * delta
	var next_yaw := wrapf(yaw + turn, -PI, PI)
	var forward := -Basis(Vector3.UP, yaw + turn * .5).z
	var start := global_position
	if (not is_zero_approx(speed) or not is_zero_approx(turn)) and not try_pose(start + forward * speed * delta, next_yaw):
		speed = 0.0
		if absf(turn) > .00001:
			try_pose(start, next_yaw)
	var turned := angle_difference(start_yaw, yaw)
	update_wheels(speed * delta, turned, steering)
	for index in levers.size():
		levers[index].rotation.x = -.27 * clampf(throttle + steering * (1.0 if index == 0 else -1.0), -1.0, 1.0)
	var load := maxf(clampf(absf(speed) / top_speed, 0.0, 1.0), absf(steering) * .42)
	motor.pitch_scale = lerpf(motor.pitch_scale, .82 + .44 * load + (.19 if blades else 0.0), minf(1.0, delta * 5.0))
	motor.volume_db = -20.0 + 6.0 * load + (3.0 if blades else 0.0)
	if blades and last_cut.distance_squared_to(to_global(CUT_DECK)) > .15 * .15:
		cut_grass()
	position_rider()
	return turned


func try_pose(at: Vector3, heading: float) -> bool:
	var pose := ground_pose(at, heading)
	if not pose.origin.is_finite() or absf(pose.origin.y - global_position.y) > .19:
		return false
	if not clear_at(body_shape, pose.translated_local(BODY_CENTER), [get_rid(), rider.get_rid()]):
		return false
	global_transform = pose
	yaw = heading
	return true


func update_wheels(distance: float, turned: float, steering: float) -> void:
	for index in wheels.size():
		var caster := casters[index]
		var wheel_at: Vector3 = WHEEL_POINTS[index]
		var point := to_global(wheel_at)
		if index < 2:
			caster.rotation.y = steering * (.83 if absf(speed) < .4 else .40)
		var ground: float = river.ground_height(point.x, point.z)
		caster.position.y = (ground - point.y + WHEEL_RADII[index]) / global_basis.y.y
		wheels[index].rotate_x(-(distance + turned * wheel_at.x) / WHEEL_RADII[index])


func index_grass() -> void:
	if not is_instance_valid(grass):
		return
	var instances := grass.multimesh
	grass_cut.resize(instances.instance_count)
	grass_heights.resize(instances.instance_count)
	for index in instances.instance_count:
		var tuft := instances.get_instance_transform(index)
		grass_heights[index] = tuft.basis.y
		var at := grass.to_global(tuft.origin)
		var cell := Vector2i(floori(at.x), floori(at.z))
		if not grass_cells.has(cell):
			grass_cells[cell] = []
		grass_cells[cell].append(index)


func cut_grass() -> void:
	last_cut = to_global(CUT_DECK)
	if not is_instance_valid(grass):
		return
	var center := Vector2i(floori(last_cut.x), floori(last_cut.z))
	var instances := grass.multimesh
	for z in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			for index: int in grass_cells.get(Vector2i(x, z), []):
				if grass_cut[index]:
					continue
				var tuft := instances.get_instance_transform(index)
				var local := to_local(grass.to_global(tuft.origin)) - CUT_DECK
				if absf(local.x) <= .71 and absf(local.z) <= .39:
					tuft.basis.y *= CUT_HEIGHT
					instances.set_instance_transform(index, tuft)
					grass_cut[index] = 1
					grass_trimmed.emit(index)


func regrow_grass(indices: Array) -> void:
	for index: int in indices:
		if not grass_cut[index]:
			continue
		var tuft := grass.multimesh.get_instance_transform(index)
		tuft.basis.y = grass_heights[index]
		grass.multimesh.set_instance_transform(index, tuft)
		grass_cut[index] = 0
	last_cut = Vector3.INF


func engine_loop() -> AudioStreamWAV:
	const RATE := 22050
	var pcm := PackedByteArray()
	pcm.resize(RATE * 2)
	for frame in RATE:
		var t := float(frame) / RATE
		var phase := TAU * 53.0 * t
		var firing := sin(phase + .19 * sin(phase * 2.0))
		var value := .44 * firing + .20 * sin(phase * 2.0) + .14 * pow(maxf(0, firing), 5.0)
		value += .062 * sin(phase * 6.0) + .043 * sin(TAU * 367.0 * t)
		pcm.encode_s16(frame * 2, roundi(value * 24500.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE
	stream.data = pcm
	return stream
